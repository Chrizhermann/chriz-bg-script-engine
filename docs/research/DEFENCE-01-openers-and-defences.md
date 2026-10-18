# DEFENCE-01 — Openers and defences: what SCS does, and the engine's design

Date: 2026-10-19. This is step 3 of the plan, third slice (answers in the plan, "Step 3, third
slice").

SCS is by DavidW. Spell Revisions is by Demivrgvs and the Gibberlings Three. No game file is in
this repository; SCS paths below are relative to its `stratagems` folder (SCS v35.21, as
installed in the SR lab).

## Question

What does SCS do to protect its mages and priests, and when? What must the engine read and weigh
to take that part of the round over, now that it takes every round in which it has a good
attack?

## What SCS does

**[src]** marks what was read in the installed SCS source. The rest comes from a source survey
(an inventory agent) and is marked where it is an interpretation.

### Where defences sit

- A mage's script runs, in this order: contingencies, flight from clouds, melee, **renewal**
  (defences, Time Stop, potions), pursuit, then the core list of combat blocks
  (`mage/ssl/main/dw#mage.ssl`). A priest's runs turn undead and melee before its renewal, then
  its core list (`priest/ssl/main/dw#priest.ssl`).
- Our hook sits before the first block that checks the round timer, so above SCS's renewal.
  Since the second slice the engine takes every round in which it has a good attack, and SCS's
  defences come only in rounds the engine leaves to SCS.
- **[src]** Renewal waits for the first-round preparation: SCS's pre-buffs run while
  `instantprep` is 0 and set it to 1 (`mage/ssl/prep/first_round_buff.ssl`, lines 7 and 21).

### The mage ladder

**[src]** `mage/ssl/generalblocks/renew.ssl` is a priority list. Its comments name the levels,
and the first block that matches casts:

- **Priority 0:** whatever makes the mage unable to act: silence, spell failure, blindness.
- **Time Stop**, when the party or a strong enemy is seen ("don't waste timestop on riff-raff",
  lines 144-160), after dispelling the party's sequencers when the mage can.
- **Priority 2:** "keep up at least one attack-blocking defense. Wizards are paper, and AC alone
  doesn't really cut it. Priority order is pro/weapons > stoneskin > mirror image >
  invisibility" (lines 287-292). Sequencers bundle several protections into one cast.
- **Priority 3:** "keep up at least one protection against personal spell attacks, i.e.
  *either* have Improved Invisibility, *or* Spell Deflection / Spell Turning, running at all
  times" (lines 726-734). Improved Invisibility is taken when True Sight is not a danger or no
  enemy caster is seen; deflections when an enemy caster is seen.
- **Priority 4:** Globe of Invulnerability or Minor Globe of Invulnerability when an enemy
  caster is seen, or when the mage has Fireball itself. **[src]** `NeedMinorGlobe` in
  `ssl/library.slb`, lines 809-817; the second case lets it throw Fireballs near itself.
- **Priority 5:** Fire Shield, Spirit Armor, Ghost Armor and Shield when an enemy is close and
  the mage's armour class is poor.
- **Escape:** under three quarters of its hit points, Mislead, Shadow Door or invisibility once
  the defence timer has run out; healing potions only when it is invisible or no enemy is in
  sight.
- **Improved Alacrity** is in the core list (position 9), when an enemy is seen.

**[src]** An enemy caster is a seen mage, bard, cleric, druid or sorcerer
(`EnemySpellcasterPresent`, `ssl/library.slb`, lines 802-808).

### The priest ladder

- Priest renewal (`priest/ssl/generalblocks/renew.ssl`): at high level Foresight or Divine Shell
  when an enemy is close; Protection from Magical Weapons or Mantle when an enemy is close and no
  weapon protection is up; holy auras; Shield of Lathander; Ironskin when Stoneskin fails.
- **[src]** Sanctuary, with Invisibility, under half its hit points (lines 118-123).
- Priest defences in the core list (`priest/ssl/combatblocks/my_defences.ssl`, position 13):
  - **[src]** Close-range defences only with an enemy within 10: Blade Barrier, Globe of Blades,
    Righteous Magic, Draw upon Holy Might.
  - **[src]** Long-term protections only while no enemy is within 10: Chaotic Commands (lines
    100-107), Physical Mirror, Shield of the Archons or Fiendish Warding, Magic Resistance.
- **[src]** Group buffs (`priest/ssl/combatblocks/group_buffing.ssl`, position 15): Recitation,
  Defensive Harmony, Prayer, Chant, Righteous Wrath of the Faithful and others, cast on the priest
  itself when more than two enemies are seen and an ally within 10 lacks the buff (lines 49-68).
  Bless needs more than three enemies.

### Rhythm and knowledge

- **[src]** After a defence SCS sets a shared `redefend` timer of 7 or 8 seconds, a little more
  than a round, and no other defence comes until it has run out (for example
  `mage/ssl/generalblocks/renew.ssl`, line 340; `priest/ssl/combatblocks/my_defences.ssl`, line
  106). The survey reports SCS's comment that the timer stops a caster from defending twice and
  forgetting to attack.
- SCS knows what the creature sees, distances, how many enemies there are and their classes. It
  reads no spellbooks.
- Response weights (`|100|50` and the like) add randomness at run time; SCS's install-time
  randomness lives in its trigger generator (survey).

## What the labs show

Batches E5, E7 and E8: 36 fights with the engine on, SR lab, Insane, mid and high groups against
dummies. The SCS casts counted here are from rounds the engine left to SCS.

- **Pre-buffs:** about 1,000 instant `ReallyForceSpell` casts, nearly all in the first round.
  The most common were Mirror Image, Minor Globe of Invulnerability, Armor of Faith, Stoneskin,
  Free Action, Shadow Door, Shield, Spiritual Hammer and Chaotic Commands. High mages also had
  Spell Deflection, Mind Blank, Chain Contingency and Prismatic Mantle.
- **First own cast:** for 98 of 144 casters (counted once per fight), the first spell SCS cast
  itself was a protection.
- **Protections in the first round:** Protection from Magical Weapons and Prismatic Mantle (high
  mages).
- **Protections in rounds two and three:** Defensive Harmony, Righteous Wrath of the Faithful,
  Prayer, Recitation and Chant.
- **Protections later in the fight:** Recitation, Defensive Harmony, Obscuring Mist,
  Invisibility, Divine Protection and Fiendish Warding.
- **Other casts:** healing from about 18 seconds on; summons from the second round; Slow and
  Dispel Magic.

## Defensive spells in the labs

The host census of the classifier at caster level 20 (`spell_census.py`) found 281 wizard and
priest spells with a protection or buff role in the SR lab, and 191 without SR.

- **Spell Revisions' Haste** (`SPWI305`) does not use the engine's haste opcode. It gives extra
  attacks (opcode 1) and movement (opcode 176) for 144 seconds. When it ends, it casts `SPWI305D`
  on the receiver: −2 armour class, THAC0 and damage for 18 seconds. It also guards against
  Improved Haste and its own recast (opcode 206).
  - **So:** the engine must read buffs by what they do, as the classifier already does, never
    by the opcode or name of the unmodded spell.
- **Delayed after-effects count as immediate today.** A sub-spell cast after a delay (opcode 146
  with timing 4) adds its effects to the spell's roles as if they came at once. Haste then looks
  as if it carried a debuff. To fix in D1.
- **Guards between related buffs look like protections.** An opcode 206 that names another
  friendly spell (Haste against Improved Haste, Mirror Image against Reflected Image) shows as
  "immune to these spells".
  - **So:** protections are weighed only against threats actually seen, which gives such guards
    no worth.
  - The same guards on a receiver tell the engine that a buff would not take there.

## The engine's design

Christopher's answers of 2026-10-19 are in the plan ("Step 3, third slice"): weigh per round,
protect and buff allies rather like SCS (casting time counts), Time Stop and combos like SCS
first.

### D1: defences and buffs

1. **What is up.** For the caster and its allies, the protections and buffs in force:
   - their effects;
   - Stoneskin skins and Mirror Images left;
   - the states that matter (invisible, sanctuary);
   - the guards against recasts.

   The pre-buffs count, so they are renewed when they run out, not cast again.
2. **The threat picture,** from what the creature perceives:
   - enemies in melee reach or coming, and who they attack;
   - enemy casters (SCS's knowledge: class, level, what is seen);
   - incoming harm per round by way of attack: weapons, personal spells, area spells and
     disables.
3. **Defence options on the attack's scale.** Attacks are worth shares of an enemy taken out. A
   protection is worth the share of a friend's hit points and fight time it probably saves
   within a horizon:
   - the threat it blocks, times how well it blocks it;
   - nothing for a threat no one poses.

   An area buff is worth what it adds for every ally it reaches. Single-target buffs on allies
   come only as exceptions agreed with Christopher. Costs: spell level, casting time and the
   risk of interruption.
4. **The decision** weighs the best attack and the best defence on that scale. Profile knobs:
   - caution, which weights defence;
   - the horizon;
   - a pause between two defences, like SCS's `redefend`, unless the threat is acute.

   Urgent cases still go to SCS for now (silence; healing needs of priests).
5. **Lab:** enemies that fight back, with fighters running at the casters and enemy casters,
   instead of dummies.

### D2 and D3

- **D2, openers like SCS:**
  - Time Stop when the party or a strong enemy is seen, then quick attacks;
  - Improved Alacrity;
  - sequencers and spell triggers, judged by the spells they release.
- **D3, removing enemy protections:** Breach, Dispel Magic, Spell Thrust and the like. They are
  worth what they open for the group's attacks.

### Open

- **Adjusting within the round** (Christopher's idea): re-deciding while a round runs, for
  example when a threat appears before the cast starts. To think through together.
- **Quick single-target spells for allies,** such as Resist Fear and Remove Paralysis
  (Christopher's examples). Exceptions to agree with him, with their casting times.
