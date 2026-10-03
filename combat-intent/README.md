# Combat Intent policy boundary

Task20 is a host-tested information model, not a native perception adapter or active AI.
The first target remains the approved current-stack lab. No spell, balance, memory-lifetime
or difficulty preset is selected by these modules.

## Information contract v1

`perception.build(frame)` (also `snapshot.new(frame)`) takes a scalar frame containing its
integer tick, semantic observer key, scene key, eligible ally keys and actor evidence. The
trusted boundary must change scene key for area/session/stack-epoch transitions; it is not
a native object ID. No userdata,
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
values. A changed scene key clears old memory automatically. `invalidate()` additionally clears
the entire ephemeral store on an owning lifecycle transition.
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

## Combat shadow candidates (Task21, partial)

`candidates.generate(view, config)` returns ordered eligible proposals and reason-coded
exclusions. Config supplies exact selected ability metadata, target keys, observed ownership,
its observer/scene/tick context, and point-coverage assessments where applicable. Metadata
includes resource, actor/point target form, normalized range, geometry identity, explicit
casting-failure limit and known blocking-protection tags. There are no built-in spell-name
guesses or tuning defaults. The range fact and selected ability range must use the same
boundary-normalized units; no native distance conversion is implemented here.

Ready spell copies, current caster state, target life/relation/sight/range and ownership gate
the proposals. Unknown immunity stays an explicit uncertainty rather than pretending the
target is vulnerable; current witnessed single-target blocking protections can exclude it.
An immune point anchor does not imply that every area recipient is immune.
Point checks must attest complete/safe coverage, the anchor, exact point, resource, geometry,
observer/scene/tick and matching normalized actor scene. This validates attachment of trusted
assessment data, not geometry calculation or an attestation that the caller measured correctly.
The future native mapper must include sufficient nearby contacts or declare coverage unknown.

All actions are `shadow-spell`, `shadow-wait` or `legacy-decline`, deliberately incompatible
with the lease dispatch types. Wait is only a hypothetical option, never an engine queue action.
No actions, scores, costs or spellbook mutations are performed. Scoring/dispatch must still
freshly revalidate ownership and all action-specific conditions at their later gates.

Run `scripts/test.ps1 -Suite unit -Filter combat_candidates` for the grouped combat tests.
The deliberately authored Slow/Glitterdust/Magic Missile fixtures prove reducers (E2), not the
installed spells' geometry or support. Review reproduced stale ownership/point-assessment gaps;
the current interface binds them to their frame/scene and explicitly rejects offensive self
targets. Scene changes clear old belief memory. See
[the actual input inspection](../docs/research/COMBAT-01-candidate-inputs.md) for E1 identities
and its corrected projectile lookup. Prebuff windows/accounting and native mapping are still
unfinished; Task21 remains in progress rather than silently reducing its intended scope.
