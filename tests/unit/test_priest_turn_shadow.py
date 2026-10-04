"""SCS-derived bounded priest shadow scenarios; no native action or asset."""
import importlib
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[2]

@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_priest_turn_shadow(backend):
    lua = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert lua.execute((ROOT / "tests/scenarios/combat/priest-turn/decisions.lua").read_text()) == 5
