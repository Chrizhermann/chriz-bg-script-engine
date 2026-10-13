# Chriz BG Script Engine — website roadmap snapshot

**Snapshot date:** 2026-09-06

**Canonical source state:** local branch `codex/task1-g0-adrs`, commit `b2b5aaf`

**Public status label:** Research and planned — not released

## Short website description

An experimental compatibility-first scripting platform for an EEex-enabled Baldur's Gate II:
Enhanced Edition research profile. The long-term goal is smarter, more coordinated combat and
safer quest/cutscene scripting without silently taking control away from existing game or mod
scripts.

## Gamer-facing roadmap

| Planned capability | What it should mean for players | Honest current status |
|---|---|---|
| Smarter, encounter-aware combat | Enemies choose legal actions from what they can actually perceive, respect protections and resources, and use normal casting rules rather than hidden instant effects. | **Planned.** Architecture and safety requirements exist; no production combat runtime or playable feature exists. |
| Short-term team coordination | Combatants can avoid wasting the same spell, reserve targets briefly, combine setup and payoff actions, and reconsider when the battlefield changes. | **Planned.** The intent/lease model is designed; simulation and engine implementation have not started. |
| Conservative coexistence with SCS and other mods | Exact, reviewed adapters preserve encounter-specific logic and yield to the installed scripts whenever a resource, owner, or dependency is unknown or changed. | **Charter rules frozen; adapter/runtime work planned.** The `B-` namespace and fail-closed ownership rules passed G0. No in-game compatibility claim has passed. |
| Save-safe quests, dialogue, and cutscenes | Durable story flows recover across save/load, skip routes, interruptions, and partial failures without duplicating rewards or trapping the player. | **Planned.** WorldFlow's state/recovery contract and threat model are documented; no quest has been migrated or run. |
| Reversible installation and isolated testing | Future components install through WeiDU, restore prior files cleanly, and are tested in a resettable laboratory before any support claim. | **Host-side foundation tested; installer/lab planned.** The read-only environment guard and evidence schema are tested. No WeiDU package or disposable game laboratory exists. |

## What exists today

- Tasks 1 and 2 are complete: architecture decisions, the narrowed `B-` namespace contract, the
  initial dependency baseline, Windows host/toolchain contract, read-only path guard, laboratory
  runbook, evidence schema/index, and 31-risk threat model are committed.
- The last recorded verification at `b2b5aaf` was **62 environment-guard tests** and **68 total
  host-side tests**, plus PowerShell, JSON/TOML, line-ending, namespace, and document-structure
  checks.
- Task 4 is **work in progress**: remaining provenance classifications, artifact policy, upstream
  register, fixture allowlist, and positive/negative fixture checks remain to be completed.
- There is **no production EEex runtime, gameplay component, downloadable installer, public release,
  or supported game/mod stack** yet. No G1–G8 runtime/compatibility gate has passed.

## Candidate dependencies — not a support claim

The first research profile is deliberately narrow: BG2:EE `2.6.6.0`, EET `v14.0`, and EEex
`v0.11.0-alpha` with LuaJIT; WeiDU `v251.00` is the intended future installer/compiler. SCS
`v35.21` and Spell Revisions `v4.19` are optional, exact adapter candidates rather than blanket mod
compatibility. The host-tooling profile is Windows x64.

Other game, EEex, EET, SCS, Spell Revisions, operating-system, and install-stack versions remain
unproved or deferred. A version label alone will never activate an adapter.

## Safety and sequencing

- The active game and active saves are not development targets.
- Task 3 (creating a disposable engine laboratory) remains pending and requires separate explicit
  authorization naming an absolute destination.
- The immediate safe roadmap work is Task 4 fixture/provenance governance. Gameplay work remains
  behind later research tasks and G1–G8 gates.

## Website publishing guidance

- Use **Research**, **In development**, or **Planned** badges—not **Available**, **Compatible**, or
  **Download**.
- Present the five capabilities above as goals. Present the host guard/evidence work as development
  infrastructure, not player functionality.
- Do not expose local branch, commit, or filesystem links on the public page. No approved public
  repository URL is recorded yet.

## Internal source links

- [Project overview](../README.md)
- [Architecture design](plans/2026-08-27-script-engine-architecture-design.md)
- [Implementation plan](../archive/2026-10-process/docs/plans/2026-08-27-research-and-vertical-slices.md)
- [Canonical task state](../archive/2026-10-process/docs/plans/2026-08-27-research-and-vertical-slices.md.tasks.json)
- [G0 charter and namespace decision](../archive/2026-10-process/docs/decisions/gates/G0-charter.md)
- [Candidate support baseline](../archive/2026-10-process/docs/research/PREP-01-support-baseline.md)
- [Host/runtime toolchain decision](research/host-runtime-toolchain-decision.md)
- [Failure and compatibility threat model](research/PREP-03-failure-safety-compatibility-threat-model.md)
- [Disposable-lab design-only runbook](research/disposable-lab-runbook.md)
