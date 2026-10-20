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

**Batch G1, 24 fights: the hard lab** (2026-10-20), built from F3's conclusion:

- the four party-side fighters with 150 hit points, carrying the lasting effects of Spell
  Revisions' Free Action and Chaotic Commands (their immunities and spell states) and 50% magic
  resistance;
- behind them a party mage without a script (a copy of MAGE12A against the mid group, of
  MAGE18C against the high group) with 8 Stoneskin skins and the same magic resistance. The lab
  casts its spells at the nearest group caster, at most one a round: Breach, damage and a few
  disables;
- every group caster with 50 more hit points; the strip at 16 seconds as in F3;
- the same three modes. G1's build had D1 but not yet D2a's openers.

| Group | Mode | Won | Length | Group hp lost | Group dead | Foes dead | Engine choices |
| --- | --- | --- | --- | --- | --- | --- | --- |
| high | SCS | 4 of 4 | 88 s | 84 | 0 | 5 of 5 | – |
| high | attacks | 4 of 4 | 90 s | 112 | 0 | 5 of 5 | 2 in 4 fights |
| high | defences | 4 of 4 | 93 s | 57 | 0 | 5 of 5 | 4 in 4 fights |
| mid | SCS | 0 of 4 | 79 s | 460 | 4 | 0 | – |
| mid | attacks | 0 of 4 | 97 s | 503 | 3.25 | 1.5 | 5 in 4 fights |
| mid | defences | 0 of 4 | 92 s | 508 | 4 | 1.5 | 6 in 4 fights |

(Means per fight; a fight ended when one side was dead, or after 120 seconds.)

- The high group won every fight in every mode. Its two mages cast Time Stop 13 to 15 times in
  each mode's four fights, about three a fight, all from SCS's script.
- The mid group lost every fight. The party mage killed MAGE8A about 12 seconds in, every time.
  With the engine the group killed 6 of 20 foes over four fights, alone none: too few fights to
  call that an effect.
- **The engine was almost passive.** In each mode's four fights it declined 52 to 89 free rounds
  for lack of an option, 57 to 90 because nothing was good enough, and 13 to 55 because a friend
  was hurt (urgent needs stay SCS's). Its best option in a declined round scored −0.04 in the
  median and 0.18 at most, below the minimum worth of 0.2. The fighters are immune to its
  disables, and its damage counts as a share of their 150 hit points, halved by magic
  resistance. So SCS played nearly every round, in all three modes.
- The lab added the magic resistance (opcode 166, mode 0) more than once to the party mage and to
  one of the fighters in each fight: they had 100 or 127 instead of 50, the same in every mode.
  G2 sets it (mode 1).

**What G1 shows:**

- The hard lab keeps up pressure: it overwhelms the mid group, and the high group wins with
  SCS's Time Stops.
- With a minimum worth of 0.2 the engine leaves almost every round to SCS against hard foes.
  Whether it should act on its best option instead is a question for Christopher; batch G2
  measures a minimum worth of 0.05.

**Batch G2, 15 fights: D2a in the hard lab** (2026-10-20). G1's lab with the magic resistance
set once (mode 1, 50 for all), the high group only, four modes:

- SCS alone;
- `own`: the engine with D1's defences and D2a's openers;
- `base`: D1's defences without openers;
- `low`: with openers and a minimum worth of 0.05.

The run was stopped in its sixteenth fight, the fourth `low` one, because Christopher's own game
started (no lab while he plays). G2's four trigger probes did not run.

| Mode | Won | Length | Group hp lost | Group dead | Foes dead | Engine claims | Time Stops |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SCS | 4 of 4 | 85 s | 60 | 0 | 5 of 5 | – | 11, SCS's |
| own | 4 of 4 | 103 s | 24 | 0 | 5 of 5 | 96 in 4 fights | 16, the engine's |
| base | 4 of 4 | 43 s | 112 | 0 | 5 of 5 | 59 in 4 fights | 1, SCS's |
| low | 3 of 3 | 91 s | 77 | 0 | 5 of 5 | 68 in 3 fights | 10, the engine's |

(Means per fight; length in game time.)

- **D2a works in game.** In its four fights the engine cast Time Stop 16 times (each mage twice a
  fight) and Improved Alacrity 4 times; in its own stops it cast 46 damage spells and 19
  disables. No errors, no failed reads.
- **With its openers the group lost the fewest hit points** (24 a fight against SCS's 60), but the
  fights ran longest: each Time Stop freezes everyone else for 18 seconds of game time.
- **Without openers** the engine took the mages' rounds for damage, so SCS seldom reached its
  Time Stop. The fights ended twice as fast as SCS's and the group lost the most.
- The engine claimed 59 to 96 rounds in a mode's fights, against 2 to 6 in G1, whose build had
  neither D2a nor the magic resistance set once. Of the rounds it declined, 139 to 309 per mode
  came while SCS's round timer ran and 16 to 77 because nothing was good enough. Most declines
  (364 to 776 per mode) were the party fighters, whose family the choice does not handle.
- A minimum worth of 0.05 left fewer rounds for lack of worth (16 in three fights against 77 in
  four) and made no clear difference otherwise.
- The high group won every fight in every mode. The hard lab does not press it enough to tell
  the modes apart by wins; hit points lost and length do.

### D2: what SCS does

Christopher's choice of 2026-10-19: D2 like SCS first, with a hard lab; touch spells and
conjured weapons as a combo with it. Read in the installed SCS source **[src]**; line numbers are
SCS v35.21.

**Time Stop** (`mage/ssl/generalblocks/renew.ssl`, lines 139-264):

- Priority 1, right after what makes the mage unable to act.
- Cast when the mage sees one of the party ("don't waste timestop on riff-raff", line 151) and no
  Time Stop of its own runs.
- Not during its own Improved Alacrity. A spell marked `/*slowspell*/` needs Alacrity down,
  unless the mage's action list ran empty while it runs (`alacritycompromise`;
  `mage/mage_shared.tph`, line 363).
- Before it, when it can, the mage dispels the party's protections (lines 113-134; D3).

**In its own Time Stop** (18 seconds in the lab, learned.md section 1):

- Game time runs on, so SCS's round timer works as usual. While the timer runs, the mage waits:
  "in timestops, don't use missiles or melee (a little cheesy, and also it wastes time)"
  (`mage/ssl/meleeblocks/standard_mage.ssl`, lines 203-213).
- Then its blocks run as usual, except those gated by `!CheckSpellState(Myself,TIME_STOP)`:
  - the first dispel and Wish;
  - attacks on the party's defences;
  - Power Word Kill, Stun and Blind, and Trap the Soul;
  - the conjured blades, and Horrid Wilting on summons;
  - its renewal of defences, apart from the basic ones at the end.
- What depends on the target's state now is left out: effects land only when time resumes.

**Improved Alacrity** (`mage/ssl/combatblocks/alacrity.ssl`):

- Fifth in the core list, so it is the first core spell in a Time Stop: the first dispel and
  Wish before it are gated.
- Cast when an enemy is seen and Alacrity is down.
- SCS's own version (`DW#QALAC`) is an innate: casting time 9, then 12 seconds of aura
  cleansing.
- While it runs:
  - the round timer is cleared at once (`alacrity_kill_timer.ssl`, right below our hook);
  - slow spells wait;
  - sequencers and weapon attacks are off (`caster_shared/caster_definitions.ssl`, lines
    1213-1491).

**Sequencers and triggers:**

- SCS gives its casters generated innates (`DW#MS*`, `DW#SQ*`, `DW#TG*`). Each releases two or
  three spells at once through opcode 146 (`caster_shared/caster_shared.tph`, lines 859-925).
- Each high mage of the lab has one Minor Sequencer, one Spell Sequencer and one Spell Trigger.
  MAGE18C's release two Melf's Acid Arrows; Minor Spell Deflection, Minor Globe of
  Invulnerability and Improved Invisibility; Stoneskin, Spell Deflection and Protection from
  Magical Weapons.
- The innate (level 0, casting time 0, aimed at a creature) casts each of its spells at once at
  its target (opcode 146, type 1), then removes itself (172) and returns after 1440 seconds
  (171, delayed).
- SCS releases them in four ways (`caster_definitions.ssl`, lines 1211-1366), each after its
  round timer, none under Improved Alacrity, none at a target that cannot be targeted or carries
  `DO_NOT_TARGET_SPELLS`:
  - `Sequencer`: `ForceSpellRES(<innate>, target)`;
  - `SequencerMyself`, for the defensive ones: `ForceSpellRES(<innate>, Myself)`;
  - `SequencerManual`, "for anything with a saving throw" (line 1209):
    `ReallyForceSpellRES(<innate>B, target)` removes the innate and, for one second, makes the
    caster immune to silence, spell failure and deafness (opcodes 38, 60, 80) and casts 10 faster;
    then each spell with `ReallyForceSpell(target, spell)`, `SmallWait(1)` between. Only while the
    caster is not disabled and no Time Stop runs (`FIN_TIME_STOP_RUNNING`);
  - `SequencerMarker`: `ApplySpellRES(<marker>, target)`, then `ForceSpellRES(<innate>, target)`.
- SCS writes a wrong range into its triggers: `resolve_trigger_spells` reads the ability's effect
  count (offset 0x1E) as its range (offset 0x0E) (`caster_shared.tph`, line 1015). The lab's
  triggers read ranges of 1 to 9.

**Touch spells and conjured weapons:**

- **Harm** (`priest/ssl/combatblocks/touch_attacks.ssl`, lines 43-56): a party member within 10;
  not protected by Protection from Magical Weapons, spell turning, magic resistance, immunity to
  necromancy or magic damage resistance; above 10% of its hit points; the priest not shapeshifted
  and without a touch charge yet.
- Then the strike (`priest/ssl/meleeblocks/touchattack.ssl`): Attack the enemy with the worst
  armour class within 10, with the same exclusions and none with Mirror Image. It has no round
  timer, "so that the priest will attack until the power is triggered or lost".
- Mages cast Vampiric Touch directly at close enemies. Conjured weapons serve SCS's melee blocks
  between casts; Melf's Minute Meteors use SCS's own item `dw#melf` (`melfsetup.ssl`).

**What the engine does today:** in batch F3, SCS still cast Time Stop 33 times, Improved
Alacrity 9 times and its triggers about 30 times, in rounds the engine left to it. The engine
never chose them:

- Time Stop is no attack.
- Improved Alacrity's casting speed is worth nothing to D1.
- The triggers' wrong ranges keep most of them out of reach.

### D2: the engine's design (2026-10-20)

Like SCS first; per enemy later.

1. **Openers as rules** (`combat-intent/openers.lua`). They are checked before the ranking, as
   SCS's order puts them before attacks:
   - **Time Stop** when the caster sees an enemy that is not a summon or an illusion, no Time
     Stop runs, and its Improved Alacrity is down;
   - **Improved Alacrity** (aura cleansing, opcode 188) when an enemy is seen and it is down; in
     the caster's own Time Stop it comes first;
   - a profile switch, `openers`, so labs can compare.
2. **The caster's own Time Stop.** The adapter reports who holds a Time Stop and the seconds
   left.
   - Enemies are frozen: a cast that ends within the stop cannot be interrupted, and aims stay
     where they are.
   - What the caster cast during the stop lands when time resumes. Targets of its disables count
     as disabled, and its expected damage comes off their hit points, so it neither repeats a
     disable nor overkills.
   - Left out, as SCS does: spells whose SPLPROT check reads the target's hit points (the power
     words), weapons and touch charges.
   - Defences count only for the time after the stop.
3. **Under Improved Alacrity:** a spell with casting time 6 or more waits while a quicker option
   reaches the minimum worth (SCS's slow spells and its compromise; profile `slowSpeed`). No
   triggers.
4. **Triggers, after a lab probe:**
   - read as their spells together (the classifier already does), with the reach of their
     shortest-range spell instead of the wrong range;
   - released as SCS does: offensive ones through its manual way, the others with
     `ForceSpellRES` at the caster;
   - the probe checks whether `SpellRES`, `ForceSpellRES` and `ReallyForceSpellRES` walk to the
     wrong range, spend the innate and land.
5. **Touch spells and conjured weapons** (the combo):
   - read the created item (opcode 111) and its on-hit effects, per install;
   - cast a touch spell only when an enemy is within reach and the strike can follow at once;
   - strike, check that it landed (hit points, effects), and strike again while the charge
     lasts;
   - Harm only on a target the caster can hit, without Mirror Image, Stoneskin or weapon
     immunity, and when it is worth it;
   - a conjured weapon is worth the damage it deals between casts, which SCS's melee blocks
     deal.

**Order of building:**

- D2a: points 1 to 3, with lab batch G2 in the hard lab.
- D2b: the trigger probe and point 4.
- D2c: point 5.

### D2c as built: touch charges (2026-10-20)

**Reading** (`combat-intent/spells.lua`): a spell that creates an item for the caster (opcode
111) carries it as a weapon: attack type, range, speed, THAC0 bonus, damage, the item's flags
and enchantment, how many hits it lasts, and what one hit does (the item's ability read as a
strike, its sub-spells included). A melee weapon whose hit removes it (opcode 112) is a **touch
charge**. In the SR lab these are the Cause Wounds spells, Harm, Slay Living, Shocking Grasp and
Chill Touch; Ghoul Touch lasts several hits and is not one.

**The touch option** (`combat-intent/touch.lua`, `choice.lua`): cast on the caster, aimed at one
enemy.

- The enemy is alive, seen, without sanctuary and within `touchReach` of the caster (10 range
  units, as SCS).
- The strike would work there: no Mirror Image or Stoneskin skin takes the hit, no immunity to
  weapons (opcode 120) keeps the hand off, and no spell protection stops the strike or a spell
  it casts. One is enough, so a charge is not spent on a hit that does half its work. SR's Chill
  Touch hand is not magical: Protection from Magical Weapons lets it through, Protection from
  Normal Weapons does not.
- Worth: what the hit does to that enemy (damage and disable), times the chance to hit (the
  caster's THAC0 less the hand's bonus, against the enemy's armour class). A hit that leaves its
  target at least one hit point (Harm's opcode 208) cannot kill and counts the hit points above
  one.
- Cost: the spell's level, and the caster's hit points lost to melee weapons that reach the
  target's spot but not its own, for one and a half rounds, times caution. The threat picture's
  round would not tell the spots apart: in it every melee enemy within a round's walk strikes
  wherever the caster stands.
- None in the caster's own Time Stop or under Improved Alacrity (SCS keeps weapons out of both),
  and none while it holds a charge.

**The strike.** The adapter finds a charge by the item in the magic weapon slot (SLOTS.IDS 34):
the touch weapon of a spell the caster has memorized, read at its level, or else the item itself
when its melee hit removes it (SCS's own casts, scrolls). With a charge, the engine strikes
before anything else, at the reachable enemy where the hit is worth most times its chance. There
is no minimum: the charge is spent already.

- The response sets SCS's round timer, then `AttackOneRound` at `EEex_Target`. SCS picks the
  enemy with the worst armour class; the engine weighs the hit.
- While the creature swings or the timer runs, two rounds at most, the engine holds it, so SCS's
  own touch block does not take the charge elsewhere.
- Once the hand is gone, the strike is judged: did the target lose hit points, become disabled or
  carry an effect of the strike. A swing that misses leaves the hand, and the creature swings
  again. A charge spent without effect counts as a miss of its touch spell on that enemy, like a
  cast that left its target untouched, so the engine does not cast it there again.
- The log has `swing` and `strike` rows; the counts are `touches`, `strikes`, `strikeHits` and
  `strikeMisses`.
- Profile: `touch` (a switch) and `touchReach`.

**Seen in batch G3** (below): the hand lands in slot 34, `AttackOneRound` at `EEex_Target`
strikes, the hit removes the hand, SR's Harm deals its 90 damage, and the strike is judged a hit.

### D2c as built: weapon attacks (2026-10-20)

Christopher chose conjured weapons as an attack option of the engine, and asked why the engine
should leave any round to SCS ("Warum überlassen wir nicht alles unserer Engine? 0.2 passt aber
ansonsten."). So the minimum worth now separates a cast from a weapon attack, not the engine
from SCS.

**The weapon in hand** (`combat-intent/weapons.lua`, `choice.weaponOptions`). The adapter reads
the selected weapon (`sense.attack`): attacks a round, THAC0 with the weapon's own to-hit bonus,
the average damage of a hit, the damage type, range, flags and enchantment, and what a hit casts
or applies (the weapon's ability, classified). A launcher shoots the ammunition in the first
filled quiver slot: their to-hit bonuses add up, the ammunition's damage type counts, and the
higher enchantment (plain ammunition from a magical launcher hits as magical). A launcher
without ammunition is no weapon.

- An attack goes at each enemy that is alive, seen, without sanctuary, within the weapon's range
  (melee: `touchReach`) and not immune to it (opcode 120, the same rule as touch charges).
- Worth: a round of its hits on that enemy. Hits: the attacks a round times the chance to hit,
  less the hits Mirror Images and Stoneskin skins take first. A hit deals the weapon's damage
  (lessened by the enemy's resistance to its type, not by magic resistance or a save) and what it
  casts or applies (lessened by both; a spell protection stops that part only). The hits kill
  when those expected reach those needed, as likely as the last one lands. The group's focus
  counts half again, as for casts.
- Cost: for melee, the hit points lost standing next to the target (the same exposure as a
  touch strike), for one round, times caution. A weapon attack spends nothing else.
- **No minimum worth.** When no cast reaches `minValue`, the engine attacks instead of leaving the
  round to SCS; a weapon attack worth more than the best cast is taken over it.
- **SCS keeps some of those rounds.** In rounds without a cast worth it, SCS used to cast what the
  engine does not cast yet: summons, Breach and Dispel Magic, healing, raising, cures. So the
  engine leaves a round it would only attack in to SCS while the caster has such a spell ready
  that fits now (decline `scs-summon`, `scs-removal`, `scs-heal`, `scs-raise` or `scs-cure`, the
  spell logged as `kept`), until those spells become engine actions. The first version counted any
  such spell ready and kept 60 rounds in batch G3, most for cures nobody needed (Vocalize kept 20
  of one mage's), so only a spell that fits counts (Christopher, 2026-10-20: "nur wenn jetzt
  sinnvoll"). Profile switch `keepScsSpells`. A spell fits (`choice.fits`):
  - a summons: always;
  - healing: the caster is below `defer.selfHealth` or an ally it reaches below
    `defer.allyHealth` (where SCS's priests heal: 50% and 75%);
  - raising: an ally it sees lies dead with a body (not frozen, petrified or exploded), not a
    summons;
  - a cure: the caster or an ally it reaches has the condition: its state, the HELD stat for
    holds, LEVELDRAIN for drained levels, a petrified ally among the dead. Curses, deafness,
    imprisonment, fatigue and the casting pause show in nothing the engine reads, so a cure for
    those alone never fits;
  - removal: an enemy it sees has what the spell takes away. For a dispel and the spells that
    strip schools or types: a protection from a spell with time left (not an item's), Stoneskin
    skins, Mirror Images, invisibility, nondetection or blur. By opcode: an effect of that opcode.
    Sanctuary; invisibility; a summoned or illusory enemy for unsummoning and banishing. Clouds
    never.
  - A spell on the caster alone reaches only the caster: Vocalize fits only when the caster itself
    is silenced, and then SCS's silenced rule has given it the round already.

  For this, sense lists the dead allies a creature sees (`frame.fallen`: id, position, state and
  gender, from the area's back list and searched like sleepers, at most eight a frame), reads
  each creature's drained levels, and marks an enemy's protections with time left (`timed`:
  `m_durationType` 4096 in its timed list).

  Open: Spell Revisions' Greater Command wakes its sleepers after 6 seconds with a cure, which the
  classifier reads as a cure role, so the engine does not cast it, and it keeps a round only when
  an ally sleeps. Spells SR delivers through a helper creature (Ice Storm, Suffocate, Gust of
  Wind, Shocking Grasp) carry a summon role and keep the round whenever ready; the engine cannot
  cast the first three yet.
- None with a touch charge in hand (the strike decides where that goes), in the caster's own
  Time Stop or under Improved Alacrity.

**Spells that conjure a weapon** (`weapons.conjured`, the `arm` option): a spell whose item is a
weapon but no touch charge (Melf's Minute Meteors, Flame Blade, Black Blade of Disaster and the
like). Its attacks a round come from the item (opcode 1 while equipped: SR's meteors set five;
an added attack adds to the caster's own; half attacks decoded).

- Cast on the caster, aimed at the enemy in reach where the weapon is worth most.
- Worth: the hits it deals in the rounds it lasts (its uses at its attacks a round, or its
  duration), at most the horizon (three rounds). Cost: the spell's level, and for melee the
  exposure for those rounds.
- Not while the magic weapon slot holds an item: the next rounds attack with it instead.
- Profile: `weapons` (a switch).

**In the adapter.** A weapon attack is SCS's round timer, then `AttackOneRound` at `EEex_Target`,
like a strike. The engine holds the creature while it attacks, or while the timer runs and the
target lives, two rounds at most, so SCS's attack blocks do not send it elsewhere. Then it
records whether the target lost hit points meanwhile (from any hand). A target that died ends
the hold. The log has `swing` rows with `weapon=true` and `attack` rows; the counts are `arms`,
`attacks` and `attackHits`. A strike's target that died now counts as hit (it was a miss before,
because a dead creature was not read).

**Open:** a conjured weapon counts the damage of the rounds after the cast, while a cast counts
its own round. Those rounds are spent attacking, not casting. Whether that should cost something
is to be seen in the lab.

**Not yet seen in a lab.** A fight must show that `AttackOneRound` at `EEex_Target` attacks
with the selected weapon, that a conjured weapon lands in slot 34 and is selected, and how
often the engine attacks instead of casting.

### Batch G3: touch, triggers and weapons in game (2026-10-20)

One launch in the hard lab's quiet room: the touch probe, the four trigger probes and two fights
of each group with the engine (touch charges and weapon attacks on). The first attempt stopped
while loading because the lab's Lua still wrote into G2's folder (learned.md, section 6); the
second ran all nine phases and cleaned up.

**Touch probe** (SCS's PRIES12A with Harm beside a scriptless dummy of 100 hit points):

- The engine cast Harm on the priest, aimed at the dummy. The hand was in slot 34 when the cast
  ended; the engine struck at once with `AttackOneRound` at `EEex_Target`.
- The dummy went from 100 to 96 (the hand's hit) and to 6 (Harm's 90); the hand was gone, and the
  strike was judged a hit. The engine then cast Cause Light Wounds the same way.
- Not explained: in the last 15 ticks the dummy died and the priest lost 10 hit points while it
  cast Cause Light Wounds on itself. Six SCS-scripted fighters of the baseline save ask the gate
  in every phase and are not tracked; to check before the next touch fight.

**Trigger probes** (a scriptless copy of MAGE18C, engine off; its Minor Sequencer `DW#MS0` with
two Melf's Acid Arrows at a dummy 256 away, its Spell Trigger `DW#TG8` on itself):

| Action | Walk | Innate | Landed |
| --- | --- | --- | --- |
| `SpellRES` at the dummy | 256 to the wrong range | spent | both arrows |
| `ForceSpellRES` at the dummy | none | spent within 5 ticks | both arrows (250 to 199) |
| SCS's manual way (`DW#MS0B`, then each arrow) | none | spent by the B innate | both arrows |
| `ForceSpellRES` at `Myself` | none | spent | Stoneskin with 9 skins and the others |

- SCS's wrong range matters only for `SpellRES`; SCS itself releases with `ForceSpellRES` or its
  manual way and never walks.
- The trigger's spells take the caster's level: 9 skins for a level-18 caster.
- So D2b releases a trigger as SCS's `Sequencer` and `SequencerMyself` do, with `ForceSpellRES`,
  and takes its reach from its shortest-range spell.

**Four fights** (two of each group):

| Group | Won | Length | Group hp lost | Group dead | Foes dead |
| --- | --- | --- | --- | --- | --- |
| high | 2 of 2 | 99 s | 60 | 0 | 10 of 10 |
| mid | 0 of 2 | 100 s | 429 | 6 of 8 | 1 of 10 |

(Means per fight; length in game time.) As in G1, the hard lab overwhelms the mid group and the
high group wins with Time Stops (the engine's, 8 in two fights). The engine chose no touch spell,
strike, weapon attack or conjured weapon:

- **SCS kept every round the engine would only have attacked in**: 60 rounds, because the caster
  had a spell ready that the engine does not cast yet: 41 cures, 17 removals, 2 summons. Most of
  those are spells SCS casts only when their condition holds: Vocalize (SPWI219, against
  silence) kept 20 of MAGE12A's rounds; Remove Fear, Remove Paralysis, Cure Disease and
  Neutralize Poison the priests'. The weapon attacks in those rounds would have been
  MAGE12A's meteors and fists, PRIES12A's mace and PRIES10A's Spiritual Hammer.
- SCS used its own weapons: every mage held Melf's Minute Meteors (SCS's `DW#MELF`) from early
  on, the priests Spiritual Hammer, and PRIES12A cast Harm and Cause Light Wounds itself.
- **A strike that did not happen.** PRIES12A held SCS's Cause Light Wounds hand for 20 seconds, a
  fighter 40 to 90 away. The engine decided once in that time and found no option; in the other
  rounds SCS's timer ran or a hurt ally sent the round to SCS. Offline, with the same spell and
  item files and a fighter like the lab's (magic resistance 50, its items' protections), the
  engine strikes (worth 0.022). The trace does not show what the engine saw, so each decline now
  logs the charge in hand and why each enemy got no strike.
- AttackOneRound with a weapon and the conjured-weapon cast stay unseen in game.

### D3

- **Removing enemy protections:** Breach, Dispel Magic, Spell Thrust and the like. They are
  worth what they open for the group's attacks.

### Open

- **Adjusting within the round** (Christopher's idea): re-deciding while a round runs, for
  example when a threat appears before the cast starts. To think through together.
- **Quick single-target spells for allies,** such as Resist Fear and Remove Paralysis
  (Christopher's examples). Exceptions to agree with him, with their casting times.
- **On-hit buffs and shapeshifts.** The classifier reads 57 wizard and priest spells of the SR
  lab as a weapon or on-hit buff on the caster (learned.md, section 9). The engine uses the touch
  charges and conjured weapons among them (D2c, above), not yet the on-hit buffs or the
  shapeshifts.
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
