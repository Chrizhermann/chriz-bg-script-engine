# Connected mage pilot

This is an explicitly loaded experiment for the private authored four-creature scene in a
quiet BG2602. It is not an installable SCS replacement or an adapter for arbitrary actors.
The build recipe is authored; generated CRE/BCS/SPL assets, runtime traces, saves and machine
paths remain private. Source provenance and the preparation oracle are recorded in COMBAT-01/02.

## Shadow and active modes

`shadow-session.lua` connects current scalar observations to preparation/combat candidates,
scoring, choice and data-only replay. Its separate research harness changes the scene. The
shadow bundle cannot submit actions. See `docs/research/mage-prebuff-shadow-results.md` for
the completed shadow result and its limitations.

`active-session.lua` uses the separate default-off active bundle. The closed combat phase
considers the declared offensive choices; preparation helpers are not activated. Exact actor-
target Magic Missile is currently the sole admitted ordinary request. Unknown point geometry
still excludes Slow/Glitterdust. Test weights are not difficulty or gameplay defaults.

The registered fixture is sampled again twice at dispatch: changed ownership, target,
resource, geometry identity, eligibility, epoch or expired proposal refuses the action.
The native boundary re-resolves the actor/target and uses normal `SpellRES`, never a forced
helper, direct effect, manual spell debit or queue clear. Queue return means accepted only.
The experiment correlates the matching action start, real memorized-copy debit, later target
HP loss in this passive closed scene and idle state before reporting completed.

## Reproduce the useful batch

1. Run `scripts/test.ps1 -Suite all -Seed 47`. Build the active bundle with
   `python -m tools.build_active_bundle <new-private-directory>/B-KCORE0.lua`.
2. Reuse the existing private Task25 recipe: unchanged v2 fixture assets, exact source hashes,
   thirteen-entry staging/cleanup ledger, own baseline save, separate profile and hidden
   desktop launcher. Verify current declared game/API/spell identities. Do not copy the game
   again or stage into a personal installation. Acquire the agreed shared reservation.
3. Probe hidden desktop isolation, stage, launch once, verify fresh remote pong and cloud-off,
   load only the own named baseline, enter the quiet room and create the four fixtures.
4. Load the active harness with the private configuration and `begin('baseline')`. It tests
   default-off, then two sequential AI-selected casts, then three legacy Strength casts and
   movements. The third mage has no Combat Intent enrollment.
5. At `await-load`, use `requestLoad()`, verify named-load completion, then `completeLoad()`.
   Recreate the quiet room/fixtures in the same process before each remaining case:
   `disable-during-cast`, `replacement`, and `load-after-start`. Do not reload the harness or
   register duplicate listeners. Each case is attempted once.
6. Disable does not clear the ordinary engine queue. Replacement uses the already-tested
   ordinary ActionOverride movement from the lab protagonist; movement/damage ordering must
   be observed. Ambiguous ordering stays unknown. Load records native state immediately
   before the request and proves local claim/enrollment reset; it does not establish the
   exact native action state at destruction.
7. Close the harness/output, stop only the owned launcher's process tree, verify exit, restore
   the three originals/remove the ten exact additions and owned IPC, then release the token.
   Preserve results/failures privately. Extract decision events for the existing replay tool.

Read current G4/G5 and task state before activation. A queued command, syntactic compilation,
host test or prepared recipe is not a successful runtime result. No baseline here proves a
whole SCS mage, general encounter balance, broad install-stack compatibility or full-scale
performance. Expand those capabilities through the retained roadmap, not implicit enrollment.

The Task25 follow-up adds `replacement-control`, `replacement-differential` and
`load-paused-start`. The first two compare the complete original-script sequence/state from
the same observed starting positions; absolute arrival remains a separate diagnostic. An
interrupted action may spend zero or one copy depending on when it is replaced; record that
count rather than assuming start means debit. The third pauses at the native start and refuses
loading unless the actor still has action31, the target is untouched and one claim is pending.
Use the same named-load/reset sequence; close each failed trace and preserve it before any
reviewed correction. The private paired checker compares only the completed control and
explicitly corrected differential, never promotes the failed trial. See the soak memo/G5 for
exact results and retained limits. No new launcher, game copy or generic framework is needed.
