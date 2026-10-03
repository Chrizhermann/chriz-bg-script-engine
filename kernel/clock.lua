-- Host-supplied monotonic ticks. This module never reads an ambient clock.
local M = {}

local function validTick(value)
    return type(value) == 'number' and value == value and
        value >= 0 and value < math.huge and value == math.floor(value)
end

function M.new(readTicks)
    assert(type(readTicks) == 'function', 'readTicks must be a function')
    local previous
    return {
        now = function()
            local tick = readTicks()
            assert(validTick(tick), 'tick must be a finite nonnegative integer')
            assert(previous == nil or tick >= previous, 'clock moved backwards')
            previous = tick
            return tick
        end,
    }
end

return M
