"""Exact claims over a declared synthetic graph only; never runtime ownership."""
from __future__ import annotations

import re
from typing import Any, Iterable

from .inventory import InventoryError, SyntheticResource, build_inventory, canonical_bytes, resource_identity


def make_claim(
    resources: Iterable[SyntheticResource], adapter_id: str, domain: str, roots: list[str],
    *, stack_id: str = "fixture-stack-v1",
) -> dict:
    """Bind explicit roots to exact declared transitive and public-variable closure.

    GLOBAL reverse references include all declared readers and writers. Opaque
    material outside that graph is not claimed; this does not prove that real
    external controllers or undeclared readers/writers are absent.
    """
    if (
        not isinstance(adapter_id, str) or len(adapter_id) > 64
        or not re.fullmatch(r"B-/(combat|worldflow)/[a-z0-9]+(?:-[a-z0-9]+)*", adapter_id)
        or domain not in ("CombatIntent", "WorldFlow")
        or adapter_id.split("/")[1] != {"CombatIntent": "combat", "WorldFlow": "worldflow"}[domain]
    ):
        raise InventoryError("invalid or conflicting adapter/domain identity")
    if not isinstance(roots, list) or not roots:
        raise InventoryError("explicit nonempty resource roots required")
    canonical_roots = [resource_identity(value) for value in roots]
    if len(set(canonical_roots)) != len(canonical_roots):
        raise InventoryError("duplicate case-insensitive claim root")
    inventory = build_inventory(resources, stack_id=stack_id)
    rows = {row["id"]: row for row in inventory["resources"]}
    reverse_variables: dict[tuple[str, str], set[str]] = {}
    for row in rows.values():
        for variable in row["publicVariables"]:
            key = (variable["scope"], variable["name"].upper())
            reverse_variables.setdefault(key, set()).add(row["id"])
    pending = set(canonical_roots)
    visited: set[str] = set()
    reasons: set[str] = set()
    hashes = []
    while pending:
        identity = min(pending)
        pending.remove(identity)
        if identity in visited:
            continue
        visited.add(identity)
        if identity not in rows:
            reasons.add("missing:" + identity)
            continue
        row = rows[identity]
        hashes.append({"id": identity, "sha256": row["sha256"]})
        if row["opaqueNodes"]:
            reasons.add("opaque:" + identity)
        pending.update(edge["target"] for edge in row["dependencies"])
        for variable in row["publicVariables"]:
            pending.update(reverse_variables[(variable["scope"], variable["name"].upper())])
        pending.difference_update(visited)
    return {
        "schemaVersion": 1, "profile": "synthetic-exact-claim-v1",
        "adapterId": adapter_id, "domain": domain, "roots": sorted(canonical_roots),
        "inventoryDigest": inventory["inventoryDigest"],
        "hashes": sorted(hashes, key=lambda row: row["id"]),
        "eligibleForAnalysis": not reasons, "reasons": sorted(reasons),
        "runtimeActivation": False, "fallback": "legacy",
    }


def claim_matches(
    claim: Any, resources: Iterable[SyntheticResource], *, stack_id: str = "fixture-stack-v1",
) -> bool:
    """Require exact equality with a fresh eligible host claim, never a hash subset.

    Whole-inventory drift invalidates even unrelated changes. Recreating a claim
    is explicit analysis, not automatic reactivation, authorization, or proof of
    effective-install/dependency discovery completeness.
    """
    try:
        if not isinstance(claim, dict) or claim.get("eligibleForAnalysis") is not True:
            return False
        expected = make_claim(resources, claim["adapterId"], claim["domain"], claim["roots"], stack_id=stack_id)
        return expected["eligibleForAnalysis"] and canonical_bytes(claim) == canonical_bytes(expected)
    except (InventoryError, KeyError, ValueError, TypeError, RecursionError):
        return False
