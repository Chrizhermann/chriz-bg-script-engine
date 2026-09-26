# First installed SCS mage/prebuff comparison

**Outcome:** Partial Task 6 progress, evidence:E1. One actual mage script and its generic
short/long prebuff pair are now mapped. No adapter, gameplay change or runtime claim.

**Question:** Do the source distinctions already documented survive in an installed mage?

**Environment:** Approved SCS-reference lab copy, inspected offline; no game, loader or save
executed. Observed stack: BG2:EE 2.7.3.0, EET 14.0, EEex 1.2.0/LuaJIT, SCS 35.21,
Spell Revisions 4.21-chriz.5. Exact stack identity is the copied `WeiDU.log` SHA-256
`4FD4AB5491533C17E5E8DE26E4DCE84A761A34EF79A998B06007234080B89FE6`.

**Method:** Inspect installed CRE fields and SCS generation log; decompile its assigned BCS
using WeiDU 24900, compare selected blocks to the pinned source, recompile in a private scratch
directory, and compare bytes. Inspect component ownership separately with WeiDU change-log.
All installed payloads/decompiles stay private under `.work/task6/effective-pilot-20260927`.

## Actor and source identity

`MAGE6B.CRE` is listed in the copied EET vanilla BG2 CRE oracle (`bg2_CRE.2da`, line1979).
Its effective bytes have multiple mod owners: the retained WeiDU diagnostic records backups from
Artisan's Kitpack 10001/10003, SCS 6000/6030, then Artisan's Kitpack Tweaks 3202/8204.
Do not attribute the whole current CRE
to SCS. Its final size is 3,440 bytes, race HUMAN, class MAGE, level6, kit ENCHANTER.
Kit storage is reversed: raw little-endian `0x02000000` maps to installed KIT.IDS `0x0200`.

Its resource script slots are override empty; class/race/general `None`; default `dw#mg266`.
Death variable is `mage6b`; dialogue is `None`. This describes the CRE, not all area/spawn overrides.
The generated BCS name is a local locator only, never the family identity or an enrollment rule.

The copied `SETUP-STRATAGEMS.DEBUG`, lines277499–277506, records generation for MAGE6B from
`dw#mage.baf` to `dw#mg266.bcs` during component6030. That is the retained evidence for its
SCS generation; the script change-log diagnostic contains no owner chain and is not a substitute.
The generic caller supplies spell-family arguments, not `detect_invisible`; the shared parser
defaults that flag to0. Together with the human/enchanter fields and recorded main template,
this matches the existing `kit=enchanter`, `detect_invisible=0`, `race=HUMAN` source lane.

All18 files in `scs-source-pilot.evidence.json` were compared to the copied source: two raw-byte
matches, sixteen CRLF-only differences. Replacing CRLF with LF in those sixteen gives the exact
recorded upstream SHA-256. This establishes textual equivalence, not raw-byte identity; no SCS
source was modified. The worker's initial mismatch warning was corrected before drawing conclusions.

## Bounded comparison

**Observations:** Line numbers below refer to the private WeiDU249 decompile with the hash below.

| Effective lines | Finding to preserve |
|---|---|
| 381–409 | Mirror Image's short-prep block requires availability, untouched prep state, sight or explicit offscreen prep, and a living caster. It force-delivers the mapped helper, removes the memorized original, then continues. |
| 411–447 | Shield's long-prep block uses detection/offscreen/party proximity plus a separate hostility-related condition. It also removes the original and continues. This is not just a different duration. |
| 388–403 vs428–441 | The short block reads `DMWW_mage_prep_difficulty`; the long block reads `DMWW_mage_difficulty`. The previously noted source distinction survives generation. No normalization or bug fix is proposed. |
| 465–533 | First-round normal casting and separate state-setting branches own the later prep-state transition. The two generic prebuff blocks alone are not the whole one-shot protocol. |
| 159–171 | A rest branch resets prep/contingency state and calls `Rest()`. Its presence is static evidence, not observed timer/rest behavior. |
| 1225–1267 | One ranged-action block has weights100/50, with a separate `Continue()` response. Keep weighted fallthrough separate from unconditional action sequencing. |

The copied prebuff table maps Shield to `dwsw114` and Mirror Image to `dwsw212`; installed
SPELL.IDS resolves their original spell IDs to2114/2212. The final CRE has one memorized entry
for each, among11 memorized entries and10 known spells. These are file contents, not a live
cast/expenditure observation. The prebuff resource origin is SCS; their precise effect semantics
and subsequent spell-owner chain are not characterized by this sample.

**Counterevidence:** The239-block script contains no `firstdispel` token or named Kruin,
Davaeorn or Malavon branch. The early-dispel source requires higher-level capabilities; absence
here is consistent with pruning, not evidence that those rules are obsolete. This low-level
sample cannot validate the planned high-level dispel or special PRECAST paths.

## Reproduction and identities

Use the exact approved lab from `.work/task3/practical-lab-20260927.json`, not the active game.
The private `weidu.exe` is a copy of the lab's Setup-stratagems.exe (WeiDU24900):

```powershell
$lab = (Get-Content .work/task3/practical-lab-20260927.json -Raw | ConvertFrom-Json).destinationRoot
$scratch = (Resolve-Path .work/task6/effective-pilot-20260927).Path
Push-Location $scratch
try {
    ./weidu.exe --game $lab --use-lang en_us --noautoupdate --log decompile-mage.log "$lab/override/dw#mg266.bcs"
    ./weidu.exe --game $lab --use-lang en_us --noautoupdate --log recompile-mage.log './dw#mg266.baf'
    Get-FileHash "$lab/override/dw#mg266.bcs", './dw#mg266.bcs' -Algorithm SHA256
} finally { Pop-Location }
```

Decompilation and recompilation both exited0; rebuilt BCS is byte-identical. The decompile has
6,671 lines,239 IF blocks,279 responses and128 explicit Continue actions. Those are descriptive
counts, not a requirement to create one test per block.

| Artifact | SHA-256 |
|---|---|
| Final MAGE6B.CRE | `307409E704DF61DAFC604FFAC04ABC99951A2849CF96AD7596C354BA81E722F4` |
| Installed/rebuilt dw#mg266.bcs | `4D56E24F957C2B83DFC5B63D485AF3F70AC8C93AC578012C120A41E6227F6F7D` |
| Private decompile | `5FE9A10D0955A15845D15B561F6B03459DE3FDA193D03A7718346A6C6182B703` |
| WeiDU24900 executable | `AD70F5897A6D0BA4B0D226F845A9B14CF345F56CC9697CA8D05CAC9FE4932C1A` |
| SCS install DEBUG | `2DB1D53E59628EA5EFECD10BF16DB6B7C9D43C1F15694251D392CA5B6D804BA4` |
| SCS settings | `5C69D94D79888ED72D862BB18DCCD5B5E00576CDDFB22C26B504CC2225448F5E` |

For ownership, run the same private executable **with the lab as cwd**, absolute `--log` and
`--out` targets under the scratch directory, and `--change-log MAGE6B.CRE` or
`--change-log dw#mg266.bcs`. Initial scratch-cwd attempts exited0 but warned that `WeiDU.log`
was missing, so their empty owner lists were rejected. Corrected CRE diagnostics record the
backup sequence above; corrected script diagnostics do not record an owner chain.
Lab `WeiDU.log` stayed byte-identical. WeiDU refreshed lab `weidu.conf`'s timestamp but its contents
remain identical to the source. No active installation was used as an executable working directory.

**Artifacts:** Copied CRE/BCS/SPL, private decompile/recompile and command logs; pinned source
record already in Git. Only authored observations/digests are admitted here. SCS by DavidW;
Spell Revisions by Demivrgvs/G3; later CRE modifications by the recorded Artisan components.
Derived implementations/fixtures remain subject to the existing reuse review; no payload published.

**Applicable evidence:** E1 installed-file/source/compiler evidence. Not engine execution,
install/uninstall acceptance, a complete semantic oracle or a supported-content claim.

Independent Sol review checked source digests, script round-trip, block anchors and evidence
limits. It caught an attribution overclaim: the retained script diagnostic does not itself prove
the script's owner. The lead checked that log and corrected the attribution to the SCS install log.
Focused existing source-checkpoint/evidence-schema checks: 24 passed in 0.06s via
`python -X utf8 -m pytest -q tests/schemas/test_scs_source_checkpoint.py tests/schemas/test_research_evidence_schema.py`.
No new test suite was added for this static comparison.

**Residual uncertainty:** Exact historical library/autolib snapshot, install-time random choices,
full actor/controller closure, helper spell effects, live difficulty values, timing, spell expenditure
and save/load. Current `autolib` and generic workspace output may reflect later generations.

**Next decision:** Keep the sample legacy-owned. Use this pair for the first approved runtime
comparison once launch permission is available; add a higher-level representative when its rules
are needed. Task6 and G1 remain open. No creative/gameplay decision is needed for these observations.
