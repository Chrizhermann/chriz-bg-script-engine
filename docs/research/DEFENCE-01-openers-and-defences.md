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

### D1 as built (2026-10-19)

**Sensing** (`adapters/eeex/sense.lua`, `defend`). The caster and each ally it sees get a guard:

- their active effects, timed and equipped, read as one record by the spell classifier, so
  protections count by what they do (effects ending within 6 seconds and delayed ones that have
  not started are left out);
- the Stoneskin skins and Mirror Images left;
- the spells their effects come from, and the spells an opcode 206 keeps off them.

Every creature around also gets its weapon: attacks a round, THAC0 with its bonuses, the average
damage of a hit, whether it shoots and whether it is magical. Enemies also show whether they see
invisible creatures. A friend whose effects cannot be read gets nothing rather than a second
copy.

**The threat picture** (`combat-intent/threat.lua`), per friend and round:

- **Weapons** from enemies that can strike within a round's walk, or shoot. Each attacks the
  friend its action names, else the nearest one it can reach and see. Hits and attacks are kept,
  because skins and images absorb hits one by one.
- **Spells** from enemy casters, by class and level only, since SCS reads no spellbooks either:
  1.2 hit points per caster level a round, 60% of it aimed at one creature and the rest as areas,
  and a 15% chance a round to disable the friend it casts at. These numbers are rough on purpose.
- An invisible friend is safe from the weapons and aimed spells of enemies that do not see
  invisible creatures.

**Worth** (`combat-intent/defence.lua`), on the attack's scale. A defence is worth the loss it
saves its receivers within the horizon (18 seconds, or less if the spell ends sooner). A friend's
loss has three parts:

- the share of its hit points it loses;
- the kill bonus, as likely as it dies;
- a third of a share (a round of disable) for each round it is out of the fight, dead or
  disabled.

Harm runs over time. Skins and images absorb the first hits, so they buy rounds even when the
friend falls in the end. What a friend already has counts first:

- the same kind twice counts once, the larger;
- independent kinds compound (armour lowers the hits that get past weapon immunity);
- a fresh Stoneskin over skins that last the horizon gains nothing, as SCS keeps "at least one"
  up.

An area buff is worth what it adds to every ally it reaches, including their extra weapon damage
as a share of an enemy. Single-target spells on allies come only from the profile's `allySpells`,
empty until Christopher agrees exceptions.

**Costs and the decision:**

- Defence options join the attack options in one ranking, with the same random pick near the
  best.
- Costs: 0.03 per spell level (times the profile's economy), plus `castCost` (0.02) per second of
  casting time.
- The worth is multiplied by the chance the cast gets through: each hit or aimed spell that gets
  past what protects the caster now can break it.
- `caution` (1) weights every defence; 0 turns them off.
- After a defence, the engine's or the script's, the next waits `redefend` (7 seconds), as SCS's
  timer does. It does not wait when the caster is in acute danger: one round would cost it half
  its hit points left, with what protects it now.

**Tests:** eight logic groups for the defence model, and the choice adapter's groups for
defences and the lab's profile switch (`setMind`).

### D1 in the lab

All runs: the SR lab on Insane, the mid (levels 8 to 12) and high (level 18) groups, against
party-side fighters with their own scripts where batch E had dummies. Each fight ran in three
modes: SCS alone, the engine's attacks only (`caution` 0), and the engine with its defences.

**Batch F, a probe.** The fields the slice reads exist and hold what it expects (effect timing,
skin and image counts, combat stats, the weapon in hand; see learned.md, sections 1 and 6). The
fighters' AttackReevaluate actions name no target, so the threat picture falls back to the
nearest friend an enemy can reach.

**Batch F2, 18 fights** against four level-8 fighters (two with a Short Sword +1 and a bow with
Arrows +1, two with a Bastard Sword) and a level-12 mage:

| Group | Mode | Won | Group dead | Group hp lost | Engine defences |
| --- | --- | --- | --- | --- | --- |
| high | SCS | 3 of 3 | 0 | 7 | – |
| high | attacks | 3 of 3 | 0 | 3 | 0 |
| high | defences | 3 of 3 | 0 | 10 | 0 |
| mid | SCS | 1 of 3 | 0.33 | 79 | – |
| mid | attacks | 2 of 3 | 0 | 47 | 0 |
| mid | defences | 1 of 3 | 0 | 28 | 0 |

(Means per fight; a fight not won ran out its 120 seconds.)

- The slice ran without errors: no failed guard reads, no engine errors, no interrupted casts.
- No fight created a need. SCS's pre-buffs held: the high mages kept all 9 Stoneskin skins and
  8 Mirror Images in every fight, and the mid group's level-12 mage its 6 skins in 8 of 9. Only
  the level-8 mage and the priests lost hit points worth mentioning.
- In 28 of 91 decisions with defences on, a defence was among the best options. The best
  defence scored −0.07 in the median: its worth was smaller than its cost. Most were Bless and
  other priest buffs.
- Three fights are too few to read the hit points lost as an effect of the modes.

**Batch F3, 18 fights**, built to create the need F2 lacked:

- the four fighters with 250 hit points each and no enemy mage;
- every group caster with 150 more hit points from the start (Christopher: so that no one dies
  too fast);
- 16 seconds in, the lab strips every caster's weapon protections the way Spell Revisions'
  Breach does (opcode 221 on secondary types 2 and 7), and its illusions (type 3), the same in
  every mode.

The strip took in all 18 fights: every caster had 0 skins and 0 images a second later.

| Group | Mode | Won | Length | Group hp lost | Fighters disabled after the strip | Engine defences |
| --- | --- | --- | --- | --- | --- | --- |
| high | SCS | 3 of 3 | 65 s | 42 | 10% | – |
| high | attacks | 2 of 3 | 108 s | 76 | 78% | 0 |
| high | defences | 2 of 3 | 110 s | 49 | 73% | 0 |
| mid | SCS | 0 of 3 | 120 s | 87 | 72% | – |
| mid | attacks | 0 of 3 | 120 s | 67 | 85% | 0 |
| mid | defences | 0 of 3 | 120 s | 91 | 89% | 1 in 3 fights |

(Means per fight. "Disabled" is the share of samples in which a standing fighter was held or
otherwise disabled.)

- No caster died. After the strip each caster lost 3 to 13 hit points on average.
- **The engine's one defence:** in the first mid fight with defences, a level-12 priest cast
  Defensive Harmony around itself (score 0.72); it reached two friends, and both carried it
  afterwards.
- **Why so few:** the threat picture counts no disabled enemy, and with the engine casting, the
  fighters were disabled about three quarters of the time or more. The extra 150 hit points
  also lower what protection is worth, because harm counts as a share of a friend's hit points.
- **The engine's attacks lean on disables** against these fighters: about 8 disables a fight
  in both groups, 6 or 7 damage spells in the high group and almost none in the mid group. SCS
  alone cast about 10 damage spells and no disables in the high group and won all three fights,
  in 65 seconds on average; with the engine they took about 110, and one in each engine mode
  was not won within 120. A full-length hold on a healthy enemy counts as that enemy taken out,
  whatever its hit points, while damage counts as a share of them, so 250-hit-point fighters
  make damage look small.

**What F2 and F3 show:**

- D1 works in game: the reads, the threat picture, the options and the decision run without
  errors, and its one defence took.
- These fights do not test its judgement. SCS's pre-buffs, and after the strip the group's
  disables, kept the fighters off the casters, and the model rightly saw little to defend
  against.
- A fair test needs enemies that keep up pressure: fighters that resist disables (Free Action,
  Chaotic Commands, magic resistance) and enemy casters with protections. The same lab would
  serve D2's openers and D3's removals.

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
- **Touch spells and conjured weapons.** The classifier reads 57 wizard and priest spells of the
  SR lab as a weapon or on-hit buff on the caster (learned.md, section 9): the Cause Wounds
  spells, Harm, Slay Living, Shocking Grasp, Chill Touch, Melf's Minute Meteors, Spiritual
  Hammer, Black Blade of Disaster, the shapeshifts and others. The engine neither attacks with
  them nor gains anything by casting them as defences. Reading them needs the created item's
  abilities (opcode 111) and the on-hit effects (248, 249), and a plan to cast and then strike,
  as SCS does with Harm.
- **Menu spells** (opcode 214): Protection from Elemental Energy, Polymorph Self, Shapechange and
  Nahal's Reckless Dweomer let the caster pick a sub-spell (learned.md, section 9). The engine
  leaves them out, as SCS's scripts do. Creatures mostly carry the elemental protections as the
  sub-spells themselves, which the engine reads fully. Using the others needs a lab probe of
  what opcode 214 does for a creature no player controls, and Christopher's choice of which
  sub-spell to pick.
- **Whom a fighter attacks.** The party fighters' AttackReevaluate names no target, so the threat
  picture guesses the nearest friend an enemy can reach. Decoding the action's object, as the
  director does for casts at a kind of creature (DIRECTOR-01), would name it.
- **The spell threat's numbers** (1.2 hit points per caster level, 60% aimed, 15% disable chance)
  are guesses. Only batch F2 had an enemy caster so far, one level-12 mage.
