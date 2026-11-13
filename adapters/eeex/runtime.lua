-- The installed runtime: the BCS handoff gate with the fight director and the engine's own
-- choice attached. Without the director or the choice (either failed to start) the gate still
-- installs, and SCS runs its rounds as before. The choice follows Baldur.lua's [BGSE] Choice
-- (on unless 0) and takes the designed encounters' orders (combat-intent/encounters.lua).
local hook=require('adapters.eeex.hook')
local director=require('adapters.eeex.director')
local choice=require('adapters.eeex.choice')
local ui=require('adapters.eeex.ui')
local arena=require('adapters.eeex.arena')
local encounters=require('combat-intent.encounters')
local M={}
function M.install(g,options)
    options=options or {}
    if options.director==nil then
        local ok,value=pcall(director.new,g,{shouts=hook.ini(g,'Shouts')~=0})
        if ok then options.director=value end
    end
    if options.choice==nil then
        local ok,value=pcall(choice.new,g,{director=options.director,enabled=hook.ini(g,'Choice')~=0,
            prebuffs=hook.ini(g,'Prebuffs')~=0,contingencies=hook.ini(g,'Contingencies')~=0,
            defensiveContingencies=hook.ini(g,'DefensiveContingencies',0)==1,
            shouts=hook.ini(g,'Shouts')~=0,orders=encounters.orders()})
        if ok then options.choice=value end
    end
    local own=options.choice
    if own then
        if options.decide==nil then options.decide=function(view,family) return own:decide(view,family) end end
        if options.prepare==nil then options.prepare=function(object,decision) return own:prepare(object,decision) end end
        if options.held==nil then options.held=function(object,decision,family) return own:held(object,decision,family) end end
        if options.replaced==nil then options.replaced=function(object,info) return own:replaced(object,info) end end
        if options.director then options.director:setChoice(own) end
    end
    local challengeOn=hook.ini(g,'ChallengeMode',0)==1
    local challengeDefault=challengeOn and 1 or 0
    local uiInstance=options.ui
    if uiInstance==nil then
        local ok,value=pcall(ui.new,g,{playerDefensiveContingencies=hook.ini(g,'PlayerDefensiveContingencies',challengeDefault)==1})
        if ok then uiInstance=value end
    end
    local rootRef=nil
    local arenaInstance=options.arena
    if arenaInstance==nil then
        local ok,value=pcall(arena.new,g,{enabled=hook.ini(g,'ArenaLocks',challengeDefault)==1,
            locks=encounters.arenaLocks(),hookDestroyed=true,
            isEnabled=function() return rootRef~=nil and rootRef.gate~=nil and rootRef.gate:on()==true end})
        if ok then arenaInstance=value end
    end
    local root=hook.install(g,options)
    rootRef=root
    root.ui=uiInstance
    root.arena=arenaInstance
    function root.setDefensiveContingencies(value,persist)
        if own then own:setDefensiveContingencies(value) end
        if persist then hook.store(g,'DefensiveContingencies',value) end
    end
    function root.setPlayerDefensiveContingencies(value,persist)
        if uiInstance then uiInstance:setPlayerDefensiveContingencies(value) end
        if persist then hook.store(g,'PlayerDefensiveContingencies',value) end
    end
    function root.setArenaLocks(value,persist)
        if arenaInstance then arenaInstance:setEnabled(value) end
        if persist then hook.store(g,'ArenaLocks',value) end
    end
    function root.setChallengeMode(value,persist)
        challengeOn=(value==true)
        if uiInstance then uiInstance:setPlayerDefensiveContingencies(challengeOn) end
        if arenaInstance then arenaInstance:setEnabled(challengeOn) end
        if persist then hook.store(g,'ChallengeMode',challengeOn) end
    end
    local baseInspect=root.inspect
    function root.inspect()
        local state=baseInspect()
        state.challengeMode=challengeOn
        if uiInstance then state.ui=uiInstance:inspect() end
        if arenaInstance then state.arena=arenaInstance:inspect() end
        return state
    end
    return root
end
return M
