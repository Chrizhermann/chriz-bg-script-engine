# Task 3, packet A4b: same-handle process identity

**Status:** Reviewed narrowed identity implementation and full host regression verified:
1,076 tests passed. Accepted only for one-process identity; no whole-provider or copy admission.

**Date / owner:** 2026-09-27 / integration lead.

**Question:** Can a bounded read-only probe bind PID, raw creation time and image spelling to
one continuously held process object, without a PID-only join or invented command-line facts?

## Scope and primary-source findings

[A4a](acquisition-process-screening-contract.md) is verified at `9ef63b0` with 1,017 host tests.
It accepts supplied facts, not Windows observations. This next subpacket proves only identity
observation for one explicitly supplied PID. It does not enumerate processes, obtain command
lines, infer a process name, exempt the current observer, inspect open files, or admit activity
as unrelated. Tests will query only their own fresh harness process; no game/other app is queried.
No process is launched or stopped by the helper, and it cannot mutate a process or filesystem.

Official Microsoft documentation inspected on this date provides E0 inputs:

- Process handles remain valid until closed, including after exit; PID validity is only for
  the process lifetime. Therefore, use one owned handle and verify liveness, not repeated
  PID-based queries assembled into a supposed instance.
  [Handles and identifiers](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers)
- `OpenProcess` supports explicit access and noninheritance; PID zero cannot be opened and
  System/CSRSS access can be denied. Denial is not evidence of no relevant activity.
  [OpenProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess)
- `GetProcessId` and `GetProcessTimes` accept query-limited handles. Creation time is returned
  as FILETIME; exit time is undefined for a live process and must not be used as a zero check.
  [PID](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocessid),
  [Times](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes)
- `QueryFullProcessImageNameW(handle, 0, ...)` requests a Win32-form image name. Buffer capacity
  is in characters; successful length excludes the terminating NUL. A name is not a physical
  executable-file identity or proof that a file is unchanged.
  [Image query](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-queryfullprocessimagenamew)
- `WaitForSingleObject(handle, 0)` returns immediately; it needs SYNCHRONIZE rights. A process
  object is signaled on termination. Only the nonsignaled return permits the next observation;
  do not equate `GetExitCodeProcess == STILL_ACTIVE` with identity/liveness proof.
  [Wait](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject),
  [Process lifetime](https://learn.microsoft.com/en-us/windows/win32/procthread/terminating-a-process)

Why command-line/enumeration support is not silently added:

- `EnumProcesses` reports bytes returned, but a full buffer can mean truncation. A later
  bounded provider must refuse full/over-limit output and account for every returned PID,
  including opaque PID zero; a skipped row cannot become a complete empty snapshot.
  [Enumeration](https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-enumprocesses)
- WMI exposes command lines and creation dates, but CIM timestamps have microsecond fields
  whereas FILETIME represents 100-nanosecond units. **Inference:** converting/rounding such
  timestamps or matching a PID alone is not exact-instance proof; no provider caching or
  race-free join guarantee has been established here.
  [Win32_Process](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process),
  [CIM datetime](https://learn.microsoft.com/en-us/windows/win32/wmisdk/cim-datetime)
- The documented `NtQueryInformationProcess` page warns about internal API changes and does
  not specify the command-line class 60 contract. That path is not selected by this subpacket;
  a separate pinned ABI/access/error/correlation review would be necessary. No PEB traversal,
  remote-memory reads, debug privilege or undocumented fallback is introduced.
  [Native query caveat](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationprocess)

## Reviewed typed boundary and sequencing

`NativeProcessIdentity.Observe(uint pid, ulong? expectedCreationFileTime)` returns a private,
immutable `ProcessIdentityObservation` containing `Pid`, `CreationFileTime`, `ImagePath`,
`StartedUtc`, `FinishedUtc`, `ElapsedMilliseconds` and fixed
`ObserverVersion = "BGSE-PROCESS-IDENTITY-1"`. PID zero or an explicitly supplied zero
expected creation is invalid input. Null expected creation means discover the currently opened
instance, not assert ownership. A nonnull expected value must exactly match raw observed FILETIME.
No public constructor/setter for observations, no raw handle, no command/name field and no
conversion into a supposedly complete `ProcessFact`. No ready/safe/clear or authorization flag.

The initial native target is Windows x64. The helper must:

1. Validate input and supported platform before opening anything. Start UTC/monotonic timing.
2. Open exactly one noninheritable process handle with
   `PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE` (`0x00101000`). No privilege adjustment,
   VM read/write, duplication, injection, suspension, termination or broader-rights fallback.
3. With that same private owned handle: require a zero-duration wait to return WAIT_TIMEOUT;
   obtain nonzero matching PID and nonzero creation FILETIME; verify expected creation if given;
   query the complete Win32 image spelling. Never reopen a PID to fill a missing field.
4. Read PID/creation/image again through that same handle, require exact unchanged scalar values
   (ordinal image spelling), then require another zero-duration nonsignaled check. A process may
   exit immediately afterward; this is interval-bound observation, not an ongoing liveness lease.
5. Each image call uses a fixed 32,767-character buffer; success requires a reported length
   1..32,766, a terminator at that index, no earlier NUL and valid UTF-16. Initialize the buffer
   with a non-NUL sentinel so a missing terminator is observable. No truncation, dynamic growth
   or native retries. Preserve the returned spelling; do not call path resolution, inspect the
   executable file, infer aliases or assert canonical filesystem identity.
6. Return only after every check. Close the owned handle on success and every refusal/exception;
   keep the handle implementation private. UTC values are audit context; monotonic elapsed time
   measures duration. Clock changes do not grant freshness or reusability.

This bounds allocations and native-call count, **not** execution time of a stuck kernel call.
All waits use zero duration; no indefinite wait, timer thread or child watchdog is created.
Later whole-provider budgets and the approved external runner remain separate requirements.
Do not abandon an in-flight call while disposing resources it may still use.

Refusals contain fixed codes only, with fixed operation/kind and numeric native error where
applicable; no raw image, PID, command, exception text or inner exception. Codes:
`BGSE_E_PROCESS_IDENTITY_INPUT`, `..._PLATFORM`, `..._QUERY`, `..._DATA`, `..._CHANGED`, `..._EXITED`.
An open/query failure is unresolved observation, never an empty fact or proof the process exited.
The later provider must preserve that failure against its enumerated PID; this probe cannot
authorize silently skipping a row. Missing entry points/platform mismatches fail closed.

## Required evidence and remaining barriers

After independent schema review, begin with a genuine missing-helper RED for the current test
process. Prove same PID, positive exact creation compared with an independent current-process
observation, unchanged complete executable spelling, scalar immutability and released handles.
Exercise expected-creation mismatch with the actual self process. Inject synthetic native-boundary
failures at each acquisition/query/recheck/cleanup stage and assert order, minimal access,
noninheritance, no reopening, no partial result and owned-handle cleanup. Cover malformed length,
terminator, NUL/UTF-16, zero/mismatched identities, signaled/failed/unknown waits and image changes.
Keep scalar/fake-call faults distinct from real Windows races or native failure injection.

The initial proof does not require launching a second process to force exit. In particular,
do not inspect or terminate a game or unrelated process to obtain a refusal case. Self-process
native success and fake-call lifecycle tests do not prove PID reuse, denial, cross-bitness,
protected-process behavior, hostile image mutation or an exhaustive system snapshot.

Test seam: internal `IProcessIdentityApi.Open(pid, access, inherit)` returns one internal
`IProcessIdentitySession : IDisposable` with `GetPid()`, `GetCreationFileTime()`,
`ReadImage(char[] buffer)` returning length, and `Poll()` returning the wait result. Internal
`ObserveWith(pid, expectedCreation, api)` runs the same workflow as public `Observe`, which
always selects the native implementation after platform validation. Native failures are
sanitized at their source; unexpected managed backend/cleanup failures receive fixed query
refusals. Test-only fakes compile in the same assembly, not a public injected provider. They
record order/handle ownership and can fail cleanup; no result may escape a cleanup failure.

**Review / TDD start:** Independent review accepted the narrower same-handle scope, exact raw
creation semantics, zero-wait liveness, explicit buffer rules and incomplete-provider boundary.
It reinforced that live exit FILETIME is undefined and fixed call counts are not hard deadlines.
The initial own-harness-process test failed before the helper existed: 1 failed in 1.10 seconds.
No native A4b query occurred in that RED. The test harness will compare with the separate .NET
current-process start-time accessor and executable-path property; that is a cross-check, not
independent evidence that the operating system itself is correct.

## Executed evidence and reproducibility

The first implemented self-test failed once (1 failed in 2.04 seconds): the independent .NET
executable property retained the launch spelling `pwsh.EXE`, while the native API returned
`pwsh.exe`. The lead reproduced this using the same test harness and found case-insensitive
ordinal equality. Only that cross-accessor test now uses ordinal-ignore-case comparison;
production still requires exact ordinal equality between its two same-handle image reads.
The original test then passed in 1.68 seconds. No game or unrelated process was observed.

Seven primary tests passed in 12.52 seconds: native self PID/creation/image cross-checks,
immutable bounded result surface, null/zero expected-creation behavior, actual self-instance
expected-creation mismatch, and handle release after success/refusal. Handle checks warm the
exact paths, repeat 32 observations/refusals and compare current-process handle counts using
the current-process pseudo handle only; no process enumeration occurs.
[Handle-count API](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesshandlecount)

Independent review found a real support-boundary defect: Windows plus 64-bit pointers also
admits ARM64, whereas this contract allows only x64. A test-only same-assembly platform accessor
reported ARM64 on the actual x64 host. Before the fix, the public path returned a self-process
observation instead of refusing (1 failed in 2.50 seconds). Requiring explicit process
architecture X64 corrected the same regression (1 passed in 1.32 seconds). This is synthetic
platform-boundary proof, not an actual ARM64 run. The native-query workflow is unchanged.

A Sol 6 worker independently extracted installed SDK 10.0.26100.0 declarations for the six
native functions and the two access constants. The lead reread those declarations and matched
all five header hashes. FILETIME uses low/high DWORD fields, not a cast of an unaligned pointer;
the helper checks its marshaled size/offset and combines raw fields arithmetically.
[FILETIME](https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime)

| SDK header under `um/` | SHA-256 |
|---|---|
| `processthreadsapi.h` | `436AE4CBB017D1CDB381AAF2119A3F89B04BAE257FD4C881EF251DAA02533540` |
| `winbase.h` | `EC538199F5EBE8CEC2DFD4F1BA48316EF776C82D37277AED3A677965E494F192` |
| `synchapi.h` | `D962588974E5E100205F683160B351DEE70EA100AA736E14D878B7A74577A9C5` |
| `handleapi.h` | `C967FDF1A98E4CE8D501DAE26B905F6452173B2BE1C25E6AA2E5EEAE415369CC` |
| `winnt.h` | `8693F0AD4ADA355C912D40CA41CE929B480E92291BDA2F9227ACF56736BFFBFF` |

Environment remains Windows x64 `10.0.26200.0`, PowerShell 7.6.6, Python 3.11.9, pytest 8.4.2.
`kernel32.dll` and `KernelBase.dll` both report file version `10.0.26100.9278`;
SHA-256 respectively `8F8629741558B5DF71DEF4E1DD8EF9645D4F806B949762C47757C50FEA1A9E6D`
and `BECAD014FB8EFA8CB5E314931CCA92778AD42C649B12A6909632CACD68AF4F40`.
SDK declarations/binary identities are E1, not a claim that every native failure was reproduced.

Reproduce the focused checks with:

```text
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_process_identity.py archive/2026-10-process/tests/tooling/test_process_identity_faults.py
```

The full host suite remains mandatory before a narrow implementation commit. Record its exact
command, saved stdout/stderr/status and fingerprints privately. Self-process observations are
E2 host evidence; injected session failures are E2 workflow simulations, not OS race/denial
experiments. No runtime/game evidence or full-provider completeness is claimed.

The delegated 51-case fault suite exposed two test-harness issues before exercising its intended
branches. The first run failed 51/51 in 73.74 seconds because `Add-Type` rejected uninitialized
fake fields (CS0649). Explicit test-field initializers fixed that compilation problem. The second
run passed one and failed 50 in 77.28 seconds because PowerShell could not resolve the internal
fake class by type name. After the agreed single correction, the worker stopped and handed back
the diagnosis. The lead added a test-only public bridge factory returning the internal fake as
an object; production accessibility/interfaces were not widened. The formerly blocked success
case then passed in 1.64 seconds. The combined primary/fault run of the final bytes then passed
**59 tests in 86.49 seconds**, exit 0. No implementation/test bytes changed afterward.

Final independent static review accepted the x64 guard, native marshalling and same-handle
workflow. It checked both image/wait checkpoints, exact failure-stage ordering, zero/changed
identities, consistent valid-max/surrogate success fixtures and cleanup failure. The lead also
read the full worker file; the passing privacy assertions found no private canary in refusals. Static
review did not certify either failed worker run as functional proof. Collection currently finds
1,076 cases (1,017 prior plus 59 new) in 0.30 seconds; collection is not test execution.
Both G0 validators and the LF/CRLF regression passed unchanged. The related existing native
capacity guard was inspected and already requires X64 explicitly; it needed no correction.
Final independent review also accepted the test-only factory correction: production visibility
and fault assertions stayed unchanged. No static blocker remains for the full regression run.
JSON/link/privacy/whitespace checks and final review passed; all seven saved helper/test,
dependency and tool fingerprints matched before dispatch. The full suite was dispatched once
in fresh `work/process-identity-tests-v1` under Task 3 private records, timeout 1,800 seconds,
launcher exit 0. The hidden completion runner preserves results and submits its own single
completion message. No polling, watcher, rerun or overwrite occurred.

On completion, the saved status reported **succeeded, exit 0; 1,076 passed in 826.31 seconds**
(13:46), with empty stderr, no warnings/skips or timeout. The status interval was
16:12:16.754218 to 16:26:03.893133 UTC on 26 September, 827.138915 seconds. Eight result files
total 2,468 bytes; exactly one completion notification was accepted. The command was
`python -X utf8 -m pytest -q` in this worktree with a 1,800-second timeout.

The lead checked the saved result and all seven recorded helper/test/dependency/tool hashes,
both native DLL hashes/versions and all five SDK header hashes. An independent Sol 6 audit
matched the saved command, count (1,017 + 59), status/exit/timing, single notification and all
seven hashes; code/test modification times preceded dispatch. The audit confirmed that native
queries target only each harness's own PID and the fault suite injects in-assembly fakes.
No implementation/test bytes changed after dispatch. This completes only the A4b host checkpoint.

Authored helper SHA-256 before full dispatch:
`C71204A41157F99CD6B26B6B71165A9B90792E3909F9A4726747288B21921C96`.

Full enumeration/opaque records, bound command-line provenance, instance correlation across all
providers, current-observer identity, fresh task coordination, approved operation/root binding,
repeat checks before writes/publication and operation-level `-WhatIf` remain open. The user has
not approved a name-based system/service exemption. All copier B-E/runtime and G1 barriers remain.

**Evidence / counterevidence / next decision:** E0 official API documentation, E1 pinned local
declarations/binaries and E2 bounded self-process/synthetic checks only. The need to account for
unopenable and opaque rows is a real limitation, not a reason to weaken unknown handling. Freeze
the verified evidence in a narrow commit, then separately resolve the remaining native
provider/command/coordination contract. This probe cannot declare a quiet window or permit copying.
