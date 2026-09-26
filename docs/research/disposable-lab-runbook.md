# Practical disposable game lab

**Status — 2026-09-27:** The approved SCS-reference copy is verified, its separate profile is
configured, and a lab-file backup/restore check passed. It has not been launched. Task 3 remains
in progress until the separately authorized launch/save check; no runtime gate has passed.

The user reconfirmed the original architecture and features, but rejected the expanded
acquisition framework. This procedure replaces the previous runbook. Historical scanner,
capacity and process-provider results remain in Git and their research memos; they are not
prerequisites for making or using a disposable lab. No further framework work is planned.

## What this lab is for

A separate game installation for examining installed SCS behavior, installing our changes,
trying representative scenarios, and fixing what actually breaks. The copy retains
the approved source's existing EET, SCS, EEex, Spell Revisions and quality-of-life stack.
It is a comparison profile, not the separately proposed minimal EET diagnostic profile.
Do not silently rebuild the stack, remove SCS, or change gameplay options.

## Locations and boundaries

Exact source, destination, profile and setup commands are recorded privately in
`.work/task3/practical-lab-20260927.json` and `.work/task3/copy-practical-lab.ps1`.
The destination is the already approved `BGSE-Lab/scs-reference/game`, not a new choice.
The intended profile name is `BGSE Lab - SCS Reference`.

- Source installation and existing saves/configuration stay read-only.
- No game launch, UI/app control or unrelated process termination is currently authorized.
- Background copying, static inspection and host-side tests may proceed.
- Do not use links back into the original installation for writable game files.
- Keep copied game files, decompiles, saves and private logs out of Git.

## Setup and verify

1. Confirm the exact approved source and a fresh destination. Check available disk space
   and avoid an installer actively changing that source; do not inspect arbitrary processes
   or require the discarded acquisition machinery.
2. Copy with standard `robocopy /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /MT:8`.
   The private setup script lists the exact exclusions: installer-app metadata, the separate
   Radar application and transient logs, in-tree saves/cache/crash output, and root `engine.lua`.
   Game content and mod source/backup folders are retained. No player's Documents profile is copied.
3. For a long copy, use completion-wakeup once, in a fresh result directory. Verify its saved
   exit status and copy summary. Robocopy codes 0–7 are success; 8+ is failure. A notification
   alone is not success. Preserve and diagnose actual failures; do not build hypothetical guards.
4. Write a new `engine.lua` **in the lab only**, retaining the copied engine mode but setting:

   ```lua
   engine_name = "BGSE Lab - SCS Reference"
   engine_mode = 1
   ```

5. Check required files (`Baldur.exe`, `InfinityLoader.exe`, `chitin.key`, `WeiDU.log`), the
   separate profile identity, and relevant loader/output paths. Record the executable version,
   loader/runtime identities and installed mod log. No whole-tree fingerprint service is needed.
6. Check copied automation/console hooks before any later launch: no inherited queued commands,
   active-profile paths or external auto-run scripts. Initialize only required lab settings;
   do not copy the active `Baldur.lua` wholesale. Installed profile-dependent options may need
   explicit initialization in the new profile.
7. After separate permission to launch, use the lab loader with its game directory as working
   directory. Create one clearly named test save and confirm it appears only in the lab profile.
   Until then, report configuration/static checks separately from runtime proof.

The save-identity pattern is taken from `chriz-bg-collection` and the item-randomizer lab:
change `engine_name`, not global Windows Documents or OneDrive settings. A separate Documents
subfolder is sufficient for this practical profile; the old blanket reparse-root prohibition
does not require changing the user's Windows setup. Actual engine save routing still needs
the launch/save check above.

## Reset and rebuild

- For a small experiment, back up the specific lab files being changed and restore those files
  afterwards. Record additions so they can be removed from the lab. For an installed mod, use its
  normal WeiDU uninstall path when appropriate; do not hand-edit the install log.
- If the lab is badly broken, close its game/loader first, preserve useful test evidence and
  rename the exact lab `game` folder to a dated failed-copy folder. Re-run the fresh-copy recipe
  and reapply the lab `engine.lua`. Never mirror or restore into the source installation.
- Rebuilding from a changed source creates a new comparison baseline; record the new mod log
  rather than claiming byte-identical restoration. Keep a full frozen snapshot only when a
  concrete experiment needs one. No second full game copy is required now.
- Reset only the dedicated lab profile when a fresh game/save is needed. Preserve wanted test
  saves first. Neither a rebuild nor a mod uninstall authorizes deletion of active saves.
- Do not create destructive cleanup automation. List exact retained copies in the private
  `.work/task3/CLEANUP.md`; remove only identified, no-longer-needed lab output.

## Testing and next work

Use a few representative script families and actual regressions, expanding when a feature
requires it. The next source-to-effective study is the already planned mage/prebuff pilot,
using the [mage ledger](../provenance/scs/mage-pilot-ledger.md) and
[prebuff ledger](../provenance/scs/prebuff-pilot-ledger.md). Static decompilation is not gameplay
testing and does not activate an adapter.

Task 3 completes after the separate copy/profile works, one authorized launch/save verifies
isolation, and a practical reset/restore has been exercised. There is no requirement to build
a general copy transaction system, rehearse every hypothetical failure, or run the entire host
suite for setup/documentation changes. G0–G8 and user-owned gameplay decisions remain intact.

## Verified setup checkpoint

- Copy job: runner exit 0, robocopy exit 1; 164,610 files / reported 11.164 GiB copied in 88.2s,
  zero failed files or mismatches, empty stderr. Logs are private under
  `.work/task3/work/practical-lab-copy-v1`; no retry was needed.
- Copied stack labels: BG2:EE 2.7.3.0, EET 14.0, EEex 1.2.0 plus LuaJIT, SCS 35.21,
  Spell Revisions 4.21-chriz.5 and Bubb's Spell Menu 5.2. This is an observed comparison
  stack, not release support or a silent replacement of PREP-01's older candidate.
- Created lab-only `engine.lua` and the empty dedicated profile directory. No active
  `Baldur.lua` or saves were copied. Source `engine.lua` hash stayed unchanged.
- Required game files exist. Game/override/EEex script roots are ordinary directories;
  loader executable/script/library paths are relative. The bounded Lua/config check found
  no source absolute path, remote-console request or external auto-run file. The copied
  hotkey table contains only commented examples. This is static inspection, not an engine proof.
- Backed up lab `engine.lua`, added a temporary comment, then restored it byte-for-byte.
  This demonstrates a small experiment's file rollback, not full save/runtime reset.
- Only one full game copy exists from this task. Exact retained paths and cleanup candidates
  are in `.work/task3/CLEANUP.md`. No source files, existing saves or unrelated processes changed.
