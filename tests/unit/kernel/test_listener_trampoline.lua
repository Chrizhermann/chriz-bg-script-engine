-- Seven focused scenarios, no game code or native calls.
local path = ...
local load = function() return assert(loadfile(path))() end
local M = load()
local state, listeners, registrations, seen = {}, {}, 0, 0
local register = { event=function(fn) registrations=registrations+1; listeners[1]=fn end }
for version=1,100 do
    M = load()
    M.attach(state, register, {event=function(value) seen=version+value end}, function() return true end)
end
listeners[1](7)
assert(registrations==1 and seen==107 and state.generation==100)

-- A synchronous initialized callback sees the already installed implementation.
local immediate={}
M.attach(immediate,{init=function(fn) fn() end},{init=function() seen=19 end},function() return true end)
assert(seen==19 and immediate.registrations.init==1)

-- Capability loss must not touch the passed actor or run its old handler; stays disabled.
local available=true
M.attach(state,register,{event=function() error('must not run') end},function() return available end)
available=false
listeners[1](setmetatable({}, {__index=function() error('actor dereferenced') end}))
assert(state.disabled=='capability-lost' and state.failures==1)
available=true
listeners[1]()
assert(state.failures==1)

-- A Lua boundary error is contained once; no repeated failing work.
local failing, callback={},nil
M.attach(failing,{event=function(fn) callback=fn end},{event=function() error('fixture-fault') end},function() return true end)
assert(pcall(callback))
assert(failing.disabled=='callback:event' and failing.failures==1)
callback()
assert(failing.failures==1)

-- Registration may append then fail: never retry it or enable its uncertain callback.
local partial, attempts, uncertain={},0,nil
local bad={event=function(fn) attempts=attempts+1; uncertain=fn; error('after-append') end}
M.attach(partial,bad,{event=function() error('inactive') end},function() return true end)
M.attach(partial,bad,{event=function() error('inactive') end},function() return true end)
assert(attempts==1 and partial.disabled=='registration:event')
assert(pcall(uncertain))

-- Unrelated root fields survive; callback parameters aren't stored after dispatch.
local isolated={unrelated='keep'}
local captured
M.attach(isolated,{event=function(fn) captured=fn end},{event=function(...) assert(select('#',...)==3) end},function() return true end)
captured('a',nil,nil)
assert(isolated.unrelated=='keep' and isolated.args==nil)
-- Boot refuses occupied roots and never dereferences a sprite during its load callback.
local fake = {EEex_Active=true}
local hooks = {}
for _, event in ipairs({'Initialized','Destroyed'}) do
    fake['EEex_GameState_Add'..event..'Listener']=function(fn) hooks[event]=fn end
end
fake.EEex_Sprite_AddLoadedListener=function(fn) hooks.Loaded=fn end
fake.EEex_Sprite_GetName=function() error('name not safe during load') end
fake.EEex_Sprite_GetInPortrait=function() error('party not ready') end
fake.Infinity_IsMenuOnStack=function() return false end
fake.Infinity_GetTransitionInProgress=function() return false end
local occupied={other='untouched'}
fake['B-']=occupied
assert(M.boot(fake)==nil and fake['B-']==occupied and next(hooks)==nil)
fake['B-']=nil
local booted=assert(M.boot(fake))
hooks.Loaded({})
assert(not booted.disabled and booted.loadedAll==1)
booted.sample() -- off-world: no actor lookup
assert(not booted.disabled)
fake.EEex_Sprite_GetName=nil
hooks.Loaded({})
assert(booted.disabled=='capability-lost' and booted.loadedAll==1)
return 7
