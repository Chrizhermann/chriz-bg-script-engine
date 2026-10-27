"""A thief's own hide (combat-intent/stealth.lua): who can hide by its skill, and when a thief that
sees no enemy hides, by its wit or its orders, one try a round; on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_stealth(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_stealth.lua').read_text(encoding='utf-8')) == 7
