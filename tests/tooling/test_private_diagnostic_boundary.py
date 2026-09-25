"""Private collector lifetime and opt-in publication, without real source access."""
from __future__ import annotations

import json
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT, snapshot_tree
from test_fresh_tree import literal
from test_measurement_diagnostics import VALID_DIAGNOSTIC
from test_offline_reference_measurement import SCRIPT


def run_script(script, expected_exit=0):
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", script],
                            cwd=REPOSITORY_ROOT, capture_output=True, encoding="utf-8",
                            timeout=30, check=False)
    assert result.returncode == expected_exit, result.stderr
    assert result.stderr == ""
    assert len(result.stdout.strip().splitlines()) == 1
    return json.loads(result.stdout.lstrip("\ufeff"))


@pytest.mark.parametrize("next_call", ["success", "unrelated-refusal"])
def test_reused_collector_resets_and_refusal_has_no_private_fields(tmp_path, next_call):
    source = tmp_path / "source"
    source.mkdir()
    locked = source / "PRIVATE_PATH_CANARY.bin"
    locked.write_bytes(b"ordinary synthetic bytes")
    destination = tmp_path / "fresh" / "game"
    next_source = source if next_call == "success" else r"relative\invalid"
    before = snapshot_tree(tmp_path)
    payload = run_script(f"""
$ErrorActionPreference='Stop'
Add-Type -Path {literal(REPOSITORY_ROOT / 'scripts/lib/SourceMeasurement.cs')}
$collector=[Bgse.Lab.PrivateMeasurementDiagnostic]::new()
$writer=[IO.File]::Open({literal(locked)}, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
try {{
    try {{
        [Bgse.Lab.SourceMeasurement]::MeasureWithPrivateDiagnostics(
            {literal(source)}, {literal(destination)}, '1048576', '1048576', $collector) | Out-Null
        throw 'Synthetic writer did not block the private call'
    }} catch {{
        $failure=$_.Exception
        while ($null -ne $failure.InnerException) {{ $failure=$failure.InnerException }}
        if ($failure.GetType().FullName -cne 'Bgse.Lab.MeasurementRefusal') {{ throw }}
        $observed=$collector.AttemptedPath
        $declared=@($failure.GetType().GetProperties([Reflection.BindingFlags]'Public,Instance,DeclaredOnly').Name)
        $errorText=$failure.ToString()
        $publicDiagnostic=$failure.Diagnostic
        $emptyData=$failure.Data.Count -eq 0
    }}
    try {{
        [Bgse.Lab.SourceMeasurement]::Measure({literal(source)}, {literal(destination)}, '1048576', '1048576') | Out-Null
        throw 'Synthetic writer did not block default call'
    }} catch {{
        $plain=$_.Exception
        while ($null -ne $plain.InnerException) {{ $plain=$plain.InnerException }}
        if ($plain.GetType().FullName -cne 'Bgse.Lab.MeasurementRefusal') {{ throw }}
        $defaultText=$plain.ToString()
    }}
}} finally {{ $writer.Dispose() }}
$nextCode='success'
try {{
    [Bgse.Lab.SourceMeasurement]::MeasureWithPrivateDiagnostics(
        {literal(next_source)}, {literal(destination)}, '1048576', '1048576', $collector) | Out-Null
}} catch {{
    $next=$_.Exception
    while ($null -ne $next.InnerException) {{ $next=$next.InnerException }}
    $nextCode=$next.Message
}}
@{{observed=$observed; declared=$declared; errorText=$errorText; defaultText=$defaultText;
  diagnostic=$publicDiagnostic; emptyData=$emptyData; nextCode=$nextCode;
  after=$collector.AttemptedPath}} | ConvertTo-Json -Depth 4 -Compress
""")
    assert payload["observed"] == str(locked)
    assert payload["declared"] == ["Diagnostic"]
    assert payload["diagnostic"] == VALID_DIAGNOSTIC
    assert payload["emptyData"] is True
    assert "PRIVATE_PATH_CANARY" not in payload["errorText"] + payload["defaultText"]
    assert payload["after"] is None
    assert payload["nextCode"] == ("success" if next_call == "success" else "BGSE_E_PATH_SYNTAX")
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("case", ["object-path", "empty-path", "wrong-code", "wrong-phase",
                                 "wrong-pass", "wrong-operation", "wrong-kind", "wrong-error"])
def test_private_publication_rejects_nonmatching_or_coercible_data(case):
    # A fresh-process test double exercises the real wrapper's output boundary;
    # it is not native filesystem evidence or a hostile-process security model.
    diagnostic = dict(VALID_DIAGNOSTIC)
    code = "BGSE_E_PATH_ACCESS"
    setup = "$pathValue='PRIVATE_PATH_CANARY'"
    if case == "object-path":
        setup = """
$pathValue=[pscustomobject]@{ secret='PRIVATE_PATH_CANARY' }
$pathValue | Add-Member -MemberType ScriptMethod -Name ToString -Value { 'a-path' } -Force
"""
    elif case == "empty-path":
        setup = "$pathValue=''"
    elif case == "wrong-code":
        code = "BGSE_E_ALIAS"
    elif case == "wrong-phase":
        diagnostic.update(phase="capacity", **{"pass": None})
    elif case == "wrong-pass":
        diagnostic["pass"] = 0
    elif case == "wrong-operation":
        diagnostic["operation"] = "open-metadata"
    elif case == "wrong-kind":
        diagnostic.update(failureKind="managed-io", nativeError=None)
    elif case == "wrong-error":
        diagnostic["nativeError"] = 5
    payload = run_script(f"""
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
namespace Bgse.Lab {{
    public sealed class PrivateMeasurementDiagnostic {{ public object AttemptedPath {{ get; set; }} }}
    public sealed class MeasurementRefusal : Exception {{
        public object Diagnostic {{ get; }}
        public MeasurementRefusal() : base("{code}") {{ Diagnostic=SourceMeasurement.Diagnostic; }}
    }}
    public static class SourceMeasurement {{
        public static object Diagnostic, PathValue;
        public static object MeasureWithPrivateDiagnostics(string s,string d,string a,string r,PrivateMeasurementDiagnostic p) {{
            p.AttemptedPath=PathValue;
            throw new MeasurementRefusal();
        }}
    }}
}}
'@
$diagnostic={literal(json.dumps(diagnostic))} | ConvertFrom-Json
if ($diagnostic.pass -is [long]) {{ $diagnostic.pass=[int]$diagnostic.pass }}
if ($diagnostic.nativeError -is [long]) {{ $diagnostic.nativeError=[int]$diagnostic.nativeError }}
{setup}
[Bgse.Lab.SourceMeasurement]::Diagnostic=$diagnostic
[Bgse.Lab.SourceMeasurement]::PathValue=$pathValue
& {literal(SCRIPT)} -SourceRoot 'source' -DestinationRoot 'destination' -IncludePrivateFailurePath -WhatIf
exit $LASTEXITCODE
""", 3)
    assert payload["code"] == code
    assert payload["status"] == "refused"
    assert payload["writesAuthorized"] is False
    assert payload["runtimeReady"] is False
    assert "privateDiagnostic" not in payload
    assert "PRIVATE_PATH_CANARY" not in json.dumps(payload)
