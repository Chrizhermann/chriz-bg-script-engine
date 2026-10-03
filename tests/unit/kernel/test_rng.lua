-- Park-Miller replay and bounded integer draws without global randomness.
local rng = assert(loadfile(...))()
local function rejects(fn)
    assert(not pcall(fn))
end

-- 1. Pinned first states and exact whole-generator range replay.
local generator = rng.new(1)
assert(generator:state() == 1)
for _, expected in ipairs({16807, 282475249, 1622650073}) do
    assert(generator:nextInt(1, 2147483646) == expected)
    assert(generator:state() == expected)
end

-- 2. Interleaving other streams cannot alter replay.
local a, b, reference = rng.new(73), rng.new(73), rng.new(73)
local a1, b1 = a:nextInt(-20, 20), b:nextInt(-20, 20)
assert(a1 == b1 and a1 == reference:nextInt(-20, 20))
local a2 = a:nextInt(-20, 20)
assert(b:nextInt(-20, 20) == a2 and reference:nextInt(-20, 20) == a2)
assert(a:state() == b:state())

-- 3. Closed ranges include singleton, zero, and negative endpoints.
local bounds = rng.new(2147483646)
assert(bounds:nextInt(-5, -5) == -5)
for _ = 1, 30 do
    local value = bounds:nextInt(-7, 3)
    assert(value >= -7 and value <= 3 and value == math.floor(value))
end

-- 4. Invalid seeds/ranges fail without advancing the state.
for _, seed in ipairs({0, -1, 1.5, 2147483647, math.huge, 0/0, '1'}) do
    rejects(function() rng.new(seed) end)
end
rejects(function() rng.new() end)
local unchanged = rng.new(42)
for _, pair in ipairs({{2, 1}, {0, 2147483646}, {0.5, 2}, {0, math.huge}, {'0', 1}}) do
    rejects(function() unchanged:nextInt(pair[1], pair[2]) end)
    assert(unchanged:state() == 42)
end
rejects(function() unchanged:nextInt(1) end)

-- 5. Rejection sampling discards an out-of-band draw, and ambient RNG is unused.
local oldRandom, oldSeed = math.random, math.randomseed
math.random = function() error('ambient RNG used') end
math.randomseed = function() error('ambient RNG seed used') end
local sampled = rng.new(1)
sampled:nextInt(0, 2147483645)
sampled:nextInt(0, 2147483645)
-- Third raw state is 1622650073, above the accepted band for width 2^30.
-- The fourth state, 984943658, must be consumed instead.
assert(sampled:nextInt(0, 1073741823) == 984943657)
assert(sampled:state() == 984943658)
math.random, math.randomseed = oldRandom, oldSeed
return 5
