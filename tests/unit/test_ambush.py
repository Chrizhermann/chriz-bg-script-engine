"""Tests for sensible ambushes (combat-intent/ambush.lua, adapters/eeex/search.lua, hook/runtime, tools/ambush_rule.py)."""

import importlib
import struct
from pathlib import Path

import pytest

from tools import ambush_rule

ROOT = Path(__file__).resolve().parents[2]


def _run_lua(backend: str, script: str):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    return runtime.execute(script)


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_ambush_policy_areas_approach_and_rest_perimeter(backend):
    _run_lua(
        backend,
        """
        local ambush = require('combat-intent.ambush')

        assert(ambush.isAmbushArea('BG5600') == true)
        assert(ambush.isAmbushArea('bg6100') == true)
        assert(ambush.isAmbushArea('AR0041') == true)
        assert(ambush.isAmbushArea('ar0046') == true)
        assert(ambush.isAmbushArea('BD0063') == true)
        assert(ambush.isAmbushArea('BD6100') == false)
        assert(ambush.isAmbushArea('OH1000') == false)
        assert(ambush.isAmbushArea('AR0700') == false)
        assert(ambush.isAmbushArea('') == false)
        assert(ambush.isAmbushArea(nil) == false)

        assert(ambush.shouldApproach({enabled = true, area = 'BG5600', ea = 255}) == true)
        assert(ambush.shouldApproach({enabled = true, area = 'AR0045', ea = 200, fought = false, gaveUp = false}) == true)
        assert(ambush.shouldApproach({enabled = false, area = 'BG5600', ea = 255}) == false)
        assert(ambush.shouldApproach({enabled = true, area = 'AR0700', ea = 255}) == false)
        assert(ambush.shouldApproach({enabled = true, area = 'BG5600', ea = 30}) == false)
        assert(ambush.shouldApproach({enabled = true, area = 'BG5600', ea = 254}) == false)
        assert(ambush.shouldApproach({enabled = true, area = 'BG5600', ea = 255, fought = 120}) == false)
        assert(ambush.shouldApproach({enabled = true, area = 'BG5600', ea = 255, gaveUp = 300}) == false)

        local near = ambush.nearestParty({x = 100, y = 100}, {
            {id = 5, x = 200, y = 100},
            {id = 2, x = 200, y = 100},
            {id = 9, x = 400, y = 400},
        })
        assert(near ~= nil and near.id == 2)
        assert(ambush.nearestParty({x = 0, y = 0}, {}) == nil)

        local party = {{id = 1, x = 500, y = 500}}
        local cands = {
            {x = 840, y = 500}, -- east 340
            {x = 850, y = 570}, -- east-south ~357, ~71 px from (840,500)
            {x = 160, y = 500}, -- west 340
            {x = 500, y = 840}, -- south 340
            {x = 500, y = 620}, -- too close (120)
            {x = 980, y = 500}, -- beyond 420
        }
        -- Outer hostile (>= 240 px) stays put; two melee-range hostiles move to perimeter preserving side & spacing
        local moves = ambush.restPerimeter(party, {
            {id = 10, x = 560, y = 500}, -- east 60
            {id = 11, x = 590, y = 520}, -- east 92
            {id = 12, x = 200, y = 500}, -- already 300 px west
        }, cands)
        assert(#moves == 2)
        local byId = {}
        for _, m in ipairs(moves) do byId[m.id] = m end
        assert(byId[10].x > 500 and byId[11].x > 500)
        local d10 = math.sqrt((byId[10].x - 500)^2 + (byId[10].y - 500)^2)
        local d11 = math.sqrt((byId[11].x - 500)^2 + (byId[11].y - 500)^2)
        assert(d10 >= 280 and d10 <= 420 and d11 >= 280 and d11 <= 420)
        local sep = math.sqrt((byId[10].x - byId[11].x)^2 + (byId[10].y - byId[11].y)^2)
        assert(sep >= 56)

        -- Fallback relaxation up to 520 px / 40 px spacing when normal band lacks slots
        local tight = ambush.restPerimeter(party, {
            {id = 20, x = 540, y = 500},
            {id = 21, x = 550, y = 500},
        }, {
            {x = 960, y = 500}, -- 460 px (needs relaxed max 520)
            {x = 960, y = 542}, -- 42 px away (needs relaxed spacing 40)
        })
        assert(#tight == 2)
        """,
    )


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_search_ambush_approach_clue_lifecycle(backend):
    _run_lua(
        backend,
        """
        local searchMod = require('adapters.eeex.search')

        local function makeArea(res)
            return {
                m_resref = {get = function() return res end},
                m_header = {m_areaType = 1},
            }
        end
        local area = makeArea('BG5600')
        local pc = {
            m_id = 1, m_pArea = area, m_pos = {x = 640, y = 480},
            m_baseStats = {m_hitPoints = 40, m_generalState = 0},
        }
        local enemy = {
            m_id = 10, m_pArea = area, m_pos = {x = 140, y = 480},
            m_typeAI = {m_EnemyAlly = 255, m_General = 1, m_Race = 1, m_Class = 2},
            m_baseStats = {m_hitPoints = 30, m_generalState = 0},
            m_curAction = {m_actionID = 0},
        }
        local g = {
            EEex_Sprite_GetInPortrait = function(i) return i == 0 and pc or nil end,
            EEex_GameObject_IsSprite = function(o) return o ~= nil end,
            EEex_GameObject_Get = function(id)
                if id == 1 then return pc end
                if id == 10 then return enemy end
                return nil
            end,
            EEex_Sprite_GetStat = function() return 0 end,
            EEex_BAnd = function(a, b) return a % (b * 2) >= b and b or 0 end,
        }

        local seeker = searchMod.new(g, {ambushes = true})
        local mind = {wit = 10, sight = 448}
        local frame = {
            area = 'BG5600',
            self = {id = 10, x = 140, y = 480, ea = 255, hp = 30, level = 3, seeInvisible = false},
        }

        -- Before first contact, relocated creature approaches nearest living party member via 'called'
        local d1 = seeker:decide(enemy, frame, 100, 'fighter', mind, {}, {}, nil, nil)
        assert(d1 ~= nil and d1.kind == 'search' and d1.clue == 'called' and d1.target == 1)

        -- Repeating decide retains original latched ambushTick so patience can expire rather than looping forever
        local d2 = seeker:decide(enemy, frame, 150, 'fighter', mind, {}, {}, nil, nil)
        assert(d2 ~= nil and d2.kind == 'search')
        local d3, why3 = seeker:decide(enemy, frame, 5000, 'fighter', mind, {}, {}, nil, nil)
        assert(d3 == nil and why3 == 'given-up')

        -- After engaging in a fight (s.fought set) and losing sight with no clues, ambush approach does not fire
        local seeker2 = searchMod.new(g, {ambushes = true})
        seeker2:fight(enemy, frame, 200, nil)
        seeker2.decide(seeker2, enemy, frame, 205, 'fighter', mind, {}, {}, nil, nil)
        local afterFight, whyFight = seeker2:decide(enemy, frame, 210, 'fighter', mind, {}, {}, nil, nil)
        assert(afterFight == nil or afterFight.clue ~= 'called')
        assert(whyFight == 'no-clue')

        -- Disabled via setAmbushes(false): no ambush approach clue emitted
        local seeker3 = searchMod.new(g, {ambushes = true})
        seeker3:setAmbushes(false)
        local offDec, offWhy = seeker3:decide(enemy, frame, 100, 'fighter', mind, {}, {}, nil, nil)
        assert(offDec == nil and offWhy == 'no-clue')
        """,
    )


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_runtime_ambushes_and_respawns_default_on_independent_of_challenge(backend):
    _run_lua(
        backend,
        """
        local runtime = require('adapters.eeex.runtime')
        local saved = {}
        local ini = {}
        local g = {
            Infinity_GetINIValue = function(sec, key, fallback)
                if sec == 'BGSE' and ini[key] ~= nil then return ini[key] end
                return fallback
            end,
            Infinity_SetINIValue = function(sec, key, val)
                saved[key] = val
            end,
            BGSE_HOOKED = {},
        }
        local root = runtime.install(g, {director = false, choice = false})
        local st = root.inspect()
        assert(st.challengeMode == false)
        assert(st.ambushes == true)
        assert(st.respawn.respawns == true)
        assert(st.respawn.ambushes == true)
        assert(g.BGSE_AmbushOn() == true)

        root.setAmbushes(false, true)
        assert(g.BGSE_AmbushOn() == false)
        assert(root.inspect().ambushes == false)
        assert(root.inspect().respawn.ambushes == false)
        assert(saved.Ambushes == 0)

        root.setRespawns(false, true)
        assert(root.inspect().respawn.respawns == false)
        assert(saved.Respawns == 0)

        root.setAmbushes(true, false)
        assert(g.BGSE_AmbushOn() == true)
        root.setEnabled(false, false)
        assert(g.BGSE_AmbushOn() == false)
        root.setEnabled(true, false)
        assert(g.BGSE_AmbushOn() == true)
        """,
    )


def _make_sr_bmp(w: int = 80, h: int = 80, blocked=None) -> bytes:
    blocked = set(blocked or ())
    stride = ((w * 4 + 31) // 32) * 4
    pixels = bytearray(stride * h)
    for cy in range(h):
        ry = h - 1 - cy
        row = ry * stride
        for cx in range(w):
            nib = 0 if (cx, cy) in blocked else 1
            byte_off = row + (cx >> 1)
            if (cx & 1) == 0:
                pixels[byte_off] = (pixels[byte_off] & 0x0F) | (nib << 4)
            else:
                pixels[byte_off] = (pixels[byte_off] & 0xF0) | nib
    data_off = 54 + 64
    header = struct.pack('<2sIHHI', b'BM', data_off + len(pixels), 0, 0, data_off)
    dib = struct.pack('<IIIHHIIIIII', 40, w, h, 1, 4, 0, len(pixels), 0, 0, 16, 16)
    return header + dib + (b'\x00' * 64) + bytes(pixels)


def test_ambush_rule_relocation_modes_and_safeties():
    # Center 200..400 blocked patch + open Fog-of-War ring
    blocked = {(cx, cy) for cx in range(36, 44) for cy in range(36, 44)}
    bmp = _make_sr_bmp(80, 80, blocked=blocked)
    _, _, grid = ambush_rule.parse_sr_bmp(bmp)
    assert grid[40 * 80 + 40] == 0
    assert grid[20 * 80 + 20] == 2
    assert grid[2 * 80 + 20] == 0  # border 4-cell strip excluded
    cands = ambush_rule.build_candidates('BG5600', bmp)
    assert cands and all(30625 <= p_sq and m_sq <= 490000 for _, _, _, _, p_sq, m_sq in cands)

    spawns = '\n'.join(f'    CreateCreature("KOBOLD",[640.480],S)' for _ in range(8))
    baf = f"""IF
  Global("AMB","GLOBAL",0)
THEN
  RESPONSE #100
    SetGlobal("AMB","GLOBAL",1)
{spawns}
END

IF
  Global("DLG","GLOBAL",0)
THEN
  RESPONSE #100
    CreateCreature("GUARD",[640.480],S)
    CreateCreature("RESUNA",[640.480],S)
    CreateCreature("ARCHER",[640.480],S)
END

IF
  Global("GTH","GLOBAL",0)
THEN
  RESPONSE #100
    CreateCreature("GITH01",[640.480],S)
    CreateCreature("GITH02",[640.480],S)
    CreateCreature("GITH03",[640.480],S)
END

IF
  Global("OR2","GLOBAL",0)
  OR(2)
    Global("A","GLOBAL",1)
    Global("B","GLOBAL",1)
THEN
  RESPONSE #100
    CreateCreature("WOLF",[640.480],S)
END

IF
  OR(3)
    Global("A","GLOBAL",1)
    Global("B","GLOBAL",1)
THEN
  RESPONSE #100
    CreateCreature("WOLF",[640.480],S)
END

IF
  Global("CUT","GLOBAL",0)
THEN
  RESPONSE #100
    CreateCreature("THIEF",[640.480],S)
    JumpToPoint([500.500])
END

IF
  Global("IMP","GLOBAL",0)
THEN
  RESPONSE #100
    CreateCreatureImpassable("GOLEM",[640.480],S)
END
"""
    patched, changed = ambush_rule.patch_ambush_baf(baf, 'BG5600', bmp, frozenset({'RESUNA'}))
    assert changed == 5

    blocks = list(ambush_rule.BLOCK_RE.finditer(patched))
    # First block expanded to ON + OFF dual blocks (hostile Fog-of-War pack)
    host_on = blocks[0].group(0)
    host_off = blocks[1].group(0)
    assert ambush_rule.AMBUSH_ON_LINE in host_on
    assert ambush_rule.AMBUSH_OFF_LINE in host_off
    host_coords = [(int(m.group(3)), int(m.group(4))) for m in ambush_rule.CREATE_RE.finditer(host_on)]
    assert len(host_coords) == 8
    for x, y in host_coords:
        d = ((x - 640) ** 2 + (y - 480) ** 2) ** 0.5
        assert 480 <= d <= 700
        assert grid[(y // 12) * 80 + (x // 16)] > 0
    for i in range(len(host_coords)):
        for j in range(i + 1, len(host_coords)):
            sep = ((host_coords[i][0] - host_coords[j][0]) ** 2 + (host_coords[i][1] - host_coords[j][1]) ** 2) ** 0.5
            assert sep >= 56

    # Dialogue block: RESUNA (talker) in 300..355 px, companions in 365..485 px
    dlg_on = blocks[2].group(0)
    dlg_spawns = {m.group(2): ((int(m.group(3)) - 640) ** 2 + (int(m.group(4)) - 480) ** 2) ** 0.5
                  for m in ambush_rule.CREATE_RE.finditer(dlg_on)}
    assert 300 <= dlg_spawns['RESUNA'] <= 355
    assert 365 <= dlg_spawns['GUARD'] <= 485
    assert 365 <= dlg_spawns['ARCHER'] <= 485

    # Planar block: GITH* in 175..275 px and de-stacked
    gith_on = blocks[4].group(0)
    gith_coords = [(int(m.group(3)), int(m.group(4))) for m in ambush_rule.CREATE_RE.finditer(gith_on)]
    assert len(gith_coords) == 3
    for x, y in gith_coords:
        d = ((x - 640) ** 2 + (y - 480) ** 2) ** 0.5
        assert 175 <= d <= 275

    # Closed OR(2) safety: EEex_LuaTrigger goes at end of triggers (outside OR(2))
    or_closed = blocks[6].group(0).splitlines()
    assert or_closed[2].strip() == 'OR(2)'
    assert or_closed[5].strip() == ambush_rule.AMBUSH_ON_LINE.strip()

    # Open OR(3) safety: EEex_LuaTrigger inserts above OR(3)
    or_open = blocks[8].group(0).splitlines()
    assert or_open[1].strip() == ambush_rule.AMBUSH_ON_LINE.strip()
    assert or_open[2].strip() == 'OR(3)'

    # Cutscene / JumpToPoint & CreateCreatureImpassable blocks left completely untouched (single block each)
    assert 'JumpToPoint([500.500])' in blocks[10].group(0)
    assert 'BGSE_AmbushOn' not in blocks[10].group(0)
    assert 'CreateCreatureImpassable("GOLEM"' in blocks[11].group(0)
    assert 'BGSE_AmbushOn' not in blocks[11].group(0)

    # Idempotency check
    patched2, changed2 = ambush_rule.patch_ambush_baf(patched, 'BG5600', bmp, frozenset({'RESUNA'}))
    assert changed2 == 0
    assert patched2 == patched

    # AR0041 already-sensible distant RENFELD block stays untouched
    renfeld = """IF
  Global("REN","GLOBAL",0)
THEN
  RESPONSE #100
    CreateCreature("RENFELD",[960.860],S)
    CreateCreature("RETHUG01",[900.800],S)
END
"""
    ren_out, ren_changed = ambush_rule.patch_ambush_baf(renfeld, 'AR0041', bmp, frozenset({'RENFELD'}))
    assert ren_changed == 0
    assert ren_out == renfeld
