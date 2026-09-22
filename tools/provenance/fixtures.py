"""Read-only admission of the reviewed original JSON fixture set (Task 4 / E2).

This is not a release scanner, a legal decision engine, or a proof of authorship.
Human review establishes origin; exact paths and digests bind that review to bytes.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
import sys
from datetime import date
from pathlib import Path
from typing import Any


REGISTRY = "docs/provenance/fixture-allowlist.json"
FIXTURE_ROOT = "tests/fixtures"
MAX_BYTES = 262144
FIELDS = {
    "id", "path", "sha256", "classification", "origin", "owner", "source", "purpose",
    "requiredCredit", "redistributionStatus", "evidenceLayers", "review",
}
PRIVATE_PATH = re.compile(r"(?i)(?:\b[a-z]:[\\/]|\\\\[^\s]|/(?:home|users)/)")
DEVICE = re.compile(r"(?i)^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)")


class FixtureRefused(ValueError):
    """The fixture set has not satisfied its admission contract."""


def _fields(value: Any, required: set[str], label: str) -> None:
    if not isinstance(value, dict):
        raise FixtureRefused(f"{label}: expected object")
    missing = required - value.keys()
    if missing:
        raise FixtureRefused(f"{label}: missing {', '.join(sorted(missing))}")
    if value.keys() - required:
        raise FixtureRefused(f"{label}: undeclared field")


def _no_private_paths(value: Any) -> None:
    if isinstance(value, str) and PRIVATE_PATH.search(value):
        raise FixtureRefused("personal/absolute path in fixture or provenance metadata")
    if isinstance(value, dict):
        for key, item in value.items():
            _no_private_paths(key)
            _no_private_paths(item)
    elif isinstance(value, list):
        for item in value:
            _no_private_paths(item)


def _unique_object(pairs: list[tuple[str, Any]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise FixtureRefused("duplicate JSON key")
        result[key] = value
    return result


def _invalid_constant(_: str) -> None:
    raise FixtureRefused("non-finite JSON number")


def _finite_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed):
        raise FixtureRefused("non-finite JSON number")
    return parsed


def _bounded_int(value: str) -> int:
    if len(value.lstrip("-")) > 4096:
        raise FixtureRefused("JSON integer exceeds digit limit")
    return int(value)


def _json(payload: bytes) -> dict:
    if len(payload) > MAX_BYTES:
        raise FixtureRefused("fixture/registry exceeds byte limit")
    try:
        value = json.loads(
            payload.decode("utf-8"), object_pairs_hook=_unique_object,
            parse_constant=_invalid_constant, parse_float=_finite_float, parse_int=_bounded_int,
        )
    except FixtureRefused:
        raise
    except (ValueError, RecursionError):
        raise FixtureRefused("invalid UTF-8 JSON") from None
    if not isinstance(value, dict):
        raise FixtureRefused("fixture/registry must be a JSON object")
    _no_private_paths(value)
    return value


def _path(value: str) -> None:
    parts = value.split("/")
    if (
        not value.startswith(FIXTURE_ROOT + "/")
        or not re.fullmatch(r"[A-Za-z0-9_./-]+", value)
        or any(part in {"", ".", ".."} or part.endswith(".") or DEVICE.match(part) for part in parts)
    ):
        raise FixtureRefused("fixture path is not a canonical repository-relative path")
    if not value.endswith(".json"):
        raise FixtureRefused("Task 4 admits original JSON fixtures only")


def _direct(path: Path, *, directory: bool) -> os.stat_result:
    try:
        info = path.lstat()
    except FileNotFoundError:
        raise FixtureRefused("missing reviewed file or fixture directory") from None
    if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
        raise FixtureRefused("linked/reparse fixture path")
    if directory:
        if not stat.S_ISDIR(info.st_mode):
            raise FixtureRefused("fixture parent is not a directory")
    elif not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        raise FixtureRefused("fixture is linked or not a regular file")
    return info


def _read(root: Path, relative: str) -> bytes:
    cursor = root
    parts = relative.split("/")
    for part in parts[:-1]:
        cursor /= part
        _direct(cursor, directory=True)
    target = cursor / parts[-1]
    info = _direct(target, directory=False)
    if info.st_size > MAX_BYTES:
        raise FixtureRefused("fixture/registry exceeds byte limit")
    with target.open("rb") as handle:
        payload = handle.read(MAX_BYTES + 1)
    if len(payload) > MAX_BYTES:
        raise FixtureRefused("fixture/registry exceeds byte limit")
    return payload


def load_registry(root: Path) -> dict:
    """Load the same bounded UTF-8 registry on LF and CRLF host checkouts."""
    return _json(_read(root, REGISTRY))


def validate_fixture_set(root: Path, registry: Any) -> list[str]:
    """Require a complete, exact, reviewed inventory under tests/fixtures.

    Call with a quiescent trusted checkout. This does not lock the checkout against
    concurrent hostile filesystem changes and never copies or publishes any bytes.
    """
    _fields(registry, {"schemaVersion", "entries"}, "registry")
    if type(registry["schemaVersion"]) is not int or registry["schemaVersion"] != 1:
        raise FixtureRefused("unsupported schemaVersion")
    entries = registry["entries"]
    if not isinstance(entries, list) or not entries:
        raise FixtureRefused("registry entries must be a nonempty array")
    ids: set[str] = set()
    paths: set[str] = set()
    for entry in entries:
        _fields(entry, FIELDS, "fixture")
        for field in FIELDS - {"review", "evidenceLayers"}:
            if not isinstance(entry[field], str) or not entry[field].strip():
                raise FixtureRefused(f"fixture: blank/non-text {field}")
        if entry["id"].casefold() in ids or entry["path"].casefold() in paths:
            raise FixtureRefused("duplicate fixture id or path (case-insensitive)")
        ids.add(entry["id"].casefold())
        paths.add(entry["path"].casefold())

    approved: list[str] = []
    for entry in entries:
        _path(entry["path"])
        _no_private_paths(entry)
        if not re.fullmatch(r"artifact:[a-z0-9][a-z0-9._-]*", entry["id"]):
            raise FixtureRefused("invalid artifact id")
        if not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            raise FixtureRefused("invalid SHA-256 digest")
        if entry["classification"] not in {
            "redistributable-synthetic-fixture", "independently-authored-metadata",
        }:
            raise FixtureRefused("classification is held; not admitted by this contract")
        if entry["origin"] != "original":
            raise FixtureRefused("origin is held; synthetic labeling does not erase derivation")
        if entry["redistributionStatus"] != "redistributable":
            raise FixtureRefused("redistributionStatus is held")
        if entry["evidenceLayers"] != ["evidence:E2"]:
            raise FixtureRefused("evidenceLayers must describe E2 fixture admission only")
        review = entry["review"]
        _fields(review, {"decision", "reviewer", "date"}, "review")
        if review["decision"] != "approved-for-repository" or not isinstance(review["reviewer"], str) or not review["reviewer"].strip():
            raise FixtureRefused("review is not approved")
        try:
            if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", review["date"]):
                raise ValueError
            date.fromisoformat(review["date"])
        except (ValueError, TypeError):
            raise FixtureRefused("review date is invalid") from None
        payload = _read(root, entry["path"])
        if hashlib.sha256(payload).hexdigest() != entry["sha256"]:
            raise FixtureRefused("fixture digest changed; review the new bytes")
        _json(payload)
        approved.append(entry["path"])

    # Inventory every entry, including hidden files; never follow directory links.
    pending = [root / FIXTURE_ROOT]
    observed: set[str] = set()
    while pending:
        parent = pending.pop()
        _direct(parent, directory=True)
        for child in parent.iterdir():
            info = child.lstat()
            is_dir = stat.S_ISDIR(info.st_mode)
            _direct(child, directory=is_dir)
            if is_dir:
                pending.append(child)
            else:
                relative = child.relative_to(root).as_posix()
                if relative not in approved:
                    raise FixtureRefused("unlisted fixture file; exact review required")
                observed.add(relative)
    if observed != set(approved):
        raise FixtureRefused("missing reviewed fixture")
    return sorted(approved)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    try:
        approved = validate_fixture_set(root, load_registry(root))
    except (FixtureRefused, OSError, RecursionError) as error:
        # OS messages may contain personal paths; expose only policy diagnostics.
        reason = str(error) if isinstance(error, FixtureRefused) else "filesystem/structure check failed"
        print(f"fixture admission refused: {reason}", file=sys.stderr)
        return 1
    print(f"fixture admission passed: {len(approved)} reviewed file(s)")
    for path in approved:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
