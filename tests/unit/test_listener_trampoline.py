"""Focused observer experiment behavior on the two declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_listener_trampoline(backend):
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    assert runtime.execute(
        (ROOT / "tests/unit/kernel/test_listener_trampoline.lua").read_text(encoding="utf-8"),
        str(ROOT / "experiments/eeex-observer/B-XOBS00.lua"),
    ) == 7
