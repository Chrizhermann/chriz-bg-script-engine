"""Synthetic packet A1 paths only; never whole-operation or copy admission."""
from __future__ import annotations

import json
import os
import subprocess

import pytest

from test_environment_contract import POWERSHELL_PATH, REPOSITORY_ROOT, snapshot_tree


LIBRARY = REPOSITORY_ROOT / "scripts" / "lib"


def invoke(source, copy, evidence, protected, *, copy_entries=(), evidence_entries=(), body="", setup=""):
    environment = os.environ.copy()
    environment["BGSE_FOOTPRINT_REQUEST"] = json.dumps({
        "source": str(source), "copy": str(copy), "evidence": str(evidence),
        "protected": None if protected is None else [str(path) for path in protected],
        "copyEntries": copy_entries, "evidenceEntries": evidence_entries,
    })
    environment["BGSE_FOOTPRINT_LIBRARY"] = str(LIBRARY)
    command = r"""
$ErrorActionPreference = 'Stop'
$request = $env:BGSE_FOOTPRINT_REQUEST | ConvertFrom-Json
$plan = $null
try {
    Add-Type -Path @((Join-Path $env:BGSE_FOOTPRINT_LIBRARY 'SourceMeasurement.cs'),
        (Join-Path $env:BGSE_FOOTPRINT_LIBRARY 'AcquisitionFootprint.cs'))
    $protected = if ($null -eq $request.protected) { $null } else { [string[]]@($request.protected) }
    $copyEntries = [Bgse.Lab.PlannedEntry[]]@($request.copyEntries | ForEach-Object {
        if ($null -eq $_) { $null } else { [Bgse.Lab.PlannedEntry]::new($_[0], $_[1]) }
    })
    $evidenceEntries = [Bgse.Lab.PlannedEntry[]]@($request.evidenceEntries | ForEach-Object {
        if ($null -eq $_) { $null } else { [Bgse.Lab.PlannedEntry]::new($_[0], $_[1]) }
    })
    SETUP
    $plan = [Bgse.Lab.AcquisitionFootprint]::new($request.source, $request.copy,
        $request.evidence, $protected, $copyEntries, $evidenceEntries)
    BODY
    $plan.Revalidate()
    @{ code = 'footprint-only'; entries = @($plan.Creations) } | ConvertTo-Json -Depth 5 -Compress -EscapeHandling EscapeNonAscii
} catch {
    $failure = $_.Exception
    while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
    @{ code = $failure.Message; type = $failure.GetType().FullName } | ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
} finally { if ($null -ne $plan) { $plan.Dispose() } }
""".replace("SETUP", setup).replace("BODY", body)
    result = subprocess.run([POWERSHELL_PATH, "-NoProfile", "-Command", command],
                            cwd=REPOSITORY_ROOT, env=environment, capture_output=True,
                            encoding="utf-8", timeout=30, check=False)
    assert result.returncode == 0, result.stderr
    assert result.stderr == "", result.stderr
    return json.loads(result.stdout.lstrip("\ufeff"))


@pytest.fixture
def roots(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "sentinel.bin").write_bytes(b"unchanged source")
    saves = tmp_path / "saves"
    saves.mkdir()
    (saves / "sentinel.bin").write_bytes(b"unchanged protected data")
    return source, tmp_path / "copy-parent" / "game", tmp_path / "evidence-parent" / "run", [source, saves]


def assert_refused(result, code):
    assert result == {"code": code, "type": "Bgse.Lab.MeasurementRefusal"}


def test_complete_deterministic_footprint_is_read_only(roots, tmp_path):
    source, copy, evidence, protected = roots
    before = snapshot_tree(tmp_path)
    result = invoke(*roots, copy_entries=[("z/file.bin", False), ("z", True), ("empty", True),
                                        ("naïve[1].bin", False)],
                    evidence_entries=[("receipt.json", False), ("intent.json", False)])
    expected = []
    for tree, root, entries in [
        ("copy", copy, [("empty", True), ("naïve[1].bin", False), ("z", True), ("z/file.bin", False)]),
        ("evidence", evidence, [("intent.json", False), ("receipt.json", False)]),
    ]:
        expected.extend({"Path": str(path), "Tree": tree, "Relative": None,
                         "IsDirectory": True, "IsRootChain": True} for path in (root.parent, root))
        expected.extend({"Path": str(root / name), "Tree": tree, "Relative": name,
                         "IsDirectory": directory, "IsRootChain": False} for name, directory in entries)
    assert result == {"code": "footprint-only", "entries": expected}
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("which", ["copy", "evidence"])
@pytest.mark.parametrize("relation", ["same", "child", "parent", "case"])
def test_every_output_avoids_all_protected_roots_both_directions(roots, tmp_path, which, relation):
    source, copy, evidence, protected = roots
    # Keep the target's parent separate from both other outputs: otherwise an
    # output/output refusal would mask the protected-ancestor branch.
    target = protected[1] / 'nested-protected'
    target.mkdir()
    protected = [source, target]
    proposed = {"same": target, "child": target / "new", "parent": target.parent,
                "case": str(target).upper()}[relation]
    if which == "copy":
        copy = proposed
    else:
        evidence = proposed
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(source, copy, evidence, protected), "BGSE_E_OVERLAP")
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("relation", ["same", "child", "parent"])
def test_copy_and_evidence_cannot_overlap(roots, tmp_path, relation):
    source, copy, evidence, protected = roots
    evidence = {"same": copy, "child": copy / "proof", "parent": copy.parent}[relation]
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(source, copy, evidence, protected), "BGSE_E_OVERLAP")
    assert snapshot_tree(tmp_path) == before


def test_shared_missing_parent_refused_but_existing_parent_allowed(roots, tmp_path):
    source, copy, evidence, protected = roots
    shared = tmp_path / "shared"
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(source, shared / "copy", shared / "evidence", protected), "BGSE_E_FOOTPRINT_COLLISION")
    assert snapshot_tree(tmp_path) == before
    shared.mkdir()
    before = snapshot_tree(tmp_path)
    result = invoke(source, shared / "copy", shared / "evidence", protected)
    assert result["code"] == "footprint-only"
    assert [entry["Path"] for entry in result["entries"]] == [str(shared / "copy"), str(shared / "evidence")]
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("variant", ["null", "empty", "source-omitted", "duplicate", "missing", "too-many"])
def test_unknown_omitted_or_duplicate_protection_is_not_permission(roots, tmp_path, variant):
    source, copy, evidence, protected = roots
    protected = {"null": None, "empty": [], "source-omitted": protected[1:],
                 "duplicate": [source, str(source).upper()], "missing": [source, tmp_path / "unknown"],
                 "too-many": [source] + [tmp_path / f"unused-protected-{i}" for i in range(64)]}[variant]
    before = snapshot_tree(tmp_path)
    code = "BGSE_E_PATH_ACCESS" if variant == "missing" else "BGSE_E_PROTECTED_ROOTS"
    assert_refused(invoke(source, copy, evidence, protected), code)
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("relative", ["", ".", "../x", "a/../b", "/x", "a\\b", "a//b", "a/",
                                      "C:/x", "x:ads", "NUL", "bad.", "bad ", "a" * 256])
@pytest.mark.parametrize("which", ["copy", "evidence"])
def test_unsafe_relative_names_fail_without_writes(roots, tmp_path, relative, which):
    before = snapshot_tree(tmp_path)
    arguments = {which + "_entries": [(relative, False)]}
    assert_refused(invoke(*roots, **arguments), "BGSE_E_PATH_SYNTAX")
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("entries,code", [
    ([("same", True), ("SAME", False)], "BGSE_E_FOOTPRINT_COLLISION"),
    ([("parent/child", False)], "BGSE_E_FOOTPRINT_PARENT"),
    ([("parent", False), ("parent/child", False)], "BGSE_E_FOOTPRINT_PARENT"),
    ([("Parent", True), ("parent/child", False)], "BGSE_E_FOOTPRINT_PARENT"),
])
def test_topology_is_explicit_and_case_canonical(roots, tmp_path, entries, code):
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(*roots, copy_entries=entries), code)
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("which", ["copy", "evidence"])
@pytest.mark.parametrize("directory", [True, False])
def test_readiness_marker_is_not_in_any_output_plan(roots, tmp_path, which, directory):
    before = snapshot_tree(tmp_path)
    entries = [("a", True), ("a/.BGSE-DISPOSABLE-LAB.JSON", directory)]
    assert_refused(invoke(*roots, **{which + "_entries": entries}), "BGSE_E_SOURCE_MARKER")
    assert snapshot_tree(tmp_path) == before


def test_marker_in_missing_root_chain_refused(roots, tmp_path):
    source, copy, evidence, protected = roots
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(source, tmp_path / ".bgse-disposable-lab.json" / "game", evidence, protected),
                   "BGSE_E_SOURCE_MARKER")
    assert snapshot_tree(tmp_path) == before


def test_caller_arrays_cannot_change_observed_footprint(roots, tmp_path):
    before = snapshot_tree(tmp_path)
    result = invoke(*roots, copy_entries=[("kept", False)], body=r"""
    $protected[0] = 'C:\not-the-source'
    $copyEntries[0] = [Bgse.Lab.PlannedEntry]::new('changed', $true)
    $returned = $plan.Creations
    $returned[0] = $null
    """)
    assert result["code"] == "footprint-only"
    assert all(entry is not None for entry in result["entries"])
    assert [entry["Relative"] for entry in result["entries"] if not entry["IsRootChain"]] == ["kept"]
    assert snapshot_tree(tmp_path) == before


def test_disposal_is_idempotent_and_prevents_revalidation(roots, tmp_path):
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(*roots, body="$plan.Dispose(); $plan.Dispose()"), "BGSE_E_FOOTPRINT_STATE")
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("setup,code", [
    ("$copyEntries = $null", "BGSE_E_FOOTPRINT_INPUT"),
    ("$evidenceEntries = $null", "BGSE_E_FOOTPRINT_INPUT"),
    ("$copyEntries = [Bgse.Lab.PlannedEntry[]]@($null)", "BGSE_E_FOOTPRINT_INPUT"),
    ("$evidenceEntries = [Bgse.Lab.PlannedEntry[]]@($null)", "BGSE_E_FOOTPRINT_INPUT"),
    ("$copyEntries = [Bgse.Lab.PlannedEntry[]](@([Bgse.Lab.PlannedEntry]::new('valid', $false)) * 1000001)", "BGSE_E_FOOTPRINT_INPUT"),
    ("$evidenceEntries = [Bgse.Lab.PlannedEntry[]](@([Bgse.Lab.PlannedEntry]::new('valid', $false)) * 1000001)", "BGSE_E_FOOTPRINT_INPUT"),
    ("$copyEntries = @([Bgse.Lab.PlannedEntry]::new([string][char]0xd800, $false))", "BGSE_E_PATH_SYNTAX"),
    ("$request.copy = 'C:' + [char]92 + ((@('a' * 254) * 129) -join [char]92)", "BGSE_E_PATH_SYNTAX"),
])
def test_input_bounds_and_nulls_refuse_before_native_access(roots, tmp_path, setup, code):
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(*roots, setup=setup), code)
    assert snapshot_tree(tmp_path) == before


def test_combined_name_budget_real_guard_boundary_without_large_allocation(roots, tmp_path):
    # Private-method test of the real accumulated budget branch, not a claim
    # that a 64-million-character whole command was executed or memory measured.
    before = snapshot_tree(tmp_path)
    setup = r"""
    $method = [Bgse.Lab.AcquisitionFootprint].GetMethod('Children', [Reflection.BindingFlags]'NonPublic,Static')
    $args = [object[]]@($request.copy, 'copy', [Bgse.Lab.PlannedEntry[]]@(
        [Bgse.Lab.PlannedEntry]::new('ok', $false)), [long]63999999)
    $method.Invoke($null, $args) | Out-Null
    """
    assert_refused(invoke(*roots, setup=setup), "BGSE_E_FOOTPRINT_INPUT")
    assert snapshot_tree(tmp_path) == before


def test_native_identity_overlap_guard_distinguishes_shared_ancestor(roots, tmp_path):
    # Native aliases are separately exercised through actual junction/8.3 tests.
    # This invokes the real identity-comparison boundary with deterministic IDs.
    before = snapshot_tree(tmp_path)
    setup = r"""
    $method = [Bgse.Lab.AcquisitionFootprint].GetMethod('VerifySeparatePhysicalRoots', [Reflection.BindingFlags]'NonPublic,Static')
    try {
        $method.Invoke($null, [object[]]@([string[]]@('protected-root'), [string[]]@('shared-ancestor'))) | Out-Null
    } catch { throw 'positive-control-shared-ancestor-was-refused' }
    $method.Invoke($null, [object[]]@([string[]]@('protected-root'), [string[]]@('shared-ancestor', 'protected-root'))) | Out-Null
    """
    assert_refused(invoke(*roots, setup=setup), "BGSE_E_OVERLAP")
    assert snapshot_tree(tmp_path) == before


def test_output_records_have_no_public_mutators(roots, tmp_path):
    before = snapshot_tree(tmp_path)
    body = r"""
    foreach ($type in @([Bgse.Lab.PlannedEntry], [Bgse.Lab.FootprintEntry])) {
        if ($type.GetFields([Reflection.BindingFlags]'Public,Instance').Count -ne 0) { throw 'mutable field' }
        foreach ($property in $type.GetProperties()) {
            if ($null -ne $property.GetSetMethod()) { throw 'mutable property' }
        }
    }
    """
    assert invoke(*roots, body=body)["code"] == "footprint-only"
    assert snapshot_tree(tmp_path) == before


@pytest.mark.parametrize("which", ["copy", "evidence"])
def test_appeared_output_root_poisoned_creations_access(roots, tmp_path, which):
    # Only the harness creates/removes these empty fixture directories. Verify
    # the actual library branch and that poisoning also disables the getter.
    body = r"""
    $root = $request.WHICH
    [IO.Directory]::CreateDirectory($root) | Out-Null
    try {
        try { $plan.Revalidate(); throw 'unexpected success' }
        catch {
            $failure = $_.Exception
            while ($null -ne $failure.InnerException) { $failure = $failure.InnerException }
            if ($failure.Message -cne 'BGSE_E_DESTINATION_EXISTS') { throw }
        }
        $ignored = $plan.Creations
    } finally {
        [IO.Directory]::Delete($root)
        [IO.Directory]::Delete([IO.Path]::GetDirectoryName($root))
    }
    """.replace("WHICH", which)
    before = snapshot_tree(tmp_path)
    assert_refused(invoke(*roots, body=body), "BGSE_E_FOOTPRINT_STATE")
    after = snapshot_tree(tmp_path)
    before["."].pop("mtime_ns")
    after["."].pop("mtime_ns")
    assert after == before
