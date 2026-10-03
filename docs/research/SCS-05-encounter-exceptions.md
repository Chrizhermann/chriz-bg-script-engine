# SCS mage pilot: encounter exceptions

**Outcome:** Conditional; original source-only register extended on 2026-10-04 with one named
source-to-effective comparison. No encounter ownership or engine-behavior proof.

**Question:** Can a shared mage file safely be treated as wholly generic behavior?

**Environment:** env:host; game-state access none.
Continuation uses the approved copied lab offline and WeiDU24900 in private scratch; no engine,
UI, save or active-game operation.

**Versions and fingerprints:** SCS v35.21 pin/digests in
[scs-source-pilot.evidence.json](scs-source-pilot.evidence.json).

**Method:** Follow a named include and first-round exception gates using
[the source method](SCS-01-generation-pipeline.md); no installed creature/area inspected in the
original checkpoint. The continuation below adds one CRE and its generated script, not an area scan.

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

## Kruin source-to-effective continuation — 2026-10-04

**Question:** Does this shared include contain real retained encounter behavior, and what must
not be lost in a generic mage translation? Same copied stack as the
[higher-level mage comparison](2026-09-28-scs-high-mage-dispel.md): SCS35.21, SR4.21-chriz.5,
EET14, BG2EE2.7.3.0, EEex1.2.0. No new content/profile/design choice.

### Identity and generation boundary

The [BG2 variable row2](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/override/bg2/variable.2da#L2)
supplies IsKruin=True. The [override reader241–267](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_shared.tph#L241-L267)
collects it by creature name and type; [mage build335–366](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/mage_shared.tph#L335-L366)
passes it as a generation variable. [RequireBlock496–507](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L496-L507)
is a compiler filter, not a runtime actor-identity check. This pin does not establish Windows
SSL binary/source equivalence or reconstruct all historical inputs.

The installed KRUIN.CRE is4,068 bytes, level15, class1, kit32768, with DV/dialogue `kruin`.
Its slots are override `gpshout`, class/race empty, general `kruin`, default `dw#mg224`.
Retained install DEBUG276977–276983 records SCS generating that default script for KRUIN.
Its decompile/recompile is byte-identical. Thus the following is observed generated output,
not inferred solely from a filename. The named general/override slots remain separate controllers.
The general KRUIN.BCS is not a loose override file; exact-name extraction resolves it from
DATA/SCRIPTS.BIF. Its two blocks both require KruinTalked=0: without See([PC]) it requests
MoveToObject(Player1), otherwise it requests StartDialogNoSet([PC]). This is a concrete
non-combat handoff beside the generated combat script, not permission to replace the whole actor.
The override script, dialogue/area controllers, variable writers and full later owner chain remain
untraced. No running encounter or public variable was changed.

The [original script-recognition gate771–809](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/mage.tpa#L771-L809)
precedes enforcement; post-install slots cannot reconstruct those pre-install inputs. Never turn
the IsKruin row or generated resref into our own broad enrollment shortcut.

### Retained rule groups

Source: [kruin_special5–72](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/kruin_special.ssl#L5-L72).
Effective ranges refer to the private BAF pinned below.

| Effective range | Observation / preservation requirement |
|---|---|
| 6587–6870, Symbol Stun | Six reverse-order enemy selectors end in See/False, followed by a LastSeen candidate. Guards include normal area-action checks, difficulty controls, not-SUMMONED, !NumCreatureGT([ENEMY.HUMANOID],1), stun/chaotic-command/magic-resistance checks, allegiance, not helpless and HaveSpell(2124). Weight200 applies the vision helper, sets castspell, requests SpellNoDec(NPC_SYMBOL_STUN), then ReallyForceSpellRES(dw#nahal,Myself) and RemoveSpell(2124). Weight100 only Continue. |
| 6872–7141, Wilting | Same selector shape, but different target rules: not-SUMMONED OR carrying morsword, magic-damage resistance≤30, MR≤50 OR targetcompromise active, allegiance and no equipped clck26. It requests SpellNoDec(HORRID_WILTING), then the same helper/removal; weight200 versus Continue-only100. Do not borrow the Symbol Stun branch's helpless/summon rules. |
| 7143–7172, fiend | One self-action candidate with three explicit absence-of-visible-demon checks and HaveSpell(2124). Weight200 sets castspell, requests SpellNoDecRES(dw#sumfi,Myself), then helper/removal; weight50 only Continue. This matches the SR resource form, not the other source branch's symbolic spell form. |

All three candidates retain caster spell-failure<60 and castspell-timer checks. Source CorePlus
is not a generation toggle: its expanded difficulty predicates remain in the effective BAF,
using INI(DMWW_mage_difficulty,...) plus DifficultyGT(EASY), rather than the source library's
Global spelling. Preserve the effective logical groups; this is not just an unconditional
"Core difficulty" flag. The [difficulty continuation](SCS-06-difficulty-randomness-and-fairness.md)
traces the conditional source rewrite; actual runtime setting interpretation remains untested here.

SIConjuration/SINecromancy predicates are absent in the corresponding effective groups, matching
SR's explicit [TRIGGER_REPLACE9–20](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library_sr.slb#L9-L20)
blank bodies. This differs from SIAbjuration's append-only declaration in the ordinary Breach
family. The no-decrement action definitions have no ordinary HaveSpell(payload) requirement;
these source branches supply a different resource check and explicit removal of2124.

Source EnemiesInOrder is nearest-first, but the Combine path emits the reverse-six selector order
above; this does not prove which target the engine actually remembers or selects.

**Important ordering counterexample:** The compact source lists the Nahal helper/removal before
Action(...), but the generated response puts them after the selected SpellNoDec action. This
matches the [definition/unconditional-action construction](SCS-shared-rule-expansion.md).
Do not reorder it into an imagined pre-cast setup or call it free casting. Installed SPELL.IDS
aliases2124 to both ALARM and NAHALS_RECKLESS_DWEOMER; the decompiler's chosen label is not a
different resource or proof of live expenditure.

DW#NAHAL contains one self-targeted opcode280, parameter2=1, timing1 effect. SPWI124 contains
opcode214 followed by280. [IESDP280](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op280)
describes type1 as affecting the next valid spell cast; that is E0 interpretation of E1 bytes,
not evidence of which cast actually surges in this script sequence. Delivery, action timing,
slot removal, weighted frequencies and selector side effects all remain `needs-engine-proof`.
No upstream bug, behavior change or named encounter activation is proposed.

### Reproduction and retained evidence

Reuse the high-mage report's native-path WeiDU24900 command recipe with `dw#mg224` and a fresh
private output directory. Both commands returned0, created the expected BAF/BCS, and had no
ERROR/FATAL log entry; the BCS roundtrip matched. Tool SHA-256:
`AD70F5897A6D0BA4B0D226F845A9B14CF345F56CC9697CA8D05CAC9FE4932C1A`.
WeiDU may refresh the copied lab's weidu.conf timestamp; its content hash stayed unchanged.
Nothing was installed or launched, and no profile/save was accessed.

| Artifact | SHA-256 |
|---|---|
| KRUIN.CRE | `75E62D08D8039456D718F940FD9144F4FDFDD98FF65E9154BF95CA5F8690840C` |
| Installed/rebuilt dw#mg224.bcs | `E7858C3D04872A317557C1C2943F6A4E2B7438C12172639AD38717A3C1CEB00C` |
| Private BAF | `664D2EEB3EA693707D8A938B05D175EA497B2F941CE2704C5E26DB9431255351` |
| Extracted/rebuilt KRUIN.BCS | `B31EA9DB5AF4A9C5797E44B3BF7A0CF357EFA696FF01562B8CD93B8E9395CD1D` |
| General-script private BAF | `06C1F43050BA62F3B4F44B991BBE5B32DC4F97C3A8C0BB96065249B697D4F43D` |
| DW#NAHAL.SPL | `04E3444FF990B93DFDE1E9E66E2A3954FF2D126B85FDE2B10442825EBE7EBE72` |
| SPWI124.SPL | `232D9EAA16819A3EBE96E7C1857303874B4247110324D9B92F27DD78D7816DCC` |
| Pinned BG2 variable.2da | `35FA78EEC99D9F5406FF0E6E46DE2953B1A39F596C1FECEC6E6E74361EF85591` |

All source anchors use the existing SCS pin. Main/source/action/library identities reuse the
source manifests and reviewed direct-include index; the new variable row matches copied-lab
content after CRLF normalization. Worker extraction and lead checks corrected an initial
line-ending false alarm: some upstream files are themselves CRLF, so normalizing only the local
side before comparing to a raw Git blob is incorrect. No source drift was found in this chain.

Private artifacts, commands, logs and SPL field output: `.work/task6/kruin-20261004`.
SCS by DavidW; Spell Revisions by Demivrgvs/G3. Only this authored factual summary and identities
are admitted to Git; source, generated scripts, installed resources and any derived behavior
fixture remain reference-only/private. E1 compiler roundtrip is not E3 installation or E4 playtest.

The exact general-script command was WeiDU's `--out . --biff-get KRUIN.BCS` in the same private
scratch, followed by decompile and a recompile into a fresh `general-roundtrip` subdirectory.
All three exited0, produced expected outputs without ERROR/FATAL and the BCS roundtrip matched.
No extracted resource was written into the game. Exact successful commands and any failed host
attempts are retained in the private recipe, not conflated with accepted compiler evidence.

**Review:** Independent source-chain extraction, independent effective-block/helper-byte review
and lead inspection agree. Final wording review retained exact namespaces and called untraced
slots controllers rather than implying a proved ownership chain. Source nearest-first versus
emitted reverse-six order and definition-versus-unconditional action order remain explicit.
No source/runtime behavior claim or intentional change follows from compiler success.
The final independent delta review also verified the BIF extraction/roundtrip and conditional
difficulty rewrite. Existing24 evidence/schema checks passed in0.07s, task-state JSON parsed,
and `git diff --check` passed. No new tests or generic tooling were added.
