-- Independent Park-Miller streams for reproducible host simulations.
local M = {}
local MODULUS = 2147483647
local MULTIPLIER = 16807
local SAMPLE_COUNT = MODULUS - 1
local MAX_EXACT_INTEGER = 9007199254740991

local function integer(value)
    return type(value) == 'number' and value == value and
        value < math.huge and value > -math.huge and
        value == math.floor(value) and
        value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER
end

function M.new(seed)
    assert(integer(seed) and seed >= 1 and seed < MODULUS,
        'seed must be an integer from 1 to 2147483646')
    local current = seed
    return {
        state = function()
            return current
        end,
        nextInt = function(_, minimum, maximum)
            assert(integer(minimum) and integer(maximum) and minimum <= maximum,
                'range endpoints must be ordered exact integers')
            local width = maximum - minimum + 1
            assert(width >= 1 and width <= SAMPLE_COUNT,
                'range width exceeds generator sample count')

            local accepted = math.floor(SAMPLE_COUNT / width) * width
            local sample
            repeat
                -- The product is < 2^53, so Lua doubles represent it exactly.
                current = (current * MULTIPLIER) % MODULUS
                sample = current - 1
            until sample < accepted
            return minimum + (sample % width)
        end,
    }
end

return M
