# Task 3, packet A3: fresh native volume observations

**Status:** Reviewed implementation and full synthetic-host regression verified; accepted only for
bounded point-in-time observations, not acquisition or runtime admission.

**Date / owner:** 2026-09-26; verification 2026-09-27 / integration lead.

**Question:** Can a bounded read-only provider bind each proposed output to its current
filesystem volume and available-to-caller capacity, without treating path aliases as new space?

## Scope

The [A2 calculator](acquisition-capacity-contract.md) at `fb58e24` passed 787 host tests but
deliberately trusts supplied observations. A3 obtains those observations from Windows for
three explicitly supplied proposed destinations, using synthetic temporary paths in tests.
It is not source inventory, process/coordination admission, a copier, protected-root admission,
baseline-location approval, a quota reservation or permission to launch a game.

Existing exact user roots remain unchanged. No new baseline location is selected here.
Any real invocation still needs reviewed exact purpose/path/approval and complete footprint
binding; no game paths were queried while implementing this checkpoint.

## Primary-source research

Microsoft documentation inspected on 26 September 2026 establishes:

- A volume may have multiple GUID paths. Therefore, different GUID names alone are not proof
  of separate capacity pools. [Naming a Volume](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-volume)
- `GetFinalPathNameByHandleW` supports a directory handle and `VOLUME_NAME_NT` (2), returning
  a native device path. Zero means failure; a result at/above the supplied character buffer
  length is not a usable complete name. [Handle path query](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew)
- Path-based free-space APIs follow links. Independent review rejected the first draft's
  before/after checks as insufficient: a DOS mapping can change during the query and return
  before the final check (ABA). Those queries will **not** supply A3 capacity.
  [Path-based API](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexw)
- `NtQueryVolumeInformationFile(FileFsFullSizeInformation)` queries the volume of an open
  directory. One result supplies caller-quota-aware allocation counts and geometry. Negative
  counts, zero geometry, inconsistent caller availability and checked-product overflow refuse.
  Actual free units may legitimately exceed the caller's quota-limited total; that comparison
  must not be rejected. [Query](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntqueryvolumeinformationfile),
  [structure](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntddk/ns-ntddk-_file_fs_full_size_information)
- A directory opened without `FILE_FLAG_OVERLAPPED` is synchronous: I/O calls using that
  handle block until completion. Only the existing private synchronous `SourceMeasurement.Open`
  handles may enter this boundary, never externally supplied/asynchronous handles. The
  user-mode `Nt` entry point and x64 ABI still require focused proof before acceptance.
  [Synchronous handles](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew#synchronous-and-asynchronous-io-handles),
  [I/O status block](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_io_status_block)
- Filesystem name and read-only status can be queried through that same handle, as can
  device type/characteristics. Do not reintroduce a path query for NTFS/fixed-device acceptance.
  [Filesystem](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumeinformationbyhandlew),
  [device](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_file_fs_device_information)
- Device checks use disk type 7 and reject removable/read-only/remote bits 1/2/16.
  [Microsoft field definitions](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/616b66d5-b335-4e1c-8f87-b4a55e8d3e4a)
  `WindowsIdentity.GetCurrent(true)` detects impersonation; a non-impersonating process's
  user SID supplies the private quota-context binding.
  [Identity API](https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsidentity.getcurrent?view=net-10.0)

These are E0 documentation inputs, not runtime proof. They do not establish atomic disk
snapshots, stable cross-boot identities or physical backing-store capacity.

The enum values are additionally E1 pinned static evidence from Microsoft's public-DDK copies:
`FileFsDeviceInformation = 4`, `FileFsFullSizeInformation = 7` at Terminal revision
`0a5dffe1afed59420f1624ef2ab796f7aa07e105`,
[conddkrefs.h](https://github.com/microsoft/terminal/blob/0a5dffe1afed59420f1624ef2ab796f7aa07e105/src/host/conddkrefs.h#L65-L80).
The lead independently opened that exact source. The installed SDK 10.0.26100.0 `winternl.h`
was also inspected for `IO_STATUS_BLOCK`; SHA-256
`A43424486349C38F697C009512DFE4EB8FCA733D7665AFAB42F50752170B9785`. No WDK compilation is claimed.
The helper checks x64 marshaled sizes/offsets before querying: status block 16 bytes with
32-bit status at 0 and pointer-sized information at 8; full-size data 32 bytes, signed counts
at 0/8/16 and unsigned geometry at 24/28; device data 8 bytes. A success return is authoritative;
matching status-block success and exact returned length are additional conservative guards.

## Reviewed boundary

1. Immutable `CapacityTarget(purpose, destinationRoot, safetyReserveBytes)` records; reserve
   nullable UInt64 with no default. Exactly one target for each A2 purpose, maximum three.
   No nulls, unknown reserves, aliases, traversal, root-wide paths or output overlap. All
   destinations must be fresh; never accept existing partials. There is no source discovery.
2. `NativeCapacity.Observe(CapacityTarget[] targets)` snapshots inputs and holds no-follow
   ancestor chains using the existing `SourceMeasurement` primitives. Require Windows x64,
   ordinary fixed NTFS paths. No recursion, writes, directory creation or child process.
   A3 observes only metadata of existing ancestors; it cannot claim content stability.
3. Derive a session-local volume key from the **held drive-root handle**, not a caller token,
   drive letter, label, volume serial alone or GUID path. The initial implementation supports
   only an exact native root of the form `\Device\HarddiskVolume<positive decimal>\`.
   Canonical key: `NTVOLUME_<decimal>` (1-10 digits, no leading zero). Unknown native namespaces refuse;
   do not guess a mapping or fall back to a supplied ID.
4. Every held ancestor's native path must have that exact device prefix and agree with its
   expected drive-relative suffix. Before and after capacity reads, recheck native root name,
   held identities and freshly reopened complete ancestor chains, including missing segments.
   An appeared ancestor/root or changed device/identity refuses. Handles are always released.
   Once native keys are known, also compare volume-relative destination suffixes: equal or
   parent/child outputs on the same native volume refuse even under different drive letters.
   This supplements DOS-spelling overlap checks; it does not change live drive mappings.
5. Query full-size information through the deepest held ordinary ancestor's **same synchronous
   handle**. Require exact successful completion and complete output, nonnegative counts,
   nonzero geometry, caller-free <= caller-total and caller-free <= actual-free. Multiply using
   checked UInt64 arithmetic. Query local fixed-disk type and NTFS/not-read-only through the
   same handle. Native errors produce sanitized refusals; never fall back to a name-based API.
   Restrict to non-impersonating execution and record the caller SID privately; recheck it
   around observations. Future writes must use that same effective user and fresh observations.
   The query is not a security-context lock, reservation or guarantee against quota changes.
6. Group targets by derived native key. For repeated samples require the same root identity,
   allocation unit and explicit reserve; take the **minimum** available bytes observed rather
   than adding samples or assuming they are simultaneous. Different native keys that report
   an identical root identity are ambiguous and refuse instead of claiming independent space.
7. Return immutable `CapacityObservation` with defensive `Bindings` and `Volumes` arrays.
   Each binding has `Purpose`, exact `DestinationRoot`, `VolumeId`, `ExistingAncestor`,
   `AncestorIdentity` and `RootIdentity`. `Volumes` contains A2 `CapacityVolume` records.
   The observation also records `CallerSid`. These private records are not public stdout or a persisted authorization token. Result
   properties do not say `safe`, ready or admitted.
8. No cached observation is accepted as refresh. Every `Observe` call repeats the native
   queries. Future operation integration must bind A1 and full inventory/baseline plans,
   invoke this immediately before first write, and repeat relevant checks later. A returned
   result reserves no space; other processes can consume it immediately.

Native device names are local and potentially transient across reboots/remounts. They group
currently held filesystem volumes only, not underlying disks, shared thin pools, virtual disk
backing files, guarantees under privileged remounting or power-loss behavior. This candidate
does not broaden the repository's fixed-NTFS scope; ambiguous unsupported layouts must refuse
real admission rather than being relabeled proven. The complete operation's remaining safety
requirements remain in [the acceptance packet](offline-acquisition-acceptance.md).

## Required proof and open questions

After independent review freezes the identity/query contract: actual missing-helper RED;
native observations for fresh synthetic sibling destinations; same-volume grouping; caller
quota-aware output structure; output array immutability; source/fixture snapshots unchanged;
fresh queries, appeared ancestors and handle cleanup; existing outputs, aliases, junctions,
wrong types and malformed inputs refuse. Separate pure/reflection boundary tests for native
query failure/zero unit/truncated names/inconsistent identities from actual OS fault injection.
Do not claim isolated quota, multi-volume, remount or native-error proof without exercising it.

Independent review accepted the revised same-handle completion/ABI boundary for TDD. Buffer lifetime follows the
synchronous-handle contract; do not add asynchronous support by merely rejecting STATUS_PENDING
and releasing buffers while an operation could still own them. A real pending return would
contradict the supported synchronous assumption and is a failed experiment requiring investigation,
not a supported asynchronous path. Decoder tests of the numeric status are not pending-I/O proof.
The verified checkpoint below accepts only this bounded A3 observation. No game inspection,
capacity reservation, copy admission or gate advancement follows.

## Execution and review

The first missing-helper test genuinely failed before `NativeCapacity.cs` existed (1 test,
0.99 seconds). After implementation the same fresh-sibling native query passed (1 test,
1.66 seconds), including the actual ABI checks and same-handle device/filesystem/full-size
calls on a temporary directory. An independent Sol 6 worker's 46 scalar decoder tests passed
in 52.69 seconds without correction. The lead read the test source and checked overflow
reachability; these tests are not injected OS failures, quota setup or remount experiments.

The first independent code review accepted ABI, ownership/disposal and quota arithmetic,
but requested an explicit native-volume-relative overlap guard. DOS spelling alone was
insufficient proof for multiple letters referring to one filesystem volume. A focused RED/GREEN
regression first failed all six cases because the guard was absent (7.38 seconds), then passed
all six (7.19 seconds). `Observe` calls that guard after deriving held native keys and before
capacity sampling. Cases cover case-insensitive equality, both ancestry directions, sibling
prefix separation and different-volume acceptance, using supplied scalar facts only.

The original 41 primary tests passed in 49.68 seconds. Review then requested a complete
before/after fixture snapshot around native success, explicit full-path-length and invalid
UTF-16 cases, and returned native-path length boundaries. The first four length tests failed
because a private test seam did not yet exist (6.66 seconds); extraction of the already present
inline check made them pass (5.48 seconds). This was a testability refactor, not discovery of a
missing length guard. Final tests include exact 32,767/32,768/32,769-character scalar boundaries;
large/invalid input strings are constructed inside the harness process so transport limits
cannot hide the library's rejection. No real OS truncation or pending operation is injected.

Final independent static review accepted the helper and both test files with no remaining
blocking finding. The lead retained all safety assertions and checked the requested
documentation details. No reviewer native calls or tests are claimed. The combined focused
suite passed **102 tests in 124.67 seconds**, exit 0, no skips or errors. Both G0 validators
and their LF/CRLF regression also passed unchanged. The full regression is verified below.

Environment: Windows x64 `10.0.26200.0`, PowerShell 7.6.6, Python 3.11.9, pytest 8.4.2;
`ntdll.dll` file version `10.0.26100.9278`, SHA-256
`A74F7482085EAB125CCC09152AB7E0B5994BCB13E1A7B29880BDBB24179ECB8B`.
These identities and exact authored/test/tool hashes are retained privately with the commands.
Tests create only temporary host fixtures. The helper opens existing metadata handles, samples
capacity and releases its handles; it does not create directories or spawn processes. These
invocations accessed no game files. Test harnesses start fresh PowerShell compilers and deliberately create
their synthetic fixtures. No operation-level no-child-process proof is claimed here.

Native success, unchanged fixtures, handle release within the same process after success and
refusal, and changed ancestor on a fresh call are host fixture observations. Appeared-ancestor
revalidation and volume-key/grouping contradictions additionally use controlled private-boundary
tests. They are not demonstrations of an adversarial OS race. Actual quotas, multiple native
volumes, remounts, security-context switching and native failure/pending completion are untested.
Space is not reserved and the minimum sample is only conservative for the sampled values.
Any later quota-context change requires a fresh observation before writes.

This contributes E1 source/binary identities and E2 synthetic-host checks only. It does not
complete packet A or implement a copier. Process/coordination observation, full source/footprint/
baseline/evidence/authorization binding, operational `-WhatIf`, packets B-E and runtime isolation
remain required. No actual baseline location is selected. Task 3 and G1 remain incomplete.

Reproduce focused coverage with:

```text
python -X utf8 -m pytest -q archive/2026-10-process/tests/tooling/test_native_capacity.py archive/2026-10-process/tests/tooling/test_native_capacity_faults.py
```

The full-suite command `python -X utf8 -m pytest -q` completed once as background job
`880566c9-c067-49c5-8da4-ff06b250fb16`: **succeeded, exit 0, 889 passed in 625.09 seconds**,
empty stderr, no warnings or skips. The status interval was 14:51:32.500888 to 15:01:58.488855
UTC on 26 September (625.987967 seconds), below the 1,800-second timeout. Results remain in
the fresh private directory `work/native-capacity-tests-v1` under Task 3: eight files,
2,287 bytes. One completion notification was accepted. No job was polled, rerun or overwritten.
The count matches 787 prior plus 102 new tests.

On completion the lead verified saved status/output/exact command and all eight authored,
dependency and tool fingerprints, plus the native DLL fingerprint. An independent Sol 6
audit matched command, status/count/time bounds, single notification and the three authored
helper/test hashes; no discrepancy was found. No test/code changed after dispatch. The prior
focused run preceded only an equivalent test setup simplification; this full run covers the
exact final test bytes. JSON/link/privacy/whitespace checks passed. This accepts the bounded
A3 helper and leaves all operation-level barriers above intact.

Authored helper SHA-256 at dispatch:
`E6172021CADFCEF1477E68943F5E3DFEAD476B1685A9445F29BFC28EAA5D53EA`.
