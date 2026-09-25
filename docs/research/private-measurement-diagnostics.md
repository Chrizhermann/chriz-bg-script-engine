# Task 3: opt-in private content-open diagnostics

**Status:** Host-only diagnostic checkpoint verified: 637 full-suite tests passed after reproducing
and correcting a hidden-process encoding defect; independent implementation/correction review passed.
No new real-source observation at this checkpoint.

**Date / owner:** 2026-09-26 / integration lead.

**Question:** Can a separately authorized local diagnostic identify the attempted filename behind
the repeated sharing refusal without changing the default public output or any source guard?

**Environment / versions:** Windows 11 x64 build 26200, PowerShell 7.6.6, CPython 3.11.9,
pytest 8.4.2. Base `6c7cf98`; prior scanner implementation `7959996` with 613 passing host tests.
All new code checks use independently authored temporary fixtures, never game resources.

## Authorization and bounded coordination

On 26 September the user authorized preparing/testing the proposed targeted read-only diagnostic,
continuing overnight, waiting several hours for known competing work, and bounded retries after
that work clears. This supersedes the earlier one-shot-only restriction for **new authorized
attempts**, not the records of the three consumed failed jobs. Old jobs are never repeated or
overwritten. An unexplained blocker is reported instead of retried. Creative/gameplay decisions,
runtime profile choices and G0-G8 gate decisions still belong to the user.

The chosen operational bound is six hours from this authorization, ending at **10:35:13 Asia/Seoul
on 26 September 2026**: at most twelve scheduled coordination checks, thirty minutes apart, and
at most three new source attempts. Known busy coordination consumes waiting time, not a source
attempt; each actual dispatch gets a new private result directory and recorded attempt number.
No failed attempt is retried without evidence of a known conflict that subsequently cleared.
No schedule resets the deadline or counters. Source success stops source retries and does not
admit copying, launching or a runtime gate.

The item-randomiser task requested the machine's game/installer window for its separately approved
isolated tests. The lead explicitly yielded the window, including this task's real-source
inspection. Its private shared reservation uses atomic exclusive file creation and a random
ownership token; its advisory deadline is never permission to steal/delete a peer reservation.
An owner releases only after its game/helper processes stop, verifies its token, and notifies the
peer. This courtesy protocol supplements task/process checks; it is not an enforced filesystem
isolation or proof against unrelated activity. No game path was opened for this coordination.

The peer subsequently reported normal game exit, loader/guard exit 0 and no pending console
request. Its matching-token release receipt was read and the shared lock was absent at that
bounded observation. The peer now plans only offline documentation. This task still has no own
reservation at this host checkpoint: fresh coordination remains required before source dispatch.
A release message is not proof that the whole machine will remain quiet.

A private task-local helper reproduces the agreed courtesy protocol without inspecting its game
path metadata: exclusive creation only; no takeover of expired/malformed/existing reservations;
release requires the same schema/thread/token and explicit confirmation that the owned command
stopped. Reads are bounded and linked/multiply-linked/malformed records refuse. A failed write
retains possible partial evidence, never auto-cleans it. Check-then-unlink assumes cooperating
owners; it does not prevent hostile namespace replacement. The helper and its tests are retained
with private hashes/commands, separate from the tracked scanner and its full regression.

Eleven CLI test methods were written before the helper. The worker's first run recorded ten
failures, then corrected a vacuous negative assertion; the lead reran that corrected test file
before implementation and observed fifteen assertion/subtest failures in 0.903 seconds, still
caused by the absent helper. After implementation, independent review caught an unhandled deep
JSON nesting error; a new CLI test reproduced exit 1 instead of a clean refusal before correction.
The specific exception is now caught without changing ownership or deletion rules. The final
temporary-only checks passed **11 CLI tests in 3.360 seconds** and **7 supplementary/fault tests
in 0.168 seconds**, no skips. These include concurrent acquisition, ownership/confirmation
mismatches, expiry, malformed/oversized/duplicate/deep records, links, directories and flush failure.
No real reservation was acquired by these tests. Final independent static review verified the
corrected helper hash and accepted the helper/tests with no remaining blocking findings; it ran
no tests or real-lock/source/process queries. The full scanner regression is now verified below;
fresh coordination is still a separate prerequisite.

Exact approved roots, deadlines/counters, shared lock path and peer observations are in ignored
`.work/task3/overnight-authorization-20260926.json`. The existing heartbeat is reused, not duplicated;
it stays paused during preparation or a dispatched command and never polls that command's files.
The completion-wakeup workflow reports command termination for independent result verification.

## Narrow implementation contract

The existing command gains explicit `-IncludePrivateFailurePath`. Without it, the C# measurement
receives no collector and the PowerShell output retains its existing sanitized schema. With it,
each wrapper invocation creates a private collector and uses the same measurement core and native
opens. No path, raw exception, holder identity or caller-owned object is added to public exceptions.

Only this exact refusal may add the private object: `BGSE_E_PATH_ACCESS`, `phase=inventory`,
`pass=1` or `2`, `operation=open-content`, `failureKind=native-error`, `nativeError=32`.
The collector captures the requested name at the failed native content open, then rethrows the
same refusal. It is reset before every opt-in call; it is caller-owned, not global, and concurrent
calls require separate collectors. Missing files, metadata-open failures, markers, alias checks,
other errors and successful measurements do not produce a private path.

The optional object contains exactly:

```json
{
  "classification": "private-local-only",
  "attemptedPath": "<exact attempted absolute path>",
  "pathIdentity": "unverified-at-failed-open",
  "holderAttribution": "unexecuted"
}
```

The path is an attempted name, **not** proof of the successfully opened physical identity or of
the conflicting holder. There is no holder enumeration, automatic retry, skipped entry, relaxed
sharing, forced handle closure, process termination, file creation or copy in this diagnostic.
The readiness-marker, alias, stream, hard-link and source-change refusals remain unchanged.
`-WhatIf` does not select a weaker path; either mode is read-only.

**Privacy:** opted-in stdout is private and may contain a personal path. Capture it only in a new
ignored task-owned result directory outside source/destination/protected roots; never commit,
publish or paste the raw log into a public research memo. The wrapper does not create its own log
or guarantee privacy of an arbitrary caller's output destination. Default output remains redacted.

JSON output escapes non-ASCII characters, including private filenames. This preserves their exact
decoded values even when a hidden Windows process inherits a legacy output writer; it does not
change a shared console code page, another app's encoding, or the output's privacy classification.

## TDD, reproduction and review

A bounded Sol 6 worker owned only `test_measurement_private_diagnostics.py`. Before implementation,
all ten new cases failed in 14.12 seconds because the switch was absent (fresh-process parameter
binding error). The lead implemented the shared-core/collector boundary; the worker then observed
**10 passed in 19.57 seconds**. These prove exact nested Unicode/bracket filename reporting for a
held synthetic writer, unchanged default diagnostics, success/other-refusal omission, unchanged
fixtures and both `-WhatIf` forms. The lead corrected the test specification to exclude only the
volatile free-space observation from cross-run equality and require adequate capacity separately.

The lead added direct C# collector-reuse/exception-privacy and production-wrapper malformed-value
checks in `test_private_diagnostic_boundary.py`. These are supplementary boundary regressions,
not claimed as pre-implementation RED evidence or real-game proof. Malformed-input test doubles
exercise the actual wrapper publication branch; they are not a hostile-process security boundary.
The command covering this file and both existing diagnostic files passed **41 tests in 52.34
seconds**, exit 0. Together with the worker's separate ten-case run this is 51 focused passes,
not a claim that the combined reproduction command below was executed as one invocation.

Independent lead-model static review found no blocking issue in the shared core, collector,
wrapper, two test files or privacy/coordination contract. The reviewer did not run tests or inspect
any game. The lead checked the worker's tests/results and applied the review's status-wording
correction: the full suite was still pending at that earlier review, not a passed result.

The first full host run, job `97738395-ce37-4377-a070-803104b770db`, **failed**: exit 1,
**2 failed, 631 passed, 2 warnings in 251.98 seconds**, empty stderr, no timeout. Its completion
notification was verified, including unchanged wrapper/helper hashes. Both failing cases were
the exact Unicode filename assertion, with and without `-WhatIf`: hidden-process stdout used
legacy bytes, causing the Python UTF-8 reader to fail before parsing JSON. The original focused
foreground passes did not prove hidden-process encoding. Retain this failed job; never rerun it.
Both G0 validators and the LF/CRLF regression had passed before dispatch, as had JSON/privacy
and diff checks. Those successes do not override the failed full suite.

The lead reproduced the defect with four new cases in `test_private_diagnostic_encoding.py`:
CP437/CP949 managed output writers, each with/without `-WhatIf`, a held synthetic writer and a
filename containing accented Latin, Korean, emoji and brackets. All **4 failed in 6.15 seconds**
before correction because the raw JSON bytes were not ASCII; lossy encoding also changed names.
The test changes only its fresh hidden child's managed writer, not a console code page or another
process. A one-line `ConvertTo-Json -EscapeHandling EscapeNonAscii` correction preserves the exact
JSON value. The new cases plus the original private-diagnostic file then passed **14 tests in
25.26 seconds**, exit 0. The raw-byte, exact decoded-name, refusal and unchanged-fixture assertions
were retained. The fresh full run below then tested this changed code.

Independent static review of the encoding correction and regression found no blocking issue:
escaping changes JSON representation, not the decoded path, default ASCII fields or native
source guards. The reviewer inspected the test coverage and official host API documentation;
they did not run tests, inspect processes, or access a game. Both G0 validators and the LF/CRLF
regression passed again after the correction.

The corrected full suite, job `bf63cfcc-84c7-4269-973e-894b994cf99f`, was independently verified
after its completion notification: **exit 0, 637 passed in 238.43 seconds**, empty stderr, no
timeout or warnings. It ran from 19:59:12 to 20:03:11 UTC on 25 September (26 September locally).
The command/executable identity and raw wrapper/helper hashes matched the recorded dispatch.
The single completion notification was accepted. This tests changed code and four new regressions,
not a rerun of the failed job. Both result directories are retained privately; the successful one
contains eight files totaling 1,969 bytes. No source attempt was dispatched by this host checkpoint.

PowerShell's documented `EscapeNonAscii` setting escapes non-ASCII and control characters and
has existed since PowerShell 6.2, within the command's required 7.4-to-before-8 host range:
[ConvertTo-Json documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-7.6).
This is documentation input for API availability, not proof of testing every supported host version.

```powershell
python -X utf8 -m pytest -q tests/tooling/test_private_diagnostic_encoding.py tests/tooling/test_measurement_private_diagnostics.py
python -X utf8 -m pytest -q tests/tooling/test_private_diagnostic_boundary.py tests/tooling/test_measurement_diagnostics.py tests/tooling/test_measurement_diagnostics_faults.py
python -X utf8 -m pytest -q
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File scripts/test-g0-line-endings.ps1
git diff --check
```

**Evidence / residual uncertainty:** E2 synthetic behavior only. The attempted-name field cannot
identify a holder or establish that repeated failures involve the same file. Peer-task activity
and process snapshots are bounded coordination observations, not continuous exclusion. The
existing source-sharing failures remain unresolved until a separately recorded real observation.
No E3/E4/E5, accepted source inventory, copy admission or gate pass is claimed.

**Next decision:** The host checks and independent review passed. Recheck task/process coordination,
acquire the reviewed cooperative reservation and record its ownership before source use. If the diagnostic encounters an
unexplained blocker, retain its private evidence and notify the user without retry. Real copying
still requires every reviewed offline-acquisition packet; Task 3 remains in progress.

## Post-checkpoint coordination: no dispatch

After host checkpoint `66a2282`, compact task status showed both named BG tasks idle and no other
active BG task in the returned recent inventory. A bounded read-only OS snapshot found no named
game/loader/installer candidate or exact-root command match other than the observing filter itself.
Follow-up classification identified six background shell sessions owned by the other assistant
app; their command lines expose no task or script scope. A bounded parent/child check found no
children, but that cannot prove an in-process script is idle or unrelated to the game roots.

These sessions are **not proven to hold or block a game file**. Their unresolved task scope is a
coordination uncertainty, not a new scanner failure or an accepted quiet window. Under the user's
unknown-owner/scope rule, no source measurement or reservation acquisition was dispatched. Source
attempt count remains zero under the renewed authorization. The heartbeat remains paused pending
user direction; there is no repeated polling, game/app control, process termination or new copy.
Exact observations, process identities and tool hashes are private. The original deadline/counters
are not reset; any later cleared attempt still needs fresh checks and the exclusive reservation.
