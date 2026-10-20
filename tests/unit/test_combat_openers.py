"""The engine's openers (combat-intent/openers.lua) and the choice around them: Time Stop and
Improved Alacrity, the caster's own Time Stop, slow spells, power words; on both declared Lua
backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_openers(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_openers.lua').read_text(encoding='utf-8')) == 8
