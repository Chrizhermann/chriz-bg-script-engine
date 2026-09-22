# Task 3: sanitized measurement failure diagnostics

**Outcome:** Host-only diagnostic improvement; not a source diagnosis, another source scan, copy
admission or runtime evidence. Full host regression verification passed.

**Date / owner:** 2026-09-22 / integration lead.

**Question:** Can future read-only failures distinguish their operation and error category without
changing refusal behavior, publishing personal data or adding any filesystem writes?

**Environment / versions:** Windows 11 x64 build 26200, fixed local NTFS, PowerShell Core 7.6.6 /
.NET 10.0.12, CPython 3.11.9 / pytest 8.4.2. Base: `3252ef8`, the independently reviewed fresh-creation
checkpoint with 563 full host tests passing. Every new execution uses synthetic temporary fixtures
or in-memory test doubles. The named source was not accessed for this change.

## Motivation and unchanged boundaries

The [recorded source measurement](offline-reference-measurement.md) ended with exit 3 and
`BGSE_E_PATH_ACCESS`, but its schema-1 record retained no underlying error/stage. That packet cannot
now reveal the exact cause. Elapsed time, empty stderr and the generic code do not identify a file,
pass, permissions problem or sharing conflict. No rerun or renamed substitute scan was performed.

This change adds an **optional** `diagnostic` object to authored refusal output. Historical schema-1
records without it remain valid. Success output is unchanged; failures still report exit 3, false
write/runtime authorization and unexecuted process/writable-root admission. The wrapper remains
always read-only with or without `-WhatIf`: no diagnostic log, path-token map or other file is written.

## Diagnostic schema and limits

Only these five fields are published, after independent scalar-type and enum validation:

| Field | Admitted values |
|---|---|
| `phase` | `inputs`, `source-ancestors`, `destination-ancestors`, `inventory`, `inventory-comparison`, `destination-recheck`, `final-identities`, `capacity` |
| `pass` | Integer 1 or 2 during `inventory`; null in every other phase |
| `operation` | `guard`, `open-metadata`, `open-content`, `query-info`, `query-id`, `query-final-path`, `enumerate`, `hash-read`, `measurement` |
| `failureKind` | `guard`, `native-error`, `buffer-limit`, `managed-io`, `unexpected` |
| `nativeError` | Nonnegative 32-bit integer for `native-error`; null otherwise |

The native operation/error detail covers the implemented **path-access branches**: native open,
metadata, file-ID and final-path queries. Stream-query and disk-capacity failures retain their
dedicated refusal codes with generic guard diagnostics. This is not complete telemetry for every
native call or an identification of the exact source entry.

Native error numbers are captured immediately after failure, before disposing a handle or making
another native call. Final-path buffer exhaustion is separate and has no native error; managed
exceptions do not reuse thread-local native error state. Enumeration and hash-read wrappers
classify I/O/access exceptions as `managed-io` and other exceptions as `unexpected`. Already annotated
refusals pass through unchanged. Overflow still reaches the existing capacity classification.
The outer measurement adds phase/pass without overwriting precise inner details, and clears the
pass before inventory comparison and every subsequent phase. No diagnostic state is global.

The wrapper snapshots the five properties once, requires actual scalar types, and emits canonical
enum constants and numeric values. Malformed, missing or legacy diagnostics are omitted entirely,
without changing the original refusal. No filename, path, raw exception message, stack trace,
original inner exception, unsalted path hash or caller-owned object is published.

## Test-first and independent review record

1. Lead tests initially failed because the new observation wrapper was absent. A bounded Terra
   worker independently added two whole-command tests; both were RED because `diagnostic` was
   absent. The worker owned only `test_measurement_diagnostics_faults.py`; it touched no source/game
   or implementation file. The two corrected cases passed independently in 3.24 seconds.
2. Initial implementation made the missing-source and held-write-handle cases distinguish native
   errors 2/3 and 32, respectively, while leaving complete synthetic snapshots unchanged. Other
   lead tests exercise invalid handles, managed enumeration/read faults, unexpected exceptions and
   buffer-limit refusal. These are explicitly method-boundary tests where fault injection requires
   it, not timed whole-command race evidence.
3. Independent Astra review found two real implementation defects. PowerShell whitelist comparison
   could coerce an object through `ToString()` and later serialize its extra private-looking fields.
   Three production-wrapper tests reproduced actual synthetic-canary disclosure, one for each text
   field. Separately, the new managed observation wrapper swallowed overflow's original category;
   a fourth RED reproduced that change. The lead added explicit scalar checks/canonical publication
   and a dedicated overflow rethrow. No safety assertion was weakened.
4. Test-harness corrections are separate from those production defects: a wrapper invoked through
   `pwsh -Command` needed explicit propagation of `$LASTEXITCODE`; JSON-created test-double integers
   needed the same 32-bit types as the real C# properties. After those corrections, the three
   privacy REDs reached and demonstrated the actual publication defect.
5. The corrected focused suite passed **31 tests in 32.56 seconds**. It also checks legacy/missing
   diagnostics, malformed scalar fields, precise-refusal preservation, post-inventory `pass=null`,
   unchanged source fixtures, absent destination and no canary/path disclosure. Independent Astra
   rereview accepted the narrow checkpoint subject to full regression validation. The reviewer
   inspected code/tests but did not execute them. No Luna or Claude was involved.
6. After the full pass, a bounded Terra documentation/state review confirmed the failed-source
   boundary and in-progress task state. An ambiguous abbreviated filename initially sent that
   reviewer to a nonexistent root `.tasks.json`; the lead supplied the exact
   `docs/plans/2026-08-27-research-and-vertical-slices.md.tasks.json` path and the corrected check
   passed. Future handoffs must name that plan-suffixed state file explicitly.

## Reproduction and verification

From the repository root, using temporary host fixtures only:

```powershell
python -X utf8 -m pytest -q tests/tooling/test_measurement_diagnostics.py tests/tooling/test_measurement_diagnostics_faults.py
python -X utf8 -m pytest -q
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File scripts/test-g0-line-endings.ps1
git diff --check
```

Both G0 validators, the LF/CRLF validator regression and `git diff --check` passed after the code
corrections. Full regression validation of the **new diagnostic code**, not a repeat source scan,
passed **594 tests in 200.73 seconds**, exit 0 with empty stderr, as job
`760baf32-937a-4a17-8a53-dc7799e42c29`. The lead verified its status and saved output after the
completion notification. Its durable ignored record is `.work/task3/work/diagnostics-tests-v1/`.
No job was repeated or watcher polled. Ten relative Markdown links and the persisted in-progress
Task 3 state were also checked. None of these host results clears the source-acquisition barrier.

Raw-byte tool identities for this submitted run (including current line endings):

| Artifact | SHA-256 |
|---|---|
| `scripts/measure-offline-reference.ps1` | `070502B4747D414B1F4B6BA854F4D0F46C07B5EFD2116B7A622DB30EDCCC14E7` |
| `scripts/lib/SourceMeasurement.cs` | `259AD26EB596AEB6D6F1376B713D46D306F130057FD27D31259744DCB16AD466` |

**Evidence:** E2 synthetic host behavior and deterministic method tests. No game access, accepted
source inventory, E3/E4/E5, copying, runtime profile admission or gate completion.

**Artifacts:** Authored helper/wrapper changes, synthetic tests and this redacted memo; no game data
or real exception path is an artifact. The original failed source record is preserved separately.

**Counterevidence / residual uncertainty:** The focused tests demonstrate both the original
ambiguity and the malformed-value publication hazard; requested types or generic catch blocks were
not enough. These new fields may identify a future failure category but do not name the exact
entry. Exact-path diagnostics would require a separately admitted private channel. They cannot
retroactively diagnose the original failure.

**Next checkpoint / barrier:** Retain the failed source result and the instruction not to repeat
it. A new source diagnostic operation needs explicit direction before execution; this host-only
change is not that approval. Source-specific investigation and the complete copier contract are
still required before any real copy. No weakened sharing, skipped entries, automatic retry, launch
or active-profile change follows from this checkpoint. Task 3 remains in progress; no G1 pass.
