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
mapping identities, never stable enrollment keys. The helper's full effect payload is not traced here.

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

**Residual uncertainty:** Historical actor-specific flags/libraries, external controllers,
helper payloads, LastSeenBy/False selector semantics, absent party-slot evaluation, timer/casting
outcomes and save/load. Full regeneration and wider spell/encounter support are not proved.

**Next decision:** No user design choice is needed to retain this mapping. Keep legacy ownership;
do not activate a translation or close Task6/G1. Later representative game checks must observe
target selection, actual delivery and expenditure separately. Task3 save routing remains open.
