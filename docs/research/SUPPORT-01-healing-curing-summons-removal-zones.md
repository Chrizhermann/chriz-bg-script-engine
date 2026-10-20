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
