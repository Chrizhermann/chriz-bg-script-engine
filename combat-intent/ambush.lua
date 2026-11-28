-- Pure ambush-approach and rest-interruption perimeter policy (Christopher, 2026-11-28).
-- No engine/EEex calls; operates on plain scalar tables only.
local M = {}

M.AREAS = {
    BG5600 = true, BG5601 = true,
    BG5700 = true, BG5701 = true,
    BG5800 = true, BG5801 = true,
    BG5900 = true, BG5901 = true,
    BG6000 = true, BG6001 = true,
    BG6100 = true,
    AR0041 = true, AR0042 = true, AR0043 = true,
    AR0044 = true, AR0045 = true, AR0046 = true,
    BD0063 = true,
}

M.EVIL_CUTOFF = 200
M.CHARMED_PC = 254

M.REST_JUMP_TICKS = 4500   -- 1 in-game hour (300s * 15 ticks/s)
M.REST_TOO_CLOSE = 240
M.REST_MIN_DIST = 280
M.REST_MAX_DIST = 420
M.REST_RELAXED_MAX_DIST = 520
M.MIN_SPACING = 56
M.RELAXED_SPACING = 40

local function distSq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

function M.isAmbushArea(area)
    if type(area) ~= 'string' or #area == 0 then return false end
    return M.AREAS[area:upper()] == true
end

function M.shouldApproach(input)
    if type(input) ~= 'table' then return false end
    if input.enabled ~= true then return false end
    if not M.isAmbushArea(input.area) then return false end
    local ea = input.ea
    if type(ea) ~= 'number' or ea < M.EVIL_CUTOFF or ea == M.CHARMED_PC then return false end
    if input.fought ~= nil and input.fought ~= false then return false end
    if input.gaveUp ~= nil and input.gaveUp ~= false then return false end
    return true
end

function M.nearestParty(selfPos, party)
    if type(selfPos) ~= 'table' or type(selfPos.x) ~= 'number' or type(selfPos.y) ~= 'number' then return nil end
    if type(party) ~= 'table' then return nil end
    local best, bestSq = nil, nil
    for _, p in ipairs(party) do
        if type(p) == 'table' and type(p.x) == 'number' and type(p.y) == 'number' and type(p.id) == 'number' then
            local sq = distSq(selfPos, p)
            if not best or sq < bestSq or (sq == bestSq and p.id < best.id) then
                best, bestSq = p, sq
            end
        end
    end
    return best
end

local function minDistSqToList(pt, list)
    local best = nil
    for _, item in ipairs(list) do
        local sq = distSq(pt, item)
        if not best or sq < best then best = sq end
    end
    return best
end

local function centroid(list)
    local sx, sy, n = 0, 0, 0
    for _, item in ipairs(list) do
        if type(item) == 'table' and type(item.x) == 'number' and type(item.y) == 'number' then
            sx = sx + item.x
            sy = sy + item.y
            n = n + 1
        end
    end
    if n == 0 then return nil end
    return {x = sx / n, y = sy / n}
end

local function pickCandidate(hostile, party, placed, candidates, minPartySq, maxPartySq, minSpaceSq, center)
    local hx = (hostile.x or center.x) - center.x
    local hy = (hostile.y or center.y) - center.y
    local best, bestScore = nil, nil
    for _, c in ipairs(candidates) do
        if type(c) == 'table' and type(c.x) == 'number' and type(c.y) == 'number' then
            local pSq = minDistSqToList(c, party)
            if pSq and pSq >= minPartySq and pSq <= maxPartySq then
                local spaceOk = true
                for _, o in ipairs(placed) do
                    if distSq(c, o) < minSpaceSq then
                        spaceOk = false
                        break
                    end
                end
                if spaceOk then
                    local cx = c.x - center.x
                    local cy = c.y - center.y
                    -- Prefer candidates keeping the hostile's general direction from the party centroid
                    local dotPenalty = 0
                    if (hx ~= 0 or hy ~= 0) and (cx ~= 0 or cy ~= 0) then
                        local dot = hx * cx + hy * cy
                        local magSq = (hx * hx + hy * hy) * (cx * cx + cy * cy)
                        if dot <= 0 then
                            dotPenalty = 1e9 - dot
                        else
                            -- Normalized alignment penalty (0 = exact direction, up to 1e6)
                            dotPenalty = math.floor((1 - (dot * dot) / magSq) * 1e6)
                        end
                    end
                    local midSq = ((M.REST_MIN_DIST + M.REST_MAX_DIST) / 2) ^ 2
                    local score = dotPenalty + math.abs(pSq - midSq) * 0.001
                    if not best or score < bestScore or (score == bestScore and (c.x < best.x or (c.x == best.x and c.y < best.y))) then
                        best, bestScore = c, score
                    end
                end
            end
        end
    end
    return best
end

function M.restPerimeter(party, hostiles, candidates)
    local out = {}
    if type(party) ~= 'table' or #party == 0 then return out end
    if type(hostiles) ~= 'table' or #hostiles == 0 then return out end
    if type(candidates) ~= 'table' or #candidates == 0 then return out end
    local center = centroid(party)
    if not center then return out end

    local tooCloseSq = M.REST_TOO_CLOSE * M.REST_TOO_CLOSE
    local toMove, placed = {}, {}
    for _, h in ipairs(hostiles) do
        if type(h) == 'table' and type(h.id) == 'number' and type(h.x) == 'number' and type(h.y) == 'number' then
            local pSq = minDistSqToList(h, party)
            if pSq and pSq < tooCloseSq then
                toMove[#toMove + 1] = h
            else
                placed[#placed + 1] = {x = h.x, y = h.y}
            end
        end
    end
    if #toMove == 0 then return out end
    table.sort(toMove, function(a, b) return a.id < b.id end)

    local minSq = M.REST_MIN_DIST * M.REST_MIN_DIST
    local maxSq = M.REST_MAX_DIST * M.REST_MAX_DIST
    local relaxedMaxSq = M.REST_RELAXED_MAX_DIST * M.REST_RELAXED_MAX_DIST
    local spaceSq = M.MIN_SPACING * M.MIN_SPACING
    local relaxedSpaceSq = M.RELAXED_SPACING * M.RELAXED_SPACING

    for _, h in ipairs(toMove) do
        local chosen = pickCandidate(h, party, placed, candidates, minSq, maxSq, spaceSq, center)
            or pickCandidate(h, party, placed, candidates, minSq, relaxedMaxSq, spaceSq, center)
            or pickCandidate(h, party, placed, candidates, minSq, relaxedMaxSq, relaxedSpaceSq, center)
        if chosen then
            local pt = {id = h.id, x = math.floor(chosen.x + 0.5), y = math.floor(chosen.y + 0.5)}
            out[#out + 1] = pt
            placed[#placed + 1] = {x = pt.x, y = pt.y}
        end
    end
    return out
end

return M
