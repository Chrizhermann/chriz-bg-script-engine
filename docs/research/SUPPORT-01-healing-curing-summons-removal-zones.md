# SUPPORT-01 — Healing, curing, summons, removal and danger zones (D3)

Status: being built (2026-10-20). Christopher's go: "Mach alles, dann Lab Tests."

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
