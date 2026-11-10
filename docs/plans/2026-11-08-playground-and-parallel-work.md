# Toward the Playground, and what runs beside it

Christopher, 2026-11-08: soon he tests the new spell mod and the AI together, and we keep building step by
step. What is already clear gets built in parallel. Additions for the whole game are designed with him, agents
build them, and we refine afterwards. Agent and human keep testing meanwhile; the other to-dos follow alongside.

## The way to his first test

1. **Stack lab** `BGSE-Lab/eet-magic`: a copy of `eet-nosr-2` with Chriz BG Magic installed on top of SCS. The
   lab tooling is `.work/stepMagic-lab/`, a copy of `stepEnc-lab` with the lab's paths.
   2026-11-08, first check: the spell mod (`claude/decided-specs`, 52d8558) installs in 30 seconds without a
   fault, the engine on top of it in 6 minutes, and the five encounters ran once each in both modes against the
   level 2-4 party at Insane: 10 fights, no error, clean cleanup. One fight a cell shows that it works, nothing
   about strength.
   The spell mod session (2026-11-08): take `6eeaf36` on `claude/decided-specs` for the joint test, not 52d8558.
   New there: IWD Hopelessness, and the control check of all eight wizard elementals with creatures of their own,
   so `SPWI516`, `SPWI520`, `SPWI521`, `SPWI620`, `SPWI621` and `SPWI622` now call own EFFs and CREs (`CBMW*`):
   run `spell_diff.py` again for these. Then `0a035e5` (same branch) brought the Celestials: Deva, Fallen Deva,
   Planetar and Dark Planetar are creatures of their own (`CBMDEVAG`, `CBMDEVAE`, `CBMPLANG`, `CBMPLANE`), called
   through `SPDEVA`, `SPDEVA2`, `SPPLAN` and `SPPLAN2`. The party keeps at most one of each pair, enemy summoners
   are not limited, and the player picks their spells. `e200515` gives enemy celestials their fight script back
   (see Beside it) and brings Lesser Restoration, which also ends attribute drain.
2. **Installer under the overwrite rule** (`claude/overwrite`): decided results are written whatever stood
   there.
3. **Playtest recorder** (`claude/recorder`, component 10, REC-01), then its three checks in a lab game.
4. **Dispelling Screen and other layered protections** (`claude/layers`).
5. **Batch on the merged build**: `magic-v1`, the five encounters against four parties at Insane.
6. **Playground** (`tools/playground.py`): a copy of the stack lab with its own folder and profile. `update`
   takes out engine and spell mod, last first, and puts the wanted versions in; saves stay. The copy still holds
   Artisan's Kitpack and Bardic Wonders; Christopher picks vanilla classes until our own kit mod exists. A fresh
   install without them takes about two hours and pays only if they get in the way.

State of 2026-11-08, after the PC restart: `claude/overwrite`, `claude/recorder` and `claude/layers` are merged, and
this branch is `main` now (Christopher's OK). Spell mod `6eeaf36` reads without a gap (no unknown effect, no partial
spell). The recorder passed its checks in a hidden game (REC-01). **The Playground stands** (`docs/PLAYGROUND.md`,
engine d8cbfda, spell mod 6eeaf36). At 06:45 it took spell mod `0a035e5` with engine 9220e12 (the same engine code) in
four minutes, its first real `update`. The engine reads that spell mod without a gap as well (137 new spells, no
unknown effect, no partial spell), and the six celestial summonings (`SPPR726`, `SPPR727`, `SPWI923`, `SPWI924`,
`SPCL923`, `SPCL935`) read as summons of the new creatures. At 07:12 it took `e200515` (engine 86c9b5c, the same
engine code), and so did the stack and tour labs (`magic_swap.py`). No partial spell there either; one part the engine
cannot read: Lesser Restoration (`SPPR417`) ends attribute drain through the spell mod's Lua function `CBMLRES`
(opcode 402). Running then: `magic-v1r` in `eet-magic`, the BG1 area tour in the second lab `eet-tour`
(`.work/stepTour-lab`: every BG1 area with enemies, the PC next to them, the engine on), the fight list FIGHTS-01.

**Stack batch `magic-v1r`** (2026-11-08, `.work/stepMagic-lab`, engine c114eac plus the recorder's fixed scan, spell mod
6eeaf36, recorder on): all 81 phases ran, no phase lost, no engine error, no crash, clean cleanup. Parties won 10 of 40
fights against the engine and 8 of 40 against SCS at Insane without double damage: Tarnesh 5 and 3, Neira 2 and 3, Karlat
3 and 2, Silke and Greywolf none. Two fights a cell and a simple bot, so this says the stack works and the two sides
stay close at equal settings, nothing about the bar or about a player. The recorder ran through it all: 82 loads
counted, 1.1 MB, 161 fight rows.

**BG1 area tour** (2026-11-08, `.work/stepTour-lab`, engine d8cbfda, spell mod 6eeaf36): the PC, kept alive, jumped next to
the enemies of each BG1 area from the census at Insane. 80 of 99 areas ran, with about 5,300 rounds the engine took and
8,400 actions: no engine error and no crash. 15 areas were not reached within 45 seconds and 4 at the end were not
visited (a second stop at the game's death screen, which the lab cannot leave). It shows that the engine runs on
BG1's creatures; it says nothing about how well they fight.

## What the fight census shows

`tools/fight_census.py` read the whole game (2026-11-08, lab `eet-nosr-2`). Hostile placed creatures that run on
the engine today, by SCS's scripts: BG1 628 of 727, BG2 and ToB 854 of 1,025, EE NPC content 97 of 130, Siege of
Dragonspear 24 of 1,140. Of creatures made by scripts, 4,865 of 6,476 creation lines. So the base frame already
covers BG1 and BG2; the gap is Siege of Dragonspear, which waits for Christopher's SoD Remix anyway, and monsters
with scripts of their own (trolls, golems, wyverns, ankhegs, some of them also in BG2).

## Beside it

- **Fight list:** BG1's fights in story order (`docs/research/FIGHTS-01-bg1-fight-list.md`), rated `simple` or
  `worth designing`. Christopher goes through it in blocks; finished designs go to agents.
- **The engine's own hook** for creatures without SCS scripts (built 2026-11-10,
  [HOOK-03](../research/HOOK-03-own-hook.md)): every fight script a creature carries that is not SCS's gets one
  hook block at its top; the engine drives such a creature when it is on the enemy side and carries no SCS-hooked
  script, as the family its class gives it, and the script's other blocks (calls for help, story variables) keep
  running as duties. By the files that brings BG1 from 628 to all 727 hostile placed creatures (gnolls, xvarts,
  ankhegs, wyverns, basilisks, ettercaps, carrion crawlers, kobolds, wolves), BG2 and ToB to 1,007 of 1,025 and
  Siege of Dragonspear to 1,125 of 1,140. Lab checks: ten one-minute cases with BG1's monsters on the engine, the
  story counters of killed xvarts, gnolls and ankhegs, and the BG1 area tour again (98 of 99 areas), all without
  an engine error. The Playground took it on 2026-11-10 at 07:47 (engine a504c36, 1,108 own hooks beside 1,140
  SCS ones, spell mod e200515). A party member the enemy charmed stays the game's: whether the engine should play
  it is Christopher's to decide. `[BGSE] Others=0` switches the own hook off.
  Christopher, 2026-11-10: these creatures must not become simpler than they were, and their quirks mostly stay;
  known gaps are fixed before he plays. The first rows showed each two-attack monster using one attack only, and
  xvarts and Drizzt's gnolls going for the party instead of the cow and Drizzt. Since engine b8f8611 a creature
  uses all its body's weapons (the better one more often, by its wit), one whose body shoots steps back from
  melee to do it, a script that attacks a creature by name keeps its creature while that one lives, and a
  creature in panic is left to the game (HOOK-03, "What the monsters were known for", with a table monster by
  monster). Lab check of seven cases without an engine error: ankhegs 14 spits and 4 bites, a basilisk's gaze
  turned a cow on the party's side to stone and it bit the immune PC, xvarts hacked at Hulrik's cow for 40
  seconds, left the PC alone meanwhile and went for it once the cow was dead. The Playground took that engine
  on 2026-11-10 at 09:11 (five minutes; spell mod e200515 as before).
- **SCS's ambushes and calls for help** (2026-11-10, [HOOK-01](../research/HOOK-01-scs-hook-placement.md) rules
  14 and 15; Christopher: the ambushes are taken over as they are for now, the groups come straight at the party,
  and get cooler in their own design rounds). Three places where SCS still walked creatures past the engine are
  closed: its helper scripts' walks at party members a creature does not perceive (the two assassin parties,
  Tazok's tent, the Bandit Camp's alarm, its calls for help), its walk to a group member whose call was heard,
  and the gate that kept its mages and priests idle until they saw an enemy themselves. The engine does these
  walks now; a neutral creature on its way to a talk keeps its own. What changes in play: SCS's casters come
  along with their group, as its fighters always did. Lab check on engine 1531fb9 without an engine error (both
  assassin parties, Molkar neutral, the Bandit Camp with its alarm). What cut the engine's attacks short in the
  camp's brawl (215 times in 90 seconds) is SCS's own call for help, every three rounds a creature: the engine
  decides anew in the same tick, no cast was ever cut, and the shouts stay SCS's for now. How far a group should
  hear (today: the whole map) is fine for many scenes as it is, a better design comes later (Christopher,
  2026-11-10). Open: the engine's answers take about 230 ms a second there with 37 creatures fighting. The Playground took that engine on 2026-11-10 at 11:07 (engine f032f2d, three and a
  half minutes; spell mod e200515 as before).
- **Enemy celestials** (found 2026-11-08, the spell mod fixed its part in `e200515`): under SCS the old celestials (`DEVAGOOD`, `PLANGOOD` and their
  evil twins) ran SCS's own fight scripts, which the engine hooks, so enemy celestials cast their spells. The spell
  mod's own celestials run `CBMDEVAC` or `CBMPLANC` (one of each pair per party) and `BDSUM00`, which casts no spell.
  For the party that is right, the player picks. On the enemy side they would only swing now: 127 creatures know one
  of the six summonings, nearly all Summon Dark Planetar (SCS mages and liches of BG2 and ToB, none in BG1).
  The spell mod session fixes it on its side: `CBMDEVAC` and `CBMPLANC` give enemy celestials the game's celestial
  script on arrival (`ChangeAIScript` to the class slot: `DEVAGOOD`, `DEVAEVIL`, `PLANGOOD` for both Planetars). Under
  SCS that is SCS's script, which the installer hooks already (`DEVAGOOD`, `DEVAEVIL`, `PLANGOOD`, `PLANEVIL`,
  `PLANET`), and the new celestials memorize 29 or 38 spells. Lab check with `e200515` (2026-11-08, tour lab, Insane,
  a hostile caster without scripts made to cast Summon Dark Planetar, then Summon Fallen Deva next to the protected
  PC): both arrived on the enemy side with `PLANGOOD` or `DEVAEVIL` in the class slot and fought hard with SCS's
  script (the PC lost 972 and 294 hit points in a minute; casts of `SPPR715`, `SPPR503` and `SPPR725`). The engine
  took none of their rounds, and it never did, for the old celestials either: the gate declines a creature whose
  hooked script has an unhooked one below it (`script-below`, HOOK-02), and `BDSUM00`, the game's script for
  summons, sits in the default slot. That holds for 29 creature files with an SCS script: summons with `BDSUM00`
  (the four celestials, two djinn, the phase spider summon, two tome golems) and some with shout or plot scripts
  below. The census's placed foes are almost untouched: BG1 628 of 628 are driven, BG2 and ToB 846 of 854 (8 with
  `DW#GITH1` or `SAHDIE` below). Christopher (2026-11-08): no question, everything SCS steers goes to the engine.
  Since then the gate drives all of them (all 29 creature files, among them Torgal, Bodhi in Spellhold, the
  githyanki, the Sahuagin ambushers, SCS's abishai and every summon with `BDSUM00`) and runs the lower scripts'
  duties itself (`adapters/eeex/lower.lua`, HOOK-02 rule 4): their shouts for help, plot variables, dialogue
  starts and powers cast without a spellbook entry run before the engine's own actions; their fighting is the
  engine's. Unit tests and a mutation check (16 of 16 killed) pass. Lab check (2026-11-10, tour lab, engine
  740c9d4, spell mod e200515, Insane, `celestialLab.lua`, one minute a case next to the protected PC): the engine
  drove all three, with no engine error and a clean cleanup. The Dark Planetar took eight rounds (Hold Person at
  the PC, then its sword; the PC lost 737 hit points, 972 under SCS), the Fallen Deva eight (272, 294 under
  SCS), and a githyanki mage (`GITH04`, SCS's help script `DW#GITH1` below its hooked one) ten, while its help
  script's shouts ran four times as duties (the call for help every three rounds, the shout on seeing the PC
  once). The lower scripts' blocks were checked 2,950 times from inside the hook's own trigger without a fault.
  Not seen in game yet: a dialogue start or a plot variable as a duty, and a group answering a shout. The PC
  cannot die there, so damage spells are worth nothing to the engine and its celestials mostly swing; that says
  nothing about their choices against a real party. The Playground took this engine (a76f88b, the same engine
  code) on 2026-11-10 at 05:29 in five minutes; its spell mod stays e200515.
- **Lesser Restoration's `CBMLRES`:** worth an entry in `spells.lua`'s `luaEffects` once the engine senses drained
  abilities on its allies; until then it reads as unknown, which costs nothing else.
- **Later:** our own party AI script; our own classes, kits and races (see the main plan's ideas list).
