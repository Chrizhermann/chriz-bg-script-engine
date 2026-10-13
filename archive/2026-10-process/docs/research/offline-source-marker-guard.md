# Task 3: reject inherited lab readiness markers

**Outcome:** Focused host tests, independent review and the 613-test full host regression pass.
No accepted source inventory, copy, runtime admission or gate completion.

**Date / owner:** 2026-09-23 / integration lead.

**Question:** Can offline source measurement accidentally accept a lab readiness marker as ordinary
copyable data, allowing a future unchanged copy to inherit someone else's readiness claim?

**Environment / versions:** Windows 11 x64 build 26200, PowerShell Core 7.6.6 / .NET 10.0.12,
CPython 3.11.9 / pytest 8.4.2; starting repository checkpoint `58a4a94`. All test writes are to
synthetic temporary folders. No game source, destination, save, configuration, running app or
process inventory is accessed during this checkpoint. The user is streaming/using the PC and
may play; the real source scan and any game/app control remain deferred.

## Existing requirement and narrow policy

The [lab runbook](../../../../docs/research/disposable-lab-runbook.md) says never to copy or link a readiness marker from
another lab. Its offline amendment and [source preflight](../../../../docs/research/disposable-lab-provisioning.md) also
prohibit marking an offline acquisition launch-ready. A read-only measurement is neither
provisioning nor copy authorization, but should reject this known contamination before producing
an accepted inventory.

The reserved basename is exactly `.bgse-disposable-lab.json`, compared case-insensitively with
ordinal semantics. Any occupied source entry with that name, at any depth and regardless of
file type or contents, is refused. This includes an empty/malformed file, a directory or a
redirect with that name; no attempt is made to validate, repair, strip, ignore or adopt it.
Near names such as `.bgse-disposable-lab.json.bak` remain ordinary data, subject to every existing
path/type/stream/identity guard. The conservative directory-name reservation does not mean a
directory could serve as a valid runtime marker.

The inventory guard runs after lexical path validation and before its per-entry open or payload
read. Ancestor checks have already metadata-opened the source root; a valid source directory with
the reserved basename is then refused by the inventory guard, while invalid roots can fail earlier.
Another earlier error can stop traversal before a later marker is reached: this is not a separate
global marker-presence scan or a promise of error precedence over all other checks.
Refusal uses `BGSE_E_SOURCE_MARKER`, exit 3, with the existing scalar guard diagnostic
and false write/runtime flags. It does not add a path, marker body, lab ID or original exception
to public output. Success output is unchanged.

## Test-first and review record

The initial lead test placed an empty root marker beside ordinary synthetic data. The old tool
returned exit 0 instead of the required exit 3: a genuine RED demonstrating accepted contamination,
not a test-harness or environment failure. Root cases also cover malformed/valid-looking payloads,
both `-WhatIf` modes, unchanged full fixtures, absent destination and near-name positive controls.

A bounded Terra worker independently authored four whole-wrapper fault cases in its assigned test
file only: nested directory/file markers, a marker-named junction and a marker held open for writing.
All four were RED before implementation: the directory/file were accepted; the junction reached
the ordinary reparse guard; the held marker reached the ordinary content-open sharing guard.
The lead reviewed the tests and kept their assertions unchanged. The worker did not duplicate
the lead's combined GREEN run. No game access, visible app interaction or source scan occurred.

Independent lead-model design review supported the narrow guard and identified two important
wording limits: source-root ancestor metadata opens happen before inventory, and another earlier
failure can mask a later marker. The lead incorporated those limits and added test-first coverage
for a marker-named source root plus a locked near-name control. The source-root RED also showed
the previous tool accepting the reserved directory name. Implementation adds one private C# name
guard and one allowed PowerShell refusal code; it changes no native access/share flags.
Independent review of the final implementation found no consequential code/test defect and
accepted the checkpoint subject to validation and those documentation corrections. The reviewer
did not execute tests. The lead incorporated the corrections; no assertion was relaxed.
A separate bounded Sol 6 reviewer checked the documentation/task state, privacy and relative links
without tests, job access or edits. It found no consequential inconsistency and caught stale
next-step wording that still listed the already completed implementation review; the lead corrected
that wording. This worker choice follows the user's newly stated preference for Sol 6 on suitable
bounded subtasks. Design, diagnosis, implementation and final judgment stayed with the lead.

## Reproduction

Use synthetic fixtures only, from the repository root:

```powershell
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_offline_source_marker.py archive/2026-10-process/tests/tooling/test_offline_source_marker_faults.py
python -X utf8 -m pytest -q
pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File archive/2026-10-process/scripts/test-g0-line-endings.ps1
git diff --check
```

**Verification:** The combined focused suite passed **19 tests in 25.49 seconds**, exit 0. Both G0
validators and the LF/CRLF validator regression passed. Full host regression passed **613 tests
in 242.71 seconds**, exit 0, empty stderr, as job `1097ef63-76f1-4a7e-be53-3f18e447b1cc`. After its
completion notification, the lead verified `status.json`, both output logs and `job.json` in the
durable ignored `.work/task3/work/marker-guard-tests-v1/` record. The job ran from
`2026-09-23T14:36:33.276850Z` to `2026-09-23T14:40:36.895535Z` (243.62 seconds total elapsed).
The command was the documented full host pytest invocation. Both tool hashes still matched the
submitted identities below. No job was repeated or watcher polled. The earlier 594-test pass
belongs to `aa75fd6`; the 613-test result includes this new guard's 19 cases.
JSON task-state validation, sixteen relative Markdown links and `git diff --check` also passed.

Raw-byte tool identities at submission (line endings included):

| Artifact | SHA-256 |
|---|---|
| `archive/2026-10-process/scripts/measure-offline-reference.ps1` | `620B2A14B504F3351C11AF972E3D3171740F9E5F7678552084A49691F93DFF04` |
| `archive/2026-10-process/scripts/lib/SourceMeasurement.cs` | `0B8400C0E27AF1E741889AB90DAE402FD12001078CD930EED566408454D2C103` |

**Evidence / artifacts:** E2 synthetic host tests, authored code and redacted documentation only.
No installed-game content, E3/E4/E5 evidence or Task 3 completion.

**Counterevidence / residual uncertainty:** A name guard in read-only measurement is not a
mutation-time copy boundary. The future operational copier must revalidate the complete source
and refuse a marker that appears after measurement; it cannot treat an older accepted inventory
as authority to copy. No whole-command race or persistent filesystem snapshot is claimed here.
The original source-sharing conflict is not fixed or retested by this work.

**Next checkpoint / barrier:** The host-only marker guard is verified. Real source access waits
for a coordinated quiet window and direction. Complete copier/process/protected-root guards,
runtime-profile admission, independent writable roots and launch/reset proof remain separate.
