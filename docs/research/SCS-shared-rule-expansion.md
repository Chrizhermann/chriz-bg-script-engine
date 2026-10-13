# Task 6: shared-rule and generation-helper source trace

**Outcome:** Conditional, source-only checkpoint, 2026-09-22. Task 6 remains in progress.
This continues the [first checkpoint](../../archive/2026-10-process/docs/research/2026-09-22-task6-source-checkpoint.md), not a gate pass.

**Question:** What changes between compact early-dispel source, selected shared libraries and
the compiler/helper stages, before any effective generated-script comparison?

**Environment:** env:host; game-state access none. Read-only public HTTPS inspection in memory,
authored metadata and offline documentation checks. No game, save, installer or upstream execution.

**Versions and fingerprints:** SCS v35.21, commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`; 15 raw-file identities in
[scs-shared-rules.evidence.json](../../archive/2026-10-process/docs/research/scs-shared-rules.evidence.json). Three identities are reused
unchanged from the first checkpoint; twelve are new. This is not an installed-stack fingerprint.

**Method:** Use the PowerShell recipe in [SCS-01](SCS-01-generation-pipeline.md), changing its
input filename to `scs-shared-rules.evidence.json`. Hash raw bytes without line-ending conversion;
inspect numbered LF-delimited source ranges in memory. A Terra worker extracted the six selected
macro definitions/absences from seven pinned libraries. The lead independently checked those
hashes and bodies, traced caller/library/compiler/helper context, and requested independent review.
No SSL expansion, Perl execution, WeiDU parsing, decompile or policy simulation was performed.

**Observations:** The following are source construction facts, not a reconstructed policy table.

## Ordered libraries: appending is not replacing

The caller builds this input-dependent sequence in `always.tph`:

1. Base library and difficulty library; then EE and EE weapon libraries, or vanilla weapons.
2. Conditional IWD-divine library entries, then optional SR, then IR or non-IR.
3. INI-selected external library overrides.
4. A later conditional `library_freeactionstun` append.
5. At the SSL invocation, the driver adds generated `autolib` after that list.

The two IWD-divine append conditions are separate; do not assume deduplication or resolve flags
from names alone. The external-library comment is not a guarantee that external input is globally
last. See [initial selection](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/lib/always.tph#L140-L186),
[external entries](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/lib/always.tph#L228-L237),
[later stun branch](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/lib/always.tph#L496-L514),
and [driver arguments](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/sfo2e/lib_ssl.tph#L84-L98).

The pinned Perl reader visits libraries in supplied order. Ordinary `TARGET` / `TRIGGER`
declarations **append** body entries; `TARGET_REPLACE` / `TRIGGER_REPLACE` clear the named body
first. Therefore SR's ordinary `SIAbjuration` declaration, containing a comment rather than a new
predicate, does not remove the earlier base predicate. SR's ordinary `AvoidDispel` declaration adds
six conditions. This is not a last-definition-wins dictionary. The reader removes `//` comments,
not C-style block comments; do not describe the latter as already stripped by this stage.
Sources: [library reader](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L129-L187),
[line normalization](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L246-L251),
[SR declarations](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library_sr.slb#L1-L46).

This inspects `ssl.pl`, not a demonstrated build of Windows `ssl.exe`. The driver normally chooses
the executable on Windows; `Use_Perl_Natively` selects Perl. Binary/source equivalence remains open.

## Bounded early-dispel macro index

The [call site](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/first_dispel.ssl#L7-L31)
uses these six names. All base anchors below refer to pinned
[library.slb](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/library.slb).

| Name | Base lines | Minimal structural finding / remaining boundary |
|---|---|---|
| `PCsInOrderShort` | 251-254 | Three target expressions: `[PC]`, second-nearest and third-nearest PC. Not fixed Player1-3 or portrait order. |
| `Enemy` | 63-65 | Distinguishes actor and target allegiance; not a complete hostility/legality contract. |
| `AvoidDispel` | 376-395 | Checks across six fixed player slots plus a dispel-delay timer; not merely a test of the selected target. SR 40-46 appends six more checks. |
| `AvoidDispellingMalison` | 410-416 | Six fixed player-slot conditions; actual absent-slot evaluation remains unproved. |
| `DispelTarget` | 427-434 | A six-way disjunction over protection categories and stoneskins; not a full immunity model. |
| `SIAbjuration` | 845-846 | Base spell-immunity-stat predicate persists under the ordinary SR declaration at 7-8. |

No declarations for those six names were found in the other five inspected variants:
`library_ee`, `library_ir`, `library_notir`, `library_freeactionstun`, `library_iwd_divine`.
This is a seven-file search boundary, not a global absence claim: weapon/difficulty libraries,
generated `autolib`, external entries and actual installed inputs were not exhaustively checked.
The inspected bodies contain raw expressions, not further named target/trigger macro calls.
No claim about real predicate outcomes, visibility, target legality or fairness follows from this index.

## Response construction is another transformation

The pinned Perl source distinguishes action-definition conditions, target/trigger expansion,
unconditional action text and `OnContinue` text. See
[collection](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L535-L553),
[Combine processing](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L675-L795),
[action expansion](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L797-L928),
and [block printing](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/ssl/ssl.pl#L946-L990).

- `Combine()` invokes shared action-definition-condition construction, reverses target candidates,
  and constructs selector blocks with `See(target)` and `False()`. Subsequent action candidates use
  `LastSeenBy(Myself)`. This describes output construction, not proof that a failing trigger changes
  target memory in the engine or selects the intended target.
- This staged output is appended to final output only if an action survives generation/pruning
  (`actionsexist`, 785-794). Do not promise unconditional emission of every selector block.
- Explicit pipe-separated action weights feed construction. Without explicit weights the source
  sets 100/0; definition expansion substitutes the first weight. The second, when nonzero, creates
  an additional response containing `OnContinue` actions and `Continue()`. `OnContinue` is not an
  unconditional after-success callback.
- For defined actions, unconditional action text is appended after the definition's action body
  (845). Textual timer placement in compact source alone cannot establish expanded action order.

The complete definition/pruning/substitution chain still needs an actual output comparison.
No expanded script was reconstructed here, no observed probability was measured, and no upstream
bug or intentional behavior change is asserted.

## CRE insertion can rearrange existing ownership

The [mage caller](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/mage_shared.tph#L28-L46)
sets `insert_script` when allocating a missing script name. Only that branch calls stripping and
low insertion after the build; an explicitly supplied script name bypasses this insertion block.
The load chain starts with SFO1 in
[always.tph](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/lib/always.tph#L7-L18),
whose [filetype loader](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/sfo/install_sfo.tpa#L403-L414)
includes the inspected CRE helper. This is not proof against every possible later helper override.

Upstream [strip_scs_scripts](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/lib/stratagems_shared.tph#L1-L32)
conditionally clears recognized upstream names across five script fields. The
[low-insertion helper](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/sfo/filetype/lib_cre.tpa#L821-L868)
searches from offset `0x268` toward `0x248` for an empty/none field. If found, it shifts intervening
entries toward the hole and writes the new script at `0x268`. If full, it checks the bottom two
script resources, can call `merge_scripts`, and writes the new lowest entry. It does not simply
fill an empty slot. The called merge implementation and resulting BCS order were not inspected.

These are descriptive upstream facts, **not** this project's removal/enrollment rules. No actor
is claimed by prefix; exact eligibility, dependency closure and legacy fallback remain mandatory.
Effective CRE fields, area overrides, subsequent patches and other controllers remain uncollected.

**Counterevidence:** The external-library comment omits later appends; an apparently blank SR
entry does not clear the base test; a short target macro is not fixed party order; low insertion
is not an empty-slot-only operation; staged compiler output can be discarded. Each prevents a
plausible but incorrect simplification. None establishes a bug in upstream runtime behavior.

**Artifacts:** Fifteen reference-only source identities and five bounded claims in the linked
record. No source payload, generated BCS, derived behavior fixture or installed resource admitted.

**Applicable evidence:** evidence:E1 for source facts. The tests below check evidence/document
contracts only, not E2 policy simulation, E3 integration, E4 engine behavior or E5 support.

**Residual uncertainty:** Actual ordered libraries/autolib/external inputs and flags, compiler
identity, final substitutions/pruning, effective actor/slots/control closure and source-to-BCS
comparison remain outstanding. The complete pilot oracle and derived-fixture admission are open.

**Next decision:** The integration lead reviews provenance-complete effective-evidence intake and
exact profile/compiler inputs before claiming a semantic oracle. Stop the affected work at missing
artifact/admission decisions. Christopher separately authorizes Task 3 with a destination before
any provisioning; neither source research nor this checkpoint authorizes installed-game access.

## Verification and delegation record

- RED: `python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_scs_shared_rule_trace.py -q --tb=short`:
  eight failures in 0.43s because the new record/memo did not exist. Assertions were not weakened.
- Focused GREEN: `python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_scs_source_checkpoint.py archive/2026-10-process/tests/schemas/test_scs_shared_rule_trace.py -q`:
  26 passed in 0.06s. Full host suite: `python -X utf8 -m pytest -q`:
  **483 passed in 65.13s**, exit 0.
- Executed the SCS-01 PowerShell recipe with the input filename substitution described above:
  all 15 hashes matched, 330,977 aggregate raw bytes read in memory. The independent reviewer
  separately matched all 15 hashes and lengths; neither retained upstream payload files.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-decisions.ps1`: passed; existing G0 status remains
  Pass with narrowed scope, not a new gate decision.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-namespace.ps1`: grammar/collision vectors passed.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/test-g0-line-endings.ps1`: LF and CRLF checkout checks passed.
- Independent review accepted the source-only checkpoint with no blocking findings and separately
  ran the 26 focused tests (0.06s). Review covered source anchors, raw identities, provenance and
  authority limits. One wording correction clarified that AvoidDispel checks across six player
  slots, not merely six total predicates; the lead applied it.
- Tool identities: Python 3.11.9, pytest 8.4.2, PowerShell 7.6.6. No SSL/Perl/WeiDU/Lua execution
  or parsing evidence is claimed. `git diff --check` passed; 25 relative Markdown links resolved.
- Staged scope audit: ten documentation/test files only; `git diff --cached --check` passed.
  Final focused rerun after verification notes: 26 passed in 0.06s. No runtime or fixture added.
- Tests bind five claims to their source-chain identities and reject reassignment of a previously
  recorded artifact. They do not independently establish the truth of the source interpretations.
- Worker: Terra, seven-file read-only extraction, approximately nine worker minutes (self-reported),
  no correction/retry. Lead independently checked all seven digests and consequential bodies;
  lead retained compiler/helper interpretation and final judgment. Exact token/cost data unavailable.
- Independent review highlighted the final output-survival guard and the conditional insertion
  branch; both were checked by the lead and included above before final validation.

Repeatable lesson: follow the complete load/merge chain and later appends, then inspect conditions
at the caller and final output boundary. A name, comment, first assignment or staged output is not
the final artifact. Keep these checks in future worker packets; do not bulk-translate similar files
until this pilot has passed its effective comparison and provenance barriers.
