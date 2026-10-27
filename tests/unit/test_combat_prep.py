"""SCS's preparation, phase 1 (combat-intent/prep.lua): which of SCS's preparation blocks the engine
holds back (first-round casts, and what a creature's orders name), and the orders' prep and prepSkip;
on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_prep(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_prep.lua').read_text(encoding='utf-8')) == 3
