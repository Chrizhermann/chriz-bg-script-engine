"""A4b: own harness process only; no system enumeration or game process probe."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT


def invoke(body: str, *, extra_source: str = ""):
    environment = os.environ.copy()
    environment["BGSE_IDENTITY_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    environment["BGSE_IDENTITY_TEST_SOURCE"] = extra_source
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    if ($env:BGSE_IDENTITY_TEST_SOURCE) {
        $units = @((Get-Content -Raw (Join-Path $env:BGSE_IDENTITY_LIBRARY 'SourceMeasurement.cs')),
                   (Get-Content -Raw (Join-Path $env:BGSE_IDENTITY_LIBRARY 'NativeProcessIdentity.cs')),
                   $env:BGSE_IDENTITY_TEST_SOURCE)
        # Compile test-only internal fakes in the authored assembly; no public
        # injection API or production source edits. Hoist only top-level usings.
        $usingPattern = '(?m)^using [^;\r\n]+;\r?$'
        $usings = @($units | ForEach-Object {
            [regex]::Matches($_, $usingPattern) | ForEach-Object { $_.Value.TrimEnd() }
        } | Select-Object -Unique)
        $bodies = @($units | ForEach-Object { [regex]::Replace($_, $usingPattern, '') })
        Add-Type -TypeDefinition (($usings -join [Environment]::NewLine) +
            [Environment]::NewLine + ($bodies -join [Environment]::NewLine))
    } else {
        Add-Type -Path @((Join-Path $env:BGSE_IDENTITY_LIBRARY 'SourceMeasurement.cs'),
                        (Join-Path $env:BGSE_IDENTITY_LIBRARY 'NativeProcessIdentity.cs'))
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


def test_own_process_observation_matches_independent_host_accessors():
    result = invoke(r"""
    $observed = [Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID, $null)
    $current = [System.Diagnostics.Process]::GetCurrentProcess()
    try {
        $expectedCreation = [uint64]$current.StartTime.ToUniversalTime().ToFileTimeUtc()
    } finally { $current.Dispose() }
    @{
        version=$observed.ObserverVersion
        pidMatches=($observed.Pid -eq $PID)
        creationMatches=($observed.CreationFileTime -eq $expectedCreation -and $expectedCreation -gt 0)
        # Independent accessors retain different launch-path casing. Production
        # still requires exact equality between its two same-handle queries.
        imageMatches=[string]::Equals($observed.ImagePath, [Environment]::ProcessPath, [StringComparison]::OrdinalIgnoreCase)
        elapsedValid=($observed.ElapsedMilliseconds -ge 0)
        utcKinds=($observed.StartedUtc.Kind.ToString() -eq 'Utc' -and $observed.FinishedUtc.Kind.ToString() -eq 'Utc')
        writableProperties=@($observed.GetType().GetProperties() | Where-Object CanWrite).Count
    } | ConvertTo-Json -Compress
""")
    assert result == {"version": "BGSE-PROCESS-IDENTITY-1", "pidMatches": True,
                      "creationMatches": True, "imageMatches": True, "elapsedValid": True,
                      "utcKinds": True, "writableProperties": 0}


def refused(result, suffix):
    assert result == {"code": "BGSE_E_PROCESS_IDENTITY_" + suffix, "type": "Bgse.Lab.MeasurementRefusal"}


@pytest.mark.parametrize("pid,expected", [("0", "$null"), ("$PID", "0")])
def test_invalid_identity_input_refuses_before_process_access(pid, expected):
    refused(invoke(f"[Bgse.Lab.NativeProcessIdentity]::Observe([uint32]{pid}, {expected}) | ConvertTo-Json -Compress"), "INPUT")


def test_exact_expected_creation_correlates_only_that_current_instance():
    result = invoke(r"""
    $first = [Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID, $null)
    $second = [Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID, $first.CreationFileTime)
    @{ same=($first.CreationFileTime -eq $second.CreationFileTime -and $first.ImagePath -ceq $second.ImagePath)
       publicFields=@($second.GetType().GetProperties().Name | Sort-Object)
       publicConstructors=$second.GetType().GetConstructors().Length
    } | ConvertTo-Json -Compress
""")
    assert result == {"same": True, "publicConstructors": 0, "publicFields": [
        "CreationFileTime", "ElapsedMilliseconds", "FinishedUtc", "ImagePath", "ObserverVersion", "Pid", "StartedUtc",
    ]}


def test_wrong_expected_creation_refuses_the_real_current_process():
    refused(invoke(r"""
    $first = [Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID, $null)
    [Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID, [uint64]($first.CreationFileTime + [uint64]1)) |
        ConvertTo-Json -Compress
"""), "CHANGED")


HANDLE_PROBE = r"""
namespace Bgse.Lab {
    public static class IdentityHandleProbe {
        [System.Runtime.InteropServices.DllImport("kernel32.dll", ExactSpelling=true, SetLastError=true)]
        [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
        private static extern bool GetProcessHandleCount(System.IntPtr process, out uint count);
        private static uint Count() {
            uint count;
            if (!GetProcessHandleCount(new System.IntPtr(-1), out count)) throw new System.Exception("count-failed");
            return count;
        }
        public static uint[] Exercise(uint pid, bool fail) {
            ulong creation = NativeProcessIdentity.Observe(pid, null).CreationFileTime;
            ulong? expected = fail ? creation + 1 : creation;
            // Warm up the exact success/refusal and count paths before measuring.
            for (int i=0; i<4; i++) {
                try { NativeProcessIdentity.Observe(pid, expected); }
                catch (MeasurementRefusal e) { if (!fail || e.Message != "BGSE_E_PROCESS_IDENTITY_CHANGED") throw; }
                Count();
            }
            uint before = Count();
            for (int i=0; i<32; i++) {
                bool refused = false;
                try { NativeProcessIdentity.Observe(pid, expected); }
                catch (MeasurementRefusal e) {
                    if (!fail || e.Message != "BGSE_E_PROCESS_IDENTITY_CHANGED") throw;
                    refused = true;
                }
                if (refused != fail) throw new System.Exception("wrong-path");
            }
            return new uint[] { before, Count() };
        }
    }
}
"""


@pytest.mark.parametrize("fail", [False, True])
def test_owned_native_handles_are_released_after_success_or_refusal(fail):
    result = invoke(
        f"[Bgse.Lab.IdentityHandleProbe]::Exercise([uint32]$PID, ${str(fail).lower()}) | ConvertTo-Json -Compress",
        extra_source=HANDLE_PROBE,
    )
    assert isinstance(result, list), result
    assert result[0] == result[1], result


def test_simulated_arm64_is_not_mistaken_for_supported_x64():
    # Test-only same-namespace compile seam shadows the platform accessor, not
    # the process API. Before the guard fix this reached own-process native
    # success on the actual x64 test host. This is not an ARM64 execution test.
    source = r"""
namespace Bgse.Lab {
    internal static class RuntimeInformation {
        public static System.Runtime.InteropServices.Architecture ProcessArchitecture {
            get { return System.Runtime.InteropServices.Architecture.Arm64; }
        }
        public static bool IsOSPlatform(System.Runtime.InteropServices.OSPlatform platform) {
            return System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(platform);
        }
    }
}
"""
    refused(invoke(
        "[Bgse.Lab.NativeProcessIdentity]::Observe([uint32]$PID,$null) | ConvertTo-Json -Compress",
        extra_source=source,
    ), "PLATFORM")
