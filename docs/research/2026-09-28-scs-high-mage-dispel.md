# Installed higher-level mage: opportunistic dispel

**Outcome:** Partial Task 6 progress, evidence:E1. One higher-level comparator now connects
the previously traced early-dispel source to its actual generated output. No policy is activated.

**Question:** Which target checks, choices and timer writes survive generation for a mage that
has the higher-level dispel path missing from the level6 sample?

**Environment:** Offline inspection of the existing approved SCS-reference lab only. Same stack
as the [first installed pilot](2026-09-27-scs-effective-mage-pilot.md): BG2:EE 2.7.3.0,
EET 14.0, EEex 1.2.0/LuaJIT, SCS 35.21 and Spell Revisions 4.21-chriz.5. No engine, UI, save,
installer or active installation was used. The copied WeiDU.log digest is unchanged.

**Method:** Select a higher-level CRE independently of its generated script name; read its
script slots/spell allocation, locate generation in the retained SCS log, decompile/recompile
with WeiDU24900 in private scratch, compare bytes, then compare one bounded generated region
to pinned source and installed ID/mapping tables. Do not rebuild SSL or infer missing flags.

## Actor and evidence identity

MAGE18B.CRE is listed in the copied EET BG2 vanilla CRE oracle at line1969. Its final file is
4,204 bytes: level18, MAGE, ELF, kit0, death variable `mage18b`, empty dialogue. Script slots
are override empty, class empty, race `None`, general empty, default `dw#mg256`. This is a
CRE-level observation, not proof of area/spawn overrides or every later mod's ownership.

SCS install DEBUG lines277384–277390 record MAGE18B's generated `dw#mage.baf` being assigned
to `dw#mg256.bcs` in component6030. The final actor has36 known and47 memorized entries,
including two SPWI302 entries and one DW#TG15 entry, each with memorized flags1. Both resources
also occur in its known list. These are file allocations, not observed available spells in play.

Installed SPELL.IDS lines340–341 give **both** WIZARD_DISPEL_MAGIC and WIZARD_REMOVE_MAGIC
the number2302. Thus the decompile's REMOVE_MAGIC label does not itself mean the source spell
changed. Installed `trigger_list.2da` line80 maps DEATH_SPELL_DISPEL_MAGIC_GREATER_MALISON
to `dw#tg15`; the same table maps 3X_DISPEL_MAGIC to `dw#sq34` at line59. Those are local
mapping identities, never stable enrollment keys. The continuation below inspects this trigger
and its immediate spell children, not their complete transitive effect/projectile closure.

Eight selected source files match the existing v35.21 pin
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`: library, mage-shared and ssl-compiler raw;
caster-definitions, first-dispel, library-sr, main-mage and standard-mage after CRLF-to-LF
normalization. Their exact identities remain in the two existing source evidence JSON records.
This is not proof that the current generic workspace/autolib contains this actor's historical inputs.

## Observations and migration dispositions

Source anchors: [first-dispel 7–31](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/first_dispel.ssl#L7-L31),
[SpellArea 798–813](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L798-L813),
[sequencer definitions 1212–1265](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L1212-L1265).
The [shared-rule report](SCS-shared-rule-expansion.md) supplies the library/compiler anchors.
Effective lines below refer to the hashed private decompile, not the compact SSL.

| Effective lines | Observation / disposition |
|---|---|
| 6173–6360 | Three selector blocks are ordered ThirdNearest([PC]), SecondNearest([PC]), [PC], each ending in See(target), False(). Later candidates use LastSeenBy(Myself). `preserve` the emitted order; the selector's target-memory side effect still `needs-engine-proof`. Do not substitute portrait order or assume all selectors run successfully. |
| Same selectors and 6362–6501 | The protection disjunction, all-six-player disabled/insect/allegiance/Malison checks, SR's all-six-player TURNING_TO_STONE checks, delay_dispel timer and base spell-immunity predicate survive expansion. `preserve` their distinct scopes; this is not just a selected-target buff check. |
| Same region | Caster level>14, !TIME_STOP and three level/chapter OR pairs survive. Chapter literals are18/19/20 in this install. Source HasL6 is a generation requirement, not an emitted runtime predicate; exact historical pruning inputs remain `opaque`. |
| 6362–6428 | A single-weight100 sequencer candidate checks its own availability, targetability and !Improved Alacrity, sets castspell=ONE_ROUND, then ForceSpellRES(dw#tg15), then firstdispel=1000 and DMWW_dispel=THREE_ROUNDS. `preserve` order; expenditure/delivery `needs-engine-proof`. |
| 6430–6501 | SpellArea has availability, !invisibility, !sanctuary, caster spell-failure<60 and do-not-target checks. Its weight100 response applies dw#mgsee, starts castspell, requests normal Spell, then writes the two dispel timers. A separate weight50 response writes firstdispel=1000 and Continue only. `preserve` the skip's state change; it is not a post-cast callback. |

The source's two manual-sequencer alternatives are absent from this region. Current allocation
tables list possibilities, not the actor's generation-time choice. Do not invent a reason for
their pruning or add those alternatives back merely because they occur in the compact source.

For the ordinary-spell block, 100:50 describes a two-to-one response weight, not a measured
casting frequency. The earlier sequencer or another higher-priority block can prevent reaching
it. Likewise the source calls this a fast opportunistic dispel, but this is not necessarily the
actor's first combat action: thousands of generated lines precede it. The emitted timers follow
the action requests; they are not proof that a cast completed or removed any protection.

**Counterevidence:** The source's four alternatives become two emitted action blocks; a source
spell name changes spelling through an IDS alias; an ordinary SR comment-only declaration does
not remove the base immunity predicate; the non-casting response still writes the firstdispel
timer. Each would be lost by treating the source as a plain ordered spell list.

## Trigger payload and reuse accounting

**Continuation question:** What does the selected trigger contain, and what stops or restores
its use? Read five exact override SPLs directly; no installer, compiler or game execution.
The private reader uses the SPL header's separate casting-effect and ability-effect slices,
including nonzero starting indices, rather than assuming all effects are delivered to the target.

DW#TG15 is a 394-byte innate level1 spell with one ability (minimum level0, target1,
casting time0, stored projectile1), zero casting effects and these five ability effects:

| File order | Raw operation / resource | Migration significance |
|---|---|---|
| 0, 1, 2 | opcode146, target2, parameter2=1: SPWI302, SPWI412, SPWI605 | Preserve the actual bundle order; the table name lists DEATH_SPELL first but the file does not. This is not three ordinary scripted casts. |
| 3 | opcode172, target1, resource dw#tg15 | Self-removal is part of this helper, separate from the BCS action's availability check and timer writes. |
| 4 | opcode171, target1, resource dw#tg15, timing4, duration1440 | Delayed return is encoded separately from the removal. Do not equate1440 with the actor's rest timer or assume a successful observed recharge. |

All five effects have probability bounds100/0, resistance0 and save fields0. The
[IESDP opcode descriptions](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op146)
describe146/type1 as instant casting at caster level,172 as spellbook removal and171 as giving
an ability. [SPL timing4](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/spl_v1.htm)
is delayed/permanent. These are E0 documentation interpretations of E1 bytes, not observations
of delivery, expenditure, elapsed engine time or persistence.

The copied `caster_shared.tph` matches the existing source pin after CRLF normalization
(SHA-256 `4868EDF4D61CC68E6DBC4EE53CAF56FDC2CD406DB42E723F0DF9548A14871929`). Its
[make_spell_trigger](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_shared.tph#L859-L924)
builds the child casts and remove/return effects. The pinned
[trigger.2da row21](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/triggers/trigger.2da#L21)
supplies DISPEL_MAGIC, GREATER_MALISON, DEATH_SPELL in that order. The builder's name routine
(caster_shared lines1311–1364) sorts the labels, not the row's payload arguments.
Category dsp also asks the builder for a separate B-suffixed remover clone; this selected
ForceSpellRES branch calls the original, not that clone. Installed SPELL.IDS also
aliases2605 to both DEATH_SPELL and BANISHMENT; a source label is not a vanilla payload guarantee.

The immediate children are distinct delivery resources: SPWI302 has eight ability effects;
SPWI412 has two casting effects and one ability effect referring to SPWI412D; SPWI605 has two
casting effects and two ability effects referring to DVBANISH. Their stored projectiles are
177,170,172 respectively. The latter two casting slices refer to DW#BLHDA/DW#HDANI. These
dependencies are recorded, not recursively interpreted or admitted as a complete oracle.
Their casting times3/4/6 must not be substituted for the trigger's instant child-cast mode.
File order is not proof of the order in which separate projectiles reach their targets.

The ordinary SpellArea branch has its own helper: DW#MGSEE contains one self-targeted opcode193,
parameter1=6, parameter2=16, timing0, duration6. IESDP describes193 as script invisibility
detection via SEEINVISIBLE. It does not remove invisibility from the target. Preserve this
pre-action effect separately from the already emitted !INVISIBLE/!sanctuary guards; no live
target-legality result is claimed.

The same actor's BAF lines132–171, matching
[rest.ssl](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/generalblocks/rest.ssl#L5-L49),
separately move rest_state0→1 on detecting an enemy,
1→2 and start rest_timer when detection ends, and 2→1 on renewed detection. Expiry in state2
resets rest_state/instantprep/contingency flags, sets redefend, requests healing and Rest().
Installed GTIMES.IDS defines EIGHT_HOURS=2400, not1440. This bounded block does not explicitly
re-grant DW#TG15 or reset firstdispel/DMWW_dispel. Do not merge helper restoration, rest recovery,
normal spell slots and short combat timers into one guessed cooldown rule.

**Disposition:** Preserve these separate source/file mechanisms; their interaction with actual
ForceSpellRES execution, interruption, child delivery, spellbook state and save/load remains
`needs-engine-proof`. No change to SCS fairness, spell allocation or recharge behavior is proposed.

## Ordinary Breach continuation — 2026-10-04

**Question:** Which shared rules survive in a repeated, ordinary targeted-spell family, rather
than the earlier combined dispel selector? Same actor, installed stack and private decompile;
read-only E1 inspection, not a new cast or generation run.

The [ordinary Breach block](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/attacks_on_pc_defences.ssl#L34-L48)
matches six consecutive effective blocks at BAF lines6547–6737. The source is the ninth standard
combat include, not the next include after early dispel. Other source families intervene; this
actor's two emitted defensive-renewal blocks immediately precede the six Breach blocks.

| Rule group | Effective observation / migration disposition |
|---|---|
| Target expansion | Six ordered candidates: `[PC]`, then second through sixth nearest PC. `preserve` the emitted order, not portrait slots; runtime evaluation with fewer targets remains unproved. Unlike the combined early-dispel branch, these are full repeated conditions/actions, not `See/False` selector stubs. |
| Ordinary-action checks | Each has castspell-timer availability, HaveSpell(BREACH), not-not-targetable, no sanctuary, caster spell-failure<60, no DO_NOT_TARGET_SPELLS and See(target). `preserve` these distinct checks; no claim that they are a complete legality model for all spells. |
| Shared protection checks | Each rejects positive Spell Turning, Spell Trap, Spell Deflection and Shield of the Archons stats, and spell-immunity-stat value1. The base SIAbjuration test remains present despite SR's comment-only declaration. `preserve`; do not replace the emitted predicates with a guessed generic immunity flag. |
| Relationship and state | Caster must have ENEMY allegiance, selected target must not; target is not immobile/feebleminded/held. Target must have PRIORITY_BREACH, caster must not have TIME_STOP, and DMWW_breach must not be unexpired. `preserve` the scopes and negations. |
| Casting response | Weight100 sets castspell=ONE_ROUND, requests normal Spell(target,BREACH), then sets DMWW_dispel, DMWW_antimagic and DMWW_breach to THREE_ROUNDS, in that order. Installed GTIMES resolves these to6 and18. `preserve` order; action completion and timer execution remain `needs-engine-proof`. |
| Skip response | Weight150 contains only Continue(). It does not write those timers, unlike the earlier dispel skip that writes firstdispel. The conditional weight ratio is100:150, not observed cast frequency or a post-success callback. `preserve` this difference. |

Source expansion anchors are [Spell definition18–33](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L18-L33)
and base library [protection41–45](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L41-L45),
[relationship/state63–69](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L63-L69),
[target order244–250](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L244-L250),
[priority marker366–367](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L366-L367)
and [immunity845–846](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb#L845-L846).
Installed SPELL.IDS resolves WIZARD_BREACH to2513; SPLSTATE.IDS resolves PRIORITY_BREACH to183.
The [DS source table73–87](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ds/ds_scs.tpa#L73-L87)
is another input to that marker, not a literal condition expanded at the call site. Its list
differs from the older call-site comment (for example, Stoneskin and Death Ward are not entries
in this selected table). Therefore preserve the observed marker check; do not derive a replacement
protection list from the comment. Complete DS patching/final effect provenance remains open.

**Counterevidence and boundary:** Source `IgnoreBlock(Indiscriminate)` is a generation filter,
not an emitted runtime condition. The wand18 alternative and special ADHW/priority_breach variant
are absent from the retained effective region; this does not establish why generation pruned them.
No separately identifiable predicate is attributed to the `slowspell` comment marker. No Breach
payload, removal outcome or complete resource/control closure is claimed. Six structurally repeated
blocks are one useful migration family, not six independent spell designs or six required launches.

**Artifacts and reproduction:** Reuse the hashed BAF below and inspect lines6547–6737; source
comparison uses the exact pin and SCS-01 raw-byte recipe. The source file's upstream SHA-256 is
`F6BEF77A69E1297FA1862585B7EF57D95CE01420A1EA6EE34888281CA5DB5BE8` (7,528 bytes), copied-lab raw
`C60D8DABA1959B005653CCC52FA7068D38C11BA6754674AB3F7BA95F53EA607C`; CRLF-to-LF content matches.
DS source upstream SHA-256 is `95F77F73D30871CD70C8A3D49B148EDAAF4CCD46C41A32C3984243A861247A77`
(6,244 bytes), copied-lab raw `F635DC131108C657907D7FC4B5834ACA30578343B33AACF4CB2C302F56F51207`,
also matching after normalization. Private pins are in
`.work/task6/mage-family-index-20261004/breach-pins.private.json`. No upstream payload or derived
behavior fixture is added to Git. Credit and reference-only restrictions below still apply.

## Manual sequencer continuation — 2026-10-04

**Question:** Does a representative composite spell follow the same accounting and action path
as an ordinary cast? The existing MAGE18B decompile answers the structural part without another
game launch. It does not answer whether every child actually executes or lands.

Pinned [sequencer.ssl:75–84](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/sequencer.ssl#L75-L84)
requests a two-Minor-Lightning-Bolt `MinorSequencerManualRES` with weights150/50 and Combine.
The installed trigger table line24 maps that symbolic bundle to `dw#ms22`; SPELL.IDS line336
maps WIZARD_MINOR_LIGHTNING_BOLT to2229. These exact local mappings, not a generated-name rule,
connect the call to BAF11083–11124. The definition is
[caster_definitions.ssl:1313–1333](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L1313-L1333).

The emitted action block requires the bundle, cast timer, enabled/living caster, no improved
alacrity or running time stop, and targetability/DNT, resistance/protection, allegiance,
difficulty and sight predicates. Its150-weight response sets the cast timer, forces the
B-suffix resource, forces SPWI229, waits1, then forces SPWI229 again. Its50-weight response
only Continues. The selected target is LastSeenBy, not a fresh independently chosen target
for each child. No ordinary child memorization check or BCS RemoveSpell appears in this response.

**Accounting counterexample:** Absence of BCS RemoveSpell is not absence of accounting.
The existing private SPL reader shows DW#MS22 contains two opcode146 child effects followed by
self-target172 and delayed171 referencing the bundle itself. DW#MS22B contains no146: it retains
172/171, adds three one-second opcode101 entries for38/60/80 and one-second189 with parameter1=10.
The [builder:913–924](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_shared.tph#L913-L924)
explicitly constructs this remover clone by deleting146 from the base. Its retained171 has
timing4/duration1440, as in the earlier trigger family. IESDP describes
[172 as spell removal](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op172) and
[171 as ability granting](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op171) (E0 reference);
the bytes and builder are E1. Actual removal, delayed return and interrupted-child behavior
still need engine observation. Do not replace this with two normal memorized casts by analogy.

**Selector counterexample:** BAF10569–10605 ends with See, False and Continue. The worker initially
called this pruning; lead review corrected it: Combine deliberately emits selector blocks
([compiler:973–977](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L973-L977)).
The later surviving action block is the relevant comparison. Neither the selector's False nor
the source's preferred weak-target conditions alone prove runtime target-memory behavior.
The initially sought undead-paranoia manual dispel response was not found in this BAF; do not
promote its lich/vampire-guarded source call to observed MAGE18B output.

**Reproduction:** Reuse the existing hashed BAF/IDS/trigger table and inspect the ranges above.
The47-file private index pins sequencer.ssl (normalized SHA256
`0d2050773637ac8019f456545b8d09b12d551275c336b419e58fbb67e4c13dcd`).
Run the unchanged `inspect-trigger.ps1 -Resources DW#MS22,DW#MS22B,SPWI229` against the approved
copied lab; retained `manual-sequencer.private.json` records fields and raw effect bytes.
Installed SPL SHA256 identities are DW#MS22
`07031c8967eb6d73c04c3a850a9211ab29d784f0b6856322207f504f554610d7`, DW#MS22B
`b5fdb083f71e6bd6e8d975f24c744851ac4008a1ca5ff8bdd547387276ef031c`, SPWI229
`240f6f32011ac8020a64cbb3152688d13df3309a4adad05a3e6dab8a9b679a8a`.
Child projectile/transitive helper closure and complete final patch ownership remain open.
No new parser, tests, fixture publication or actor admission. SCS/Spell Revisions credits below apply.
Independent review checked the source-to-output mapping, directly rehashed the three installed
SPLs and accepted these bounded conclusions. The lead retained the selector correction above.
The combined existing action/persistence/evidence checks passed42 in0.17s; no new test case
was added for this research. Those checks validate code/evidence contracts, not SCS behavior.

## Reproduction, artifacts and review

Private directory: `.work/task6/high-mage-20260928`. Reuse the already recorded WeiDU24900
executable; do not copy/install the game again. The following records the successful commands;
use a fresh private scratch directory for a future repeat rather than overwrite retained logs.
Native Windows paths are significant here:

```powershell
$lab = (Resolve-Path (Get-Content .work/task3/practical-lab-20260927.json -Raw | ConvertFrom-Json).destinationRoot).Path
$tool = (Resolve-Path .work/task6/effective-pilot-20260927/weidu.exe).Path
$scratch = (Resolve-Path .work/task6/high-mage-20260928).Path
Push-Location $scratch
try {
    & $tool --game $lab --use-lang en_us --noautoupdate --log decompile-native-path.log (Join-Path $lab 'override/dw#mg256.bcs')
    & $tool --game $lab --use-lang en_us --noautoupdate --log recompile-native-path.log './dw#mg256.baf'
    Get-FileHash (Join-Path $lab 'override/dw#mg256.bcs'), './dw#mg256.bcs' -Algorithm SHA256
} finally { Pop-Location }
```

Both successful commands exited0, produced their expected outputs and had no fatal diagnostic.
The BCS roundtrip is byte-identical. Decompile:13,633 lines,479 IF blocks,627 responses,
320 Continue actions; descriptive counts only, not a requirement for hundreds of tests.
Initial forward-slash `--game` attempts reported no matching language paths, produced no BAF/BCS,
and returned0 despite FATAL ERROR. Retained logs show failure, not acceptance. Using Resolve-Path's
native path with the same tool/language/files resolved the issue. No game files were repaired.
WeiDU refreshed the lab's 17-byte `weidu.conf` timestamp; it still contains `lang_dir = en_us`.
The active installation and all profiles/saves were untouched.

| Artifact | SHA-256 |
|---|---|
| Final MAGE18B.CRE | `35FC119692000361F012D9E0CE6027F367269217FB0CC924AF02AC955FB51D4E` |
| Installed/rebuilt dw#mg256.bcs | `2E7CF46847CFC0704DB7789D45BE9D4864B7F3748E8B8296B226E5C6F883388D` |
| Private decompile | `99491588A4F702BFAF665E0C9670CE32EA7C6FE58B928827FD80D8DB034917C1` |
| Installed SPELL.IDS | `1FD84A38609DAB514BFE94A527943F103C9E860B32DE77B03DDD601F934EEFD1` |
| Installed trigger_list.2da | `A2F413D709B47EE12E5ED858AA8A97181901B45A07838255A3CBFBA4AE9D2952` |
| Installed DW#TG15.SPL | `1F35014443AA24633A90AA6F8C41D8B3B9DB9D7D077DA8022B824FCF416CA77A` |
| Installed DW#MGSEE.SPL | `4888B610A65E4DCA704DD2C88B40791C84D42D9D7AF596BEB5B3C4990B7B8B54` |
| Installed SPWI302.SPL | `509CB56033CDA4233131F8F75499732B2B33CF842362B007EDA1BCC8613CD988` |
| Installed SPWI412.SPL | `6409689A93F302E5DBDBEBBF96B92DC6D066B883F158CED3DFD9181F1458F498` |
| Installed SPWI605.SPL | `ECAAF5B4847592AE6D73306D2D8BC1AB602A66F4AF20F21AF1C508E3BF7DA2C8` |
| Pinned trigger.2da (13,950 raw bytes) | `58562F4F06AAC3AB991F50D644875E4976FAF5A42676203D30CCD2652333756C` |
| Pinned rest.ssl (1,191 raw bytes) | `DA7AE0C659192B9E7EC5BB0972140BB5CCE06778F41C4CCF8E39730005ACC625` |

The continuation reuses the prior private SPL-reader pattern as `inspect-trigger.ps1` in the
same high-mage directory. Reproduce with `& ./inspect-trigger.ps1` for DW#TG15/DW#MGSEE and
`& ./inspect-trigger.ps1 -Resources SPWI302,SPWI412,SPWI605` for the children, passing the
approved copied lab as `-LabRoot`. Retained outputs: `trigger-and-vision.private.json` and
`trigger-children.private.json`; executed with PowerShell7.6.6, exit0. Reader SHA-256:
`1B371B4F7E29DDFCEA49A078B085589B49740E0EB083842D9B25B2630A28A45E`.
Nothing in the game or profiles is written by these reads. `trigger-source-pins.private.json` records direct raw-byte
HTTPS hashes at the same SCS revision: both additional copied sources match after CRLF-to-LF
normalization. The installed SPL hashes describe this stack, not an upstream vanilla baseline.

**Artifacts:** Private decompile/recompile, command logs, actor field summary and source-match
record; existing pinned source manifests and earlier tool/stack digests. No upstream payload,
decompile or derived behavior fixture is admitted to Git. SCS by DavidW; Spell Revisions by
Demivrgvs/G3. Full final CRE/SPL content-owner chains remain uncollected.

**Applicable evidence:** E1 source, installed files and byte-identical compiler roundtrip.
Not an E2 behavior simulation, E3 install/uninstall check, E4 game result or complete semantic oracle.

**Review:** Independent Sol extraction checked source gates, the selected effective region and
installed helper mapping. The lead independently checked the emitted blocks, actor allocation,
symbol aliases, byte roundtrip and source digests. The worker's final document review found no
blocking technical error; wording corrections distinguished the earlier source-only checkpoint,
untraced remainder and unproved selector side effect. The lead incorporated those corrections.
Existing checks passed:24 in0.15s using
`python -X utf8 -m pytest -q tests/schemas/test_scs_source_checkpoint.py tests/schemas/test_research_evidence_schema.py`.
These validate evidence records, not game behavior. No new test suite/cases; `git diff --check` passed.

**Continuation review:** Sol independently traced the trigger builder/allocation/rest source,
rehashed all five copied SPLs and checked the field summaries against the report. No blocking
error or overclaim was found. The lead verified source arguments/name sorting, binary effect
slices and the additional upstream pins (local CRLF bytes differ; normalized content matches).
The same24 existing checks passed in0.08s; no new cases. All findings remain read-only research.

**Residual uncertainty:** Historical actor-specific flags/libraries, external controllers,
transitive child/helper payloads, LastSeenBy/False selector semantics, absent party-slot evaluation, timer/casting
outcomes and save/load. Full regeneration and wider spell/encounter support are not proved.

**2026-10-04 review:** Independent Sol source-to-output review accepted the ordinary Breach
continuation without a material correction. The lead checked all six emitted blocks, macro
bodies, installed numeric aliases, raw/normalized source identities and the DS comment mismatch.
Existing24 evidence/schema checks passed in0.06s; no new tests, framework or game run. These checks
validate the retained evidence records, not the truth of the new source interpretation by themselves.
`git diff --check` passed. The separate inventory review corrected an API metadata label, documented
in SCS-02; per-file matches and behavior observations were unaffected.

**Next decision:** No user design choice is needed to retain this mapping. Keep legacy ownership;
do not activate a translation or close Task6/G1. Later representative game checks must observe
target selection, actual delivery and expenditure separately. Task3 subsequently completed; this
read-only mapping neither changes its approved lab boundary nor closes G1.
