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
  full), and the hit points poison would still take (as often as it strikes by its type, over
  its first minute, as the classifier counts poison; SPELLS-01). A spell that heals and cures
  (Heal) counts both.
- **Who:** the caster itself; allies above SCS's healing level for the caster's level; not an ally
  another member of the group is already healing or curing (the director's reservations, as for
  disables). A spell cast at a creature reaches allies in its range and a round's walk beyond it
  (touch spells reach one range unit). Since 2026-10-28 one walk rule holds for heals and attacks
  ([FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md), "Positioning in the casting pause"): the
  walk at the caster's pace comes first and lowers the worth (6 / (6 + seconds)), and a friend
  that falls during the walk and the casting gains nothing; a caster that cannot walk reaches no
  one beyond its range. Until then the walk cost as casting time does. Area heals go where they
  help most; one that spares no one counts the enemies it heals against itself.
- **Cost:** the spell's level and its casting time; harm while casting can break it.
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

- **Worth:** each creature the spell brings is worth its fight over the rest of the fight after
  the cast (below): the share of an enemy its hits take (its attacks, THAC0 and damage against the
  enemies' mean armour class and hit points, as a weapon attack is worth) while it lives, and the
  share of a friend its body spares, up to its own hit points, by drawing its part of the blows of
  the enemies that can strike. Each further creature draws a smaller part, so a horde is worth less
  than its count times one. It lives until the blows it draws have taken its hit points, and fights
  no longer than the summons lasts: opcode 67 unsummons its creature when the effect ends, unless
  it is permanent (IESDP); a summons through an EFF lasts the 177's duration (`e468f19`).
- **The rest of the fight** (`threat.rest`; agreed with Christopher 2026-10-22, before that the
  horizon of 18 seconds): round by round, each side's harm (the weapons of its creatures that are
  not disabled, against the other side's mean armour class, and its casters' spells at 1.2 hit
  points a caster level) falls on the other side's creatures one by one, the one that deals the
  most harm for its hit points first; a fallen creature deals no more harm, and Stoneskin skins and
  Mirror Images take a weapon hit each first. It ends when a side has no one left, at most the
  profile's `fightCap` (60 seconds). So an early summons counts much and a late one little; the
  kind of summons is in its creatures' worth. The choice record keeps the estimate (`rest`).
  Preferences of single summoners come with the per-fight design. (Until 2026-10-29 both sides'
  harm stayed whole until one side was dead and skins counted nothing: the starts of lab batch J's
  fights, which lasted 55 to 193 seconds, counted 7 and 13; FIGHT-01, "How long the fight lasts".)
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
- **One the other side charmed** (since 2026-10-29; FIGHT-01, "Freeing a member the party
  charmed"): an enemy in the charmed state, freed when every charm on it goes, worth the same charm
  on an enemy for the time it still has; its other effects count neither way then. A tactic by wit.
- **Chance:** a dispel takes each effect as likely as the engine's rule makes it (49% at the
  effect's caster level, 5% more a level above, 10% less a level below, none from five levels
  below, 99% at most; IESDP, opcode 58); the removal lands as likely as magic resistance lets it
  (only when its effects can be resisted), the saving throw and its own chance.
- **Insight** (since 2026-11-03; Christopher: knowing it 100% would be dumb, "Außer vielleicht ein
  Irenicus oder so"): the effect's caster level in that rule is what the caster believes, by wit,
  not the engine's number. A clever caster guesses whoever cast the protection: the enemy itself
  when it casts spells, else the strongest caster on its side in view, and at least what a spell
  of that level takes (a sixth-level protection is the work of level 11 or more). A normal one
  takes the enemy's own level and is less sure (a spread of 4 levels instead of 2). A dull one
  counts the base 49%, as if the levels were equal. What the group has seen dispels do to the same
  spell's effects on that enemy narrows the guess (effects that stayed make a higher level likelier,
  effects that went a lower one; a normal caster takes in half), and an area dispel is worth one
  try at enemies no dispel has been tried at: until then each of their effects counts at least 49%
  ("generell ein mal zu casten, damit es AOE auf mehrere weg ist"). Orders `insight='exact'` give a
  special boss the engine's numbers; 'estimate', 'rough' and 'none' set the others by hand.
- **Screens** (built 2026-11-08; Christopher's decisions of 2026-11-04): opcode 101 against
  opcode 58 stops the dispel part, even one that always dispels. Opcode 206 against a spell the
  removal delivers stops that branch. Other removals by secondary type, school or opcode still
  work. The classifier can leave out blocked deliveries without making the spell partial; it
  reads a relevant set once and keeps it, using only the plain records already read. A ward
  unrelated to the spell needs no second classification. No screen spell or secondary type is
  named in the policy. The adapter keeps these wards until they expire, also with less than
  a round left: a removal that lands now still meets them.
  A clever caster reads these wards, a normal one when it notices the tactic in that decision,
  a dull one never. Exact insight reads them always. Missing a screen may waste a dispel; what
  the group learns from its result stays as above.
  Taking a screen down earns half (`removal.screenFollow=0.5`) of what the best next removal
  still ready would open on that enemy. The current copy is spent first, a following area must
  spare friends, surviving wards still protect, and the following removal looks no further.
  What the first cast opens itself still counts, so Pierce Shield and Spellstrike can combine
  that opening with the following Breach. The share is for tuning in batched lab fights.
- **Dispel releases** (built 2026-11-08): a sequencer, contingency or trigger release with a
  dispel gets one tenth of its removal worth (`removal.sequencerShare=0.1`), also when removal
  accompanies an attack. It remains allowed; a release without a dispel keeps its worth.
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
  active effects (`sense.wards`: opcode, parameters 1 and 2, resource, source, school, secondary type, power,
  caster level, dispellable, timed, item, lasting after death, seconds left) and classifies each
  once by its fields. A removal is judged when it ends: did an enemy it was for lose effects,
  skins, images or its invisibility, or vanish (`strip` rows, counts `stripped`, `unstripped`). A
  dispel that rolls also teaches the group, per enemy and spell, the share of the effects a dispel
  can take that stayed and went (`removal.learn`; when none went, only as likely as the dispel got
  through magic resistance), for this session only; the `choice` row tells the level it works at
  (`at`) and the insight, the `strip` row how many enemies taught (`learned`).
- **SCS keeps no rounds any more.** With removal done, the profile switch `keepScsSpells` and its
  fitting rule are gone (DEFENCE-01); SCS's scripts never raise, so nothing is left to keep.

In the SR lab, 54 wizard and priest spells have a removal role: the engine casts 31 as removals and
12 as attacks with a removal; 2 are cures that would harm the caster's side as removals, 2 areas
for allies, 2 on the caster only, 3 changes of shape and 2 innates with unknown projectiles (host
census, nothing ran). Cures with a removal (Break Enchantment takes the Disabling type) are worth
less than nothing on an enemy and stay cures.

Not yet: invisible enemies the caster does not see are not in its frame, so an invisibility purge
or True Seeing has no worth unless the caster sees them (they would need to be remembered). A
removal claims nothing in the group: two casters may breach the same enemy while the first cast is
under way. Debuff spells (Slow, Malison) are cast for their debuff since F2b (FIGHT-01), and a
removal with a debuff (Spell Revisions' Slow) adds both.

The spell mod's installed files were read on the host on 2026-11-08, without launching a game:
Dispelling Screen (`SPWI510`) uses 101/58 and 206 against `SPWI513B`, both under its own
secondary type (31 in that install). Dispel and Remove Magic end with 221 against that type;
Breach delivers its old payload in `SPWI513B` and the screen removal in `SPWI513C`. Pierce
Shield and Spellstrike carry their own removal of the same type. Those seven parent spells
classify without a partial reading. The screen's number is read from data, not assumed by the AI.

Pierce Magic (`SPWI608`) calls `CBMBPM` through opcode 402. Its installed Lua floors half the
target's current magic resistance, clamps the reduction to 10..40 points and keeps it for 30
seconds. `spells.lua` describes this known function, regardless of which spell calls it;
`harm.weakened` counts its target-dependent reduction when the caster weighs an opening. An
unknown function remains unknown. This is the one description of Lua behaviour that cannot be
read from the SPL's effects alone.

Host checks use renamed synthetic spells, secondary type 41, independent and lasting screens,
blocked payloads and surviving branches, two ready copies and spent or unusable follow-ups,
normal tactic draws, dull and exact insight, releases and a screened group. In the fixed example
(level-15 caster, one fighter, a foe under Protection from Magical Weapons), unscreened Breach
stays at 0.5905405405 and dispel at 0.2893648649. A screened dispel used to be rejected as
protected (worth 0); it now takes only the screen and is worth 0.1446824324 when a second dispel
is ready. That second dispel, after the screen is gone, is worth 0.2893648649. With no follow-up,
the screen alone earns nothing. These are logic results, not measurements of a fight.

Not yet in game: screen absorption, its timing, the resulting choices and both tuning shares.
Entropy Shield and the protagonist's special petrification/imprisonment are not implemented
here: once their files exist, read their delivered effects, breakable wards, target conditions
and cures. If Entropy Shield uses new Lua functions or unclassified effects, those need meanings
in the classifier and removal valuation. The protagonist's new states need recognition in the
snapshot, targeting and threat valuation so the statue remains attackable at low priority,
plus its cure and whole-party defeat rules. Neither can be inferred from spells not installed.

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
  saves; disables it does not shrug off (Cloudkill's death only up to its levels); conditions that
  weaken, by the share of the creature's fight they take (`harm.debuff`, since F2b: Stinking
  Cloud's spell failure takes most of a mage's fight and little of a fighter's; until then fixed
  values, a silence's 0.7 for spell failure, blindness 0.3, deafness 0.2, disease 0.1); nothing when
  its spell protections keep the zone
  out or the zone spares its side. Turnings, deflections and traps that count down keep it out
  only for as many explosions as their levels last: each explosion that reaches the creature takes
  its sub-spell's power from them, and they stop the last one even with fewer levels left
  (`targeting.stopped`, lab batch H7); the explosions after that hurt and break casts.
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
- **SCS's escape stands aside** (HOOK-01, rule 6): the installer gives SCS's escape blocks, its
  mages' run from a Cloudkill before they see the enemy and its stand-still while it hears a
  cloud (above the hook) a last condition: they run when `BGSE_Zones` says no. `BGSE_Zones` is true while the gate would ask the engine (switches,
  registry, the scripts below, no backoff after an error) from the script that decides for the
  creature (the first hooked script in its stack, since 2026-10-25 also for a lower script's
  blocks), the choice is on for that script's family, zones can be read
  and the creature is on the engine's side; with no enemy in sight only when the engine has a way
  out of a zone that hurts the creature (its claim then leads it out); and not while it casts, or
  swings in a strike or weapon round of the engine's, in a zone that hurts it and that the engine
  did not know when it chose the action: the hook cannot break an action its own block runs, so
  SCS breaks it off as it always did. So with no enemy in sight and no zone hurting the creature,
  SCS's escape and stand-still run as before. SCS's cloud blocks below the hook run only when the
  engine declines and stay as they are. Until 2026-10-22 the escapes ran whenever the creature
  saw no enemy and the stand-still always (lab batch H7, below); until 2026-10-23 the run from a
  Cloudkill always (lab batch H8, below). In the SR lab's 1,148 hooked scripts 11,496 blocks get
  the condition, all of them last: 9,957 escapes (mage 5,201, priest 2,456, monster 1,360,
  fighter 940), 952 stand-stills (mage 560, priest 307, monster 85) and 587 runs from a Cloudkill
  (mage 585, monster 2; host run of the rule, nothing installed).

In the SR lab, 46 wizard, priest and innate abilities have an area projectile that explodes again
and again (host census, nothing ran). Most clouds explode every 75 ticks, ten times (Stinking
Cloud, Cloudkill, Web, Acid Fog, Incendiary Cloud); storms every 100 ticks, four times (Ice Storm,
Fire Storm, Meteor Swarm). Most deliver their effects through spells they cast on each creature.

**Own clouds** (built 2026-10-23; Christopher: "Ich würde eine Mischung aus A und C machen"):
until then the engine weighed its own cloud by one explosion. In the eighteen care fights of H2
to H7 the level-12 mage never chose Ice Storm (four explosions); SCS alone cast it in three of
its six care fights (six casts, four storms landed), mostly at the party's fighters, and the
lab's fighters stayed for two to four of a storm's explosions. In three of the engine's fights
the storm came from SCS's script, in rounds the engine declined. Now an area of the caster's own
that explodes again and again counts the explosions each enemy inside is expected to sit through
(CHOICE-01, "Lasting areas"): the cheaper of staying and walking out, mixed with the chance that
the enemy stays anyway.

- **What the group sees:** the adapter looks at each zone at most every 5 ticks, from the view of
  a creature of the engine's side that decides and sees enemies. An enemy inside a zone that
  hurts it (its resistances and spell protections as the engine reads them) and able to walk is
  remembered with the zone's explosions left; still inside after further explosions, it stayed
  for each of them; seen outside while the zone lasts, it left once. What the group has seen
  lives only in the session (at most `cacheLimit` enemies, `inspect().stays`) and is shared by
  the whole side. A load forgets it, as it forgets the engine's other session state: object ids
  are the session's own (until 2026-10-23 it outlived a load).
- **Projectiles:** the reader takes the delay between explosions (offset 0x210), and from the
  area flags bits 8 and 9 (the repetitions are the caster's wizard or priest level) and 14 (the
  first explosion affects no one and does not count; IESDP). No area projectile of the SR lab
  sets bit 8 or 9. The first explosion goes off when the projectile lands (docs/learned.md).
- **Friends in the area:** an area that does not spare friends no longer waits while an ally or
  the caster stands in it where it does nothing to them (CHOICE-01, "Areas").
- Not tried in the lab yet.

Not yet: no protections against zones (Protection from Fire and the like); ways out do not prefer
spots that keep enemies in sight or range; a cast under way is not broken off for a zone by the
engine itself; spells such as Cloudkill count by their main kind alone (the disable), so their
damage on enemies above its levels does not count; what a deflection is worth against the
enemies' other spells once a cloud has used it up does not count either; a ranged attack the game
walks closer to its target first can lead into a zone (lab batch H8, below).

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
  expect to live ("ja, auf jeden Fall"). Built 2026-10-22 for every kind of spell option
  (CHOICE-01, "Spell slots"); not yet tried in the lab.
- **Summons:** many factors: early in a fight good, mid-fight it can be good, late situational;
  the kind of summons; the summoner, who may prefer summons over other spells. Agreed 2026-10-22:
  a summons counts over the expected rest of the fight, at most its own duration (built the same
  day, "Summons" above); single summoners' preferences come with the per-fight design.
- **Time Stop:** Christopher is fixing durations that run on for others during a Time Stop; the
  double Time Stop's side effects are left alone here.
- **Testing:** both his own playtests (docs/playtest.md) and a lab party that plays like a human.
- **Protection removal:** Secret Word is probably undervalued against the player. Only very few
  AI mages, if any, should use combos such as Improved Alacrity and then Secret Word again and
  again at the party (Entropy Shield gone at once, the next spell at once); Irenicus is a
  candidate for such nasty combos. Design with Christopher.

## Lab batch H6 (2026-10-22)

Ten fights in one launch with the zone break chance (`47755c6`), the spell-slot share (`9d65843`)
and invisibility counted once (`fe03fc4`): eight care fights (conditions on the priests), the
engine six times and SCS alone twice, then two zone fights of the engine.

| | Engine, H6 | Engine, H4 and H5 | SCS alone, H4 to H6 |
| --- | --- | --- | --- |
| Care fights | 6 | 4 | 5 |
| Group creatures lost a fight | 2.3 | 2.3 | 2.4 |
| Party members killed a fight | 0.5 | 0.5 | 1.2 |
| Party hit points left (mean) | 474 | 443 | 393 |
| Group hit points left (mean) | 160 | 150 | 149 |
| Summons cast a fight | 1.8 | 2.0 | 3.0 |
| Weapon rounds a fight (a spell scored higher) | 7.8 (4.5) | 9.8 (7.0) | none |

- **As safe, less deadly:** the engine keeps its group alive as well as SCS alone, yet kills fewer
  of the party and leaves it more hit points. The slot share and the invisibility fix changed
  little here.
- **The slot share** was below 1 in 116 of the engine's 197 choices in H6 and below a half in 81:
  under the party's fighters the casters expect to live a round or two. Weapon rounds while a
  spell scored higher fell from 7.0 to 4.5 a fight.
- **Summons stay the gap:** SCS alone cast 3.0 summons a fight, the engine 1.8.
- **The Ice Storm again:** in two fights the level-12 mage began Conjure Lesser Water Elemental
  inside the party's Ice Storm twice; three of the four casts had the storm's next explosion
  inside their 4.8 seconds of casting (2.0, 3.5 and 3.8 seconds away), and two of those broke
  when its damage landed (the mage's hit points fell mid-cast). Offline the same storm gives such
  a cast no chance, so the engine saw something else in game. Before each of the three the mage
  had been attacking with its weapon (AttackOneRound, AttackReevaluate). Suspicion: the casting
  timer the engine reads as the casting aura also runs during attack rounds, so it thought the
  cast would begin after the explosion. The choice record now keeps the aura, the chance the cast
  finishes and the zones around the caster (`a814cdb`); a short lab run decides.
- **Zone fights:** the engine kept every group creature alive, as before.

### The Ice Storm, found (`9b60759`)

The casting aura was not the cause: the H6 samples show the mage's casting counter at −1 (free)
during and after its weapon round. SCS pre-buffs the mage at the start of each fight with
Protection from Missiles (`DWSW311`, 60 seconds), whose immunities by projectile name arrows,
bolts and the like by their PROJECTL.IDS entries, arrows at entry 1. The engine compared each
immunity with the spell's projectile field both as it is and one below it, so entry 1 also
matched field 1, no projectile, which the sub-spell Ice Storm casts at each creature it hits
(`SPWI404D`) has. So the mage counted the storm harmless: its casts there kept their full worth
and no way out was worth anything. The storm's damage did reach it (13 hit points about ten
ticks after an explosion, Stoneskins untouched), and its explosions broke the casts. Now only the
entry one below the field counts (docs/learned.md). The same false protection, there since the
director's first slice, hid every Spell Revisions area spell that works through such a sub-spell
(the clouds, Glitterdust, Horror, Breach) from any creature under Protection from Missiles, as a
zone and as a target. A lab run with the new build checks the mage in the storm.

## Lab batch H7 (2026-10-22)

One launch with the projectile fix (`9b60759`, build `0d0ea6f`): a shield probe, four care fights of
the engine (conditions on the priests) and two zone fights of the engine.

### Shield probe: what stops a Spell Revisions area spell

A scriptless copy of the party mage cast Ice Storm (`SPWI404`: every 6.7 seconds its sub-spell
`SPWI404D`, power 4, at each creature an explosion hits) and Acid Fog (`SPWI614`: every 5 seconds
`SPWI614D`, power 6) at caster level 18, each over six dummies: one bare, five under a protection
each dummy cast on itself before the clouds came. Hit points lost:

| Protection | Ice Storm (4 explosions) | Acid Fog (10 explosions) |
| --- | --- | --- |
| None | 42 | 100 |
| Protection from Missiles (`SPWI311`) | 42 | 100 |
| Minor Spell Deflection (`SPWI318`: 6 levels, spell levels 1–4) | 18, the first two stopped | 100 |
| Spell Deflection (`SPWI522`: 9 levels, 1–7) | 15, the first three stopped | 80, the first two stopped |
| Greater Spell Deflection (`SPWI701`: 12 levels, 1–9) | 8, the first three stopped | 80, the first two stopped |
| Globe of Invulnerability (`SPWI602`: levels 1–4) | 0 | 100 |

- The sub-spells meet spell protections as spells cast at the creature: deflections and globes
  by the sub-spell's power stop them, Protection from Missiles does not. The engine's model
  (`targeting.protected`, `zones.hit`) gives the same for all twelve dummies, offline with the
  effects each wore. So the open question from IESDP (whether an explosion's sub-spells pass
  deflections like the explosion's own effects) is answered for Spell Revisions' clouds: they do
  not.
- A deflection takes the sub-spell's power from its levels with each explosion it stops and stops
  the last one even with fewer levels left (9 levels stop three explosions of power 4), then it is
  gone. Since 2026-10-22 the engine counts this for its own creatures in a zone: a turning,
  deflection or trap with L levels left stops the next ⌈L/power⌉ explosions (several of them one
  after another), and the explosions after them hurt and break casts (D3e above). What the
  creature loses with the protection itself (it no longer stops the enemies' own spells) does not
  count yet, so a creature under a deflection still stays in a cloud while the deflection lasts.

### The fights

| | Engine, H7 | Engine, H6 | SCS alone, H4 to H6 |
| --- | --- | --- | --- |
| Care fights | 4 | 6 | 5 |
| Group creatures lost a fight | 1.8 | 2.3 | 2.4 |
| Party members killed a fight | 1.5 | 0.5 | 1.2 |
| Party hit points left (mean) | 306 | 474 | 393 |
| Group hit points left (mean) | 184 | 160 | 149 |
| Summons cast a fight | 3.5 | 1.8 | 3.0 |
| Weapon rounds a fight (a spell scored higher) | 10 (6) | 7.8 (4.5) | none |

- **The Ice Storm:** the level-12 mage, under SCS's Protection from Missiles as in every fight,
  walked out of the party's Ice Storm 45 ticks after it came (out 47 ticks later), and no summons
  began inside a storm.
- **More deadly:** with four fights only, the group lost fewer creatures and the party far more
  hit points and members than in H6; summons came about twice as often as in H6. Four fights are
  a trend, not proof.
- **Zone fights:** the level-12 mage spent 381 and 339 ticks in the party's clouds, against 432 to
  990 in H2 to H6: SCS's Protection from Missiles had hidden Spell Revisions' clouds from it as
  well. The level-8 mage still spent 591 and 906 ticks in them and the level-10 priest 576 in one
  fight. In the first fight the mage walked four ways out through the overlapping Stinking Cloud
  and Cloudkill and lost 19 hit points in that time. In the two longest stays the engine never had
  the round: the creature stood out of the party's sight (400 to 700 px away), so SCS's cloud
  blocks above the hook ran (HOOK-01, rule 6). The mage stood in
  an Incendiary Cloud for 37 seconds, 46 px from its centre, and lost 113 hit points while SCS ran
  `SetInterrupt` and `RunAwayFromNoLeaveArea` from the cloud's marker every three seconds without
  moving it at all; once the engine had the round it walked out in 47 ticks. The priest stood at
  the edge of one for 34 seconds and lost 99 (SCS's `NoAction()` while it hears a cloud and sees
  no enemy). Since then SCS's escapes and stand-still stand aside with no enemy in sight too,
  whenever the engine has a way out of a zone that hurts the creature (HOOK-01, rule 6; D3e
  above). The mage's run was not one of those escapes but the mages' run from a Cloudkill, which
  got the condition only after lab batch H8 (below).

## Lab batch H8 (2026-10-23)

One launch with build `9cdf859`: the summons' rest of the fight (`2d60ce0`), SCS's cloud blocks
standing aside with no enemy in sight (`d0128d1`), deflections in a cloud (`130281a`) and EFF
files' timing (`e468f19`). Six care fights of the engine and two of SCS alone (conditions on the
priests), then three zone fights of the engine; the cleanup was clean.

| | Engine, H8 | Engine, H7 | Engine, H6 | SCS alone, H4 to H8 |
| --- | --- | --- | --- | --- |
| Care fights | 6 | 4 | 6 | 7 |
| Group creatures lost a fight | 1.3 | 1.8 | 2.3 | 2.3 |
| Party members killed a fight | 2.5 | 1.5 | 0.5 | 1.1 |
| Party hit points left (mean) | 199 | 306 | 474 | 388 |
| Group hit points left (mean) | 240 | 184 | 160 | 150 |
| Summons cast a fight | 3.5 | 3.5 | 1.8 | 2.7 |
| Weapon rounds a fight (a spell scored higher) | 7.0 (3.5) | 10 (6) | 7.8 (4.5) | none |

- **The strongest batch yet:** the engine's group lost the fewest creatures and killed the most
  of the party's six, with the most hit points left. SCS alone in the same launch lost 2.0
  creatures a fight and killed 1.0. Six fights are a trend; it holds since H6.
- **Summons over the rest of the fight:** the summons' choice records counted 23 to 56 seconds of
  fight in the care fights and the cap of 60 (57 once) against the zone fights' dummies.
- **Zone fights:** the group's four casters spent 1,962, 2,499 and 1,053 ticks in the party's
  clouds, against 1,464 and 1,722 in H7; every group creature lived. The engine led them out 30
  times.
- **The run from a Cloudkill** (fixed 2026-10-23): in the second zone fight both mages stood in
  the party's Incendiary Cloud for 34 and 38 seconds out of the party's sight; the level-12 mage
  89 pixels from its centre (186 to 122 hit points), the level-8 mage at its edge (176 to 68).
  Each had walked out of a Cloudkill and stood 272 and 278 pixels from its centre, just outside,
  when the Incendiary Cloud came down on them. Above the hook, SCS's mage scripts run from a
  Cloudkill's marker before they see the enemy (`mage/ssl/generalblocks/gohostile.ssl`:
  `Heard([ANYONE],404)`, `!See([PC])`, `Range(LastHeardBy(Myself),20)`, then `SetInterrupt(FALSE)`,
  `RunAwayFromNoLeaveArea(LastHeardBy(Myself),45)`, `SetInterrupt(TRUE)`). That block sets no
  `seencloud` timer, so rule 6 had not given it the condition: it fired every 48 ticks while they
  heard the Cloudkill, the hook was never reached, and the run never moved them. When the
  Cloudkill's marker fell quiet the engine walked each out within two seconds. The same block
  kept H7's mage in its Incendiary Cloud. Now rule 6 also covers blocks that hear a marker's shout
  and only run from the marker they heard (HOOK-01).
- **SCS's runs rarely move anyone here:** of 500 runs from a marker or an enemy (action 355) that
  group creatures began in the SCS-alone zone fights of H1 and H3, the zone fights of H7 and H8
  and four care fights of H8, 92 moved the creature more than 8 pixels within three seconds; the
  others left it where it stood, most of all in the zone fights. Where no zone hurts it, SCS's
  runs and stand-still still take the rounds of a creature that sees no enemy, as designed (D3e):
  in one care fight the level-12 mage stood 13 seconds beside the party's Ice Storm, unhurt.
- **A ranged attack walked back into a cloud:** right after it left the Incendiary Cloud, the
  level-12 mage threw Melf's Minute Meteors (range 30, which the engine counts as 480 pixels) at
  a dummy 428 pixels away; the game walked it to about 290 pixels first, back into the cloud
  (19 hit points). Not analysed yet.

## Lab batch H9 (2026-10-23)

One launch with build `c2f88d9`: SCS's run from a Cloudkill standing aside (`b2c0b94`), the
group's own clouds counted by the explosions each enemy is expected to sit through (`707b78e`,
CHOICE-01) and a load forgetting what the group saw (`c2f88d9`). Three zone fights of the engine,
then care fights: three of the engine as it is (`learned`), three with its own clouds counted by
one explosion (`once`) and two of SCS alone. Every fight closed without an error and the cleanup
was clean; one SCS fight ended at the lab's time limit after 79 seconds.

| | Engine, learned | Engine, once | SCS alone | Engine, H8 | SCS alone, H4 to H9 |
| --- | --- | --- | --- | --- | --- |
| Care fights | 3 | 3 | 2 | 6 | 8 |
| Group creatures lost a fight | 1.3 | 2.0 | 1.5 | 1.3 | 2.1 |
| Party members killed a fight | 4.0 | 4.7 | 0.5 | 2.5 | 0.9 |
| Party hit points left (mean) | 70 | 30 | 354 | 199 | 402 |
| Group hit points left (mean) | 234 | 175 | 214 | 240 | 168 |
| Summons cast a fight | 4.0 | 3.7 | 3.0 | 3.5 | 2.6 |
| Weapon rounds a fight (a spell scored higher) | 9.3 (1.7) | 6.3 (2.7) | none | 7.0 (3.5) | none |

- **The run from a Cloudkill:** no group creature began it inside a party cloud (13 runs outside
  them in the first zone fight). The group's four casters spent 1,233, 1,728 and 1,194 ticks in
  the party's clouds (H8: 1,962, 2,499 and 1,053); every group creature lived.
- **The strongest care batch yet:** in both modes the engine's group killed four to five of the
  party's six a fight; SCS alone killed 0.5 in the same launch. Three fights a mode are a trend.
- **Own clouds:** the engine chose none of its own lasting clouds, so `learned` against `once`
  tells nothing yet. In the care fights the level-12 mage never had Ice Storm (`SPWI404`) among
  its three best options. Replayed offline with the engine's own code on the logged positions
  (2026-10-24), the storm was no option at most of its 50 choices: a member of the group, a summon
  or the party mage the group had charmed stood within its reach plus the allies' margin (287 of
  304 aims; a first count with a smaller margin and without the charmed mage had found a free
  target at 26 choices). Where it was one, Horror (`SPWI205`) on the same enemies scored higher:
  the storm's 2d8 cold an explosion meets the party's 50% magic resistance and the fighters' 150
  to 166 hit points, the party mage's stoneskins catch it, and its slot costs twice Horror's. No
  fault; against this party the choice holds. Teleport Field (`SPWI421`) only moves enemies, so
  the engine weighs it as no attack.
- **Minimum hit points** (fixed 2026-10-23): in the second zone fight the level-12 priest stood at
  the edge of the party's Incendiary Cloud (238 of 256 pixels from its centre) for 39 seconds,
  from 228 to 144 hit points, swinging its mace at the party's cloud caster. The lab keeps that
  caster at one hit point or more (opcode 208, `boostTick` in `labF.lua`), and the engine counted a
  likely kill each round (0.41 against the way out's 0.05). Such minimums are real game data: 27
  spells of the lab game deliver opcode 208, among them Barbarian Rage at level 20 (`SPCL152`, 10
  hit points for 30 seconds), SCS's troll regeneration (`DWTRRG2`, `DWTRRG4`, `DWTRRG12`,
  `DWTFRG2`: one hit point for two seconds, renewed every second) and invulnerabilities without
  end. Now the engine reads each creature's minimum (MINHITPOINTS) and the spells and items it
  comes from (`adapters/eeex/sense.lua`). Damage counts only down to the minimum, and nothing
  kills while it holds, death by opcode 13 included (IESDP); an enemy at its minimum is no focus
  and no damage target, and the group's own losses in clouds and under attack stop there too. A
  spell that takes away every effect setting the minimum is not held back by it: SCS's fire, acid
  and cold spells end troll regeneration through a 177 for the troll race (`DWTROLFI`,
  `DWTROLAC`, `DWTROLCO`, opcode 321 on each regeneration spell), so a troll in a party fire
  cloud still counts as able to die there. (CHOICE-01, DIRECTOR-01)

## Kills by the dice (fixed 2026-10-28)

- **Was:** `harm.damage` counted a kill as soon as a hit's average damage reached the hit points
  left, as a step, and a zone multiplied one explosion's worth (each capped at all the creature is
  worth) by its explosions. In a zone whose next explosion comes before any way out, a creature
  with about one explosion's average left saw no worth in leaving: staying and going both ended at
  all it is worth. Found while testing wit (MIND-01).
- **Now:** damage roles keep their rolls (SPELLS-01), and `harm.spread` spreads one explosion over
  whole hit points. A zone adds its explosions up by the dice before the kill counts (`harmOf` in
  `combat-intent/zones.lua`): the creature dies once, however many explosions it takes, and keeps
  the lowest minimum among the zones that reach it. A clever mage at 10 of 40 hit points in a 4d9
  cloud, the next explosion (17.5 on average after saves) a second away, saw no worth in leaving;
  now leaving is worth 0.07 to it: staying meets two explosions, leaving only the one on its way
  out, which leaves it alive about one time in eight. The engine's own clouds count the
  explosions an enemy sits through the same way (CHOICE-01).
