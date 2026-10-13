"""Sanitized failure attribution on synthetic inputs, never the game corpus."""
from __future__ import annotations

import json
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT, snapshot_tree
from test_fresh_tree import literal
from test_offline_reference_measurement import measure, SCRIPT


def probe(body):
    script = f"""
$ErrorActionPreference = 'Stop'
Add-Type -Path {literal(REPOSITORY_ROOT / 'archive/2026-10-process/scripts/lib/SourceMeasurement.cs')}
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class DiagnosticFixtures {{
    public static Func<int> Throw(Exception error) {{ return () => {{ throw error; }}; }}
    public static Func<int> Failure(string kind) {{
        return () => {{
            if (kind == "io") throw new IOException("PRIVATE_DIAGNOSTIC_CANARY");
            if (kind == "denied") throw new UnauthorizedAccessException("PRIVATE_DIAGNOSTIC_CANARY");
            if (kind == "overflow") throw new OverflowException();
            throw new InvalidOperationException("PRIVATE_DIAGNOSTIC_CANARY");
        }};
    }}
}}
'@
$flags = [Reflection.BindingFlags]'NonPublic,Static'
try {{
    {body}
    @{{ accepted=$true }} | ConvertTo-Json -Compress
}} catch {{
    $failure=$_.Exception
    while ($null -ne $failure.InnerException) {{ $failure=$failure.InnerException }}
    @{{ code=$failure.Message; diagnostic=$failure.Diagnostic; exceptionType=$failure.GetType().FullName }} | ConvertTo-Json -Depth 4 -Compress
}}
"""
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", script],
                            cwd=REPOSITORY_ROOT, capture_output=True, encoding="utf-8",
                            timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == ""
    assert "PRIVATE_DIAGNOSTIC_CANARY" not in result.stdout
    assert len(result.stdout.strip().splitlines()) == 1
    return json.loads(result.stdout.lstrip("\ufeff"))


@pytest.mark.parametrize("kind,expected", [("io", "managed-io"), ("denied", "managed-io"),
                                            ("unexpected", "unexpected")])
@pytest.mark.parametrize("operation", ["enumerate", "hash-read"])
def test_managed_failures_classified_without_message_or_stale_native_error(kind, expected, operation):
    result = probe(f"""
    $method=[Bgse.Lab.SourceMeasurement].GetMethod('Observe', $flags).MakeGenericMethod([int])
    $action=[DiagnosticFixtures]::Failure({literal(kind)})
    [Runtime.InteropServices.Marshal]::SetLastPInvokeError(1234)
    $method.Invoke($null, @({literal(operation)}, $action)) | Out-Null
    """)
    assert result["code"] == "BGSE_E_PATH_ACCESS"
    assert result["diagnostic"] == {"phase": None, "pass": None, "operation": operation,
                                     "failureKind": expected, "nativeError": None}


@pytest.mark.parametrize("method,operation", [("ReadInfo", "query-info"), ("ReadIdentity", "query-id")])
def test_invalid_handle_captures_actual_native_error(method, operation):
    result = probe(f"""
    $method=[Bgse.Lab.SourceMeasurement].GetMethod({literal(method)}, $flags)
    $handle=[Microsoft.Win32.SafeHandles.SafeFileHandle]::new([IntPtr]::Zero, $false)
    try {{ $method.Invoke($null, @($handle)) | Out-Null }} finally {{ $handle.Dispose() }}
    """)
    assert result["code"] == "BGSE_E_PATH_ACCESS"
    assert result["diagnostic"]["operation"] == operation
    assert result["diagnostic"]["failureKind"] == "native-error"
    assert result["diagnostic"]["nativeError"] == 6  # ERROR_INVALID_HANDLE


@pytest.mark.parametrize("length,expected,error", [(0, "native-error", 5),
                                                   (32768, "buffer-limit", None),
                                                   (32769, "buffer-limit", None)])
def test_final_path_query_failure_and_buffer_limit_are_distinct(length, expected, error):
    result = probe(f"""
    $method=[Bgse.Lab.SourceMeasurement].GetMethod('VerifyFinalPathLength', $flags)
    $method.Invoke($null, @([uint32]{length}, [int]5)) | Out-Null
    """)
    assert result["code"] == "BGSE_E_PATH_ACCESS"
    assert result["diagnostic"]["operation"] == "query-final-path"
    assert result["diagnostic"]["failureKind"] == expected
    assert result["diagnostic"]["nativeError"] == error


def test_observe_preserves_precise_authored_failure_not_generic_managed_wrapper():
    result = probe("""
    $failure=[Bgse.Lab.MeasurementRefusal]::new('BGSE_E_PATH_ACCESS', 'query-info', 'native-error', 6)
    $action=[DiagnosticFixtures]::Throw($failure)
    $method=[Bgse.Lab.SourceMeasurement].GetMethod('Observe', $flags).MakeGenericMethod([int])
    $method.Invoke($null, @('hash-read', $action)) | Out-Null
    """)
    assert result["diagnostic"] == {"phase": None, "pass": None, "operation": "query-info",
                                     "failureKind": "native-error", "nativeError": 6}


def test_observe_preserves_existing_outer_overflow_classification():
    result = probe("""
    $action=[DiagnosticFixtures]::Failure('overflow')
    $method=[Bgse.Lab.SourceMeasurement].GetMethod('Observe', $flags).MakeGenericMethod([int])
    $method.Invoke($null, @('hash-read', $action)) | Out-Null
    """)
    assert result["exceptionType"] == "System.OverflowException"


def test_post_inventory_refusal_does_not_retain_last_inventory_pass(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "file.bin").write_bytes(b"ordinary fixture")
    before = snapshot_tree(tmp_path)
    code, result = measure(source, tmp_path / "new-game", reserve="18446744073709551615")
    assert code == 3
    assert result["code"] == "BGSE_E_CAPACITY"
    assert result["diagnostic"] == {"phase": "capacity", "pass": None, "operation": "guard",
                                     "failureKind": "guard", "nativeError": None}
    assert snapshot_tree(tmp_path) == before


VALID_DIAGNOSTIC = {"phase": "inventory", "pass": 1, "operation": "open-content",
                    "failureKind": "native-error", "nativeError": 32}


def invoke_fake_refusal(diagnostic, *, historical=False, malicious_field=None):
    # Fresh-process test double skips the real helper; never observes a source.
    # Exercises the production wrapper's publication boundary, not a new option.
    property_source = "" if historical else "public object Diagnostic { get; }"
    assignment = "" if historical else "Diagnostic = diagnostic;"
    attack = ""
    if malicious_field:
        allowed = diagnostic[malicious_field]
        attack = f"""
$coercible = [pscustomobject]@{{ personalPath = 'SYNTHETIC_SECRET' }}
$coercible | Add-Member -MemberType ScriptMethod -Name ToString -Value {{ {literal(allowed)} }} -Force
$diagnostic.{malicious_field} = $coercible
"""
    script = f"""
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
namespace Bgse.Lab {{
    public sealed class MeasurementRefusal : Exception {{
        {property_source}
        public MeasurementRefusal(object diagnostic) : base("BGSE_E_PATH_ACCESS") {{ {assignment} }}
    }}
    public static class SourceMeasurement {{
        public static object Diagnostic;
        public static object Measure(string s, string d, string a, string r) {{
            throw new MeasurementRefusal(Diagnostic);
        }}
    }}
}}
'@
$diagnostic = {literal(json.dumps(diagnostic))} | ConvertFrom-Json
if ($null -ne $diagnostic) {{
    if ($diagnostic.pass -is [long]) {{ $diagnostic.pass = [int]$diagnostic.pass }}
    if ($diagnostic.nativeError -is [long]) {{ $diagnostic.nativeError = [int]$diagnostic.nativeError }}
}}
{attack}
[Bgse.Lab.SourceMeasurement]::Diagnostic = $diagnostic
& {literal(SCRIPT)} -SourceRoot 'SYNTHETIC_SECRET' -DestinationRoot 'SYNTHETIC_SECRET' -WhatIf
exit $LASTEXITCODE
"""
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", script],
                            cwd=REPOSITORY_ROOT, capture_output=True, encoding="utf-8",
                            timeout=30, check=False)
    assert result.returncode == 3
    assert result.stderr == ""
    assert "SYNTHETIC_SECRET" not in result.stdout
    payload = json.loads(result.stdout.lstrip("\ufeff"))
    assert payload["schemaVersion"] == 1
    assert payload["code"] == "BGSE_E_PATH_ACCESS"
    assert payload["writesAuthorized"] is False and payload["runtimeReady"] is False
    return payload


def test_publication_validates_scalars_instead_of_serializing_the_exception():
    value = dict(VALID_DIAGNOSTIC, untrustedExtra="SYNTHETIC_SECRET")
    result = invoke_fake_refusal(value)
    assert result["diagnostic"] == VALID_DIAGNOSTIC


@pytest.mark.parametrize("field,value", [("phase", "SYNTHETIC_SECRET"),
    ("operation", "SYNTHETIC_SECRET"), ("failureKind", "SYNTHETIC_SECRET"),
    ("pass", 0), ("pass", None), ("nativeError", -1), ("nativeError", "32"),
    ("failureKind", "managed-io"), ("phase", "capacity")])
def test_malformed_diagnostic_is_omitted_without_changing_refusal(field, value):
    diagnostic = dict(VALID_DIAGNOSTIC, **{field: value})
    assert "diagnostic" not in invoke_fake_refusal(diagnostic)


@pytest.mark.parametrize("historical", [False, True])
def test_diagnostic_absence_remains_valid_for_schema_one(historical):
    assert "diagnostic" not in invoke_fake_refusal(None, historical=historical)


@pytest.mark.parametrize("field", ["phase", "operation", "failureKind"])
def test_string_coercion_cannot_smuggle_private_object_into_diagnostic(field):
    diagnostic = {"phase": "inputs", "pass": None, "operation": "guard",
                  "failureKind": "guard", "nativeError": None}
    assert "diagnostic" not in invoke_fake_refusal(diagnostic, malicious_field=field)
