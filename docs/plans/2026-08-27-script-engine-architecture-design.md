# Chriz BG Script Engine — Architecture Design

**Status:** Approved direction; research and implementation gates remain open

**Date:** 2026-08-27

**Repository:** `chriz-bg-script-engine`

**Primary modules:** **Combat Intent**, **WorldFlow**, and a shared runtime kernel

## 1. Executive summary

This project is a compatibility-first scripting platform for Baldur's Gate Enhanced
Edition games running EEex. Its long-term aim is to make authored Infinity Engine behavior
safer, more expressive, more observable, and easier to test than large collections of raw
BCS/DLG priority blocks.

The first product-facing vertical slice is **Combat Intent**: an SCS-inspired combat
decision system that preserves and selectively reuses SCS's accumulated tactical knowledge
while gradually replacing brittle generated control flow with perception, utility scoring,
short intentions, group coordination, spatial reasoning, normal engine actions, and
execution feedback.

The second policy domain is **WorldFlow**: persistent, deterministic, recoverable state
machines for quests, dialogue orchestration, cutscenes, encounter phases, rewards, and other
world scripting. WorldFlow is not combat AI. It shares infrastructure with Combat Intent but
uses stricter durability, compatibility, idempotency, and recovery rules.

The engine will not perform a global takeover. Unknown or uncertain content always remains
under its original BCS/DLG ownership. Adapters claim only explicitly identified resources,
script decisions, or state transitions. When capability, fingerprint, ownership, or runtime
state is uncertain, the new layer yields completely to legacy behavior.

Small engine-facing BCS/DLG artifacts will probably remain necessary. The goal is to replace
the fragile authoring and orchestration model, not to remove every `.BCS` or `.DLG` file from
the game.

## 2. Decisions already made

The following decisions are part of the approved design:

1. The work belongs in a new repository, not in `chriz-bg-rebalance`.
2. The combat module is named **Combat Intent**.
3. The persistent world-scripting module is named **WorldFlow**.
4. Both modules share a small runtime kernel but keep separate policy and state semantics.
5. SCS is a major source of tactical knowledge and selected reusable code, not something to
   dismiss or rewrite blindly.
6. SCS integration is evolutionary: observe, supervise, migrate behavior families, then
   optionally replace the generic combat layer.
7. Unknown content is legacy-owned by default.
8. Any uncertainty about ownership or compatibility causes an immediate yield to legacy
   BCS/DLG, even when that means an enhancement stays inactive.
9. Combat and world actions must use normal engine semantics whenever those semantics matter.
   Combat Intent will not obtain difficulty by granting free spells, ignoring aura, bypassing
   casting time, or applying effects directly as a substitute for ordinary casting.
10. The current active game installation is a read-only research source. Engine validation
    will use synthetic fixtures and explicitly approved disposable game environments.
11. Initial runtime scope is single-player BG2:EE/EET with EEex. Multiplayer, non-EEex
    support, and every Enhanced Edition/version are deferred.
12. Compatibility, provenance, diagnostics, simulation, and fallback are foundation work,
    not release hardening to be postponed.

## 3. Motivation and problem statement

BCS and DLG are powerful but fragile authoring targets:

- Script-level and block ordering encode hidden priority.
- The first matching block normally wins, while `Continue()` changes control flow in ways
  that are difficult to inspect globally.
- Multiple independently authored scripts can race through shared globals, timers, shouts,
  dialogue, and action queues.
- A queued action being accepted does not prove that it started, completed, or persisted.
- Save/load can interrupt queued continuations while Lua tables survive with stale engine
  userdata.
- Cutscene launch and skip paths are often hand-maintained duplicates that drift apart.
- Dialogue start and transition selection depend on ordering semantics that are easy to
  break with otherwise reasonable patches.
- Generic AI assigned to mod-added creatures can activate neutral or staged actors before
  their encounter scripts are ready.
- Debugging normally reveals what happened only after a fight, quest, or save has broken.

SCS demonstrates both the strength and the limitation of the current model. It uses a
high-level SSL generation pipeline, creature-specific spell allocation, archetype selection,
difficulty controls, compatibility knowledge, and hundreds of carefully ordered decisions.
That corpus creates remarkably immersive behavior. The effective output is nevertheless a
large reactive priority tree expressed through the same limited BCS execution model.

The project therefore separates two kinds of value:

- **Retain and extend domain knowledge:** counters, target validity, prebuff fairness,
  archetypes, encounter exceptions, spell expenditure, difficulty concepts, and years of
  practical compatibility work.
- **Replace brittle machinery gradually:** implicit priority, scattered state, weak action
  feedback, uncoordinated actors, limited spatial choice, duplicate world-flow paths, and
  low observability.

## 4. Goals

### 4.1 Platform goals

- Provide a small, versioned EEex/engine boundary instead of allowing policy modules to call
  arbitrary native APIs directly.
- Make ownership of actors, resources, decisions, and transitions explicit.
- Preserve legacy behavior whenever the new engine declines, fails, is disabled, or cannot
  prove compatibility.
- Produce structured, replayable explanations of decisions and state transitions.
- Make most policy logic testable outside the game with pure scalar snapshots and seeded
  simulation.
- Support install-time resource inventory, provenance, semantic fingerprints, and conflict
  reporting.
- Support versioned persistent state with migrations and recovery.
- Enable future mod authors to register compatible profiles and flows without patching the
  kernel.

### 4.2 Combat Intent goals

- Reuse and improve SCS-grade combat knowledge without depending permanently on SCS runtime
  scripts.
- Make decisions from perceived or plausibly remembered information rather than unrestricted
  engine omniscience.
- Respect actual spellbooks, items, aura, casting time, interruption, target legality, range,
  line of sight, and installed spell behavior.
- Support explainable utility scoring, bounded weighted randomness, reaction latency, and
  character-specific competence.
- Support one- to three-action intentions with revalidation and safe abandonment.
- Support bounded squad communication, role and target reservations, and spatial decisions.
- Preserve authored encounter phases and higher-priority world control.

### 4.3 WorldFlow goals

- Express quest and encounter orchestration as versioned durable state machines.
- Require explicit preconditions, effects, postconditions, retry policy, and recovery for
  every transition.
- Preserve public globals, timers, script names, dialogue entry points, and other contracts
  that vanilla or third-party mods may depend on.
- Reconcile interrupted flows after save/load or missing actors instead of replaying an
  entire sequence blindly.
- Generate or validate normal, skipped, and emergency-recovery end states from a shared
  specification where possible.
- Prevent duplicate rewards, spawns, journal updates, dialogue starts, and stacked cutscene
  ownership.

## 5. Explicit non-goals

The initial program does not promise:

- Automatic safe conversion of arbitrary third-party BCS/DLG.
- A global heuristic takeover of every creature or quest.
- Exactly-once execution for every opaque engine side effect.
- Removal of every BCS/DLG artifact.
- Multiplayer determinism or synchronization.
- A non-EEex runtime.
- Support for every EE executable, EEex release, operating system, or total-conversion stack.
- A complete navigation mesh, chokepoint solver, or optimal path planner.
- Perfect, omniscient, or uniformly difficult AI.
- Rewriting dialogue prose or redesigning quest content as part of WorldFlow migration.
- Repackaging SCS as a renamed or modified distribution.
- Runtime testing against the user's active playthrough without separate explicit approval.
- Migrating all combat and world scripts before producing useful incremental releases.

## 6. Design principles

### 6.1 Legacy ownership is the default

The engine has no implicit right to control an unknown actor or resource. A claim requires an
allowlisted identity, a supported semantic fingerprint, required capabilities, an explicit
scope, and a fallback. Missing or ambiguous evidence means no claim.

### 6.2 Compatibility by construction

Compatibility is enforced by ownership boundaries, namespacing, manifests, fingerprints,
feature gates, and fallbacks. It is not inferred from the absence of reported bugs.

### 6.3 Capability detection, not version optimism

EEex component numbers, script locations, APIs, and lifecycle details have changed across
releases. The kernel will probe required capabilities through a version-specific adapter and
disable only dependent features when a safe requirement is absent. Native-crash hazards must
be rejected before the unsafe call; `pcall` cannot contain C++ access violations.

### 6.4 Normal engine semantics

Combat decisions queue ordinary `SpellRES`, `SpellPointRES`, movement, attack, or item actions
where appropriate. Action acceptance is recorded separately from action start and verified
postconditions. Direct effects and forced casts are reserved for world scripting cases where
the engine and existing content already define instant scripted semantics.

### 6.5 Ephemeral tactics, durable world state

Combat beliefs, intentions, reservations, and object IDs expire quickly and are rebuilt.
Quest progress and compatibility-facing variables are durable, versioned, and reconciled.
The two stores are never interchangeable.

### 6.6 Explain every mutation

Every claimed action or transition records the owner, inputs, rejected alternatives, selected
rule, required capabilities, resource provenance, and outcome confidence. A player-facing
debug mode may be added later, but structured traces are part of the kernel from the start.

### 6.7 Evidence before expansion

Every milestone ends at an explicit gate. A failed gate narrows the feature, improves the
tooling, or leaves the project in observer/linter mode. It does not justify bypassing safety.

### 6.8 Selective SCS reuse with visible provenance

SCS's documentation permits code reuse with full credit while asking that the mod or a
modified version not be mirrored. Every reused or adapted artifact will carry its source,
version/revision, transformation, and redistribution classification. SCS-derived data and
adapters remain separable from the independently owned kernel.

## 7. Architecture overview

```text
                       install-time inventory
                  + provenance + fingerprints
                               |
                               v
                    +-----------------------+
                    | Shared Runtime Kernel |
                    +-----------------------+
                    | capabilities          |
                    | identity resolution   |
                    | ownership / leases    |
                    | state / migrations    |
                    | action bridge         |
                    | outcome observation   |
                    | traces / circuit break|
                    +-----------+-----------+
                                |
                 +--------------+--------------+
                 |                             |
                 v                             v
        +-------------------+          +------------------+
        |   Combat Intent   |          |    WorldFlow     |
        +-------------------+          +------------------+
        | perception        |          | durable states   |
        | beliefs           |          | guarded changes  |
        | candidates        |          | postconditions   |
        | utility / profile |          | reconciliation   |
        | short intentions  |          | recovery / skip  |
        | squad blackboard  |          | compatibility ABI|
        +---------+---------+          +---------+--------+
                  |                              |
                  +---------------+--------------+
                                  |
                                  v
                tiny BCS/DLG bridge or generated glue
                                  |
                                  v
                       ordinary engine behavior

Adapters: SCS | legacy BCS/DLG | supported mods | future SDK
Tools: typed IR | linter | resource graph | replay | trace viewer
```

### 7.1 Shared kernel responsibilities

The kernel owns mechanisms, not encounter policy:

- Boot-time capability negotiation and diagnostic reporting.
- One-time listener registration through guarded root-level trampolines.
- Normalized lifecycle events for bootstrap, actor load, area transition, save import, action
  start, action advance, and adapter disable.
- Semantic identity resolution without persisting engine object IDs or userdata.
- Separate ephemeral and durable state stores.
- Versioned schemas and migration entry points.
- Resource/actor ownership claims and short-lived combat leases.
- Normal engine-action compilation, queuing, and observation.
- Postcondition evaluation and outcome confidence.
- Per-adapter circuit breakers, kill switches, and bounded diagnostics.
- Deterministic clocks/RNG interfaces for simulation.
- Structured traces and replay input/output.
- Compatibility reports derived from the install manifest and runtime state.

The kernel does not decide whether `Slow` is better than `Magic Missile` or whether a quest
should grant a reward. Those decisions belong to the policy modules and adapters.

### 7.2 Engine boundary

EEex exposes Lua triggers/actions, script-slot inspection, stored scripting targets, resource
inspection, sprite state, actions, and persistence. These APIs are sufficient in principle,
but their lifecycle and safety differ by version. All direct EEex access must live under an
`engine` adapter. Policy code consumes scalar snapshots and semantic operations.

This boundary prevents a future EEex change from spreading through every rule and permits
pure-Lua simulation without constructing fake C++ userdata.

### 7.3 Install-time boundary

WeiDU remains the installer of record. The project will not attempt to replace WeiDU's stack,
backup, dialog-compilation, or cross-mod patch semantics. Higher-level tools may generate BAF,
D, 2DA, manifest, or Lua artifacts, but public installation remains a conventional, reversible
WeiDU component with synthetic-game and byte-exact uninstall tests.

## 8. Ownership and arbitration

### 8.1 Ownership hierarchy

From highest to lowest authority:

1. Player control and hard engine modes.
2. WorldFlow or legacy encounter ownership: dialogue, cutscene, phase transition, staging,
   plot state, scripted retreat, transformation, spawning, or other choreography.
3. Explicit forced behavior defined by a supported encounter adapter.
4. Combat Intent's one-action combat lease.
5. Legacy generic combat AI.
6. Conservative idle/basic fallback when no legacy layer exists.

Combat Intent never changes allegiance, plot globals, dialogue state, encounter phases, doors,
spawns, loot, cinematics, or exact choreography.

### 8.2 Combat lease

A combat lease is temporary permission to choose and queue at most one normal action. It is
valid only while all declared conditions remain true:

- Actor and adapter are explicitly enrolled.
- Required resource fingerprint and capabilities match.
- Actor is hostile/active and eligible for combat control.
- No higher authority currently owns the actor.
- Current action/aura state allows a new decision.
- Actor is not in dialogue, cutscene staging, Project Image owner-lock, or another excluded
  lifecycle state.
- The intended target/action remains legal immediately before queuing.

The lease ends on queueing, timeout, interruption, target invalidation, phase change, control
change, error, capability loss, or adapter disable. Plans never justify destructive global
queue clearing.

### 8.3 WorldFlow claim

A WorldFlow claim is a durable assertion that one flow instance may advance one transition.
Unlike a combat lease, it must survive save/load and reconcile stale owners. A claim records a
flow identifier, schema version, transition/epoch, durable status, and recovery policy—not a
raw runtime object ID.

WorldFlow is modeled as an idempotent saga, not an ACID transaction. Some engine actions cannot
be rolled back or proven exactly once. Each transition must declare whether an action is:

- naturally idempotent;
- conditionally repeatable after checking a postcondition;
- at-most-once with a durable pre-action marker;
- at-least-once with convergence/duplicate tolerance;
- compensatable through a specific recovery action; or
- unsupported for automatic scheduling.

## 9. Combat Intent design

### 9.1 Decision pipeline

```text
eligible actor
  -> perception-limited snapshot
  -> belief/memory update
  -> legal candidate generation
  -> utility scoring
  -> profile and deterministic noise
  -> intention selection
  -> group reservation
  -> immediate revalidation
  -> one normal engine action
  -> start/outcome observation
  -> belief, trace, and reservation update
```

### 9.2 Perception and fairness

Combat Intent distinguishes:

- currently sensed facts;
- previously observed facts with age and confidence;
- shared facts received from eligible allies;
- inferences from visible behavior;
- engine-visible facts forbidden to fair-play policy;
- explicit difficulty/omniscience features, disabled by default.

Raw access to a party member's full spellbook, exact unseen resistances, hidden location, or
unobserved protection is not automatically fair merely because EEex exposes it. Each policy
input must name its perception source.

### 9.3 Legal candidates

Candidate generators produce options only after coarse eligibility checks. The legality layer
then verifies actual availability and action-specific constraints: memorized/usable resources,
ability header, target type, current aura/action state, perception, range/LOS, immunity or
protection knowledge, ally safety, item ability zero, and known engine locks.

Unknown spell/projectile geometry or unsupported installed modifications do not receive a
best-effort spatial guess. That candidate is rejected or delegated to legacy AI.

### 9.4 Utility and personality

Scores are decomposed into named terms rather than one opaque priority number. Expected terms
include survival, control value, damage, counter value, resource cost, risk, positioning,
friendly-fire risk, redundancy, plan synergy, encounter objective, and profile preferences.

Character profiles should separate dimensions that games often collapse into Intelligence:

- tactical competence;
- planning horizon;
- reaction latency;
- choice noise/consistency;
- aggression and caution;
- discipline and willingness to abandon a plan;
- teamwork and communication quality;
- resource conservation;
- creativity/risk tolerance;
- training, faction, archetype, and explicit encounter overrides.

High intelligence does not automatically imply military coordination. A brilliant but
isolated wizard, trained soldier, animal, hive creature, summoned servant, and panicked novice
should differ for understandable reasons.

Weighted randomness selects among credible alternatives using a deterministic seed. Greater
competence normally reduces poor-candidate breadth, reaction delay, and noise; it does not
turn every actor into an identical optimizer.

### 9.5 Short intentions

An intention is usually one or two future actions, with three as an exceptional upper bound.
It records purpose and constraints, not a brittle queue of engine actions. Every step is
regenerated/revalidated before execution. Hysteresis avoids changing plans every tick, while
expiry and failure budgets prevent fixation.

Examples include expose-then-disable, retreat-then-defend, strip-then-control, zone-then-focus,
or protect-caster-then-engage. The plan is abandoned when its assumptions no longer hold.

### 9.6 Squad coordination

The squad blackboard is ephemeral and scoped to a combat/group. It may record target focus,
dispel/disable reservations, role claims, protected allies, danger zones, and recently shared
observations. Entries expire and are revalidated.

Group intelligence is not universal telepathy. Membership comes first from explicit encounter
metadata. Conservative proximity, hearing, faction, or shout inference may be added for generic
actors only after research. Information sharing is constrained by perception and communication
quality.

### 9.7 Spatial reasoning

The initial spatial model supports positions, distance, engine LOS/perception checks, known
circular AoE geometry, ally/enemy clustering, simple safe-point sampling, escape zones, and
bounded repositioning. Cones, lines, bouncing projectiles, delayed clouds, secondary projectiles,
path reachability, and chokepoints require a tested geometry/capability registry.

### 9.8 SCS migration strategy

Combat Intent progresses through four modes:

1. **Shadow:** compute and trace hypothetical choices; SCS acts normally.
2. **Supervise:** claim only narrow, high-confidence decisions at a validated SCS handoff;
   otherwise fall through.
3. **Migrate:** replace one behavior family at a time while SCS remains fallback for the rest.
4. **Standalone:** use the project's own low-level combat bridge for explicitly supported
   creatures; retain higher encounter scripts and conservative fallback.

The initial order is expected to be mage offense, mage defense/emergency behavior, prebuffing,
fighter/fighter-mage, priest/support, thief, mixed squads, specialized monsters, and then
individually reviewed encounters. The order is provisional and subject to migration-cost data.

## 10. WorldFlow design

### 10.1 State-machine model

A representative flow is:

```text
NOT_STARTED
  -> CLAIMED
  -> ACTORS_READY
  -> DIALOGUE_COMPLETE
  -> RESOLUTION_PENDING
  -> COMMITTED

Any nonterminal state may enter RECONCILING, ABORTED_SAFE, or LEGACY_YIELD.
```

Every state and transition declares:

- durable identifier and schema version;
- owner and support/fingerprint requirements;
- public engine globals/locals/timers read or written;
- required actors/resources and semantic resolution rules;
- preconditions;
- planned engine actions;
- postconditions and observation confidence;
- idempotency/retry classification;
- timeout and recovery behavior;
- normal, skipped, interrupted, and legacy handoff outcomes;
- provenance and external compatibility contract.

### 10.2 DLG and BCS boundaries

Dialogue text, player replies, journal presentation, interjections, and engine dialogue UI remain
DLG-native. Tiny BCS/DLG triggers/actions may call the WorldFlow bridge, consult generated
predicates, or execute engine actions. Unsupported constructs remain opaque legacy nodes rather
than being rewritten by an incomplete model.

WorldFlow may eventually generate BAF/D glue from a higher-level declaration, but only after
round-trip and runtime semantics are proven for the supported subset.

### 10.3 Cutscene and skip convergence

Where feasible, one declared final-state contract generates or validates:

- normal completion;
- `CUTSKIP*` response/end-state behavior;
- emergency recovery after interrupted load/area transition;
- cleanup such as cutscene mode, area script, breakability state, fades, actor placement,
  doors, ambients, and variables.

Equivalence is semantic, not byte-based: each path must satisfy the same declared world
invariants without duplicating non-repeatable rewards or plot mutations.

### 10.4 Reconciliation

On load or re-entry, WorldFlow reconstructs reality from durable engine state and supported
private metadata. It does not trust a lost queued continuation. Reconciliation can:

- detect that an action already achieved its postcondition;
- safely retry an idempotent action;
- continue from the next valid state;
- apply a documented compensating/recovery operation;
- yield to legacy control; or
- stop with an actionable diagnostic when no safe resolution exists.

WorldFlow may not hide an unrecoverable state behind an infinite retry.

## 11. Compatibility architecture

### 11.1 Primary invariant

> Unknown, modified, stale, or ambiguous content remains under its original BCS/DLG
> ownership. A failed compatibility check disables only the affected adapter; it never grants
> broader control.

Unsupported mods should normally continue to install and run. The expected degradation is
that a particular enhancement stays inactive until supported—not that unknown content stops
working.

### 11.2 Compatibility tiers

Support is declared per resource/domain rather than per whole mod:

| Tier | Meaning | Mutations permitted | Fallback |
|---|---|---|---|
| C0 Pass-through | Unknown content | None | Original scripts entirely |
| C1 Observed | Safely identified for tracing/linting | None | Original scripts entirely |
| C2 Cooperative | Mod author registered a supported extension | Typed declared hooks | Original scripts |
| C3 Adapted | Supported effective resource variants | Bounded branch/resource claims | Preserved legacy branch |
| C4 Native | Fully migrated supported corpus | Full declared ownership | Legacy-safe committed states and uninstall restoration |

A single mod may mix tiers: one mage profile at C3, a registered spell at C2, and all quests at
C0.

### 11.3 Adapter activation envelope

Each adapter declares:

- stable adapter ID, schema, and API version;
- domain and compatibility tier;
- supported games/campaigns and required mod features;
- exact actor/resource selectors;
- resources, script positions, variables, and transitions it may claim;
- dependency closure and semantic fingerprints;
- required EEex/engine capabilities;
- save schema and legacy handback states;
- original resource/branch used as fallback;
- coexistence and conflict declarations;
- provenance and distribution classification.

Activation has two phases:

1. **Static eligibility:** effective resources, install provenance, semantic fingerprints,
   dependencies, and capabilities match.
2. **Runtime claim:** the actor or flow has reached the declared safe handoff and immediate
   preconditions still hold.

No static eligibility means no bridge installation. No runtime claim means the bridge declines
and legacy execution continues.

### 11.4 Resource fingerprints

Whole-file hashes are useful evidence but often too strict. The project needs canonical semantic
fingerprints that preserve claimed meaning while ignoring proven-irrelevant formatting or TLK
number differences. Fingerprints may cover:

- a CRE's relevant identity fields and script-slot map;
- the ordered BCS blocks surrounding a handoff;
- a DLG state's triggers, transitions, actions, inbound/outbound links, and ordering role;
- an ARE's relevant script, region, door, ambient, and default-state fields;
- spell/item ability semantics required by a candidate;
- all known readers/writers of a public quest variable;
- installed SCS/SR/EET provenance needed by an adapter.

Ambiguous canonicalization is not accepted as a match. Research must demonstrate which changes
are irrelevant and which affect behavior.

### 11.5 Installation-order behavior

| Scenario | Required response |
|---|---|
| Unknown mod installed before us, unrelated resources | Leave it C0; it runs normally. |
| Unknown mod installed before us, modifies a claim | Fingerprint mismatch disables only that adapter. |
| Supported variant installed before us | Activate the declared bounded adapter. |
| Unknown mod installed after us, unrelated content | Combat adapters may revalidate locally; WorldFlow becomes stale until dependency rescan when new scripts could write public state. |
| Later mod changes claimed BCS/DLG/ARE/CRE | Bridge declines; later effective logic wins. |
| Later mod changes a CRE slot | Never force the old assignment back at runtime. |
| Stack changes without compatibility refresh | Yield wherever full dependency validity cannot be proven. |
| Installed before SCS/EET finalization | Do not activate adapters requiring final effective resources; request tail refresh. |
| Bootstrap/capability assets are moved or replaced | Enter safe mode and leave legacy scripts active. |

Merely protecting this mod's filenames is insufficient. A later component can leave a bridge
file untouched while replacing the CRE slot, area script, DLG state, global writer, or spell
semantics on which the bridge depends.

### 11.6 Domain-specific compatibility strictness

Combat Intent can often revalidate one actor and its immediate resources after an install-stack
change. WorldFlow usually cannot: a new script can write an existing quest global without
modifying the resource currently being controlled. Therefore:

- Combat Intent may remain active only if its complete local claim can be revalidated.
- WorldFlow enters stale/pass-through mode after unknown stack drift until a reverse-reference
  scan rebuilds and verifies the flow's dependency graph.

### 11.7 Resource-specific policies

#### CRE and script slots

- Prefer patching an existing script resref at a validated branch over changing a CRE's slot.
- Never auto-enroll by class, hostility, spellbook, or equipment alone.
- Never auto-enroll neutral actors.
- Runtime `SetScriptLevelResRef()` is not a production ownership primitive until save/load,
  caching, restoration, and uninstall behavior are proven.
- A required slot collision or altered saved actor causes yield unless a C4 migration explicitly
  supports it.

#### BCS

- Preserve higher encounter blocks and all ordering outside the declared insertion point.
- The bridge claims at most one bounded action/step.
- False, error, invalid target, timeout, or stale fingerprint continues to legacy logic.
- Do not use `NoAction()` merely to maintain ownership.
- Do not clear action queues unless every action is proven to be owned by the current claim.
- Discover SCS-generated script assignments from effective CREs/manifests; never hardcode
  `dw#mg*` names.

#### DLG

- Use semantic anchors, not assumed numeric states.
- Do not create an unintended start state.
- Preserve inbound/outbound `EXTERN`, continuation ordering, interjections, carried actions, and
  text dependencies.
- Retain a valid legacy transition until a C4 migration proves handback for every persisted
  state.
- Any skippable cutscene edit must generate or validate its matching skip end state.

#### ARE and area scripts

- Prefer patching the existing area-script resref over changing the ARE assignment.
- Treat unvisited resources and save-baked visited-area state as different cases.
- Runtime door, region, ambient, or area-script mutations require explicit restoration and
  postconditions.
- `SetAreaScript()` may be used only under a WorldFlow-owned cutscene transition and must restore
  the exact previous script.
- EET/campaign variants come from effective data, not assumed names.

#### SPL, ITM, IDS, and 2DA

- Resolve effective semantic resources; do not assume vanilla spell slots or SCS allocation.
- Unexpected changes invalidate only dependent candidates/adapters.
- Candidate APIs expose typed operations, not arbitrary action strings.
- Unknown projectile/ability/item semantics cause rejection or legacy delegation.

#### Globals, locals, and timers

- Private names use a unique project prefix and respect the 32-character engine limit.
- Existing quest variables are public compatibility contracts.
- Every adapter declares meanings and access modes for public variables it reads/writes.
- The analysis index records all known readers/writers.
- Unknown values/writers cause reconciliation or yield, never silent normalization.
- Overlapping exclusive claims quarantine both adapters unless coexistence is explicit.

### 11.8 Mod-author extension API

The future extension API is declarative, versioned, and frozen after registration.

Shared fields include extension identity, API range, mod/component predicates, domain/tier,
selectors/claims, dependencies/fingerprints, conflicts/coexistence, fallback, save schema, and
provenance.

Combat Intent extensions may provide actor selectors, profiles, known spell/item semantics,
typed candidates, handoff conditions, perceptible facts, and required fallback. They do not
receive direct queue/scheduler access by default.

WorldFlow extensions may provide stable flow/state IDs, public-variable contracts, transition
anchors, pre/postconditions, idempotent steps, save-safe committed states, legacy handback, and
shared normal/skip final-state declarations.

Duplicate IDs or exclusive claims fail registration. Registration order cannot change meaning.
Removing an extension returns its resources to C0 pass-through.

## 12. Persistence and save lifecycle

### 12.1 Combat Intent persistence

Combat Intent does not persist plans, targets, object IDs, userdata, action queues, or squad
reservations. On load and area lifecycle changes it discards unsafe ephemeral state, resolves
fresh actors, waits for a new handoff, and observes any existing engine action before deciding.

Static profiles and install metadata live outside sprite runtime state. Minimal scalar flags may
use engine locals when BCS interoperability requires them.

### 12.2 WorldFlow persistence

WorldFlow persists only stable, versioned facts:

- flow and schema ID;
- durable phase/epoch;
- claim/commit/idempotency token;
- semantic actor/resource identities;
- minimal reconciliation evidence;
- existing public globals in their established meanings.

It never persists engine userdata or runtime object IDs. EEex v0.11-compatible marshal payloads
contain only numbers, strings, and acyclic tables, with numeric `0`/`1` booleans. Exporters make
a sanitized copy and never mutate live state.

### 12.3 Save compatibility rules

| Event | Behavior |
|---|---|
| Save predates installation | Adopt only recognized stable states after inspecting actual world state. |
| Ambiguous legacy mid-sequence | Do not claim; legacy remains authoritative. |
| Save occurs after queueing | On load, inspect postconditions; queue acceptance does not imply execution. |
| Upgrade N-2 to N | Apply sequential pure schema migrations, then reconcile before commit. |
| Older runtime sees future schema | Do not down-convert; disable that flow and yield. |
| Runtime/module disabled | Ephemeral Combat Intent state disappears; WorldFlow must be at a legacy-safe committed or explicitly recoverable state. |
| Uninstall | WeiDU restores resources; internal inert variables may remain but restored scripts cannot depend on them. |
| EEex/marshal handler absent | Behavior must be proven per supported EEex version; never assume data is stripped or retained. |

A WorldFlow design that cannot safely hand back from every reachable persisted state is rejected
or narrowed before implementation.

## 13. Failure containment and diagnostics

Containment is hierarchical:

1. **Candidate fault:** reject that action.
2. **Actor fault:** release its lease and let legacy AI continue.
3. **Adapter fault:** trip only that adapter's bounded circuit breaker.
4. **Subsystem fault:** disable Combat Intent or WorldFlow independently.
5. **Kernel/native capability fault:** global read-only safe mode; no mutations.

Rules:

- Registered EEex callbacks use one labeled boundary wrapper that preserves return shape and
  rate-limits diagnostics. Internal functions remain unwrapped in tests so errors are visible.
- `pcall`/`xpcall` contain Lua failures only. Unsafe native inputs are preflighted.
- Action start is not completion. Outcome observers and postconditions are action-family-specific.
- Retry budgets are finite. Unknown outcomes are recorded as unknown, not success.
- Project Image owners are never queued by Combat Intent.
- WorldFlow watchdogs may unwind only cutscene/area ownership created by the same flow claim.
- Diagnostics never mutate quest state.
- Feature flags and master kill switches always restore fallthrough behavior.

## 14. SCS knowledge, reuse, and provenance

### 14.1 Reuse categories

Every rule/artifact is classified as:

- **Original:** independently designed kernel, algorithm, schema, test, or policy.
- **Game-derived:** facts generated from effective CRE/SPL/ITM/IDS/2DA/BCS/DLG/ARE data.
- **SCS-derived:** selectively adapted source, rule, table, or behavior with full attribution.
- **SCS compatibility:** disposable integration code tied to a documented version/fingerprint.
- **Reference-only:** inspected for understanding but not distributed or transformed into a
  shipping artifact.

Each non-original item records upstream path/revision/version, author, acquisition date, hash
where appropriate, transformation, required credit, and redistribution status.

### 14.2 What to preserve from SCS

Candidate knowledge includes legality and target filters, spell-counter relationships, prebuff
fairness/resource rules, archetypes, difficulty concepts, compatibility exceptions, encounter
ownership boundaries, and selected well-designed implementation patterns.

BCS/compiler workarounds and accidental priority consequences are not automatically promoted to
policy. Every migrated rule must explain its semantic purpose.

### 14.3 Migration ledger

Every migrated behavior family or encounter receives a ledger containing:

- source and effective behavior;
- provenance/license classification;
- retained knowledge;
- intentional differences;
- supported fingerprints and dependency closure;
- fallback and disable behavior;
- fixtures/traces;
- save/install compatibility;
- unresolved cases and support tier.

## 15. Analysis tools and intermediate representation

The project needs a typed, provenance-carrying IR for inspection and assisted migration. It
must represent resources, script slots, blocks, triggers, weighted responses, actions, objects,
variables, timers, DLG states/transitions, ordering, cross-resource edges, source spans,
effective hashes, and opaque unsupported nodes.

Initial uses are:

- resource/script-slot graph;
- public-variable readers/writers;
- branch/order/`Continue()` analysis;
- unreachable or shadowed blocks;
- repeated cutscene launchers and teardown imbalance;
- cutscene/skip-path drift;
- unsafe delivery to dead objects;
- timer/global/local mismatches;
- duplicate or unguarded side effects;
- semantic diff across mod versions;
- claim/fingerprint generation;
- scenario extraction and trace replay.

Automatic semantic conversion is not assumed. Unsupported constructs remain opaque and block
unsafe rewriting. WeiDU remains the compiler/installer until evidence supports a narrower change.

## 16. Testing strategy

### 16.1 Evidence levels

Research conclusions use an explicit scale:

- **E0 — source/documentation claim**
- **E1 — static artifact or binary/decompile proof**
- **E2 — deterministic pure-host simulation**
- **E3 — real WeiDU against a synthetic game**
- **E4 — disposable full-game engine proof**
- **E5 — supported-corpus soak/compatibility proof**

Safety-critical runtime claims cannot graduate on E0 alone.

### 16.2 Test layers

1. **Pure Lua/model tests:** immutable snapshots, fake boundary objects, seeded RNG, utility
   scores, intentions, reservations, WorldFlow transitions, migrations, property invariants.
2. **Golden replay:** recorded scalar states and expected reason-coded decisions/transitions.
3. **Static/IR tests:** canonicalization, dependency graphs, lints, source maps, fingerprints.
4. **WeiDU `--nogame` harness:** patch/generator unit tests using explicit fixtures.
5. **Synthetic fake game:** public installer, compilation, predicates, publication allowlist,
   rollback, reinstall/idempotency, and byte-exact uninstall.
6. **Disposable Combat Intent arena:** actor lifecycle, handoff, shadow comparison, one-action
   claim, interruption, spatial safety, SCS fallback, and performance.
7. **Disposable WorldFlow laboratory:** dialogue, cutscene, skip, missing/dead actors, area
   transition, save/load at every boundary, recovery, disable, and uninstall.
8. **Compatibility matrix and soak:** supported stack permutations, unknown mods before/after,
   repeated combats, summons/clones, area changes, saves, rest, reload, and bounded performance.

No automated test writes to the active playthrough installation.

### 16.3 Core invariants

Tests must prove, as applicable:

- Unknown resources remain byte- and behaviorally unclaimed.
- No unavailable, illegal, imperceptible, or unsafe candidate is queued.
- No policy consumes a fact absent from its perception snapshot.
- No queue acceptance is reported as completion.
- No persistent state contains object IDs or userdata.
- Save/load clears unsafe ephemeral state.
- Every lease and claim expires or reaches a declared terminal/recovery state.
- Higher encounter/world ownership always defeats Combat Intent.
- Errors disable only the smallest affected scope.
- Normal/skip/recovery WorldFlow paths converge on declared invariants.
- Rewards, spawns, journal changes, and dialogue starts are not duplicated.
- Install/uninstall touches only allowlisted artifacts and restores originals.
- Fixed seeds produce deterministic traces.
- Performance and memory stay within measured budgets.

### 16.4 Compatibility matrix minimum

Before an alpha, test at least:

- SCS present and absent;
- supported spell-revision system present and absent;
- different generated SCS resrefs;
- unknown mod installed before and after;
- harmless, relevant, and ambiguous changes to recognized resources;
- occupied/changed script slots;
- vanilla/SR/SCS+SR semantic spell identity;
- fresh and pre-existing saves;
- visited and unvisited area state;
- save/load during every supported lease/flow phase;
- EEex capability missing or changed;
- hot reload/listener duplication;
- subsystem disabled and re-enabled;
- reinstall after stack change;
- uninstall/restore;
- representative actor-count stress and extended soak.

## 17. Research and preparation program

Research is a first-class deliverable. Each spike ends as **Proven**, **Conditional**,
**Rejected**, or **Unknown**, with evidence level, artifacts, decision, remaining uncertainty,
and dependent work unblocked or blocked.

### 17.1 Foundation research

- Pin the initial game, EET, EEex, WeiDU, SCS, SR, and operating-system support baseline.
- Define a unique resource/global/local namespace.
- Create the evidence/provenance ledger and redistribution classifications.
- Create the failure taxonomy and risk register.
- Define support tiers and adapter activation schema.
- Decide how install-stack epochs and compatibility refreshes are detected.

### 17.2 EEex and engine research

- Complete a source- and runtime-backed capability matrix.
- Map bootstrap, load, sprite initialization, area change, save/marshal, action, rest, clone,
  despawn, and hot-reload lifecycle.
- Prove script arbitration and the exact safe handoff protocol.
- Determine durable versus ephemeral identity.
- Prove capability negotiation and circuit breaking across supported EEex versions.
- Define the complete fair-play read model.
- Determine what compiled EEex triggers/actions do if EEex is absent or partially removed.

### 17.3 SCS corpus research

- Build a stratified representative corpus rather than reading everything manually.
- Trace SSL/template inputs to generated BAF/BCS and effective CRE assignments.
- Extract a tactical-knowledge taxonomy.
- Characterize prebuff fairness/accounting and exceptions.
- Separate encounter contracts from generic combat policy.
- Build shadow-decision comparison/replay.
- Audit reuse terms per artifact class.

### 17.4 BCS/DLG/IR research

- Specify supported BCS execution semantics experimentally.
- Specify DLG start/transition/interjection semantics.
- Map cutscene launch, skip rigs, and end-state equivalence.
- Classify engine actions by idempotency, observability, retry, and compensation.
- Evaluate decompile/recompile fidelity.
- Design the typed IR and opaque-node rules.
- Validate high-value lints before attempting rewriting.
- Design semantic fingerprints and dependency closure.
- Prove bridge generation, install, idempotency, and restoration.

### 17.5 Action and ownership research

- Observe proposed, queued, started, advanced, completed, interrupted, cleared, rejected,
  timed-out, and unknown outcomes.
- Determine whether action families require different observers.
- Prove combat lease arbitration against scripts/player/WorldFlow/control changes.
- Define bounded retry/replan rules.
- Test clone, summon, charm, Project Image, and despawn edge cases.

### 17.6 WorldFlow research

- Formalize saga/claim/commit/reconciliation semantics.
- Define durable stores and schema migrations.
- Prove exclusive claims under competing launchers and reload.
- Enumerate interruption points and model-check recovery.
- Generate/verify normal and skip end states from one declaration.
- Preserve external globals and cross-mod signals.
- Design disable, upgrade, downgrade, and uninstall handoff.
- Prove that the selected pilot can hand back from every reachable persisted state.

### 17.7 Spatial, fairness, and performance research

- Verify coordinate, distance, range, LOS, perception, and safe native argument semantics.
- Build a tested AoE geometry registry.
- Determine bounded reposition/path-failure behavior.
- Formalize belief expiry and information sharing.
- Establish engine/Lua baselines and per-decision budgets.
- Compare event-driven, staggered, and periodic schedulers.
- Stress allocations, logging, resource parsing, and large groups.
- Define degradation ladders that reduce enhancement rather than blocking legacy behavior.

### 17.8 Test-environment preparation

- Pure-Lua scenario/replay harness.
- Synthetic CRE/BCS/DLG/SPL/ARE fixtures and fake game.
- Curated effective-resource corpus with redistribution classification.
- Disposable Combat Intent arena.
- Disposable WorldFlow miniature quest/laboratory.
- Install-order/stack-drift compatibility matrix.
- Save-safety and performance soak procedures.

## 18. Program epics and gates

```text
E0 Charter / compatibility / provenance
├── E1 Engine, EEex, BCS/DLG, SCS research
└── E2 Test lab, corpus, IR and ownership manifests
        |
        v
E3 Shared kernel + observer + safe fallback
├── E4 Combat Intent shadow pilot
│       └── E5 Combat Intent active one-action pilot
│               └── E6 Combat Intent scaling and SCS migration
│
└── E7 WorldFlow synthetic pilot
        └── E8 WorldFlow supported migrations

E2 + stable schemas -> E9 analysis tools and adapter SDK
E6 + E8 + E9       -> E10 hardening and supported alpha
E10                 -> E11 ongoing supported-corpus expansion
```

### G0 — Charter gate

Compatibility contract, terminology, provenance, support baseline, safety boundaries, and
non-goals are approved.

### G1 — Bridge feasibility gate

Required normal engine actions, handoff, observation, and legacy fallback are demonstrated.
Failure pivots the project to observer/linter work until a safer bridge exists.

### G2 — Unknown-content pass-through gate

Unknown fixtures installed before/after remain unclaimed. Relevant recognized changes disable
only affected adapters. Installer restore is exact for claimed resources.

### G3 — Observer gate

One tagged actor is traced without behavioral mutation, lifecycle leaks, stale references,
unbounded cost, or global enrollment.

### G4 — Combat Intent shadow gate

One synthetic mage produces legal, fair, deterministic, explainable choices compared with SCS.

### G5 — Active combat gate

One narrow action is safely leased, queued normally, observed, interrupted/reloaded, disabled,
and returned to legacy behavior. Broad combat work waits for this decisive gate.

### G6 — Migration economics gate

After several representative families, measure manual research, fixture, adapter, and review
cost. If expansion is too expensive, improve IR/extraction/tooling rather than spending tokens
on whole-corpus manual transcription.

### G7 — WorldFlow convergence gate

One miniature quest reaches one valid final state through normal, skipped, interrupted,
saved/reloaded, capability-failed, disabled, and recovery paths without duplication or lock.

### G8 — Supported alpha gate

Support matrix, install/uninstall, save lifecycle, performance/soak, provenance, migration
ledgers, troubleshooting, and adapter documentation substantiate the declared corpus.

A `1.0` release means the engine and its declared corpus are reliable—not that all known BCS/DLG
has been migrated.

## 19. Initial vertical slices

### 19.1 Combat Intent pilot

Use an explicitly tagged synthetic mage and one allied martial actor in a disposable arena.
Shadow-score only a small set such as `Slow`, `Glitterdust`, `Magic Missile`, and reposition/wait.
Record snapshot, legality, scores, choice, rejected alternatives, intended target/point, and the
actual legacy/SCS action that starts.

Active mode initially claims only one well-understood leaf, with real resource expenditure,
aura/casting time, ally-safe geometry, start/outcome observation, timeout, and immediate SCS or
legacy fallback. Then add one reservation interaction to prove group coordination without a
global hive mind.

### 19.2 WorldFlow pilot

Build a synthetic miniature quest rather than patching a real playthrough. Include actor setup,
dialogue, a skippable cutscene, one area/world mutation, one reward, and a final public variable.
Fault-inject missing/dead/busy actors, declined/interrupted dialogue, queued-not-executed action,
save/load before and after each transition, skip, capability loss, disable, upgrade, and uninstall.

## 20. Repository structure

Provisional structure:

```text
AGENTS.md
README.md
docs/
  architecture/
  decisions/
  plans/
  research/
  compatibility/
  provenance/
kernel/
combat-intent/
worldflow/
adapters/
  scs/
  legacy/
  cooperative/
tools/
  script-ir/
  corpus/
  replay/
tests/
  unit/
  scenarios/
  fixtures/
  fake-game/
  integration/
  soak/
packaging/
```

Directories will be introduced only when a plan task requires them. Empty scaffolding is not a
substitute for evidence or working slices.

## 21. Delegation and cost controls

Good bounded subagent tasks include one evidence spike, one pure module behind a frozen interface,
one candidate/legality rule with fixtures, one profile schema, one simulation scenario, one linter
rule, one adapter version/resource family, one WorldFlow transition, or one compatibility-matrix
cell.

The integration owner retains public schemas, cross-module interfaces, ownership/fallback rules,
disposable-game execution, release claims, and any decision involving the active game.

Cost controls:

- one supported stack first;
- generated corpus manifests instead of whole-corpus reading;
- canonical research memos so findings are not repeatedly rediscovered;
- compact, redistributable fixtures and replay traces;
- schema freezes per milestone;
- one behavior/encounter family between reviews;
- measured migration effort and an explicit economics gate;
- feature flags and adapter isolation;
- authoritative ownership manifest/support matrix;
- no broad tasks such as “rewrite mage AI” or “convert every quest.”

## 22. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Native EEex crash from bad API/argument/lifecycle | Narrow adapter, capability probe, disposable proof, reject before call |
| New layer suppresses encounter scripts | Explicit handoff, priority tests, one-action leases, legacy default |
| Queue accepted but never executes | Action state model, listeners plus postconditions, unknown outcome state |
| Save contains stale userdata/object IDs | Never persist them; clear ephemeral state and re-resolve |
| WorldFlow duplicates irreversible effects | Side-effect registry, durable markers, postconditions, saga recovery |
| Later mod silently invalidates assumptions | Stack epoch, dependency graph, semantic fingerprints, adapter quarantine |
| Global scan breaks unknown neutral actors | No heuristic enrollment; exact manifests/registration only |
| SCS migration loses years of special cases | Shadow oracle, provenance taxonomy, family-by-family ledgers |
| Reuse creates attribution/distribution problems | Artifact-level audit, visible credit, packaging allowlist |
| Runtime cost scales with every AI tick | Event/stagger research, dirty state, caching, budget/circuit breaker |
| WorldFlow becomes a second incompatible quest system | Preserve public variables/entry points, legacy handback at every state |
| Scope consumes unbounded human/AI effort | vertical gates, migration economics, IR/tooling before corpus expansion |

## 23. Success criteria

The architecture succeeds when:

- Unknown content continues under legacy scripts without manual support.
- A supported adapter can be disabled independently and immediately restore fallthrough.
- Combat Intent can explain, execute, and verify a fair normal action without disrupting world
  control.
- WorldFlow can recover a durable sequence after every declared interruption boundary.
- Save/load, upgrade, disable, and uninstall have tested outcomes.
- SCS-derived knowledge is preserved with clear provenance and intentional improvements.
- A new adapter can be developed mostly from compact manifests, IR slices, fixtures, and replays.
- Performance and migration cost are measured rather than assumed.
- Release support claims enumerate exact tiers, fingerprints, versions, and untested boundaries.

## 24. Open research questions

These are deliberately unresolved:

- What is the safest production handoff for unmodified SCS installations: same-resref branch
  insertion, sidecar slot, or another generated bridge?
- What execution outcomes can be proven generically, and which require action-specific observers?
- What BCS/DLG subset can be round-tripped semantically without loss?
- Which semantic fingerprint normalization is both stable and conservative?
- How completely can public quest-global readers/writers be discovered across a large stack?
- Which EEex releases should form the initial supported capability profiles?
- What happens when compiled EEex triggers/actions remain but EEex is absent or partially removed?
- Which SCS artifacts can be distributed, adapted, or represented only through locally generated
  manifests?
- Which AoE/projectile geometries can be derived safely, and which require curated metadata?
- Can meaningful movement candidates be generated without pathing loops or choreography conflict?
- How should install-stack epochs be detected without unsafe mid-stack manipulation?
- What is a sustainable per-family/per-encounter migration cost?
- Which first real, low-risk WorldFlow migration provides the best evidence after the synthetic
  laboratory succeeds?

## 25. Evidence baseline consulted for this design

The design is based on read-only inspection of the current BG2:EE/EET environment and verified
project knowledge, including:

- SCS v35.21 mage generation and low-script insertion (`mage/mage_shared.tph`).
- SCS mage priority structure (`mage/ssl/main/dw#mage.ssl`).
- SCS action/prebuff definitions (`caster_shared/caster_definitions.ssl`).
- A representative generated SCS mage script and effective CRE slot stack.
- SCS copyright/reuse statement (`doc/readme-stratagems.html`).
- EEex v0.11 Lua trigger/action, script-level, stored-target, resource, sprite, and persistence
  sources.
- Verified BCS/DLG, cutscene, skip, action-queue, save/load, and SCS-compatibility findings in the
  BG modding knowledge base.
- Existing pure-Lua and synthetic-WeiDU testing patterns in `chriz-bg-rebalance`.

Source inspection is not treated as runtime proof. The research plan requires disposable-engine
evidence for lifecycle, native API, action, persistence, and recovery claims before active control.
