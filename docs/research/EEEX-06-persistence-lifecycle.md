# Task10 persistence boundary — working research contract

**Question:** Can durable test facts survive save/load and upgrades while unsafe session state
is discarded and corrupt data affects only its own record?

**Status:** Host contract accepted at E2; bounded engine marshal/lifecycle batch observed at E4.
New-game follow-up is accepted below; true quickload remains unproved. The first measured cost batch is in
[PERF-01](PERF-01-observer-baseline.md).
Task10's bounded research scope is complete after the approved QuickLoad deferral below;
G1 is not approved. Modules are under `experiments/persistence`, not registered production
kernel code. The plan's eventual `kernel/` placement is deferred until the research gate, as for
the capabilities/action-observer experiments. No real quest phases or gameplay policy selected.

## Pure state boundary

`state_schema.copy(value, shape, limits)` accepts only explicitly declared unsigned32 integers,
NUL-free strings, records and bounded arrays. Record fields are allowlisted, not a blacklist of suspicious
names. Stable actor/resource identities must be declared strings; undeclared numeric object IDs
and numeric identity values are rejected. A validator cannot recognize a session ID deliberately
disguised as another allowed number: schema authors retain responsibility for semantic fields.

Plain acyclic tables only; no metatables, userdata, functions, threads or Lua booleans. Flags
use numeric0/1. Depth, nodes, total charged bytes and per-string size are explicitly bounded.
These are logical payload budgets, not a prediction of serialized EEex byte size. Every result
is an independent copy; caller values never reach trusted migration code by reference.

`export(payload, contract)` returns a sanitized `{schemaId,schemaVersion,payload}` envelope
or a reason code. `load(envelope, contract)` returns `ready` with the copied current envelope,
`absent` for no saved data, or `quarantined` with a bounded code and no raw invalid payload.
Unknown/future versions yield; supported old versions pass through sequential pure migrations,
with validation/copying before and after each step. Missing/throwing/invalid migration affects
only that record. `absent` is **not** permission to adopt a real legacy quest without inspection.
Schemas, limits and migration functions are trusted programming configuration and may assert
when invalid; persisted data is untrusted. No engine call, storage write or automatic retry.
Contract metadata also crosses the wire boundary: schema IDs must be nonempty, NUL-free and
within the configured string limit; schema versions must be positive unsigned32 integers.

## Bounded diagnostics

`diagnostics.new(config)` exposes `record(event)`, `error(adapterId,code)` and `snapshot()`.
It retains a fixed-size chronological ring of copied whitelisted scalars and a bounded map of
per-adapter error counts. Error limits suppress further rows; new-adapter overflow declines
without silent eviction. This is not an implemented production circuit breaker.

Only machine-identifier text (alphanumeric, underscore, dot, colon, hyphen) within the configured
length is retained. Other/freeform/path/oversized values become `[redacted]`; arbitrary input
fields are omitted. Raw exception text is not a supported input. This is a structural publication
boundary, **not** a claim to detect every private name or secret embedded in a valid identifier.
Capacity ceilings bound programming configuration, not feature scope. Snapshots cannot mutate
the live ring/counters, and diagnostics never touch quest state.

## Host method, results and review — E2

Windows host, Python3.11/Lupa2.8, Lua5.1 and LuaJIT2.1.1774896198. Each module began with an
actual missing-module RED run on both backends. Eight state scenarios cover independent export,
two forward migrations, future/corrupt quarantine, unsafe types/IDs, cycles/metatables, budgets,
failed migration isolation and envelope shape. Seven diagnostics scenarios cover ring order,
copy isolation, redaction, malformed inputs and error/adapter caps. No setup-framework tests.

The lead implemented state validation; an independent Sol reviewer checked code and executed
the focused tests. A Sol worker implemented diagnostics against the frozen lead API; lead review
found that the identifier pattern accidentally admitted literal `%`. A focused RED reproduced
it on both backends before the minimal correction. The copy-isolation assertion was also moved
before ring eviction so it actually exercises the intended case. No assertion was weakened.

Combined existing observer/schema plus new focused checks: **16 passed**, no skips:

`python -X utf8 -m pytest -p no:faulthandler -q tests/unit/test_state_schema.py tests/unit/test_diagnostics.py tests/unit/test_action_observer.py tests/unit/test_listener_trampoline.py tests/schemas/test_capability_profile.py tests/schemas/test_research_evidence_schema.py`

The per-run diagnostic-hook switch is the documented Windows/LuaJIT handled-exception workaround,
not an assertion bypass. The independent reviewer omitted it and saw that known diagnostic while
still obtaining exit0/two passed; that separate output is not represented as anomaly-free.
Exact RED/GREEN/correction/combined output is private `.work/task10/`.

A final lead review found that the payload checks did not cover the exported envelope's trusted
schema ID/version. The existing envelope scenario was extended, not replaced: both backends
first failed for NUL IDs, oversized IDs and versions above unsigned32 through export and load.
The minimal contract checks then passed the same combined16 checks (exit0, no skips).
Receipts: `state-envelope-red.log` and `state-envelope-green.log`. Updated state module SHA256
`6bfb1df69a4dd7ce50d408333f70a573af1d0c46e640a50aa7ff03aa9f77d1e1` is **E2-only**;
the E4 batches below used the earlier, separately fingerprinted module with valid metadata.
Their observed results stand, but they are not an engine retest of this final check.
Independent review accepted the six-path regression and short-circuit guards; it inspected the
saved RED/GREEN receipts rather than claiming a separate rerun.

## Engine evidence and remaining work

Prelaunch E1 review tightened the initially generic finite-number/string validator. The pinned
EEex serializer selects integer-width writers/readers and NUL-terminated strings. Fractions
have no explicit integer validation there; an embedded NUL changes the reader's logical string
length. Signed-width selection also warrants separate proof, not assumptions about native
conversion. This research direct-wire profile therefore admits only0..4294967295 integers and
NUL-free keys/values. Other logical values need an explicit proved encoding later; this does
not remove any planned gameplay feature. The source supports Lua booleans in this version,
but the agreed cross-version numeric0/1 flag contract is retained.

Focused RED runs independently reached the fractional-number and embedded-NUL acceptance
defects; minimal boundary checks made both backends GREEN. The existing eight scenarios remain
eight, with targeted assertions rather than a broad new suite. Logs: `state-wire-red.log`,
`state-nul-red.log`, `state-wire-green.log`. Native unsigned round trips are recorded below.

Prior Task8 proved a Lua root survives own save/load, a destroyed listener advances the session
epoch and fresh observation resolves actors again. Task9 proved independent saved markers and
spell debit with no observed unfinished-action continuation in two bounded cases. Those are
relevant boundaries, **not** EEex marshal-handler proof for this new contract.

Current pinned `EEex_Sprite.lua` SHA256
`ecd341bae5295d3db5a52279f84c55a4ff173150665a94b450ef3dfcf6cb3b4e` statically shows keyed
marshal registration, exporter table/nil handling, protected exporter/importer calls and a
fallback store for missing handlers. This source alone does not guarantee runtime safety,
absence-of-handler retention or save compatibility. Source belongs to EEex/Bubb
and stays private. Same BG2:EE2.7.3.0/EEex1.2.0 comparison stack as ACT-01.

## Integrated persistence batch — E4, 2026-10-04 local

One hidden session used the existing quiet disposable arena, authored
`experiments/persistence/session-probe.lua`, four synthetic records on our fixture caster and
only our marshal key `B-`. The importer performs validation and own-UDAux writes, not native
sprite/name/area reads during unmarshalling. World inspection re-resolves the fixture; only
scalars/tables cross the persistence boundary. No real quest or production lease was enrolled.

Same BG2:EE2.7.3.0, EEex1.2.0/LuaJIT, EET14, SCS35.21, SR4.21-chriz.5 and Bubb Spell Menu5.2
comparison stack as ACT-01. Probe SHA256
`0773cca777211df3e5c849aea8544e4a46aecd45320f8f90183325792f3add7d`;
state module `ad868e68c6b75ee4695399bc18d3a1fba4226c5876aba45fa782022d7364c851`;
diagnostics `21aaf716850119f71bbed4b3542520200112f1de384f17dc69d2332842d5ccf9`.

| Case | Independent observed result |
| --- | --- |
| Save/load current facts | Saved marker10031 replaced unsaved20031 on reload; current v3 ready. Unsigned255/256/65535/65536/4294967295 returned exactly. |
| Named-load ephemeral clear | Immediately before load, both before/changed receipts show armed=true, epoch0. Destroyed event9 clears it before imports10–15; later receipt shows false, epoch1/imports1. This is a scalar synthetic attempt, not production lease/handle cleanup. |
| Old version | v1 imported through two migrations to v3. Later upgraded save reloaded as v3 with zero repeated migrations. |
| Future/corrupt sibling | Future99 quarantined `future-schema`; wire-valid but semantically invalid epoch999 quarantined `number-range`. Good/old records still loaded. |
| Area away/back | Ephemeral attempt cleared; durable facts were exported/imported on leaving/returning to the arena. |
| Stack mismatch | Changing only the probe's synthetic expected tag quarantined good/old with `stack-epoch`; restoring tag and reloading restored acceptance. Not an installed-stack mutation. |
| Missing handler | Removing only our registered handler and loading showed native fallback storage, no own import. A new save made in this state later restored all four records after handler return. |
| Main menu | Destroyed listener advanced epoch7 to8 and cleared ephemeral state; loading the original own save restored durable facts. |
| Death | After queued normal Kill, later fresh observation showed HP0/state2048 and cleared the synthetic ephemeral attempt. Queued Kill alone was not counted as proof. |

Before restoring the handler, load the no-state own baseline. Registered exporters and fallback
storage are both visited by the pinned serializer; installing an exporter on an already loaded
fallback carrier is **not** proved safe by this experiment. Only the exact own registry entry was
removed. This is handler-absence retention with EEex still present, not an installer-uninstall,
EEex-absence or production legacy-fallback guarantee.

Three unique own save folders were created (initial, absent-handler, upgraded). Each had four
files, verified by size and SHA256 before loading. Initial/absent/upgraded SAV hashes respectively:
`41e4763ba0490bdaaef2a4d11834bd7acdef6b73c869132e9bebf45799d54427`,
`6cc7fcf5a0c360ead26da9a76d9e3ed3f74ce90fd031bafa05a19c8cf68f1867`,
`e8eeb1a0ca1e5dd4f34ac3846bef463c1329e1042e24f211fbb1376fe60701b4`.
These file identities plus native import and changed-unsaved-marker postconditions prove these
round trips; no claim is made to have independently decoded the native marshal byte stream.

Private `.work/task10/persistence-runtime-v1` contains the exact recipe, deployment copy,
serial command/result receipts, save-file ledgers and closed91-event trace (4800bytes), SHA256
`89ba55745d71df3fbeaa1ba3260b7ccdd3eb7186d7d549681dabcd0111b6e810`.
Final counters: seven imports, seven own-loaded callbacks, three own exports, epoch8, one
registration per destroyed/loaded listener, no probe failure or diagnostic error. Future/corrupt
quarantines are expected outcomes, not discarded failures. The game was deliberately closed via
its own held job; graceful game exit0 is not claimed. Nine additions and owned IPC removed,
three original lab files restored byte-exactly, own reservation released. Small own saves are
listed in private CLEANUP; active game and personal saves untouched.

Independent Sol full-trace/source/receipt review accepted these bounded conclusions; lead
verified marker reversal, migration counts, final state and cleanup. It specifically retained
the missing raw-byte decode and broader lifecycle/production limitations above.
Final evidence-to-plan review also checked `initial-load-submit.json`, `initial-load-result.json`
and trace5–16: the attempt was still armed before named load, not prematurely cleared by the
first area poll. This observation had been omitted from the first memo; it required no rerun.

### First new-game follow-up: partial, not acceptance

After the separate performance trace closed, the same hidden process seeded fresh synthetic
state and followed the existing Task3 pre-generated test-character route. An immediate return
from character acceptance reported WORLD_ACTIONBAR, but a later world-menu assertion failed.
The lead incorrectly treated that immediate response as settled state and skipped the old
conditional chapter-screen step. The receipt does not identify the intervening menu, so chapter
timing is a source-backed diagnosis to verify, not a newly observed screen or native-crash claim.

The trace also exposes a fixture mistake: arming immediately after probe installation let the
first area observation clear the ephemeral marker before the main-menu destruction event.
The next focused check must wait for that initial area observation before arming. Neither this
case nor an immediate command response is promoted to new-game lifecycle acceptance.

Evidence remains private in `.work/task10/persistence-runtime-v2`; the game was closed without
retrying the failed command. Its two existing **own** automatic-save/prologue folders were
preserved before/after and all eight original files restored;28 files in copied personal
auto/quickslots were unchanged. Independent receipt/trace review accepted the diagnosis and
bounded correction: once after character acceptance, inspect the settled menu; perform the
already proved chapter action only if actually present; verify a later world observation.

### Corrected new-game / old-save batch — E4

One focused follow-up reused the unchanged probe and existing Task3 character-creation commands;
no new menu framework was built. First area observation now preceded arming. The later command
receipt confirmed the ephemeral attempt was armed, then the main-menu destroyed event cleared
it and advanced epoch1. This fixes the fixture ordering flaw without weakening the assertion.

After character acceptance, a two-second settle and one state read observed CHAPTER with its
Done button clickable and no transition in progress. The existing chapter action then produced
a later settled WORLD_ACTIONBAR observation. This directly confirms the timing explanation;
the earlier failed attempt remains failure evidence, not retroactively a pass.

In the new world the own portrait character was in BG2600, had neither `B-` UDAux nor fallback
state, and the handler remained registered with zero imports. Loading own initial-record save978
then produced exactly one import: good10031 ready, old v1→v3/migrated2, future/corrupt quarantined.
Loading own pre-state baseline973 returned to BG2600 without inventing own state or fallback;
imports stayed1 and epoch became3. Listener registration counts stayed one each; no probe error.
This proves the observed main-menu/new-game path and handler retention, **not** a distinct
new-game hook independent of the already-cleared main-menu boundary.

Private `.work/task10/persistence-runtime-v3` preserves the reviewed corrected recipe, exact
deployed source, settled menu/result receipts and closed20-event/1107-byte trace, SHA256
`24c9945fd9e49c26b04238a4faa69cd0dc5093f44515d7e04869344e31b27cdf`.
Independent full-trace/receipt/source review accepted the bounded findings and verified eight
restoration hashes against the private backups. Own processes stopped; all12 staged targets
reconciled and IPC removed; own reservation released. The two own automatic-save/prologue
folders were restored (eight files), and28 copied personal slot files remained unchanged.
No new named save, full copy or active-game mutation.

### Cold load with all BGSE experiment modules absent — E4

The combined Task10/11 follow-up reused the same isolated engine/profile and loaded own978
without staging the BGSE bootstrap or observer and without loading any bridge/persistence
module. Before and after load, `_G["B-"]` and our marshal registry entry were absent. The
own actor also had no imported `B-` UDAux. EEex remained installed and active.

The exact native fallback packet was present at
`EEex_GetUDAux(caster).EEex_Sprite_FallbackMarshalStorage["B-"]`. Its direct shape follows
effective `EEex_Sprite.lua` lines1431–1438, SHA-256
`ECD341BAE5295D3DB5A52279F84C55A4FF173150665A94B450EF3DFCF6CB3B4E`.
Assertions verified good10031/schema3 with all five uint32 boundary samples, old10032/schema1,
future10033/schema99 and corrupt10034/schema3/epoch999. Without our importer, the old record
was not migrated and future/corrupt records were not classified as ready or quarantined.

This adds **module-absence named-load retention**, beyond the earlier handler-only test.
It does not prove saving/re-enabling in this fully absent session, EEex uninstall/absence,
production disable handback, or arbitrary malformed-save recovery. The earlier absent-handler
resave/re-enable experiment remains separate evidence, not a substitute for those limits.

Private `.work/task11/absence-and-area-v1` contains the exact16-target stage/cleanup ledger,
`absence-audit.lua`, fresh pong and load/QA/result receipts. The existing own978 SAV identity
above was rechecked before launching. No new save was made. A later, independent dialogue
area experiment in the same session failed its continuation expectation (BCS-01); it does
not invalidate the completed fallback audit. Independent source/result review confirmed
these bounded claims. All16 staged targets and owned IPC were reconciled after own processes
stopped, original lab bytes restored, and the matching reservation released.

### Remaining boundary

True quickload remains unproved: the verified helper uses an explicitly selected named save.
The installed UI exposes quicksave and named LoadGame but no source-backed callable QuickLoad
was found in a bounded Lua/bindings search. Do not claim the two paths equivalent or send OS
input to fill the gap. On2026-10-04 Christopher explicitly approved deferring this one check,
not forgetting it. [COMP-P13](../compatibility/acceptance-matrix.md#108-save-upgrade-downgrade-disable-and-uninstall)
and the [owned follow-up](research-backlog.md#approved-deferral-comp-p13--true-quickload) carry it
into Task40 before G8. Task10 can close at its bounded research scope; QuickLoad is not passed.

The bounded follow-up also inspected the published InfinityLoader bindings at commit
`f14a00527286f819b8034411bc92ca719cfe3c86` and installed LuaBindings (SHA-256
`0C6A86DBB402AA5863286C4398CC9E691FA8A2CD7F83D517B29EDCAEAC51F1E9`). The apparent stats
QuickLoad method reloads sprite statistics, not a game save; no allowed true QuickLoad
entry point was established. Do not invent a native call or represent named loading as proof.

Task10 now includes cold module-absence retention as well as handler-absence resave/re-enable.
Those are explicitly bounded research disable cases, not a full production uninstall or
legacy handback. The approved deferral changes the timing of the true-QuickLoad requirement,
not its evidence standard or the supported profile. Production handback/reconciliation and
real lease/handle cleanup belong to their later implementation tasks; no such runtime exists
in this research probe.
Corruption here means semantic payload corruption, not arbitrary
malformed native save bytes. No native crash was induced or retried. This narrow result is not
WorldFlow activation, a general save-compatibility promise or G1 approval.
