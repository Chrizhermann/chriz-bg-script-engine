# Task9 action observation experiment

Research only; no autonomous combat AI or ownership authority. Use only the approved hidden,
Steam-disconnected lab and its named `BGSE Lab Test` character. Never stage in the active game.

## Explicit resource allocation (before source creation)

| Logical artifact | Engine filename | Host source |
|---|---|---|
| `synthetic.action-state` | `B-XACT00.lua` | `action_state.lua` |
| `synthetic.action-probe` | `B-XACT01.lua` | `B-XACT01.lua` |
| `synthetic.cast-probe` | `B-XACT02.lua` | `B-XACT02.lua` |
| `synthetic.adverse-cast-probe` | `B-XACT03.lua` | `B-XACT03.lua` |
| `synthetic.cast-fixture` | `B-XMAGE0.CRE` | Private output of `build-cast-fixture.tp2` |

These synthetic-only stems are explicit unique allocations, not hashes/truncation of adapter IDs.
No cross-extension reuse. All allocated filenames must be absent before staging; no release publication.
The probe uses existing `_G["B-"]` established by the Task8 experiment; repeated initialization
refuses to register twice. There is no extra autoload bootstrap.

The first engine question is deliberately small: one normal `MoveToPoint` on the sole test
character in the named lab area, while idle, then a separately sampled position postcondition.
No forced movement, queue clearing, spell/effect shortcuts or retries. A position at the target
before queuing cannot count as success. The callback is evidence of start, never completion.
Only scalar observations are kept, never actor/action userdata or engine object IDs.
Acceptance additionally requires observing exactly one queued action with ID23 and the
requested destination. The later start callback must match that destination; its reducer result
is recorded. Unexpected synchronous start or queue contents produce `unknown`, without retry.
This single-fixture correlation is not a production ownership token or an uncontended lease.

Host reducer contract is in `docs/research/ACT-01-action-state-model.md`. Cast outcomes,
interruption, contention, target invalidation and Project Image exclusion remain later Task9
work, not silently covered by the movement case. Runtime evidence is recorded separately.

First run: the exact queue entry was verified, but the later console sample timed out and
remained unconsumed. No start/completion result was recovered. This is a partial research
checkpoint, not a passing action observer. See ACT-01 for evidence and the next diagnostic;
do not repeat the failed run directory or claim that a timeout cancelled the queued action.

The separate diagnostic observed action23 start, then WORLD_ACTIONBAR closing and dialogue
menus opening. This removed the console's host. The old room contains a dialogue-initiating
NPC; ordinary casting therefore needs a quiet private fixture, not a console rewrite.

The caster uses the synthetic local death variable `B-XCAST0`. Build privately with WeiDU
`--nogame`; original installed ARE/CRE inputs remain unchanged. Temporarily stage the patched
BG2602.ARE only in the disposable lab, preserving/restoring its exact original bytes. Load our
earlier own save973, which has never visited BG2602, not the baked room in save974. No new area
art is copied. Generated ARE/CRE bytes remain private and are never published.

`B-XACT02.lua` is explicitly loaded after the unique nonparty ally is created and settled in
the quiet room. It submits one ordinary self-targeted effective SPWI212 (Mirror Image on this
stack). It never grants spells, forces casting, resets aura, changes effects, or clears queues.
Completion requires correlated start plus exactly one spent memorized copy and a new timed
source-SPWI212 opcode159 effect. Counts/timers/effects are independently sampled after engine
progress. An empty queue alone cannot complete. This proves only this synthetic actor/stack,
not fairness under contention, every spell, or Project Image ownership.

The first quiet-session cast passed: one matching start, both available counts2->1 with
total2 unchanged, and new source-SPWI212 op159/206 effects. The unchanged movement probe
also reached(232,186) from(200,186) after its matching start. See ACT-02 for the setup correction
(use the console area helper, not MoveBetweenAreas for the party), exact evidence and remaining
negative cases. All temporary lab resources were removed/restored; no new save was made.

`B-XACT03.lua` is a bounded follow-up, explicitly loaded once after B-XACT02. It observes
four separate fresh-fixture trials: natural busy aura, temporary silence, appended ordinary
movement and one small damage condition during windup. It reuses the console poll, not a new
scheduler. `observed-window` is an observation cutoff, never success or cancellation. The
started listener and per-tick snapshots copy scalars only. Silence/damage injection is fixture
setup for negative cases, not a shortcut to spell success. Reset our own baseline between cases.
See ACT-02/03/04 for the actual findings, one corrected pre-intervention assumption, unknown
movement result, private evidence and remaining Task9 work. This remains research, not AI.

After the documented private setup, load both probes once per process:

```lua
assert(loadfile('override/B-XACT02.lua'))()
assert(loadfile('override/B-XACT03.lua'))()
return _G['B-'].adverseProbe.begin('aura')
```

Retrieve `_G['B-'].adverseProbe.trials.aura` after its status becomes `observed-window`;
the raw samples/events, not that status, determine the outcome. For each remaining kind
(`silence`, `contention`, `damage`), reload the exact own save973 using the existing QA helper,
use the documented CLUA room setup and recreate the caster. Then call `begin(kind)` once,
without reloading the Lua modules. Do not overlap trials or auto-retry an error/missed window.
The current code includes the evidence-driven one-copy-spent windup correction. Exact private
launch/stage/reset/cleanup recipes and the two original deployed versions remain with the runs.
