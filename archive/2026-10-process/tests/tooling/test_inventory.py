from __future__ import annotations

import hashlib
import json
import random

import pytest

from tools.corpus.inventory import InventoryError, SyntheticResource, build_inventory, canonical_bytes


def resource(resource_id: str, nodes: list, source_path: str = "") -> SyntheticResource:
    payload = b"BGSE-SYNTHETIC-RESOURCE-V1\n" + json.dumps({"nodes": nodes}).encode("utf-8")
    return SyntheticResource(resource_id, payload, source_path)


def corpus() -> list[SyntheticResource]:
    return [
        resource("B-XACTR0.CRE", [{"kind": "script-slot", "slot": "override", "target": "B-XBRAIN.BCS"}]),
        resource("B-XBRAIN.BCS", [
            {"kind": "dependency", "target": "B-XSPELL.SPL"},
            {"kind": "public-variable", "scope": "GLOBAL", "name": "B-XG-PHASE", "access": "read"},
        ]),
        resource("B-XSPELL.SPL", []),
        resource("B-XWATCH.BCS", [
            {"kind": "public-variable", "scope": "GLOBAL", "name": "B-XG-PHASE", "access": "write"},
        ]),
    ]


def test_shuffled_inventory_is_byte_identical_and_keeps_full_hashes() -> None:
    inputs = corpus()
    expected = canonical_bytes(build_inventory(inputs))
    for seed in range(10):
        shuffled = list(inputs)
        random.Random(seed).shuffle(shuffled)
        assert canonical_bytes(build_inventory(shuffled)) == expected
    rows = {row["id"]: row for row in build_inventory(inputs)["resources"]}
    for item in inputs:
        assert rows[item.resource_id]["sha256"] == hashlib.sha256(item.payload).hexdigest()
        assert rows[item.resource_id]["byteLength"] == len(item.payload)


def test_source_paths_are_dropped_not_used_as_resource_identity() -> None:
    first = resource("B-XSPELL.SPL", [], "C:/Users/Example/source")
    second = resource("b-xspell.spl", [], "/home/example/source")
    encoded = canonical_bytes(build_inventory([first]))
    assert encoded == canonical_bytes(build_inventory([second]))
    assert b"Users" not in encoded and b"home" not in encoded


def test_slot_dependencies_and_public_variables_retain_positions() -> None:
    rows = {row["id"]: row for row in build_inventory(corpus())["resources"]}
    assert rows["B-XACTR0.CRE"]["scriptSlots"] == [
        {"position": 0, "slot": "override", "target": "B-XBRAIN.BCS"},
    ]
    assert rows["B-XACTR0.CRE"]["dependencies"] == [
        {"position": 0, "kind": "script-slot", "target": "B-XBRAIN.BCS"},
    ]
    assert rows["B-XBRAIN.BCS"]["publicVariables"] == [
        {"position": 1, "scope": "GLOBAL", "name": "B-XG-PHASE", "access": "read"},
    ]


def test_empty_missing_and_conflicting_slots_are_distinct() -> None:
    known_empty = {"kind": "script-slot", "slot": "override", "target": None}
    valid = build_inventory([resource("B-XACTR0.CRE", [known_empty])])["resources"][0]
    assert valid["scriptSlots"][0]["target"] is None
    assert valid["opaqueNodes"] == valid["dependencies"] == []
    missing = {"kind": "script-slot", "slot": "override"}
    invalid = build_inventory([resource("B-XACTR0.CRE", [missing])])["resources"][0]
    assert invalid["scriptSlots"] == [] and invalid["opaqueNodes"]
    conflict = build_inventory([resource("B-XACTR0.CRE", [known_empty, known_empty])])["resources"][0]
    assert len(conflict["scriptSlots"]) == 2
    assert conflict["opaqueNodes"] == [{"position": 1, "reason": "duplicate-slot"}]


@pytest.mark.parametrize("node", [
    {"kind": "future-action", "private": "C:/Users/Example/hidden"},
    {"kind": "dependency", "target": "B-XSPELL.SPL", "ignored": True},
    {"kind": "public-variable", "scope": "LOCALS", "name": "Phase", "access": "write"},
    {"kind": "dependency", "target": "../outside"},
    "unknown-record", None,
])
def test_unknown_or_invalid_forms_are_opaque_without_leaking_raw_content(node) -> None:
    result = build_inventory([resource("B-XBRAIN.BCS", [node])])
    assert result["resources"][0]["opaqueNodes"]
    assert b"Users" not in canonical_bytes(result)
    assert result["runtimeActivation"] is False


@pytest.mark.parametrize("payload", [
    b"BCS-like original test bytes, not a real decompile",
    b'BGSE-SYNTHETIC-RESOURCE-V1\n{"nodes":[],"unhandled":true}',
    b'BGSE-SYNTHETIC-RESOURCE-V1\n{"nodes":[],"nodes":[]}',
    b'BGSE-SYNTHETIC-RESOURCE-V1\n{"nodes":NaN}',
])
def test_unknown_envelope_is_opaque(payload: bytes) -> None:
    result = build_inventory([SyntheticResource("B-XBRAIN.BCS", payload)])
    assert result["resources"][0]["opaqueNodes"][0]["position"] == -1


def test_duplicate_case_insensitive_identity_is_an_error() -> None:
    with pytest.raises(InventoryError, match="duplicate"):
        build_inventory([resource("B-XSPELL.SPL", []), resource("b-xspell.spl", [])])


def test_node_sequence_is_not_sorted_away() -> None:
    nodes = [{"kind": "dependency", "target": target} for target in ("B-XSPELL.SPL", "B-XWATCH.BCS")]
    first = build_inventory([resource("B-XBRAIN.BCS", nodes)])
    second = build_inventory([resource("B-XBRAIN.BCS", list(reversed(nodes)))])
    assert first["resources"][0]["dependencies"][0]["target"] == "B-XSPELL.SPL"
    assert second["resources"][0]["dependencies"][0]["target"] == "B-XWATCH.BCS"
    assert first["inventoryDigest"] != second["inventoryDigest"]


@pytest.mark.parametrize("bad_id", ["../file", "C:/source.BCS", "toolongname.CRE", "B-XACTR0.EXE"])
def test_invalid_identity_is_refused_without_private_diagnostic(bad_id: str) -> None:
    with pytest.raises(InventoryError) as error:
        build_inventory([SyntheticResource(bad_id, b"")])
    assert bad_id not in str(error.value)
