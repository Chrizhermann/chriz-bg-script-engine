# SCS prebuff pilot: timing and accounting

**Outcome:** Conditional; source-only distinctions established, expenditure not engine-proved.

**Question:** Do all prebuff paths share the same trigger and spell-removal contract?

**Environment:** env:host; game-state access none.

**Versions and fingerprints:** SCS v35.21, exact revision and per-file identities in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Trace setup's short/medium/long/very-long includes into shared action definitions and
the allocation PRECAST branch; use [the pinned-source recipe](SCS-01-generation-pipeline.md).

**Observations:** The ordinary short-versus-long pair is the prebuff research representative.
Keep these source-level distinctions separate:

| Path | Source anchors | Observation / proposed disposition |
|---|---|---|
| Generic short | `caster-definitions` 470-486 | Requires allowed prebuffing, availability, untouched instant-prep state and sight or explicit offscreen flag. Force-spell, removal and continuation are explicit. `preserve`; outcome `needs-engine-proof`. |
| Generic long | `caster-definitions` 488-514 | Uses detection/proximity plus a separate hostility/detection/offscreen condition. Removal remains explicit. `preserve`; not the short rule with another duration. |
| Out-of-sight | `caster-definitions` 594-615 | Separate no-sight/proximity gate, anonymous resource and removal. `opaque` until generated resource/expansion trace. |
| Resource / innate / boolean | `caster-definitions` 641-687 | Removal statements are comments, while timers and continuation are active source. `opaque`; never assume generic accounting. |
| PRECAST / no-decrement | `caster-definitions` 690-702; `mage-shared` 833-845; `prep-very-long` 11-63 | PRECAST allocation does not take the default spell-add branch; special templates lack generic removal. `opaque` pending allocation/effective proof. |

Setup includes the duration groups before combat initialization and first-round buffing
(`mage-setup`, 53-56, 76-114). The generic prebuff definitions test `instantprep=0` but do not
themselves set it to one. First-round branches write it, with differing timers/continuation
(`first-round`, 223-268). Thus the pair alone is not a proved one-shot protocol; reset writers,
interruptions and ordered fallthrough still matter. Source duration comments are author intent,
not inspected effective SPL durations.

**Counterevidence:** Special paths without active removal refute universal prebuff expenditure.
`DoNotPrebuff` is not equivalent to no first-round defensive casting: the first-round file has
explicit branches for that setting (204-213, 260-268). Do not silently change this distinction.

**Artifacts:** `artifact:scs3521-caster-definitions`, `mage-shared`, `mage-setup`, `prep-short`,
`prep-medium`, `prep-long`, `prep-very-long`, `first-round`, `caster-shared` in the
[manifest](scs-source-pilot.evidence.json).
[Generic definitions](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L470-L514).

**Applicable evidence:** evidence:E1. No spell removal, buff application, fair casting or engine
postcondition was observed. The project does not adopt force-spell shortcuts for ordinary combat.

**Residual uncertainty:** Generated prebuff SPL payloads, complete setting/reset closure, special
allocation, actual durations, aura, interruption and save/load behavior remain unresolved.

**Next decision:** Integration lead cross-checks each accounting variant separately against
effective artifacts, then designs independently reviewed engine probes after the appropriate gates.
No derived fixture or runtime policy is admitted by this memo.
