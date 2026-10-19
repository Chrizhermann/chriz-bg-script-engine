"""Touch charges (combat-intent/touch.lua) and the choice around them: touch spells, the chance to
hit, what keeps a charge off an enemy, the touch option and the strike; on both declared Lua
backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_touch(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_touch.lua').read_text(encoding='utf-8')) == 8
