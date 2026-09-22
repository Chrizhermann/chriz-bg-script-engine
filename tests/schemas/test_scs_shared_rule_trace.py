"""Source-research record checks only; no SCS parser, rule simulation or network access."""
from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from test_scs_source_checkpoint import validate_source_checkpoint


ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / "docs/research/scs-shared-rules.evidence.json"
MEMO = ROOT / "docs/research/SCS-shared-rule-expansion.md"
REQUIRED_CLAIMS = {
    "claim:scs-shared-library-order",
    "claim:scs-shared-library-merge",
    "claim:scs-shared-dispel-macros",
    "claim:scs-shared-response-expansion",
    "claim:scs-shared-slot-transform",
}


def load_record() -> dict:
    return json.loads(RECORD.read_text(encoding="utf-8"))


def validate_trace(record: dict) -> None:
    validate_source_checkpoint(record)
    assert record["id"] == "research:scs-shared-rules-source-checkpoint"
    assert {claim["id"] for claim in record["claims"]} == REQUIRED_CLAIMS
    artifacts = {item["id"]: item for item in record["artifacts"]}
    bindings = {
        "claim:scs-shared-library-order": {"artifact:scs3521-always", "artifact:scs3521-ssl-driver"},
        "claim:scs-shared-library-merge": {"artifact:scs3521-ssl-compiler", "artifact:scs3521-library", "artifact:scs3521-library-sr"},
        "claim:scs-shared-dispel-macros": {"artifact:scs3521-library", "artifact:scs3521-first-dispel"},
        "claim:scs-shared-response-expansion": {"artifact:scs3521-ssl-compiler", "artifact:scs3521-first-dispel"},
        "claim:scs-shared-slot-transform": {"artifact:scs3521-cre-helper", "artifact:scs3521-stratagems-shared", "artifact:scs3521-mage-shared"},
    }
    for claim in record["claims"]:
        assert bindings[claim["id"]] <= set(claim["evidenceRefs"]), "missing source-chain link"
    # Reused artifact IDs identify the same bytes, not a silently revised source.
    previous = json.loads((ROOT / "docs/research/scs-source-pilot.evidence.json").read_text(encoding="utf-8"))
    for artifact in previous["artifacts"]:
        if artifact["id"] in artifacts:
            assert artifacts[artifact["id"]] == artifact, "reassigned artifact identity"


def test_shared_source_trace_preserves_claim_chains_and_evidence_scope() -> None:
    validate_trace(load_record())


@pytest.mark.parametrize("claim_id", sorted(REQUIRED_CLAIMS))
def test_missing_source_chain_is_rejected(claim_id: str) -> None:
    record = copy.deepcopy(load_record())
    for claim in record["claims"]:
        if claim["id"] == claim_id:
            claim["evidenceRefs"] = ["artifact:scs3521-library"]
    with pytest.raises(AssertionError, match="missing source-chain link"):
        validate_trace(record)


def test_reused_artifact_cannot_silently_change_bytes() -> None:
    record = copy.deepcopy(load_record())
    next(a for a in record["artifacts"] if a["id"] == "artifact:scs3521-mage-shared")["digest"]["value"] = "A" * 64
    with pytest.raises(AssertionError, match="reassigned artifact identity"):
        validate_trace(record)


def test_memo_records_the_nonobvious_source_boundaries() -> None:
    text = MEMO.read_text(encoding="utf-8")
    for field in ("Outcome", "Question", "Environment", "Versions and fingerprints", "Method",
                  "Observations", "Counterevidence", "Artifacts", "Applicable evidence",
                  "Residual uncertainty", "Next decision"):
        assert f"**{field}:**" in text
    for term in ("append", "TRIGGER_REPLACE", "SIAbjuration", "autolib", "library_freeactionstun",
                 "ssl.exe", "LastSeenBy", "OnContinue", "merge_scripts", "source-only"):
        assert term in text
    assert "scs-shared-rules.evidence.json" in text
