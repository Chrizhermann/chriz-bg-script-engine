# Mage pilot migration ledger

**Status:** Source-only research checkpoint; held for effective comparison and reuse review.

**Date / owner:** 2026-09-22 / integration lead.

**Origin:** SCS-derived behavior study; authored factual metadata, not copied policy or source.

**Upstream:** Sword Coast Stratagems v35.21, commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`, component 6030 with 5900 prerequisite. Actual final
stack and settings not selected by this record.

**Family identity / source artifacts:** Ordinary enchanter-to-standard-mage generator branch,
`mage_shared.tph` 384-394 and 472-492, and enclosing main/setup/action layers. Template-selection
inputs: `kit=enchanter`, `detect_invisible=0`, `race=HUMAN`. The later invisibility-detection and
lich/skeleton/demilich overrides are excluded from this lane, not assumed absent from actual actors.
Other generation inputs are still uncollected. Stable research ID
`scs-mage-standard-source-pilot`; this is not an engine resource name or an activation selector.
Digests/links: [source evidence](../../research/scs-source-pilot.evidence.json).
Continuation: [shared-rule/compiler/helper evidence](../../research/scs-shared-rules.evidence.json)
and [interpretation/review](../../research/SCS-shared-rule-expansion.md).

**Effective artifacts:** not collected. No installed actor, generated BCS, effective CRE slots,
resource payloads or complete control closure. `dw#mg...` names never identify this family alone.

**Behavior summary:** Generator inputs choose spells and template branches; setup, defensive,
movement and core combat stages are ordered and may contain named exceptions. Read the six
Task 6 memos beginning with [the pipeline](../../research/SCS-01-generation-pipeline.md).

**Preserved rules:** Proposed dispositions below are research intentions, not shipped behavior.

| Record | Source evidence | Disposition / acceptance still needed |
|---|---|---|
| M01 inputs and identity | `mage-shared` 28-46, 313-367; `caster-shared` 1043-1065; shared-rule continuation | `preserve`: identify by full generator/effective provenance, not generated name; conditional insertion and possible slot shifts/merge are source-traced, but final slots and hashes remain unverified. |
| M02 priority and continuation | `main-mage` 7-122; `standard-mage` 5-51 | `preserve`: do not flatten ordering; compare expanded BCS and later shadow traces. |
| M03 target/protection legality | `first-dispel` 7-31; `caster-definitions` 18-33; shared-rule continuation | `opaque`: six macro bodies and merge/continuation construction source-traced; actual ordered libraries, all prerequisites and effective output still required before policy translation. |
| M04 encounter handoff | `kruin` 5-71; `first-round` 25-77 | `opaque`: legacy-owned; prove control closure and separately review any future enrollment. |
| M05 actions and settings | `mage-setup` 14-38; `difficulty` 140-287 | `needs-engine-proof`: preserve observed source distinctions in future tests; no source-to-runtime promotion. |

**Intentional changes:** None approved. Replacing SCS's runtime is the long-term goal, not permission
to discard its encounter/content changes or copy policies now. Any future generalization/change gets
a separate rationale and counterexample tests. Original infrastructure remains independent of SCS.

**Omissions:** No tactical rule deliberately omitted from the future design in this checkpoint.
Most combat includes, martial/priest families, campaigns and wider components are not mapped yet;
this is an explicit coverage gap, not a conclusion that they are irrelevant.

**Opaque cases:** Untraced target/protection bodies, actual installed-library composition,
per-creature overrides, final weights/continuation, merged-script output, external controllers and
effective stack. Selected library precedence and stripping/insertion source paths are characterized,
but do not establish effective behavior or authorize our own prefix-based resource removal.

**Ownership / fallback:** No adapter claim exists. Unknown content and all studied actors remain
with original BCS/DLG ownership. No guessed dependency closure or permissive fingerprint.

**Tests:** Offline evidence/document checks only; see
[checkpoint verification](../../research/2026-09-22-task6-source-checkpoint.md). No semantic oracle,
compiler, install, shadow, or engine test; ordinary/edge/compatibility cells remain open.
The shared-rule continuation adds source-chain and immutable-artifact documentation regressions,
not behavior-preservation tests.

**Attribution:** SCS by David Wallace (DavidW); follow file/component contributor credit before
derived reuse. Spell Revisions (Demivrgvs/G3) informs optional compatibility branches, not a tested
support claim. Do not imply this project is SCS or endorsed by its authors.

**Distribution decision:** Source links/digests and limited authored factual summaries only.
Upstream payloads remain `reference-only`; effective artifacts remain local-only after authorized
collection. Derived runtime/data/fixtures remain held under
[the register](../upstream-register.md). No source, generated scripts, or reconstructed bulk tables
admitted; no public publication or contributor-license decision made.

**Review:** Integration lead checks source findings and independent reviewer checks this checkpoint;
exact result/corrections recorded in the checkpoint report. Content/provenance review is necessary
in addition to passing offline tests.
