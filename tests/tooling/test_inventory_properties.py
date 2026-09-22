"""Independent bounded Task 5 oracles over original, in-memory toy resources.

These tests prove no real resource parsing, controller discovery, or runtime
ownership. The graph oracle uses integer sets before serializing the toy input.
"""
from __future__ import annotations

import json
import random
from dataclasses import replace

import pytest

from tools.corpus.exact_hash import claim_matches, make_claim
from tools.corpus.inventory import SyntheticResource, build_inventory, canonical_bytes


def _identity(index: int) -> str:
    return f"B-X{index:05}.BCS"


def _resource(index: int, nodes: list) -> SyntheticResource:
    payload = b"BGSE-SYNTHETIC-RESOURCE-V1\n" + json.dumps({"nodes": nodes}).encode("utf-8")
    return SyntheticResource(_identity(index), payload, "C:/Users/Example/private")


def _claim(resources: list[SyntheticResource]) -> dict:
    return make_claim(resources, "B-/worldflow/property-probe", "WorldFlow", [_identity(0)])


@pytest.mark.parametrize("seed", range(100))
def test_seeded_graph_matches_independent_fixed_point(seed: int) -> None:
    rng = random.Random(seed)
    dependencies = [{j for j in range(8) if rng.randrange(5) == 0} for _ in range(8)]
    variables = [{j for j in range(3) if rng.randrange(4) == 0} for _ in range(8)]
    expected = {0}
    while True:
        used_variables = set().union(*(variables[i] for i in expected))
        expanded = expected.union(*(dependencies[i] for i in expected))
        expanded.update(i for i in range(8) if variables[i] & used_variables)
        if expanded == expected:
            break
        expected = expanded

    resources = []
    for i in range(8):
        nodes = [{"kind": "dependency", "target": _identity(j)} for j in sorted(dependencies[i])]
        nodes += [
            {"kind": "public-variable", "scope": "GLOBAL",
             "name": f"Public{j}" if i % 2 else f"PUBLIC{j}",
             "access": "read" if i % 3 else "write"}
            for j in sorted(variables[i])
        ]
        resources.append(_resource(i, nodes))
    original = _claim(resources)
    assert {row["id"] for row in original["hashes"]} == {_identity(i) for i in expected}
    assert original["eligibleForAnalysis"] is True
    assert original["runtimeActivation"] is False
    assert original["fallback"] == "legacy"

    rng.shuffle(resources)
    assert canonical_bytes(_claim(resources)) == canonical_bytes(original)
    assert claim_matches(original, resources)
    resources[0] = replace(resources[0], payload=resources[0].payload + b" ")
    # Byte drift is conservatively invalidating even outside the selected closure.
    assert _claim(resources)["eligibleForAnalysis"] is True
    assert not claim_matches(original, resources)


_BAD_VALUES = [None, True, False, 0, 1, 1.5, [], {}, "", "/home/private",
               "C:/Users/Private", ["bad"], {"kind": "dependency"}]


@pytest.mark.parametrize("value", _BAD_VALUES, ids=[f"value-{i}" for i in range(13)])
@pytest.mark.parametrize("field", range(7), ids=["kind", "dependency", "slot-name", "slot-target",
                                              "variable-name", "variable-scope", "variable-access"])
def test_malformed_node_matrix_is_opaque_without_path_leak(value, field: int) -> None:
    nodes = [
        {"kind": value},
        {"kind": "dependency", "target": value},
        {"kind": "script-slot", "slot": value, "target": None},
        {"kind": "script-slot", "slot": "override", "target": value},
        {"kind": "public-variable", "scope": "GLOBAL", "name": value, "access": "read"},
        {"kind": "public-variable", "scope": value, "name": "Valid", "access": "read"},
        {"kind": "public-variable", "scope": "GLOBAL", "name": "Valid", "access": value},
    ]
    resources = [_resource(0, [nodes[field]])]
    inventory = build_inventory(resources)
    candidate = _claim(resources)
    # A null target is the one deliberate valid-empty control among 91 vectors.
    valid_empty_slot = field == 3 and value is None
    assert bool(inventory["resources"][0]["opaqueNodes"]) is not valid_empty_slot
    assert candidate["eligibleForAnalysis"] is valid_empty_slot
    assert claim_matches(candidate, resources) is valid_empty_slot
    assert candidate["runtimeActivation"] is False
    encoded = canonical_bytes({"inventory": inventory, "claim": candidate})
    assert b"/home/private" not in encoded and b"C:/Users/Private" not in encoded
    assert b"C:/Users/Example/private" not in encoded
