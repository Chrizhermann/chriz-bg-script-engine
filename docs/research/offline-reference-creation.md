# Task 3: exclusive fresh-creation primitive

**Outcome:** Synthetic host mechanics only; not an operational copier, copy admission, runtime
admission or Task 3 completion. No game destination was created.

**Date / owner:** 2026-09-22 / integration lead.

**Question:** Can the future acquisition tool create an independent fresh tree without adopting
existing paths, reopening newly created objects before claiming them, or following redirects?

**Environment:** Windows 11 x64 build 26200, fixed local NTFS, PowerShell Core 7.6.6 / .NET 10.0.12,
CPython 3.11.9 / pytest 8.4.2. All writes in this checkpoint target temporary synthetic fixtures.

## Boundary and implementation

`scripts/lib/FreshTree.cs` is a separately loaded primitive, not a user-facing provisioning command.
The read-only measurement wrapper still compiles only `SourceMeasurement.cs`. A small factoring in
that helper shares its existing validation of the same native handle; it does not add writes to
the measurement command. No operational copy script invokes the primitive yet.

- Construction validates the absent destination and existing ancestors without creating anything.
  `PlannedDirectories` returns a defensive copy of **every missing intermediate directory and the
  final root**. The future caller must admit this whole write footprint, not just the final root.
- Every missing directory is created exclusively by `CreateDirectory2W`, returning its ownership
  handle in the creation operation. Existing paths are refused, never adopted or overwritten.
  Directory handles remain open until disposal; newly owned directories deny ordinary write/delete
  sharing. Existing ancestor handles retain the measurement's read/list, no-delete sharing rule.
- Files use `CreateFile3` with `CREATE_NEW`. Both native creation operations disallow path redirects
  in the operation itself. A preflight observation alone does not establish this property.
- Returned handles are checked for canonical path, type, native identity, hard links and streams.
  Children require an already owned parent. Unsafe relative paths and case-insensitive duplicates
  are refused. File handles are transferred to the caller for write/flush/readback and disposal;
  the primitive does not claim ownership or stability after the caller closes them.
- Any failed creation poisons the instance. Disposal closes retained handles but deletes nothing.
  Failed or partial output must be retained and cannot be adopted by another fresh-tree instance.
- Both native API exports are mandatory before creation. There is no mkdir-then-open, overwrite,
  path-redirect or older-API fallback. The primitive's Windows 11 24H2/API requirement does not change
  the broader Task 2 checker floor or admit another game/EEex profile.

Source and protected-root admission, process state, capacity, complete acquisition manifests,
publication, cancellation and final source/copy verification are **not provided** by this class.
It creates no readiness marker, never launches anything and does not edit game configuration.
Do not call it against a game path independently of the future reviewed operation-level contract.

## Native contract and reproduced corrections

The pinned Microsoft SDK header at
[`71033001b4479c6566546b68d32276e70a8d68b9`](https://github.com/microsoft/win32metadata/blob/71033001b4479c6566546b68d32276e70a8d68b9/generation/WinSDK/RecompiledIdlHeaders/um/fileapi.h#L1409-L1457)
defines the five-argument `CreateDirectory2W` signature and the file-creation parameter structure.
The [directory documentation](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createdirectory2w)
has an inconsistent six-argument example and conflicting failure-value prose. The implementation
uses the header signature and rejects both NULL and INVALID_HANDLE_VALUE.

The [CreateFile3 contract](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfile3)
and its [extended parameters](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-createfile3_extended_parameters)
define creation-time redirect refusal. Tests check the x64 structure's 32-byte size and pointer
offsets 16 and 24. Directory flags use `1`; file flags include `0x10000` and leaf no-follow.

The first implementation's directory access/share mask failed the success fixtures. A lead-owned
native parameter matrix on this host observed:

| Directory access | Sharing | Result |
|---|---|---|
| LIST_DIRECTORY | READ | Invalid parameter (87), nothing created |
| LIST_DIRECTORY | READ + WRITE | Invalid parameter (87), nothing created |
| LIST_DIRECTORY + SYNCHRONIZE | READ + WRITE | Invalid parameter (87), nothing created |
| LIST_DIRECTORY + SYNCHRONIZE | READ | Created, but subsequent same-handle metadata validation refused |
| LIST_DIRECTORY + READ_ATTRIBUTES + SYNCHRONIZE (`0x100081`) | READ | Creation and same-handle validation passed |

The correction adds the required access rights and narrows sharing; it does not weaken redirect or
identity checks. The matrix is a host observation, not a claim about undocumented internals on
every Windows build. Temporary probe output was not a lab acquisition.

## Test-first, delegation and reproducibility

The lead's first test harness had a PowerShell quoting typo, which was corrected before recording
the intended RED: `FreshTree.cs` was absent. A bounded Terra worker independently authored seven
fault tests; its initial RED was also the absent helper. The worker changed only its assigned test
file, used temporary fixtures, and did not implement native code or touch a game. Its first run
against the implementation reported four failures reaching root creation; the lead diagnosed and
corrected the native masks above rather than weakening assertions. The worker independently reran
its unchanged cases: seven passed in 7.22 seconds. No Luna or Claude was invoked.

Independent Astra review found no blocking primitive-level code defect, requested more precise
parent-handle wording, and suggested stronger sharing and ownership-footprint tests. The lead
corrected the wording, checks retained identity before a validated reopen, proves a returned plan
array cannot alter creation, and checks actual sharing error 32 plus a successful after-disposal
control. A native component-length failure tests retained partial output during root creation.

Coverage includes fresh creation, unchanged read-only construction, empty directories, Unicode
names, same-handle byte write/flush/readback, collisions, appeared ancestors, unowned parents,
traversal/ADS/device names, duplicate casing, disposal, poisoned state, native sharing and redirect
refusal. Direct native-create boundary tests and the missing-export guard are deterministic method
tests, not a whole-command concurrent race or an executed older-Windows test. No in-place junction
conversion or hostile administrator/device-map test is claimed.

Reproduce from the repository in a fresh PowerShell process per fixture:

```powershell
python -X utf8 -m pytest -q tests/tooling/test_fresh_tree.py tests/tooling/test_fresh_tree_faults.py
python -X utf8 -m pytest -q
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File scripts/test-g0-line-endings.ps1
git diff --check
```

**Verification:** The combined creation/measurement tests passed 77 cases in 92.30 seconds before
the final three added cases; those cases separately passed, as did the strengthened sharing case.
The full host suite then passed **563 tests in 168.72 seconds**, exit 0, empty stderr. The lead
verified the saved status/output after job `42c9faad-d5df-4394-8c44-ff4660731bc3`'s completion
notification; its durable ignored record is `.work/task3/work/fresh-tree-tests-v1/`. Both G0
validators, the LF/CRLF regression, ten relative Markdown links and `git diff --check` passed.
These results verify the bounded primitive checkpoint, not the failed named-source measurement,
an operational copier, a game launch or Task 3 completion.

**Evidence:** E1 pinned SDK signature; E0 API documentation; E2 synthetic native-host observations.
No E3/E4/E5, engine isolation, whole-copy success, crash-safe publication or permanent immutability.

**Artifacts:** Authored helper/tests and this redacted memo. No source payload, personal path,
installed-game data, save or copied configuration is a publication artifact.

**Counterevidence / residual uncertainty:** The API names and requested flags did not by themselves
prove a working call shape; actual native tests found the mask defect. Held directories are not a
filesystem snapshot or defense against arbitrary privileged namespace manipulation. Closed files
can change. Metadata/security backup fidelity is not promised.

**Next decision/checkpoint:** Finish and independently review the operation-level offline copier,
including private intent/source/copy manifests and completion publication. A successful
[measurement](offline-reference-measurement.md) is only an input, never copy authority. Runtime
profile and non-cloud writable-root decisions remain separate barriers before engine use.
The named-source scan has now refused with an undiagnosed access error; this primitive's synthetic
success must not override that refusal. Improve diagnostic evidence before source acquisition.
