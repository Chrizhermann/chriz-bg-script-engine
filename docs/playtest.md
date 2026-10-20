# Playtesting the engine in your own game

For Christopher's own test runs (2026-10-21: lab party and own tests, "oder beides").
Experimental: use a copy of the game or a backup, and judge whole fights, not single spells.

## Install

1. The game needs EEex (the installer checks for it) and SCS. Install the engine last, after SCS
   and every other mod that changes creature scripts: it hooks SCS's scripts in `override`.
2. Copy the folder `bgse/` from the branch `claude/wizardly-proskuriakova-c85fd0` into the game
   folder, and a copy of WeiDU next to it as `setup-bgse.exe`.
3. Run `setup-bgse.exe` and install "Chriz BG Script Engine: let the engine take over SCS
   creatures' rounds". Uninstall the same way.

## Switches

In `Baldur.lua` (game closed), section `BGSE`, all on unless set to 0:

- `SetPrivateProfileString('BGSE','Enabled','0')` switches the engine off: SCS alone.
- `Mages`, `Priests`, `Fighters`, `Monsters` switch one family.
- `Choice` at 0 leaves every round to SCS, with the director's advice only.

In a running game the EEex Lua console takes `BGSE.setEnabled(false)` or `BGSE.setEnabled(true)`;
`BGSE.setEnabled(false, true)` also stores it in `Baldur.lua`.

## What to watch

- Groups of casters: do they spread their disables, heal and cure the right friend, leave clouds,
  summon at a good moment, take down protections?
- Anything silly: a caster standing idle or punching while it has spells, casting into a storm,
  curing a friend inside a globe.
- The same fight with the engine off is SCS alone.

A note on what you saw (area, creatures, what happened) is enough; the lab reproduces the rest.
