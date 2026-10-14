# Chriz BG Script Engine

An EEex/Lua engine that makes enemy groups in Baldur's Gate II:EE fight together more
intelligently, on top of Sword Coast Stratagems (SCS). Every creature keeps the identity SCS gave
it. The engine adds what install-time scripts can't: a group that acts together, reactions to how
the fight is going, and area spells kept off allies. Scripted encounter phases come next and
quests (WorldFlow) later. It is planned as an optional, experimental component of Chriz Easy BG
(CEBG).

## Status

Private, in development, nothing released. In a disposable lab today:
- an installable WeiDU component (needs EEex) that hooks SCS's mage, priest and general-AI
  scripts just before SCS's per-round action choice, keeps SCS's bookkeeping and special
  abilities running, and has a global switch plus one per creature family;
- with the hook installed, real SCS creatures fight as before while the engine declines, and
  hand their rounds over when it claims them;
- a small runtime kernel and the BCS→Lua handoff; two lab mages casting Magic Missile through
  the engine, with interruption, switching off and loading a save checked.

Short plans, group reservations and spatial checks pass host tests. A test priest's Turn Undead
choices were compared with SCS's own in two lab runs.

Next: classify spells by their effects, read creature profiles, a group fight director, and the
first big mixed lab fight.

## Start here

- [Current design](docs/plans/2026-10-14-combat-intent-on-scs.md)
- [What we learned](docs/learned.md)
- [Working agreements](AGENTS.md)
- [August architecture](docs/plans/2026-08-27-script-engine-architecture-design.md): goals and
  module structure. Its delivery process is retired.
- [Research notes](docs/research/)
- [Archived process](archive/2026-10-process/README.md)

## Credits

Sword Coast Stratagems was created by David Wallace (DavidW). Spell Revisions was created by
Demivrgvs and contributors at Gibberlings Three. This project builds on their work as a source of
tactical knowledge; it does not copy or redistribute SCS files.

## Naming

The combat module is **Combat Intent**. The project deliberately does not use **Tactics** as a
name, to avoid confusion with existing Infinity Engine mods.
