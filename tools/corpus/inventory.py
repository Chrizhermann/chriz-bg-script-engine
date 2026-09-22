"""Provisional Task 5 inventory of an original, explicitly synthetic toy format.

No filesystem/game reader, BCS/DLG parser, or runtime activation exists here. The
payload binds every declaration to its full-resource hash. Unknown forms remain
opaque. Source paths are diagnostic input only and never enter output or errors.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from typing import Any, Iterable


MARKER = b"BGSE-SYNTHETIC-RESOURCE-V1\n"
RESOURCE_ID = re.compile(r"[A-Z0-9_#-]{1,8}\.(?:CRE|BCS|DLG|ARE|SPL|ITM|PRO|IDS|2DA)")
SLOTS = {"override", "class", "race", "general", "default", "area"}
MAX_PAYLOAD = 1048576


class InventoryError(ValueError):
    """Malformed or ambiguous host inventory input; no claim may use it."""


@dataclass(frozen=True)
class SyntheticResource:
    resource_id: str
    payload: bytes
    source_path: str = ""


def canonical_bytes(value: Any) -> bytes:
    """Canonical host JSON; never a semantic normalization of resource bytes."""
    return (json.dumps(value, ensure_ascii=True, allow_nan=False, sort_keys=True,
                       separators=(",", ":")) + "\n").encode("utf-8")


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def resource_identity(value: str) -> str:
    if not isinstance(value, str) or not value.isascii() or not RESOURCE_ID.fullmatch(value.upper()):
        raise InventoryError("invalid typed resource identity")
    return value.upper()


def _unique_object(pairs: list[tuple[str, Any]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def _invalid_constant(_: str) -> None:
    raise ValueError("non-finite constant")


def _parse_nodes(payload: bytes) -> tuple[list, str | None]:
    if not payload.startswith(MARKER):
        return [], "unsupported-format"
    try:
        document = json.loads(payload[len(MARKER):].decode("utf-8"),
                              object_pairs_hook=_unique_object, parse_constant=_invalid_constant)
    except (ValueError, RecursionError):
        return [], "malformed-document"
    if not isinstance(document, dict) or set(document) != {"nodes"} or not isinstance(document["nodes"], list):
        return [], "malformed-document"
    return document["nodes"], None


def _declaration(row: dict, node: Any, position: int, slots: set[str]) -> None:
    def opaque(reason: str) -> None:
        row["opaqueNodes"].append({"position": position, "reason": reason})

    if not isinstance(node, dict) or not isinstance(node.get("kind"), str):
        opaque("unknown-node")
        return
    kind = node["kind"]
    if kind == "dependency":
        if set(node) != {"kind", "target"}:
            opaque("invalid-node")
            return
        try:
            target = resource_identity(node["target"])
        except InventoryError:
            opaque("invalid-node")
            return
        row["dependencies"].append({"position": position, "kind": "declared", "target": target})
    elif kind == "script-slot":
        if set(node) != {"kind", "slot", "target"} or not isinstance(node["slot"], str) or node["slot"] not in SLOTS:
            opaque("invalid-node")
            return
        try:
            target = None if node["target"] is None else resource_identity(node["target"])
        except InventoryError:
            opaque("invalid-node")
            return
        if target is not None and not target.endswith(".BCS"):
            opaque("invalid-node")
            return
        slot = node["slot"]
        row["scriptSlots"].append({"position": position, "slot": slot, "target": target})
        if target is not None:
            row["dependencies"].append({"position": position, "kind": "script-slot", "target": target})
        if slot in slots:
            opaque("duplicate-slot")
        slots.add(slot)
    elif kind == "public-variable":
        if (
            set(node) != {"kind", "scope", "name", "access"}
            or node["scope"] != "GLOBAL"
            or not isinstance(node["name"], str)
            or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,31}", node["name"])
            or not isinstance(node["access"], str) or node["access"] not in {"read", "write"}
        ):
            opaque("invalid-node")
            return
        row["publicVariables"].append({"position": position, "scope": "GLOBAL",
                                       "name": node["name"], "access": node["access"]})
    else:
        opaque("unknown-node")


def build_inventory(resources: Iterable[SyntheticResource], *, stack_id: str = "fixture-stack-v1") -> dict:
    """Inventory declared toy resources without reading source_path or any file.

    Identifiers include extension/type. Case collisions are refused rather than
    resolved as an override order. This is not a real KEY/BIFF/override resolver.
    """
    if not isinstance(stack_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", stack_id):
        raise InventoryError("invalid synthetic stack identity")
    rows = []
    identities: set[str] = set()
    for item in resources:
        if not isinstance(item, SyntheticResource) or not isinstance(item.payload, bytes):
            raise InventoryError("expected immutable synthetic resource bytes")
        identity = resource_identity(item.resource_id)
        if identity in identities:
            raise InventoryError("duplicate case-insensitive resource identity")
        identities.add(identity)
        if len(item.payload) > MAX_PAYLOAD:
            raise InventoryError("synthetic resource exceeds byte limit")
        row = {"id": identity, "sha256": digest(item.payload), "byteLength": len(item.payload),
               "scriptSlots": [], "dependencies": [], "publicVariables": [], "opaqueNodes": []}
        nodes, error = _parse_nodes(item.payload)
        if error:
            row["opaqueNodes"].append({"position": -1, "reason": error})
        else:
            slots: set[str] = set()
            for position, node in enumerate(nodes):
                _declaration(row, node, position, slots)
        rows.append(row)
    result = {"schemaVersion": 1, "profile": "synthetic-inventory-v1", "stackId": stack_id,
              "runtimeActivation": False, "resources": sorted(rows, key=lambda row: row["id"])}
    result["inventoryDigest"] = digest(canonical_bytes(result))
    return result
