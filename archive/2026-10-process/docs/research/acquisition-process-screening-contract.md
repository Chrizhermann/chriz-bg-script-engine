# Task 3, packet A4a: bounded process screening

**Status:** Reviewed pure implementation and full host regression verified. Accepted only for
bounded supplied-fact screening. A3 is verified at `d1b01b6`. No native process provider or admission.

**Date / owner:** 2026-09-27 / integration lead.

**Question:** Can supplied process observations be screened conservatively without confusing an
unrelated interpreter, missing information or a name match with proof of actual game-tree use?

## Scope and evidence

This is the first part of packet A4, not a native process provider or acquisition preflight.
It accepts supplied scalar facts just as A2 accepts supplied capacity values. It cannot prove
that the caller supplied every process or told the truth. No source, game, process, thread,
registry, WMI, filesystem or network operation occurs in the classifier. No process is launched,
terminated, suspended or contacted. No source retry window is reopened.

The [acquisition packet](offline-acquisition-acceptance.md) requires fresh coordination and a
bounded process observation. It explicitly disclaims an exhaustive open-handle inventory.
The [earlier diagnostic](private-measurement-diagnostics.md#post-checkpoint-coordination-no-dispatch)
records six uncertain shell instances; the user later identified those specific instances as
unrelated. That was not permission for a permanent interpreter-name or process-ID allowlist.
Independent repository inspection found no existing operational process classifier/provider;
the current measurement still says `processCheck = unexecuted`.

Microsoft documents process-ID reuse and supplies creation-time and image/command-line fields;
parent IDs are also reusable. These are E0 inputs, not a claim that a native correlation provider
has been proved. A PID, name or apparent parent alone cannot identify a continuing instance.
[Win32_Process](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process),
[GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes)

## Frozen typed boundary

- `ProcessFact(uint pid, ulong? creationFileTime, string name, string imagePath, string commandLine)`:
  immutable scalar record. PID must be nonzero. `null` means unavailable, never an empty known value. Creation time is
  the raw positive Windows FILETIME observation; no name/parent inference supplies a missing one.
- `ProcessInstance(uint pid, ulong creationFileTime)`: both values nonzero; an exact instance declared relevant by
  external coordination; this is a **positive selector**, never an exemption.
- `ProcessScope(string[] watchedRoots, string[] helperImages, ProcessInstance[] declaredHelpers)`:
  defensive immutable arrays. Roots are supplied explicitly, never inferred or broadened to a
  shared parent. Helper images are exact paths, not caller regexes. Empty helper lists are valid;
  null lists are unknown and invalid. Do not infer complete real coordination from empty lists.
- `ProcessScreening.Screen(ProcessScope scope, ProcessFact[] facts, bool enumerationComplete)`:
  pure screening only. A false completeness flag or missing collection refuses. A true caller
  flag is **not independently verified enumeration**. The native provider remains mandatory.
- Immutable private result: `SelectorVersion = "BGSE-PROCESS-1"` and defensive `Records` array.
  Each record exposes `Pid`, `CreationFileTime`, `State` and defensive `Reasons` (distinct fixed codes,
  no raw command line or path). Sort records by PID and reasons ordinally. No `clear`, `safe`,
  ready, admitted or authorization property. Supplied facts may contain secrets: do not log them.

Frozen limits: maximum 16,384 process facts and declared helpers, **1-64** watched
roots, 256 helper images, 255 name characters, 32,766 image/root characters and 32,767 command
characters; aggregate fact text <= 8,388,608 UTF-16 code units. Check array counts before cloning;
validate scalar and aggregate text on the bounded defensive snapshot, not a mutable caller array.
All supplied text must be valid UTF-16 without NUL. Malformed structure, duplicates (PID for
facts/helpers; slash-normalized case-insensitive exact paths for scope) or exceeded bounds refuse with
`BGSE_E_PROCESS_INPUT`. Invalid/incomplete enumeration refuses `BGSE_E_PROCESS_COVERAGE`.
Do not truncate facts or discard a row. Reproduce the existing ordinary absolute Windows lexical
grammar as a pure string check; do not call native/path-resolution helpers or inspect existing
paths. This is not native alias/reparse/physical-identity validation. A later provider must account
explicitly for reserved/opaque OS records rather than silently discarding them to satisfy PID rules.

## Three states, no automatic clearance

| Observed supplied facts | State / consequence |
|---|---|
| One or more positive selectors; all context fields present and interpretable | `candidate`: needs relevant-activity review; not proof of a held file |
| Missing creation/name/image/command or invalid image spelling | `unresolved`: never clears admission |
| Complete interpretable facts with no selector | `not-selected`: only absence of matches under this finite rule set, not proof of unrelatedness or no access |

Unavailable fields remain unresolved even if some positive selector is also present; retain all
applicable reasons. A known empty command line is distinct from a failed retrieval. Empty or
missing names/images and unknown creation time are unresolved. Invalid lexical image spelling
is unresolved, not repaired or converted into a trusted path. Native provider truncation must
be reported as incomplete/unknown, not passed as a plausible complete string.

Declared helper missing from the supplied snapshot, or the same PID with unknown/zero/different
creation time, refuses the entire screening as `BGSE_E_PROCESS_COVERAGE`. Ordinary undeclared
facts with unknown/zero creation time remain row-level unresolved. It cannot silently turn a previously
relevant helper into a newly unrelated process. A future provider/coordinator must freshly prove
exit/replacement and refresh the declaration set; a classifier cannot guess why it disappeared.

No self or unrelated-process exemption exists in A4a. A later provider must bind its one actual
observer instance to reviewed code, invocation and phase. Never exclude all interpreters, an
application's ancestors/descendants or a caller PID list. Children are independently observed.
Any future exact-instance scope attestation needs its own reviewed provenance and freshness
contract; this packet adds no new authority to clear unknown activity. The user's specific prior
clarification remains historical input, not a reusable exemption.

## Version 1 positive selectors

Apply case-insensitive ordinal matching, separately to observed name and image basename where
available. Name/command matches select conservatively; none grants clearance.

1. Image at/below an explicit watched root, with a directory-component boundary.
2. Known candidate spellings: `Baldur.exe`, `InfinityLoader.exe`, `EEex.exe`, `WeiDU.exe`,
   `NearInfinity.exe`; also `setup-<nonempty>.exe` (WeiDU-style naming). These are conservative
   match rules, not identification/provenance proof for arbitrary renamed executables.
3. Exact explicit helper image, or exact declared PID + creation-time instance.
4. A watched-root literal in the command line after normalizing `/` to `\`, bounded after the
   root by end-of-text, a path separator, `Char.IsWhiteSpace` whitespace or single/double quote. This may overselect a quoted
   mention and therefore is not proof of current access. A sibling like `game-extra` must not
   match `game`. Do not execute, expand variables, decode commands or infer a working directory.
5. A case-insensitive `NearInfinity.jar` literal in the command line, with basename delimiters
   (start, separator, `Char.IsWhiteSpace` whitespace or single/double quote before;
   end, whitespace or single/double quote after).

Generic `python`, `pwsh`, `java`, an editor name, an external script path or a shared parent alone
neither selects a conflict nor proves unrelatedness. A complete generic interpreter with no
positive selector is only `not-selected`; incomplete context is unresolved. Relative paths,
configuration files, encoded commands, aliases, IPC, plugins and later work can evade these
literal selectors. Fresh coordination must supply known relevant helpers even without literals.
This version is not an arbitrary Windows/shell command parser or hostile-process security model.

Reason vocabulary to freeze: `command-root`, `declared-helper`, `helper-image`, `image-root`,
`known-tool`, `near-infinity-argument`, `unknown-creation`, `unknown-name`, `unknown-image`,
`unknown-command`, `uninterpretable-image`. No partial result on structural/coverage refusal.

## Required TDD and later barriers

Start with a real missing-helper RED. Cover all three states, directory-prefix boundaries,
both slash spellings/case, conservative tool selectors, unrelated complete generic interpreters,
missing versus empty command line, each missing field, bad image spelling, declared helper
matching/missing/PID reuse, malformed/bounded inputs, immutability, ordering and refusal privacy.
Use synthetic strings only. Independent review must inspect branch reachability, not just counts.

Before real use, A4 still requires a bounded native provider with instance-correlated facts,
observation interval and completeness/error accounting; private/public output discipline;
exact current observer treatment; fresh coordination including scoped helper ownership;
approved root/operation binding; repeat checks before first write and final publication; and
host fixture tests including late process conflict and missing data. Native provider failures
cannot be hidden behind a caller-created empty snapshot. A4a alone accepts none of those claims.

Actual opaque system/helper observations may require a separate scope decision. Preserve them
as unresolved instead of silently introducing an OS/service or name-based bypass. Stop and ask
the user about genuinely unresolved relevant activity when encountered in an authorized
operational preflight; do not inspect unrelated apps or repeatedly ask about unchanged state.

## Execution, review and reproduction

Independent review accepted the non-admitting scope and required explicit
zero-ID/helper-correlation semantics, normalized scope duplicates, distinct reasons and safe
snapshot/validation order. These are incorporated above. The genuine missing-helper test failed
before `ProcessScreening.cs` existed: 1 failed in 1.36 seconds.

The initial implementation run had 3 failures and 50 passes in 68.43 seconds. All three failures
concerned unavailable command lines. The lead reproduced the harness cause directly: passing
plain PowerShell `$null` into a C# string parameter produced an empty string (length zero,
`ReferenceEquals(value, null) == false`). Passing
`[System.Management.Automation.Language.NullString]::Value` preserved a real C# null.
The harness now uses that explicit sentinel for missing strings; no production assertion was
relaxed. A direct constructor-boundary test checks null and empty for name, image and command.
The corrected 54-test primary file passed in 74.31 seconds. This conversion hazard must also
be handled explicitly if a future native provider constructs facts through PowerShell.

Independent static review found no blocking implementation defect but identified two masked
immutability checks: the original fact was outside both original and replacement watched roots,
and the declared-helper array was empty. Separate tests now use an originally contained image
and a nonempty relevant helper; either array leak changes the asserted result or refuses.
Additional cases cover quotes/Unicode whitespace, a later valid literal after a nonmatching
one, duplicate reason suppression and a tool basename retained on an uninterpretable image.
Those 11 additions passed in 17.67 seconds. The reviewer accepted the corrected primary cases
and the doc table's whole-screen declared-helper coverage semantics. No reviewer execution is
claimed. The helper has no process, native, filesystem or child-process calls.

A Sol 6 worker owns only the independent malformed-input/limit/privacy test file. The lead
identified null-filled overcount arrays as insufficient evidence of count-guard reachability;
the worker replaced them with otherwise valid unique facts/instances and at-limit positives.
An absent helper-count guard now reaches a distinct coverage refusal, not the expected input
refusal. Oversized text is constructed inside the test process, preventing environment/command
transport limits from impersonating a library guard. The worker's focused run passed all 63
cases in 100.69 seconds, exit 0; only two trailing spaces were removed afterward. The lead
read the final cases and confirmed the branch distinction. All 128 new cases therefore passed
in the three focused runs above; the combined full regression of the final bytes is verified below.
The final independent static review accepted the corrected fault cases, including valid-entry
overcount versus coverage behavior, at-limit success, text budgets, UTF-16 and privacy branches.
No blocking review finding remains. JSON, local links, public path scan and staged whitespace
checks passed before dispatch and again before committing the verified checkpoint.

Environment: Windows x64 `10.0.26200.0`, PowerShell 7.6.6, Python 3.11.9, pytest 8.4.2.
Exact authored/test/dependency/tool fingerprints and the saved full command belong in the
private Task 3 checkpoint. The test harness starts fresh PowerShell compilers; the classifier
itself starts nothing. A classifier source inspection is not whole-operation no-child proof.
Both existing G0 validators and their LF/CRLF regression passed; no gate status changes.

Reproduce the focused tests with:

```text
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_process_screening.py archive/2026-10-process/tests/tooling/test_process_screening_faults.py
```

Then run the complete host suite with `python -X utf8 -m pytest -q`, capturing the exit status,
stdout/stderr, exact command and tool identities. Do not substitute the process facts from this
test harness for an operational observation. No game/source access or copy is needed for these
tests. No source retry, real process enumeration or new coordination reservation occurred.

Collection found 1,017 tests (889 prior plus 128 new) in 0.29 seconds. Collection is not a pass.
The full suite was dispatched once as job `2246a81f-9b8e-4100-901e-fbc24d9ca418`, launcher
exit 0, into fresh `work/process-screening-tests-v1` under private Task 3 records, with a
1,800-second timeout and one completion message. On completion it reported **succeeded, exit 0,
1,017 passed in 881.99 seconds**, empty stderr, no warnings/skips or timeout. The status interval
was 15:30:35.317062 to 15:45:19.487270 UTC on 26 September, 884.170208 seconds. Eight result
files total 2,466 bytes; one notification was accepted. No polling, rerun or overwrite occurred.

The lead checked the saved command/status/output and all seven saved helper/test/dependency/tool
fingerprints. An independent Sol 6 saved-result audit matched the command, count (889+128),
exit/status/time bound, single notification and all three authored helper/test fingerprints;
no discrepancy was found. No implementation or test bytes changed after dispatch. This accepts
only the A4a classifier, not the operational requirements below. Authored helper SHA-256:
`C1A645F7C0D76393517055DC5378FE2C1F2ECE7DF04C805E05AD1ACC0B6BC54F`.

**Evidence / uncertainty:** E1 repository inspection at `d1b01b6`, E0 Microsoft documentation,
and E2 pure synthetic supplied-fact assertions only. The caller's completeness flag is unverified;
hidden/encoded/relative access, PID reuse during real observation, denied/opaque process data,
OS provider timeouts and late activity have not been exercised. Native provider/correlation,
current-observer identification, fresh scoped coordination and complete bound `-WhatIf` remain
required within packet A. Copier packets B-E, runtime profile/roots/launch/reset and G1 remain
open. No real admission, E3/E4/E5 result or Task 3 completion is claimed.
