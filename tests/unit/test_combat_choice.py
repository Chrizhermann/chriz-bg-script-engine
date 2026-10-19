"""The engine's own attack choice (combat-intent/choice.lua, ids.lua, mind.lua) and its EEex
side (adapters/eeex/choice.lua) against fake engine globals, on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def run(backend, name):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    return runtime.execute((ROOT / name).read_text(encoding='utf-8'))


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_choice(backend):
    assert run(backend, 'tests/unit/combat_intent/test_choice.lua') == 16


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_choice(backend):
    assert run(backend, 'tests/unit/kernel/test_eeex_choice.lua') == 19
