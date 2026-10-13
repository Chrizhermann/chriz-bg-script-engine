# SCS mage pilot: priority taxonomy

**Outcome:** Conditional; source-only map with a 2026-10-04 complete direct-include identity
inventory, not a complete priority oracle.

**Question:** Is the standard combat include list the entire mage decision order?

**Environment:** env:host; game-state access none.
The 2026-10-04 continuation also reads source files in the approved copied lab, without launching
the engine, inspecting saves, running the installer or changing the game.

**Versions and fingerprints:** SCS v35.21 pin and hashes in
[scs-source-pilot.evidence.json](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json).

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
[manifest](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json). [Main template](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/main/dw%23mage.ssl#L7-L122).

**Applicable evidence:** evidence:E1, selected authored structure only.

**Residual uncertainty:** Exact expanded branch order, macro response weights and actual action
selection are not established. No complete taxonomy coverage or behavior-preservation test exists.
The [shared-rule continuation](SCS-shared-rule-expansion.md) now traces weight/continuation and
conditional output construction in the Perl source; this is not generated-output or runtime proof.

**Next decision:** Preserve source ordering distinctions in the effective comparison; approve no
priority rewrite until exceptions and generated behavior are understood. Owner: integration lead.

## Direct-include coverage — 2026-10-04

All **47 distinct direct includes** in standard_mage.ssl:5–51 are now identity-checked against the
same v35.21 pin. The copied-lab files match their pinned Git blobs after CRLF-to-LF normalization;
none is missing or duplicated. These files contain 4,542 physical source lines and 423 visible
`Action(...)` call sites using 33 distinct first-argument labels. These are source counts, not
423 different behaviors, tests, supported spells or runtime decisions. The main template's
non-core stages, other magetypes and nested dependencies are outside this inventory.

This gives us a usable breadth checklist while mapping shared rules. For example:

| Literal action label | Call sites | Direct-include files containing it |
|---|---:|---:|
| SpellArea | 75 | 19 |
| Spell | 74 | 20 |
| SpellMyself | 43 | 9 |
| SequencerManual | 42 | 6 |
| SpellAreaIgnoreDNT | 38 | 4 |
| MinorSequencerManual | 14 | 3 |
| Sequencer | 14 | 6 |
| Wand | 8 | 5 |

The remaining 25 labels remain in the private inventory; none is omitted from intended migration
scope. Labels identify definition lookups, not interchangeable semantics. Common definitions can
be researched and eventually implemented once, with representative source/effective/runtime
comparisons and relevant regression cases. Spell-specific conditions, target scopes, weighted
responses, accounting and named exceptions still need their own mapping. A low call count is not
evidence that a feature is unimportant. Do not build one test or one launch per source call.

**Counterexamples:** wish.ssl has zero Action macro calls but has direct BCS actions, so a macro
index cannot measure all behavior. Two authored include paths differ from their pinned path only
by case (`kill_summons_if_no_PC`, `attacks_on_PC_defences`); exact pinned spellings are retained.
The indexed argument labels strip terminal numeric response weights and are not a lossless call
representation. No selected block comment contains an Action/IgnoreBlock call; the simple extractor
is checked for this corpus only, not offered as a general SSL parser.

**Reproduction and artifacts:** Follow the pinned
[include list](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/magetypes/standard_mage.ssl#L5-L51)
and [recursive tree](https://api.github.com/repos/Gibberlings3/SwordCoastStratagems/git/trees/5dc240e9ff85d3909b6436e54b56297d3b61e33b?recursive=1).
For each local source, compare its normalized bytes using Git's blob framing
(`blob <byte-length>` plus NUL, then contents) against the path's pinned blob SHA-1. Do not assume
normalization always matches upstream: elsewhere in this same revision some files are already
CRLF, so first compare raw bytes or normalize both sides explicitly. Line counts exclude a terminal
empty split element. The private one-off `index.ps1`, `index.private.json` and README under
`.work/task6/mage-family-index-20261004` retain exact paths, hashes, line-pinned labels and the run
command. Nothing there is admitted as a redistributable SCS-derived data table.

**Review:** Independent review checked counts, representative source matches, comment handling,
case-only paths and the zero-macro counterexample. It corrected one metadata name: the tree API's
returned commit SHA must not be called the root-tree SHA. The actual root-tree identity is
`e880705c1006b6669df1eef7d957f97485a484b7`; per-file blob comparisons were unaffected. The lead
independently rehashed all 47 raw/normalized copied sources and checked the selected effective
Breach family. Corrected private index SHA-256:
`808D06F4200BA73596F2C85851EE864F632C6EBF4B2AA19648DF172BA79E5226`.

**Evidence and remaining work:** E1 identity/text coverage only. The
[higher-level comparison](2026-09-28-scs-high-mage-dispel.md) separately maps early dispel and one
ordinary Breach family to actual output. Most of this inventory is not yet semantically mapped;
no full oracle, adapter activation, Task6 completion or G1 approval follows. SCS by DavidW;
reference-only source, no bulk policy/source/fixture distribution.

## Shared action boundary checklist — 2026-10-04

All 33 first-argument labels in that private inventory resolve to named definitions in the pinned
`caster_shared/caster_definitions.ssl`; none is unresolved. This is name-resolution coverage,
not complete semantic coverage. Copied-source raw SHA256 is
`825f0d0000101acc375c5c3d4d43ee5cf7656bbac80d825d4932231ee5255440`; CRLF-to-LF bytes match
the existing pinned artifact digest `7040c135bc0233f149cc56f7433bd05bca1109b5f44318a9ad479572827a3373`
in [the source manifest](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json). The lead independently repeated the
label lookup and hash checks after worker extraction, and read these consequential bodies.

The following small checklist identifies distinctions to preserve when grouping reusable code.
It is not a reconstructed policy table or permission to activate any family. All anchors refer to
the [same pinned definitions](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl).

| Boundary | Concrete distinction / source lines |
|---|---|
| Target versus recipient | Ordinary target, self and area variants have different guards; area adds a helper effect before normal casting. 18–33, 177–188, 798–813. |
| Resource accounting | NoDec definitions omit their own HaveSpell check; callers can add accounting. Replace-self checks/removes a different spell from its payload. 379–407, 443–464, 1124–1137. |
| Similar RES variants | Boolean variants add a generation gate. SpellAreaRESBoolean uses failure threshold50, ordinary area60; do not normalize this unexplained difference. 286–340, 798–813, 1028–1043. |
| Side-effect order | Marker effects precede the cast. SpellL9 increments its counter before Spell; SpellL9Area increments after. Counters are not proof of success. 52–68, 124–139, 845–862, 975–992. |
| Composite actions | Sequencer uses ForceSpellRES; manual variants prepend a B-suffix RES action to two/three forced children separated by waits and add guards. Neither is one ordinary spell. 1212–1226, 1243–1347. |
| Separate item/special paths | Wand uses HasItem/UseItem and an interrupt toggle; vsPMscroll selects Spell Strike explicitly. 1189–1204, 1448–1461. |

**Method and limit:** Resolve literal labels against `Name(...)` declarations, then inspect full
definition bodies, not suffixes. The private index recipe remains corpus-specific. Compiler
pruning, response construction, ordered library overrides and call-site conditions still determine
effective output; use the [generation trace](SCS-shared-rule-expansion.md) and the selected
[Breach comparison](2026-09-28-scs-high-mage-dispel.md). No new parser, policy module, test suite
or runtime claim. Independent review narrowed the counter-order comparison to its two exact labels
and removed an unproved semantic role for the B-suffix action. E1 only; future representative batches should distinguish these action families,
not enumerate every call site. Attribution and reference-only restrictions above remain unchanged.
