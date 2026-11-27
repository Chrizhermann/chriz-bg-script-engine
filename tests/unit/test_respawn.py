"""Tests for Fog-of-War respawn governance & rest-interruption perimeter (combat-intent/respawn.lua & adapters/eeex/respawn.lua)."""

import importlib
import struct
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def _run_lua(backend: str, script: str):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    return runtime.execute(script)


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_respawn_policy_tiers_distances_and_unbounded_cycles(backend):
    _run_lua(
        backend,
        """
        local respawn = require('combat-intent.respawn')

        -- Hardcoded infested areas = 1 turn (900 ticks)
        assert(respawn.tier({area = 'bg5201'}) == 'infested')
        assert(respawn.cooldownTicks({area = 'AR0404'}) == 900)

        -- Boss-gated infested areas (De'Arnise Keep & Umar Temple): 1 turn while boss lives, 2h after
        assert(respawn.tier({area = 'AR1302', bossDead = false}) == 'infested')
        assert(respawn.cooldownTicks({area = 'AR1302', bossDead = false}) == 900)
        assert(respawn.tier({area = 'AR1302', bossDead = true}) == 'dungeon')
        assert(respawn.cooldownTicks({area = 'AR1302', bossDead = true}) == 9000)
        assert(respawn.tier({area = 'AR1401', bossDead = false}) == 'infested')
        assert(respawn.tier({area = 'AR1401', bossDead = true}) == 'dungeon')

        -- High-density indoor threshold (>= 6 spawn points) -> infested; outdoor stays wilderness
        assert(respawn.tier({area = 'BG4101', outdoor = false, spawnCount = 6}) == 'infested')
        assert(respawn.tier({area = 'BG4101', outdoor = false, spawnCount = 5}) == 'dungeon')
        assert(respawn.cooldownTicks({area = 'BG4101', outdoor = false, spawnCount = 5}) == 9000)
        assert(respawn.tier({area = 'BG3200', outdoor = true, spawnCount = 10}) == 'wilderness')
        assert(respawn.cooldownTicks({area = 'BG3200', outdoor = true, spawnCount = 10}) == 54000)

        -- Distance floor scaling (640 px floor, 65% map diag up to 1100 px)
        assert(respawn.minDistance(nil) == 1100)
        assert(respawn.minDistance(2200) == 1100)
        assert(respawn.minDistance(1400) == 910)
        assert(respawn.minDistance(700) == 640)

        -- Firing detection
        assert(respawn.hasFired(150, 150, true) == true)
        assert(respawn.hasFired(15, 240, false) == true)
        assert(respawn.hasFired(150, 149, false) == false)

        -- Fresh initial room spawn untouched when party > 448 and not fired
        local fresh = respawn.evaluate({
            tick = 1000, saved = 0, partyDist = 700, countdown = 20,
            wasHeld = false, fired = false, cooldown = 9000, minDist = 1100,
        })
        assert(fresh.reason == 'fresh' and fresh.hold == false and fresh.saved == 0 and fresh.ready == nil)

        -- Seeing or firing an initial point arms governance and blocks immediate respawn
        local armed = respawn.evaluate({
            tick = 1000, saved = 0, partyDist = 350, countdown = 20,
            wasHeld = false, fired = false, cooldown = 9000, minDist = 1100,
        })
        assert(armed.reason == 'armed' and armed.hold == true and armed.saved == 10000 and armed.ready == 0)

        -- Even after cooldown passes, staying inside minDist blocks respawn ('distance')
        local heldDist = respawn.evaluate({
            tick = 12000, saved = 10000, partyDist = 900, countdown = 150,
            wasHeld = true, fired = false, cooldown = 9000, minDist = 1100,
        })
        assert(heldDist.reason == 'distance' and heldDist.hold == true and heldDist.ready == 0)

        -- Infinite respawn cycles (no wave cap): 12 consecutive fire -> cooldown -> distance -> release cycles
        local tick = 1000
        local saved = 10000
        for cycle = 1, 12 do
            local cool = respawn.evaluate({
                tick = tick + 100, saved = saved, partyDist = 1400, countdown = 150,
                wasHeld = true, fired = false, cooldown = 9000, minDist = 1100,
            })
            assert(cool.reason == 'cooldown' and cool.hold == true)

            tick = saved + 10
            local rel = respawn.evaluate({
                tick = tick, saved = saved, partyDist = 1400, countdown = 150,
                wasHeld = true, fired = false, cooldown = 9000, minDist = 1100,
            })
            assert(rel.reason == 'released' and rel.hold == false and rel.ready == 1 and rel.nextCountdown == 30)

            local nextWave = respawn.evaluate({
                tick = tick + 5, saved = saved, partyDist = 1300, countdown = 240,
                wasHeld = false, fired = true, cooldown = 9000, minDist = 1100,
            })
            assert(nextWave.reason == 'cooldown' and nextWave.hold == true)
            saved = nextWave.saved
            assert(saved == tick + 5 + 9000)
        end
        """,
    )


def _bmp_header_bytes(w: int, h: int) -> bytes:
    header = struct.pack('<2sIHHI', b'BM', 118, 0, 0, 118)
    dib = struct.pack('<IIIHHIIIIII', 40, w, h, 1, 4, 0, 0, 0, 0, 16, 16)
    return header + dib


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_respawn_adapter_governance_and_rest_perimeter(backend):
    bmp = list(_bmp_header_bytes(80, 80))  # diag = sqrt(1280^2 + 960^2) = 1600 -> 1040 minDist
    _run_lua(
        backend,
        f"""
        local respawnMod = require('adapters.eeex.respawn')
        local bmpBytes = {{{','.join(str(b) for b in bmp)}}}

        local gameTime = 1000
        local areaVars = {{}}
        local globalVars = {{SPRITE_IS_DEADTORGAL = 0}}
        local queued = {{}}
        local area = {{
            m_resref = {{get = function() return 'AR1302' end}},
            m_header = {{m_areaType = 0}},
            m_lVertSort = {{}},
            m_lVertSortBack = {{}},
        }}
        local pc = {{
            m_id = 1, m_active = 1, m_pArea = area,
            m_pos = {{x = 1200, y = 400}},
            m_baseStats = {{m_hitPoints = 40, m_generalState = 0}},
        }}
        local sp1 = {{
            m_id = 101, m_objectType = 0x20, bReady = 1,
            m_pos = {{x = 400, y = 400}},
            m_countdown = 20,
        }}
        area.m_lVertSort = {{101}}
        local objs = {{[101] = sp1}}

        local g = {{
            CGameObjectType = {{SPAWNING = 0x20}},
            EngineGlobals = {{g_pBaldurChitin = {{m_pObjectGame = {{m_worldTime = {{m_gameTime = 1000}}}}}}}},
            EEex_Area_GetVisible = function() return area end,
            EEex_Sprite_GetInPortrait = function(i) return i == 0 and pc or nil end,
            EEex_GameObject_Get = function(id) return objs[id] end,
            EEex_GameObject_IsSprite = function(o) return o and o.m_objectType ~= 0x20 end,
            EEex_Area_GetVariableInt = function(_, k) return areaVars[k] or 0 end,
            EEex_Area_SetVariableInt = function(_, k, v) areaVars[k] = v end,
            EEex_GameState_GetGlobalInt = function(k) return globalVars[k] or 0 end,
            EEex_Resource_Fetch = function(res, kind)
                if res == 'AR1302SR' and kind == 'BMP' then
                    return {{Demand = function() return bmpBytes end, nSize = #bmpBytes}}
                end
                return nil
            end,
            EEex_UDToPtr = function(t) return type(t) == 'table' and 1000 or 0 end,
            EEex_ReadU8 = function(ptr) return bmpBytes[ptr - 1000 + 1] or 0 end,
            EEex_Area_GetNearestOpenPosition = function(_, px, py) return px, py end,
            EEex_Action_QueueResponseStringOnAIBase = function(cmd, sp)
                queued[#queued + 1] = {{id = sp.m_id, cmd = cmd}}
            end,
        }}
        local function setTime(t)
            gameTime = t
            g.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime = t
        end

        local api = respawnMod.new(g, {{hookListeners = false, isEnabled = function() return true end}})

        -- Fresh point far from party (800 px > 448 sight): untouched
        api:step()
        assert(sp1.bReady == 1 and (areaVars['BGSE_SP_400_400_1'] or 0) == 0)

        -- Party sees sp1 (300 px <= 448 sight): arms governance (AR1302 boss alive => +900 = 1915)
        pc.m_pos.x = 700
        setTime(1015)
        api:step()
        assert(sp1.bReady == 0 and sp1.m_countdown == 150)
        assert(areaVars['BGSE_SP_400_400_1'] == 1915)

        -- Cooldown passes, but party is only 900 px away (< minDist 1040): still held!
        pc.m_pos.x = 1300
        setTime(2000)
        api:step()
        assert(sp1.bReady == 0 and sp1.m_countdown == 150)

        -- Party moves >= 1040 px away: released to 30 and bReady=1
        pc.m_pos.x = 1500
        setTime(2030)
        api:step()
        assert(sp1.bReady == 1 and sp1.m_countdown == 30)

        -- Disable respawns cleanly unholds held points
        pc.m_pos.x = 700
        sp1.m_countdown = 240 -- simulate respawn fired & started new cooldown -> will hold
        setTime(2060)
        api:step()
        assert(sp1.bReady == 0 and sp1.m_countdown >= 150)
        api:setRespawnsEnabled(false)
        assert(sp1.bReady == 1 and sp1.m_countdown <= 90)

        -- Rest-interruption perimeter: time jump >= 4500 in same area moves close non-summoned hostile
        api:setRespawnsEnabled(true)
        local meleeHostile = {{
            m_id = 201, m_active = 1, m_pArea = area,
            m_pos = {{x = 750, y = 400}}, -- 50 px from PC at (700, 400)
            m_typeAI = {{m_EnemyAlly = 255}},
            m_lSummonedBy = {{m_Instance = -1}},
            m_nCopyParent = -1,
            m_baseStats = {{m_hitPoints = 20, m_generalState = 0}},
        }}
        local summonedHostile = {{
            m_id = 202, m_active = 1, m_pArea = area,
            m_pos = {{x = 730, y = 410}}, -- 32 px from PC, but summoned!
            m_typeAI = {{m_EnemyAlly = 255}},
            m_lSummonedBy = {{m_Instance = 99}},
            m_nCopyParent = -1,
            m_baseStats = {{m_hitPoints = 20, m_generalState = 0}},
        }}
        local clonedHostile = {{
            m_id = 203, m_active = 1, m_pArea = area,
            m_pos = {{x = 720, y = 410}}, -- clone!
            m_typeAI = {{m_EnemyAlly = 255}},
            m_lSummonedBy = {{m_Instance = -1}},
            m_nCopyParent = 201,
            m_baseStats = {{m_hitPoints = 20, m_generalState = 0}},
        }}
        local preExisting = {{
            m_id = 204, m_active = 1, m_pArea = area,
            m_pos = {{x = 760, y = 400}},
            m_typeAI = {{m_EnemyAlly = 255}},
            m_lSummonedBy = {{m_Instance = -1}},
            m_nCopyParent = -1,
            m_baseStats = {{m_hitPoints = 20, m_generalState = 0}},
        }}
        area.m_lVertSort = {{101, 204}}
        objs[204] = preExisting
        setTime(2100)
        api:step() -- 204 known before rest

        -- Rest happens: +4500 ticks, meleeHostile + summonedHostile + clonedHostile spawn next to party
        area.m_lVertSort = {{101, 201, 202, 203, 204}}
        objs[201] = meleeHostile
        objs[202] = summonedHostile
        objs[203] = clonedHostile
        setTime(6700)
        api:step()
        assert(#queued == 1 and queued[1].id == 201, 'expected only non-summoned new melee hostile moved')
        assert(queued[1].cmd:match('^JumpToPoint%(%[%d+%.%d+%]%)\\nFaceObject%(NearestEnemyOf%(Myself%)%)$'))
        local jx, jy = queued[1].cmd:match('%[(%d+)%.(%d+)%]')
        local d = math.sqrt((tonumber(jx) - 700)^2 + (tonumber(jy) - 400)^2)
        assert(d >= 280 and d <= 420)
        local st = api:inspect()
        assert(st.counts.restJumps == 1 and st.counts.restRelocated == 1)
        """,
    )
