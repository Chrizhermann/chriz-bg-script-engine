"""Deterministic native decoder tests; no volume or game paths are queried."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT


LIBRARY = REPOSITORY_ROOT / "scripts" / "lib"
MAX_SIGNED = 2**63 - 1


def probe(method: str, arguments: list[object]) -> dict[str, object]:
    environment = os.environ.copy()
    environment["BGSE_NATIVE_DECODER_LIBRARY"] = str(LIBRARY)
    environment["BGSE_NATIVE_DECODER_CASE"] = json.dumps({
        "method": method,
        "arguments": [str(value) if isinstance(value, int) else value for value in arguments],
    })
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    Add-Type -Path @((Join-Path $env:BGSE_NATIVE_DECODER_LIBRARY 'SourceMeasurement.cs'),
        (Join-Path $env:BGSE_NATIVE_DECODER_LIBRARY 'AcquisitionCapacity.cs'),
        (Join-Path $env:BGSE_NATIVE_DECODER_LIBRARY 'NativeCapacity.cs'))
    $case = $env:BGSE_NATIVE_DECODER_CASE | ConvertFrom-Json
    $method = [Bgse.Lab.NativeCapacity].GetMethod($case.method,
        [Reflection.BindingFlags]'NonPublic,Static')
    if ($null -eq $method) { throw 'missing-private-decoder' }
    $values = $case.arguments
    if ($case.method -ceq 'ValidateCapacity') {
        $parameters = [object[]]@(
            [int]::Parse([string]$values[0]),
            [int]::Parse([string]$values[1]),
            [UInt64]::Parse([string]$values[2]),
            [long]::Parse([string]$values[3]),
            [long]::Parse([string]$values[4]),
            [long]::Parse([string]$values[5]),
            [uint32]::Parse([string]$values[6]),
            [uint32]::Parse([string]$values[7]))
    } elseif ($case.method -ceq 'VolumeKey') {
        $parameters = [object[]]@([string]$values[0])
    } elseif ($case.method -ceq 'ValidateDevice') {
        $parameters = [object[]]@(
            [uint32]::Parse([string]$values[0]),
            [uint32]::Parse([string]$values[1]),
            [string]$values[2],
            [uint32]::Parse([string]$values[3]))
    } else { throw 'unknown-test-method' }
    $answer = $method.Invoke($null, $parameters)
    if ($case.method -ceq 'ValidateCapacity') {
        @{ code='decoded'; values=@($answer) } | ConvertTo-Json -Compress -Depth 3
    } elseif ($case.method -ceq 'VolumeKey') {
        @{ code='decoded'; value=$answer } | ConvertTo-Json -Compress
    } else {
        @{ code='decoded'; value=$null } | ConvertTo-Json -Compress
    }
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName } | ConvertTo-Json -Compress
}
"""
    result = subprocess.run(
        [POWERSHELL_PATH, "-NoProfile", "-Command", command],
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        encoding="utf-8",
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    assert result.stderr == "", result.stderr
    lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(lines) == 1
    return json.loads(lines[0])


def capacity(*, status: int = 0, completion: int = 0, returned: int = 32,
             total: int = 100, caller: int = 90, actual: int = 120,
             sectors: int = 2, bytes_per_sector: int = 4096) -> dict[str, object]:
    return probe("ValidateCapacity", [status, completion, returned, total, caller, actual,
                                      sectors, bytes_per_sector])


def assert_refused(result: dict[str, object], code: str) -> None:
    assert result == {"code": code, "type": "Bgse.Lab.MeasurementRefusal"}


def test_valid_capacity_allows_actual_free_above_caller_total() -> None:
    # The available-to-caller product comes from caller-free, not actual-free.
    assert capacity() == {"code": "decoded", "values": [8192, 90 * 8192]}


@pytest.mark.parametrize(("field", "value"), [
    ("status", 1), ("status", 259), ("status", 0x40000000), ("status", -1),
    ("completion", 1), ("completion", 259), ("completion", -1),
])
def test_status_and_completion_require_exact_success(field: str, value: int) -> None:
    assert_refused(capacity(**{field: value}), "BGSE_E_CAPACITY_NATIVE")


@pytest.mark.parametrize("returned", [0, 31, 33])
def test_full_size_information_requires_exact_32_returned_bytes(returned: int) -> None:
    assert_refused(capacity(returned=returned), "BGSE_E_CAPACITY_NATIVE")


@pytest.mark.parametrize("field", ["total", "caller", "actual"])
def test_negative_allocation_counts_refuse(field: str) -> None:
    assert_refused(capacity(**{field: -1}), "BGSE_E_CAPACITY_NATIVE")


@pytest.mark.parametrize("values", [
    {"total": 89, "caller": 90, "actual": 100},
    {"total": 100, "caller": 90, "actual": 89},
])
def test_caller_free_cannot_exceed_caller_total_or_actual_free(values: dict[str, int]) -> None:
    assert_refused(capacity(**values), "BGSE_E_CAPACITY_NATIVE")


@pytest.mark.parametrize("field", ["sectors", "bytes_per_sector"])
def test_zero_geometry_refuses(field: str) -> None:
    assert_refused(capacity(**{field: 0}), "BGSE_E_CAPACITY_NATIVE")


def test_maximum_uint32_geometry_product_itself_does_not_overflow() -> None:
    # UInt32.MaxValue squared still fits UInt64; use one allocation unit so
    # only the geometry multiplication is near the boundary.
    unit = (2**32 - 1) ** 2
    assert capacity(total=1, caller=1, actual=1, sectors=2**32 - 1,
                    bytes_per_sector=2**32 - 1) == {
        "code": "decoded", "values": [unit, unit]
    }


def test_total_byte_product_overflow_refuses() -> None:
    assert_refused(capacity(total=MAX_SIGNED, caller=1, actual=1,
                            sectors=2, bytes_per_sector=2),
                   "BGSE_E_CAPACITY_OVERFLOW")


def test_actual_free_byte_product_overflow_refuses_independently() -> None:
    # Actual free may exceed total. Keep total/caller products small to isolate it.
    assert_refused(capacity(total=1, caller=1, actual=MAX_SIGNED,
                            sectors=2, bytes_per_sector=2),
                   "BGSE_E_CAPACITY_OVERFLOW")


def test_caller_free_byte_product_near_limit_is_valid() -> None:
    # Caller-free <= total means an overflow of caller's product also overflows
    # total's product. This valid edge checks that the caller product is retained.
    result = capacity(total=MAX_SIGNED, caller=MAX_SIGNED - 1,
                      actual=MAX_SIGNED, sectors=1, bytes_per_sector=2)
    assert result == {"code": "decoded", "values": [2, (MAX_SIGNED - 1) * 2]}


@pytest.mark.parametrize(("native_root", "expected"), [
    ("\\Device\\HarddiskVolume1\\", "NTVOLUME_1"),
    ("\\Device\\HarddiskVolume9876543210\\", "NTVOLUME_9876543210"),
])
def test_volume_key_accepts_only_exact_positive_decimal_device_root(
    native_root: str, expected: str
) -> None:
    assert probe("VolumeKey", [native_root]) == {"code": "decoded", "value": expected}


@pytest.mark.parametrize("native_root", [
    "", "\\Device\\HarddiskVolume0\\", "\\Device\\HarddiskVolume01\\",
    "\\Device\\HarddiskVolume12345678901\\", "\\Device\\HarddiskVolume-1\\",
    "\\Device\\HarddiskVolume1", "\\Device\\HarddiskVolume1\\child\\",
    "\\Device\\HarddiskVolume1\\\n", "\\device\\HarddiskVolume1\\",
    "\\Device\\harddiskVolume1\\", "\\Device\\HarddiskVolume1/",
    "\\Device\\CdRom1\\", "C:\\",
])
def test_volume_key_rejects_noncanonical_or_nonroot_names(native_root: str) -> None:
    assert_refused(probe("VolumeKey", [native_root]), "BGSE_E_CAPACITY_IDENTITY")


def test_device_accepts_only_fixed_ntfs_without_restricted_flags() -> None:
    assert probe("ValidateDevice", [7, 0, "NTFS", 0]) == {
        "code": "decoded", "value": None
    }


@pytest.mark.parametrize("device_type,characteristics,filesystem,flags", [
    (6, 0, "NTFS", 0),
    (7, 1, "NTFS", 0),
    (7, 2, "NTFS", 0),
    (7, 16, "NTFS", 0),
    (7, 1 | 2 | 16, "NTFS", 0),
    (7, 0, "ntfs", 0),
    (7, 0, "ReFS", 0),
    (7, 0, "NTFS", 0x80000),
])
def test_device_refuses_wrong_type_characteristics_filesystem_or_readonly(
    device_type: int, characteristics: int, filesystem: str, flags: int
) -> None:
    assert_refused(probe("ValidateDevice", [device_type, characteristics, filesystem, flags]),
                   "BGSE_E_CAPACITY_VOLUME")
