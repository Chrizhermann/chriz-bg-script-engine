# Chriz BG Script Engine — Working Agreements

Read this first. The current plan is
[docs/plans/2026-10-14-combat-intent-on-scs.md](docs/plans/2026-10-14-combat-intent-on-scs.md).
What we know about EEex, SCS and the lab is in [docs/learned.md](docs/learned.md).

## What this is

A hobby mod by Christopher (Chris): an EEex/Lua engine that makes enemy groups in his modded
Baldur's Gate II:EE game (EET, SCS, Spell Revisions and the rest of the CEBG collection) fight
smarter and more dynamically. Scripted encounter phases come next and quests (WorldFlow) later.
It will ship as an optional, experimental CEBG component.

## Direction (Chris, 2026-10-14)

- **A mod, not an MMO.** Quality, features and stability matter; brittle preconditions don't.
  Don't add checks that switch a feature off because another mod changed an item, spell or
  creature.
- **SCS is the base.** Every creature keeps its SCS identity: spellbook, items and personality.
  SCS's rough fight logic is the blueprint. Reuse SCS ideas, never SCS code or files.
- **Whole fights over single spells.** Judge progress by mixed lab fights (fighters drinking
  potions, buffing priests, mages, monsters, several of each), then by community playtesting.
- **Gameplay design is Chris's.** Build the technical base and hooks, show what's possible, and
  design behaviour together with him. Don't decide gameplay content alone. Check in early and
  briefly.
- **The old process is retired:** stop/go gates G0–G8, evidence grades E0–E5, exact-hash
  activation, provenance and migration ledgers, acquisition and process-screening tooling. It
  lives in [archive/2026-10-process/](archive/2026-10-process/). Don't follow rules from the
  archive.

## Engineering rules

- Read the installed game's real data at runtime: memorized spells, items, effects. Classify
  spells by what they do. Skip anything unexpected or hand that creature back to SCS; never
  switch the whole feature off.
- Fail soft. If the engine has no decision, errors or is switched off, the creature's own
  script continues. Keep one global kill switch.
- Play fair. Act only on what the creature could perceive. Use normal engine actions (casting
  time, interruption, spell slots, target legality), not direct effect application.
- Re-check right before acting. An accepted or queued action is not proof that it happened;
  handle failed and interrupted actions.
- Never save session-local handles (EEex userdata, object IDs, action-queue ownership). Engine
  state is short-lived and rebuilt after loading.
- Keep EEex and native calls behind the kernel's engine boundary; policy modules work on plain
  snapshots.
- WeiDU stays the installer of record.
- Test where things can really break (decisions, installs, saves, crashes) with fast logic
  tests. Judge behaviour in batched lab fights. Investigate every failing test.

## Labs

- Every game test runs in a disposable lab, never in Chris's game or with his saves. Follow
  [docs/research/disposable-lab-runbook.md](docs/research/disposable-lab-runbook.md).
- Launch a lab game only through the quiet runner `lab_quiet_run.py`
  (`%USERPROFILE%\.codex\artifacts\next-batch-20261013\lab-tools\`): hidden desktop, muted,
  windowed, with a pointer guard. `prepare` the profile, then `run`. Launch only when no
  Baldur/InfinityLoader process is running, and not while Chris is working or streaming.
- Run many fights per launch and log decisions and outcomes. Use small reproductions only to
  diagnose failures.

## Safety

- Read-only: `C:\Games\Baldur's Gate II Enhanced Edition modded\` and
  `C:\Games\Baldurs Gate 1 and 2 mods\`. Chris's current game may be read or copied, never
  modified; never run WeiDU or tools in it.
- Never commit installed-game files, SCS or other upstream files, generated BCS/DLG, saves, logs
  with personal paths, credentials or transcripts.
- Credit SCS (DavidW), Spell Revisions (Demivrgvs and Gibberlings Three) and other upstream
  authors prominently.

## Git and tests

- The private remote is `origin` (github.com/Chrizhermann/chriz-bg-script-engine); pushing
  branches there is fine. The active gh account is hermannchristopher, so pass the Chrizhermann
  token per command. No public release and no contact with upstream authors without Chris's OK.
- Work on branches and keep commits focused.
- Tests: `powershell -NoProfile -File scripts/test.ps1 -Suite all`. The bridge-installer test
  needs `BGSE_WEIDU` set to a WeiDU executable.
