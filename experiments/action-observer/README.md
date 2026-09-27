# Task9 action observation experiment

Research only; no autonomous combat AI or ownership authority. Use only the approved hidden,
Steam-disconnected lab and its named `BGSE Lab Test` character. Never stage in the active game.

## Explicit resource allocation (before source creation)

| Logical artifact | Engine filename | Host source |
|---|---|---|
| `synthetic.action-state` | `B-XACT00.lua` | `action_state.lua` |
| `synthetic.action-probe` | `B-XACT01.lua` | `B-XACT01.lua` |

These synthetic-only stems are explicit unique allocations, not hashes/truncation of adapter IDs.
No cross-extension reuse. Both filenames must be absent before staging; no release publication.
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
