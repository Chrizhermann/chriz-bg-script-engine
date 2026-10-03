import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_observer_kernel(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / "tests/unit/kernel/test_bootstrap.lua").read_text()) == 5
    from tools.build_observer_bundle import build
    isolated = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    isolated.execute("package.path=''; package.cpath=''")
    module = isolated.execute(build())
    assert module.new is not None and module.eeex is not None
    assert isolated.eval("package.loaded['kernel.bootstrap']") is None
