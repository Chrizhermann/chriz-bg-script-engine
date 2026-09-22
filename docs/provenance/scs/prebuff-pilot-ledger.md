# Prebuff pilot migration ledger

**Status:** Source-only research checkpoint; accounting variants not engine-proved.

**Date / owner:** 2026-09-22 / integration lead.

**Origin / upstream:** SCS-derived behavior study, v35.21 commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`, mage component 6030/shared caster definitions.

**Family identity / source artifacts:** Ordinary `SpellPrecast` versus `SpellPrecastLong` action
definitions reached through mage setup; stable research ID `scs-prebuff-generic-source-pilot`.
Special paths are explicitly separate exceptions, not automatically enrolled variants. See
[source identities](../../research/scs-source-pilot.evidence.json) and
[accounting memo](../../research/SCS-03-prebuff-accounting.md).

**Effective artifacts:** not collected. No generated prebuff SPL, effective BCS/decompile, memorized
spell state or engine postconditions. Actual stack/actor/settings remain unselected.

**Behavior summary:** Short and long preparation differ in perception/proximity gates. Generic
source actions explicitly remove spells; resource/innate/PRECAST paths can differ. The instant-prep
state is shared with first-round transitions, not owned entirely by the generic pair.

**Preserved rules:** Proposed mapping dispositions, not implemented behavior:

| Record | Source evidence | Disposition / required comparison |
|---|---|---|
| P01 short gate | `caster-definitions` 470-486 | `preserve`: availability, opt-out, instant-prep state, sight/offscreen and death checks. |
| P02 long gate | `caster-definitions` 488-514 | `preserve`: distinct detection/proximity and hostility-related clauses, not merely a duration change. |
| P03 expenditure and continuation | Same pair, plus `first-round` 223-268 | `needs-engine-proof`: compare force/removal/continuation and all state writers; observe separate postconditions later. |
| P04 exceptional accounting | `caster-definitions` 641-702; `mage-shared` 833-845; `prep-very-long` 11-63 | `opaque`: do not synthesize generic costs for resource/innate/PRECAST paths. |
| P05 configuration/fairness | `difficulty` 148-190, 226-287; prep group files | `opaque`: resolve actual general/prep inputs, conditions and generated spell durations. |

**Intentional changes:** None approved. Ordinary combat's normal-action rule remains the project's
contract; studying special SCS prebuff delivery does not authorize bypassing aura/casting costs.

**Omissions:** No approved behavior deletion. Full sequencer/contingency accounting, summoned casters,
all spell-mod variants, offscreen-state/reset writers and encounter-specific prep are not mapped.

**Opaque cases:** Effective resource construction, one-shot/reset closure, special PRECAST spell
allocation, timer/continuation outcomes, interruption, rest and save/load behavior.

**Ownership / fallback:** Entirely legacy-owned; no adapter, runtime claim or support enrollment.

**Tests:** Evidence integrity/document contract only. Planned later cases separately vary sight,
proximity, hostility, opt-out, death, availability, prep state, difficulty and special accounting.
They are test requirements, not copied fixtures or passing behavior tests. No SCS-derived fixture
is approved; `tests/fixtures/manifests/scs-pilot.synthetic.json` intentionally does not exist yet.

**Attribution:** SCS by David Wallace (DavidW); Spell Revisions by Demivrgvs/G3 for relevant optional
compatibility context. Resolve other component-level credits before derived reuse.

**Distribution decision:** Only authored minimal factual research, links and digests admitted at this
checkpoint. Upstream remains `reference-only`; generated resources/decompiles stay local-only after
authorized collection; derived implementation/fixtures remain held pending artifact-specific review.

**Review:** Independent source/checkpoint review plus integration-owner verification recorded in
[the checkpoint report](../../research/2026-09-22-task6-source-checkpoint.md). This is not LIC-01
closure, runtime acceptance, Task 6 completion, or publication approval.
