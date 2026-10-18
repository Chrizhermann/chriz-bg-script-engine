# Combat Intent on SCS — design

**Status:** proposed for Christopher's review, 2026-10-14. His answers to the
first-release questions are recorded under "To design with Christopher". Step 1 (hook
placement and the component skeleton) is done; see "Step 1 result". Christopher reviewed it
the same day (answers 5–8 below). The monster scripts are hooked too (see "Monster hook
result"); step 2 is under way.
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
| Prebuffs and preparation, contingencies and sequencers | The in-combat action choice for mages, priests, fighters and monsters, informed by the group |
| The special moves of named and encounter creatures (Kruin, Sendai, Irenicus, …) | A fight director that makes the group act together, named creatures included |
| Monster specials (golems, dragons, beholders, vampires, …) | Keeping area spells off allies; reacting to how the fight is going |
| Idle, non-hostile, panic and chase behaviour | Potion timing and target choice for fighters |

Christopher decided on 2026-10-14 that the engine drives monsters and named creatures from
the first release; their SCS specials stay (see "To design with Christopher").

**Hook.** A small block in a creature's SCS script asks the engine for a decision. If the
engine has one, the creature performs it with a normal action; if not, SCS's own blocks
run exactly as before (`docs/research/BCS-01-lua-handoff.md`). The block sits just before
SCS's per-round action choice, below SCS's setup, prebuffs and preparation; SCS
bookkeeping and specials from further down are copied above it (see "Step 1 result").

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
  mage, priest, general-AI or monster scripts. The SCS script name only helps find them;
  the patch checks the script really looks like SCS output first. A creature that doesn't
  match keeps pure SCS or vanilla behaviour. No exact hashes anywhere.
- **Named SCS creatures** (SCS's own per-creature flags such as `IsKruin`, plus its named
  special scripts) take part from the first release (Christopher, 2026-10-14). Their
  special moves stay SCS's; the engine takes over the rest of their fight where it can.
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

- **Lab scenario** (the existing BG2 lab with EET, SCS and Spell Revisions, on Insane): a party of
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
- **Tools:** the acquisition and process-screening tooling, the exact-hash inventory, and the
  G0 validators. All of it, with the retired docs and their tests, is in
  `archive/2026-10-process/`; older states are also on the `wip/` branches.
- **Still in force:** SCS (DavidW) and Spell Revisions (Demivrgvs and G3) get prominent
  credit, and SCS files are not redistributed.

## Order of work after approval

1. **Hook placement:** where the block sits in SCS-generated scripts (lab check), plus the
   installable component skeleton (WeiDU, EEex required, kill switch). **Done 2026-10-14.**
2. **Spell classifier and creature profile reader,** with logic tests. They also cover
   named specials that are spellbook entries and abilities used without a spellbook check
   (answers 5 and 6). **The 166 monster-only SCS scripts get the hook** (answer 7; done
   2026-10-14, see "Monster hook result"). **The spell classifier works on the host**
   (2026-10-14, [SPELLS-01](../research/SPELLS-01-spell-classifier.md)); the in-game reader
   and the creature profile work in the lab game (2026-10-15). **Done 2026-10-15,** see
   "Step 2 lab batch".
3. **Fight director and per-creature decisions** for mages, priests, fighters and monsters.
   **First slice in the lab 2026-10-18** (an advisor on SCS's own casts: shared focus, one
   disabler per target), see "Step 3, first slice". **Second slice:** the engine's own
   attack spells and targets for mages and priests, taking the round (answer B), with
   per-creature profiles; see "Step 3, second slice". Then defences, dispels and protection
   removal, healing and buffs, then fighters and monsters with items, potions and movement,
   until the whole framework stands. Christopher designs the personalities on top of it.
4. **The lab fight scenario, batch runner and engine-on versus SCS comparison logs,** on
   Insane (answer 8), with a run without the hook to time SCS against.
5. **Iterate on fight quality,** then the experimental CEBG component.

## Step 1 result: hook placement (2026-10-14)

**Where the hook sits.** The installer recognises SCS-generated scripts by SCS's own round
timer (`castspell`) and difficulty settings (`DMWW_…`), never by name or hash. It puts the
hook directly before the first block of SCS's per-round action choice: the first block that
checks the round timer, skipping SCS's first-round preparation and the ranged fighters'
retarget block. Everything above stays SCS's and runs first: setup, rest and alert state,
prebuffs, contingencies, the first-round sequencer or protection, cloud escape, chasing and
the non-hostile guards.

**Guarded copies.** A few SCS blocks below that point must keep running while the engine
drives the creature:
- the bookkeeping that keeps Melf's Minute Meteors, Energy Blades and Star Blades working
  (item swaps and charges);
- abilities cast without a spellbook check (golem haste, drake breath, a hag's or an
  elemental's powers), with the target-picking blocks they rely on.

The installer copies these above the hook, each with the engine's claim as its first
condition, and leaves the originals where they are. When the engine declines or is switched
off, the copies don't fire and SCS's script runs in its exact original order. When the engine
takes the round, the copies keep SCS's bookkeeping and specials alive.

**In the lab game** (EET, SCS, Spell Revisions and the CEBG collection): 1,028 SCS scripts
hooked (585 mage, 307 priest, 136 general AI) with 799 copied blocks; 2 scripts without a
round timer left as they are; every other file unchanged. A Python version of the rule
(`tools/hook_rule.py`) produces the same scripts block for block. The install takes about
4 minutes; decompiling and recompiling SCS's scripts is most of it, and that round trip on
its own changes no byte.

**Lab check:** two level-18 mages, a level-18 priest, a melee and a ranged fighter and a
clay golem, all installed SCS creatures, against one PC kept alive; one fight per case from
the same save.
- *Engine present but declining:* SCS ran as before: prebuffs (Stoneskin, Mind Blank), the
  first-round sequencer, a spell most rounds, golem haste every three rounds, fighters
  attacking. Each creature's hook was asked 30–108 times a minute and declined; no errors.
- *Engine holding every round:* prebuffs and the first-round sequencer above the hook still
  ran; round casts and attacks stopped; the golem's copied haste still fired every three
  rounds; a test response on the priest ran once.
- *Switches:* switching the fighter family off mid-fight gave the fighters and the golem back
  to SCS at once; the global switch then gave back the mages and the priest. The Baldur.lua
  switch writes and reads back.
- *Bookkeeping:* with the engine holding, a mage given the Energy Blades item ran SCS's
  copied bookkeeping twice: the item was swapped for SCS's helper item and the charge counter
  set, as SCS's own block does. It happened right after the mage's 24-second Time Stop cast;
  responses chosen during a running cast wait for it, with or without the engine.

**Not hooked in step 1:** 166 SCS monster scripts with no mage, priest or general-AI part
(dragons, beholders, demons, Bodhi, Sarevok, Melissan, …). Christopher (2026-10-14): hook
them now (answer 7). Done the same day; see "Monster hook result".

**Found on the way:** an SCS mage that stays invisible re-applies its invisibility animation
on every script pass; the priest version checks whether it already did. Held for a minute,
one mage's effect list grew from 123 to 467 entries. The hook doesn't cause this, but the
engine must not keep an invisible mage waiting. Also, the lab ran at difficulty 2 of 5 (SCS's
IMPROVED), where the general AI destroys a fighter's potions on its first pass. From now on
lab fights run on Insane (answer 8), where SCS keeps them.

**What the engine must do when it acts** (for step 3): set SCS's round timer and hold while
its own action runs; set `firedsequencer` when it fires a sequencer; keep SCS's limit of
three level-9 spells per mage (`l9_mage_spells`); keep SCS's group flags (Malison, time-stop
recast, curing blindness, the beholder flags); decline when the creature perceives no enemy,
so SCS's chase and closedown run.

## Monster hook result (2026-10-14)

Details in [HOOK-02](../research/HOOK-02-monster-scripts-and-script-slots.md).
- **Which scripts:** 123 of the 166 carry another SCS difficulty setting (fiend, dragon,
  vampire, genie, spider, Durlag, Ascension, illithid, Bodhi, beholder, spirit troll); 120
  of them now get the hook as the family `monster`. The three that never check the round
  timer and the 43 without an SCS setting (named-encounter scripts, other mods' scripts)
  stay as they are.
- **What stays SCS's:** besides the specials, the monster scripts hold blocks below the
  anchor that do more than a combat round: summons, gating away at low health, death
  handlers, turning hostile, resting, dialogue starts. The installer copies them above the
  hook like the specials. On the mage, priest and general-AI scripts this adds nothing.
- **Several hooked scripts on one creature** (146 creature files carry two or more SCS
  scripts; monster scripts usually sit in a higher slot above SCS's general AI): the first
  hooked script that asks in a pass decides for the creature, with its own family, and the
  others decline in that pass. The engine also declines when a script without the hook sits
  below the deciding one (28 of 4,050 creatures), because taking the round would keep that
  script from running. The installer writes the list of hooked scripts to
  `override/M_BGSEHK.lua` for this.
- **In the lab game:** 1,148 scripts hooked (585 mage, 307 priest, 136 general AI, 120
  monster) with 2,666 copies; WeiDU and `tools/hook_rule.py` agree on every one. Install
  time is still about 4 minutes.
- **`SpellNoDec` casts (answer 10):** copied since the same day: 130 more specials in 37
  scripts (fiends, two dragons, Ascension's bosses, one general AI) and 207 target picks,
  3,003 copies in all; WeiDU and the Python rule still agree on every script.
- **So far:** host tests only; monsters join the next lab batch.

## Step 2 lab batch (2026-10-15)

SR lab on Insane with SCS's per-component settings at their highest (answer 8), three hidden
launches, the lab restored afterwards (all 1,196 SCS scripts byte-identical).
- **In-game reader:** the same records as the host parser for every SPL, EFF and PRO file,
  4,930 of 4,932 items and all 435 projectile numbers. The two other items differ only after
  a save is loaded, where the engine's own copy changed. Creature profiles of 11 creatures
  (mages, a priest, fighters, a golem, fiends, an illithid, a vampire) took at most 29 ms.
  ([SPELLS-01](../research/SPELLS-01-spell-classifier.md))
- **Engine declining:** casters and monsters fought as without the component; casts after
  SCS's round timer ran out came at the same delays as without the hook.
- **Engine holding the monsters:** their ordinary rounds stopped and their copied powers
  ran: the tanar'ri's innate casts and the vampire's whole rat cycle, three times in a
  minute (answer 11). The glabrezu declined because of an unhooked script below, and the
  illithid's lower fighter script left it to its monster script.
  ([HOOK-02](../research/HOOK-02-monster-scripts-and-script-slots.md))
- **Lab lesson:** a save brings its own difficulty; the batch now sets Insane in game after
  every load. The first baseline ran on Normal and was redone.

## Step 3, first slice (2026-10-18)

Agreed with Christopher: first the technical base, then one small visible behaviour, a
shared focus target and no double disables for mages and priests, shown in the lab.
([DIRECTOR-01](../research/DIRECTOR-01-fight-director-first-slice.md))

**What it is.** SCS still chooses every spell; the director only advises on the target of a
cast SCS has already chosen.

- **Group picture:** hooked creatures check in when their script asks the gate, at most every
  15 ticks each, with what they perceive. One director per area keeps the picture: enemies,
  health, disables, a focus target, disable reservations.
- **Advice:** when a member's ordinary Spell cast at a creature starts, the director advises
  through EEex's started-action listener:
  - damage goes to the focus;
  - a disable at an already disabled or reserved enemy goes to a free one;
  - each change is re-checked against legality (range, magic resistance, visible protections,
    the spell's creature filters) and fair play.
- **What stays the creature's own:** the cast keeps its casting time, spell slot and
  interruption.
- **Fail soft:** errors and the switches leave the cast as SCS chose it.

**Lab, three launches.**

- **Redirects work.** Changing a starting cast's target works, for casts at one creature and
  for casts at a kind of creature (`[PC.0.0.MAGE]`). In four probes the casts landed on the
  new target, with normal casting and the memorized copy spent.
- **In mixed fights the director acted almost never:** one redirect in 11 director-on fights,
  and no errors. The diagnosis:
  - SCS aims many casts at a kind of creature, which have no target yet when they start;
  - sleeping enemies lie in a render list that EEex's area search skips;
  - the focus lapsed between a member's casts;
  - most of the "double disables" left were Dire Charm on confused or panicked targets with no
    free alternative.
- **Fixed the same day, technical only:**
  - lying creatures are perceived;
  - casts at a kind of creature are decoded (redirected only within their kind in launch D;
    any kind since Christopher's answer 2 below);
  - the focus is remembered for a round.
- **Launch D, the fixes in game (5 + 5 fights):**
  - all 164 sleeping-dummy samples were in the director's picture;
  - 41 casts at a kind of creature were decoded, and none was left "unseen" any more;
  - the first focus held for 475 to 1,081 ticks;
  - 5 redirects in 5 fights, and no errors;
  - wasted disables fell from 11 of 42 to 7 of 51. Every remaining one had no free
    alternative.

  The fights' outcome did not change measurably: the advisor alters too few casts. The next
  lever is the engine's own spell and target choice.

**Open for Christopher**, asked 2026-10-18:

1. Dire Charm on an already confused or panicked target: waste, or an upgrade?
   **Answer: waste.** "Verschwendung. Aber sehr bescheuerte/unweise Magier könnten sowas
   eventuell machen? Ich weiß nicht, ob es solche gibt." **So:** a confused or panicked
   target counts as disabled, as the director already treats it. It redirects such a cast to
   a free target it can see; with none, SCS's cast still goes ahead for now. Cancelling it
   would cost the creature its round, because SCS's round timer is already running. The
   clean fix belongs to the next step: when the engine chooses spells itself, it does not
   pick such a cast. Unwise casters are an idea for the personality layer (see the ideas
   list).
2. Casts at a kind of creature: same kind only (now), or any creature?
   **Answer: any creature.** "Natürlich? Oder wieso sollte er es nicht? Ich verstehe es
   nicht." **So:** the director takes any legal target for them, as for every other cast. The
   same-kind rule only protected SCS's class choice; the spell's own creature filters are
   still checked.
3. No alternative: keep SCS's cast (now), or cancel it so SCS picks something else?
   Settled with answer 1: the cast stays until the engine chooses spells itself.
4. Area spells: aim them at the focus or at the biggest cluster without allies?
   **Answer: both.** "Das soll beides gehen." **So:** the engine's own choice can aim an area
   spell at the focus or at the best cluster without allies, whichever scores better.
5. Next: the engine's own spell and target choice, with the director's plan in the scoring.
   **Answer: yes.** It starts with mages and priests.

## Step 3, second slice: the engine's own choice (design, 2026-10-18)

SCS's round, read from the installed scripts: below the hook comes a priority list. While
the `castspell` round timer runs, SCS fills the round (waiting, stepping away, melee or
ranged attacks). Once it has run out, the first matching block casts: breaking silence,
True Sight, dispels, defences and potions, protection removal and, for priests, healing come
first; summons and attacks follow. Attacks aim roughly (nearest, farthest, a class) and roll
dice between blocks (80/20 and the like). SCS's attack blocks read enemy stats directly:
magic resistance, resistances, saves, level, holds and spell protections.

Christopher's answers, 2026-10-18:
1. Who decides when to attack: SCS, with the engine swapping its attack casts (A), or the
   engine taking the whole round once SCS's round timer has run out and it has a good attack
   (B)? Suggested A first.
   **Answer: B.** So the engine takes the round with its own cast and sets SCS's round timer
   as SCS does, so that SCS's filler runs between casts. Until the engine does defence,
   dispels and healing itself, it leaves the round to SCS when something urgent comes first
   in SCS's own order: the caster is silenced, or a priest with healing ready is badly hurt
   itself or sees an ally who is.
2. Rules besides the two agreed ones (no disable on an already disabled target; no allies in
   an area spell): damage on the group's focus unless another target is clearly better;
   economical casting (a small spell finishes a nearly dead enemy, strong spells are kept for
   strong enemies); remembering where a spell had no effect.
   **Answer: all three,** with a note for everything that follows: "Es sei aber gesagt, dass
   dies und andere Taktiken (die wir noch gemeinsam später besprechen können) definitiv nicht
   überall gleich sein darf. Gruppen und einzelne Kreaturen müssen verschiedene Intelligenzen
   haben. Das macht das Ganze ja so cool. Beispiel: Manche Gruppen sollten komplett
   unkoordiniert sein und sind deshalb nicht ganz so gefährlich. Der Fighter haut einfach auf
   das erstbeste Ziel. Der Magier zaubert einfach Feuerbälle drauf los. Sowas. Aber wie
   gesagt, ich hab richtig Bock mir sowas dazu auszudenken, aber das kommt, sobald wir das
   GESAMTE Grundgerüst komplett fertig haben :)." **So:** every rule is a knob in a
   per-creature profile (coordination, how often the best option is taken, economy, memory,
   knowledge); one default profile for now, the profiles themselves later with him.
3. Always the best attack, or a random pick among nearly equal ones?
   **Answer: random,** "aber wenn ein Charakter besonders strategisch intelligent ist (z.B.
   Irenicus), sollte er FAST (nicht immer) immer das beste machen. Was genau das beste ist,
   kannst du mich oder SCS auch noch fragen. SCS wird aber auch für SR nicht immer das beste
   wissen."
4. How much may the engine know about enemies?
   **Answer: as much as SCS,** "aber Dinge, die keinen Sinn ergeben würden, dass die
   Charaktere das wissen, sollten wir weglassen. Aber das können wir auch in einem späteren
   Ausbauschritt noch verbessern? Weil das ja individuelle Arbeit wäre." **So:** SCS's
   knowledge now; implausible knowledge is removed in a later refinement step.

## Step 3, second slice: result (2026-10-18)

([CHOICE-01](../research/CHOICE-01-engine-own-attack-choice.md))

**What it is.** Hooked mages and priests take their attack rounds from the engine.

- Once SCS's round timer has run out, the engine reads what the creature sees, what it has
  ready and the director's plan, and picks an attack at a creature or a point: expected damage
  or disable worth after saves, resistances and magic resistance, the focus, economy and
  remembered misses, then a random pick near the best.
- It queues a normal SpellRES or SpellPointRES that first sets SCS's round timer, so SCS's
  filler runs between casts. It leaves the round to SCS when the caster is silenced, when a
  priest with healing ready sees urgent need, and when no attack is good enough.
- The agreed rules (no disable on a disabled target, no allies in an area, damage on the
  focus, economical casting, remembered immunities) are knobs of one default profile.

**Lab, batches E to E5** (the SR lab on Insane, a level-8 to -12 group and a level-18 group
against dummies):

- E: the engine's casts work. Every queued cast started, and there were no errors.
- E2 and E3: SCS's round timer and the casting aura kept most rounds with SCS. Since the engine
  takes the round as soon as SCS's timer is out, it casts about twice as often. Time Stops
  explain the hook actions that stayed current.
- Two faults found in E3, fixed and confirmed in E4: misses judged while a Time Stop froze the
  target, and equal aims weighed several times in the draw.
- A classifier fault locked out most fire, acid and charm spells: it made the creature
  conditions of conditional deliveries (SCS's troll extras, Spell Revisions' exclusions)
  filters on the whole spell. Fixed. In E5 the filter declines are gone, and Flame Strike,
  Melf's Acid Arrow, Sleep, Charm Person, Dire Charm and Horror come.
- No engine disable has gone to a disabled target since E4.
- The spells' own immunity checks (SPLPROT rows of opcodes 318, 324 and 326) are answered by
  the engine's own check for each enemy. In E7 the engine sent no Hold Person to a dummy with
  Free Action and no charm to one with Chaotic Commands. A director fault found on the way is
  fixed: it would not move a cast away from a creature immune to it.

**Next:** the engine's own openers and defences.

**Asked with the report**, answered by Christopher on 2026-10-18:

1. The engine casts an attack before SCS's Time Stop opener and other strong non-attack spells
   whenever SCS's timer runs out. Leave SCS's opener first, or attack first as now, until the
   engine weighs such spells itself in the defence slice?
   **Answer: SCS's opener first, as a stopgap,** "aber mMn releasen wir sowieso nicht bevor
   wir nicht auch das ausgetauscht haben". Then dropped with answer 3's principle: the engine
   takes the openers over itself next.
2. What a caster does when no attack is an option: SCS's round (now), wait, or a profile knob?
   **Answer: SCS's round, as now.** It runs SCS's own priority list (defences, dispels,
   summons, SCS's attacks, melee or ranged filler), so no one stands idle. "Ich finde warten
   sollte jemand fast nie, außer er ist total dumm :D" Waiting may become a trait of very
   dumb profiles later.
3. Should the director also move SCS's disables away from a free enemy immune to them? Now it
   moves them only from disabled or reserved enemies.
   **Answer: yes in principle, but it is a fallback.** Christopher's principle for all such
   work: the engine replaces SCS's fight logic completely in the end, and nobody will play
   long, if at all, with the SCS fallback. "Und jetzt will ich nicht, dass wir Stunden und Tage
   investieren, immer um die Fallbacks und die Umlenkungen zu implementieren." **So:** neither
   stopgap is built (SCS's opener first, redirects away from immune enemies); the engine's own
   openers and defences come next and replace both.

## To design with Christopher

Short decisions for the first release, answered by Christopher on 2026-10-14:
1. **Monsters:** in the first release, should golems, dragons, beholders and the like
   keep their SCS specials and only join the group plan (suggested), or should the engine
   drive them too?
   **Answer: the engine drives them too.** The engine also picks monsters' combat actions;
   their SCS specials stay.
2. **Named SCS creatures:** stay pure SCS at first (suggested)?
   **Answer: enroll them from the start.** The engine takes them over where it can; their
   specials stay.
3. **Difficulty:** follow SCS's own difficulty settings (suggested), or a separate slider?
   **Answer, in Christopher's words:** "The sliders are parallel to what the game has... It
   has the same difficulty steps usually, just leaving some out sometimes. I think we should
   just do the same, but do know: I want to increase some in difficulty, especially on
   insane and above (even though there should not be anything above) once we have taken
   over everything." So the engine follows the same difficulty steps as SCS and the game;
   raising the difficulty is later work (see the ideas list).
4. **First lab fight:** is there a specific fight or group you'd like to see first?
   **Answer: the mixed group (suggested).** Real installed SCS creatures in the quiet lab
   room: two fighters with potions, a priest, a mage and a monster against a party of four
   to six. The variant with two mages and two priests comes later.

Open after step 1 (2026-10-14):
5. **Abilities without a spellbook check** stay SCS's for every family, including monsters
   run by SCS's general AI (golem haste, drake breath, beholder telekinesis). Should some of
   them become engine choices?
   **Answer: yes, later, or earlier if it is easy.** In Christopher's words: "Ja. Ich denke
   mal schon. Vor allem, wenn das unseren Code und unsere Geschwindigkeit äh, wenn das unsere
   Code besser macht und unsere Geschwindigkeit verbessert, und wir dadurch dann später
   flexibler sind, wenn wir da Änderungen haben wollen, dann möchte ich, dass wir das später
   ändern, ja. Also wenn es einfach ist, können wir es auch eher als später ändern." So step 2
   classifies these abilities too, and the engine takes them over where that makes the code
   simpler, faster or more flexible.
6. **Named specials that are spellbook entries** (Abazigal's breath, Kruin's wild magic) look
   like ordinary spells to the engine. Classify them with the other spells in step 2, or keep
   them SCS's?
   **Answer: in step 2 if that is simpler:** "die können wir auch schon früher mit
   reinnehmen, wenn es einfacher ist, klar."
7. **The 166 monster-only SCS scripts** (dragons, beholders, demons, Bodhi, Sarevok,
   Melissan, …): their own step after the first mixed fight?
   **Answer: hook them now.** "Wenn es nach mir geht, können wir das jetzt alles direkt mit
   reinnehmen. Wir wollen ja sowieso relativ komplexe Lab-Tests machen. Und ähm, da können
   auch gerne ein paar Monster mit dabei sein. Und wenn die dann direkt unsere Skripte
   übernehmen und nicht die SES-Skripte [SCS-Skripte], das wäre geil." They get the hook in
   step 2, and monsters join the lab fights.
8. **Lab difficulty** (Christopher's own point): "ich würde fast behaupten, dass es wohl am
   besten ist, wenn wir alle Lab-Versuche auf Insane machen. Also auf der höchsten
   Schwierigkeitsstufe. Beziehungsweise auf der höchsten Schwierigkeitsstufe, die halt, die
   es halt gibt jeweils. Warum? Weil das dann alle Intelligenzen ähm, und alle Items und alle
   Spells beinhaltet. […] Wenn wir dann nochmal hinterher Tests machen wollen, irgendwie auf
   Core oder auf Mittel […], können wir das ja auch nochmal später machen. Aber aus meiner
   Ansicht nach, wenn mit den komplexesten Kombinationen alles funktioniert, dann wird es
   wahrscheinlich auch funktionieren, wenn mal was wegfällt."
   **Lab setting:** the game's slider on Insane and SCS's per-component settings at their
   highest (a few go above Insane: Insane Plus and Legacy of Bhaal), but not the game's
   Legacy of Bhaal mode. Christopher: "Gerne alles auf maximale Stufe, aber die
   Game-Schwierigkeitsstufe, also den Spielmodus, LOB bitte nicht. Der ist absoluter
   Schwachsinn, den benutzt niemand. Das ist, glaube ich, von Beamdog und nicht von BioWare.
   Und äh, ist völlig unspaßig." A check on a lower setting comes later, to make sure the
   engine copes with less.
9. **Ascension** (Christopher's own point, after the no-SR check found that SCS scripts the
   original Melissan differently without Ascension): "aus meiner Sicht ähm, sollten wir auf
   Ascension aufbauen. Und mit Ascension zusammenarbeiten können. Genau wie SAS das ähm,
   genau wie SCS das macht. Nur halt mit unserer eigenen Engine. […] ich glaube nicht, dass
   wir komplett Ascension auch ähm, äh, übernehmen sollten. Also austauschen sollten. Weil
   das ja auch einiges an Story Elementen hinzufügt und das eigentlich für die meisten Leute
   vollkommen okay ist. […] Lass uns das erstmal einfach nur übernehmen und dann die
   Skripte verbessern, anstatt dass wir ähm, Ascension selbst austauschen."
   **So:** Ascension stays as it is, like SCS: its story, dialogue, phases and special moves
   stay Ascension's (and SCS's Improved Ascension's), and the engine improves the creatures'
   combat choices through the same hook. SCS's Ascension scripts are hooked as monster
   scripts since the monster hook.
   Later the same day, on Ascension's special abilities: "wir müssen tatsächlich bei den
   Spezialfähigkeiten von Ascension hinterher gucken. Das wird das [Da werden wir das]
   vielleicht äh, reviewen und selber einbauen, weil sich schon sehr viele Leute über die
   Ascension-Fähigkeiten beschwert haben. A, über, darüber, dass die cheaten, B, dass es
   darüber keine Informationen gibt. Nirgendwo, das, ne, dass man nicht erfahren kann, was da
   benutzt wird und ähm, dass man quasi nicht nachvollziehen kann, was passiert ist.
   Nirgendwo, nicht in, nicht in den Logs, ähm, nirgendwo, quasi nicht im Chat, dass das
   nicht die echten Fähigkeiten sind, wie aus dem Game und so weiter. Und da müssen wir
   hinterher vielleicht mal Lösungen finden. Ähm, und ich finde ja, dass die Ascension Gegner
   ruhig extrem stark sein können, aber dass die cheaten, finde ich eigentlich nicht geil."
   **So, later work:** go through Ascension's special abilities and, where it helps, rebuild
   them in the engine. They may stay extremely strong, but they should not cheat, and the
   player should be able to see what was used. What counts as cheating and how the fight
   shows it is designed with Christopher; the engine's fair-play rule already holds for its
   own choices. The groundwork is
   [ASC-01](../research/ASC-01-ascension-specials.md) (2026-10-15): every special of
   Ascension's bosses, how it leaves fair play, whether Ascension, SCS or vanilla wrote it,
   and design options to talk through. On the cheapest option, showing everything in the
   log and over the head: "Das müssen wir meiner Meinung nach aber nicht mit prio 1 jetzt
   machen, das wäre aber cool für später." **So:** later, not now.
   Clarified the same day: the missing log line is not the main problem. Ascension's
   abilities carry real spells' names but follow other rules: "du siehst ähm, deinen
   Charakter der so starke Spell-Saving-Throws hat, dass er gegen Blade-Barrier niemals den
   Saving-Throw verlieren könnte. Plötzlich wie er zerrissen wird von Blade-Barrier, von
   Amelisan." The questions are whether we want such advantages at all, for example in the
   last fights, and if so, "wie machen wir es klar, dass ein Spieler verstehen kann, was
   gerade passiert oder er sich vielleicht sogar darauf vorbereiten kann?" Ascension's
   concept stays valuable; long term it may be improved or replaced. The design is
   Christopher's, proposals welcome. Checked in the files: the game's Blade Barrier does 8d8
   with a save vs spell, SR's 1d8 per hit without a save, and Melissan's, under the same
   name, 12d12 with a save vs death at −2 to −9 by caster level.
   On the proposals (2026-10-18): "genau". **So, for later:** no hidden rule changes (an
   ability named like a real spell follows that spell's rules); a boss that needs more gets
   its own ability with its own name, description (damage, which save, what helps against
   it) and look; strength comes from visible means (higher caster level, more spells,
   faster casting, the engine's clever use, enemies working together, as Balthazar
   already does); especially hard abilities are announced a round ahead and can be
   countered (distance, a specific protection, interruption); hints in dialogue or the
   journal let players prepare. Long term, Ascension's story and dialogue stay and its
   fights are rebuilt boss by boss with the engine and encounter phases, from ASC-01.
10. **Scripted casts without a spellbook check** (`SpellNoDec`, `SpellNoDecRES`; found by the
    no-SR check): the hook rule leaves them below the hook, so they stop while the engine
    holds the creature. That matters for Melissan without Ascension (105 blocks, her whole
    spell list) and one self-heal of Ascension's Illasera. Suggested: copy them above the hook
    like the other abilities without a spellbook check (answer 5), except blocks that also
    remove the spell, since `RemoveSpell` means a spellbook entry is used up.
    **Answer: yes.** "Neurostring [SpellNoDec] an sich erstmal gut, was du da vorgeschlagen
    hattest."
11. **Powers a monster applies to itself** (`ApplySpell`, `ApplySpellRES` on `Myself` without
    a spellbook check; found by the no-SR re-check): they stay below the hook, so they stop
    while the engine holds the creature. 167 blocks in 23 monster scripts without SR, 170 in
    26 with SR. The visible case is SCS's 12 vampire scripts: the rat-form cast is copied,
    but turning invisible and turning back are self-applies below the hook, so a vampire the
    engine holds stays a rat until the engine declines. The rest are single buffs: genie fire
    shields, dragon stoneskin and protection from magic energy, a fiend's stoneskin or
    invisibility, and with SR Ascension's Abazigal, balor and succubus. Suggested: copy them
    above the hook like answers 5 and 10, so the creature keeps SCS's powers while the engine
    holds it. (HOOK-01)
    **Answer: yes.** "Klar. Gibt es eine Alternative, oder ist das einfach die beste Lösung?"
    The alternatives were worse: handing the creature back to SCS while it is in such a state
    needs every SCS script's own variable names, and the engine applying these powers itself
    would apply effects directly, against the fair-play rule; taking powers over belongs to
    the later work of answer 5. Done on 2026-10-15: exactly those blocks are copied now, and
    mage, priest and general-AI scripts get no new copies.

Decided on 2026-10-18, with the answers above:
12. **Pre-buffs.** They exist because creatures that know or suspect an attack is coming
    prepare instead of standing around unbuffed (the deeper Cloakwood Mines hear the party
    coming, or are on edge anyway), mostly with longer-lasting buffs. Christopher likes SCS's
    pre-buffs "zu 50 bis 100%", their random part included; sometimes they could be more and
    smarter. **So:** a first test release can keep exactly SCS's pre-buffs; the engine's own
    preparation is designed later, fight by fight with Christopher, with SCS as the
    reference.
13. **Random choices per run, not per installation.** Christopher likes the random parts of
    SCS's pre-buffs and spellbooks: "Das sollte meiner Meinung nach übrigens auch pro Run
    möglich sein. Und nicht pro Installation". SCS draws its spellbook swaps once, when it is
    installed; its pre-buff scripts roll at run time. **So:** later, random choices such as
    spellbook swaps are drawn per run and kept for that run.
14. **SCS's other components stay SCS's for now.** Item balancing and SCS's other tweaks
    outside the fight logic stay as SCS installs them; they may be reviewed one by one later.
    This is the plan's split (see "How it fits with SCS"): the engine replaces SCS's fight
    logic and reads the creatures as installed.

Christopher's ideas so far (living list; more will follow):
- **Started casts don't fail when the target runs out of sight.** Reported in September:
  casts aimed at a character, such as Davaeorn's suspected Fireball, usually don't go off
  once that character runs around a corner. Not yet reproduced in a lab. A likely
  approach: aim area spells at the spot instead of the creature, so they still land.
- **Prebuffed area buffs reach the allies, not only the caster.** Designed in August; one
  lab probe on `codex/aoe-prebuff-design` cast SCS's Haste prebuff for real and both the
  caster and a nearby ally got it. Not wired in yet.
- **Smart enemies dodge slow area spells** (clouds, webs, dragon breath and the like) when
  they could see the cast. Recorded as later work on Oct 12: ground-targeted, delayed
  effects are the best candidates; homing projectiles can't be outrun.
- **Smarter spell use, dispelling and breaching, scaled by how clever the enemy is.**
  Fits the personality and difficulty layer.
- **Harder fights on the top difficulties, once the engine runs everything.** Oct 14: "I
  want to increase some in difficulty, especially on insane and above (even though there
  should not be anything above) once we have taken over everything."
- **Spells that differ between installs.** Oct 14: "Wir müssen auch hinterher dann uns mal
  unterhalten über ähm, die großen Unterschiede zwischen ein paar Spells bei Spell
  Revisions und ohne. Ob da die Engine die Unterschiede intelligent genug übernimmt. Ähm,
  und was passieren würde, wenn jetzt jemand ein Spell austauscht oder verändert. […] Wäre
  ja, der Sleep Spell […] ohne Spell Revisions bleibt ein Schlaf bestehen, wenn die Kreatur
  angegriffen wird. Die schläft. Mit Spell Revisions wird die aufgeweckt, wenn die
  angegriffen wird. Ein Gegner, der schlau genug ist, könnte ja zum Beispiel als eine
  Aktionsmöglichkeit haben, jemanden aufzuwecken, wenn es denn möglich ist. Und er müsste
  dann aber auch wissen, wenn es nicht möglich ist." No solution needed yet. Such
  differences live in the installed spell's effects, which the classifier reads; how
  Sleep's wake-up shows there is not checked yet.

- **How fast engine casters react compared to SCS.** Oct 14: "Für mich wäre mal
  interessant, wie schnell wäre unsere Engine? Also zum Beispiel, ne? ähm, ein Caster wird
  hostile bemerkt, dass er in Kampf losgeht. Und bei SES SCS äh, dauert es ne, deine 0,3
  bis 0,6 Sekunden oder was du da gerade angibst. Oder vielleicht ein bisschen länger. Ne,
  das, dass er da anfängt, ähm, dass die Buffs wirklich da sind. Weil manchmal ist es noch
  so, dass es einfach einen Moment dauert, bis die Buffs wirklich da sind. Und wie lange
  würde unsere Engine brauchen?" To measure in the lab: from first sight to the first action
  and to the first buff in effect, for SCS without the hook, with the hook declining and,
  from step 3, with the engine deciding.
- **Creature parameters such as intelligence and cooperation.** Oct 14: "Zum Beispiel hatte
  ChatGPT damals ja die Idee, dass man ähm, Kreaturen oder Charakteren, also allen,
  Kreaturen, Files an sich, ähm, Intelligenzen zuweist. Ne? Oder irgendwie so einen Wert
  zuweist und Kooperation zuweist. Also gewisse Parameter hat, die dann mitbestimmen, wie der
  Charakter reagiert. Ne? Ob der dann irrational reagiert oder sowas. [...] Oder wie
  kooperativ der Charakter reagiert. Und äh, das fand ich eigentlich echt cool. Und da würde
  ich hoffen, dass das schnell innerhalb des Games klappen könnte, ohne dass äh, die KI dann
  irgendwie super langsam werden würde." Fits the personality layer; a few numbers per
  creature in the scoring cost little at run time.
  Oct 18, on Dire Charm at an already confused target: "Aber sehr bescheuerte/unweise Magier
  könnten sowas eventuell machen? Ich weiß nicht, ob es solche gibt." Checked in the SR lab's
  creature files:
  - Of the casters with wizard spells, only duergar and a few dwarves have INT 8 or less, and
    their one spell is an innate invisibility.
  - Low WIS among priest-spell users is just as rare (Minsc, imps).
  - The files' values are a weak guide: many important casters carry a default 9 in every
    stat, Dracandros and drow mages among them.

  So a "how clever" value would come from our own small table (by race, kind or kit) rather
  than from the creature files.
- **The group protects itself, not only dispels the party.** Oct 18, on "one dispeller per
  protection": "und im Falle von SR Dispelling Screen oder mit und ohne SR andere AOE oder
  Single target schutzspells. Aber eher natürlich die, die für fights gerecht sind und
  schnell. Da müssen wir später mal schauen, was Sinn macht." A protector role in the
  director, preferring fast protections that suit a fight; which spells, later.

Bigger design topics, in a dedicated design session:
- what the director should do in typical situations (which threats come first, when a
  group falls back or regroups, how fighters protect casters);
- personalities: how individual creatures differ within SCS's identity;
- group-aware preparation and enemies who remember the party (see above);
- later, scripted encounter phases.
