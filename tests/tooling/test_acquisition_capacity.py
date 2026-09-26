"""Pure capacity accounting; supplied numbers are not native disk admission."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT


MAX = 2**64 - 1
OVERHEAD = 65536
PURPOSES = ("working-copy", "future-baseline", "evidence")


def invoke(volumes, allocations, *, setup="", body=""):
    # Decimal strings preserve exact UInt64 values across the harness JSON.
    def exact(value):
        if isinstance(value, int):
            return str(value)
        if isinstance(value, (list, tuple)):
            return [exact(item) for item in value]
        return value

    environment = os.environ.copy()
    environment["BGSE_CAPACITY_REQUEST"] = json.dumps({"volumes": exact(volumes), "allocations": exact(allocations)})
    environment["BGSE_CAPACITY_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    Add-Type -Path @((Join-Path $env:BGSE_CAPACITY_LIBRARY 'SourceMeasurement.cs'),
        (Join-Path $env:BGSE_CAPACITY_LIBRARY 'AcquisitionCapacity.cs'))
    function Number($value) {
        if ($null -eq $value) { return $null }
        return [UInt64]::Parse([string]$value, [Globalization.CultureInfo]::InvariantCulture)
    }
    $request = $env:BGSE_CAPACITY_REQUEST | ConvertFrom-Json
    $volumes = $null
    if ($null -ne $request.volumes) {
        $volumes = [Bgse.Lab.CapacityVolume[]]::new($request.volumes.Count)
        for ($i=0; $i -lt $request.volumes.Count; $i++) {
            $v = $request.volumes[$i]
            if ($null -ne $v) { $volumes[$i] = [Bgse.Lab.CapacityVolume]::new(
                $v[0], (Number $v[1]), (Number $v[2]), (Number $v[3])) }
        }
    }
    $allocations = $null
    if ($null -ne $request.allocations) {
        $allocations = [Bgse.Lab.CapacityAllocation[]]::new($request.allocations.Count)
        for ($i=0; $i -lt $request.allocations.Count; $i++) {
            $a = $request.allocations[$i]
            if ($null -ne $a) {
                $files = $null
                if ($null -ne $a[2]) {
                    $files = [Nullable[UInt64][]]::new($a[2].Count)
                    for ($j=0; $j -lt $files.Count; $j++) { $files[$j] = Number $a[2][$j] }
                }
                $allocations[$i] = [Bgse.Lab.CapacityAllocation]::new(
                    $a[0], $a[1], $files, (Number $a[3]), (Number $a[4]))
            }
        }
    }
    SETUP
    $budgets = [Bgse.Lab.AcquisitionCapacity]::Calculate($volumes, $allocations)
    BODY
    @{ code = 'accounted-only'; budgets = @($budgets) } | ConvertTo-Json -Compress -Depth 5
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName } | ConvertTo-Json -Compress
}
""".replace("SETUP", setup).replace("BODY", body)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == "", result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


def allocation(purpose, *, volume="VOL_A", files=(), directories=1, extra=0):
    return [volume, purpose, None if files is None else list(files), directories, extra]


def empty_allocations():
    return [allocation(purpose) for purpose in PURPOSES]


def assert_refused(result, suffix="INPUT"):
    assert result == {"code": "BGSE_E_CAPACITY_" + suffix, "type": "Bgse.Lab.MeasurementRefusal"}


def test_shared_volume_exact_arithmetic_and_reserve_once():
    values = [allocation("working-copy", files=[0, 1, 4096, 4097], directories=3, extra=7),
              allocation("future-baseline", files=[12], directories=2, extra=9),
              allocation("evidence", files=[3], directories=1, extra=5)]
    working = 16384 + 7 * OVERHEAD + 7
    baseline = 4096 + 3 * OVERHEAD + 9
    evidence = 4096 + 2 * OVERHEAD + 5
    required = working + baseline + evidence + 123
    result = invoke([["VOL_A", 4096, required, 123]], values)
    assert result == {"code": "accounted-only", "budgets": [{
        "VolumeId": "VOL_A", "AllocationUnitBytes": 4096, "WorkingCopyBytes": working,
        "FutureBaselineBytes": baseline, "EvidenceBytes": evidence, "SafetyReserveBytes": 123,
        "RequiredBytes": required, "AvailableBytes": required, "RemainingBytes": 0,
    }]}


def test_separate_volume_units_and_deterministic_order():
    volumes = [["VOL_Z", 8192, MAX, 3], ["VOL_A", 4096, MAX, 1], ["VOL_M", 512, MAX, 2]]
    allocations = [allocation("evidence", volume="VOL_Z", files=[8193]),
                   allocation("working-copy", volume="VOL_M", files=[513]),
                   allocation("future-baseline", volume="VOL_A", files=[4096])]
    result = invoke(volumes, allocations)
    assert result["code"] == "accounted-only"
    assert [item["VolumeId"] for item in result["budgets"]] == ["VOL_A", "VOL_M", "VOL_Z"]
    assert [item["RequiredBytes"] for item in result["budgets"]] == [2*OVERHEAD+4096+1, 2*OVERHEAD+1024+2, 2*OVERHEAD+16384+3]
    assert result == invoke(list(reversed(volumes)), list(reversed(allocations)))


@pytest.mark.parametrize("shortfall", [0, 1])
def test_exact_fit_is_accepted_one_byte_short_is_not(shortfall):
    result = invoke([["VOL_A", 4096, 3 * OVERHEAD - shortfall, 0]], empty_allocations())
    if shortfall:
        assert_refused(result, "INSUFFICIENT")
    else:
        assert result["budgets"][0]["RemainingBytes"] == 0


def test_surplus_elsewhere_cannot_hide_volume_deficit():
    allocations = empty_allocations()
    allocations[2][0] = "VOL_B"
    assert_refused(invoke([["VOL_A", 4096, MAX, 0], ["VOL_B", 4096, OVERHEAD - 1, 0]], allocations), "INSUFFICIENT")


@pytest.mark.parametrize("column", [1, 2, 3])
def test_unknown_volume_numbers_are_not_zero(column):
    volume = ["VOL_A", 4096, MAX, 0]
    volume[column] = None
    assert_refused(invoke([volume], empty_allocations()))


@pytest.mark.parametrize("field", ["files", "file", "directories", "extra"])
def test_unknown_allocation_numbers_are_not_zero(field):
    values = empty_allocations()
    if field == "files": values[0][2] = None
    if field == "file": values[0][2] = [None]
    if field == "directories": values[0][3] = None
    if field == "extra": values[0][4] = None
    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], values))


@pytest.mark.parametrize("volumes", [None, [], [None], [["VOL_A", 0, MAX, 0]],
    [["VOL_A", 4096, MAX, 0], ["VOL_A", 4096, MAX, 0]],
    [["VOL_A", 4096, MAX, 0], ["VOL_UNUSED", 4096, MAX, 0]],
    [[f"VOL_{i}", 4096, MAX, 0] for i in range(4)]])
def test_invalid_volume_collections_refused(volumes):
    assert_refused(invoke(volumes, empty_allocations()))


@pytest.mark.parametrize("values", [None, [], [None, None, None],
    [allocation("working-copy"), allocation("evidence")],
    [allocation("working-copy"), allocation("working-copy"), allocation("evidence")],
    [allocation("working-copy"), allocation("future-baseline"), allocation("unknown")]])
def test_invalid_allocation_collections_refused(values):
    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], values))


@pytest.mark.parametrize("key", [None, "", "vol_a", "VOL_A\n", " VOL_A", "VOL.A", "C:\\path", "_VOL", "V"*129])
def test_noncanonical_volume_keys_refused(key):
    values = [allocation(purpose, volume=key) for purpose in PURPOSES]
    assert_refused(invoke([[key, 4096, MAX, 0]], values))


@pytest.mark.parametrize("directories", [0, 1000001, MAX])
def test_entry_count_requires_root_and_has_finite_bound(directories):
    values = empty_allocations()
    values[0][3] = directories
    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], values))


def test_files_and_directories_share_count_limit():
    values = empty_allocations()
    values[0] = allocation("working-copy", files=[0], directories=1000000)
    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], values))
    values[0][3] = 999999
    result = invoke([["VOL_A", 4096, MAX, 0]], values)
    assert result["budgets"][0]["WorkingCopyBytes"] == 1000000 * OVERHEAD


@pytest.mark.parametrize("files,extra,reserve", [([MAX], 0, 0), ([MAX-4095], 0, 0),
    ([], MAX, 0), ([], 0, MAX), ([2**63, 2**63], 0, 0)])
def test_arithmetic_overflow_refuses_without_partial_result(files, extra, reserve):
    values = empty_allocations()
    values[0] = allocation("working-copy", files=files, extra=extra)
    assert_refused(invoke([["VOL_A", 4096, MAX, reserve]], values), "OVERFLOW")


def test_large_valid_rounding_does_not_use_overflowing_length_plus_unit():
    # length+unit-1 would overflow, but quotient/remainder and complete totals fit.
    unit = MAX - 4*OVERHEAD
    assert unit + unit - 1 > MAX
    values = empty_allocations()
    values[0] = allocation("working-copy", files=[unit])
    result = invoke([["VOL_A", unit, MAX, 0]], values)
    assert result["budgets"][0]["RequiredBytes"] == unit + 4*OVERHEAD


def test_allocation_constructor_and_getter_defend_file_array():
    setup = r"""
    $files = [Nullable[UInt64][]]@(1)
    $allocation = [Bgse.Lab.CapacityAllocation]::new('VOL_A','working-copy',$files,1,0)
    $files[0] = [UInt64]::MaxValue
    $exposed = $allocation.FileByteLimits
    $exposed[0] = [UInt64]::MaxValue
    $allocations[0] = $allocation
    """
    result = invoke([["VOL_A", 4096, MAX, 0]], empty_allocations(), setup=setup)
    assert result["budgets"][0]["WorkingCopyBytes"] == 4096 + 2*OVERHEAD


def test_result_does_not_change_with_input_array_or_return_array_mutation():
    body = r"""
    $volumes[0] = $null
    $allocations[0] = $null
    $saved = $budgets[0]
    $budgets[0] = $null
    $budgets = @($saved)
    foreach ($type in @([Bgse.Lab.VolumeBudget], [Bgse.Lab.CapacityVolume], [Bgse.Lab.CapacityAllocation])) {
        if ($type.GetFields([Reflection.BindingFlags]'Public,Instance').Count -ne 0) { throw 'mutable-field' }
        foreach ($p in $type.GetProperties()) { if ($null -ne $p.GetSetMethod()) { throw 'mutable-property' } }
    }
    """
    result = invoke([["VOL_A", 4096, MAX, 0]], empty_allocations(), body=body)
    assert result["budgets"][0]["RequiredBytes"] == 3*OVERHEAD


def test_constructor_rejects_oversize_array_without_calling_calculate():
    setup = r"""
    Add-Type -TypeDefinition @'
using System;
public static class CapacityConstructorFixture {
    public static ulong?[] Zeros() {
        var values = new ulong?[1000001];
        Array.Fill<ulong?>(values, 0);
        return values;
    }
}
'@
    $files = [CapacityConstructorFixture]::Zeros()
    $unexpected = [Bgse.Lab.CapacityAllocation]::new('VOL_A','working-copy',$files,1,0)
    throw 'constructor-accepted-oversize-array'
    """
    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], empty_allocations(), setup=setup))
