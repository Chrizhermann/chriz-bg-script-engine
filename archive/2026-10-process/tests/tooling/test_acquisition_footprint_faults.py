"""Synthetic failure and handle-lifetime checks for packet A1's read-only footprint."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from test_acquisition_footprint import LIBRARY, assert_refused, invoke, roots
from test_environment_contract import (
    POWERSHELL_PATH,
    REPOSITORY_ROOT,
    create_junction,
    get_short_path,
    snapshot_tree,
)


@pytest.mark.parametrize("which", ["copy", "protected"])
def test_junction_in_output_or_protected_chain_refuses_without_following(
    roots, tmp_path: Path, which: str
) -> None:
    source, copy, evidence, protected = roots
    target = tmp_path / "synthetic-junction-target"
    target.mkdir()
    (target / "sentinel.bin").write_bytes(b"untouched junction target")
    junction = copy.parent if which == "copy" else tmp_path / "protected-junction"
    create_junction(junction, target)
    try:
        if which == "protected":
            protected = [*protected, junction]
        before = snapshot_tree(tmp_path)

        assert_refused(invoke(source, copy, evidence, protected), "BGSE_E_REPARSE_POINT")

        assert snapshot_tree(tmp_path) == before
        assert (target / "sentinel.bin").read_bytes() == b"untouched junction target"
    finally:
        os.rmdir(junction)


def test_existing_output_ancestor_short_alias_refuses_without_mutation(
    roots, tmp_path: Path
) -> None:
    source, _, evidence, protected = roots
    long_parent = tmp_path / "long copy output parent"
    long_parent.mkdir()
    alias = get_short_path(long_parent)
    copy = alias / "game"
    before = snapshot_tree(tmp_path)

    assert_refused(invoke(source, copy, evidence, protected), "BGSE_E_ALIAS")

    assert snapshot_tree(tmp_path) == before
    assert not (long_parent / "game").exists()


@pytest.mark.parametrize("which", ["copy", "evidence"])
def test_appeared_missing_output_ancestor_poisoned_after_refusal(
    roots, tmp_path: Path, which: str
) -> None:
    source, copy, evidence, protected = roots
    appeared = copy.parent if which == "copy" else evidence.parent
    before = snapshot_tree(tmp_path)
    body = rf"""
    $appeared = [IO.Directory]::CreateDirectory('{str(appeared).replace("'", "''")}')
    try {{
        $plan.Revalidate()
        throw 'unexpectedly-accepted-appeared-ancestor'
    }} catch {{
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) {{ $failure = $failure.InnerException }}
        if ($failure.Message -cne 'BGSE_E_DESTINATION_CHANGED') {{ throw }}
    }} finally {{
        $appeared.Delete()
    }}
    # The original observation stays poisoned even when the fixture is restored.
    """

    assert_refused(invoke(source, copy, evidence, protected, body=body),
                   "BGSE_E_FOOTPRINT_STATE")

    # The test itself briefly creates/deletes an ancestor, so the fixture root's
    # directory mtime changes. Every other root field and all child records stay.
    after = snapshot_tree(tmp_path)
    before["."].pop("mtime_ns")
    after["."].pop("mtime_ns")
    assert after == before
    assert not appeared.exists()


def test_held_protected_directory_blocks_rename_then_dispose_releases_it(
    roots, tmp_path: Path
) -> None:
    source, _, _, _ = roots
    moved = Path(str(source) + "-moved")
    body = r"""
    $moved = $request.source + '-moved'
    $blocked = $false
    try {
        [IO.Directory]::Move($request.source, $moved)
        [IO.Directory]::Move($moved, $request.source)
    } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked) { throw 'rename-allowed-while-held' }
    $plan.Dispose()
    try {
        [IO.Directory]::Move($request.source, $moved)
        [IO.Directory]::Move($moved, $request.source)
    } catch { throw 'rename-blocked-after-dispose' }
    """

    assert_refused(invoke(*roots, body=body), "BGSE_E_FOOTPRINT_STATE")

    assert source.is_dir()
    assert not moved.exists()
    assert (source / "sentinel.bin").read_bytes() == b"unchanged source"


def test_constructor_failure_releases_earlier_held_paths_in_same_process(
    roots, tmp_path: Path
) -> None:
    source, copy, evidence, protected = roots
    missing_protected = tmp_path / "absent-protected-root"
    request = {
        "source": str(source),
        "copy": str(copy),
        "evidence": str(evidence),
        "protected": [str(protected[0]), str(protected[1]), str(missing_protected)],
    }
    environment = os.environ.copy()
    environment["BGSE_FOOTPRINT_FAULT_REQUEST"] = json.dumps(request)
    environment["BGSE_FOOTPRINT_FAULT_LIBRARY"] = str(LIBRARY)
    command = r"""
$ErrorActionPreference = 'Stop'
$request = $env:BGSE_FOOTPRINT_FAULT_REQUEST | ConvertFrom-Json
Add-Type -Path @((Join-Path $env:BGSE_FOOTPRINT_FAULT_LIBRARY 'SourceMeasurement.cs'),
    (Join-Path $env:BGSE_FOOTPRINT_FAULT_LIBRARY 'AcquisitionFootprint.cs'))
$empty = [Bgse.Lab.PlannedEntry[]]@()
$plan = $null
try {
    $plan = [Bgse.Lab.AcquisitionFootprint]::new($request.source, $request.copy,
        $request.evidence, [string[]]@($request.protected), $empty, $empty)
    $code = 'unexpected-constructor-success'
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    $code = $failure.Message
} finally { if ($null -ne $plan) { $plan.Dispose() } }
$moved = $request.source + '-moved'
$released = $false
try {
    [IO.Directory]::Move($request.source, $moved)
    [IO.Directory]::Move($moved, $request.source)
    $released = $true
} catch [IO.IOException] { }
@{ code = $code; released = $released } | ConvertTo-Json -Compress
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
    assert result.stderr == ""
    payload = json.loads(result.stdout.lstrip("\ufeff"))
    assert payload == {"code": "BGSE_E_PATH_ACCESS", "released": True}
    assert source.is_dir()
    assert not Path(str(source) + "-moved").exists()
    assert not missing_protected.exists()
    assert (source / "sentinel.bin").read_bytes() == b"unchanged source"


@pytest.mark.parametrize("which", ["copy", "evidence"])
def test_existing_output_root_refuses_and_preserves_fixture(
    roots, tmp_path: Path, which: str
) -> None:
    source, copy, evidence, protected = roots
    output = copy if which == "copy" else evidence
    output.mkdir(parents=True)
    (output / "sentinel.bin").write_bytes(b"existing output must stay untouched")
    before = snapshot_tree(tmp_path)

    assert_refused(invoke(source, copy, evidence, protected), "BGSE_E_DESTINATION_EXISTS")

    assert snapshot_tree(tmp_path) == before


def test_existing_protected_file_is_not_treated_as_a_directory(
    roots, tmp_path: Path
) -> None:
    source, copy, evidence, protected = roots
    protected_file = protected[1] / "sentinel.bin"
    before = snapshot_tree(tmp_path)

    assert_refused(invoke(source, copy, evidence, [source, protected_file]),
                   "BGSE_E_ENTRY_TYPE")

    assert snapshot_tree(tmp_path) == before


def test_nested_protected_roots_are_valid_distinct_roots(roots, tmp_path: Path) -> None:
    source, copy, evidence, protected = roots
    nested = source / "nested-protected"
    nested.mkdir()
    (nested / "sentinel.bin").write_bytes(b"nested protected data")
    before = snapshot_tree(tmp_path)

    result = invoke(source, copy, evidence, [source, nested, protected[1]])

    assert result["code"] == "footprint-only"
    assert snapshot_tree(tmp_path) == before
    assert not copy.exists()
    assert not evidence.exists()


def test_source_argument_must_be_explicitly_in_protected_set(
    roots, tmp_path: Path
) -> None:
    source, copy, evidence, protected = roots
    other_source = tmp_path / "other-ordinary-source"
    other_source.mkdir()
    before = snapshot_tree(tmp_path)

    assert_refused(invoke(other_source, copy, evidence, protected),
                   "BGSE_E_PROTECTED_ROOTS")

    assert snapshot_tree(tmp_path) == before


def test_missing_source_refuses_even_when_named_in_protected_set(
    roots, tmp_path: Path
) -> None:
    _, copy, evidence, protected = roots
    missing_source = tmp_path / "missing-source"
    before = snapshot_tree(tmp_path)

    assert_refused(invoke(missing_source, copy, evidence,
                          [missing_source, protected[1]]), "BGSE_E_PATH_ACCESS")

    assert snapshot_tree(tmp_path) == before
    assert not missing_source.exists()
