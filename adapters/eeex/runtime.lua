-- The installed runtime: the BCS handoff gate with the fight director attached. Without the
-- director (it failed to start) the gate still installs and SCS runs as before.
local hook=require('adapters.eeex.hook')
local director=require('adapters.eeex.director')
local M={}
function M.install(g,options)
    options=options or {}
    if options.director==nil then
        local ok,value=pcall(director.new,g)
        if ok then options.director=value end
    end
    return hook.install(g,options)
end
return M
