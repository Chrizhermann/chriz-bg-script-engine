-- Default-off orchestration of one ordinary action. No engine calls or queue clearing.
local values=require('kernel.manifest')
local identity=require('kernel.identity')
local leases=require('kernel.lease')
local combat=require('combat-intent.dispatch')
local M={}
local terminal={completed=true,failed=true,interrupted=true,invalidated=true,['timed-out']=true}
local function actorKey(id) return id.resource..'\0'..id.key end
function M.new(config)
    assert(type(config.read)=='function' and type(config.submit)=='function')
    assert(type(config.maxProposalAgeTicks)=='number' and config.maxProposalAgeTicks>=0 and
        config.maxProposalAgeTicks<math.huge and config.maxProposalAgeTicks%1==0)
    local manager=leases.new(config)
    local admission=config.admission and values.copy(config.admission) or nil
    local enabled,disabled,pending,inDispatch=false,{},{},false
    local api={}
    function api:invalidate(reason,adapterId)
        local ended=manager:invalidate(reason,adapterId)
        for attempt,r in pairs(pending) do
            if not adapterId or r.identity.adapterId==adapterId then pending[attempt]=nil end
        end
        if not adapterId then enabled=false end
        return ended
    end
    function api:setEnabled(value)
        assert(type(value)=='boolean')
        if not value then self:invalidate('runtime-disabled') end
        enabled=value
    end
    function api:disable(adapterId,reason)
        assert(type(adapterId)=='string');disabled[adapterId]=reason or 'adapter-disabled'
        return self:invalidate(disabled[adapterId],adapterId)
    end
    function api:tick()
        local ended=manager:tick();local seen={}
        for _,r in ipairs(ended) do
            seen[r.attemptId]=true
            if pending[r.attemptId] and pending[r.attemptId].state=='unknown' then r.state='unknown' end
            pending[r.attemptId]=nil
        end
        for attempt,r in pairs(pending) do
            if config.clock:now()>=r.deadline then
                if not seen[attempt] then ended[#ended+1]={attemptId=attempt,state=r.state=='unknown' and 'unknown' or 'timed-out',reason='observation-deadline'} end
                pending[attempt]=nil
            end
        end
        table.sort(ended,function(a,b) return a.attemptId<b.attemptId end);return ended
    end
    local function allowed(id)
        if not enabled then return nil,'runtime-disabled' end
        if disabled[id.adapterId] then return nil,'adapter-disabled' end
        for _,r in pairs(pending) do if actorKey(r.identity)==actorKey(id) then return nil,'actor-in-flight' end end
        return true
    end
    local function read(id)
        local ok,result=pcall(function()
            local r=values.copy(config.read(values.copy(id)))
            assert(r.decision.input.frame.observerKey==id.key,'observer-identity-mismatch')
            assert(type(r.ownership)=='table' and type(r.context)=='table')
            return r
        end)
        if not ok then api:disable(id.adapterId,'sample-error');return nil,'sample-error' end
        return result
    end
    local function dispatch(self,rawIdentity,proposal)
        local id,reason=identity.validate(rawIdentity);if not id then return nil,reason end
        self:tick()
        local ok,why=allowed(id);if not ok then return nil,why end
        local first,why=read(id);if not first then return nil,why end
        local request,why=combat.revalidate(proposal,first.decision,config.maxProposalAgeTicks,admission)
        if not request then return nil,why end
        local token,why=manager:acquire(id,first.ownership,first.context);if not token then return nil,why end
        local second,why=read(id)
        if not second then manager:invalidate('sample-error',id.adapterId);return nil,why end
        local stillAllowed,why=allowed(id)
        if not stillAllowed then manager:invalidate(why,id.adapterId);return nil,why end
        local current,why=combat.revalidate(proposal,second.decision,config.maxProposalAgeTicks,admission)
        if not current or not values.equal(request,current) then
            manager:invalidate('candidate-changed',id.adapterId);return nil,why or 'candidate-changed'
        end
        second.ownership.targetLegal=true -- produced only by the fresh closed revalidator
        local result,why=manager:dispatch(token,second.ownership,second.context,current,function(r)
            return config.submit(values.copy(id),r)
        end)
        if not result then return nil,why end
        if result.state=='accepted' or result.state=='unknown' then
            pending[result.attemptId]={identity=values.copy(id),state=result.state,deadline=config.clock:now()+config.attemptTicks}
        end
        return result
    end
    function api:dispatch(rawIdentity,proposal)
        if inDispatch then return nil,'dispatch-in-progress' end
        inDispatch=true
        local ok,result,reason=pcall(dispatch,self,rawIdentity,proposal)
        inDispatch=false
        if not ok then error(result,0) end
        return result,reason
    end
    function api:observe(attempt,event)
        local r=pending[attempt];if not r then return nil,'unknown-attempt' end
        local result,reason=manager:observe(attempt,event)
        if result then
            r.state=result.state
            if terminal[result.state] then pending[attempt]=nil end
        end
        return result,reason
    end
    function api:inspect()
        local count=0;for _ in pairs(pending) do count=count+1 end
        return {enabled=enabled,disabled=values.copy(disabled),pending=count}
    end
    return api
end
return M
