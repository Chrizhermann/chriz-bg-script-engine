# Task 3, packet A4c: bounded process-ID enumeration

**Status:** Independently reviewed implementation and full host regression verified: 1,097 tests
passed. Accepted only for bounded numeric enumeration, not complete provider or copy admission.

**Date / owner:** 2026-09-27 / integration lead.

**Question:** Can the native provider retain every PID returned by a bounded OS enumeration,
reject possible truncation and preserve opaque entries without declaring a quiet window?

## Scope and evidence

[A4b](acquisition-process-identity-contract.md) is verified at `4c0409d` with 1,076 passing host
tests. It observes one explicitly supplied process; it does not discover processes. This packet
adds only the numeric enumeration envelope, not command lines, per-process identity enrichment,
coordination, unknown-process exemptions or the full acquisition admission operation.

Microsoft documents `EnumProcesses` input/output sizes in bytes. A returned count equal to the
buffer capacity can hide truncation; success alone does not establish a full list. On Windows 7
and later, `K32EnumProcesses` is exported by kernel32. These are E0 documentation inputs.
[API reference](https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-enumprocesses)

The official sample skips PID zero and opens other processes for their names. Neither behavior
is adopted here: every reported PID is retained, and this helper obtains no process handle.
The sample also acknowledges access failures; a later enrichment failure must remain visible.
[Sample and limitations](https://learn.microsoft.com/en-us/windows/win32/psapi/enumerating-all-processes)

Local Windows SDK 10.0.26100.0 `um/psapi.h`, SHA-256
`4166FBCE43622F469AA46CD1CEA27A73171353DF8101643C2E850124622D5EF9`, lines 119 and
131-137 define the K32 alias and BOOL/DWORD-pointer/byte-capacity/output-DWORD declaration.
This is E1 pinned declaration evidence, not native execution or atomic-snapshot proof.

## Reviewed boundary

`NativeProcessEnumeration.Observe()` supports Windows x64 only and performs exactly one
`K32EnumProcesses` call. It allocates 16,385 DWORD slots (65,540 bytes), with a maximum accepted
16,384 entries. The extra slot allows the exact accepted maximum without accepting a full buffer.
Marshal the BOOL return explicitly; set `ExactSpelling` and `SetLastError`, capturing the saved
native error immediately on false return. Missing entry points/DLLs must be sanitized as query
failures, never printed with environment details.
There is no resize, retry, secondary enumeration, privilege adjustment, process open, image/name/
command retrieval, file operation or child process. The test harness's own compiler process is
separate from the helper's no-child contract.

- Refuse unsupported platform before calling the backend.
- Native failure produces fixed `BGSE_E_PROCESS_ENUMERATION_QUERY`, fixed operation/kind and
  numeric Win32 error only. Unexpected managed failures are sanitized without inner exceptions.
- A zero, non-DWORD-aligned or beyond-capacity byte count is `..._DATA`. A full buffer is
  `..._LIMIT`, never a usable truncated prefix. A null internal test backend is `..._INPUT`.
- Copy only the reported prefix; reject duplicate IDs with `..._DATA`, including repeated zero.
  Sort ascending. Preserve a single zero and all other uint values; do not invent reserved-ID,
  process-name or service exemptions. Do not silently deduplicate, discard or repair rows.
- Return immutable `ProcessIdEnumeration`: `ObserverVersion = "BGSE-PROCESS-ENUMERATION-1"`,
  defensive `Pids` array, UTC `StartedUtc` / `FinishedUtc` and monotonic `ElapsedMilliseconds`.
  No public constructor, mutable setter, raw handle, complete/safe/ready flag or admission token.
  Clone arrays at construction and retrieval. Wall-clock ordering is not an acceptance check.
- Internal `IProcessEnumerationApi.Read(uint[] buffer, uint capacityBytes)` returns bytes written;
  `ObserveWith(api)` is the same workflow used by public `Observe` after its platform guard.
  Test fakes compile in the same assembly. Public callers cannot inject a backend.

This is a bounded response to one OS call, not an atomic snapshot of every process alive during
an interval. Processes can start or exit and PIDs can be reused. A nonfull buffer says nothing
about activity that starts later, open files, inaccessible identity/command data or task ownership.
Fixed allocation/call count is not a hard deadline for a kernel call. No cancellation thread or
disposal race is introduced; operation-level timeouts remain separate.

## Test-first plan and barriers

Start with a missing-helper RED. The native smoke test may obtain numeric system-wide PIDs only;
it must not open another process or print the list. Assert inclusion of the harness's own PID,
sorted uniqueness, accepted count, UTC/timing shape and defensive result data. This is a real
host OS observation, not a deterministic process-count fixture or game/runtime test.

Use in-assembly fakes for empty/misaligned/full/oversized responses, duplicate IDs, preserved zero,
exact maximum size, unused-tail exclusion, sorting, defensive buffer/getter copies, single-call
failure and sanitized exception behavior. Simulated unsupported platform must fail before any
backend call. No fault test should enumerate real processes or try to force system-wide churn.

Record exact commands, tools/native DLL/header fingerprints, RED/GREEN outcomes and any worker
corrections. Run focused and full host tests, G0 validations and independent code/result reviews
before a narrow commit. Keep raw PIDs private and do not infer permission to inspect their images,
commands or files from enumeration success.

Later integration must account for every returned PID, including zero and failed/opaque rows,
correlate identities and command provenance, bind the current observer and fresh coordination,
and recheck at the required operation boundaries. Do not pass this PID list directly to A4a as
`enumerationComplete = true`. No unknown row is automatically unrelated. Source retries remain
stopped; no source/game access, copy, runtime profile choice or gate advancement is authorized here.

**Counterevidence / residual uncertainty:** API buffer sufficiency is not atomicity, permanent
liveness or whole-provider coverage. Protected/opaque rows and command provenance remain open.
**Review / TDD:** Independent read-only review accepted this bounded schema without a blocker,
confirmed the SDK header hash/declarations and reinforced no filtering, defensive ownership,
native-error privacy and honest system-wide numeric-ID scope. The first native-smoke test failed
because `NativeProcessEnumeration.cs` did not yet exist: **1 failed in 1.73 seconds**. No native
enumeration occurred in that RED. A separate bounded worker owns only fake-backend tests after
schema freeze; the lead owns implementation, native execution and integration judgment.

**Next decision:** integrate and verify fault coverage, then the full host regression; preserve all
later barriers.

## Executed checkpoint

The implemented helper passed the same native smoke test: **1 passed in 1.98 seconds**. It
performed one system-wide numeric-ID enumeration; the test checked own-harness membership,
accepted size, strictly sorted uniqueness, result immutability, scalar surface and UTC/monotonic
timing. The test emitted booleans and schema labels only, not process IDs, names or command lines.
No process was opened, no image/command was requested and no game file or directory was accessed.
This is bounded native host smoke evidence, not a deterministic system snapshot or engine proof.

Environment: Windows x64 10.0.26200.0, PowerShell 7.6.6, Python 3.11.9, pytest 8.4.2. Native
kernel32 version/hash remain those independently verified in A4b above; the selected entry point
is the kernel32 K32 export, not the psapi wrapper. Exact tool/native/header identities are saved
privately with the checkpoint. Both G0 validators and the LF/CRLF regression passed unchanged.

Independent static implementation review found no blocker in platform ordering, ABI, saved-error
capture, byte-count validation, defensive copies, duplicate handling, one-call/no-enrichment scope
or exception privacy. Its test-surface suggestion renamed the property list accurately and added
an explicit zero-public-fields assertion; no implementation change was needed. Static review is
not execution of the remaining fault branches.

The Sol 6 worker authored only the fake-backend file after schema freeze, reused the reviewed
public test bridge to reach an internal fake, and explicitly initialized fields. The lead read
the entire file before running it. The first combined run passed **19 tests in 38.29 seconds**;
there were no harness failures or implementation corrections. The worker did not run native tests.

Independent test review found an important masked branch: both oversized byte counts were also
misaligned, so they did not independently test the upper bound. The lead added aligned 65,544
to isolate that guard, a direct same-assembly constructor/input-mutation check, and exact fixed
diagnostic assertions. No production code or safety assertion was relaxed. The final strengthened
run supersedes the earlier 19-case result when verified below.

Platform-shadow tests prove the current refusal outcome, not an instrumented zero-native-call
counter. Before-query ordering is separately verified by static review of the current binding
and public call sequence. Actual native Win32 error-number propagation is also static evidence;
managed, missing-DLL and missing-entry exceptions are simulated. These distinctions remain open
for any stronger later operational claim.

The final strengthened run passed **21 tests in 32.88 seconds**, exit 0. Independent review
accepted all three corrections with no remaining static blocker. No code/test bytes changed
after this run. Full collection finds **1,097 tests** (1,076 prior + 21 new) in 0.20 seconds;
collection is not execution. After JSON/link/privacy/whitespace checks and verification of all
seven saved helper/test/dependency/tool hashes, both native DLLs and the SDK header, the full
suite was dispatched once through the completion-wakeup runner in fresh
`work/process-enumeration-tests-v1` under private Task 3 records, timeout 1,800 seconds,
launcher exit 0. No polling, watcher, rerun or overwrite occurred.

The saved completion result reported **succeeded, exit 0; 1,097 passed in 843.55 seconds**
(14:03), with empty stderr/runner log, no warnings/skips and no timeout. The status interval was
16:41:32.865477 to 16:55:37.901567 UTC on 26 September, 845.036090 seconds. Eight result files
total 2,553 bytes; exactly one completion notification was accepted. The exact command was
`python -X utf8 -m pytest -q` in this worktree with a 1,800-second timeout.

The lead matched all seven saved helper/test/dependency/tool hashes, both native DLLs and the
SDK header. Independent Sol 6 result audit matched command/cwd, count (1,076 + 21), status/exit,
timing, single notification and all seven hashes; all relevant modification times preceded
dispatch. It independently checked that the native path enumerates numeric IDs only and that
fault fixtures use the internal fake. No code or test bytes changed after the verified run.
This completes A4c only; all opaque-row, command-provenance and operation-admission barriers remain.

Authored helper SHA-256:
`8AB59038D7154BCC2B52142117DF55406A2F08DC7459DAEDD6D26550B6D8B0E3`.
E0 documents/E1 SDK and authored-code inspection support the binding; E2 synthetic assertions
prove the tested workflow branches. The native numeric-ID smoke is bounded host integration,
not a deterministic assertion about system population and not E3/E4/E5 game evidence.

Focused reproduction:

```text
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_process_enumeration.py archive/2026-10-process/tests/tooling/test_process_enumeration_faults.py
```

Full regression uses `python -X utf8 -m pytest -q`, only after focused tests and independent
review. No accepted enumeration will authorize skipping opaque rows or begin real acquisition.
