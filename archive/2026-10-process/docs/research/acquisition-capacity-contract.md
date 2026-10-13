# Task 3, packet A2: pure multi-volume capacity accounting

**Status:** A2 verified: independent review and 787 full-suite host tests passed. Not a native capacity
provider, complete packet A, copy admission or runtime evidence.

**Date / owner:** 2026-09-26 / integration lead.

**Question:** Does deterministic accounting include every supplied allocation, both independent
copies and evidence output, without spending the same volume's free space more than once?

## Scope and frozen interface

The already reviewed [operation contract](offline-acquisition-acceptance.md) requires per-volume
capacity before any write. This subpacket implements arithmetic only, alongside the accepted
[A1 footprint](acquisition-footprint-contract.md) at `788c3c4`. It takes no filesystem paths,
observes no disks/processes and creates no files or child processes. It selects no lab profile,
baseline destination, gameplay rule or new user allowance.

`archive/2026-10-process/scripts/lib/AcquisitionCapacity.cs` defines immutable scalar records and a pure calculator:

- `CapacityVolume(volumeId, allocationUnitBytes, availableBytes, safetyReserveBytes)`;
  the numeric constructor arguments are nullable unsigned 64-bit values so unknown is not zero.
- `CapacityAllocation(volumeId, purpose, fileByteLimits, directoryCount, extraAllowanceBytes)`;
  byte limits are a defensively copied nullable-UInt64 array; directory count and allowance are
  nullable UInt64. `purpose` is exactly `working-copy`, `future-baseline` or `evidence`.
- `AcquisitionCapacity.Calculate(CapacityVolume[] volumes, CapacityAllocation[] allocations)`
  returns a defensive array of immutable `VolumeBudget` records, sorted by ordinal `VolumeId`.
- Each result has `VolumeId`, `AllocationUnitBytes`, `WorkingCopyBytes`, `FutureBaselineBytes`,
  `EvidenceBytes`, `SafetyReserveBytes`, `RequiredBytes`, `AvailableBytes` and `RemainingBytes`.
  There is no `safe`, `admitted`, `writesAuthorized` or runtime-ready result.

This is an in-process typed interface, **not** a JSON/user-input parser or trusted source of
disk observations. The caller must not turn absent data into zero before constructing inputs.
Output records carry private volume keys and must not be dumped as public operation stdout.

## Exact rules and arithmetic

1. Exactly one allocation of each of the three purposes is required, including an empty-file
   tree. Reject missing/duplicate/unknown purposes, null arrays/elements and more than three
   volume observations. Every observation must be referenced; every allocation must have one
   observation. Reject duplicate volume keys. Shared-volume allocations are accumulated.
2. Volume keys are bounded canonical tokens matching `[A-Z0-9][A-Z0-9_-]{0,127}` exactly.
   Case variants do not create separate valid aliases. **The future provider must derive one
   canonical physical-volume key**, not a drive-letter, mount-point, path or caller's guess.
   The calculator cannot discover physical aliases hidden behind different supplied tokens.
3. Allocation unit must be known and positive; available space and reserve must be known.
   Every file limit, directory count and extra allowance must be known. Zero-byte files and
   explicitly zero allowances/reserves are representable for tests, not a change to approved
   operational allowances. Each purpose includes at least its root directory. Include all
   planned missing ancestors/empty directories. At most 1,000,000 files plus directories per
   purpose; reject excess before materializing a large derived plan.
4. Budget each file as `ceil(byteLimit / allocationUnit) * allocationUnit`. Budget each supplied
   file/directory another 65,536 bytes, matching the scanner's explicit per-entry planning
   allowance. Use quotient/remainder, not potentially overflowing `length + unit - 1`.
   Add that purpose's explicit extra allowance once as bytes without allocation rounding.
   Never assume compression, sparse allocation, shared bytes, hard links or an in-place reset
   baseline save capacity.
5. Add all purpose budgets on the same volume, then add its safety reserve **once**. Compare
   with that volume's available bytes. Exact equality passes arithmetic; insufficient space,
   any unknown value or any UInt64 arithmetic overflow refuses. A surplus on a different
   volume cannot cover a deficit. No partial successful result escapes if one volume fails.
6. Snapshot caller arrays before calculation; nested records have get-only scalar properties
   and defensive array getters. Reordering input must not change output. No operation-level
   ownership/authorization or continuing disk reservation is conferred by a returned estimate.
7. Refusals are sanitized `MeasurementRefusal` codes: `BGSE_E_CAPACITY_INPUT` for invalid or
   unknown inputs/bindings, `BGSE_E_CAPACITY_OVERFLOW` for arithmetic overflow, and
   `BGSE_E_CAPACITY_INSUFFICIENT` for a volume deficit. Unknown data is never a partial result.

The per-entry allowance is not a filesystem upper bound. File byte limits must bound actual
planned source/evidence outputs, including manifests, intent, receipts and temporaries. A real
operation must enforce those bounds and its approved total allowance, include complete A1 and
baseline creation sets, use current independently queried volume identities/capacities, and
refresh immediately before writing. None of those binding/provider checks is implemented here.
The future baseline must be an independent allocation on its actual declared volume; this
calculator does not choose it or silently assume it is colocated with the working copy.
It requires a separately justified complete baseline plan. Result names describe the supplied
observations and accounted contributions, never independently measured or reserved free space.

## TDD and acceptance

Start with missing-helper RED. Exercise exact same-volume arithmetic and reserve-once,
different-volume allocation units and budgets, exact boundary/one-byte deficit, a deficit
hidden by another volume's surplus, all null/unknown/type-purpose/key/count limits, overflow
in rounding/summing/allowance/reserve, empty-file trees, zero-length files, input ordering and
mutation resistance. Distinguish actual public calculation tests from private-guard tests.

The lead owns contract/integration. After interface review freezes it, Sol 6 may independently
test scalar fault cases. Review corrections and counterexamples, focused tests and full host
regression are required before accepting A2. The execution evidence below is E2 host evidence
only, not E3/E4/E5, game access or a game copy.

Still required for packet A: tested native process/coordination/capacity providers, complete
source/evidence/footprint and approval binding, refresh, operational no-write/no-child `-WhatIf`.
Packets B-E and runtime isolation/reset remain separate; Task 3 stays in progress.

## Executed evidence and review

The user renewed continuation after a token-limit interruption on 26 September. This work
does not reopen the earlier source-measurement window or reset its expired overnight retry
bounds. The source measurement remains completed; no new source access or retry is needed.

Environment: Windows x64, Python 3.11.9, PowerShell 7.6.6; synthetic numbers only. Source and
disk capacity are **not** observed. Harness child processes compile the two local C# sources
and invoke this pure API; the calculator itself launches nothing and writes no files. Harness
JSON uses decimal strings to preserve exact unsigned 64-bit values; this is not a product
JSON parser or proof that arbitrary user input has been authorized.

The actual missing-helper RED test failed in 1.14 seconds before `AcquisitionCapacity.cs`
existed. After implementation, that exact arithmetic/required-total test passed in 1.82
seconds. The initial 46 primary tests passed in 55.89 seconds. An independent Sol 6 worker
authored and ran 19 fault/oracle tests: all passed in 23.93 seconds, without a correction.
The lead read the tests and checked their consequential arithmetic and failure assertions.

Independent static review found no implementation blocker. The lead and reviewer both
noticed the first large-rounding test's hypothetical unsafe formula reached `UInt64.MaxValue`
but did not overflow. The corrected fixture explicitly proves `length + unit - 1 > MAX`
while the valid full budget equals MAX; it passed in 1.57 seconds. Review also requested
direct constructor-limit coverage independent of `Calculate`: a 1,000,001-element known-zero
array must refuse, and constructor success raises a distinct harness error. It passed in
1.68 seconds. The constructor's validation-before-clone ordering is static evidence; no
allocation telemetry or out-of-memory stress experiment is claimed. No product change was
needed after initial GREEN. The final new suite comprises 47 primary plus 19 independent cases.

The more-than-three-volumes case proves invalid-collection refusal; redundant binding rules
would also reject that input, so it is not isolated proof of the volume-count guard. In
contrast, aggregate overflow uses individually valid purpose budgets, and combined entry
count uses known non-null limits, so unrelated validation cannot mask those intended checks.
Refusal output contains no partial budgets. Successful scalar outputs remain estimates from
supplied facts; the caller can still lie or omit outputs until later integration enforces binding.

Both G0 validators and the LF/CRLF regression passed unchanged. Their result does not advance
G0-G8 or finish Task 3. Reproduce the focused test set with:

```text
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_acquisition_capacity.py archive/2026-10-process/tests/tooling/test_acquisition_capacity_faults.py
```

Full-suite job `80234060-7171-4213-ae26-10a61e2b13d1` was verified **succeeded, exit 0:
787 passed in 459.14 seconds**, empty stderr, no warnings or timeout. It ran once using
`python -X utf8 -m pytest -q`, timeout 1,800 seconds, with the fresh private result directory
`work/acquisition-capacity-tests-v1` under the Task 3 work area. Status start/end were
14:17:07.138885 / 14:24:47.159133 UTC on 26 September, 460.020248 seconds wall time.
The single completion notification was accepted. Eight result files totaling 2,111 bytes
are retained. No job was polled, rerun or overwritten. Authored helper SHA-256 at dispatch:
`0B457ED90849539E7B0D8CF1CB2F770376CFCAF05CE5BE1EB0218F4D949CEDFF`.

The lead rechecked all seven saved code/test/dependency/tool identities after completion.
An independent Sol 6 saved-result audit matched the command, outcome, time bounds, count
(721 previous plus 66 new) and all three authored code/test hashes. No discrepancy was found.
JSON, relative-link, privacy and diff checks passed. This accepts A2's pure accounting only;
fresh native observations, complete input/footprint/authorization binding and all remaining
operation tests are still required before a real copy. No game or user-profile choice follows.
