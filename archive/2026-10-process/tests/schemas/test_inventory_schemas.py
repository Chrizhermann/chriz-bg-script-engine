"""Shape checks for Task 5's provisional, synthetic-only output contract.

The local validator implements only the keywords used below, not full JSON Schema.
Graph closure, duplicate identities, digest authenticity, and claim eligibility are
implementation invariants; passing these shape checks grants no runtime ownership.
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any

import pytest


ROOT = Path(__file__).resolve().parents[2]
DIGEST = "a" * 64
SUPPORTED = {
    "$schema", "$id", "$comment", "title", "description", "type", "const", "enum",
    "required", "properties", "additionalProperties", "items", "minItems",
    "uniqueItems", "minLength", "maxLength", "pattern", "minimum",
}


class SubsetValidationError(AssertionError):
    """A schema shape or keyword falls outside this explicit test contract."""


def load_schema(name: str) -> dict[str, Any]:
    path = ROOT / "schemas" / name
    assert path.is_file(), f"Task 5 schema is absent: {name}"
    return json.loads(path.read_text(encoding="utf-8"))


def validate_subset(value: Any, schema: dict[str, Any], path: str = "$") -> None:
    """Validate only this schema's declared subset, rejecting unsupported keywords."""
    if set(schema) - SUPPORTED:
        raise SubsetValidationError(f"{path}: unsupported schema keyword")
    checks = {
        "object": lambda item: isinstance(item, dict),
        "array": lambda item: isinstance(item, list),
        "string": lambda item: isinstance(item, str),
        "integer": lambda item: type(item) is int,
        "boolean": lambda item: type(item) is bool,
        "null": lambda item: item is None,
    }
    declared = schema.get("type")
    kinds = declared if isinstance(declared, list) else [declared]
    if any(kind not in checks for kind in kinds):
        raise SubsetValidationError(f"{path}: unsupported schema type")
    if not any(checks[kind](../../../../tests/schemas/value) for kind in kinds):
        raise SubsetValidationError(f"{path}: incorrect type")
    if "const" in schema and value != schema["const"]:
        raise SubsetValidationError(f"{path}: incorrect constant")
    if "enum" in schema and value not in schema["enum"]:
        raise SubsetValidationError(f"{path}: outside enum")
    if isinstance(value, dict):
        if set(schema.get("required", [])) - value.keys():
            raise SubsetValidationError(f"{path}: missing required field")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False and value.keys() - properties.keys():
            raise SubsetValidationError(f"{path}: undeclared field")
        for key, item in value.items():
            if key in properties:
                validate_subset(item, properties[key], f"{path}.{key}")
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            raise SubsetValidationError(f"{path}: too few items")
        if schema.get("uniqueItems"):
            encoded = [json.dumps(item, sort_keys=True) for item in value]
            if len(encoded) != len(set(encoded)):
                raise SubsetValidationError(f"{path}: duplicate items")
        if "items" in schema:
            for index, item in enumerate(value):
                validate_subset(item, schema["items"], f"{path}[{index}]")
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            raise SubsetValidationError(f"{path}: too short")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            raise SubsetValidationError(f"{path}: too long")
        # JSON Schema patterns search rather than implicitly fullmatch. Anchors in
        # the schema, not a stronger test-only matching mode, establish the boundary.
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            raise SubsetValidationError(f"{path}: invalid pattern")
    if type(value) is int and "minimum" in schema and value < schema["minimum"]:
        raise SubsetValidationError(f"{path}: below minimum")


def manifest_sample() -> dict[str, Any]:
    """Original shape example; its placeholder digests are not authenticity evidence."""
    return {
        "schemaVersion": 1,
        "profile": "synthetic-inventory-v1",
        "stackId": "synthetic-task5",
        "runtimeActivation": False,
        "resources": [{
            "id": "B-XCRE01.CRE", "sha256": DIGEST, "byteLength": 17,
            "scriptSlots": [{"position": 0, "slot": "default", "target": "B-XAI001.BCS"}],
            "dependencies": [{"position": 0, "kind": "script-slot", "target": "B-XAI001.BCS"}],
            "publicVariables": [{"position": 1, "scope": "GLOBAL", "name": "QuestStage", "access": "read"}],
            "opaqueNodes": [{"position": -1, "reason": "unsupported-format"}],
        }],
        "inventoryDigest": DIGEST,
    }


def claim_sample() -> dict[str, Any]:
    return {
        "schemaVersion": 1, "profile": "synthetic-exact-claim-v1",
        "adapterId": "B-/combat/synthetic-task5", "domain": "CombatIntent",
        "roots": ["B-XCRE01.CRE"], "inventoryDigest": DIGEST,
        "hashes": [{"id": "B-XCRE01.CRE", "sha256": DIGEST}],
        "eligibleForAnalysis": True, "reasons": [], "runtimeActivation": False,
        "fallback": "legacy",
    }


SCHEMAS = [
    ("install-manifest.schema.json", manifest_sample),
    ("resource-claim.schema.json", claim_sample),
]


@pytest.mark.parametrize("name,sample", SCHEMAS)
def test_schema_contract_and_required_fields(name: str, sample: Any) -> None:
    schema = load_schema(name)
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert "not a full JSON Schema" in schema["$comment"]
    assert set(schema["required"]) == set(sample()) == set(schema["properties"])
    validate_subset(sample(), schema)
    for field in sample():
        incomplete = sample()
        del incomplete[field]
        with pytest.raises(SubsetValidationError, match="missing required"):
            validate_subset(incomplete, schema)


def test_manifest_accepts_empty_inventory_and_explicit_empty_slot() -> None:
    schema = load_schema("install-manifest.schema.json")
    document = manifest_sample()
    document["resources"][0]["scriptSlots"][0]["target"] = None
    validate_subset(document, schema)
    document["resources"] = []
    validate_subset(document, schema)


def test_claim_accepts_explicit_refusal_shape() -> None:
    document = claim_sample()
    document.update(eligibleForAnalysis=False, hashes=[], reasons=["opaque-resource"])
    validate_subset(document, load_schema("resource-claim.schema.json"))
    document.update(adapterId="B-/worldflow/synthetic-task5", domain="WorldFlow")
    validate_subset(document, load_schema("resource-claim.schema.json"))


def set_field(document: Any, path: tuple[Any, ...], value: Any) -> None:
    for key in path[:-1]:
        document = document[key]
    document[path[-1]] = value


@pytest.mark.parametrize("path,value", [
    (("schemaVersion",), True), (("schemaVersion",), 2),
    (("profile",), "runtime-inventory"), (("runtimeActivation",), True),
    (("runtimeActivation",), 0), (("stackId",), "C:/private"),
    (("stackId",), ""), (("stackId",), "x" * 65),
    (("inventoryDigest",), "A" * 64), (("inventoryDigest",), "a" * 63),
    (("unexpected",), "ignored"), (("resources",), {}),
    (("resources", 0, "id"), "b-xcre01.CRE"),
    (("resources", 0, "id"), "NINECHARS.CRE"),
    (("resources", 0, "id"), "B-XCRE01.EXE"),
    (("resources", 0, "sha256"), "not-a-digest"),
    (("resources", 0, "byteLength"), -1),
    (("resources", 0, "byteLength"), True),
    (("resources", 0, "extra"), "ignored"),
    (("resources", 0, "scriptSlots", 0, "position"), -1),
    (("resources", 0, "scriptSlots", 0, "slot"), "highest"),
    (("resources", 0, "scriptSlots", 0, "target"), 0),
    (("resources", 0, "scriptSlots", 0, "target"), "B-XAI001"),
    (("resources", 0, "dependencies", 0, "kind"), "guessed"),
    (("resources", 0, "dependencies", 0, "target"), None),
    (("resources", 0, "dependencies", 0, "position"), False),
    (("resources", 0, "publicVariables", 0, "scope"), "LOCALS"),
    (("resources", 0, "publicVariables", 0, "name"), "7Quest"),
    (("resources", 0, "publicVariables", 0, "name"), "Q" * 33),
    (("resources", 0, "publicVariables", 0, "access"), "assumed"),
    (("resources", 0, "opaqueNodes", 0, "position"), -2),
    (("resources", 0, "opaqueNodes", 0, "reason"), "safe-to-ignore"),
])
def test_manifest_rejects_wrong_types_unsupported_forms_and_extra_fields(
    path: tuple[Any, ...], value: Any,
) -> None:
    document = manifest_sample()
    set_field(document, path, value)
    with pytest.raises(SubsetValidationError):
        validate_subset(document, load_schema("install-manifest.schema.json"))


@pytest.mark.parametrize("path,value", [
    (("schemaVersion",), True), (("schemaVersion",), 2),
    (("profile",), "runtime-claim"), (("runtimeActivation",), True),
    (("runtimeActivation",), 0), (("eligibleForAnalysis",), 1),
    (("fallback",), "take-over"), (("domain",), "Kernel"),
    (("adapterId",), "BGSE/combat/test"), (("adapterId",), "B-/combat/Test"),
    (("adapterId",), "B-/combat/"), (("adapterId",), "B-/combat/a--b"),
    (("adapterId",), "B-/combat/" + "a" * 55),
    (("roots",), []), (("roots",), ["B-XCRE01.CRE", "B-XCRE01.CRE"]),
    (("roots",), ["b-xcre01.cre"]), (("roots",), ["B-XCRE01.CRE.extra"]),
    (("inventoryDigest",), "A" * 64), (("inventoryDigest",), "a" * 63),
    (("hashes", 0, "id"), "../B-XCRE01.CRE"),
    (("hashes", 0, "sha256"), "A" * 64),
    (("hashes", 0, "extra"), "ignored"),
    (("reasons",), ["duplicate", "duplicate"]), (("reasons",), [None]),
    (("unexpected",), "ignored"),
])
def test_claim_rejects_ambiguous_shape_and_runtime_authority(
    path: tuple[Any, ...], value: Any,
) -> None:
    document = claim_sample()
    set_field(document, path, value)
    with pytest.raises(SubsetValidationError):
        validate_subset(document, load_schema("resource-claim.schema.json"))


@pytest.mark.parametrize("name,sample", SCHEMAS)
def test_all_nested_objects_have_exact_required_fields(name: str, sample: Any) -> None:
    schema = load_schema(name)

    def visit(document: Any, shape: dict[str, Any]) -> None:
        if isinstance(document, dict):
            assert shape["additionalProperties"] is False
            assert set(shape["required"]) == set(shape["properties"]) == set(document)
            for field in document:
                incomplete = copy.deepcopy(document)
                del incomplete[field]
                with pytest.raises(SubsetValidationError):
                    validate_subset(incomplete, shape)
                visit(document[field], shape["properties"][field])
            extra = copy.deepcopy(document)
            extra["unexpected"] = "not dropped"
            with pytest.raises(SubsetValidationError):
                validate_subset(extra, shape)
        elif isinstance(document, list):
            for item in document:
                visit(item, shape["items"])

    visit(sample(), schema)


def test_subset_validator_rejects_unimplemented_keywords() -> None:
    with pytest.raises(SubsetValidationError, match="unsupported schema keyword"):
        validate_subset({}, {"type": "object", "$ref": "ignored-reference"})


@pytest.mark.parametrize("name,sample,path", [
    ("install-manifest.schema.json", manifest_sample, ("stackId",)),
    ("install-manifest.schema.json", manifest_sample, ("inventoryDigest",)),
    ("install-manifest.schema.json", manifest_sample, ("resources", 0, "id")),
    ("install-manifest.schema.json", manifest_sample, ("resources", 0, "sha256")),
    ("install-manifest.schema.json", manifest_sample, ("resources", 0, "scriptSlots", 0, "target")),
    ("install-manifest.schema.json", manifest_sample, ("resources", 0, "dependencies", 0, "target")),
    ("install-manifest.schema.json", manifest_sample, ("resources", 0, "publicVariables", 0, "name")),
    ("resource-claim.schema.json", claim_sample, ("adapterId",)),
    ("resource-claim.schema.json", claim_sample, ("roots", 0)),
    ("resource-claim.schema.json", claim_sample, ("inventoryDigest",)),
    ("resource-claim.schema.json", claim_sample, ("hashes", 0, "id")),
    ("resource-claim.schema.json", claim_sample, ("hashes", 0, "sha256")),
])
@pytest.mark.parametrize("suffix", ["\n", "\r\n", "\u2028"])
def test_patterns_reject_trailing_line_terminators(
    name: str, sample: Any, path: tuple[Any, ...], suffix: str,
) -> None:
    document = sample()
    current: Any = document
    for key in path:
        current = current[key]
    set_field(document, path, current + suffix)
    with pytest.raises(SubsetValidationError, match="invalid pattern"):
        validate_subset(document, load_schema(name))


def test_declared_grammar_boundaries_and_resource_types() -> None:
    schema = load_schema("install-manifest.schema.json")
    document = manifest_sample()
    document["stackId"] = "s" * 64
    document["resources"][0]["byteLength"] = 0
    document["resources"][0]["publicVariables"][0]["name"] = "Q" * 32
    document["resources"][0]["publicVariables"][0]["access"] = "write"
    document["resources"][0]["dependencies"][0]["kind"] = "declared"
    for resource_type in ["CRE", "BCS", "DLG", "ARE", "SPL", "ITM", "PRO", "IDS", "2DA"]:
        document["resources"][0]["id"] = "A." + resource_type
        validate_subset(document, schema)
    for slot in ["override", "class", "race", "general", "default", "area"]:
        document["resources"][0]["scriptSlots"][0]["slot"] = slot
        validate_subset(document, schema)
    for reason in ["unsupported-format", "malformed-document", "unknown-node", "invalid-node", "duplicate-slot"]:
        document["resources"][0]["opaqueNodes"][0]["reason"] = reason
        validate_subset(document, schema)
    claim = claim_sample()
    claim["adapterId"] = "B-/combat/" + "a" * 54
    validate_subset(claim, load_schema("resource-claim.schema.json"))


@pytest.mark.parametrize("nodes,eligible", [
    ([], True),
    ([{"kind": "script-slot", "slot": "default", "target": None}], True),
    ([{"kind": "script-slot", "slot": "default", "target": "B-XPROB0.BCS"},
      {"kind": "public-variable", "scope": "GLOBAL", "name": "QuestStage", "access": "read"}], True),
    ([{"kind": "dependency", "target": "B-XMISS0.BCS"}], False),
    ([{"kind": "unknown-node"}], False),
])
def test_actual_prototype_outputs_conform_without_granting_runtime_authority(
    nodes: list[dict], eligible: bool,
) -> None:
    from tools.corpus.exact_hash import make_claim
    from tools.corpus.inventory import SyntheticResource, build_inventory

    resource = SyntheticResource(
        "B-XPROB0.BCS",
        b"BGSE-SYNTHETIC-RESOURCE-V1\n" + json.dumps({"nodes": nodes}).encode("utf-8"),
    )
    manifest = build_inventory([resource])
    claim = make_claim(
        [resource], "B-/combat/synthetic-probe", "CombatIntent", [resource.resource_id],
    )
    validate_subset(manifest, load_schema("install-manifest.schema.json"))
    validate_subset(claim, load_schema("resource-claim.schema.json"))
    assert claim["eligibleForAnalysis"] is eligible
    assert manifest["runtimeActivation"] is claim["runtimeActivation"] is False
    assert claim["fallback"] == "legacy"
