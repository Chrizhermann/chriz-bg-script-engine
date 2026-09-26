"""Run the seven pure Lua cases on both explicit ADR-0006 backends, then check output shape."""
import importlib
import json
from pathlib import Path

import pytest

from test_research_evidence_schema import validate_project_subset

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_capability_contract(backend):
    pytest.importorskip("lupa", reason="optional lua-test extra is required for E2 Lua evidence")
    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    profile = runtime.execute(
        (ROOT / "tests/unit/kernel/test_capabilities.lua").read_text(encoding="utf-8"),
        str(ROOT / "adapters/eeex/capabilities.lua"),
    )
    # The contract has one ordered array of flat, scalar-only records.
    record = dict(profile.items())
    record["capabilities"] = [dict(item.items()) for _, item in profile["capabilities"].items()]
    schema = json.loads((ROOT / "schemas/capability-profile.schema.json").read_text(encoding="utf-8"))
    validate_project_subset(record, schema)
    assert len({item["id"] for item in record["capabilities"]}) == len(record["capabilities"])
