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
   are not limited, and the player picks their spells.
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
`SPCL923`, `SPCL935`) read as summons of the new creatures. Running then: `magic-v1r` in `eet-magic`, the BG1 area tour in the second lab `eet-tour`
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
- **General hook** for creatures without SCS scripts: not needed for his first test. Idea to probe: a script level
  the game keeps free (level 3), set at run time, so that story scripts above it still run first and nothing is
  patched in the creature files.
- **Enemy celestials** (found 2026-11-08, open): under SCS the old celestials (`DEVAGOOD`, `PLANGOOD` and their
  evil twins) ran SCS's own fight scripts, which the engine hooks, so enemy celestials cast their spells. The spell
  mod's own celestials run `CBMDEVAC` or `CBMPLANC` (one of each pair per party) and `BDSUM00`, which casts no spell.
  For the party that is right, the player picks. On the enemy side they would only swing now: 127 creatures know one
  of the six summonings, nearly all Summon Dark Planetar (SCS mages and liches of BG2 and ToB, none in BG1).
  Proposal: the engine's installer hooks `CBMDEVAC` and `CBMPLANC` for enemies only, and the engine picks their
  spells by worth. Waits for Christopher and the spell mod session.
- **Later:** our own party AI script; our own classes, kits and races (see the main plan's ideas list).
