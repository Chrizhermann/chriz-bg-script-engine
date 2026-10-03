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

## Effective difficulty rewrite — 2026-10-04

The [named Kruin comparison](SCS-05-encounter-exceptions.md) now supplies a concrete E1 output
example: CorePlus becomes two OR groups using INI(DMWW_mage_difficulty,...) and
DifficultyGT(EASY). The relevant source is not only difficulty.slb. After variable evaluation,
the [direct-BCS driver148–149](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/sfo2e/lib_ssl.tph#L140-L149)
calls script_difficulty_ini before compilation; the BAF-returning path also calls it at209.

The [rewrite113–118](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/sfo2e/lib_script.tph#L113-L118)
is conditional on m_dw_did.lua existing in the game. It changes matching DMWW-prefixed difficulty
Global tests into INI tests; it is not a rewrite of arbitrary quest globals. The copied lab has
that Lua resource. This source mechanism is consistent with the observed output, without
reconstructing the actor's historical install environment or proving the setting at runtime.
Preserve the effective setting access, engine difficulty and OR grouping separately. Reading only
the raw library's global variable in a future translation would miss this transformation.

**Method / artifacts:** Read-only copied-lab source and the already byte-verified Kruin BAF; no
installer execution, configuration edit or engine run. Exact existing SCS revision. New
lib_script.tph pinned raw SHA-256 `98DE30B02581C54BE7A7996A8A93DEE3637372BC4AB51160D01997C753B18FF0`
(5,507bytes), copied-lab raw `EB2D3FECDAC6D24F6F47FA53DA29F408C842AA622DAC833177CFA8867AD21D0B`;
both sides match after CRLF-to-LF normalization. Installed m_dw_did.lua SHA-256
`7B58B64A6F67FDA7391085C10D3D50729CD5EB3FD4E01EE75F2166F9E9D9AE83` records presence/identity,
not full Lua behavior review. Reuse the SCS-01 raw-byte source recipe and private
`.work/task6/kruin-20261004` output. SCS by DavidW; metadata only, upstream payloads remain private.

**Residual boundary:** No gameplay balance choice, complete difficulty oracle, measured response
frequency, supported-setting sweep or E4 fairness guarantee. The earlier prep-variable distinction
remains unresolved rather than silently normalized. This continuation does not close Task6 or G1.
