"""Whole-wrapper refusal tests for reserved offline-source readiness markers."""
from __future__ import annotations

import os
from pathlib import Path

from test_environment_contract import create_junction, snapshot_tree
from test_offline_reference_faults import _GENERIC_WRITE, exclusive_handle
from test_offline_reference_measurement import measure


MARKER = ".bgse-disposable-lab.json"


def marker_refusal(source: Path, destination: Path) -> None:
    code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_SOURCE_MARKER"
    assert payload["status"] == "refused"
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert payload["processCheck"] == "unexecuted"
    assert payload["writableRootAdmission"] == "unexecuted"
    assert payload["diagnostic"] == {
        "phase": "inventory",
        "pass": 1,
        "operation": "guard",
        "failureKind": "guard",
        "nativeError": None,
    }


def test_nested_marker_directory_refuses_without_touching_its_canary(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    marker_directory = source / "nested" / MARKER
    marker_directory.mkdir(parents=True)
    canary = marker_directory / "not-a-marker.bin"
    canary.write_bytes(b"marker-directory child remains unchanged")
    destination = tmp_path / "new-destination" / "game"
    before = snapshot_tree(tmp_path)

    marker_refusal(source, destination)

    assert canary.read_bytes() == b"marker-directory child remains unchanged"
    assert not destination.exists()
    assert snapshot_tree(tmp_path) == before


def test_nested_mixed_case_marker_file_refuses_without_reading_its_payload(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    marker = source / "nested" / ".BGSE-DISPOSABLE-LAB.JSON"
    marker.parent.mkdir()
    marker.write_bytes(b"private marker payload must remain opaque")
    destination = tmp_path / "new-destination" / "game"
    before = snapshot_tree(tmp_path)

    marker_refusal(source, destination)

    assert marker.read_bytes() == b"private marker payload must remain opaque"
    assert not destination.exists()
    assert snapshot_tree(tmp_path) == before


def test_marker_named_junction_refuses_before_following_outside_target(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    sentinel = outside / "sentinel.bin"
    sentinel.write_bytes(b"outside remains untouched")
    marker_junction = source / "nested" / MARKER
    marker_junction.parent.mkdir()
    create_junction(marker_junction, outside)
    destination = tmp_path / "new-destination" / "game"
    before = snapshot_tree(tmp_path)
    try:
        marker_refusal(source, destination)
        after = snapshot_tree(tmp_path)
    finally:
        os.rmdir(marker_junction)

    assert sentinel.read_bytes() == b"outside remains untouched"
    assert not destination.exists()
    assert after == before


def test_locked_exact_marker_refuses_at_guard_before_content_open(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    marker = source / "nested" / MARKER
    marker.parent.mkdir()
    marker.write_bytes(b"locked marker payload")
    destination = tmp_path / "new-destination" / "game"
    before = snapshot_tree(tmp_path)

    # This admits metadata/list access but would reject the helper's ordinary
    # content-read handle. The marker guard must win before any content open.
    with exclusive_handle(marker, _GENERIC_WRITE, share=3):
        marker_refusal(source, destination)

    assert marker.read_bytes() == b"locked marker payload"
    assert not destination.exists()
    assert snapshot_tree(tmp_path) == before
