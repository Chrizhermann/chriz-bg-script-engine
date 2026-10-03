# Task10 persistence boundary — working research contract

**Question:** Can durable test facts survive save/load and upgrades while unsafe session state
is discarded and corrupt data affects only its own record?

**Status:** Host contract accepted at E2; bounded engine marshal/lifecycle batch observed at E4.
Quickload/new-game coverage and baseline-cost work remain pending.
Task10/G1 are not complete. Modules are under `experiments/persistence`, not registered production
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

Remaining: new-game/quickload observation, measured observer-only cost, and later production
disable/reconciliation behavior. Corruption here means semantic payload corruption, not arbitrary
malformed native save bytes. No native crash was induced or retried. This narrow result is not
WorldFlow activation, a general save-compatibility promise or G1 approval.
