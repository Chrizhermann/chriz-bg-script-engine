"""The in-game reader (adapters/eeex/resources.lua) returns exactly the records
tools/ie_resources.py parses, read through a fake EEex memory. The fake flags every read
outside a resource, so the reader is shown to stay inside each one."""
import importlib
from pathlib import Path

import pytest

from tools import ie_resources as ie
from test_ie_resources import (build_cre, build_eff, build_itm, build_pro, build_spl, far_tables, fx,
                               itm_ability, spl_ability)

ROOT = Path(__file__).resolve().parents[2]

FAKE = '''
local files, natives = ...
outside, fetches = false, 0
local memory = {}
local function byte(a)
    for _, m in pairs(memory) do
        if a >= m.base and a < m.base + #m.data then return m.data:byte(a - m.base + 1) end
    end
    outside = true
    error('read outside a resource')
end
local function u(a, n) local v = 0 for i = n - 1, 0, -1 do v = v * 256 + byte(a + i) end return v end
G = {EEex_ReadU8 = byte}
if natives then
    G.EEex_ReadU16 = function(a) return u(a, 2) end
    G.EEex_ReadU32 = function(a) return u(a, 4) end
    G.EEex_Read16 = function(a) local v = u(a, 2) return v >= 32768 and v - 65536 or v end
    G.EEex_Read32 = function(a) local v = u(a, 4) return v >= 2^31 and v - 2^32 or v end
    G.EEex_ReadLString = function(a, n)
        local t = {}
        for i = 0, n - 1 do local b = byte(a + i) if b == 0 then break end t[#t + 1] = string.char(b) end
        return table.concat(t)
    end
end
local next_base = 0x100000
G.EEex_Resource_Fetch = function(resref, ext)
    local data = files[ext .. ':' .. resref]
    if data == nil then return nil end
    fetches = fetches + 1
    local key = ext .. ':' .. resref
    if not memory[key] then memory[key] = {base = next_base, data = data}; next_base = next_base + 0x100000 end
    local base = memory[key].base
    return {nSize = #data, Demand = function() return {ptr = base} end}
end
G.EEex_UDToPtr = function(ud) return ud.ptr end
G.EEex_Resource_LoadIDS = function(name) assert(name == 'PROJECTL') return 'ids' end
G.EEex_Resource_IterateUnpackedIDSEntries = function(ids, fn)
    for _, row in ipairs({{0, 'NONE'}, {1, 'Arrow'}, {2, 'fireball'}, {2, 'LATER'}}) do fn(row[1], row[2], row[2]) end
end
reader = require('adapters.eeex.resources').new(G)
'''


def to_py(lua, value):
    if lua.eval('type')(value) != 'table':
        return value
    keys = list(value.keys())
    if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_py(lua, value[k]) for k in sorted(keys)]
    return {str(k): to_py(lua, value[k]) for k in keys}


SPL = build_spl([spl_ability(count=2, index=1, projectile=14), spl_ability(count=1, index=3)],
                [fx(opcode=1, p1=-7, res='cast'), fx(opcode=2, p1=-1, special=0xFFFFFFFF),
                 fx(opcode=3, res='ab  '), fx(opcode=4, res='ab1')], casting=(0, 1))
NUL = build_spl([spl_ability(count=1, index=0)], [fx()[:0x14] + b'sp\0junkX' + fx()[0x1C:]])
ITM = build_itm([itm_ability(count=1, index=0),
                 itm_ability(attack=3, thac0=5, count=2, index=1, projectile=21)],
                [fx(opcode=10), fx(opcode=11), fx(opcode=12, p1=-4)], equipping=(2, 1))
LATIN = build_spl([spl_ability(count=1, index=0)], [fx()[:0x14] + b'sp\xe9x\0\0\0\0' + fx()[0x1C:]])
FILES = {'SPL:SPWI304': SPL, 'SPL:NULREF': NUL, 'SPL:EMPTY': build_spl([], []), 'ITM:POTN08': ITM,
         'SPL:FAR': far_tables(build_spl([], [])), 'ITM:FAR': far_tables(build_itm([], [])),
         'SPL:LATIN': LATIN,
         'EFF:AB': build_eff(), 'PRO:FIREBALL': build_pro(3), 'PRO:ARROW': build_pro(2),
         'SPL:BADSIG': b'XXXX' + SPL[4:], 'SPL:SHORT': SPL[:0x40], 'SPL:TINY': b'SPL',
         'SPL:PASTEND': build_spl([spl_ability(count=2, index=0)], [fx()]),
         'ITM:CUT': build_itm([itm_ability(), itm_ability()], [])[:-1],
         'PRO:AREACUT': build_pro(3)[:0x200], 'CRE:SUMMON': build_cre(), 'CRE:NARROW': build_cre(wide=False),
         'CRE:CUT': build_cre()[:-2]}
PARSE = {'SPL': ie.parse_spl, 'ITM': ie.parse_itm, 'EFF': ie.parse_eff, 'PRO': ie.parse_pro, 'CRE': ie.parse_cre}


def runtime(backend, natives=True):
    lua = importlib.import_module(f'lupa.{backend}').LuaRuntime(encoding='latin-1')
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    lua.execute(FAKE, lua.table_from(FILES), natives)
    return lua


@pytest.mark.parametrize('natives', [True, False], ids=['native', 'bytes-only'])
@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_records_match_the_host_parser(backend, natives):
    lua = runtime(backend, natives)
    get = lua.eval('reader.get')
    for key in ('SPL:SPWI304', 'SPL:NULREF', 'SPL:EMPTY', 'SPL:FAR', 'ITM:FAR', 'SPL:LATIN',
                'ITM:POTN08', 'EFF:AB', 'PRO:FIREBALL', 'PRO:ARROW', 'CRE:SUMMON', 'CRE:NARROW'):
        kind, resref = key.split(':')
        assert to_py(lua, get(kind, resref.lower())) == PARSE[kind](FILES[key], resref), key
    assert lua.eval('outside') is False and list(lua.eval('reader.problems').values()) == []


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_malformed_resources_are_nil_with_a_problem_and_no_stray_read(backend):
    lua = runtime(backend)
    get = lua.eval('reader.get')
    bad = ('SPL:BADSIG', 'SPL:SHORT', 'SPL:TINY', 'SPL:PASTEND', 'ITM:CUT', 'PRO:AREACUT', 'CRE:CUT')
    for key in bad:
        kind, resref = key.split(':')
        with pytest.raises(ie.FormatError):
            PARSE[kind](FILES[key], resref)
        assert get(kind, resref) is None, key
    assert lua.eval('outside') is False
    assert len(lua.eval('reader.problems')) == len(bad)


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_lookup_maps_projectiles_caches_and_ignores_bad_keys(backend):
    lua = runtime(backend)
    lookup = lua.eval('reader.lookup')
    assert to_py(lua, lookup('PRO', 3)) == ie.parse_pro(build_pro(3), 'FIREBALL')
    assert to_py(lua, lookup('PRO', 2)) == ie.parse_pro(build_pro(2), 'ARROW')
    assert lookup('PRO', 1) is None and lookup('PRO', 99) is None
    assert to_py(lua, lookup('SPL', 'SPWI304')) == ie.parse_spl(SPL, 'SPWI304')
    fetches = lua.eval('fetches')
    lookup('SPL', 'spwi304')
    assert lua.eval('fetches') == fetches
    assert lookup('SPL', 'MISSING') is None and lookup('SPL', 'TOOLONGNAME') is None
    assert lookup('SPL', '') is None and lookup('XYZ', 'SPWI304') is None
    assert list(lua.eval('reader.problems').values()) == []
    lua.execute('reader.reset()')
    lookup('SPL', 'SPWI304')
    assert lua.eval('fetches') == fetches + 1


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_without_eeex_the_reader_declines(backend):
    lua = importlib.import_module(f'lupa.{backend}').LuaRuntime(encoding='latin-1')
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert lua.execute('''
        local r = require('adapters.eeex.resources').new({})
        return r.lookup('SPL', 'SPWI304') == nil and r.lookup('PRO', 3) == nil and #r.problems == 2
    ''') is True
