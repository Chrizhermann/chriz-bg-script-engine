# Script Engine Research and Vertical-Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

> **For Codex:** REQUIRED SKILL: Use `executing-plans`; use `subagent-driven-development` for
> bounded parallel tasks after their shared schemas are frozen.

**Goal:** Prove and build a compatibility-first EEex scripting kernel, a shadow-to-active
Combat Intent mage/prebuff pilot, and a fault-tolerant synthetic WorldFlow quest without ever
claiming unknown BCS/DLG content.

**Architecture:** A narrow EEex boundary feeds scalar snapshots into a pure Lua policy core.
Install-time inventory and exact dependency hashes determine initial adapter eligibility; semantic
fingerprints remain disabled until loss-aware IR/canonicalization research proves them. Runtime
leases and durable claims arbitrate ownership; tiny BCS/DLG bridges preserve ordinary engine
semantics and legacy fallthrough. Combat Intent and WorldFlow share mechanisms but retain separate
policy, lifecycle, persistence, and failure semantics.

**Tech Stack:** Lua 5.1-compatible policy/runtime code for EEex/LuaJIT, WeiDU for reversible
installation and BAF/DLG compilation, Python 3 plus `pytest` for host-side tooling and model tests,
PowerShell for Windows lab orchestration, JSON/JSONL for host artifacts, generated Lua tables for
runtime manifests. Host interpreter floors are recorded in ADR 0006; embedded-runtime and compiler
support remains gated by PREP/EEEX research.

---

**Status:** In execution; canonical per-task state is recorded in the task-state file below

**2026-09-27 user priority reset:** Keep the full feature ambition and good code quality. Use a
practical "good enough" standard for lab setup, tooling and process. First get a separate,
resettable test game, then migrate and test useful behavior. Reuse or take inspiration from the
item-randomizer lab. The later custom offline-acquisition packets A-E are not lab prerequisites
and must not be expanded further. Representative feature/script-family tests replace any
assumption that every encounter or hypothetical setup failure must be covered. Keep active
game/save isolation, user-owned gameplay decisions and honest evidence boundaries. This update
supersedes conflicting process requirements below; historical results remain evidence, not a
reason to continue an unnecessary subsystem.

**Date:** 2026-08-27

**Plan path:** `docs/plans/2026-08-27-research-and-vertical-slices.md`

**Task state:** `docs/plans/2026-08-27-research-and-vertical-slices.md.tasks.json`

## 1. Execution contract

This is a dependency-ordered program plan, not blanket authorization to run every task. Each gate
must be recorded as a decision before downstream tasks begin. A negative research result is a valid
outcome: narrow the adapter, change the bridge, or stop the affected branch.

The following rules apply to every task:

1. Read `AGENTS.md`, the architecture design, the applicable research-spike entry, and the relevant
   compatibility cases before acting.
2. Use the `bg-modding` and `eeex-api` skills for engine/WeiDU work; use
   `bg-modding-learn` only to record a verified reusable fact, never a project hypothesis.
3. Write the smallest failing host, fixture, or engine test before production behavior.
4. Preserve the intentional RED result as evidence in the task memo or commit description.
5. Never write to the active game. An engine experiment requires a named disposable environment.
6. Do not commit upstream binaries, generated SCS BCS, saves, TLK content, or full decompiles.
7. Stop immediately on a native crash, ownership ambiguity, failed fingerprint, or unclassified
   irreversible side effect; capture evidence and quarantine only the affected adapter.
8. Run checks relevant to the changed behavior and affected dependencies, then `git diff --check`.
   Run wider regression when integration risk warrants it, not for every documentation edit.
   Do not increase test scope merely to justify unused setup machinery.
9. Keep one research question or one coherent behavior slice per commit.
10. Update the task JSON and the associated gate/decision record after review.

A task's **Research linkage** means that it uses or advances those backlog issues. It closes an ID
only when that issue's own exit criterion and evidence target are met. Partial work records a link
and remaining evidence; it never marks the whole spike complete by association.

## 2. Required reading and authoritative artifacts

- `docs/plans/2026-08-27-script-engine-architecture-design.md`
- `docs/research/research-backlog.md`
- `docs/compatibility/acceptance-matrix.md`
- `AGENTS.md`
- BG modding knowledge-base references selected by its `INDEX.md`, especially
  `scs-compatibility.md`, `ie-scripting.md`, `eeex-actions.md`, `eeex-persistence.md`,
  `eeex-sprites.md`, `weidu.md`, and `weidu-testing.md`

Research memos are authoritative only for the exact environments and evidence layers they name.
Support manifests and effective resource fingerprints outrank remembered install details.

## 3. Program dependency map

```text
E0  Charter, compatibility invariant, provenance policy
├── E1  EEex / engine / SCS research
└── E2  Disposable lab, corpus, fixtures, ownership manifest

E1 + E2 ─────────────> E3  Shared kernel: observer, capabilities, leases, fallback
E3 ──────────────────> E4  Combat Intent shadow pilot
E4 ──────────────────> E5  Active one-action pilot
E5 ──────────────────> E6  SCS-family migration and economics gate
E3 + E5 ─────────────> E7  Synthetic WorldFlow laboratory
E7 ──────────────────> E8  Selected real-flow migrations

E2 ──────────────────> E9a IR, lint, replay, provisional internal registration
E5 + E8 + E9a ───────> E9b Stable third-party extension API
E6 + E8 + E9b ───────> E10 Supported-alpha hardening
E10 ─────────────────> E11 Deliberate supported-corpus expansion
```

The `E0` through `E11` identifiers in dependency maps and phase headings are program epics.
Evidence grades are written as `evidence:E0` through `evidence:E5`, and epic labels as `epic:E0`
through `epic:E11`. Bare `E*` references are not used where the namespace is ambiguous.

WorldFlow research may run beside Combat Intent research after epic E3. WorldFlow may not schedule a
persistent world mutation until the action observer, ownership handoff, adapter quarantine, and
save/load behavior have passed the relevant epic E3 and G5 tests.

E9 is one epic with two maturity stages: internal analysis/registration structures may begin after
E2, but the public SDK is not frozen until one real Combat Intent adapter and one real WorldFlow
adapter have tested its abstractions.

## 4. Board and epic structure

Use one project board with these statuses:

```text
Research -> Design review -> Ready -> In progress -> Simulation verified
         -> Disposable-game verified -> Compatibility verified -> Done
```

Each issue carries:

- `epic:E0` through `epic:E11`;
- `area:kernel`, `area:combat-intent`, `area:worldflow`, `area:adapter`, `area:tooling`,
  `area:packaging`, or `area:research`;
- every `evidence:E0` through `evidence:E5` layer actually reached and still applicable;
- `compat:C0` through `compat:C4` where applicable;
- `env:host`, `env:synthetic`, `env:disposable`, or `env:soak`;
- `priority:P0`, `priority:P1`, or `priority:P2`;
- `risk:native-crash`, `risk:save`, `risk:ownership`, `risk:install-order`,
  `risk:redistribution`, or `risk:performance` where applicable;
- upstream version/component and a provenance link for derived work;
- prerequisites, gate contribution, acceptance IDs, and explicit non-goals.

Issue titles use stable IDs from the research and compatibility backlogs, for example:
`EEEX-03: Prove action-start and completion observers` or
`COMP-B07: Legacy fallthrough after lease revocation`.

## 5. Gates and stop/go decisions

| Gate | Entry | Required exit evidence | Failure response |
|---|---|---|---|
| **G0 Charter** | Architecture draft and naming decision | Approved charter, compatibility invariant, safety boundary, non-goals, provenance policy, task map | Resolve design conflict; no runtime work |
| **G1 Bridge feasibility** | PREP complete; disposable environment explicitly authorized, provisioned, isolated, and reset-tested | Capability profile; safe hook lifecycle; BCS/Lua handoff; normal action and dialogue initiation; action observations; persistence lifecycle; crash and reload procedure; evidence E4 probe results | Narrow supported EEex profile or stop native branch |
| **G2 Unknown pass-through** | Manifest and ownership schemas drafted | Static eligibility plus runtime lease proven; unknown/modified/stale resources remain C0; any post-install drift remains stale with no reactivation; per-adapter quarantine; install-order invalidation; core `COMP-I/B/D/P` tests | Disable takeover path; redesign bridge |
| **G3 Observer** | G1 and G2 pass | Kernel can observe and explain supported actors without queueing actions or changing world state; bounded performance; save/load clears ephemeral handles | Remain research-only |
| **G4 Combat shadow** | G3; mage family ledger; frozen snapshot/candidate schemas | Mage/prebuff decisions replay deterministically, obey perception/fairness, compare against legacy/SCS oracle, never dispatch; evidence E4 arena proof | Revise model or abandon family |
| **G5 Active combat** | G4; action observer and kill switch proven | One ordinary action per lease; revalidation; aura/resource expenditure; started/completed/failed/unknown outcomes; immediate legacy handback; save/load and interruption tests | Return pilot to shadow-only |
| **G6 Migration economics** | At least one active family and one additional shadow family | Measured person/agent time, fixture cost, exception count, runtime cost, regression rate, and SCS knowledge-retention score fit declared budget | Invest in IR/tooling or stop broad migration |
| **G7 WorldFlow convergence** | Epic E3 and G5 stable; durable schema approved; persistent mutation specifically approved | Synthetic quest converges across normal/skip/recovery/save/load/upgrade/disable paths; no duplicate reward/spawn/journal; public ABI and handback proven | WorldFlow remains observer/linter-only |
| **G8 Supported alpha** | G5, G7, packaging and matrix candidates | Exact support manifest; installer rollback; diagnostics; provenance/license allowlist; performance budget; supported-corpus soak; known limitations | No release; quarantine failed families |

No date, token budget, or amount of completed code can waive a failed gate.

## 6. Commit and review discipline

Expected commit sequence for an implementation task:

```text
test: specify <one invariant>
research: record <one experiment>          # research task only
feat: implement <one minimal behavior>     # production task only
docs: record <gate or support decision>
```

A small task may combine the test and minimal implementation in one reviewed commit only when the
intentional RED output is preserved in the issue/memo. Never mix an upstream corpus import, public
schema change, native hook, behavior rule, and fixture rewrite in one commit.

Integration review checks:

```powershell
python -m pytest -q
git diff --check
git status --short
```

Add Lua, WeiDU, packaging, and disposable-engine commands only after PREP tasks freeze their exact
paths. A missing tool means the check is unexecuted, not passing.

## 7. Phase A — Charter, lab authorization, evidence, and corpus (E0-E2)

### Task 1: Freeze the architectural decisions as ADRs

**Depends on:** none

**Files:**

- Create: `docs/decisions/0001-legacy-ownership-by-default.md`
- Create: `docs/decisions/0002-separate-combat-intent-and-worldflow.md`
- Create: `docs/decisions/0003-weidu-remains-installer-of-record.md`
- Create: `docs/decisions/0004-evidence-and-environment-gates.md`
- Create: `docs/decisions/0005-scs-provenance-and-reuse.md`
- Create: `docs/decisions/0006-runtime-and-host-language-boundaries.md`
- Create: `docs/decisions/template.md`
- Create: `docs/decisions/gates/G0-charter.md`
- Create: `scripts/validate-g0-namespace.ps1`
- Create: `scripts/validate-g0-decisions.ps1`

**Steps:**

1. Copy the decision, context, alternatives, consequences, compatibility effect, evidence basis,
   reversal condition, and review date into each ADR.
2. Mark ADR 0006 `provisional` until Task 2's host/runtime toolchain decision is complete.
3. Verify every ADR names unknown-content pass-through and the active-game boundary where relevant.
4. Record G0 as passed only after confirming the initial platform, unique namespace, support tiers,
   kill-switch policy, non-goals, SCS attribution policy, and separation of ephemeral Combat Intent
   from durable WorldFlow state.
5. Run:

   ```powershell
   & ./scripts/validate-g0-decisions.ps1
   ```

   Expected: exit 0 with every required ADR and gate-record field reported present.
6. Commit: `docs: record script engine architecture decisions`.

**Exit:** G0 has durable, independently reviewable decisions rather than one monolithic document.

### Task 2: Establish the development and disposable-lab contract

**Research linkage (not automatic closure):** PREP-01, PREP-03

**Depends on:** Task 1

**Artifact checkpoints:** Task 2 first publishes and reviews
`docs/research/PREP-01-support-baseline.md`. That artifact, rather than completion of Task 2's
independent checker, toolchain, and runbook work, releases Task 4's PREP-02 spike. Task 2 may
continue those independent steps, but it must not begin or close PREP-03 until Task 4 publishes and
reviews `docs/research/PREP-02-evidence-and-provenance-index.md`.

**Files:**

- Create: `docs/research/PREP-01-support-baseline.md`
- Create: `docs/research/host-runtime-toolchain-decision.md`
- Create: `docs/research/disposable-lab-runbook.md`
- Create: `docs/research/PREP-03-failure-safety-compatibility-threat-model.md`
- Create: `scripts/check-dev-environment.ps1`
- Test: `tests/tooling/test_environment_contract.py`
- Create: `pyproject.toml`

**Steps:**

1. Inventory the current game/EEex/WeiDU/EET/SCS/Spell Revisions ecosystem, upstream revisions,
   operating-system constraints, and install-order assumptions read-only. This research step may
   precede the checker test because it writes no production code and is required to define PREP-01.
2. Complete the PREP-01 support baseline with exact dependency states, versions/revisions where
   available, capability assumptions, and deterministic non-claim behavior for every unsupported or
   uncertain case.
3. Review PREP-01 against its backlog exit criterion, run `git diff --check`, and make the narrow
   artifact-checkpoint commit `research: pin initial support baseline`. This checkpoint releases
   Task 4's PREP-02 work; Task 2 remains `in_progress`.
4. Write a failing test that invokes the environment checker with a fixture path matching the
   documented active game and expects a hard refusal before any file write.
5. Run `python -m pytest tests/tooling/test_environment_contract.py -q`; expected: FAIL because the
   checker does not exist.
6. Inventory Python, Lua/LuaJIT candidates, Near Infinity, decompiler
   commands, path/encoding constraints, and disposable-disk requirements without modifying a game.
7. Implement the minimal read-only checker. It must require an explicit
   `BGSE_DISPOSABLE_GAME_ROOT`, resolve the canonical absolute target and every ancestor, reject the
   known active-game root and all descendants/aliases, reject symlinks/junctions/reparse points that
   resolve into or out of the disposable root, reject any intended write target escaping that root,
   reject a root without a disposable marker file, and print capability results without secrets.
8. Run the focused test; expected: PASS for a temporary marked fixture and PASS-by-refusal for the
   active path.
9. Create a clean disposable-lab runbook covering copy creation, marker, launch, log capture, save
   reset, crash detection, process shutdown, restore, and evidence retention. Do not create the
   actual game copy without explicit approval.
10. Decide the host test/runtime toolchain in ADR 0006 and document unsupported alternatives.
11. Stop at the PREP-02 artifact barrier if Task 4 has not published and reviewed
    `docs/research/PREP-02-evidence-and-provenance-index.md`. Once it has, complete the PREP-03 risk
    register with prevention, detection, fallback, recovery, responsible subsystem, and planned
    validation for every critical failure class.
12. Run the full host suite and commit: `test: establish safe development environment contract`.

**Exit:** repeatable commands exist, but no active or disposable game has been mutated merely by
running the checker.

### Task 3: Obtain authorization and provision the disposable engine laboratory

**Current direction — 2026-09-27:** Keep the approved architecture and full feature plan.
Use a practical lab: separate game copy, separate saves/configuration, simple reset/rebuild,
then representative migration tests. Custom acquisition/process/copy packets A–E are abandoned
as a prerequisite; do not finish them before useful mod work.

**Research linkage (not automatic closure):** TEST-05, TEST-06, LIC-03

**Depends on:** Task 2 plus explicit user authorization naming the disposable destination

**Current checkpoint:** The previously approved SCS-reference copy is verified: 164,610 files,
reported 11.164 GiB, zero failed files/mismatches. The lab has its own engine profile identity;
a lab-only configuration backup/restore check passed. One authorized backend-only startup and
fresh Remote Console ping passed after peer coordination, with new configuration in the dedicated
lab profile. Owned processes and temporary probe files are cleaned up; no computer control or
active saves used. Save routing is still unverified: no permitted backend-only save route has
been established. Continue static SCS research on the copy. Task 3 is not complete.

**Procedure:** [Practical lab runbook](../research/disposable-lab-runbook.md).
Exact paths, commands, results and cleanup candidates stay private under `.work/task3`.

**Steps:**

1. Use the exact user-approved source and fresh destination. Check available disk space and
   avoid interfering with an actual source install or game session.
2. Make the ordinary file copy using existing tools. Preserve and diagnose an actual failure;
   a disposable lab may be rebuilt without a custom transactional copier.
3. Set a unique lab `engine_name`; do not copy the active profile or change global Documents
   settings. Check expected game files and loader/output paths, and record the copied stack.
4. Check copied console/automation hooks before launch. After separate launch permission,
   create a test save and confirm the engine uses only the dedicated lab profile.
5. Exercise a practical restore of the files changed by one experiment. Document full rebuild
   as the fallback; do not require a second full game baseline or exhaustive failure simulation.
6. Record results honestly, keep game resources/private logs out of Git, and make a narrow
   documentation/setup commit. Preserve G0–G8 and user-owned creative/gameplay decisions.

**History:** The earlier source measurements and synthetic acquisition helpers are recorded in
their research memos and Git history. The last full host checkpoint had 1,146 passing tests;
that was not a usable lab or gameplay evidence. It does not justify continuing that subsystem.

**Exit:** A named, resettable, separate lab works, including one authorized launch/save check.
No runtime task may substitute the active installation while this exit remains open. Safe static
Task 6 research may proceed on the copy in parallel.

### Task 4: Define evidence, fixture, corpus, and redistribution governance

**Research linkage (not automatic closure):** PREP-02, TEST-01, TEST-02, LIC-01 through LIC-04

**Depends on:** Task 1 plus Task 2's reviewed `docs/research/PREP-01-support-baseline.md` artifact;
Task 2 need not be complete

**Artifact checkpoint:** PREP-02 is the first independently reviewed output of this task. Publishing
`docs/research/PREP-02-evidence-and-provenance-index.md` releases Task 2's PREP-03 work while the
remaining fixture, licensing, and redistribution governance continues here.

**Files:**

- Create: `docs/research/evidence-template.md`
- Create: `docs/research/PREP-02-evidence-and-provenance-index.md`
- Create: `docs/provenance/artifact-policy.md`
- Create: `docs/provenance/upstream-register.md`
- Create: `docs/provenance/fixture-allowlist.md`
- Create: `schemas/research-evidence.schema.json`
- Test: `tests/schemas/test_research_evidence_schema.py`

**Steps:**

1. Write failing schema tests for missing environment, versions, method, artifacts, evidence grade,
   counterevidence, residual uncertainty, and next decision.
2. Run the focused test; expected: FAIL because the schema is absent.
3. Define classifications for independently authored metadata, short factual extracts, generated
   fingerprints, locally generated effective artifacts, redistributable synthetic fixtures,
   upstream source, and forbidden packaged content.
4. Implement the minimum schema, template, and evidence index needed to satisfy PREP-02. Validate a
   sample Combat Intent rule and WorldFlow compatibility contract end-to-end without consulting the
   active game or personal memory.
5. Record SCS's exact source/version and reuse statement as E1 pinned static evidence. Record any
   interpretation of what that statement permits separately as an E0 claim or policy decision; it
   is not legal advice and does not itself authorize redistribution.
6. Run focused schema tests and `git diff --check`, review PREP-02 against its backlog exit criterion,
   and make the narrow checkpoint commit `docs: establish evidence and provenance ledger`. This
   releases Task 2's PREP-03 step; Task 4 remains `in_progress`.
7. Complete the remaining provenance classifications and validate one positive and one negative
   fixture.
8. Verify the fixture allowlist excludes full SCS source/generated BCS, installed binaries, TLK,
   saves, and personal-path logs.
9. Run focused and full tests; commit: `docs: define fixture and provenance governance`.

**Exit:** every future fixture and migrated behavior has a place, an owner, its applicable evidence
layers, and a distribution decision.

### Task 5: Build the effective-install inventory and exact ownership-manifest prototype

**Research linkage (not automatic closure):** IR-01, IR-02, TEST-03

**Depends on:** Tasks 2 and 4

**Files:**

- Create: `schemas/install-manifest.schema.json`
- Create: `schemas/resource-claim.schema.json`
- Create: `tools/corpus/inventory.py`
- Create: `tools/corpus/exact_hash.py`
- Test: `tests/tooling/test_inventory.py`
- Test: `tests/tooling/test_exact_hash.py`
- Create: `docs/research/IR-01-inventory-and-fingerprint.md`

**Steps:**

1. Write failing tests for deterministic ordering, stable path redaction, exact full-resource hash
   capture, script-slot inventory, dependency edges, public-variable declarations, opaque nodes,
   and rejection of ambiguous claims.
2. Run the focused tests; expected: FAIL because tools/schemas do not exist.
3. Implement inventory against compact synthetic fixtures only. Output canonical JSON with no
   absolute source path.
4. Implement exact full-resource and declared-dependency hashes only. Unknown record forms are
   opaque and make a claim ineligible. Semantic canonicalization may be emitted as experimental
   analysis later, but cannot activate an adapter before the loss-aware IR and counterexample suite
   pass.
5. Generate a manifest twice from the same shuffled fixture; expected: byte-identical output.
6. Mutate any byte in a claimed resource or declared dependency; expected: the initial claim
   invalidates. Record harmless over-invalidation as an accepted conservative cost, not a reason to
   weaken the hash.
7. Record limits, exact-hash over-invalidation, and future semantic-canonicalization hazards in the
   research memo.
8. Run tests and commit: `feat: add conservative install inventory prototype`.

**Exit:** epic:E2 can identify exact resources and reject uncertainty with no selective semantic
match; it does not yet activate runtime ownership.

### Task 6: Characterize the SCS combat corpus and create migration ledgers

**Research linkage (not automatic closure):** SCS-01 through SCS-06

**Depends on:** Tasks 4 and 5

**2026-09-27 continuation:** The [first installed mage/prebuff comparison](../research/2026-09-27-scs-effective-mage-pilot.md)
now records MAGE6B's effective slots, selected prebuff branches and byte-identical WeiDU
decompile/recompile. This supersedes the missing-effective-sample portion of the historical
checkpoint below, not its remaining semantic/control-closure and reuse limits. Task 6 stays open.

**2026-09-28 continuation:** The [higher-level dispel comparison](../research/2026-09-28-scs-high-mage-dispel.md)
adds MAGE18B's actual target selectors, action alternatives and weighted skip/timer behavior.
Its BCS roundtrip is byte-identical. This is offline mapping, not runtime acceptance; no new
lab tooling or gameplay/design decision is introduced.

**2026-09-22 checkpoint:** In progress. The reviewed
[pinned-source mage/prebuff checkpoint](../research/2026-09-22-task6-source-checkpoint.md)
records source identities, two ledgers and bounded observations. Effective generated-script
comparison, remaining source/control tracing and derived-fixture admission are still required;
this is not the Task 6 exit or a gate pass. Task 3 authorization remains separate.
The [shared-rule continuation](../research/SCS-shared-rule-expansion.md) adds ordered-library,
macro merge, compiler response and conditional CRE insertion source evidence. It does not supply
the missing effective artifacts or a semantic oracle.

**Files:**

- Create: `docs/research/SCS-01-generation-pipeline.md`
- Create: `docs/research/SCS-02-mage-priority-taxonomy.md`
- Create: `docs/research/SCS-03-prebuff-accounting.md`
- Create: `docs/research/SCS-04-target-and-protection-rules.md`
- Create: `docs/research/SCS-05-encounter-exceptions.md`
- Create: `docs/research/SCS-06-difficulty-randomness-and-fairness.md`
- Create: `docs/provenance/scs/mage-pilot-ledger.md`
- Create: `docs/provenance/scs/prebuff-pilot-ledger.md`
- Create: `tests/fixtures/manifests/scs-pilot.synthetic.json`

**Steps:**

1. Select one representative mage and prebuff family by source location and generator inputs, never
   by assuming a generated `dw#*` resref is stable.
2. Record source component/version, generator stages, effective script-slot position, spell
   allocation inputs, macro expansion, branch order, `Continue()`, weighted responses, accounting,
   encounter handoff, and difficulty/fairness controls.
3. Classify each rule as `preserve`, `generalize`, `intentional-change`, `omit`, `opaque`, or
   `needs-engine-proof`.
4. Store only authored metadata and minimal synthetic representations in Git. Keep local paths and
   effective artifacts outside the repository.
5. Cross-check the compact SSL against a read-only decompile of the effective generated BCS; record
   discrepancies without committing the decompile.
6. Review the ledgers for attribution and distribution status.
7. Commit: `research: map SCS mage and prebuff pilot behavior`.

**Exit:** the pilot has a bounded semantic oracle and provenance ledger; no runtime code has been
copied or activated.

## 8. Phase B — EEex bridge and lifecycle proof (E1, G1)

### Task 7: Build the EEex capability profile

**Research linkage (not automatic closure):** EEEX-01, EEEX-02

**Depends on:** Task 2

**2026-09-27 checkpoint:** Completed as a pure host contract; see the
[capability catalog](../research/EEEX-01-capability-catalog.md) and
[static lifecycle map](../research/EEEX-02-lifecycle-and-hook-map.md). Seven focused behavior cases
pass on both Lua 5.1 and LuaJIT; independent review accepted the packet. No EEex function was called,
no bootstrap installed and no runtime safety claimed. Task 8 still waits for Task 3 completion.

**Files:**

- Create: `docs/research/EEEX-01-capability-catalog.md`
- Create: `docs/research/EEEX-02-lifecycle-and-hook-map.md`
- Create: `schemas/capability-profile.schema.json`
- Create: `adapters/eeex/capabilities.lua`
- Test: `tests/unit/kernel/test_capabilities.lua`

**Steps:**

1. Enumerate candidate APIs from exact EEex source revisions: listener registration, actor
   iteration, script slots, current action, aura/cast state, stored targets, resources, marshal,
   area/save/load lifecycle, clocks, and diagnostics.
2. For each capability, record signature, numeric/boolean conventions, lifecycle, failure mode,
   crash potential, fallback, and minimum evidence needed.
3. Write a failing pure-Lua test that feeds missing, renamed, and partially available functions and
   expects a data-only profile with no speculative call.
4. Implement minimal detection through injected function tables; do not touch globals in policy
   tests.
5. Run focused tests; expected: deterministic capability profiles and explicit unavailable reasons.
6. Commit: `feat: add versioned EEex capability profiles`.

**Exit:** capability detection exists as a pure contract; engine safety remains bounded by
evidence:E0 and evidence:E2 until the disposable probes pass.

### Task 8: Prove observer registration and hot-reload safety

**Research linkage (not automatic closure):** EEEX-02, EEEX-05

**Depends on:** Tasks 2, 3, and 7

**Files:**

- Create: `experiments/eeex-observer/M_B-K.lua`
- Create: `experiments/eeex-observer/{allocated-observer-stem}.lua`
- Create: `experiments/eeex-observer/README.md`
- Create: `docs/research/EEEX-03-observer-probe.md`
- Test: `tests/unit/kernel/test_listener_trampoline.lua`

`{allocated-observer-stem}` is a non-literal planning token. Before creating the experiment,
record a one-to-one logical-artifact allocation whose stem satisfies
`^B-[KCWX][A-Z0-9]{5}$`; do not truncate or hash an adapter ID into that stem. `M_B-K.lua` is the
fixed planned bootstrap name, while its autoload and ordering remain Task 8 evidence questions.

**Steps:**

1. Write a failing host test for an append-only listener registered once through a root-level
   trampoline whose implementation can be replaced on reload without duplicating callbacks.
2. Implement the injected fake-listener case; verify 100 reloads produce one registration and the
   newest implementation receives events.
3. Add a read-only observer experiment with a bounded actor allowlist and no action/global writes.
4. Run it only in the approved disposable environment. Exercise startup, area entry, actor load,
   save, load, main-menu return, hot reload, actor destruction, and EEex capability loss.
5. Record event order, missing events, duplicate callbacks, stale userdata behavior, engine build,
   EEex revision, logs, and crash/no-crash result.
6. If any call crashes, stop and quarantine it; do not retry with altered arguments without source
   analysis and a new experiment ID.
7. Commit host tests and redistributable experiment source/log excerpts only:
   `research: prove EEex observer lifecycle`.

**Exit:** evidence:E4 identifies a safe observer lifecycle or G1 fails.

### Task 9: Prove normal-action outcome observation

**Research linkage (not automatic closure):** ACT-01, ACT-02, ACT-04

**Depends on:** Tasks 3 and 8

**Files:**

- Create: `docs/research/ACT-01-action-state-model.md`
- Create: `docs/research/ACT-02-cast-observation.md`
- Create: `docs/research/ACT-03-interruption-and-invalidation.md`
- Create: `docs/research/ACT-04-queue-contention.md`
- Create: `experiments/action-observer/`
- Test: `tests/unit/kernel/test_action_observer.lua`

**Steps:**

1. Write failing model tests for `proposed`, `accepted`, `started`, `advanced`, `completed`,
   `failed`, `interrupted`, `invalidated`, `timed-out`, and `unknown`.
2. Prove that `accepted` can never directly transition to `completed` without an independent
   postcondition or a trusted engine observation.
3. Implement the pure state reducer and run focused tests.
4. In the disposable arena, observe ordinary cast, no-aura delay, silenced cast, target death,
   target movement, player/legacy queue contention, interruption, area transition, save/load, and
   Project Image owner-lock exclusion.
5. Compare current-action/listener evidence with resource expenditure, aura/cast timers, effects,
   projectiles, or other action-specific postconditions. Record false positives and unknowns.
6. Define conservative timeouts and the rule for relinquishing ownership without destructive queue
   clearing.
7. Commit: `research: define and prove action outcome states`.

**Exit:** one ordinary action family's observer is proved at evidence:E4 with explicit unknown
outcomes; otherwise active control remains forbidden.

### Task 10: Prove persistence, stack epochs, diagnostics, and baseline cost

**Research linkage (not automatic closure):** EEEX-02, EEEX-04, WF-02, PERF-01, PERF-05

**Depends on:** Tasks 3, 5, and 8

**Files:**

- Create: `docs/research/EEEX-06-persistence-lifecycle.md`
- Create: `docs/research/PERF-01-observer-baseline.md`
- Create: `kernel/state_schema.lua`
- Create: `kernel/diagnostics.lua`
- Test: `tests/unit/kernel/test_state_schema.lua`
- Test: `tests/unit/kernel/test_diagnostics.lua`

**Steps:**

1. Write failing tests that reject userdata/object IDs/functions/threads, unknown schema versions,
   oversized traces, and unbounded per-adapter errors.
2. Implement scalar/table validation, schema tags, migration dispatch, bounded ring diagnostics,
   and redaction.
3. In the disposable environment, verify new game, save, load, quickload, area transition, death,
   main-menu return, old save without state, future schema, corrupted adapter state, mod disable,
   and upgrade.
4. Prove ephemeral leases/actions/handles clear on load while durable WorldFlow-shaped test state
   migrates or quarantines per schema.
5. Benchmark observer-only cost across idle, ordinary combat, summons, and a crowded area. Record
   methodology, frame/tick distribution, memory, trace volume, and instrumentation overhead.
6. Commit: `feat: add bounded state and diagnostics foundations`.

**Exit:** persistence and diagnostics cannot poison the whole runtime, and observer cost has a
measured baseline.

### Task 11: Prove the BCS/Lua/DLG bridge and legacy decline path

**Research linkage (not automatic closure):** EEEX-03, BCS-01, BCS-04, DLG-01

**Depends on:** Tasks 3 and 8 through 10

**Files:**

- Create: `docs/research/BCS-01-lua-handoff.md`
- Create: `docs/research/DLG-01-normal-dialogue-initiation.md`
- Create: `docs/research/FLOW-01-legacy-decline-and-handback.md`
- Create: `experiments/bridge/{allocated-bridge-script-stem}.baf`
- Create: `experiments/bridge/{allocated-dialogue-stem}.d`
- Create: `experiments/bridge/{allocated-bridge-lua-stem}.lua`
- Create: `experiments/bridge/setup-bgse-bridge.tp2`
- Test: `tests/integration/test_bridge_installer.py`

Each `{allocated-...-stem}` is a non-literal planning token. Before creating the bridge fixture,
record a separate one-to-one logical-artifact allocation whose engine stem satisfies
`^B-[KCWX][A-Z0-9]{5}$` and is unique case-insensitively across extensions. Never truncate or hash
an adapter ID into an engine name. `bgse` is the host-only installer slug and is not an engine
resource derivation.

**Steps:**

1. Write a failing synthetic-game test requiring a conventional WeiDU component to compile a tiny
   BAF/D resource set, publish only allowlisted files, reinstall idempotently, and uninstall to
   byte-identical fixture state.
2. Implement the smallest bridge whose BCS side can ask Lua whether it has a valid claim. A decline,
   missing capability, or Lua error must reach an existing legacy sentinel block in the same test
   without clearing its actions or changing a plot variable.
3. Prove in the disposable game that the BCS trigger/action reaches Lua with scalar identifiers and
   that Lua can decline safely. Never persist the current object ID.
4. Prove one ordinary engine dialogue initiation path, including target unavailable, target busy,
   player decline, interruption, area change, and runtime-disabled cases. The bridge must not jump
   directly to a DLG state as a substitute for normal selection unless a later supported adapter
   explicitly owns that entry ABI.
5. Verify compiled behavior with a minimal decompile kept outside Git; commit only authored bridge
   source and synthetic fixtures.
6. Run installer, host, and reset tests; commit: `research: prove conservative legacy bridge`.

**Exit:** BCS and dialogue can consult the runtime without making it the default owner; decline and
failure visibly restore the legacy path.

### Task 12: Review and record G1

**Depends on:** Tasks 7 through 11

**Files:**

- Create: `docs/decisions/gates/G1-bridge-feasibility.md`
- Modify: `docs/compatibility/support-manifest.md` (create if absent)

**Steps:**

1. Assemble exact capability profile, source revisions, engine build, experiment IDs, crashes,
   unsupported calls, lifecycle gaps, action observation limits, persistence result, and cost.
2. Mark each claim with every applicable `evidence:E0` through `evidence:E5` layer and each
   capability `supported`, `shadow-only`, `unavailable`, or
   `quarantined`.
3. Run all host tests and reproduce the disposable smoke sequence from a reset lab state.
4. Review against every G1 exit criterion and P0 open question.
5. Record `PASS`, `PASS WITH NARROWED SCOPE`, or `FAIL`; do not use conditional language as a pass.
6. Commit: `docs: record G1 bridge feasibility decision`.

**Exit:** downstream kernel work has an exact supported capability envelope or stops.

## 9. Phase C — Compatibility lab, safe observer, and early WorldFlow research (E2-E3, G2-G3)

### Task 13: Establish the deterministic host simulation scaffold

**Research linkage (not automatic closure):** TEST-01

**Depends on:** Tasks 2 and 12; G1 must not be `FAIL`

**Files:**

- Create: `scripts/test.ps1`
- Create: `tools/run_lua_tests.py`
- Create: `tests/lua/test_helper.lua`
- Create: `tests/lua/fake_engine.lua`
- Create: `kernel/clock.lua`
- Create: `kernel/rng.lua`
- Test: `tests/unit/kernel/test_clock.lua`
- Test: `tests/unit/kernel/test_rng.lua`

**Steps:**

1. Write failing Lua tests for injected monotonic time, deterministic sequence replay, independent
   RNG streams, integer/float boundary behavior, invalid seeds, and no access to ambient wall clock
   or global random state.
2. Implement a Python runner that launches the interpreter selected by
   `docs/research/host-runtime-toolchain-decision.md`, reports every test file, preserves
   stdout/stderr, and fails if no tests are discovered.
3. Run `pwsh -File scripts/test.ps1 -Suite unit`; expected: intentional RED for missing clock/RNG.
4. Implement minimal Lua 5.1-compatible clock and RNG interfaces. Do not optimize or add policy.
5. Run the unit suite twice with shuffled test order; expected: identical decisions and no global
   state leakage.
6. Add a test-run manifest containing interpreter path class and version but no personal absolute
   path.
7. Commit: `test: add deterministic Lua simulation scaffold`.

**Exit:** future policy and state machines can be proved without constructing EEex userdata.

### Task 14: Implement exact-hash support manifests and conservative activation eligibility

**Research linkage (not automatic closure):** IR-04, COMP-I01 through COMP-I12

**Depends on:** Tasks 5 and 13

**Files:**

- Create: `kernel/manifest.lua`
- Create: `kernel/eligibility.lua`
- Create: `adapters/registry.lua`
- Create: `docs/compatibility/support-manifest.md`
- Test: `tests/unit/kernel/test_manifest.lua`
- Test: `tests/unit/kernel/test_eligibility.lua`
- Fixture: `tests/fixtures/manifests/eligibility/*.lua`

**Steps:**

1. Write failing tests for C0-C4 tiers, exact adapter ID/version, required capabilities, resource
   dependencies, exact hash algorithm/version, script-slot topology, public-state declarations,
   legacy fallback, stack epoch, and provenance.
2. Add negative fixtures for unknown resource, missing dependency, new opaque node, changed slot,
   changed recognized resource, stale stack epoch, ambiguous actor identity, and manifest schema
   from a future version.
3. Run `pwsh -File scripts/test.ps1 -Suite unit -Filter eligibility`; expected: FAIL.
4. Implement a pure eligibility reducer returning `eligible=false` plus stable reason codes on every
   uncertainty. Initial activation requires exact hashes across the declared dependency/control
   closure. Selective semantic matches are rejected until the IR/canonicalization gate passes. The
   reducer must never mutate adapter state or promote a tier.
5. Prove one adapter's failed fingerprint does not disable or activate another adapter.
6. Export a human-readable support report and verify it never says “compatible” without an exact
   tier, profile, and evidence reference.
7. Commit: `feat: add default-deny adapter eligibility`.

**Exit:** activation is machine-default-deny; naming convention and whole-file presence are
insufficient.

### Task 15: Implement ownership arbitration, dispatch leases, and in-flight attempts

**Research linkage (not automatic closure):** ACT-03, ACT-04, BCS-04, COMP-B01 through COMP-B12

**Depends on:** Tasks 13 and 14

**Files:**

- Create: `kernel/ownership.lua`
- Create: `kernel/lease.lua`
- Create: `kernel/action_attempt.lua`
- Create: `kernel/identity.lua`
- Test: `tests/unit/kernel/test_ownership.lua`
- Test: `tests/unit/kernel/test_lease.lua`
- Test: `tests/unit/kernel/test_action_attempt.lua`
- Test: `tests/unit/kernel/test_identity.lua`

**Steps:**

1. Write failing tests for the authority order: player/hard mode, WorldFlow or legacy encounter,
   supported forced behavior, Combat Intent lease, legacy generic combat, conservative idle.
2. Write dispatch-lease tests for acquire, decline, one-action limit, expiry, timeout, dialogue, cutscene,
   staging, allegiance change, area change, target invalidation, occupied action, capability loss,
   adapter quarantine, runtime disable, and save/load.
3. Write identity tests proving object IDs/userdata are never accepted as durable identity and that
   ambiguous stable identities cause decline.
4. Run focused tests; expected: FAIL because arbitration is absent.
5. Implement immutable request/result tables and stable reason codes. A lease may authorize one
   dispatch attempt, not a multi-action queue and not a queue clear. Queue acceptance ends the
   dispatch lease and creates an in-flight attempt token that prevents a duplicate/conflicting new
   Combat Intent lease until start/failure/interruption/invalidation/timeout; it never owns or
   clears legacy/player actions and never persists across load.
6. Add a property-style seeded test that generates event permutations and proves every lease and
   attempt token expires or terminates, never silently survives invalidation.
7. Commit: `feat: add explicit ownership and one-action leases`.

**Exit:** Combat Intent has no route around higher world/legacy authority.

### Task 16: Assemble the observer-only shared kernel

**Research linkage (not automatic closure):** EEEX-05, EEEX-06, PERF-02, PERF-03

**Depends on:** Tasks 7, 8, 10, and 13 through 15

**Files:**

- Create: `kernel/bootstrap.lua`
- Create: `kernel/engine.lua`
- Create: `kernel/events.lua`
- Create: `kernel/trace.lua`
- Create: `adapters/eeex/engine.lua`
- Create: `adapters/eeex/listeners.lua`
- Test: `tests/unit/kernel/test_bootstrap.lua`
- Test: `tests/unit/kernel/test_trace.lua`

**Steps:**

1. Write failing fake-engine tests for bootstrap, capability negotiation, explicit enrollment,
   observer events, adapter-local exception, circuit open/half-open behavior, disable, reload, and
   save/load invalidation.
2. Assert unknown actors produce no locals, globals, actions, durable records, or adapter callbacks
   beyond aggregate bounded diagnostics.
3. Run focused tests; expected: FAIL.
4. Implement the smallest observer kernel using injected adapters. Policy modules may read scalar
   snapshots but cannot obtain native EEex objects.
5. Emit bounded structured traces containing actor semantic identity, manifest/adapter ID,
   capability profile, ownership state, snapshot version, event, and reason codes.
6. Run host tests and the disposable observer scenario. Compare cost with Task 10's baseline and
   investigate all regressions.
7. Commit: `feat: assemble observer-only runtime kernel`.

**Exit:** explicitly tagged supported actors can be observed, explained, disabled, and forgotten
without behavioral mutation.

### Task 17: Build the compatibility lab and unknown-content pass-through suite

**Research linkage (not automatic closure):** BCS-03, BCS-04, DLG-03, IR-04, IR-05, TEST-02, TEST-07 plus P0 compatibility cases

**Depends on:** Tasks 3, 11, and 14 through 16

**Files:**

- Create: `tests/fake-game/`
- Create: `tests/scenarios/compatibility/`
- Create: `tests/integration/test_unknown_passthrough.py`
- Create: `tests/integration/test_install_order.py`
- Create: `tests/integration/test_save_lifecycle.py`
- Create: `docs/research/compatibility-lab-results.md`

**Steps:**

1. Create minimal synthetic CRE/BCS/DLG/ARE/SPL/IDS/2DA fixtures with independently authored
   sentinel behavior. Include an opaque/unsupported BCS block and DLG action.
2. Write failing cases for unknown mod before, unknown mod after, recognized resource modified
   before, recognized resource modified after, occupied slots, added public-global writer, removed
   dependency, version upgrade, runtime disable, exception, and capability loss.
3. Add COMP-I07 RED fixtures for an occupied engine resource prefix, bootstrap filename, adapter ID,
   and exclusive internal-variable claim. Hash the fixture tree before the attempted install and
   prove each collision is rejected before any byte is changed.
4. Run the focused integration tests; expected: intentional RED.
5. Wire inventory, eligibility, bridge, observer, and lease code into the fake-game installer.
6. Prove unknown bytes remain untouched in the fake game. In a disposable sentinel scenario, prove
   one unknown actor and one unknown quest/controller continue their observable legacy behavior
   while the kernel is loaded. After any unknown stack drift, both domains remain stale/pass-through
   for G2; no adapter reactivates. Successful refreshed reactivation is separate G5/G8 research
   requiring a proved dependency, public-state, and external-control closure.
7. Install, reinstall, upgrade, disable, and uninstall. Verify publication allowlist and byte-exact
   restoration of fixture-owned originals.
8. Map results to stable `COMP-*` IDs and record unexecuted cells explicitly.
9. Commit: `test: prove unknown-content legacy ownership`.

**Exit:** the primary compatibility invariant has evidence:E3 structural/restoration proof and
evidence:E4 sentinel-behavior proof rather than prose.

### Task 18: Review and record G2 and G3

**Depends on:** Tasks 13 through 17

**Files:**

- Create: `docs/decisions/gates/G2-unknown-content-pass-through.md`
- Create: `docs/decisions/gates/G3-safe-observer.md`
- Modify: `docs/compatibility/support-manifest.md`

**Steps:**

1. Run the full host, Lua, fake-game, and disposable observer suites from a clean state.
2. Audit every adapter activation path for manifest eligibility and runtime ownership.
3. Audit every durable field for object IDs, userdata, closures, and area-local assumptions.
4. Compare observer cost against the approved budget and record p50/p95/worst cases.
5. Record each gate `PASS`, `PASS WITH NARROWED SCOPE`, or `FAIL`, including unsupported cases.
6. Commit: `docs: record compatibility and observer gates`.

**Exit:** active decision work is allowed only for the exact envelope named by both gate records.

### Task 19: Research WorldFlow semantics and public compatibility ABI without mutation

**Research linkage (not automatic closure):** BCS-01 through BCS-04, DLG-01 through DLG-03,
FLOW-01, FLOW-02, WF-06

**Depends on:** Tasks 5 and 11

**Files:**

- Create: `docs/research/WF-01-bcs-dlg-semantics.md`
- Create: `docs/research/WF-02-public-state-abi.md`
- Create: `schemas/worldflow-abi.schema.json`
- Create: `tools/ir/public_state_graph.py`
- Test: `tests/tooling/test_public_state_graph.py`

**Steps:**

1. Write failing graph tests for global/local/timer readers and writers, DLG start states and
   transitions, script-slot owners, shouts, area/encounter controllers, forced actions,
   journal/reward/spawn actions, cutscene launch/teardown, skip path, and opaque dynamic references.
2. Implement only the independently understood BCS/DLG subset needed to inventory synthetic
   examples. Preserve order and emit opaque nodes; this advisory graph cannot activate an adapter
   or justify a selective semantic fingerprint.
3. Define the public ABI manifest: variable names/scopes/meaning, entry triggers, dialogue entry
   states, timers, locals, death variables, journal effects, external readers/writers, expected
   final world invariants, and legacy re-entry/handback.
4. Validate against synthetic scripts with an unknown later writer/controller; expected: the graph
   reports incomplete closure and any hypothetical claim remains stale/pass-through.
5. Inspect representative effective content read-only and record evidence:E1, uncertainties, and
   unsupported constructs without converting or patching it.
6. Commit: `research: map WorldFlow semantics and public ABI`.

**Exit:** WorldFlow research can guide the synthetic pilot, but no persistent transition has been
claimed and no advisory graph is trusted as complete activation evidence.

## 10. Phase D — Combat Intent shadow, one active action, then scaling (E4-E6, G4-G6)

### Task 20: Freeze Combat Intent snapshot, perception, and belief contracts

**Research linkage (not automatic closure):** EEEX-06, SPACE-04, ACT-01

**Depends on:** Task 18; G2 and G3 must pass

**Files:**

- Create: `combat-intent/snapshot.lua`
- Create: `combat-intent/perception.lua`
- Create: `combat-intent/beliefs.lua`
- Create: `schemas/combat-snapshot.schema.json`
- Test: `tests/unit/combat_intent/test_snapshot.lua`
- Test: `tests/unit/combat_intent/test_perception.lua`
- Fixture: `tests/scenarios/combat/mage-pilot/*.lua`

**Steps:**

1. Write failing tests that reject native objects and distinguish observed fact, plausible memory,
   inferred fact, unknown, and expired belief.
2. Add fairness fixtures for invisible/undetected targets, unknown protections, previously witnessed
   casts, allies' shared observations, target leaving sight, and stale memory.
3. Run focused tests; expected: FAIL.
4. Implement immutable scalar snapshots and time-bounded beliefs with source/confidence/reason.
5. Add a policy audit that fails if a scorer reads a field not declared by the snapshot schema.
6. Commit: `feat: define fair Combat Intent perception`.

**Exit:** the pilot cannot obtain difficulty from engine omniscience.

### Task 21: Implement legal candidate generation

**Research linkage (not automatic closure):** ACT-02, SCS-03, SCS-04, SPACE-02

**Depends on:** Task 20

**Files:**

- Create: `combat-intent/candidates.lua`
- Create: `combat-intent/legality.lua`
- Create: `combat-intent/actions.lua`
- Test: `tests/unit/combat_intent/test_candidates.lua`
- Test: `tests/unit/combat_intent/test_legality.lua`

**Steps:**

1. Write table-driven RED tests for the combat shadow set: `Slow`, `Glitterdust`, `Magic Missile`,
   wait, and legacy decline. Add a separate prebuff shadow set containing one ledger-approved
   long-duration self-buff, one ledger-approved short-duration self-buff, and decline; choose exact
   spells only after Task 6. Movement/reposition candidates are deferred until after G5.
2. Cover actual spell allocation, depleted copy, aura, silence, casting failure, target legality,
   range, sight, projectile/AoE metadata confidence, ally risk, immunity known/unknown, occupied
   action, and higher ownership. Prebuff legality additionally covers long/short preparation window,
   sight/detection/offscreen fairness, one-shot state, real resource removal/accounting, and existing
   buff detection.
3. Require every exclusion to produce a stable reason code. Shadow-only AoE evaluation uses curated
   exact pilot metadata; uncertain geometry/resource interpretation excludes the candidate rather
   than invoking general spatial logic early.
4. Implement pure candidate and legality reducers.
5. Run focused and full unit suites; commit: `feat: generate only legal combat candidates`.

**Exit:** no unavailable, illegal, imperceptible, or unowned action can enter scoring.

### Task 22: Implement utility, competence profiles, and bounded randomness

**Research linkage (not automatic closure):** SCS-03, SCS-06

**Depends on:** Tasks 13 and 21

**Files:**

- Create: `combat-intent/utility.lua`
- Create: `combat-intent/profile.lua`
- Create: `combat-intent/choose.lua`
- Test: `tests/unit/combat_intent/test_utility.lua`
- Test: `tests/unit/combat_intent/test_profiles.lua`
- Test: `tests/unit/combat_intent/test_choose.lua`

**Steps:**

1. Write failing score-breakdown tests for control value, expected affected targets, friendly risk,
   redundancy, resource conservation, interruption risk, urgency, profile modifiers, and deliberate
   uncertainty. The bounded prebuff set additionally scores duration plausibility, preparation
   timing, redundancy, resource accounting, and archetype priority.
2. Define profiles so wit/discipline/reaction/noise change information use, latency, commitment,
   and weighting without ever changing legality or resources.
3. Write distribution tests showing fixed seed replay and bounded variation across seeds; avoid a
   brittle assertion on one unseeded outcome.
4. Implement additive reason-coded utility and weighted choice within a configurable near-best
   band. Keep values data-driven and pilot-sized.
5. Compare selected outcomes with the SCS pilot ledger: tag `agree`, `intentional divergence`,
   `suspected upstream bug`, or `unresolved`.
6. Commit: `feat: add explainable combat utility and profiles`.

**Exit:** randomness creates characterful variation without making actors arbitrarily stupid or
omniscient.

### Task 23: Implement structured trace, replay, and SCS shadow comparison

**Research linkage (not automatic closure):** SCS-06, IR-02, IR-03, TEST-01

**Depends on:** Tasks 6, 16, and 20 through 22

**Files:**

- Create: `tools/replay/replay.py`
- Create: `tools/replay/diff.py`
- Create: `combat-intent/trace.lua`
- Test: `tests/tooling/test_replay.py`
- Test: `tests/scenarios/combat/test_mage_shadow.py`
- Create: `docs/research/combat-shadow-oracle.md`

**Steps:**

1. Write failing tests that replay a canonical snapshot and require byte-stable normalized decision
   output, score reasons, exclusions, seed, selected candidate, and fallback reason.
2. Implement trace normalization/redaction and a replay runner independent of EEex.
3. Encode the mage/prebuff pilot scenarios from Task 6 without copying upstream BCS.
4. Compare Combat Intent with observed SCS/legacy outcomes. Do not assume disagreement is a bug;
   classify and review it.
5. Bound trace volume and prove malformed/large traces cannot block combat.
6. Commit: `feat: add deterministic Combat Intent replay`.

**Exit:** every shadow decision can be reproduced and reviewed without replaying the whole game.

### Task 24: Run the mage/prebuff pilot in mutation-free shadow mode

**Depends on:** Tasks 18 and 23

**Files:**

- Create: `adapters/scs/mage_pilot.lua`
- Create: `adapters/scs/prebuff_pilot.lua`
- Test: `tests/integration/test_scs_mage_shadow.py`
- Create: `docs/research/mage-prebuff-shadow-results.md`
- Create: `docs/decisions/gates/G4-combat-shadow.md`

**Steps:**

1. Write failing adapter tests for exact manifest/dependency-hash match, script-slot/higher-owner
   handoff, unknown encounter script, changed spell allocation, unsupported difficulty option, and
   decline. Include the bounded long/short prebuff candidates, preparation-window fairness,
   one-shot/accounting behavior, already-present buff, and no-eligible-prebuff decline.
2. Implement read-only mapping from the supported manifest into scalar pilot snapshots.
3. Run synthetic and disposable mage scenarios with shadow dispatch disabled at the kernel type
   boundary, not merely by convention.
4. Capture decision coverage, exclusions, SCS comparison, fairness audit, performance, exceptions,
   and every fallback.
5. Verify there are zero actions, locals/globals, queue mutations, script-slot changes, or durable
   actor records caused by shadow mode.
6. Record G4 result and commit: `feat: validate SCS mage pilot in shadow mode`.

**Exit:** G4 passes for exact pilot dependency hashes or the adapter stays disabled.

### Task 25: Activate one normal combat action behind a kill switch

**Depends on:** Tasks 9, 15, and 24; G4 must pass

**Files:**

- Create: `kernel/action_dispatch.lua`
- Create: `combat-intent/dispatch.lua`
- Create: `adapters/eeex/action_dispatch.lua`
- Test: `tests/unit/kernel/test_action_dispatch.lua`
- Test: `tests/integration/test_active_action_claim.py`

**Steps:**

1. Choose the simplest normal action whose observation/postconditions Task 9 actually proved. Do
   not preselect `Slow` or any AoE when a simpler single-target action provides cleaner ownership
   and execution evidence. If no candidate meets the bar, record a no-go and choose no substitute
   without review.
2. Write failing tests for immediate revalidation, one lease/one dispatch, actual memorized spell,
   aura/casting time, started/completed/interrupted/unknown, target loss, geometry change, dialogue,
   cutscene, staging, save/load at every lease state, area change, capability loss, exception,
   dependency-hash/stack-epoch drift, and runtime disable.
3. Implement dispatch through the ordinary action bridge with a default-off feature flag and an
   adapter-local kill switch.
4. Run synthetic tests, then a reset disposable arena. Independently verify spell expenditure,
   casting progression, effect/projectile postcondition, and legacy resumption.
5. Disable the adapter mid-scenario; expected: no new claims and ordinary legacy behavior on the
   next eligible script pass.
6. Commit: `feat: activate one verified Combat Intent action`.

**Exit:** one action can be owned honestly; queue acceptance alone is never reported as success.

### Task 26: Prove active-combat containment and record G5

**Research linkage (not automatic closure):** ACT-05, PERF-03, PERF-04, TEST-05, TEST-08 plus active
`COMP-B/X/P/SCS` cases

**Depends on:** Tasks 3 and 25

**Files:**

- Create: `tests/soak/combat_pilot/`
- Create: `docs/research/active-combat-soak.md`
- Create: `docs/decisions/gates/G5-active-combat.md`

**Steps:**

1. Run repeated cases for SCS present/absent, supported spell revision present/absent, unknown
   nearby creatures/scripts, occupied slots, modified supported resource, summons/clones,
   Project Image exclusion, save/load, rest, area transition, death, disable, and adapter error.
2. Verify all feature-off and failure cases reach a known legacy sentinel outcome.
3. Measure decision latency, engine-tick cost, allocations, trace volume, lease duration, unknown
   outcomes, and circuit-breaker activations.
4. Investigate every failure; do not average away rare ownership or save defects.
5. Record exact tested matrix, reset procedure, iterations, untested cells, and G5 result.
6. Commit: `test: prove active Combat Intent containment`.

**Exit:** active mode stays enabled only for the exact passing pilot envelope.

### Task 27: Implement short intentions and expiring reservations

**Research linkage (not automatic closure):** ACT-04, SPACE-05

**Depends on:** Tasks 15, 22, and 26; G5 must pass

**Files:**

- Create: `combat-intent/intention.lua`
- Create: `combat-intent/reservation.lua`
- Test: `tests/unit/combat_intent/test_intention.lua`
- Test: `tests/unit/combat_intent/test_reservation.lua`

**Steps:**

1. Write failing tests for a two-step `reposition -> attempt Slow` intention with explicit purpose,
   next action, assumptions, expiry, success, abort, and replan conditions.
2. Write two-actor tests for target/effect/space reservations, collision avoidance, expiry, actor
   loss, interruption, target invalidation, combat end, save/load, and adapter disable.
3. Prove intentions never reserve future spell slots, actions, or positions indefinitely and never
   survive a missing semantic identity.
4. Implement minimal one-next-step intentions and bounded shared blackboard records.
5. Run seeded interleaving/property tests; commit: `feat: add bounded combat intentions`.

**Exit:** the system can plan briefly and coordinate without creating a permanent group hive mind.

### Task 28: Add conservative spatial candidates and AoE risk

**Research linkage (not automatic closure):** SPACE-01, SPACE-02, SPACE-03, SPACE-04

**Depends on:** Tasks 20, 21, 26, and 27; G5 must pass

**Files:**

- Create: `combat-intent/spatial.lua`
- Create: `combat-intent/geometry.lua`
- Create: `docs/research/SPACE-01-coordinate-and-los.md`
- Create: `docs/research/SPACE-02-projectile-geometry.md`
- Test: `tests/unit/combat_intent/test_geometry.lua`
- Test: `tests/unit/combat_intent/test_spatial.lua`

**Steps:**

1. Research coordinate units, personal space, path/LOS query safety, projectile geometry, and
   installed spell targeting. Mark curated versus derivable metadata.
2. Write failing pure tests for ally-in-AoE, uncertain radius, chokepoint, unreachable candidate,
   occupied destination, caster threat, retreat bias, and no safe movement.
3. Implement a small sampled candidate set; do not build a full path planner.
4. Exclude any AoE/movement candidate whose geometry or reachability lacks the required evidence
   layer or combination of layers.
5. Validate only safe read/query calls in the disposable arena; stop on native fault.
6. Commit: `feat: add conservative spatial reasoning`.

**Exit:** spatial awareness improves a bounded pilot without assuming pathfinding control.

### Task 29: Adapt a second bounded SCS family in shadow mode

**Research linkage (not automatic closure):** SCS-01 through SCS-06, IR-03, TEST-05

**Depends on:** Tasks 6, 23, and 26; G5 must pass for the first family

**Files:**

- Create: `docs/provenance/scs/<second-family>-ledger.md`
- Create: `adapters/scs/<second-family>_shadow.lua`
- Create: `tests/scenarios/combat/<second-family>/`
- Create: `docs/research/<second-family>-shadow-results.md`

**Steps:**

1. Select a family that is bounded but meaningfully different from the mage pilot. Record why it is
   useful for measuring reuse rather than choosing the easiest duplicate.
2. Complete its source/effective provenance, exact dependency hashes, encounter ownership, resource
   semantics, preserved rules, intentional differences, opaque cases, and fallback ledger.
3. Write failing replay/eligibility tests before the adapter, including changed resource, unknown
   controller, unsupported SCS version, and higher encounter owner.
4. Implement shadow-only observation and decisions behind a type-level no-dispatch boundary.
5. Run synthetic and disposable shadow scenarios; classify SCS agreement/divergence and record time,
   fixture size, exceptions, review effort, and runtime cost.
6. Commit: `research: shadow a second SCS behavior family`.

**Exit:** G6 has a real second sample. This task does not activate a second family.

### Task 30: Measure migration economics and record G6

**Depends on:** Tasks 27 through 29

**Files:**

- Create: `docs/research/migration-cost-model.md`
- Create: `docs/decisions/gates/G6-migration-economics.md`

**Steps:**

1. Compare the completed first and second family ledgers, traces, fixtures, and implementation
   histories.
2. Measure source-reading time, artifact size, rules retained, special cases, fixture creation,
   implementation/review tokens, tests, runtime cost, regressions, and unresolved semantics for
   both families.
3. Compare manual work with work saved by the exact inventory, advisory graph, replay, and templates
   that exist at G6. Treat benefits from the later typed IR as projected and unmeasured, not savings
   already achieved.
4. Set explicit budgets and a stop rule for the next wave.
5. Record `SUSTAINABLE`, `TOOLING REQUIRED`, or `STOP BROAD MIGRATION`.
6. Commit: `docs: record Combat Intent migration economics`.

**Exit:** corpus expansion follows measured economics, not enthusiasm alone.

## 11. Phase E — WorldFlow synthetic laboratory (E7, G7)

WorldFlow source research begins earlier in Task 19. Persistent implementation in this phase requires G3 and the action/failure semantics proven by G5. No real quest or active save is a pilot.

### Task 31: Freeze the synthetic WorldFlow claim envelope and public ABI

**Research linkage (not automatic closure):** BCS-03, BCS-04, DLG-03, WF-03, WF-06

**Depends on:** Tasks 17, 19, and 26; G5 must pass

**Files:**

- Create: `docs/research/worldflow-mini-claim-envelope.md`
- Create: `tests/fixtures/worldflow-mini/public-abi.json`
- Test: `tests/tooling/test_worldflow_mini_closure.py`

**Steps:**

1. Select only independently authored synthetic mini-quest resources and enumerate their exact
   BCS/DLG/ARE/resource dependency closure, public state, controllers, side effects, and handback.
2. Write failing tests for one missing reader/writer, opaque action, unknown controller, changed
   exact hash, changed dialogue ordering, duplicate claim, and unsupported side effect.
3. Freeze the pilot ABI and exact-hash claim envelope. The earlier advisory graph is evidence input,
   not activation authority; every opaque or unclosed edge makes the pilot ineligible.
4. Add a later synthetic writer/controller outside the directly claimed resource; expected:
   refreshed closure detects it and the flow remains stale/pass-through.
5. Review the envelope against the G5 action/failure semantics before authorizing persistent
   commands.
6. Commit: `test: freeze synthetic WorldFlow claim envelope`.

**Exit:** WorldFlow cannot claim a transition whose public observers/writers are unknown.

### Task 32: Implement the pure durable saga state machine

**Research linkage (not automatic closure):** WF-01, WF-02, WF-03

**Depends on:** Tasks 10, 13, 15, and 31

**Files:**

- Create: `worldflow/schema.lua`
- Create: `worldflow/machine.lua`
- Create: `worldflow/claim.lua`
- Create: `worldflow/transition.lua`
- Test: `tests/unit/worldflow/test_machine.lua`
- Test: `tests/unit/worldflow/test_claim.lua`
- Fixture: `tests/scenarios/worldflow/mini_quest.lua`

**Steps:**

1. Define the synthetic states:

   ```text
   NOT_STARTED -> CLAIMED -> ACTORS_READY -> DIALOGUE_COMPLETE
               -> REWARD_RESOLVING -> COMMITTED
   ```

   Include explicit `RECOVERING`, `LEGACY_OWNED`, and terminal quarantine outcomes where needed.
2. Write failing tests for legal/illegal transitions, optimistic epoch, duplicate controller,
   expired/stale claim, schema version, missing identity, save/load, capability loss, disable,
   legacy handback, and corrupted state.
3. Classify every transition as naturally idempotent, conditionally repeatable, at-most-once,
   at-least-once/convergent, compensatable, or unsupported.
4. Implement a pure immutable transition reducer. It emits typed commands and expected
   postconditions; it performs no engine mutation.
5. Property-test repeated `recover -> reconcile -> retry` sequences for termination or explicit
   quarantine.
6. Commit: `feat: add durable WorldFlow saga core`.

**Exit:** durable flow logic can be exhausted outside the engine and makes no ACID/exactly-once
promise the engine cannot fulfill.

### Task 33: Implement side-effect registry, postconditions, and reconciliation

**Research linkage (not automatic closure):** WF-04, WF-06

**Depends on:** Tasks 9, 10, and 32

**Files:**

- Create: `worldflow/effects.lua`
- Create: `worldflow/postconditions.lua`
- Create: `worldflow/reconcile.lua`
- Test: `tests/unit/worldflow/test_effects.lua`
- Test: `tests/unit/worldflow/test_reconcile.lua`

**Steps:**

1. Write failing cases for start dialogue, set public global, stage actor, start/end cutscene, spawn,
   grant reward, journal update, and area/world mutation.
2. For each command define idempotency class, durable marker timing, normal engine path,
   postcondition, timeout, retry, compensation, legacy handback, and unsupported ambiguity.
3. Cover already-applied effect, queue accepted/not started, started/not observed, missing/dead/busy
   actor, moved actor, duplicate controller, partial transition, and stale stack epoch.
4. Implement typed command descriptors and reconciliation without direct engine calls.
5. Prove rewards/spawns/journal entries cannot be duplicated in all modeled interleavings; commands
   lacking a sufficient postcondition must be unsupported, not “probably done.”
6. Commit: `feat: add WorldFlow reconciliation contracts`.

**Exit:** every scheduled side effect has an honest repeat/recovery model.

### Task 34: Build the synthetic DLG/BCS mini-quest bridge

**Research linkage (not automatic closure):** WF-05, TEST-02, TEST-06

**Depends on:** Tasks 11, 17, and 31 through 33

**Files:**

- Create: `tests/fixtures/worldflow-mini/`
- Create: `adapters/worldflow/mini_quest.lua`
- Create: `packaging/test/worldflow-mini.tp2`
- Test: `tests/integration/test_worldflow_mini_installer.py`
- Test: `tests/integration/test_worldflow_mini_flow.py`

**Steps:**

1. Author an independent miniature quest with controller, one NPC, normal dialogue entry, skippable
   cutscene, one world mutation, one reward, one journal update, final public global, and legacy
   sentinel path.
2. Write the RED installer tests: compile, publish allowlist, idempotent reinstall, upgrade,
   disable, uninstall, and byte-exact fixture restoration.
3. Write the RED flow tests: normal path, skip path, legacy decline, and public final invariants.
4. Implement the narrow adapter and tiny bridge. Preserve normal dialogue selection and a
   separately testable legacy path at every unclaimed state.
5. Verify normal and skip paths share one declared convergence function rather than duplicated
   hand-maintained final effects.
6. Commit: `feat: add synthetic WorldFlow mini-quest`.

**Exit:** WorldFlow owns only an independently authored fixture and remains reversible.

### Task 35: Fault-inject every WorldFlow boundary and record G7

**Research linkage (not automatic closure):** WF-04, WF-07, TEST-04, TEST-06, TEST-08 and `COMP-D/P/A` WorldFlow cases

**Depends on:** Tasks 3 and 34

**Files:**

- Create: `tests/scenarios/worldflow/fault_matrix.py`
- Create: `tests/integration/test_worldflow_recovery.py`
- Create: `docs/research/worldflow-fault-results.md`
- Create: `docs/decisions/gates/G7-worldflow-convergence.md`

**Steps:**

1. Generate interruption points before/after durable marker, queue request, action acceptance,
   action start, postcondition, public state publication, and claim release for every transition.
2. Inject save/load at every point plus dead/missing/busy/moved actor, declined/interrupted dialogue,
   cutscene skip/interruption, reward already present, duplicate controller, area transition,
   capability loss, adapter exception, disable, upgrade, corrupted state, and unknown later writer.
3. Run pure exhaustive interleavings first; then run the approved subset in the reset disposable
   game.
4. Assert convergence on one valid final state or explicit safe legacy/quarantine state, no duplicate
   irreversible effect, no cutscene lock, and preserved public ABI meaning.
5. Record exact tested/unexecuted boundaries, counterexamples, recovery latency, and G7 result.
6. Commit: `test: prove synthetic WorldFlow convergence`.

**Exit:** real-flow migration stays forbidden unless G7 passes without waiving an irreversible
side-effect defect.

## 12. Phase F — IR, first real flow, extension surface, packaging, and alpha hardening (E8-E10, G8)

### Task 36: Implement the typed script/dialogue IR subset and core lints

**Research linkage (not automatic closure):** IR-01 through IR-05, BCS-02, DLG-02

**Depends on:** Tasks 5, 17, 19, 23, 31, and 35; interfaces from G3/G7 frozen

**Files:**

- Create: `tools/ir/model.py`
- Create: `tools/ir/bcs.py`
- Create: `tools/ir/dlg.py`
- Create: `tools/ir/graph.py`
- Create: `tools/ir/lints.py`
- Test: `tests/tooling/ir/`
- Create: `docs/research/ir-supported-subset.md`

**Steps:**

1. Write golden tests for resources, script slots, ordered blocks, triggers, weighted responses,
   actions, objects, variables, timers, DLG states/transitions, source spans, fingerprints, and
   opaque nodes.
2. Implement the minimum parser/import path selected by research; preserve order and unsupported
   syntax exactly enough to block unsafe analysis.
3. Add one lint per commit with focused fixtures: shadowed/unreachable block, unbalanced cutscene,
   normal/skip final-state drift, dead-object delivery, timer scope mismatch, duplicate side effect,
   unknown public writer, and unsafe claim boundary.
4. Add semantic diff and resource/public-state graphs used by adapters; do not attempt universal
   source regeneration. Exercise harmless, relevant, and opaque counterexamples, but keep adapter
   activation on exact hashes unless a later per-resource decision proves canonicalization.
5. Commit each coherent rule, ending with: `feat: add conservative script IR and safety lints`.

**Exit:** migration work can query compact semantics without repeatedly consuming whole corpora.
This task does not globally enable semantic-fingerprint activation.

### Task 37: Select and migrate one low-risk real WorldFlow target

**Depends on:** Tasks 35 and 36; G7 must pass

**Files:**

- Create: `docs/research/worldflow-first-target-selection.md`
- Create: `docs/provenance/worldflow/<target>-ledger.md`
- Create: `adapters/worldflow/<target>.lua`
- Create: `tests/scenarios/worldflow/<target>/`
- Create: `docs/compatibility/<target>-support.md`

**Steps:**

1. Score candidates for bounded public ABI, once-only effects, reversibility, external writers,
   dialogue complexity, cutscene/skip duplication, licensing, fixture feasibility, and player risk.
2. Reject any candidate requiring the active playthrough, unknown third-party intent, or an
   unprovable reward/spawn effect.
3. Inventory all effective resources and reverse references in a disposable supported stack.
4. Write replay/fixture tests before the adapter; preserve public variables and legacy entry points.
5. Implement only the supported decision/transition boundary and prove unknown-content pass-through
   when any dependency changes.
6. Run the full WorldFlow fault matrix and commit one target family.

**Exit:** E8 contains one exact supported migration; broad quest conversion remains out of scope.

### Task 38: Stabilize and prove the third-party extension API

**Research linkage (not automatic closure):** IR-06 and `COMP-API01` through `COMP-API10`

**Depends on:** Tasks 14, 15, 18, 26, 32, 36, and 37

**Files:**

- Create: `schemas/adapter-manifest.schema.json`
- Create: `sdk/register.lua`
- Create: `sdk/validate.py`
- Create: `docs/sdk/adapter-authoring.md`
- Create: `examples/cooperative-adapter/`
- Test: `tests/sdk/`

**Steps:**

1. Treat all earlier registration structures as internal and provisional. Compare what the active
   Combat Intent pilot and first real WorldFlow adapter actually needed before freezing a public
   abstraction.
2. Write RED cases for unique namespace, version, support tier, exact claims, dependencies,
   capabilities, fingerprints, public ABI, fallback, state schema, migrations, provenance, and
   diagnostics.
3. Add malicious/buggy fixtures: broad wildcard, undeclared writer, colliding namespace, raw object
   ID persistence, unsupported schema, exception, oversized trace, and attempt to promote itself.
4. Implement validation and registration so an extension can reduce only its own availability;
   it cannot broaden kernel capability or another adapter's claim.
5. Demonstrate one C2 cooperative adapter and one rejected adapter entirely in synthetic fixtures.
6. Run all `COMP-API` cases and commit: `feat: add constrained adapter extension API`.

**Exit:** supported mods can opt in explicitly without turning unknown mods into accidental native
content.

### Task 39: Build the reversible WeiDU package and independent feature gates

**Depends on:** Tasks 18, 26, 35, 37, and 38

**Files:**

- Create: `chriz-bg-script-engine/chriz-bg-script-engine.tp2`
- Create: `chriz-bg-script-engine/lib/`
- Create: `chriz-bg-script-engine/lua/`
- Create: `chriz-bg-script-engine/tra/english/setup.tra`
- Create: `tests/fake-game/test_package.py`
- Create: `docs/installation.md`

**Steps:**

1. Write failing fake-game tests for missing EEex, unsupported capability profile, SCS absent,
   supported SCS present, changed fingerprints, reinstall, upgrade, disable, uninstall, publication
   allowlist, and byte-exact restoration.
2. Define separate conventional components for kernel/observer, Combat Intent pilot, WorldFlow
   pilot/target, and development diagnostics as allowed by the final design. An adapter component
   may no-op safely without disabling unrelated components.
3. Implement the smallest WeiDU installer using capability/resource predicates and generated
   manifests. Do not manipulate the active stack or imitate WeiDU backup/uninstall internals.
4. Verify installation after unknown synthetic mods before and after; expected behavior follows the
   matrix, including stale claims.
5. Verify packaged files against provenance/fixture allowlists and credit requirements.
6. Commit: `feat: package reversible script engine alpha`.

**Exit:** the package is reversible in synthetic/disposable tests; this is not yet release approval.

### Task 40: Execute the supported compatibility, soak, and performance matrix

**Depends on:** Tasks 26, 30, 35, and 37 through 39

**Files:**

- Create: `tests/soak/supported-alpha/`
- Create: `docs/compatibility/supported-alpha-results.md`
- Create: `docs/performance/budgets.md`
- Create: `docs/recovery.md`

**Steps:**

1. Freeze exact game, EEex, SCS, SR, adapter, component, install-order, and fingerprint matrix.
2. Run every case in the initial G8 acceptance allowlist in
   `docs/compatibility/acceptance-matrix.md` that remains applicable to the frozen support profile.
   Explicitly record `pass`, `fail`, `blocked`, `not-applicable-with-profile-change`, or
   `unexecuted`; never infer a permutation.
3. Soak idle/combat/summons/area transitions/save-load/rest/disable/upgrade with representative actor
   counts and bounded logs.
4. Measure p50/p95/worst decision and observer cost, memory growth, trace volume, circuit trips,
   action unknowns, lease age, and WorldFlow recovery latency.
5. Investigate every failure and distinguish product defect, unsupported environment, fixture defect,
   and unrelated lab failure.
6. Write recovery/disable instructions that preserve legacy behavior and never tell users to edit
   WeiDU.log or active saves manually.
7. Commit: `test: execute supported alpha compatibility matrix`.

**Exit:** alpha claims can name actual evidence and untested boundaries.

### Task 41: Complete provenance, security, documentation, and G8 review

**Depends on:** Tasks 36 through 40

**Files:**

- Create: `docs/decisions/gates/G8-supported-alpha.md`
- Create: `docs/compatibility/support-matrix.md`
- Create: `docs/known-limitations.md`
- Create: `docs/architecture/runtime.md`
- Create: `docs/architecture/combat-intent.md`
- Create: `docs/architecture/worldflow.md`
- Create: `docs/sdk/compatibility-guide.md`
- Create: `CREDITS.md`
- Create: `LICENSE` or `LICENSES/` only after the licensing decision is approved

**Steps:**

1. Audit packaged code/data for secrets, personal paths, installed artifacts, upstream content,
   unsafe file operations, unbounded diagnostics, native call surfaces, and unsupported claims.
2. Reconcile every migration ledger, support manifest, test result, credit, and redistribution
   decision with package contents.
3. Verify feature flags independently disable Combat Intent, WorldFlow, and each adapter while
   preserving legacy fallthrough.
4. Run the full clean verification suite and disposable smoke from published instructions.
5. Record G8 `PASS`, `PASS WITH NARROWED SCOPE`, or `FAIL`. A pass names exact supported corpus and
   does not claim unknown-mod behavioral integration.
6. Commit: `docs: record supported alpha readiness`.

**Exit:** a release may be proposed separately. This task does not publish, create a remote, contact
upstream, or modify the active game.

## 13. E11 expansion playbook

After G8, expansion repeats a fixed loop rather than reopening the architecture:

1. Inventory and provenance one bounded family/flow.
2. Add exact support and public-state manifests.
3. Capture minimal redistributable fixtures/replays.
4. Run static eligibility and shadow/observer mode.
5. Review differences and migration economics.
6. Activate only the smallest supported claim.
7. Run focused compatibility and soak cells.
8. Update ledgers, support matrix, limitations, credits, and recovery.
9. Stop when budget, ownership evidence, or performance fails.

Unknown third-party content continues to work through untouched legacy BCS/DLG. It receives C0
pass-through and may receive non-invasive diagnostics/lints; it is never automatically converted or
claimed.

## 14. Small-agent execution packets

A delegated task packet must contain:

- one numbered task or one research/acceptance ID subset;
- exact allowed files and a no-other-files rule;
- frozen input schemas and fixtures;
- explicit non-goals;
- exact test command and expected RED/GREEN result;
- evidence/environment requirement;
- compatibility and provenance impact;
- whether commit is allowed;
- a request to report unexpected files, failures, and untested boundaries.

The integration owner performs schema changes, cross-module merges, gate decisions, disposable-game
runs, publication decisions, and any interaction with the active game. Parallel agents should not
share implementation files or independently redefine ownership semantics.

## 15. Token and cost controls

- Start with one exact EEex/game/SCS stack and one synthetic stack.
- Give agents compact manifests, IR slices, fixtures, and replay traces—not whole installed corpora.
- One spike answers one question; one implementation issue owns one behavior or transition family.
- Freeze schemas per gate and reject opportunistic interface redesign in leaf tasks.
- Store canonical research memos and migration ledgers so evidence is not repeatedly rediscovered.
- Prefer deterministic host replay to renewed engine runs.
- Limit parallel work to non-overlapping files behind frozen contracts.
- Measure migration cost after the first and second families; stop broad work at G6 if necessary.
- Invest in IR, extraction, lint, and fixture generation when manual exception handling dominates.
- Treat unknown content as a zero-migration compatibility case: leave it alone.
- Do not build a universal BCS/DLG compiler, full path planner, multiplayer synchronizer, or every-EE
  abstraction before supported vertical slices demand it.

## 16. Definition of done for this plan

This plan is fully executed only when:

- G0 through G8 have explicit decision records;
- all prerequisite P0 research and compatibility cases are resolved;
- one SCS-derived Combat Intent pilot passes shadow and narrowly active gates;
- one synthetic and one selected low-risk WorldFlow flow pass convergence tests;
- unknown/modified/stale content demonstrably remains legacy-owned;
- the reversible package, support matrix, provenance, diagnostics, recovery, and performance budgets
  are complete;
- no active-game write was used as evidence;
- a separate explicit decision determines whether to publish an alpha.

If a branch stops at a failed gate, the completed observer, lint, IR, replay, or research artifacts
remain valid deliverables. A stopped takeover is not a failed project if it prevents unsafe scope.
