-- EEex side of the BCS handoff. A hook block's trigger calls BGSE_Claim(object, family, script)
-- and its response calls BGSE_Act(object); guarded copies of SCS blocks above the hook call
-- BGSE_Claim too. script is the hooked script's own resref, written in at install time. SCS's own
-- cloud blocks above the hook (escapes, runs from a marker, stand-still) ask
-- BGSE_Zones(object, family, script) last and stand aside while it is true: the engine weighs
-- danger zones for the creature (D3e). SCS's hunting blocks ask BGSE_Search(object, family,
-- script) the same way: the engine searches for every creature it drives. SCS's free
-- invisibility asks BGSE_Hide(object, family, script, kind) the same way: the engine hides a thief
-- by its own skill (F2f). SCS's preparation (prebuffs, contingencies, chain contingencies,
-- first-round casts) asks BGSE_Prep(object, family, script, kind, cast, spent) the same way, and a
-- prebuff, contingency or chain that ran calls BGSE_Prepped with the same names from its response.
-- SCS's vanishing exits ask BGSE_Stay(object, family, script) the same way: the engine keeps every
-- creature it drives in the fight unless its orders let it leave.
-- All go by the script that decides for the creature (kernel/hook.lua, driver), which for a creature
-- with two hooked scripts is the higher one, also in the lower one's blocks.
-- Switches live in the player's Baldur.lua under [BGSE] (Enabled, Mages, Priests, Fighters,
-- Monsters; all on unless set to 0). The install also writes M_BGSEHK.lua, which sets
-- BGSE_HOOKED (hooked script -> family); the gate reads it on first use. Errors never escape
-- into the creature's script: a failure is a decline, and the script's own blocks run on.
-- options.director (adapters/eeex/director.lua) gets the gate's check-ins and EEex's
-- started-action events; it acts only while the gate is on for the creature's family.
-- options.choice (adapters/eeex/choice.lua) is the engine's own choice; options.prepare runs
-- right before a decision's response is queued and may skip it ('skipped'): a target gone by
-- then is no error. options.held(object, decision, family) runs when the hook's response holds
-- instead; for a plain hold it may answer with a new decision, which is queued the same way
-- (kernel/hook.lua: the response of a plain hold runs only once the action it held is gone).
-- The game leaves the actions a script block queued running while that same block stays true,
-- and runs its response again only once the creature has nothing left to do; any other block that
-- fires interrupts them. So the hook block alone could never replace the engine's own running
-- action with a new decision: once in lab batch I a glabrezu's attack went on at a dead target for
-- a minute while its teleport waited. The game records which block queued a creature's actions
-- (m_curScriptNum, m_curResponseSetNum, m_curResponseNum). A claim that wants something else (a
-- new decision, or a hold with the creature standing still) clears the response set number while
-- the actions the hook's last response queued still run as queued: the hook block then counts as
-- another block, and the game interrupts them in the same pass by its own rules (lab step W).
-- Anything else in the creature's queue, a story's action added behind them for one, keeps it from
-- happening. options.replaced(object, info) hears of each.
local hook=require('kernel.hook')
local M={}
M.keys={mage='Mages',priest='Priests',fighter='Fighters',monster='Monsters'}
local function ini(g,key)
    local get=rawget(g,'Infinity_GetINIValue')
    if type(get)~='function' then return 1 end
    local ok,value=pcall(get,'BGSE',key,1)
    if ok and type(value)=='number' then return value end
    return 1
end
M.ini=ini
function M.settings(g)
    local families={}
    for family,key in pairs(M.keys) do families[family]=ini(g,key)~=0 end
    return {enabled=ini(g,'Enabled')~=0,families=families}
end
local function store(g,key,value)
    local set=rawget(g,'Infinity_SetINIValue')
    if type(set)=='function' then pcall(set,'BGSE',key,value and 1 or 0) end
end
-- Game time, in ticks (15 per second). Every block of one script pass sees the same tick,
-- and game time stands still while the game is paused.
function M.gameTime(g)
    local chitin=rawget(g,'EEex_EngineGlobal_CBaldurChitin')
    local engine=rawget(g,'EngineGlobals')
    if not chitin and engine then chitin=engine.g_pBaldurChitin end
    return chitin.m_pObjectGame.m_worldTime.m_gameTime
end
-- Only a plain record leaves the engine boundary; the object itself is never kept.
local function actor(object,script) return {id=object.m_id,script=script} end
local function sprite(g,id)
    local object=g.EEex_GameObject_Get(id)
    if object and g.EEex_GameObject_IsSprite(object,false) then return object end
end
-- Script levels in the order the engine runs them (SCRLEV.IDS: override, area, specifics,
-- class, race, general, default; 3 is unused), read with EEex's own accessor.
M.levels={0,1,2,4,5,6,7}
function M.scripts(g,object)
    local get=g.EEex_AIBase_GetScriptLevelResRef
    if type(get)~='function' then return nil end
    local names={}
    for i,level in ipairs(M.levels) do
        local name=get(object,level)
        names[i]=type(name)=='string' and name:lower() or ''
    end
    return names
end
-- The creature's non-empty scripts after the given one, or nil when it is not in the stack
-- (or the stack cannot be read).
function M.below(g,object,script)
    local names=M.scripts(g,object)
    if not names then return nil end
    for i,name in ipairs(names) do
        if name==script then
            local rest={}
            for j=i+1,#names do
                if names[j]~='' and names[j]~='none' then rest[#rest+1]=names[j] end
            end
            return rest
        end
    end
end
-- How many creatures' records of the engine's own actions are kept at most.
M.ownLimit=1024
-- The action numbers in the creature's queue, in order.
function M.queued(g,object)
    local ids={}
    g.EEex_Utility_IterateCPtrList(object.m_queuedActions,function(action) ids[#ids+1]=action.m_actionID end)
    return ids
end
-- The creature's non-empty scripts from the top slot down, or nil when the stack cannot be read.
function M.stack(g,object)
    local names=M.scripts(g,object)
    if not names then return nil end
    local list={}
    for _,name in ipairs(names) do
        if name~='' and name~='none' then list[#list+1]=name end
    end
    return list
end
function M.install(g,options)
    options=options or {}
    local settings=M.settings(g)
    local clock=options.now or function() return M.gameTime(g) end
    local director,choice,prepare,held=options.director,options.choice,options.prepare,options.held
    local replaced=options.replaced
    -- id -> the block that queued the hook's last response (sn, rs, rn) and the actions it queued;
    -- owned counts them (at most M.ownLimit: creatures that died with a record keep it until then).
    local mine,owned={},0
    local replacing={count=0,errors=0}
    local function drop(id) if mine[id]~=nil then mine[id]=nil;owned=owned-1 end end
    -- Right after the hook's response queued a decision: when those actions are all the creature
    -- has queued and a block of a script queued them, they are the engine's own.
    local function remember(object,before)
        local ok,own=pcall(function()
            local rs=object.m_curResponseSetNum
            if before~=0 or type(rs)~='number' or rs<0 then return nil end
            local ids=M.queued(g,object)
            if #ids==0 then return nil end
            return {sn=object.m_curScriptNum,rs=rs,rn=object.m_curResponseNum,ids=ids}
        end)
        local id=object.m_id
        drop(id)
        if ok and own then
            if owned>=M.ownLimit then mine,owned={},0 end
            mine[id]=own;owned=owned+1
        end
    end
    -- A claim of kind 'decision' or 'idle': the engine's own actions, while they run as the hook's
    -- last response queued them, give way to it.
    local function release(object,kind)
        local ok=pcall(function()
            local id=object.m_id
            local own=mine[id]
            if not own then return end
            if object.m_curScriptNum~=own.sn or object.m_curResponseSetNum~=own.rs or object.m_curResponseNum~=own.rn then
                drop(id);return
            end
            local current=object.m_curAction.m_actionID
            local left={}
            if current~=0 then left[1]=current end
            for _,action in ipairs(M.queued(g,object)) do left[#left+1]=action end
            if #left==0 or #left>#own.ids then return end
            local skip=#own.ids-#left
            for i,action in ipairs(left) do
                if action~=own.ids[skip+i] then return end
            end
            object.m_curResponseSetNum=-1
            drop(id)
            replacing.count=replacing.count+1
            if replaced then pcall(replaced,object,{kind=kind,action=current,left=#left}) end
        end)
        if not ok then replacing.errors=replacing.errors+1 end
    end
    local gate=hook.new({
        now=clock,
        observe=director and function(view,family) director:observe(view,family) end,
        enabled=settings.enabled,families=settings.families,
        backoffTicks=options.backoffTicks,maxDecisionAgeTicks=options.maxDecisionAgeTicks,
        decide=options.decide,
        hooked=options.hooked,
        below=function(id,script)
            local object=sprite(g,id)
            if object then return M.below(g,object,script) end
        end,
        stack=function(id)
            local object=sprite(g,id)
            if object then return M.stack(g,object) end
        end,
        perform=function(a,decision)
            local object=sprite(g,a.id)
            if not object or type(decision.response)~='string' or #decision.response==0 then return false end
            if prepare then
                local ready=prepare(object,decision)
                if ready=='skipped' then return 'skipped' end
                if ready~=true then return false end
            end
            local counted,before=pcall(function() return object.m_queuedActions.m_nCount end)
            g.EEex_Action_QueueResponseStringOnAIBase(decision.response,object)
            if counted then remember(object,before) end
            return true
        end,
        held=held and function(a,decision,family)
            local object=sprite(g,a.id)
            if object then return held(object,decision,family) end
        end,
    })
    local previous=rawget(g,'BGSE')
    local root={gate=gate,version=options.version or 'dev',director=director,choice=choice,
        listening=type(previous)=='table' and previous.listening or false,
        watching=type(previous)=='table' and previous.watching or false}
    -- Game time for helpers, or nil when it cannot be read.
    function root.now()
        local ok,tick=pcall(clock)
        if ok and type(tick)=='number' then return tick end
    end
    function root.setEnabled(value,persist)
        gate:setEnabled(value);if persist then store(g,'Enabled',value) end
    end
    function root.setFamily(family,value,persist)
        gate:setFamily(family,value);if persist then store(g,M.keys[family],value) end
    end
    -- The engine's own choice on or off (Baldur.lua [BGSE] Choice); off leaves the rounds to
    -- SCS, with the director's advice.
    function root.setChoice(value,persist)
        if choice then choice:setEnabled(value) end
        if persist then store(g,'Choice',value) end
    end
    -- Experiments install a decider here: function(actor, family) -> nil | {response=...} | {hold=true}.
    function root.setDecider(fn) gate:setDecider(fn) end
    function root.inspect()
        local state=gate:inspect()
        state.replaced={count=replacing.count,errors=replacing.errors}
        if director then state.director=director:inspect() end
        if choice then state.choice=choice:inspect() end
        return state
    end
    -- A load forgets which actions were the engine's own: object ids do not outlive the session.
    function root.forget() mine,owned={},0 end
    g.BGSE=root
    local registered=options.hooked~=nil
    local function register()
        if not registered then
            local list=rawget(g,'BGSE_HOOKED')
            if type(list)=='table' then gate:setHooked(list);registered=true end
        end
    end
    -- Only a claim that names a decision or an idle hold makes the engine's own running actions give
    -- way: a hold, or a claim whose kind went missing (lab batch J's wrapper around the gate passed
    -- on its first answer only), leaves them running.
    g.BGSE_Claim=function(object,family,script)
        local ok,result,kind=pcall(function()
            register()
            return gate:claim(actor(object,script),family)
        end)
        if ok and result==true and (kind=='decision' or kind=='idle') then release(object,kind) end
        return ok and result==true
    end
    -- True while the engine weighs danger zones for the creature: its gate would ask the engine
    -- from the script that decides for it (gate:driver) and the choice weighs zones for it now as
    -- that script's family (choice:zones). Any error is false, so SCS's cloud escape runs.
    g.BGSE_Zones=function(object,family,script)
        local ok,result=pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            return choice~=nil and driver~=nil and choice:zones(driver,a.id)==true
        end)
        return ok and result==true
    end
    -- True for every creature the engine drives and searches for (gate:driver, choice:searches):
    -- SCS's own hunting blocks (its chase after the first party member it saw, its free detection
    -- casts, its door search) stand aside, and the engine alone searches. Any error is false.
    g.BGSE_Search=function(object,family,script)
        local ok,result=pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            return choice~=nil and driver~=nil and choice:searches(driver,a.id)==true
        end)
        return ok and result==true
    end
    -- True for every creature the engine drives (gate:driver) and hides its own way (choice:hides,
    -- by the kind of SCS's free invisibility asking: 'plain' or 'improved'): that block of SCS's
    -- stands aside, and the thief hides by its own skill. Any error is false, so SCS's block runs.
    g.BGSE_Hide=function(object,family,script,kind)
        local ok,result=pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            return choice~=nil and driver~=nil and choice:hides(driver,a.id,kind)==true
        end)
        return ok and result==true
    end
    -- True for SCS's preparation the engine holds back for a creature it drives (gate:driver,
    -- choice:holdsPrep): its first-round casts, and what the creature's orders hold back. Any error is
    -- false, so SCS's block runs.
    g.BGSE_Prep=function(object,family,script,kind,cast,spent)
        local ok,result=pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            return choice~=nil and driver~=nil and choice:holdsPrep(driver,a.id,kind,cast,spent)==true
        end)
        return ok and result==true
    end
    -- True for every creature the engine drives and keeps in the fight (gate:driver, choice:stays): SCS's
    -- vanishing exits stand aside unless the creature's orders let it leave. Any error is false, so SCS's
    -- block runs.
    g.BGSE_Stay=function(object,family,script)
        local ok,result=pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            return choice~=nil and driver~=nil and choice:stays(driver,a.id)==true
        end)
        return ok and result==true
    end
    -- True while the engine holds a talk-on-sight creature's talk to prepare it first (choice:talkHold,
    -- combat-intent/talk.lua): SCS's talk-on-sight blocks wait meanwhile. The gate's switch off or any
    -- error is false, so the talk goes on as before.
    g.BGSE_TalkHold=function(object,family,script)
        local ok,result=pcall(function()
            return choice~=nil and gate:on()==true and choice:talkHold(object.m_id)==true
        end)
        return ok and result==true
    end
    -- True once for a talk-on-sight creature whose preparation the fight's designer adds to, after SCS's
    -- had its pass (choice:talkExtras): the engine's block before the talk fires, and its response
    -- (BGSE_TalkAct) queues those actions. The gate's switch off or any error is false.
    g.BGSE_TalkExtras=function(object,family,script)
        local ok,result=pcall(function()
            return choice~=nil and gate:on()==true and choice:talkExtras(object.m_id)==true
        end)
        return ok and result==true
    end
    g.BGSE_TalkAct=function(object)
        pcall(function() if choice then choice:talkAct(object.m_id) end end)
    end
    -- SCS's preparation ran for the creature (choice:prepped logs it for a creature the engine drives).
    g.BGSE_Prepped=function(object,family,script,kind,cast,spent)
        pcall(function()
            register()
            local a=actor(object,script)
            local driver=gate:driver(a)
            if choice~=nil and driver~=nil then choice:prepped(driver,a.id,kind,cast,spent) end
        end)
    end
    -- The response replaces whatever the last one queued: the actions it queues now, if any, are
    -- the engine's own from here on.
    g.BGSE_Act=function(object)
        pcall(function()
            drop(object.m_id)
            gate:act(actor(object))
        end)
    end
    -- Engine state is session-local: a load or a return to the menu forgets every claim.
    -- One listener serves every reinstall; it always reaches the current root.
    if not root.listening and type(rawget(g,'EEex_GameState_AddDestroyedListener'))=='function' then
        g.EEex_GameState_AddDestroyedListener(function()
            local current=rawget(g,'BGSE')
            if type(current)=='table' and current.gate then current.gate:invalidate() end
            if type(current)=='table' and type(current.forget)=='function' then pcall(current.forget) end
            if type(current)=='table' and current.director then pcall(current.director.invalidate,current.director) end
            if type(current)=='table' and current.choice then pcall(current.choice.invalidate,current.choice) end
        end)
        root.listening=true
    end
    -- Every sprite's action start reaches the current director; EEex keeps listeners for the
    -- whole session, so this one is added once and finds the current root each time.
    if director and not root.watching and type(rawget(g,'EEex_Action_AddSpriteStartedActionListener'))=='function' then
        g.EEex_Action_AddSpriteStartedActionListener(function(sprite,action)
            local current=rawget(g,'BGSE')
            if type(current)=='table' and current.director then current.director:onStarted(sprite,action) end
        end)
        root.watching=true
    end
    if director then director:attach(root) end
    if choice then choice:attach(root) end
    return root
end
return M
