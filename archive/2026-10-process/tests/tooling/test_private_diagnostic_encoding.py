"""Exact private filenames survive legacy console encodings in hidden jobs."""
from __future__ import annotations

import json
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT, snapshot_tree
from test_fresh_tree import literal
from test_offline_reference_faults import _GENERIC_WRITE, exclusive_handle
from test_offline_reference_measurement import SCRIPT


@pytest.mark.parametrize("whatif", [True, False])
@pytest.mark.parametrize("codepage", [437, 949])
def test_json_roundtrips_unicode_under_non_utf8_output_writer(tmp_path, codepage, whatif):
    source = tmp_path / "source"
    source.mkdir()
    locked = source / "naïve-한글-😀[1].bin"
    locked.write_bytes(b"synthetic fixture")
    destination = tmp_path / "fresh" / "game"
    before = snapshot_tree(tmp_path)
    # Set only this fresh process's managed writer: no chcp, global console code
    # page change, environment mutation, or control of another app/console.
    script = f"""
$ErrorActionPreference='Stop'
$writer=[IO.StreamWriter]::new([Console]::OpenStandardOutput(), [Text.Encoding]::GetEncoding({codepage}))
$writer.AutoFlush=$true
[Console]::SetOut($writer)
& {literal(SCRIPT)} -SourceRoot {literal(source)} -DestinationRoot {literal(destination)} `
    -OutputAllowanceBytes 1048576 -SafetyReserveBytes 1048576 -IncludePrivateFailurePath {'-WhatIf' if whatif else ''}
exit $LASTEXITCODE
"""
    with exclusive_handle(locked, _GENERIC_WRITE, share=3):
        result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", script],
                                cwd=REPOSITORY_ROOT, capture_output=True, timeout=30, check=False,
                                creationflags=subprocess.CREATE_NO_WINDOW)
    assert result.returncode == 3, result.stderr
    assert result.stderr == b""
    # Raw byte assertion catches encoding loss before a replacement decoder can
    # disguise it. JSON escapes preserve the exact Unicode name on decoding.
    assert result.stdout.isascii()
    payload = json.loads(result.stdout.decode("utf-8"))
    assert payload["privateDiagnostic"]["attemptedPath"] == str(locked)
    assert payload["diagnostic"]["nativeError"] == 32
    assert payload["writesAuthorized"] is False and payload["runtimeReady"] is False
    assert snapshot_tree(tmp_path) == before
