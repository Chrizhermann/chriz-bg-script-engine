"""Exclusive native creation in synthetic NTFS trees; not copy admission."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT, create_junction, snapshot_tree


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def invoke(destination, body):
    library = REPOSITORY_ROOT / "scripts" / "lib"
    script = f"""
$ErrorActionPreference = 'Stop'
Add-Type -Path @({literal(library / 'SourceMeasurement.cs')}, {literal(library / 'FreshTree.cs')})
$tree = $null
try {{
    $tree = [Bgse.Lab.FreshTree]::new({literal(destination)})
    {body}
}} catch {{
    $errorValue = $_.Exception
    while ($null -ne $errorValue.InnerException) {{ $errorValue = $errorValue.InnerException }}
    @{{ code = $errorValue.Message; type = $errorValue.GetType().FullName }} | ConvertTo-Json -Compress
}} finally {{ if ($null -ne $tree) {{ $tree.Dispose() }} }}
"""
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", script],
                            capture_output=True, encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == "", result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


def test_constructor_is_read_only_and_disposal_does_not_create(tmp_path):
    destination = tmp_path / "missing" / "game"
    before = snapshot_tree(tmp_path)
    result = invoke(destination, "@{ code = 'validated' } | ConvertTo-Json -Compress")
    assert result["code"] == "validated"
    assert snapshot_tree(tmp_path) == before


def test_creates_independent_files_and_empty_directories_and_retains_on_dispose(tmp_path):
    destination = tmp_path / "missing" / "game"
    result = invoke(destination, """
    $tree.CreateRoot()
    $tree.CreateDirectory('empty')
    $tree.CreateDirectory('nested')
    $handle = $tree.CreateFile('nested/naïve[1].bin')
    $stream = [IO.FileStream]::new($handle, [IO.FileAccess]::ReadWrite)
    try {
        $data = [byte[]](0, 1, 2, 255)
        $stream.Write($data, 0, $data.Length)
        $stream.Flush($true)
        $stream.Position = 0
        $read = [byte[]]::new(4)
        $length = $stream.Read($read, 0, 4)
        @{ code = 'created'; length = $length; read = @($read) } | ConvertTo-Json -Compress
    } finally { $stream.Dispose() }
    """)
    assert result == {"code": "created", "length": 4, "read": [0, 1, 2, 255]}
    assert (destination / "empty").is_dir()
    assert (destination / "nested" / "naïve[1].bin").read_bytes() == bytes([0, 1, 2, 255])
    assert not (destination / ".bgse-disposable-lab.json").exists()


@pytest.mark.parametrize("relative", ["../escape", "/escape", "C:/escape", "a\\b", "a//b",
                                      ".", "", "a/../b", "file:stream", "NUL", "bad.", "bad "])
def test_noncanonical_child_names_are_refused(tmp_path, relative):
    destination = tmp_path / "game"
    result = invoke(destination, f"$tree.CreateRoot(); $tree.CreateFile({literal(relative)}) | Out-Null")
    assert result["code"] == "BGSE_E_PATH_SYNTAX"
    assert list(destination.iterdir()) == []


def test_creation_requires_root_and_cannot_reenter_root_creation(tmp_path):
    destination = tmp_path / "game"
    before = snapshot_tree(tmp_path)
    result = invoke(destination, "$tree.CreateDirectory('empty')")
    assert result["code"] == "BGSE_E_CREATION_STATE"
    assert snapshot_tree(tmp_path) == before
    result = invoke(destination, "$tree.CreateRoot(); $tree.CreateRoot()")
    assert result["code"] == "BGSE_E_CREATION_STATE"
    assert list(destination.iterdir()) == []


def test_reports_whole_missing_root_footprint_before_any_write(tmp_path):
    destination = tmp_path / "new-parent" / "reference" / "game"
    before = snapshot_tree(tmp_path)
    result = invoke(destination, "@{ planned = @($tree.PlannedDirectories) } | ConvertTo-Json -Compress")
    assert result["planned"] == [str(tmp_path / "new-parent"),
                                 str(tmp_path / "new-parent" / "reference"), str(destination)]
    assert snapshot_tree(tmp_path) == before


def test_caller_cannot_mutate_creation_plan_through_returned_array(tmp_path):
    destination = tmp_path / "missing" / "game"
    result = invoke(destination, f"""
    $plan = $tree.PlannedDirectories
    $plan[0] = {literal(tmp_path / 'escape')}
    $tree.CreateRoot()
    @{{ code = 'created' }} | ConvertTo-Json -Compress
    """)
    assert result["code"] == "created"
    assert destination.is_dir()
    assert not (tmp_path / "escape").exists()


def test_native_parameter_layout_and_missing_export_guard(tmp_path):
    result = invoke(tmp_path / "game", """
    $flags = [Reflection.BindingFlags]'NonPublic,Static'
    $type = [Bgse.Lab.FreshTree].GetNestedType('FileParameters', [Reflection.BindingFlags]'NonPublic')
    $value = [Activator]::CreateInstance($type)
    $size = [Runtime.InteropServices.Marshal]::SizeOf($value)
    $security = [Runtime.InteropServices.Marshal]::OffsetOf($type, 'Security').ToInt32()
    $template = [Runtime.InteropServices.Marshal]::OffsetOf($type, 'Template').ToInt32()
    $guard = [Bgse.Lab.FreshTree].GetMethod('RequireExports', $flags)
    $codes = @()
    foreach ($pair in @(@($false,$true), @($true,$false), @($false,$false))) {
        try { $guard.Invoke($null, [object[]]$pair); $codes += 'accepted' }
        catch {
            $failure = $_.Exception
            while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
            $codes += $failure.Message
        }
    }
    @{ size=$size; security=$security; template=$template; codes=@($codes) } | ConvertTo-Json -Compress
    """)
    assert result == {"size": 32, "security": 16, "template": 24,
                      "codes": ["BGSE_E_UNSUPPORTED_HOST"] * 3}


def test_failure_disables_instance_and_disposal_preserves_partial_output(tmp_path):
    destination = tmp_path / "game"
    result = invoke(destination, """
    $tree.CreateRoot()
    $tree.CreateDirectory('kept')
    try { $tree.CreateFile('../escape') | Out-Null } catch {}
    $tree.CreateDirectory('after-failure')
    """)
    assert result["code"] == "BGSE_E_CREATION_STATE"
    assert [entry.name for entry in destination.iterdir()] == ["kept"]


def test_native_failure_mid_root_creation_retains_earlier_owned_ancestor(tmp_path):
    # NTFS component-length failure after the first new ancestor was created.
    # No failure-injection switch is exposed in the operational API.
    partial = tmp_path / "partial-parent"
    destination = partial / ("x" * 256) / "game"
    result = invoke(destination, "$tree.CreateRoot()")
    assert result["code"] == "BGSE_E_PATH_ACCESS"
    assert partial.is_dir()
    assert list(partial.iterdir()) == []


def test_case_insensitive_duplicate_refused_without_second_entry(tmp_path):
    destination = tmp_path / "game"
    result = invoke(destination, "$tree.CreateRoot(); $tree.CreateDirectory('Mixed'); $tree.CreateDirectory('MIXED')")
    assert result["code"] == "BGSE_E_DESTINATION_EXISTS"
    assert [entry.name for entry in destination.iterdir()] == ["Mixed"]


def test_disposal_closes_only_directories_and_prevents_further_creation(tmp_path):
    destination = tmp_path / "game"
    result = invoke(destination, "$tree.CreateRoot(); $tree.Dispose(); $tree.CreateFile('later') | Out-Null")
    assert result["code"] == "BGSE_E_CREATION_STATE"
    assert list(destination.iterdir()) == []


def test_actual_directory_and_file_write_sharing_is_denied(tmp_path):
    destination = tmp_path / "game"
    result = invoke(destination, f"""
    $tree.CreateRoot()
    $tree.CreateDirectory('owned')
    $method = [Bgse.Lab.SourceMeasurement].GetMethod('CreateFileW', [Reflection.BindingFlags]'NonPublic,Static')
    $conflict = $method.Invoke($null, @({literal(destination / 'owned')}, [uint32]0x40000000,
        [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0x02200000, [IntPtr]::Zero))
    $directoryError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $directoryDenied = $conflict.IsInvalid
    $conflict.Dispose()
    $handle = $tree.CreateFile('held.bin')
    try {{
        $fileDenied = $false
        try {{
            $unexpected = [IO.File]::Open({literal(destination / 'held.bin')}, [IO.FileMode]::Open,
                [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            $unexpected.Dispose()
        }} catch [IO.IOException] {{ $fileDenied = $true }}
    }} finally {{ $handle.Dispose() }}
    $tree.Dispose()
    $control = $method.Invoke($null, @({literal(destination / 'owned')}, [uint32]0x40000000,
        [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0x02200000, [IntPtr]::Zero))
    $controlAllowed = !$control.IsInvalid
    $control.Dispose()
    @{{ directoryDenied=$directoryDenied; directoryError=$directoryError;
        fileDenied=$fileDenied; afterDisposeAllowed=$controlAllowed }} | ConvertTo-Json -Compress
    """)
    assert result == {"directoryDenied": True, "directoryError": 32,
                      "fileDenied": True, "afterDisposeAllowed": True}


def test_native_directory_collision_returns_refusal_and_preserves_directory(tmp_path):
    existing = tmp_path / "existing"
    existing.mkdir()
    (existing / "kept.bin").write_bytes(b"untouched")
    before = snapshot_tree(existing)
    result = invoke(tmp_path / "unused-game", f"""
    $method = [Bgse.Lab.FreshTree].GetMethod('NewDirectory', [Reflection.BindingFlags]'NonPublic,Static')
    $method.Invoke($null, @({literal(existing)})) | Out-Null
    """)
    assert result["code"] == "BGSE_E_DESTINATION_EXISTS"
    assert snapshot_tree(existing) == before


@pytest.mark.parametrize("method", ["NewDirectory", "NewFile"])
def test_mutating_native_operation_itself_refuses_redirect_not_just_preflight(tmp_path, method):
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "kept.bin").write_bytes(b"untouched")
    junction = tmp_path / "junction"
    create_junction(junction, outside)
    before = snapshot_tree(outside)
    try:
        # Deterministic test of the private create boundary used by FreshTree;
        # bypasses path preflight, not the native operation's redirect guard.
        result = invoke(tmp_path / "unused-game", f"""
        $method = [Bgse.Lab.FreshTree].GetMethod({literal(method)}, [Reflection.BindingFlags]'NonPublic,Static')
        $method.Invoke($null, @({literal(junction / 'must-not-create')})) | Out-Null
        """)
        assert result["code"] == "BGSE_E_PATH_ACCESS"
        assert snapshot_tree(outside) == before
    finally:
        os.rmdir(junction)
