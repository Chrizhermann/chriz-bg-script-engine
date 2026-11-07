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
2. **Installer under the overwrite rule** (`claude/overwrite`): decided results are written whatever stood
   there.
3. **Playtest recorder** (`claude/recorder`, component 10, REC-01), then its three checks in a lab game.
4. **Dispelling Screen and other layered protections** (`claude/layers`).
5. **Batch on the merged build**: `magic-v1`, the five encounters against four parties at Insane.
6. **Playground** (`tools/playground.py`): a copy of the stack lab with its own folder and profile. `update`
   takes out engine and spell mod, last first, and puts the wanted versions in; saves stay. The copy still holds
   Artisan's Kitpack and Bardic Wonders; Christopher picks vanilla classes until our own kit mod exists. A fresh
   install without them takes about two hours and pays only if they get in the way.

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
- **Later:** our own party AI script; our own classes, kits and races (see the main plan's ideas list).
