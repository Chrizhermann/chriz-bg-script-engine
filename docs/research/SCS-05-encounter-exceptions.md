# SCS mage pilot: encounter exceptions

**Outcome:** Conditional; source-only exception register, no encounter ownership proof.

**Question:** Can a shared mage file safely be treated as wholly generic behavior?

**Environment:** env:host; game-state access none.

**Versions and fingerprints:** SCS v35.21 pin/digests in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Follow a named include and first-round exception gates using
[the source method](SCS-01-generation-pipeline.md); no installed creature/area inspected.

**Observations:** `standard-mage` includes `kruin_special` at line 20. That file's named gates,
resource accounting and SR-specific branch (`kruin`, 5-71) must remain separate from ordinary mage
rules. First-round preparation also contains named Davaeorn and Malavon branches, including fixed
locations and area-state interaction (`first-round`, 25-77). Record these as encounter-owned and
`opaque` for the ordinary pilot, not as optional generic optimizations.

Selecting a source enchanter branch does not prove an actor lacks these or other controls. Effective
CRE slots, area actor overrides, scripts, globals, dialogue/cutscene controllers, shout/help traffic,
summon relationships and subsequent patches are still part of the eligibility investigation.

**Counterevidence:** Exceptions inside shared includes disprove classification by folder or apparent
template similarity. No complete exception census or external-control scan was performed.

**Artifacts:** `artifact:scs3521-standard-mage`, `kruin`, `first-round`, `mage-entry` in the
[manifest](scs-source-pilot.evidence.json).
[Named first-round branches](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/prep/first_round_buff.ssl#L25-L77).

**Applicable evidence:** evidence:E1; evidence:E4 handoff/containment testing is still future work.

**Residual uncertainty:** Exact enrollment, public-state dependencies and durable encounter
semantics are unknown. No support claim for a named encounter follows from this observation.

**Next decision:** Integration owner reviews a complete ordinary-actor control closure before
activation. Named cases stay with legacy control until separately mapped and approved.
