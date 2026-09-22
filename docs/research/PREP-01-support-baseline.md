# PREP-01 — Initial Support Baseline and Fail-Closed Contract

**Status:** Conditional — support target and non-claim behavior pinned at evidence:E1; runtime
support remains unproved

**Date:** 2026-08-30

**Research ID:** PREP-01

**Applicable evidence:** evidence:E0 claim/documentation input plus evidence:E1 revision-pinned
source, release, host, and prior effective-install observations

## Question

What exact game, campaign, EEex, WeiDU, EET, SCS, Spell Revisions, operating-system, and install-order
baseline should constrain the first research profile, and what deterministic result applies when a
dependency or capability is absent, mismatched, stale, ambiguous, or unrecognized?

## Outcome summary

This checkpoint pins one deliberately narrow **candidate research profile**:

- Windows 11 x64;
- single-player BG2:EE `2.6.6.0`;
- EET `v14.0` finalized by `EET_end`;
- EEex `v0.11.0-alpha` with its LuaJIT component and upstream-declared x64 Microsoft Visual C++
  Redistributable prerequisite;
- WeiDU `v251.00` for future project-owned compilation and static/integration verification;
- SCS `v35.21` as an optional adapter family; and
- Spell Revisions `v4.19` as an optional effective-spell-semantics family.

`Required` below means required for this candidate profile. It does **not** mean that the dependency
or the profile has passed runtime acceptance. No engine or adapter is supported for mutation until
its required evidence:E3 installer and evidence:E4 runtime cases pass. At PREP-01, every runtime
adapter remains inactive and every game resource remains legacy-owned.

The profile is based on a prior read-only installed-stack observation plus revision-pinned upstream
evidence. The active game was not accessed for this checkpoint. Newer releases and every other
platform combination are separate, explicitly deferred profiles rather than presumed-compatible
upgrades.

**Later observation, not a baseline replacement:** The user-approved Task 3 source inspected on
2026-09-22 has a different executable and dependency labels. See
[the source preflight](disposable-lab-provisioning.md). Its reviewed offline-reference acquisition
scope grants no runtime profile, launch permission or support claim; the candidate above remains
unchanged until a separate profile decision and evidence review.

The candidate describes an already-finalized effective EET stack. It does not define or authorize a
fresh EET construction from store downloads. The BG:EE plus SoD source build, store provenance, and
conditional DLCMerger input needed for such a construction are classified separately below and
remain deferred.

## Scope and environment

### Repository state

- Baseline checkout before this memo: `514c2fde9db4ffebd160570b693a3d29beaf80c1`.
- Task 1 and G0 are complete; Task 2 is `in_progress`.
- Task 3 remains pending and separately requires explicit authorization naming a disposable
  destination.

### Prior installed-stack observation used as evidence

Commit `a57f9bb667dcb4a33c826a88809092b104d37192` records a 2026-08-30 read-only inspection in
`docs/research/2026-08-30-scs-aoe-prebuff-delivery.md`. Reproduce the retained record without
accessing a game:

```powershell
git show a57f9bb667dcb4a33c826a88809092b104d37192:docs/research/2026-08-30-scs-aoe-prebuff-delivery.md
```

That memo records:

| Observed dependency | Identifier |
|---|---|
| Game | BG2:EE `2.6.6.0` |
| `Baldur.exe` | SHA-256 `FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580` |
| EET | `v14.0` |
| EEex | `v0.11.0-alpha`, including LuaJIT |
| Effective-stack WeiDU | `24600` |
| Spell Revisions | `v4.19` |
| SCS | `v35.21`; components 5900, 6030, and 6040 were identified |
| `WeiDU.log` | SHA-256 `AC8F36CD73A444BE0311F4979D343AB9BBED589B80A1203C785BA310469EA75F` |

This is evidence for one observed stack, not proof that the installation is unchanged, that every
installed mod directory matches its release tag, or that any runtime behavior is safe.

### Host observation for this checkpoint

Only ordinary host metadata and commands already on `PATH` were inspected:

| Host fact | Observed value | Classification |
|---|---|---|
| Operating system | Microsoft Windows 11 Pro 25H2, version `10.0.26200`, build `26200`, UBR `9168`, x64 | Observed-only reference host; required candidate OS family |
| PowerShell Core | `7.6.5`, x64/Win32NT | Observed-only; exact Task 2 floor remains deferred |
| Windows PowerShell | `5.1.26100.9168` | Observed-only; not selected as the project runtime |
| Python | CPython `3.11.9` | Observed-only; exact Task 2 floor remains deferred |
| pytest | `8.4.2` | Observed-only; exact Task 2 floor remains deferred |
| Git | `2.55.0.windows.4` | Observed-only |
| GitHub CLI | `2.86.0` | Observed-only; used for public release metadata reproduction |
| `lua` / `luajit` | Not directly discoverable on `PATH` | Availability unproved; not evidence of absence |
| `weidu` | Not directly discoverable on `PATH` | Required project tool is not yet executable evidence |
| Near Infinity | Not directly discoverable on `PATH` | Explicitly deferred to later Task 2 inventory |
| Microsoft Visual C++ Redistributable x64 | Not inspected | Required by pinned EEex documentation; presence and exact installed version unproved |

No recursive disk search was performed. No game, save, loader configuration, or candidate disposable
path was enumerated or read.

## Method

1. Read the architecture, PREP-01 backlog entry, compatibility matrix, Task 2 plan, ADRs 0004 and
   0006, and the G0 charter.
2. Reuse the version/hash facts from the retained E1 installed-stack memo without reopening the
   active installation.
3. Resolve official upstream release tags and upstream-published asset digests with GitHub release
   metadata and `git ls-remote --tags`; no package was downloaded.
4. Inspect the pinned EEex, EET, and Spell Revisions documentation for platform and install-order
   statements, plus the current engine/EEex release split for concrete counterevidence to broad
   version claims.
5. Inventory normal host metadata and directly discoverable commands without searching game paths.
6. Classify every dependency as `Required`, `Optional adapter`, `Observed-only`, or `Explicitly
   deferred`.
7. Define the deterministic no-claim result for every unsupported or uncertain state.
8. Review the result against PREP-01's exit criterion. No runtime or installer behavior was
   exercised.

## Read-only reproduction commands

Run these from the repository root. They enumerate ordinary host metadata and public upstream
metadata only; they do not accept or search a game path:

```powershell
$os = Get-CimInstance Win32_OperatingSystem
[pscustomobject]@{
    Caption = $os.Caption
    Version = $os.Version
    BuildNumber = $os.BuildNumber
    OSArchitecture = $os.OSArchitecture
} | Format-List

$cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[pscustomobject]@{
    DisplayVersion = $cv.DisplayVersion
    CurrentBuild = $cv.CurrentBuild
    UBR = $cv.UBR
} | Format-List

[pscustomobject]$PSVersionTable |
    Select-Object PSEdition, PSVersion, Platform, OS |
    Format-List
powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
python --version
python -m pytest --version
git --version
gh --version

$toolRows = @(foreach ($name in @('lua', 'luajit', 'weidu', 'NearInfinity', 'NearInfinity.exe')) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    [pscustomobject]@{ Name = $name; Discovered = [bool]$command }
})
$toolRows | Format-Table -AutoSize
```

Reproduce the selected release metadata and package identities with:

```powershell
$releases = @(
    @{ Repo = 'Bubb13/EEex'; Tag = 'v0.11.0-alpha' }
    @{ Repo = 'WeiDUorg/weidu'; Tag = 'v251.00' }
    @{ Repo = 'Gibberlings3/EET'; Tag = 'v14.0' }
    @{ Repo = 'Gibberlings3/SwordCoastStratagems'; Tag = 'v35.21' }
    @{ Repo = 'Gibberlings3/SpellRevisions'; Tag = 'v4.19' }
)
$releaseQuery = '{tag_name,published_at,prerelease,html_url,assets:[.assets[]|{name,size,digest}]}'

foreach ($release in $releases) {
    gh api "repos/$($release.Repo)/releases/tags/$($release.Tag)" --jq $releaseQuery
    gh api "repos/$($release.Repo)/git/ref/tags/$($release.Tag)" --jq '{ref,object}'
}

# v251.00 is annotated; peel its recorded tag object to the source commit.
$weiduTagObject = 'ed63cc84e9e6c67a6edde635f6d9b88703865420'
gh api "repos/WeiDUorg/weidu/git/tags/$weiduTagObject" --jq '{tag,sha,object}'
```

The later/deferred releases in this memo were queried with the same two endpoints and their exact
tags. The release metadata was observed on 2026-08-30. GitHub asset metadata is independently
mutable from a source tag, so future acquisition must compare the then-current package against the
recorded size and digest rather than assuming the link still serves identical bytes.

## Revision-pinned upstream evidence

Tag SHAs below are the commits to which the named release tags resolve. An annotated tag object is
also recorded where Git reports one.

| Project | Release/tag | Commit SHA | Release date | Primary source |
|---|---|---|---|---|
| BG2:EE | Patch `2.6.6` / executable `2.6.6.0` | Proprietary executable; local hash above | 2021-05-17 | [Beamdog 2.6.6 patch notes](https://www.beamdog.com/news/266-patch-icewind-dale-and-baldurs-gate-i-ii-enhanced-editions/) |
| BG2:EE | Current `2.7` line / executable `2.7.3.0` | Proprietary executable; no candidate hash acquired | 2026-06-23 | [Beamdog announcement](https://forums.beamdog.com/discussion/90724/2-7-baldurs-gate-icewind-dale-ees-update-new-languages-improved-cloud-support-mobile-modding), [official debug-file index](https://files.beamdog.com/) |
| EEex | `v0.11.0-alpha` | `89e524640766aa61d6963070299eaaac86f883d8` | 2025-08-27 | [release](https://github.com/Bubb13/EEex/releases/tag/v0.11.0-alpha), [pinned README](https://github.com/Bubb13/EEex/blob/89e524640766aa61d6963070299eaaac86f883d8/README.md) |
| WeiDU | `v251.00` | `5d94cb73661d74a6fd5126ede39c4c7b3748e188`; annotated tag object `ed63cc84e9e6c67a6edde635f6d9b88703865420` | 2026-03-01 | [release](https://github.com/WeiDUorg/weidu/releases/tag/v251.00), [commit](https://github.com/WeiDUorg/weidu/commit/5d94cb73661d74a6fd5126ede39c4c7b3748e188) |
| WeiDU | observed stack `v246.00` / `24600` | `b26ebf21541dc722485b4948b5b058b19c8a28c7`; annotated tag object `4c29799ad2b74f38d5f6f4416dee43af955f34e8` | release metadata published 2019-07-18 | [release](https://github.com/WeiDUorg/weidu/releases/tag/v246.00) |
| EET | `v14.0` | `ad20ca29ae797e773fffb10c25537c1b1a674716` | 2025-03-29 | [release](https://github.com/Gibberlings3/EET/releases/tag/v14.0), [pinned readme](https://github.com/Gibberlings3/EET/blob/ad20ca29ae797e773fffb10c25537c1b1a674716/EET/readme-EET.html) |
| SCS | `v35.21` | `5dc240e9ff85d3909b6436e54b56297d3b61e33b` | 2024-11-21 | [release](https://github.com/Gibberlings3/SwordCoastStratagems/releases/tag/v35.21), [pinned TP2](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/setup-stratagems.tp2) |
| Spell Revisions | `v4.19` | `e97435afeb14ff5c83cfa41e14c23940c9a0cf8e` | 2025-11-25 | [release](https://github.com/Gibberlings3/SpellRevisions/releases/tag/v4.19), [pinned README](https://github.com/Gibberlings3/SpellRevisions/blob/e97435afeb14ff5c83cfa41e14c23940c9a0cf8e/README.md) |

The selected releases are profile identifiers, not version-range claims. GitHub reports later
releases for EEex (`v1.2.0`, commit `204040502ac920161d60046d90b766b8d2d08152`), EET (`v14.1`,
commit `20d00c58aadc906b0abfdfda6fc5a0c1dd771ecc`), and Spell Revisions (`v4.21`, commit
`af1dedb6d211f86ad7a321d4080e46c748e8abac`). Those releases are not silently substituted for the
observed profile; each is explicitly deferred below.

The EET source itself contains a version-label trap: tag `v14.0`'s pinned
[`EET/EET.tp2`](https://github.com/Gibberlings3/EET/blob/ad20ca29ae797e773fffb10c25537c1b1a674716/EET/EET.tp2)
still declares `VERSION ~V13.4~`, while tag `v14.1` changes that declaration only to `v14.0`.
Therefore neither a `WeiDU.log` version string nor the installed TP2 declaration uniquely identifies
either source tag. Exact package/source provenance and effective-resource identities must decide;
the label alone must not accept or reject the candidate.

GitHub's release metadata also publishes these package identities without requiring acquisition:

| Selected package | GitHub release-metadata identity |
|---|---|
| `eeex-v0.11.0-alpha.zip` | 5,086,265 bytes; SHA-256 `BFC5133C8118A83AE4F6C5BFDFD40E8177F401A653E1CD5D4074AF082716D87B` |
| `WeiDU-Windows-251.zip` | 2,322,613 bytes; SHA-256 `A54C6198D6EBED8139793FCACB225500D563657C23FC775B840383F9750493D8` |
| `spell_rev-v4-19.zip` | 7,620,362 bytes; SHA-256 `E1F7E9E31E806FAE70850870E3F7103E30EB181D865AD3233C4DFB4EAA4E3185` |
| EET `v14.0` | No attached release asset or upstream package digest; source tag is the available pin |
| `stratagems-35.21.exe` | 58,464,696 bytes; GitHub reports no digest for this older asset |

These are upstream metadata values, not locally recomputed hashes. Package acquisition and local
hash verification remain later, separately authorized work.

### Why engine `2.7` and EEex v1 are separate profiles

Beamdog's `2.7` announcement identifies dynamic-language changes and a rebuilt-BIF indexing fix,
and its official file index publishes distinct `2.6.6.0` and `2.7.3.0` debug-file sets. EEex
`v1.0.0` then [failed to initialize on a Steam 2.7 build](https://github.com/Bubb13/EEex/issues/135)
because an executable pattern could not be found. EEex `v1.1.0` subsequently
[added 2.7.3.0 support](https://github.com/Bubb13/EEex/releases/tag/v1.1.0), while `v1.1.5`
[added recognition for the GOG 2.7 BG2:EE executable](https://github.com/Bubb13/EEex/releases/tag/v1.1.5).

That sequence is concrete counterevidence to treating either a nearby engine version or a matching
marketing version from another store as interchangeable. PREP-01 therefore keeps the observed
`2.6.6.0` plus EEex `v0.11.0-alpha` pair as the candidate and defers every `2.7`/EEex-v1/store
combination to a separately fingerprinted capability profile.

## Dependency support-state ledger

The support state is scoped to the candidate profile, not to completed product support.

| Dependency or profile | Exact identifier | Support state | Adapter applicability | Deterministic mismatch or uncertainty result | Required evidence still unexecuted |
|---|---|---|---|---|---|
| Game executable/data | BG2:EE `2.6.6.0`; candidate executable hash above | **Required** | Shared boundary and every future adapter | Any other build or a hash that cannot be established has no runtime profile; no adapter claims content | evidence:E3 packaging where relevant; evidence:E4 lifecycle/runtime; evidence:E5 matrix |
| Campaign | Single-player EET on BG2:EE | **Required** | Initial resource, identity, area, dialogue, and campaign profile | Standalone BG2:EE, BG:EE, SoD without EET, IWD:EE, PST:EE, total conversions, and multiplayer have no active profile | evidence:E3 plus evidence:E4 for exact campaign behavior |
| EET | `v14.0`, commit `ad20ca29...`; finalized `EET_end` | **Required** | Initial EET identity and effective-resource profile | Missing, different, intermediate, or unfinalized EET disables all EET-dependent adapters; renamed resources are never guessed | evidence:E3 final-stack inventory and evidence:E4 campaign/runtime cases |
| Finalized-stack construction provenance | EET `v14.0` final stack observed; BG2:EE store/acquisition channel and construction manifest not retained | **Observed-only** | Reproduction and future disposable-copy provenance | A store label never substitutes for executable and effective-resource hashes. Missing construction provenance blocks clean reacquisition/rebuild claims | authorized disposable manifest plus final effective-stack inventory |
| Fresh EET source input | pinned EET `v14.0` readme requires a clean/compatible BG:EE plus SoD source; exact future source build/store/hash not selected | **Explicitly deferred** | Fresh EET construction only; not required to retain the historical E1 observation | Do not install or claim a fresh EET stack until an exact source profile is separately reviewed | source-game provenance, hashes, compatible-input scan, and authorized lab plan |
| DLCMerger for EET source | A7-DlcMerger required by pinned EET readme for Steam/GOG SoD; exact DLCMerger revision not selected | **Explicitly deferred** | Fresh EET construction from Steam/GOG source only | Unknown source store or missing exact DLCMerger identity blocks fresh EET construction; never guess from directory shape | pinned DLCMerger release plus source-store-specific install evidence |
| Operating system | Windows 11 x64; reference build `26200.9168` | **Required** | Host tooling and EEex runtime candidate | Other Windows builds, 32-bit Windows, Linux/Proton/Wine, and macOS have no active profile | environment checker, toolchain decision, and evidence:E4 runtime |
| EEex | `v0.11.0-alpha`, commit `89e52464...` | **Required** | Shared engine boundary candidate | Missing, different, partially removed, or unproved EEex produces no runtime activation; no nearest-version guess | evidence:E4 capability/lifecycle matrix and bridge-removal cases |
| EEex LuaJIT component/configuration | Exact component present in the prior observation; configuration not re-read | **Required** | Lua 5.1/LuaJIT runtime candidate | Missing or ambiguous LuaJIT capability disables the whole initial runtime profile before mutation | evidence:E3 prerequisite refusal and evidence:E4 loader/runtime proof |
| Microsoft Visual C++ Redistributable x64 | moving vendor package named by the [pinned EEex README](https://github.com/Bubb13/EEex/blob/89e524640766aa61d6963070299eaaac86f883d8/README.md); exact installed version unobserved | **Required** | EEex loader prerequisite | Missing or unproved runtime leaves the EEex profile unavailable; Windows version is never treated as proof of installation | host prerequisite inventory and evidence:E4 loader-start proof |
| Project WeiDU | `v251.00`, commit `5d94cb73...` | **Required** | Future project-owned BAF/D/TP2 checks and synthetic integration | Missing or another version leaves the check unexecuted; Python/PowerShell never impersonates WeiDU | executable discovery, exact commands, evidence:E3 fake-game proof |
| Effective-stack WeiDU provenance | observed `24600`, upstream `v246.00` commit `b26ebf21...` | **Observed-only** | Explains the existing effective stack; not the project verifier | It is never treated as a passing project tool floor and is never rerun against the active stack | byte/provenance correlation if an adapter needs compiler identity |
| SCS | `v35.21`, commit `5dc240e9...`; observed components 5900/6030/6040 | **Optional adapter** | Only separately fingerprinted SCS mage/prebuff families | Absent SCS means no SCS adapter. Different version, components, generated shape, or `dw#*` names remain SCS-owned C0/C1 content | evidence:E1 family closure, evidence:E3 inventory/installer, evidence:E4 handoff |
| Spell Revisions | `v4.19`, commit `e97435af...`; exact installed component set not retained here | **Optional adapter** | Only candidates whose effective SPL/PRO/dependencies are exactly resolved | Absence means no SR-specific semantics. Different or ambiguous effective spell semantics reject only dependent candidates/adapters | evidence:E1 dependency closure plus evidence:E3/E4 semantic cases |
| Host PowerShell/Python/pytest/Git/GitHub CLI | observed versions in the host table | **Observed-only** | PREP-01 reproduction only | Availability or version mismatch makes the applicable host check unexecuted; no game support follows | remaining Task 2 checker/toolchain decisions |
| EEex `v1.2.0` | commit `20404050...` | **Explicitly deferred** | Possible future separate EEex v1 profile | No v1 profile or cross-version equivalence is inferred | evidence:E1 capability mapping plus evidence:E3/E4 profile cases |
| BG2:EE `2.7.3.0` plus EEex v1 | exact store executable and compatible EEex v1 release not selected | **Explicitly deferred** | Possible future engine/loader profile | Engine label, EEex major version, or another store's result never activates it; missing exact executable identity yields no profile | store-specific executable fingerprint plus evidence:E1/E3/E4 profile |
| EET `v14.1` and later | `v14.1`, commit `20d00c58...` | **Explicitly deferred** | Possible future EET profile | No adapter activates on the `v14.0` label or hashes when `v14.1` is effective | refreshed evidence:E1/E3/E4 profile |
| Spell Revisions `v4.21` and other versions | `v4.21`, commit `af1dedb6...` | **Explicitly deferred** | Possible future spell-semantics profile | Exact effective resources remain unknown and dependent candidates stay inactive | refreshed evidence:E1/E3/E4 profile |
| Other SCS releases/configurations | anything other than the exact `v35.21` candidate family | **Explicitly deferred** | Possible future per-family adapter | SCS continues as legacy owner; no fuzzy generated-script match | family ledger and required evidence:E1/E3/E4 |
| Other game builds, OSes, campaigns, multiplayer, and non-EEex runtime | all other combinations | **Explicitly deferred** | None | No active runtime profile and no compatibility claim | a separately proposed and reviewed profile |
| Near Infinity, standalone Lua/LuaJIT host runner, decompiler commands, path/encoding floors, disk budget | no selected floor at this checkpoint | **Explicitly deferred** | Continuing Task 2 only | Missing/unknown tools do not pass a check and do not authorize searching or writing game paths | Task 2 steps after PREP-01 |

## Capability assumptions and limits

These are prerequisites to test, not evidence that the capability works in the engine:

1. The exact BG2:EE executable must match the declared `2.6.6.0` profile. A version label without
   an executable/content identity is insufficient for adapter activation.
2. The selected candidate is an already-finalized EET stack. Its observation does not establish a
   reproducible fresh-build source, store, DLCMerger, or installer path.
3. EEex's x64 Microsoft Visual C++ Redistributable prerequisite must be resolved before any loader
   test. The pinned README's moving “latest” link is a dependency declaration, not an exact package
   pin or evidence that the host has it.
4. EEex `v0.11.0-alpha` must expose its expected v0.11 script layout and `M___EEex.lua` bootstrap,
   and LuaJIT must be active. EEex presence alone is not an API contract.
5. A complete v0.11 layout mixed with complete v1 assets is ambiguous upgrade residue and must be
   rejected. The runtime may not choose whichever layout looks newest.
6. Required EEex calls, callback timing, object lifecycles, marshal behavior, action observation,
   and bridge failure behavior remain Task 7 through Task 11 evidence questions. PREP-01 approves no
   native call.
7. Removing or partially removing EEex while compiled bridge resources remain is an unresolved
   COMP-X09 case. This checkpoint does not promise safe fallthrough for that configuration; the
   configuration remains unsupported until evidence:E4 either proves it or establishes a blocking
   uninstall/restoration order.
8. WeiDU `v251.00` is the selected future project verification/compiler identity, but no executable
   was discovered or run here. Parser, compiler, install, and uninstall checks are unexecuted.
9. SCS and Spell Revisions version/component labels never replace exact effective resource,
   dependency, script-slot, and external-control closure checks.
10. Whole-file hashes are the only candidate activation fingerprints at this stage. Selective
   semantic fingerprints remain deferred until loss-aware IR and counterexample research passes.

## Install-order and final-stack contract

The selected candidate's immediate order contract starts only from an already-finalized EET `v14.0`
stack. A future disposable copy must be explicitly authorized, content-manifested, and shown to
match the declared executable/final-stack identities before use. PREP-01 does not authorize that
copy.

A from-scratch construction is not yet a selected profile. If one is later reviewed, its minimum
order constraints are:

1. Pin clean/compatible BG:EE plus SoD source and BG2:EE target builds, stores, package/content
   identities, and disk/path requirements. For Steam/GOG SoD, pin and install the required
   DLCMerger input first. Unknown source/store identity blocks the build.
2. Install EET `v14.0` core and native EET content in their documented order.
3. If SR `v4.19` is present, install its main spell-replacement component early and before SCS, as
   required by SR's pinned README. Place any optional NPC spellbook update only after the NPC mods it
   is meant to update.
4. Install SCS `v35.21` and every other intended content, AI, quest, spell, and compatibility patch.
5. Run EET `v14.0`'s required `EET_end` finalizer after all other game mods, as required by its
   pinned readme.
6. Only after the finalizer and intended stack are complete may a future BGSE inventory/manifest
   refresh inspect effective resources. This is a read-only tail scan; the eventual BGSE WeiDU
   component's placement remains a Task 39 design and is not decided here.
7. Any later install, uninstall, reinstall, finalizer rerun, runtime-asset change, or unreadable
   normalized epoch makes both domains stale/pass-through. Reactivation requires a new dependency
   and external-control scan; WorldFlow additionally requires refreshed public-state reverse
   references.

Installing BGSE before final effective resources exist never authorizes optimistic activation. A
bridge artifact remaining on disk after stack drift is not evidence that its claim is still valid.

## Normative fail-closed contract

The following outcomes are deterministic requirements for later implementation. They are not
reported as executed behavior at PREP-01.

| Condition | Required result |
|---|---|
| Unknown or untested game build/campaign | No runtime profile; no adapter claim; original content remains unmodified and unclaimed |
| Engine version label is known but store/executable identity is absent or different | No runtime profile; do not reuse another store's loader or capability result |
| Required dependency absent | Entire dependent profile remains unavailable; no substitute version or heuristic path is selected |
| EEex Microsoft Visual C++ runtime missing or unproved | No EEex loader/runtime profile; do not infer presence from Windows or attempt a runtime probe |
| Fresh EET source build/store or conditional DLCMerger input is unknown | No fresh EET construction, reproducibility claim, or disposable provisioning; only upstream-declared minimum order constraints are recorded, and the retained finalized-stack observation remains E1 only |
| Optional SCS/SR family absent | Only that optional adapter/semantic family remains inactive; absence is not incompatibility |
| Version label matches but exact capabilities/resources do not | Capability/resource result wins; affected adapter remains ineligible |
| EET log/TP2 reports `V13.4` or `v14.0` without source/package provenance | Treat the EET tag as unproved; do not infer `v14.0` or `v14.1`, and do not reject solely on the stale label |
| Unknown EEex version or layout | No runtime activation and no speculative native call |
| Mixed v0.11/v1 EEex layouts | Reject as ambiguous; do not select either family |
| Required EEex capability missing | Disable the smallest dependent feature or adapter; never broaden another claim |
| EEex absent/partial with compiled bridge present | Configuration remains unsupported and blocked pending COMP-X09 evidence; do not promise unproved fallthrough |
| EET missing, changed, or not finalized | No EET-specific identity/resource/area/dialogue adapter activates |
| SCS missing | No SCS adapter; effective non-SCS/legacy scripts keep ownership |
| SCS version/component/generated shape unrecognized | SCS remains the owner; generated `dw#*` names never establish identity by themselves |
| SR missing | No SR-specific semantics; unrelated future profiles may continue only if separately eligible |
| Effective spell/projectile semantics unknown or changed | Reject only the dependent candidate/adapter; never assume vanilla or SR resrefs |
| Resource hash, dependency, script slot, public writer set, or stack epoch differs | Mark the affected claim stale/ineligible; later effective content wins |
| Opaque BCS/DLG/resource syntax enters a dependency closure | The claim is incomplete and ineligible; opaque content stays legacy-owned |
| Unknown mod/content is present | C0 pass-through; no class, hostility, spellbook, prefix, or similarity heuristic enrolls it |
| Tool missing, version unknown, or command unavailable | Check is unexecuted, never passing; no replacement installer is improvised |
| Intended target is the active game, an alias/descendant, or an unmarked/escaping disposable path | No write is authorized. The future checker must hard-refuse before writing, but that checker does not yet exist |
| Native safety, lifecycle, or outcome remains uncertain | No call or action is attempted; required evidence gate remains closed |

No no-claim outcome deletes, rewrites, disables, or clears legacy BCS/DLG. Where safe behavior with a
partially removed runtime has not yet been proved, the configuration is blocked rather than described
as a successful legacy fallback.

## Observations

- The exact historical target stack is reproducibly described by a retained E1 memo without
  revisiting the game.
- Official upstream tags resolve to immutable commits for every open-source dependency in the
  selected profile.
- EEex's pinned `v0.11.0-alpha` README names Windows as native and BG2:EE `2.6.6.0` as compatible,
  but this remains upstream documentation/static evidence rather than this project's runtime proof.
- The same EEex README names the x64 Microsoft Visual C++ Redistributable as a dependency; that
  prerequisite was not inspected on this host.
- EET's pinned `v14.0` readme requires a BG:EE plus SoD source, conditionally requires DLCMerger for
  Steam/GOG SoD, and requires `EET_end` after all other mods.
- EET tag `v14.0` declares TP2 version `V13.4`, and tag `v14.1` declares `v14.0`; installer/log
  labels are therefore not exact tag identities.
- SR's pinned `v4.19` README requires its main component before SCS.
- Newer EEex, EET, and SR releases exist, so an unversioned “latest” baseline would already be
  ambiguous.
- The engine `2.7`/EEex-v1 release sequence contains an observed loader-pattern failure and a later
  store-specific recognition fix, so store/executable identity is a material profile dimension.
- The selected future WeiDU `v251.00` differs from the `24600` used by the observed effective stack.
  The distinction is retained instead of pretending the old stack was generated by the new tool.
- Host Python, pytest, PowerShell, Git, and GitHub CLI are available, while Lua/LuaJIT, WeiDU, and
  Near Infinity were not directly discoverable on `PATH`. This is a discovery result, not a full
  tool inventory.

## Counterevidence and residual uncertainty

- No game file or current `WeiDU.log` was reopened. The retained observation may no longer describe
  the active installation, so the active installation is not a support target or a validation lab.
- The prior memo explicitly did not prove that installed SCS source was byte-identical to its tag.
- The exact installed SR component set was not retained in this checkpoint. Version `v4.19` alone
  cannot activate an SR-dependent adapter.
- EET `v14.1`, EEex `v1.2.0`, and SR `v4.21` are newer than parts of the selected observed profile.
  EET `v14.1` specifically reports [EEFP-compatibility and `EET_end` fixes](https://github.com/Gibberlings3/EET/releases/tag/v14.1),
  which is material counterevidence to treating `v14.0` as “current” or interchangeable. It does not
  erase `v14.0` as the exact historical candidate. No forward-compatibility inference is made.
- The source BG:EE plus SoD build/store, any DLCMerger version, the BG2:EE acquisition channel, and
  the original EET construction manifest were not retained. This checkpoint therefore supports no
  fresh EET build or clean reacquisition claim.
- The retained installed-stack memo labels EET `v14.0`, but the upstream TP2-label defect means that
  the label cannot establish byte identity with tag commit `ad20ca29...`. Candidate activation still
  requires source/package provenance and final effective-resource hashes.
- The exact installed Microsoft Visual C++ Redistributable version was not inspected. The EEex
  prerequisite is classified, but runtime readiness remains unproved.
- No BG2:EE `2.7.3.0` executable from any store was inspected. The upstream 2.7/EEex-v1 evidence
  justifies a distinct fail-closed profile boundary, not a support claim.
- Upstream asset digests were read from release metadata. No package was downloaded, so those
  values are not locally recomputed acquisition evidence.
- Windows build `26200.9168` is observed host metadata, not an evidence:E4 engine result or a broad
  Windows compatibility range.
- WeiDU `v251.00` was pinned from source/release metadata but no local executable was run. Its
  behavior against project sources, fake games, or any real stack remains unexecuted.
- No standalone Lua/LuaJIT runner or Near Infinity command was selected. Encoding, path, and disk
  floors remain continuing Task 2 work.
- EEex v0.11 bootstrap, LuaJIT, lifecycle, API, persistence, and action behavior still require the
  later capability and disposable-engine program.
- Safe behavior after partial/full EEex removal with compiled bridge resources remains unknown.
- No evidence:E2 policy simulation, evidence:E3 synthetic-game integration, evidence:E4
  disposable-engine proof, or evidence:E5 supported-corpus soak was produced by PREP-01.

## Artifacts and retention

| Artifact | Retention | Use |
|---|---|---|
| This memo | Repository | Normative candidate baseline and deterministic non-claim contract |
| Task state JSON | Repository | Task 2 remains `in_progress`; Task 3 authorization barrier remains visible |
| Prior installed-stack memo at `a57f9bb...` | Git history/related worktree | Exact E1 observation without renewed game access |
| Upstream release tags and commits | Public upstream repositories | Immutable dependency identities and documentation inputs |
| Host command output | Ephemeral terminal output summarized above | Reference host observation without personal paths |
| Active game, saves, loader state, installed resources | Not accessed or retained | Explicitly outside this checkpoint |
| Disposable game | Not provisioned | Task 3 remains unauthorized |

## PREP-01 exit-criterion review

| Criterion | Result |
|---|---|
| Every dependency has an explicit support state | Met by the dependency ledger |
| Exact identifiers are present where available | Met for the candidate game hash, releases, tags, and host |
| Capability assumptions are distinct from version labels | Met; assumptions are prerequisites, not executed evidence |
| Install-order expectations are explicit | Met, including the finalized-copy boundary, deferred EET source/DLCMerger inputs, SR before SCS, `EET_end`, and tail refresh |
| Adapter applicability is scoped | Met per optional SCS/SR and required EET/EEex families |
| Every unsupported/uncertain case has a deterministic result | Met by the fail-closed matrix |
| No untested engine or EEex version is called supported | Met; the profile is explicitly a candidate pending evidence:E4 |
| Active game and disposable boundary preserved | Met; neither was accessed, created, launched, or mutated |
| Checker RED-before-GREEN remains possible | Met; no checker, checker test, or `pyproject.toml` was created |

## Outcome and next decision

**Outcome:** Conditional.

PREP-01's evidence:E1 objective is satisfied: one exact candidate ecosystem is pinned, every
dependency has a support state, and every mismatch or uncertainty has a deterministic non-claim
outcome. This releases Task 4's PREP-02 evidence/provenance checkpoint for a later authorized turn.
It does not complete Task 2, activate Task 4 in this turn, or authorize runtime work.

Task 2 remains `in_progress`. Its next checker step must begin in a later continuation by adding
`tests/tooling/test_environment_contract.py` first and preserving the intentional RED because
`scripts/check-dev-environment.ps1` does not exist. Only after that RED may the minimal checker be
implemented. The host-runtime decision, runbook, PREP-03, and Task 2 completion remain later work.

Task 3 remains pending and requires a separate explicit user authorization naming the disposable
destination. No active or disposable game path may substitute for that decision.
