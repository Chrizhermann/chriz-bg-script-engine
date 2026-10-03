-- Deterministic injected ticks, with no dependency on host or game clocks.
local clock = assert(loadfile(...))()
local function rejects(fn)
    assert(not pcall(fn))
end

-- 1. The injected source is read only on demand; repeated ticks are valid.
local tick = 0
local reads = 0
local c = clock.new(function() reads = reads + 1; return tick end)
assert(reads == 0)
assert(c:now() == 0 and c:now() == 0 and reads == 2)
tick = 15
assert(c:now() == 15 and reads == 3)

-- 2. A backward jump fails and cannot move the accepted watermark.
tick = 14
rejects(function() c:now() end)
tick = 15
assert(c:now() == 15)
tick = 16
assert(c:now() == 16)

-- 3. Invalid readings and missing source fail, including non-finite values.
rejects(function() clock.new() end)
rejects(function() clock.new(3) end)
for _, bad in ipairs({-1, 1.5, math.huge, -math.huge, 0/0, '3', false}) do
    local source = clock.new(function() return bad end)
    rejects(function() source:now() end)
end

-- 4. Instance watermarks are separate even with different tick origins.
local first = clock.new(function() return 100 end)
local second = clock.new(function() return 2 end)
assert(first:now() == 100 and second:now() == 2)

-- 5. Ambient clocks are never consulted.
local oldClock, oldTime, oldDate = os.clock, os.time, os.date
os.clock = function() error('ambient clock used') end
os.time = function() error('ambient time used') end
os.date = function() error('ambient date used') end
assert(c:now() == 16)
os.clock, os.time, os.date = oldClock, oldTime, oldDate
return 5
