"""Independent scalar fault cases for A2 capacity accounting."""
from __future__ import annotations

import pytest

from test_acquisition_capacity import (
    MAX,
    OVERHEAD,
    PURPOSES,
    allocation,
    assert_refused,
    empty_allocations,
    invoke,
)


def _purpose_budget(unit: int, files: list[int], directories: int, extra: int) -> int:
    """Small independent integer oracle, intentionally outside the C# calculator."""
    rounded = sum(((length // unit) + (length % unit != 0)) * unit for length in files)
    return rounded + (len(files) + directories) * OVERHEAD + extra


def test_shared_volume_aggregate_overflow_even_though_each_purpose_fits() -> None:
    # Each complete purpose budget is 2^63, so no single purpose overflows.
    # Summing only the first two already exceeds UInt64.MaxValue.
    half_plus_one = (MAX // 2) + 1
    extra = half_plus_one - OVERHEAD
    allocations = [allocation(purpose, extra=extra) for purpose in PURPOSES]
    assert _purpose_budget(4096, [], 1, extra) == half_plus_one
    assert all(_purpose_budget(4096, [], 1, extra) <= MAX for _ in PURPOSES)

    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], allocations), "OVERFLOW")


def test_reserve_applies_once_to_each_shared_volume_with_independent_oracle() -> None:
    volumes = [["VOL_B", 512, MAX, 19], ["VOL_A", 4096, MAX, 7]]
    allocations = [
        allocation("working-copy", volume="VOL_A", files=[0, 4097], directories=2, extra=3),
        allocation("future-baseline", volume="VOL_A", files=[4096], directories=1, extra=5),
        allocation("evidence", volume="VOL_B", files=[513, 1], directories=3, extra=11),
    ]
    working = _purpose_budget(4096, [0, 4097], 2, 3)
    baseline = _purpose_budget(4096, [4096], 1, 5)
    evidence = _purpose_budget(512, [513, 1], 3, 11)

    result = invoke(volumes, allocations)

    assert result["code"] == "accounted-only"
    budgets = {item["VolumeId"]: item for item in result["budgets"]}
    assert set(budgets) == {"VOL_A", "VOL_B"}
    assert budgets["VOL_A"]["WorkingCopyBytes"] == working
    assert budgets["VOL_A"]["FutureBaselineBytes"] == baseline
    assert budgets["VOL_A"]["EvidenceBytes"] == 0
    assert budgets["VOL_A"]["RequiredBytes"] == working + baseline + 7
    assert budgets["VOL_B"]["WorkingCopyBytes"] == 0
    assert budgets["VOL_B"]["FutureBaselineBytes"] == 0
    assert budgets["VOL_B"]["EvidenceBytes"] == evidence
    assert budgets["VOL_B"]["RequiredBytes"] == evidence + 19
    assert all(item["RemainingBytes"] == MAX - item["RequiredBytes"] for item in budgets.values())


def test_other_volume_surplus_never_returns_partial_budget_on_deficit() -> None:
    allocations = [
        allocation("working-copy", volume="VOL_A", files=[1]),
        allocation("future-baseline", volume="VOL_A"),
        allocation("evidence", volume="VOL_B", files=[1]),
    ]
    evidence_need = _purpose_budget(4096, [1], 1, 0) + 9
    volumes = [["VOL_A", 4096, MAX, 0], ["VOL_B", 4096, evidence_need - 1, 9]]

    assert_refused(invoke(volumes, allocations), "INSUFFICIENT")


def test_exact_full_uint64_total_is_valid_without_wraparound() -> None:
    allocations = empty_allocations()
    allocations[0][4] = MAX - 3 * OVERHEAD

    result = invoke([["VOL_A", 4096, MAX, 0]], allocations)

    assert result["code"] == "accounted-only"
    assert result["budgets"][0]["WorkingCopyBytes"] == MAX - 2 * OVERHEAD
    assert result["budgets"][0]["RequiredBytes"] == MAX
    assert result["budgets"][0]["RemainingBytes"] == 0


def test_extra_allowance_is_byte_exact_not_rounded_to_allocation_unit() -> None:
    allocations = empty_allocations()
    allocations[2] = allocation("evidence", files=[1], directories=1, extra=1)
    expected_evidence = 4096 + 2 * OVERHEAD + 1

    result = invoke([["VOL_A", 4096, MAX, 0]], allocations)

    assert result["code"] == "accounted-only"
    assert result["budgets"][0]["EvidenceBytes"] == expected_evidence
    assert result["budgets"][0]["RequiredBytes"] == 2 * OVERHEAD + expected_evidence


def test_allocation_with_no_observed_volume_refuses_entire_calculation() -> None:
    allocations = empty_allocations()
    allocations[2][0] = "VOL_MISSING"

    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], allocations), "INPUT")


@pytest.mark.parametrize("purpose", ["Working-copy", "working_copy", " evidence", "evidence ",
                                           "future-Baseline", "", "évidence"])
def test_purpose_is_exact_canonical_token(purpose: str) -> None:
    allocations = empty_allocations()
    allocations[2][1] = purpose

    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], allocations), "INPUT")


@pytest.mark.parametrize("volume_id", ["A/B", "A.B", "A B", "A:DRIVE", "A\u200bB"])
def test_volume_id_is_a_canonical_token_not_a_path_or_alias(volume_id: str) -> None:
    allocations = [allocation(purpose, volume=volume_id) for purpose in PURPOSES]

    assert_refused(invoke([[volume_id, 4096, MAX, 0]], allocations), "INPUT")


def test_million_valid_file_limits_plus_root_refuse_count_before_budgeting() -> None:
    # Generate the large typed array inside one fresh PowerShell child. Every
    # element is a known zero, so null-element validation cannot mask the bound.
    setup = r"""
    Add-Type -TypeDefinition @'
using System;
public static class CapacityFaultFixture {
    public static ulong?[] Zeros(int count) {
        var values = new ulong?[count];
        Array.Fill<ulong?>(values, 0);
        return values;
    }
}
'@
    $files = [CapacityFaultFixture]::Zeros(1000000)
    $allocations[0] = [Bgse.Lab.CapacityAllocation]::new(
        'VOL_A', 'working-copy', $files, [Nullable[UInt64]]1, [Nullable[UInt64]]0)
    """

    assert_refused(invoke([["VOL_A", 4096, MAX, 0]], empty_allocations(), setup=setup),
                   "INPUT")
