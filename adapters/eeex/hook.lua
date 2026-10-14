-- EEex side of the BCS handoff. A hook block's trigger calls BGSE_Claim(object, family) and
-- its response calls BGSE_Act(object); guarded copies of SCS blocks above the hook call
-- BGSE_Claim too. Switches live in the player's Baldur.lua under [BGSE] (Enabled, Mages,
-- Priests, Fighters, Monsters; all on unless set to 0). Errors never escape into the
-- creature's script: a failure is a decline, and the script's own blocks run on.
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
local function actor(object) return {id=object.m_id} end
local function sprite(g,id)
    local object=g.EEex_GameObject_Get(id)
    if object and g.EEex_GameObject_IsSprite(object,false) then return object end
end
function M.install(g,options)
    options=options or {}
    local settings=M.settings(g)
    local gate=hook.new({
        now=options.now or function() return M.gameTime(g) end,
        enabled=settings.enabled,families=settings.families,
        backoffTicks=options.backoffTicks,maxDecisionAgeTicks=options.maxDecisionAgeTicks,
        decide=options.decide,
        perform=function(a,decision)
            local object=sprite(g,a.id)
            if not object or type(decision.response)~='string' or #decision.response==0 then return false end
            g.EEex_Action_QueueResponseStringOnAIBase(decision.response,object)
            return true
        end,
    })
    local previous=rawget(g,'BGSE')
    local root={gate=gate,version=options.version or 'dev',
        listening=type(previous)=='table' and previous.listening or false}
    function root.setEnabled(value,persist)
        gate:setEnabled(value);if persist then store(g,'Enabled',value) end
    end
    function root.setFamily(family,value,persist)
        gate:setFamily(family,value);if persist then store(g,M.keys[family],value) end
    end
    -- Experiments install a decider here: function(actor, family) -> nil | {response=...} | {hold=true}.
    function root.setDecider(fn) gate:setDecider(fn) end
    function root.inspect() return gate:inspect() end
    g.BGSE=root
    g.BGSE_Claim=function(object,family)
        local ok,result=pcall(function() return gate:claim(actor(object),family) end)
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
        end)
        root.listening=true
    end
    return root
end
return M
