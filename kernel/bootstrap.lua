-- Observer-only kernel. There is deliberately no queue, local-write or persistence API.
local values=require('kernel.manifest')
local identity=require('kernel.identity')
local registry=require('adapters.registry')
local engine=require('kernel.engine')
local trace=require('kernel.trace')
local M={}
function M.new(config)
    assert(type(config)=='table' and type(config.clock)=='table' and type(config.clock.now)=='function')
    assert(type(config.retryTicks)=='number' and config.retryTicks>=1 and config.retryTicks<math.huge)
    local support=registry.new()
    local log=trace.new(config.traceCapacity)
    local adapters,enrolled={},{ }
    local enabled,session,unknown,sampling=true,0,0,false
    local api={}
    function api:register(declaration,observe)
        assert(type(observe)=='function','observer callback required')
        local m,reason=values.validate(declaration);if not m then return false,reason end
        local ok,why=support:register(m);if not ok then return false,why end
        adapters[m.id]={manifest=m,observe=observe,state='closed',retryAt=0,errors=0}
        return true
    end
    function api:enroll(input)
        if not enabled then return false,'runtime-disabled' end
        local id,reason=identity.validate(input);if not id then return false,reason end
        if not adapters[id.adapterId] then return false,'unknown-adapter' end
        local key=id.adapterId..'\0'..id.resource..'\0'..id.key
        enrolled[key]=id;return true
    end
    local function sample(environment,candidates,readSnapshot)
        if not enabled then return end
        assert(type(readSnapshot)=='function','snapshot reader required')
        local now=config.clock:now()
        support:observeEnvironment(environment)
        local generation=session
        local keys,seen={},{}
        for key in pairs(enrolled) do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys) do
            local id=enrolled[key]
            local a=adapters[id.adapterId]
            local resolved,reason=identity.resolve(id,candidates)
            local eligibility=resolved and support:evaluate(id.adapterId,environment,resolved)
            if eligibility and not eligibility.eligible then reason=eligibility.reason end
            if eligibility and eligibility.eligible then
                seen[id.resource..'\0'..id.key]=true
                if a.state=='open' and now<a.retryAt then reason='circuit-open'
                else
                    if a.state=='open' then a.state='half-open' end
                    local ok=pcall(function()
                        local scalar=engine.snapshot(readSnapshot(values.copy(id),values.copy(resolved)))
                        assert(scalar.area==resolved.area,'snapshot-area-changed')
                        a.observe(values.copy(id),scalar)
                    end)
                    if session~=generation or not enabled then return end
                    if ok then a.state='closed';reason='observed'
                    else a.state='open';a.errors=math.min(a.errors+1,65535);a.retryAt=now+config.retryTicks;reason='adapter-error' end
                end
            end
            log:record({kind='sample',actorKey=id.key,adapterId=id.adapterId,profile=a.manifest.profile,
                snapshotVersion=1,owner='legacy',reason=reason or 'invalid-observation',tick=now})
        end
        local count=0
        if type(candidates)=='table' then
            for _,candidate in ipairs(candidates) do
                if type(candidate)=='table' and type(candidate.resource)=='string' and type(candidate.key)=='string'
                    and not seen[candidate.resource..'\0'..candidate.key] then count=count+1 end
            end
        end
        unknown=count -- aggregate only: no callbacks or persistent records for unknown actors
    end
    function api:sample(environment,candidates,readSnapshot)
        if sampling then return false,'reentrant-sample' end
        sampling=true
        local ok=pcall(sample,environment,candidates,readSnapshot)
        sampling=false
        if not ok then
            enrolled={};enabled=false;session=session+1
            log:record({kind='invalidate',reason='sample-boundary-error',owner='legacy'})
            return false,'sample-boundary-error'
        end
        return true
    end
    function api:disable(adapterId,reason)
        return support:quarantine(adapterId,reason or 'adapter-disabled')
    end
    function api:invalidate(reason)
        enrolled={};session=session+1
        log:record({kind='invalidate',reason=reason,tick=config.clock:now(),owner='legacy'})
    end
    function api:shutdown()
        self:invalidate('runtime-disabled');enabled=false
    end
    function api:inspect()
        local circuits,count={},0
        for _ in pairs(enrolled) do count=count+1 end
        for id,a in pairs(adapters) do circuits[id]={state=a.state,errors=a.errors,retryAt=a.retryAt} end
        return {enabled=enabled,session=session,enrolled=count,unknown=unknown,
            trace=log:snapshot(),circuits=circuits,support=support:report()}
    end
    return api
end
return M
