"""Whole-wrapper diagnostics stay scalar, authored, and non-disclosing."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from test_environment_contract import SYNTHETIC_SECRET, snapshot_tree
from test_offline_reference_faults import _GENERIC_WRITE, exclusive_handle
from test_offline_reference_measurement import measure


DIAGNOSTIC_KEYS = {
    "phase",
    "pass",
    "operation",
    "failureKind",
    "nativeError",
}


def assert_diagnostic(
    payload: dict[str, object], expected: dict[str, object], native_errors: set[int]
) -> None:
    diagnostic = payload["diagnostic"]
    assert isinstance(diagnostic, dict)
    assert set(diagnostic) == DIAGNOSTIC_KEYS
    assert {key: value for key, value in diagnostic.items() if key != "nativeError"} == expected
    assert diagnostic["nativeError"] in native_errors
    assert all(
        value is None or isinstance(value, (str, int)) and not isinstance(value, bool)
        for value in diagnostic.values()
    )
    assert SYNTHETIC_SECRET.casefold() not in json.dumps(payload).casefold()


def test_missing_source_has_sanitized_native_open_metadata_diagnostic(tmp_path: Path):
    source = tmp_path / f"missing-{SYNTHETIC_SECRET}" / "source"
    destination = tmp_path / "fresh-destination" / "game"
    before = snapshot_tree(tmp_path)

    code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_PATH_ACCESS"
    assert_diagnostic(
        payload,
        {
            "phase": "source-ancestors",
            "pass": None,
            "operation": "open-metadata",
            "failureKind": "native-error",
        },
        {2, 3},
    )
    assert snapshot_tree(tmp_path) == before
    assert not source.exists()
    assert not destination.exists()


def test_held_source_file_has_sanitized_content_open_diagnostic(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    locked = source / "a-locked.bin"
    locked.write_bytes(b"ordinary source bytes")
    (source / f"z-{SYNTHETIC_SECRET}.bin").write_bytes(SYNTHETIC_SECRET.encode())
    destination = tmp_path / "fresh-destination" / "game"
    before = snapshot_tree(tmp_path)

    with exclusive_handle(locked, _GENERIC_WRITE, share=3):
        code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_PATH_ACCESS"
    assert_diagnostic(
        payload,
        {
            "phase": "inventory",
            "pass": 1,
            "operation": "open-content",
            "failureKind": "native-error",
        },
        {32},
    )
    assert snapshot_tree(tmp_path) == before
    assert not destination.exists()
