"""The engine's own defences (combat-intent/defence.lua) and threat picture
(combat-intent/threat.lua) on synthetic spells and frames, on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_defence(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_defence.lua').read_text(encoding='utf-8')) == 8
