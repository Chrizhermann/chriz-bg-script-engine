# Prebuff pilot migration ledger

**Status:** Generic short/long pair compared with installed output; narrow source-derived oracle
admitted for repository use and shadow-only gates implemented. Accounting remains unproved in-engine.

**Date / owner:** Updated 2026-10-04 / integration lead.

**Origin / upstream:** SCS-derived behavior study, v35.21 commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`, mage component 6030/shared caster definitions.

**Family identity / source artifacts:** Ordinary `SpellPrecast` versus `SpellPrecastLong` action
definitions reached through mage setup; stable research ID `scs-prebuff-generic-source-pilot`.
Special paths are explicitly separate exceptions, not automatically enrolled variants. See
[source identities](../../research/scs-source-pilot.evidence.json) and
[accounting memo](../../../../../docs/research/SCS-03-prebuff-accounting.md).

**Effective artifacts:** MAGE6B's installed script, original spell IDs, mapped prebuff helper
resources and file-level spell allocation now inspected; see
[the installed comparison](../../../../../docs/research/2026-09-27-scs-effective-mage-pilot.md). Mirror Image
and Shield preserve the short/long gating and explicit-removal distinctions. Their four final
SPLs and all seven ability slices are characterized: retained effects match the originals
byte-for-byte after filtering the pinned builder's opcode classes. This is output equivalence,
not proof that the exact pinned builder revision ran historically. Both have 300-second timed payloads despite different
prep categories. Live spell state and engine postconditions are not collected.

**Bounded oracle and current implementation:** The reviewed
[pilot oracle](../../../../../docs/research/SCS-pilot-oracle.md) compares the selected source to MAGE6B's
effective blocks and admits six compact, source-derived synthetic expectations under the exact
[fixture allowlist](../fixture-allowlist.json). The
[shadow reducer](../../../../../combat-intent/preparation.lua) implements the short sight/offscreen
and long detection/offscreen/proximity-plus-hostility gate shapes. It accepts explicit, externally
resolved `shortDifficulty` and `longDifficulty` booleans; it does not invent a live
`DoNotPrebuff` flag. It proposes helper identity, one original-copy debit and continuation,
without forcing the helper, spending the spell or setting `instantprep`.

Fresh self observations, known buff absence, a ready copy, accounting readiness and current
combat ownership are conservative pilot requirements imposed by this project. They are not
claimed as exact SCS predicates. Neutral preparation is not admitted by this shadow path.

**Behavior summary:** Short and long preparation differ in perception/proximity gates. Generic
source actions explicitly remove spells; resource/innate/PRECAST paths can differ. The instant-prep
state is shared with first-round transitions, not owned entirely by the generic pair.

**Preserved rules:** Selected dispositions and a non-dispatch shadow comparison, not live behavior:

| Record | Source evidence | Disposition / required comparison |
|---|---|---|
| P01 short gate | `caster-definitions` 470-486; MAGE6B BAF381-409 | `preserve`: availability, generation-time opt-out, instant-prep state, sight/offscreen and death checks. The selected shape is represented in shadow only. |
| P02 long gate | `caster-definitions` 488-514; MAGE6B BAF411-447 | `preserve`: distinct detection/proximity and hostility-related clauses, not merely a duration change. The selected shape is represented in shadow only. |
| P03 expenditure and continuation | Same pair, plus `first-round` 223-268; installed state map | `needs-engine-proof`: helpers request one original removal and Continue but do not set completion; later branches set instantprep and rest resets it. The shadow proposal records, but does not execute, a one-copy debit. External closure and live postconditions remain open. |
| P04 exceptional accounting | `caster-definitions` 641-702; `mage-shared` 833-845; `prep-very-long` 11-63 | `opaque`: do not synthesize generic costs for resource/innate/PRECAST paths. |
| P05 configuration/fairness | `difficulty` 148-190, 226-287; MAGE6B BAF381-447 | `preserve` the observed split between prep and general mage settings; shadow inputs must resolve the emitted predicates. Live setting behavior, other helpers and runtime outcomes remain open. |
| P06 helper payload | Pinned `lib_spl.tpa` 753-832; four final SPL digests in installed comparison | `preserve`: remaining effect order and original-resource321 references. Record nonzero casting times as file metadata, not observed delivery timing. Helper non-stacking and buff detection still need runtime comparison. |

**Intentional changes:** None approved. Ordinary combat's normal-action rule remains the project's
contract; studying special SCS prebuff delivery does not authorize bypassing aura/casting costs.
The pilot's extra fail-closed observations and ownership check are implementation safeguards,
not an approved change to SCS gameplay policy.

**Omissions:** No approved behavior deletion. Full sequencer/contingency accounting, summoned casters,
all spell-mod variants, external offscreen-state writers and encounter-specific prep are not mapped.

**Opaque cases:** Other helper construction, external one-shot/reset closure, special PRECAST spell
allocation, duplicate/recast outcomes, timer/continuation outcomes, interruption, rest and save/load
behavior. This pair's builder and this script's local resets are characterized, not engine-proved.

**Ownership / fallback:** Entirely legacy-owned; the shadow proposal has no dispatch authority.
No active adapter, runtime claim or support enrollment follows from this pilot.

**Tests:** One actual BCS decompile/recompile roundtrip and seven filtered effect-slice comparisons
are byte-identical. The bounded fixture records six authored expectations; separate host-only
shadow gate tests cover representative perception, configuration, ready-copy, current-buff,
ownership and accounting-readiness cases. These are E1 file comparisons plus E2 host behavior, not helper
execution, expenditure or engine acceptance. Special accounting and external closure remain open.

**Attribution:** SCS by David Wallace (DavidW); Spell Revisions by Demivrgvs/G3 for relevant optional
compatibility context. Resolve other component-level credits before derived reuse.

**Distribution decision:** The exact source-derived synthetic fixture and shadow-only reducer
received artifact-specific repository admission. They are credited and contain no copied SCS
source, generated BCS or spell payload. Upstream payloads remain `reference-only`, generated
resources/decompiles stay local-only, and other derived implementation/fixtures remain held for
their own review. No external publication is authorized.

**Review:** Independent source/checkpoint review plus integration-owner verification recorded in
[the checkpoint report](../../research/2026-09-22-task6-source-checkpoint.md). The 2026-10-04
integration-owner review of the narrow oracle and fixture is recorded in the linked pilot memo.
Independent installed helper/state review is recorded in the installed comparison. This is not
LIC-01 closure, runtime acceptance, full-corpus completion or publication approval.
