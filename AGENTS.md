# Chriz BG Script Engine — Working Agreements

## User priority reset — 2026-09-27

This is a hobby game-mod project. Preserve the full intended feature scope and good code
quality; apply a pragmatic "good enough" standard to supporting tooling, process and setup.
Do not silently cut features, but deliver them in useful, reviewable increments.
The user reconfirmed the original architecture and feature plan after this reset. Simplify
supporting process, not Combat Intent, WorldFlow, compatibility behavior or SCS migration scope.

- Prioritize a usable disposable lab and actual script/AI migration over infrastructure.
- Use or take inspiration from the item-randomizer lab. Prefer existing tools and simple
  setup/reset instructions to custom copying, process-inspection or safety frameworks.
- A failed or inconsistent disposable lab can be rebuilt. Keep the active game and its saves
  untouched; do not turn lab reliability into a general-purpose backup/transaction system.
- Test real feature behavior and relevant regressions. Use representative script families and
  gameplay examples; do not require every encounter or hypothetical setup failure to be tested.
- Add tooling only for a concrete development/testing need. Keep documentation sufficient to
  reproduce useful work, without creating a parallel paperwork project.
- The expanded offline-acquisition packets A-E are no longer prerequisites for making the lab.
  Do not resume their process-provider/copy-framework development from historical checkpoints.
- Preserve creative/gameplay choices for the user and existing no-game-launch/UI-control limits
  until changed explicitly. Report what has actually been tested; do not inflate support claims.

This direction supersedes conflicting setup/process requirements in the older plan and research
memos. It does not authorize writes to the active game, shared saves, or unrelated projects.

## Hidden-lab automation clarification — 2026-09-28

The user explicitly permits the item-randomizer approach: scripted game-menu actions, including
save/load, inside the separate hidden BGSE lab. "No computer control" means no takeover of the
visible desktop, OS mouse/keyboard injection, desktop switching, or unrelated apps. It does not
forbid the game's internal queued button events. Reuse the existing method; a manual user save
is not a prerequisite. Coordinate with other game-testing tasks, preserve the original game and
all personal saves, clean up our temporary additions, and retain G0–G8 and user-owned design choices.

## Representative batch testing — 2026-09-30

The user wants substantial logged gameplay/action sequences, not a new launch or report per
spell. Keep one hidden lab session across a useful batch and reload our fixture between cases.
Collect relevant actions, state changes and postconditions for analysis after the batch;
missing observations remain unknown. Use isolated probes to diagnose actual failures or gaps,
not to enumerate every spell/encounter. Restart only for required disk changes, failure or end
of batch. Preserve feature scope, active-game isolation, user-owned design choices and G0-G8.

## Deliverable-sized implementation batches — 2026-10-04

The next product target is a representative multi-behavior mage in the existing lab, not
another isolated spell demonstration. Implement independent pieces concurrently behind
lead-owned interfaces; run related host checks together and use substantial logged engine
scenarios with explicit postconditions. Use small reproductions to diagnose observed failures.
Review a coherent change/batch once, then recheck affected fixes rather than recursively reviewing
reviews. Report working behavior and remaining defects, not each internal step. This changes
execution cadence, not gameplay design, feature scope, evidence claims, or G0–G8 approval.

## Project charter

This repository develops a compatibility-first EEex scripting platform with two policy domains:

- **Combat Intent** for combat perception, decision-making, coordination, and verified actions.
- **WorldFlow** for durable quest, dialogue, cutscene, encounter, and reward state machines.

The domains share infrastructure but not policy or state semantics. Combat state is mostly
ephemeral; WorldFlow state is durable, versioned, and recoverable.

## Prime compatibility invariant

Unknown, modified, stale, or ambiguous content remains under its original BCS/DLG ownership.
Adapters claim only explicitly identified resources, decisions, actors, or transitions. A failed
check disables only the affected adapter and yields to legacy behavior.

Never replace this invariant with a best-effort heuristic, broad creature scan, permissive
fingerprint, or global fallback mode.

## Current phase

The current phase is research and architecture. Do not create production runtime code until the
corresponding research gate and implementation task are approved. A document describing an API is
not evidence that the API is safe in the engine.

The canonical architecture is:

- `docs/plans/2026-08-27-script-engine-architecture-design.md`
- `docs/plans/2026-08-27-research-and-vertical-slices.md`
- `docs/research/research-backlog.md`
- `docs/compatibility/acceptance-matrix.md`

Future implementation plans belong under `docs/plans/`; verified research memos under
`docs/research/`; compatibility manifests and acceptance matrices under `docs/compatibility/`.

## Safety and environments

- Never write to, install into, or test against the user's active game or active playthrough
  without explicit permission in that conversation.
- Treat installed games used for source inspection as read-only unless they were explicitly
  designated disposable.
- Use synthetic fixtures, host-side simulation, and disposable game copies for destructive or
  stateful validation.
- Never claim that an EEex action executed because it was accepted or queued. Observe engine
  progress and verify an independent postcondition.
- Never persist EEex userdata, raw object IDs, action-queue ownership, or other session-local
  handles. Persist stable identities and re-resolve them.
- A native EEex crash is a failed experiment. Record the exact capability and call shape; do not
  retry blindly.

## Research evidence

Classify each material claim by the applicable evidence layer or combination of layers. Evidence
grades identify distinct proof environments, not substitutable confidence levels. A higher-numbered
layer does not discharge a required lower-layer proof; record combinations such as E3+E4 when both
installer/restoration and runtime behavior matter.

1. **E0 — claim/documentation input:** upstream documentation, comments, forum statements,
   unpinned source, or an unverified design assumption inspected.
2. **E1 — pinned static evidence:** revision-pinned source inspection, effective resource,
   decompile, binary, install output, or provenance chain inspected reproducibly.
3. **E2 — deterministic host simulation:** pure policy, parser, replay, property-test, or state
   machine behavior reproduced outside the game process.
4. **E3 — synthetic-game integration:** real WeiDU operates on a minimal fake game to prove
   compilation, patching, packaging and publication-allowlist enforcement, reinstall, and
   restoration without launching a game executable.
5. **E4 — disposable-engine proof:** behavior is observed in an isolated full BG2:EE plus EEex
   environment, including runtime/save behavior where relevant.
6. **E5 — supported-corpus soak:** the declared support matrix is exercised repeatedly, including
   compatibility variants, save/load, performance stress, and failure paths.

Do not promote E0/E1 conclusions to runtime guarantees. Every research memo must state the
question, environment, exact versions/fingerprints, method, observations, counterevidence,
artifacts, evidence grade, residual uncertainty, and next decision.

## Engineering rules

- Keep EEex/native calls behind a narrow, versioned engine boundary. Policy modules consume
  scalar snapshots and issue typed requests.
- Use normal engine actions when aura, casting time, interruption, inventory, spell expenditure,
  or target legality matters. Direct effect application is not a substitute for fair casting.
- Revalidate immediately before action dispatch; execution-time state may differ from
  decision-time state.
- Model accepted, started, completed, failed, interrupted, invalidated, and unknown outcomes
  separately.
- Combat ownership is a short lease, normally one ordinary action. WorldFlow ownership is a
  narrow durable transition claim with postconditions and recovery.
- Preserve public quest variables, dialogue entry points, creature death variables, and expected
  resource identities when migrating supported content unless a reviewed adapter says otherwise.
- Use stable, seeded randomness in simulations. Record all decision inputs, candidate scores,
  exclusions, tie-breaking, selected intent, action result, and fallback reason.
- Write failing tests before implementation for each approved production task.
- Investigate every failing test. Never weaken a safety assertion merely to pass a gate.
- No adapter may activate without static eligibility and runtime ownership checks.
- No unsupported resource may be enrolled by naming convention alone.

## Compatibility and install order

- WeiDU remains the install-time system of record for patching, backups, uninstall order, and
  inter-mod cooperation.
- Inventory effective resources after the final intended install order.
- Start activation with exact hashes across declared dependencies/control closure. Semantic
  fingerprints may replace them only after the relevant loss-aware IR and counterexample suite are
  proved; unknown syntax remains opaque.
- A later stack change invalidates affected claims in both domains. Reactivation requires a
  refreshed dependency/external-control scan; WorldFlow additionally requires refreshed
  public-state reverse references.
- Preserve legacy BCS/DLG artifacts so disabling or quarantining an adapter restores ordinary
  fallthrough.
- Support claims name exact content families, adapter versions, capability profiles, and tested
  install stacks. “Compatible with mods” is not a sufficient claim.

## SCS and upstream provenance

SCS is a first-class knowledge source, not disposable scaffolding. Preserve its tactical intent,
encounter exceptions, fairness rules, and compatibility learning where evidence supports them.

For each SCS-derived family, maintain a migration ledger containing upstream version/component,
source artifacts, effective generated artifacts, behavior summary, preserved rules, intentional
changes, omitted rules, tests, attribution, and redistribution decision.

Do not infer stable identity from generated `dw#*` resrefs. Do not redistribute source, generated
BCS, fixtures, prose, or data until its license/provenance category is documented. Credit SCS
(DavidW), Spell Revisions (Demivrgvs/G3), and other upstream authors prominently and specifically.

## Scope control and delegation

Good bounded tasks include one evidence spike, parser subset, pure policy module, adapter family,
simulation scenario, linter rule, compatibility cell, or WorldFlow transition. Avoid tasks such as
“rewrite mage AI,” “convert every quest,” or “support arbitrary mod stacks.”

The integration owner retains ownership/fallback schemas, shared public interfaces, disposable
engine execution, release claims, and active-game decisions. Freeze schemas at milestone gates
before parallel implementation.

## Git and publication

- Keep commits narrow and evidence-backed.
- Do not add a GitHub remote, publish the repository, release artifacts, or contact upstream
  authors unless explicitly authorized.
- Do not commit installed-game files, copyrighted upstream artifacts, generated effective BCS/DLG,
  saves, logs containing personal paths, credentials, or authentication state.
