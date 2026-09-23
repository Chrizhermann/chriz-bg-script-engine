"""Offline acquisition must not inherit a lab's readiness claim."""
from __future__ import annotations

import json

import pytest

from test_environment_contract import SYNTHETIC_SECRET, snapshot_tree
from test_offline_reference_faults import _GENERIC_WRITE, exclusive_handle
from test_offline_reference_measurement import measure


MARKER = ".bgse-disposable-lab.json"


@pytest.mark.parametrize("whatif", [True, False])
@pytest.mark.parametrize("payload", [
    b"",
    b"not JSON: " + SYNTHETIC_SECRET.encode(),
    b"x" * 4097,
    json.dumps({
        "schemaVersion": 1,
        "markerType": "chriz-bg-script-engine-disposable-lab",
        "createdByTask": 3,
        "labId": "90f743e8-ffb4-4da6-bd85-fc6a071e624a",
    }).encode(),
], ids=["empty", "malformed", "oversized", "valid-looking"])
def test_source_readiness_marker_is_refused_regardless_of_payload(tmp_path, payload, whatif):
    source = tmp_path / "synthetic-source"
    source.mkdir()
    (source / MARKER).write_bytes(payload)
    (source / "ordinary.bin").write_bytes(b"unrelated ordinary bytes")
    destination = tmp_path / "fresh-parent" / "offline-copy"
    before = snapshot_tree(tmp_path)

    code, result = measure(source, destination, whatif=whatif)

    assert code == 3
    assert result["status"] == "refused"
    assert result["code"] == "BGSE_E_SOURCE_MARKER"
    assert result["diagnostic"] == {
        "phase": "inventory", "pass": 1, "operation": "guard",
        "failureKind": "guard", "nativeError": None,
    }
    assert "contentDigest" not in result
    assert "files" not in result
    assert SYNTHETIC_SECRET not in json.dumps(result)
    assert snapshot_tree(tmp_path) == before
    assert not destination.parent.exists()


@pytest.mark.parametrize("root_name", [MARKER, MARKER.upper()])
def test_marker_named_source_directory_root_is_refused(tmp_path, root_name):
    source = tmp_path / root_name
    source.mkdir()
    (source / "ordinary.bin").write_bytes(b"ordinary bytes")
    destination = tmp_path / "fresh-parent" / "offline-copy"
    before = snapshot_tree(tmp_path)

    code, result = measure(source, destination)

    assert code == 3
    assert result["code"] == "BGSE_E_SOURCE_MARKER"
    assert result["diagnostic"]["phase"] == "inventory"
    assert snapshot_tree(tmp_path) == before
    assert not destination.parent.exists()


def test_locked_near_name_still_reaches_ordinary_content_guard(tmp_path):
    source = tmp_path / "synthetic-source"
    source.mkdir()
    locked = source / (MARKER + ".bak")
    locked.write_bytes(b"ordinary bytes")
    destination = tmp_path / "fresh-parent" / "offline-copy"
    before = snapshot_tree(tmp_path)

    with exclusive_handle(locked, _GENERIC_WRITE, share=3):
        code, result = measure(source, destination)

    assert code == 3
    assert result["code"] == "BGSE_E_PATH_ACCESS"
    assert result["diagnostic"]["operation"] == "open-content"
    assert result["diagnostic"]["nativeError"] == 32
    assert snapshot_tree(tmp_path) == before
    assert not destination.parent.exists()


@pytest.mark.parametrize("near_name", [
    ".bgse-disposable-lab.json.bak",
    "prefix.bgse-disposable-lab.json",
    ".bgse-disposable-lab-json",
    "bgse-disposable-lab.json",
])
def test_nonreserved_names_are_not_mistaken_for_readiness_marker(tmp_path, near_name):
    source = tmp_path / "synthetic-source"
    source.mkdir()
    (source / near_name).write_bytes(b"ordinary source data")
    destination = tmp_path / "fresh-parent" / "offline-copy"
    before = snapshot_tree(tmp_path)

    code, result = measure(source, destination)

    assert code == 0
    assert result["code"] == "BGSE_MEASUREMENT_ONLY"
    assert result["files"] == 1
    assert result["passes"] == 2
    assert snapshot_tree(tmp_path) == before
    assert not destination.parent.exists()
