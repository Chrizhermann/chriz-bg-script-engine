# Building the first five encounters (Tarnesh, Silke, Karlat, Neira, Greywolf)

The design is in [BOSS-01](../research/BOSS-01-bg1-early-encounters.md), decided with Christopher
on 2026-11-03 and 2026-11-04. This plan turns it into engine and installer work and one lab batch.
Scale by difficulty everywhere: the hard parts (instant buffs, openers, the stronger companion) from
Hard; Core and below play normally (Christopher, 2026-11-04).

## What exists

- Orders by creature file (`combat-intent/orders.lua`, `api:setOrders`): target preferences such
  as `{target='protagonist', bonus=…}`, `prep`, `prepSkip` and more. The runtime passes none yet.
- SCS's own preparation blocks run in its scripts; the installer marks them so the engine can hold
  them back (`combat-intent/prep.lua`). SCS's blocks need a visible enemy, or the local
  `offscreenprep` set to 1, and follow SCS's difficulty setting (from Hard by default).
- SCS ships instant "cast previously" copies for some spells only (`dwsp###`, `dwsw###`): for
  example Armor of Faith, Spiritual Hammer, Mirror Image, Minor Spell Deflection; none for Aid or
  Protection From Good.
- Creature grants in the installer (gift spells and items, `bgse/lib/hook.tpa`).

## Steps

1. **Encounter book.** A data module with each designed creature's orders and extras, passed to the
   choice by the runtime: a light protagonist preference for Tarnesh, Karlat and Neira (a small
   bonus, to tune in the lab).
2. **Talk-on-sight preparation** (decided 2026-11-03 for SCS's talk-on-sight creatures, and wanted
   for Karlat and Neira): before the talk script starts the dialogue, the engine prepares the
   creature: SCS's own instant preparation (by setting `offscreenprep`, with SCS's difficulty
   rules) and the designer's extras (a potion, instant copies of spells it has memorized, the slots
   spent). Creatures without anything to prepare talk at once as before. Installer rule on the talk
   scripts (`DW#SHDLG`, `INITDLG`, `SHOUTDLG`), mirrored in Python with agreement tests. Probe in
   the lab first: the order of the script passes around `Dialog`/`StartDialogNoSet`.
3. **Neira:** WIS 15; first level Armor of Faith, Protection From Good, Doom, Command, Bless; second
   level Aid, Hold Person, Silence, Spiritual Hammer; third level Unholy Blight; a Potion of
   Invisibility. From Hard: Aid, Armor of Faith and Protection From Good instantly on sight, then
   after the talk the potion, then the opening spell from invisibility (Doom, then Hold Person, by
   worth). She casts her own Aid and Protection From Good at once, visibly (SCS's "cast previously"
   copies hide the cast, but she prepares in sight of the party).
4. **Karlat:** from the talk-on-sight preparation, his best battle potion right before he speaks.
5. **Silke:** her preparation (the potion, Mirror Image, instant) when the "thugs" arrive; Garrick's
   line added to his dialogue.
6. **Greywolf and Kestrel:** two creature files for Kestrel (an apprentice on Core and below, a
   seasoned archer above Core), created with Greywolf in Prism's dialogue by difficulty; Kestrel
   turns hostile with Greywolf and leaves with him.
7. **Mages step away from melee now and then**, by wit (decided 2026-11-03), for every caster.
8. **Lab batch** on `BGSE-Lab/eet-nosr-2`: each encounter against a lone level-1 hero, two level-1
   heroes, a level 1 to 2 party and a level 2 to 4 party, at Core and at Insane without double
   damage, average hit points, several runs; engine against SCS; logs of decisions and outcomes.

Each step gets logic tests, the full suite, a commit and a push; installer rules also get the
Python/WeiDU agreement check on both labs.

## Done

- Step 1 (2026-11-04): `combat-intent/encounters.lua` holds the orders; the runtime hands them to
  the choice. Tarnesh, Karlat and Neira prefer the protagonist lightly: an attack on the protagonist
  counts a quarter more (`LIGHT=0.25`, to tune in the lab).
- Step 2, SCS's own preparation (2026-11-04): installer rule 13 (HOOK-01) holds `DW#SHDLG`'s talk blocks
  while `BGSE_TalkHold` says so; the engine turns on SCS's `offscreenprep` and waits for the
  preparation (`combat-intent/talk.lua`). Still to come with steps 3 and 4: the designer's extras
  (potions, our own instant copies), and Karlat's own talk script, which is the game's `INITDLG`.
  To check in the lab: that SCS's prebuffs run in the held pass and the talk starts after.
- Step 2, the designer's extras (2026-11-04): orders `talkPrep` (a list of `'buff-potion'` or
  `{cast=…, spend=…}`) and `talkFrom` (lowest difficulty, 1 to 5). The installer puts one block of the
  engine's before the first talk block; after SCS's preparation it fires once and queues the extras
  (`UseItem` of the best buff potion the creature carries; `ReallyForceSpellRES` of our instant copy
  and `RemoveSpellRES` of the memorized spell, only while that spell is ready). The talk waits until
  they ran, at most 120 ticks in all. WeiDU and Python agree on both EET labs.
- Step 3, Neira (2026-11-04):
  - Her creature, from a data entry in `bgse/encounters.tpa` that a shared installer routine applies
    (`bgse/lib/encounter.tpa`): WIS 15, Christopher's book, and a Potion of Invisibility in a free pack
    slot. Checked on her real lab file: only WIS, the spell tables and the new item change, and uninstall
    restores it.
  - Her orders: from Hard she casts her own Aid and Protection From Good at once before she speaks and
    spends them; SCS's own preparation adds Armor of Faith and the hammer.
  - Her opener, a new kind of order (FIGHT-01, Openers), from Hard: the potion, a 4-second watch from
    invisibility, then Doom or Hold Person by worth, then Hold Person.
  - To check in the lab: the order around the talk, the potion right after it, that the watch feels
    right (4 seconds, to tune with Christopher), and how often she drinks the potion on Core, where she
    has no opener and drinks it only when it is worth it, as any creature would.
- Step 4, Karlat (2026-11-04): from Hard he drinks his best buff potion before he speaks (`talkPrep`
  `'buff-potion'`). His talk script, the game's `INITDLG`, is shared by many creatures, so the encounter
  entry gives him his own copy (`talk = ~INITDLG>BGSEKARL~`) whose talk alone waits; the talk rule's `own`
  mode holds only the talk blocks of such a copy (HOOK-01, rule 13). Checked on his real lab files with
  the lab's IDS: the copy agrees with the Python rule, and uninstall restores him.
- Step 5, Silke (2026-11-04): her entry puts her preparation into her cutscene (`cutscene = ~SILKECUT~`,
  `prepare = ~POTN11 SPWI212~`: the potion she carries and one Mirror Image she has memorized, cast with its
  casting and the slot spent), before her wait while the "thugs" walk up. The cutscene runs without
  triggers, so this holds on every difficulty (BOSS-01). Garrick's line comes from a second kind of entry,
  `bgse_encounter_line`, which finds the state by what it does. Checked on the real lab files: both go in
  where planned, and uninstall restores them.
- Step 6, Greywolf and Kestrel (2026-11-04): a third kind of entry, `bgse_encounter_new`, makes Kestrel's two
  creature files from two archers of the game (level, hit points, THAC0, scores, items, weapon proficiencies,
  and a fighter's saving throws at his level from the game's table); `bgse_encounter_cutline` puts a line into
  Greywolf's cutscene, as he appears, that asks the engine for his companion; the new order `companion` has
  the engine create the apprentice on Core and below, the partner from Hard (FIGHT-01, Companions). Kestrel's
  own script keeps him with Greywolf, hostile with him, gone when Greywolf leaves or is charmed. Checked on
  the real lab files: both creatures as planned, the line in place, his script compiled, and uninstall
  restores the folder. Not the Prism dialogue, as planned first: the cutscene is where Greywolf appears.
- Step 7, casters step away from melee (2026-11-04): the archers' step away (FIGHT-01, kiting) now serves
  every creature whose best choice is a cast that damage can break, and it also counts how much less
  likely a melee hit breaks that cast after the step; in the casting pause a step costs only what runs
  past the pause, so casters step away then, as SCS's mages do. By wit, at most every 18 seconds
  (FIGHT-01, Casters step away too). To see in the lab with the five encounters: Tarnesh and Neira
  against fighters.
- Step 8, the lab (started 2026-11-04): the BG1 encounters need a lab of their own, in the no-SR lab
  (`BGSE-Lab/eet-nosr-2`), with its tooling in `.work/stepEnc-lab/` (adapted from batch J):
  - A QA variant of the lab's own UI.MENU, made by `qa_menu.py`: the buttons the lab glue presses
    get names (load, save, the dialogue's button) and the menus the game stops in poll the remote
    console; the script reproduces the SR lab's QA menu exactly.
  - A BG1 starting point: the test save at the prologue's start that the lab tooling made in the SR
    lab (2026-10-04; one level-1 fighter, "BGSE Lab Test", in Candlekeep), copied into the lab profile
    while the lab runs and moved out again afterwards.
  - The lab steps a dialogue as a player would (the first reply each time) through the dialogue's own
    button in the game's confirm mode.
  - First a probe (Tarnesh: the trip to the Friendly Arm Inn, the talk on sight, the stepped
    dialogue, the fight), then the batch: four parties from the BG1 companions (the PC alone, with
    Imoen, a level 1 to 2 party, a level 2 to 4 party), the five encounters' own ways in (talk on
    sight for Tarnesh, Karlat and Neira; Garrick's offer and Silke's cutscene; Prism's talk and
    Greywolf's cutscene with Kestrel), Core and Insane, engine against SCS.
  - Labs run only while the PC is free (Christopher's rule for background labs); a waiter tries every
    few minutes.
- Encounter tooling (2026-11-04, Christopher: build each encounter faster than the last): the guide
  [docs/ENCOUNTERS.md](../ENCOUNTERS.md) with a checklist, where each decision goes and the pitfalls so far,
  and `tools/scout.py`, which shows everything about a creature in one command.
