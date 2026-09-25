"""Opt-in, local-only path detail for one synthetic inventory open failure."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from test_environment_contract import (
    POWERSHELL_PATH,
    REPOSITORY_ROOT,
    SYNTHETIC_SECRET,
    snapshot_tree,
)
from test_offline_reference_faults import _GENERIC_WRITE, exclusive_handle
from test_offline_reference_measurement import SCRIPT


def invoke_measurement(
    source: Path | str,
    destination: Path,
    *,
    include_private: bool,
    whatif: bool,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    command = [
        POWERSHELL_PATH,
        "-NoProfile",
        "-File",
        str(SCRIPT),
        "-SourceRoot",
        str(source),
        "-DestinationRoot",
        str(destination),
        "-OutputAllowanceBytes",
        "1048576",
        "-SafetyReserveBytes",
        "1048576",
    ]
    if include_private:
        command.append("-IncludePrivateFailurePath")
    if whatif:
        command.append("-WhatIf")
    result = subprocess.run(
        command,
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )
    assert result.stderr == ""
    lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(lines) == 1
    payload = json.loads(lines[0])
    assert isinstance(payload, dict)
    assert payload["schemaVersion"] == 1
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert payload["processCheck"] == "unexecuted"
    assert payload["writableRootAdmission"] == "unexecuted"
    return result, payload


@pytest.mark.parametrize("whatif", [True, False])
def test_private_path_only_for_opted_in_content_open_32(tmp_path: Path, whatif: bool) -> None:
    source = tmp_path / "source"
    nested = source / "nested"
    nested.mkdir(parents=True)
    locked = nested / f"naïve[1]-{SYNTHETIC_SECRET}.bin"
    locked.write_bytes(b"ordinary fixture bytes")
    destination = tmp_path / "fresh-destination" / "game"
    before = snapshot_tree(tmp_path)

    # Sharing read and write lets metadata inspection succeed; this held write
    # handle blocks the subsequent content-read open with Win32 error 32.
    with exclusive_handle(locked, _GENERIC_WRITE, share=3):
        public_run, public = invoke_measurement(
            source, destination, include_private=False, whatif=whatif
        )
        private_run, private = invoke_measurement(
            source, destination, include_private=True, whatif=whatif
        )

    assert public_run.returncode == private_run.returncode == 3
    assert public["status"] == private["status"] == "refused"
    assert public["code"] == private["code"] == "BGSE_E_PATH_ACCESS"
    expected_diagnostic = {
        "phase": "inventory",
        "pass": 1,
        "operation": "open-content",
        "failureKind": "native-error",
        "nativeError": 32,
    }
    assert public["diagnostic"] == private["diagnostic"] == expected_diagnostic
    assert "privateDiagnostic" not in public
    public_output = public_run.stdout.replace("\\\\", "\\").casefold()
    assert "attemptedpath" not in public_output
    for private_value in (source, locked, SYNTHETIC_SECRET):
        assert str(private_value).casefold() not in public_output
    assert private["privateDiagnostic"] == {
        "classification": "private-local-only",
        "attemptedPath": str(locked),
        "pathIdentity": "unverified-at-failed-open",
        "holderAttribution": "unexecuted",
    }
    assert set(private) == set(public) | {"privateDiagnostic"}
    assert snapshot_tree(tmp_path) == before
    assert not destination.exists()


@pytest.mark.parametrize("whatif", [True, False])
def test_opted_in_success_matches_default_without_private_diagnostic(
    tmp_path: Path, whatif: bool
) -> None:
    source = tmp_path / "source"
    nested = source / "nested"
    nested.mkdir(parents=True)
    (nested / "naïve[1].bin").write_bytes(b"ordinary fixture bytes")
    destination = tmp_path / "fresh-destination" / "game"
    before = snapshot_tree(tmp_path)

    ordinary_run, ordinary = invoke_measurement(
        source, destination, include_private=False, whatif=whatif
    )
    opted_run, opted = invoke_measurement(
        source, destination, include_private=True, whatif=whatif
    )

    assert ordinary_run.returncode == opted_run.returncode == 0
    assert ordinary["code"] == opted["code"] == "BGSE_MEASUREMENT_ONLY"
    assert ordinary["status"] == opted["status"] == "observed-read-only"
    assert {key: value for key, value in ordinary.items() if key != "observedFreeBytes"} == {
        key: value for key, value in opted.items() if key != "observedFreeBytes"
    }
    assert ordinary["observedFreeBytes"] >= ordinary["requiredFreeBytes"]
    assert opted["observedFreeBytes"] >= opted["requiredFreeBytes"]
    assert "privateDiagnostic" not in opted
    assert snapshot_tree(tmp_path) == before
    assert not destination.exists()


@pytest.mark.parametrize("whatif", [True, False])
@pytest.mark.parametrize(
    ("refusal", "expected_code"),
    [
        ("missing-source", "BGSE_E_PATH_ACCESS"),
        ("invalid-input", "BGSE_E_PATH_SYNTAX"),
        ("source-marker", "BGSE_E_SOURCE_MARKER"),
    ],
)
def test_other_opted_in_refusals_never_publish_private_path(
    tmp_path: Path, whatif: bool, refusal: str, expected_code: str
) -> None:
    source = tmp_path / "source"
    source.mkdir()
    (source / "ordinary.bin").write_bytes(b"ordinary fixture bytes")
    destination = tmp_path / "fresh-destination" / "game"
    if refusal == "missing-source":
        selected_source: Path | str = tmp_path / f"missing-{SYNTHETIC_SECRET}"
    elif refusal == "invalid-input":
        selected_source = r"relative\source"
    else:
        (source / ".bgse-disposable-lab.json").write_bytes(b"synthetic marker")
        selected_source = source
    before = snapshot_tree(tmp_path)

    result, payload = invoke_measurement(
        selected_source, destination, include_private=True, whatif=whatif
    )

    assert result.returncode == 3
    assert payload["status"] == "refused"
    assert payload["code"] == expected_code
    assert "privateDiagnostic" not in payload
    assert "attemptedPath" not in result.stdout
    assert SYNTHETIC_SECRET.casefold() not in result.stdout.casefold()
    assert snapshot_tree(tmp_path) == before
    assert not destination.exists()
