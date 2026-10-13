# Mage pilot migration ledger

**Status:** Partial source-to-effective research checkpoint with one bounded source-derived
oracle admitted for repository use; no active adapter or broad migration claim.

**Date / owner:** Updated 2026-10-04 / integration lead.

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
and [interpretation/review](../../../../../docs/research/SCS-shared-rule-expansion.md).

**Effective artifacts:** One installed MAGE6B CRE and its assigned SCS6030 script now inspected;
all five resource slots recorded and the BCS decompiled/recompiled byte-identically with WeiDU249.
See [the installed comparison](../../../../../docs/research/2026-09-27-scs-effective-mage-pilot.md) for exact
identity, later CRE owners, source equivalence and bounded findings. Full control closure and
runtime evidence are not collected. `dw#mg...` names never identify this family alone.
The [higher-level MAGE18B comparator](../../../../../docs/research/2026-09-28-scs-high-mage-dispel.md)
adds the opportunistic dispel output absent from MAGE6B. It is a bounded comparison, not a
claim that its exact archetype/generation inputs or all higher-level mages are supported.
The reviewed [pilot oracle](../../../../../docs/research/SCS-pilot-oracle.md) also compares MAGE6B's generic
Shield/Mirror Image preparation with one MAGE18B ordinary Glitterdust branch. Its six compact
source-derived synthetic cases are admitted under the exact
[fixture allowlist](../fixture-allowlist.json). MAGE6B's final spell tables contain none of
Magic Missile, Glitterdust or Slow, so the planned multi-behavior caster remains an authored
fixture, not a migrated MAGE6B actor.

**Behavior summary:** Generator inputs choose spells and template branches; setup, defensive,
movement and core combat stages are ordered and may contain named exceptions. Read the six
Task 6 memos beginning with [the pipeline](../../../../../docs/research/SCS-01-generation-pipeline.md).

**Preserved rules:** Proposed dispositions below are research intentions and bounded shadow
comparison, not shipped gameplay behavior.

| Record | Source evidence | Disposition / acceptance still needed |
|---|---|---|
| M01 inputs and identity | `mage-shared` 28-46, 313-367; `caster-shared` 1043-1065; installed comparison | `preserve`: identify by generator/effective provenance, not generated name. One CRE's final slots and hashes are verified; area/controller overrides and full generator inputs remain open. |
| M02 priority and continuation | `main-mage` 7-122; `standard-mage` 5-51 | `preserve`: do not flatten ordering; compare expanded BCS and later shadow traces. |
| M03 target/protection legality | `first-dispel` 7-31; `caster-definitions` 18-33, 798-813, 1212-1265; higher-level comparison | `preserve` selected emitted gates, action ordering and weighted skip timer. Six macro bodies now compared with one effective branch; historical inputs, selector side effects and action outcomes remain `opaque` / `needs-engine-proof`. |
| M04 encounter handoff | `kruin` 5-72; installed Kruin BAF6587–7172 and separate general script; SCS-05 | `preserve` mapped Symbol Stun/Wilting/SR-fiend branches, explicit Nahal accounting after payload action, and separate approach/dialogue controller. Complete control closure remains `opaque`; actor stays legacy-owned and needs separate enrollment review. |
| M05 actions and settings | `mage-setup` 14-38; `difficulty` 140-287; `lib_script` 113-118 and effective Kruin predicates | `preserve` distinct source settings and conditional Global-to-INI conversion; `needs-engine-proof` for effective setting/response behavior, no source-to-runtime promotion. |
| M06 trigger payload and accounting | `caster-shared` 859-924; higher-level comparison's DW#TG15/DW#MGSEE and immediate children | `preserve`: child order, instant bundle, self-removal/delayed return and ordinary-branch visibility helper are distinct from BCS timers/rest. Bytes inspected; delivery, expenditure and restoration interaction `needs-engine-proof`. |
| M07 ordinary targeted Breach | `attacks_on_pc_defences` 34-48; higher-level comparison BAF6547–6737; DS source73–87 | `preserve`: six ordered target blocks, emitted legality/protection predicates, normal Spell then timer writes, and a Continue-only150-weight skip distinct from early dispel. Actual marker effects, target evaluation and delivery `needs-engine-proof`; missing variants' pruning reasons remain `opaque`. |
| M08 detection self-cast | `truesight` 7-15; SCS-04 comparison BAF8110–8246 | `preserve` enemy candidate versus self recipient, scoped coverage predicates, normal spell/timer and actual SR library replacement. Unmatched source alternatives remain `opaque`; visibility, delivery and detection effect `needs-engine-proof`. |
| M09 manual sequencer | `sequencer` 75–84; `caster-definitions` 1313–1333; higher-level comparison BAF11083–11124 and DW#MS22B | `preserve` selector/action separation,150/50 skip, B-suffix removal/return effects and two forced children with an intervening wait. Not two normal memorized casts; target memory, delivery and accounting outcomes `needs-engine-proof`. |
| M10 bounded preparation/Glitterdust oracle | `caster-definitions` 470–514 and 798–813; MAGE6B BAF381–447; MAGE18B BAF12556–12681 | `preserve` the selected source-to-effective gates, ordered helper/removal/Continue requests and Glitterdust weighted cast/Continue branch in a six-case authored oracle. Shield/Mirror gate shapes are shadow-only; MAGE6B lacks the three planned offensive spells. No recipient, expenditure or engine outcome is proved. |

**Intentional changes:** None approved. Replacing SCS's runtime is the long-term goal, not permission
to discard its encounter/content changes or copy policies now. Any future generalization/change gets
a separate rationale and counterexample tests. Original infrastructure remains independent of SCS.

**Omissions:** No tactical rule deliberately omitted from the future design in this checkpoint.
All 47 standard-mage direct includes now have a pinned identity/literal-label inventory in
[the priority taxonomy](../../../../../docs/research/SCS-02-mage-priority-taxonomy.md), not a semantic map.
Most combat includes, martial/priest families, campaigns and wider components are not mapped yet;
this is an explicit coverage gap, not a conclusion that they are irrelevant.

**Opaque cases:** Untraced target/protection bodies, actual installed-library composition,
per-creature overrides, weights/continuation outside the selected first-dispel branch, merged-script
output, external controllers and
historical generation inputs. Selected library precedence and stripping/insertion source paths are characterized,
but do not establish effective behavior or authorize our own prefix-based resource removal.

**Ownership / fallback:** No active adapter claim exists. Unknown content and all studied actors
remain with original BCS/DLG ownership. The Shield/Mirror shadow proposal requires current combat
ownership and never dispatches; it cannot enroll a legacy actor. No guessed dependency closure or
permissive fingerprint.

**Tests:** The installed comparison additionally proves one byte-identical BCS roundtrip, not
engine behavior. Historical offline evidence/document checks: see
[checkpoint verification](../../research/2026-09-22-task6-source-checkpoint.md). One bounded
source-derived semantic oracle is admitted; separate host tests exercise the Shield/Mirror shadow
gate. No full-corpus semantic oracle, enrolled-adapter shadow comparison or engine test exists;
ordinary/edge/compatibility cells remain open.
The shared-rule continuation adds source-chain and immutable-artifact documentation regressions,
not behavior-preservation tests.
The higher-level comparator adds a second byte-identical BCS roundtrip, not a new test framework
or live support claim.
The named Kruin continuation adds two more private byte-identical roundtrips (generated combat
and archived general script), plus True Sight uses the already retained higher-level decompile.
These are compiler/structure checks, not extra engine launches or behavior-preservation tests.

**Attribution:** SCS by David Wallace (DavidW); follow file/component contributor credit before
derived reuse. Spell Revisions (Demivrgvs/G3) informs optional compatibility branches, not a tested
support claim. Do not imply this project is SCS or endorsed by its authors.

**Distribution decision:** Source links/digests and limited authored factual summaries remain
admitted. The exact source-derived synthetic oracle and Shield/Mirror shadow-only reducer have
artifact-specific repository admission under [the register](../upstream-register.md). Upstream
payloads remain `reference-only`; effective artifacts remain local-only. Other derived runtime,
data and fixtures remain held. No source, generated scripts or reconstructed bulk tables are
admitted; no external publication or blanket contributor-license decision was made.

**Review:** Integration lead checks source findings and independent reviewer checks this checkpoint;
exact result/corrections recorded in the checkpoint report. Content/provenance review is necessary
in addition to passing offline tests.
