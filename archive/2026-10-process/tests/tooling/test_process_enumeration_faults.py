"""A4c enumeration contract faults through an in-assembly synthetic backend only."""
from __future__ import annotations

import pytest

from test_process_enumeration import invoke


FAKE_SOURCE = r"""
using System;

namespace Bgse.Lab {
    public static class EnumerationTestBridge {
        public static object NewFake() { return new FakeEnumerationApi(); }
        public static ProcessIdEnumeration Observe(object api) {
            return NativeProcessEnumeration.ObserveWith((IProcessEnumerationApi)api);
        }
        public static bool ConstructorCopiesInput() {
            uint[] values = new uint[] { 7u };
            var observed = new ProcessIdEnumeration(values, DateTime.UtcNow, DateTime.UtcNow, 0);
            values[0] = 99u;
            return observed.Pids[0] == 7u;
        }
    }

    internal sealed class FakeEnumerationApi : IProcessEnumerationApi {
        public uint[] Values = new uint[] { 7u, 0u, uint.MaxValue };
        public int SequenceCount = 0;
        public uint? ForcedBytes = null;
        public string ThrowKind = null;
        public uint[] SeenBuffer = null;
        public uint SeenCapacityBytes = 0;
        public int Calls = 0;

        public uint Read(uint[] buffer, uint capacityBytes) {
            Calls++;
            SeenBuffer = buffer;
            SeenCapacityBytes = capacityBytes;
            if (ThrowKind == "managed")
                throw new InvalidOperationException("PRIVATE_ENUMERATION_CANARY");
            if (ThrowKind == "dll")
                throw new DllNotFoundException("PRIVATE_ENUMERATION_CANARY");
            if (ThrowKind == "entry")
                throw new EntryPointNotFoundException("PRIVATE_ENUMERATION_CANARY");
            if (SequenceCount > 0) {
                for (int i = 0; i < SequenceCount && i < buffer.Length; i++)
                    buffer[i] = (uint)(SequenceCount - i - 1);
                return ForcedBytes ?? (uint)(SequenceCount * sizeof(uint));
            }
            for (int i = 0; i < Values.Length && i < buffer.Length; i++)
                buffer[i] = Values[i];
            return ForcedBytes ?? (uint)(Values.Length * sizeof(uint));
        }
    }
}
"""


def fake_observe(*, configure: str = "", mutate_after: bool = False):
    body = f"""
    $api = [Bgse.Lab.EnumerationTestBridge]::NewFake()
    {configure}
    try {{
        $observed = [Bgse.Lab.EnumerationTestBridge]::Observe($api)
        $ids = $observed.Pids
        $sorted = $true
        for ($i=1; $i -lt $ids.Length; $i++) {{
            if ($ids[$i-1] -ge $ids[$i]) {{ $sorted = $false }}
        }}
        [uint32[]]$smallIds = @()
        if ($ids.Length -le 10) {{ $smallIds = [uint32[]]$ids.Clone() }}
        $originalFirst = $ids[0]
        if (${str(mutate_after).lower()}) {{
            $ids[0] = [uint32]9999
            $api.SeenBuffer[0] = [uint32]8888
        }}
        @{{ code='observed'; calls=$api.Calls; capacityBytes=$api.SeenCapacityBytes;
           bufferLength=$api.SeenBuffer.Length; count=$observed.Pids.Length;
           ids=$smallIds;
           first=$originalFirst; last=$ids[$ids.Length-1]; sorted=$sorted;
           defensive=($observed.Pids[0] -eq $originalFirst);
           version=$observed.ObserverVersion;
           elapsedValid=($observed.ElapsedMilliseconds -ge 0);
           utcKinds=($observed.StartedUtc.Kind.ToString() -eq 'Utc' -and
                     $observed.FinishedUtc.Kind.ToString() -eq 'Utc')
        }} | ConvertTo-Json -Compress -Depth 5
    }} catch {{
        $failure = $_.Exception
        while ($null -ne $failure.InnerException) {{ $failure = $failure.InnerException }}
        $diagnostic = $failure.Diagnostic
        @{{ code=$failure.Message; type=$failure.GetType().FullName;
           hasInner=($null -ne $failure.InnerException);
           operation=$diagnostic.operation; kind=$diagnostic.failureKind;
           nativeError=$diagnostic.nativeError;
           calls=$api.Calls; capacityBytes=$api.SeenCapacityBytes;
           bufferLength=$(if ($null -ne $api.SeenBuffer) {{ $api.SeenBuffer.Length }} else {{ 0 }})
        }} | ConvertTo-Json -Compress -Depth 5
    }}
    """
    return invoke(body, extra_source=FAKE_SOURCE)


def one_read(result) -> None:
    assert result["calls"] == 1, result
    assert result["capacityBytes"] == 65_540, result
    assert result["bufferLength"] == 16_385, result


def refused(result, suffix: str) -> None:
    one_read(result)
    assert result["code"] == "BGSE_E_PROCESS_ENUMERATION_" + suffix, result
    assert result["type"] == "Bgse.Lab.MeasurementRefusal", result
    assert result["hasInner"] is False, result
    assert "PRIVATE_ENUMERATION_CANARY" not in str(result)


def test_sorted_success_preserves_zero_and_max_uint_without_inventing_exemptions():
    result = fake_observe()
    one_read(result)
    assert result["code"] == "observed", result
    assert result["ids"] == [0, 7, 4_294_967_295]
    assert result["sorted"] is True
    assert result["defensive"] is True
    assert result["version"] == "BGSE-PROCESS-ENUMERATION-1"
    assert result["elapsedValid"] is True
    assert result["utcKinds"] is True


def test_exact_maximum_accepted_prefix_is_preserved_and_sorted():
    result = fake_observe(configure="$api.SequenceCount=16384")
    one_read(result)
    assert result["code"] == "observed", result
    assert result["count"] == 16_384
    assert result["first"] == 0 and result["last"] == 16_383
    assert result["sorted"] is True


def test_full_16385_slot_buffer_refuses_possible_truncation():
    refused(fake_observe(configure="$api.SequenceCount=16385"), "LIMIT")


@pytest.mark.parametrize("byte_count", [0, 1, 3, 5, 65_541, 65_544, 4_294_967_295])
def test_invalid_byte_count_refuses_before_prefix_indexing(byte_count: int):
    result = fake_observe(configure=("$api.Values=[uint32[]]@(7); "
                                    f"$api.ForcedBytes=[uint32]{byte_count}"))
    refused(result, "DATA")


@pytest.mark.parametrize("values", [
    "[uint32[]]@(0,0)",
    "[uint32[]]@(7,7)",
    "[uint32[]]@(9,0,9)",
])
def test_duplicate_ids_including_zero_refuse_instead_of_deduplication(values: str):
    refused(fake_observe(configure=f"$api.Values={values}"), "DATA")


def test_unused_buffer_tail_is_not_treated_as_reported_entries():
    result = fake_observe(configure="$api.Values=[uint32[]]@(23,0,0); $api.ForcedBytes=[uint32]4")
    one_read(result)
    assert result["code"] == "observed", result
    assert result["count"] == 1 and result["ids"] == [23]


def test_result_copies_survive_retained_backend_buffer_and_getter_mutation():
    result = fake_observe(mutate_after=True)
    one_read(result)
    assert result["code"] == "observed", result
    assert result["count"] == 3
    assert result["first"] == 0 and result["defensive"] is True


def test_constructor_independently_copies_its_input_array():
    result = invoke(
        "[Bgse.Lab.EnumerationTestBridge]::ConstructorCopiesInput() | ConvertTo-Json -Compress",
        extra_source=FAKE_SOURCE,
    )
    assert result is True


def test_backend_exceptions_are_sanitized_without_retry_or_private_text():
    # These are synthetic backend throws, not a native Win32 error-path experiment.
    results = [fake_observe(configure=f"$api.ThrowKind='{kind}'")
               for kind in ("managed", "dll", "entry")]
    for result in results:
        refused(result, "QUERY")
        assert result["operation"] == "enumerate"
        assert result["kind"] == "query-error"
        assert result["nativeError"] is None
    assert len({(result["operation"], result["kind"]) for result in results}) == 1


def test_null_internal_backend_refuses_before_any_read():
    result = invoke(r"""
    [Bgse.Lab.EnumerationTestBridge]::Observe($null) | Out-Null
    """, extra_source=FAKE_SOURCE)
    assert result == {"code": "BGSE_E_PROCESS_ENUMERATION_INPUT",
                      "type": "Bgse.Lab.MeasurementRefusal"}


@pytest.mark.parametrize("platform", ["arm64", "nonwindows"])
def test_simulated_unsupported_platform_refuses_before_native_enumeration(platform: str):
    # This same-namespace shadow requires an unqualified RuntimeInformation use
    # in the authored helper; inspect that binding before executing this test.
    architecture = "Arm64" if platform == "arm64" else "X64"
    is_windows = "true" if platform == "arm64" else "false"
    shadow = f"""
namespace Bgse.Lab {{
    internal static class RuntimeInformation {{
        public static System.Runtime.InteropServices.Architecture ProcessArchitecture {{
            get {{ return System.Runtime.InteropServices.Architecture.{architecture}; }}
        }}
        public static bool IsOSPlatform(System.Runtime.InteropServices.OSPlatform platform) {{
            return {is_windows};
        }}
    }}
}}
"""
    result = invoke(r"""
    [Bgse.Lab.NativeProcessEnumeration]::Observe() | Out-Null
    """, extra_source=shadow)
    assert result == {"code": "BGSE_E_PROCESS_ENUMERATION_PLATFORM",
                      "type": "Bgse.Lab.MeasurementRefusal"}
