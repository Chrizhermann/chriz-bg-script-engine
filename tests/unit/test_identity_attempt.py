"""Pure identity resolution and action attempts on both Lua backends."""

import importlib
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
@pytest.mark.parametrize("module", ["identity", "action_attempt"])
def test_identity_attempt(module, backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    assert runtime.execute(
        (ROOT / f"tests/unit/kernel/test_{module}.lua").read_text(encoding="utf-8"),
        str(ROOT / f"kernel/{module}.lua"),
    ) == 5
