# Task9 appended-action contention — partial E4 result

**Question:** Does appending an ordinary movement request during casting cancel the cast?
**Environment:** Same pinned BG2:EE2.7.3/EEex1.2.0 comparison stack and private quiet caster
as [ACT-02](ACT-02-cast-observation.md). No active-game use, no player input injection.

**Method:** Fresh own save973/room/caster; `B-XACT03.lua` queues one ordinary self-cast. After
its matching start and3ticks, require current31, exactly one spent copy, total2 and no spell
effects. Append one `MoveToPoint([336.192])`,32units right of the sampled baseline. Do not clear
or replace the current action or queue. Observe450simulation ticks. EEex's pinned queue helper
appends actions; its source/hash are in ACT-01. This models a second append producer, not a
real player replacement command, running legacy script or ownership collision token.

**Observed — 2026-09-29:**

- 32638: exact queued31/SPWI212 and matching start.
- 32641: current31, count1/ready1/total2, no effects. After the append, queued23 while current31.
- 32658: action23 start callback. At32659, current23 and new source-SPWI212 op159/215/206.
- 32662: current0. Through33088, position remained(304,192), not requested(336,192).

Thus the spell's independently observed effect completed despite the appended move. Queue
ordering was observed; movement completion was **not**. All450samples32639–33088 were
consecutive. This was not a successful move, engine crash or cast interruption. The follow-up
below identifies a blocked destination and separately demonstrates that the caster can move.

**Artifacts:** private `adverse-v2/begin-contention.json`, `result-contention-final.json`,
exact deployed source/staging and cleanup receipts. Revised source SHA256
`be7c29f23100ca210c60c93a464b003a377c360bff60638fdfc95c7883dc5547`.
**Counterevidence:** action start and later empty queue failed to prove the requested position.

## Stationary movement follow-up — E1 + bounded E4

Read-only extraction of effective BG2602SR from DATA/EETBG26.BIF (resource68,
offset2061438, length978) gives SHA256
`1ae6874c491b95ed68174b00b3081adeaf4a3e329a8edebec7af439abf2cc51e`.
It is a 40x43, 4-bit search bitmap, 16x12 world units per cell. Original requested (336,192)
maps to cell(21,16), index0; baseline(304,192) maps to(19,16), index9. The
[IESDP search-map definition](https://gibberlings3.github.io/iesdp/appendices/search.html)
classifies0 as non-walkable obstacle and9 as walkable wood. The blocked destination is a
concrete explanation consistent with the failed move, not an observed native failure code.

In a fresh caster after loading baseline973, one ordinary move targeted a checked index9
cell at(232,216). At32748, the caster was idle at(304,192), and exactly one queued ID23
contained destination(232,216). Its start callback occurred32749. At32912, the caster was
at(232,222), current0/queue empty, with both memorized copies untouched and no spell effects.
This confirms ordinary movement by this caster; it **does not** prove exact requested-position
arrival (Y differs by 6), an arrival tolerance, or cast-plus-move behaviour for this new goal.
The original appended move remains a failed position postcondition, not retrospectively passed.

Private `load-boundary-v1/move-clear.lua` SHA256
`b7db6dbb721b9de53c852673ca262a6bafc713df34aac40c4e3c78fe09bf516f`,
`move-submit.json` and `move-result.json` retain the exact command and evidence. Same session
cleanup as ACT-03; no new asset, save, copying framework or production policy. Independent
read-only diagnosis was checked by the lead against the effective bytes and runtime observations.

**Next:** real player/legacy replacement and ownership loss remain unproved. No queue-clearing/
retry policy or production lease is authorized. G1 open.

## Target displacement during casting — bounded E4, 2026-09-30

Same targeted Strength fixture, pinned source and session as [ACT-02](ACT-02-cast-observation.md).
Fresh own973/room/pair, one ordinary cast: accepted32805, matching ID31/SPWI214 start32806.
At32810, caster current31/ready1/total2 and target idle/effect-free at(224,216): append one
target `MoveToPoint([232.264])`, observing exact queued ID23/destination. Its start32811 and
actual position(225,222) that tick prove displacement before delivery, not merely a queued move.

The target reached(232,270), current0/empty queue, by32818 and stayed there. First target
source-SPWI214 opcode44 appeared32833; the target had already stopped15ticks earlier.
All450 samples32806–33255 are consecutive, total memorized records remain2, one copy spent.
This proves delivery after displacement during casting in this fixture, **not** delivery while
still moving, exact arrival at requested(232,264), or range/line-of-sight boundary behavior.

Private `target-runtime-v1/movement-final.json` retains the full trace. Independent review
confirmed event/position/effect ordering and the stationary-at-delivery limit. See ACT-02 for
exact reproduction/cleanup; no policy change, new save, retry or G1 closure.
