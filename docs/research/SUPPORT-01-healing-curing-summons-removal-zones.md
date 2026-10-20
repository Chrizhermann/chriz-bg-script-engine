# SUPPORT-01 — Healing, curing, summons, removal and danger zones (D3)

Status: built (2026-10-20); lab batch H next. Christopher's go: "Mach alles, dann Lab Tests."

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
- **Staying:** a cast where the caster stands loses what the zones' explosions may break (each one
  whose damage lands breaks it); a melee attack or strike counts what walking to its target and
  standing there does, so a creature fights its way out towards an enemy outside and thinks twice
  before walking into a cloud.
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

Not yet: the projectile's tick counts assume 15 ticks a second, and which list holds the zones
and what its fields mean in play are unchecked (lab batch H); explosions count spread evenly (the
counter to the next one is read but not used); no protections against zones (Protection from
Fire and the like); ways out do not prefer spots that keep enemies in sight or range; the engine
does not cast clouds for their lingering harm on enemies (its zones are only dangers to its own);
a cast under way is not broken off for a zone by the engine itself.
