# ADR 0004: Evidence layers and environment gates

**Status:** Accepted

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

Every material claim records the applicable proof environment or combination:

- **E0 — claim/documentation input:** upstream documentation, comments, forum statements, unpinned
  source, or an unverified design assumption;
- **E1 — pinned static evidence:** revision-pinned source or a reproducible effective artifact,
  binary, decompile, install output, or provenance chain;
- **E2 — deterministic host simulation:** pure Lua/model tests, replay, property tests, or
  state-machine exploration outside the game process;
- **E3 — synthetic-game integration:** real WeiDU operates on a minimal fake game without launching
  a game executable;
- **E4 — disposable-engine proof:** behavior is observed in an isolated full BG2:EE plus EEex
  environment; and
- **E5 — supported-corpus soak:** repeated declared compatibility, save/load, performance, and
  failure-path coverage.

The layers are not a scalar confidence ladder. E4 runtime behavior does not replace required E3
installer/restoration proof. G0 through G8 are stop/go authorization decisions, not evidence grades;
new work cannot proceed through a failed or pending gate merely because another environment passed.

## Context

Source inspection, deterministic logic tests, installer behavior, engine behavior, and repeated
compatibility testing answer different questions. The prior documents used conflicting E3 language,
which could let a fake-game patch test be mistaken for an engine test or vice versa. Program epics
also use E0-E11, so records must qualify ambiguous identifiers as `epic:E*` or `evidence:E*`.

## Alternatives

- **One scalar maturity score:** rejected because it permits unrelated runtime evidence to mask a
  missing installer or restoration proof.
- **Documentation/source as sufficient proof:** rejected for safety-critical runtime behavior.
- **Run every question in a full game:** rejected because host and fake-game tests are safer, faster,
  more deterministic, and often the correct proof environment.
- **Use the active game for convenience:** rejected because it risks the user's installation and
  playthrough and cannot provide a resettable experiment.

## Consequences

Research memos state question, environment, versions/fingerprints, method, observations,
counterevidence, artifacts, evidence layers, residual uncertainty, and next decision. Missing tools
or environments are recorded as unexecuted. Queue acceptance is never reported as action completion;
runtime postconditions require independent observation.

## Compatibility

Support claims name the exact tier, adapter version, capability profile, install stack, evidence
combination, and untested boundary. A failed proof disables or narrows only the dependent adapter.
No evidence grade promotes unknown content from C0 or waives runtime ownership checks.

**Unknown-content rule:** Unknown, modified, stale, or ambiguous content remains legacy-owned in
every environment and at every gate.

**Active-game boundary:** The active game is read-only unless the user gives separate explicit
permission in that conversation. Task 3 requires separate authorization for a named disposable
destination; general plan approval is not that authorization.

## Evidence

- E0 definitions: `archive/2026-10-process/docs/research/research-backlog.md`, "Evidence grades."
- E0 normative alignment: `AGENTS.md`, architecture section 16.1, and acceptance-matrix section 2.
- E0 execution gates: implementation plan section 5 and acceptance-matrix gate table.
- E2 host validation: `archive/2026-10-process/scripts/validate-g0-decisions.ps1` now checks the cross-document evidence
  vocabulary, the G0 namespace contract/task-state correlation, and the scalar phrases that caused
  the original conflict. `archive/2026-10-process/scripts/validate-g0-namespace.ps1` checks deterministic namespace
  grammar and collision vectors without an engine call.
- The intentional RED and GREEN outcomes are recorded in commits `c2edd57`, `a8078ba`, and
  `1f9e80d`. The durable validator supersedes their one-off assertions.
- No E3-E5 environment was used.

Reproduce the current GREEN from the repository root:

```powershell
pwsh -NoProfile -File ./scripts/validate-g0-decisions.ps1 -RepositoryRoot .
```

Expected output after the narrowed G0 pass:

```text
Task 1 decision-record structure validation passed. G0 gate status: Pass with narrowed scope (evaluated separately).
```

Reproduce an isolated historical RED without modifying the checkout:

```powershell
$probe = Join-Path ([IO.Path]::GetTempPath()) ("bgse-g0-red-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $probe | Out-Null
git archive 5544726 | tar -xf - -C $probe
pwsh -NoProfile -File "$probe/scripts/validate-g0-decisions.ps1" -RepositoryRoot $probe
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$resolvedProbe = [IO.Path]::GetFullPath($probe)
if ($resolvedProbe.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
    $resolvedProbe -ne $tempRoot) {
    [IO.Directory]::Delete($resolvedProbe, $true)
}
```

Expected: exit 1 naming the absent ADR, template, and G0 files. The temporary archive contains only
repository history and is unrelated to any game path.

## Revisit when

Review if a planned acceptance case cannot be assigned to one or more existing proof environments.
Adding, merging, or weakening a layer requires a new ADR and updates to the backlog, plan, matrix,
and project guidance in the same reviewed change.

## Review date

2026-08-30; reviewed at every program gate.
