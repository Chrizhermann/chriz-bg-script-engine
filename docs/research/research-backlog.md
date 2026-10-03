# Research and Preparation Backlog

**Status:** Initial research program

**Project:** `chriz-bg-script-engine`

**Primary modules:** Combat Intent, WorldFlow, Shared Runtime Kernel, SCS Adapter, Legacy BCS/DLG
Adapter, Script Analysis Tooling

## Purpose

This document is the issue-ready research and preparation backlog for a compatibility-first Infinity Engine scripting platform. The long-term goal is broader than enemy AI: preserve and selectively reuse SCS's large body of tactical knowledge, replace brittle tactical control flow with Combat Intent, and gradually make authored quest, dialogue, cutscene, and encounter orchestration safer through WorldFlow.

The program is deliberately incremental. It does not assume that arbitrary BCS or DLG can be converted automatically, that queued actions have executed, that every engine side effect can be made exactly-once, or that every EEex API is safe at every lifecycle point. Each of those claims must be earned with evidence.

## Non-negotiable architectural invariants

1. **Unknown or uncertain content yields completely to legacy behavior.** Unsupported must not mean incompatible. An unknown creature, script, dialogue, quest, or mod remains controlled by its original BCS/DLG unless a versioned adapter explicitly and safely claims it.
2. **Enrollment is explicit and provenance-aware.** No global class-based scan may silently enroll every mage, fighter, creature, or quest resource.
3. **Legacy fallback remains executable.** A failed probe, stale adapter, runtime error, missing capability, ownership conflict, or uncertain decision must release control rather than suppress the original scripts.
4. **Normal engine actions remain authoritative.** Combat Intent should preserve aura, casting time, interruption, target validity, spell slots, item charges, and ordinary action semantics. Queue acceptance is never treated as execution success.
5. **Persistent story logic is held to a higher standard than combat logic.** WorldFlow must use durable states, explicit preconditions and postconditions, idempotent steps where possible, and recovery where exact atomicity is impossible.
6. **No persistent object IDs or engine userdata.** Runtime handles are ephemeral and must be semantically re-resolved after save/load, area transition, respawn, or actor replacement.
7. **The active game installation is read-only.** Runtime research and validation use synthetic fixtures and a disposable full game environment. No research spike authorizes installation or mutation of the active playthrough.
8. **SCS is a knowledge source and transitional runtime partner, not a disposable obstacle.** Useful tactical rules, compatibility knowledge, encounter contracts, and selected implementation patterns should be retained with precise provenance and attribution.
9. **Combat Intent and WorldFlow share infrastructure but not failure domains.** A combat scorer failure must not corrupt persistent quest state; a WorldFlow recovery must not seize unrelated actors.
10. **Compatibility is a design property.** Install order, semantic fingerprints, stable public globals, safe fallback, schema migration, uninstall, and unknown-mod behavior are researched before broad deployment.

## Evidence grades

Every research issue must close with one outcome: **Proven**, **Conditional**, **Rejected**, or **Unknown**. It must cite every applicable evidence layer reached and any required layer that remains unexecuted.

| Grade | Meaning | Acceptable use |
|---|---|---|
| **E0 — Claim** | Upstream documentation, comment, forum statement, or unverified design assumption. | Generates a question; cannot alone justify safety-critical behavior. |
| **E1 — Static evidence** | Pinned source inspection, effective resource, binary structure, decompile, install log, or provenance chain. | Supports implementation hypotheses and fixture selection. |
| **E2 — Host simulation** | Deterministic pure-Lua/model tests, replay, property tests, or state-machine exploration outside the game process. | Proves kernel logic independent of EEex boundary behavior. |
| **E3 — Synthetic-game evidence** | Real WeiDU operating on a minimal fake game, including public installer and byte-exact uninstall behavior. | Proves packaging, compilation, patching, and restoration. |
| **E4 — Disposable-engine evidence** | Observed behavior in an isolated full BG2:EE + EEex test environment. | Required for engine lifecycle, action, save/load, dialogue, cutscene, and spatial claims. |
| **E5 — Supported-corpus evidence** | Repeated scenario matrix, compatibility variants, save/load cycles, performance stress, and soak testing. | Required before broad adapter expansion or public preview. |

Native crashes bypass Lua error handling. A successful pcall around a dangerous engine call is not evidence that the call is safe. Calls that cross fragile userdata or C++ boundaries require source-backed preconditions and disposable-engine validation.

## Priority and blocker labels

### Approved deferral: COMP-P13 — true QuickLoad

**Status:** Deferred, unexecuted — not waived or passed. Christopher approved moving this
specific Task10/G1 check to later compatibility testing on2026-10-04. Ordinary named loading
is separate evidence; it cannot close this item. The area-transition non-continuation finding
also goes into G1 review, not into a passing continuation claim.

**Owner / due checkpoint:** Integration owner; Task40 supported compatibility batch, before G8
and before any true-QuickLoad support claim. Revisit earlier if an allowed invocation route is
established or implementation changes the load/lifecycle boundary. Keep this ID in Task40's
persisted checkpoint and the acceptance matrix so completing Task10 cannot hide it.

**Closure:** Record the exact engine/profile and an authorized, verified invocation of the actual
QuickLoad path. On an own disposable save, observe save identity/durable facts, clearing of
ephemeral attempts, fresh actor resolution, no duplicate callback registration or unintended
action replay, and post-load legacy behavior. Preserve command/event/postcondition evidence
and have the integration owner review it. A named load of the quicksave slot is not a substitute.
No new OS-input permission follows from the deferral. If still unavailable, record it as blocked
at Task40; G8 must resolve the support restriction explicitly, never silently drop the case.

Every issue created from this document should carry:

- **Type:** research-spike or preparation
- **Area:** prep, eeex, scs, bcs, dlg, flow, ir, action, worldflow, space, performance, test, or licensing
- **Priority:** P0, P1, or P2
- **Blocker:** repository, observer, combat-pilot, worldflow-pilot, compatibility-expansion, or public-preview

Priority meanings:

- **P0:** Establishes a safety boundary or blocks the next vertical slice.
- **P1:** Required before the corresponding subsystem can expand beyond a narrow pilot.
- **P2:** Required before supported-corpus expansion or public preview, but not the first feasibility proof.

`Dependencies` lists hard prerequisites for beginning the spike and is intentionally acyclic. A
dependency is satisfied by review of the prerequisite spike's exit artifact, not by completion of
unrelated work in the same implementation task. When dependent spikes cross task boundaries, the
implementation plan must name the artifact checkpoint that releases the dependent work.

Later disposable or soak issues may add evidence layers without becoming a backward dependency;
record those as validation links when closing the later issue.

## Research gates

These `RG*` gates summarize when groups of research spikes are mature enough to inform the
program. They do not replace the architecture program gates `G0` through `G8`; the implementation
plan maps completed research evidence into those stricter authorization decisions.

### RG0 — Research foundation ready

The support baseline, evidence ledger, failure taxonomy, repository boundaries, and licensing hold points exist. Research results can be reproduced without the active game.

### RG1 — Observer feasibility

A read-only observer can identify an explicitly enrolled actor, reconstruct a fair perceived state, correlate it with the effective SCS/legacy script stack, and emit a deterministic explanation without changing gameplay or persistent state.

### RG2 — Combat Intent pilot

One tagged mage can safely lease one narrow combat decision, execute it through ordinary engine behavior, observe its outcome, and yield to SCS or legacy BCS on every uncertainty, error, ownership change, or resource mismatch.

### RG3 — WorldFlow pilot

A miniature quest flow converges on the same declared world state after normal execution, skip, interruption, save/load, missing actors, and runtime disablement, without duplicated irreversible effects or cutscene lock.

### RG4 — Compatibility expansion

Adapters are expanded by audited behavior family or encounter pack. Unknown content remains untouched; changed supported content is detected semantically and yields safely.

### RG5 — Public preview readiness

Licensing, provenance, release packaging, byte-exact uninstall, performance budgets, save safety, compatibility matrix, failure recovery, and supported-corpus soak meet documented thresholds.

---

# Epic PREP — Research governance and compatibility charter

## PREP-01 — Pin the initial support baseline and fail-closed contract

**Labels:** preparation, area:prep, priority:P0, blocker:repository

**Question:** What exact game, EEex, WeiDU, EET, SCS, Spell Revisions, operating-system, and install-order baseline is initially supported, and what does unsupported-but-compatible mean?

**Why it matters:** Compatibility cannot be tested against an undefined platform. Broad version promises would multiply engine-structure, resource, and installer variables before the first safe handoff is proven.

**Method and evidence:** Inventory the current target ecosystem read-only, pin upstream source revisions where available, and classify each dependency as required, optional adapter, observed-only, or explicitly deferred. Define behavior for version mismatch, missing capability, and an unrecognized resource. Evidence target: E1.

**Artifacts and deliverable:** `docs/research/PREP-01-support-baseline.md` containing version identifiers, capability assumptions, install-order expectations, adapter applicability, and the normative yield-to-legacy rule.

**Exit criterion:** Every dependency has an explicit support state; every unsupported or uncertain case has a deterministic non-claim outcome; no document implies support for an untested engine or EEex version.

**Dependencies:** None.

**Gate contribution:** Required for RG0 and all later gates.

## PREP-02 — Establish the evidence and provenance ledger

**Labels:** preparation, area:prep, priority:P0, blocker:repository

**Question:** Can every adopted rule, compatibility exception, fixture, source transformation, and runtime conclusion be traced to its origin and evidence?

**Why it matters:** This project will mix original architecture, observable game behavior, SCS-derived knowledge, generated resources, synthetic fixtures, and local-only evidence. Without structured provenance, later refactoring and licensing review become guesswork.

**Method and evidence:** Define stable identifiers for source files, installed resources, decompiles, traces, fixtures, research results, and transformations. Record version, hash, acquisition date, owning component, source path, redistribution status, and evidence grade. Evidence target: E1.

**Artifacts and deliverable:** A machine-readable provenance schema, a human-readable evidence index, and templates for research-result headers and artifact manifests.

**Exit criterion:** A reviewer can trace a sample Combat Intent rule and a sample WorldFlow compatibility contract from design statement to exact evidence without consulting personal memory or the active game.

**Dependencies:** PREP-01.

**Gate contribution:** Required for RG0; foundational to RG4 and RG5.

## PREP-03 — Build the failure, safety, and compatibility threat model

**Labels:** research-spike, area:prep, priority:P0, blocker:repository

**Question:** Which failures can corrupt combat, quests, saves, install compatibility, or engine stability, and how can each be contained?

**Why it matters:** A clever decision engine is not valuable if it creates delayed casts, duplicate rewards, stuck cutscenes, poisoned saves, or silently suppresses third-party content.

**Method and evidence:** Catalog known and hypothesized hazards: queue-success versus execution, script-slot shadowing, repeated listener registration, stale object IDs, partial sprite initialization, save/load interruption, non-idempotent side effects, cutscene stacking, skip-path drift, Project Image owner lock, action races, resource replacement after installation, native access violations, and uninstall during in-flight state. Rank severity, detectability, reversibility, and blast radius. Evidence target: E1 initially; later E4/E5 spikes add their distinct runtime and soak evidence layers.

**Artifacts and deliverable:** Risk register with prevention, detection, fallback, recovery, responsible subsystem, and validation scenario for each critical risk.

**Exit criterion:** Every critical risk maps to at least one prevention or containment mechanism and one planned test; unknown high-severity risks block the affected feature rather than becoming release notes.

**Dependencies:** PREP-01, PREP-02.

**Gate contribution:** Completes RG0 and informs every later gate.

---

# Epic EEEX — Engine and EEex capability map

## EEEX-01 — Produce a pinned, source-backed EEex capability matrix

**Labels:** research-spike, area:eeex, priority:P0, blocker:observer

**Question:** Which required operations are genuinely available and safe in the initially supported EEex build?

**Why it matters:** Designing against remembered or newer API signatures can hard-crash the game. The architecture must distinguish stable capabilities from version-sensitive or absent ones.

**Method and evidence:** Inspect pinned EEex source and effective API definitions, then exercise safe read-only probes in a disposable game. Cover script-slot inspection, sprite and area enumeration, positions, range and LOS, spellbook and effect inspection, action queuing, Lua triggers/actions, local/global state, marshal handlers, dialog actions, resource access, and listeners. Record signature, lifecycle restrictions, and failure mode. Evidence target: E1 plus E4 for runtime-sensitive calls.

**Artifacts and deliverable:** docs/research/eeex-capability-matrix.md with available, fragile, absent, and deferred classifications; source references; probe scenarios; safe wrapper requirements.

**Exit criterion:** Every RG1 and RG2 kernel requirement has a proven API or approved alternative. An absent safety-critical capability blocks its dependent design instead of being approximated silently.

**Dependencies:** PREP-01, PREP-03, TEST-05.

**Gate contribution:** Core blocker for RG1 and RG2.

## EEEX-02 — Map the engine and EEex lifecycle

**Labels:** research-spike, area:eeex, priority:P0, blocker:observer

**Question:** When are sprites, areas, scripts, action queues, effect lists, and persistence structures safe to inspect or mutate?

**Why it matters:** A hook may fire more often or earlier than its name suggests. Summoned actors and load-time objects can be partially initialized, and repeated registrations are append-only.

**Method and evidence:** Instrument bootstrap, new game, load, marshal/import, sprite load, summoned-creature initialization, area enter/leave, AI passes, list resolution, action start/advance, rest, save, quicksave copies, game over, and hot reload in the disposable environment. Correlate logs with source. Evidence target: E4.

**Artifacts and deliverable:** Lifecycle diagram and hook-safety matrix showing cadence, valid object fields, allowed work, prohibited work, and registration lifetime.

**Exit criterion:** Every proposed listener and scheduler entry point has a measured cadence and safe-access window. No design assumes that loaded means fully initialized or that a stat/list hook is infrequent.

**Dependencies:** EEEX-01, TEST-05.

**Gate contribution:** Required for RG1; blocks active runtime work in RG2 and persistent work in RG3.

## EEEX-03 — Prove script arbitration and a fail-safe Lua handoff

**Labels:** research-spike, area:eeex, priority:P0, blocker:combat-pilot

**Question:** Can a minimal BCS bridge lease exactly one decision to Lua without suppressing higher encounter logic or losing the lower legacy fallback?

**Why it matters:** This is the core migration seam. If Lua must globally supervise or destructively clear queues, compatibility risk rises sharply.

**Method and evidence:** Use a purpose-built CRE with separately observable override, class, race, general, and default scripts. Exercise first-match behavior, Continue(), NoAction(), EEex Lua triggers/actions, action queueing, errors, false returns, and timeout. Test higher-level phase and dialog blocks while a low-level combat bridge is present. Evidence target: E4.

**Artifacts and deliverable:** Handoff protocol, ownership precedence, bridge pseudocode, error path, and exact fallback contract.

**Exit criterion:** Lua claims only an explicitly enrolled actor and only one allowed action; false, error, stale enrollment, or timeout demonstrably evaluates or restores the untouched legacy path in the same bounded control cycle.

**Dependencies:** EEEX-01, EEEX-02, BCS-01, ACT-01, TEST-05.

**Gate contribution:** Principal blocker for RG2.

## EEEX-04 — Determine the runtime and durable object-identity contract

**Labels:** research-spike, area:eeex, priority:P0, blocker:observer

**Question:** Which identifiers remain meaningful across AI passes, area transitions, save/load, death, respawn, summoning, cloning, and actor replacement?

**Why it matters:** Persisting object IDs or userdata can target the wrong actor after load. Resrefs and script names can also be non-unique.

**Method and evidence:** Track object ID, CRE resref, death variable/script name, area, locals, copy-parent fields, and semantic encounter identity across reload, summon, Project Image, Simulacrum, duplicate-resref creatures, polymorph, and respawn. Evidence target: E4.

**Artifacts and deliverable:** Identity policy separating ephemeral handles from durable semantic selectors, including ambiguity and re-resolution rules.

**Exit criterion:** No durable schema contains object IDs or userdata; every actor reference can be re-resolved or explicitly becomes unresolved and yields; duplicate candidates cannot be selected arbitrarily.

**Dependencies:** EEEX-01, EEEX-02, TEST-05.

**Gate contribution:** Required for RG1, RG2, and RG3.

## EEEX-05 — Design capability negotiation, hot-reload safety, and circuit breaking

**Labels:** research-spike, area:eeex, priority:P1, blocker:combat-pilot

**Question:** How does the runtime refuse unsafe operation when APIs, signatures, optional modules, or lifecycle behavior differ?

**Why it matters:** Version checks alone are brittle; repeated hot reload can duplicate global listeners; native faults cannot be recovered with pcall.

**Method and evidence:** Test missing LuaJIT, absent functions, incompatible signatures, optional module absence, duplicate registration, partial bootstrap, and module reload. Use capability probes that avoid unsafe calls. Evidence target: E1 and E4.

**Artifacts and deliverable:** Versioned capability manifest, startup diagnostic, root-level one-time trampoline design, module disable states, and error-rate circuit breaker.

**Exit criterion:** Missing or changed capability disables only dependent features, emits one actionable report, and leaves legacy scripts operational. Reload does not multiply listeners or state machines.

**Dependencies:** EEEX-01, EEEX-02, PREP-03.

**Gate contribution:** Required for RG2 and RG5.

## EEEX-06 — Verify the fair read-model coverage

**Labels:** research-spike, area:eeex, priority:P0, blocker:observer

**Question:** Can Combat Intent observe everything needed for the pilot without cheating or unsafe native access?

**Why it matters:** A scorer built on unavailable, stale, or omniscient facts would be neither reliable nor fair.

**Method and evidence:** Build an observation matrix for aura and action state, memorized and known spells, item availability, active effects, spell states, stats, hostility, visibility, invisibility and detection, target validity, range, LOS, current scripts, summons, clones, and nearby allies. Mark each field authoritative, inferred, delayed, unknown, or prohibited. Evidence target: E1 and E4.

**Artifacts and deliverable:** Initial PerceivedActorState schema, freshness policy, and authoritative-source table.

**Exit criterion:** Every proposed pilot feature is observable, safely derivable, deliberately unknown, or removed from v1. Hidden player facts cannot enter ordinary decisions.

**Dependencies:** EEEX-01, EEEX-02, EEEX-04, TEST-05.

**Gate contribution:** Completes the technical basis of RG1.

---

# Epic SCS — SCS knowledge and generated-behavior corpus

## SCS-01 — Build a representative SCS behavior corpus

**Labels:** research-spike, area:scs, priority:P0, blocker:observer

**Question:** What finite sample captures SCS's tactical breadth well enough to design and test the first architecture?

**Why it matters:** Reconstructing all SCS behavior at once is infeasible, while selecting only one simple mage would conceal prebuff, encounter, group, difficulty, and compatibility patterns.

**Method and evidence:** Stratify by caster level, specialist/archetype, spell allocation, prebuff mode, fighter, priest, thief, multiclass, summoned creature, monster type, coordinated group, boss phase, and custom encounter. Include SCS-present and SCS-absent forms where relevant. Evidence target: E1.

**Artifacts and deliverable:** Corpus manifest listing effective CRE/BCS/DLG/SPL artifacts, source paths, hashes, owning components, redistribution status, and selection rationale.

**Exit criterion:** Every initially planned behavior family has an ordinary, edge, and compatibility-sensitive representative; the corpus is small enough for repeatable analysis.

**Dependencies:** PREP-01, PREP-02, LIC-01.

**Gate contribution:** Required for RG1 and RG2; seeds RG4.

## SCS-02 — Trace SSL source through generation to effective creature behavior

**Labels:** research-spike, area:scs, priority:P0, blocker:observer

**Question:** How does an authored SCS rule become the actual priority tree assigned to a particular installed creature?

**Why it matters:** Compact SSL omits install-time target expansion, spell allocation, difficulty pruning, response weighting, and install-specific generated resrefs.

**Method and evidence:** For representative actors, record SSL and template inputs, install variables, generated BAF where available, effective/decompiled BCS, script-slot assignment, and resource ownership. Trace Continue() and weighted response behavior. Evidence target: E1.

**Artifacts and deliverable:** End-to-end source maps for at least one mage, one prebuffer, one martial actor, and one encounter-specific actor.

**Exit criterion:** A reviewer can explain every effective sample block's origin, its slot priority, and why it survived generation. No adapter treats generated script names as stable identifiers.

**Dependencies:** SCS-01, IR-01.

**Gate contribution:** Required for RG1; informs the RG2 handoff and provenance design.

## SCS-03 — Extract a tactical-knowledge taxonomy

**Labels:** research-spike, area:scs, priority:P0, blocker:combat-pilot

**Question:** Which SCS material represents reusable domain knowledge, and which is only brittle BCS/compiler machinery?

**Why it matters:** Blindly porting generated branches would reproduce the technical limitations. Ignoring them would throw away years of encounter and spell expertise.

**Method and evidence:** Classify sampled rules as legality, target safety, protection/counter knowledge, resource accounting, prebuff, archetype/personality, difficulty, encounter contract, compatibility exception, randomization, group convention, or BCS workaround. Record source and proposed destination. Evidence target: E1.

**Artifacts and deliverable:** Normalized rule catalog with provenance and disposition: Combat Intent data, SCS adapter, WorldFlow contract, legacy-only, deferred, or rejected.

**Exit criterion:** Every candidate rule has a semantic purpose and destination; no rule is ported merely because it appears early or often in generated BCS.

**Dependencies:** SCS-01, SCS-02, LIC-01, LIC-02.

**Gate contribution:** Required for RG2 and RG4.

## SCS-04 — Characterize prebuff fairness, timing, and resource accounting

**Labels:** research-spike, area:scs, priority:P1, blocker:combat-pilot

**Question:** Which SCS prebuffs represent plausible earlier preparation, and how are memorized resources, contingencies, sequencers, and existing effects accounted for?

**Why it matters:** Prebuffing is immersive only if it respects declared fairness and does not duplicate resources, repeat preparation, or apply defenses based on impossible knowledge.

**Method and evidence:** Trace short- and long-preparation gates, sight/proximity/offscreen flags, force-cast helpers, RemoveSpell accounting, one-shot state, contingencies, sequencers, and known special cases such as pre-existing Stoneskin/compiler markers. Compare effective actors. Evidence target: E1, later E4 in the arena.

**Artifacts and deliverable:** Prebuff contract separating historical preparation simulation, live casting, resource expenditure, fairness inputs, and compatibility markers.

**Exit criterion:** Each sampled prebuff can be reproduced or deliberately changed without free resources, accidental repetition, stale marker detection, or omniscient activation.

**Dependencies:** SCS-02, SCS-03, EEEX-06, ACT-02.

**Gate contribution:** Required before prebuff behavior joins RG2; otherwise deferred from the first active action.

## SCS-05 — Separate encounter contracts from generic combat policy

**Labels:** research-spike, area:scs, priority:P0, blocker:combat-pilot

**Question:** Which higher-level scripts must remain authoritative over dialogue, staging, hostility, phase changes, retreat, transformation, spawning, and plot state?

**Why it matters:** Generic combat AI can break an encounter before dialogue or scripted transitions complete. The bridge must know when not to act.

**Method and evidence:** Analyze complete script-slot stacks and cross-resource dependencies for representative encounters. Record globals, timers, shouts, dialog starts, cutscenes, phase transitions, and state changes that enable generic combat. Evidence target: E1 and selective E4.

**Artifacts and deliverable:** Encounter-ownership map, deny-lease conditions, and adapter claim boundaries.

**Exit criterion:** Combat Intent cannot preempt any identified encounter transition; uncertain phases and unrecognized encounter scripts stay entirely legacy-owned.

**Dependencies:** SCS-01, SCS-02, BCS-01, DLG-01, FLOW-01.

**Gate contribution:** Required for RG2 and later encounter expansion in RG4.

## SCS-06 — Create a shadow-decision oracle

**Labels:** research-spike, area:scs, priority:P1, blocker:combat-pilot

**Question:** Can the new engine compare its hypothetical choice with SCS's effective choice without changing gameplay?

**Why it matters:** Shadow comparison turns the installed SCS behavior corpus into an oracle and exposes regressions or deliberate improvements before action ownership is enabled.

**Method and evidence:** Capture perceived state, currently eligible SCS branch where reconstructible, actual started action, Combat Intent candidates, scores, filtered reasons, and outcome. Replay the snapshots in pure Lua with seeded randomness. Evidence target: E2 plus E4.

**Artifacts and deliverable:** Versioned trace/replay format and comparison report classifying agreement, reasoned disagreement, incomplete observation, and unmodeled legacy behavior.

**Exit criterion:** One representative mage encounter can be replayed offline; each divergence has an inspectable reason and provenance rather than only two action names.

**Dependencies:** SCS-02, SCS-03, EEEX-06, ACT-01, IR-02, TEST-01, TEST-05.

**Gate contribution:** Completes RG1 and is the principal evidence bridge into RG2.

---

# Epic BCS — Legacy script runtime semantics

## BCS-01 — Specify the operational semantics of the supported BCS subset

**Labels:** research-spike, area:bcs, priority:P0, blocker:observer

**Question:** What precisely happens across script levels, blocks, triggers, weighted responses, Continue(), action queues, timers, shouts, and object selectors?

**Why it matters:** Both the observer and the handoff protocol depend on actual engine ordering, not an approximate reading of BAF source. A small semantic error can suppress an entire lower script or repeat a side effect.

**Method and evidence:** Combine pinned documentation, effective decompiles, and focused disposable-game fixtures designed to distinguish competing interpretations. Vary script slot, block order, Continue(), NoAction(), false and true triggers, weighted all-miss cases, and queued actions. Evidence target: E1 and E4.

**Artifacts and deliverable:** Executable or testable BCS semantics document with explicit modeled, opaque, and unknown constructs.

**Exit criterion:** The model predicts every focused fixture, including priority, fallthrough, weighted responses, and action-queue effects. Unsupported constructs remain opaque and prevent unsafe transformation.

**Dependencies:** PREP-03.

**Gate contribution:** Required for RG1; blocks EEEX-03 and all legacy analysis.

## BCS-02 — Classify BCS actions by side effect, idempotency, and observability

**Labels:** research-spike, area:bcs, priority:P0, blocker:worldflow-pilot

**Question:** Which common actions are safe to retry, conditionally retry, compensate, reconcile, or never automate?

**Why it matters:** WorldFlow cannot provide recovery merely by rerunning a script block. Item grants, XP, spawns, destroys, joins, and area changes have very different duplicate and rollback behavior.

**Method and evidence:** Catalog variable writes, timers, item create/give/remove, XP, reputation, join/leave, spawn, destroy, movement, doors, ambient state, area transition, journal, spell/effect, dialog, and cutscene actions. For each, identify precondition, postcondition, duplicate effect, reversibility, persistence boundary, and ambiguous result. Validate representative actions in the WorldFlow lab. Evidence target: E1 and E4.

**Artifacts and deliverable:** Versioned side-effect registry consumed by WorldFlow authoring and validation.

**Exit criterion:** No WorldFlow operation may schedule an action lacking a registry entry. Non-idempotent and unobservable actions are excluded, manually adapted, or explicitly classified as an unresolved release blocker.

**Dependencies:** BCS-01, IR-02.

**Gate contribution:** Required for RG3 and RG5.

## BCS-03 — Map public variables, timers, shouts, and script-slot contracts

**Labels:** research-spike, area:bcs, priority:P0, blocker:combat-pilot

**Question:** Which legacy values and entry points function as public APIs between resources and mods?

**Why it matters:** Replacing internal orchestration while changing a plot global, timer name, shout convention, or script-slot expectation can break another mod even when the visible quest still works in isolation.

**Method and evidence:** For representative combat and quest resources, build a cross-reference
graph of global/local variables, timers, named objects, shouts, script assignments, area/encounter
controllers, forced actions, dialog starts, and external script references. For Combat Intent,
define an external-control closure that can detect a later controller even when it does not modify
the actor's CRE or generic BCS. Separate internal implementation details from externally observed
contracts. Exercise later-mod counterexamples in the synthetic and disposable compatibility labs.
Evidence target: evidence:E1 pinned static inspection plus evidence:E3 synthetic-game integration
and evidence:E4 disposable-engine runtime proof for activation safety.

**Artifacts and deliverable:** Compatibility-contract inventory, external-control-closure model,
and graph query format.

**Exit criterion:** Each migrated representative resource has an explicit list of preserved inputs,
outputs, and external owners; an unknown area/encounter controller, shout/global writer, forced
action, or script owner makes the adapter stale; unknown references cause adapter yield rather than
guessed rewriting.

**Dependencies:** BCS-01, IR-01, IR-02, PREP-02.

**Gate contribution:** The conservative inventory/yield rule is required for RG2/RG3. Complete
external-control closure blocks any post-drift reactivation claim at RG4/RG5; until then drift stays
permanently stale/pass-through.

## BCS-04 — Define legacy handback after partial ownership

**Labels:** research-spike, area:bcs, priority:P1, blocker:compatibility-expansion

**Question:** After Combat Intent or WorldFlow releases a resource, what state must be restored so its original scripts can continue coherently?

**Why it matters:** Preserving the BCS file is insufficient if the new runtime has changed locals, action queues, script slots, or phase variables in ways the old script does not understand.

**Method and evidence:** Identify lease-local versus public state, action ownership markers, temporary script assignment, and postcondition state for pilot resources. Disable the runtime at each boundary and observe legacy continuation. Evidence target: E2 and E4.

**Artifacts and deliverable:** Handback contract and per-adapter restoration checklist.

**Exit criterion:** Each pilot resource can lose runtime ownership at every permitted boundary without permanent idle state, duplicate phase entry, or a private variable that legacy code cannot interpret.

**Dependencies:** BCS-01, BCS-03, EEEX-03.

**Gate contribution:** Required for RG4 and RG5.

---

# Epic DLG — Dialogue runtime semantics and interoperability

## DLG-01 — Specify dialog state and transition semantics

**Labels:** research-spike, area:dlg, priority:P0, blocker:worldflow-pilot

**Question:** How are start states, weights, absent versus empty triggers, transitions, external jumps, interjections, actions, and interruptions selected?

**Why it matters:** WorldFlow may supervise when dialogue starts, but DLG remains the engine-facing conversation surface. Wrong state-order assumptions can hijack or make dialogue unreachable.

**Method and evidence:** Create minimal DLG fixtures and compare representative vanilla/mod dialogs. Exercise ordinary click entry, forced dialogue, triggerless targets, empty/always-true triggers, external jumps, interjection, target death, save/load, and missing actor. Evidence target: E1 and E4.

**Artifacts and deliverable:** Dialog semantic model and a supported-construct matrix for observation, generation, and opaque preservation.

**Exit criterion:** The model predicts all fixture entry and transition outcomes. Constructs not proven safe remain legacy-owned and cannot be regenerated.

**Dependencies:** BCS-01.

**Gate contribution:** Required for RG3; informs SCS-05 and IR design.

## DLG-02 — Map dialogue actions and external quest contracts

**Labels:** research-spike, area:dlg, priority:P1, blocker:worldflow-pilot

**Question:** Which dialog actions carry plot state, rewards, actor changes, or compatibility signals that WorldFlow must preserve?

**Why it matters:** Treating dialogue as text and choice presentation alone would miss irreversible actions and cross-mod entry points attached to transitions and interjections.

**Method and evidence:** Analyze representative DLG action lists, external transitions, interjection return paths, item/reward delivery, join/leave, globals, journal entries, and forced cutscenes. Link actions into the BCS side-effect registry. Evidence target: E1.

**Artifacts and deliverable:** Dialogue-to-WorldFlow contract map and action provenance graph.

**Exit criterion:** Every action-bearing transition in the pilot quest is classified, preserved, or deliberately moved with an equivalent externally visible contract.

**Dependencies:** DLG-01, BCS-02, BCS-03, IR-02.

**Gate contribution:** Required for RG3 and later dialogue migration in RG4.

## DLG-03 — Define unknown-mod dialogue coexistence

**Labels:** research-spike, area:dlg, priority:P2, blocker:compatibility-expansion

**Question:** How should adapters behave when another mod appends, replaces, or reorders states and transitions in a recognized DLG?

**Why it matters:** Whole-file hashes are too brittle, while silently ignoring a relevant dialog edit is unsafe.

**Method and evidence:** Produce semantic variants: unrelated appended banter, a new valid transition, modified plot action, reordered start state, altered external jump, and unknown interjection. Compare semantic fingerprints and runtime behavior. Evidence target: E1, E3, and E4.

**Artifacts and deliverable:** DLG-specific fingerprint slices and claim/yield policy.

**Exit criterion:** Harmless unrelated additions do not disable the entire adapter; relevant or ambiguous changes disable only affected claims and preserve the modified DLG untouched.

**Dependencies:** DLG-01, DLG-02, IR-04.

**Gate contribution:** Required for RG4 and RG5.

---

# Epic FLOW — Cutscene, skip, and encounter-flow semantics

## FLOW-01 — Model cutscene launch, execution, teardown, and skip rigs

**Labels:** research-spike, area:flow, priority:P0, blocker:worldflow-pilot

**Question:** How do launcher once-flags, StartCutSceneEx, action queues, area-script replacement, breakable IDs, CUTSKIP/CUTMOVE resources, fades, and teardown interact?

**Why it matters:** A cutscene may soft-lock from a repeated launcher, missing teardown, stacked cutscene mode, area-transition fade gap, or a skip rig that replays stale vanilla state.

**Method and evidence:** Analyze representative normal and skippable cutscenes, including explicit discovery of CUTSKIP and CUTMOVE resources outside ordinary area-prefix corpora. Build focused fixtures for launcher refire, skip, area transition, missing EndCutSceneMode, and interrupted actions. Evidence target: E1 and E4.

**Artifacts and deliverable:** Cutscene graph model, lifecycle contract, skip-ID map format, and hazard checklist.

**Exit criterion:** The model predicts normal, skipped, interrupted, and area-transition behavior for the fixtures; every path has an explicit teardown and externally observable end state.

**Dependencies:** BCS-01, DLG-01.

**Gate contribution:** Required for RG3 and SCS encounter ownership analysis.

## FLOW-02 — Prove normal/skip/recovery end-state equivalence

**Labels:** research-spike, area:flow, priority:P0, blocker:worldflow-pilot

**Question:** Can normal cutscene completion, user skip, and emergency reconciliation be generated from one authoritative end-state declaration?

**Why it matters:** Hand-maintained cutscene and skip paths drift. A shared declaration is the most promising way to prevent old effects, doors, spawns, timers, or plot variables from reappearing only on skip.

**Method and evidence:** Author a fixture involving movement, spawn/despawn, door and ambient changes, variables, and dialogue. Generate or supervise the normal and skip paths, capture semantic world snapshots, and inject interruption before each state change. Evidence target: E2 and E4.

**Artifacts and deliverable:** End-state schema, normal/skip mapping rules, equivalence checker, and fixture traces.

**Exit criterion:** Normal, skipped, interrupted-and-reloaded, and explicit recovery paths converge on the same declared invariants; differences are either transient and bounded or reported as failures.

**Dependencies:** FLOW-01, BCS-02, WF-01, WF-04, TEST-06.

**Gate contribution:** Principal proof for RG3.

---

# Epic IR — Script analysis, provenance, and generation tooling

## IR-01 — Evaluate decompilation and recompilation fidelity

**Labels:** research-spike, area:ir, priority:P0, blocker:observer

**Question:** Can existing tools expose effective BCS/DLG semantics without silently changing or losing required constructs?

**Why it matters:** Analysis and migration built on lossy decompilation can produce false source maps or unsafe rewritten scripts.

**Method and evidence:** Decompile and recompile a stratified corpus with pinned WeiDU and Near Infinity where useful. Compare semantic structure and controlled runtime behavior, not only bytes. Include unknown actions/triggers, complex object selectors, weighted responses, external dialog transitions, and generated SCS scripts. Evidence target: E1 and selective E4.

**Artifacts and deliverable:** Tool-selection ADR and fidelity report listing stable, normalized, lossy, and opaque constructs.

**Exit criterion:** The chosen pipeline preserves every construct required by RG1-RG3 or records unsupported constructs opaquely and blocks unsafe rewriting.

**Dependencies:** PREP-01, PREP-02, SCS-01.

**Gate contribution:** Required for RG1 and all subsequent tooling.

## IR-02 — Design a typed, loss-aware, provenance-carrying IR

**Labels:** research-spike, area:ir, priority:P0, blocker:observer

**Question:** What representation can support linting, source maps, shadow replay, bridge generation, and future WorldFlow authoring?

**Why it matters:** A simplified AST that discards order, weights, opaque actions, or origin data would be unsafe for compatibility decisions.

**Method and evidence:** Model resources, script slots, states, blocks, triggers, responses, actions, object selectors, timers, variables, external references, source spans, hashes, and opaque nodes. Represent uncertainty explicitly. Attempt loss-aware import of representative combat BCS, quest BCS, DLG, and cutscene/skip pairs. Evidence target: E2.

**Artifacts and deliverable:** Versioned IR schema, invariants, sample documents, and migration rules.

**Exit criterion:** All representative artifacts can be represented without discarded constructs or provenance; unsupported nodes round-trip opaquely and prevent transformations that depend on their meaning.

**Dependencies:** IR-01, BCS-01, DLG-01, FLOW-01, PREP-02.

**Gate contribution:** Required for RG1, RG2, and RG3.

## IR-03 — Prove static analysis value before automatic rewriting

**Labels:** research-spike, area:ir, priority:P1, blocker:compatibility-expansion

**Question:** Can analysis identify real script hazards with acceptable false positives and clear evidence?

**Why it matters:** Read-only linting benefits unsupported content without claiming ownership and provides a safer first step toward broad BCS/DLG reliability.

**Method and evidence:** Specify and test rules for repeated cutscene launchers, missing or unbalanced teardown, unsafe Exists without life checks, script-slot shadowing, unreachable blocks, unresolved resources, timer/global mismatches, duplicate irreversible side effects, stale target assumptions, and normal/skip drift. Use verified defects and synthetic controls. Evidence target: E2 and E1 corpus evidence.

**Artifacts and deliverable:** Linter rule catalog with confidence, evidence trace, remediation guidance, suppression format, and corpus report.

**Exit criterion:** Every production rule detects at least one verified defect or synthetic fault, passes a negative control, and explains the exact evidence. Low-confidence heuristics cannot auto-rewrite.

**Dependencies:** IR-02, BCS-02, DLG-02, FLOW-01.

**Gate contribution:** Required before broad unsupported-content analysis in RG4.

## IR-04 — Design semantic fingerprints and explicit claim manifests

**Labels:** research-spike, area:ir, priority:P0, blocker:combat-pilot

**Question:** How can an adapter start with exact dependency hashes and later detect relevant
incompatibility without rejecting proven-harmless byte-level changes?

**Why it matters:** Whole-file hashes disable too much; weak pattern matching may claim a resource whose relevant behavior was changed by another mod.

**Method and evidence:** Establish exact full-resource/dependency hashes as the first activation
rule. Separately compare them with experimental semantic fingerprints over claimed script slots,
blocks, dialog states, global contracts, resource references, and action/trigger slices. Create
harmless, relevant, ambiguous, and opaque modifications. Test install-before, install-after, and
runtime mismatch cases. Evidence target: E2, E3, and E4.

**Artifacts and deliverable:** Claim-manifest schema, fingerprint algorithm, mismatch classifications, and diagnostics format.

**Exit criterion:** Relevant, ambiguous, or opaque changes force yield-to-legacy for the affected
claim; exact hashes remain the default; a semantic matcher may relax them only for a separately
proved resource family; no classifier enrolls unknown resources by class alone.

**Dependencies:** IR-02, BCS-03, DLG-01, PREP-03.

**Gate contribution:** Required for RG2 and central to RG4/RG5 compatibility.

## IR-05 — Validate bridge generation, source maps, and restoration

**Labels:** research-spike, area:ir, priority:P1, blocker:combat-pilot

**Question:** Can minimal BCS/DLG bridges be generated, attributed, compiled, installed, reinstalled, and removed without resource drift?

**Why it matters:** Even a sound runtime can be unsafe if its installer overwrites assignments, publishes unintended files, or cannot restore an earlier resource exactly.

**Method and evidence:** Generate BAF/D from IR, compile with pinned WeiDU, install into the synthetic game, repeat installation, simulate controlled failure, uninstall, and compare original resources byte-for-byte. Link generated blocks back to source/claim IDs. Evidence target: E2 and E3.

**Artifacts and deliverable:** Generator contract, source-map format, publication allowlist, and round-trip test suite.

**Exit criterion:** Reinstall is idempotent, failures roll back, only declared resources are published, uninstall restores originals exactly, and every generated block has a provenance/source-map entry.

**Dependencies:** IR-02, IR-04, TEST-02, LIC-02.

**Gate contribution:** Required for RG2 bridge installation and RG5 release readiness.

## IR-06 — Define a stable native-registration API for future mods

**Labels:** research-spike, area:ir, priority:P2, blocker:compatibility-expansion

**Question:** How can future mods explicitly register Combat Intent profiles or WorldFlow contracts without patching internal tables?

**Why it matters:** Explicit native registration is safer and more scalable than maintaining hidden heuristics for every new mod.

**Method and evidence:** Draft versioned schemas for actor enrollment, behavior capability, protected encounter states, public variables, and optional WorldFlow hooks. Threat-model collisions, partial registration, version mismatch, and unload. Validate with two synthetic third-party adapters. Evidence target: E2 and E3.

**Artifacts and deliverable:** Registration API specification, namespace rules, validation errors, and example adapters.

**Exit criterion:** A synthetic mod can opt in one actor and one quest flow without modifying core files; invalid or unknown schema versions yield without partial enrollment.

**Dependencies:** IR-02, IR-04, ACT-03, WF-06, LIC-02.

**Gate contribution:** Required for mature RG4 expansion, optional for the first private pilot.

---

# Epic ACT — Action ownership, execution, and feedback

## ACT-01 — Determine the observable action lifecycle

**Labels:** research-spike, area:action, priority:P0, blocker:observer

**Question:** Can the kernel distinguish proposed, queued, started, advanced, completed, interrupted, cleared, rejected, and timed-out actions?

**Why it matters:** Queueing success proves only that an action was accepted into a queue. Updating beliefs or persistent state on that basis can produce false tactical memory and broken quests.

**Method and evidence:** Correlate started-action and next-action listeners, current action fields, target state, aura/casting state, spell-slot expenditure, item charges, animation/effect evidence, queue transitions, and declared postconditions. Include deliberate queue clearing and invalid targets. Evidence target: E4.

**Artifacts and deliverable:** ActionAttempt state machine with timestamps, correlation IDs, confidence grades, and terminal outcomes including outcome-unknown.

**Exit criterion:** No supported action is marked successful merely because queueing returned. Every tested attempt reaches a proven terminal state or a bounded unknown state that causes safe reconciliation/yield.

**Dependencies:** EEEX-01, EEEX-02, BCS-01, TEST-05.

**Gate contribution:** Required for RG1, RG2, and RG3.

## ACT-02 — Validate action-family-specific observers

**Labels:** research-spike, area:action, priority:P0, blocker:combat-pilot

**Question:** Does one generic completion detector suffice, or are different postconditions required for spell, attack, movement, item, dialogue, and world-state actions?

**Why it matters:** A spell may start but be interrupted; movement may end short; a dialogue action may queue while the target becomes invalid; a variable write may be immediate.

**Method and evidence:** Test normal cast, unavailable cast, interrupted cast, target loss, attack, movement, item use, dialog start, variable mutation, spawn, destroy, door change, area transition, and cutscene start. Record which signals are authoritative and which are only hints. Evidence target: E4.

**Artifacts and deliverable:** Observer and postcondition template per action family, with unsupported actions identified.

**Exit criterion:** Each v1 action family has a tested terminal observer. Unsupported families cannot be scheduled through a reliability-claiming API.

**Dependencies:** ACT-01, BCS-02, TEST-05, TEST-06.

**Gate contribution:** Required for RG2 and RG3.

## ACT-03 — Prove the actor lease and ownership-arbitration protocol

**Labels:** research-spike, area:action, priority:P0, blocker:combat-pilot

**Question:** What happens when Combat Intent, legacy AI, encounter BCS, player commands, charm/control changes, or WorldFlow want the same actor?

**Why it matters:** A tactical enhancement must not fight the encounter script, ignore player control, or clear queues destructively. WorldFlow must be able to reserve actors for critical choreography.

**Method and evidence:** Deliberately collide commands and ownership changes. Test lease eligibility, one-action scope, renewal, revocation, actor hostility change, player command, dialog/cutscene entry, WorldFlow claim, and legacy fallback. Evidence target: E2 and E4.

**Artifacts and deliverable:** Ownership hierarchy, lease record, preemption reasons, release protocol, and forbidden queue operations.

**Exit criterion:** WorldFlow/encounter control and explicit player control preempt Combat Intent; lease loss cannot leave an actor locked, idle indefinitely, or detached from its legacy script.

**Dependencies:** EEEX-03, SCS-05, BCS-04, WF-03.

**Gate contribution:** Principal ownership proof for RG2 and shared requirement for RG3.

## ACT-04 — Define timeout, retry, abandonment, and replanning rules

**Labels:** research-spike, area:action, priority:P1, blocker:combat-pilot

**Question:** When should a stalled or invalidated intention be retried, abandoned, reconciled, or handed back?

**Why it matters:** Indefinite retry loops and immediate oscillation between equally scored actions can be as damaging as a wrong initial choice.

**Method and evidence:** Fault-inject path failure, target death, invisibility, silence, aura change, depleted resource, queue clearing, player order, dialogue interruption, and area transition. Compare bounded retry and hysteresis strategies in replay before engine validation. Evidence target: E2 and E4.

**Artifacts and deliverable:** Retry budgets, timeout classes, cancellation reasons, hysteresis rules, and replanning triggers.

**Exit criterion:** No supported fault creates an infinite retry loop, duplicate irreversible side effect, repeated queue spam, or permanent ownership lease.

**Dependencies:** ACT-01, ACT-02, ACT-03, TEST-01.

**Gate contribution:** Required for RG2 active behavior and RG5 soak.

## ACT-05 — Cover clones, summons, charm, and Project Image edge cases

**Labels:** research-spike, area:action, priority:P1, blocker:combat-pilot

**Question:** Which actor forms require special identity, eligibility, or queue behavior?

**Why it matters:** Project Image can lock its owner and release delayed zombie casts; copies and summons may share resources or disappear; charm can reverse ownership and allegiance.

**Method and evidence:** Test Project Image owner lock, Simulacrum, copy-parent relations, scripted allied summons, charmed enemies/allies, temporary neutrals, despawning creatures, and destroyed actors with queued attempts. Evidence target: E4.

**Artifacts and deliverable:** Actor-kind policy, eligibility checks, identity treatment, and explicit exclusions.

**Exit criterion:** The runtime cannot queue onto a locked Project Image owner, cannot persist proxy identity as the owner, and releases actors immediately when allegiance or existence invalidates the lease.

**Dependencies:** EEEX-04, ACT-01, ACT-03, TEST-05.

**Gate contribution:** Required before RG2 supports anything beyond the simplest ordinary actor; required for RG5.

---

# Epic WF — WorldFlow durable orchestration

## WF-01 — Choose and formalize the recoverable saga model

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** How should persistent flows represent eligibility, claim, intent, execution, verification, commit, compensation, and recovery?

**Why it matters:** The Infinity Engine does not expose a general atomic transaction spanning globals, actions, dialogues, actors, areas, and saves. WorldFlow needs honest crash-consistency semantics instead of an unprovable exactly-once promise.

**Method and evidence:** Model representative quest transitions with explicit preconditions and postconditions. Compare write-ahead intent, claim-before-action, action-before-commit, reconciliation, and compensating-action strategies. Enumerate unavoidable ambiguity windows. Evidence target: E2.

**Artifacts and deliverable:** Versioned WorldFlow operation schema, state-transition diagram, allowed terminal states, and semantic guarantees.

**Exit criterion:** Every transition is idempotent, conditionally idempotent, compensatable, manually adapted, or rejected. Documentation states precisely where exactly-once cannot be guaranteed.

**Dependencies:** PREP-03, BCS-02, ACT-01, IR-02, TEST-01.

**Gate contribution:** Foundational blocker for RG3.

## WF-02 — Define durable storage, serialization, and schema migration

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** Which flow state belongs in engine globals/locals, EEex marshal data, or reconstructible world state, and how is it upgraded safely?

**Why it matters:** EEex marshal domains are version-sensitive, engine variables are public but small, and a private schema that cannot be loaded after update can strand saves.

**Method and evidence:** Test numeric/string/table serialization, numeric booleans, empty tables, malformed data, cyclic and unsupported values, quicksave marshalling copies, schema upgrade, downgrade, missing field, and lazy repair. Keep runtime handles out. Evidence target: E2 and E4.

**Artifacts and deliverable:** Persistence schema, storage-placement rules, size budget, exporter sanitization contract, migration chain, and corrupt-state policy.

**Exit criterion:** At least two forward schema migrations and malformed-state recovery succeed without save failure; no boolean, userdata, function, cycle, or object ID reaches the supported marshal boundary.

**Dependencies:** EEEX-01, EEEX-02, EEEX-04, WF-01, TEST-06.

**Gate contribution:** Required for RG3 and RG5.

## WF-03 — Prove exclusive claims and concurrency control

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** How do area scripts, creatures, dialogs, re-entrant events, and repeated AI passes avoid advancing the same flow simultaneously?

**Why it matters:** Repeated launchers and racing actors can duplicate mode entry, rewards, spawns, or plot advancement.

**Method and evidence:** Simulate competing claimants around a durable claim/epoch token, then validate repeated launchers and simultaneous actors in the WorldFlow lab. Include claimant death, area unload, save/load, stale claim, timeout, and runtime restart. Evidence target: E2 and E4.

**Artifacts and deliverable:** Claim/lease protocol with semantic owner, epoch, acquisition precondition, expiry/reconciliation, and takeover rules.

**Exit criterion:** Concurrent attempts converge on one committed transition; stale claims recover; an ambiguous owner halts/yields rather than allowing parallel execution.

**Dependencies:** WF-01, WF-02, EEEX-04, FLOW-01, TEST-06.

**Gate contribution:** Required for RG3.

## WF-04 — Enumerate interruption points and model-check recovery

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** What happens if interruption, save/load, actor loss, or runtime shutdown occurs immediately before and after every persistent write and engine action?

**Why it matters:** Most quest race bugs live between otherwise reasonable steps. Happy-path tests do not exercise these boundaries.

**Method and evidence:** Enumerate each boundary in representative flows. Run deterministic host-level state-machine exploration, then validate the critical ambiguity windows in the disposable lab using prepared saves and fault injection. Evidence target: E2 and E4.

**Artifacts and deliverable:** Failure-point matrix, replayable recovery traces, and unresolved ambiguity register.

**Exit criterion:** Every modeled interruption ends completed, safely retryable, intentionally aborted, awaiting explicit condition, or legacy-yielded. No path ends in silent limbo or repeats a classified irreversible action.

**Dependencies:** WF-01, WF-02, WF-03, ACT-02, TEST-01, TEST-06.

**Gate contribution:** Principal recovery proof for RG3.

## WF-05 — Generate normal, skip, and recovery paths from one end state

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** Can a single declared outcome drive normal cutscene completion, user skip, and recovery after interruption?

**Why it matters:** Separate hand-authored end paths drift and are a recurrent source of soft locks and resurrected effects/state.

**Method and evidence:** Define semantic assertions for actor locations/existence, hostility, doors, ambients, globals, timers, inventory/rewards, dialog availability, area script, and cutscene mode. Generate/supervise paths for the WorldFlow fixture and compare snapshots. Evidence target: E2 and E4.

**Artifacts and deliverable:** End-state DSL/schema, assertion engine, generated mapping rules, and equivalence report.

**Exit criterion:** Normal, skipped, interrupted/reloaded, and emergency-recovery executions converge on the same declared invariants, including teardown.

**Dependencies:** WF-01, WF-04, FLOW-01, FLOW-02, TEST-06.

**Gate contribution:** Completes the central functional claim of RG3.

## WF-06 — Preserve external mod compatibility contracts

**Labels:** research-spike, area:worldflow, priority:P0, blocker:worldflow-pilot

**Question:** How can WorldFlow own orchestration while other mods continue to read or set expected globals, timers, dialog states, script events, and actor state?

**Why it matters:** An internally correct quest can still be incompatible if it stops emitting or honoring the signals on which another component relies.

**Method and evidence:** Inventory public variables and cross-resource entry points in the pilot quest. Inject external state changes before, during, and after transitions. Classify changes as supported input, harmless observation, contradiction, or unknown. Evidence target: E1, E2, and E4.

**Artifacts and deliverable:** Per-flow compatibility contract covering consumed signals, emitted signals, preserved values, authoritative owner, and conflict/yield behavior.

**Exit criterion:** Understood external changes reconcile correctly; contradictory or unknown changes disable/yield the adapter without overwriting the external state; public legacy outputs remain available.

**Dependencies:** BCS-03, BCS-04, DLG-02, WF-01, WF-03, IR-04.

**Gate contribution:** Required for RG3 and RG4.

## WF-07 — Design runtime disable, upgrade, downgrade, and uninstall recovery

**Labels:** research-spike, area:worldflow, priority:P1, blocker:public-preview

**Question:** What happens if WorldFlow is disabled, absent, upgraded, downgraded, or uninstalled while a persistent operation exists?

**Why it matters:** A save must not require a private runtime forever merely because one quest transition began under it.

**Method and evidence:** Disable or remove the runtime at each pilot state; load with Lua absent; test known and unknown schema versions; uninstall bridge resources; restore original BCS/DLG; and observe legacy continuation or explicit safe block. Evidence target: E3 and E4.

**Artifacts and deliverable:** Handoff-to-legacy protocol, install-time migration checks, downgrade policy, recovery component design, and release checklist.

**Exit criterion:** Disabling/uninstalling cannot leave cutscene mode active or a flow in private unrecoverable state. Unsupported in-flight states are migrated, reconciled, or block the operation with a clear recovery path before destructive changes.

**Dependencies:** WF-02, WF-04, WF-06, BCS-04, IR-05, TEST-02, TEST-06.

**Gate contribution:** Required for RG5.

---

# Epic SPACE — Spatial reasoning, perception, and fairness

## SPACE-01 — Verify coordinate, distance, range, and LOS semantics

**Labels:** research-spike, area:space, priority:P1, blocker:combat-pilot

**Question:** What do engine coordinates and range/LOS APIs actually measure, and which signatures are safe?

**Why it matters:** Passing the wrong object-type representation can hard-crash; incorrect units or LOS rules can cause obvious friendly fire and illegal targeting.

**Method and evidence:** Place tagged actors at known positions and compare m_pos, script range triggers, visual range, LOS, walls, closed/open doors, and area separation. Validate numeric boolean arguments and reject pointer/type mismatches before entering C++. Evidence target: E1 and E4.

**Artifacts and deliverable:** Spatial primitive contract, safe wrappers, coordinate scale, rounding rules, and LOS caveats.

**Exit criterion:** Wrapper results match controlled scenes; malformed types and booleans are rejected in Lua; no spatial call used by the pilot has an untested native signature.

**Dependencies:** EEEX-01, EEEX-02, TEST-05.

**Gate contribution:** Required before spatial actions enter RG2.

## SPACE-02 — Build an authoritative AoE geometry model

**Labels:** research-spike, area:space, priority:P1, blocker:combat-pilot

**Question:** Where do effective radius and shape come from for projectiles, bursts, cones, lines, clouds, delayed effects, and mod-replaced spells?

**Why it matters:** Ability-header target type alone does not provide exact geometry, and SCS marker feature blocks can create false AoE classifications.

**Method and evidence:** Resolve actual castable SPL ability and projectile resources, follow projectile/secondary effects, and compare predicted affected actor sets against disposable casts. Include SCS/SR-modified spells, edge-of-radius targets, allies, neutrals, and obstructions. Evidence target: E1 and E4.

**Artifacts and deliverable:** Versioned geometry registry with source provenance, confidence, semantic fingerprint, and unknown fallback.

**Exit criterion:** Pilot AoE spells predict affected ally/enemy sets correctly in boundary scenarios. Unknown or changed geometry prevents Combat Intent from claiming the spatial decision.

**Dependencies:** SPACE-01, EEEX-06, IR-04, TEST-05.

**Gate contribution:** Required for the first AoE claim in RG2 and broad spell support in RG4.

## SPACE-03 — Evaluate movement and repositioning feasibility

**Labels:** research-spike, area:space, priority:P2, blocker:compatibility-expansion

**Question:** Can actors choose and reach tactically useful positions without pathing loops, collision deadlocks, or interference with encounter choreography?

**Why it matters:** Position scoring without path feasibility can make the AI less intelligent and more fragile.

**Method and evidence:** Test movement actions, unavailable destinations, personal space, doors, narrow passages, moving targets, combat interruption, timeout, and encounter-owned staging positions. Compare simple candidate sampling with any safe path-query support. Evidence target: E2 and E4.

**Artifacts and deliverable:** Repositioning capability report, safe candidate constraints, path-failure handling, and deliberately deferred path features.

**Exit criterion:** A pilot actor reaches or abandons a selected position predictably, cannot loop indefinitely, and never overrides a WorldFlow/encounter movement claim.

**Dependencies:** SPACE-01, ACT-02, ACT-03, ACT-04, PERF-02.

**Gate contribution:** Not required for the narrow first action in RG2; required before spatial movement expansion in RG4.

## SPACE-04 — Formalize perception, belief, and information sharing

**Labels:** research-spike, area:space, priority:P0, blocker:observer

**Question:** What may an actor know without cheating, how long may it remember observations, and what may allies communicate?

**Why it matters:** EEex may expose world facts the creature should not possess. Tactical intelligence should come from better reasoning over fair information, not hidden party state.

**Method and evidence:** Define sensed-now, observed-before, inferred, shared, and omniscient categories. Exercise invisibility, stealth, detection, unseen casting, actor disappearance, protection inference, group range, shouts, and memory expiry. Separate optional explicit cheat modes from the default contract. Evidence target: E2 and E4.

**Artifacts and deliverable:** Fairness policy, belief schema, expiry rules, observation events, and squad-sharing constraints.

**Exit criterion:** Golden tests prove ordinary decisions cannot consume hidden spellbooks, exact unseen stats, stale precise positions, or information unavailable to every sharing ally.

**Dependencies:** EEEX-04, EEEX-06, TEST-01, TEST-05.

**Gate contribution:** Required for RG1 and RG2.

## SPACE-05 — Prove bounded squad reservations and coordination

**Labels:** research-spike, area:space, priority:P2, blocker:compatibility-expansion

**Question:** Can allies coordinate target, disable, dispel, and area reservations without a global omniscient hive mind?

**Why it matters:** Group coordination is a major improvement over isolated scripts, but persistent or over-broad reservations can deadlock actors and violate fairness.

**Method and evidence:** Simulate two and then several allied actors sharing only permitted observations. Test duplicate dispels, conflicting disables, target death, actor loss, communication range, reservation expiry, save/load, and group split. Evidence target: E2 and E4.

**Artifacts and deliverable:** Ephemeral group-blackboard schema, reservation types, communication gates, ownership, expiry, and cleanup rules.

**Exit criterion:** Two casters avoid a tested duplicate action when communication permits; loss or failure clears the reservation; no reservation or runtime actor ID persists across load.

**Dependencies:** SPACE-04, ACT-01, ACT-03, ACT-04, EEEX-04, PERF-02.

**Gate contribution:** Optional stretch for RG2; required before coordinated-group expansion in RG4.

---

# Epic PERF — Performance budgets and safe degradation

## PERF-01 — Establish the unmodified engine and observer baseline

**Labels:** research-spike, area:performance, priority:P0, blocker:observer

**Question:** What are normal frame, AI-pass, action, memory, and save/load costs before the new runtime performs meaningful work?

**Why it matters:** Absolute timings without a baseline cannot distinguish mod overhead from normal engine variance. A listener that fires per actor per AI pass can become expensive quickly.

**Method and evidence:** Measure idle, ordinary encounter, caster-heavy encounter, summon-heavy encounter, cutscene, area transition, and save/load states in the disposable environment. Capture distributions and hardware/runtime configuration. Evidence target: E4.

**Artifacts and deliverable:** Repeatable benchmark harness, raw measurements, baseline report, and initial overhead budget proposal.

**Exit criterion:** Variance and measurement noise are understood well enough to set evidence-based observer and active-decision budgets; no target is chosen solely by intuition.

**Dependencies:** TEST-05, EEEX-02.

**Gate contribution:** Required for RG1 and every later performance comparison.

## PERF-02 — Compare event-driven, readiness-polled, and staggered schedulers

**Labels:** research-spike, area:performance, priority:P0, blocker:combat-pilot

**Question:** When should an actor reconsider its decision, and how can latency remain fast without scoring every actor every AI pass?

**Why it matters:** Full per-tick evaluation is likely wasteful, while slow polling makes reactions feel unintelligent. Listener cadence and action readiness need to drive a bounded scheduler.

**Method and evidence:** Prototype observer-only strategies based on action-state changes, aura/readiness, perception invalidation, bounded polling, per-actor staggering, and urgent events. Measure calls, candidate evaluations, latency, and missed changes. Evidence target: E2 and E4.

**Artifacts and deliverable:** Scheduler ADR with trigger classes, minimum/maximum reconsideration latency, deduplication, and starvation rules.

**Exit criterion:** The selected scheduler reacts within the agreed gameplay latency while avoiding full candidate evaluation on every actor's every AI pass.

**Dependencies:** PERF-01, EEEX-02, ACT-01, ACT-04.

**Gate contribution:** Required for RG2.

## PERF-03 — Stress CPU, allocations, GC, spatial queries, and diagnostics

**Labels:** research-spike, area:performance, priority:P1, blocker:compatibility-expansion

**Question:** How does the design scale under worst-case actor, effect, spell, candidate, and coordination counts?

**Why it matters:** LuaJIT allocations, repeated resource parsing, range scans, and verbose decision logging may dominate costs long before the actual utility calculation.

**Method and evidence:** Replay large synthetic snapshots and run disposable battles with many summons/casters. Profile temporary tables, caches, geometry lookups, effect scans, group blackboards, source maps, and debug logging. Measure median and tail latency plus memory growth. Evidence target: E2, E4, and E5.

**Artifacts and deliverable:** Complexity report, allocation and caching guidelines, stress fixtures, diagnostic-level costs, and supported actor/candidate envelope.

**Exit criterion:** Agreed 95th/99th-percentile decision and frame-overhead budgets are met; memory and cache size are bounded; disabling diagnostics reduces cost without changing choices.

**Dependencies:** PERF-02, SPACE-01, SPACE-02, SPACE-05, TEST-05.

**Gate contribution:** Required for RG4 and RG5.

## PERF-04 — Define a deterministic safe-degradation ladder

**Labels:** research-spike, area:performance, priority:P1, blocker:public-preview

**Question:** What should happen when a scorer, adapter, actor group, or persistence operation exceeds error or time budgets?

**Why it matters:** Overload must reduce enhancement rather than freeze the game, delay quest progression, or suppress legacy AI.

**Method and evidence:** Inject slow scorers, repeated exceptions, oversized candidate sets, invalid geometry, failed resource loads, and high actor counts. Test per-decision, per-actor, per-adapter, and global circuit breakers. Evidence target: E2 and E4.

**Artifacts and deliverable:** Degradation ladder: skip optional scorer, shorten candidate set, use safe default, yield current action, disable adapter, fall back to legacy; plus recovery/reset rules.

**Exit criterion:** Every injected overload terminates within a bound and preserves legacy execution. Circuit breakers cannot silently re-enable in a tight failure loop.

**Dependencies:** PREP-03, EEEX-05, PERF-02, PERF-03, ACT-04.

**Gate contribution:** Required for RG5.

## PERF-05 — Set storage, trace, and save-size budgets

**Labels:** research-spike, area:performance, priority:P2, blocker:public-preview

**Question:** How much transient and durable state may each actor, group, adapter, and flow retain?

**Why it matters:** Unbounded observations, explanations, reservations, or recovery history can bloat memory and saves even if frame time remains acceptable.

**Method and evidence:** Measure serialized WorldFlow state, ephemeral beliefs, trace buffers, provenance/source-map references, and group data across long scenarios. Verify pruning and no persistent runtime identity. Evidence target: E2 and E5.

**Artifacts and deliverable:** Per-entity budgets, retention policy, ring-buffer sizes, pruning triggers, and diagnostic export policy.

**Exit criterion:** State size remains within agreed bounds over soak; old observations and completed flows are compacted safely; save growth is explained and bounded.

**Dependencies:** WF-02, SPACE-04, SPACE-05, PERF-03.

**Gate contribution:** Required for RG5.

---

# Epic TEST — Fixtures, harnesses, and disposable validation

## TEST-01 — Define the pure-Lua scenario, property, and replay harness

**Labels:** preparation, area:test, priority:P0, blocker:observer

**Question:** Can most Combat Intent and WorldFlow logic be tested deterministically without launching the game?

**Why it matters:** Engine-only tests are slow, fragile, and poor at exhaustive failure injection. The EEex boundary should be thin enough that core logic runs over immutable snapshots and explicit commands.

**Method and evidence:** Design fake boundary objects, immutable perceived-state snapshots, seeded random streams, golden candidate scores, action-attempt events, and WorldFlow state transitions. Add properties for legal resources, no forbidden targets, fairness, bounded retry, reservation cleanup, and yield on unknown. Evidence target: E2.

**Artifacts and deliverable:** Scenario/replay schema, fake boundary contract, property catalog, deterministic RNG policy, and minimum pilot fixture set.

**Exit criterion:** A mage shadow decision and one WorldFlow saga replay identically across repeated runs; only explicit EEex adapter code requires the game process.

**Dependencies:** PREP-02, PREP-03.

**Gate contribution:** Required for RG1, RG2, and RG3.

## TEST-02 — Extend the synthetic WeiDU fake-game harness

**Labels:** preparation, area:test, priority:P0, blocker:combat-pilot

**Question:** Can the public installer, claim manifest, and bridge generator be tested without any real game installation?

**Why it matters:** Installer mistakes can damage a mod stack independently of runtime correctness. Synthetic testing permits controlled RED cases and byte-exact restoration.

**Method and evidence:** Extend the minimal KEY V1, BIFF V1, TLK, IDS, and marker-resource game with CRE/BCS/DLG/ARE fixtures. Run pinned WeiDU public components through install, repeat install, controlled failure, reinstall where applicable, and uninstall. Evidence target: E3.

**Artifacts and deliverable:** Fake-game builder, fixture writer/parser support, publication allowlist, and installer test matrix.

**Exit criterion:** KEY/BIF/TLK stay unchanged where required; only declared files appear; failure rolls back; reinstall is idempotent; uninstall restores every original byte exactly.

**Dependencies:** PREP-01.

**Gate contribution:** Required for RG2 and RG5.

## TEST-03 — Establish a curated effective-resource fixture corpus

**Labels:** preparation, area:test, priority:P1, blocker:compatibility-expansion

**Question:** Which real-shaped resources are required to expose SCS, SR, EET, and third-party structural variation without redistributing prohibited assets?

**Why it matters:** Hand-built fixtures often miss real record shapes and compatibility modifications, while copied game assets may not be redistributable.

**Method and evidence:** Select byte-exact read-only evidence where permitted; otherwise record local-only fixture manifests and construct synthetic equivalents. Include BIFF-only and override resources, modified script slots, marker effects, generated scripts, dialog edits, and cutscene/skip pairs. Evidence target: E1 and E3.

**Artifacts and deliverable:** Fixture inventory divided into shippable synthetic, shippable upstream-permitted, and local-only evidence, each with provenance and purpose.

**Exit criterion:** CI runs without proprietary game assets; an authorized local extended suite can reproduce every claimed effective-install edge case.

**Dependencies:** PREP-02, SCS-01, LIC-01.

**Gate contribution:** Required for RG4 and RG5.

## TEST-04 — Build automated semantic world-state snapshots

**Labels:** preparation, area:test, priority:P0, blocker:worldflow-pilot

**Question:** Can tests compare world outcomes semantically rather than relying on visual observation or logs alone?

**Why it matters:** Normal, skip, recovery, and compatibility paths may differ in irrelevant action order while still needing identical durable actor/area/quest state.

**Method and evidence:** Define snapshots for relevant globals/locals, actor existence/identity/location/allegiance, inventory and rewards, doors, ambients, area scripts, timers, dialog availability, cutscene mode, and WorldFlow state. Exclude volatile fields explicitly. Evidence target: E2 and E4.

**Artifacts and deliverable:** Snapshot schema, extractor, canonicalizer, semantic diff, and assertion format.

**Exit criterion:** The WorldFlow lab can compare normal and skip outcomes automatically and report a focused semantic difference for each injected fault.

**Dependencies:** EEEX-01, EEEX-04, BCS-03, DLG-02, WF-01.

**Gate contribution:** Required for RG3.

## TEST-05 — Build the disposable Combat Intent arena

**Labels:** preparation, area:test, priority:P0, blocker:observer

**Question:** Can perception, shadow evaluation, safe handoff, action feedback, fallback, and early spatial choice be proven end-to-end?

**Why it matters:** Source analysis and simulation cannot prove actual engine lifecycle, queue, target, spell, or save behavior.

**Method and evidence:** Prepare an isolated full BG2:EE + EEex environment with a tagged mage, allied fighter, controlled enemies, known spellbooks, obstacles, reset mechanism, and deterministic saves. Keep it separate from the active installation. Evidence target: E4.

**Artifacts and deliverable:** Arena component, scenario catalog, expected traces, reset/restore procedure, environment manifest, and safety checklist.

**Exit criterion:** Shadow mode produces no gameplay or durable-state mutations; active mode eventually claims one narrow action; every injected uncertainty restores or preserves legacy behavior.

**Dependencies:** PREP-01, PREP-03, LIC-01.

**Gate contribution:** Required infrastructure for RG1 and RG2.

## TEST-06 — Build the disposable WorldFlow laboratory

**Labels:** preparation, area:test, priority:P0, blocker:worldflow-pilot

**Question:** Can a miniature quest exercise dialogue, cutscene, skip, area transition, death, missing actors, save/load, restart, and recovery in isolation?

**Why it matters:** Persistent orchestration must be validated in a purpose-built scenario where every interruption point is reproducible.

**Method and evidence:** Create a test quest with explicit normal, skip, external-interference, actor-loss, and failure paths. Provide save points or scripted setup for each transition and integrate semantic snapshots. Evidence target: E4.

**Artifacts and deliverable:** Test quest resources, scenario driver, fault-injection controls, prepared saves, and expected end states.

**Exit criterion:** Every WF-04 interruption boundary can be triggered reproducibly without touching the active game, and the lab resets cleanly between runs.

**Dependencies:** TEST-04, FLOW-01, WF-01.

**Gate contribution:** Required for RG3.

## TEST-07 — Validate unknown/supported mods and install-order compatibility

**Labels:** research-spike, area:test, priority:P0, blocker:compatibility-expansion

**Question:** What happens when unknown and supported content is installed before or after the engine, modifies claimed resources, or occupies expected script slots?

**Why it matters:** Protecting the engine's own filenames is not enough. A later mod can change a CRE assignment, DLG, ARE, spell, or public variable contract without overwriting the bridge file.

**Method and evidence:** Test SCS present/absent; unknown creature and quest mods before/after; recognized resource unchanged, harmlessly changed, relevantly changed, and ambiguously changed; occupied slots; relocated spells; adapter rerun; runtime fingerprint mismatch; and explicit native registration. Evidence target: E3 and E4.

**Artifacts and deliverable:** Compatibility matrix with expected claim, partial claim, observe-only, warning, rerun-required, and full-yield outcomes.

**Exit criterion:** Unknown content remains unclaimed and behaves as legacy; changed relevant content disables only affected adapters with actionable diagnostics; no install-order case silently broadens ownership.

**Dependencies:** IR-04, IR-05, DLG-03, WF-06, TEST-02, TEST-05, TEST-06.

**Gate contribution:** Principal validation for RG4 and required for RG5.

## TEST-08 — Run save-safety, long-run, and recovery soak

**Labels:** research-spike, area:test, priority:P1, blocker:public-preview

**Question:** Does repeated observation, action feedback, coordination, persistence, hot reload, save/load, and adapter failure accumulate harmful state or poison saves?

**Why it matters:** Many severe EEex and scripting faults appear only after repeated cycles, rest, cloning, area transitions, or reload.

**Method and evidence:** Run repeated battles, summons/clones, action interruption, group creation/destruction, area changes, rest, autosave/quicksave, full save/load, runtime disable/re-enable, clean exit/restart, and adapter circuit-breaking. Inspect logs and save artifacts for growth and known corruption indicators. Evidence target: E5.

**Artifacts and deliverable:** Soak protocol, run manifests, thresholds, raw metrics, save-size trends, and failure reports.

**Exit criterion:** No unbounded listener/state growth, delayed zombie actions, unresolved leases, failed reloads, duplicate persistent side effects, or unexplained save growth over the agreed duration and scenario count.

**Dependencies:** ACT-05, WF-07, PERF-03, PERF-04, PERF-05, TEST-05, TEST-06, TEST-07.

**Gate contribution:** Required for RG5.

---

# Epic LIC — Licensing, reuse, attribution, and publication safety

## LIC-01 — Audit SCS reuse terms per artifact class

**Labels:** research-spike, area:licensing, priority:P0, blocker:repository

**Question:** What may be copied, adapted, transformed, generated from, or merely studied from SCS source, generated scripts, data tables, documentation, and bundled third-party material?

**Why it matters:** The project intends to reuse as much valuable SCS knowledge as permitted. A vague whole-project conclusion is insufficient because source, generated artifacts, documentation, and bundled resources may have different provenance.

**Method and evidence:** Pin the exact SCS release and repository revision; archive applicable copyright/reuse statements; trace bundled third-party components; distinguish upstream-authored source from effective generated artifacts; and record required credit or redistribution limitations. Treat legal ambiguity as a shipping hold, not a technical assumption. Evidence target: E1.

**Artifacts and deliverable:** Artifact-class reuse decision table, attribution requirements, unresolved questions, and approved credit language. This is a provenance decision record, not legal advice.

**Exit criterion:** Every planned SCS-derived artifact class has a documented permitted-use conclusion. Unresolved categories remain reference-only and cannot be committed as distributable material.

**Dependencies:** PREP-01.

**Gate contribution:** Required for RG0, RG2, RG4, and RG5.

## LIC-02 — Enforce provenance metadata and original/derived separation

**Labels:** preparation, area:licensing, priority:P0, blocker:combat-pilot

**Question:** Can original kernel algorithms, SCS-derived rules, game-derived facts, compatibility adapters, and local-only evidence remain mechanically distinguishable?

**Why it matters:** Clear separation makes attribution honest, enables independent evolution, and ensures that removing the SCS adapter does not remove the standalone engine architecture.

**Method and evidence:** Require provenance fields or headers for rule tables and generated outputs: origin class, upstream path/revision, transformation description, author/credit, license decision, and evidence IDs. Define directories and dependency directions that isolate adapters from the kernel. Evidence target: E2 validation of schema and dependency rules.

**Artifacts and deliverable:** Provenance schema, source/rule header templates, repository directory policy, attribution generator inputs, and dependency-lint rules.

**Exit criterion:** An automated report can enumerate all derived material and origin; core modules do not import SCS adapter policy; unclassified rule data fails validation.

**Dependencies:** PREP-02, LIC-01.

**Gate contribution:** Required for RG2 and RG5.

## LIC-03 — Prevent accidental redistribution of game, save, and third-party artifacts

**Labels:** preparation, area:licensing, priority:P0, blocker:public-preview

**Question:** Can builds and releases exclude proprietary game resources, local decompiles, TLK content, saves, logs, credentials, and non-redistributable fixtures?

**Why it matters:** Research requires real-shaped local evidence, but the public artifact must contain only approved original, synthetic, or permitted upstream material.

**Method and evidence:** Define a publication allowlist and deterministically scan source trees, fixtures, archives, and generated outputs for known resource formats, save/TLK signatures, local paths, secrets, and unclassified provenance. Build from a clean checkout, then install, reinstall, and uninstall the resulting package with pinned WeiDU against the synthetic fake game and compare it with the publication manifest. Evidence target: E2 for scanner/allowlist enforcement and E3 for fake-game package enforcement.

**Artifacts and deliverable:** Release audit specification/script plan, fixture classification enforcement, clean-build manifest, and third-party notices template.

**Exit criterion:** A clean checkout builds the release from permitted inputs only; packaging fails closed on any unclassified or local-only artifact; the resulting archive matches its publication manifest.

**Dependencies:** LIC-01, LIC-02, TEST-02, TEST-03.

**Gate contribution:** Required for RG5 and before sharing test artifacts externally.

## LIC-04 — Define contribution and upstream-credit policy

**Labels:** preparation, area:licensing, priority:P2, blocker:public-preview

**Question:** How should future contributors add rules or adapters while preserving provenance, attribution, and conflict boundaries with established mod names/projects?

**Why it matters:** Provenance degrades quickly if new tactical rules arrive without source classification or if project/module names create avoidable ecosystem conflict.

**Method and evidence:** Draft contribution requirements for evidence IDs, source attribution, licensing declaration, synthetic fixture preference, naming checks, and adapter isolation. Include SCS credit prominently and avoid names already associated with Tactics/Tactics Remix or other established projects. Evidence target: E1 policy review.

**Artifacts and deliverable:** CONTRIBUTING policy inputs, naming review checklist, and third-party rule submission template.

**Exit criterion:** A hypothetical external rule contribution can be accepted or rejected using objective provenance, evidence, and naming criteria.

**Dependencies:** LIC-01, LIC-02, PREP-02.

**Gate contribution:** Required for RG5, not for private proof-of-concept research.

---

# Recommended execution order and parallel work

## Stage 0 — Establish the repository as an evidence project

Execute PREP-01 through PREP-03 and LIC-01 first. In parallel, begin TEST-01 and design TEST-05 without installing anything into the active game. Create the provenance and support vocabulary before collecting more artifacts.

**Stage exit:** RG0.

## Stage 1 — Prove observation before control

Critical path:

1. EEEX-01, EEEX-02, EEEX-04
2. BCS-01, IR-01, IR-02
3. SCS-01, SCS-02, SCS-03
4. SPACE-04, EEEX-06
5. ACT-01, PERF-01
6. SCS-06 in TEST-05, replayed through TEST-01

Work that can proceed in parallel: licensing/provenance schema, initial DLG/FLOW static research, and synthetic-game preparation.

**Stage exit:** RG1. No action injection is authorized before this gate.

## Stage 2 — Lease one ordinary combat action

Critical path:

1. EEEX-03, ACT-02, ACT-03
2. IR-04, IR-05, TEST-02
3. PERF-02 and ACT-04
4. One narrow mage action in TEST-05 using normal spell expenditure and feedback
5. Failure, ownership-change, SCS-present, SCS-absent, and resource-mismatch cases

Prebuff, movement, group coordination, broad archetypes, and every-enemy enrollment remain out unless their individual research exits are already met.

**Stage exit:** RG2.

## Stage 3 — Prove one durable WorldFlow

Critical path:

1. DLG-01, DLG-02, FLOW-01, BCS-02
2. WF-01, WF-02, WF-03
3. TEST-04 and TEST-06
4. WF-04, FLOW-02, WF-05
5. WF-06 and BCS-04
6. Runtime-disable and legacy handback checks

**Stage exit:** RG3. The pilot should remain synthetic/purpose-built; no real quest conversion is required to prove the model.

## Stage 4 — Expand by audited packs

Run IR-03, DLG-03, TEST-03, TEST-07, SPACE-02 through SPACE-05, SCS-04/SCS-05 encounter packs, and native registration. Expansion units should be behavior families or individually reviewed encounter/quest packs, never global heuristic enrollment.

**Stage exit:** RG4.

## Stage 5 — Harden for preview

Complete WF-07, PERF-03 through PERF-05, TEST-08, LIC-03/LIC-04, byte-exact installer restoration, migration documentation, and all P0/P1 risks. Publish only after the evidence ledger is complete for the claimed support matrix.

**Stage exit:** RG5.

# Issue-closing requirements

Every research issue derived from this backlog must include in its closing comment or result document:

1. Outcome: Proven, Conditional, Rejected, or Unknown.
2. Applicable evidence layer or layer combination reached, exact artifacts used, and required layers
   that remain unexecuted.
3. Reproduction steps that do not write to the active game.
4. Finding and limitations, including competing explanations rejected.
5. Architectural consequence: proceed, change design, reduce scope, or block.
6. New risks or dependencies discovered.
7. Whether the result is reusable knowledge suitable for the BG modding knowledge base; unresolved theories are not added there.
8. Links to traces, fixtures, source maps, hashes, screenshots where relevant, and raw logs.

# Explicit deferred scope

The following are north-star possibilities or later work, not promises made by the initial architecture:

- Automatic safe conversion of arbitrary third-party BCS or DLG.
- Automatic enrollment of every creature based on class, level, race, or spellbook.
- Guaranteed exactly-once execution for every Infinity Engine side effect.
- Elimination of every BCS/DLG artifact; small engine-facing bridges are expected to remain.
- Full pathfinding, navmesh reconstruction, chokepoint control, formation AI, or real-time battlefield planning.
- Multiplayer determinism or synchronized Lua state.
- Non-EEex operation.
- Support for every EE engine patch, platform, EEex branch, or historical SCS version.
- Whole-game quest conversion before the synthetic WorldFlow pilot and explicit per-quest contracts.
- Broad compatibility claims for unknown mods beyond the invariant that unclaimed content remains legacy-owned.
- Runtime semantic rewriting of resources modified after installation unless fingerprint and handback research proves it safe.
- Persistent tactical plans, group blackboards, object IDs, or action queues across save/load.
- Shipping copied game resources, saves, TLK content, local decompiles, or SCS-derived artifacts lacking a completed reuse decision.
- Testing, installation, or hot-patching against the user's active playthrough without separate explicit authorization.
- Treating all high-INT or high-WIS creatures as equally coordinated or omniscient; personality/training profiles require their own later design.
- A universal cure for all legacy script bugs. Unknown scripts first receive pass-through, observation, linting, and optional manual migration.

# Initial program success definition

The first meaningful success is not a large spell catalog or a rewritten quest. It is reproducible evidence that the platform can:

1. Observe an explicitly enrolled actor or flow without side effects.
2. Explain the effective legacy/SCS decision context.
3. Acquire a narrow, revocable ownership lease.
4. Submit an ordinary engine action.
5. Verify what actually happened rather than trusting queue acceptance.
6. Persist only safe, versioned semantic state.
7. Recover after interruption or yield completely.
8. Leave unknown and changed content under its original scripts.
9. Restore claimed resources exactly on uninstall.
10. Attribute every reused rule and distribute only permitted artifacts.

Once those properties are proven, increasing intelligence and coverage becomes an incremental data, adapter, and scenario program rather than a fragile all-at-once rewrite.
