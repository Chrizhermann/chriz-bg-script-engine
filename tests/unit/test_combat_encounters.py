"""The designed encounters (combat-intent/encounters.lua): the creatures' orders pass the orders'
check, the book hands out copies, the light protagonist preference, and the runtime handing the
orders to the engine's choice; on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_encounters(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_encounters.lua').read_text(encoding='utf-8')) == 5
