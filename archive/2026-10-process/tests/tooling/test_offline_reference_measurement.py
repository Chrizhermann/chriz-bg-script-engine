"""Read-only Windows acquisition measurements, never game/launch acceptance."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from test_environment_contract import (
    POWERSHELL_PATH, REPOSITORY_ROOT, create_junction, get_short_path, snapshot_tree,
)


SCRIPT = REPOSITORY_ROOT / "scripts" / "measure-offline-reference.ps1"


def measure(source, destination, *, allowance="1048576", reserve="1048576", whatif=True):
    command = [POWERSHELL_PATH, "-NoProfile", "-File", str(SCRIPT),
               "-SourceRoot", str(source), "-DestinationRoot", str(destination),
               "-OutputAllowanceBytes", allowance, "-SafetyReserveBytes", reserve]
    if whatif:
        command.append("-WhatIf")
    result = subprocess.run(command, cwd=REPOSITORY_ROOT, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.stderr == ""
    assert len(result.stdout.strip().splitlines()) == 1
    payload = json.loads(result.stdout.lstrip("\ufeff"))
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert payload["processCheck"] == "unexecuted"
    assert payload["writableRootAdmission"] == "unexecuted"
    output = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    assert str(source).casefold() not in output
    assert str(destination).casefold() not in output
    return result.returncode, payload


@pytest.fixture
def trees(tmp_path):
    source = tmp_path / "source with spaces"
    source.mkdir()
    (source / "empty").mkdir()
    (source / "nested").mkdir()
    (source / "a.bin").write_bytes(b"abc")
    (source / "nested" / "naïve[1].bin").write_bytes(b"12345")
    return source, tmp_path / "fresh-parent" / "game"


@pytest.mark.parametrize("whatif", [True, False])
def test_measurement_is_read_only_and_not_write_or_runtime_admission(trees, tmp_path, whatif):
    source, destination = trees
    before = snapshot_tree(tmp_path)
    code, result = measure(source, destination, whatif=whatif)
    assert code == 0
    assert result["status"] == "observed-read-only"
    assert result["code"] == "BGSE_MEASUREMENT_ONLY"
    assert result["files"] == 2
    assert result["directories"] == 3  # includes root and empty directory
    assert result["logicalBytes"] == 8
    assert result["requiredFreeBytes"] > 2 * 8 + 2 * 1048576
    assert result["observedFreeBytes"] >= result["requiredFreeBytes"]
    assert len(result["contentDigest"]) == 64
    assert len(result["identityDigest"]) == 64
    assert result["passes"] == 2
    assert result["atomicSnapshot"] is False
    assert result["capacityPlanningOnly"] is True
    assert snapshot_tree(tmp_path) == before


def test_digest_is_deterministic_and_content_not_physical_identity(trees, tmp_path):
    source, destination = trees
    _, first = measure(source, destination)
    _, again = measure(source, destination)
    assert first["contentDigest"] == again["contentDigest"]
    assert first["identityDigest"] == again["identityDigest"]
    clone = tmp_path / "independent-fixture"
    clone.mkdir()
    (clone / "empty").mkdir()
    (clone / "nested").mkdir()
    (clone / "a.bin").write_bytes(b"abc")
    (clone / "nested" / "naïve[1].bin").write_bytes(b"12345")
    _, copied = measure(clone, destination)
    assert first["contentDigest"] == copied["contentDigest"]
    assert first["identityDigest"] != copied["identityDigest"]
    (clone / "empty").rmdir()
    _, removed = measure(clone, destination)
    assert copied["contentDigest"] != removed["contentDigest"]


@pytest.mark.parametrize("kind", ["same", "child", "parent", "case", "existing"])
def test_overlap_and_existing_destination_refused_unchanged(trees, tmp_path, kind):
    source, destination = trees
    destination = {"same": source, "child": source / "new", "parent": tmp_path,
                   "case": Path(str(source).upper()), "existing": source / "empty"}[kind]
    before = snapshot_tree(tmp_path)
    code, result = measure(source, destination)
    assert code == 3
    assert result["code"] in {"BGSE_E_OVERLAP", "BGSE_E_DESTINATION_EXISTS"}
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("invalid", ["relative/game", r"C:\safe\..\game", r"C:\safe\.\game",
    r"\\server\share\game", r"\\?\C:\safe\game", r"C:\safe\file:stream",
    r"C:\safe\NUL", r"C:\safe\game.", "C:\\safe\\game "])
def test_invalid_destination_refused_before_filesystem_access(trees, tmp_path, invalid):
    source, _ = trees
    before = snapshot_tree(tmp_path)
    code, result = measure(source, invalid)
    assert code == 3
    assert result["code"] == "BGSE_E_PATH_SYNTAX"
    assert snapshot_tree(tmp_path) == before


def test_fresh_destination_even_existing_empty_or_foreign_marker_is_refused(trees, tmp_path):
    source, destination = trees
    destination.mkdir(parents=True)
    for marker in (False, True):
        if marker:
            (destination / ".bgse-disposable-lab.json").write_text('{"labId":"foreign"}')
        before = snapshot_tree(tmp_path)
        code, result = measure(source, destination)
        assert code == 3
        assert result["code"] == "BGSE_E_DESTINATION_EXISTS"
        assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("where", ["source-child", "source-parent", "destination-parent"])
def test_reparse_refused_without_following_or_writing(trees, tmp_path, where):
    source, destination = trees
    target = tmp_path / "outside-target"
    target.mkdir()
    (target / "sentinel").write_bytes(b"untouched")
    link = source / "link" if where == "source-child" else tmp_path / "junction"
    create_junction(link, target if where != "source-parent" else source)
    try:
        if where == "source-parent":
            source = link
        elif where == "destination-parent":
            destination = link / "new-game"
        before = snapshot_tree(tmp_path)
        code, result = measure(source, destination)
        assert code == 3
        assert result["code"] == "BGSE_E_REPARSE_POINT"
        assert snapshot_tree(tmp_path) == before
    finally:
        os.rmdir(link)


def test_hardlinked_source_is_refused(trees, tmp_path):
    source, destination = trees
    os.link(source / "a.bin", tmp_path / "outside-hardlink")
    before = snapshot_tree(tmp_path)
    code, result = measure(source, destination)
    assert code == 3
    assert result["code"] == "BGSE_E_HARDLINK"
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("entry", ["a.bin", "empty"])
def test_alternate_streams_are_refused_not_silently_omitted(trees, tmp_path, entry):
    source, destination = trees
    stream = Path(str(source / entry) + ":extra")
    stream.write_bytes(b"not ordinary file bytes")
    before = snapshot_tree(tmp_path)
    code, result = measure(source, destination)
    assert code == 3
    assert result["code"] == "BGSE_E_STREAMS"
    assert stream.read_bytes() == b"not ordinary file bytes"
    assert snapshot_tree(tmp_path) == before


def test_short_name_source_alias_is_refused(trees):
    source, destination = trees
    alias = get_short_path(source)
    code, result = measure(alias, destination)
    assert code == 3
    assert result["code"] == "BGSE_E_ALIAS"


def test_short_name_destination_ancestor_alias_is_refused(trees, tmp_path):
    source, _ = trees
    parent = tmp_path / "long destination parent"
    parent.mkdir()
    alias = get_short_path(parent)
    code, result = measure(source, alias / "new-game")
    assert code == 3
    assert result["code"] == "BGSE_E_ALIAS"


def test_same_prefix_sibling_is_not_an_overlap(trees):
    source, _ = trees
    code, _ = measure(source, Path(str(source) + "-independent"))
    assert code == 0


@pytest.mark.parametrize("allowance,reserve", [("-1", "0"), ("0", "-1"), ("1.5", "0"),
    ("unknown", "0"), ("18446744073709551616", "0"),
    ("18446744073709551615", "18446744073709551615")])
def test_invalid_or_overflowing_capacity_refused(trees, allowance, reserve):
    source, destination = trees
    code, result = measure(source, destination, allowance=allowance, reserve=reserve)
    assert code == 3
    assert result["code"] == "BGSE_E_CAPACITY"


def test_insufficient_capacity_is_refused(trees):
    source, destination = trees
    code, result = measure(source, destination, reserve="9000000000000000000")
    assert code == 3
    assert result["code"] == "BGSE_E_CAPACITY"


def test_missing_source_is_refused_sanitized(trees):
    source, destination = trees
    code, result = measure(source / "missing", destination)
    assert code == 3
    assert result["code"] == "BGSE_E_PATH_ACCESS"


@pytest.mark.parametrize("appeared", ["directory", "junction"])
def test_new_destination_ancestor_is_rechecked_not_only_missing_leaf(tmp_path, appeared):
    """Deterministically interleave a new ancestor with the actual final guard."""
    destination = tmp_path / "initially-missing" / "game"
    target = tmp_path / "outside-target"
    target.mkdir()
    (target / "sentinel").write_bytes(b"untouched")
    environment = os.environ.copy()
    environment.update(BGSE_TEST_SOURCE=str(REPOSITORY_ROOT / "archive/2026-10-process/scripts/lib/SourceMeasurement.cs"),
                       BGSE_TEST_DEST=str(destination), BGSE_TEST_TARGET=str(target),
                       BGSE_TEST_APPEARED=appeared)
    command = r"""
        $ErrorActionPreference = 'Stop'
        Add-Type -Path $env:BGSE_TEST_SOURCE
        $flags = [Reflection.BindingFlags]'NonPublic,Static'
        $type = [Bgse.Lab.SourceMeasurement]
        $before = $type.GetMethod('Ancestors', $flags).Invoke($null, @($env:BGSE_TEST_DEST, $true))
        $parent = Split-Path -Parent $env:BGSE_TEST_DEST
        try {
            if ($env:BGSE_TEST_APPEARED -eq 'junction') {
                New-Item -ItemType Junction -Path $parent -Target $env:BGSE_TEST_TARGET | Out-Null
            } else {
                New-Item -ItemType Directory -Path $parent | Out-Null
            }
            try {
                $type.GetMethod('VerifyDestination', $flags).Invoke($null, @($env:BGSE_TEST_DEST, $before))
                'accepted'
            } catch {
                $exception = $_.Exception
                while ($exception.InnerException) { $exception = $exception.InnerException }
                $exception.Message
            }
        } finally {
            foreach ($entry in $before) { $entry.Dispose() }
        }
    """
    try:
        result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
            env=environment, cwd=REPOSITORY_ROOT, capture_output=True,
            encoding="utf-8", timeout=30, check=False)
        assert result.returncode == 0, result.stderr
        expected = "BGSE_E_REPARSE_POINT" if appeared == "junction" else "BGSE_E_DESTINATION_CHANGED"
        assert result.stdout.strip() == expected
        assert not destination.exists()
        assert (target / "sentinel").read_bytes() == b"untouched"
    finally:
        if appeared == "junction" and os.path.lexists(destination.parent):
            os.rmdir(destination.parent)


def test_physical_root_overlap_is_independent_of_path_spelling(trees):
    source, _ = trees
    environment = os.environ.copy()
    environment.update(BGSE_TEST_SOURCE=str(REPOSITORY_ROOT / "archive/2026-10-process/scripts/lib/SourceMeasurement.cs"),
                       BGSE_TEST_ROOT=str(source))
    command = r"""
        $ErrorActionPreference = 'Stop'
        Add-Type -Path $env:BGSE_TEST_SOURCE
        $flags = [Reflection.BindingFlags]'NonPublic,Static'
        $type = [Bgse.Lab.SourceMeasurement]
        $chain = $type.GetMethod('Ancestors', $flags).Invoke($null, @($env:BGSE_TEST_ROOT, $false))
        try {
            $sourceId = $chain[$chain.Count - 1].Id
            $ids = [string[]]@($chain | ForEach-Object { $_.Id })
            try {
                $type.GetMethod('VerifySeparateIdentities', $flags).Invoke($null, @($sourceId, $ids))
                'accepted'
            } catch {
                $exception = $_.Exception
                while ($exception.InnerException) { $exception = $exception.InnerException }
                $exception.Message
            }
        } finally { foreach ($entry in $chain) { $entry.Dispose() } }
    """
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
        env=environment, cwd=REPOSITORY_ROOT, capture_output=True,
        encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "BGSE_E_OVERLAP"


def test_held_ancestor_really_prevents_rename(trees):
    source, _ = trees
    environment = os.environ.copy()
    environment.update(BGSE_TEST_SOURCE=str(REPOSITORY_ROOT / "archive/2026-10-process/scripts/lib/SourceMeasurement.cs"),
                       BGSE_TEST_ROOT=str(source))
    command = r"""
        $ErrorActionPreference = 'Stop'
        Add-Type -Path $env:BGSE_TEST_SOURCE
        $flags = [Reflection.BindingFlags]'NonPublic,Static'
        $type = [Bgse.Lab.SourceMeasurement]
        $chain = $type.GetMethod('Ancestors', $flags).Invoke($null, @($env:BGSE_TEST_ROOT, $false))
        try {
            try {
                [IO.Directory]::Move($env:BGSE_TEST_ROOT, $env:BGSE_TEST_ROOT + '-moved')
                'rename-allowed'
            } catch [IO.IOException] { 'rename-blocked' }
        } finally { foreach ($entry in $chain) { $entry.Dispose() } }
    """
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
        env=environment, cwd=REPOSITORY_ROOT, capture_output=True,
        encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "rename-blocked"
    assert source.is_dir()
