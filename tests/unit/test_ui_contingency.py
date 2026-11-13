"""Optional Challenge-Mode Contingency UI filter (adapters/eeex/ui.lua, hook.lua, runtime.lua)."""
import importlib
from pathlib import Path

import pytest

from tests.unit.test_ie_resources import build_pro, build_spl, fx, spl_ability
from tools import build_runtime

ROOT = Path(__file__).resolve().parents[2]


def _make_spls():
    # Damage (Fireball-like: target=4, projectile=3 enemy AoE, opcode 12 fire damage)
    dmg = build_spl([spl_ability(count=1, index=0, target=4, projectile=3)],
                    [fx(opcode=12, target=2, p2=8 * 65536, dice=6, sides=6)])
    # Disable (Hold/Web-like: opcode 175)
    dis = build_spl([spl_ability(count=1, index=0, target=1, projectile=1)],
                    [fx(opcode=175, target=2, duration=30)])
    # Debuff (Slow-like: opcode 40)
    deb = build_spl([spl_ability(count=1, index=0, target=4, projectile=3)],
                    [fx(opcode=40, target=2, duration=36)])
    # Removal (Dispel/Breach-like: opcode 58)
    rem = build_spl([spl_ability(count=1, index=0, target=1, projectile=1)],
                    [fx(opcode=58, target=2)])
    # Protection (Stoneskin-like: opcode 218 on self)
    prot = build_spl([spl_ability(count=1, index=0, target=5, projectile=1)],
                     [fx(opcode=218, target=1, p1=6, duration=43200)])
    # Buff (Blur/Haste-like: opcode 16 haste)
    buff = build_spl([spl_ability(count=1, index=0, target=5, projectile=1)],
                     [fx(opcode=16, target=1, duration=60)])
    # Summon (Monster Summoning-like: opcode 127)
    summon = build_spl([spl_ability(count=1, index=0, target=4, projectile=1)],
                       [fx(opcode=127, target=2, duration=60)])
    return {
        'SPL:SPWI304': dmg,
        'SPL:SPWI306': dis,
        'SPL:SPWI312': deb,
        'SPL:SPWI302': rem,
        'SPL:SPWI408': prot,
        'SPL:SPWI305': buff,
        'SPL:SPWI407': summon,
        'PRO:ENEMY': build_pro(3),
    }


def _env_lua(files_lua):
    return f'''
local files = {files_lua}
local memory, next_base = {{}}, 0x100000
local function byte(a)
    for _, m in pairs(memory) do
        if a >= m.base and a < m.base + #m.data then return m.data:byte(a - m.base + 1) end
    end
    error('oob')
end
iniWrites = {{}}
iniValues = iniValues or {{}}
ticks = 40
local time = setmetatable({{}}, {{__index = function(_, k) if k == 'm_gameTime' then return ticks end end}})
EngineGlobals = {{g_pBaldurChitin = {{m_pObjectGame = {{m_worldTime = time}}}}}}
Infinity_GetINIValue = function(sec, k, default)
    if iniValues[k] ~= nil then return iniValues[k] end
    return default
end
Infinity_SetINIValue = function(sec, k, v) iniWrites[sec .. '.' .. k] = v end
EEex_ReadU8 = byte
EEex_Resource_Fetch = function(resref, ext)
    local data = files[ext .. ':' .. resref]
    if not data then return nil end
    local key = ext .. ':' .. resref
    if not memory[key] then memory[key] = {{base = next_base, data = data}}; next_base = next_base + 0x100000 end
    local base = memory[key].base
    return {{nSize = #data, Demand = function() return {{ptr = base}} end}}
end
EEex_UDToPtr = function(ud) return ud.ptr end
EEex_Resource_LoadIDS = function(name) return name end
EEex_Resource_IterateUnpackedIDSEntries = function(ids, fn)
    if ids == 'PROJECTL' then fn(2, 'ENEMY', 'ENEMY') end
end
EEex_GameObject_Get = function() return nil end
EEex_GameObject_IsSprite = function() return false end
EEex_AIBase_GetScriptLevelResRef = function() return '' end
EEex_Action_QueueResponseStringOnAIBase = function() end
EEex_GameState_AddDestroyedListener = function() end
menuListeners = {{}}
EEex_Menu_AddAfterMainFileLoadedListener = function(fn) menuListeners[#menuListeners + 1] = fn end
local allSpells = {{
    {{resref = 'SPWI304', level = 3}},
    {{resref = 'SPWI306', level = 3}},
    {{resref = 'SPWI312', level = 3}},
    {{resref = 'SPWI302', level = 3}},
    {{resref = 'SPWI408', level = 4}},
    {{resref = 'SPWI305', level = 3}},
    {{resref = 'SPWI407', level = 4}},
    {{resref = 'UNKNOWN9', level = 2}},
}}
function filterContingencyMageSpells()
    local copy = {{}}
    for i, v in ipairs(allSpells) do copy[i] = v end
    return copy
end
'''


def _resrefs(rows):
    return [rows[i]['resref'] for i in sorted(rows.keys())]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_player_defensive_contingencies_defaults_off_and_filters_when_enabled(backend):
    lua = importlib.import_module('lupa.' + backend).LuaRuntime(encoding='latin-1')
    lua.execute("package.path=''; package.cpath=''")
    files = _make_spls()
    # Install from the real built runtime bundle (verifies adapters.eeex.ui is bundled cleanly).
    files_arg = lua.table_from(files)
    lua.globals()['_TEST_FILES'] = files_arg
    lua.execute(_env_lua('_TEST_FILES'))
    lua.execute(build_runtime.build())

    # 1. Opt-in defaults: both PlayerDefensiveContingencies and enemy DefensiveContingencies default OFF (false)!
    assert lua.execute('''
        local st = BGSE.inspect()
        assert(st.ui ~= nil and st.ui.playerDefensiveContingencies == false)
        assert(st.choice.defensiveContingencies == false)
        contingencyResRef = 'SPWI617'
        showContingency = true
        return #filterContingencyMageSpells()
    ''') == 8

    # 2. Enable via BGSE.setPlayerDefensiveContingencies(true, true): persists to INI and filters only
    # Contingency / Chain Contingency screens, leaving Sequencers & Triggers completely untouched!
    lua.execute('BGSE.setPlayerDefensiveContingencies(true, true)')
    assert lua.eval("iniWrites['BGSE.PlayerDefensiveContingencies']") == 1
    assert lua.eval('BGSE.inspect().ui.playerDefensiveContingencies') is True

    for resref in ('SPWI617', 'SPWI908', 'SPIN142', 'DW#WZCND'):
        lua.execute(f"contingencyResRef = '{resref}'; showContingency = false")
        kept = _resrefs(lua.execute('return filterContingencyMageSpells()'))
        assert kept == ['SPWI408', 'SPWI305', 'SPWI407', 'UNKNOWN9'], resref

    # Fallback when contingencyResRef is empty: honours showContingency == true vs false.
    lua.execute("contingencyResRef = ''; showContingency = true")
    assert _resrefs(lua.execute('return filterContingencyMageSpells()')) == ['SPWI408', 'SPWI305', 'SPWI407', 'UNKNOWN9']
    lua.execute("contingencyResRef = ''; showContingency = false")
    assert len(_resrefs(lua.execute('return filterContingencyMageSpells()'))) == 8

    # Sequencers and Spell Triggers NEVER filter offensive spells!
    for seq in ('SPWI420', 'SPWI710', 'SPWI809', 'SPIN143', 'SPIN144', 'SPIN145', 'SPWI999'):
        lua.execute(f"contingencyResRef = '{seq}'; showContingency = false")
        assert len(_resrefs(lua.execute('return filterContingencyMageSpells()'))) == 8, seq

    # Disable again -> all 8 return even on SPWI908.
    lua.execute("BGSE.setPlayerDefensiveContingencies(false, true); contingencyResRef = 'SPWI908'")
    assert len(_resrefs(lua.execute('return filterContingencyMageSpells()'))) == 8
    assert lua.eval("iniWrites['BGSE.PlayerDefensiveContingencies']") == 0


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_ui_hooks_after_menu_load_and_respects_ini_flag(backend):
    lua = importlib.import_module('lupa.' + backend).LuaRuntime(encoding='latin-1')
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    files = _make_spls()
    lua.globals()['_TEST_FILES'] = lua.table_from(files)
    lua.execute('iniValues = {PlayerDefensiveContingencies = 1, DefensiveContingencies = 1}')
    lua.execute(_env_lua('_TEST_FILES'))
    # Simulate UI.MENU not yet loaded when M_BGSE installs: remove filterContingencyMageSpells first.
    lua.execute('savedOrig = filterContingencyMageSpells; filterContingencyMageSpells = nil')
    lua.execute("require('adapters.eeex.runtime').install(_G, {version = 'test'})")
    assert lua.eval('#menuListeners') == 2
    assert lua.eval('BGSE.inspect().ui.playerDefensiveContingencies') is True
    assert lua.eval('BGSE.inspect().choice.defensiveContingencies') is True
    # Also test setDefensiveContingencies persistence on root.
    lua.execute('BGSE.setDefensiveContingencies(false, true)')
    assert lua.eval("iniWrites['BGSE.DefensiveContingencies']") == 0
    assert lua.eval('BGSE.inspect().choice.defensiveContingencies') is False

    # Now UI.MENU loads and defines filterContingencyMageSpells; menu listeners run once cleanly!
    lua.execute('''
        filterContingencyMageSpells = savedOrig
        for _, fn in ipairs(menuListeners) do fn() end
        -- Reinstall must not double-wrap or stack base calls.
        local wrapCalls = 0
        local orig = _bgseOrigFilterContingency
        _bgseOrigFilterContingency = function(...) wrapCalls = wrapCalls + 1; return orig(...) end
        require('adapters.eeex.runtime').install(_G, {version = 'test'})
        assert(#menuListeners == 2)
        contingencyResRef = 'SPWI617'
        local out = filterContingencyMageSpells()
        assert(#out == 4)
        -- Hook direct reinstall keeps single base call when _bgseUiWrapper is still active.
        assert(BGSE.inspect().ui.counts.filtered == 4)
    ''')
