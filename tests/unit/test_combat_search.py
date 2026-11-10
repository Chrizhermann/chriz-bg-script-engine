"""The engine's own search for enemies a creature cannot see (combat-intent/search.lua): patience by
wit, the tactics draw, clue order, the walk, detection, giving up and guarding; on both declared Lua
backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_search(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_search.lua').read_text(encoding='utf-8')) == 13
