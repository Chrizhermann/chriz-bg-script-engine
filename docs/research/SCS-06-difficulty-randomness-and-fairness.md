# SCS mage pilot: difficulty, randomness and fairness

**Outcome:** Conditional; source-only input/exception map, not a fairness guarantee.

**Question:** Can difficulty names or comments be translated directly into new policy thresholds?

**Environment:** env:host; game-state access none.

**Versions and fingerprints:** SCS v35.21 pin/digests in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Inspect prep call sites and selected difficulty-library bodies with
[the source recipe](SCS-01-generation-pipeline.md), retaining distinctions rather than rewriting them.

**Observations:** Short, medium, long and very-long preparation call distinct difficulty triggers.
The library combines configurable globals, engine difficulty and in some branches
`created_out_of_sight` (`difficulty`, 140-287). Preserve all inputs in the comparison packet.

Important source discrepancy: `CorePlusPrep` (176-190) references `difficulty_variable`, whereas
many neighboring prep triggers reference `prep_difficulty_variable`. `EasyMinusPrep` (148-155)
mixes the two. This is a verified source distinction, **not a diagnosed upstream bug**: library
selection, expansion, settings and actual output still need tracing. Do not silently normalize it.

`mage-setup` 14-38 has explicit response weights 200 and 100, with spell removal only on one branch.
These numbers do not establish observed frequency, deterministic replay or an action's completion.
`mage-shared` 823-830 also selects a random chain-contingency entry during generation. Install-time
allocation variability and runtime response choice require separate records.

**Counterevidence:** A trigger's name does not fully specify its predicate; source-level weights
and comments are not measured runtime distributions. Duration-group labels do not prove effective
SPL duration or resource expenditure.

**Artifacts:** `artifact:scs3521-difficulty`, `mage-setup`, `mage-shared`, `prep-short`, `prep-medium`,
`prep-long`, `prep-very-long` in [the manifest](scs-source-pilot.evidence.json).
[Difficulty distinction](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/difficulty.slb#L148-L190).

**Applicable evidence:** evidence:E1 only; no shadow oracle or replay comparison ran.

**Residual uncertainty:** Preserve/change decisions for discrepancies, exact randomization and
fairness require effective evidence first, then host oracle and disposable-engine checks as planned.
This filename is a Task 6 deliverable; it does not close backlog SCS-06 (shadow comparison).

**Next decision:** Lead investigates expansion before asking Christopher to choose intentional
behavior changes. For now all unresolved cases remain opaque and legacy-owned.
