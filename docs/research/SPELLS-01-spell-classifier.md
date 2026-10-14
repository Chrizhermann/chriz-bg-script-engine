# SPELLS-01 — What a spell or item ability does, read from its effects

Date: 2026-10-14. Step 2 of the plan (with Christopher's answers 5 and 6). Read on two lab
games: the SR lab (BG2:EE 2.7.3.0, EET, EEex 1.2.0, SCS 35.21, Spell Revisions and the CEBG
collection) and the no-SR lab (BG2:EE 2.7.3.0, EEex 1.2.0, SCS 35.21 with CEBG's BG2
components). Opcode meanings come from the IESDP (Gibberlings Three). Spell Revisions is by
Demivrgvs and the Gibberlings Three, SCS by DavidW. No game file is in this repository.

## Question

Can the engine tell what a creature's spells, innate abilities and items do (damage,
disables, buffs, protections, dispels and breaches, healing, summons) from the installed
files alone, whatever Spell Revisions, SCS or other mods changed?

## What it is

- `combat-intent/spells.lua` classifies one SPL or ITM ability from plain records: the
  fields `tools/ie_resources.py` reads on the PC. In game, `adapters/eeex/resources.lua`
  hands over the same records (see "In game" below).
- It follows deliveries: spells cast by effects (146 and 148, at the casting level they name;
  type 1 uses the caster's level), spell effects applied directly (326), static charge (333;
  with no resource it casts the holder's resref plus B, at level 1 unless parameter 2 names
  one), 366, EFF files (177 and 283) and repeating EFFs (272: once a second, every p1
  seconds, p1 times a second). It stops at 12 deliveries or 2,048 effects; a cycle repeats
  effects already read, so the walk stops there and amounts become a lower bound.
- Per ability it returns roles (damage, disable, debuff, removal, protection, buff, heal,
  cure, raise, summon, move, prepare). Each role says who gets it (self, target, area,
  point, party, everyone, ...), the chance, saves, half damage on a save, level range,
  duration and amounts. It also returns the area (radius, enemies or allies only, cone,
  line), flags (offensive, beneficial, friendly fire, self harm, conditional, approximate,
  partial, a spell choice for the player, unknown projectile) and unknown opcodes.
- It never raises. Missing or odd data is reported (partial with a reason), and the caller
  skips what it cannot use; the creature's other abilities stay usable.
- Host tests: `tests/unit/combat_intent/test_spells.lua`, 22 groups on Lua 5.1 and LuaJIT,
  all synthetic records.

## Census over every SPL

| | SR lab | no-SR lab |
|---|---|---|
| Spells | 6,746 | 2,426 |
| Protection | 1,911 | 707 |
| Buff | 1,231 | 396 |
| Damage | 860 | 395 |
| Debuff | 850 | 416 |
| Disable | 783 | 397 |
| Removal (dispel, breach, ...) | 433 | 318 |
| Summon | 408 | 282 |
| Cure / heal / raise | 202 / 153 / 24 | 106 / 78 / 17 |
| Prepare (contingency, sequencer) / move | 110 / 30 | 79 / 15 |
| No role | 2,132 | 336 |
| Unknown opcodes | EEex 401 (96 spells), 402 (48), HP swap 343 (2) | none |
| Partial | 70 | 1 |
| Unknown projectile shape | 91 | 63 |

- *No role* spells hold only graphics, sounds and bookkeeping: SCS's and kits' granting and
  removing of spells (171, 172), helpers refreshing themselves (321), visual effects (215),
  proficiencies (233). 70 SR-lab spells have no effect at all.
- *Partial* in the SR lab: 68 spells name SPL files that are not installed (51 of them from
  one other mod), three have effect trees past 2,048 effects. The no-SR lab has one missing
  file.
- *Self harm* (331 SR, 74 no-SR) is mostly real trade-offs: kit stances and passives,
  berserker rage, Reckless Frenzy, a self-pause while channelling, trolls going down.

## What the census corrected

- Parameter 2 is not always a modifier type: opcode 0's is the damage type (16 sets base AC),
  332's is the damage type, 178 and 179 keep their amount in the special field, which can be
  negative.
- Casting time (189): positive values cast faster. Polymorph on oneself (135) is a
  shapechange, not a disable. A time stop held by the caster (231) freezes everyone else,
  allies included. Wild magic (280) on another creature makes its spells surge. Opcode 168
  removes a creature from the game (Banishment's last step). 143 puts an item in a slot:
  weapons are slots 34–38 and the fist.
- 177 with IDS entry 0 applies to anyone: 1,717 of the SR lab's 177 effects in spells and
  items use EA 0 (bard songs, most SR spells). A non-zero entry limits the EFF to that
  creature type; those spells are flagged conditional with their filters.
- Projectile numbers: a spell's field N is MISSILE.IDS entry N and PROJECTL.IDS entry N−1.
  Numbers missing from PROJECTL.IDS have no PRO file: Magic Missile's 68–78, Call Lightning's
  chain, Holy Might, Invisible Travelling and others are built into the engine, so their
  shape is unknown here (`projectileUnknown`). They look like single-target or self
  projectiles; the flag keeps the engine careful until that is checked.
- Only bits 0–4 of an effect's save type are saves. EE's bits 10 and 11 (skip the primary or
  secondary target) occur in neither lab; 24 and 25 (bypass mirror images, ignore
  difficulty) are flags.

## In game

- `adapters/eeex/resources.lua` reads SPL, ITM, EFF and PRO records from the engine's
  resource table through EEex (`EEex_Resource_Fetch`, then `Demand`, as EEex's own
  `EEex_Resource_Demand` does) and maps projectile numbers through PROJECTL.IDS. The raw
  reads dereference any address unchecked, so every read is bounded by the resource's size
  first. A missing resource is nil, a malformed one nil plus a problem; it never raises and
  caches plain records only.
- `adapters/eeex/creature.lua` takes a creature's snapshot: memorized spells and innate
  abilities (copies, ready copies, whether the engine's spell buttons offer them, caster
  level), its items by slot with their use counts, and its level.
  `combat-intent/abilities.lua` classifies that snapshot: each spell at the creature's
  caster level for it, and every ability of every item it carries.
- Host tests run both on synthetic files through a fake EEex memory that flags any read
  outside a resource: the reader returns exactly the host parser's records, also with
  only `EEex_ReadU8` available, and the profile classifies like the host records.

## Limits

- Nothing has run in game yet. The next lab batch compares the in-game reader with the host
  parser on the lab game and dumps creature profiles. The binding shapes the creature
  snapshot relies on (item array, button lists, memorized lists) come from the engine
  header and EEex's own scripts, not from a game run.
- Amounts are averages. Repeats (272, 333, cycles) are approximate, and conditional effects
  (177 with an IDS filter, 326, 366) are counted as if they applied.
- Who gets an effect comes from its target field. SR's and SCS's own target filters (318 and
  324 naming the spell, SPLPROT conditions, projectile creature filters) are not yet checked
  against a creature.
- EEex's opcodes run Lua or set extended stats; what they do cannot be read from the file.
- Items: only ability effects. Equipping effects (an item's passive bonuses) are not
  classified yet.
