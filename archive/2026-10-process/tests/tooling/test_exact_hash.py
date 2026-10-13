from __future__ import annotations

import copy
from dataclasses import replace

import pytest

from tools.corpus.exact_hash import claim_matches, make_claim
from tools.corpus.inventory import InventoryError, canonical_bytes
from test_inventory import corpus, resource


def claim(inputs=None, **kwargs) -> dict:
    return make_claim(corpus() if inputs is None else inputs, "B-/combat/synthetic-probe", "CombatIntent", ["B-XACTR0.CRE"], **kwargs)


def test_transitive_and_public_variable_closure_is_exact_and_analysis_only() -> None:
    result = claim()
    assert result["eligibleForAnalysis"] is True
    assert result["reasons"] == []
    assert {row["id"] for row in result["hashes"]} == {item.resource_id for item in corpus()}
    assert result["runtimeActivation"] is False and result["fallback"] == "legacy"
    assert claim_matches(result, list(reversed(corpus()))) is True
    assert canonical_bytes(result) == canonical_bytes(claim(list(reversed(corpus()))))


def test_every_byte_of_resource_and_transitive_dependencies_is_bound() -> None:
    inputs = corpus()
    original = claim(inputs)
    for resource_index, item in enumerate(inputs):
        for byte_index in range(len(item.payload)):
            changed = bytearray(item.payload)
            changed[byte_index] ^= 1
            modified = list(inputs)
            modified[resource_index] = replace(item, payload=bytes(changed))
            assert not claim_matches(original, modified), (resource_index, byte_index)


def test_harmless_whitespace_and_new_unrelated_content_still_invalidate() -> None:
    inputs = corpus()
    original = claim(inputs)
    changed = [replace(inputs[0], payload=inputs[0].payload + b" \r\n"), *inputs[1:]]
    assert claim(changed)["eligibleForAnalysis"] is True
    assert not claim_matches(original, changed)
    assert not claim_matches(original, inputs + [resource("B-XEXTRA.BCS", [])])
    assert not claim_matches(original, inputs, stack_id="changed-stack")


def test_missing_dependency_and_opaque_declared_dependency_block_claim() -> None:
    missing = claim([item for item in corpus() if item.resource_id != "B-XSPELL.SPL"])
    assert missing["eligibleForAnalysis"] is False
    assert "missing:B-XSPELL.SPL" in missing["reasons"]
    inputs = corpus()
    inputs[2] = resource("B-XSPELL.SPL", [{"kind": "unknown-ability"}])
    opaque = claim(inputs)
    assert opaque["eligibleForAnalysis"] is False
    assert "opaque:B-XSPELL.SPL" in opaque["reasons"]
    assert not claim_matches(opaque, inputs)


def test_unrelated_opaque_resource_is_not_claimed() -> None:
    inputs = corpus() + [resource("B-XOTHER.BCS", [{"kind": "opaque"}])]
    result = claim(inputs)
    assert result["eligibleForAnalysis"] is True
    assert "B-XOTHER.BCS" not in {row["id"] for row in result["hashes"]}
    assert result["runtimeActivation"] is False  # not proof of external-control completeness


def test_cycles_terminate_without_dropping_dependencies() -> None:
    inputs = corpus()
    inputs[2] = resource("B-XSPELL.SPL", [{"kind": "dependency", "target": "B-XACTR0.CRE"}])
    assert claim(inputs)["eligibleForAnalysis"] is True
    assert len(claim(inputs)["hashes"]) == 4


def test_case_insensitive_public_writer_reference_is_included() -> None:
    inputs = corpus()
    inputs[3] = resource("B-XWATCH.BCS", [
        {"kind": "public-variable", "scope": "GLOBAL", "name": "b-xg-phase", "access": "write"},
    ])
    assert "B-XWATCH.BCS" in {row["id"] for row in claim(inputs)["hashes"]}


@pytest.mark.parametrize("roots", [[], ["B-XACTR0.CRE", "b-xactr0.cre"], "B-XACTR0.CRE"])
def test_ambiguous_or_empty_root_selectors_are_rejected(roots) -> None:
    with pytest.raises(InventoryError):
        make_claim(corpus(), "B-/combat/synthetic-probe", "CombatIntent", roots)


@pytest.mark.parametrize("change", ["drop-hash", "extra-field", "activate", "int-boolean", "change-domain", "missing-field"])
def test_modified_or_underspecified_claim_is_not_accepted(change: str) -> None:
    candidate = copy.deepcopy(claim())
    if change == "drop-hash":
        candidate["hashes"].pop()
    elif change == "extra-field":
        candidate["ignored"] = True
    elif change == "activate":
        candidate["runtimeActivation"] = True
    elif change == "int-boolean":
        candidate["schemaVersion"] = True
    elif change == "change-domain":
        candidate["domain"] = "WorldFlow"
    else:
        del candidate["inventoryDigest"]
    assert not claim_matches(candidate, corpus())
