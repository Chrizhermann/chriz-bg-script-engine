-- Pure Fog-of-War respawn governance policy (Christopher, 2026-11-28).
-- Primary lever: minimum distance to any living party member (no off-screen spawns right behind
-- the party). Secondary lever: area-tier cooldown (no wave cap - preserves infinite dungeon nests).
-- Pure scalar Lua; no engine/EEex calls.
local M = {}

M.SIGHT_RANGE = 448
M.FIRE_RADIUS = 192
M.DEFAULT_MIN_DIST = 1100
M.FLOOR_MIN_DIST = 640
M.HOLD_COUNTDOWN = 150
M.RELEASE_COUNTDOWN = 30
M.DISABLE_MAX_COUNTDOWN = 90
M.DENSE_SPAWN_COUNT = 6

M.COOLDOWNS = {
    infested = 900,    -- 1 turn / 10 rounds (60s * 15 ticks/s)
    dungeon = 9000,    -- 2 in-game hours (600s * 15 ticks/s)
    wilderness = 54000 -- 12 in-game hours (3600s * 15 ticks/s)
}

M.INFESTED = {
    BG5201 = true,
    BG3901 = true,
    BG5100 = true,
    BG2100 = true,
    BG0123 = true,
    BG0224 = true,
    BG0225 = true,
    BG0226 = true,
    AR0202 = true,
    AR0404 = true,
    AR0701 = true,
    AR1201 = true,
    AR1202 = true,
    AR1300 = 'SPRITE_IS_DEADTORGAL',
    AR1302 = 'SPRITE_IS_DEADTORGAL',
    AR1303 = 'SPRITE_IS_DEADTORGAL',
    AR1401 = 'SPRITE_IS_DEADSHADEL',
}

function M.tier(input)
    if type(input) ~= 'table' then return 'dungeon' end
    local area = type(input.area) == 'string' and input.area:upper() or ''
    local entry = M.INFESTED[area]
    if entry == true then
        return 'infested'
    elseif type(entry) == 'string' then
        if input.bossDead ~= true then return 'infested' end
    end
    local outdoor = input.outdoor == true
    local spawnCount = type(input.spawnCount) == 'number' and input.spawnCount or 0
    if not outdoor and spawnCount >= M.DENSE_SPAWN_COUNT then
        return 'infested'
    end
    if outdoor then return 'wilderness' end
    return 'dungeon'
end

function M.cooldownTicks(input)
    return M.COOLDOWNS[M.tier(input)] or M.COOLDOWNS.dungeon
end

function M.minDistance(mapDiag)
    if type(mapDiag) == 'number' and mapDiag > 0 then
        local scaled = math.floor(mapDiag * 0.65)
        if scaled < M.DEFAULT_MIN_DIST then
            return math.max(M.FLOOR_MIN_DIST, scaled)
        end
    end
    return M.DEFAULT_MIN_DIST
end

function M.hasFired(prevCountdown, curCountdown, hadHostileNear)
    if hadHostileNear == true then return true end
    if type(prevCountdown) == 'number' and type(curCountdown) == 'number' then
        if prevCountdown <= 45 and curCountdown > prevCountdown then
            return true
        end
    end
    return false
end

function M.evaluate(input)
    local tick = type(input.tick) == 'number' and math.max(0, math.floor(input.tick)) or 0
    local saved = type(input.saved) == 'number' and math.max(0, math.floor(input.saved)) or 0
    local partyDist = type(input.partyDist) == 'number' and input.partyDist or nil
    local countdown = type(input.countdown) == 'number' and input.countdown or 0
    local wasHeld = input.wasHeld == true
    local fired = input.fired == true
    local cooldown = type(input.cooldown) == 'number' and math.max(1, math.floor(input.cooldown)) or M.COOLDOWNS.dungeon
    local minDist = type(input.minDist) == 'number' and math.max(0, input.minDist) or M.DEFAULT_MIN_DIST

    local function holdResult(newSaved, reason)
        return {
            saved = newSaved,
            hold = true,
            nextCountdown = math.max(countdown, M.HOLD_COUNTDOWN),
            ready = 0,
            reason = reason,
        }
    end

    if saved == 0 then
        if fired or (partyDist ~= nil and partyDist <= M.SIGHT_RANGE) then
            local newSaved = math.max(1, tick + cooldown)
            if partyDist == nil or partyDist < minDist or tick < newSaved then
                return holdResult(newSaved, 'armed')
            end
            return {
                saved = newSaved,
                hold = false,
                nextCountdown = nil,
                ready = 1,
                reason = 'open',
            }
        end
        return {
            saved = 0,
            hold = false,
            nextCountdown = nil,
            ready = nil,
            reason = 'fresh',
        }
    end

    -- Clamp anomalous future target if game clock is unexpectedly far behind saved.
    if tick + 900 < saved and (saved - tick) > cooldown * 2 then
        saved = math.max(1, tick + cooldown)
    end

    if fired and not wasHeld then
        saved = math.max(1, tick + cooldown)
    end

    if partyDist ~= nil and partyDist < minDist then
        return holdResult(saved, 'distance')
    end
    if tick < saved then
        return holdResult(saved, 'cooldown')
    end

    if wasHeld and countdown > M.RELEASE_COUNTDOWN then
        return {
            saved = saved,
            hold = false,
            nextCountdown = M.RELEASE_COUNTDOWN,
            ready = 1,
            reason = 'released',
        }
    end
    return {
        saved = saved,
        hold = false,
        nextCountdown = nil,
        ready = 1,
        reason = 'open',
    }
end

return M
