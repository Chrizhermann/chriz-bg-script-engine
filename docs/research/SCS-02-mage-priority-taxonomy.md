# SCS mage pilot: priority taxonomy

**Outcome:** Conditional; source-only map, not a complete priority oracle.

**Question:** Is the standard combat include list the entire mage decision order?

**Environment:** env:host; game-state access none.

**Versions and fingerprints:** SCS v35.21 pin and hashes in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Apply the [source retrieval method](SCS-01-generation-pipeline.md); compare the main
template, setup and standard combat include list. No SSL expansion or BCS parsing executed.

**Observations:** The main mage template includes definitions, preamble and setup before its
non-hostile/idle guards. Contingency, escape, melee, defensive renewal, easy-mode and pursuit stages
precede the configurable core-magic include. Closedown follows it (`main-mage`, 7-122).
The standard combat file contains 47 include directives in lines 5-51. Early dispelling precedes
many later offensive choices, but availability/pruning and each block's conditions still matter.
This is authored include order, not a list of actions every mage will perform.

Our authored classification is: eligibility/legality; target safety; protection handling;
resource accounting; precombat preparation; archetype priorities; difficulty/randomness;
encounter exceptions; compatibility substitutions; group coordination; BCS workarounds.
These categories are indexing aids, not permission to merge distinct rules. Record source location,
condition, action family, ordering/continuation, side effects, exception, disposition and uncertainty
per future mapping row. Similarity alone never authorizes actor enrollment.

**Counterevidence:** `standard-mage` line 20 includes named Kruin logic. `mage-setup` lines 31-38
contain unequal explicit response weights; lines 76-100 contain state-setting and `Continue()`.
Flattening the files to an unordered spell list loses real source distinctions.

**Artifacts:** `artifact:scs3521-main-mage`, `standard-mage`, `mage-setup`, `preamble` in the
[manifest](scs-source-pilot.evidence.json). [Main template](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/main/dw%23mage.ssl#L7-L122).

**Applicable evidence:** evidence:E1, selected authored structure only.

**Residual uncertainty:** Exact expanded branch order, macro response weights and actual action
selection are not established. No complete taxonomy coverage or behavior-preservation test exists.

**Next decision:** Preserve source ordering distinctions in the effective comparison; approve no
priority rewrite until exceptions and generated behavior are understood. Owner: integration lead.
