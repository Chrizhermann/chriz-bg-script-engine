"""The creature snapshot (adapters/eeex/creature.lua) on a fake sprite, and its profile
(combat-intent/abilities.lua) classified through the in-game reader over fake EEex memory."""
import importlib
from pathlib import Path

import pytest

from tools import ie_resources as ie
from test_eeex_resources import FAKE, FILES, to_py
from test_ie_resources import build_spl, fx, spl_ability

ROOT = Path(__file__).resolve().parents[2]

BOLT = build_spl([spl_ability(min_level=1, target=1, projectile=2, count=1, index=0)],
                 [fx(opcode=12, dice=6, sides=6, save=1, special=0)])

SPRITE = '''
local function str(v) return {get = function() return v end} end
frees, levels = 0, {}
local items = {[15] = {cResRef = str('POTN08'), m_useCount1 = 3, m_useCount2 = 0, m_useCount3 = 0, m_flags = 1},
    [20] = {cResRef = str('noitem'), m_useCount1 = 1, m_useCount2 = 0, m_useCount3 = 0, m_flags = 0},
    [30] = {ptr = 0}}
G.EEex_Utility_IterateCPtrList = function(list, fn) for _, v in ipairs(list) do if fn(v) then break end end end
G.EEex_Utility_FreeCPtrList = function() frees = frees + 1 end
G.EEex_Sprite_GetStat = function(_, stat) return ({[34] = 9, [68] = 12, [69] = 0})[stat] end
G.EEex_Sprite_GetCasterLevelForSpell = function(_, resref, wild)
    assert(wild == false)
    levels[#levels + 1] = resref
    return 11
end
local none = {getReference = function() return {} end}
sprite = {m_resref = str('testmage'), m_scriptName = str('mage one\\0junk'),
    m_memorizedSpellsMage = {getReference = function(_, level)
        if level == 2 then
            return {{m_spellId = str('bolt'), m_flags = 1}, {m_spellId = str('BOLT'), m_flags = 0},
                {m_spellId = str('GONE'), m_flags = 1}, {m_spellId = str(''), m_flags = 1}}
        end
        return {}
    end},
    m_memorizedSpellsPriest = none,
    m_memorizedSpellsInnate = {getReference = function(_, level)
        assert(level == 0) return {{m_spellId = str('SPWI304'), m_flags = 1}}
    end},
    GetQuickButtons = function(_, kind, exists)
        assert(exists == false)
        if kind == 2 then return {{m_count = 1, m_bDisabled = 0, m_abilityId = {m_res = str('BOLT')}},
            {m_count = 0, m_bDisabled = 0, m_abilityId = {m_res = str('GONE')}}} end
        return {{m_count = 1, m_bDisabled = 1, m_abilityId = {m_res = str('SPWI304')}}}
    end,
    m_equipment = {m_selectedWeapon = 10, m_selectedWeaponAbility = 0,
        m_items = {get = function(_, slot) return items[slot] end}}}
creature = require('adapters.eeex.creature')
abilities = require('combat-intent.abilities')
spells = require('combat-intent.spells')
'''


def runtime(backend):
    lua = importlib.import_module(f'lupa.{backend}').LuaRuntime(encoding='latin-1')
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    lua.execute(FAKE, lua.table_from({**FILES, 'SPL:BOLT': BOLT}), True)
    lua.execute(SPRITE)
    return lua


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_snapshot_reads_spells_buttons_items_and_levels(backend):
    lua = runtime(backend)
    snapshot = to_py(lua, lua.execute('return creature.read(G, sprite, reader)'))
    assert (snapshot['resref'], snapshot['scriptName'], snapshot['level']) == ('TESTMAGE', 'mage one', 12)
    assert (snapshot['selectedWeapon'], snapshot['selectedAbility']) == (10, 0)
    assert snapshot['spells'] == [
        {'list': 'mage', 'resref': 'BOLT', 'level': 3, 'memorized': 2, 'ready': 1, 'usable': True,
         'casterLevel': 11},
        {'list': 'mage', 'resref': 'GONE', 'level': 3, 'memorized': 1, 'ready': 1, 'usable': False},
        {'list': 'innate', 'resref': 'SPWI304', 'level': 1, 'memorized': 1, 'ready': 1,
         'usable': False, 'casterLevel': 11}]
    assert snapshot['items'] == [{'slot': 15, 'resref': 'POTN08', 'flags': 1, 'uses': [3, 0, 0]},
                                 {'slot': 20, 'resref': 'NOITEM', 'flags': 0, 'uses': [1, 0, 0]}]
    # The engine's level check runs only for spells the game has; both button lists are freed.
    assert list(lua.eval('levels').values()) == ['BOLT', 'SPWI304'] and lua.eval('frees') == 2


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_snapshot_failure_is_nil_and_frees_the_buttons(backend):
    lua = runtime(backend)
    assert lua.execute('''
        local saved = sprite.GetQuickButtons
        sprite.GetQuickButtons = function() return {{m_count = 1, m_bDisabled = 0}} end
        -- The first list fails while it is read: it is freed and no second one is made.
        local value, err = creature.read(G, sprite, reader)
        assert(value == nil and type(err) == 'string' and frees == 1)
        sprite.GetQuickButtons = saved
        sprite.m_equipment = nil
        value, err = creature.read(G, sprite, reader)
        return value == nil and type(err) == 'string'
    ''') is True


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_profile_classifies_like_the_host_records(backend):
    lua = runtime(backend)
    profile = to_py(lua, lua.execute('''
        return abilities.profile(creature.read(G, sprite, reader), reader.lookup)'''))
    bolt, gone, innate = profile['spells']
    assert gone['missing'] is True and 'effect' not in gone
    assert bolt['ability'] == 1 and innate['ability'] == 2
    assert bolt['effect']['kinds'] == ['damage'] and bolt['effect']['roles']['damage']['who'] == {'target': True}

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({k: to_lua(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(v) for v in value])
        return value
    classify = lua.eval('function(r, i) return spells.classify(r, i, reader.lookup, {level = 11}) end')
    assert bolt['effect'] == to_py(lua, classify(to_lua(ie.parse_spl(BOLT, 'BOLT')), 1))
    assert innate['effect'] == to_py(lua, classify(to_lua(ie.parse_spl(FILES['SPL:SPWI304'], 'SPWI304')), 2))
    potion, missing = profile['items']
    assert missing == {'slot': 20, 'resref': 'NOITEM', 'abilities': [], 'missing': True}
    assert potion['itemType'] == 20 and len(potion['abilities']) == 2
    assert [(a['location'], a['charges'], a['depletion'], a['uses']) for a in potion['abilities']] == [
        (3, 9, 1, 3), (3, 9, 1, 0)]
