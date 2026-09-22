# Task 3: authorization and source preflight

**Outcome:** Conditional; Task 3 in progress. Destination approved, but no copy, marker,
installation, launch, save, reset or game mutation has occurred.

**Date / owner:** 2026-09-22 / integration lead.

**Question:** Can the user-approved SCS reference source become the planned isolated laboratory
without changing the active installation, silently changing the support baseline, or sharing saves?

**Environment:** env:host, game-state access read-only. Inspection was limited to the named source's
filesystem metadata, four file fingerprints, selected installation-log labels and engine-name
assignment; host disk/process metadata and the Documents known-folder path/attributes were read.
No save contents, unrelated game trees, executable behavior or engine process memory were accessed.

## Authorization and current boundary

After the concrete `BGSE-Lab/scs-reference/game` destination proposal, Christopher approved proceeding
and said detailed design/code review could happen later. The lead recorded this as authorization to
begin Task 3 at that exact destination, with the previously named source used read-only. Absolute
source/destination paths are retained in the ignored local request, not in committed documentation.
This is not permission to mutate the source, change Windows account settings, choose another
installation recipe, waive G0-G8, or invoke Claude now. Claude review remains future work.

Local request: `.work/task3/scs-reference-request.json` (ignored, not a distributable artifact).
Losing that local request means the next session must recover the exact approval from this task,
not infer filesystem targets from conventional paths or from this redacted memo.

## Observed source, not a new support claim

**Versions and fingerprints:** Lead-observed raw-byte SHA-256:

| Artifact | Observed fact | Bytes | SHA-256 |
|---|---|---:|---|
| `Baldur.exe` | FileVersion `2.7.3.0` | 7,202,696 | `B51093A49140B2B8A7C046B4652BB8E535BE24EBBC12B1D735E0B94217A14D57` |
| `WeiDU.log` | Installation-log input, not proof of installed-file integrity | 44,095 | `4FD4AB5491533C17E5E8DE26E4DCE84A761A34EF79A998B06007234080B89FE6` |
| `engine.lua` | Existing collection-managed identity; value kept private | 97 | `1BA2DF4CFFB27E4307D3246400A577CD4B695D4C010C1185A37DB4A72227B93D` |
| `InfinityLoader.ini` | Configuration fingerprint only; no loader executed | 5,045 | `8C0347177F76894CD7E0ECDA589BE6F32A37BD0A926B2E1D651653AF76F8A9BD` |

Selected log labels: EET `v14.0` plus finalizer entry; EEex `v1.2.0` main and LuaJIT components;
SCS `35.21` including 5900/6030/6040; Spell Revisions `v4.21-chriz.5`; Bubb's Spell Menu Extended
`v5.2`. These are observed labels, not verified upstream revisions or complete effective-stack
identities. The log's finalizer entry does not prove no later mod changed relevant resources.

**Observations:**

- Attribute-only source traversal: 164,630 files, 3,530 descendant directories,
  12,147,300,922 logical bytes (11.313 GiB), zero encountered reparse entries. Source ancestors were
  also checked for reparse attributes. This is not a native-identity or hard-link audit.
- Destination and its proposed lab parent did not exist.
- Destination drive snapshot: fixed NTFS, 1,999,364,943,872 total bytes,
  133,043,429,376 free bytes. Space is volatile; no complete capacity acceptance is claimed.
- Enumerated game/loader processes belonged to a different installation, not the source or proposed
  destination. They were left untouched. Enumeration is not an exhaustive open-handle/lock proof.
- At `2026-09-22T22:31:27+09:00`, Windows' Documents known folder was under OneDrive and its directory
  carried a `ReparsePoint` attribute. No contents were enumerated, native reparse tag classified,
  cloud-sync state inferred, or settings changed. The existing no-reparse lab policy rejects this
  location without needing to guess its target or type.

[PREP-01](PREP-01-support-baseline.md) retains the separate `2.6.6.0` / EEex `0.11.0-alpha` /
SR `4.19` candidate. The observed source does not match that candidate. The
[pinned EEex v1.2 README](https://github.com/Bubb13/EEex/blob/204040502ac920161d60046d90b766b8d2d08152/README.md#compatibility)
lists 2.6.6.0, not this 2.7.3.0 executable. That documentation gap is not proof of a crash or of
compatibility; neither was tested. No downgrade, upgrade or baseline replacement is authorized by
this record.

## Reviewed offline-reference boundary

Independent review permits a narrower **offline SCS reference acquisition** checkpoint inside the
approved copy scope. It does not admit an engine lab or change PREP-01's runtime candidate:

- A future guarded independent copy may retain the source bytes for static comparison, with an
  explicit source manifest and copy-verification evidence.
- No launch, loader/native execution, install/reinstall, save loading, or adapter activation is
  permitted by offline admission. Resource extraction/decompilation needs its own bounded host
  operation/output contract; never run such a command from the source directory.
- Copied configuration still names the old user profile. The offline copy is **not launch-isolated**.
  Do not write `.bgse-disposable-lab.json` or represent it as ready. A future distinct acquisition
  manifest must bind the exact roots, source snapshot and copy identity and state `offline-only`.
- Source/destination ancestor, reparse, hard-link, child-identity, process, capacity and full-copy
  verification requirements still apply. Offline status waives none of those checks.
- Task 3 remains incomplete until the actual engine profile, independent writable roots, one
  observed launch/save cycle and two verified resets satisfy the canonical exit.

This is an internal scope clarification within the approved reference-copy request, not a new
runtime design decision. It has not yet been implemented or used to copy files.

## Isolation implementation packet

The current Task 2 checker is intentionally post-provision: it requires a destination and marker,
accepts only exact game-root-contained targets, and rejects unbounded directory writes. Do not
change its `BGSE_OK` meaning to authorize a recursive copy or reset.

The requirements below were independently reviewed; the next host-side packet must:

1. Follow TDD for separate provisioning/reset operations and their `-WhatIf` paths; no real copy
   until the relevant contract passes independent review. Dry runs must validate and leave complete
   fixture snapshots unchanged, including markers, logs, baselines and child processes.
2. Define a fresh-destination bootstrap state: verify all existing ancestors, exclusively create
   new owned paths, refuse adoption/overwrite, and never mark incomplete output launch-ready.
   Preserve failed partial output for diagnosis; do not automatically recursively delete it.
3. Guard protected source roots separately from every writable lab root. The real engine route
   includes Documents/saves, configuration, loader state, logs/crashes, evidence and reset baseline;
   none is covered merely by a safe game-folder result. Refuse overlap, aliases and shared files.
4. Enumerate every source/destination child without following reparse points, reject hard-linked
   files, and recheck identities immediately before mutation. Preserve source manifests and prove
   independent copied identities and content; a root check plus generic recursive copying is not
   sufficient.
5. Bind resets to the expected lab ID, exact roots and immutable baseline manifest/digest, not just
   a syntactically valid marker. Reject foreign markers/baselines and drift; restore twice and
   compare protected and lab trees against the defined retention policy.
6. Turn source-process and capacity checks into tested contracts. Before copying, select explicit
   output/backup allowance and reserve, refresh free space, and budget the working copy plus an
   independent reset baseline. The preliminary byte count alone does not satisfy this contract.

These are implementation/review responsibilities; Christopher need not inspect every code line.
A different destination, active-profile changes or a materially different runtime recipe require
his direction. No code or acceptance-test implementation is claimed in this preflight packet.

## Collection identity recipe: reuse with its actual limits

The Terra extraction and lead source check used `chriz-bg-collection` commit
`32ab76df7ed52054c3e3534a7fee5c3bbff2daa1`, reading committed objects only and preserving the dirty
working tree. `engine/src/stage.rs` blob: `b517f6bb5c768be435b9a03d867acf8beba49fdb`;
`engine/tests/stage.rs` blob: `a67ee4af1a7afbdfd30394c0206d55bf8ad733ec`.

- `stage.rs` 267-317 derives a normalized display name plus twelve SHA-256 hex characters from
  install ID, a NUL separator and normalized managed-root identity. It joins that engine name to
  the supplied Documents directory; 438-479 defines normalization.
- 320-372 reserves a separate save directory or checks its exact ownership record; it does not
  prove the supplied Documents ancestor itself is non-cloud/non-reparse and safe for this lab.
- 374-435 patches the BG1 identity early and reapplies/verifies the BG2 identity after EET; only
  exactly one valid `engine_name` assignment is accepted. It does not redirect every external
  writable location or prove runtime isolation merely by editing `engine.lua`.
- Tests at 392-524 cover identity/collision/finalization scenarios; those collection tests were
  inspected, not executed here. The existing-modded-copy route still needs its own source manifest,
  effective-stack review and full writable-root contract.

Worker packet was bounded read-only extraction with no game access or edits. The lead checked both
blob identities and consequential derivation/reservation/finalization ranges. Independent Astra
review retained safety interpretation and identified the narrower offline admission above. No Luna
or Claude was invoked. No worker retry or correction was needed; token/cost data were unavailable.

## Reproduction and evidence limits

**Method:** Use the locally retained exact request only after confirming its approval still applies.
Query source ancestors with `Get-Item -LiteralPath -Force`; stop at a reparse attribute. Walk with a
stack of `DirectoryInfo` objects and `EnumerateFileSystemInfos()`, count regular entries, and never
push reparse directories. Hash the four exact files above with `Get-FileHash -Algorithm SHA256` and
read `Baldur.exe`'s `VersionInfo.FileVersion`. For log facts, select only the named component entries;
do not export the full log. Query fixed-volume capacity and game/loader process executable paths;
retain personal paths only locally.

Documents check: `[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)`, followed
by `Get-Item -LiteralPath` for attributes. No traversal or save reading is required to reproduce the
observed guard conflict. A future native reparse-tag investigation is separate, not implied here.

**Counterevidence:** Log names are not binary/provenance proof; matching SCS version labels do not
make the other stack versions match. Attribute-only enumeration misses hard-link identity. A unique
engine name does not neutralize cloud/reparse ancestors. Process enumeration is not proof that
every file is unlocked. Ample-looking free space is not a fully costed copy/reset plan.

**Artifacts:** This authored redacted memo, local ignored request, four fingerprints and pinned
collection blob identities. No game resources, logs, saves, config payloads or decompiles committed.

**Applicable evidence:** E1 bounded static/metadata observations; E0 upstream documentation input.
No provisioning, compiler, installer, reset or engine proof. Host validations recorded below do not
promote these observations to runtime acceptance.

**Residual uncertainty:** Full source/native identity manifest, store provenance, actual EEex
binary identity, exact mod-source revisions, complete writable roots, non-cloud runtime save
isolation, operational guards and copy/reset acceptance remain outstanding.

**Next decision:** Retain the older runtime candidate or approve a separately researched newer
runtime profile before engine use; resolve a supported non-cloud save/config route without changing
the user's global Documents setting. The approved offline copy can be prepared independently once
its guarded host implementation is reviewed. Never substitute the currently running game.

**Verification:** `python -X utf8 -m pytest -q`: 483 passed in 57.35 seconds. Both
`scripts/validate-g0-decisions.ps1` and `scripts/validate-g0-namespace.ps1` passed;
`scripts/test-g0-line-endings.ps1` passed its LF and CRLF cases. `git diff --check` and seven
changed-document relative links passed. The ignored local request was confirmed excluded by
`.gitignore`; the source executable and installation-log hashes were rechecked unchanged and the
destination still did not exist. Independent Astra review accepted this five-file preflight
packet, with the wording clarification above. No production code was added, so no new production
RED/GREEN cycle is claimed; the next implementation packet must start with the planned failing
tests. These checks do not complete Task 3 or pass G1.
