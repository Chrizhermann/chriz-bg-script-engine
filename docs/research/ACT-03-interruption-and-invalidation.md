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
**Residual uncertainty/next:** target death/movement, active-action area/save-load invalidation,
Project Image owner exclusion and real player/legacy replacement remain unproved. Session
teardown invalidation already has Task8 evidence, but does not close those action-specific cases.
Task9 remains in progress, G1 open; no production ownership/fallback schema is changed here.
