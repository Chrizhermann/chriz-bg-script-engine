# Active Combat Intent pilot — current-stack batch

**Status:** Connected ordinary casting, disable and load reset observed; replacement endpoint
checks failed and are retained. G5's precise admission decision is recorded separately.

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
  no further retries were made. Task28 retains this route/arrival limitation.
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

Host simulation, source inspection and this bounded engine batch are E1+E2+E4, not E5. Current-stack
development admission must not become a general SCS-family/support claim. Wider stack combinations,
actual SCS prebuff helper accounting, area geometry, broader actor/control closures, image/summon
families, full-encounter performance/allocations and supported-corpus soak remain on the roadmap.
Earlier G1/G3 research and host lifecycle checks remain complementary evidence, not unrun active
cases. Do not describe the load-after-start result as a saved in-flight action continuation test.
