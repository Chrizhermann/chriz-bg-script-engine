"""A4c numeric IDs only: no process opens, names, commands or game access."""
from __future__ import annotations

import json
import os
import subprocess

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT


def invoke(body: str, *, extra_source: str = ""):
    environment = os.environ.copy()
    environment["BGSE_ENUMERATION_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    environment["BGSE_ENUMERATION_TEST_SOURCE"] = extra_source
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    if ($env:BGSE_ENUMERATION_TEST_SOURCE) {
        $units = @((Get-Content -Raw (Join-Path $env:BGSE_ENUMERATION_LIBRARY 'SourceMeasurement.cs')),
                   (Get-Content -Raw (Join-Path $env:BGSE_ENUMERATION_LIBRARY 'NativeProcessEnumeration.cs')),
                   $env:BGSE_ENUMERATION_TEST_SOURCE)
        $usingPattern = '(?m)^using [^;\r\n]+;\r?$'
        $usings = @($units | ForEach-Object {
            [regex]::Matches($_, $usingPattern) | ForEach-Object { $_.Value.TrimEnd() }
        } | Select-Object -Unique)
        $bodies = @($units | ForEach-Object { [regex]::Replace($_, $usingPattern, '') })
        Add-Type -TypeDefinition (($usings -join [Environment]::NewLine) +
            [Environment]::NewLine + ($bodies -join [Environment]::NewLine))
    } else {
        Add-Type -Path @((Join-Path $env:BGSE_ENUMERATION_LIBRARY 'SourceMeasurement.cs'),
                        (Join-Path $env:BGSE_ENUMERATION_LIBRARY 'NativeProcessEnumeration.cs'))
    }
    BODY
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName } | ConvertTo-Json -Compress -Depth 4
}
""".replace("BODY", body)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert not result.stderr, result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


def test_native_numeric_response_includes_own_harness_without_opening_other_processes():
    result = invoke(r"""
    $observed = [Bgse.Lab.NativeProcessEnumeration]::Observe()
    $ids = $observed.Pids
    $sortedUnique = $true
    for ($i=1; $i -lt $ids.Length; $i++) {
        if ($ids[$i-1] -ge $ids[$i]) { $sortedUnique = $false }
    }
    $first = $ids[0]
    $ids[0] = $ids[0] -bxor [uint32]1
    @{
        version=$observed.ObserverVersion
        includesSelf=($observed.Pids -contains [uint32]$PID)
        sortedUnique=$sortedUnique
        bounded=($ids.Length -ge 1 -and $ids.Length -le 16384)
        defensive=($observed.Pids[0] -eq $first)
        elapsedValid=($observed.ElapsedMilliseconds -ge 0)
        utcKinds=($observed.StartedUtc.Kind.ToString() -eq 'Utc' -and $observed.FinishedUtc.Kind.ToString() -eq 'Utc')
        writableProperties=@($observed.GetType().GetProperties() | Where-Object CanWrite).Count
        publicConstructors=$observed.GetType().GetConstructors().Length
        publicProperties=@($observed.GetType().GetProperties().Name | Sort-Object)
        publicFields=$observed.GetType().GetFields().Length
    } | ConvertTo-Json -Compress
""")
    assert result == {
        "version": "BGSE-PROCESS-ENUMERATION-1", "includesSelf": True,
        "sortedUnique": True, "bounded": True, "defensive": True,
        "elapsedValid": True, "utcKinds": True, "writableProperties": 0,
        "publicConstructors": 0, "publicFields": 0, "publicProperties": [
            "ElapsedMilliseconds", "FinishedUtc", "ObserverVersion", "Pids", "StartedUtc",
        ],
    }
