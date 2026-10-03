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

## Area change and a save/load action sequence — bounded E4, 2026-09-30

Same [integrated session](ACT-02-cast-observation.md#integrated-session-project-image-exclusion-and-resumed-casting--e4-2026-09-30),
fresh own973/room/pair. Ordinary targeted Strength accepted32705, matching start32706;
current31 and ready2->1 at32710 precede moving the **protagonist** to BG2600. The caster remains
in BG2602. It is still casting in the last current-area sample32719; at32720 the protagonist is
in BG2600 and the old action observation scope is invalidated. Return requested32765; fresh
resolution32775 finds caster idle/empty queue with one copy spent, target without source-SPWI214
effects. No relevant effect was seen in any observed target row. The unobserved away interval
prevents a universal cancellation/no-delivery claim; this did not transport the casting actor.

Next, ordinary `Wait(20)` then `MoveToPoint([232.264])`: current63 plus queued23 is observed32777
before entering the save menu, and in the post-menu snapshot (reported tick32774). Existing QA
creates one new uniquely named own save, verifies GAM/SAV/BMP, and loads that exact folder.
Before loading, the live chain does run: Move23 starts33072, displacement33074–33087 reaches
(232,270). The game is not restarted between these steps.

Loading destroys the old session (epoch1->2) and restores world tick32760. Freshly resolved
caster is at original(304,192), current0/empty queue/ready1 of2; all361 consecutive post-load
samples32760–33120 retain those values. No move or automatic resubmission occurs. This proves
**no continuation in this loaded observation window**, not that a serialized queue was cleared:
the loaded tick predates the sampled Wait setup, and the exact serialized action state was not
inspected. Save timing/snapshot semantics and saved-in-flight spell persistence remain unknown.
Do not promote pre-menu or post-menu snapshots into proof of the bytes inside a save.

Private `integrated-runtime-v1/events.tsv`, `batch-final.json`, `own-save-verified.json` and
existing QA receipts preserve the complete evidence. Own save975 remains a tiny cleanup
candidate; no personal save was loaded or overwritten. Source/stack/cleanup pins and independent
review are in ACT-02. At this v1 checkpoint Task9/G1 remained open; no retry, refund or
queue-clear policy followed from it.

## Paused captures with independently verified saved markers — E4, 2026-10-03

The [second integrated batch](ACT-01-action-state-model.md#task9-research-exit--2026-10-03)
uses the same fresh baseline/quiet room/pair between cases, without restarting the game.
At the observed in-flight state, set a unique caster local `B-XCAPTURE`, query/pause through
the existing UI clock method, and save to a new own slot through queued menus. Read the actual
GAM/SAV and embedded BG2602 CRE offline; verify identity/capture locals and memorization flags.
Then change the live, unsaved marker by+1 and load that exact new folder. The original marker
must return. Re-resolve actors, unpause if necessary, and observe without any resubmission.

| Case | Paused capture and saved bytes | Fresh post-load observation |
|---|---|---|
| Wait60 then Move | ID63 start32921; capture current63/queued23, position(304,192), marker10031. Own save976 contains identity93301/marker10031 and both Strength copies available. | Unsaved10032 discarded,10031 restored; idle/empty queue/unchanged position through961 consecutive unique ticks32909–33869. No Wait/Move continuation. |
| Ordinary targeted Strength | ID31 start32697, spent copy visible32701; pausing reports32700 with current31, ready1/2, target effect-free, marker10041. Own save977 contains identity93301/marker10041 and memorization flags[0,1]. | Unsaved10042 discarded,10041 and spent copy restored; idle/empty queue/unchanged position, no target source-SPWI214 effect through451 consecutive ticks32699–33149. No cast continuation or observed refund. |

This removes uncertainty about loading the intended capture and about persisted spell debit.
It does **not** identify raw serialized current-action/queue fields: those were not established
in the ARE/CRE formats. It proves the bounded save/load behavior, not universal engine queue
nonpersistence, a native interruption reason, or what every spell/projectile does during load.
The GAM clock is in game seconds; pause can reverse a tick. Saved clock values (32910/32700)
must not be used alone to infer that other saved state predates the capture. Phase-only rows
can also carry the prior sample tick; use actor snapshots, markers and session epochs.

Saved evidence pins (GAM / SAV):

- Own976: `f763b8875f355e36878c6d0b2afd37bce9ecc111479015866680f0f52a6a62fe` /
  `a5188c2fed539077a8fc7020999ead1fd7792e32eff66e80fab31f5b3426a053`.
- Own977: `dfa05382eb58b313bffb0a596b3a1e55349032c859677fdb0a90018edf174750` /
  `8baabfb546bfea3971e9a3789b7280650f705e79a4b31e90d438920ba1841077`.

The private one-off extractor checks SAV/ARE/CRE signatures and table bounds, CRE V2-effect
stride, opcode187 locals and memorized-spell entries. It is not a general save editor and
never writes a save. E1 format interpretation accompanies E4 observation; original v1 evidence
is not relabeled. Full trace/source review and cleanup are recorded in ACT-01. No automatic
retry, refund or queue-clearing policy follows from this result.
