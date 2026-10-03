-- One normal typed submission. This module cannot build BAF or clear an engine queue.
local values=require('kernel.manifest')
local identity=require('kernel.identity')
local ownership=require('kernel.ownership')
local attempts=require('kernel.action_attempt')
local M={}
local function integer(v) return type(v)=='number' and v==v and v>=0 and v<math.huge and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=256 and not v:find('\0',1,true) end
local function context(c)
    if type(c)~='table' or getmetatable(c)~=nil then return false end
    return text(c.epoch) and integer(c.session) and text(c.area) and integer(c.allegiance) and text(c.adapterVersion)
end
local function currentIdentity(id,c)
    local resolved,reason=identity.resolve(id,c.candidates)
    if not resolved then return nil,reason end
    if resolved.epoch~=c.epoch or resolved.area~=c.area then return nil,'stale-identity' end
    return resolved
end
local function sameContext(a,b)
    for _,field in ipairs({'epoch','session','area','allegiance','adapterVersion'}) do
        if a[field]~=b[field] then return false end
    end
    return true
end
local function requestShape(r)
    if type(r)~='table' or getmetatable(r)~=nil then return false end
    local fields
    if r.kind=='spell' then
        fields={kind=true,resource=true,targetKey=true}
        if not text(r.resource) or #r.resource>8 or r.resource:find('[^A-Z0-9_#-]') or not text(r.targetKey) then return false end
    elseif r.kind=='attack' then
        fields={kind=true,targetKey=true};if not text(r.targetKey) then return false end
    elseif r.kind=='move' then
        fields={kind=true,x=true,y=true};if not integer(r.x) or not integer(r.y) then return false end
    else return false end
    for k in pairs(r) do if not fields[k] then return false end end
    return true
end

function M.new(config)
    assert(type(config)=='table' and type(config.clock)=='table' and type(config.clock.now)=='function')
    assert(integer(config.leaseTicks) and config.leaseTicks>0 and integer(config.attemptTicks) and config.attemptTicks>0)
    local sequence=0
    local leases,records,locks={},{},{}
    local api={}
    local function key(id) return id.resource..'\0'..id.key end
    local function unlock(k,token) if locks[k]==token then locks[k]=nil end end
    local function reap(now)
        local ended={}
        for token,l in pairs(leases) do
            if now>=l.deadline then leases[token]=nil;unlock(l.actor,token) end
        end
        for token,r in pairs(records) do
            if now>=r.deadline then
                ended[#ended+1]={attemptId=token,state='timed-out',reason='observation-deadline'}
                records[token]=nil;unlock(r.actor,token)
            end
        end
        table.sort(ended,function(a,b) return a.attemptId<b.attemptId end)
        return ended
    end
    -- Call on each observation tick before acquisition to record expired outcomes.
    function api:tick() return reap(config.clock:now()) end
    function api:acquire(input,snapshot,observed)
        local id,reason=identity.validate(input);if not id then return nil,reason end
        if not context(observed) then return nil,'invalid-context' end
        local resolved,why=currentIdentity(id,observed);if not resolved then return nil,why end
        local decision=ownership.decide(snapshot);if not decision.combat then return nil,decision.reason end
        local now=config.clock:now();reap(now)
        local actor=key(id);if locks[actor] then return nil,'actor-in-flight' end
        sequence=sequence+1;local token='lease:'..sequence
        leases[token]={identity=id,actor=actor,context=values.copy(observed),deadline=now+config.leaseTicks}
        locks[actor]=token
        return {id=token,identity=values.copy(id),expiresAt=now+config.leaseTicks}
    end
    function api:dispatch(token,snapshot,observed,request,submit)
        local now=config.clock:now();reap(now)
        local l=type(token)=='table' and leases[token.id]
        if not l then return nil,'stale-lease' end
        -- Consume before checking/submitting. Even a failed dispatch cannot reuse the lease.
        leases[token.id]=nil;unlock(l.actor,token.id)
        if not context(observed) or not sameContext(observed,l.context) then return nil,'context-changed' end
        local resolved,why=currentIdentity(l.identity,observed);if not resolved then return nil,why end
        local decision=ownership.decide(snapshot);if not decision.combat then return nil,decision.reason end
        if snapshot.targetLegal~=true then return nil,'target-invalid' end
        if not requestShape(request) or type(submit)~='function' then return nil,'invalid-request' end
        sequence=sequence+1;local attemptId='attempt:'..sequence
        local r={actor=l.actor,identity=l.identity,deadline=now+config.attemptTicks,value=attempts.new(attemptId)}
        records[attemptId]=r;locks[l.actor]=attemptId -- covers reentrant calls during submission
        local ok,accepted=pcall(submit,values.copy(request))
        if records[attemptId]~=r then
            return {attemptId=attemptId,state='invalidated',reason='during-dispatch'}
        end
        if ok and accepted==true then
            r.value=attempts.reduce(r.value,{attemptId=attemptId,kind='accepted'})
        elseif ok and accepted==false then
            r.value=attempts.reduce(r.value,{attemptId=attemptId,kind='failed',reason='submission-rejected'})
            records[attemptId]=nil;unlock(l.actor,attemptId)
        else
            r.value=attempts.reduce(r.value,{attemptId=attemptId,kind='unknown',reason='submission-unknown'})
            -- May have queued before an error. Keep only a bounded duplicate-prevention lock.
        end
        return values.copy(r.value)
    end
    function api:observe(attemptId,event)
        reap(config.clock:now())
        local r=records[attemptId];if not r then return nil,'unknown-attempt' end
        local ok,e=pcall(values.copy,event);if not ok or type(e)~='table' then return nil,'invalid-event' end
        if e.attemptId==nil then e.attemptId=attemptId end
        local valid,result,reason=pcall(attempts.reduce,r.value,e)
        if not valid then return nil,'invalid-event' end
        r.value=result
        if reason=='applied' and result.state~='accepted' and result.state~='proposed' then
            unlock(r.actor,attemptId)
            if result.state~='started' and result.state~='advanced' then records[attemptId]=nil end
        end
        return values.copy(result),reason
    end
    function api:invalidate(reason,adapterId)
        assert(text(reason),'invalidation reason required')
        local ended={}
        for token,l in pairs(leases) do
            if not adapterId or l.identity.adapterId==adapterId then
                leases[token]=nil;unlock(l.actor,token)
            end
        end
        for token,r in pairs(records) do
            if not adapterId or r.identity.adapterId==adapterId then
                ended[#ended+1]={attemptId=token,state='invalidated',reason=reason}
                records[token]=nil;unlock(r.actor,token)
            end
        end
        table.sort(ended,function(a,b) return a.attemptId<b.attemptId end)
        return ended
    end
    return api
end
return M
