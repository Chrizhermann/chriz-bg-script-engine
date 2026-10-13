from __future__ import annotations

import json
import re
from typing import Any


class ProjectSubsetValidationError(AssertionError):
    """Raised by the project's deliberately small JSON Schema subset checker."""


def validate_project_subset(
    instance: Any,
    schema: dict[str, Any],
    *,
    path: str = "$",
) -> None:
    """Validate only the JSON Schema keywords used by this repository's schemas.

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
        if not type_checks[expected_type](instance):
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
