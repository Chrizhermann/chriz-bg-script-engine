# Active Combat Intent pilot — current-stack batch

**Status:** Connected ordinary casting, disable, full paired legacy handback and paused-native
load reset observed. Earlier endpoint/debit assertions failed and are retained. G5 records
the precise development admission, not broad supported-stack acceptance.

**Question:** Can the new chooser cause one ordinary action, recognize its actual result,
stop claiming actions when disabled, and return control to the original script?

## Environment and method

BG2:EE2.7.3, current tested EEex1.2/LuaJIT, the existing EET/SCS lab and TrueTime configuration;
exact executable/API/spell pins are retained in the private Task25 receipt and match G4.
The game/profile/baseline are the same isolated lab used for the preceding research. No new
copy or save was made. The sole protagonist, three authored hostile mage fixtures and passive
opposing target occupy quiet BG2602. Only two mage identities are admitted. This is not an
actual SCS mage-family adapter or a whole-install compatibility test.

The default-off active bundle joins scalar sensing, eligibility/ownership, candidate generation,
utility, seeded choice and two fresh dispatch checks to a one-action lease. Its native bridge
accepts only ordinary actor-target SPWI112 through `SpellRES`. The combat-only experiment omits
preparation-helper activation; area candidates retain their unknown-geometry exclusions. Existing
test-vector weights are not gameplay defaults. There is no direct effect, free spell, manual
debit or queue clear. The third mage remains exclusively legacy-scripted.

One hidden process runs four cases, with own named-baseline reload and fixture recreation:

- Baseline: default-off refusal, two sequential AI-selected casts, then three original-script
  Strength casts and movements.
- Disable during a started cast: invalidate the claim and prevent further submissions while
  allowing the ordinary engine action to finish; verify legacy cast/move afterward.
- Replacement: after start, the protagonist submits the previously proved ordinary ActionOverride
  move. Actual displacement before damage plus sustained no damage can support a bounded
  interruption inference; ambiguous ordering remains unknown.
- Load after start: capture actor/target/bookkeeping before requesting the own baseline, then
  verify all enrollment and claims clear. This does not prove native pending state at destruction.

Every accepted action needs a matching start, real spell-copy expenditure and an independent
closed-scene postcondition before completion is reported. Damage attribution here depends on
sequential attacks, a passive target and no other damage source. The prototype does not claim a
general damage-attribution API. Raw decision inputs/results are data-only JSONL and replayed
outside the engine on both Lua backends. The method is in the combat-pilot README.

## Counterevidence and correction

The first attempt accepted/started an AI-selected cast, removed its ready copy and reduced the
target from37HP to27HP. The experiment nonetheless timed out: its sparse ready-spell map omits
zero-count entries, but the completion predicate compared the missing value directly with zero.
This was a recorder defect, not evidence of a failed native cast. The failed812-row trace and
source were preserved. A host reproduction confirmed the incorrect and corrected predicates.
The corrected comparison retains all other completion requirements. Closed-run listener-trampoline
reuse allowed a reset/corrected batch in the same process, without a new native listener or launch.

## Observations and bounded results

- Corrected baseline passed: mage0 chose/submitted/started SPWI112, spent its only copy and
  reduced the target37→28HP. Mage1 then independently chose/submitted/started it, spent its copy
  and reduced28→19HP. The completion reducer received independent postconditions only after
  those observations and idle state. Three subsequent legacy Strength casts, op44 effects,
  copy debits, movements and completion markers met the original assertions.
- Disable-during-cast passed: a started claim was invalidated immediately; the already-running
  ordinary cast finished (37→28HP) without queue clearing. No new claim followed. All three
  original scripts passed their cast/move assertions and own-load reset.
- Replacement produced observed Move23 displacement before damage and no target damage over
  the following150ticks. The ordinary claim was classified interrupted by this bounded
  closed-scene inference. All three legacy Strength casts, copy debits, op44 effects and
  completion markers resumed. But mage0 stopped at(264,258), outside24pixels of(304,240):
  **the full endpoint assertion failed and remains failed**.
- A control with Combat Intent closed throughout moved the fixture to the same(232,270)
  starting position, then ran the unchanged legacy sequence. It reproduced exactly(264,258)
  and the same completion marker. This proves the short route can occur without our AI,
  not its precise pathfinding cause. A single reviewed nearby-intervention attempt also
  interrupted the cast and resumed legacy behavior but stopped at(280,234), about24.74pixels
  from the destination. That assertion also remains failed. No thresholds were relaxed and
  no further endpoint retries were made. Task28 retains this route/arrival limitation.
- Load-after-start passed the stated bookkeeping check: just before reload the spell was
  already spent, target28HP and caster idle, while one uncompleted observation record remained.
  Destruction invalidated that record; own baseline restored zero enrollment/pending claims
  and default-off state. This is explicitly **not** an engine cast-in-flight load test.

Four closed trace segments contain3830events and54decision records (including failed cases).
Every decision replays identically on Lua5.1 and LuaJIT. Seven selected SPWI112 starts were
logged across diagnosis/cases, not seven successful completed claims. Twelve logged legacy
Strength starts and their movements are distinct from the new AI's selected actions. The
separate route control is retained as its own receipt. Listener registration stayed one per
started/destroyed/loaded event despite closed-harness reuse. Raw world ticks regress during
load; file order and run/session context, not a single sorted tick axis, establish ordering.

Across562 completed recorder callbacks in corrected segments, median1.033ms, p952.017ms,
max95.754ms including verbose JSON I/O/replayable input construction. Sparse dispatch bursts
are much costlier than idle observation; this meets the declared300ms development ceiling
but is not a production decision-latency, allocation or full-encounter budget. Failed callback
durations are not included. The host suite passes202checks on both Lua backends where applicable.

All13 staged targets were reconciled: three originals restored, ten additions and owned IPC
removed. Own processes stopped; the matching reservation was released. No game copy/new save,
personal-profile change or active-game write. Full private receipts/source versions/traces are
under the Task25 active-runtime checkpoint. Independent review separates ordinary-action
ownership evidence from the unresolved legacy endpoint assertions.

The [IESDP action reference](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm#23)
describes MoveToPoint's intended destination, but provides no guarantee for our24pixel threshold
or explanation of this observed short stop; it does not resolve the runtime counterexample.

## Evidence limits

### Reviewed follow-up: paired legacy behavior and paused native action

A second combined session reused the identical product bundle and fixture assets, with one
native listener per event. Before execution, G5 declared a full AI-off control versus active
replacement comparison and a synchronous pause at native cast start. This does not substitute
an easier endpoint assertion: the old endpoint tests remain failed, while the new question is
whether handback preserves the original script's actual behavior. Movement is not admitted as
a Combat Intent action by this result.

The full control completed. The first differential failed an incorrect new assertion: it had
one action31 start, Move23 at three ticks later, real displacement, no damage for150ticks and
an idle caster, but the spell remained available. Starting an action does not prove debit.
Independent trace review and a focused source-predicate RED/GREEN reproduction established the
correction: interruption permits exactly zero or one spent copy, records which, and still
requires one start, displacement before damage, sustained unchanged target HP and idle state.
Missing/duplicate starts, increased or over-debited copies still fail. Successful completion
still requires one debit and its independent effect proof. No product action code changed.

One corrected differential in that same session spent one copy, interrupted without damage,
then produced the same full legacy result as the completed control for all three actors:
each had the same ordered six original-script actions, Strength copy2→1 and source op44 effect,
actual movement, final HP/other ready copies, idle/empty queue, phase4 and done1. Before-legacy
positions and final positions matched exactly: (264,258), (360,246), (408,246). The first remains
outside the original24pixel threshold in **both** control and treatment. This establishes the
bounded handback comparison, not a pathfinding explanation or successful arrival at the goal.
The failed differential never reached legacy and contributes no passing handback evidence.

The independent load case paused synchronously at the sole matching Magic Missile start.
Immediately before named load, native action31 was still present, the world paused, target37HP,
one copy still ready and one active pending claim. Destruction invalidated that claim; completed
load had zero enrollment/pending claims, default-off state and no automatic reissue. Own pause
was released. This proves reset from an observed running action, not serializing/resuming it.

The three closed follow-up segments contain1190/66/732rows and10/8/8decisions. All26 decisions
replay on both Lua backends; together with the earlier54, that is80 saved active-batch decisions.
The full legacy comparison checks18ordered actions, not just completion markers. All372 completed
recorder callbacks: median0.9945ms, p951.885ms, max104.074ms with verbose recording. The same
small-scene/development-budget limits apply; failed callback cost is not included. Full current
host suite still passes202checks. No broad tooling tests were added.

The owned process tree stopped; all13 targets were reconciled (three originals restored, ten
additions removed) and owned IPC preserved/removed. Matching reservation released. No new game
copy/save, personal-profile change or active-game write. Private Task25 active-runtime-v2 keeps
source versions, failed/corrected traces, commands, tool identities, replay and cleanup receipts.

Host simulation, source inspection and this bounded engine batch are E1+E2+E4, not E5. Current-stack
development admission must not become a general SCS-family/support claim. Wider stack combinations,
actual SCS prebuff helper accounting, area geometry, broader actor/control closures, image/summon
families, full-encounter performance/allocations and supported-corpus soak remain on the roadmap.
Earlier G1/G3 research and host lifecycle checks remain complementary evidence, not unrun active
cases. Neither load case proves saved in-flight continuation. The second proves invalidation
after an actually paused native start; the first remains bookkeeping-only counterevidence.

## Connected ordinary defenses — 2026-10-12

The reviewed extension connects ordinary self defenses to the same default-off action path.
Explicit profile admission adds self Shield/Mirror; the default without that map remains
actor-target Missile only. Both fresh decisions must preserve the exact selected descriptor;
native submission re-resolves the self identity and queues normal `SpellRES(...,Myself)`.
Profile-owned effect markers avoid treating the reference spell's effect count/order as a
universal layout. Alternate declared resrefs, unrelated/reordered effects and stale/buffed/
spent exclusions are host-tested on both Lua backends. No SCS forced helper is dispatched.

The existing four-actor scene and original fixture bytes were reused in one hidden session.
Test-only scores30/20/10 produced Shield → Mirror → Missile on each of two enrolled mages.
All six selections passed native action31 start, one ready-copy debit, later source-specific
protection or target damage, and idle completion. Target HP was37→26→14. Each mage retained
one of its original two Shield copies; subsequent decision records exclude it as already
protected rather than removing or spending the spare copy. Both protections remained present
through the final legacy sequence. The third mage retained both Shield copies and its Mirror.

All three original scripts then started Strength, spent one copy, acquired its source-op44
effect, started and completed observed movement, and reached idle/empty queue plus done marker.
Arrival distances are diagnostics, not a new pathfinding admission or erasure of prior failures.
The named baseline load cleared enrollment/pending state and left dispatch off. No save created.
The closed trace has1944events and38decisions; all replay identically on Lua5.1 and LuaJIT.
Independent raw-trace review confirms one expected default-off refusal followed by six accepted
requests and six started/completed outcomes, not merely matching final-looking spell effects.

The full current host suite remains216checks/38files (existing groups expanded, no broad tooling
suite). Recorded368 callback durations max51.365ms against the same300ms development ceiling;
this includes verbose logging and is not a production encounter-scale budget. A separate read-only
status query used invalid Lua indexing syntax, failed before reading state, and was corrected
with `rawget`; the failed RPC is preserved and is not a failed gameplay trial.

Private reproducibility packet: Task25 `multi-runtime-v1` contains config, exact sources, build,
predeclared G5 extension, stage/cleanup ledger, commands, trace, checker and replay. Bundle SHA256
`41389ECCEAD81F1B0FF2CB1D73682D8FBAD789F50ACB8A26FDF19ED56A410083`; harness SHA256
`408E706065942E4CFA76C25B09CBF3630E87C1AF7D6049A815F5B7ECF1BA4C8B`.
The same process also ran the separate priest shadow comparison. Afterward the owned
hidden launcher exited0, lab-process absence was checked,13temporary additions were
removed and three originals restored to their recorded hashes; the matching reservation
was released. The G5 extension is accepted for this exact development fixture. No new
game copy or save was made, and the active game/personal saves were not used.
