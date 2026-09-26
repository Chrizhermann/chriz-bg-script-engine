"""Pure screening of synthetic process facts; never OS/process or game admission."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT

ROOT = r"C:\synthetic\game"


def fact(pid=10, creation=100, name="python.exe", image=r"C:\tools\python.exe", command="python -V"):
    return [pid, creation, name, image, command]


def invoke(facts, *, roots=(ROOT,), images=(), helpers=(), complete=True, setup="", body=""):
    environment = os.environ.copy()
    environment["BGSE_SCREENING_INPUT"] = json.dumps({
        "facts": facts, "roots": roots, "images": images, "helpers": helpers, "complete": complete,
    })
    environment["BGSE_SCREENING_LIBRARY"] = str(REPOSITORY_ROOT / "scripts" / "lib")
    command = r"""
$ErrorActionPreference = 'Stop'
try {
    Add-Type -Path @((Join-Path $env:BGSE_SCREENING_LIBRARY 'SourceMeasurement.cs'),
                    (Join-Path $env:BGSE_SCREENING_LIBRARY 'ProcessScreening.cs'))
    $inputData = $env:BGSE_SCREENING_INPUT | ConvertFrom-Json
    $facts = $null
    if ($null -ne $inputData.facts) {
        $facts = [Bgse.Lab.ProcessFact[]]::new($inputData.facts.Count)
        for ($i=0; $i -lt $facts.Count; $i++) {
            $item = $inputData.facts[$i]
            if ($null -ne $item) {
                $creation = $null
                if ($null -ne $item[1]) { $creation = [UInt64]::Parse([string]$item[1]) }
                # PowerShell coerces plain $null into an empty .NET string.
                # Preserve unknown versus known-empty facts at this test boundary.
                $text = [object[]]::new(3)
                for ($j=0; $j -lt 3; $j++) {
                    $text[$j] = $item[$j + 2]
                    if ($null -eq $text[$j]) { $text[$j] = [System.Management.Automation.Language.NullString]::Value }
                }
                $facts[$i] = [Bgse.Lab.ProcessFact]::new([uint32]$item[0], $creation, $text[0], $text[1], $text[2])
            }
        }
    }
    $helpers = $null
    if ($null -ne $inputData.helpers) {
        $helpers = [Bgse.Lab.ProcessInstance[]]::new($inputData.helpers.Count)
        for ($i=0; $i -lt $helpers.Count; $i++) {
            $item = $inputData.helpers[$i]
            if ($null -ne $item) { $helpers[$i] = [Bgse.Lab.ProcessInstance]::new([uint32]$item[0], [UInt64]$item[1]) }
        }
    }
    $roots = $null; $images = $null
    if ($null -ne $inputData.roots) { $roots = [string[]]$inputData.roots }
    if ($null -ne $inputData.images) { $images = [string[]]$inputData.images }
    $scope = [Bgse.Lab.ProcessScope]::new($roots, $images, $helpers)
    SETUP
    $result = [Bgse.Lab.ProcessScreening]::Screen($scope, $facts, [bool]$inputData.complete)
    BODY
    @{ code='screened-only'; result=$result } | ConvertTo-Json -Compress -Depth 6
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code=$failure.Message; type=$failure.GetType().FullName } | ConvertTo-Json -Compress
}
""".replace("SETUP", setup).replace("BODY", body)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == "", result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


def test_three_states_do_not_conflate_candidate_unknown_and_unselected():
    result = invoke([
        fact(pid=30, name="Baldur.exe", image=ROOT + r"\Baldur.exe", command='"' + ROOT + r'\Baldur.exe"'),
        fact(pid=20, command=None),
        fact(pid=10),
    ])
    assert result == {"code": "screened-only", "result": {
        "SelectorVersion": "BGSE-PROCESS-1", "Records": [
            {"Pid": 10, "CreationFileTime": 100, "State": "not-selected", "Reasons": []},
            {"Pid": 20, "CreationFileTime": 100, "State": "unresolved", "Reasons": ["unknown-command"]},
            {"Pid": 30, "CreationFileTime": 100, "State": "candidate",
             "Reasons": ["command-root", "image-root", "known-tool"]},
        ]}}


def record(result):
    assert result["code"] == "screened-only", result
    assert result["result"]["SelectorVersion"] == "BGSE-PROCESS-1"
    return result["result"]["Records"][0]


def refused(result, code="INPUT"):
    assert result == {"code": "BGSE_E_PROCESS_" + code, "type": "Bgse.Lab.MeasurementRefusal"}


@pytest.mark.parametrize("name", ["Baldur.exe", "InfinityLoader.exe", "EEex.exe", "WeiDU.exe",
                                 "NearInfinity.exe", "SETUP-synthetic.EXE"])
def test_known_tool_names_select_even_outside_watched_root(name):
    assert record(invoke([fact(name=name)]))["Reasons"] == ["known-tool"]


@pytest.mark.parametrize("name", ["python.exe", "pwsh.exe", "java.exe", "editor.exe",
                                 "setup-.exe", "baldur.exe.backup"])
def test_generic_or_nonmatching_names_are_not_selected_but_not_cleared(name):
    entry = record(invoke([fact(name=name)]))
    assert entry["State"] == "not-selected"
    assert entry["Reasons"] == []
    assert set(entry) == {"Pid", "CreationFileTime", "State", "Reasons"}


@pytest.mark.parametrize("image,selected", [
    (ROOT + r"\tool.exe", True), (ROOT.upper() + r"\tool.exe", True),
    (ROOT.replace("\\", "/") + "/tool.exe", True),
    (ROOT + r"-extra\tool.exe", False), (r"C:\synthetic\tool.exe", False),
])
def test_image_root_component_boundaries(image, selected):
    entry = record(invoke([fact(image=image)]))
    assert entry["State"] == ("candidate" if selected else "not-selected")
    assert entry["Reasons"] == (["image-root"] if selected else [])


@pytest.mark.parametrize("command,selected", [
    (ROOT, True), ('--root="' + ROOT + '"', True),
    (ROOT + r"\file", True), (ROOT.upper() + " argument", True),
    (ROOT.replace("\\", "/") + "/file", True),
    (ROOT + "-extra", False), (ROOT + "more", False),
])
def test_command_root_literals_are_conservative_bounded_selectors(command, selected):
    entry = record(invoke([fact(command=command)]))
    assert entry["Reasons"] == (["command-root"] if selected else [])


@pytest.mark.parametrize("command,selected", [
    ("java -jar NearInfinity.jar", True), ('java -jar "C:/tools/NEARINFINITY.JAR"', True),
    ("java -jar NotNearInfinity.jar", False), ("java -jar NearInfinity.jar.backup", False),
])
def test_near_infinity_argument_boundaries(command, selected):
    entry = record(invoke([fact(command=command)]))
    assert entry["Reasons"] == (["near-infinity-argument"] if selected else [])


@pytest.mark.parametrize("field,value,reason", [
    (1, None, "unknown-creation"), (1, 0, "unknown-creation"),
    (2, None, "unknown-name"), (2, "", "unknown-name"),
    (3, None, "unknown-image"), (3, "", "unknown-image"),
    (4, None, "unknown-command"),
    (3, r"relative\python.exe", "uninterpretable-image"),
    (3, r"C:\tools\..\python.exe", "uninterpretable-image"),
])
def test_unavailable_or_uninterpretable_context_is_unresolved(field, value, reason):
    item = fact()
    item[field] = value
    entry = record(invoke([item]))
    assert entry["State"] == "unresolved"
    assert entry["Reasons"] == [reason]


def test_known_empty_command_is_not_missing():
    assert record(invoke([fact(command="")]))["State"] == "not-selected"


def test_harness_preserves_csharp_null_and_empty_strings():
    result = invoke([fact(name=None, image=None, command=None), fact(pid=11, name="", image="", command="")], setup=r"""
    foreach ($property in @('Name', 'ImagePath', 'CommandLine')) {
        if (-not [object]::ReferenceEquals($facts[0].$property, $null)) { throw 'lost-null' }
        if ([object]::ReferenceEquals($facts[1].$property, $null) -or $facts[1].$property.Length -ne 0) { throw 'lost-empty' }
    }
""")
    assert record(result)["Reasons"] == ["unknown-command", "unknown-image", "unknown-name"]


def test_missing_context_retains_positive_selection_reasons():
    entry = record(invoke([fact(name="Baldur.exe", command=None)]))
    assert entry["State"] == "unresolved"
    assert entry["Reasons"] == ["known-tool", "unknown-command"]


def test_image_basename_is_evaluated_separately_from_reported_name():
    entry = record(invoke([fact(name="reported-name", image=r"C:\tools\setup-synthetic.exe")]))
    assert entry["Reasons"] == ["known-tool"]


def test_explicit_helper_image_is_a_positive_selector_not_an_exemption():
    entry = record(invoke([fact()], images=[r"c:\TOOLS\PYTHON.exe"]))
    assert entry["State"] == "candidate"
    assert entry["Reasons"] == ["helper-image"]


def test_declared_instance_is_a_positive_selector_not_an_exemption():
    entry = record(invoke([fact()], helpers=[[10, 100]]))
    assert entry["State"] == "candidate"
    assert entry["Reasons"] == ["declared-helper"]


@pytest.mark.parametrize("values", [[], [fact(pid=11)], [fact(creation=101)], [fact(creation=None)]])
def test_missing_or_reused_declared_instance_refuses_coverage(values):
    refused(invoke(values, helpers=[[10, 100]]), "COVERAGE")


@pytest.mark.parametrize("facts,complete", [(None, True), ([], False), ([fact()], False)])
def test_unknown_enumeration_is_not_a_clean_empty_snapshot(facts, complete):
    refused(invoke(facts, complete=complete), "COVERAGE")


def test_caller_reported_complete_empty_set_remains_only_screened():
    assert invoke([]) == {"code": "screened-only", "result": {"SelectorVersion": "BGSE-PROCESS-1", "Records": []}}


def test_arrays_are_defensive_and_records_have_no_setters():
    result = invoke([fact()], images=[r"C:\tools\helper.exe"], helpers=[], setup=r"""
    $roots[0] = 'C:\different'
    $images[0] = 'C:\tools\python.exe'
    $scope.WatchedRoots[0] = 'C:\different'
    $scope.HelperImages[0] = 'C:\tools\python.exe'
""", body=r"""
    $facts[0] = $null
    $records = $result.Records
    $records[0] = $null
    if ($null -eq $result.Records[0]) { throw 'record-array-leaked' }
    foreach ($type in @([Bgse.Lab.ProcessFact], [Bgse.Lab.ProcessInstance], [Bgse.Lab.ProcessScope],
        $result.GetType(), $result.Records[0].GetType())) {
        if (@($type.GetProperties() | Where-Object CanWrite).Count) { throw 'mutable-property' }
    }
""")
    assert record(result)["State"] == "not-selected"


def test_reasons_array_is_defensive():
    result = invoke([fact(name="Baldur.exe")], body=r"""
    $reasons = $result.Records[0].Reasons
    $reasons[0] = 'forged'
""")
    assert record(result)["Reasons"] == ["known-tool"]


def test_watched_root_input_and_getter_arrays_are_defensive():
    result = invoke([fact(image=ROOT + r"\tool.exe")], setup=r"""
    $roots[0] = 'C:\different'
    $scope.WatchedRoots[0] = 'C:\different'
""")
    assert record(result)["Reasons"] == ["image-root"]


def test_nonempty_declared_helper_input_and_getter_arrays_are_defensive():
    result = invoke([fact()], helpers=[[10, 100]], setup=r"""
    $helpers[0] = [Bgse.Lab.ProcessInstance]::new(999, 200)
    $scope.DeclaredHelpers[0] = [Bgse.Lab.ProcessInstance]::new(998, 201)
""")
    assert record(result)["Reasons"] == ["declared-helper"]


@pytest.mark.parametrize("delimiter", ["'", '"', "\t", "\u2003"])
def test_command_delimiters_include_quotes_and_unicode_whitespace(delimiter):
    command = ROOT + delimiter + "NearInfinity.jar" + delimiter
    assert record(invoke([fact(command=command)]))["Reasons"] == ["command-root", "near-infinity-argument"]


@pytest.mark.parametrize("command,reasons", [
    (ROOT + "-extra " + ROOT, ["command-root"]),
    ("NotNearInfinity.jar NearInfinity.jar", ["near-infinity-argument"]),
    ("NearInfinity.jar.backup NearInfinity.jar", ["near-infinity-argument"]),
])
def test_later_valid_literal_survives_an_earlier_nonmatching_occurrence(command, reasons):
    assert record(invoke([fact(command=command)]))["Reasons"] == reasons


def test_reasons_are_distinct_even_when_both_name_and_image_select_tool():
    entry = record(invoke([fact(name="Baldur.exe", image=ROOT + r"\Baldur.exe")], roots=[ROOT, r"C:\synthetic"]))
    assert entry["Reasons"] == ["image-root", "known-tool"]


def test_uninterpretable_image_does_not_erase_observed_tool_basename():
    entry = record(invoke([fact(image=r"relative\Baldur.exe")]))
    assert entry["State"] == "unresolved"
    assert entry["Reasons"] == ["known-tool", "uninterpretable-image"]
