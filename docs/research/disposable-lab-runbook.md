# Practical disposable game lab

**Status — 2026-09-28:** The separate copy starts, creates a new test character, saves into its
named profile and reloads the saved state. Temporary files are removed and the lab is closed.
Task3 is complete: the lab-only optional Steam-DLL rename resolved the observed cloud activity
in one verified save/reload run. Keep this copy Steam-disconnected. No runtime gate has passed.
On 2026-09-28 the user clarified that hidden-game menu automation is allowed. The earlier
blanket menu-click prohibition below is historical, not the current permission boundary.

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
- The user authorizes hidden-lab startup and scripted internal game-menu/save/load actions
  (clarified 2026-09-28). No visible-desktop takeover, OS input injection, desktop switching,
  unrelated app control or unrelated process termination. Coordinate with the item-randomizer
  lab before launching. Reuse its existing queued-button method; no direct render-time save calls.
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
7. Keep the lab's optional Steam DLL disabled as described in the verified checkpoint below;
   check it has not been restored by a rebuild/update before a stateful launch. Use the lab loader
   with its game directory as working directory. The authorized one-shot
   backend startup check below is complete; do not automatically repeat it.
   For a rebuilt baseline, create one clearly named test save through a permitted
   method and confirm its local destination and cloud behavior separately. Hidden-game internal
   button events are permitted; local save routing alone does not prove cloud isolation.

The save-identity pattern is taken from `chriz-bg-collection` and the item-randomizer lab:
change `engine_name`, not global Windows Documents or OneDrive settings. A separate Documents
subfolder establishes a distinct local path, not a separate game-cloud namespace. The old
blanket reparse-root prohibition does not require changing the user's Windows setup. Our
OneDrive cloud-directory attributes are not evidence of a junction to the active profile.

### Historical backend-only startup check — completed 2026-09-27

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
- WeiDU rewrites the whole `WeiDU.log` on every install and uninstall: `--quick-log` drops the
  component names and an uninstall adds a `// Recently Uninstalled` line. Copy the log before
  installing a test component; after its uninstall, check that the entries match the copy and
  put the copy back. (HOOK-01)
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
using the [mage ledger](../../archive/2026-10-process/docs/provenance/scs/mage-pilot-ledger.md) and
[prebuff ledger](../../archive/2026-10-process/docs/provenance/scs/prebuff-pilot-ledger.md). Static decompilation is not gameplay
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

### Save/load verified; initial cloud-setting failure — 2026-09-28

Under the clarified permission, reused the sibling hidden launcher, queued-button save/load
runner and bundled pregenerated character. No desktop input, personal-save load, new full copy,
production runtime or new test framework. Independent review checked the private responses,
save hashes and restored files. Existing 24 documentation/evidence checks passed.

- First launch: new test character and named save; changed a synthetic GLOBAL from928 to929
  without saving, then queued load restored928 and the expected character. Initial startup
  was in a movie; after a command timed out while pending, its late successful response was
  preserved and only the remaining steps ran. The request was not resent.
- Cleanup exposed previously absent save folders with existing-playthrough names in this new
  profile. None was loaded. Their precise source/transfer route is unproven. The initial test
  save also had cloud artifacts; remote account state was not inspected.
- One diagnosed correction: set `Cloud Saves Enabled=0` only in the lab's `Baldur.lua`.
  The key exists in the observed executable and is also described in this
  [community troubleshooting report](https://forums.beamdog.com/discussion/81280/trying-to-get-a-clean-install-cant-get-rid-of-old-save-games).
  In the second fresh process, both the INI value and live `cloudEnabled` were0.
  A fresh named save/load restored930 after an unsaved931 change, but still produced a new
  `.cloud`/`.cloud.meta` pair and refreshed existing local cloud-file metadata. The setting
  alone therefore does **not** establish isolation on this copied stack.
- Both runs returned to the main menu, then closed only their own tracked job trees. Owned
  processes were verified absent; temporary console/QA files removed, UI restored exactly,
  and matching reservations released. This was not graceful executable exit; helper exit
  codes were not captured. The lab-only cloud-off precaution remains, not a claimed solution.

This was E4 evidence for the specified new-game/save/reload path, not cloud isolation, listener
lifecycle or G1. It held Task3 open until the following lab-only workaround was verified.
Do not change global Steam settings, delete remote saves, or require a manual user save test.
Private recipes/results: `.work/task3/hidden-save-20260928/`, `cloud-off-20260928/`, and
`CLEANUP.md`. Test saves and additional lab-local copies are retained and listed there.

### Practical Steam-disconnected lab verified — 2026-09-28

The user requested a quick solution and deferral of unnecessary cloud investigation. Static
inspection of this exact executable showed no Steam import/delay-import dependency, a dynamic
`steam_api64` lookup and a `Steam not found` path. Steamworks requires successful initialization
before its interfaces can be used ([Valve API overview](https://partner.steamgames.com/doc/sdk/api)).
That supported one bounded experiment, not an assumed startup guarantee.

**Keep this lab-only change:** with the lab closed, rename its `steam_api64.dll` to
`steam_api64.dll.bgse-disabled`. Preserve that file; do not replace or patch it. Leave the
appid file, Steam client/account settings and every other installation unchanged. Recorded DLL
SHA256: `e3fe06e2d802c2f753aeb46869e2af898f34715ce85f08001456fd8a80ecd21e`.
Reversing that exact rename restores integration, so do not do it during ordinary lab testing.
Reapply the change after any rebuild that restores the DLL. Keep the separate `engine_name`
and lab profile; leave `Cloud Saves Enabled=0` as a secondary precaution, not the solution.

One fresh hidden run reused the existing launcher, queued-menu runner and temporary menu:

- Fresh console pong; no Steam/client/overlay module loaded before or after the save test.
- The existing UI's no-argument `Infinity_CanCloudSave()` returned **false**, before and after.
- Loaded only our earlier test character, set marker932, saved a distinct named slot, changed
  unsaved933, then reloaded and independently observed932 and the expected character.
- The new save, under the dedicated profile, had **no cloud metadata**. All36 existing local
  cloud files retained identical names, lengths, hashes and modification times. No new cloud file.
- Returned to the main menu, stopped only the owned job, verified all owned processes absent,
  restored menu/settings, removed temporary payloads and released the matching reservation.
  Helper exit code was unavailable; this is not an exit0/graceful executable-quit claim.

The first host comparison mixed JSON-parsed dates and strings, falsely reporting changes;
comparing both saved snapshots identically resolved it without another launch or weaker check.
Private exact recipe/results: `.work/task3/steam-disconnected-20260928/`; cleanup ledger lists
the retained disabled DLL, new test save and prior files. No additional full copy or test suite.

This E1+E4 result completes practical Task3 lab setup after independent review. Task8 can now
begin; listener/lifecycle, Combat Intent, WorldFlow and G1 remain unproved. It does not audit
historical remote transfers or arbitrary external sync (including OneDrive), nor retroactively
establish that earlier runs uploaded nothing. Defer that investigation; do not delete remote
saves. Future tests use this Steam-disconnected copy and only explicitly named lab fixtures.
