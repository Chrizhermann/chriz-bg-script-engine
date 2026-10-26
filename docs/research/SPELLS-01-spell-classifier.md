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
- On-hit and critical hit effects (opcodes 248, 249 and 341) are listed in `c.hits`: what one hit
  brings, classified as cast at the creature hit. A critical hit effect's spell is read at the
  holder's level without its projectile; what it puts on its caster lands on the holder
  (FIGHT-01, "F2e"). Each entry keeps the spell or item it comes from (`source`), so an enemy that
  carries what the hit brings is known.
- Host tests: `tests/unit/combat_intent/test_spells.lua`, 38 groups on Lua 5.1 and LuaJIT,
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
- A protection from the spell itself (opcode 206) with a saving throw of its own lands on a
  failed save and keeps the rest of that spell from the creature: what follows it there lands
  only on a successful save (2026-10-20). Fifteen SPL files of the SR lab use this, among them
  Greater Command's chain, Great Shout, Mold Touch and the strikes of Bigby's Icy Grasp and
  Crushing Hand. The classifier keeps a cure that follows (below) and leaves anything else that
  follows out; such a reading is approximate (`on-save:` reason).
- A cure that a spell itself brings later to the creatures it gave that condition is no cure:
  it ends the spell's own condition (2026-10-20). The classifier finds such ends on a first walk
  (`ownEnds`: condition and receiver, from when the condition lands to the first cure after it)
  and walks the spell again without those cures. A cure that comes for sure ends the condition
  then. A cure that comes only on a successful save lets the creature break free: Spell
  Revisions' Greater Command puts its targets to sleep for 60 seconds, and every 6 seconds a
  spell cast at each sleeper wakes it on a save (vs. spell at -4; -8 from caster level 29, -12
  from 49) or casts the next one. The classifier reads a 60-second sleep with a save every 6
  seconds (`breakFree`), also in each creature's view; the engine counts the time the target is
  expected to sleep by its save (`choice.brokenFree`). A cure for someone else (the caster) or
  one that comes before the condition stays a cure. Over every SPL of the SR lab only Greater
  Command and its sub-spell match.
- Levels (2026-10-26). An effect reaches only creatures within its levels (IESDP; GemRB's
  `CheckLevel`). A spell's or item's effect keeps them in its dice fields, except where the dice
  roll an amount (opcodes 12, 17, 18, 218 with parameter 2 at 1, 331 and 333; the list had 25
  and 98, which keep levels there too, and lacked 331 and 333). An EFF file keeps them in fields
  of its own (0x54, 0x58; both readers return them as `minLevel` and `maxLevel`), and its dice
  are only dice. The classifier read neither the EFF fields nor a delivery's levels, and merged
  the tiers of one spell into one range: Unholy Word's death up to level 4 and confusion up to 9
  became one disable up to level 4, so its confusion counted for no one above. Now levels are
  creature conditions, as IDS
  entries and SPLPROT rows are, for every effect and delivery that reaches others: each creature
  sees what reaches its level (`spells.view`, judged by `targeting.holds` from the creature's
  level), Deathblow's on-hit slay (`SPCL902`, its EFF up to level 10) included. What lands on the
  caster by a preset target is checked against the caster level the spell is classified at; a
  self-targeted effect is not checked. At caster level 12, 57 spells of the SR lab reach
  creatures by level and 35 of them reach levels differently: Color Spray, Holy Word, Unholy
  Word, Cloudkill, Prismatic Spray, Sleep, Artisan's Kitpack's Deathless Master's Touch and Bardic
  Wonders' Legionnaire's March among them.
- Debuff amounts (2026-10-26, for F2b in FIGHT-01; IESDP). Saving throw changes are tallied per
  save as well (`saveBy`: 33 death, 34 wands, 35 polymorph, 36 breath, 37 spells, 325 all five),
  for the spells whose saves they meet; `saves` keeps their sum. Casting failure (60) counts by
  kind of spell (`miscastBy`; parameter 2 0 and 3 wizard, 1 and 4 priest, 2 and 5 innate, 3 to 5
  as dead magic). Negative chant (137) lowers luck by the first byte of parameter 1; a value
  below 0 raises it and is a buff. Disease (78) counts by its type in parameter 2: damage over
  time (0 to 3, poison as opcode 25 counts it), lower strength, dexterity, constitution,
  intelligence, wisdom or charisma (4 to 9), a slow (10), Mold Touch's magic damage (11, and 12
  losing a die a round) and Contagion (13: strength, dexterity and charisma, and a slow). Damage
  over time counts its first minute at most (`overTime`): a fight is over sooner, and a disease
  that runs for hours would otherwise seem to kill anyone.
- How often poison strikes (2026-10-26; IESDP opcodes 25, 78 and 272). The classifier had poison
  types 2 and 3 the wrong way round. Type 2 deals parameter 1 every second: Bolt of Biting
  (`BOLT04`, parameter 1 2 for 15 seconds) says "30 points of poison damage in 15 seconds", and
  a wyvern's sting (`WYVERN2`) deals 5 a second for 20 seconds, 100 in all, where the engine read
  4. Type 3 deals one point every parameter 1 seconds: the Poisoned Arrow (`AROW14`) says "1
  point of poison damage every 3 seconds", and Spell Revisions' Poison (`SPPR411`) deals one
  every 4, 3 or 2 seconds by caster level, so at level 12 it reads 51 (6d6 and 30 poison) instead
  of 141. Now `spells.perSecond` reads all three opcodes: type 0 a point a second when parameter
  1 is not 0; 1 a point a second (272 does nothing); 2 and 3 as above; 4 parameter 3 every
  parameter 1 seconds, from EFF files only (Artisan's Kitpack's assassin poisons `C0AS#PV1` to
  `5`: 2 to 10 a round, so its Poison Weapon's hit reads 10 at level 1 and 40 at level 20); each
  slowed by the frequency multiplier in parameter 4 (0 counts as 1; spells and items have none).
  Type 1 was read as parameter 1 a second: the Arrow of Biting (`AROW05`, parameter 1 30), which
  hobgoblin marksmen and elite mercenaries shoot, read 600 for its 20 seconds and deals 20. The
  EFF readers read parameters 3 and 4 (offsets 0x60 and 0x64); on a creature they are
  `m_effectAmount2` and `m_effectAmount3`, the file's order. Poison without an end counts its
  first minute, as a long one does, and a 272 that never applies its file delivers nothing.
  Over every SPL and ITM ability of the SR lab at caster level 12, 136 poison readings change
  (110 item abilities, mostly monster weapons, and 26 spells), 69 up and 67 down.
- An empty item reference in opcode 111 creates no weapon and is no missing file
  (2026-10-20); IESDP warns that the game can crash on it. A kit mod in the SR lab gives one kit
  (SPLPROT row 418, the kit check) the charge of a touch spell in the fist instead, through a
  spell with such an effect, so Shocking Grasp, Chill Touch and Ghoul Touch (`SPWI115`,
  `SPWI117`, `SPWI218`) read as partial and the engine never struck with them. Over every SPL
  of the SR lab ten spells change: these three, the kit's own Shocking Grasp and Chill Touch,
  its four helper spells and a mod's Harm (`OHBPR608`), which empties the weapon slot first.

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
- `tools/reader_parity.py` runs the same reader over every SPL, ITM, EFF and PRO of a game
  folder through a fake memory that maps only the resource being read. On both lab games and Christopher's two installs (up to 7,814 spells, 5,921 items, 1,933 EFF and 577 projectiles per folder) every record matches the host parser, the projectile maps match and no read leaves a resource.
- In the SR lab game on Insane (2026-10-15) the reader returned the host parser's records for
  all 6,744 SPL, 1,654 EFF and 417 PRO files and for 4,930 of 4,932 items, and the same 435
  projectile numbers; reading all of them took 4.7 s, 2.9 s of it for the spells. The two other
  items (`NPCHAN`, `NPSHLD`) have equipping effects with -1 dice sides in their files. The
  game showed -1 too before a save was loaded and 0 after loading the lab save, while the
  PC carries neither item: loading the save changed the engine's own copy, and the reader
  reads that copy. Who carries them was not traced; 72 other items with negative dice sides
  read as in their files.
- Profiles of 11 lab creatures (two mages, a priest, two fighters, a clay golem, a
  tanar'ri, a maurezhi, a glabrezu, a vampiric illithid, a mature vampire): a level-18
  caster's first read took 13–29 ms, later reads 0–8 ms; no record was missing and the
  reader logged no problem. Each mage showed 36 spells (40 or 41 ready copies), 31 or 32 of
  which its spell buttons offered.

## Limits

- In game only in the SR lab, from one save, for 11 creatures. The no-SR lab has no profile
  or save yet.
- Once a save is loaded, the engine's copy of an item can differ from its file (seen for
  two items' dice sides), so in-game records can differ from host records there.
- Amounts are averages. Repeats (272, 333, cycles) are approximate, and conditional effects
  (177 with an IDS filter, 326, 366) are counted as if they applied.
- Who gets an effect comes from its target field. SR's and SCS's own target filters (318 and
  324 naming the spell, SPLPROT conditions, projectile creature filters) are not yet checked
  against a creature.
- EEex's opcodes run Lua or set extended stats; what they do cannot be read from the file.
- Items: only ability effects. Equipping effects (an item's passive bonuses) are not
  classified yet.
