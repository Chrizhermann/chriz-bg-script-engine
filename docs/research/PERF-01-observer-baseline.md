# Observer-cost baseline — Task10 research

**Question:** What does a small scalar observer add to this engine, and how much of the
measurement is the measurement itself?

**Status:** One E4 baseline batch completed and independently reviewed. This is not a production performance budget or closure of
the wider PERF-01/PERF-05 backlog. No gameplay latency/quality trade-off has been selected.

## Scope and reproducible method

Authored `experiments/persistence/performance-probe.lua` runs in one hidden disposable session.
For each scene it collects four windows: minimal telemetry, observer, observer, minimal telemetry.
Each window has two seconds of unreported warmup followed by ten seconds of buffered scalar
rows. Disk output occurs only between windows; the protocol excludes host commands during
measurement. One premature completion check in the actual run is disclosed and excluded below.
Scene counts, active-action counts and HP sums at each window boundary expose scene drift.
The same process and tiny fixtures are reused, resetting from our own baseline between scenes.

Minimal telemetry still validates the test scene and records a frame identifier, world tick,
clock interval, timer-pair cost and Lua heap size. It is **not an uninstrumented game**. Observer
mode additionally scans this bounded fixture area once per changed world tick, makes short-lived
scalar HP/state/action/queue/position snapshots and records machine-only diagnostics into a
256-row ring. No policy evaluation, resource parsing, spell scoring or production adapter runs.
Snapshot actor cap128 and trace caps are experiment limits, not intended feature limits.

`EEex_Utility_GetMicroseconds()` is the installed documented initialization-relative microsecond
clock; `EEex_Utility.lua` SHA256
`f6bea5aa38a4c1da9888dda2ee87bb26230a08ccfdd0794978825aa71a70decb` lines79–86 forwards
to `EEex.GetMicroseconds()`. Installed options code subtracts samples to measure elapsed time.
The probe rejects observed clock reversal. Its deltas are **callback-frame intervals**, not GPU
render times, OS CPU time or AI-pass durations. Snapshot work times include native reads, scalar
allocation and bounded diagnostic recording, but not TSV conversion/collection or common
telemetry. Those costs can affect the callback interval and Lua heap in both modes.

Report distributions separately for each phase and for actual snapshot rows. Quantiles use
linear interpolation at `(n-1)*p`. ABBA ordering reduces simple ordering bias but does not remove
JIT/GC/engine-load variability. A changing fight/summon scene is descriptive workload evidence,
not a controlled estimate of causal overhead. Heap samples include instrumentation buffers;
they are neither retained-runtime memory nor proof of a memory leak. Process working set is
recorded separately before/after, not attributed wholly to the observer.

## Environment and fixtures

AMD Ryzen7 7800X3D, eight cores/sixteen logical processors, Windows, BG2:EE2.7.3.0,
EEex1.2.0/LuaJIT, EET14, SCS35.21, SR4.21-chriz.5, Bubb Spell Menu5.2. Same isolated profile
and disabled lab Steam DLL as the prior action/persistence work. Source installation, personal
saves and visible desktop remain untouched. Exact game/loader/client identities are private
and shared with the ACT-01 environment, not a new supported-install claim.

Four observed scenes:

- Idle protagonist in the private quiet arena.
- Existing synthetic caster and target, one ordinary `Attack` request. Actual action/HP evidence,
  not command acceptance, determines whether a window represents active combat.
- Real installed Monster Summoning I (`SPWI309`) executed with `ReallyForceSpellPointRES` for
  fixture setup. This tests the summon workload, **not** fair memorized casting. Summoned creature
  resource and resolved summoner relation must be observed before accepting that label.
- Thirty-two `CreateCreature` copies of the existing stripped fixture plus the protagonist.
  These are explicitly a synthetic crowd, not32 summons, SCS actors or a campaign encounter.

The effective summoning chain is point-target SPL -> opcode177 EFF -> opcode67 CRE. Pins:
SPWI309 `19a14735260901f91dfb3bd9c19ac195c54e8dcd67d9a4ad5328e3a9eeaef3b0`;
HOBARCSU.EFF `6665f62e9cc2e127288de7f0d64462b774b159aeb51473d55c7b6201b9818b44`;
HOBARCSU.CRE `9edff6638f74b2f66b73137346c1a36c8de0f0eae8cde531c37eb9fef3c0460a`.
The pinned serializer `EEex_Marshal.lua` (`4df027752c755b914eeeec92377469746c92d0d19a4302bb1d13a030ce9285de`)
uses `m_lSummonedBy` as the summoner relation; no persisted object ID is used in this experiment.
Generated fixtures and installed resources remain private, not redistributed.

## Review and limitations

Independent prelaunch review removed a duplicate owner-validation cost and required scalar
phase-boundary scene snapshots. Lead checked both Lua5.1/LuaJIT compilation and pinned native
call shapes. No new generic lab framework or broad test suite was added.

Still required for broader claims: repeated runs, other supported stacks/hardware, caster-heavy
and cutscene scenarios, area/save/load cost distributions, long retention/soak, scheduler and
active-decision cost. Any initial numbers below are a baseline for this deliberately small
observer, not evidence that the eventual Combat Intent or WorldFlow runtime is cheap.

## Results — 2026-10-04 local

Closed trace:4812 data rows,302877bytes, SHA256
`64ea1be193a6adbeb65412e8db11d5d4e796b2f58ec3db545a800cb7a636845a`.
Probe SHA256 `7714e143f77793ef444a2a5d879821e7064c962291fd5fe2c6395a3dd105b12c`.
Every phase has300 or301 consecutive frame rows and150 world ticks across approximately
ten seconds. Actual snapshots occurred about15 times/second, not once per rendered frame.
Private recipe, raw rows, exact deployed source, serial receipts, one-off analysis and cleanup
are under `.work/task10/performance-runtime-v1`.

| Scene | Observed workload | Snapshot median, two observer windows | Snapshot p95, two windows | Maximum sample |
| --- | --- | --- | --- | --- |
| Idle | One idle protagonist | 68 / 70.5µs | 120 / 128.3µs | 303µs |
| Ordinary melee | Three actors; attacker active throughout sampled observer rows, HP sum86→81 over phase boundaries | 107 / 108µs | 230.1 / 223µs | 474µs |
| Summons present | Five idle actors, including two HOBARCSU with observed caster relation | 138 / 142µs | 296.5 / 291.4µs | 5395µs |
| Crowded | 33 idle actors, stable HP sum1196 | 612 / 653.5µs | 1262 / 1144µs | 7980µs |

Summons were present but not fighting: this is **not summon-heavy combat**. Minimal windows do
not sample actions, so their unsampled values must not be interpreted as zero activity. Boundary
observations and the normal Attack's later action3/target-HP change support the melee label.
Crowded/summon maxima were isolated and are not attributed solely to this observer; native work,
GC and scheduling were not independently profiled. Keep them rather than dropping outliers.

Median callback intervals were33.316–33.352ms across all windows. Their p99 values spanned
35.362–39.035ms. A capped approximately30Hz callback can hide smaller cost increments; these
numbers do not establish zero slowdown or a production frame budget. The minimal inner timer
pair generally cost0–1µs and excludes the common telemetry workload.

One host completion assertion was sent slightly before crowded phase4 ended. It failed because
the batch was still running; a later receipt independently showed phase5/done/no probe failure.
No case was rerun. Preserve all300 phase4 rows but exclude that final minimal window from causal
ABBA comparison because the remote request may have disturbed it. The earlier two crowded
observer windows are intact. This is a measurement-procedure defect, not hidden engine failure.

Process working set grew from317931520 to322375680bytes; private memory from440991744 to
451915776bytes across the broader session, including loads/setup/remote commands. Neither delta
is assigned entirely to the observer. Outside timed windows, an explicit final Lua collection
changed33770.04KiB to30201.86KiB; sampled heap contains temporary row strings and the ring, so
this does not prove long-term retention/soak behavior. Ring length remained256.

Independent full-trace/source/receipt review confirmed identities, frame continuity, counts,
combat activity, summons relation and stated limitations. It corrected the private report so
minimal-phase activity is `null` (unobserved), not zero. Lead reproduced analysis and reviewed
outliers. No threshold or scheduler design was selected. The result is a useful first baseline:
the observed scalar scan scales visibly with actor count; future richer observers must be
compared against it instead of assuming that short Lua code is cheap.

The same owned session subsequently attempted a separate new-game lifecycle check; its later
menu assertion failed and is not counted as acceptance (see EEEX-06). It occurred after this
trace was closed. Own processes stopped, temporary files restored/removed and reservation
released. No original installation/personal-save mutation or new full game copy.
