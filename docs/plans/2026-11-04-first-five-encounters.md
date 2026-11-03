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
   worth). Our own instant copies for Aid and Protection From Good.
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
