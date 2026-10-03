# Combat Intent policy boundary

Task20 is a host-tested information model, not a native perception adapter or active AI.
The first target remains the approved current-stack lab. No spell, balance, memory-lifetime
or difficulty preset is selected by these modules.

## Information contract v1

`perception.build(frame)` (also `snapshot.new(frame)`) takes a scalar frame containing its
integer tick, semantic observer key, eligible ally keys and actor evidence. No userdata,
functions, metatables, cycles or numerical object keys are accepted. Each input fact names
its source, value, observation/expiry ticks and confidence; witnessed/inferred information
also requires a public basis. Optional ally provenance stays attached to shared facts.

Admission produces `observed`, `remembered`, `inferred`, `shared`, `unknown` or `expired`.
Unknown/expired records contain a reason but no value. Ordinary sight requires both visibility
and detection. Seeing an actor alone reveals neither its last spell, protections nor exact
resistances. Self-only readiness and available spell copies require the observer's own `self`
source; another actor's spellbook is never admitted. Engine-private evidence is rejected.
Allied reports require an explicitly eligible source and public evidence provenance.

The boundary validates the supplied provenance; it cannot establish whether a caller lied
about witnessing a cast. That belongs to the later native mapper and G4 fairness audit.
There is no omniscience mode. `spellbook` currently means a list of available spell copies,
not all known spells; repeated resource names can represent multiple available copies.

`view:get(subject, field)` and `view:export()` return copies. Policy scorers receive only
`view:reader(declaredFields)`, which rejects an undeclared read. Giving a scorer the full view
would defeat that restricted interface; the broader mapping/debugging API is not itself a
per-scorer restriction. These are trusted-module copy boundaries, not a hostile-Lua sandbox.
The JSON schema describes exported normalized data, not unfiltered input or runtime fairness.

## Ephemeral beliefs

`beliefs.new({observerKey=..., maxEntries=...})` creates observer-bound, bounded memory.
`observe(view)` admits only known unexpired evidence, never another observer's snapshot.
Older observations cannot overwrite newer ones; equally timed admitted updates replace the
previous entry deterministically in call order. Loss of sight does not erase plausible memory.
`read(subject, field, tick)` preserves provenance/confidence and adds age, but strips expired
values. `invalidate()` clears the entire ephemeral store on an owning lifecycle transition.
Capacity failure is explicit and does not partially replace existing memory. The native caller
must wire invalidation; no engine events or saved records are registered here.

## Reproduce

Run `powershell -NoProfile -File scripts/test.ps1 -Suite unit -Filter perception` and the
combat snapshot schema checks. The runner identifies Python, Lupa and both Lua backends.
The tests group visibility, witnessed casts, sharing, forbidden fields, copies, scorer reads,
staleness and observer-bound memory rather than enumerating game encounters.

Evidence: E2 only. Missing-module RED preceded implementation. Independent review found
that plain sight incorrectly admitted a previous exact spell; a failing regression reproduced
it before requiring a witnessed/inferred basis. Lead review similarly rejected allied guesses
for self-only readiness/allocation. Both corrections pass on Lua5.1 and LuaJIT. Native visibility,
resource mapping, information extraction and actual decision behavior remain unproved.
