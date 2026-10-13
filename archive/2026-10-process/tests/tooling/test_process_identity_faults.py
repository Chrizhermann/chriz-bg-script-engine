"""A4b same-handle lifecycle faults using only an in-assembly fake backend."""
from __future__ import annotations

import pytest

from test_process_identity import invoke


FAKE_SOURCE = r"""
using System;
using System.Collections.Generic;

namespace Bgse.Lab {
    public static class IdentityTestBridge {
        public static object NewFake() { return new FakeIdentityApi(); }
        public static ProcessIdentityObservation Observe(uint pid, ulong? expected, object api) {
            return NativeProcessIdentity.ObserveWith(pid, expected, (IProcessIdentityApi)api);
        }
    }
    internal sealed class FakeIdentityApi : IProcessIdentityApi {
        public readonly List<string> Calls = new List<string>();
        public readonly FakeIdentitySession Session;
        public string ThrowAt = null;
        public bool NullSession = false;
        public uint OpenPid, OpenAccess;
        public bool OpenInherit;
        public FakeIdentityApi() { Session = new FakeIdentitySession(this); }
        public IProcessIdentitySession Open(uint pid, uint access, bool inherit) {
            Calls.Add("open"); OpenPid = pid; OpenAccess = access; OpenInherit = inherit;
            Fail("open");
            return NullSession ? null : Session;
        }
        public void Fail(string stage) {
            if (ThrowAt == stage) throw new InvalidOperationException("PRIVATE_IDENTITY_CANARY");
        }
    }

    internal sealed class FakeIdentitySession : IProcessIdentitySession {
        private readonly FakeIdentityApi api;
        private int pollCount, pidCount, creationCount, imageCount;
        public uint FirstPoll = 0x102, SecondPoll = 0x102;
        public uint FirstPid = 42, SecondPid = 42;
        public ulong FirstCreation = 100, SecondCreation = 100;
        public string FirstImage = @"C:\synthetic\tool.exe";
        public string SecondImage = @"C:\synthetic\tool.exe";
        public string MalformedMode = null;
        public int MalformedAt = 1;
        public bool ThrowOnDispose = false;
        public int BufferChecks;
        public FakeIdentitySession(FakeIdentityApi owner) { api = owner; }
        public uint Poll() {
            string stage = "poll" + (++pollCount);
            api.Calls.Add(stage); api.Fail(stage);
            return pollCount == 1 ? FirstPoll : SecondPoll;
        }
        public uint GetPid() {
            string stage = "pid" + (++pidCount);
            api.Calls.Add(stage); api.Fail(stage);
            return pidCount == 1 ? FirstPid : SecondPid;
        }
        public ulong GetCreationFileTime() {
            string stage = "creation" + (++creationCount);
            api.Calls.Add(stage); api.Fail(stage);
            return creationCount == 1 ? FirstCreation : SecondCreation;
        }
        public uint ReadImage(char[] buffer) {
            string stage = "image" + (++imageCount);
            api.Calls.Add(stage); api.Fail(stage);
            if (buffer == null || buffer.Length != 32767) throw new InvalidOperationException("bad-capacity");
            for (int i = 0; i < buffer.Length; i++)
                if (buffer[i] != '\uffff') throw new InvalidOperationException("bad-sentinel");
            BufferChecks++;
            bool malformed = imageCount == MalformedAt && MalformedMode != null;
            string mode = malformed ? MalformedMode : null;
            string image = imageCount == 1 ? FirstImage : SecondImage;
            if (mode == "max" || mode == "pair")
                image = mode == "max" ? new string('a', 32766) : "x\ud83d\ude00y";
            if (mode == "high" || mode == "low" || mode == "high-end" || mode == "reverse")
                image = mode == "high" ? "x\ud800y" :
                    mode == "low" ? "x\udc00y" :
                    mode == "high-end" ? "xy\ud800" : "x\udc00\ud800y";
            for (int i = 0; i < image.Length; i++) buffer[i] = image[i];
            if (mode != "unterminated") buffer[image.Length] = '\0';
            if (mode == "early-nul") buffer[1] = '\0';
            if (mode == "zero") return 0;
            if (mode == "full") return 32767;
            if (mode == "over") return 32768;
            return (uint)image.Length;
        }
        public void Dispose() {
            api.Calls.Add("dispose");
            if (ThrowOnDispose) throw new InvalidOperationException("PRIVATE_IDENTITY_CANARY");
        }
    }
}
"""

SUCCESS_CALLS = ["open", "poll1", "pid1", "creation1", "image1",
                 "pid2", "creation2", "image2", "poll2", "dispose"]


def fake_observe(*, configure: str = "", pid: int = 42, expected: str = "$null"):
    body = f"""
    $api = [Bgse.Lab.IdentityTestBridge]::NewFake()
    {configure}
    try {{
        $observed = [Bgse.Lab.IdentityTestBridge]::Observe([uint32]{pid}, {expected}, $api)
        @{{ code='observed'; calls=@($api.Calls.ToArray()); pid=$observed.Pid;
           creation=$observed.CreationFileTime; imageLength=$observed.ImagePath.Length;
           imageMatchesFirst=[string]::Equals($observed.ImagePath, $api.Session.FirstImage,
               [StringComparison]::Ordinal);
           bufferChecks=$api.Session.BufferChecks; access=$api.OpenAccess;
           openPid=$api.OpenPid; inherit=$api.OpenInherit }} | ConvertTo-Json -Compress -Depth 5
    }} catch {{
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) {{ $failure = $failure.InnerException }}
        @{{ code=$failure.Message; type=$failure.GetType().FullName;
           calls=@($api.Calls.ToArray()); bufferChecks=$api.Session.BufferChecks }} |
            ConvertTo-Json -Compress -Depth 5
    }}
    """
    return invoke(body, extra_source=FAKE_SOURCE)


def refused(result, suffix: str, calls: list[str]) -> None:
    assert result["code"] == "BGSE_E_PROCESS_IDENTITY_" + suffix, result
    assert result["type"] == "Bgse.Lab.MeasurementRefusal", result
    assert result["calls"] == calls, result
    assert "PRIVATE_IDENTITY_CANARY" not in str(result)
    assert not any(key in result for key in ("pid", "creation", "imageLength"))


def test_success_has_exact_minimal_open_args_fresh_buffers_and_call_order() -> None:
    result = fake_observe()
    assert result == {"code": "observed", "calls": SUCCESS_CALLS, "pid": 42,
                      "creation": 100, "imageLength": len(r"C:\synthetic\tool.exe"),
                      "imageMatchesFirst": True, "bufferChecks": 2,
                      "access": 0x101000, "openPid": 42, "inherit": False}


@pytest.mark.parametrize("pid,expected", [(0, "$null"), (42, "[Nullable[UInt64]]0")])
def test_invalid_input_refuses_before_open(pid: int, expected: str) -> None:
    refused(fake_observe(pid=pid, expected=expected), "INPUT", [])


def test_null_backend_refuses_before_open() -> None:
    result = invoke(r"""
    [Bgse.Lab.IdentityTestBridge]::Observe([uint32]42, $null, $null) | Out-Null
    """, extra_source=FAKE_SOURCE)
    assert result == {"code": "BGSE_E_PROCESS_IDENTITY_INPUT", "type": "Bgse.Lab.MeasurementRefusal"}


@pytest.mark.parametrize("configure,code", [
    ("$api.ThrowAt='open'", "QUERY"),
    ("$api.NullSession=$true", "DATA"),
])
def test_open_failure_or_null_session_never_reopens(configure: str, code: str) -> None:
    refused(fake_observe(configure=configure), code, ["open"])


@pytest.mark.parametrize("stage,index", [
    ("poll1", 2), ("pid1", 3), ("creation1", 4), ("image1", 5),
    ("pid2", 6), ("creation2", 7), ("image2", 8), ("poll2", 9),
])
def test_managed_query_throw_at_each_stage_is_sanitized_and_disposed(stage: str, index: int) -> None:
    result = fake_observe(configure=f"$api.ThrowAt='{stage}'")
    refused(result, "QUERY", SUCCESS_CALLS[:index] + ["dispose"])


@pytest.mark.parametrize("configure,code,index", [
    ("$api.Session.FirstPid=0", "DATA", 3),
    ("$api.Session.FirstPid=43", "CHANGED", 3),
    ("$api.Session.FirstCreation=0", "DATA", 4),
    ("$api.Session.SecondPid=0", "DATA", 6),
    ("$api.Session.SecondPid=43", "CHANGED", 6),
    ("$api.Session.SecondCreation=0", "DATA", 7),
    ("$api.Session.SecondCreation=101", "CHANGED", 7),
])
def test_identity_zero_or_change_refuses_at_exact_stage(configure: str, code: str, index: int) -> None:
    refused(fake_observe(configure=configure), code, SUCCESS_CALLS[:index] + ["dispose"])


def test_expected_creation_mismatch_stops_before_image_query() -> None:
    refused(fake_observe(expected="[Nullable[UInt64]]101"), "CHANGED",
            SUCCESS_CALLS[:4] + ["dispose"])


@pytest.mark.parametrize("check,index", [("FirstPoll", 2), ("SecondPoll", 9)])
@pytest.mark.parametrize("value,code", [(0, "EXITED"), (0xFFFFFFFF, "QUERY"), (7, "DATA")])
def test_both_zero_wait_checks_fail_closed(check: str, index: int, value: int, code: str) -> None:
    refused(fake_observe(configure=f"$api.Session.{check}=[uint32]{value}"), code,
            SUCCESS_CALLS[:index] + ["dispose"])


def test_image_spelling_change_is_ordinal_and_disposed() -> None:
    refused(fake_observe(configure="$api.Session.SecondImage='C:\\synthetic\\TOOL.exe'"),
            "CHANGED", SUCCESS_CALLS[:8] + ["dispose"])


@pytest.mark.parametrize("mode", ["zero", "full", "over", "unterminated", "early-nul",
                                  "high", "low", "high-end", "reverse"])
@pytest.mark.parametrize("at,index", [(1, 5), (2, 8)])
def test_malformed_image_buffer_refuses_without_second_attempt(mode: str, at: int, index: int) -> None:
    config = f"$api.Session.MalformedAt={at}; $api.Session.MalformedMode='{mode}'"
    refused(fake_observe(configure=config), "DATA", SUCCESS_CALLS[:index] + ["dispose"])


@pytest.mark.parametrize("mode,length", [("max", 32766), ("pair", 4)])
def test_max_valid_image_length_and_valid_surrogate_pair(mode: str, length: int) -> None:
    # Configure both reads identically: no malformed second-query masking.
    config = (f"$api.Session.MalformedMode='{mode}'; $api.Session.MalformedAt=1; "
              "$api.Session.SecondImage=$api.Session.FirstImage")
    if mode == "max":
        config += "; $api.Session.FirstImage='a' * 32766; $api.Session.SecondImage='a' * 32766"
    else:
        config += "; $api.Session.FirstImage='x' + [string][char]0xD83D + [string][char]0xDE00 + 'y'; "
        config += "$api.Session.SecondImage=$api.Session.FirstImage"
    result = fake_observe(configure=config)
    assert result["code"] == "observed", result
    assert result["calls"] == SUCCESS_CALLS
    assert result["imageLength"] == length
    assert result["bufferChecks"] == 2


def test_cleanup_exception_cannot_yield_observation_or_private_text() -> None:
    refused(fake_observe(configure="$api.Session.ThrowOnDispose=$true"), "QUERY", SUCCESS_CALLS)


def test_malformed_private_image_does_not_escape_in_refusal() -> None:
    result = fake_observe(configure=("$api.Session.FirstImage='PRIVATE_IDENTITY_CANARY'; "
                                    "$api.Session.MalformedMode='unterminated'"))
    refused(result, "DATA", SUCCESS_CALLS[:5] + ["dispose"])
