-- EEex side of the BCS handoff. A hook block's trigger calls BGSE_Claim(object, family, script)
-- and its response calls BGSE_Act(object); guarded copies of SCS blocks above the hook call
-- BGSE_Claim too. script is the hooked script's own resref, written in at install time. SCS's own
-- cloud blocks above the hook (escapes, runs from a marker, stand-still) ask
-- BGSE_Zones(object, family, script) last and stand aside while it is true: the engine weighs
-- danger zones for the creature (D3e). SCS's hunting blocks ask BGSE_Search(object, family,
-- script) the same way: the engine searches for every creature it drives. Both go by the script
-- that decides for the creature (kernel/hook.lua, driver), which for a creature with two hooked
-- scripts is the higher one, also in the lower one's blocks.
-- Switches live in the player's Baldur.lua under [BGSE] (Enabled, Mages, Priests, Fighters,
-- Monsters; all on unless set to 0). The install also writes M_BGSEHK.lua, which sets
-- BGSE_HOOKED (hooked script -> family); the gate reads it on first use. Errors never escape
-- into the creature's script: a failure is a decline, and the script's own blocks run on.
-- options.director (adapters/eeex/director.lua) gets the gate's check-ins and EEex's
-- started-action events; it acts only while the gate is on for the creature's family.
-- options.choice (adapters/eeex/choice.lua) is the engine's own choice; options.prepare runs
-- right before a decision's response is queued and may skip it ('skipped'): a target gone by
-- then is no error. options.held(object, decision) runs when the hook's response holds instead.
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
            g.EEex_Action_QueueResponseStringOnAIBase(decision.response,object)
            return true
        end,
        held=held and function(a,decision)
            local object=sprite(g,a.id)
            if object then held(object,decision) end
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
        if director then state.director=director:inspect() end
        if choice then state.choice=choice:inspect() end
        return state
    end
    g.BGSE=root
    local registered=options.hooked~=nil
    local function register()
        if not registered then
            local list=rawget(g,'BGSE_HOOKED')
            if type(list)=='table' then gate:setHooked(list);registered=true end
        end
    end
    g.BGSE_Claim=function(object,family,script)
        local ok,result=pcall(function()
            register()
            return gate:claim(actor(object,script),family)
        end)
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
            return choice~=nil and driver~=nil and choice:searches(driver)==true
        end)
        return ok and result==true
    end
    g.BGSE_Act=function(object)
        pcall(function() gate:act(actor(object)) end)
    end
    -- Engine state is session-local: a load or a return to the menu forgets every claim.
    -- One listener serves every reinstall; it always reaches the current root.
    if not root.listening and type(rawget(g,'EEex_GameState_AddDestroyedListener'))=='function' then
        g.EEex_GameState_AddDestroyedListener(function()
            local current=rawget(g,'BGSE')
            if type(current)=='table' and current.gate then current.gate:invalidate() end
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
