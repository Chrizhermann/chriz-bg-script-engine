# Priest Turn Undead: second-family shadow ledger

Updated2026-10-12; integration owner. **Bounded Task29 authored comparison**, no
active priest adapter or G6 admission. Origin: SCS-derived authored rule reduction.

## Source and effective identity

Sword Coast Stratagems35.21, David Wallace (DavidW), Smarter Priests6040.
[Pinned source](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/priest/ssl/main/dw%23priest.ssl):
revision `5dc240e9ff85d3909b6436e54b56297d3b61e33b`, upstream SHA256
`B4FFB617B9F2755CA7FF82979BBD0B48D282AD2E10D13BF728BCFA4689D761A1`.
Copied-lab source raw SHA `D96A4DD6CE57EF038A8D504BBB6573F92E74833F7D5914E48C9DADF5FB4ADF48`
matches after CRLF normalization. Use downloaded raw-file lines57–81, not a browser's
blank-line-normalized line count. Generation-time IsDruid exclusion is not an emitted
runtime predicate in this cleric sample.

The retained installer log links A#AMNP.CRE to dw#pr0.bcs. CRE SHA
`A1A193597736825CB41B68B6E86E5250EA89F17331012D7CA9A12758B40BFFC1`;
BCS SHA `BB7F1B25AE477559857ACBC1C8EBC54820285B1FAACE7E698690E18813CF3324`.
Current class is cleric; default script dw#pr0, general A#AMNG, allegiance128.
These are concrete provenance observations, never prefix-based enrollment.

WeiDU24900 offline `--nogame --search-ids` decompilation produced the selected
matching blocks397–419, but also179 missing archived-ID diagnostics (ASTYLES7,
HAND172). The full-script decompile is **not diagnostic-clean**. A separate fresh
recompile exited0 without ERROR/WARNING and reproduced the original BCS byte-for-byte.
The selected Turn block uses none of those missing label tables. No game/profile
was written. Full private commands, output, identities and unresolved diagnostics
remain in `.work/task29/turn-source-v1/roundtrip-receipt.private.json`.

## Bounded rules and differences

This family was selected because a maintained non-spell action, coupled target
selection and local timers exercise different machinery from mage preparation.
It is not a claim to reproduce the priest's whole combat policy.

- Preserve the coupled undead-sight/LastSeenBy disabled check and cast-timer gate.
  GOODCUTOFF is the source allegiance selector, not a moral-alignment inference.
- Preserve initiation's ordered timer arguments30 and4 followed by Continue;
  GTIMES resolves FIVE_ROUNDS to30. A request is not an executed timer write.
- Preserve the later Turn branch's initiation/active-window condition.
- The shadow reducer deliberately returns the first matching branch only. After an
  initialization proposal it requires a fresh observation; unlike actual SCS Continue,
  it does not execute writes and continue within the same script pass. This is a
  conservative shadow boundary, **not an approved gameplay scheduling change**.
- Shared project eligibility/ownership checks are extra observation-admission gates,
  not newly discovered SCS predicates. No tactical weight or difficulty default changes.

Counterevidence: effective blocks180–185 retain non-ENEMY NoAction before Turn.
A#AMNP's current allegiance128 therefore does not establish reachable Turn behavior.
The A#AMNG controller, encounter/hostility changes, later patches and full external
closure remain untraced. The installed actor stays legacy-owned and unadmitted.
Missing generated melee include in the copied source also prevents a whole-template
source-closure claim. Other priest spells, shapeshifting, movement and exceptions
remain in intended scope, not omitted rules.

## Artifact review and distribution decision

Independent review checked the pin/roundtrip and corrected generation-vs-runtime,
coupled-target and Continue-boundary wording. Integration-owner admission is limited
to the newly authored `adapters/scs/priest_turn_shadow.lua` reducer and compact
source-derived tests under `tests/scenarios/combat/priest-turn`, with their unit
driver. The source's existing credited-reuse/no-mirror statement was rechecked at
the pinned revision. No source text, BCS, game resource, bulk policy table or upstream
asset is included. This is an artifact-specific private-repository decision under
the existing register, not legal advice, a blanket upstream permission or publication.
Credit SCS/DavidW; Spell Revisions/Demivrgvs/G3 identifies the inspected stack, not
authorship of these generic priest rules. No author contact or public sharing.

## Evidence and remaining work

Source/effective identity and roundtrip are E1. Host reducer/eligibility/replay checks
are E2: missing-module RED2 then GREEN2 on Lua5.1/LuaJIT; independent review's missing
family binding was reproduced RED2 and corrected GREEN2. Both the manifest ID and
exact authored B-XPRST0.CRE root are required; an otherwise valid unrelated manifest
or actor is refused. These are invented host resource identities/hashes, not game bytes.
The [results checkpoint](../../research/priest-turn-shadow-results.md) records
commands, coverage and remaining observation work. The2026-10-12 exact authored
fixture now has bounded E4 evidence: two continuous90second intervals, twelve native
Turn starts each, timer windows/cooldowns and later target displacement. The refined
passive reader records the sole target's selected-marker match without executing See.
First-selection timing and native predicate boundary equivalence remain unknown;
runtime callback cost was not measured. No full installed-actor claim follows.
Fixture CRE/BCS hashes, instrumentation differences and cleanup are in the results
memo and private packet. Native Turn dispatch remains out of scope.
