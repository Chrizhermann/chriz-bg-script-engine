# Task9 damage interruption — bounded E4 result

**Question:** Can an ordinary cast spend its resource but be interrupted before effect delivery?
**Environment/method:** [ACT-02](ACT-02-cast-observation.md) pins the stack, quiet synthetic ally,
spell and source. Fresh own save973, no scripts/dialogue, current0, empty queue, HP37 and two
ready copies. Queue one ordinary self-cast. At a later tick with matched start, current31,
one spent copy and no spell effects, impose one small damage effect on this caster only:

```lua
EEex_GameObject_ApplyEffect(sprite, {
    effectID=12, targetType=1, effectAmount=1, dwFlags=0, durationType=1,
    effectList=1, noSave=0, immediateResolve=1,
})
```

This is a controlled adverse condition, not an attack/spell-delivery fairness test. The
[opcode12 definition](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op12) describes normal
crushing damage; observed HP loss, not the API return or requested amount, is the proof it landed.
No source/target engine handles are retained; no queue clear, forced cast, refund or retry.

**Observed — 2026-09-29:**

- Submission32551; matching ID31/SPWI212 start32552; at32553, current31 and count/ready2->1.
- 32555 before intervention: HP37, current31, count1/ready1/total2, aura2, no spell effects.
  Same-call post-damage snapshot: HP36, otherwise the same observed fields.
- 32556: current0, empty queue, HP36, count1/ready1. Casting did not reach its prior quiet-case
  effect-delivery interval. No source-SPWI212 effects appeared in any of450samples32552–33001.
- Final: HP36, one copy still spent, aura-1, no effect and no later queued action.

This is evidence of interruption under this controlled damage condition. The causal attribution
is an inference from the intervention and immediate early action exit, not a native
`interrupted` callback/reason code. It is not a claim that all damage always interrupts, that
every caster/stack behaves the same, or that a spent slot can prove spell completion.
All450 samples were consecutive, maxgap1tick; the observer recorded no error.

**Counterevidence:** expenditure and action-start had both occurred despite no delivered effect.
**Artifacts:** private `adverse-v2/begin-damage.json`, `result-damage.json`, exact deployed source
and staging/cleanup records. Source SHA256 is the ACT-04 revised pin. No generated assets published.

## Loading an earlier baseline after observed cast windup — E4

**Question/method:** Does the observer discard its old attempt across loading? Same pinned
stack/quiet caster, one ordinary cast, then the existing queued-menu helper loads our own
baseline973. No new save or action handle is retained. `load-boundary.lua` requests load only
after matched start, current31, one-copy debit and no source effects; it does not sample sprites
during loading. Afterward it resolves the protagonist afresh and observes 100 game ticks.

**Observed — 2026-09-29:** accepted at32780; at32781, matching start, current31, count/ready1,
total2 and no source-SPWI212 effects. Four queued menu events completed the exact load.
The attempt became `invalidated/session-destroyed`. Fresh BG2600 state at32129 and32229:
protagonist current0/queued0, no synthetic caster in that area, matching cast starts still1.
The clock rollback reflects the earlier save; it is not a continuous action-duration measure.

**Limits/counterevidence:** this proves the observer's load-boundary invalidation following
observed windup, not the cast's exact state at session destruction or whether effect delivery
occurred between the load request and destruction. The loaded baseline does not contain the
caster, so this is not saved-in-flight-action persistence proof. The 100-tick window and current
area check do not prove universal continuation safety. `beforeLoad.observed` captures the
within-tick windup change omitted by the deduplicated sample list; its event table is live
until JSON retrieval, whereas snapshot/attempt records are replaced rather than mutated.

**Artifacts/reproduction:** `experiments/action-observer/load-boundary.lua` SHA256
`40518f4fe4d4b71d5f64858cd23cccd0570481a8512b51c9f6a80d74a2451f9f`;
unchanged B-XACT02 `4159d0d0c00485b486c24e0743e4f4fc2c5ca10f941a21eefd4762f74c01bf46`.
Installed EEex_GameState.lua Destroyed-listener source pin:
`0b7088f2e0c366fccd5b08e425eb70a7d009223377140788fd298cecbf3a9ff9`.
Private `load-boundary-v1` keeps exact staging/QA/launcher recipes, submission/result JSON,
tool identities and cleanup receipts. Explicitly load B-XACT02 after baseline/quiet-room/caster
setup, submit the host chunk once, retrieve `loadBoundary` after complete/failed; never retry
within that process. Independent static and result review accepted the bounded claims.
Existing 12 focused host checks passed; the chunk compiled under both Lua 5.1 and LuaJIT.
One hidden session, no new save/copy; own processes stopped, nine additions removed,
ARE/menu/settings restored byte-exactly and reservation released.

**Residual uncertainty/next:** active-action area transition, saved-in-flight-action persistence,
Project Image owner exclusion and real player/legacy replacement remain unproved. Later bounded
target cases are below/in ACT-04. Task9 remains in progress, G1 open; no production ownership/
fallback schema is changed here.

## Target death during ordinary targeted casting — partial E4, 2026-09-30

Use the [targeted baseline's](ACT-02-cast-observation.md#ordinary-targeted-cast-baseline--e4-2026-09-30)
exact stack/probe and fresh own973/room/pair. Ordinary SpellRES accepted at32682 and matched
one ID31/SPWI214 start that tick. At32686, current31, ready1/total2, target alive and effect-free:
queue `Kill(Myself)` once on the synthetic target. Queue ID131 is submission evidence only.
Its matching target start was32687. At32688 the target was independently observed with HP0,
base/active state2048 and dead=true; caster current became0 with one spell copy still spent.

The450 consecutive samples cover32683–33132. Target lookup succeeds only32683–32688:
no source-SPWI214 effect appears in those six samples. From32689 onward the target is absent,
even with corpse-inclusive lookup. Death was proved before disappearance; disappearance itself
is **not** death proof or evidence of no subsequent delivery. Later corpse/object effects are
unknown. Early caster action exit is consistent with target invalidation, not a native reason
code or proof that all dead targets reject spells. No refund was observed in the caster trace.

Private `target-runtime-v1/death-final.json` preserves metadata and all450 samples. Independent
review confirmed the six-sample visibility limit. No blind retry or extra corpse experiment;
session cleanup is recorded in ACT-02. Remaining ownership/transition/Project Image work and
G1 stay open; this result must not become a universal cancellation or corpse-immunity rule.
