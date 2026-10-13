"""Negative host-fault coverage for the offline reference measurement."""
from __future__ import annotations

import ctypes
import json
import os
import subprocess
from contextlib import contextmanager
from pathlib import Path

import pytest

from test_environment_contract import (
    POWERSHELL_PATH,
    REPOSITORY_ROOT,
    get_unused_drive_root,
    snapshot_tree,
)
from test_offline_reference_measurement import SCRIPT, measure


_CREATE_FILE = ctypes.WinDLL("kernel32", use_last_error=True).CreateFileW
_CREATE_FILE.argtypes = (
    ctypes.c_wchar_p,
    ctypes.c_uint32,
    ctypes.c_uint32,
    ctypes.c_void_p,
    ctypes.c_uint32,
    ctypes.c_uint32,
    ctypes.c_void_p,
)
_CREATE_FILE.restype = ctypes.c_void_p
_CLOSE_HANDLE = ctypes.WinDLL("kernel32", use_last_error=True).CloseHandle
_CLOSE_HANDLE.argtypes = (ctypes.c_void_p,)
_CLOSE_HANDLE.restype = ctypes.c_int
_INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
_GENERIC_WRITE = 0x40000000
_OPEN_EXISTING = 3


@contextmanager
def exclusive_handle(path: Path, access: int, *, share: int = 0, flags: int = 0):
    """Hold a real temporary-fixture handle that denies conflicting opens."""
    handle = _CREATE_FILE(
        str(path),
        access,
        share,
        None,
        _OPEN_EXISTING,
        flags,
        None,
    )
    if handle == _INVALID_HANDLE_VALUE:
        error = ctypes.get_last_error()
        raise OSError(error, f"CreateFileW failed for the synthetic fixture {path}")
    try:
        yield
    finally:
        assert _CLOSE_HANDLE(handle), "failed to close the synthetic-fixture handle"


def invoke_without_capacity(source: Path, destination: Path, omitted: str):
    command = [
        POWERSHELL_PATH,
        "-NoProfile",
        "-File",
        str(SCRIPT),
        "-SourceRoot",
        str(source),
        "-DestinationRoot",
        str(destination),
    ]
    if omitted == "allowance":
        command.extend(["-SafetyReserveBytes", "0"])
    else:
        command.extend(["-OutputAllowanceBytes", "0"])
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
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert payload["processCheck"] == "unexecuted"
    disclosed = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    assert str(source).casefold() not in disclosed
    assert str(destination).casefold() not in disclosed
    return result.returncode, payload


@pytest.fixture
def source_and_destination(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "ordinary.bin").write_bytes(b"original fixture bytes")
    return source, tmp_path / "new-destination-parent" / "game"


def test_held_source_write_handle_is_refused_without_fixture_mutation(
    source_and_destination, tmp_path: Path
):
    source, destination = source_and_destination
    before = snapshot_tree(tmp_path)

    with exclusive_handle(source / "ordinary.bin", _GENERIC_WRITE):
        code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_PATH_ACCESS"
    assert snapshot_tree(tmp_path) == before


def test_destination_ancestor_that_is_not_a_directory_is_refused_unchanged(
    source_and_destination, tmp_path: Path
):
    source, _ = source_and_destination
    blocked_parent = tmp_path / "blocked-destination-parent"
    blocked_parent.write_bytes(b"not a destination directory")
    destination = blocked_parent / "game"
    before = snapshot_tree(tmp_path)

    code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_ENTRY_TYPE"
    assert snapshot_tree(tmp_path) == before


def test_existing_delete_access_on_source_directory_is_refused(source_and_destination, tmp_path):
    source, destination = source_and_destination
    before = snapshot_tree(tmp_path)
    # Existing DELETE access, sharing everything. The measuring handle's omission
    # of FILE_SHARE_DELETE must still refuse this; desiredAccess=0 did not do so.
    with exclusive_handle(source, 0x10000, share=7, flags=0x02000000):
        code, payload = measure(source, destination)
    assert code == 3
    assert payload["code"] == "BGSE_E_PATH_ACCESS"
    assert snapshot_tree(tmp_path) == before


def test_unready_destination_volume_is_refused_sanitized_and_unchanged(
    source_and_destination, tmp_path: Path
):
    source, _ = source_and_destination
    destination = get_unused_drive_root() / "offline-reference-destination"
    before = snapshot_tree(tmp_path)

    code, payload = measure(source, destination)

    assert code == 3
    assert payload["code"] == "BGSE_E_VOLUME"
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("omitted", ["allowance", "reserve"])
def test_omitted_explicit_capacity_input_is_refused_unchanged(
    source_and_destination, tmp_path: Path, omitted: str
):
    source, destination = source_and_destination
    before = snapshot_tree(tmp_path)

    code, payload = invoke_without_capacity(source, destination, omitted)

    assert code == 3
    assert payload["code"] == "BGSE_E_CAPACITY"
    assert snapshot_tree(tmp_path) == before


def test_missing_measurement_library_is_a_sanitized_generic_wrapper_refusal(
    source_and_destination, tmp_path: Path
):
    source, destination = source_and_destination
    fixture_script = tmp_path / "wrapper-fixture" / SCRIPT.name
    fixture_script.parent.mkdir()
    fixture_script.write_text(SCRIPT.read_text(encoding="utf-8"), encoding="utf-8")
    before = snapshot_tree(tmp_path)

    result = subprocess.run(
        [
            POWERSHELL_PATH,
            "-NoProfile",
            "-File",
            str(fixture_script),
            "-SourceRoot",
            str(source),
            "-DestinationRoot",
            str(destination),
            "-OutputAllowanceBytes",
            "0",
            "-SafetyReserveBytes",
            "0",
        ],
        cwd=REPOSITORY_ROOT,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )

    assert result.returncode == 3
    assert result.stderr == ""
    lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(lines) == 1
    payload = json.loads(lines[0])
    assert payload["schemaVersion"] == 1
    assert payload["status"] == "refused"
    assert payload["code"] == "BGSE_E_MEASUREMENT"
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert payload["processCheck"] == "unexecuted"
    disclosed = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    for path in (source, destination, fixture_script, fixture_script.parent / "lib"):
        assert str(path).casefold() not in disclosed
    assert snapshot_tree(tmp_path) == before


def test_reflected_observation_verifier_refuses_a_known_source_change(
    source_and_destination, tmp_path: Path
):
    """Exercise the real private verifier between two deterministic inventories."""
    source, _ = source_and_destination
    observed_file = source / "ordinary.bin"
    environment = os.environ.copy()
    environment.update(
        {
            "BGSE_TEST_MEASUREMENT_SOURCE": str(
                REPOSITORY_ROOT / "scripts" / "lib" / "SourceMeasurement.cs"
            ),
            "BGSE_TEST_OBSERVED_SOURCE": str(source),
            "BGSE_TEST_OBSERVED_FILE": str(observed_file),
        }
    )
    command = r'''$ErrorActionPreference = 'Stop'
Add-Type -Path $env:BGSE_TEST_MEASUREMENT_SOURCE
$flags = [System.Reflection.BindingFlags]'NonPublic,Static'
$type = [Bgse.Lab.SourceMeasurement]
$inventory = $type.GetMethod('Inventory', $flags)
$verify = $type.GetMethod('VerifyObservations', $flags)
if ($null -eq $inventory -or $null -eq $verify) { throw 'expected private observation verifier' }
$first = $inventory.Invoke($null, @($env:BGSE_TEST_OBSERVED_SOURCE))
[System.IO.File]::AppendAllText($env:BGSE_TEST_OBSERVED_FILE, ' deliberate change')
$second = $inventory.Invoke($null, @($env:BGSE_TEST_OBSERVED_SOURCE))
try {
    $verify.Invoke($null, @($first, $second))
    $code = 'unexpected-success'
}
catch {
    $exception = $_.Exception
    while ($null -ne $exception.InnerException) { $exception = $exception.InnerException }
    $code = $exception.Message
}
[Console]::Out.WriteLine((@{ code = $code; writesAuthorized = $false; runtimeReady = $false } | ConvertTo-Json -Compress))'''
    before_mutation = snapshot_tree(tmp_path)
    result = subprocess.run(
        [POWERSHELL_PATH, "-NoProfile", "-Command", command],
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )
    after_intentional_mutation = snapshot_tree(tmp_path)

    assert result.returncode == 0, result.stderr or result.stdout
    assert result.stderr == ""
    lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(lines) == 1
    payload = json.loads(lines[0])
    assert payload == {
        "code": "BGSE_E_SOURCE_CHANGED",
        "runtimeReady": False,
        "writesAuthorized": False,
    }
    disclosed = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    assert str(source).casefold() not in disclosed
    assert str(observed_file).casefold() not in disclosed
    assert before_mutation != after_intentional_mutation
    assert observed_file.read_bytes() == b"original fixture bytes deliberate change"
    assert {
        relative: record
        for relative, record in after_intentional_mutation.items()
        if relative not in {".", "source/ordinary.bin"}
    } == {
        relative: record
        for relative, record in before_mutation.items()
        if relative not in {".", "source/ordinary.bin"}
    }
