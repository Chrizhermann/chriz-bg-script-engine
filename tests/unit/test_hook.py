"""Host contract of the BCS handoff gate on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_hook_gate(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_hook.lua').read_text(encoding='utf-8')) == 20


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_hook_boundary(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_eeex_hook.lua').read_text(encoding='utf-8')) == 10
