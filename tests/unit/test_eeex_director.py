"""EEex side of the fight director (adapters/eeex/sense.lua, adapters/eeex/director.lua)
against fake engine globals, on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_director(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_eeex_director.lua').read_text(encoding='utf-8')) == 11
