# FIGHTS-01 — BG1 fights in story order

For Christopher to review about five fights at a time: keep it simple, or design it. Ratings are
suggestions; he decides the gameplay. Scope: BG1 and Tales of the Sword Coast, EET's BG areas only;
no SoD, BG2 or ToB. Chapters follow the story route. Side areas are listed afterwards for review,
though played earlier; travel ambushes have no fixed order.

**Sources, checked 2026-11-08:** every creature fact comes from files, through tools/fight_census.py
(summary.md, creatures.csv and areas.csv in sibling worktree wizardly-proskuriakova-c85fd0/.work/census/)
and tools/scout.py in the no-SR lab eet-nosr-2. Both complete CSVs were read, including neutral
creatures. Books describe this installation. Credit DavidW for SCS. Story placement comes from game
knowledge; each area association was checked against the census or scout --where. No game was run.

Uppercase names are CRE filenames without .CRE. Classes and levels are from the census; its level
is the highest stored level byte, not necessarily caster level. Spell danger lists selected
memorized spells or innates; a dash does not rule out scripted powers. **scs** = today's engine hook
through SCS; **other** = own script, needing the general hook. Placed-actor hook overrides take
precedence. **simple** = general engine enough once hooked; **worth designing** = discuss the fight;
**done** = the five existing [BOSS-01 designs](BOSS-01-bg1-early-encounters.md), not new live acceptance.
**unconfirmed** marks an evidence gap.

## Candlekeep and chapters 1–2

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | Candlekeep | BG2602, priests' quarters | Shank: SHANK_, fighter 1 | other, area override | — | simple — a first small melee fight. |
| 2 | Candlekeep | BG2607, bunkhouse | Carbos: CARBOS_, fighter 1 | scs | — | simple — the second small assassin. |
| 3 | 1 | BG2300, Friendly Arm Inn steps | Tarnesh: TARNES, mage 4 | scs | Sleep, Horror, Power Word Sleep | done — existing sheet. |
| 4 | 1 | BG3300, Beregost | Silke: SILKE, bard 10 | scs | Confusion, Haste, Minor Sequencer | done — existing sheet. |
| 5 | 1 | BG3357, Red Sheaf | Karlat: KARLAT, fighter 5 | scs | — | done — existing sheet. |
| 6 | 2 | BG4801, Nashkel Inn | Neira: NEIRA, cleric 5 | scs | Hold Person, Silence, Unholy Blight | done — existing sheet. |
| 7 | 2 | BG5400, Prism at Nashkel Mines | Greywolf: GREYWO, fighter 7; Kestrel: BGSEKES1/BGSEKES2 absent, unconfirmed here | scs for GREYWO | — | done — existing sheet, including the companion design. |
| 8 | 2 | BG4906, Nashkel Carnival tent | Zordral: ZORDRA, mage 6 | scs | Sleep, Blindness, Remove Magic | simple — one small caster encounter. |
| 9 | 2 → 3 | BG5405, Mulahey's cave | Mulahey: MULAHE, cleric 7; KOBOLD7, kobold 4; reinforcements KOBOLD, DW#MULKA, DW#MULKC, kobold 1; SKELET, DW#MULSA, DW#MULSK, skeleton 1 | scs | Mental Domination, Hold Person, Silence | worth designing — the first boss with reinforcements. |

## Chapter 3 — assassins and the Bandit Camp

The two travelling assassin parties have no placed actors in this census. Their ten creation maps
are BG5600, BG5601, BG5700, BG5701, BG5800, BG5801, BG5900, BG5901, BG6001 and BG6100.
Their order is not fixed. The camp's exterior and tent are separate entries to discuss together;
the census also records creation of the tent leaders by BG1900.

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 10 | 3 | BG4800, Nashkel | Nimbul: NIMBUL, mage/thief 7 | scs | Confusion, Dire Charm, Minor Sequencer | simple — the general caster and thief play fits. |
| 11 | 3 | BG3352, Feldepost's Inn upstairs | Tranzig: TRANZI, mage 6 | scs | Slow, Hold Person, Melf's Acid Arrow | simple — a lone informant with a modest book. |
| 12 | 3 onward | BG5600 and the travel maps above | Lamalha: LAMALH, cleric 5; Zeela: ZEELA, cleric 6; Telka: TELKA and Maneira: MANEIR, fighter/thief 5 each | scs | Both: Hold Person; Lamalha: Silence; Zeela: Animate Dead | worth designing — two priests supporting two attackers. |
| 13 | 3 onward | BG5600 and the travel maps above | Molkar: MOLKAR, fighter 6; Drakar: DRAKAR, fighter/cleric 5; Halacan: HALACA, fighter/mage 5; Morvin: MORVIN, fighter 5 | scs | Drakar: Hold Person; Halacan: Chromatic Orb, Acid Arrow | worth designing — a compact mixed party. |
| 14 | 3 | BG1900, Bandit Camp exterior | Taurgosz Khosann: TAUGOS, fighter 8; Ardenor Crush: ARDENO, hobgoblin 7; BANDITC, fighter 3; HOBGOBC, hobgoblin 4; DW#C3CBT, fighter 5; DW#C3CHE, fighter 3 | scs | — | worth designing — the camp can fight as a group. |
| 15 | 3 | BG1901, Tazok's tent; BG1900 creation also recorded | Raemon: RAEMON and Britik: BRITIK, fighter 5 each; Hakt: HAKT, hobgoblin 5; Venkt: VENKT, mage 6; DW#C3BT1, DW#C3BT2, DW#C3BT3, fighter 5; DW#C3HB1, DW#C3HB2, fighter 3 | scs | Venkt: Sleep, Remove Magic, Monster Summoning I | worth designing — ranged pressure behind a mixed front. |

## Chapter 4 — Cloakwood

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 16 | 4, optional | BG2200, Aldeth's clearing | If siding with Aldeth: Seniyad, SENIYA, druid 9; DRUID3, druid 3 | scs | Seniyad: Insect Plague, Call Lightning; druids: Sunscorch | simple — general druid support should suffice. |
| 17 | 4 | BG2101, Centeol's nest | Centeol: CENTEO, spider centeol 11; SPIDGI, giant spider 4; SPIDSW, sword spider 5; ETTERC, ettercap 5 | scs; other for ETTERC | Giant spiders: Web Tangle | worth designing — a crowded monster nest. |
| 18 | 4, optional | BG1602, Shadow Druid treehouse | Amarande: AMARAN, druid 11 | scs | Summon Insects, Static Charge, Thorn Spray | simple — a strong lone druid. |
| 19 | 4 | BG1800, Cloakwood Mine entrance | Drasus: DRASUS, fighter 10; Genthore: GENTHO, fighter 9; Kysus: KYSUS, mage 11; Rezdan: REZDAN, mage 9 | scs | Kysus: Confusion, elementals; Rezdan: Chaos, Dire Charm | worth designing — two fighters buying time for two mages. |
| 20 | 4 | BG1804, mine level 2 | Hareishan: HAREIS, mage 9; guards IRONGU, IRONGUAR, IRONELIT, fighter 5; IRON9, fighter 2 | scs | Chaos, Emotion: Hopelessness, Slow | worth designing — a caster amid many guards. |
| 21 | 4 | BG1802, mine level 3 | Natasha: NATASH, mage 9; guards IRONGU, fighter 5 | scs | Cone of Cold, Ice Storm, Shout | simple — general casting and guard support first. |
| 22 | 4 → 5 | BG1803, Davaeorn's level | Davaeorn: DAVAEO, mage 11; two Battle Horrors, DW#DAVHO, iron golem 9; guard IRON5, fighter 5 | scs | Fireball, Lightning Bolt, Sunfire; Dimension Door | worth designing — a mobile boss with guards and traps. |

## Chapter 5 — Baldur's Gate

City side quests are collected at the end.

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 23 | 5 | BG0603, Seven Suns basement | Doppelganger guarding Jhasso: DOPPSS, doppelganger 1 | scs | — | simple — a small rescue fight. |
| 24 | 5 | BG0615, Iron Throne top floor | Zhalimar: ZHALIM, fighter 11; Gardush: GARDUS, fighter 10; Alai: ALAI, fighter/mage 8; Aasim: AASIM, fighter/cleric 8; Diyab: DIYAB, cleric/thief 9; Naaman: NAAMAN, mage 9; false Emissary Tar: EMITAR3, doppelganger 1 | scs; other for EMITAR3 | Alai: Haste; Aasim: Mental Domination; Diyab: Silence, Unholy Blight; Naaman: Chaos | worth designing — four casters in a full enemy party. |

## Chapter 6 — return to Candlekeep

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 25 | 6 | BG2626, Candlekeep grounds | Ogre Mage ambush: OGREMA, OGREMA_A, OGREMA_B, OGREMA_C, OGREMA_D, ogre mage 5 each | scs | Sleep, Glitterdust, Dire Charm, Lance of Disruption | worth designing — several casters arriving together. |
| 26 | 6, optional | BG2610, library | Rieltar: RIELTA, mage 5; Brunos: BRUNOS and Tuth: TUTH, fighter 9 each; Kestor: KESTOR, thief 8 | scs | Rieltar: Dire Charm, Glitterdust, Blindness | simple — general mixed-party play first. |
| 27 | 6 | BG2619, catacombs | False Gorion: GORION3, greater doppelganger 9; false Elminster: ELMINS4, greater doppelganger 30; false Tethtoril: TETHTO3, doppelganger 10 | scs | False Gorion: Lightning Bolt, Flame Arrow | worth designing — a memorable disguised group. |
| 28 | 6 | BG5506, escape caves | Prat: PRAT, fighter/mage 8; Sakul: SAKUL, mage 8; Bor: BOR, fighter 7; Tam: TAM, fighter 8 | scs | Prat: Haste, Confusion; Sakul: Vitriolic Sphere, Slow | worth designing — a mixed party on the escape route. |
| 29 | 6 | BG5506, basilisk passage | Two Greater Basilisks: BASILG, greater basilisk 10 | other | — | simple — preserve a short monster hazard. |

## Chapter 7 — Sarevok

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 30 | 7 | BG0615, Iron Throne top floor | Cythandria: CYTHAN, mage 11; Argh: ARGHH and Ungh: UGHH, stone golem 14 each | scs; other for both golems | Sunfire, Cone of Cold, Breach | worth designing — a mage protected by two heavy companions. |
| 31 | 7 | BG0112, Undercellar | Slythe: SLYTHE, fighter/thief 9; Krystin: KRYSTI, mage 13 | scs | Krystin: Domination, earth elementals, Breach; Slythe: Poison Weapon | worth designing — an assassin and mage working together. |
| 32 | 7 | BG0108, Ducal Palace; unconfirmed difficulty-dependent form selection | Fighting templates: DW#HDP7, DW#HDP71, DW#HDP72, greater doppelganger 1; DW#HDP73, thief 8; DW#HDP74, cleric 9; DW#HDP75, mage 9 | scs for these forms; initial noble disguises are other | Shaman: Greater Command, Mental Domination; mage: Chaos, Sunfire | worth designing — protecting the dukes changes the objective. |
| 33 | 7 | BG0123, Undercity | Rahvin: RAHVIN, fighter 11; Haseo: HASEO, fighter 11; Carston: CARSTO, fighter 9; Gorf: GORF_, ogre 9; Wudei: WUDEI, cleric 12; Shaldrissa: SHALDR, mage 13 | scs | Wudei: Greater Command, Blade Barrier; Shaldrissa: Chaos, Otiluke's Freezing Sphere | worth designing — a full party before the final temple. |
| 34 | 7, optional | BG0123, outside the temple | Tamoko: TAMOKO, cleric 14 | scs | Unholy Word, Slay Living, Blade Barrier | simple — let the general priest engine carry her. |
| 35 | 7 | BG0125, Temple of Bhaal | Sarevok: SAREVO, sarevok 15; Semaj: SEMAJ, mage 12; Angelo: GALDOR, fighter/mage 12; Tazok: TAZOK2, fighter 11; Diarmid: DW#DIARM, fighter 11 | scs | Semaj: elementals, Breach; Angelo: Improved Haste, Cone of Cold | worth designing — the campaign's final group fight. |

## Side areas — wilderness

These can be visited during the earlier chapters; the numbers are discussion order.

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 36 | Side | BG5100, Gnoll Stronghold pits | Gnoll Chieftain: GNOLL_C, gnoll 4; GNOLL and GNOLL_E, gnoll 2 | scs | — | simple — general group melee first. |
| 37 | Side | BG3700, Bassilus's clearing | Bassilus: BASSIL, cleric 10; SKELETB, skeleton 1; ZOMBIEB, zombie 2 | scs | Greater Command, Righteous Wrath of the Faithful, Hold Person | worth designing — a priest and his undead family. |
| 38 | Side | BG3500, Mutamin's Garden | Mutamin: MUTAMI, mage 6; BASILL, basilisk 6; BASILG, greater basilisk 10 | scs for Mutamin; other for basilisks | Mutamin: Remove Magic, Horror, Sleep | worth designing — caster support changes the basilisk fight. |
| 39 | Side | BG3500, Kirian's party | Kirian: KIRIAN, fighter/mage 5; Peter: PETER, fighter/cleric 5; Baerin: BAERIN and Lindin: LINDIN, fighter 6 each | scs | Kirian: Glitterdust; Peter: Silence, Hold Person | worth designing — a small party with two kinds of magic. |
| 40 | Side | BG3000, Spider Wood; travel creation also recorded | Denak: DENAK, mage 9; Diana: DIANA, mage 8; Brendan: BRENDA, mage 7; Lasala: LASALA, mage 6 | scs | Denak: Confusion, water elementals; Diana: summons; Brendan: Vitriolic Sphere; Lasala: Lightning Bolt | worth designing — four Red Wizards together. |
| 41 | Side | BG4500, Carsa near Firewine Bridge | Kahrk: KAHRK, ogre mage 12 | scs | Domination, Cone of Cold, Improved Haste | worth designing — a deliberately dangerous optional caster. |
| 42 | Side | BG3600, Lighthouse coast | Sil: SIL, mage 6; two sirines, SIRINE, mage 5 | scs | Dire Charm, Improved Invisibility | worth designing — several charmers sharing targets. |
| 43 | Side | BG3100, Shipwreck's Coast | Droth: DROTH, ogre mage 5, called by Shoal: SHOAL, nereid 4; Shoal's allegiance follows the dialogue | scs | Droth: Icelance, Glitterdust, Sleep | simple — a small encounter after the dialogue. |
| 44 | Side | BG3601, coastal treasure cave | Three Flesh Golems: GOLEMF, flesh golem 9 | scs | — | simple — general monster targeting first. |
| 45 | Side | BG1401, Ankheg nest | ANKHEG and ANKHEGF, ankheg 8 | other | — | simple — general monster play once hooked. |

## Side areas — Ulcaster and Firewine

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 46 | Side | BG3900, Ulcaster ruins | Icharyd: ICHARY, skeleton warrior 15 | scs | — | worth designing — a named undead encounter. |
| 47 | Side | BG3901, Ulcaster dungeon | Wolf of Ulcaster: DW#ULCWO, vampiric wolf 8; scripted DW#REWO, dread wolf 1, and GHOUL, ghoul 2 | scs for fighters; other for helper DW#ULCGR, no class 1 | — | worth designing — the dungeon boss and its reinforcements. |
| 48 | Side | BG5201, Firewine dungeon, Lendarn's room | Lendarn: LENDAR, mage 7 | scs | Fireball, Shout, Lance of Disruption | simple — general casting in tight passages first. |
| 49 | Side | BG5201, Firewine dungeon, Ogre Mage's room | OGREMA02, ogre mage 5; OGREGR, OGREGR_C, OGREGR_D, ogrillon 2 | scs | Power Word Sleep, Chromatic Orb | simple — a small caster with melee support. |

## Side areas — Durlag's Tower and the cult

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 50 | TotSC | BG0511, first underground level | Fear: FEARM, ghoul revenant 15; Avarice: AVARICEM, thief 12; Pride: PRIDEM, fighter/cleric 12; Love candidate LOVEM, iron golem 12, unconfirmed transition | scs for combat files; other for puzzle warders | No memorized spells in these four combat files | worth designing — four distinct warders. |
| 51 | TotSC | BG0513, third underground level | Three Ashirukuru: ASHIRU, fighter/thief 8 | scs | File also lists Hold Person, Confusion, Haste; casting use unconfirmed | worth designing — concealed attackers as a pack. |
| 52 | TotSC | BG0509, Air Aspect trial | AIRASPEC, wyvern 10; three Invisible Stalkers, STALKE_, shadow 9 | other for Air Aspect; scs for stalkers | — | simple — general monster cooperation first. |
| 53 | TotSC | BG0506, chessboard | KING, fighter/mage 9; QUEEN, mage 8; two BISHOP, clay golem 10; two KNIGHT and two ROOK, clay golem 8; eight PAWN, clay golem 5 | scs for pieces | King: Domination, Haste; Queen: summons, Vitriolic Sphere; bishops: Flame Strike, Hold Person | worth designing — the board and several casters matter. |
| 54 | TotSC | BG0516, Demon Knight's chamber | Demon Knight: DEATHK, fighter/mage 18 | scs | Power Word Kill/Stun/Blind, Symbol Death, Fireball | worth designing — the tower's final boss. |
| 55 | TotSC | BG1003, Ulgoth's Beard cult house | CULT2, mage 15; CULTT1, fighter/mage 10; CULTT2, CULTT2A, CULTT4, fighter 8; CULTT3, CULTT3A, fighter/thief 8 | scs | Wizard: Suffocate, Disintegrate; enforcer: Chaos; assassin: Poison Weapon | worth designing — a large mixed cult group. |
| 56 | TotSC | BG1002, cult cellar | Aec'Letec: TANAR, tanar'ri 12; Tracea Carol: TRACEA, mage 11; CULTD1, CULTD2, CULTD3, CULTD4, CULTD5, CULTD6, fighter 8 | other for TANAR; scs for cultists | Aec'Letec: Paralyze, Silence; Tracea: Sunfire; guards' Hold Person/Confusion use unconfirmed | worth designing — a boss with a ritual around it. |

## Side areas — Werewolf Island and Ice Island

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 57 | TotSC | BG1504, wreck's top deck | Karoug: KAROUG, wolfwere 11; Daese: DAESE, mage 8; WOLFWEGL, wolfwere 10, created by Karoug's dialogue | other for Karoug; scs for Daese and wolfweres | Daese: Confusion, Emotion: Hopelessness, Dire Charm | worth designing — a monster boss with caster support. |
| 58 | TotSC | BG1500, island escape ship | Kaishas: KAISH2, werewolf 5 | scs | Hold Person, Rigid Thinking, Glyph of Warding | simple — general casting and melee at the escape. |
| 59 | TotSC | BG1004, Mendas's house on return | Mendas: MENDAS3, mage 10; MENDAS, werewolf 20; Baresh: BARESH2, fighter 12 | scs for these files | Mendas: Chaos, Domination, Confusion | worth designing — the final confrontation after the island. |
| 60 | TotSC | BG1009, Ice Island dungeon | Andris: ANDRIS, mage 11; Beyn: BEYN, mage 8; Marcellus: MARCEL, mage 6 | scs | Andris: Sunfire, Greater Malison, Polymorph Other; Beyn: Ice Storm; Marcellus: Slow | worth designing — three mages in a confined dungeon. |
| 61 | TotSC | BG1009 and BG1010, Dezkiel's Ice Island placements; unconfirmed which copy is reached | Dezkiel: DEZKIE, mage 8 | scs | Flame Arrow, Combust, Slow | simple — general solo caster play. |

## Side areas — Baldur's Gate quests

| # | Chapter | Place | Who: files, classes and census levels | Engine | Spell danger | Rating and reason |
| ---: | --- | --- | --- | --- | --- | --- |
| 62 | 5 onward | BG0126, Ragefast's house | Ragefast: RAGEFA, mage 7 | scs | Flame Arrow, Combust, Slow | simple — a lone mage if talks fail. |
| 63 | 5 onward | BG0200, north city; BG0137, tower creation; final tower room unconfirmed | Ramazith: RAMAZI, mage 9 | scs | Summon Shadow, Emotion: Hopelessness, Remove Magic | worth designing — the pursuit through his tower. |
| 64 | 5 onward | BG0115, Blushing Mermaid upstairs | Marek: MAREK1, mage/thief 13 | scs | Shout, Vampiric Touch, Invisibility | simple — a small fight ending the poison quest. |
| 65 | 5 onward | BG0114, Blushing Mermaid downstairs | Larze: LARZE, ogre 11 | scs | — | simple — a lone bruiser. |
| 66 | 5 onward | BG1111, Sunin's house | Sunin: SUNIN, mage 11; Joular: JOULAR, fighter 6; Maka: MAKA, fighter 7 | scs | Confusion, elementals, Breach | worth designing — a mage with two called guards. |
| 67 | 5 onward | BG0161, Degrodel's house | Degrodel: DEGROD, mage 10, if made hostile; HELMHO and DOOMGU, iron golem 9; STALKE_, shadow 9 | scs | Degrodel: Chaos, elementals, Spider Spawn | worth designing — several guardian types in a small house. |
| 68 | 5 onward | BG0011, Jardak's house upstairs | Jardak: JARDAK, fighter 11 | scs | — | simple — general fighter play. |
| 69 | 5 onward | BG0226, sewers, Scar's investigation | OGRMBA, ogre mage 5; CARRIO, carrion crawler 3 | scs for mage; other for crawlers | Sleep, Melf's Acid Arrow | simple — general caster and monster support first. |
| 70 | 5 onward | BG1207, basilisk warehouse | Greater Basilisk: BASILNAD, greater basilisk 10 | other | — | simple — preserve the contained monster encounter. |

## Data notes and unconfirmed details

- **Shank:** creatures.csv says scs, but areas.csv says other in BG2602: the area supplies
  INITDLG and WTASIGHT. This is the only BG1 placed actor whose class, level or hook differs from
  its standalone census entry. Use SHANK_ and CARBOS_; SHANK and CARBOS are BG2 actors.
- **Levels:** SAKUL, BEYN and DEZKIE read as mage 7 in scout but level 8 in the census.
  HALACA has 4/4/5 stored, so the census reports 5 although the two active classes read 4/4.
  MAREK1 is mage 7/thief 13, not a level-13 mage. The table deliberately retains census levels.
  The false Elminster really is recorded as greater doppelganger 30; palace doppelganger
  templates as level 1. These are file values, not inferred encounter strength.
- **Finished designs versus this source lab:** BGSEKES1 and BGSEKES2 are absent from both the
  census and scout; Neira's scouted book still has Remove Fear, not the designed replacement.
  The done labels come from the task and BOSS-01, not evidence that those edits are installed here.
- **Transformations:** the palace's NOBLPA scripts reference the fighting templates, but the
  difficulty-dependent selection was not traced. LOVE's dialogue creates FEARM, PRIDEM and
  AVARICEM; LOVEM exists but scout finds no area, script or dialogue reference. Love's actual
  combat transition is unconfirmed. Initial disguises and puzzle actors being other does not
  by itself mean their fighting forms lack the hook.
- **Books and placement:** ASHIRU has priest and wizard memorization despite fighter/thief class;
  the six CULTD guards have the same spell list under zero-slot headers. Their casting use is
  unconfirmed. DEATHK and TANAR also have memorized abilities under zero-slot headers, which alone
  does not establish usability. Kaishas's KAISH2 has priest spells despite werewolf class.
  DEZKIE occurs in both BG1009 and BG1010; the reachable copy is unconfirmed. RAMAZI is placed in
  BG0200 and created by BG0137, but his final tower room is unconfirmed. The census reports no
  CRE parsing errors; it cannot follow every transformation, movement or runtime-created creature.

## Other creatures needing the general hook

- Shank (1): SHANK_; Centeol's ettercaps (17): ETTERC; false Emissary Tar (24): EMITAR3.
- Basilisks in the escape caves (29), Mutamin's Garden (38) and warehouse (70): BASILG, BASILL, BASILNAD.
- Cythandria's golems (30): ARGHH, UGHH; ankhegs (45): ANKHEG, ANKHEGF.
- Air Aspect (52): AIRASPEC; Aec'Letec (56): TANAR; Karoug (57): KAROUG; sewer crawlers (69): CARRIO.
- Puzzle actors, palace disguises and the Wolf of Ulcaster's DW#ULCGR helper also read other;
  they are not counted as additional combatants needing the hook.

## Script or dialogue starts a lab must reproduce

- Greywolf (7): PRISM; Mulahey's reinforcements (9): BG5405; Nimbul (10): BG4800; Tranzig (11): BG3352.
- Both travelling parties (12–13): the ten travel-map scripts; Seniyad and DRUID3 (16): ALDCUT01.
- Ogre Mage ambush (25): BG2626; Cythandria and her golems (30): BG0615 and CYTHAN;
  Slythe/Krystin (31): BG0112; palace disguises and transformations (32): BG0108 and NOBLPA scripts.
- Tamoko's Undercity instance (34): BG0123; Sarevok and Diarmid (35): BG0125 and SAREVOK_;
  Kahrk (41): CARSA references, not a CreateCreature entry; Droth (43): SHOAL.
- Ulcaster reinforcements (47): DW#ULCWO and DW#ULCGR; warder combat forms (50): LOVE, with Love's
  transition still unconfirmed; cult fights (55–56): BG1003 and BG1002.
- Kaishas at the ship (58): BG1500; returning Mendas/Baresh (59): BG1004; Marek upstairs (64):
  BG0115; Sunin's guards (66): SUNIN. These are resource names, not lab commands.

## Groups with several casters

- Lamalha and Zeela (12); Drakar and Halacan (13); Seniyad and the lesser druids (16).
- Kysus and Rezdan (19); Alai, Aasim, Diyab and Naaman (24); the five Ogre Mages (25); Prat and Sakul (28).
- Palace shaman and mage (32, form selection unconfirmed); Wudei and Shaldrissa (33); Semaj and Angelo (35).
- Kirian and Peter (39); Denak, Diana, Brendan and Lasala (40); Sil and both sirines (42).
- Chess King, Queen and both Bishops (53); Cult Wizard and Enforcer (55); Andris, Beyn and Marcellus (60).
