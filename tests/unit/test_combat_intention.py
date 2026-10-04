"""One-next-step pure plans; these tests cannot dispatch a game action."""
import importlib
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[2]

@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_combat_intention(backend):
    lua = importlib.import_module('lupa.' + backend).LuaRuntime()
    lua.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert lua.execute((ROOT/'tests/unit/combat_intent/test_intention.lua').read_text()) == 5
