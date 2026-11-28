# The Playground

Christopher's test install: the newest playable-races, spell mod, kit overhaul, and script engine on a clean CEBG `0.1.6` stack (without Spell Revisions, Artisan's Kitpack, or Bardic Wonders), in a folder and profile of its own.
His own game and its saves stay out of it.

## Playing

- Start: `Start Playground.cmd` in `%USERPROFILE%\Games\Playground`.
- Saves and options: `Documents\Chriz Playground`. The profile starts on Insane without double damage and without
  maximum hit points, with `Debug Mode = 1` enabled (`Ctrl+Space` opens the console, `Ctrl+J` teleports to the cursor).
  SCS's fine settings are not set, so SCS follows the game's slider.
- Classes & races: powered by `chriz-bg-playable-races` (Hobgoblin `101`), `chriz-bg-magic`, and `chriz-bg-kits` (`100 110 200 210 220 300 310 320`), plus `chriz-bg-modpack` chapter XP caps (`650` + `652`), `Chriz Overhead Text`, and `BuffBot`.
- The recorder writes to `game\bgse-playtest\<date-time>.jsonl`: orders, also those given in pause, what the enemies'
  AI decided, fights and reloads. `[BGSE] Recorder=0` in `Baldur.lua` turns it off. Enemies never read it.
- Runtime switches in `Baldur.lua` under `[BGSE]`: `Choice=0` disables the combat choice engine, `Others=0` disables the
  own monster/non-SCS hook, `Prebuffs=0` hands prebuff blocks back to SCS, `Contingencies=0` hands contingencies, chain
  contingencies and sequencers back to SCS, `DefensiveContingencies=1` enables the Challenge-Mode rule forbidding offensive
  or dispel spells in enemy Contingencies and Chain Contingencies, and `Shouts=0` suppresses overhead call-for-help and
  contingency-callout text while keeping local earshot alerts active.
- `python -I tools/read_playtest.py <file>` prints a summary per fight.

## Updating

Close the game first; the tool stops while the game runs from the folder.

    python -I tools/playground.py update [--engine <git ref>] [--magic <git ref>] [--kits <git ref>] [--races <git ref>]
    python -I tools/playground.py status

An update takes out engine, kits, spell mod, and playable races (last first) and puts the wanted versions back in, in about five minutes. Saves stay and keep working when mod data remains compatible; effects already on a character in a save stay as they were cast.

## Making it anew

`python -I tools/playground.py setup <clean lab game> --weidu <weidu.exe> --magic-repo <chriz-bg-magic> [--kits-repo <chriz-bg-kits>] [--races-repo <chriz-bg-playable-races>]`
copies a clean CEBG EET base game (built without Spell Revisions, Artisan's Kitpack, Bardic Wonders, `cdtweaks:2380`, or maximum hit points) and installs our four own mods on top.
