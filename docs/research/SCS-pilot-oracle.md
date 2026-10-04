# Bounded mage/prebuff pilot oracle

**Status:** Integration-owner-admitted authored factual comparison and SCS-derived synthetic expectations.
This is a small Task 6 pilot oracle, not the SCS corpus oracle, an adapter,
or runtime acceptance. The companion
[`scs-pilot.synthetic.json`](../../tests/fixtures/manifests/scs-pilot.synthetic.json) contains
authored metadata and six source-derived synthetic cases, no copied SSL, BAF, spell payload or
bulk tactical table. Repository admission does not authorize external publication.

**Question:** Which selected source distinctions survive in installed mage output, and what can
be checked without enrolling an actor? The answer is limited to MAGE6B's generic Shield/Mirror
Image prep and MAGE18B's ordinary Glitterdust block. SCS v35.21 is pinned to commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`; the copied lab uses BG2:EE 2.7.3.0,
EET 14.0, EEex 1.2.0/LuaJIT, SCS 35.21, Spell Revisions 4.21-chriz.5 and WeiDU 24900.
The copied `WeiDU.log` digest is
`4FD4AB5491533C17E5E8DE26E4DCE84A761A34EF79A998B06007234080B89FE6`.
No game or installer was run for this artifact.

## Selected E1 comparison

| Selection | Pinned source | Effective observation | Boundary |
|---|---|---|---|
| Mirror Image generic short prep | [`caster_definitions.ssl:470-486`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L470-L486) | MAGE6B private BAF 381-409: `HaveSpell`, `instantprep=0`, sight or `offscreenprep=1`, alive, `DMWW_mage_prep_difficulty` and slider clauses. Weight 100 requests DWSW212 on self, one original Mirror Image removal and continuation, in that order. | Generic block does not write `instantprep`. |
| Shield generic long prep | [same source:488-514](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L488-L514) | MAGE6B BAF 411-447: `HaveSpell`, `instantprep=0`, detection/offscreen/player-within-20 gate **and** detection/offscreen/enemy gate, alive, `DMWW_mage_difficulty` and slider clauses. Weight 100 requests DWSW114 on self, one original Shield removal and continuation, in that order. | Long differs in perception and setting, not merely duration. |
| Ordinary Glitterdust | [`glitterdust.ssl:1-10`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/ssl/combatblocks/glitterdust.ssl#L1-L10), [`SpellArea:798-813`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/caster_shared/caster_definitions.ssl#L798-L813) | MAGE18B BAF 12556-12681 ends with the last-seen target block: availability/timer, visibility, disabling, Minor Globe, resistance/target-compromise, save, allegiance and invisibility-state guards. Weight 100 applies `DW#MGSEE`, sets cast timer and requests a normal Spell on LastSeenBy; weight 50 only continues. | Another actor; does not validate MAGE6B Glitterdust or area recipient geometry. |

The source's `DoNotPrebuff` test is a generation-time SSL boolean. The selected MAGE6B effective
blocks contain the emitted difficulty and local-state predicates, not a live `DoNotPrebuff`
trigger. The blocks continue without setting `instantprep`; MAGE6B BAF 465-533 later contains
distinct first-round cast/set and no-cast/set branches, and BAF 159-171 clears the state on a
rest-reset branch. The comparison must keep these events separate. [The installed comparison](2026-09-27-scs-effective-mage-pilot.md#helper-payload-and-preparation-state-continuation)
records DWSW212/DWSW114 helper effect slices and one original memorized copy of each in the
final CRE. Both helpers have 300-second timed effects, so no live duration difference is claimed.

The final MAGE6B CRE's ten known and eleven memorized spell records contain neither Magic
Missile (`SPWI112`), Glitterdust (`SPWI224`) nor Slow (`SPWI312`). Its decompile has no cast
block for these three. [COMBAT-01](COMBAT-01-candidate-inputs.md#verified-inputs) pins their
installed resources and correct PROJECTL resolution, but does not establish complete geometry,
recipient or engine legality. An integrated three-spell mage is therefore an independently
authored fixture, not a claim that MAGE6B executes those source call sites.

## How to use the six cases

The fixture's sight-only and detection-only cases distinguish short from long eligibility. Two
cases use emitted setting values 5/2 and 2/3 to show that the prep and general mage settings
are separate. One case expects both generic blocks in effective order, each requesting helper
delivery, one original removal and `Continue`, while leaving `instantprep` at zero. The final case records
the later first-round set and rest reset as separate selected branches. These are authored
host-test expectations derived from selected E1 predicates; they have not been run in the
engine. The synthetic inputs assume their named selector and timer conditions; they are not a
complete reconstruction of every SCS macro or game world state.

**Identities and reproduction:** [The MAGE6B comparison](2026-09-27-scs-effective-mage-pilot.md#reproduction-and-identities)
pins final CRE `307409E704DF61DAFC604FFAC04ABC99951A2849CF96AD7596C354BA81E722F4`,
effective BCS `4D56E24F957C2B83DFC5B63D485AF3F70AC8C93AC578012C120A41E6227F6F7D`,
private decompile `5FE9A10D0955A15845D15B561F6B03459DE3FDA193D03A7718346A6C6182B703`,
and the helper/original SPL hashes. [The MAGE18B comparison](2026-09-28-scs-high-mage-dispel.md#reproduction-artifacts-and-review)
pins effective BCS `2E7CF46847CFC0704DB7789D45BE9D4864B7F3748E8B8296B226E5C6F883388D`
and private decompile `99491588A4F702BFAF665E0C9670CE32EA7C6FE58B928827FD80D8DB034917C1`.
[The source manifest](scs-source-pilot.evidence.json) holds the pinned identities; the
private WeiDU249 decompiles remain under `.work/task6`, outside this fixture. No upstream
payload is copied into these artifacts.

**Counterevidence and residual uncertainty:** MAGE6B does not contain the three offensive
spells. MAGE18B's selected Glitterdust block does not prove any cast landed, which response
was chosen, all affected recipients, or why other source alternatives were pruned. Neither
actor establishes external `offscreenprep` writers, area/controller overrides, full generation
inputs, transitive spell/projectile ownership, actual helper expenditure, buff lifetime, or
save/load behavior. All actors remain legacy-owned; no activation claim follows.

**Provenance and next decision:** The six case expectations derive from selected pinned SCS
source and effective output, while their wording and compact representation were authored here.
Credit Sword Coast Stratagems (David Wallace/DavidW) and Spell Revisions (Demivrgvs/G3) for the
relevant stack. The pinned SCS readme copyright statement permits code reuse with full credit
and asks that SCS or a modified SCS not be mirrored. The integration-owner review on 2026-10-04
checked the selected emitted blocks, source pins, classification and exact fixture allowlist
entry. This repository fixture contains no source, generated resource bytes or bulk tactical
table. The validator checks byte identity and admission metadata, not source-truth or engine
behavior. Wider SCS migration and engine proof remain separate work; external publication
remains unauthorized.

The new shadow preparation reducer implements only these two gate shapes, with explicit
adapter-resolved configuration and accounting readiness. It neither forces a helper nor
spends a copy. It adds conservative unknown-buff/already-present exclusions and currently
requires combat ownership (neutral preparation is not admitted). Those are pilot limitations,
not assertions that SCS itself has the same exclusions. Difficulty booleans must be resolved
from the selected emitted predicates; no live `DoNotPrebuff` variable is invented.
