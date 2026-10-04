"""Pure decision and replay contract; no engine or gameplay dispatch."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_combat_decision(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / "tests/unit/combat_intent/test_decision.lua").read_text()) == 5
