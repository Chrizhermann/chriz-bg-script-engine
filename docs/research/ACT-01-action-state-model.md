# Task9 action observation — working contract

**Question:** How do we keep a queued request distinct from a proved gameplay result?
**Status:** In progress. Task8 narrow lifecycle passed; G1 and action activation remain open.
This is research code under `experiments/action-observer`, not a production ownership layer.

## Frozen host contract for this bounded implementation

Module `action_state.lua`: `new(attemptId)` creates `{attemptId=..., state='proposed'}`;
`reduce(record, event)` returns a fresh record plus a reason string. Never mutate either input,
call the engine, schedule a retry or clear a queue. Only copied scalar result fields are returned:
`attemptId`, `state`, `reason`. Attempt ID is a nonempty string, not an engine object ID.

Events contain matching `attemptId` and `kind` (the target state below). States:
`proposed`, `accepted`, `started`, `advanced`, `completed`, `failed`, `interrupted`,
`invalidated`, `timed-out`, `unknown`. Completed and all failure/uncertainty outcomes are terminal
for this attempt; late evidence requires separate reconciliation, never an automatic second action.

- proposed -> accepted; accepted -> started; started -> advanced; advanced -> advanced.
- Completion from accepted/started/advanced additionally requires `proof` equal to
  `independent-postcondition` or `trusted-engine-completion`. `queue-return`, action start,
  next-action and an empty queue are not completion proof. The engine adapter must actually
  establish and correlate that proof; the pure reducer does not authenticate a string label.
- Any nonterminal state can fail, invalidate or become unknown with a nonempty reason.
- Accepted/started/advanced may time out; started/advanced may be interrupted; both require reason.
- Stale attempt, terminal attempt, invalid transition or missing proof leaves the state unchanged
  in a fresh scalar result and returns a rejection reason. Invalid input shapes raise a caller
  error. No timestamps, engine handles or callback arguments are retained by this first reducer.

This minimal model separates outcomes; action-specific evidence, clock/deadline policy and
correlation are still required. A timeout does not mean the engine queue was cancelled or that
retrying is safe. Unknown/timeout relinquishes enhancement and asks for observation/reconciliation.

## Bounded engine checkpoint

Use only our named disposable fixture. The first ordinary movement attempt was intended to
record queue acceptance, action-start callback, then a later independent position sample.
Only the queued entry was verified; the following console request timed out (details below).
Never use queue-return or callback alone as success. No destructive queue clearing. This
checkpoint does not substitute for cast, interruption, contention or target-invalidation probes.

## Host results and independent review — E2

Seven focused scenarios run on Lua5.1 and LuaJIT2.1 via Lupa: progress states, valid completion
proof, rejected queue/start/empty-queue claims, stale/terminal/invalid edges, explicit failures
and uncertainty, nonmutating scalar outputs, malformed callers. Initial RED was the absent
module. Lead review found an empty event reason could produce a record that the next call
rejected; one regression assertion reproduced this on both backends before the minimal fix.
Both now pass; no assertion was weakened. Exact command:

`python -X utf8 -m pytest -p no:faulthandler -q tests/unit/test_action_observer.py`

This disables only pytest's diagnostic fault handler for the already documented Windows/LuaJIT
exception bridge behavior (Task7), not exception assertions. Original output excerpts and the
independent lead's actual focused output are private under `.work/task9/`. No broad lab suite
was added or rerun. The worker implemented only the pure reducer/tests; lead reviewed its
contract and correction. A separate source reviewer checked the native probe before staging.

## Native method and pinned source — E1

Same dedicated Steam-disconnected comparison stack as [Task8](EEEX-03-observer-probe.md):
BG2:EE2.7.3.0, EET14.0, EEex1.2.0/LuaJIT, SCS35.21, SR4.21-chriz.5, Bubb Spell Menu5.2.
Only our sole named disposable character is eligible for this experiment. Source is the
effective lab copy, credited to EEex/Bubb; no upstream payload is included in this repository.

| Source | SHA256 | Inspected behavior |
|---|---|---|
| `EEex_Action.lua` | `18ea2ed7974984d7da66ac315ca035574cc4faa2802f55c4f431efca2862787b` | Lines49–76 parse and append ordinary actions;180–184 append the listener;326–339 dispatch `(sprite, action)` from current action. No completion return from queue helper. |
| `EEex_Action_Patch.lua` | `29d4d0981788e77f41a7d00dfae1f6949426cd6ccbeb04608ad97fe16433f761` | Lines65–84 hook after SetCurrAction, excluding NoAction. |
| Effective `ACTION.IDS` | `d50ddfbb2ec41bc7feb946528512fbf7e64e5d2d462fe0cf0c8cafdde50d5a30` | ID23 is `MoveToPoint(P:Point*)`. |
| Effective `UI.MENU` | `560a2c97f09b4473b2d821ff78ab44cd1c552320902b73500a148a242d601d1a` | Clock queries CheckIfPaused and calls TogglePauseGame(true); any test unpause must query first, never toggle blindly. |

Review strengthened the probe before launch: queue return alone no longer means acceptance.
It requires an initially idle actor/empty queue and then exactly one queued ID23 with the
requested destination. The callback must match ID23 plus destination, with its reducer result
recorded. Unexpected synchronous start or queue contents means `unknown`, without retry.
Only a later position sample after an applied `started` transition can complete this probe.
Current/queued action reads use the existing EEex/sibling-lab pattern; current-version preflight
must verify them before dispatch. Never clear a queue or retain actor/action userdata.

This is a one-attempt fixture correlation, not a native unique action token, production lease,
content eligibility check or general ownership proof. Another producer submitting the same
destination is not distinguishable by this draft; contention research remains required.

## Runtime result — E4 partial, not the Task9 exit

One fresh hidden process, after the peer finished its game test and released the shared
reservation. The existing launcher/queued-menu helper was reused, not expanded. No visible
desktop/input control or active-game write. Exact authored payloads/versions are recorded in
the private staging ledger; executable identity is the Task8 pin. Fresh console pong, EEex
active, and cloud-save capability false preceded loading only our Task8 fixture.

| Observation | Result |
|---|---|
| Read-only preflight | Own single character in BG2602 at(200,186), current action0, empty queue, unpaused. Current-version queue reads worked. |
| One submission | `MoveToPoint([232.186])`; same-chunk snapshot was `accepted`, exactly one queued ID23 at(232,186), starts0, unchanged pre-action position. |
| Later independent sample | Console timeout after15seconds. The request remained unconsumed; there is no callback or position result. |
| Cleanup | Own helper/loader/game absent after owned-job closure; eight temporary additions and IPC removed, original menu/config restored, matching reservation released. No save was made. |

The last observed reducer state is `accepted`. Operational outcome is **unknown**: the host's
console timeout is not an observed engine failure/interruption, proof that movement stopped,
or proof of a native crash. The process was still present at the bounded OS check before
cleanup; it was closed deliberately. There was no repeat submission or second launch.

**Counterevidence:** return from the queue wrapper is not a result; even a verified queue
entry did not give us the independent postcondition. No claim of an applied start transition,
movement completion, general action ownership or Task9 acceptance is supported by this run.
Independent review confirmed this boundary from the actual request/result and cleanup files.

**Original diagnostic limit:** static review then found no source-proven cause. The existing console is
render/menu-polled (its default hosts are WORLD_ACTIONBAR and START); an unconsumed request
alone cannot distinguish a screen/transport problem from an action/callback problem. Do not
label it a native crash or a confirmed menu bug. Next is a small diagnostic separating
transport availability from action evidence before another movement attempt, not a new lab
framework or a blind retry. The broader cast/interruption/contention matrix remains pending.

**Artifacts:** `.work/task9/movement-v1/` holds prepared commands, source identities, staging
records, preflight, accepted queue response, timeout, preserved request and cleanup receipts.
`.work/task9/host-final.log` records the lead's combined focused check:12passed, no skips
(both new reducer backends, both Task8 backends, existing capability/evidence schemas).
Initial worker RED/GREEN output is explicitly preserved as transcript excerpts, not full logs.
Original installed resources, personal paths, saves and private logs are not committed.

**Evidence and next decision:** E1 queue/hook inspection + E2 state-model proof + E4 queue-entry
observation, with E4 start/completion unresolved. Task9 stays in progress, G1 stays open and
production active control remains forbidden. No creative/gameplay decision is needed for the
next diagnostic; do not reinterpret this checkpoint as approval to migrate live content.

## Follow-up: dialogue removed the console host — 2026-09-28

One separately prepared hidden diagnostic reproduced the same movement request. A private
bounded file observer wrapped existing menu open/close callbacks, preserving their original
functions and return values, and recorded the fixture's action-start callback. Independent
source review checked the EEex registry-wrapper API and callback lifetime before launch.
This observer writes copied scalars only and remains independent of console menu polling.

Observed sequence (UI elapsed milliseconds, **not simulation timing evidence**):

- 40571: requested the one ordinary movement; same-chunk response again accepted exactly
  one queued ID23 at(232,186), starts0, position(200,186).
- 40592: fixture action-start callback ID23 at position(200,186).
- 43229: WORLD_ACTIONBAR closed; WORLD_DIALOG and WORLD_DIALOG_CONFIRM opened.

The console's pinned default hosts are WORLD_ACTIONBAR and START. Its close callback removes
EEEX_REMOTE. This directly establishes a dialogue/transport interruption in the diagnostic,
not a movement crash. The original run had no menu log, so its exact historical sequence
cannot be reconstructed. Neither run proves the final movement position. No redundant command
was sent into the now-absent console host, no dialogue choice was made, and no save was created.

Static explanation: effective BG2602 contains SHANK_, whose override INITDLG initiates dialogue
when it sees a PC and has not talked. WeiDU24900 decompiled the actual effective INITDLG.BCS.
The diagnostic did not identify the conversation speaker; Shank is the source-backed cause
candidate, while the menu transition itself is observed E4 evidence.

| Effective source | SHA256 |
|---|---|
| BG2602.ARE | `b5dd336565c6f2d334b6f75857d8cb74f867b7403110329b3f846fd01c7f968b` |
| SHANK_.CRE | `39d891ecc82042389897bb5080b548df924bb960014bb5137850e768a4547f86` |
| INITDLG.BCS | `27ca95c7fcc2711c222267fcf76d4219ec7793a2e386cf1bea87f8f9af96fc44` |
| M_EEexRC.lua | `17928ec474d5316d7cc87c20489fb2d93529971cb3ceea5cf64856f47fed3e3d` |

Artifacts: `.work/task9/transport-diagnostic-v1/` contains the exact private observer, decompile,
source pins, menu/action TSV, queue/preflight responses, and cleanup receipts. Same Task8 stack,
executable and separate Steam-disconnected profile. Cooperative reservation was absent and the
bounded game/installer process snapshot empty before acquiring our exclusive token; the peer
was preparing its next test, not running a game in that snapshot. Our helper/loader/game were
closed and verified absent; eight temporary additions and IPC removed, original menu/config
restored, matching reservation released. No full copy or new save.

Next: a small private quiet-area/caster fixture for ordinary casting. The existing sole
protagonist has no known or memorized spells, so it is not a valid ordinary-cast fixture.
Use real memorized spell expenditure plus an independent effect postcondition, not forced
casting. Task9 and G1 remain open. This fix is experiment isolation, not gameplay design or
a general Remote Console repair.
