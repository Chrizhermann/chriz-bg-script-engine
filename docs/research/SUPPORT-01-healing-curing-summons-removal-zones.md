# SUPPORT-01 — Healing, curing, summons, removal and danger zones (D3)

Status: built (2026-10-20); lab batch H ran on 2026-10-20 and 21 (below). Christopher's go:
"Mach alles, dann Lab Tests."

## Question

Until now the engine left a round to SCS when a caster had a heal, cure, summons or removal ready
that fitted the moment (DEFENCE-01, "SCS keeps a round only when its spell fits now"). Christopher
(2026-10-20): the SCS-and-engine hybrid will never be played; SCS's fight AI is dropped, and the
engine should take every round it can. So the engine needs these decisions itself, with SCS's
fight logic as the blueprint (ideas, never code or files):

- heal itself and its allies, and drink potions;
- cure what keeps a friend out of the fight;
- cast summons;
- remove enemy protections;
- lead creatures out of harmful clouds and storms ("Natürlich. Wir können uns da gerne an SCS
  orientieren, aber ich bin auch offen für eine bessere Implementierung von selbst").

Raising the dead stays open: SCS's scripts never raise (below).

## What SCS does

From SCS's source ([src], read-only), credit DavidW.

**Healing** (`priest/ssl/generalblocks/renew.ssl`): a priest heals itself below 70% (Heal, else
the strongest cure wounds), drinks Extra or Superior Healing below 50%, and keeps Regenerate up
below 80%. It heals an ally below 50% with Mass Heal or Heal and below 75% with Mass Cure or
the cure wounds spells, strongest first. Allies count only above a level that rises with the
priest's own (`priest_shared.tph`, `minimum_healing_level`): level 1-3 priests heal allies above
level 1, 9-14 above their level less 5, 15-17 less 6, 18-20 less 7, and higher less 8. These
blocks come before its attacks. SCS's mages only drink potions.

**Curing** (same file and the priest's other blocks): blindness with True Seeing, Neutralize
Poison, Cure Disease or Heal; feeblemind with Heal; fear with Remove Fear; holds with Remove
Paralysis; sleep, confusion and stun with Exaltation (Icewind Dale spells); charm and confusion
with Spell Revisions' Remove Curse. Free Action only as a pre-buff. No restoration in a fight. The
same level rule applies to allies.

**Raising:** none. SCS's scripts never raise a fallen ally.

**Summons** (`mage/ssl/combatblocks/midlevel_summons.ssl`, `highpowered_summons.ssl`,
`priest/ssl/combatblocks/uber_summons.ssl`, `very_lowpowered_summons.ssl`): most summons are cast
at an enemy the caster targets (SCS's `SpellArea`): the elementals, the monster summonings, Animate
Dead (within 15), the Devas. A few go on the caster itself (`SpellMyself`) once it sees an enemy:
Gate, Summon Fiend, Death Knight, Mordenkainen's Sword, the genies. Nishruu and Hakeashar, which
eat magic, go at an enemy spellcaster. SCS summons one Deva at a time and chooses Summon Fiend by
the caster's alignment and the fiends already around; apart from that it counts no summons. Its
preparation blocks also summon before a fight, out of sight of the enemy (pre-buffs).

**Protection removal** (`mage/ssl/combatblocks/attacks_on_pc_defences.ssl`,
`attack_antimagic.ssl`, `first_dispel.ssl`, `remove_magic.ssl`, `kill_summons.ssl`; trigger blocks
in `ssl/library.slb`): SCS's mages breach an enemy with Stoneskin or protections from weapons,
damage or effects (`BreachTarget`; first those marked `PRIORITY_BREACH`: Chaotic Commands, Death
Ward, Protection from Magic Energy, PfMW). Spell Shield goes to Warding Whip, Secret Word, Spell
Thrust, Pierce Magic or Ruby Ray; turnings and other spell protections to the Breach, Power Word
Silence and Secret Word sequencer, Secret Word, Spell Strike, Ruby Ray, Warding Whip or Spell
Thrust; magic resistance from 40 up to Lower Resistance (also three at once). Dispel Magic goes at
an enemy with protections, enhancements or Stoneskin (`DispelTarget`), opportunistically early in
a fight (`first_dispel`), but not while one of the party is disabled, in an Insect Plague, under
Malison or (with Spell Revisions) turning to stone (`AvoidDispel`, `AvoidDispellingMalison`): the
dispel would free them too. Death Spell kills summoned creatures up to level 8. Timers of 12 to
18 seconds keep such casts apart.

**Danger zones** (`initial/detectcloud.tpa`, `genai/ssl/fleecloud.ssl`,
`mage/ssl/generalblocks/fleecloud.ssl`, `fleecloud_fm.ssl`): SCS gives each cloud and storm spell
an invisible marker creature that shouts a code for its kind every few seconds (404 Cloudkill, 405
and 409 Incendiary Cloud, Fire Storm and Meteor Swarm, 407 Storm of Vengeance, 408 Death Fog, 410
Web, 411 Stinking Cloud, 412 Ice Storm and Writhing Fog, 413 Suffocate and Cloud of Pestilence). A
creature that hears one within 15 to 20 (10 for 413) and can be hurt by it (its resistances, magic
resistance, Minor Globe, undead or demon for some) sets its `seencloud` timer and runs from the
marker (`RunAwayFromNoLeaveArea`), unless it is resistant enough and sees an enemy. A melee
creature that sees an enemy walks at it instead (`MoveToObject([PC])` when not within 8). A mage
or priest that sees no enemy and hears a cloud stands still (`NoAction`). Mages and priests escape
when their action list is empty or their round timer runs, so they break off a cast to flee while
the timer runs. Most of these blocks sit near the top of the scripts, above the engine's hook
(HOOK-01); in some general AI and monster scripts they come below it.

## The engine's design

### Healing and curing (D3a, D3b; built 2026-10-20)

`combat-intent/care.lua`. Heals and cures compete with attacks and defences every round, on the
attack's scale (shares of a creature), as protections do (DEFENCE-01):

- **Worth of a heal:** what the friend is worth at the horizon's end with the heal, less what it
  is worth without. Its worth counts the share of its hit points left then, the kill bonus as
  likely as it lives, and the rounds it is in the fight (alive and not disabled), each worth a
  round of disable. Harm runs as the defence slice has it (`defence.course`, from the threat
  picture). So a heal on a friend no one threatens is worth the hit points it restores, as damage
  on an enemy is worth the hit points it takes. On a friend about to fall it is also worth the
  rounds it keeps the friend standing, and the kill bonus if it saves it. A friend that falls
  before the cast lands gains nothing.
- **Worth of a cure:** what the condition would still keep the friend out of, as the same disable
  on an enemy is worth (hold 1, sleep 0.8, confusion 0.8, panic 0.7, silence 0.7 for casters,
  blindness 0.3, deafness 0.2 for casters, disease 0.1), for the seconds it has left (18 count in
  full), and the hit points poison would still take. A spell that heals and cures (Heal) counts
  both.
- **Who:** the caster itself; allies above SCS's healing level for the caster's level; not an ally
  another member of the group is already healing or curing (the director's reservations, as for
  disables). A spell cast at a creature reaches allies in its range and a round's walk beyond it
  (touch spells reach one range unit); the walk costs as casting time does. Area heals go where
  they help most; one that spares no one counts the enemies it heals against itself.
- **Cost:** the spell's level, its casting time and the walk; harm while casting can break it.
  Potions cost as a first-level spell and cannot be broken.
- **Potions:** the caster drinks healing or curing items it carries (quick slots and backpack)
  with `UseItem`, while uses are left.
- **What the engine reads:** each friend's level and IDS values, and the conditions on it with the
  seconds each has left, from its effect lists (`sense.guard`): sleep, holds, stun, panic,
  confusion, feeblemind, silence, blindness, deafness, disease, berserk, the casting pause and
  poison, with the hit points the poison will still take. A condition counts while its state
  still shows (holds: the HELD stat).
- **In game:** a heal or cure claims the allies it helps as soon as it is chosen; sanctuary does
  not keep it out. Once it ends it is judged: did a friend gain hit points or lose a condition.
- **No more hand-backs:** the engine no longer leaves a round to SCS for a hurt group or a silenced
  caster (the profile's `defer` is gone). A silenced caster has only the spells the engine lets it
  cast (Vocalize among them) and its potions.

Not yet: Regenerate (opcode 98), charmed allies (they show as enemies), petrification (an ally
turned to stone lies among the fallen), and curse or level drain, which show in nothing the engine
reads.

### Summons (D3c; built 2026-10-20)

`combat-intent/summons.lua`. Summons compete with attacks, defences and care every round, on the
attack's scale:

- **Worth:** each creature the spell brings is worth its fight over the horizon (the cast's
  remaining seconds of the 18): the share of an enemy its hits take (its attacks, THAC0 and damage
  against the enemies' mean armour class and hit points, as a weapon attack is worth), and the
  share of a friend its body spares, up to its own hit points, by drawing its part of the blows of
  the enemies that can strike. Each further creature draws a smaller part, so a horde is worth less
  than its count times one.
- **The creatures:** read from their CRE files (`adapters/eeex/resources.lua`: hit points, armour
  class, THAC0, attacks, strength, level, IDS values, items, slots and the opcodes of their own
  effects), the weapon in their first weapon slot and, for a launcher, the ammunition in the first
  filled quiver slot. Damage counts the weapon's dice and bonus, what its own damage effects add
  (opcode 12 in its normal mode on the creature hit: a summoned jelly's acid, an elemental's fire)
  and strength for melee (STRMOD's default bonuses). Summons from monster tables (opcodes 127 and
  331) name no creature and count as creatures of twice the spell's level.
- **Only fighters on the caster's side count.** A creature whose own effects remove its avatar or
  selection circle (opcodes 271 and 287: SCS's markers for its clouds and storms, a kit's helper)
  or that has no weapon is no fighter, and a spell that brings only such creatures is no summons
  at all (it may still be an attack or a defence). Opcode 67 aligns a creature with the creature
  it lands on in modes 0, 1 and 3, against it in mode 5, and takes the side from the creature's
  file in the other modes (IESDP). So a summons in mode 5 on the caster is hostile and never cast;
  one from the file joins only when that side is the caster's: Limited Wish and Wish bring their
  neutral genie (`WISH01`, `WISH02`, EA 128) and are not cast as summons.
- **Where:** a spell on the caster is cast on it; one at a point or a creature at the group's
  focus when it is in range, else at the nearest enemy in range, else at the point toward the
  nearest enemy at the edge of range (SCS casts most of them at an enemy).
- **Cap:** no summoned creature (GENDER.IDS SUMMONED) once the profile's `summonCap` (5, the
  game's own limit) summoned allies stand in view. Summoned demons and illusions do not count.
- **Cost:** the spell's level and its casting time; harm while casting can break it.
- **In game:** the adapter reads each creature once and caches it. A summons is judged when it
  ends: did summoned allies the caster did not see before now stand in its view (`conjure` rows,
  counts `conjured` and `unconjured`).
- **Not cast as summons:** images of the caster (Project Image, Simulacrum: opcode 236), changes of
  shape (opcode 151 replacing the caster itself, as the SPWI9xx innates of werewolves and
  doppelgangers do), and summons whose creatures land on another creature, whose side follows it.
  SCS keeps no more rounds for summons.

In the SR lab, 105 wizard and priest spells have a summon role: the engine casts 81 as summons when
their creatures fight for the caster, 18 are changes of shape, 3 images and 3 cast at another
creature (host census, nothing ran). Of the 89 creature entries they name, 68 are fighters and 21
markers, helpers or creatures without a weapon.

Open for Christopher: SCS summons one Deva at a time and picks Summon Fiend by alignment; the engine
has no such rules yet. SCS also summons before a fight (pre-buffs), which stays as it is.

### Protection removal (D3d; built 2026-10-20)

`combat-intent/removal.lua`. Removals compete with attacks, defences, care and summons every round,
on the attack's scale. Instead of SCS's fixed targets and timers, worth decides, seen from the
other side of combat-intent/defence.lua:

- **What it opens:** the enemy's loss under the caster's side's pressure over the horizon, with
  the protections it would lose gone, less with them (`defence.loss`; the side's pressure pictures
  the caster and its allies as the attackers, `removal.pressure`: weapons in hand, a caster's
  spells). PfMW on an enemy two fighters cannot hurt is worth much; on one no friend attacks with a
  weapon, nothing.
- **Its buffs:** what the enemy's haste, extra attacks and bonuses would take from a friend with
  its weapon (`defence.offense`).
- **What it frees:** the conditions the caster's side holds the enemy in, each worth what freeing
  a friend of it is worth for the time it has left (combat-intent/care.lua), and the weapon harm
  it gets back once a Slow or a penalty is gone. A dispel on a held enemy is worth less than
  nothing: SCS's `AvoidDispel` falls out of the sum, enemy by enemy.
- **Summoned enemies:** unsummoned or destroyed, a kill (Banishment's own condition, summoned
  creatures, holds by the spell's view of each enemy).
- **Chance:** a dispel takes each effect as likely as the engine's rule makes it (49% at the
  effect's caster level, 5% more a level above, 10% less a level below, none from five levels
  below, 99% at most); the removal lands as likely as magic resistance lets it (only when its
  effects can be resisted), the saving throw and its own chance.
- **What it takes** (IESDP): a dispel each effect that can be dispelled; Breach's kind (opcodes
  220, 221) every effect of each spell or item with a matching effect, up to the power level, but
  those that last after death; Secret Word's kind (229, 230) the matching effects of the first
  spell and the first item with such an effect above power 0; a removal by opcode (337) those
  effects. Stoneskin skins, Mirror Images and invisibility go with the spell that gave them.
- **Spell protections:** globes, turnings, deflections and traps compare the power of the effects
  a spell delivers, also of spells it casts at the target, not its level. Secret Word, Spell
  Thrust, Pierce Magic, Ruby Ray of Reversal, Khelben's Warding Whip, Pierce Shield, Spellstrike
  and Dispel Magic deliver power 0 and pass them; Breach delivers power 5 and a turning of level 5
  stops it, which is why SCS strips spell protections first. This holds for every spell the engine
  weighs now, attacks too (`targeting.protected`).
- **Where:** at an enemy it can see in range, at a point near the enemies it should reach (each
  enemy's spot and the middle of those around it), or around the caster; an area that does not
  spare friends waits while one stands in it. An area counts every enemy in it, also those it would
  free.
- **Attacks that also remove** stay attacks and add their removal's worth on each enemy they hit:
  Chromatic Orb's haste removal, Disintegrate's destruction of some creatures.
- **In game:** when a ready spell removes something from enemies, the adapter reads each enemy's
  active effects (`sense.wards`: opcode, parameter 2, source, school, secondary type, power,
  caster level, dispellable, timed, item, lasting after death, seconds left) and classifies each
  once by its fields. A removal is judged when it ends: did an enemy it was for lose effects,
  skins, images or its invisibility, or vanish (`strip` rows, counts `stripped`, `unstripped`).
- **SCS keeps no rounds any more.** With removal done, the profile switch `keepScsSpells` and its
  fitting rule are gone (DEFENCE-01); SCS's scripts never raise, so nothing is left to keep.

In the SR lab, 54 wizard and priest spells have a removal role: the engine casts 31 as removals and
12 as attacks with a removal; 2 are cures that would harm the caster's side as removals, 2 areas
for allies, 2 on the caster only, 3 changes of shape and 2 innates with unknown projectiles (host
census, nothing ran). Cures with a removal (Break Enchantment takes the Disabling type) are worth
less than nothing on an enemy and stay cures.

Not yet: invisible enemies the caster does not see are not in its frame, so an invisibility purge
or True Seeing has no worth unless the caster sees them (they would need to be remembered), and
debuff spells (Slow, Malison) are not cast for their debuff. A removal claims nothing in the group:
two casters may breach the same enemy while the first cast is under way.

### Danger zones (D3e; built 2026-10-20)

`combat-intent/zones.lua`, with the harm on a creature shared with the engine's attacks
(`combat-intent/harm.lua`). The engine reads the zones itself instead of listening for SCS's
markers, so it knows every zone, also those SCS marks not, and judges each by the creature in it:

- **What a zone is:** an area projectile (EEex's `CProjectileArea`) that has reached its place and
  has explosions left: clouds, storms, webs, Entangle, Spike Growth. The adapter reads them from
  the area's object lists once a tick (`sense.zones`): centre, radius (explosion range),
  explosions left and the ticks between them, who cast it (friend, enemy or unknown), whom it
  spares (the projectile's area flags) and the effects one explosion delivers, classified as a
  spell at the zone's caster level, with the spells it casts on each creature (opcode 146).
- **Harm of one explosion** on the creature: damage through its resistances, magic resistance and
  saves; disables it does not shrug off (Cloudkill's death only up to its levels); conditions
  (Stinking Cloud's spell failure counts as a silence, 0.7, blindness 0.3, deafness 0.2, disease
  0.1, casters' conditions a fifth on others); nothing when its spell protections keep the zone
  out or the zone spares its side.
- **Worth of leaving:** the explosions it would sit through in the next round if it stayed,
  counted from when it would be out, at most one per period where a zone makes those it hits
  immune to itself for a while (Spell Revisions' clouds, opcode 206), and no more than it is worth.
- **When:** leaving costs no spell, only the seconds of the walk, so the creature leaves when
  that is worth more than the walk's part of a round of its best other option. A creature that
  is held, webbed or entangled does not try. Zones do not count in the caster's own Time Stop.
- **Where to:** the shortest walk (16 directions, up to a round's walk) to a point beyond every
  zone that hurts it, moved to the nearest open spot of the area's search map
  (`EEex_Area_GetNearestOpenPosition`) as long as that still lies outside them, else the next
  way out. `MoveToPoint`, without SCS's round timer; held while the creature walks (twice the
  walk and a margin at most), then judged (`escaped` rows: out or not).
- **Staying:** a cast where the caster stands loses what the zones' explosions may break: each
  explosion during its casting time whose damage lands breaks it, counted from when the casting
  aura of the creature's last cast frees, so an explosion due for sure breaks it for sure (since
  `47755c6`, lab batch H5); a melee attack or strike counts what walking to its target and standing
  there does, so a creature fights its way out towards an enemy outside and thinks twice before
  walking into a cloud.
- **Mid-round:** while SCS's round timer runs and the creature is not casting, and when it sees
  no enemy, it still walks out of a zone that hurts it.
- **SCS's escape stands aside** (HOOK-01, rule 6): the installer gives SCS's escape blocks above
  the hook a last condition: they run when the creature sees no enemy or `BGSE_Zones` says no.
  `BGSE_Zones` is true while the gate would ask the engine (switches, registry, the scripts
  below, no backoff after an error), the choice is on, zones can be read and the creature is on
  the engine's side; but not while it casts, or swings in a strike or weapon round of the
  engine's, in a zone that hurts it and that the engine did not know when it chose the action:
  the hook cannot break an action its own block runs, so SCS breaks it off as it always did. So
  with no enemy in sight SCS's escape and its stand-still run as before; with one in sight the
  engine weighs the zones. SCS's escapes below the hook run only when the engine declines and
  stay as they are. In the SR lab's scripts 9,957 escape blocks in 1,078 hooked scripts get the
  condition (mage 5,201, priest 2,456, monster 1,360, fighter 940), all of them last (host run of
  the rule, nothing installed).

In the SR lab, 46 wizard, priest and innate abilities have an area projectile that explodes again
and again (host census, nothing ran). Most clouds explode every 75 ticks, ten times (Stinking
Cloud, Cloudkill, Web, Acid Fog, Incendiary Cloud); storms every 100 ticks, four times (Ice Storm,
Fire Storm, Meteor Swarm). Most deliver their effects through spells they cast on each creature.

Not yet: no protections against zones (Protection from Fire and the like); ways out do not prefer
spots that keep enemies in sight or range; the engine does not cast clouds for their lingering
harm on enemies (its zones are only dangers to its own); a cast under way is not broken off for a
zone by the engine itself.

## Lab batch H (2026-10-20 and 21)

The SR lab in one slot, the quiet room `BD0072`, Insane. Five launches, H1 and H2 in one install,
the others each in its own; every cleanup was clean.

- **H1** (build `72cd95b`): the zone probe (Stinking Cloud, Ice Storm, Acid Fog and Incendiary
  Cloud at rings of dummies) and two zone fights each with the engine and with SCS alone. Zone
  fights: the mid group against dummies, while the lab's party mage lays Stinking Cloud, Cloudkill
  and Incendiary Cloud on it.
- **H2** (same install): care fights `cmid` (the hard mid lab of DEFENCE-01; at fixed times the lab
  holds, panics, blinds or stuns a group creature, or wounds it to a third of its hit points), two
  high fights `rhigh` and a hard mid fight `gmid`, the engine and SCS alone.
- **H3** (`01d0297`, after the zone fix `8b36373`): the potion probe, two care fights and three zone
  fights each with the engine and SCS alone.
- **H4** (`ea6a130`, with the hold `254eeaa`): two care fights with the conditions on the priests,
  one with SCS alone, a high, a hard mid and a zone fight.
- **H5** (`b9dd589`): the minimum worth in the care lab (below).

### Danger zones (D3e)

- **The probe** measured what the engine reads (docs/learned.md, section 5): clouds and storms are
  area projectiles in the area's `m_lVertSort`, an explosion comes every delay+1 ticks, the next in
  counter+1, explosion range 256 reaches 252 pixels and not 280 (heights 4/3), the game runs 15
  ticks a second.
- **Fixed after H1** (`8b36373`): a live projectile's number is its PROJECTL.IDS entry, one less
  than a spell's projectile field, so the classifier had read the neighbouring PRO file (its area
  filter and shape); `EEex_Area_GetNearestOpenPosition` needs the creature's personal space, and
  without it every way out went to the raw point; and the engine now counts from when the next
  explosion comes.
- **Time in the lab's clouds**, summed over the group's four casters (ticks):

  | Fight | Engine | SCS alone |
  | --- | --- | --- |
  | H1, 1 | 1,458 | 3,735 |
  | H1, 2 | 1,782 | 3,444 |
  | H3, 3 | 1,773 | 3,624 |
  | H3, 4 | 1,515 | 4,464 |
  | H3, 5 | 2,151 | 3,744 |
  | H4, 6 | 1,836 | – |

  The engine cut the time in clouds by 43 to 66%. With the engine every group creature lived
  through all six zone fights; with SCS alone the level-8 mage died in one H3 fight and ended the
  other two at 3 and 4 hit points.
- **Ways out:** 51 chosen, 44 got out, 4 did not and 3 were still under way when the fight ended;
  no zone failure. All 31 ways out of H3 and H4 lay on the search map's 16 by 12 grid.
- SCS's own run-away (action 355) still ran 5 to 28 times in each zone fight with the engine,
  against 42 to 78 with SCS alone, in rounds the engine left to SCS: while a creature sees no enemy
  SCS's escape runs as before (D3e), and the engine also leaves rounds to SCS while SCS's round
  timer runs. Not analysed further.

### Healing, curing and potions (D3a, D3b)

- 36 of the engine's heals, cures and drinks were judged in the care, high and hard mid fights,
  and 28 helped: a friend gained hit points or lost a condition. 25 drinks started.
- **Globes** (fixed in `ea6a130`): two of the misses were Remove Paralysis and Resist Fear cast at a
  held or panicked mage in SCS's Minor Globe of Invulnerability, which keeps out spells of levels 1
  to 3, beneficial ones from allies too; SCS's priests cast Remove Paralysis into it twice as well.
  Friends now carry their spell protections, and a heal, cure or defence leaves out a friend they
  keep it from (docs/learned.md, section 9: from the creature itself turnings and the like stop
  nothing and a globe only a hostile spell; what an explosion delivers passes turnings,
  deflections and traps). So an area attack now counts against a spell-turned enemy too. In H4 no
  cure went to a mage in a globe.
- **The rest were drinks:** one replaced by SCS's attack block while it waited for the casting
  aura (H3), the others drunk while the drinker lost more hit points than the potion gave, or
  replaced the same way in H2's build; the judgement compares hit points, so the logs do not tell
  these apart.
- **Invisible allies** (fixed in `01d0297`): in H2's care fights the held mid mage stood under
  Improved Invisibility. SCS's priests cast Remove Paralysis on it; the engine's never saw it as an
  ally, because a creature's frame left out every invisible creature unless it sees invisible
  ones. Invisibility now hides a creature from its enemies only.
- **The engine's own action** (fixed in `254eeaa`): a potion chosen while the casting aura of the
  creature's last cast ran became its action at once and waited for the aura; the engine then left
  the round to SCS for SCS's timer, and SCS's attack block below the hook took the drink's place
  (once also a Remove Paralysis 11 ticks into its casting). The engine now holds its own cast or
  drink while it is the creature's action: while the aura runs or a Time Stop freezes the creature,
  and for its casting time and 45 ticks from the latest of its start, the aura last seen busy and
  time resuming. The potion probe showed that a drink started on a frozen creature works when time
  resumes.
- **Hold (II)** (opcode 185) counts apart from holds: opcode 162, the cure of holds, leaves it.
- **H4, conditions on the priests:** a panic on a priest got Resist Fear from the other priest and
  ended; a hold got Remove Paralysis 63 ticks after it landed, and damage broke the cast. The
  engine then left the rest of SCS's round timer to SCS, whose blocks attacked.

### Summons (D3c)

- The engine cast summons in the care, high and hard mid fights: Animal Summoning IV, Conjure
  Lesser Water and Earth Elemental, Conjure Earth Elemental, Animate Dead, Aerial Servant and
  Summon Dark Planetar.
- **The judgement** (fixed in `b9dd589`) counted only new allies of a summoned gender, so the Dark
  Planetar (female) and Animate Dead's skeletons (neither) came but counted as failures. A summons
  is now judged by new allies of the creature files it names, and one that also brings creatures
  from monster tables by new summoned allies as well.
- In the three high fights both mages opened with Time Stop at once (SCS alone does the same), and
  everyone else stood frozen for 36 seconds; each time a priest's summons started before the stops
  brought nothing when time resumed, though its casting aura had passed its casting time. Why is
  unknown (docs/learned.md, section 2).
- In the care fights the engine summoned less than SCS alone. Conjure Lesser Water Elemental stood
  in the engine's top three 54 times (score 0.02 to 0.48, median 0.13: worth less 0.25 for its
  level and casting time), led 20 times and was cast 10 times; SCS alone cast it 2.5 times as often
  for the time its casters lived (below). A summons counts its creatures' fight over the horizon,
  three rounds; the elementals stay about two minutes.

### Protection removal (D3d)

The engine chose no removal: in these fights a removal option did not arise, was out of reach (8
times) or was worth less than nothing (Spell Thrust twice in a high fight). SCS's Breach and Dispel
Magic in the engine's fights came in rounds the engine left to SCS. D3d has not run in game yet.

### The engine against SCS in the care lab

Sixteen care fights in H2 to H5 (the lab's conditions on the mages in H2 and H3, on the priests in
H4 and H5): the engine with its minimum worth of 0.2 in eight, with 0.05 (the lab's `low` mode,
H5) in four, SCS alone in four. The party's six members have 724 hit points in all.

| | Engine, 0.2 | Engine, 0.05 | SCS alone |
| --- | --- | --- | --- |
| Group creatures lost (of four a fight) | 19 (2.4 a fight) | 11 (2.8) | 8 (2.0) |
| Party members killed | 4 (0.5 a fight) | 2 (0.5) | 4 (1.0) |
| Party hit points left (mean) | 448 | 500 | 370 |
| Casts a creature-minute alive | 4.8 | 5.2 | 6.6 |
| Weapon rounds (a spell scored higher) | 148 (64) | 17 (6) | none |

- **The minimum worth is not the cause.** Since D3 SCS keeps no round, and a weapon round needs no
  minimum: when no spell reaches 0.2 the caster attacks, even with a lower worth than the best
  spell (DEFENCE-01, D2c: "0.2 passt aber ansonsten"): mages punched with their fists at a median
  worth of 0.005. With 0.05 the casters swung far less and cast a little more often, yet the group
  lost more and dealt less harm. The minimum worth stays at 0.2.
- **Less harm to the party:** SCS alone took 354 of the party's hit points a fight, the engine 276
  (0.05: 224), and SCS killed twice as many.
- **Fewer casts:** between two casts of one creature both took a median of 96 ticks, but the
  engine's casters spent more rounds with a weapon or without an action.
- **Summons:** SCS's lead came from the two fights in which its water elementals fought long:
  they took 436 and 518 of the party's hit points, its other two 194 and 270, about what the
  engine took. While a water elemental fought on the group's side, the party lost hit points about
  twice as fast (six fights: 2.9 to 5.9 a second, against 1.6 to 3.1 without; the jaguars of
  Animal Summoning IV did not change it). SCS alone cast Conjure Lesser Water Elemental 3.8 times
  in ten creature-minutes, the engine 1.5 (with 0.05: 4.7, three of them broken in the Ice Storm
  below). The engine counts a summons' fight over three rounds.
- **The Ice Storm** (fixed in `47755c6`): in one fight with 0.05 the level-12 mage began Conjure
  Lesser Water Elemental three times inside the party's Ice Storm (2d8 cold every 6.7 seconds, no
  save); each time the next explosion broke the cast in its last ticks, and the group was gone
  after 42 seconds. The engine knew when the explosion would come and that its damage lands, yet
  gave the cast a 37% chance (e^-1, as if explosions came at random). The second cast began 4
  ticks late, when the casting aura of the first freed.

In the other labs: in the zone fights the engine kept every group creature alive (SCS alone lost
its level-8 mage once); in the high fights both won every fight, in 107 to 116 seconds with the
engine and 114 with SCS alone, with about the same hit points left.

## Christopher's answers (2026-10-21)

- **Judge by effect:** what counts is whether the engine's groups beat their enemies better and
  would react more intelligently to a human player, not whether they match SCS.
- **Spell slots:** a slot costs less when the caster has more spells left than rounds it can
  expect to live ("ja, auf jeden Fall"). To build.
- **Summons:** many factors: early in a fight good, mid-fight it can be good, late situational;
  the kind of summons; the summoner, who may prefer summons over other spells. How far to model
  it is open.
- **Time Stop:** Christopher is fixing durations that run on for others during a Time Stop; the
  double Time Stop's side effects are left alone here.
- **Testing:** both his own playtests (docs/playtest.md) and a lab party that plays like a human.
- **Protection removal:** Secret Word is probably undervalued against the player. Only very few
  AI mages, if any, should use combos such as Improved Alacrity and then Secret Word again and
  again at the party (Entropy Shield gone at once, the next spell at once); Irenicus is a
  candidate for such nasty combos. Design with Christopher.
