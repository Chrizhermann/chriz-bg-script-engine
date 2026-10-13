"""Same-handle capacity observations on synthetic host paths, never game admission."""
from __future__ import annotations

import json
import os
import re
import subprocess

import pytest

from test_environment_contract import (
    POWERSHELL_PATH, REPOSITORY_ROOT, create_junction, get_short_path, snapshot_tree,
)

PURPOSES = ("working-copy", "future-baseline", "evidence")


def targets(tmp_path, reserve=123):
    return [[purpose, str(tmp_path / purpose / "output"), reserve] for purpose in PURPOSES]


def invoke(values, *, setup="", body="", action="$observation = [Bgse.Lab.NativeCapacity]::Observe($targets)"):
    environment = os.environ.copy()
    environment["BGSE_NATIVE_TARGETS"] = json.dumps(values)
    environment["BGSE_NATIVE_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    Add-Type -Path @((Join-Path $env:BGSE_NATIVE_LIBRARY 'SourceMeasurement.cs'),
        (Join-Path $env:BGSE_NATIVE_LIBRARY 'AcquisitionCapacity.cs'),
        (Join-Path $env:BGSE_NATIVE_LIBRARY 'NativeCapacity.cs'))
    $request = $env:BGSE_NATIVE_TARGETS | ConvertFrom-Json
    $targets = $null
    if ($null -ne $request) {
        $targets = [Bgse.Lab.CapacityTarget[]]::new($request.Count)
        for ($i=0; $i -lt $request.Count; $i++) {
            $item = $request[$i]
            if ($null -ne $item) {
                $reserve = $null
                if ($null -ne $item[2]) { $reserve = [UInt64]::Parse([string]$item[2]) }
                $targets[$i] = [Bgse.Lab.CapacityTarget]::new($item[0], $item[1], $reserve)
            }
        }
    }
    SETUP
    ACTION
    BODY
    @{ code='observed-only'; observation=$observation } | ConvertTo-Json -Depth 6 -Compress
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName } | ConvertTo-Json -Compress
}
""".replace("SETUP", setup).replace("BODY", body).replace("ACTION", action)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == "", result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


def test_fresh_siblings_share_one_volume_without_creating_outputs(tmp_path):
    fixture = tmp_path / "unchanged.txt"
    fixture.write_bytes(b"synthetic-only\x00\xff")
    before = snapshot_tree(tmp_path)
    result = invoke(targets(tmp_path))
    assert result["code"] == "observed-only", result
    observed = result["observation"]
    assert re.fullmatch(r"S-1-\d+(?:-\d+)+", observed["CallerSid"])
    assert len(observed["Volumes"]) == 1
    volume = observed["Volumes"][0]
    assert re.fullmatch(r"NTVOLUME_[1-9][0-9]{0,9}", volume["VolumeId"])
    assert volume["AllocationUnitBytes"] > 0
    assert volume["AvailableBytes"] >= 0
    assert volume["AvailableBytes"] % volume["AllocationUnitBytes"] == 0
    assert volume["SafetyReserveBytes"] == 123
    assert {b["Purpose"] for b in observed["Bindings"]} == set(PURPOSES)
    for binding in observed["Bindings"]:
        assert binding["DestinationRoot"] == str(tmp_path / binding["Purpose"] / "output")
        assert binding["ExistingAncestor"] == str(tmp_path)
        assert binding["VolumeId"] == volume["VolumeId"]
        assert re.fullmatch(r"[0-9a-f]{16}:[0-9a-f]{16}:[0-9a-f]{16}", binding["RootIdentity"])
        assert re.fullmatch(r"[0-9a-f]{16}:[0-9a-f]{16}:[0-9a-f]{16}", binding["AncestorIdentity"])
    assert sorted(p.name for p in tmp_path.iterdir()) == ["unchanged.txt"]
    assert fixture.read_bytes() == b"synthetic-only\x00\xff"
    assert snapshot_tree(tmp_path) == before


def refused(result, code):
    assert result == {"code": code, "type": "Bgse.Lab.MeasurementRefusal"}


@pytest.mark.parametrize("change", ["null", "empty", "two", "four", "null-item", "duplicate",
                                   "unknown-purpose", "case-purpose", "null-reserve", "null-path",
                                   "empty-path", "long-component", "marker"])
def test_bad_inputs_refuse_without_creating_anything(tmp_path, change):
    values = targets(tmp_path)
    if change == "null":
        values = None
    elif change == "empty":
        values = []
    elif change == "two":
        values.pop()
    elif change == "four":
        values.append(values[0])
    elif change == "null-item":
        values[0] = None
    elif change == "duplicate":
        values[0][0] = values[1][0]
    elif change == "unknown-purpose":
        values[0][0] = "other"
    elif change == "case-purpose":
        values[0][0] = "Working-copy"
    elif change == "null-reserve":
        values[0][2] = None
    elif change == "null-path":
        values[0][1] = None
    elif change == "empty-path":
        values[0][1] = ""
    elif change == "long-component":
        values[0][1] = str(tmp_path / ("z" * 256))
    elif change == "marker":
        values[0][1] = str(tmp_path / ".BGSE-disposable-LAB.json" / "child")
    before = snapshot_tree(tmp_path)
    refused(invoke(values), "BGSE_E_CAPACITY_INPUT")
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("suffix", [r"a\..\output", r"a\.\output", r"a\\output",
                                    "output.", "output ", "CON", "output:ads"])
def test_unsafe_path_spelling_refuses(tmp_path, suffix):
    values = targets(tmp_path)
    values[0][1] = str(tmp_path) + "\\" + suffix
    refused(invoke(values), "BGSE_E_PATH_SYNTAX")
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("relation", ["equal", "inside", "outside"])
def test_output_overlap_refuses_in_both_directions(tmp_path, relation):
    values = targets(tmp_path)
    values[1][1] = values[0][1]
    if relation == "inside":
        values[1][1] += "\\nested"
    if relation == "outside":
        values[0][1] += "\\nested"
    refused(invoke(values), "BGSE_E_OVERLAP")


@pytest.mark.parametrize("kind", ["directory", "file", "parent-file"])
def test_existing_or_wrong_type_output_refuses_unchanged(tmp_path, kind):
    values = targets(tmp_path)
    parent = tmp_path / "working-copy"
    if kind == "parent-file":
        parent.write_bytes(b"sentinel")
    else:
        parent.mkdir()
        if kind == "directory":
            (parent / "output").mkdir()
        else:
            (parent / "output").write_bytes(b"sentinel")
    before = snapshot_tree(tmp_path)
    refused(invoke(values), "BGSE_E_DESTINATION_EXISTS" if kind == "directory" else "BGSE_E_ENTRY_TYPE")
    assert snapshot_tree(tmp_path) == before


def test_junction_ancestor_is_not_followed(tmp_path):
    target = tmp_path / "synthetic-target"
    target.mkdir()
    (target / "sentinel").write_bytes(b"unchanged")
    junction = tmp_path / "working-copy"
    create_junction(junction, target)
    try:
        before = snapshot_tree(tmp_path)
        refused(invoke(targets(tmp_path)), "BGSE_E_REPARSE_POINT")
        assert snapshot_tree(tmp_path) == before
    finally:
        os.rmdir(junction)


def test_short_alias_ancestor_refuses(tmp_path):
    parent = tmp_path / "ordinary long ancestor name"
    parent.mkdir()
    alias = get_short_path(parent)
    values = targets(tmp_path)
    values[0][1] = str(alias / "output")
    before = snapshot_tree(tmp_path)
    refused(invoke(values), "BGSE_E_ALIAS")
    assert snapshot_tree(tmp_path) == before


def test_same_volume_inconsistent_reserves_refuse(tmp_path):
    values = targets(tmp_path)
    values[0][2] += 1
    refused(invoke(values), "BGSE_E_CAPACITY_IDENTITY")


def test_returned_arrays_and_records_are_immutable(tmp_path):
    result = invoke(targets(tmp_path), body=r"""
    $bindings = $observation.Bindings
    $volumes = $observation.Volumes
    $bindings[0] = $null
    $volumes[0] = $null
    $targets[0] = $null
    if ($null -eq $observation.Bindings[0] -or $null -eq $observation.Volumes[0]) { throw 'array-leak' }
    foreach ($type in @([Bgse.Lab.CapacityBinding], [Bgse.Lab.CapacityObservation], [Bgse.Lab.CapacityTarget])) {
        if (@($type.GetProperties() | Where-Object CanWrite).Count -ne 0) { throw 'mutable-property' }
    }
""")
    assert result["code"] == "observed-only", result
    assert len(result["observation"]["Bindings"]) == 3


@pytest.mark.parametrize("failure", [False, True])
def test_observe_releases_native_handles_inside_process(tmp_path, failure):
    parent = tmp_path / "existing-parent"
    parent.mkdir()
    values = [[purpose, str(parent / purpose), 123] for purpose in PURPOSES]
    if failure:
        values[2][2] = 124  # Fails Group after all handles and native samples exist.
    action = r"""
    $parent = [IO.Path]::GetDirectoryName($targets[0].DestinationRoot)
    try {
        $observation = [Bgse.Lab.NativeCapacity]::Observe($targets)
        if (EXPECT_FAILURE) { throw 'expected-refusal-missing' }
    } catch {
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
        if (-not (EXPECT_FAILURE) -or $failure.Message -cne 'BGSE_E_CAPACITY_IDENTITY') { throw }
        $observation = @{ release='after-refusal' }
    }
    [IO.Directory]::Move($parent, $parent + '-moved')
    [IO.Directory]::Move($parent + '-moved', $parent)
""".replace("EXPECT_FAILURE", "$true" if failure else "$false")
    result = invoke(values, action=action)
    assert result["code"] == "observed-only", result
    assert parent.is_dir()
    assert list(parent.iterdir()) == []


def test_second_observation_is_fresh_not_a_cached_binding(tmp_path):
    result = invoke(targets(tmp_path), body=r"""
    $parent = [IO.Path]::GetDirectoryName($targets[0].DestinationRoot)
    [void][IO.Directory]::CreateDirectory($parent)
    try {
        $new = [Bgse.Lab.NativeCapacity]::Observe($targets)
        $before = @($observation.Bindings | Where-Object Purpose -CEQ 'working-copy')[0]
        $after = @($new.Bindings | Where-Object Purpose -CEQ 'working-copy')[0]
        if ($before.ExistingAncestor -ceq $after.ExistingAncestor -or
            $before.AncestorIdentity -ceq $after.AncestorIdentity) { throw 'stale-binding' }
    } finally { [IO.Directory]::Delete($parent) }
""")
    assert result["code"] == "observed-only", result
    assert list(tmp_path.iterdir()) == []


def test_appeared_ancestor_refuses_real_revalidation_branch(tmp_path):
    # Invoke the private hold/Verify boundary. This is controlled branch evidence,
    # not an OS race occurring during an ordinary Observe call.
    setup = r"""
    $static = [Reflection.BindingFlags]'NonPublic,Static'
    $instance = [Reflection.BindingFlags]'NonPublic,Instance'
    $type = [Bgse.Lab.NativeCapacity]
    $heldType = $type.GetNestedType('Held', [Reflection.BindingFlags]'NonPublic')
    $held = [Activator]::CreateInstance($heldType, $true)
    $entries = [Bgse.Lab.SourceMeasurement].GetMethod('Ancestors', $static).Invoke(
        $null, [object[]]@($targets[0].DestinationRoot, $true))
    $parent = [IO.Path]::GetDirectoryName($targets[0].DestinationRoot)
    try {
        $heldType.GetField('Target', $instance).SetValue($held, $targets[0])
        $heldType.GetField('Entries', $instance).SetValue($held, $entries)
        $root = $type.GetMethod('NativePath', $static).Invoke($null, [object[]]@($entries[0].Handle))
        $heldType.GetField('NativeRoot', $instance).SetValue($held, $root)
        [void][IO.Directory]::CreateDirectory($parent)
        [void]$type.GetMethod('Verify', $static).Invoke($null, [object[]]@($held))
        throw 'appeared-ancestor-accepted'
    } finally {
        foreach ($entry in $entries) { $entry.Dispose() }
        [IO.Directory]::Delete($parent)
    }
"""
    refused(invoke(targets(tmp_path), setup=setup), "BGSE_E_DESTINATION_CHANGED")
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("change,code", [("none", None), ("root", "IDENTITY"),
                                       ("key", "IDENTITY"), ("unit", "IDENTITY"),
                                       ("reserve", "IDENTITY"), ("separate", None)])
def test_grouping_uses_minimum_and_rejects_inconsistent_identity_facts(change, code):
    # Pure reducer probe, not a claim to have mounted multiple native volumes.
    action = r"""
    $ctor = [Bgse.Lab.CapacityBinding].GetConstructors([Reflection.BindingFlags]'NonPublic,Instance')[0]
    $bindings = [Bgse.Lab.CapacityBinding[]]::new(3)
    $samples = [Bgse.Lab.CapacityVolume[]]::new(3)
    for ($i=0; $i -lt 3; $i++) {
        $key='NTVOLUME_1'; $root='root-one'; $unit=[UInt64]4096; $reserve=[UInt64]123
        if ($i -eq 1) {
            CHANGE
        }
        $bindings[$i] = $ctor.Invoke([object[]]@('purpose', 'destination', $key, 'ancestor', 'ancestor-id', $root))
        $samples[$i] = [Bgse.Lab.CapacityVolume]::new($key, $unit, [UInt64](../../../../tests/tooling/100-$i*10), $reserve)
    }
    $group = [Bgse.Lab.NativeCapacity].GetMethod('Group', [Reflection.BindingFlags]'NonPublic,Static')
    $observation = @{ Volumes=@($group.Invoke($null, [object[]]@($bindings, $samples))) }
""".replace("CHANGE", {
        "none": "", "root": "$root='root-two'", "key": "$key='NTVOLUME_2'",
        "unit": "$unit=8192", "reserve": "$reserve=124",
        "separate": "$key='NTVOLUME_2'; $root='root-two'",
    }[change])
    result = invoke(None, action=action)
    if code:
        refused(result, "BGSE_E_CAPACITY_" + code)
    else:
        assert result["code"] == "observed-only", result
        volumes = result["observation"]["Volumes"]
        assert len(volumes) == (2 if change == "separate" else 1)
        assert volumes[0]["VolumeId"] == "NTVOLUME_1"
        assert volumes[0]["AvailableBytes"] == 80
        assert volumes[0]["SafetyReserveBytes"] == 123
        if change == "separate":
            assert volumes[1]["VolumeId"] == "NTVOLUME_2"
            assert volumes[1]["AvailableBytes"] == 90


@pytest.mark.parametrize("left,right,same_volume,overlap", [
    (r"C:\planned\output", r"D:\planned\output", True, True),
    (r"C:\planned\output", r"D:\PLANNED\OUTPUT", True, True),
    (r"C:\planned\output", r"D:\planned\output\child", True, True),
    (r"C:\planned\output\child", r"D:\planned\output", True, True),
    (r"C:\planned\output", r"D:\planned\output-more", True, False),
    (r"C:\planned\output", r"D:\planned\output", False, False),
])
def test_volume_relative_overlap_guard(left, right, same_volume, overlap):
    values = [["working-copy", left, 123], ["future-baseline", right, 123],
              ["evidence", r"C:\other-output", 123]]
    action = r"""
    $keys = [string[]]@('NTVOLUME_1', 'SECOND_KEY', 'NTVOLUME_1')
    $paths = [string[]]@($targets | ForEach-Object DestinationRoot)
    $method = [Bgse.Lab.NativeCapacity].GetMethod('VerifyPhysicalDestinations', [Reflection.BindingFlags]'NonPublic,Static')
    if ($null -eq $method) { throw 'missing-physical-overlap-guard' }
    [void]$method.Invoke($null, [object[]]@($keys, $paths))
    $observation = @{ privateGuard='accepted' }
""".replace("SECOND_KEY", "NTVOLUME_1" if same_volume else "NTVOLUME_2")
    result = invoke(values, action=action)
    if overlap:
        refused(result, "BGSE_E_OVERLAP")
    else:
        assert result == {"code": "observed-only", "observation": {"privateGuard": "accepted"}}


@pytest.mark.parametrize("count,value,accepted", [(0, "", False), (32768, "x", False),
                                                 (9, "short", False), (5, "short", True)])
def test_native_path_result_length_guard(count, value, accepted):
    action = r"""
    $method = [Bgse.Lab.NativeCapacity].GetMethod('ValidateNativePathResult', [Reflection.BindingFlags]'NonPublic,Static')
    if ($null -eq $method) { throw 'missing-native-path-result-guard' }
    $observation = @{ value=$method.Invoke($null, [object[]]@([uint32]COUNT, 'VALUE')) }
""".replace("COUNT", str(count)).replace("VALUE", value)
    result = invoke(None, action=action)
    if accepted:
        assert result == {"code": "observed-only", "observation": {"value": value}}
    else:
        refused(result, "BGSE_E_CAPACITY_IDENTITY")


@pytest.mark.parametrize("count,accepted", [(32767, True), (32768, False), (32769, False)])
def test_native_path_large_result_boundary_without_command_line_limit(count, accepted):
    action = r"""
    $method = [Bgse.Lab.NativeCapacity].GetMethod('ValidateNativePathResult', [Reflection.BindingFlags]'NonPublic,Static')
    $value = 'x' * COUNT
    $answer = $method.Invoke($null, [object[]]@([uint32]COUNT, $value))
    $observation = @{ count=$answer.Length }
""".replace("COUNT", str(count))
    result = invoke(None, action=action)
    if accepted:
        assert result == {"code": "observed-only", "observation": {"count": count}}
    else:
        refused(result, "BGSE_E_CAPACITY_IDENTITY")


@pytest.mark.parametrize("kind", ["full-length", "invalid-utf16"])
def test_input_string_limits_reach_library_not_transport(tmp_path, kind):
    setup = r"""
    $bad = 'C:\' + [char]0xD800
    $targets[0] = [Bgse.Lab.CapacityTarget]::new('working-copy', $bad, [UInt64]123)
"""
    if kind == "full-length":
        setup = r"""
    $parts = [string[]]::new(129)
    for ($i=0; $i -lt $parts.Count; $i++) { $parts[$i] = 'x' * 255 }
    $bad = 'C:\' + [string]::Join('\', $parts)
    if ($bad.Length -lt 32767 -or @($parts | Where-Object { $_.Length -gt 255 }).Count) { throw 'bad-limit-fixture' }
    $targets[0] = [Bgse.Lab.CapacityTarget]::new('working-copy', $bad, [UInt64]123)
"""
    refused(invoke(targets(tmp_path), setup=setup), "BGSE_E_CAPACITY_INPUT")
    assert list(tmp_path.iterdir()) == []
