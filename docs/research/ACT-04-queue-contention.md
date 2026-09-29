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
consecutive. The reason for the stationary move is unproved (no pathfinding/eligibility probe);
do not label it a successful move, engine crash or cast interruption. Earlier protagonist
movement to a different point succeeded, but does not resolve this caster's result.

**Artifacts:** private `adverse-v2/begin-contention.json`, `result-contention-final.json`,
exact deployed source/staging and cleanup receipts. Revised source SHA256
`be7c29f23100ca210c60c93a464b003a377c360bff60638fdfc95c7883dc5547`.
**Counterevidence:** action start and later empty queue failed to prove the requested position.
**Next:** retain unknown movement outcome; real player/legacy replacement and ownership loss
remain unproved. No queue-clearing/retry policy or production lease is authorized. G1 open.
