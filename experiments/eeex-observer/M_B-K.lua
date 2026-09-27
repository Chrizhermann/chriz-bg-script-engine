-- Synthetic Task8 bootstrap; not a production kernel or an activation path.
if type(loadfile) ~= 'function' then return end
local module, reason = loadfile('override/B-XOBS00.lua')
if not module then return end -- absent companion declines; never writes game state
local ok, observer = pcall(module)
if ok and type(observer) == 'table' and type(observer.boot) == 'function' then
    pcall(observer.boot, _G) -- Lua loader errors decline; runtime proof checks actual state
end
