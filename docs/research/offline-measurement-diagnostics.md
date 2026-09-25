# Task 3: sanitized measurement failure diagnostics

**Outcome:** Host-only diagnostic improvement passed full regression verification. Separately
authorized source observations on 2026-09-23 and 2026-09-24 identified content-open sharing
violations, but not the exact files or conflicting owners. The latter followed quiet-window
coordination and still refused; no accepted inventory, copy admission or runtime evidence.

**Date / owner:** 2026-09-22; source-result follow-ups through 2026-09-24 / integration lead.

**Question:** Can future read-only failures distinguish their operation and error category without
changing refusal behavior, publishing personal data or adding any filesystem writes?

**Environment / versions:** Windows 11 x64 build 26200, fixed local NTFS, PowerShell Core 7.6.6 /
.NET 10.0.12, CPython 3.11.9 / pytest 8.4.2. Base: `3252ef8`, the independently reviewed fresh-creation
checkpoint with 563 full host tests passing. Implementation-checkpoint executions used synthetic
temporary fixtures or in-memory test doubles. The named source was not accessed for that change;
the separately authorized observation is recorded at the end of this memo.

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

## Separately authorized source diagnostic — 2026-09-23

The user explicitly approved **one new read-only diagnostic scan** after the host-only checkpoint
above. This supersedes only the need for permission for that one operation; the original failed
measurement and its no-rerun record are preserved. Copying, installation, game/loader execution,
source mutation and runtime admission remain excluded. A refusal permits no automatic retry,
weakened check or skipped entry.

The integration lead launched the instrumented code at `aa75fd6` once in a fresh PowerShell process,
with `-WhatIf`, the previously approved source/destination from the private request, output allowance
`1073741824` bytes and safety reserve `21474836480` bytes. Both raw tool hashes matched the table
above immediately before submission. The 1,800-second safety timeout does not authorize a retry.
Private approval details are in `.work/task3/source-diagnostic-authorization.json`; the new job is
`68fae1fa-f426-40e8-9f90-609cf4856e86`, with durable results under
`.work/task3/work/source-diagnostic-v1/`. These private files remain ignored.

A bounded Terra reviewer independently inspected the wrapper/helper and confirmed the read-only
boundary, fresh-process requirement and diagnostic limitations. The reviewer did not access the
game, request, job or results, and ran no commands against them. The lead retains result verification
and diagnosis. No code changed and the previous 594-test checkpoint remains historical test evidence.

### Verified result and bounded interpretation

After the completion notification, the lead read `status.json`, `stdout.log`, `stderr.log` and
`job.json` once. The recorded command matched the approved operation and allowances:

- Started `2026-09-22T15:06:10.042194Z`; finished `2026-09-22T15:13:40.321807Z`:
  **450.28 seconds**, `state=failed`, **exit 3**, not a timeout.
- Standard error was empty. Standard output was exactly one schema-1 refusal:
  `BGSE_E_PATH_ACCESS`, `writesAuthorized=false`, `runtimeReady=false`, with process and
  writable-root admission still `unexecuted`.
- Its diagnostic was `phase=inventory`, `pass=1`, `operation=open-content`,
  `failureKind=native-error`, `nativeError=32`.
- No accepted inventory, file count, capacity result or content/identity digest was returned.
  No repeat invocation, watcher polling, copying, installation or game execution followed.

Microsoft identifies native error 32 as
[`ERROR_SHARING_VIOLATION`](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-).
The failure therefore occurred at the first inventory pass's native content-open, before hashing
that entry. It is not evidence of an ACL/permissions failure, absent file, corrupt game or
byte-range lock (the latter has a different error code). It does not retroactively establish the
cause of the older, uninstrumented failed job.

The [CreateFileW sharing contract](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew)
checks compatibility with existing access/sharing and writable mappings, regardless of process
context. Our content-open requests `GENERIC_READ`, sharing reads only, so an existing writable
handle or mapping is one possible cause. The packet does not identify the file, owner, exact
conflicting access or duration. It cannot distinguish a persistent conflict from a transient one.

Lead inspection and an independent Astra review found **no ordinary self-conflict path**: the
scanner's same-file metadata handle requests access `1` with sharing `3`, compatible with its
content handle's `GENERIC_READ` and sharing `1`; it creates no writable file handle or mapping.
The exact diagnostic is already reproduced by the synthetic held-writer regression. This source
review is not proof excluding every filesystem/filter interaction or identifying another process.
The reviewer accessed repository code/tests only, not the real source or job output.

A separate, one-time **read-only OS process snapshot** at `2026-09-23T00:14:48.0626090+09:00`
queried only `Baldur.exe` and `InfinityLoader.exe`, then matched their executable directories to
the approved source root. It found zero matches and zero unreadable image paths. This was not a
source-tree rescan, open-handle inventory or copy-admission process check; no process was changed.
It does not establish what was running at failure time or exclude other holders/mappings.

**User-supplied coordination context:** After this result, the user reported that another agent
had been testing with a running game and attributed the conflict to that activity. This is
consistent with the observed sharing violation, but the report did not bind a particular file,
executable path or process to the failed open. Record it as the likely operational explanation,
not an independently verified lock-owner diagnosis. The later zero-match snapshot does not refute
the report. No other agent, game or process was interrupted.

### Verification, evidence and next decision

No implementation changed. The following synthetic-only command passed **4 tests in 5.66 seconds**:

```powershell
python -X utf8 -m pytest -q tests/tooling/test_measurement_diagnostics_faults.py tests/tooling/test_offline_reference_measurement.py::test_measurement_is_read_only_and_not_write_or_runtime_admission
```

This checks the reproduced sharing conflict, missing-source distinction and ordinary successful
measurement with and without `-WhatIf`, including unchanged synthetic trees. Both G0 validators
and the LF/CRLF regression also passed. The 594-case full suite above was **not** rerun; its result
belongs to the unchanged implementation checkpoint. Documentation/task-state validation is recorded
with this evidence commit: JSON state validation, ten relative Markdown links and `git diff --check`
passed. A bounded Terra read-only review confirmed consistency/privacy before the user's concurrent
testing explanation; the lead then updated the next decision to prioritize coordination over a
new file/holder investigation. No code changed.

**Evidence:** E1 captured point-in-time host refusal from pinned authored tooling, E2 synthetic
reproduction/positive controls, and E0 Microsoft API documentation. This is not an effective-game
inventory, E3/E4/E5 evidence or a gate pass. Task 3 remains in progress.

**Next decision / barrier:** The one authorized diagnostic operation has been consumed. Given the
user's explanation, first coordinate a quiet source window: confirm the other agent has finished
and relevant game/loader activity has ended, then obtain direction for another read-only check.
The report alone is not confirmation of shutdown or permission to stop someone else's work. Do not
repeat the scan automatically or require a new private-path diagnostic before trying the agreed
quiet window. If the conflict recurs, a separately scoped private file/holder investigation may
be appropriate; any exact paths stay outside version control. No application termination, forced
handle closure, source change, skipped entry or relaxed sharing is authorized. Complete copier
guards, runtime-profile admission and independent writable-root isolation remain separate
requirements even after the sharing conflict is resolved.

## Quiet-window coordination — 2026-09-24

The user confirmed the game was no longer running and authorized waiting and running later when
other tasks might overlap. This permits one new read-only check once a quiet source window is
established; the no-launch, no-app-control and no-game/save/configuration-write boundaries remain.

At approximately 05:24 local time, two related BG tasks were active. Recent history in the installer
task included work on the same installation/profile; current overlapping activity could not be
excluded. A bounded OS snapshot for named game/loader/setup/WeiDU/NearInfinity executables found
zero images under the source and zero unreadable image paths. This is not an exhaustive tool/handle
inventory or a quiet-window guarantee. A single 60-second task event wait timed out without either
task completing. No source file was opened and no new measurement was dispatched.

A thread follow-up named `Resume BGSE scan when the source is quiet` was created, ID
`resume-bgse-scan-when-the-source-is-quiet`, at a 30-minute interval. It rechecks task/process
coordination, remains quiet on unchanged waiting state, and can dispatch one new read-only scan
with the recorded source/destination and allowances. It must pause immediately after dispatch,
leaving result verification to the command's own completion notification; it is not a job watcher
or permission for repeated failed scans. No other task or process is interrupted. Failed launch,
scan refusal or a substantive decision blocker is preserved and reported rather than retried.

This is coordination state only. The verified tooling remains `7959996` with 613 host tests; no
new inventory, source diagnosis, copy admission or gate evidence is claimed.

### Dispatch safety clarification — 2026-09-24

At approximately 06:26 local time, both related tasks reported idle with completed latest turns;
no other active relevant task was returned in the pinned/recent-task listing. Latest handoff text
was unavailable, so absence of detached work was not established. The bounded named-process
snapshot again found no source-path matches, unreadable image paths or other matching images.
These observations are not an exhaustive handle inventory or lasting quiet-window clearance.

No scan was dispatched. Inspection of the required `codex-completion-wakeup` runner found a
conflict with the follow-up's literal **no-process-termination** restriction: the runner requires
a finite positive timeout and forcibly terminates its own command's process tree on expiry.
There is no supported no-termination mode. A separate Sol 6 read-only review confirmed the
control flow; the lead inspected the same code. No helper was modified or invoked, no game file,
save or configuration was changed, and no existing app/process was controlled or terminated.
This is an authorization conflict, not a
scanner defect or new source refusal.

The heartbeat was paused at approximately 06:29 local time. The single renewed measurement
authorization remains unconsumed. Ask whether timeout cleanup may stop only processes started
by this operation, never a game or another task's processes. Re-establish current task/process
coordination before any eventual dispatch; do not reuse this point-in-time check as clearance.
Private observations, exact paths and tool hashes are in the ignored Task 3 workspace. Wrapper
and measurement-helper hashes still match the verified `7959996` checkpoint; the 613-test suite
was not rerun. No implementation changed and Task 3 remains incomplete.

Verification: independent read-only review found no blocking documentation issues; its process
wording refinement was applied. Task-state/private-record JSON, paused automation state,
ignored private-record placement, absence of private absolute user paths in these documentation
files, and `git diff --check` passed.

### Overnight continuation approval — 2026-09-24

The user explicitly approved timeout cleanup for processes started by this scan, never a game or
another task's processes. This resolves the runner-authorization pause above; do not ask for that
same exception again. The user then authorized overnight continuation within the original plan,
reserved creative/gameplay decisions, and requested cleanup or an exact list of created copies.
No new source, destination, runtime profile, active-game mutation or gate bypass is inferred.

At approximately 07:01 local time, the installer task remained idle but the randomizer task was
active again. Its latest turn exposed no scope details. A fresh bounded named-process snapshot
was empty; it does not discharge the task-overlap uncertainty. No source file was opened and no
scan was dispatched. The existing 30-minute heartbeat was reactivated with the approved runner-only
timeout exception and unchanged one-dispatch limit. It must pause after dispatch or a substantive
failure/decision barrier; the completion notification, not a polling watcher, handles job results.

A bounded Sol 6 read-only cleanup inventory found 43 files totaling 14,697 bytes in the ignored
Task 3 workspace before adding the new approval/cleanup records. The lead independently matched
the three root records and five result-directory totals. The failed source observations and exact
approval records are retained; historical synthetic-test logs are optional later cleanup, with
negligible storage benefit. No files were deleted and this task has created no game copy. External
destinations were not inspected for this inventory, so this is not a claim about other tasks' files.
The private `.work/task3/CLEANUP.md` lists exact paths, retention decisions and future copy/partial
output bookkeeping; `.work/task3/overnight-authorization-20260924.json` records approval and checks.

The authored scanner hashes remain those of `7959996`; no implementation or support claim changed.
This is coordination and cleanup documentation only. Task 3, copy admission and runtime gates
remain incomplete; the user's overnight instruction does not waive their required verification.

Verification: the independent cleanup/documentation review found no blocking issue; the
lead verified JSON state, ignored private-record placement, active heartbeat with the narrow timeout
exception, both G0 validators, LF/CRLF regression and `git diff --check`. The plan-required full
synthetic host suite, job `fcaffe01-d198-476e-8a3f-a5d7122380d0`, was verified after its completion
notification: **613 passed in 227.66 seconds**, exit 0, empty standard error. The saved command
was `python -X utf8 -m pytest -q`; its wall interval was `2026-09-23T22:06:12.794554Z` through
`22:10:01.426244Z`. Scanner/helper hashes were rechecked unchanged. No new production behavior
was added, so no new RED/GREEN implementation cycle is claimed. At approximately 07:10 local,
the randomizer task was still active and the bounded process snapshot empty; source access
remained deferred. The heartbeat remains responsible for the next coordination check.

### One-shot quiet-window dispatch — 2026-09-24

At approximately 07:33 local time, both related BG tasks were idle and no other active relevant
task was returned in the pinned/recent-task listing. A compact follow-up confirmed the randomizer
turn completed without a reported error. The bounded named game/loader/installer process snapshot
had no matches or unreadable image paths. These are point-in-time coordination observations, not
an exclusive lock, exhaustive handle inventory or guarantee that the source remains quiet.

The wrapper, measurement helper, PowerShell executable and completion-runner hashes matched the
previously recorded identities; PowerShell was 7.6.6 and Python 3.11.9. The one renewed measurement
was dispatched in a fresh PowerShell process with `-WhatIf`, the exact approved source/destination,
output allowance 1,073,741,824 bytes and safety reserve 21,474,836,480 bytes. The runner timeout is
1,800 seconds and its cleanup authority is restricted to its own command tree. Job
`68b549af-51b4-43fb-aea8-ad4225d6bafc` has a new private result directory; no prior job was repeated
or overwritten. The launcher exited 0 and the heartbeat was immediately paused after dispatch.

This records dispatch only: **the measurement result is pending**, not successful or accepted.
Wait for the command's completion notification, then verify status, output and tool identities once.
Do not poll, retry a refusal, create a copy or advance a gate from this launch receipt. The private
approval record and cleanup ledger record the consumed one-shot approval and exact artifacts.
No game launch, app control, game/save/configuration write or copier implementation is authorized
by the dispatch. Task 3 remains incomplete.

Documentation verification: independent Sol 6 read-only review found no blocking issue. The lead
checked task/private JSON, ignored evidence placement, public-path redaction, paused heartbeat,
both G0 validators, LF/CRLF regression and `git diff --check`. No implementation changed; the
613-test result above is the latest full-suite evidence, not a new run or a measurement result.

### Verified quiet-window refusal — 2026-09-24

The completion notification for job `68b549af-51b4-43fb-aea8-ad4225d6bafc` arrived normally.
The lead verified the saved status, command, standard output/error and single accepted notification
submission. The command and allowances exactly matched the approved dispatch. Wrapper, C# helper,
PowerShell executable and completion-runner hashes were rechecked against the private pre-dispatch
record and were unchanged. Authored measurement code remains at checkpoint `7959996`.

- Started `2026-09-23T22:37:56.338036Z`; finished `2026-09-23T22:44:20.789676Z`:
  **384.45 seconds**, `state=failed`, **exit 3**. This was not a timeout.
- Empty standard error; standard output contained one schema-1 refusal, `BGSE_E_PATH_ACCESS`,
  with `writesAuthorized=false`, `runtimeReady=false`, and process/writable-root admission
  `unexecuted`.
- Diagnostic: `phase=inventory`, `pass=1`, `operation=open-content`,
  `failureKind=native-error`, `nativeError=32`.
- No accepted inventory, counts, capacity result or content/identity digest. No game was launched,
  source/save/configuration written, copy created or timeout cleanup invoked by this operation.

Native error 32 is Windows
[`ERROR_SHARING_VIOLATION`](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-),
reconfirmed from Microsoft's documentation. The earlier sharing-contract interpretation remains
applicable, but **this result does not identify a file, owner or the same entry as the prior refusal**.
The earlier report of a running game does not establish this attempt's cause. Idle tasks and an
empty bounded process snapshot before dispatch did not prevent a later sharing refusal; they were
never an exhaustive handle check or continuous exclusion of other activity.

The eight private result files total 1,821 bytes. They and the exact authorization/tool-identity
record are retained in the ignored Task 3 workspace; `.work/task3/CLEANUP.md` records them. No
game copy or partial game destination was created by this task, so there is no game-folder cleanup
to perform. The heartbeat remains **PAUSED**, the one-shot authorization is consumed, and no new
source access, process/handle query, retry, skipped entry or sharing relaxation followed the refusal.

**Evidence:** E1 captured host refusal from pinned authored tooling, not an accepted source
inventory or E3/E4/E5 proof. The prior 613-test E2 result remains unchanged; no implementation or
support claim changed and no new full-suite run is claimed.

**Next decision / barrier:** Stop the source-acquisition path here as required by the one-shot
instruction. Another broad measurement would repeat an unexplained failure. The proposed next
source-specific operation is a separately scoped, private exact-file diagnostic and, where safely
available, read-only holder attribution. It needs direction before source access; no force-closing
handles or processes, log publication, automatic copy or gate advancement. The reviewed host-only
copier packets remain future work, not evidence that acquisition succeeded. Task 3 remains incomplete.

**Verification:** An independent Sol 6 read-only evidence review matched the saved command,
allowances, duration, refusal and notification records against the authorization snapshot, with
no contradiction found. The lead checked task/private JSON, ignored evidence placement,
public-path redaction, paused heartbeat, both G0 validators, LF/CRLF regression and
`git diff --check`. This is a documentation/result checkpoint, not a new implementation or test
suite. No source recheck was performed during verification.

### Later authorization — 2026-09-26

The user subsequently approved the targeted private diagnostic and bounded overnight waiting/
retries for known competing work. See [the new diagnostic checkpoint](private-measurement-diagnostics.md).
That later scope does not alter any failed result above, repeat an old job, identify its holder,
or permit unexplained retries, source writes, game launches or an automatic copy.
