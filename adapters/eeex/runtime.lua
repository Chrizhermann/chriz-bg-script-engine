-- The installed runtime: the BCS handoff gate with the fight director and the engine's own
-- choice attached. Without the director or the choice (either failed to start) the gate still
-- installs, and SCS runs its rounds as before. The choice follows Baldur.lua's [BGSE] Choice
-- (on unless 0) and takes the designed encounters' orders (combat-intent/encounters.lua).
local hook=require('adapters.eeex.hook')
local director=require('adapters.eeex.director')
local choice=require('adapters.eeex.choice')
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
            prebuffs=hook.ini(g,'Prebuffs')~=0,orders=encounters.orders()})
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
    return hook.install(g,options)
end
return M
