"""Check the in-game resource reader against the host parser on a whole game folder.

adapters/eeex/resources.lua reads every SPL, ITM, EFF and PRO of the folder through a fake EEex
memory that maps only the resource being read (any other read fails the run), and each record
is compared with tools/ie_resources.py. The projectile-number map is compared too. Read-only on
the game; nothing runs in the game itself.

    python -X utf8 -I tools/reader_parity.py <game_root> [lua51|luajit21]
"""
import importlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import ie_resources as ie  # noqa: E402

FAKE = '''
local fetch, ids = ...
outside = false
-- The reader parses a resource completely right after demanding it, so only the latest one is
-- mapped: a read anywhere else is a stray read.
local current, next_base = nil, 0x100000
local function byte(a)
    local m = current
    if m and a >= m.base and a < m.base + #m.data then return m.data:byte(a - m.base + 1) end
    outside = true
    error('read outside a resource')
end
local function u(a, n) local v = 0 for i = n - 1, 0, -1 do v = v * 256 + byte(a + i) end return v end
G = {EEex_ReadU8 = byte,
    EEex_ReadU16 = function(a) return u(a, 2) end, EEex_ReadU32 = function(a) return u(a, 4) end,
    EEex_Read16 = function(a) local v = u(a, 2) return v >= 32768 and v - 65536 or v end,
    EEex_Read32 = function(a) local v = u(a, 4) return v >= 2^31 and v - 2^32 or v end,
    EEex_ReadLString = function(a, n)
        local t = {}
        for i = 0, n - 1 do local b = byte(a + i) if b == 0 then break end t[#t + 1] = string.char(b) end
        return table.concat(t)
    end,
    EEex_UDToPtr = function(ud) return ud.ptr end,
    EEex_Resource_LoadIDS = function() return 'ids' end,
    EEex_Resource_IterateUnpackedIDSEntries = function(_, fn)
        for _, row in ipairs(ids) do fn(row[1], row[2], row[2]) end
    end}
G.EEex_Resource_Fetch = function(resref, ext)
    local data = fetch(resref, ext)
    if data == nil then return nil end
    local base = next_base
    next_base = next_base + 0x1000000
    return {nSize = #data, Demand = function() current = {base = base, data = data} return {ptr = base} end}
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


def main(root, backend='luajit21'):
    game = ie.Game(root)
    lua = importlib.import_module(f'lupa.{backend}').LuaRuntime(encoding='latin-1')
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    projectiles = ie.projectiles(game)
    lua.execute(FAKE, game.get, lua.table_from([lua.table_from([n - 1, r]) for n, r in sorted(projectiles.items())]))
    get, reset = lua.eval('reader.get'), lua.eval('reader.reset')
    failed = False
    for kind in ('SPL', 'ITM', 'EFF', 'PRO'):
        names = [n for n in game.names(kind) if 0 < len(n) <= 8]
        same = absent = 0
        differ = []
        for name in names:
            data = game.get(name, kind)
            try:
                expected = ie.PARSERS[kind](data, name) if data is not None else None
            except ie.FormatError:
                expected = None
            got = get(kind, name)
            got = to_py(lua, got) if got is not None else None
            if got != expected:
                differ.append(name)
            elif got is None:
                absent += 1
            else:
                same += 1
            reset()
        failed = failed or bool(differ)
        print(f'{kind}: {len(names)} resources, {same} same, {absent} unreadable by both, {len(differ)} differ {differ[:5]}',
              flush=True)
    reader_map = {}
    for n in range(1, max(projectiles, default=0) + 5):
        pro = lua.eval('reader.projectile')(n)
        if pro is not None:
            reader_map[n] = pro['resref']
    host_map = {n: r for n, r in projectiles.items() if game.get(r, 'PRO') is not None}
    print(f'projectile numbers with a PRO file: reader {len(reader_map)}, host {len(host_map)}, '
          f'equal {reader_map == host_map}')
    stray = lua.eval('outside')
    print('reads outside a resource:', stray)
    return 1 if failed or stray or reader_map != host_map else 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(*sys.argv[1:3]))
