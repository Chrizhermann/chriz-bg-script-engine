# AoE Historical Prebuff Research and Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Prove whether supported SCS historical AoE prebuffs already affect eligible nearby allies, preserve that behavior without generic fan-out, and add adapter-owned execution only if a later reviewed migration requires it.

**Architecture:** Start with exact source/generated-artifact characterization, then deterministic host tooling, fake-game eligibility tests, mutation-free shadow observation, and an unmodified-SCS disposable-engine baseline. The native installed spell/projectile remains the only generic recipient-selection mechanism. A compound forced cast plus spell debit is outside the current one-normal-action Combat Intent lease and may be implemented only after G5 through a separately approved ownership-hierarchy exception.

**Tech Stack:** Markdown research/provenance records, Python 3 host tooling and pytest, Lua 5.1-compatible pure policy tests, WeiDU synthetic-game fixtures, EEex in a separately authorized disposable BG2:EE laboratory, SCS 35.21 pilot artifacts.

---

**Status:** Gated dependency overlay; Task 0 completed after canonical Task 1/G0 integration

**Approved design:** `docs/plans/2026-08-30-aoe-prebuff-allies-design.md`

**Preliminary evidence:** `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`

## Execution rules

1. Never run an engine experiment against the active game or active playthrough.
2. Task 3 of the canonical roadmap still requires separate user authorization naming a disposable
   destination. Approval of this feature or plan is not that authorization.
3. Canonical ADRs, roadmap, research backlog, and acceptance matrix remain integration-owner-owned.
   This feature consumes their frozen contracts and changes them only at an explicitly approved
   later gate task.
4. Do not freeze manifest, ownership, identity, action-attempt, capability, snapshot, geometry,
   trace, persistence, or kill-switch schemas in this feature branch. Consume the integration
   owner's frozen contracts.
5. Preserve intentional RED evidence before each production or research-tool implementation.
6. Generated SCS BAF/BCS/SPL/PRO, installed resources, saves, logs with personal paths, and upstream
   source remain local/reference-only unless the provenance gate explicitly authorizes a fixture.
7. Queue acceptance is never execution evidence. Every runtime conclusion needs engine progress and
   an independent postcondition.
8. An ambiguous cast/debit occurrence has retry budget zero unless stable evidence proves that
   neither side effect occurred.
9. If stock supported SCS passes the baseline, do not create standalone corrective delivery code.
10. If an expected prerequisite file/interface differs after integration, stop and update this plan
    through the integration owner rather than creating a parallel abstraction.
11. Except for the self-contained Task 2 research extractor, tasks that consume future frozen
    interfaces are dependency/scenario specifications, not yet code-level executable plans. At the
    start of each such task, invoke `@writing-plans` against the now-existing interfaces and replace
    that task with exact code, commands, and bite-sized commits before editing implementation files.

## Dependency overview

```text
Canonical Task 1 / G0 integration (completed)
├── canonical Tasks 4 + 5 + 6 + 13 ──> Task 1 below (evidence:E1 ledger)
├── canonical Tasks 4 + 5 + 13 ──────> Task 2 below (evidence:E2 tooling)
├── canonical Tasks 14–17 ──────> Task 3 below (synthetic-game contract)
├── canonical Tasks 20–24 / G4 ─> Task 4 below (shadow-only model)
└── canonical Task 3 authorization + Tasks 6, 9, 26, 28
                                  └─> Task 5 below (disposable baseline)
                                       └─> Task 6 architecture decision
                                            └─> Task 7 selected branch
                                                 └─> Task 8 supported soak
```

### Task 0: Reconcile with integrated G0 and refresh temporary evidence vocabulary

**Files:**

- Verify: `AGENTS.md`
- Verify: `docs/decisions/gates/G0-charter.md`
- Verify: `scripts/validate-g0-decisions.ps1`
- Verify: `docs/plans/2026-08-27-research-and-vertical-slices.md`
- Modify if needed: `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`
- Modify if needed: `docs/plans/2026-08-30-aoe-prebuff-allies-design.md`
- Modify if needed: this plan and its `.tasks.json`

**Step 1: Confirm the branch is clean before integration-owner work**

Run:

```powershell
git status --short --branch
```

Expected: this feature branch and no unrelated working-tree changes.

**Step 2: Stop if G0 artifacts are not integrated**

Run:

```powershell
$required = @(
  'docs/decisions/gates/G0-charter.md',
  'scripts/validate-g0-decisions.ps1'
)
$required | ForEach-Object { if (-not (Test-Path -LiteralPath $_)) { throw "Canonical Task 1 not integrated: $_" } }
```

Expected after integration: no output. Task 0 recorded that result before reconciliation.

**Step 3: Run the integrated G0 validator**

Run:

```powershell
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
```

Expected: PASS using the integrated task's documented output. Investigate any failure; do not edit
the validator merely to make this feature pass.

**Step 4: Reconcile evidence terminology and ownership naming**

Read the integrated G0 charter, authority vocabulary, evidence terminology, and resource-prefix
decision created by Task 1. Update only temporary wording in this feature's memo/design/plan.
Preserve the underlying facts and hashes. Do not modify the canonical documents from this task.

**Step 5: Verify and commit only if reconciliation changed files**

Run:

```powershell
git diff --check
git diff -- docs/research/2026-08-30-scs-aoe-prebuff-delivery.md docs/plans/2026-08-30-aoe-prebuff-allies-design.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md.tasks.json
```

Expected: only terminology/gate-reference updates and synchronized Task 0 status/metadata. If
changed:

```powershell
git add -- docs/research/2026-08-30-scs-aoe-prebuff-delivery.md docs/plans/2026-08-30-aoe-prebuff-allies-design.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md.tasks.json
git commit -m "docs: align AoE prebuff work with G0"
```

### Task 1: Canonicalize the evidence:E1 material in the Task 6 SCS prebuff ledger

**Prerequisites:** Canonical Tasks 4, 5, 6, and 13 have created and frozen the
evidence/provenance, pilot-ledger, inventory, and test-runner interfaces.

**Files:**

- Modify: `docs/research/SCS-03-prebuff-accounting.md`
- Modify: `docs/provenance/scs/prebuff-pilot-ledger.md`
- Modify: `tests/fixtures/manifests/scs-pilot.synthetic.json`
- Modify: `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`
- Test: use the schema/ledger validation test established by Tasks 4–6; if none exists, create
  `tests/schemas/test_scs_prebuff_pilot_ledger.py`

**Step 1: Write the failing ledger assertion**

Using the frozen schema's actual field names, require one pilot entry that records:

- logical Improved Haste prebuff family;
- SCS 35.21 source/generator provenance;
- the concrete sampled generated-BAF candidate and its hash;
- original/prebuff SPL hashes and matching raw target/projectile fields;
- preparation trigger class and separate accounting spell;
- disposition `needs-engine-proof`;
- runtime ally delivery and exactly-once accounting `unknown`;
- local-only/reference-only artifact status;
- the approved decision “native cast preferred; no generic per-ally fan-out.”

Do not invent schema keys. If the frozen schema cannot represent one of these facts, stop and ask
the integration owner to extend the canonical schema.

**Step 2: Run the focused test to verify RED**

Run the exact schema command documented by Task 4. If the fallback test file was needed:

```powershell
python -m pytest tests/schemas/test_scs_prebuff_pilot_ledger.py -q
```

Expected: FAIL because the AoE historical-prebuff entry is absent or incomplete.

**Step 3: Add the minimal ledger/research entry**

Transfer independently written metadata and hashes from the preliminary memo. Do not copy local
BAF/SPL/PRO bytes, decompiles, or personal paths. Link the approved design and retain every stated
uncertainty.

**Step 4: Validate deterministic inventory and exact-hash behavior**

Run the actual tests created by Task 5:

```powershell
python -m pytest tests/tooling/test_inventory.py tests/tooling/test_exact_hash.py -q
```

Expected: PASS, including deterministic shuffled-input output and exact-byte invalidation cases.
If an extra manual mutation probe is needed, copy the synthetic fixture into a newly created
temporary directory, mutate the temporary copy, and delete only that exact temporary directory
after resolving its absolute path. Never mutate a tracked fixture in place.

**Step 5: Run focused and full tests**

```powershell
python -m pytest tests/schemas tests/tooling/test_inventory.py tests/tooling/test_exact_hash.py -q
pwsh -NoProfile -File scripts/test.ps1 -Suite unit
```

Expected: PASS. If the repository's integrated commands differ, use the commands frozen by Tasks
2/13 and update this plan before proceeding.

**Step 6: Commit**

```powershell
git add -- docs/research/SCS-03-prebuff-accounting.md docs/provenance/scs/prebuff-pilot-ledger.md tests/fixtures/manifests/scs-pilot.synthetic.json docs/research/2026-08-30-scs-aoe-prebuff-delivery.md tests/schemas/test_scs_prebuff_pilot_ledger.py
git commit -m "research: ledger SCS AoE historical prebuff evidence"
```

Omit the fallback test path from `git add` if the canonical schema test already covered the entry.

### Task 2: Add deterministic SPL delivery-shape extraction

**Prerequisites:** Canonical Tasks 4, 5, and 13; artifact-policy and test-runner interfaces are
frozen.

**Files:**

- Create: `tools/corpus/spl_delivery_shape.py`
- Create if absent: `tests/helpers/synthetic_spl.py`
- Test: `tests/tooling/test_spl_delivery_shape.py`
- Modify: `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`

**Step 1: Write independently authored synthetic SPL fixtures**

Create a minimal SPL V1 builder that writes only the fields used by the parser. Fixtures must be
generated during tests, not copied from the game or SCS. Include:

- one point-target ability with projectile raw value 158;
- two level headers with different minimum caster levels;
- casting features separate from ability effects;
- opcode 146 child-spell references;
- malformed offsets/counts and an unknown signature.

**Step 2: Write the failing parser tests**

The core positive assertion should have this shape:

```python
def test_extracts_delivery_shape_without_inferring_geometry():
    data = build_synthetic_spl(
        abilities=[
            {"target": 4, "min_level": 1, "casting_time": 6, "projectile": 158},
            {"target": 4, "min_level": 12, "casting_time": 6, "projectile": 158},
        ],
        ability_effects=[{"opcode": 146, "target": 2, "resource": "CHILD001"}],
        casting_effects=[{"opcode": 139, "target": 1, "resource": ""}],
    )

    shape = extract_spl_delivery_shape(data)

    assert shape["ability_count"] == 2
    assert shape["abilities"][0]["target"] == 4
    assert shape["abilities"][0]["projectile_raw"] == 158
    assert shape["child_spell_resrefs"] == ["CHILD001"]
    assert "radius" not in shape
```

Also require exact SHA-256, deterministic JSON ordering, bounds rejection, casting-feature
separation, and no interpretation of projectile identity, ally eligibility, or geometry.

**Step 3: Run the focused test to verify RED**

```powershell
python -m pytest tests/tooling/test_spl_delivery_shape.py -q
```

Expected: FAIL with `ModuleNotFoundError` for `tools.corpus.spl_delivery_shape`.

**Step 4: Implement the minimal extractor**

Use `struct.unpack_from` with explicit little-endian formats. The implementation should follow this
interface and reject every out-of-bounds slice:

```python
def extract_spl_delivery_shape(data: bytes) -> dict:
    """Return structural delivery metadata; never infer runtime geometry."""
```

Read only the validated SPL V1 fields already documented by the evidence memo:

- signature;
- ability/effect offsets and counts;
- target, minimum level, casting time, effect index/count, raw projectile;
- casting-feature slice;
- effect opcode, target, probability window, and resource;
- opcode 146 child resrefs;
- exact input SHA-256.

Do not classify buffs, normalize PROJECTL IDs, parse PRO geometry, or silently truncate malformed
data.

**Step 5: Run focused tests and verify GREEN**

```powershell
python -m pytest tests/tooling/test_spl_delivery_shape.py -q
```

Expected: PASS, including malformed-input cases.

**Step 6: Run the repository suite twice**

```powershell
pwsh -NoProfile -File scripts/test.ps1 -Suite unit
pwsh -NoProfile -File scripts/test.ps1 -Suite unit
```

Expected: identical passing results with no fixture-order or global-state dependence.

**Step 7: Compare local evidence read-only**

Run the tool against local Improved Haste original/prebuff files only through the Task 5 redacted
inventory boundary. Expected: target/projectile equality and the hashes already recorded in the
memo. Do not retain input bytes or absolute paths. Any mismatch reopens the memo; do not adjust the
test to the expected value.

**Step 8: Commit**

```powershell
git add -- tools/corpus/spl_delivery_shape.py tests/helpers/synthetic_spl.py tests/tooling/test_spl_delivery_shape.py docs/research/2026-08-30-scs-aoe-prebuff-delivery.md
git commit -m "test: extract SPL delivery shape deterministically"
```

### Task 3: Prove fake-game eligibility, legacy response shape, and rollback

**Prerequisites:** Tasks 1 and 2 of this plan; canonical Tasks 14–17. This task uses their frozen
manifest, bridge, installer, and fake-game harness rather than creating a second harness.

**Files:**

- Create: `tests/fake-game/test_aoe_historical_prebuff.py`
- Create: `tests/fixtures/aoe-historical-prebuff/`
- Modify only through frozen interfaces: `tests/fixtures/manifests/scs-pilot.synthetic.json`
- Modify: `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`

**Step 1: Write the failing synthetic-game test**

Use independently authored SPL/PRO/BCS fixtures. Require:

- exact supported metadata recognizes the synthetic legacy prebuff family as eligible for
  observation while runtime activation remains disabled;
- the independently authored legacy BCS fixture contains one native forced-cast action and one
  corresponding debit action;
- no adapter request or force-cast bridge is generated before the Task 6 architecture decision;
- one changed SPL, PRO, child spell, accounting resource, or BCS control byte makes the claim stale;
- unknown/opaque resources remain byte-identical and legacy-owned;
- install, reinstall, failed install, and uninstall restore fixture-owned originals byte-for-byte;
- no generated upstream or installed artifact enters the publication allowlist.

**Step 2: Run the focused test to verify RED**

```powershell
python -m pytest tests/fake-game/test_aoe_historical_prebuff.py -q
```

Expected: FAIL because the fixture/manifest entry is absent.

**Step 3: Add the minimum synthetic fixture and manifest entry**

Use the actual Task 14 manifest schema. Keep runtime activation disabled; this task proves only
static observation eligibility, legacy response shape, packaging, and restoration. Do not add an
adapter-owned compound request type or generated force-cast response.

**Step 4: Run GREEN and byte-exact restoration checks**

```powershell
python -m pytest tests/fake-game/test_aoe_historical_prebuff.py -q
python -m pytest tests/integration/test_unknown_passthrough.py tests/integration/test_install_order.py -q
```

Expected: PASS. The result must explicitly state that no ally range, projectile delivery, caster
level, or runtime spell expenditure was proved.

**Step 5: Commit**

```powershell
git add -- tests/fake-game/test_aoe_historical_prebuff.py tests/fixtures/aoe-historical-prebuff tests/fixtures/manifests/scs-pilot.synthetic.json docs/research/2026-08-30-scs-aoe-prebuff-delivery.md
git commit -m "test: prove AoE prebuff legacy fake-game contract"
```

### Task 4: Model the AoE historical-prebuff candidate in mutation-free shadow mode

**Prerequisites:** Canonical Tasks 20–24 and G4 prerequisites; Tasks 1–3 of this plan; the pilot
entry is ledger-approved. General AoE geometry may remain unknown because this task cannot
dispatch.

**Files:**

- Modify: `adapters/scs/prebuff_pilot.lua`
- Test: `tests/integration/test_scs_aoe_historical_prebuff_shadow.py`
- Modify: `docs/research/mage-prebuff-shadow-results.md`

**Step 1: Write RED tests at the frozen interfaces**

Cover only the exact ledger-approved pilot and require:

- matching actor, effective generated action, accounting spell, dependency closure, and stack
  epoch produce one `observed_legacy_prebuff` shadow trace, never one action per prospective ally;
- when exact projectile/PRO closure is unavailable, recipient prediction is explicitly `unknown`
  rather than a decline or inferred geometry;
- when curated exact geometry is available, predicted recipients are diagnostic only and contain
  no native object/userdata;
- stale hash, missing mapping, higher owner, preparation-window mismatch, Project Image owner lock,
  depleted spell, existing one-shot state, or unknown actor returns decline with a stable reason;
- the kernel type boundary makes dispatch impossible in shadow mode;
- no locals, globals, queues, spellbooks, effects, or durable records are mutated.

**Step 2: Run the focused tests to verify RED**

```powershell
python -m pytest tests/integration/test_scs_aoe_historical_prebuff_shadow.py -q
```

Expected: FAIL because the candidate mapping is absent.

**Step 3: Implement the smallest read-only mapping**

Consume the frozen manifest/snapshot/trace shapes. Add no new public action schema, no dispatch
path, and no generic `ReallyForceSpell` capability. If the existing frozen trace cannot represent
`observed_legacy_prebuff` plus an unknown recipient prediction, stop for an integration-owner plan
refresh instead of modifying `combat-intent/actions.lua` from this task.

**Step 4: Run focused and full suites**

```powershell
python -m pytest tests/integration/test_scs_aoe_historical_prebuff_shadow.py tests/integration/test_scs_mage_shadow.py -q
pwsh -NoProfile -File scripts/test.ps1
```

Expected: PASS and explicit zero-mutation assertions.

**Step 5: Commit**

```powershell
git add -- adapters/scs/prebuff_pilot.lua tests/integration/test_scs_aoe_historical_prebuff_shadow.py docs/research/mage-prebuff-shadow-results.md
git commit -m "feat: shadow SCS AoE historical prebuff delivery"
```

### Task 5: Prove the unmodified SCS baseline in the disposable engine

**Prerequisites:** Tasks 1–4 of this plan; canonical Task 3 has explicit authorization for a named
lab and has passed isolation/reset proof; Tasks 6 and 9 are complete; Task 26/G5 has proved
ordinary-action containment; Task 28/SPACE-02 has resolved the exact pilot projectile/PRO closure.
None of those ordinary-action results authorize this compound forced action.

**Files:**

- Create: `docs/research/aoe-historical-prebuff-engine-proof.md`
- Create: `tests/scenarios/combat/aoe-historical-prebuff/README.md`
- Create: `experiments/aoe-historical-prebuff/README.md`
- Create: `experiments/aoe-historical-prebuff/observe.lua`
- Create: `experiments/aoe-historical-prebuff/verify_export.py`
- Test: `tests/integration/test_scs_aoe_historical_prebuff_baseline.py`

**Step 1: Write the scenario assertions before running the game**

The first case must use the concrete Improved Haste candidate traced from generated BAF through
compiled BCS and an assigned disposable actor. Define independent observations for:

- preparation branch reached;
- force-cast action started/executed;
- projectile/cast postcondition;
- selected caster-level ability and source identity where observable;
- one original spell debit;
- one-shot state;
- per-actor outcome: affected, already present, protected/immune, invalidated, or unknown.

Do not make “every prospective ally has an effect” the cast-completion postcondition.

**Step 2: Run the verifier before any disposable mutation to preserve RED**

```powershell
python -m pytest tests/integration/test_scs_aoe_historical_prebuff_baseline.py -q
```

Expected: FAIL with a precise missing-evidence-export assertion. Preserve this output in the task
record; do not weaken the verifier.

**Step 3: Verify the lab and reset before every mutation**

Run the exact `check`, `reset`, launch, process-shutdown, and evidence-export commands frozen in
`docs/research/PREP-03-disposable-lab-runbook.md`. Expected: named marker and isolation checks pass;
the known active root and every alias are refused. If the runbook has no exact command for one of
these operations, stop and fix Task 3 rather than improvising.

**Step 4: Establish unmodified SCS baseline cases**

Use actors at controlled distances derived from the now-inspected PRO closure:

- caster;
- prospective eligible actors inside, at, and outside the proven boundary;
- hostile and neutral actors;
- summon and charmed/allegiance-changing actor;
- already-buffed and protected/immune actor;
- moving, dead, despawned, and area-transitioning actor.

Wait for engine ticks and independently inspect effects/source identity and spellbook accounting.
Record queue/action observations separately.

**Step 5: Exercise compound failure windows**

Cover queue clearing, caster death, Project Image owner lock, save/load, quickload, area transition,
runtime disable, and actor replacement between candidate observation and resolution. Never rerun an
ambiguous occurrence. Reset the lab between destructive scenarios.

Generated/local engine output goes only to the external directory defined by the runbook, under a
task-specific child such as
`$env:BGSE_DISPOSABLE_EVIDENCE_ROOT\aoe-historical-prebuff\<run-id>`. It must not be inside the
repository. The authored `observe.lua` and `verify_export.py` are committed only after provenance
review and must contain no local paths or copied game/SCS content.

**Step 6: Run the focused host verifier**

```powershell
python -m pytest tests/integration/test_scs_aoe_historical_prebuff_baseline.py -q
```

Expected: PASS only when the exported redacted evidence proves the declared result. A missing
observation is `unknown`, not pass. The test must fail if it sees only “queued/accepted.”

**Step 7: Repeat supported shape probes cautiously**

Test Haste, Bless, and Defensive Harmony only after each is traced to a concrete generated and
assigned action. Otherwise label it a resource-shape probe, not actor behavior. Repeat the exact
pilot across declared vanilla/SR/SCS+SR stacks only when each stack is independently provisioned
and fingerprinted.

**Step 8: Classify the baseline**

- **Proven:** native SCS delivery and one debit satisfy the exact pilot contract.
- **Concrete defect:** exact generated action/resource fails a declared postcondition.
- **Unknown:** observations cannot distinguish the outcome.

Do not implement a fix in this task.

**Step 9: Commit only authored and redacted permitted evidence**

```powershell
git add -- docs/research/aoe-historical-prebuff-engine-proof.md tests/scenarios/combat/aoe-historical-prebuff/README.md experiments/aoe-historical-prebuff/README.md experiments/aoe-historical-prebuff/observe.lua experiments/aoe-historical-prebuff/verify_export.py tests/integration/test_scs_aoe_historical_prebuff_baseline.py
git commit -m "research: prove SCS AoE historical prebuff baseline"
```

Do not add local experiment output unless the Task 4 provenance allowlist explicitly permits its
independently authored/redacted form.

### Task 6: Record the post-G5 architecture and go/no-go decision

**Prerequisites:** Tasks 4 and 5 of this plan; canonical G5 and SPACE-02; integration owner review.

**Files:**

- Create: `docs/decisions/gates/G5A-aoe-historical-prebuff.md`
- Modify if approved by the integration owner: `docs/plans/2026-08-27-script-engine-architecture-design.md`
- Modify if approved by the integration owner: `docs/compatibility/acceptance-matrix.md`
- Modify: `docs/plans/2026-08-30-aoe-prebuff-allies-design.md`
- Modify: this plan and its `.tasks.json`

**Step 1: Write the decision record before production code**

Record the baseline evidence, exact support envelope, compound-action mismatch with the one-normal-
action lease, failure windows, zero-retry rule, geometry evidence, and smallest-scope fallback.

**Step 2: Classify the baseline first**

1. **Proven:** stock SCS satisfies the requirement. Branch A preservation coverage is required.
2. **Concrete native defect:** stop and design a fingerprinted spell-family exception. Generic
   per-ally `ApplySpellRES` remains forbidden.
3. **Unknown:** keep the adapter shadow-only and legacy-owned.

For a proven baseline, make a second independent decision: is a deliberate SCS-family migration
actually requested and is the ownership-hierarchy exception approved? If yes, Branch B follows
after Branch A. If no, the work completes with Branch A and no production implementation.

**Step 3: Review canonical changes**

Canonical architecture/acceptance edits belong to the integration owner. The new G5A record must
state explicitly that ordinary-action G5 evidence is prerequisite context, not coverage for this
compound forced operation. If no architecture exception is approved, mark Branch B not applicable
rather than leaving production-action work aspirational.

**Step 4: Run documentation/gate validation**

```powershell
pwsh -NoProfile -File scripts/validate-g0-decisions.ps1
git diff --check
pwsh -NoProfile -File scripts/test.ps1
```

Expected: PASS and one unambiguous branch in the decision record.

**Step 5: Commit**

```powershell
git add -- docs/decisions/gates/G5A-aoe-historical-prebuff.md docs/plans/2026-08-30-aoe-prebuff-allies-design.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md docs/plans/2026-08-30-aoe-historical-prebuff-research-and-implementation.md.tasks.json
git commit -m "docs: decide AoE historical prebuff ownership"
```

Add canonical architecture/acceptance paths to the commit only when the integration owner approved
those exact edits.

### Task 7: Execute the selected implementation branch

**Prerequisites:** Task 6 records a proven baseline or a separately redesigned concrete-defect
path. An unknown baseline makes this task not applicable.

#### Branch A: Baseline-preservation

**Files:**

- Modify: `tests/integration/test_scs_aoe_historical_prebuff_baseline.py`
- Modify: `docs/compatibility/acceptance-matrix.md`
- Modify: `docs/compatibility/support-manifest.md`

**Steps:**

1. Write a failing acceptance assertion that the supported stock-SCS pilot retains native area
   delivery and one debit while the engine is observer/shadow-only.
2. Run the focused test; expected: RED until the supported manifest and acceptance cell include the
   baseline evidence.
3. Add only the manifest/acceptance metadata and regression fixture. Do not add corrective runtime
   delivery code.
4. Run focused and full suites; expected: PASS.
5. Commit: `test: preserve native SCS AoE prebuff delivery`.

After Branch A passes, record it complete even if no migration is requested.

#### Branch B: Optional migration-preservation

Do not implement from this pre-schema plan. The integration owner must first freeze the dedicated
forced-operation request, compound attempt/outcome, authority, observer, kill-switch, and fallback
interfaces. Then invoke `@brainstorming` only for any newly introduced design choices and use
`@writing-plans` to replace this branch with a code-level TDD plan against the real interfaces.

That follow-on plan must include, at minimum:

- a default-off, exact-pilot-only typed request;
- no generic public `ForceCast` or per-recipient apply API;
- native cast plus exactly one debit;
- independent delivery/accounting observations;
- zero retry across ambiguity and lifecycle discontinuity;
- Project Image, higher-owner, stale-stack, actor replacement, and runtime-disable decline;
- adapter-local quarantine/circuit breaker;
- synthetic, disposable, save/load, and legacy-handback tests.

#### Branch C: Concrete native defect

Stop. Capture the exact failed spell/action/projectile family and return to `@brainstorming`. Any
exception is spell-family-specific and fingerprinted. Do not fall through to Branch B or generic
fan-out automatically. This plan does not authorize that redesign: record Tasks 7 and 8 as
`completed` with result `not_applicable_pending_redesign` and preserve the exact defect as the
blocker. A later approved redesign gets a new or explicitly superseding plan rather than silently
reactivating these tasks.

#### Unknown, rejected, or unresolved concrete-defect outcomes

Record Task 7 as `completed` with result `not_applicable`, keep the family shadow-only/legacy-owned,
and record Task 8 as `completed` with result `not_applicable`. Pending task state must not survive a
terminal no-go decision. For a concrete defect, retain the more specific
`not_applicable_pending_redesign` result from Branch C.

### Task 8: Add supported-stack matrix and soak coverage

**Prerequisites:** Branch A acceptance is complete or an approved Branch B follow-on implementation
has passed its own active gate. The integration owner has assigned this as an explicit sub-work-item
of canonical Task 40 before Task 40 closes.

**Files (within canonical Task 40 ownership):**

- Create: `tests/soak/supported-alpha/aoe-historical-prebuff/`
- Modify: `docs/compatibility/supported-alpha-results.md`
- Modify: `docs/recovery.md`
- Modify: `docs/compatibility/support-manifest.md`

**Step 1: Freeze the exact support matrix**

Name game executable, EEex, SCS, SR, EET, adapter, component order, generated action, original SPL,
prebuff SPL, projectile/PRO closure, and every dependency hash. No inferred permutation.

**Step 2: Run repeated supported cases**

Cover combat entry, repeated combats, save/load, quickload, area transitions, rest, summons/clones,
Project Image, actor replacement, stack drift, runtime disable, observer error, and SCS absent.
Record `pass`, `fail`, `blocked`, `not-applicable`, or `unexecuted` per cell.

**Step 3: Measure and investigate**

Record decision/observer cost, trace volume, unknown outcomes, blocked occurrences, circuit trips,
and memory growth. Investigate every failure instead of averaging it away.

**Step 4: Verify recovery and fallback**

The recovery guide must preserve legacy behavior and must not direct users to edit WeiDU.log,
installed resources, or active saves manually.

**Step 5: Run the full clean suite and commit**

```powershell
pwsh -NoProfile -File scripts/test.ps1
git diff --check
```

Expected: PASS with all unexecuted cells explicitly recorded.

```powershell
git add -- tests/soak/supported-alpha/aoe-historical-prebuff docs/compatibility/supported-alpha-results.md docs/recovery.md docs/compatibility/support-manifest.md
git commit -m "test: soak supported AoE historical prebuff delivery"
```

## Completion condition

This plan is complete when all task records are terminal (`completed`, including an explicit
`not_applicable` result where appropriate) and one evidence-backed outcome is true:

- supported stock SCS delivery is preserved through regression/acceptance coverage with no
  corrective runtime code;
- an explicitly approved migration operation passes its dedicated synthetic, disposable, and soak
  gates; or
- the family remains shadow-only/legacy-owned with the blocker and unknowns recorded.

“Plan exhausted” or “queue accepted” is never completion.
