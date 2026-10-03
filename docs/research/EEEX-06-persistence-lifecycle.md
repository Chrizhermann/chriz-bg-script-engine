# Task10 persistence boundary — working research contract

**Question:** Can durable test facts survive save/load and upgrades while unsafe session state
is discarded and corrupt data affects only its own record?

**Status:** Host contract accepted at E2; engine marshal/lifecycle and baseline-cost work pending.
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
`state-nul-red.log`, `state-wire-green.log`. Native unsigned value round trips remain E4 work.

Prior Task8 proved a Lua root survives own save/load, a destroyed listener advances the session
epoch and fresh observation resolves actors again. Task9 proved independent saved markers and
spell debit with no observed unfinished-action continuation in two bounded cases. Those are
relevant boundaries, **not** EEex marshal-handler proof for this new contract.

Current pinned `EEex_Sprite.lua` SHA256
`ecd341bae5295d3db5a52279f84c55a4ff173150665a94b450ef3dfcf6cb3b4e` statically shows keyed
marshal registration, exporter table/nil handling, protected exporter/importer calls and a
fallback store for missing handlers. This is E1 source evidence only; it does not guarantee
runtime safety, absence-of-handler retention or save compatibility. Source belongs to EEex/Bubb
and stays private. Same BG2:EE2.7.3.0/EEex1.2.0 comparison stack as ACT-01.

Next: one representative hidden persistence batch using synthetic facts, real saved-byte/load
postconditions, forward migration, corrupt/future state, scoped disable/absence and ephemeral
invalidation. Measure observer-only cost separately against an uninstrumented window. Preserve
unknown lifecycle/quickload/new-game/performance cases until actually observed. No production
WorldFlow activation, quest migration or G1 approval follows from the host result.
