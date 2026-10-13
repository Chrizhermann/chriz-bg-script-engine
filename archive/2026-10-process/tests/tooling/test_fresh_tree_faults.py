"""Synthetic fault tests for FreshTree's narrowly owned write surface."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from test_environment_contract import (
    POWERSHELL_PATH,
    REPOSITORY_ROOT,
    create_junction,
    snapshot_tree,
)


SOURCE_MEASUREMENT = REPOSITORY_ROOT / "scripts" / "lib" / "SourceMeasurement.cs"
FRESH_TREE = REPOSITORY_ROOT / "scripts" / "lib" / "FreshTree.cs"


def invoke_fresh_tree(destination: Path, action: str, **values: Path | str):
    environment = os.environ.copy()
    environment.update(
        {
            "BGSE_TEST_SOURCE_MEASUREMENT": str(SOURCE_MEASUREMENT),
            "BGSE_TEST_FRESH_TREE": str(FRESH_TREE),
            "BGSE_TEST_DESTINATION": str(destination),
            "BGSE_TEST_ACTION": action,
        }
    )
    environment.update({f"BGSE_TEST_{name}": str(value) for name, value in values.items()})
    command = r'''$ErrorActionPreference = 'Stop'
Add-Type -Path @($env:BGSE_TEST_SOURCE_MEASUREMENT, $env:BGSE_TEST_FRESH_TREE)
$tree = $null
$result = [ordered]@{ code = 'BGSE_OK' }
try {
    $tree = [Bgse.Lab.FreshTree]::new($env:BGSE_TEST_DESTINATION)
    switch ($env:BGSE_TEST_ACTION) {
        'create-root' { $tree.CreateRoot() }
        'appeared-ancestor' {
            [System.IO.Directory]::CreateDirectory($env:BGSE_TEST_APPEARED) | Out-Null
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::Combine($env:BGSE_TEST_APPEARED, 'external.txt'),
                'external data'
            )
            $tree.CreateRoot()
        }
        'owned-rename' {
            $tree.CreateRoot()
            $tree.CreateDirectory('owned')
            try {
                [System.IO.Directory]::Move($env:BGSE_TEST_OWNED, $env:BGSE_TEST_RENAMED)
                $result['renameBlocked'] = $false
            }
            catch { $result['renameBlocked'] = $true }
        }
        'unowned-child' {
            $tree.CreateRoot()
            [System.IO.Directory]::CreateDirectory($env:BGSE_TEST_UNOWNED) | Out-Null
            $tree.CreateDirectory('external/child')
        }
        'file-collision' {
            $tree.CreateRoot()
            [System.IO.File]::WriteAllText($env:BGSE_TEST_COLLISION, 'external bytes')
            $tree.CreateFile('occupied.bin') | Out-Null
        }
        'relative' {
            $tree.CreateRoot()
            $tree.CreateDirectory($env:BGSE_TEST_RELATIVE)
        }
        default { throw "unknown test action" }
    }
}
catch {
    $exception = $_.Exception
    while ($null -ne $exception.InnerException) { $exception = $exception.InnerException }
    $result.code = $exception.Message
}
finally {
    if ($null -ne $tree) { $tree.Dispose() }
}
[Console]::Out.WriteLine(($result | ConvertTo-Json -Compress))'''
    result = subprocess.run(
        [POWERSHELL_PATH, "-NoProfile", "-Command", command],
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    assert result.stderr == ""
    lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(lines) == 1
    payload = json.loads(lines[0])
    disclosed = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    for value in (destination, *values.values()):
        assert str(value).casefold() not in disclosed
    return payload


def test_existing_destination_is_refused_without_touching_its_contents(tmp_path: Path):
    destination = tmp_path / "existing-destination"
    destination.mkdir()
    (destination / "sentinel.bin").write_bytes(b"must remain unchanged")
    before = snapshot_tree(tmp_path)

    payload = invoke_fresh_tree(destination, "create-root")

    assert payload == {"code": "BGSE_E_DESTINATION_EXISTS"}
    assert snapshot_tree(tmp_path) == before


def test_appeared_missing_ancestor_refuses_before_creating_destination(tmp_path: Path):
    appeared = tmp_path / "appeared-parent"
    destination = appeared / "new-root"

    payload = invoke_fresh_tree(destination, "appeared-ancestor", APPEARED=appeared)

    assert payload == {"code": "BGSE_E_DESTINATION_CHANGED"}
    assert (appeared / "external.txt").read_bytes() == b"external data"
    assert not destination.exists()


def test_owned_directory_cannot_be_renamed_while_tree_owns_it(tmp_path: Path):
    destination = tmp_path / "fresh-root"
    owned = destination / "owned"
    renamed = destination / "renamed"
    outside = tmp_path / "outside-sentinel.bin"
    outside.write_bytes(b"outside data")
    before = snapshot_tree(tmp_path)

    payload = invoke_fresh_tree(
        destination,
        "owned-rename",
        OWNED=owned,
        RENAMED=renamed,
    )

    assert payload == {"code": "BGSE_OK", "renameBlocked": True}
    assert owned.is_dir()
    assert not renamed.exists()
    assert outside.read_bytes() == b"outside data"
    after = snapshot_tree(tmp_path)
    assert after["outside-sentinel.bin"] == before["outside-sentinel.bin"]


def test_unowned_external_child_cannot_be_enrolled_as_an_owned_parent(tmp_path: Path):
    destination = tmp_path / "fresh-root"
    unowned = destination / "external"

    payload = invoke_fresh_tree(destination, "unowned-child", UNOWNED=unowned)

    assert payload == {"code": "BGSE_E_CREATION_STATE"}
    assert unowned.is_dir()
    assert not (unowned / "child").exists()


def test_file_collision_is_refused_without_overwriting_external_bytes(tmp_path: Path):
    destination = tmp_path / "fresh-root"
    collision = destination / "occupied.bin"

    payload = invoke_fresh_tree(destination, "file-collision", COLLISION=collision)

    assert payload == {"code": "BGSE_E_DESTINATION_EXISTS"}
    assert collision.read_bytes() == b"external bytes"
    assert snapshot_tree(destination)["occupied.bin"]["bytes"] == b"external bytes"


def test_junction_ancestor_is_refused_without_writing_outside(tmp_path: Path):
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "sentinel.bin").write_bytes(b"outside remains untouched")
    junction = tmp_path / "junction"
    create_junction(junction, outside)
    destination = junction / "new-root"
    before = snapshot_tree(tmp_path)
    try:
        payload = invoke_fresh_tree(destination, "create-root")
        after = snapshot_tree(tmp_path)
    finally:
        os.rmdir(junction)

    assert payload == {"code": "BGSE_E_REPARSE_POINT"}
    assert after == before
    assert (outside / "sentinel.bin").read_bytes() == b"outside remains untouched"


def test_unsafe_relative_component_is_refused_without_an_escape(tmp_path: Path):
    destination = tmp_path / "fresh-root"

    payload = invoke_fresh_tree(destination, "relative", RELATIVE="../escaped")

    assert payload == {"code": "BGSE_E_PATH_SYNTAX"}
    assert destination.is_dir()
    assert not (tmp_path / "escaped").exists()
