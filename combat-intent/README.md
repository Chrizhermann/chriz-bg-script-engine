# Combat Intent policy boundary

Task20 defines the host-tested information contract. The authored current-stack pilot now also
has a bounded native input mapper, G4 shadow decisions and Task25's default-off ordinary
actor-target Magic Missile path. None is general SCS activation or a player-facing balance,
memory-lifetime or difficulty preset.

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

The boundary validates supplied provenance; it cannot establish whether a caller lied about
witnessing a cast. The bounded native mapper and G4 audit cover only the authored hostile fixtures,
not general truthfulness of public observations.
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

The Task20 contract's host evidence is E2. Missing-module RED preceded implementation.
Independent review found that plain sight incorrectly admitted a previous exact spell; a failing
regression reproduced it before requiring a witnessed/inferred basis. Lead review similarly
rejected allied guesses for self-only readiness/allocation. Both corrections pass on Lua5.1
and LuaJIT. The authored current-stack pilot has separate E1+E2+bounded E4 evidence under
G4 and Task25. General native visibility, resource mapping and decision behavior remain unproved.

## Combat shadow candidates (Task21, completed narrowed pilot)

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
The authored pilot supplies no point-coverage assessment, so unknown geometry excludes point
candidates. Broader nearby-contact mapping remains future work.

The candidate reducer emits `shadow-spell`, `shadow-preparation`, `shadow-position`, `shadow-wait` or
`legacy-decline`; it performs no native action, scoring or spellbook mutation. Wait is only a
hypothetical option, never an engine queue action. Downstream utility, choice and replay exist;
Task25's separate default-off dispatcher admits only ordinary actor-target Magic Missile after
fresh ownership and action revalidation, not preparation helpers or point spells.

Run `scripts/test.ps1 -Suite unit -Filter combat_candidates` for the grouped combat tests.
The deliberately authored Slow/Glitterdust/Magic Missile fixtures prove reducers (E2), not the
installed spells' geometry or support. Review reproduced stale ownership/point-assessment gaps;
the current interface binds them to their frame/scene and explicitly rejects offensive self
targets. Scene changes clear old belief memory. See
[the actual input inspection](../docs/research/COMBAT-01-candidate-inputs.md) for E1 identities
and its corrected projectile lookup. Selected generic Shield/Mirror Image prep gates and the
authored-fixture native mapper are complete within narrowed Task21/G4 scope. Helper execution
and debit, neutral/special prep and Slow/Glitterdust point geometry remain unadmitted.

## Short plans and coordination (Task27)

`intention.new({identity, sceneKey, maxSteps, maxLifetimeTicks})` accepts a copied plan with a
purpose, one to three semantic step labels, scalar assumptions and an absolute expiry. `next`
offers only the current label after checking fresh identity, scene, assumptions and legality;
it is not an engine request. The caller regenerates a current legal decision and obtains the
ordinary dispatcher lease separately. `observe` uses the existing action-result reducer:
accepted/started do not advance the plan, proved completion advances once, and failure,
interruption or unknown aborts without automatic retry. `cancel` abandons a plan; `invalidate`
retires the instance on load or other lifecycle boundaries. Reads never extend the deadline.

`reservation.new({sceneKey, groupKey, maxEntries, maxLifetimeTicks})` provides an advisory,
explicit-group board, not global telepathy or action ownership. Each current scalar context
names the permitted members, known targets and admitted space keys. `reserve` claims one
target, one target/effect pair or one space until expiry; same-owner reads cannot renew it.
`view` gives a copied snapshot for the consuming policy's trace. Missing members/subjects reap
claims; changed group/scene or combat end retires the board. Completion, interruption and
adapter disable must release claims or invalidate the board at the caller's lifecycle boundary.
Kinds do not silently impose cross-kind tactical rules; no spell slots or future actions are
reserved. Lifetimes, group membership and tactical priorities have no built-in gameplay defaults.

Both modules return `dispatchAuthorized=false`; tokens are transient module-session handles,
never save data. Discard their objects and outstanding tokens together on module/session reload.
If coordination affects a choice, retain the copied advisory view alongside its decision inputs;
do not introduce an unrecorded score modifier. The current native pilot has not wired this layer.

Reproduce with `scripts/test.ps1 -Suite all -Seed 47`, or the two intention/reservation unit
drivers and `tests/integration/test_combat_coordination.py`. The combined two-mage example
reserves a control effect and position, completes a synthetic reposition, attempts Slow,
handles interruption, hands the job to the second mage, then loses the target and resets.
Seeded interleavings check bounded exclusivity. These are E2 policy results, **not live movement,
Slow casting or pathfinding proof**. Native movement/AoE admission remains separate.

## Position proposals and area risk (Task28)

`spatial.sample(view, config)` produces up to eight explicit offsets. `evaluate` rejects
unproved routes, occupied points, inadequate clearance, blocked LOS and stale query context.
Queries bind the exact actor frame as well as scene/observer/tick/from/point; same-tick actor
changes invalidate them. `pathProofId=false` is the current native setting: the verified
nearest-open query does not prove reachability. An identity string binds a trusted caller's
reviewed attestation; the reducer does not establish that the underlying proof is correct.
Metric scales, footprint/clearance units, sampling radius and score weights are caller-owned.
`travelDistance` is straight-line metric displacement, not route length; `retreatGain` compares
distance to the nearest currently observed enemy, not omniscient threat or damage prediction.

Optional candidate config `spatial={config=..., reports=...}` feeds accepted positions through
the same ownership, utility, choice and replay path. Each `shadow-position` carries generated
`retreatGain`/`travelDistance` features; score terms must match those values and profile weights
are explicit. The active dispatcher rejects this action type. No engine movement is queued.

`geometry.assess` supplies the existing point-spell legality shape with current full-frame
coverage, a caller-attested circle/radius/metric and conservative non-enemy overlap risk. It
does not infer shape or ally-safe filtering from spell names. Unknown coverage cannot attest
safety. The installed pilot's point-spell metadata remains unadmitted, so these are not new
live spell claims. The Task28 query batch verified personal space, five open-square results
and LOS-range call shapes in one room; it did not verify routes or projectile recipients.

Reproduce the focused spatial/geometry drivers and `tests/integration/test_spatial_decision.py`,
or the full existing host suite. See [SPACE-01](../docs/research/SPACE-01-coordinate-and-los.md)
and [SPACE-02](../docs/research/SPACE-02-projectile-geometry.md) for exact E1/E2/E4 boundaries.
