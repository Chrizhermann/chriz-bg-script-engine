# Practical disposable game lab

**Status — 2026-09-27:** The approved SCS-reference copy is verified, its separate profile is
configured, and a lab-file backup/restore check passed. One backend-only startup and fresh
Remote Console ping now passed, with configuration created in the dedicated lab profile.
The lab is closed and temporary probe files removed. Task 3 remains in progress until actual
save routing is verified; no runtime gate has passed.

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
- On 2026-09-27 the user authorized this lab's startup/save check through backend commands,
  explicitly excluding computer control. No mouse/keyboard or desktop/app UI automation;
  no unrelated process termination. Coordinate with the item-randomizer lab before launching.
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
7. Use the lab loader with its game directory as working directory. The authorized one-shot
   backend startup check below is complete; do not automatically repeat it.
   Save verification remains separate: create one clearly named test save through a permitted
   method and confirm it appears only in the lab profile. Do not substitute menu clicks for
   backend access. Until then, report configuration/static checks separately from runtime proof.

The save-identity pattern is taken from `chriz-bg-collection` and the item-randomizer lab:
change `engine_name`, not global Windows Documents or OneDrive settings. A separate Documents
subfolder is sufficient for this practical profile; the old blanket reparse-root prohibition
does not require changing the user's Windows setup. Actual engine save routing still needs
the launch/save check above.

### Backend-only startup check

Reuse the item-randomizer's non-input-desktop launcher and the existing EEex Remote Console;
do not build another launcher framework. Exact source paths, tool identities and the four-line
launcher adaptation are private under `.work/task3/backend-startup-20260927/`. Preparation
passed syntax checking and independent review against the existing tools; execution and
cleanup are recorded below. No new test suite or launcher framework was added.

Wait while the peer owns `bg-game-install.lock`; its review time is not expiry. When it is free,
check for a conflicting game/installer, acquire our own exclusive reservation, and verify the
launcher's non-input-desktop probe. Temporarily stage only the console's two published files
in this lab. Launch with a three-minute owned-process lifetime, check the ready file, then
require a fresh `pong` reply. A ready file alone is not liveness. Preserve the result, close only
our launched process tree, remove only our temporary additions, and release our matching token.
Never switch input desktops, click a menu, send keys, or stop another task's processes.

The existing randomizer load/save/quit driver uses `Infinity_ClickItem` (SDL mouse events), so
it is not reused under the present restriction. Its earlier direct save call from a render
callback crashed natively; do not retry that shortcut. A backend-only save route has not been
established. Startup/console success or a newly created configuration file would **not** prove
save routing. Leave that check open for a permitted backend method or a later manual lab save.

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

## Verified startup checkpoint

- After the peer finished, acquired our own reservation and verified the launcher's child and
  grandchild stayed on the non-input desktop. Exactly one lab launch; no clicks or keys.
- Remote Console v0.2.0/protocol1.1 returned a fresh `pong`, `eeexActive=true`, `luajit=true`
  and `io=true`; client exit0. Its ready timestamp preceded that request. This is bounded E4
  startup/IPC evidence, not BGSE capabilities, gameplay, save/load or G1 acceptance.
- The previously empty dedicated profile gained a 1,058-byte `Baldur.lua`. This proves observed
  configuration output there, **not** the destination of a gameplay save. No save was created.
- After about 59 seconds, signaled the helper to close only its own process tree; helper exit0
  and the recorded processes verified absent. This was not a graceful menu-quit test. Removed
  the two staged console files and its ready marker after checking identities. Lab `engine.lua`
  and `WeiDU.log` hashes stayed unchanged; our reservation was released and the heartbeat paused.
- Exact commands, identities, ready/ping outputs and cleanup evidence are private in
  `backend-startup-20260927/runtime-result.json` and adjacent records. Keep the new lab settings;
  there is no leftover game process, second game copy or temporary console installation.
- Independent review matched the saved outputs, current lab hashes and absence of temporary
  files; it kept process-exit/release observations attributed to the lead and save proof open.

Next: verify one named save through an allowed backend method or a later manual lab save.
The menu-click restriction still applies; Task 3 remains in progress and Task 8 remains pending.
