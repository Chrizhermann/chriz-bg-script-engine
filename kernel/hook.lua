-- BCS handoff gate. A hook block in a creature's script calls claim() each time it is
-- reached: true means the engine performs this round's action, false lets the creature's own
-- blocks run on. Guarded copies of SCS blocks above the hook ask the same question in the same
-- script pass, so the gate answers once per creature and tick and repeats that answer.
-- A creature can carry hooked scripts in several slots (an SCS monster script above SCS's
-- general AI, for example). Slots run from override down to default, and a lower script is
-- reached only after the higher ones let the pass through, so the first hooked script that
-- asks in a pass decides for the creature; the others decline in that pass. The engine also
-- declines when a script that carries no hook sits below the deciding one: an engine round
-- would keep that script from ever running.
-- Nothing here raises to the caller and nothing in it survives a load.
local values=require('kernel.manifest')
local trace=require('kernel.trace')
local M={}
M.families={'mage','priest','fighter','monster'}
local known={};for _,family in ipairs(M.families) do known[family]=true end
local function scalarId(id) return type(id)=='number' and id>=0 and id<4294967296 and id%1==0 end
local function count(value,limit) return type(value)=='number' and value>=0 and value<=limit and value%1==0 end
function M.new(config)
    assert(type(config)=='table' and type(config.now)=='function','clock required')
    local backoff,maxAge=config.backoffTicks or 150,config.maxDecisionAgeTicks or 30
    assert(count(backoff,1e6) and count(maxAge,1e6))
    local enabled=config.enabled~=false
    local families={}
    for family in pairs(known) do
        families[family]=not(type(config.families)=='table' and config.families[family]==false)
    end
    local decide,perform,observe=config.decide,config.perform,config.observe
    assert(observe==nil or type(observe)=='function')
    -- hooked: script resref (lower case) -> family, from the install. below(id, script): the
    -- creature's non-empty script resrefs in the slots after script, or nil when script is not
    -- in its stack.
    local hooked,below
    local function setHooked(t)
        assert(t==nil or type(t)=='table')
        if t==nil then hooked=nil;return end
        hooked={}
        for name,family in pairs(t) do
            if type(name)=='string' and #name>0 then hooked[name:lower()]=family end
        end
    end
    setHooked(config.hooked)
    below=config.below
    assert(below==nil or type(below)=='function')
    local pending,blocked,answers={},{},{}
    local counts={reached=0,repeats=0,claimed=0,acted=0,held=0,skipped=0,stale=0,errors=0,observeErrors=0}
    local declines={}
    local log=trace.new(config.traceCapacity or 64)
    local api={}
    local function bump(t,key) t[key]=math.min((t[key] or 0)+1,4294967295) end
    local function decline(reason) bump(declines,reason);return false end
    local function now()
        local ok,tick=pcall(config.now)
        if ok and count(tick,4294967295) then return tick end
    end
    local function failed(id,family,reason,tick)
        bump(counts,'errors')
        if tick then blocked[id]=tick+backoff end
        log:record({kind='error',actorKey=tostring(id),family=family,reason=reason,tick=tick})
    end
    local function evaluate(id,actor,family,tick,script)
        if not enabled then return decline('disabled') end
        if not known[family] then return decline('unknown-family') end
        if not families[family] then return decline('family-off') end
        if not hooked then return decline('no-registry') end
        if not below then return decline('no-stack') end
        local found,rest=pcall(below,id,script)
        if not found then failed(id,family,'stack-error',tick);return decline('error') end
        if type(rest)~='table' then return decline('no-stack') end
        for _,name in ipairs(rest) do
            if type(name)~='string' or not hooked[name:lower()] then return decline('script-below') end
        end
        -- A load restarts the tick count, so a backoff from before it no longer applies.
        if blocked[id] and tick<blocked[id] and blocked[id]-tick<=backoff then return decline('backoff') end
        blocked[id]=nil
        -- An observer (the fight director's check-in) sees every creature the gate would ask
        -- the decider about; its errors never change the answer.
        if observe and not pcall(function()
            local view=values.copy(actor);view.script=script
            observe(view,family)
        end) then bump(counts,'observeErrors') end
        if not decide then return decline('no-decider') end
        local ok,decision=pcall(function()
            local view=values.copy(actor);view.script=script
            return decide(view,family)
        end)
        if not ok then failed(id,family,'decide-error',tick);return decline('error') end
        if decision==nil then pending[id]=nil;return decline('no-decision') end
        local copied,result=pcall(values.copy,decision)
        if not copied or type(result)~='table' or (result.hold~=nil and result.hold~=true) then
            failed(id,family,'bad-decision',tick);return decline('error')
        end
        pending[id]={decision=result,tick=tick,family=family}
        bump(counts,'claimed')
        log:record({kind='claim',actorKey=tostring(id),family=family,reason=result.hold and 'hold' or 'claimed',tick=tick})
        return true
    end
    -- actor is {id=..., script=...}: the creature and the hooked script that asks.
    function api:claim(actor,family)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return decline('bad-actor') end
        local script=rawget(actor,'script')
        if type(script)~='string' or #script==0 or #script>32 then return decline('bad-script') end
        script=script:lower()
        local tick=now();if not tick then return decline('no-clock') end
        local seen=answers[id]
        if seen and seen.tick==tick then
            if seen.script==script and seen.family==family then bump(counts,'repeats');return seen.result end
            -- Another of the creature's scripts asked first in this pass and decided.
            if seen.script~=script then return decline('lower-script') end
        end
        bump(counts,'reached')
        local result=evaluate(id,actor,family,tick,script)
        answers[id]={tick=tick,script=script,family=family,result=result}
        return result
    end
    -- A decision is performed once, by the hook's response. {hold=true} claims the round
    -- without queueing anything, so the creature's running action is left alone.
    function api:act(actor)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return false,'bad-actor' end
        local p=pending[id];pending[id]=nil
        if not p then return false,'no-pending' end
        local tick=now()
        if not tick or tick<p.tick or tick-p.tick>maxAge then bump(counts,'stale');return false,'stale' end
        if not enabled or not families[p.family] then return false,'disabled' end
        if p.decision.hold then
            bump(counts,'held')
            log:record({kind='act',actorKey=tostring(id),family=p.family,reason='held',tick=tick})
            return true,'held'
        end
        if not perform then failed(id,p.family,'no-performer',tick);return false,'no-performer' end
        local ok,done=pcall(function() return perform(values.copy(actor),values.copy(p.decision)) end)
        -- 'skipped': the decision no longer fits (its target died meanwhile); no error, no backoff.
        if ok and done=='skipped' then
            bump(counts,'skipped')
            log:record({kind='act',actorKey=tostring(id),family=p.family,reason='skipped',tick=tick})
            return false,'skipped'
        end
        if not ok or done~=true then failed(id,p.family,ok and 'not-performed' or 'perform-error',tick);return false,'error' end
        bump(counts,'acted')
        log:record({kind='act',actorKey=tostring(id),family=p.family,reason='performed',tick=tick})
        return true
    end
    -- Whether the gate is on for a family right now (for helpers that act outside a claim).
    function api:allows(family) return enabled and known[family]==true and families[family]==true end
    function api:setEnabled(value)
        assert(type(value)=='boolean');enabled=value;answers={}
        if not value then pending={} end
    end
    function api:setFamily(family,value)
        assert(known[family] and type(value)=='boolean');families[family]=value;answers={}
        if not value then for id,p in pairs(pending) do if p.family==family then pending[id]=nil end end end
    end
    function api:setDecider(fn) assert(fn==nil or type(fn)=='function');decide=fn;pending,answers={},{} end
    function api:setPerformer(fn) assert(fn==nil or type(fn)=='function');perform=fn;pending,answers={},{} end
    function api:setHooked(t) setHooked(t);answers={} end
    function api:invalidate() pending,blocked,answers={},{},{} end
    function api:inspect()
        local open=0;for _ in pairs(pending) do open=open+1 end
        local scripts=0;for _ in pairs(hooked or {}) do scripts=scripts+1 end
        return {enabled=enabled,families=values.copy(families),counts=values.copy(counts),
            declines=values.copy(declines),pending=open,hookedScripts=hooked and scripts or nil,
            trace=log:snapshot()}
    end
    return api
end
return M
