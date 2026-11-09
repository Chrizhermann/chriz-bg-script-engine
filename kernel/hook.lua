-- BCS handoff gate. A hook block in a creature's script calls claim() each time it is
-- reached: true means the engine performs this round's action, false lets the creature's own
-- blocks run on. Guarded copies of SCS blocks above the hook ask the same question in the same
-- script pass, so the gate answers once per creature and tick and repeats that answer.
-- A creature can carry hooked scripts in several slots (an SCS monster script above SCS's
-- general AI, for example). Slots run from override down to default, and a lower script is
-- reached only after the higher ones let the pass through, so the first hooked script that
-- asks in a pass decides for the creature; the others decline in that pass.
-- Scripts without a hook below the deciding one (a summon's BDSUM00, shout, dialogue and plot
-- scripts; Christopher 2026-11-08: the engine takes over every creature) no longer hand the creature
-- back to SCS. An engine round keeps their blocks from running, so on every claim config.owe walks
-- them as the game would (adapters/eeex/lower.lua) and names the blocks that hold now and do more than
-- an ordinary combat round: their shouts, plot variables, dialogue starts and scripted powers. Those
-- duties are owed until the hook's response runs, which hands them to config.perform before the
-- engine's own actions.
-- The engine's own hook (2026-11-10): a fight script that is not SCS's carries one hook block at its
-- top, registered with the family 'auto'. It decides only for a creature none of whose scripts is
-- SCS-hooked (those keep their SCS identity and their guarded blocks), with the family
-- config.resolve gives the creature (by its side and class; nil for one the engine does not drive).
-- The rest of such a script is walked like a lower script: its fight blocks are the engine's, its
-- other blocks are duties.
-- Story targets (Christopher, 2026-11-10: a creature the engine takes over keeps what it was known
-- for): while a creature such a script attacks by name is there (xvarts going for Hulrik's cow, gnolls
-- for Drizzt; config.yields), the creature is its script's, as the game had the encounter. The gate
-- asks again every storyTicks, and the engine takes the creature once the answer is no.
-- Nothing here raises to the caller and nothing in it survives a load.
local values=require('kernel.manifest')
local trace=require('kernel.trace')
local M={}
M.families={'mage','priest','fighter','monster'}
M.AUTO='auto'
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
    local decide,perform,observe,held=config.decide,config.perform,config.observe,config.held
    assert(observe==nil or type(observe)=='function')
    assert(held==nil or type(held)=='function')
    -- owe(id, scripts, tick, deciding) (optional): the duty blocks of the creature's lower scripts
    -- (scripts, in slot order below the deciding one; first the deciding script itself when it
    -- carries the engine's own hook) that hold now, as plain records with a unique key; they stay owed
    -- for maxDutyAgeTicks after they last held (an action of the engine's can run for a round or longer
    -- before the hook's response runs again).
    local owe,dutyAge=config.owe,config.maxDutyAgeTicks or 300
    assert(owe==nil or type(owe)=='function')
    assert(count(dutyAge,1e6))
    -- resolve(id) (optional): the family of a creature that asks from the engine's own hook, or nil.
    local resolve=config.resolve
    assert(resolve==nil or type(resolve)=='function')
    -- yields(id, scripts, tick, deciding) (optional), for a creature that asks from the engine's own
    -- hook, with owe's list: true while a creature those scripts attack by name is there. The answer
    -- stands for storyTicks.
    local yields,storyTicks=config.yields,config.storyTicks or 45
    assert(yields==nil or type(yields)=='function')
    assert(count(storyTicks,1e6))
    -- hooked: script resref (lower case) -> family, from the install. below(id, script): the
    -- creature's non-empty script resrefs in the slots after script, or nil when script is not
    -- in its stack. stack(id) (optional): all its non-empty script resrefs, from the top slot down.
    local hooked,below,stack
    local function setHooked(t)
        assert(t==nil or type(t)=='table')
        if t==nil then hooked=nil;return end
        hooked={}
        for name,family in pairs(t) do
            if type(name)=='string' and #name>0 then hooked[name:lower()]=family end
        end
    end
    setHooked(config.hooked)
    below,stack=config.below,config.stack
    assert(below==nil or type(below)=='function')
    assert(stack==nil or type(stack)=='function')
    local pending,blocked,answers,owed={},{},{},{}
    local owing=0
    -- id -> the tick the creature's story target was last found there; storied counts them (past
    -- owingLimit, creatures that died on their story, every record goes).
    local stories,storied={},0
    local counts={reached=0,repeats=0,claimed=0,acted=0,held=0,renewed=0,skipped=0,stale=0,errors=0,observeErrors=0,
        heldErrors=0,owed=0,dutiesHanded=0,dutiesDropped=0,dutyErrors=0,stories=0,storyErrors=0}
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
    -- Whether a decider's answer, copied (copied, result), is no plain decision, hold or idle hold.
    local function bad(copied,result)
        return not copied or type(result)~='table' or (result.hold~=nil and result.hold~=true) or
            (result.idle~=nil and (result.idle~=true or result.hold~=true))
    end
    -- Whether a script carries SCS's hook (its own family), not the engine's own.
    local function scs(name)
        local family=type(name)=='string' and hooked[name:lower()]
        return family~=nil and family~=false and family~=M.AUTO
    end
    local function familyOf(id)
        if not resolve then return nil end
        local ok,family=pcall(resolve,id)
        if ok and known[family] then return family end
    end
    -- The creature's scripts below the deciding one that are walked for duties: those without a hook
    -- and those with the engine's own, up to the next SCS-hooked one. A pass reaches them only through
    -- every script above, and an SCS-hooked one ends it with its own blocks.
    local function lower(rest)
        local list={}
        for _,name in ipairs(rest) do
            if type(name)~='string' or #name==0 or scs(name) then break end
            list[#list+1]=name:lower()
        end
        return list
    end
    -- At most this many duties per creature and creatures that owe some; past the second limit
    -- (creatures that died owing) every record goes.
    local dutyLimit,owingLimit=8,1024
    local function drop(id) if owed[id]~=nil then owed[id]=nil;owing=owing-1 end end
    local function owes(id,found,tick)
        if type(found)~='table' then return end
        local list=owed[id]
        for _,record in ipairs(found) do
            local copied,item=pcall(values.copy,record)
            if not copied or type(item)~='table' or type(item.key)~='string' then
                bump(counts,'dutyErrors')
            else
                local known=false
                -- A block that holds again stays owed from now.
                for _,old in ipairs(list or {}) do if old.key==item.key then known=true;old.owedAt=tick;break end end
                if not known and #(list or {})<dutyLimit then
                    if not list then
                        if owing>=owingLimit then owed,owing={},0 end
                        list={};owed[id]=list;owing=owing+1
                    end
                    item.owedAt=tick;list[#list+1]=item;bump(counts,'owed')
                end
            end
        end
    end
    -- The duties still fresh, oldest first; they are handed over once.
    local function due(id,tick)
        local list=owed[id]
        drop(id)
        if not list then return nil end
        local fresh={}
        for _,item in ipairs(list) do
            if tick>=item.owedAt and tick-item.owedAt<=dutyAge then fresh[#fresh+1]=item
            else bump(counts,'dutiesDropped') end
        end
        if #fresh>0 then return fresh end
    end
    -- Whether the script keeps a creature that asks from the engine's own hook for its story (see the
    -- top): its story target was there within storyTicks, or is there now.
    local function story(id,under,tick,script)
        local last=stories[id]
        if last and tick>=last and tick-last<=storyTicks then return true end
        local held=false
        if yields and #under>0 then
            local ok,answer=pcall(yields,id,under,tick,script)
            if not ok then bump(counts,'storyErrors') else held=answer==true end
        end
        if held then
            if last==nil then
                if storied>=owingLimit then stories,storied={},0 end
                storied=storied+1
            end
            stories[id]=tick
            bump(counts,'stories')
            log:record({kind='story',actorKey=tostring(id),reason=script,tick=tick})
            return true
        end
        if last~=nil then stories[id]=nil;storied=storied-1 end
        return false
    end
    -- rest: the scripts below, when the claim read them already; auto: the script carries the engine's
    -- own hook.
    local function evaluate(id,actor,family,tick,script,rest,auto)
        if not enabled then return decline('disabled') end
        if not known[family] then return decline('unknown-family') end
        if not families[family] then return decline('family-off') end
        if not hooked then return decline('no-registry') end
        if not below then return decline('no-stack') end
        if not rest then
            local found,list=pcall(below,id,script)
            if not found then failed(id,family,'stack-error',tick);return decline('error') end
            rest=list
        end
        if type(rest)~='table' then return decline('no-stack') end
        local under=lower(rest)
        if auto then table.insert(under,1,script) end
        -- A load restarts the tick count, so a backoff from before it no longer applies.
        if blocked[id] and tick<blocked[id] and blocked[id]-tick<=backoff then return decline('backoff') end
        blocked[id]=nil
        -- A story target keeps the creature with its script: no check-in, no decision, and what the
        -- engine queued for it gives way to the script's block by the game's own rules.
        if auto and story(id,under,tick,script) then pending[id]=nil;return decline('story') end
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
        if bad(copied,result) then failed(id,family,'bad-decision',tick);return decline('error') end
        pending[id]={decision=result,tick=tick,family=family}
        bump(counts,'claimed')
        -- The engine takes this pass: the lower scripts' blocks that hold now and do more than fight
        -- are owed until the hook's response runs. A failing walk only costs those duties.
        if owe and #under>0 then
            local walked,found=pcall(owe,id,under,tick,script)
            if walked then owes(id,found,tick) else bump(counts,'dutyErrors') end
        end
        log:record({kind='claim',actorKey=tostring(id),family=family,
            reason=result.idle and 'idle' or result.hold and 'hold' or 'claimed',tick=tick})
        return true,result.idle and 'idle' or result.hold and 'hold' or 'decision'
    end
    -- actor is {id=..., script=...}: the creature and the hooked script that asks. A claim also
    -- names its kind: 'decision' (a response to perform), 'hold' (the creature's running action
    -- goes on) or 'idle' (a hold with the creature standing still: an action of the engine's own
    -- that still runs is no longer wanted).
    function api:claim(actor,family)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return decline('bad-actor') end
        local script=rawget(actor,'script')
        if type(script)~='string' or #script==0 or #script>32 then return decline('bad-script') end
        script=script:lower()
        local auto=false
        if family==M.AUTO then
            if not hooked then return decline('no-registry') end
            if hooked[script]~=M.AUTO then return decline('unknown-family') end
            family=familyOf(id)
            if not family then return decline('no-family') end
            auto=true
        end
        local tick=now();if not tick then return decline('no-clock') end
        local seen=answers[id]
        if seen and seen.tick==tick then
            if seen.script==script and seen.family==family then bump(counts,'repeats');return seen.result,seen.kind end
            -- Another of the creature's scripts asked first in this pass and decided.
            if seen.script~=script then return decline('lower-script') end
        end
        bump(counts,'reached')
        -- The engine's own hook above an SCS-hooked script stands back without an answer: the SCS
        -- script decides in this pass, with its guarded blocks.
        local rest
        if auto and below then
            local found,list=pcall(below,id,script)
            if found and type(list)=='table' then
                for _,name in ipairs(list) do
                    if scs(name) then return decline('scs-script') end
                end
                rest=list
            end
        end
        local result,kind=evaluate(id,actor,family,tick,script,rest,auto)
        answers[id]={tick=tick,script=script,family=family,result=result,kind=kind}
        return result,kind
    end
    -- A decision is performed once, by the hook's response. {hold=true} claims the round
    -- without queueing anything, so the creature's running action is left alone, and
    -- {hold=true,idle=true} claims it for the creature to stand still; config.held (optional)
    -- hears of either, with the claim's family, and its errors change nothing. The game runs a
    -- block's response only once the creature has nothing left to do or another block interrupted
    -- its actions, so a plain hold whose response runs finds the action it meant to leave alone
    -- gone: config.held may answer such a hold with a new decision, performed here as a claimed one
    -- is ('renewed'). Its answer to an idle hold, or a hold, changes nothing; an answer that is no
    -- decision counts as one of its errors.
    -- The duties owed by the lower scripts (still fresh, oldest first) go to config.perform as a third
    -- argument, to be queued before the decision's own actions; a hold that is not renewed hands them
    -- over alone, as perform(actor, {hold=true}, duties).
    function api:act(actor)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return false,'bad-actor' end
        local p=pending[id];pending[id]=nil
        if not p then return false,'no-pending' end
        local tick=now()
        if not tick or tick<p.tick or tick-p.tick>maxAge then bump(counts,'stale');return false,'stale' end
        if not enabled or not families[p.family] then drop(id);return false,'disabled' end
        -- What the lower scripts owe goes first, in the same response as the engine's own actions.
        local duties=due(id,tick)
        if duties then
            for _ in ipairs(duties) do bump(counts,'dutiesHanded') end
            log:record({kind='duty',actorKey=tostring(id),family=p.family,reason=duties[1].key,tick=tick})
        end
        local decision,reason=p.decision,'performed'
        if decision.hold then
            bump(counts,'held')
            local answer
            if held then
                local ok,result=pcall(function() return held(values.copy(actor),values.copy(decision),p.family) end)
                if ok then answer=result else bump(counts,'heldErrors') end
            end
            local renewed
            if answer~=nil and not decision.idle then
                local copied,result=pcall(values.copy,answer)
                if bad(copied,result) then bump(counts,'heldErrors')
                elseif not result.hold then renewed=result end
            end
            if not renewed then
                -- The hold's response runs once the creature has nothing left to do: the duties alone.
                if duties and perform then
                    local ok,done=pcall(function() return perform(values.copy(actor),{hold=true},duties) end)
                    if not ok or done~=true then bump(counts,'dutyErrors') end
                end
                log:record({kind='act',actorKey=tostring(id),family=p.family,reason='held',tick=tick})
                return true,'held'
            end
            bump(counts,'renewed')
            decision,reason=renewed,'renewed'
        end
        if not perform then failed(id,p.family,'no-performer',tick);return false,'no-performer' end
        local ok,done=pcall(function() return perform(values.copy(actor),values.copy(decision),duties) end)
        -- 'skipped': the decision no longer fits (its target died meanwhile); no error, no backoff.
        if ok and done=='skipped' then
            bump(counts,'skipped')
            log:record({kind='act',actorKey=tostring(id),family=p.family,reason='skipped',tick=tick})
            return false,'skipped'
        end
        if not ok or done~=true then failed(id,p.family,ok and 'not-performed' or 'perform-error',tick);return false,'error' end
        bump(counts,'acted')
        log:record({kind='act',actorKey=tostring(id),family=p.family,reason=reason,tick=tick})
        return true,reason=='renewed' and 'renewed' or nil
    end
    -- Whether the gate is on for a family right now (for helpers that act outside a claim).
    function api:allows(family) return enabled and known[family]==true and families[family]==true end
    -- Whether the gate's own switch is on (the engine's kill switch), for helpers outside any family.
    function api:on() return enabled end
    -- Whether the gate would ask the decider about this creature from this script now (its
    -- switches, the registry, a readable script stack, a decider and no backoff after an error),
    -- without asking. Scripts without a hook below change nothing: the engine drives the creature
    -- and runs their duties.
    function api:drives(actor,family)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return false end
        local script=rawget(actor,'script')
        if type(script)~='string' or #script==0 or #script>32 then return false end
        if not (enabled and known[family] and families[family] and hooked and below and decide) then return false end
        local tick=now()
        if not tick then return false end
        if blocked[id] and tick<blocked[id] and blocked[id]-tick<=backoff then return false end
        local found,rest=pcall(below,id,script:lower())
        return found and type(rest)=='table'
    end
    -- The family of the script that decides for the creature, when the gate would ask the
    -- decider from it now (api:drives), else nil; the actor names the script that asks, which must
    -- be in the creature's stack. The first hooked script in the stack decides: a lower script
    -- runs only after every higher one let the pass through, and a higher hooked script asks on
    -- the way. For SCS blocks in any of the creature's hooked scripts that stand aside while the
    -- engine drives it, and for the game's own vanishing exits in a script above the first hooked
    -- one, which runs first in each pass and lets it through whenever it does not act itself.
    function api:driver(actor)
        local id=type(actor)=='table' and rawget(actor,'id')
        if not scalarId(id) then return nil end
        local script=rawget(actor,'script')
        if type(script)~='string' or #script==0 or #script>32 or not (stack and hooked) then return nil end
        script=script:lower()
        local found,names=pcall(stack,id)
        if not found or type(names)~='table' then return nil end
        -- The first SCS-hooked script decides; without one, the first with the engine's own hook, as
        -- the family the creature resolves to.
        local first,own,asks
        for _,name in ipairs(names) do
            if type(name)=='string' then
                name=name:lower()
                if scs(name) then first=first or name
                elseif hooked[name]==M.AUTO then own=own or name end
                if name==script then asks=true end
            end
        end
        local decider=first or own
        if not (asks and decider) then return nil end
        local family
        if first then family=hooked[first] else family=familyOf(id) end
        if family and api:drives({id=id,script=decider},family) then return family end
        return nil
    end
    function api:setEnabled(value)
        assert(type(value)=='boolean');enabled=value;answers={}
        if not value then pending,owed,owing={},{},0 end
    end
    function api:setFamily(family,value)
        assert(known[family] and type(value)=='boolean');families[family]=value;answers={}
        if not value then for id,p in pairs(pending) do if p.family==family then pending[id]=nil end end end
    end
    function api:setDecider(fn) assert(fn==nil or type(fn)=='function');decide=fn;pending,answers={},{} end
    function api:setPerformer(fn) assert(fn==nil or type(fn)=='function');perform=fn;pending,answers={},{} end
    function api:setHooked(t) setHooked(t);answers={} end
    function api:invalidate() pending,blocked,answers,owed,owing,stories,storied={},{},{},{},0,{},0 end
    function api:inspect()
        local open=0;for _ in pairs(pending) do open=open+1 end
        local scripts=0;for _ in pairs(hooked or {}) do scripts=scripts+1 end
        return {enabled=enabled,families=values.copy(families),counts=values.copy(counts),
            declines=values.copy(declines),pending=open,owing=owing,storied=storied,hookedScripts=hooked and scripts or nil,
            trace=log:snapshot()}
    end
    return api
end
return M
