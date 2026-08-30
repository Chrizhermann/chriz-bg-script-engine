# SCS AoE Prebuff Delivery — Evidence Memo

**Status:** Native Haste bridge mechanism observed in one manual disposable-engine probe;
automatic AI handoff remains unproved

**Date:** 2026-08-30

**Applicable evidence layers:** evidence:E0 claim/documentation input, evidence:E1 pinned static
evidence, evidence:E2 deterministic bridge test, and evidence:E4 disposable-engine probe

**Related design:** `docs/plans/2026-08-30-aoe-prebuff-allies-design.md`

## Question

When SCS represents a mage or priest area buff as having been cast before combat, does its
prebuff path retain the effective spell's native area delivery, or would an EEex adapter need to
enumerate nearby allies and apply the buff separately?

The material safety question is narrower than whether a spell is generally beneficial. It is
whether the concrete generated SCS action and effective prebuff resource preserve the installed
spell's recipient-selection semantics closely enough to justify a single engine cast.

## Decision relevance

The answer determines whether Combat Intent should eventually preserve an engine-authentic
historical cast or implement a new ally fan-out mechanism. A wrong choice can grant free spells,
duplicate an area effect, bypass projectiles and protections, select the wrong caster-level
ability, or affect actors that the installed spell would not reach.

This memo does not authorize runtime ownership. It records the static implementation hypothesis
and one explicitly authorized manual disposable-engine probe of the narrow bridge mechanism.

## Evidence classification

The G0 decision defines evidence layers as distinct proof environments rather than a scalar
maturity ladder. Revision-pinned upstream source, hashed generated BAF, and installed SPL/resource
inspection in this memo are evidence:E1. Unpinned action documentation and design assumptions are
evidence:E0 inputs. The focused mocked-EEex bridge test is evidence:E2. The later manual Haste
probe in an isolated full game is evidence:E4. No evidence:E3 synthetic-game integration or
evidence:E5 supported-corpus soak is claimed.

## Environment

Read-only installed-stack inspection:

- Game: BG2:EE `2.6.6.0`
- `Baldur.exe` SHA-256:
  `FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580`
- EET: `v14.0`
- EEex: `v0.11.0-alpha`, including its LuaJIT component
- WeiDU: `24600`
- Spell Revisions: `v4.19`
- SCS: `v35.21`; component 5900 “Initialise AI components”, followed in `WeiDU.log` by
  component 6030 “Smarter Mages” and component 6040 “Smarter Priests”
- `WeiDU.log` SHA-256:
  `AC8F36CD73A444BE0311F4979D343AB9BBED589B80A1203C785BA310469EA75F`

Upstream comparison:

- SCS release tag: `v35.21`
- Pinned tag commit: `5dc240e9ff85d3909b6436e54b56297d3b61e33b`
- Relevant upstream files:
  [`caster_definitions.ssl`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/v35.21/stratagems/caster_shared/caster_definitions.ssl)
  and
  [`lib_spl.tpa`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/v35.21/stratagems/sfo/filetype/lib_spl.tpa)
- Action reference:
  [IESDP BG(2)EE actions](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm)

During the static inspection phase, no game process was launched and no action was queued. No save,
CRE assignment, or effective BCS was inspected. No installed game artifact was copied into the
repository.

Authorized disposable-engine probe:

- Disposable game: a temporary copy of the inspected BG2:EE/EET installation with a unique
  `engine_name` and isolated user profile
- Bridge commit: `bdfe096`
- Installed bridge SHA-256:
  `9858914FA3380AAABD251690D75420A8CFC576DAF12094FCBFE285C25F7B084C`
- Haste prebuff clone: `dwsw305.spl`, SHA-256
  `E04AAAE94B1D34ADCC385CFC79B8776F1FB1C490E681CA269365EC03988E0F20`
- Delivery/accounting pair: `dwsw305` plus numeric spell ID `2305` (`WIZARD_HASTE`)
- Invocation: manual EEex Remote Console call on a selected party mage; not an assigned AI actor
- Retention: results recorded here; disposable game/profile removed after verification

Relevant local source/artifact fingerprints:

| Artifact | SHA-256 |
|---|---|
| `setup-stratagems.tp2` | `5C3E77B2D91B1BFF13271B23851B6AC5BA5856D7F845D7773A195A332DF7B2FB` |
| `caster_shared/caster_definitions.ssl` | `825F0D0000101ACC375C5C3D4D43EE5CF7656BBAC80D825D4932231EE5255440` |
| `sfo/filetype/lib_spl.tpa` | `409CB654A2CE02CCA6EDF9A1B81D4ABA7B09B3D5EC8AF751EAADB0C197B24934` |
| `caster_shared/prebuff.2da` | `1488B1B669ED30AC0C5FED07719D67471EA20A9C053183C8DA8726FC96B0DD55` |
| `instant_prebuff_spells.2da` | `3FB7654BCF68B567458132B60A9159413BE98BB1576B6803B84F0ED4044999F4` |
| intermediate `dw#fgmag.baf` | `A822AED11928CABE1612ADBD18B77E4755A9BE6A19A0CA083F413720A16820F6` |
| generated `dw#mg149.baf` | `F5D739AF0E6EA603A065D5F26294BDC243641902649ED9E9D8C42EC9D8895730` |

The installed TP2 declares SCS 35.21. This memo does not claim that the installed mod directory or
archive is byte-identical to the pinned release commit.

Attribution and retention policy:

- SCS and the inspected prebuff source/generated family are by DavidW; upstream ownership and
  licensing remain authoritative.
- Spell Revisions is by Demivrgvs/Gibberlings Three and shapes effective resources on this stack.
- Installed SCS source, generated BAF, SPL, IDS/2DA, game resources, and paths are local-only,
  reference-only evidence. No redistribution authorization is inferred, and none of those
  artifacts is committed.
- This memo contains independently written observations, minimal action/resource identifiers,
  hashes, and structural metadata only.

## Method

1. Inspect SCS's generic `SpellPrecast` and `SpellPrecastLong` action definitions.
2. Inspect the prebuff-resource builder and identify which fields it deliberately changes.
3. Inspect the installed prebuff mapping and representative generated BAF output.
4. Parse representative installed original/prebuff SPL pairs without modifying them.
5. Compare the action with documented `ReallyForceSpellRES` and `ApplySpellRES` behavior.
6. Search generated BAF output for concrete invocations rather than inferring behavior from spell
   names or `prebuff.2da` membership.
7. Install a temporary component that copies the committed bridge byte-for-byte into the isolated
   game; verify its hash and WeiDU component record.
8. Record selected-caster `SPWI305` availability and party `DWSW305`-sourced timed-effect counts.
9. Queue the bridge response, wait for engine ticks, and independently inspect slot and effect
   postconditions rather than treating `QUEUED_ONLY` as completion.
10. Repeat once to distinguish one-spell accounting from recipient count and record the rejected
    no-slot preflight separately.

The SPL parser was a read-only PowerShell 7.6.5 script using little-endian
`System.BitConverter`. It read the SPL V1 ability table offset at `0x64`, ability count at `0x68`,
40-byte ability records, target at ability `+0x0c`, minimum caster level at `+0x10`, casting time at
`+0x12`, effect count/index at `+0x1e/+0x20`, and the raw projectile field at `+0x26`.

## Reproduction commands

Set `$game` to the read-only root of the inspected installation. These commands must not target an
active/disposable write environment unless that environment was separately authorized.

Version and component evidence:

```powershell
Select-String -LiteralPath "$game\stratagems\setup-stratagems.tp2" -Pattern '^VERSION'
Select-String -LiteralPath "$game\WeiDU.log" -Pattern 'STRATAGEMS.*#0 #(5900|6030|6040)'
& "$game\weidu.exe" --version
```

Hashes:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath <absolute-read-only-artifact-path>
```

Generated-BAF corpus search:

```powershell
$baf = "$game\weidu_external\workspace\ssl_out"
(Get-ChildItem -LiteralPath $baf -File -Filter '*.baf').Count
rg -l --glob '*.baf' 'ReallyForceSpellRES\("dwsw613"' $baf
rg -l --glob '*.baf' 'ReallyForceSpellRES\("dwsw305"' $baf
rg -l --glob '*.baf' 'ReallyForceSpellRES\("dwsp101"' $baf
rg -l --glob '*.baf' 'ReallyForceSpellRES\("dwsp406"' $baf
rg -l --glob '*.baf' 'ReallyForceSpellRES\("dwsp108"' $baf
```

SPL shape extraction used this little-endian core for every original/clone pair:

```powershell
$bytes = [IO.File]::ReadAllBytes($path)
$abilityOffset = [BitConverter]::ToUInt32($bytes, 0x64)
$abilityCount = [BitConverter]::ToUInt16($bytes, 0x68)
for ($i = 0; $i -lt $abilityCount; $i++) {
    $offset = $abilityOffset + (0x28 * $i)
    [pscustomobject]@{
        target = $bytes[$offset + 0x0c]
        minCasterLevel = [BitConverter]::ToUInt16($bytes, $offset + 0x10)
        castingTime = [BitConverter]::ToUInt16($bytes, $offset + 0x12)
        effectCount = [BitConverter]::ToUInt16($bytes, $offset + 0x1e)
        firstEffect = [BitConverter]::ToUInt16($bytes, $offset + 0x20)
        projectileRaw = [BitConverter]::ToUInt16($bytes, $offset + 0x26)
    }
}
```

The full command output was not committed because it contains local paths and metadata for
reference-only installed artifacts. The hashes and decision-relevant structural values are
reproduced below.

## Observations

### O1 — SCS source and sampled generated BAF express a cast-plus-debit sequence

**Evidence:** evidence:E1 pinned source and generated BAF

SCS `SpellPrecast` and `SpellPrecastLong` expand to a response that force-casts the generated
prebuff resource on `Myself`, removes the original memorized spell, and then continues script
evaluation.

The trigger requires the original spell to be memorized, gates short versus long preparation
differently, and rejects a really-dead caster. The forced cast does not itself consume the
memorized spell, which explains the following `RemoveSpell` action.

One fully substituted generated mage BAF on this stack contains that sequence with install-local
resource `dwsw613` and the logical `WIZARD_IMPROVED_HASTE` accounting spell. No compiled effective
BCS, CRE assignment, script slot, or runtime eligibility was inspected, so this is a generated
action candidate rather than observed actor behavior.

The generated `dw#*` name is install-specific and is evidence, not a stable adapter identifier.

### O2 — The prebuff builder clones the effective installed SPL

**Evidence:** evidence:E1 pinned source and installed clone shape

`build_prebuff_spell` uses `COPY_EXISTING` on the current effective spell. In the inspected generic
branch it
renames the spell and removes opcodes 139, 174, 141, 215, and 50, which SCS uses here as selected
presentation effects. No explicit writes to ability target, level selection, projectile, save/MR
flags, timing, or child-spell fields were observed in that branch. Alternate builder branches and
helper behavior remain outside this observation.

This means the prebuff resource is not a generic self-applied buff wrapper. It retains the
installed spell's ability/projectile delivery structure, whose runtime behavior remains to be
proved.

### O3 — Representative installed clones retain ability target and projectile

**Evidence:** evidence:E1

The following values were read from installed SPL ability headers. `projectile` is the raw SPL
field. Effective `PROJECTL.IDS`, PRO, and secondary-projectile closure were not inspected, so the
table intentionally does not assign a projectile identity or geometry.

| Spell | Resource | Abilities | Target | Projectile | Result |
|---|---|---:|---:|---:|---|
| Improved Haste original | `spwi613` | 1 | 4 | 158 | Concrete generated-action accounting resource |
| Improved Haste prebuff | `dwsw613` | 1 | 4 | 158 | Concrete generated-action clone; target/projectile fields retained |
| Haste original | `spwi305` | 15 | 4 | 158 | Baseline |
| Haste prebuff | `dwsw305` | 15 | 4 | 158 | Target/projectile field retained in every level header |
| Bless original | `sppr101` | 1 | 4 | 162 | Baseline |
| Bless prebuff | `dwsp101` | 1 | 4 | 162 | Target/projectile field retained |
| Defensive Harmony original | `sppr406` | 1 | 5 | 501 | Baseline |
| Defensive Harmony prebuff | `dwsp406` | 1 | 5 | 501 | Target/projectile field retained |

The clone has fewer effect records because the builder removes selected cosmetic effects. Static
field equality does not prove which actors receive effects at runtime.

Representative hashes:

- Improved Haste original `spwi613.spl`:
  `AAC408F7A60E6F7EBE032BDCD37E87605FE455AA87888C42132E45D256A3C013`
- Improved Haste prebuff `dwsw613.spl`:
  `DB93418B366CEDB8ED0AFAC7B500939A8E333589689F0A8D073CC614744FD701`
- Haste original `spwi305.spl`:
  `52FA6B22207FAB2427EFFB7AEF29593F189289638CFF53DC9CB1835F83FDCB7D`
- Haste prebuff `dwsw305.spl`:
  `E04AAAE94B1D34ADCC385CFC79B8776F1FB1C490E681CA269365EC03988E0F20`
- Bless prebuff `dwsp101.spl`:
  `55C10637C73F790362D74BDD60F50C12CA67DA19F16CAC119DCA1D62867156C1`
- Bless original `sppr101.spl`:
  `93A49DE219D138015677111C8E0600182C0EC75DEE829F25B5F450ABF87C69E9`
- Defensive Harmony prebuff `dwsp406.spl`:
  `52FDC299ACDB8A399E29D3EB77569DFC9904D190C829BF0A77F6EB1DD07FAE9F`
- Defensive Harmony original `sppr406.spl`:
  `46652C693637E036A709F77AD1D69A4D55DFA1C124368BB87326A7789C0E4145`

### O4 — The installed mapping includes representative group-buff candidates

**Evidence:** evidence:E1

As install-local metadata, `instant_prebuff_spells.2da` maps the wizard and cleric Haste logical
prebuffs to `dwsw305`, Improved Haste to `dwsw613`, Remove Fear to `dwsp108`, Defensive Harmony to
`dwsp406`, and Bless to `dwsp101`. These facts are recorded rather than copying the generated
artifact.

The mapping file SHA-256 is
`3FB7654BCF68B567458132B60A9159413BE98BB1576B6803B84F0ED4044999F4`.

Mapping presence proves only that a clone was built. It does not prove that a generated creature
script actually invokes that clone.

### O5 — The bounded generated-BAF corpus differs from source/list membership

**Evidence:** evidence:E1

The searched corpus was all 276 `.baf` files directly under the inspected
`weidu_external/workspace/ssl_out` directory. Mage prep source requests Haste and Improved Haste.
Three fully substituted generated BAF files in that corpus contain the `dwsw613` Improved Haste
prebuff action:

- `dw#mg113.baf`:
  `BC2B48E759014572E9FD5C0BC19065F809BD639A2F53C9AA85FE79FE5A3C118D`
- `dw#mg149.baf`:
  `F5D739AF0E6EA603A065D5F26294BDC243641902649ED9E9D8C42EC9D8895730`
- `dw#mg185.baf`:
  `F16494624052067398E7F23481B27E48AFEC623264B2CC7E36458F448735C268`

A fighter/mage intermediate BAF contains the Haste eligibility/action shape but retains symbolic
substitutions.

The exact negative-control searches in the reproduction section found zero literal forced casts of
`dwsw305`, `dwsp101`, `dwsp406`, or `dwsp108` in that bounded corpus. Those spells have mapping
rows, but Bless and Defensive Harmony also appear in priest combat group-buffing source. Priest
source requests Protection from Evil 10' as a prebuff, yet the inspected mapping file contains no
corresponding generated mapping.

The sampled generated corpus therefore does not establish concrete Haste, Bless, Defensive
Harmony, or Remove Fear prebuff actors. It does establish that spell names, prep source, and
`prebuff.2da` membership are insufficient enrollment evidence; effective BCS and CRE assignment
must still be traced.

### O6 — `ApplySpellRES` is not an equivalent fallback

**Evidence:** evidence:E0 documentation input

IESDP documents `ReallyForceSpellRES` as an instant, casting-time-zero, uninterruptible cast. It
still casts the spell through the engine. IESDP documents `ApplySpellRES` as ignoring the spell's
projectile, substituting projectile 1/None, and selecting the lowest casting-level ability.

A distance scan followed by one `ApplySpellRES` per actor would directly change projectile
delivery and caster-level ability selection. It also creates unproved preservation risks for:

- child-spell and casting-feature context;
- probability-roll granularity;
- source and protection behavior;
- the definition of ally for charms, summons, neutrals, and clones.

Manual EEex effect injection would require reimplementing still more of SPL/projectile resolution.

### O7 — The manual Haste bridge probe delivered to an ally and spent once per cast

**Evidence:** evidence:E2 focused bridge test plus evidence:E4 disposable-engine observation

The selected caster began with two available `SPWI305` memorisations. The first successful bridge
response reduced the count to one and left ten `DWSW305`-sourced timed effects on the caster. A
subsequent invocation returned the no-available-copy preflight error; the next successful caster
invocation still reported one copy before dispatch. That second successful response reduced the
count from one to zero; post-tick inspection showed twenty `DWSW305`-sourced effects on the caster
and ten on the ally. The user independently observed both characters under Haste.

This establishes, for this exact installed clone and stack, that one native cast can select an
ally and that the adjacent accounting action spends one prepared Haste per successful response,
not one per recipient. It does not establish an exact radius, hostile/neutral/summon behavior,
cleric families, automatic SCS actor eligibility, or interruption outcomes.

`EEex_Sprite_GetSpellState(sprite, 1)` remained false for both actors despite visible Haste and the
source-matched timed effects. A hard-coded vanilla Haste state probe is therefore not an
authoritative positive or negative for this effective SCS/SR prebuff clone.

## Artifacts

| Artifact class | Location/retention | Use |
|---|---|---|
| This memo and approved design | Repository | Independently written evidence metadata and decision record |
| SCS source and generated workspace | Local read-only installation; not committed | Source/generation inspection only |
| Effective original/prebuff SPL files | Local read-only installation; not committed | Header-shape and hash comparison only |
| Full command output | Ephemeral terminal output; not committed | Reproduced into decision-relevant metadata above |
| Bridge helper and focused unit test | Repository | Authored two-action response and deterministic queue-shape proof |
| Temporary WeiDU harness and isolated save | Disposable game/profile; removed after capture | Manual E4 invocation and observation only |
| Effective BCS, CRE assignments, PRO closure, saves | Not inspected | Explicit future evidence gap |

## Residual uncertainty and counterevidence

- No automatically assigned AI actor executed a generated SCS prebuff; the E4 probe manually
  invoked the bridge on a selected party mage.
- The effective projectile resources and any secondary projectiles were not recursively inspected.
- No effective generated BCS or CRE script-slot assignment was inspected.
- The probe did not establish a radius boundary, hostile/neutral/summon selection, protection
  behavior, caster-level selection across headers, or probability granularity.
- Deleting the selected opcodes may remove substantive behavior if another mod repurposes one of
  them; each supported effective spell still needs dependency-closure inspection.
- `ReallyForceSpellRES` plus `RemoveSpell` is a non-atomic two-action sequence. The successful path
  was observed, but queue clearing, death, area transition, and save/load were not tested.
- The inspected stack is one SCS 35.21 + SR 4.19 + EET 14.0 installation. Generated resources are
  install-specific and cannot be generalized to unknown stacks.
- Source-level requests can disappear during generation, as the Protection from Evil 10' example
  may indicate; its full generation path was not traced, so no cause is assigned.

## Conclusion

**Mechanism outcome:** Proven for the exact manual Haste bridge probe

**Runtime ally-delivery outcome:** Observed for one ally on the tested stack

**Automatic AI handoff outcome:** Unproved

The evidence supports one native historical cast rather than actor-wide aura-cleansing state or a
per-ally application mechanism. In the completed Haste probe, the installed clone selected the ally
and the adjacent action spent one original memorisation per successful cast. This is sufficient to
retain the bridge helper for the future SCS migration handoff.

The result does not make the current library a gameplay component: no production bootstrap loads
it and no AI prebuff path calls it. Packaging and activation remain deferred until the main SCS
migration reaches that handoff.

## Next decision and minimum runtime proof

The completed manual probe removes any need to invent generic ally fan-out. Before an adapter claims
an actual AI decision, the remaining baseline work is still to test unmodified SCS actor behavior:

1. Resolve the exact effective projectile/PRO closure and use actors at controlled distances before
   labeling any position inside, at, or outside a radius.
2. Trace one `dwsw613` generated action through compiled BCS and an assigned disposable actor.
3. Place the caster, prospective eligible actors at controlled distances, a hostile, a summon,
   and a protected/already-buffed actor in a controlled arena.
4. Trigger that exact Improved Haste historical-prebuff candidate.
5. Wait for engine progress; do not equate queue acceptance with execution.
6. Verify effect recipients, source resrefs/caster identity, selected level header, and exactly one
   original spell debit.
7. Repeat queue clearing, caster death/despawn, Project Image owner lock, save/load, and area
   transition cases.
8. Test Haste, Bless, and Defensive Harmony resource shapes only after locating concrete generated
   and assigned actions, or label them explicitly as resource-shape probes rather than actor
   behavior.
9. Repeat representative vanilla, SR, and SCS+SR effective spell shapes.

If the unmodified SCS baseline passes, the implementation requirement becomes a preservation and
acceptance invariant, not a new delivery feature. If it fails, diagnose the concrete generated
action, projectile closure, and eligibility timing before designing a spell-specific exception.
