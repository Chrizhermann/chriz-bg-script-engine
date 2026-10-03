"""One combined bridge contract, exercised on both declared Lua backends."""
import importlib
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_research_bridge(backend):
    lua = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    assert lua.execute(
        (ROOT / "tests/unit/kernel/test_research_bridge.lua").read_text(encoding="utf-8"),
        str(ROOT / "experiments/bridge/B-XBRDG0.lua"),
    ) is True
    # Execute the actual BAF payloads, not a retyped equivalent: Lua long-string
    # call syntax can compile successfully while doing the wrong thing at runtime.
    expressions = re.findall(
        r'EEex_Lua(?:Trigger|Action)\("([^"\n]+)"\)',
        (ROOT / "experiments/bridge/B-XBRSC0.baf").read_text(encoding="utf-8"),
    )
    assert len(expressions) == 2
    lua.execute("""
        local factory = assert(loadfile(...))()
        _G['B-'] = {bridge=factory.new(function() return true end)}
        _G['B-'].bridge.arm(42, 'allow')
        EEex_LuaTrigger_Object = {m_id=42}
        EEex_LuaAction_Object = {m_id=42}
    """, str(ROOT / "experiments/bridge/B-XBRDG0.lua"))
    assert lua.execute(expressions[0]) is True
    lua.execute(expressions[1])
    assert lua.execute("return _G['B-'].bridge.snapshot().noted") is True
    lua.execute("_G['B-'] = nil")
    assert lua.execute(expressions[0]) is False
    lua.execute(expressions[1])
