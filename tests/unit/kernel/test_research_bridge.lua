local source = ...
local module = assert(loadfile(source))()
local capability = true
local bridge = module.new(function() return capability end)
assert(bridge.claim(17) == false)
bridge.arm(17, 'allow')
assert(bridge.claim(18) == false)
assert(bridge.claim(17) == true)
assert(bridge.claim(17) == false, 'same case may not grant twice')
assert(bridge.note(18) == false)
assert(bridge.note(17) == true)
assert(bridge.note(17) == false, 'action note may not repeat')
local accepted = bridge.snapshot()
assert(accepted.accepted and accepted.noted)
accepted.events[1].event = 'tampered'
assert(bridge.snapshot().events[1].event ~= 'tampered')

bridge.arm(17, 'decline')
assert(bridge.claim(17) == false and bridge.note(17) == false)
bridge.arm(17, 'error')
assert(bridge.claim(17) == false)
assert(bridge.snapshot().reason == 'policy-error')
assert(bridge.note(17) == false)

bridge.arm(17, 'allow')
capability = false
assert(bridge.claim(17) == false and bridge.note(17) == false)
assert(bridge.snapshot().reason == 'capability-missing')
capability = true
assert(bridge.claim(17) == false, 'capability recovery must not re-arm a consumed case')
bridge.arm(17, 'allow')
assert(bridge.claim(17) == true)
bridge.disable()
assert(bridge.claim(17) == false and bridge.note(17) == false)
assert(bridge.snapshot().actorId == nil)

local broken = module.new(function() error('private detail must not enter trace') end)
broken.arm(17, 'allow')
assert(broken.claim(17) == false)
assert(broken.snapshot().reason == 'capability-error')
for _ = 1, 80 do bridge.claim(17) end
local bounded = bridge.snapshot()
assert(#bounded.events <= 32 and bounded.eventCount >= 80)
assert(not pcall(bridge.arm, {}, 'allow'))
assert(not pcall(bridge.arm, 17, 'invented-policy'))
return true
