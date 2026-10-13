# Combat Intent on SCS — design

**Status:** proposed for Christopher's review, 2026-10-14.
**Replaces:** the delivery model of the August plan (stop/go gates, evidence grades,
exact-hash activation, per-spell admission). The August goals stay: smarter, fairer,
more dynamic fights first, scripted encounter phases next, quests (WorldFlow) later.
**Scope:** this is the technical frame. How fights should play (tactics, roles,
personalities, difficulty, scenarios) is designed with Christopher, later also in a
dedicated design session; this document gives that work a base, not the answers.

## What we are building

Enemy groups in Christopher's modded game (EET, SCS, Spell Revisions and the rest of
the CEBG collection) fight together more intelligently and more dynamically, while every
creature keeps the personality SCS gave it. The first release is an optional,
experimental CEBG component.

## Ground rules: this is a mod, not an MMO

- **SCS is the base.** SCS's per-creature setup and rough fight logic already work and
  players love them. We build on that and improve what static scripts cannot do; we don't
  re-derive or replace what works. We reuse SCS ideas, not SCS code or files.
- **Robust to other mods.** The engine reads each creature's and spell's actual data at
  runtime. Something unexpected is skipped or handed back to SCS. It never switches the
  whole feature off. No exact-hash or exact-shape preconditions.
- **Fair.** Enemies act on what they could perceive, at least as fairly as SCS (See and
  Detect, SCS's omniscience options respected). No cheating effects: normal casting,
  casting time, interruption and spell slots.
- **Fail soft.** If the engine has no decision, errors or is switched off, the creature's
  own SCS script simply continues. One switch disables it completely.
- **Never break saves.** Engine state is short-lived and rebuilt after loading; nothing
  session-specific is saved.
- **Judge whole fights.** Fast logic tests on the computer, batched lab fights, then
  community playtesting. Strict checks only where things can really break: crashes,
  saves, stuck creatures.

## How it fits with SCS

SCS's install-time work stays exactly as SCS made it: each creature's spellbook (kit
spell tables and random swaps), level, potions and items, per-creature flags, named
special scripts and encounter scripts. That is where SCS's uniqueness comes from, and
because the engine reads the creature as installed, the uniqueness carries over by
itself, including changes from other mods.

At runtime the work is split:

| SCS keeps | The engine adds |
|---|---|
| Prebuffs and preparation, contingencies and sequencers | The in-combat action choice for mages, priests and fighters, informed by the group |
| Named and encounter specials (Kruin, Sendai, Irenicus, …) | A fight director that makes the group act together |
| Monster specials (golems, dragons, beholders, vampires, …) | Keeping area spells off allies; reacting to how the fight is going |
| Idle, non-hostile, panic and chase behaviour | Potion timing and target choice for fighters |

**Hook.** A small block at the top of a creature's SCS combat script asks the engine for
a decision. If the engine has one, the creature performs it with a normal action; if not,
SCS's own blocks run exactly as before. This handoff already works in the lab
(`docs/research/BCS-01-lua-handoff.md`). Where exactly the block sits relative to SCS's
setup and preparation blocks is the first implementation step: the engine must not
starve SCS's bookkeeping or prebuffs.

## Read SCS's setup or recreate it?

What SCS sets up per creature, at install time:
- spellbooks built from kit spell tables by level, with random picks (the bulk);
- a few hundred hand-made entries for BG2 (kits, levels, spell choices, flags,
  variables, alignments) on top of that;
- potions for listed creatures, and named special scripts.

Decision (proposed):
- **Now: read it.** The engine sees each creature as installed, so SCS's uniqueness
  comes for free and stays correct when other mods change creatures later. Recreating it
  would rebuild SCS's spell tables, random picks and hand-made entries only to arrive
  where SCS already is.
- **Recreate the fight logic fully.** That is where a live engine beats install-time
  scripts, and it is what the engine takes over in combat.
- **Later: improve preparation where a live engine wins** (to design with Christopher):
  - a group shares out its spells, so someone can dispel, nobody triples the same spell
    and the priests split their buffs;
  - enemies who already met the party prepare against it;
  - more variety from one playthrough to the next.
- **Much later, maybe:** once the engine covers everything SCS's mage and priest AI does,
  CEBG could make those SCS components optional: shorter installs and one coherent brain.
  Lab and community results decide.

## Which creatures take part

- **At install time** the component adds the hook to creatures whose scripts are SCS
  mage, priest or general-AI scripts. The SCS script name only helps find them; the patch
  checks the script really looks like SCS output first. A creature that doesn't match
  keeps pure SCS or vanilla behaviour. No exact hashes anywhere.
- **Named SCS creatures** (SCS's own per-creature flags such as `IsKruin`, plus its named
  special scripts) stay pure SCS in the first release and can be enrolled one by one later.
- **Per-creature extras** come from SCS's own override tables in the installed game at
  our install time (for example DoNotPrebuff, NoContingency, NoSequencers, Indiscriminate).
  SCS uses them when it generates a creature's script, so they are not visible at runtime;
  we copy the few that matter into a small data file for the engine. We read SCS's
  installed files; we don't redistribute them. Missing tables just mean no extras.
- **Christopher's switches:** separate on/off choices for mages, priests, fighters and
  monsters, plus a global kill switch.

## The fight director

SCS has shouts and per-creature timers but no group plan. The director is new.

- One per hostile group in an area. It builds a shared picture from what the members can
  perceive or have been told (like SCS's shouts): enemies, their visible protections and
  buffs, who is dangerous, who is disabled; allies' health, disables and needs.
- It suggests rather than commands: focus targets (SCS's target orders as the starting
  point, such as nearest first or preferring strong or weak targets), one disabler per target, one dispeller
  per protection, which healer looks after which ally, which buffer covers whom, fighters
  protecting their casters, and when to fall back.
- Each creature still chooses its own action. The director's plan raises or lowers the
  scores and prevents duplicates such as two mages disabling the same target. It never
  acts by itself.

## How one creature decides

1. **Options from what it actually has:** memorized spells, innate abilities, potions and
   other usable items, melee or ranged attacks, moving or retreating.
2. **Spells judged by what they do:** each spell is classified from its real effects as
   damage, disable, protection removal (dispel or breach), self-protection, buff, healing,
   summon or debuff, with its range and area. Classification reads the installed spells,
   so Spell Revisions and other spell mods are handled. A small override table covers
   spells whose effects are misleading. A spell that can't be classified is ignored.
3. **Scored like SCS would think, then better.** SCS's rough priorities become scoring
   rules. For mages, for example: deal with undead and summons, dispel early when the party
   is buffed, then speed and offence, then disables. Added on top: the current situation
   (seen protections, ally state, range and line of sight, friendly-fire risk), the
   director's plan, and personality and difficulty. SCS's difficulty tiers map to how
   aggressive, quick and clever a creature is. SCS's weighted randomness stays, so fights
   don't play out identically.
4. **Normal actions,** re-checked right before acting. If the action fails or becomes
   pointless, the creature tries again next round or hands back to SCS.

## First milestone: one big mixed fight

- **Lab scenario** (the existing BG2 lab with EET, SCS and Spell Revisions): a party of
  four to six (fighter, cleric, mage, thief, …) against a mixed group of two fighters
  with potions, a priest, a mage and a monster. A second variant has two mages and two
  priests.
- **Batches:** engine on versus pure SCS in the same fights; with and without Spell
  Revisions; one save and load in the middle of a fight.
- **Passes when:**
  - nothing crashes or logs an engine error, and no creature gets stuck;
  - save and load are clean;
  - the logs show real coordination: focus fire, no double disables, priests buffing
    and healing the right ally, fighters drinking potions at sensible moments, mages
    dispelling or breaching when protections are up, no area spells on allies;
  - the fights are at least as hard as pure SCS and more coherent. Christopher judges
    that from a short fight summary or recording.
- **Then** an experimental CEBG component for community playtesting.

## What we keep from the existing work

- **Code:** the kernel (identity, leases, action dispatch and outcome tracking,
  bootstrap); the Combat Intent modules (perception, short memory, candidates, scoring,
  short plans, reservations, which become the director's core, spatial checks, area
  geometry, legality, dispatch); the EEex adapter; the BCS bridge; and the lab and its
  batch runner.
- **Research:** the SCS notes (SCS-01 to SCS-06), the action, EEex and spatial notes are
  our reference.
- **Simplify:** interfaces lose their admission and attestation layers where those add
  nothing.

## Retired

- **Process:** the G0–G8 gates, E0–E5 evidence grading as a blocker, exact-hash
  activation, per-spell admission maps, and the per-family migration and provenance
  ledgers.
- **Tools:** the acquisition and process-screening tooling. It is kept in history and on
  the `wip/` branches.
- **Still in force:** SCS (DavidW) and Spell Revisions (Demivrgvs and G3) get prominent
  credit, and SCS files are not redistributed.

## Order of work after approval

1. **Hook placement:** where the block sits in SCS-generated scripts (lab check), plus the
   installable component skeleton (WeiDU, EEex required, kill switch).
2. **Spell classifier and creature profile reader,** with logic tests.
3. **Fight director and per-creature decisions** for mages, priests and fighters.
4. **The lab fight scenario, batch runner and engine-on versus SCS comparison logs.**
5. **Iterate on fight quality,** then the experimental CEBG component.

## To design with Christopher

Short decisions for the first release:
1. **Monsters:** in the first release, should golems, dragons, beholders and the like
   keep their SCS specials and only join the group plan (suggested), or should the engine
   drive them too?
2. **Named SCS creatures:** stay pure SCS at first (suggested)?
3. **Difficulty:** follow SCS's own difficulty settings (suggested), or a separate slider?
4. **First lab fight:** is there a specific fight or group you'd like to see first?

Bigger design topics, in a dedicated design session:
- what the director should do in typical situations (which threats come first, when a
  group falls back or regroups, how fighters protect casters);
- personalities: how individual creatures differ within SCS's identity;
- group-aware preparation and enemies who remember the party (see above);
- later, scripted encounter phases.
