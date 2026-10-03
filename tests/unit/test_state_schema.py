"""Focused, research-only persistence contract on both declared Lua runtimes."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_state_schema(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    assert runtime.execute(
        (ROOT / "tests/unit/kernel/test_state_schema.lua").read_text(encoding="utf-8"),
        str(ROOT / "experiments/persistence/state_schema.lua"),
    ) == 8
