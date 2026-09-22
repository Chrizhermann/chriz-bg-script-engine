# Disposable engine laboratory runbook

**Status:** Task 3 authorized and in preflight; no laboratory has been provisioned

**Date:** 2026-08-31

**Owners:** Integration owner

**Authorization boundary:** Task 3 requires a separate user approval that names the destination.
This document is not that approval.

**Current checkpoint — 2026-09-22:** The user approved the exact proposed SCS-reference destination.
[The authorization/source-preflight memo](disposable-lab-provisioning.md) records the scope and local
request location. No copy or game mutation has occurred. The older historical checkpoint statements
below describe the earlier run, not the current authorization state.

## Purpose

This runbook defines how a later Task 3 must create, validate, operate, reset, and retire an isolated
BG2:EE plus EEex laboratory without writing to the active installation, active save tree, or shared
loader/user state. It records the procedure now so later evidence is reproducible. Every command in
the provisioning, launch, save, reset, or removal phases remains unexecuted at this checkpoint.

The current `scripts/check-dev-environment.ps1` is a read-only post-provision preflight. It neither
creates a marker nor authorizes a write. A safe result is valid only for the paths checked at that
moment; the future Task 3 scripts must repeat the checks immediately before each mutation.

## Accepted lab direction — 2026-09-22

The user accepted a small EET lab and clarified these choices:

- Retain a minimal EET plus EEex/LuaJIT reset baseline for diagnosis. Include Bubb's Spell Menu
  in the normal testing setup as a quality-of-life preference, recording its version/component.
  Its inclusion is not a claim of zero possible UI or runtime interaction.
- Establish an exact SCS comparison profile early for corpus research and behavior migration.
  SCS is the primary source and intended long-term runtime replacement target for the supported
  corpus; its absence from the diagnostic baseline does not reduce that role.
- If the existing heavily modded Chriz Easy BG installation is used, work on a separate copy.
  The existing installation remains a reference, with no lab writes or test saves directed there.
- Reuse the build recipe and save-identity approach already implemented in `chriz-bg-collection`.
  DLCMerger and separate save/configuration identities are established implementation references,
  not new open-ended research questions. Keep the exact source/version and lab-specific checks.

Read-only reference inspection used `chriz-bg-collection` branch `codex/installer-v0-real-alpha`,
commit `32ab76df7ed52054c3e3534a7fee5c3bbff2daa1`:

- `manifest/mods/dlcmerger.toml` and `manifest/artifacts/dlcmerger-2.1.toml` specify DLCMerger
  2.1, component 1, and artifact SHA-256
  `ea7584fd7285330cfaa52cfc217677ef4f8cf8151fdec666ea8af199e479db0e`.
- `manifest/reference/bg1-premerge-approved.toml` places it in the copied BG1 preparation phase.
  Reusing that step does not select all other components in the collection's recipe.
- `engine/src/stage.rs` derives/reserves a distinct Documents identity using `engine_name`,
  isolates the staged BG1 source, and reapplies/verifies the BG2 identity after EET finalization.
- `engine/tests/stage.rs` contains the identity/collision and post-EET reapplication regression
  cases. This inspection did not execute those tests or launch a game.

These are E1 static implementation references, not completed isolation evidence for this lab.
The collection checkout also contains ongoing edits; only the committed behavior above is used
as the pinned reference. Its broader mod preset and game/EEex version choices are not silently
adopted. PREP-01's fresh-build source profile still needs to be recorded, using these existing
references, before construction. Lab-specific writable-root guards and reset proof remain Task 3.

No new lab destination or provisioning authorization was given in this clarification. Task 3
remains pending; this section records the agreed approach without performing provisioning.

## Offline-reference acquisition amendment — 2026-09-22

The subsequently approved source differs from PREP-01's runtime candidate. The independently
reviewed distinction in [the preflight memo](disposable-lab-provisioning.md) permits preparing a
guarded unchanged **offline-only** reference copy without changing that runtime candidate.
It is not an engine lab, remains unprovisioned today, and must not receive the normal
`.bgse-disposable-lab.json` readiness marker. Copied user-directory configuration is not isolated
merely by copying; launch, loader/native execution, installs and save use remain prohibited until
the engine profile and complete writable-root contract are admitted.

The offline route still requires a reviewed fresh-destination bootstrap guard, no-follow child
inventory, hard-link/native identity checks, process/capacity checks and complete copy verification.
The current Task 2 checker cannot authorize that new-root operation. No new implementation or copy
is claimed by this amendment. The engine route below still requires matching/admitted fingerprints,
multi-root isolation and all of Task 3's acceptance checks. The observed cloud/reparse Documents
root is a real unresolved guard conflict; never waive it or change global Windows settings silently.

## Stop conditions

Stop before any write unless all of the following are true:

1. The user has explicitly authorized Task 3 and named one absolute destination.
2. The active source root and the destination have been supplied explicitly; neither is inferred,
   searched for, or selected from a conventional game path.
3. No game, InfinityLoader, EEex loader, WeiDU, Near Infinity, or lab helper process is using either
   tree.
4. The destination, every existing ancestor, and every intended target have passed the same lexical,
   reparse, hard-link, physical-identity, marker, and containment guards used by the environment
   checker.
5. The destination is a fixed local volume with sufficient free space under the formula in the host
   toolchain decision.
6. The planned game install, user/documents root, saves, configuration, logs, crash dumps, loader
   state, and reset baseline are independent of the active profile.

Stop immediately after a native crash, unexpected process, path/identity change, marker mismatch,
copy outside the allowlist, shared writable target, failed fingerprint, or reset mismatch. Preserve
the evidence and do not retry the same native call shape blindly.

## Roles and paths

The later authorized session must define these values in one PowerShell 7 process without printing
them into committed logs:

```powershell
$env:BGSE_ACTIVE_GAME_ROOT = '<explicit user-supplied active root>'
$env:BGSE_DISPOSABLE_GAME_ROOT = '<explicit user-approved destination>'
$labDocumentsRoot = '<explicit isolated user/documents root>'
$evidenceExportRoot = '<explicit sanitized export root outside both game trees>'
```

These are four different physical ownership domains. A child, parent, junction, short-name alias,
volume alias, shared cloud folder, or shared writable target is not independent.

## Phase 0: authorization record

Before provisioning, record in the Task 3 evidence memo:

- the exact user-approved destination (kept local/redacted from commits);
- approval date and scope;
- active source and destination physical volume/file identities in local evidence;
- game/EEex/source fingerprints permitted by PREP-01;
- planned documents/save/log/loader roots;
- required capacity and the measured free-space snapshot;
- every intended write path and process name; and
- rollback/removal owner.

General approval of the roadmap, this runbook, Task 2, or host-side tests is not Task 3 approval.

## Phase 1: RED and `-WhatIf` provisioning contract

Task 3 first adds `tests/tooling/test_disposable_reset_contract.py`. Its temporary-directory cases
cover exact active root, active descendant, case and 8.3 alias, relative traversal, device/UNC path,
symlink, junction/reparse point, output escape, missing marker, marker above/below the root, shared
user directory, and non-idempotent reset. The first run must fail because the provisioning/reset
script is absent.

Implement `scripts/provision-disposable-lab.ps1` and `scripts/reset-disposable-lab.ps1` with
`SupportsShouldProcess`/`-WhatIf` before any real copy or reset. `-WhatIf` must still resolve and
report sanitized decisions, but it must not create a directory, marker, baseline, log, or process.

## Phase 2: capacity and source inventory

After authorization, compute a read-only manifest of the named source. Do not copy source paths or
proprietary file contents into the repository. Retain locally:

- source game build and executable fingerprints;
- EEex loader/runtime fingerprints and layout;
- file count and total bytes;
- user/documents, save, configuration, logs, and crash-dump locations;
- reparse points and writable external targets; and
- source processes/locks.

Required free space is:

```text
independent working copy
+ independent reset baseline
+ worst-case WeiDU backup/output/evidence allowance
+ explicit safety reserve
```

If the exact source size or a reset/backup allowance is unknown, capacity is not proven and
provisioning stops. Hard links, junctions, shared files, and assumed compression savings do not count
as capacity. An existing file with more than one hard link is refused, even if both observed names
appear to be inside the lab.

## Phase 3: isolated copy and marker

Only the authorized Task 3 script may perform this phase.

1. Revalidate source, destination, ancestors, intended targets, fixed-volume status, process state,
   and free space immediately before copying.
2. Create a new destination without following reparse points and copy ordinary files/directories.
   Do not hard-link, junction, deduplicate, or redirect writable state into the source.
3. Compare the copied inventory with the source manifest. Quarantine any unexpected external target,
   missing file, or changed source fingerprint.
4. Configure a distinct documents/save/config/log/loader profile. Prove no writable identity is
   shared with the active profile.
5. Only after isolation passes, create exactly one regular UTF-8 marker at the destination root:

```json
{
  "schemaVersion": 1,
  "markerType": "chriz-bg-script-engine-disposable-lab",
  "createdByTask": 3,
  "labId": "<new UUID version 4>"
}
```

Additional source/version metadata may be present, but the four fields above are mandatory. The
marker must be at `.bgse-disposable-lab.json` in the exact lab root, no larger than 4096 bytes, and
must not be a symlink, reparse point, or hard link. Never copy or link a marker from another lab.

6. Create the independent reset baseline and its manifest only after the marker and isolation proof
   pass. The baseline is not a junction or hard-linked view of the working copy.

## Phase 4: read-only preflight

From PowerShell Core `>=7.4,<8`, list every path the next operation could write:

```powershell
$plannedWrites = @(
    (Join-Path $env:BGSE_DISPOSABLE_GAME_ROOT 'override\planned-output-file'),
    (Join-Path $env:BGSE_DISPOSABLE_GAME_ROOT 'weidu-backup\planned-backup-file')
)

& ./scripts/check-dev-environment.ps1 -IntendedWritePath $plannedWrites
if ($LASTEXITCODE -ne 0) {
    throw 'Disposable-lab preflight refused; inspect the sanitized code and stop.'
}
```

That invocation covers only exact game-tree targets. The current Task 2 checker accepts only targets
physically under `BGSE_DISPOSABLE_GAME_ROOT`; it does not validate the separate documents or evidence
roots named above. Task 3 must stop until it has a separately reviewed, equally guarded multi-root
contract for those roots (or a reviewed replacement ownership layout). It also refuses an existing
directory as an unbounded recursive write scope: list exact file targets, or make the future Task 3
operation-specific guard enumerate and validate every descendant before a recursive operation. Do
not weaken containment ad hoc.

A successful result has code `BGSE_OK` and reports each safety check as `verified`. Capability
statuses remain independent: command lookup reports only `discoverable` plus `unexecuted`, registry
inspection may report `metadata-present`, and `unavailable` or `unexecuted` never means pass.

| Exit | Code family | Required response |
|---:|---|---|
| 0 | `BGSE_OK` | Continue only with the exact checked paths and an immediate mutation-time recheck |
| 2 | required environment, unsupported host/path/volume, missing root/target | Correct configuration; do not write |
| 3 | active overlap, marker, reparse/hard link, directory scope, changed identity, write escape | Safety refusal; stop and investigate |
| 4 | checker/native resolution failure | Treat as unsafe; preserve sanitized evidence and stop |

## Phase 5: launch and evidence capture

Launch is prohibited until an authorized Task 3 has proved isolation. The launch wrapper must:

1. repeat path, marker, identity, process, and writable-root checks;
2. select the copied executable and isolated documents/configuration explicitly;
3. record exact executable/game/EEex fingerprints and sanitized command shape;
4. capture logs, crash dumps, engine ticks, save timestamps, and test IDs in the lab evidence root;
5. verify an independent postcondition after queued EEex work—queue acceptance is never execution
   proof; and
6. stop on native crash or unexpected access to the active profile.

No experiment may reuse an active-playthrough save. Test saves have a unique lab/test identifier and
stay inside the isolated writable profile.

## Phase 6: orderly shutdown and crash handling

For an ordinary run, request normal game shutdown, wait for process exit, verify all related lab
processes ended, flush/copy evidence, then hash the retained artifacts.

For a hang or crash:

1. record process state, timestamps, dump/log locations, active test ID, and the exact last capability
   or native call shape;
2. terminate only the verified lab process tree if normal shutdown cannot complete;
3. never kill a process identified only by a generic name without verifying its executable belongs
   to the lab;
4. export evidence before reset; and
5. mark the experiment failed and require review before a changed retry.

## Phase 7: deterministic reset

The reset script must revalidate every exact target immediately before mutation. It must refuse while
any lab process runs, preserve/export declared evidence, restore only allowlisted lab-owned state from
the independent baseline, and never follow a newly introduced reparse point.

Run the reset contract twice. After each reset compare:

- game and EEex file manifests;
- override and WeiDU backup state;
- isolated documents/configuration;
- saves, logs, crash artifacts, and temporary outputs under their declared retention policy;
- marker identity/content; and
- absence of any active-profile change.

Both resets must converge byte-for-byte on the declared baseline/volatile-state policy. A missing,
extra, aliased, or changed protected file fails the reset proof.

## Phase 8: evidence retention and retirement

Evidence exports contain stable test IDs, hashes, versions, relative paths, commands, expected and
observed outcomes, and sanitized logs. They do not contain proprietary game resources, saves, TLK
content, credentials, personal absolute paths, or raw memory dumps in Git.

Lab retirement is a separate destructive operation. Before removal, verify the exact authorized lab
identity and marker, prove no process uses it, export evidence, and use a recoverable removal method
where practical. Never derive a recursive-delete target from an unresolved environment variable.

## Acceptance checklist

Task 3 is not complete until:

- authorization names the destination;
- guard tests show intentional RED then GREEN;
- copy and every writable profile are physically isolated;
- the exact-root UUID marker passes;
- the environment checker passes with all intended targets;
- one launch/save/postcondition cycle is independently observed;
- crash cleanup is rehearsed without a native crash retry;
- reset passes twice against the baseline;
- evidence is sanitized and reproducible; and
- no active game, save, configuration, or loader state changed.

At this Task 2 checkpoint none of those Task 3 acceptance items has been executed. No directory has
been selected, provisioned, launched, reset, or removed.
