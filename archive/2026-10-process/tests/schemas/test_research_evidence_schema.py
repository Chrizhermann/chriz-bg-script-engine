from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPOSITORY_ROOT / "schemas" / "research-evidence.schema.json"
TEMPLATE_PATH = REPOSITORY_ROOT / "docs" / "research" / "evidence-template.md"
INDEX_PATH = (
    REPOSITORY_ROOT
    / "docs"
    / "research"
    / "PREP-02-evidence-and-provenance-index.md"
)

REQUIRED_RESEARCH_FIELDS = {
    "environment",
    "versions",
    "method",
    "artifacts",
    "evidenceLayers",
    "counterevidence",
    "residualUncertainty",
    "nextDecision",
}


class ProjectSubsetValidationError(AssertionError):
    """Raised by the project's deliberately small JSON Schema subset checker."""


def load_schema() -> dict[str, Any]:
    assert SCHEMA_PATH.is_file(), f"research evidence schema is absent: {SCHEMA_PATH}"
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def load_index_records() -> list[dict[str, Any]]:
    assert INDEX_PATH.is_file(), f"PREP-02 evidence index is absent: {INDEX_PATH}"
    text = INDEX_PATH.read_text(encoding="utf-8")
    blocks = re.findall(r"```json\s*\n(.*?)\n```", text, flags=re.DOTALL)
    return [json.loads(block) for block in blocks]


def validate_project_subset(
    instance: Any,
    schema: dict[str, Any],
    *,
    path: str = "$",
) -> None:
    """Validate only the JSON Schema keywords used by this repository's schema.

    This stdlib-only helper is intentionally not a general JSON Schema validator. It supports
    the project-required subset: type, const, enum, required, properties,
    additionalProperties=false, items, minItems, uniqueItems, minLength, and pattern.
    """

    if "const" in schema and instance != schema["const"]:
        raise ProjectSubsetValidationError(f"{path}: expected constant {schema['const']!r}")
    if "enum" in schema and instance not in schema["enum"]:
        raise ProjectSubsetValidationError(f"{path}: value is outside the declared enum")

    expected_type = schema.get("type")
    type_checks = {
        "array": lambda value: isinstance(value, list),
        "boolean": lambda value: isinstance(value, bool),
        "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
        "object": lambda value: isinstance(value, dict),
        "string": lambda value: isinstance(value, str),
    }
    if expected_type is not None:
        if expected_type not in type_checks:
            raise ProjectSubsetValidationError(
                f"{path}: schema uses unsupported type keyword {expected_type!r}"
            )
        if not type_checks[expected_type](../../../../tests/schemas/instance):
            raise ProjectSubsetValidationError(f"{path}: expected {expected_type}")

    if isinstance(instance, dict):
        required = schema.get("required", [])
        missing = [field for field in required if field not in instance]
        if missing:
            raise ProjectSubsetValidationError(
                f"{path}: missing required field(s): {', '.join(missing)}"
            )

        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extras = sorted(set(instance) - set(properties))
            if extras:
                raise ProjectSubsetValidationError(
                    f"{path}: undeclared field(s): {', '.join(extras)}"
                )
        for key, value in instance.items():
            if key in properties:
                validate_project_subset(value, properties[key], path=f"{path}.{key}")

    if isinstance(instance, list):
        if len(instance) < schema.get("minItems", 0):
            raise ProjectSubsetValidationError(f"{path}: array is shorter than minItems")
        if schema.get("uniqueItems"):
            normalized = [json.dumps(value, sort_keys=True) for value in instance]
            if len(normalized) != len(set(normalized)):
                raise ProjectSubsetValidationError(f"{path}: array items are not unique")
        item_schema = schema.get("items")
        if item_schema is not None:
            for index, value in enumerate(instance):
                validate_project_subset(value, item_schema, path=f"{path}[{index}]")

    if isinstance(instance, str):
        if len(instance) < schema.get("minLength", 0):
            raise ProjectSubsetValidationError(f"{path}: string is shorter than minLength")
        pattern = schema.get("pattern")
        if pattern is not None and re.fullmatch(pattern, instance) is None:
            raise ProjectSubsetValidationError(f"{path}: string does not match {pattern!r}")


def validate_prep02_index(
    records: list[dict[str, Any]],
    schema: dict[str, Any],
) -> None:
    """Apply PREP-02 cross-field rules that JSON Schema keywords do not express here."""

    if len(records) != 2:
        raise ProjectSubsetValidationError("index must contain exactly two PREP-02 records")

    record_ids = [record.get("id") for record in records]
    if len(record_ids) != len(set(record_ids)):
        raise ProjectSubsetValidationError("index contains a duplicate research record ID")

    maximum_layer_by_environment = {
        "env:host": 2,
        "env:synthetic": 3,
        "env:disposable": 4,
        "env:soak": 5,
    }
    allowed_access_by_environment = {
        "env:host": {"none", "read-only"},
        "env:synthetic": {"none"},
        "env:disposable": {"read-only", "disposable-write"},
        "env:soak": {"read-only", "soak-write"},
    }
    digest_lengths = {
        "git-blob-sha1": 40,
        "sha256": 64,
    }

    for record in records:
        validate_project_subset(record, schema)

        artifact_ids = [artifact["id"] for artifact in record["artifacts"]]
        if len(artifact_ids) != len(set(artifact_ids)):
            raise ProjectSubsetValidationError(
                f"{record['id']}: duplicate artifact ID makes evidence references ambiguous"
            )

        claim_ids = [claim["id"] for claim in record["claims"]]
        if len(claim_ids) != len(set(claim_ids)):
            raise ProjectSubsetValidationError(
                f"{record['id']}: duplicate claim ID makes the conclusion ambiguous"
            )

        record_layers = set(record["evidenceLayers"])
        for artifact in record["artifacts"]:
            algorithm = artifact["digest"]["algorithm"]
            digest = artifact["digest"]["value"]
            required_length = digest_lengths[algorithm]
            if re.fullmatch(rf"[A-Fa-f0-9]{{{required_length}}}", digest) is None:
                raise ProjectSubsetValidationError(
                    f"{artifact['id']}: {algorithm} digest must contain "
                    f"{required_length} hex characters"
                )
            if not set(artifact["evidenceLayers"]) <= record_layers:
                raise ProjectSubsetValidationError(
                    f"{artifact['id']}: artifact evidence layer is absent from its record"
                )

        environment = record["environment"]
        kind = environment["kind"]
        access = environment["gameStateAccess"]
        if access not in allowed_access_by_environment[kind]:
            raise ProjectSubsetValidationError(f"{kind} cannot use {access}")

        maximum_layer = maximum_layer_by_environment[kind]
        for layer in record["evidenceLayers"]:
            if int(layer[-1]) > maximum_layer:
                raise ProjectSubsetValidationError(f"{kind} cannot produce {layer}")

        artifact_id_set = set(artifact_ids)
        for claim in record["claims"]:
            missing_refs = sorted(set(claim["evidenceRefs"]) - artifact_id_set)
            if missing_refs:
                raise ProjectSubsetValidationError(
                    f"{claim['id']}: unknown artifact reference(s): {', '.join(missing_refs)}"
                )


def test_schema_declares_required_research_fields() -> None:
    schema = load_schema()

    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["$comment"].startswith("Project-required subset only")
    assert REQUIRED_RESEARCH_FIELDS <= set(schema["required"])


def test_schema_patterns_are_anchored_for_standard_validator_semantics() -> None:
    schema = load_schema()
    patterns: list[str] = []

    def collect_patterns(node: Any) -> None:
        if isinstance(node, dict):
            if "pattern" in node:
                patterns.append(node["pattern"])
            for value in node.values():
                collect_patterns(value)
        elif isinstance(node, list):
            for value in node:
                collect_patterns(value)

    collect_patterns(schema)

    assert patterns
    assert all(pattern.startswith("^") and pattern.endswith("$") for pattern in patterns)


def test_index_samples_validate_and_reject_each_missing_required_field() -> None:
    schema = load_schema()
    records = load_index_records()

    assert {record["id"] for record in records} == {
        "research:prep02-combat-queue-acceptance",
        "research:prep02-worldflow-public-state-drift",
    }
    for record in records:
        validate_project_subset(record, schema)

    representative = records[0]
    for field in sorted(REQUIRED_RESEARCH_FIELDS):
        incomplete = copy.deepcopy(representative)
        del incomplete[field]
        try:
            validate_project_subset(incomplete, schema)
        except ProjectSubsetValidationError as error:
            assert field in str(error)
        else:
            raise AssertionError(f"schema accepted a research record missing {field}")


def test_trace_chains_resolve_and_preserve_fail_closed_conclusions() -> None:
    schema = load_schema()
    records = load_index_records()
    records_by_id = {record["id"]: record for record in records}

    for record in records:
        validate_project_subset(record, schema)
        artifact_ids = {artifact["id"] for artifact in record["artifacts"]}
        for claim in record["claims"]:
            assert set(claim["evidenceRefs"]) <= artifact_ids

    combat = records_by_id["research:prep02-combat-queue-acceptance"]
    assert combat["nextDecision"]["fallback"] == "outcome-unknown-and-yield"
    assert "accepted" in combat["claims"][0]["statement"].casefold()
    assert "completion" in combat["claims"][0]["statement"].casefold()

    worldflow = records_by_id["research:prep02-worldflow-public-state-drift"]
    assert worldflow["nextDecision"]["fallback"] == "legacy-yield"
    assert "unknown" in worldflow["claims"][0]["statement"].casefold()
    assert "writer" in worldflow["claims"][0]["statement"].casefold()


def test_scs_pin_and_documented_validator_scope_are_exact() -> None:
    schema = load_schema()
    records = load_index_records()
    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    index = INDEX_PATH.read_text(encoding="utf-8")

    for record in records:
        validate_project_subset(record, schema)

    scs_artifacts = [
        artifact
        for record in records
        for artifact in record["artifacts"]
        if artifact["id"] == "artifact:scs-v35.21-reuse-statement"
    ]
    assert len(scs_artifacts) == 1
    scs = scs_artifacts[0]
    assert scs["version"] == "v35.21"
    assert scs["revision"] == "5dc240e9ff85d3909b6436e54b56297d3b61e33b"
    assert scs["digest"] == {
        "algorithm": "sha256",
        "value": "1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA",
    }
    assert scs["redistributionStatus"] == "reference-only"
    assert scs["evidenceLayers"] == ["evidence:E1"]

    assert "not a full JSON Schema conformance implementation" in template
    assert "not a full JSON Schema conformance implementation" in index
    assert "Conditional" in index
    assert "evidence:E1 + evidence:E2 mechanics only" in index


def test_index_semantics_reject_ambiguous_ids_and_cross_field_mismatches() -> None:
    schema = load_schema()
    records = load_index_records()

    validate_prep02_index(records, schema)

    def assert_rejected(candidate: list[dict[str, Any]], expected: str) -> None:
        try:
            validate_prep02_index(candidate, schema)
        except ProjectSubsetValidationError as error:
            assert expected in str(error)
        else:
            raise AssertionError(f"semantic validation accepted {expected}")

    extra_record = copy.deepcopy(records)
    extra_record.append(copy.deepcopy(records[1]))
    assert_rejected(extra_record, "exactly two PREP-02 records")

    duplicate_record = copy.deepcopy(records)
    duplicate_record[1]["id"] = duplicate_record[0]["id"]
    assert_rejected(duplicate_record, "duplicate research record ID")

    duplicate_artifact = copy.deepcopy(records)
    duplicate_artifact[0]["artifacts"].append(
        copy.deepcopy(duplicate_artifact[0]["artifacts"][0])
    )
    duplicate_artifact[0]["artifacts"][-1]["sourcePath"] = "ambiguous-second-source"
    assert_rejected(duplicate_artifact, "duplicate artifact ID")

    duplicate_claim = copy.deepcopy(records)
    duplicate_claim[0]["claims"].append(copy.deepcopy(duplicate_claim[0]["claims"][0]))
    duplicate_claim[0]["claims"][-1]["statement"] = "Ambiguous second statement."
    assert_rejected(duplicate_claim, "duplicate claim ID")

    mismatched_digest = copy.deepcopy(records)
    mismatched_digest[0]["artifacts"][1]["digest"] = {
        "algorithm": "sha256",
        "value": "A" * 40,
    }
    assert_rejected(mismatched_digest, "sha256 digest must contain 64 hex characters")

    impossible_layer = copy.deepcopy(records)
    impossible_layer[0]["evidenceLayers"].append("evidence:E4")
    assert_rejected(impossible_layer, "env:host cannot produce evidence:E4")

    impossible_access = copy.deepcopy(records)
    impossible_access[0]["environment"]["gameStateAccess"] = "disposable-write"
    assert_rejected(impossible_access, "env:host cannot use disposable-write")
