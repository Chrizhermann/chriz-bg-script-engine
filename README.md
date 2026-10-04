# Chriz BG Script Engine

`chriz-bg-script-engine` is a research-first, compatibility-first scripting platform for
Baldur's Gate Enhanced Edition games running EEex.

The project has two policy domains:

- **Combat Intent** — SCS-inspired combat reasoning with explicit perception, utility,
  short intentions, group coordination, spatial reasoning, and execution feedback.
- **WorldFlow** — durable, idempotent state machines for quests, dialogue orchestration,
  cutscenes, encounter phases, rewards, and recovery.

Both domains share a small runtime kernel for engine capability detection, resource identity,
ownership, persistence, diagnostics, and conservative fallback.

> **Compatibility prime directive:** unknown, modified, stale, or ambiguous content remains
> under its original BCS/DLG ownership. A failed compatibility check disables only the affected
> adapter; it never triggers a global takeover.

## Status

The repository has a tested current-stack kernel and a narrowed G5 Combat Intent pilot:
two disposable-lab mages selected and performed ordinary Magic Missile casts through the new
system, with interruption, disable/fallthrough and load invalidation checked separately.
Short plans, group reservations and conservative spatial reasoning are host-tested;
native movement/AoE activation is not yet admitted. A second, priest Turn shadow family
has source and host evidence but still needs its disposable-engine comparison batch.
See [active results](docs/research/active-combat-soak.md) and the
[priest checkpoint](docs/research/priest-turn-shadow-results.md).
It has no production release or general support claim. The active game and playthrough remain
outside testing; further engine validation uses synthetic fixtures or the approved disposable lab.

Start with:

- [`docs/plans/2026-08-27-script-engine-architecture-design.md`](docs/plans/2026-08-27-script-engine-architecture-design.md)
  — approved architecture, compatibility model, risks, gates, and vertical slices.
- [`docs/plans/2026-08-27-research-and-vertical-slices.md`](docs/plans/2026-08-27-research-and-vertical-slices.md)
  — 41 dependency-ordered tasks across E0–E11, with G0–G8 stop/go gates.
- [`docs/research/research-backlog.md`](docs/research/research-backlog.md) — 64 issue-ready research
  spikes with methods, evidence requirements, dependencies, deliverables, and exit criteria.
- [`docs/compatibility/acceptance-matrix.md`](docs/compatibility/acceptance-matrix.md) — normative
  C0–C4 ownership rules and 84 stable compatibility cases.
- [`docs/provenance/artifact-policy.md`](docs/provenance/artifact-policy.md) — fixture admission,
  upstream attribution and reuse holds, with an exact-byte host-side checker and reproduction steps.

## Relationship to SCS

Sword Coast Stratagems is a major source of tactical knowledge and inspiration. The project aims
to preserve and extend its accumulated encounter and combat expertise while replacing brittle
runtime machinery gradually and measurably. It is not a fork of SCS and will not silently copy or
redistribute SCS artifacts. Every reused or translated behavior family needs an artifact-level
provenance and licensing decision.

Sword Coast Stratagems was created by David Wallace (`DavidW`). Spell Revisions was created by
Demivrgvs and contributors at Gibberlings Three. Their work will be credited prominently wherever
it informs an adapter, behavior family, fixture, or derived implementation.

## Naming

The combat module is **Combat Intent**. The project deliberately does not use **Tactics** as a
module or product name, to avoid confusion with existing Infinity Engine mods.

## Development posture

- Evidence before expansion.
- Explicit ownership before action.
- Normal engine casting and action semantics.
- Legacy fallthrough before uncertain enhancement.
- Pure-policy simulation before native integration.
- Disposable-game proof before compatibility claims.
- Narrow supported corpora before broad conversion.

Licensing, packaging, supported EEex versions, and supported install stacks remain open research
decisions. No public release should be inferred from this repository's existence.
