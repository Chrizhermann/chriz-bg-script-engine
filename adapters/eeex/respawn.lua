-- Fog-of-War respawn governance and rest-interruption perimeter (Christopher, 2026-11-28).
--
-- Default-ON whenever [BGSE] Enabled=1 (not gated behind Challenge Mode):
-- - [BGSE] Respawns=1 (default ON): governs CGameSpawning points via minimum party distance
--   (1100 px, scaled on smaller dungeon floors) and area-tier cooldowns (1 turn infested,
--   2 in-game hours dungeon, 12 in-game hours wilderness), without capping waves.
-- - [BGSE] Ambushes=1 (default ON): on in-place rest interruptions (>= 1 game hour jump in
--   the same area), moves hostiles spawned inside melee range (< 240 px) onto open camp
--   perimeter spots (280..420 px) via JumpToPoint + FaceObject.
local hook = require('adapters.eeex.hook')
local ambush = require('combat-intent.ambush')
local respawn = require('combat-intent.respawn')

local M = {}

M.OUTDOOR_BIT = 0x1
M.DEAD_STATE_MASK = 0xFC0
M.HOSTILE_MIN_EA = 200
M.CHARMED_PC_EA = 254
M.SCAN_TICKS = 15
M.META_CACHE_LIMIT = 128

local TICK_MENU = [[
menu
{
    name "BGSE_WORLD_TICK"
    ignoreEsc
    label
    {
        enabled "BGSE_World_Tick()"
    }
}
]]

local function cleanString(raw)
    if type(raw) ~= 'string' then return '' end
    return (raw:match('^[^%z]*') or ''):upper()
end

local function readText(field)
    if field == nil then return '' end
    local ok, raw = pcall(function() return field:get() end)
    if not ok or type(raw) ~= 'string' then
        ok, raw = pcall(function() return field.m_pchData:get() end)
    end
    return ok and cleanString(raw) or ''
end

local function iterateList(g, list, fn)
    if not list then return end
    local iter = rawget(g, 'EEex_Utility_IterateCPtrList')
    if type(iter) == 'function' then
        pcall(iter, list, fn)
        return
    end
    if type(list) == 'table' then
        for _, v in ipairs(list) do fn(v) end
    end
end

local function isAliveSprite(g, sprite)
    if sprite.m_active ~= nil and sprite.m_active == 0 then return false end
    local getState = rawget(g, 'EEex_Sprite_GetState')
    local state = nil
    if type(getState) == 'function' then
        local ok, val = pcall(getState, sprite)
        if ok and type(val) == 'number' then state = val end
    end
    local stats = sprite.m_baseStats
    if type(state) ~= 'number' then state = stats and stats.m_generalState end
    if type(state) ~= 'number' then return false end
    local band = rawget(g, 'EEex_BAnd')
    if type(band) == 'function' then
        if band(state, M.DEAD_STATE_MASK) ~= 0 then return false end
    elseif math.floor(state / 64) % 64 ~= 0 then
        return false
    end
    local hp = stats and stats.m_hitPoints
    if type(hp) ~= 'number' or hp <= 0 then return false end
    return true
end

local function spriteEA(obj)
    local okLive, ea = pcall(function() return obj.m_liveTypeAI.m_EnemyAlly end)
    if okLive and type(ea) == 'number' then return ea end
    local okType, ea2 = pcall(function() return obj.m_typeAI.m_EnemyAlly end)
    if okType and type(ea2) == 'number' then return ea2 end
    return 0
end

local function isSummonedOrClone(obj)
    local okS, sumId = pcall(function() return obj.m_lSummonedBy and obj.m_lSummonedBy.m_Instance end)
    if okS and type(sumId) == 'number' and sumId ~= -1 then return true end
    local okC, copyId = pcall(function() return obj.m_nCopyParent end)
    if okC and type(copyId) == 'number' and copyId ~= -1 then return true end
    return false
end

local function currentArea(g)
    local getArea = rawget(g, 'EEex_Area_GetVisible')
    if type(getArea) == 'function' then
        local okArea, area = pcall(getArea)
        if okArea and area ~= nil then return area end
    end
    local getter = rawget(g, 'EEex_Sprite_GetInPortrait')
    if type(getter) == 'function' then
        for i = 0, 5 do
            local ok, sp = pcall(getter, i)
            if ok and sp then
                local okArea, pArea = pcall(function() return sp.m_pArea end)
                if okArea and pArea ~= nil then return pArea end
            end
        end
    end
    return nil
end

local function partyInArea(g, areaKey)
    local party = {}
    local getter = rawget(g, 'EEex_Sprite_GetInPortrait')
    if type(getter) ~= 'function' then return party end
    for i = 0, 5 do
        local ok, sp = pcall(getter, i)
        if ok and sp and sp.m_pArea and readText(sp.m_pArea.m_resref) == areaKey and isAliveSprite(g, sp) then
            local okPos, x, y = pcall(function() return sp.m_pos.x, sp.m_pos.y end)
            if okPos and type(x) == 'number' and type(y) == 'number' then
                party[#party + 1] = {id = sp.m_id or i, x = x, y = y, sprite = sp}
            end
        end
    end
    return party
end

local function getAreaVar(g, area, name)
    local fn = rawget(g, 'EEex_Area_GetVariableInt')
    if type(fn) ~= 'function' then return 0 end
    local ok, val = pcall(fn, area, name)
    if ok and type(val) == 'number' then return val end
    return 0
end

local function setAreaVar(g, area, name, val)
    local fn = rawget(g, 'EEex_Area_SetVariableInt')
    if type(fn) ~= 'function' then return false end
    local ok = pcall(fn, area, name, val)
    return ok == true
end

local function getGlobalInt(g, name)
    local fn = rawget(g, 'EEex_GameState_GetGlobalInt')
    if type(fn) == 'function' then
        local ok, val = pcall(fn, name)
        if ok and type(val) == 'number' then return val end
    end
    local ok2, val2 = pcall(function()
        return g.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_variables:getInt(name)
    end)
    if ok2 and type(val2) == 'number' then return val2 end
    return 0
end

local function demandResource(g, resref, kind)
    local fetch = rawget(g, 'EEex_Resource_Fetch')
    local toPtr = rawget(g, 'EEex_UDToPtr')
    local u8 = rawget(g, 'EEex_ReadU8')
    if type(fetch) ~= 'function' or type(toPtr) ~= 'function' or type(u8) ~= 'function' then
        return nil
    end
    local ok, base, size = pcall(function()
        local res = fetch(resref, kind)
        if res == nil then return nil end
        local data = res:Demand()
        local ptr = data ~= nil and toPtr(data) or nil
        return ptr, res.nSize
    end)
    if not ok or type(base) ~= 'number' or base <= 0 or type(size) ~= 'number' or size <= 0 then
        return nil
    end
    local u16 = rawget(g, 'EEex_ReadU16') or function(a) return u8(a) + u8(a + 1) * 256 end
    local u32 = rawget(g, 'EEex_ReadU32') or function(a) return u16(a) + u16(a + 2) * 65536 end
    local i32 = rawget(g, 'EEex_Read32') or function(a)
        local v = u32(a)
        return v >= 2147483648 and v - 4294967296 or v
    end
    local strFn = rawget(g, 'EEex_ReadLString') or function(a, n)
        local t = {}
        for i = 0, n - 1 do
            local b = u8(a + i)
            if b == 0 then break end
            t[#t + 1] = string.char(b)
        end
        return table.concat(t)
    end
    return {base = base, size = size, u8 = u8, u16 = u16, u32 = u32, i32 = i32, str = strFn}
end

local function readAreaMeta(g, area, areaKey)
    local outdoor = false
    local wed = areaKey
    local okType, kind = pcall(function() return area.m_header.m_areaType end)
    if not okType or type(kind) ~= 'number' then
        okType, kind = pcall(function() return area.m_header.reference.m_areaType end)
    end
    if okType and type(kind) == 'number' then
        outdoor = (math.floor(kind / M.OUTDOOR_BIT) % 2 == 1)
    end
    local okWed, wedField = pcall(function() return area.m_pResWED or area.m_header.m_resWED end)
    if okWed and wedField ~= nil then
        local w = readText(wedField)
        if w ~= '' then wed = w end
    end
    if not okType or wed == areaKey then
        local v = demandResource(g, areaKey, 'ARE')
        if v and v.size >= 0x4C then
            if not okType then
                local flags = v.u32(v.base + 0x48)
                outdoor = (math.floor(flags / M.OUTDOOR_BIT) % 2 == 1)
            end
            local rw = cleanString(v.str(v.base + 0x08, 8))
            if rw ~= '' then wed = rw end
        end
    end
    local mapDiag = nil
    local sr = demandResource(g, wed .. 'SR', 'BMP')
    if sr and sr.size >= 26 and sr.u8(sr.base) == 0x42 and sr.u8(sr.base + 1) == 0x4D then
        local w = sr.i32(sr.base + 18)
        local h = math.abs(sr.i32(sr.base + 22))
        if w > 0 and h > 0 then
            mapDiag = math.sqrt((w * 16) ^ 2 + (h * 12) ^ 2)
        end
    end
    return {outdoor = outdoor, mapDiag = mapDiag}
end

function M.new(g, options)
    g = g or _G
    options = options or {}
    local respawnsEnabled = options.respawns ~= false
    local ambushesEnabled = options.ambushes ~= false
    local isEngineEnabled = options.isEnabled

    local metaCache, metaCount = {}, 0
    local heldPoints, prevCountdowns = {}, {}
    local knownHostiles = {}
    local lastAreaKey, lastTick = nil, nil
    local lastSpawnArea, lastSpawnTick = nil, nil
    local lastFastMs = nil
    local dirty, checkPending = true, true
    local lastError = false
    local counts = {
        ticks = 0,
        held = 0,
        released = 0,
        armed = 0,
        restJumps = 0,
        restRelocated = 0,
    }

    local function engineOn()
        if type(isEngineEnabled) == 'function' then
            local ok, res = pcall(isEngineEnabled)
            return ok and res == true
        end
        return hook.ini(g, 'Enabled') ~= 0
    end

    local function areaMeta(area, areaKey)
        local cached = metaCache[areaKey]
        if cached then return cached end
        if metaCount >= M.META_CACHE_LIMIT then
            metaCache, metaCount = {}, 0
        end
        local meta = readAreaMeta(g, area, areaKey)
        metaCache[areaKey] = meta
        metaCount = metaCount + 1
        return meta
    end

    local function collectHostiles(area)
        local out, byId, seen = {}, {}, {}
        local getObj = rawget(g, 'EEex_GameObject_Get')
        local isSprite = rawget(g, 'EEex_GameObject_IsSprite')
        if type(getObj) ~= 'function' then return out, byId end
        for _, list in ipairs({area.m_lVertSort, area.m_lVertSortBack}) do
            iterateList(g, list, function(id)
                if type(id) == 'number' and not seen[id] then
                    seen[id] = true
                    local obj = getObj(id)
                    if obj and (type(isSprite) ~= 'function' or isSprite(obj, false)) then
                        local ea = spriteEA(obj)
                        if ea >= M.HOSTILE_MIN_EA and ea ~= M.CHARMED_PC_EA and isAliveSprite(g, obj) then
                            local okPos, x, y = pcall(function() return obj.m_pos.x, obj.m_pos.y end)
                            if okPos and type(x) == 'number' and type(y) == 'number' then
                                local entry = {
                                    id = id,
                                    x = x,
                                    y = y,
                                    summoned = isSummonedOrClone(obj),
                                    sprite = obj,
                                }
                                out[#out + 1] = entry
                                byId[id] = entry
                            end
                        end
                    end
                end
            end)
        end
        return out, byId
    end

    local function collectSpawns(area)
        local out, seen = {}, {}
        local getObj = rawget(g, 'EEex_GameObject_Get')
        local castObj = rawget(g, 'EEex_GameObject_CastUserType')
        local types = rawget(g, 'CGameObjectType')
        local spawnType = type(types) == 'table' and types.SPAWNING or 0x20
        if type(getObj) ~= 'function' then return out end
        local ordinals = {}
        for _, list in ipairs({area.m_lVertSort, area.m_lVertSortBack}) do
            iterateList(g, list, function(id)
                if type(id) == 'number' and not seen[id] then
                    seen[id] = true
                    local obj = getObj(id)
                    if obj and obj.m_objectType == spawnType then
                        local sp = type(castObj) == 'function' and castObj(obj) or obj
                        if sp then
                            local okPos, x, y = pcall(function() return sp.m_pos.x, sp.m_pos.y end)
                            if okPos and type(x) == 'number' and type(y) == 'number' then
                                local ix, iy = math.floor(x + 0.5), math.floor(y + 0.5)
                                local xy = ix .. '_' .. iy
                                ordinals[xy] = (ordinals[xy] or 0) + 1
                                local tag = string.format('BGSE_SP_%d_%d_%d', ix, iy, ordinals[xy])
                                out[#out + 1] = {id = id, x = ix, y = iy, tag = tag, sp = sp}
                            end
                        end
                    end
                end
            end)
        end
        return out
    end

    local function snapCandidates(area, party)
        local sx, sy = 0, 0
        for _, p in ipairs(party) do sx, sy = sx + p.x, sy + p.y end
        local cx, cy = sx / #party, sy / #party
        local openFn = rawget(g, 'EEex_Area_GetNearestOpenPosition')
        local cands, seenPt = {}, {}
        for _, radius in ipairs({300, 350, 400, 460}) do
            for a = 0, 15 do
                local theta = a * (math.pi / 8)
                local px = math.max(16, math.floor(cx + math.cos(theta) * radius + 0.5))
                local py = math.max(12, math.floor(cy + math.sin(theta) * radius + 0.5))
                if type(openFn) == 'function' then
                    local ok, ox, oy = pcall(openFn, area, px, py, 3, nil, -1)
                    if ok and type(ox) == 'number' and type(oy) == 'number' and ox >= 0 and oy >= 0 then
                        px, py = math.floor(ox + 0.5), math.floor(oy + 0.5)
                    end
                end
                local key = px .. ':' .. py
                if not seenPt[key] then
                    seenPt[key] = true
                    cands[#cands + 1] = {x = px, y = py}
                end
            end
        end
        return cands
    end

    local function relocateRestAmbush(area, party, newHostiles)
        local queueFn = rawget(g, 'EEex_Action_QueueResponseStringOnAIBase')
        if type(queueFn) ~= 'function' or #party == 0 then return end
        local candidates = snapCandidates(area, party)
        local moves = ambush.restPerimeter(party, newHostiles, candidates)
        for _, mv in ipairs(moves) do
            local target = nil
            for _, h in ipairs(newHostiles) do
                if h.id == mv.id then target = h; break end
            end
            if target and target.sprite then
                local cmd = string.format('JumpToPoint([%d.%d])\nFaceObject(NearestEnemyOf(Myself))', mv.x, mv.y)
                local ok = pcall(queueFn, cmd, target.sprite)
                if ok then counts.restRelocated = counts.restRelocated + 1 end
            end
        end
    end

    local function minPartyDist(pt, party)
        local best = nil
        for _, p in ipairs(party) do
            local dx, dy = pt.x - p.x, pt.y - p.y
            local d = math.sqrt(dx * dx + dy * dy)
            if not best or d < best then best = d end
        end
        return best
    end

    local function hadNewHostileNear(pt, newlyAppeared)
        local rSq = respawn.FIRE_RADIUS * respawn.FIRE_RADIUS
        for _, h in ipairs(newlyAppeared) do
            if not h.summoned then
                local dx, dy = h.x - pt.x, h.y - pt.y
                if dx * dx + dy * dy <= rSq then return true end
            end
        end
        return false
    end

    local api = {}

    function api:invalidate()
        lastAreaKey, lastTick = nil, nil
        lastSpawnArea, lastSpawnTick = nil, nil
        lastFastMs = nil
        heldPoints, prevCountdowns, knownHostiles = {}, {}, {}
        dirty, checkPending = true, true
    end

    function api:onDestroyed()
        metaCache, metaCount = {}, 0
        api:invalidate()
    end

    function api:step()
        lastError = false
        counts.ticks = counts.ticks + 1
        local area = currentArea(g)
        if not area then return false end
        local areaKey = readText(area.m_resref)
        if areaKey == '' then return false end

        local tick = nil
        local okTime, gt = pcall(hook.gameTime, g)
        if okTime and type(gt) == 'number' then tick = gt end
        if tick == nil then return false end

        local activeEngine = engineOn()
        local sameArea = (areaKey == lastAreaKey)
        local restJump = sameArea and lastTick ~= nil and (tick - lastTick) >= ambush.REST_JUMP_TICKS
        local needSpawnScan = dirty or (areaKey ~= lastSpawnArea) or restJump
            or lastSpawnTick == nil or tick < lastSpawnTick or (tick - lastSpawnTick) >= M.SCAN_TICKS

        if not sameArea then
            heldPoints, prevCountdowns = {}, {}
            knownHostiles = {}
        end

        local hostiles, hostileById = collectHostiles(area)
        local newlyAppeared = {}
        if sameArea then
            for _, h in ipairs(hostiles) do
                if not knownHostiles[h.id] and not h.summoned then
                    newlyAppeared[#newlyAppeared + 1] = h
                end
            end
        end

        local party = nil
        if restJump and ambushesEnabled and activeEngine and #newlyAppeared > 0 then
            counts.restJumps = counts.restJumps + 1
            party = partyInArea(g, areaKey)
            if #party > 0 then
                relocateRestAmbush(area, party, newlyAppeared)
            end
        elseif restJump then
            counts.restJumps = counts.restJumps + 1
        end

        -- Refresh hostile snapshot for this area
        knownHostiles = {}
        for id in pairs(hostileById) do knownHostiles[id] = true end
        lastAreaKey, lastTick = areaKey, tick

        if not needSpawnScan then
            return false
        end
        lastSpawnArea, lastSpawnTick, dirty = areaKey, tick, false

        local spawns = collectSpawns(area)
        if #spawns == 0 then
            checkPending = respawnsEnabled or ambushesEnabled
            return false
        end
        checkPending = true

        if not (respawnsEnabled and activeEngine) then
            for _, item in ipairs(spawns) do
                if heldPoints[item.tag] then
                    local okC, cd = pcall(function() return item.sp.m_countdown end)
                    if okC and type(cd) == 'number' and cd > respawn.DISABLE_MAX_COUNTDOWN then
                        pcall(function() item.sp.m_countdown = respawn.DISABLE_MAX_COUNTDOWN end)
                    end
                    pcall(function() item.sp.bReady = 1 end)
                    heldPoints[item.tag] = nil
                    counts.released = counts.released + 1
                end
            end
            return false
        end

        party = party or partyInArea(g, areaKey)
        local meta = areaMeta(area, areaKey)
        local entry = respawn.INFESTED[areaKey]
        local bossDead = type(entry) == 'string' and getGlobalInt(g, entry) ~= 0 or false
        local cooldown = respawn.cooldownTicks({
            area = areaKey,
            outdoor = meta.outdoor,
            spawnCount = #spawns,
            bossDead = bossDead,
        })
        local minDist = respawn.minDistance(meta.mapDiag)

        for _, item in ipairs(spawns) do
            local sp = item.sp
            local saved = getAreaVar(g, area, item.tag)
            local okC, curCountdown = pcall(function() return sp.m_countdown end)
            if not okC or type(curCountdown) ~= 'number' then curCountdown = 0 end
            local wasHeld = heldPoints[item.tag] == true
            local nearSpawn = sameArea and hadNewHostileNear(item, newlyAppeared)
            local fired = respawn.hasFired(prevCountdowns[item.tag], curCountdown, nearSpawn)
            local pDist = #party > 0 and minPartyDist(item, party) or nil

            local res = respawn.evaluate({
                tick = tick,
                saved = saved,
                partyDist = pDist,
                countdown = curCountdown,
                wasHeld = wasHeld,
                fired = fired,
                cooldown = cooldown,
                minDist = minDist,
            })

            if res.saved ~= saved then
                setAreaVar(g, area, item.tag, res.saved)
            end
            if type(res.nextCountdown) == 'number' then
                pcall(function() sp.m_countdown = res.nextCountdown end)
                prevCountdowns[item.tag] = res.nextCountdown
            else
                prevCountdowns[item.tag] = curCountdown
            end
            if res.ready ~= nil then
                pcall(function() sp.bReady = res.ready end)
            end

            if res.hold then
                if not wasHeld then
                    if res.reason == 'armed' then counts.armed = counts.armed + 1 end
                    counts.held = counts.held + 1
                end
                heldPoints[item.tag] = true
            else
                if wasHeld then counts.released = counts.released + 1 end
                heldPoints[item.tag] = nil
            end
        end
        return false
    end

    function api:guardedStep()
        local ok, res = pcall(api.step, api)
        if not ok then
            lastError = tostring(res)
            return false
        end
        return res == true
    end

    function api:fastStep()
        if not respawnsEnabled and not ambushesEnabled and not dirty and not checkPending then
            return false
        end
        local getTicks = rawget(g, 'Infinity_GetClockTicks')
        if type(getTicks) == 'function' then
            local okMs, nowMs = pcall(getTicks)
            if okMs and type(nowMs) == 'number' then
                if not dirty and lastFastMs ~= nil and nowMs >= lastFastMs and (nowMs - lastFastMs) < 50 then
                    return false
                end
                lastFastMs = nowMs
            end
        end
        return api:guardedStep()
    end

    function api:setRespawnsEnabled(value)
        local nextVal = (value == true)
        if nextVal ~= respawnsEnabled then
            respawnsEnabled = nextVal
            dirty = true
            lastFastMs = nil
            api:guardedStep()
        end
    end

    function api:setAmbushesEnabled(value)
        local nextVal = (value == true)
        if nextVal ~= ambushesEnabled then
            ambushesEnabled = nextVal
            dirty = true
            lastFastMs = nil
        end
    end

    function api:inspect()
        local held = 0
        for _ in pairs(heldPoints) do held = held + 1 end
        return {
            respawns = respawnsEnabled,
            ambushes = ambushesEnabled,
            lastArea = lastAreaKey or false,
            held = held,
            lastError = lastError,
            counts = {
                ticks = counts.ticks,
                held = counts.held,
                released = counts.released,
                armed = counts.armed,
                restJumps = counts.restJumps,
                restRelocated = counts.restRelocated,
            },
        }
    end

    if options.hookListeners ~= false then
        rawset(g, '_bgseWorldApi', api)
        rawset(g, 'BGSE_World_Tick', function()
            local current = rawget(g, '_bgseWorldApi')
            if type(current) == 'table' and type(current.fastStep) == 'function' then
                return current:fastStep()
            end
            return false
        end)

        local function pushMenu()
            local push = rawget(g, 'Infinity_PushMenu')
            if rawget(g, '_bgseWorldMenuLoaded') == true and rawget(g, '_bgseWorldInitSeen') == true and type(push) == 'function' then
                pcall(push, 'BGSE_WORLD_TICK')
            end
        end

        local addMenu = rawget(g, 'EEex_Menu_AddAfterMainFileLoadedListener')
        if type(addMenu) == 'function' and not rawget(g, '_bgseWorldMenuListener') then
            rawset(g, '_bgseWorldMenuListener', true)
            pcall(addMenu, function()
                local eval = rawget(g, 'EEex_Menu_Eval')
                if type(eval) == 'function' then pcall(eval, TICK_MENU) end
                rawset(g, '_bgseWorldMenuLoaded', true)
                pushMenu()
            end)
        end

        local addReload = rawget(g, 'EEex_Menu_AddAfterMainFileReloadedListener')
        if type(addReload) == 'function' and not rawget(g, '_bgseWorldMenuReloadListener') then
            rawset(g, '_bgseWorldMenuReloadListener', true)
            pcall(addReload, function() pushMenu() end)
        end

        local addInit = rawget(g, 'EEex_GameState_AddInitializedListener')
        if type(addInit) == 'function' and not rawget(g, '_bgseWorldInitListener') then
            rawset(g, '_bgseWorldInitListener', true)
            pcall(addInit, function()
                rawset(g, '_bgseWorldInitSeen', true)
                local current = rawget(g, '_bgseWorldApi')
                if type(current) == 'table' and type(current.invalidate) == 'function' then pcall(current.invalidate, current) end
                pushMenu()
            end)
        end

        local addLists = rawget(g, 'EEex_Opcode_AddDeferredListsResolvedListener') or rawget(g, 'EEex_Opcode_AddListsResolvedListener')
        if type(addLists) == 'function' and not rawget(g, '_bgseWorldListsListener') then
            rawset(g, '_bgseWorldListsListener', true)
            pcall(addLists, function()
                local current = rawget(g, '_bgseWorldApi')
                if type(current) == 'table' and type(current.fastStep) == 'function' then pcall(current.fastStep, current) end
            end)
        end

        local addDestroy = rawget(g, 'EEex_GameState_AddDestroyedListener')
        if options.hookDestroyed ~= true and type(addDestroy) == 'function' and not rawget(g, '_bgseWorldDestroyListener') then
            rawset(g, '_bgseWorldDestroyListener', true)
            pcall(addDestroy, function()
                local current = rawget(g, '_bgseWorldApi')
                if type(current) == 'table' and type(current.onDestroyed) == 'function' then pcall(current.onDestroyed, current) end
            end)
        end

        pushMenu()
    end
    return api
end

return M
