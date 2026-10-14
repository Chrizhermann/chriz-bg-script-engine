# HOOK-02 — SCS monster scripts and creatures with several SCS scripts

Date: 2026-10-14. Follows [HOOK-01](HOOK-01-scs-hook-placement.md) after Christopher's answer
7 ("hook them now"). Same stack as HOOK-01 (BG2:EE 2.7.3.0, EET, EEex 1.2.0, SCS 35.21, Spell
Revisions and the CEBG collection), read from the lab game's decompiled scripts and creature
files. SCS is by David Wallace (DavidW); Spell Revisions by Demivrgvs and the Gibberlings Three.
No SCS file or generated script is in this repository.

## Question

How do the 166 SCS scripts that step 1 left alone get the hook without starving SCS's own
logic, and what happens when one creature carries more than one hooked script?

## What the monster scripts are

- 123 of the 166 carry another SCS difficulty setting: fiend 62, dragon 16, vampire 13, genie
  10, spider 5, Durlag 4, Ascension 4, illithid 4, Bodhi 3, beholder 1, spirit troll 1. All 123
  use SCS's `castspell` round timer; three set it but never check it.
- 43 carry no SCS difficulty setting. Some are SCS's named-encounter scripts (Davaeorn's
  teleports, Sarevok), others come from other mods (Dvaradime, the BG1 NPC Project) or from the
  game. Nothing marks them as SCS-generated combat AI, so they stay as they are.
- Most SCS monster scripts are not a creature's main script. In the lab game's 9,399 creature
  files, the 120 hookable monster scripts sit in the general slot 103 times, the override slot
  60, class 36, race 6 and default 62 times; above them, in the default slot, is usually SCS's
  general AI. These higher-slot scripts are full combat scripts (about 100 melee and movement
  blocks each, plus spells and innate powers), so they make the creature's choice on most
  passes and the general AI below is a fallback.

## Script slots

- The engine runs a creature's scripts in slot order: override, area, specifics, class, race,
  general, default (SCRLEV.IDS; our engine reads them with EEex's
  `EEex_AIBase_GetScriptLevelResRef`). The first block that fires without `Continue()` ends
  the pass, so a lower script is reached only when every higher one lets the pass through.
- 146 creature files carry two or more SCS scripts. 22 of them already had two step-1 hooks
  (an SCS general AI in a higher slot above an SCS mage or general-AI script).
- A hook in a higher script that takes the round ends the pass before any lower script runs,
  exactly as SCS's own choice in that script would.

## What the step-1 rule would have starved

At or below the anchor, the monster scripts hold blocks that are not part of an ordinary
combat round: vampires calling rats and wolves (`CreateCreatureObject`), fiends gating away at
low health (`DestroySelf`), death handlers (`Die()`), mind flayers dropping their inventory and
escaping, turning hostile when attacked (`Enemy()`), resting, dialogue starts and group help
(shouting for healing, handing over a potion). The step-1 rule copied only bookkeeping runs and
abilities cast without a spellbook check, so an engine round would have kept these from
running. The mage, priest and general-AI scripts have no such blocks below their anchor.

## The rule now

`bgse/lib/hook.tpa` and `tools/hook_rule.py`, kept in step by
`tests/integration/test_hook_installer.py`:
1. Families: mage, priest and general AI as before; any other `DMWW_…_difficulty` setting
   makes it an SCS monster script.
2. Copies above the hook, guarded by the claim: bookkeeping runs and specials as before, plus
   every block at or below the anchor with an action outside an ordinary combat round
   (`COMBAT` in the Python rule: casts, items, attacks, weapons, movement around enemies,
   waiting, and their variables, timers and messages) and every death handler; target picks go
   with them when they aim at `LastSeenBy(Myself)`. On the step-1 scripts this adds nothing.
3. Each hook and copy names its own script: `BGSE_Claim(object, family, script)`. The installer
   also writes `override/M_BGSEHK.lua` with every hooked script and its family; uninstalling
   removes it.
4. At run time the first hooked script that asks in a pass decides for the creature, with its
   own family; the other hooked scripts decline in that pass. The engine also declines when a
   script that carries no hook sits below the deciding one, since an engine round would keep
   it from running: 28 of the 4,050 creatures with a hooked script in the lab game have one
   (summon scripts, shout and dialogue scripts). A dead creature's claim declines too.

## Results

The real installer ran on a scratch folder holding copies of the lab game's 1,196 SCS-marked
scripts; no game folder was touched.
- 1,148 scripts hooked: 585 mage, 307 priest, 136 general-AI and 120 monster scripts, with
  2,666 guarded copies (426, 265, 108 and 1,867). Five scripts that set the round timer but
  never check it were left as they are, and so were the 43 without an SCS difficulty setting.
  Every other script stayed byte-identical.
- For all 1,148, WeiDU's result decompiles to exactly what `tools/hook_rule.py` produces.
  `M_BGSEHK.lua` lists exactly these scripts with their families.
- The mage, priest and general-AI scripts get the same copies as in step 1. The new rule adds
  119 copies, all in monster scripts: summons, gating away, death handlers, turning hostile,
  resting, dialogue starts and the mind flayers' escape. The other 1,748 monster copies are
  innate powers cast without a spellbook check (1,192), the target picks they rely on (476)
  and item bookkeeping (80).
- So when the engine takes a monster's round, it picks the ordinary combat round: attacks,
  movement and spellbook casts. Innate powers stay SCS's for now (answer 5); step 2 classifies
  them so the engine can take them over.
- Above the anchor, the monster scripts keep SCS's conditional moves and attacks, as the
  mage and priest scripts do: wandering while no enemy is seen, escaping clouds, chasing,
  opening doors, a vampire's bat-form flight, a cornugon attacking tanar'ri on sight (checked
  in two scripts; 94 of the 120 have such blocks). The main melee choice is below the anchor.
- The install takes about 4 minutes, as in step 1.

## Limits

- No lab fight with a hooked monster yet; the arbitration has host tests only. The slot order
  comes from SCRLEV.IDS and EEex's documentation; a creature's higher slot asking first has
  not been seen in the lab yet.
- A monster script asks the engine up to about 17 times a pass (its copies and the hook).
  Only the first ask in a pass is evaluated, the rest get the stored answer, and the first one
  now also reads the creature's script slots. None of this is timed in game yet.
- When the engine takes a round, SCS's copied blocks fire before the engine's choice. A mind
  flayer whose escape sits below its attacks would escape before the engine's action, where
  SCS would first attack. Specials and plot actions stay SCS's (answers 1 and 5); ordering them
  against the engine's choices is engine work.
- The 43 scripts without an SCS difficulty setting and three SCS monster scripts that set the
  round timer but never check it are not hooked.
