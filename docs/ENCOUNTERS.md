# Building an encounter

Start here for every designed fight. Christopher wants each encounter to go faster than the last
(2026-11-04): look things up with the tools below, put each decision where this page says, and add
what cost time to the pitfalls at the end.

The design of each fight is in [BOSS-01](research/BOSS-01-bg1-early-encounters.md); the current plan
is [the first five encounters](plans/2026-11-04-first-five-encounters.md). Gameplay design is Christopher's:
the sheet gathers facts and suggestions, he decides.

## Checklist

1. **Scout** the creature and its companions in the no-SR lab (`tools/scout.py`, below); read its SCS
   scripts and dialog (a decompiled copy in a scratch folder). Write its sheet in BOSS-01: who it is, the
   story, what SCS does, what the engine does by default.
2. **Ask Christopher** only the open design questions; record his answers with the date.
3. **Engine orders** go in `combat-intent/encounters.lua`, with a group in
   `tests/unit/combat_intent/test_encounters.lua`.
4. **Creature edits** go in `bgse/encounters.tpa`. A new kind of edit gets a variant in
   `tests/integration/test_hook_installer.py` (`test_a_designed_creature_gets_its_scores_book_and_items`).
5. **New engine behaviour**: plain logic in `combat-intent/` with tests, the EEex side in `adapters/eeex/` with
   tests, a mutation check; keep both labs' installer agreement when an installer rule for scripts changes.
6. **Finish**: full suite, the sheet and the plan's Done list, commit, push.
7. **Lab batch** as the plan says (Core Rules and Hard or Insane, several runs, engine against SCS).

## Where each decision goes

Orders are per creature file (`combat-intent/orders.lua` explains each field). Difficulty is the game's
1 to 5 (3 Core Rules, 4 Hard, 5 Insane); Christopher's rule: the hard parts from Hard, Core and below play
normally.

| The design wants | Where | How |
| --- | --- | --- |
| a preferred or fixed target | `encounters.lua` | `target` (`'protagonist'`, `'player2'`, a creature file), `bonus`, `always` |
| preparation before a talk-on-sight creature speaks | `encounters.lua` | `talkPrep`: `{cast=spell, spend=spell}` (cast at once, spent) or `'buff-potion'`; `talkFrom` |
| a first sequence in the fight | `encounters.lua` | `opener`: steps of a spell or item, a list of them (the best counts), or `{watch=seconds}` (only while invisible); `openerFrom` |
| less of SCS's preparation | `encounters.lua` | `prep=false`, `prepSkip` |
| guarding, hiding, doors, leaving, dispel insight, waiting for foes out of play | `encounters.lua` | `guard`, `hide`, `doors`, `leave`, `insight`, `await` |
| least ability scores | `bgse/encounters.tpa` | `INT_VAR wis = 15` (and `str int dex con cha`) |
| a spellbook | `bgse/encounters.tpa` | `book = ~priest1=SPPR111,SPPR117 priest2=SPPR201 wizard3=SPWI304~`: those levels' memorized spells become these |
| items to carry | `bgse/encounters.tpa` | `carries = ~POTN10~` (a free pack slot, unless it carries one) |
| preparation before a talk whose script many creatures share (the game's `INITDLG`) | `bgse/encounters.tpa`, plus `talkPrep` in `encounters.lua` | `talk = ~INITDLG>BGSEKARL~`: the creature gets its own copy, whose talk waits while it prepares |
| preparation in a cutscene, in sight of the party | `bgse/encounters.tpa` | `cutscene = ~SILKECUT~ prepare = ~POTN11 SPWI212~`: before its wait it drinks what it carries and casts what it has memorized (on every difficulty: such cutscenes check no triggers) |
| a new line in a dialogue | `bgse/encounters.tpa` | `LAF bgse_encounter_line` with `dlg`, `after` (an action the state's transition does), `state` (a label) and `line`: the line follows that state and takes its transition over |

Not built yet, it comes with its encounter (plan step 6) and gets its row here then: new creatures (Kestrel).

## Tools

- `python -I tools/scout.py <lab game folder> NEIRA [KARLAT ...] [--where]`: who a creature is, its scores,
  its memorized spells and items by name, SCS's random items with their odds, scripts, dialog, effects;
  `--where` adds the areas it stands in and the scripts and dialogs that name it. Read-only.
- Labs (read-only for scouting): the no-SR lab `C:\Users\chris\Games\BGSE-Lab\eet-nosr-2\game`, the SR lab
  `C:\Users\chris\Games\BGSE-Lab\scs-reference\game`. Never Christopher's own game.
- Scripts and dialogs: decompile a copy with WeiDU into a scratch folder (as `tools/hook_agree.py` does);
  never run WeiDU in a game folder outside a disposable lab.

## Spells and potions used so far

Original game resources; names as the no-SR lab shows them.

| | |
| --- | --- |
| priest 1 | `SPPR101` Bless, `SPPR102` Command, `SPPR108` Remove Fear, `SPPR111` Armor of Faith, `SPPR113` Doom, `SPPR117` Protection From Good |
| priest 2 | `SPPR201` Aid, `SPPR208` Hold Person, `SPPR211` Silence, 15' Radius, `SPPR213` Spiritual Hammer, `SPPR214` Draw Upon Holy Might |
| priest 3 | `SPPR310` Miscast Magic, `SPPR314` Unholy Blight, `SPPR316` Prayer |
| potions | `POTN08` Healing, `POTN52` Extra Healing, `POTN09` Heroism, `POTN10` Invisibility, `POTN11` Invulnerability, `POTN12` Stone Giant Strength, `POTN14` Oil of Speed, `POTN35` Magic Shielding |

SCS's undroppable copies of potions are `DW#PTNxx`; its random items `DW#RNDnn` are drawn when the game
creates the creature, so a playthrough may differ (scout shows the odds).

## Pitfalls

- SCS's prebuffs run only with an enemy in sight, or with the creature's local `offscreenprep` at 1, and
  only from Hard. EEex local names are in capitals (`OFFSCREENPREP`).
- SCS's "cast previously" copies (`DWSP111`, renamed "… (cast previously)") have no visual and no sound. A
  creature that prepares in sight of the party casts its own spell instead: `ReallyForceSpellRES` (at once)
  and `RemoveSpellRES` (the slot spent), as `talkPrep` `{cast=X, spend=X}` does.
- In a script pass the first block that fires without `Continue()` ends the pass, and a later block's
  response replaces queued actions. Queue extra actions from a block of the engine's own (as the talk
  extras do), not from inside a trigger.
- Priest slots come from the creature's level and WIS (level 5 with WIS 15: 5/4/1), not from the counts in
  its file; spells beyond its slots are never cast. Raise WIS rather than adding spells it has no slot for.
- WeiDU's `ADD_KNOWN_SPELL` and `ADD_MEMORIZED_SPELL` take the level as `#n` or `(expression)`, not a bare
  variable, and may put a level's spells in another order.
- `decide` in `adapters/eeex/choice.lua` sits at Lua 5.1's limit of 60 upvalues: put new helpers it calls
  into a table (as `opener` is) instead of adding locals.
- The installer tests' synthetic game numbers triggers and actions its own way. To check a real script
  there, copy the lab's IDS files into it first (and drop the compiled fixtures), or the script decompiles
  into the wrong commands.
- A cutscene started with `StartCutSceneEx(…,FALSE)` runs every block without checking triggers, so it
  cannot ask for the difficulty.
- A label in a `.d` file lives only while that file compiles; a second `.d` names the state by its number.
  WeiDU leaves strings it added to the TLK after an uninstall (unused), so tests compare the old strings,
  not the whole file.
