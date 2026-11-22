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
   tests, the whole suite, a mutation check (`tools/mutation_check.py`); keep both labs' installer agreement
   when an installer rule for scripts changes.
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
| ability scores | `bgse/encounters.tpa` | `INT_VAR wis = 15` (and `str int dex con cha`): each named score is exactly that value |
| a spellbook | `bgse/encounters.tpa` | `book = ~priest1=SPPR111,SPPR117 priest2=SPPR201 wizard3=SPWI304~`: those levels' memorized spells become these whenever the spell file exists |
| items to carry | `bgse/encounters.tpa` | `carries = ~POTN10~` (a free pack slot, or the last pack slot when full, unless it carries one) |
| preparation before a talk whose script many creatures share (the game's `INITDLG`) | `bgse/encounters.tpa`, plus `talkPrep` in `encounters.lua` | `talk = ~INITDLG>BGSEKARL~`: the creature gets its own copy, whose talk waits while it prepares |
| preparation in a cutscene, in sight of the party | `bgse/encounters.tpa` | `cutscene = ~SILKECUT~ prepare = ~POTN11 SPWI212~`: before its wait it is given and drinks each item, and casts each spell (on every difficulty: such cutscenes check no triggers) |
| a new line in a dialogue | `bgse/encounters.tpa` | `LAF bgse_encounter_line` with `dlg`, `after` (an action the state's transition does), `state` (a label) and `line`: the line follows the first such state and takes its transition over |
| a new creature | `bgse/encounters.tpa` | `LAF bgse_encounter_new` with `chassis` (a creature of the game that lends body, voice and its other effects), `cre`, `name`, `level`, `hp`, `thac0`, scores, `script`, `default` (the first script this game has), `dv`, `items = ~ARMOR:LEAT01 WEAPON1:BOW05 QUIVER1:AROW01:40~`, `profs = ~105:2 91:1~` (proficiency number from STATS.IDS, stars); its saving throws come from the game's table for its class at its level; `RET bgse_born` |
| a line in a cutscene | `bgse/encounters.tpa` | `LAF bgse_encounter_cutline` with `cutscene`, `who` (the `CutSceneId` of the block), `before` (the action it goes before) and `line` |
| a companion who comes with the creature, by difficulty | `bgse/encounters.tpa`, plus `companion` in `encounters.lua` | two creatures with `bgse_encounter_new`, a cutscene line `EEex_LuaAction("if BGSE_Companion then BGSE_Companion(EEex_LuaAction_Object) end")` with `bgse_encounter_cutline`, and `companion={weak=…, strong=…, strongFrom=4}` |

## How strong the party may be

The chapter XP caps (`chriz-bg-modpack` component `652`, optional) give each chapter a ceiling on a character's
usable XP, and so on its level (Christopher, 2026-11-06). That is the highest a party can be when a fight comes,
not what it will be: a full party earns less than a small one, a multiclass splits its XP, and the fight may come
in another chapter. Party make-up, spells, items and the player's skill are not in it; those come from playing.

| Chapter | XP cap | Fighter | Ranger, Paladin | Cleric | Druid | Thief, Bard | Mage, Sorcerer |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1, 2 | 16,000 | 5 | 4 | 5 | 5 | 5 | 4 |
| 3 | 20,000 | 5 | 5 | 5 | 6 | 6 | 5 |
| 4 | 32,000 | 6 | 5 | 6 | 6 | 6 | 5 |
| 5 | 64,000 | 7 | 6 | 7 | 8 | 7 | 7 |
| 6 | 85,000 | 7 | 7 | 7 | 8 | 8 | 7 |
| 7 | 161,000 | 8 | 8 | 8 | 10 | 10 | 9 |

SoD and BG2 follow in `cbmbank_policy.lua` (`chapterCaps`, Chapter 8 to 22: 200,000 to 8,900,000). Levels from the
lab game's `XPLEVEL.2DA`. The first five encounters come in chapters 1 and 2, so up to a Fighter 5 and a Mage 4,
while the encounter lab's strongest party has levels 2 to 4.

## Tools

- `python -I tools/scout.py <lab game folder> NEIRA [KARLAT ...] [--where]`: who a creature is, its scores,
  saving throws, its memorized spells and items by name, SCS's random items with their odds, scripts, dialog,
  effects (weapon proficiencies by name); `--where` adds the areas it stands in, where the starting game's NPC
  list (`BALDUR.GAM`) puts it, and the scripts and dialogs that name it. Read-only.
- `python -I tools/fight_census.py <lab game folder> --out <folder>`: every placed actor and spawn point, every
  creature file, and quoted `CreateCreature` calls in compiled scripts and dialogs; it marks the SCS scripts that
  already meet the engine hook rule and writes CSVs plus a whole-game encounter summary. Read-only.
- `python -I tools/srmap.py <lab game folder> AREA x0 y0 x1 y1 [x,y=L ...]`: the area's search map around some
  spots as text (`#` blocks walking and sight, `x` walking), with letters on the spots; for a lab fight in which a
  walk stuck or a creature lost sight of its foes (encounter batch E8 v4: a one-cell wall at the Friendly Arm
  Inn). Read-only.
- Dialogue paths: a DLG's states and replies with their texts, triggers and actions tell which replies lead to
  the fight (the encounter lab picks them by their text: Silke's party refuses to kill the "thugs", Greywolf's
  stands against him).
- Labs (read-only for scouting): the no-SR lab `%USERPROFILE%\Games\BGSE-Lab\eet-nosr-2\game`, the SR lab
  `%USERPROFILE%\Games\BGSE-Lab\scs-reference\game`. Never Christopher's own game.
- Scripts and dialogs: decompile a copy with WeiDU into a scratch folder (as `tools/hook_agree.py` does);
  never run WeiDU in a game folder outside a disposable lab.

## Resources used so far

Original game resources; names as the no-SR lab shows them.

| | |
| --- | --- |
| priest 1 | `SPPR101` Bless, `SPPR102` Command, `SPPR108` Remove Fear, `SPPR111` Armor of Faith, `SPPR113` Doom, `SPPR117` Protection From Good |
| priest 2 | `SPPR201` Aid, `SPPR208` Hold Person, `SPPR211` Silence, 15' Radius, `SPPR213` Spiritual Hammer, `SPPR214` Draw Upon Holy Might |
| priest 3 | `SPPR310` Miscast Magic, `SPPR314` Unholy Blight, `SPPR316` Prayer |
| potions | `POTN08` Healing, `POTN52` Extra Healing, `POTN09` Heroism, `POTN10` Invisibility, `POTN11` Invulnerability, `POTN12` Stone Giant Strength, `POTN14` Oil of Speed, `POTN35` Magic Shielding |
| archer gear | `LEAT01` Leather Armor, `LEAT04` Studded Leather Armor, `BOW05` Shortbow, `BOW03` Longbow, `BOW01` Composite Longbow, `SW1H07` Short Sword, `AROW01` Arrow, `AROW08` Arrow of Fire, `AROW09` Arrow of Ice, `AROW10` Arrow of Piercing +1 |
| weapon proficiencies (STATS.IDS) | 90 long sword, 91 short sword, 104 long bow, 105 short bow, 114 two-weapon style |
| chassis | `HUNTER` "Ted", a level-3 archer; `BAERIN`, a level-6 archer (Kestrel's two files) |

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
- A chassis brings its own weapon proficiencies (opcode 233 effects) and saving throws. Give a new creature
  `profs` for the weapons it carries (Kestrel's first draft had a Shortbow without the skill); its saving
  throws come from the game's table by themselves.
- In WeiDU a variable as a number argument is written `(charges)`, not `#charges`; an optional regex group
  leaves its `MATCHn` unset, so match the rest with `\(.*\)` and read it apart.
- Outside functions WeiDU's variables are global: a routine's `RET` name must not be one the installer
  already counts with (Kestrel's routine first returned `bgse_made`, and the gift line then said 0).
- A check on real files in the synthetic game needs every table the routine reads copied in too (such as
  `SAVEWAR.2DA`), or the routine falls back and only warns.
- BG1's joinable NPCs stand where the starting game's NPC list in `BALDUR.GAM` puts them, not in any area
  file, script or spawn file: Garrick (`GARRIC`) in Beregost at (2504.2270), Khalid and Jaheira inside the
  Friendly Arm Inn (`BG2301`). A search of areas, scripts, dialogs and INI files finds no Garrick at all;
  `scout.py --where` reads the list. A save names an NPC whose copy it holds `*` and its file name from the
  second letter on (`*ARRIC`), and in the game that NPC's file name reads the same, so a lookup by `GARRIC`
  finds nobody (the encounter lab's first Silke runs).
- Testing a talk-on-sight creature in a small room: the console's move (`C:MoveToArea`) drops the party
  inside, where Karlat sees it at once and sets off to talk; moved again, it is gone, and `INITDLG` does not
  try a second time. Make the party in the street and let it walk in through the door (`LeaveAreaLUA`).
- A lab party's PC must have the party's level: the protagonist's fall ends a phase, as it ends the game,
  and the test save's level-1 fighter in the level 2 to 4 party ended most of batch v3's fights there within
  seconds (`learned.md`, section 6; the encounter lab's `HERO`). List every member's level and hit points
  first (`tools/scout.py`).
- A lab installs `snapshot/`, not the worktree: after a commit that changes `bgse/`, `refresh_snapshot.py` first
  (`labrunEnc.py` refuses otherwise), and give a fix a sign in the logs that only the new build can show.
- Before reading a lab batch, check three things (`learned.md`, section 6): that every member fought (the table
  shows only wins and hit points; `analyzeEnc.py` lists members never ordered, and an order alone proves no
  walk: compare positions), what the lab gives a creature that the game would not and the engine reads (the
  PC's minimum of one hit point read as "no kill"), and that no fight is missing (a set can end clean without
  one; `analyzeEnc.py` lists the phases lost or repeated).
