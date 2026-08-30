# AoE Historical Prebuff Delivery — Design

**Status:** Approved feature direction; architecture exception and implementation remain gated

**Date:** 2026-08-30

**Module:** Combat Intent / SCS adapter

**Evidence:** `docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`

## 1. Summary

When a supported SCS mage or priest historically prebuffs with an area spell, the engine should
perform one authentic cast of the exact installed prebuff resource. The spell's native projectile
and effect graph select nearby recipients. The adapter must not enumerate allies and apply the
spell or its effects individually.

This operation is a narrowly typed simulation of earlier preparation, not a general Combat Intent
casting shortcut. The current architecture reserves forced casts for scripted semantics and gives
Combat Intent a one-normal-action lease. Therefore adapter-owned execution is not authorized by
the existing Combat Intent dispatch contract; it requires an explicit integration-owner decision
for a narrow supported forced-behavior exception after the baseline and G5 proofs. Live combat
casts continue to use ordinary engine actions with normal aura, casting time, interruption, target
legality, and resource expenditure.

The first implementation decision is deliberately conditional: prove the unmodified SCS baseline
in a disposable engine. If SCS already buffs eligible allies, add preservation tests and no new
delivery code. Build adapter execution only when later migration work actually takes ownership of
the prebuff family.

## 2. Goals

- Preserve area delivery to every actor the exact installed spell/projectile considers eligible.
- Preserve caster identity, caster-level header selection, protections, stacking, saves/MR,
  nested spells, timing, probability behavior, and installed compatibility changes.
- Spend exactly one corresponding memorized spell, independent of recipient count.
- Preserve SCS short/long preparation fairness and one-shot behavior.
- Distinguish accepted, started, delivered, accounted, interrupted, failed, and unknown outcomes.
- Yield completely to SCS/legacy behavior on unknown content, stale fingerprints, ownership
  conflict, missing capability, or ambiguous execution.
- Avoid interfering with current G0 schemas and the first single-target active-action slice.
- Avoid creating a production exception if unmodified SCS already satisfies the requirement.

## 3. Non-goals

- A generic “apply this buff to every nearby ally” API.
- Aura cleansing, Improved Alacrity, or casting-time mutation for live Combat Intent actions.
- Retrospective propagation to allies that enter the area after the historical cast resolves.
- Automatic enrollment based on class, spell name, `dw#*` resref, or `prebuff.2da` membership.
- Flattening sequencers, contingencies, spell triggers, or summon/clone behavior into ordinary
  prebuff casts.
- Defining shared capability, ownership, action-attempt, manifest, geometry, or persistence schemas
  before their integration-owner tasks freeze them.
- Runtime changes before the corresponding research and program gates pass.

## 4. Approaches considered

### 4.1 Recommended: one native historical cast

Preserve SCS's model: force-cast the exact effective prebuff clone at the caster and separately
consume one memorized original spell. The native projectile decides recipients.

Advantages:

- preserves effective installed SPL and projectile semantics;
- preserves caster-level ability selection and nested delivery;
- performs one cast and one resource debit regardless of recipient count;
- avoids inventing a new ally definition;
- matches SCS's historical-preparation representation;
- requires no temporary caster-wide state.

Risk: the cast and resource debit are not atomic. The action observer must model and verify both
postconditions independently.

### 4.2 Rejected: temporary aura cleansing plus a zero-time normal cast

Temporary opcode 188/189-style state applies to the actor, not one queued action. Because EEex
queues actions for later engine processing, cleanup can occur too early or leak across another
action, queue clearing, save/load, death, dispel, or Project Image locking. A generated zero-time
clone plus manual accounting eventually recreates the recommended forced-cast path with more
failure surfaces.

For a live combat cast, the correct behavior is an ordinary `SpellRES`, not an artificially
cleansed version.

### 4.3 Rejected: enumerate allies and apply spell/effects per target

`ApplySpellRES` discards the original projectile and uses the lowest casting-level ability.
Distance enumeration cannot reproduce projectile radius, filters, obstructions, delayed or
secondary delivery, probability granularity, or mod-installed changes. Direct effect injection
would require a partial reimplementation of SPL resolution and could mutate unowned actors.

A spell-family-specific exception may be researched only if a concrete supported spell cannot be
delivered safely through one authentic cast. There is no generic fan-out fallback.

## 5. Architecture placement

This feature belongs to the Combat Intent SCS prebuff family as a historical-preparation operation.
It is not WorldFlow, generic squad coordination, or the first active ordinary-action slice. If
execution is eventually required, its best architectural placement is a narrowly reviewed SCS
adapter as a proposed ownership-hierarchy level 3 exception (“explicit forced behavior defined by
a supported encounter adapter”), immediately at the exact prebuff handoff. That placement is a
proposal, not a decision made by this feature document.

Roadmap placement:

1. SCS corpus and migration-ledger work records the concrete generated prebuff action and this
   intentional preservation/change decision.
2. SCS-04 defines historical preparation, fairness inputs, accounting, one-shot behavior,
   existing-effect behavior, contingencies, and exceptions.
3. Combat shadow tasks model eligibility and expected delivery without mutation.
4. Task 9/G5 action-observer work first proves ordinary-action outcomes and queue interruption
   behavior. It is a prerequisite, not evidence or authorization for this compound forced action.
5. Spatial research proves the effective projectile's predicted recipient set.
6. Active ownership waits until the relevant G5 containment and adapter gates pass; AoE remains
   outside the deliberately simpler first active action.
7. Only after the baseline and geometry proof may the integration owner decide whether to approve
   a dedicated post-G5 forced historical-preparation operation with its own disposable-engine
   action-family evidence.

The integration owner retains all public schemas, ownership/fallback contracts, disposable-engine
execution, and release/support claims.

## 6. Eligibility and fail-closed activation

A historical prebuff candidate is eligible only when all of these are true:

- The actor belongs to an explicitly supported SCS adapter family.
- Static eligibility identifies the exact effective generated action, original accounting spell,
  prebuff clone, and dependency/control closure.
- Required exact hashes or an already-approved semantic fingerprint match the current stack epoch.
- The reviewed SCS preparation handoff is active and no higher encounter/world owner suppresses it.
- The cast is classified as historical preparation, not live reactive combat casting.
- The caster has the original memorized spell and satisfies the original preparation gate.
- The engine/capability profile supports the exact typed action and required observation.
- No Project Image owner lock, actor replacement, charm/control change, death/despawn, area
  discontinuity, or competing lease invalidates dispatch.
- The operation is not a sequencer, contingency, trigger, unsupported item/innate accounting case,
  or unknown generated resource.

Failure of any check leaves the original SCS/legacy path executable. Naming convention, spell
name, class, and clone-table membership are never sufficient enrollment criteria.

## 7. Conceptual request

If the baseline demonstrates that adapter-owned execution is necessary and the integration owner
approves the architecture exception, the engine boundary may expose a typed operation
conceptually equivalent to:

```text
HistoricalPrebuffCast
  enrolled actor identity
  exact effective prebuff resource
  exact original accounting spell
  reviewed preparation-family identity
  stack epoch / compatibility claim
  correlation identity
```

This is a conceptual contract, not a frozen public schema. The integration-owned manifest,
identity, ownership, capability, geometry, and action-attempt tasks determine its actual fields.

It must not expose a generic public `ForceCast` or `ApplyToNearbyAllies` escape hatch.

## 8. Data and control flow

1. Observe the concrete SCS prebuff decision and revalidate the actor, ownership, spell, and stack.
2. If SCS still owns the family, remain shadow-only and observe the unmodified legacy response.
3. If a future adapter with an explicitly approved ownership-hierarchy level 3 exception owns this
   exact leaf, acquire its dedicated bounded authority and dispatch one compound
   historical-preparation attempt preserving SCS's cast-then-debit response shape. Do not reuse
   the ordinary one-action Combat Intent lease.
4. Force-cast the exact installed prebuff clone at the enrolled caster.
5. Let the native projectile/effect graph select recipients. Predicted recipient sets are
   diagnostic expectations, never an instruction to apply effects manually.
6. Debit exactly one memorized original spell.
7. Observe engine progress and independent cast-delivery and accounting postconditions.
8. Classify the outcome, release the dedicated authority, and never retry an ambiguous compound
   attempt for that actor/preparation occurrence.
9. Block and yield the affected actor/occurrence after ambiguity. Quarantine the adapter claim only
   on a contract/invariant violation or a repeated/systemic fault; legacy ownership remains the
   default for later decisions.

Actors entering range after resolution receive nothing. The adapter does not persist recipients,
sprite userdata, object IDs, or queue ownership.

## 9. Outcome and accounting semantics

The operation has at least two independently observable dimensions. The labels below describe
required observations, not a replacement for the integration owner's eventual attempt schema:

| Delivery observation | Accounting observation | Classification |
|---|---|---|
| Trusted cast/projectile execution postcondition observed | One original copy spent | Completed |
| Delivery observed | Debit absent or ambiguous | Accounting failure or unknown; block occurrence, no retry |
| Delivery absent/failed | One original copy spent | Debit-only failure; block occurrence, no retry |
| Delivery absent after proven queue clearing | Debit absent | Cleared/interrupted; yield |
| Either dimension cannot be established | Any | Outcome unknown; block conflicting retry and yield |

Per-recipient observations may distinguish applied, already present, protected/immune, left range,
invalidated, or unknown. “Not applied” is not automatically a cast failure because the effective
spell may legitimately reject a recipient.

The adapter must not compensate a partial result by applying missing effects, refunding or
removing spells heuristically, or repeating the force-cast. After save/load or an area/lifecycle
discontinuity, retry remains forbidden unless stable one-shot and accounting evidence proves that
no earlier side effect occurred; otherwise the family stays shadow-only and yields. Any future
recovery path requires a separately proven, spell-family-specific design.

## 10. Compatibility behavior

- Use concrete generated actions and effective resources, never stable assumptions about `dw#*`.
- Resolve Spell Revisions and other installed changes from effective resources and declared
  dependency closure.
- Preserve casting features, ability effects, child spells, source identity, projectile closure,
  anti-stacking resources, and presentation changes made by SCS's prebuff clone.
- Treat marker states as fast negatives only; confirm positive active-buff observations against
  concrete source/marker effects where available.
- A changed projectile, target mode, ability set, child-spell closure, accounting spell, or
  generated action invalidates the claim unless its semantic fingerprint was separately proved.
- SCS absent, unsupported family, missing generated mapping, or source/generated discrepancy means
  no claim.

## 11. Testing and evidence progression

### Static and host-side evidence

- Preserve the preliminary E0/E1 source and artifact ledger in the related research memo. It is
  pre-Task-6 evidence, closes no SCS-04 item or program gate, and must be canonicalized after Tasks
  4 and 5. Revisit its temporary taxonomy note after Task 1 merges.
- Add pure tests only after the integration owner freezes the manifest and request schemas.
- Host-side cases cover exact-hash eligibility, dependency drift, one-debit invariant, outcome
  classification, retry suppression, and unknown fallback.
- Synthetic installer tests may later prove packaging, compilation, and byte-exact uninstall, but
  cannot prove projectile delivery or EEex lifecycle behavior.

### Disposable-engine proof

This work requires Task 3's separately authorized, named, isolated, and reset-proven disposable
lab. Once that prerequisite is satisfied, start by testing unmodified SCS before adapter
execution:

- caster plus eligible ally inside radius;
- eligible ally just outside radius;
- hostile, neutral, charmed actor, and summon;
- already-buffed, immune/protected, dead, despawned, or moving actor;
- representative Haste-like, self-centered group, and nested-spell shapes;
- vanilla, SR, and SCS+SR effective resources;
- queue clearing, caster death, area transition, save/load, and Project Image owner lock;
- effect source/caster level and exactly-one memorized-spell debit;
- independent verification after engine ticks, not queue acceptance.

If the baseline passes, write acceptance fixtures that ensure observation/migration never regresses
it. If it fails, record the exact action/resource/projectile shape and diagnose before authorizing
any exception.

### Supported-corpus evidence

Broader claims require repeated supported-stack scenarios, save/load cycles, failure injection,
performance measurement, and declared soak coverage. One passing Haste case is not a generic AoE
support claim.

## 12. Decision outcomes

The next gate produces one of three outcomes:

1. **Baseline proven:** SCS already buffs eligible allies. Add no standalone corrective delivery
   code. A later deliberate family migration may reproduce the proven behavior only under its own
   architecture and activation gate.
2. **Concrete defect isolated:** one exact supported generated action or effective projectile fails.
   Research a fingerprinted spell-family exception without introducing generic fan-out.
3. **Observation remains ambiguous:** leave the family under SCS/legacy ownership and keep the
   adapter shadow-only.

This design intentionally makes “no production code required” a successful result.

## 13. Deferred questions

These are research questions, not unresolved product-design choices:

- Which installed prebuff families actually survive generation into concrete actor scripts?
- Which projectile flags control allegiance, radius, obstructions, deflection, and secondary
  delivery for each pilot spell?
- Which observations reliably prove delivery completion and one-spell debit on the supported EEex
  profile?
- Can the compound response be correlated without adding a fragile Lua continuation?
- Which exact effect/source identities distinguish applied, blocked, already-present, and unknown
  recipient outcomes?
- Does save/load ever serialize or replay either half of the compound response?

Until evidence answers them, the adapter does not claim the decision.
