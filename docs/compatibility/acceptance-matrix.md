# Compatibility Architecture and Acceptance Matrix

**Status:** Normative design contract; acceptance evidence is not yet complete

**Domains:** Combat Intent, WorldFlow, shared runtime kernel, adapters, installer, and extension API

**Related design:** `docs/plans/2026-08-27-script-engine-architecture-design.md`

## 1. Prime invariant

> Unknown, modified, stale, or ambiguous content remains under its original BCS/DLG ownership.
> A failed check disables only the affected adapter and yields to legacy behavior.

This invariant applies at installation, game bootstrap, adapter activation, every Combat Intent
decision, every WorldFlow transition, save import, upgrade, downgrade, stack drift, and failure
recovery. It forbids broad creature scans, permissive fingerprint matching, guessed quest state,
and global takeover as a fallback.

An unsupported mod is not automatically incompatible. Its resources remain C0 pass-through
content unless an explicit, evidence-backed adapter claims a narrower scope. The expected failure
mode is a disabled enhancement with a diagnostic, not disabled legacy content.

## 2. Evidence and gate vocabulary

The **Evidence** column in this document names the minimum proof required to pass the case, not
the evidence currently available.

| Grade | Required proof |
|---|---|
| E0 | Claim or documentation input inspected: upstream documentation, comments, forum statements, unpinned source, or an unverified design assumption |
| E1 | Revision-pinned source inspection or reproducible static evidence: effective resource, decompile, binary, install output, or provenance chain |
| E2 | Deterministic host-side simulation or model proof outside the game process |
| E3 | Real WeiDU integration against a minimal synthetic fake game for compilation, patching, packaging, allowlist enforcement, reinstall, and restoration, without launching a game executable |
| E4 | Disposable full-game BG2:EE plus EEex runtime/save proof |
| E5 | Repeated supported-corpus compatibility, save/load, performance, failure-path, and soak proof |

Gate names follow the architecture design:

| Gate | Purpose |
|---|---|
| G0 | Charter, terminology, compatibility, provenance, and safety approved |
| G1 | Engine bridge, observation, handoff, and fallback proved feasible |
| G2 | Unknown-content pass-through and exact restoration proved |
| G3 | Observer lifecycle and bounded cost proved |
| G4 | Combat Intent shadow decisions proved legal, fair, deterministic, and explainable |
| G5 | One active combat action safely leased, observed, interrupted, and returned |
| G6 | Migration cost measured and tooling direction reviewed |
| G7 | WorldFlow normal, skip, interruption, save, recovery, and disable converge |
| G8 | Declared alpha support matrix, lifecycle, performance, provenance, and docs proved |

## 3. Compatibility tiers

Tiers are per resource or behavior family. A single mod may contain content at several tiers.

| Tier | Name | Meaning | Permitted mutation | Required fallback |
|---|---|---|---|---|
| C0 | Pass-through | Unknown or deliberately unmanaged content | None | Original BCS/DLG owns all behavior |
| C1 | Observed | Recognized enough for inventory, trace, replay, or linting | None | Original behavior remains authoritative |
| C2 | Cooperative | A mod author registers through the versioned extension API | Only declared typed hooks and claims | Original scripts remain available |
| C3 | Adapted | A supported effective resource family has a bounded adapter | Only fingerprinted branches, actors, transitions, or resources | Preserved legacy branch and independent kill switch |
| C4 | Native | A supported family is fully migrated and exhaustively tested | Full declared ownership within its manifest | Legacy-compatible committed states and reversible installation |

No naming convention, class, hostility state, equipment set, spellbook, generated prefix, or
similarity score can promote content out of C0 by itself.

## 4. Activation model

### 4.1 Static eligibility

Before an adapter can request runtime ownership, its immutable activation envelope must validate:

- namespaced adapter ID, API version, domain, and compatibility tier;
- supported game/campaign and EEex capability profile;
- relevant installed-mod features rather than assumed component numbers alone;
- explicit actor/resource/transition selectors;
- claimed resources, script positions, globals, locals, and extension points;
- effective dependency closure, including referenced scripts, dialogue edges, spells, items,
  IDS/2DA entries, public-variable readers/writers, and cutscene skip rigs;
- exact dependency hashes initially; conservative semantic fingerprints only after the relevant
  loss-aware IR and canonicalization suite are proved;
- save schema and legacy handback states;
- coexistence, replacement, and conflict declarations; and
- an independently testable fallback.

Missing, changed, duplicated, opaque, or conflicting evidence makes only that adapter ineligible.

### 4.2 Runtime lease or claim

Static eligibility grants no right to act. Ownership must be revalidated at the point of use.

**Combat Intent** receives a short lease for at most one ordinary engine action. The actor must be
explicitly enrolled, currently controllable, free of higher encounter ownership, in a supported
lifecycle state, and still able to perform the intended action. Queue acceptance ends the dispatch
lease;
completion remains an independently observed outcome. Acceptance creates a separate in-flight
attempt token. It blocks conflicting new Combat Intent claims for that actor until observed
start/failure/interruption/invalidation/timeout, but it does not own or clear the legacy/player
queue and is never persisted across save/load.

**WorldFlow** receives a narrow durable claim for one declared transition. Preconditions, public
state, stable identities, idempotency class, side effects, postconditions, recovery, and legacy
handback must all be known. The claim is a versioned saga state, not a raw object pointer or an
assumption of ACID rollback.

### 4.3 Claim state

Adapters move through `discovered -> eligible -> active` only by satisfying both layers. Any
capability loss, fingerprint drift, claim collision, ownership change, unexpected public state,
or repeated fault moves the smallest affected scope to `quarantined`. Quarantine is fail-closed
and preserves diagnostics; it is never automatically widened into a global takeover.

## 5. Resource and install-order policy

### 5.1 Resource policy

- **CRE/script slots:** Preserve effective script identity wherever possible. Do not use runtime
  script-slot replacement in production until persistence, script caching, save/load, and exact
  restoration are proved. Never overwrite a later mod's effective slot assignment.
- **BCS:** Preserve higher-priority encounter/world control and the original legacy path. A bridge
  may claim only a reviewed insertion point and must become inert when its adapter is absent,
  stale, or faulted. Never clear an action queue that the current lease does not own.
- **DLG:** Use semantic anchors, preserve start-state ordering, continuation semantics, inbound and
  outbound interjections, carried actions, dialogue entry points, and public globals. A supported
  cutscene change must include its normal, skipped, and recovery end-state dependencies.
- **ARE/area scripts:** Treat fresh and save-baked visited areas separately. Prefer preserving
  existing resource identities. Any region, door, ambient, actor, or area-script mutation needs
  an exact installed-default and runtime-state restoration contract.
- **SPL/ITM/IDS/2DA:** Resolve effective installed semantics. Never assume vanilla/SR/SCS resrefs,
  generated allocation, MSECTYPE bounds, or marker uniqueness. An unclassified resource is not a
  license to guess.
- **Variables and DVs:** Internal names are unique and length-safe. Existing quest variables,
  timers, DVs, and dialogue entry points are public compatibility contracts. Their readers,
  writers, meanings, and handback values belong in the dependency graph.
- **Lua/bootstrap resources:** Use unique names and verify expected bootstrap/capability state.
  A missing or overwritten runtime must make bridges inert and leave legacy resources usable.

### 5.2 Install order

WeiDU remains the system of record for patches, backups, uninstall order, and inter-mod
cooperation. Inventory and adapter generation run against the final intended effective stack,
normally after content, EET_end, SCS, spell systems, and other AI/quest patches.

| Scenario | Policy |
|---|---|
| Unknown mod before the engine, unrelated to claims | Leave it C0; do not change its resources |
| Unknown mod before the engine changes a claimed dependency | Quarantine that adapter unless a conservative supported semantic variant matches |
| Unknown mod after the engine adds unrelated content | New content remains C0; use stack-epoch rules below |
| Later mod changes a claimed resource or script slot | Do not force the old shape back; quarantine the affected adapter |
| Engine installed before EET_end/SCS or another required finalizer | Refuse the dependent adapter or require a tail refresh; never patch an intermediate shape optimistically |
| Late tool moves/overwrites runtime assets | Capability/bootstrap failure yields to legacy behavior and emits a bounded diagnostic |

Uninstall must restore every pre-existing overridden artifact through the WeiDU stack. Mod-owned
new files must be allowlisted and removed. TLK append residue is tracked separately from byte-exact
override restoration.

## 6. Stack epoch and dependency drift

The install manifest records a stack epoch derived from a normalized install-stack identity,
capability profile, and adapter dependency fingerprints. The exact canonicalization and refresh
mechanism are P0 research items.

- With an unchanged epoch, adapters still revalidate their runtime leases/claims.
- After stack drift, all newly introduced resources remain C0 automatically.
- Combat Intent also becomes stale after unknown stack drift. A local dependency envelope is not
  sufficient until P0 research proves an external-control closure covering area/encounter
  controllers, shouts, shared variables, forced actions, and script-slot topology. Initial
  reactivation requires a refreshed full dependency/control scan.
- WorldFlow becomes stale by default after unknown stack drift. A newly added script can write a
  public quest global without modifying the currently claimed DLG/BCS, so WorldFlow requires a
  refreshed reverse-reference/dependency scan before reclaiming the flow.
- A changed claimed resource, changed public writer set, missing dependency, or ambiguous
  fingerprint quarantines only the dependent adapter.
- Failure to read or validate the epoch is equivalent to stale state, not permission to proceed.

The epoch is a compatibility signal, not a security boundary and not a substitute for runtime
ownership checks.

## 7. Save lifecycle

### 7.1 Combat Intent

Combat beliefs, plans, target reservations, runtime object IDs, userdata, and action-queue
ownership are ephemeral. They are discarded on load, area/lifecycle discontinuity, capability
loss, or actor replacement. Stable profile identity is re-resolved from the adapter manifest.
An engine action already in progress is observed as current state; it is not assumed to have
completed and is not duplicated.

### 7.2 WorldFlow

Durable state is minimal and versioned: flow ID, schema version, phase/epoch, stable resource or
DV identities, idempotency/commit markers, and reconciliation data. Persistent data never contains
engine pointers, userdata, or session object IDs.

Every durable phase must be either:

1. a legacy-safe committed state from which restored original scripts remain meaningful; or
2. a tested transient state whose actual world postconditions deterministically reconcile to a
   legacy-safe committed state.

If that cannot be proved, the flow is not eligible for migration.

### 7.3 Upgrade, downgrade, disable, and uninstall

- Existing saves are adopted only when public and actual world state match a supported phase.
- Schema upgrades are sequential, pure where possible, and postcondition-checked before stamping
  the current version.
- An older runtime encountering future state disables that flow without reverse-migrating it.
- Disabling either subsystem leaves public contracts valid and legacy artifacts available.
- Uninstall at any supported committed state restores original resources without requiring the
  runtime to execute afterward.
- A design that requires the player to remember a special detach step for correctness is
  insufficient; detach may improve cleanup but cannot be the only safety path.
- Removing EEex before the engine is unsupported until the compiled-bridge behavior is proved.

## 8. Failure containment

Containment is hierarchical and smallest-scope-first:

| Scope | Response |
|---|---|
| Candidate/action | Reject the candidate; choose another or yield |
| Actor/flow instance | Release lease/claim and return that instance to legacy ownership |
| Adapter | Trip a bounded circuit breaker and quarantine the adapter |
| Domain | Disable Combat Intent or WorldFlow independently |
| Kernel/capability boundary | Enter mutation-free safe mode |

Additional rules:

- Distinguish proposed, accepted, started, advanced, completed, failed, interrupted, invalidated,
  timed-out, and unknown outcomes.
- Queue acceptance is never completion evidence.
- Lua error containment does not justify unsafe native EEex calls; native access violations bypass
  `pcall`/`xpcall`.
- Retries must follow the declared idempotency class and remain bounded.
- Missing/dead/replaced targets, Project Image ownership, dialogue/cutscene state, player control,
  phase changes, and capability loss invalidate combat leases immediately.
- A WorldFlow cutscene watchdog may unwind only a lease it demonstrably owns.
- Listener registration uses guarded root-level trampolines so hot reload cannot append duplicate
  observers.
- Diagnostics are bounded, provenance-rich, and must not mutate quest/combat state.

## 9. Extension API compatibility contract

The extension API is declarative, namespaced, versioned, validated, and frozen after registration.

Shared registration declares: extension ID, API range, mod identity/features, domain, tier,
selectors, resource/variable claims, dependency fingerprints, coexistence/conflicts, save schema,
fallback, provenance, and required capabilities.

Combat Intent extensions contribute scalar facts, stable actor selectors, profiles, perception
sources, known resource semantics, typed candidates, and handoff conditions. WorldFlow extensions
contribute stable flow/state IDs, public-variable contracts, semantic transition anchors,
preconditions, typed/idempotency-classified effects, postconditions, recovery, and legacy handback.

The normal API does not expose arbitrary native calls, kernel monkey patches, or raw BCS response
strings. Any future unsafe escape hatch is separately permissioned, provenance-tracked, and cannot
be part of a general compatibility claim.

Duplicate IDs, incompatible API ranges, malformed typed actions, overlapping exclusive claims,
or ambiguous precedence cause registration failure before mutation. Registration file/load order
must not change the resolved ownership graph.

## 10. Acceptance cases

### 10.1 Installation, pass-through, and stack drift

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-I01 | Install a synthetic unknown mod before the engine with unique CRE/BCS/DLG/ARE resources. | Unknown resources remain byte-identical and C0; no actor, transition, or variable is claimed. | E3 | G2 |
| COMP-I02 | Install an unknown mod before the engine that changes one dependency of an otherwise supported adapter. | Only that adapter is ineligible/quarantined; the changed effective legacy resource runs. | E3 | G2 |
| COMP-I03 | Install an unknown NPC/quest mod after the engine without touching a claimed dependency. | New content remains C0 and runs through its own scripts; no naming/class heuristic enrolls it. | E4 | G2 |
| COMP-I04 | Install a later mod that patches a claimed BCS or DLG while leaving the bridge artifact present. | Fingerprint/epoch validation makes the bridge inert; later effective legacy logic continues. | E4 | G2 |
| COMP-I05 | Install a later mod that changes a claimed CRE script-slot assignment. | The engine never forces the old assignment back; the later slot owner wins and the adapter yields. | E4 | G2 |
| COMP-I06 | Remove or omit one declared adapter dependency in a synthetic stack. | Installation/runtime disables only the dependent adapter and reports the missing identity. | E3 | G2 |
| COMP-I07 | Introduce a duplicate engine resource prefix, bootstrap filename, adapter ID, or exclusive internal variable claim. | Conflict is detected before mutation; no best-effort overwrite occurs. | E3 | G2 |
| COMP-I08 | Install and uninstall over pre-existing override artifacts and mod-owned new files. | Pre-existing artifacts are restored byte-for-byte; only allowlisted mod-owned artifacts are removed. | E3 | G2 |
| COMP-I09 | Put the engine mid-stack, add later components, then exercise supported WeiDU uninstall/reinstall paths. | Later components remain installed/effective and restoration matches stack semantics; no manual WeiDU.log edits occur. | E3 | G2 |
| COMP-I10 | Change the normalized stack epoch without refreshing compatibility metadata. | New content is C0; both domains remain stale/pass-through until a refreshed dependency and external-control scan succeeds. | E4 | G8 |
| COMP-I11 | Add a new BCS/DLG resource after installation that reads or writes a WorldFlow public global without modifying the directly claimed resource. | Refreshed reverse-reference scan discovers the writer/reader and keeps the flow stale until reviewed. | E3 | G8 |
| COMP-I12 | Delete/corrupt the manifest or make stack-epoch parsing ambiguous. | Kernel enters mutation-free pass-through; it never reconstructs ownership heuristically. | E4 | G2 |

### 10.2 BCS handoff, combat leases, and action outcomes

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-B01 | Put a matching higher-priority override `NoAction()` staging block above an eligible lower combat script. | Combat Intent receives no lease; the higher world/encounter owner suppresses lower behavior. | E4 | G1 |
| COMP-B02 | Use a higher-priority setup/bookkeeping block that ends in `Continue()` before the bridge. | Evaluation reaches the reviewed handoff exactly once without reordering the higher block. | E4 | G1 |
| COMP-B03 | Make the bridge Lua trigger throw a controlled Lua error under active EEex. | Trigger declines, no mutation occurs, legacy evaluation continues, and a bounded diagnostic is recorded. | E4 | G1 |
| COMP-B04 | Queue an ordinary action but suppress/delay its started-action event. | Dispatch lease ends; an in-flight attempt remains `accepted` or `unknown`, blocks a conflicting new Combat Intent claim, and never becomes `completed` without independent evidence. | E4 | G5 |
| COMP-B05 | Let player/script activity clear an accepted action before start. | Outcome becomes cleared/interrupted; intent and reservation release; legacy/player control is not cleared in response. | E4 | G5 |
| COMP-B06 | Interrupt a normal spell after start but before effect completion. | Resource/action outcome is observed accurately; plans do not record a completed spell effect. | E4 | G5 |
| COMP-B07 | Give an enrolled caster an active Project Image owner lock. | No action is queued on the owner; Combat Intent yields and emits a reason-coded exclusion. | E4 | G5 |
| COMP-B08 | Kill, despawn, charm, replace, or move the chosen target between scoring and dispatch. | Immediate revalidation rejects the action and releases the lease without queue clearing. | E4 | G5 |
| COMP-B09 | Load an existing save containing actors that reference the original effective script resrefs, then install/disable/uninstall the engine. | Saved actors retain usable script identities and return to legacy behavior in every supported lifecycle. | E4 | G5 |
| COMP-B10 | Instrument all production bridge paths while exercising eligible actors. | No normal Combat Intent path mutates script-slot assignments at runtime. | E4 | G5 |
| COMP-B11 | Force one actor policy to fail while another eligible actor decides in the same encounter. | Faulted actor yields; the other actor and unrelated adapters continue deterministically. | E4 | G5 |
| COMP-B12 | Repeat a deterministic adapter fault past its configured threshold. | Only that adapter circuit-breaks; further calls are suppressed and legacy behavior remains active. | E4 | G5 |

### 10.3 Dialogue, cutscene, and WorldFlow convergence

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-D01 | Add bridge/target states to a DLG with multiple start triggers and transition-only states. | Existing start-state selection is unchanged; bridge-only states cannot hijack dialogue entry. | E4 | G7 |
| COMP-D02 | Exercise a state with unconditional and guarded continuation transitions plus an interjection. | Last-valid transition and interjection ordering remain equivalent on legacy and WorldFlow paths. | E4 | G7 |
| COMP-D03 | Build inbound/outbound interjections whose alternate states carry plot-critical actions and vocabulary-dependent replies. | Every route preserves required actions, entry points, and declared text dependencies. | E3+E4 | G7 |
| COMP-D04 | Run and skip the same supported cutscene. | Normal and skip paths converge on the same declared world/public-variable postconditions. | E4 | G7 |
| COMP-D05 | Keep a cutscene launch condition true across several area-script passes. | Durable claim/once guard prevents stacked launch or repeated `StartCutSceneMode()`. | E4 | G7 |
| COMP-D06 | Remove, delay, or decline the downstream forced dialogue on which legacy content relied to return control. | Owned recovery ends only the engine's own cutscene lease and restores player control without disturbing unrelated modes. | E4 | G7 |
| COMP-D07 | Apply a later semantic DLG change after the supported adapter was generated. | Dependency/epoch drift makes the adapter stale; changed dialogue remains legacy-owned. | E4 | G2 |
| COMP-D08 | Load a save with an unknown/out-of-range value in a claimed public quest global. | WorldFlow does not normalize or overwrite it; the flow yields with an actionable diagnostic. | E4 | G7 |
| COMP-D09 | Make an external legacy script change a public flow variable while WorldFlow has an active claim. | Claim detects incompatible state, stops at a safe boundary, and neither races nor rewrites the external value. | E4 | G7 |
| COMP-D10 | Disable/uninstall WorldFlow from every durable phase of the pilot flow. | Each phase is legacy-safe or deterministically reconciles before handback; no duplicate reward/spawn/dialogue occurs. | E4 | G7 |

### 10.4 ARE, area-script, and EET behavior

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-A01 | Enter a supported area for the first time after installation. | Adapter sees the expected effective ARE/script state and performs only declared behavior. | E4 | G7 |
| COMP-A02 | Load a pre-existing save in which the same area has already been visited and save-baked. | WorldFlow inspects actual runtime state, adopts only a supported phase, and never assumes override defaults were applied. | E4 | G7 |
| COMP-A03 | Exercise equivalent standalone/EET areas containing overlapping campaign-specific travel-region variants. | Each platform restores the effective installed default rather than a hardcoded campaign assumption. | E4 | G8 |
| COMP-A04 | Temporarily replace an area script under an owned, declared cutscene lease. | The exact previous effective script is restored on success, skip, error, and recovery; unrelated ownership is untouched. | E4 | G7 |
| COMP-A05 | Trigger an area transition/autosave at each supported WorldFlow phase. | Reload resolves to one valid durable phase with no duplicate side effect or lock. | E4 | G7 |
| COMP-A06 | Install a later mod that changes the claimed ARE or area script. | Only the dependent adapter quarantines; effective later content remains authoritative. | E3+E4 | G2 |
| COMP-A07 | Present EET BG1/BG2 collision-renamed resources and unsuffixed non-colliding resources. | Logical identities resolve to the intended campaign actor/resource with no prefix guess. | E3+E4 | G8 |
| COMP-A08 | Attempt to activate a finalized-dialog/area adapter before EET_end or against an intermediate EET shape. | Static eligibility refuses the adapter and requests a final-stack scan; no optimistic patch occurs. | E3 | G2 |

### 10.5 SCS integration

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-SCS01 | Run the pilot stack without SCS. | No SCS adapter activates; legacy/native allowlisted content still functions according to its tier. | E4 | G4 |
| COMP-SCS02 | Install supported SCS with generated mage scripts and effective CRE assignments. | Inventory maps actual generated artifacts to logical profiles; no generated resref is hardcoded. | E3+E4 | G4 |
| COMP-SCS03 | Build a second supported SCS install whose generated resrefs differ but semantics/profile inputs match. | Both installs produce the same logical adapter/decision fixtures while retaining their own effective resrefs. | E3+E4 | G6 |
| COMP-SCS04 | Present an unsupported SCS version or generated script shape. | Content stays C1/C0 and SCS remains the fallback; no fuzzy activation occurs. | E3 | G2 |
| COMP-SCS05 | Include a mod-added neutral/staged creature that SCS GenAI would classify as a combatant. | Combat Intent does not enroll it without an exact encounter/profile registration. | E4 | G2 |
| COMP-SCS06 | Give an SCS actor higher encounter-specific override/class logic above its generic generated AI. | Higher encounter/world behavior always wins; Combat Intent can lease only at the reviewed generic handoff. | E4 | G5 |

### 10.6 Spell Revisions and effective spell semantics

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-SR01 | Run equivalent mage fixtures with vanilla spells, SR, and SCS+SR. | Logical spell identity and typed semantics resolve from effective resources in every supported stack. | E3+E4 | G4 |
| COMP-SR02 | Relocate a familiar spell to a non-vanilla SPWI slot through SR/SCS allocation. | No adapter queues the assumed vanilla resref; the effective resolved spell is used or the candidate is rejected. | E4 | G5 |
| COMP-SR03 | Create a shared-SPLSTATE/administrative-residue false-positive condition. | Fast marker checks are confirmed against concrete active effect source/marker semantics before positive classification. | E4 | G5 |
| COMP-SR04 | Add an unknown mod spell or materially changed known spell to an enrolled actor. | The spell is excluded or invalidates the dependent claim; Combat Intent never invents its target, fairness, or geometry semantics. | E3+E4 | G5 |

### 10.7 EEex capability and lifecycle

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-X01 | Use the declared EEex v0.11 + LuaJIT baseline in a disposable game. | Required capability profile activates and every required bridge/lifecycle primitive passes its probe. | E4 | G1 |
| COMP-X02 | Use each additional declared EEex v1.x capability profile and its native script layout. | Equivalent normalized boundary operations pass without policy-module changes. | E4 | G8 |
| COMP-X03 | Install with EEex bootstrap present but required LuaJIT/runtime configuration absent. | Installer refuses active components before payload/TLK/loader mutation and explains the missing capability. | E3+E4 | G1 |
| COMP-X04 | Mix complete stale v0.11 and v1 internal EEex script layouts. | Environment is rejected as ambiguous upgrade residue; no family is guessed. | E3 | G1 |
| COMP-X05 | Remove one optional EEex symbol used by a single feature. | Only dependent capability/adapter disables; unrelated domains and legacy behavior continue. | E4 | G1 |
| COMP-X06 | Hot-reload the engine/bootstrap repeatedly and transition areas/load saves. | Root-level trampolines remain single-registration; no duplicate decision, trace, or transition fires. | E4 | G3 |
| COMP-X07 | Inject a controlled Lua exception at every engine-boundary callback. | Errors are contained at the smallest scope, logged once/bounded, and cause no mutation after failure. | E4 | G1 |
| COMP-X08 | Leave compiled bridges installed but remove/disable only the engine's Lua bootstrap while EEex remains active. | Every bridge declines and ordinary legacy evaluation continues. | E4 | G1 |
| COMP-X09 | Leave compiled EEex triggers/actions in resources but remove or partially remove EEex itself in a disposable clone. | Observed behavior is documented; release either proves safe pass-through or blocks this uninstall order with an exact restoration procedure. | E4 | G1 |
| COMP-X10 | Stress declared actor/flow counts with tracing, capability checks, resource parsing, and degraded modes. | CPU/memory/logging remain within measured budgets; overload disables enhancement before legacy behavior is starved. | E5 | G8 |

### 10.8 Save, upgrade, downgrade, disable, and uninstall

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-P01 | Load saves created before installation at every supported stable pilot-quest state. | WorldFlow adopts only phases whose public and actual world state match; Combat Intent rebuilds ephemeral state. | E4 | G7 |
| COMP-P02 | Load a save captured during an ambiguous legacy sequence or with conflicting world/public state. | No flow claim occurs; legacy owns the sequence and diagnostics identify the ambiguity. | E4 | G7 |
| COMP-P03 | Save/load during queued, started, and interrupted ordinary combat actions wherever the engine permits. | Combat Intent does not persist lease ownership or duplicate the action; post-load state is freshly observed. | E4 | G5 |
| COMP-P04 | Save/load before and after each WorldFlow pre-action marker, engine side effect, postcondition, and commit. | Every reachable save converges exactly once or to a declared duplicate-tolerant result. | E4 | G7 |
| COMP-P05 | Load state from two older supported schema generations into the current runtime. | Sequential migrations preserve public contracts, validate postconditions, and stamp current schema only on success. | E2+E4 | G7 |
| COMP-P06 | Load future schema state with an older runtime. | Older runtime does not down-convert or mutate it; only that flow disables and yields. | E2+E4 | G7 |
| COMP-P07 | Uninstall from every committed WorldFlow pilot state and reload with original resources. | Original scripts remain meaningful; no engine runtime is required to complete the uninstall handback. | E3+E4 | G7 |
| COMP-P08 | Remove/disable the engine at each reachable transient/pending WorldFlow state. | State is already legacy-safe or deterministic recovery was completed; otherwise the transition design fails acceptance. | E4 | G7 |
| COMP-P09 | Save/load/resave data whose registered marshal handler is temporarily absent under every supported EEex profile. | Data is preserved or explicitly migrated/cleaned according to the profile; saving does not crash or strip unrelated handlers. | E4 | G8 |
| COMP-P10 | Inspect every persistent engine payload across representative saves. | No userdata, pointer, raw object ID, action-queue owner, cyclic table, or unsupported scalar type is present. | E1+E4 | G7 |
| COMP-P11 | Exercise load, area change, actor replacement, summon/clone lifecycle, charm, death, resurrection, and despawn. | Ephemeral identity and reservations expire; stable identities re-resolve without attaching stale state to a new object. | E4 | G5 |
| COMP-P12 | Disable and re-enable each domain independently across save/load. | Public variables remain valid, disabled domain performs no mutation, and re-enable requires fresh eligibility/ownership checks. | E4 | G8 |
| COMP-P13 | Invoke actual QuickLoad on an own disposable save using a verified, authorized route; record the exact profile and saved identity. | Durable facts restore; transient attempts clear; actors re-resolve; no duplicate callbacks or unintended action replay; legacy behavior remains available. Named loading of a quicksave slot does not satisfy this case. User-approved deferral from Task10/G1 on2026-10-04; integration owner, Task40, still unexecuted. | E4 | G8 |

### 10.9 Mod-author extension API

| ID | Setup | Expected behavior | Evidence | Gate |
|---|---|---|---|---|
| COMP-API01 | Register extensions at supported, too-old, and too-new API ranges. | Only compatible ranges register; rejected versions perform no partial mutation. | E2 | G8 |
| COMP-API02 | Register the same namespaced extension ID twice with different content. | Duplicate registration fails deterministically and identifies both provenance sources. | E2 | G8 |
| COMP-API03 | Register overlapping exclusive resource, transition, actor, or variable claims. | Both claims quarantine unless an explicit validated cooperation/replacement relationship resolves them. | E2+E3 | G8 |
| COMP-API04 | Install a synthetic third-party mod that uses only cooperative typed registration. | Its declared content reaches C2 without patching or enrolling unrelated resources. | E3+E4 | G8 |
| COMP-API05 | Submit malformed/illegal typed action descriptors, targets, or resource semantics. | Validation rejects them before native compilation/queueing and reports a bounded extension error. | E2+E4 | G8 |
| COMP-API06 | Request a raw BCS response/native call through the ordinary safe API. | Request is rejected; any future unsafe capability requires a separate explicit permission and support exclusion. | E2 | G8 |
| COMP-API07 | Remove a cooperative extension while keeping its content installed and load existing saves. | Its resources return to C0 pass-through; inert extension data does not block legacy scripts. | E3+E4 | G8 |
| COMP-API08 | Vary extension file discovery and registration order repeatedly. | Frozen ownership graph, conflicts, priorities, and outputs remain deterministic. | E2 | G8 |
| COMP-API09 | Add unknown fields, capability names, and future save-schema declarations. | They are rejected or preserved according to version rules, never silently assigned current semantics. | E2 | G8 |
| COMP-API10 | Register maximum-length names and deliberate namespace collisions under BCS/global/local limits. | Valid generated names remain unique and length-safe; collisions fail before publication or save mutation. | E2+E3 | G8 |

## 11. Unresolved research

Every research item ends as **Proven**, **Conditional**, **Rejected**, or **Unknown**, with exact
environment/version/fingerprints, method, artifacts, evidence grade, residual uncertainty, and
the design decision it unblocks.

### P0 — architecture blockers

| Research item | Required experiment/output | Blocks |
|---|---|---|
| Compiled EEex bridge with EEex absent/partial | Disposable remove/restore matrix for Lua triggers/actions and exact safe installer ordering | G1, COMP-X08/X09 |
| Safe BCS handoff form | Compare same-resref insertion, generated bridge, and any sidecar mechanism across representative SCS/legacy priority stacks | G1, COMP-B01-B03 |
| Action/save serialization | Save/load queued, started, interrupted, LuaAction-chained, and script-level-changed states | G1/G5, COMP-B04-B10/P03 |
| Stack epoch and refresh | Safe normalized stack identity plus a refresh path that does not corrupt/reorder a WeiDU stack | G2/G8, COMP-I09-I12 |
| Public-variable reverse-reference completeness | Typed-IR scan of all BCS/DLG readers/writers, interjections, area scripts, and skip rigs for a pilot flow | G7, COMP-I11/D09 |
| WorldFlow save boundary and handback | Model/engine proof that every reachable pilot phase is legacy-safe or deterministically reconcilable | G7, COMP-D10/P01-P08 |
| EEex support floor | Source plus disposable runtime capability matrix for v0.11 and candidate v1.x releases, including LuaJIT and mixed-layout rejection | G1/G8, COMP-X01-X05 |
| Persistence without handler/runtime | Supported-version tests for fallback marshal storage, future schema, disable, uninstall, and EEex removal | G7/G8, COMP-P06-P10 |
| Initial namespace/provenance contract | Collision scan and redistribution/provenance classification for engine and SCS-derived artifacts | G0/G2/G8 |
| Combat external-control closure | Static and disposable proofs covering area/encounter controllers, shouts, shared globals, forced actions, script-slot topology, and later-mod drift | G5/G8 post-drift reactivation, COMP-I03/I10/B01/B02/SCS06 |

### P1 — required before a supported alpha

- Semantic-fingerprint canonicalization for any resource family that wants to relax exact hashes;
  otherwise that family remains exact-hash-only in the alpha.
- SCS SSL/template-to-generated-artifact mapping and logical profile inventory.
- SCS migration ledger format, attribution, licensing, and redistribution decisions by artifact.
- SR/vanilla/SCS+SR semantic spell-identity corpus and conservative unknown-spell behavior.
- EET resource-renaming, campaign-variant, EET_end, and final effective-dialogue mapping.
- Typed IR subset for ordering, `Continue()`, variables, dialogue edges, actions, and opaque nodes.
- Normal/skip/recovery WorldFlow end-state equivalence tooling.
- Disposable Combat Intent arena and WorldFlow miniature quest laboratory.
- Hot-reload, clone/summon/charm/despawn, Project Image, and listener lifecycle matrix.
- Circuit-breaker taxonomy, bounded diagnostic format, and player-visible compatibility report.
- Performance baseline, per-decision budget, degradation ladder, stress, and soak procedures.
- Synthetic unknown-mod-before/after fixtures and one cooperative extension reference fixture.
- Byte-exact WeiDU publication/uninstall allowlist and documented TLK-residue policy.

### P2 — deferred expansion research

- Opt-in heuristic enrollment, if it can ever satisfy the prime invariant; disabled by default.
- Conservative semantic matching of previously unseen resource variants.
- Additional BG:EE/non-EET/game-version/operating-system capability profiles.
- Generalized Biffing and other broad late-stack tooling interactions beyond the initial corpus.
- Formal downgrade/export tooling beyond fail-closed future-schema handling.
- Full-scale compatibility-report generation for large arbitrary mod collections.
- Broader BCS/DLG race-condition lints and assisted migration automation.
- Navigation, chokepoint, unfamiliar projectile/AoE geometry, and movement-loop research.
- Sustainable family/encounter migration economics after representative pilots.

## 12. Acceptance interpretation

Passing an individual row proves only that row in its recorded environment. A support claim must
name the exact adapter version, game/EEex/SCS/SR/EET families, exact dependency hashes and any
proved semantic-fingerprint versions, install
epoch, evidence artifacts, and untested boundaries. G8 requires the relevant rows to reach their
stated evidence tiers across the declared corpus; it does not mean arbitrary mod stacks are
supported.

Any failed row narrows or quarantines the associated feature. It never weakens the prime invariant.

## 13. Initial G8 acceptance allowlist

The first supported-alpha profile treats every current acceptance case as required unless the G8
decision record explicitly removes the corresponding feature from the supported profile:

- `COMP-I01` through `COMP-I12`
- `COMP-B01` through `COMP-B12`
- `COMP-D01` through `COMP-D10`
- `COMP-A01` through `COMP-A08`
- `COMP-SCS01` through `COMP-SCS06`
- `COMP-SR01` through `COMP-SR04`
- `COMP-X01` through `COMP-X10`
- `COMP-P01` through `COMP-P13`
- `COMP-API01` through `COMP-API10`

A removed feature changes the support profile and documentation; it does not turn a failed or
unexecuted row into a pass. Earlier gates run their relevant subsets, but G8 reconciles the entire
applicable allowlist at the evidence tier stated in each row.
