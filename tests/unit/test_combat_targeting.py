"""Targeting rules (combat-intent/targeting.lua) and the fight director
(combat-intent/director.lua) on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def run(backend, name):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    return runtime.execute((ROOT / 'tests/unit/combat_intent' / name).read_text(encoding='utf-8'))


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_targeting(backend):
    assert run(backend, 'test_targeting.lua') == 7


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_director(backend):
    assert run(backend, 'test_director.lua') == 11
