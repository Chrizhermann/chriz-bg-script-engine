"""Run the pure diagnostic contract under both supported Lua runtimes."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_diagnostics(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    assert runtime.execute(
        (ROOT / "tests/unit/kernel/test_diagnostics.lua").read_text(encoding="utf-8"),
        str(ROOT / "experiments/persistence/diagnostics.lua"),
    ) == 7
