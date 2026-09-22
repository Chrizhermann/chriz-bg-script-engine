"""Offline documentation contract; does not fetch, parse SSL, or execute a game."""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path

import pytest

from test_research_evidence_schema import load_schema, validate_project_subset


ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / "docs/research/scs-source-pilot.evidence.json"
REVISION = "5dc240e9ff85d3909b6436e54b56297d3b61e33b"
MEMOS = (
    "SCS-01-generation-pipeline.md",
    "SCS-02-mage-priority-taxonomy.md",
    "SCS-03-prebuff-accounting.md",
    "SCS-04-target-and-protection-rules.md",
    "SCS-05-encounter-exceptions.md",
    "SCS-06-difficulty-randomness-and-fairness.md",
)


def validate_source_checkpoint(record: dict) -> None:
    validate_project_subset(record, load_schema())
    assert record["outcome"] == "Conditional"
    assert record["environment"]["kind"] == "env:host"
    assert record["environment"]["gameStateAccess"] == "none"
    assert record["evidenceLayers"] == ["evidence:E1"]
    assert record["nextDecision"]["fallback"] == "no-runtime-claim"
    artifacts = record["artifacts"]
    ids = [artifact["id"] for artifact in artifacts]
    assert len(ids) == len(set(ids)), "ambiguous artifact IDs"
    claim_ids = [claim["id"] for claim in record["claims"]]
    assert len(claim_ids) == len(set(claim_ids)), "ambiguous claim IDs"
    for artifact in artifacts:
        assert artifact["revision"] == REVISION
        assert artifact["version"] == "v35.21"
        assert artifact["kind"] == "source-file"
        assert artifact["classification"] == "upstream-source"
        assert artifact["redistributionStatus"] == "reference-only"
        assert artifact["evidenceLayers"] == ["evidence:E1"]
        assert artifact["digest"]["algorithm"] == "sha256"
        assert re.fullmatch(r"[A-F0-9]{64}", artifact["digest"]["value"])
        assert artifact["sourcePath"].startswith(
            "https://github.com/Gibberlings3/SwordCoastStratagems/blob/"
            + REVISION + "/stratagems/"
        )
    for claim in record["claims"]:
        assert set(claim["evidenceRefs"]) <= set(ids), "unresolved evidence"


def load_record() -> dict:
    return json.loads(RECORD.read_text(encoding="utf-8"))


def test_source_checkpoint_is_pinned_bounded_and_reference_only() -> None:
    validate_source_checkpoint(load_record())


@pytest.mark.parametrize("change", ["runtime", "game", "reuse", "revision", "digest", "ref", "duplicate"])
def test_source_checkpoint_rejects_evidence_promotion_and_broken_identity(change: str) -> None:
    record = copy.deepcopy(load_record())
    if change == "runtime":
        record["evidenceLayers"] = ["evidence:E4"]
    elif change == "game":
        record["environment"]["gameStateAccess"] = "read-only"
    elif change == "reuse":
        record["artifacts"][0]["redistributionStatus"] = "redistributable"
    elif change == "revision":
        record["artifacts"][0]["revision"] = "main"
    elif change == "digest":
        record["artifacts"][0]["digest"]["value"] = "A" * 40
    elif change == "ref":
        record["claims"][0]["evidenceRefs"] = ["artifact:missing"]
    elif change == "duplicate":
        record["artifacts"].append(copy.deepcopy(record["artifacts"][0]))
    with pytest.raises(AssertionError):
        validate_source_checkpoint(record)


@pytest.mark.parametrize("name", MEMOS)
def test_each_memo_has_scope_evidence_and_open_questions(name: str) -> None:
    text = (ROOT / "docs/research" / name).read_text(encoding="utf-8")
    for field in ("Outcome", "Question", "Environment", "Method", "Observations",
                  "Counterevidence", "Artifacts", "Applicable evidence",
                  "Residual uncertainty", "Next decision"):
        assert f"**{field}:**" in text
    assert "source-only" in text
    assert "scs-source-pilot.evidence.json" in text


@pytest.mark.parametrize("family", ["mage", "prebuff"])
def test_ledgers_record_unresolved_effective_evidence_and_distribution(family: str) -> None:
    text = (ROOT / f"docs/provenance/scs/{family}-pilot-ledger.md").read_text(encoding="utf-8")
    for label in ("Effective artifacts", "Preserved rules", "Intentional changes", "Omissions",
                  "Opaque cases", "Tests", "Attribution", "Distribution decision", "Review"):
        assert f"**{label}:**" in text
    assert "not collected" in text
    assert "reference-only" in text


@pytest.mark.parametrize("relative_path", [
    "docs/research/SCS-01-generation-pipeline.md",
    "docs/provenance/scs/mage-pilot-ledger.md",
])
def test_main_template_selection_freezes_inputs_against_later_overrides(relative_path: str) -> None:
    text = (ROOT / relative_path).read_text(encoding="utf-8")
    for constraint in ("kit=enchanter", "detect_invisible=0", "race=HUMAN", "472-492"):
        assert constraint in text
