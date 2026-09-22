# Task 3: read-only source measurement checkpoint

**Outcome:** Host-side inventory/capacity measurement only. Not copy authorization, provisioning,
runtime admission or Task 3 completion.

**Date / owner:** 2026-09-22 / integration lead.

**Question:** Can we observe ordinary source-file bytes and physical identities reproducibly,
detect the tested unsafe paths/drift, and cost two independent copies without creating anything?

**Environment:** Windows x64, PowerShell Core 7.6.6 / .NET 10.0.12; CPython 3.11.9 / pytest 8.4.2
for synthetic tests. The selected PowerShell floor remains >=7.4,<8; only this host was executed.

## Contract and evidence boundary

`scripts/measure-offline-reference.ps1` is always read-only, including without `-WhatIf`. It uses
the authored `scripts/lib/SourceMeasurement.cs` native helper within PowerShell's existing host
safety boundary. It never starts an external process, writes a manifest/log, creates a directory,
copies a file, changes source attributes, sets up saves, marks a lab, resets, or launches a game.

Exit 0 / `BGSE_MEASUREMENT_ONLY` means **observed-read-only**, not safe-to-copy. Every result reports
`writesAuthorized=false`, `runtimeReady=false`, `processCheck=unexecuted`, and
`writableRootAdmission=unexecuted`. Expected refusal and unexpected failures produce one path-free
JSON object and exit 3. Command-line binding errors outside the documented invocation are not this
script's structured-result protocol.

- Input must use ordinary drive-absolute paths. Traversal, device/UNC/ADS syntax, reserved names,
  and normalization/8.3 aliases are refused. Both volumes must be fixed local NTFS.
- Every existing source/destination ancestor is opened with a no-follow read/list-access handle. Reparse
  points are refused; handles are kept until measurement finishes, without delete/rename sharing.
  Full 128-bit file IDs plus volume identity are retained. The source root ID is compared against
  destination ancestor IDs, independently of lexical overlap checks.
- The destination must not exist, even if empty or carrying someone else's marker. The entire
  ancestor chain is checked again after inventory, including previously absent components. Appeared
  components, identities, junctions or destination leaves cause refusal.
- Source entries include empty directories and relative paths, ordinary byte lengths and SHA-256.
  Hard-linked files, reparse points, sparse/offline/encrypted/recall/device entries, unreadable entries
  and named streams are refused. Named streams include `Zone.Identifier`; nothing is silently stripped.
- File bytes are read through the **same** validated no-follow handle that denies write/delete sharing
  for that read. Metadata/identity and stream checks surround hashing. Directory listings are checked
  before/after recursion, and two complete inventories must agree in content and physical metadata.
- Two agreeing passes are **not an atomic snapshot**. Changes after an observation, transient restored
  changes, a malicious writer, and all future copy-time races are not disproved. A copier still needs
  immediate revalidation and its own checked reads/creates; it cannot reuse this result as authority.
- The inventory remains in memory. The public result contains counts and digests, never source paths
  or source payloads. Content and physical-identity digests are separate so independent fixtures can
  have identical content but different physical identities. ACLs, owner/security data, EAs and complete
  filesystem backup fidelity are not represented or promised; this is an ordinary-file content
  measurement, not a backup image or a complete installation-provenance manifest.

## Capacity is explicit planning, not a guarantee

For the supplied destination volume the implementation observes allocation unit and caller-available
bytes. It rounds each ordinary file up to one allocation-unit multiple, adds **64 KiB per inventoried
entry** (including directories) as a declared metadata planning allowance, reserves twice that total
for independent working and reset copies on that volume, then adds explicit output allowance and
safety reserve. Missing/negative/non-integer/overflow inputs, unknown capacity or insufficient space
are refusals. Compression savings and hard links never reduce the cost.

The 64 KiB allowance is a chosen planning margin, **not a proved upper bound** on NTFS metadata. It
does not fully cost new ancestor folders, a particular future baseline layout, journal growth,
concurrent disk usage or installer output. `capacityPlanningOnly=true` makes that limitation explicit.
A later operation must bound its complete output/backup/evidence layout, refresh available space,
and handle space failure without marking a partial copy ready. Offline measurement does not invent
a worst-case WeiDU budget for an unapproved runtime recipe.

## Reproduction

From the repository root, with only the approved local request and its existing authorization:

```powershell
$request = Get-Content -LiteralPath '.work/task3/scs-reference-request.json' -Raw | ConvertFrom-Json
pwsh -NoProfile -File ./scripts/measure-offline-reference.ps1 `
    -SourceRoot $request.sourceRoot `
    -DestinationRoot $request.destinationRoot `
    -OutputAllowanceBytes 1073741824 `
    -SafetyReserveBytes 21474836480 `
    -WhatIf
```

The example allocates 1 GiB output and 20 GiB reserve for the **offline planning observation only**.
Use a fresh PowerShell process: the wrapper does not hot-reload a helper type already loaded into
an existing session. Record SHA-256 of both script/helper files for an accepted observation.
Neither the command nor the request authorizes a new source, another destination, copying, or launch.
Do not redirect source paths, payloads or unredacted diagnostics into committed artifacts.

Tests:

```powershell
python -X utf8 -m pytest -q tests/tooling/test_offline_reference_measurement.py tests/tooling/test_offline_reference_faults.py
python -X utf8 -m pytest -q
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File scripts/test-g0-line-endings.ps1
git diff --check
```

## Test-first and review record

1. Initial focused RED: first test failed because `measure-offline-reference.ps1` did not exist.
2. Initial implementation compiled after correcting a C# definite-assignment error; the 8.3 test
   then failed because .NET normalized a short alias before native comparison. Comparing the original
   input with the normalized path fixed that defect; source and destination-parent alias regressions
   both passed. The initial focused set then passed 35 cases.
3. Independent Astra review found missing final ancestor revalidation and a missing cross-chain
   physical-identity comparison. Deterministic regressions failed before the extracted guard methods
   existed and passed after implementation. They exercise an appeared ordinary parent, an appeared
   junction with still-missing leaf, and matching native IDs independent of path spelling.
4. A bounded Terra worker owns only `test_offline_reference_faults.py`. The lead owns implementation,
   integration and safety interpretation. The worker uses temporary fixtures, not game paths; no
   Claude or Luna is involved. Worker output is independently inspected and run in the full suite.
   The worker's seven-case isolated run passed in 7.55 seconds; the lead repeated the combined suite
   in explicit UTF-8 mode: 45 passed in 51.39 seconds. The worker correctly reported that a proposed
   held-delete directory test did not reproduce the assumed refusal. The lead investigated that
   counterevidence rather than accepting it as irrelevant; see the next item. No claim is made that
   all existing handles are discovered.
5. Fault interleavings for appeared destination ancestors, matching physical IDs and changed source
   observations directly invoke the private guard methods used by `Measure`. They are deterministic
   guard-method tests, not concurrent whole-command race proofs. Ordinary path, ADS, hard-link,
   sharing, capacity and generic-error cases execute the whole command. Independent Astra review
   accepted the corrected implementation and this memo for the bounded read-only checkpoint.
6. Lead follow-up reproduced an actual ancestor rename while a `desiredAccess=0` metadata handle was
   held. That regression was RED (`rename-allowed`). Metadata access does not enforce the intended
   sharing lock. Requesting `FILE_READ_DATA` / `FILE_LIST_DIRECTORY` (`0x1`) makes the no-delete
   sharing contract effective without requesting write access. The rename regression then passed;
   a lead-added test also covers an already-held DELETE handle. All checks must be rerun after this
   correction. This is why worker counterevidence and actual native behavior—not flag inspection—
   are part of acceptance.
7. The named-source run using the former in-memory helper was stopped after rechecking the exact
   owned helper process identity. It produced no accepted inventory and is superseded. No game or
   loader process was stopped. The stream-query buffer was also bounded to 64 KiB to reduce repeated
   per-entry allocation; an insufficient buffer still refuses rather than accepting partial data.

**Final verification:** After the sharing correction and both locking regressions,
`python -X utf8 -m pytest -q` passed **530 tests in 137.40 seconds**, including all 47 new measurement
cases. Both G0 validators passed; the LF/CRLF regression script passed both forms. `git diff --check`
and all ten relative Markdown links in the affected plan/memos passed. The local request and
background-result directory are ignored; the destination and its immediate parent remained absent.
Independent Astra review found no remaining blocker for the corrected read-only measurement job.
No Task 3 completion, G1 pass, full copy or engine acceptance is inferred from these host checks.

**Named-source execution:** The first run was superseded/stopped as recorded above, without an
accepted result. The corrected fresh-process run was dispatched using the local completion helper;
its durable ignored result directory is `.work/task3/work/measurement-v2/`. The helper saves exit
status/stdout/stderr and attempts one continuation notification. Inspect `status.json` and the
output after that notification before making any evidence claim; queue acceptance alone is not
measurement success. Corrected-helper source observation is pending, not passing. Raw-byte tool hashes
for the next fresh-process run (line endings are part of these identities):

| Artifact | SHA-256 |
|---|---|
| `scripts/measure-offline-reference.ps1` | `5A1FC871CC83EC2141583C3E0587F5B5F03265CBFE27CBAC6361D08FDDD767B9` |
| `scripts/lib/SourceMeasurement.cs` | `339106B5C85D805B95AA0B68A0C1A1F8B3D56BF7DE078570E24021D60BAD1E5D` |

**Artifacts:** Authored helper/wrapper, independently authored temporary fixture tests, this
redacted memo and aggregate measurement output. No source payloads, personal paths or game files
are publication artifacts.

**Counterevidence / residual uncertainty:** Synthetic fixtures do not exercise the full installed
stack or all possible host races. NTFS metadata/extra-attribute fidelity and complete process/lock
discovery remain outside the measurement. A matching two-pass observation is not a persistent
snapshot or a guarantee that later copying will succeed; no E3/E4/E5 evidence is claimed.

## Sources, limitations and next checkpoint

The native calls follow Microsoft's
[CreateFileW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew),
[FILE_STREAM_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_stream_info),
and [GetDiskFreeSpaceW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespacew)
contracts. These are E0 documentation inputs; synthetic NTFS observations are E2 evidence, not
EEex/runtime proof. No unsupported alias family is admitted merely because no counterexample was
observed; no all-files-unlocked, complete helper/process, cloud isolation or runtime claim is made.

Next: independently review the guarded copier's fresh-creation, complete protected-root/process,
immutable private-manifest and copy-verification contract before any copy. The separate runtime
profile decision and non-cloud writable-root solution in [the authorization memo](disposable-lab-provisioning.md)
remain required before engine admission; reset/launch/save acceptance and G1 are still unexecuted.
