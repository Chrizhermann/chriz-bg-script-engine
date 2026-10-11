# Priest Turn shadow: authored-fixture comparison

2026-10-12 — Task29 comparison checkpoint, G6 not yet reviewed.
**E1+E2+bounded E4; no active priest adapter or full-priest support claim.**

Question: can the existing eligibility, ownership and replay machinery represent a
second SCS family with different behavior, without building another testing framework?
The selected family has two timer-driven Turn Undead branches, not another spell ranker.

## Host checkpoint (2026-10-04)

The authored scalar reducer preserves the selected branch order, coupled target
predicates, timer arguments and later active-window choice. It reuses the existing
manifest/ownership/snapshot contracts and records a replayable no-dispatch proposal.
An initialization proposal requires a fresh observation; it does not write timers or
execute SCS's same-pass Continue. This shadow boundary is not a gameplay redesign.

Five grouped scenarios run on each Lua backend: initialization/replay; subsequent
window/cooldown; false or unknown predicates; resource/family/control/ownership/stale
observation rejection; and invalid data/tampered replay. Tests contain no game assets.
Independent review found missing family scoping; its failing test was reproduced,
then exact manifest ID and authored priest-root checks were added. The register's
obsolete mage-only wording was corrected at the same checkpoint.

Reproduction from the repository root:

```powershell
./scripts/test.ps1 -Suite unit -Filter priest_turn -Seed 47
./scripts/test.ps1 -Suite all -Seed 47
```

Focused result: 2 passed, including both backends and all five groups. Combined
result: 216 passed across 38 files. Python3.11.9, Lupa2.8, Lua5.1 and
LuaJIT2.1.1774896198. This is host evidence, not a priest executing Turn in the engine.

## Source and initial reader boundary (historical checkpoint)

The [family ledger](../provenance/scs/priest-turn-ledger.md) pins SCS35.21/component6040,
source/effective hashes, the exact offline byte-identical roundtrip and its limitations.
The decompile emitted179 missing-ID diagnostics; these remain recorded, not dismissed
as a clean whole-script translation. Its installed neutral priest is not enrolled:
an earlier NoAction block and unresolved encounter control prevent that conclusion.

Next: build one authored private priest/undead scene and observe a useful continuous
legacy batch spanning initialization, active window, cooldown and target-state changes.
Compare the existing shadow decisions against observed legacy timer/Turn behavior.
Do not evaluate a stateful See trigger as an allegedly mutation-free reader: its
selected-target state needs a reviewed observation method. Native trigger evaluation
has not been attempted. No native Turn dispatch is authorized by this checkpoint.

Bounded reader research (E1): installed `EEex_Object.lua` resolves LastSeenBy through
native Decode/GetShare, not a source-proven passive getter. `getLocalInt` can read
raw timer values without evaluating See, and world time is exposed, but exact
GlobalTimerNotExpired equivalence remains unproved. Independent extraction and lead
source inspection agree. Exact wrapper hashes/lines and the proposed observation
boundary are retained in `.work/task29/turn-source-v1/reader-evidence.md`; no native
call was made. Reuse these findings rather than repeat the source investigation.

Those were the pre-batch limits. The following result supersedes the unexecuted-batch
status, not the unresolved full-actor/source-closure limits.

## Connected disposable comparison — 2026-10-12

Environment: approved BG2:EE2.7.3.0, EEex1.2.0/LuaJIT, EET14, SCS35.21,
SR4.21-chriz.5, Bubb Spell Menu5.2, WeiDU24900. The private authored scene used
cleric B-XPRST0, one B-XUND00 skeleton and the own test PC in quiet BG2602. It ran
after the connected mage batch in the same hidden process, reloading only the own
baseline between intervals. Nothing was installed in the active game; no save created.

The priest has only the authored B-XPTUR0 default script. It preserves the two selected
SCS branch conditions/timer arguments/Continue/Turn order, adding two local counters.
Those counters may affect scheduling: this is an instrumented two-rule comparator,
not an unmodified SCS priest. Private WeiDU parse/build/compile/decompile exited0;
all unrelated donor fields were preserved. CRE hashes are
`3B16B329F0E6A48B2EC0A1AD52D25EF6D0162AF17464C33334279CAEC71EE869` and
`C065036EE9E29E0EDF0D42C3E6D97164EE5B5DC5AF6FEEC37BBE28D2317631E1`;
BCS `4DE9F134A20721167FF51E1FACA08E83E9A220ED98E7D12FD0E16D10B266DED5`.

Two90second intervals closed normally, each273rows and12 native action33 starts.
The first reader found `m_lSeen` userdata, leaving target identity unknown. Its trace
and original sampler remain preserved. A bounded source-backed read-only probe then
verified `m_lSeen.m_Instance` as numeric, matching the sole visible undead. The refined
sampler recorded marker match and unchanged-before/after LOS collection, without
calling See/Decode or mutating the marker. Lua5.1/LuaJIT compilation passed before use.

Independent refined-trace review and lead checks establish:

- 53 no-undead samples at ticks34532–34792: no initialization/Turn counters or starts.
- Undead first observed at34797; first native Turn start34804. The marker is not yet
  matched in the first two target samples, then matches in214 of216 target samples.
  The first branch is therefore instrument-witnessed, not independently predicted
  from a pre-action selected marker. The later windows have independent bound samples.
- Three initialization cycles, with deadlines35254/35718/36182 and turning deadlines
  34864/35328/35792. Paired deadlines differ390ticks, consistent with30s/4s at15ticks/s.
  Twelve actual Turn starts accompany four branch hits per active window, with no
  additional hits in the intervening expired windows. Exact equality boundaries remain
  unknown; a sampled deadline is not a native trigger-equivalence proof.
- After Turn begins, the skeleton moves under action354 from(320,204) to(504,378),
  then holds. It remains alive at8HP; no disabled/dead bits were observed. This is
  independent target displacement in the isolated scene, consistent with turning,
  not a demonstrated disabled/dead-target branch or every possible Turn outcome.

The global priest action listener was registered once and reused, not duplicated on
reload. The private90s logger recorded269 periodic samples per interval and closed
without error. Its callback duration was not instrumented; no production runtime-cost
claim is available from the sample cadence or brief RPC durations. G6 must retain that
measurement gap rather than inventing a migration-cost estimate.

Offline comparison feeds only the independent refined fields into the unchanged scalar
reducer; counters and action-start counts are outputs, never predicate inputs. The actual
authored resource hashes/sole default script bind the comparison manifest. Higher-owner
absence is the controlled-room assumption, not a new general-purpose runtime reader.
All270 snapshots (opening plus269 periodic) replay identically on Lua5.1 and LuaJIT:
6initialize,33turn,231decline. The54 target-absent frames include the opening sample;
two visible-but-unbound marker frames decline. At exact timer equality tick35792 the
comparison records unknown/decline rather than guessing native boundary behavior.
Two later initialization windows precede the next timer/counter update; the first falls
between samples. All12 Turn-hit/start increments share sampled intervals; ten following
shadow frames say turn, two decline as action-busy. This is sampled correspondence,
not twelve exact native evaluation-instant predictions or proof of Turn completion.

Reproduce the private result with
`python .work/task29/priest-batch-v1/compare.py .work/task29/priest-batch-v1/refined-control-then-target.jsonl`.
The lead reran it successfully after source review; `refined-comparison.json` preserves
windows, output deltas, hashes and limitations. The fixture adds three files/6489bytes.
It reused the existing launcher, room, transport, reducer and replay; no new framework.
The two90s priest intervals fit the same approximately12minute hidden session as the
mage feature test. Coding/review token totals and callback costs were not measured.
One passive-reader correction was needed after actual field-type evidence; independent
trace review caught the limit of using only the final stationary target sample.

Method/artifacts: private Task29 `priest-batch-v1` retains the authored TP2/BAF, WeiDU
output, original/refined samplers, bounded field probe, exact launch commands and closed
traces; Task25 `multi-runtime-v1` holds the shared16-file stage/cleanup ledger. The own
launcher exited0, no owned lab process remained,13additions were removed and three
originals hash-restored; the matching reservation was released. No native priest
dispatch was added to Combat Intent, and installed A#AMNP remains unadmitted.

Unresolved: general See/LastSeenBy equivalence, equality boundaries, disabled target
behavior, exact same-pass scheduling without counters, and full encounter/controller
closure. None blocks the observed authored comparison; none is silently accepted as
full priest migration. Task30/G6 must use this bounded second sample and its actual
remaining costs, not extrapolate whole-family support.
