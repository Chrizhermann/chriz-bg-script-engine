# SCS mage/prebuff pilot: generation pipeline

**Outcome:** Conditional; Task 6 source-only checkpoint, 2026-09-22. Task 6 remains in progress.

**Question:** Can the pilot be identified by generator inputs rather than generated resource names?

**Environment:** env:host, game-state access none. No installer, game, or lab execution.

**Versions and fingerprints:** SCS v35.21, commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`; raw-file SHA-256 and byte counts in
[the evidence record](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json). This pin is a research reference, not a newly
chosen lab version or proof that any installed copy matches it.

**Method:** Trace selected source callers and includes, hash raw HTTPS bytes in memory, then
independently check extraction. Reproduction below; workflow/review in
[the checkpoint report](../../archive/2026-10-process/docs/research/2026-09-22-task6-source-checkpoint.md).

**Observations:** Source stages inspected:

| Stage | Pinned artifact ID suffix and lines | Meaning and boundary |
|---|---|---|
| Component selection | `tp2`, 1013-1018, 1057-1060 | 6030 invokes mage; 5900 is the prerequisite. Not a complete install recipe. |
| Input loading / edits | `mage-entry`, 13-108, 148-227 | Spell tables, overrides and difficulty inputs precede generation; creature selection and before/after/crosspatch work matter. |
| Per-creature generation | `mage-shared`, 28-46 | Type/level/spell allocation, name allocation, build, old-script stripping and low insertion are distinct operations. |
| Pilot branch | `mage-shared`, 384-394, 472-492 | Select the enchanter-to-standard-mage branch with the input constraints below, not an installed actor. |
| Compilation inputs | `mage-shared`, 313-367 | Spells, kit/race, contingencies, sequencers, per-creature booleans/variables, SR substitutions and Alacrity/Wish branch affect output. |
| SSL / BAF / BCS | `ssl-driver`, 19-101, 120-157, 178-218 | SSL expansion, conditional-line handling, engine/hotkey substitutions, variable evaluation and difficulty processing precede final BCS compilation. |
| Resource naming | `caster-shared`, 1043-1065 | Generator searches for an unused name. Generated `dw#mg...` spelling is not stable family identity. |

Freeze the main-template selection inputs as `kit=enchanter`, `detect_invisible=0`, `race=HUMAN`.
The initial kit branch alone is insufficient: `mage-shared` 472-492 subsequently substitutes
`dw#mgin` for invisibility detection and `dw#lich` for lich/skeleton/demilich races. Under the frozen
selection inputs, the source path uses `dw#mage.ssl` with `ssl_mage_type=standard_mage`, not just the
small combat include list. These constraints identify the template lane, not a complete generated
instance: level, spell allocation, settings and overrides remain inputs to collect.
A source call to low insertion does **not** establish an effective slot index.
The [shared-rule continuation](SCS-shared-rule-expansion.md) traces the conditional insertion call,
slot shifts and possible merge invocation; actual merged output, original slots, area actor
overrides, later patches and external controllers remain uncollected.
Allocation inputs must include the exact spell/defensive tables, kit, level,
mod libraries, INI/settings, per-creature overrides and any install-time random selections.

**Counterevidence:** The Alacrity/Wish path compiles through an additional BAF rewrite, and the
entry point performs later edits/crosspatching. A single SSL file or generated name cannot specify
the effective creature. No generated BCS comparison was performed.

**Artifacts:** `artifact:scs3521-tp2`, `mage-entry`, `mage-shared`, `caster-shared`, `ssl-driver`
(latter names abbreviate the same ID prefix); see [manifest](../../archive/2026-10-process/docs/research/scs-source-pilot.evidence.json).
For example, [the per-creature generator](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/mage/mage_shared.tph#L28-L46).

**Applicable evidence:** evidence:E1 for the pinned source statements only. Offline documentation
checks are not compiler, installer, semantic-oracle, or engine proof.

**Residual uncertainty:** Selected macro/compiler/helper source paths are now traced in the
continuation, not fully executed. Actual macro expansion, effective slot/control closure,
representative actor, generated resources and comparison remain open. Task 5's synthetic inventory
cannot supply them.

**Next decision:** Integration owner completes the source trace and reviews the effective-evidence
packet below; no adapter activates, and no Task 3 authorization is inferred.

## Reproduce source identities

From the repository root, this reads public source into memory and prints only digest/length results.
It does not execute upstream code or save its bytes. URL-encoding `#` in filenames is essential.
Line references count LF boundaries, starting at one; a terminal newline is not an additional
physical line. Do not normalize CRLF/LF before hashing.

```powershell
$scsRecord = Get-Content archive/2026-10-process/docs/research/scs-source-pilot.evidence.json -Raw | ConvertFrom-Json
$scsClient = [Net.WebClient]::new()
try {
    foreach ($scsArtifact in $scsRecord.artifacts) {
        $scsRawUrl = $scsArtifact.sourcePath.Replace(
            'https://github.com/Gibberlings3/SwordCoastStratagems/blob/',
            'https://raw.githubusercontent.com/Gibberlings3/SwordCoastStratagems/')
        $scsBytes = $scsClient.DownloadData($scsRawUrl)
        $scsHasher = [Security.Cryptography.SHA256]::Create()
        try {
            $scsDigest = [BitConverter]::ToString($scsHasher.ComputeHash($scsBytes)).Replace('-', '')
        } finally { $scsHasher.Dispose() }
        if ($scsDigest -cne $scsArtifact.digest.value) { throw "Source mismatch: $($scsArtifact.id)" }
        [pscustomobject]@{ id=$scsArtifact.id; bytes=$scsBytes.Length; sha256=$scsDigest }
    }
} finally { $scsClient.Dispose() }
```

Inspect selected lines without persisting payload: decode that file's byte array as UTF-8, split on
LF, and print only the required numbered interval. Cross-check claims against context, not keyword
hits alone. The JSON's digest represents the whole raw file; it does not imply every line was
semantically analyzed.

## Effective-evidence packet still required

Record exact game/campaign builds and final mod order; SCS archive/commit/component/settings;
WeiDU/SSL identities; actual allocation/override/library inputs; creature and all effective slots;
area/controller/global/dialogue dependencies; resource digests and transformations. Compare expanded
BAF/decompiled BCS priority, predicates, response weights, `Continue()`, spell accounting and special
handoffs against source. Keep actual payloads/decompiles and private paths outside Git, using stable
artifact IDs in reports. Record disagreement rather than altering the oracle to fit.

Task 3 remains separately gated by explicit destination authorization. A future read-only evidence
inspection is not permission to install, launch, change saves/configuration, or provision a lab.
