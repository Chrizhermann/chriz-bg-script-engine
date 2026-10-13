"""Pure A4a input, coverage, and output privacy faults on synthetic facts."""
from __future__ import annotations

import pytest

from test_process_screening import ROOT, fact, invoke, record, refused


@pytest.mark.parametrize("facts", [[None], [fact(pid=0)], [fact(pid=10), fact(pid=10)]])
def test_null_zero_or_duplicate_fact_pid_refuses_structure(facts) -> None:
    refused(invoke(facts), "INPUT")


@pytest.mark.parametrize("helpers", [
    [None], [[0, 100]], [[10, 0]], [[10, 100], [10, 101]],
])
def test_null_zero_or_duplicate_declared_helper_refuses_structure(helpers) -> None:
    refused(invoke([fact()], helpers=helpers), "INPUT")


def test_declared_helper_with_unknown_observed_creation_refuses_coverage() -> None:
    # A helper declaration is a positive instance selector. The same PID with
    # unknown creation cannot be silently treated as an unrelated replacement.
    refused(invoke([fact(creation=0)], helpers=[[10, 100]]), "COVERAGE")


@pytest.mark.parametrize("roots,images", [
    (None, ()), ((), ()), ((ROOT,), None),
    ((ROOT, ROOT.upper()), ()),
    ((ROOT, ROOT.replace("\\", "/")), ()),
    ((ROOT,), (r"C:\tools\helper.exe", r"c:/TOOLS/helper.EXE")),
])
def test_missing_or_normalized_duplicate_scope_inputs_refuse(roots, images) -> None:
    refused(invoke([fact()], roots=roots, images=images), "INPUT")


def test_null_scope_or_null_helper_collection_refuses() -> None:
    refused(invoke([fact()], setup="$scope = $null"), "INPUT")
    refused(invoke([fact()], helpers=None), "INPUT")


@pytest.mark.parametrize("path", [
    "", "relative\\game", "C:\\", "C:\\synthetic\\..\\game",
    "C:\\synthetic\\.\\game", "C:\\synthetic\\game\\",
    "C:\\synthetic\\\\game", "C:\\synthetic\\" + "x" * 256,
    "C:\\synthetic\\file:stream", "C:\\synthetic\\NUL",
    "C:\\synthetic\\game.", "C:\\synthetic\\game ",
    "\\\\server\\share\\game", "\\\\?\\C:\\synthetic\\game",
])
@pytest.mark.parametrize("field", ["root", "helper-image"])
def test_scope_paths_require_ordinary_absolute_canonical_spelling(
    field: str, path: str
) -> None:
    if field == "root":
        refused(invoke([fact()], roots=[path]), "INPUT")
    else:
        refused(invoke([fact()], images=[path]), "INPUT")


FACTS_AT_LIMIT = r"""
    $facts = [Bgse.Lab.ProcessFact[]]::new(16384)
    for ($i=0; $i -lt $facts.Length; $i++) {
        $facts[$i] = [Bgse.Lab.ProcessFact]::new([uint32]($i + 1),
            [Nullable[UInt64]]100, 'python.exe', 'C:\tools\python.exe', 'python -V')
    }
"""

HELPERS_AT_LIMIT = r"""
    $helpers = [Bgse.Lab.ProcessInstance[]]::new(16384)
    for ($i=0; $i -lt $helpers.Length; $i++) {
        $helpers[$i] = [Bgse.Lab.ProcessInstance]::new([uint32]($i + 1), [uint64]100)
    }
    $scope = [Bgse.Lab.ProcessScope]::new($roots, $images, $helpers)
"""

COMPACT_RESULT = "$result = @{ SelectorVersion=$result.SelectorVersion; RecordCount=$result.Records.Length }"


def test_fact_count_above_limit_refuses_with_every_row_valid() -> None:
    setup = FACTS_AT_LIMIT.replace("16384", "16385")
    refused(invoke([fact()], setup=setup), "INPUT")


def test_helper_count_above_limit_refuses_with_valid_distinct_instances() -> None:
    # All 16,384 observed facts are valid and match helpers; only the final
    # additional helper is unmatched, so a missing count guard yields COVERAGE.
    setup = FACTS_AT_LIMIT + HELPERS_AT_LIMIT.replace("16384", "16385")
    refused(invoke([fact()], setup=setup), "INPUT")


@pytest.mark.parametrize("setup", [FACTS_AT_LIMIT, FACTS_AT_LIMIT + HELPERS_AT_LIMIT])
def test_fact_and_helper_counts_at_limit_are_valid(setup: str) -> None:
    result = invoke([fact()], setup=setup, body=COMPACT_RESULT)
    assert result == {"code": "screened-only", "result": {
        "SelectorVersion": "BGSE-PROCESS-1", "RecordCount": 16384,
    }}


@pytest.mark.parametrize("setup", [
    "$tooMany = [string[]]::new(65); for ($i=0; $i -lt 65; $i++) { "
    "$tooMany[$i] = 'C:\\synthetic\\root' + $i }; "
    "$scope = [Bgse.Lab.ProcessScope]::new($tooMany, $images, $helpers)",
    "$tooMany = [string[]]::new(257); for ($i=0; $i -lt 257; $i++) { "
    "$tooMany[$i] = 'C:\\synthetic\\helper' + $i + '.exe' }; "
    "$scope = [Bgse.Lab.ProcessScope]::new($roots, $tooMany, $helpers)",
])
def test_scope_collection_count_bounds_refuse_with_valid_unique_paths(setup: str) -> None:
    refused(invoke([fact()], setup=setup), "INPUT")


@pytest.mark.parametrize("setup", [
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "('n' * 256), 'C:\\tools\\python.exe', 'python -V')",
    "$long = 'C:\\' + (('a' * 100 + '\\') * 324) + ('b' * 40); "
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "'python.exe', $long, 'python -V')",
    "$long = 'C:\\' + (('a' * 100 + '\\') * 324) + ('b' * 40); "
    "$scope = [Bgse.Lab.ProcessScope]::new([string[]]@($long), $images, $helpers)",
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "'python.exe', 'C:\\tools\\python.exe', ('q' * 32768))",
])
def test_individual_text_limits_refuse_without_environment_transport(setup: str) -> None:
    refused(invoke([fact()], setup=setup), "INPUT")


def test_aggregate_fact_text_limit_refuses_without_truncating_rows() -> None:
    # 257 separately valid, uniquely identified facts. Their 32,767-character
    # commands alone exceed 8,388,608 UTF-16 units. No OS enumeration occurs.
    setup = r"""
    $facts = [Bgse.Lab.ProcessFact[]]::new(257)
    $command = 'q' * 32767
    for ($i=0; $i -lt $facts.Length; $i++) {
        $facts[$i] = [Bgse.Lab.ProcessFact]::new([uint32]($i + 1),
            [Nullable[UInt64]]100, 'python.exe', 'C:\tools\python.exe', $command)
    }
    """
    refused(invoke([fact()], setup=setup), "INPUT")


@pytest.mark.parametrize("setup", [
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "('canary' + [string][char]0), 'C:\\tools\\python.exe', 'python -V')",
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "('canary' + [string][char]0xD800), 'C:\\tools\\python.exe', 'python -V')",
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "('canary' + [string][char]0xDC00), 'C:\\tools\\python.exe', 'python -V')",
    "$facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100, "
    "'python.exe', 'C:\\tools\\python.exe', ('canary' + [string][char]0))",
    "$scope = [Bgse.Lab.ProcessScope]::new("
    "[string[]]@('C:\\synthetic\\game' + [string][char]0xD800), $images, $helpers)",
    "$scope = [Bgse.Lab.ProcessScope]::new("
    "[string[]]@('C:\\synthetic\\game' + [string][char]0xDC00), $images, $helpers)",
])
def test_nul_or_invalid_utf16_refuses_without_disclosing_text(setup: str) -> None:
    result = invoke([fact()], setup=setup)
    refused(result, "INPUT")
    assert "canary" not in str(result).lower()


def test_valid_utf16_surrogate_pair_is_not_rejected() -> None:
    setup = r"""
    $pair = [string][char]0xD83D + [string][char]0xDE00
    $facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100,
        ('python' + $pair + '.exe'), 'C:\tools\python.exe', 'python -V')
    """
    assert record(invoke([fact()], setup=setup))["State"] == "not-selected"


def test_refusal_and_success_records_never_echo_supplied_private_text() -> None:
    secret = "PRIVATE_PROCESS_FACT_CANARY"
    bad = invoke([fact(command=secret)], setup=r"""
    $facts[0] = [Bgse.Lab.ProcessFact]::new(10, [Nullable[UInt64]]100,
        'PRIVATE_PROCESS_FACT_CANARY' + [string][char]0,
        'C:\tools\python.exe', 'PRIVATE_PROCESS_FACT_CANARY')
    """)
    refused(bad, "INPUT")
    assert secret not in str(bad)

    selected = invoke([fact(name="Baldur.exe", command=secret)])
    entry = record(selected)
    assert entry["State"] == "candidate"
    assert entry["Reasons"] == ["known-tool"]
    assert secret not in str(selected)


def test_incomplete_enumeration_refuses_coverage_without_partial_records() -> None:
    refused(invoke([fact(name="Baldur.exe")], complete=False), "COVERAGE")
