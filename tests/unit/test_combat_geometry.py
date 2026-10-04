"""Pure conservative point-geometry reducer, not native spell admission."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_combat_geometry(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / "tests/unit/combat_intent/test_geometry.lua").read_text()) == 6
