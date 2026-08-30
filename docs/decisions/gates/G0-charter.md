# G0: Charter gate

**Status:** Pending

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

The compatibility charter, domain separation, evidence vocabulary, coarse platform scope, support
tiers, kill-switch policy, non-goals, WeiDU boundary, and conservative SCS provenance policy are
approved at architecture level through ADRs 0001-0006.

G0 does **not** pass in this record. The public engine namespace remains a user-owned design choice.
After selection, read-only current collision checks must be rerun; contacting a maintainer or asking
for a reservation is a separate, explicitly authorized decision. `BGSE` remains a repository,
environment-variable, test, and documentation slug only; it is not an Infinity Engine
resource/global/local prefix.

## Entry criteria

- Architecture draft and compatibility matrix exist and are internally reviewable.
- The prime unknown-content pass-through invariant is normative.
- Initial platform, terminology, safety boundaries, provenance hold points, support tiers,
  kill-switch behavior, and non-goals are explicit.
- A unique engine-visible namespace is chosen and collision-checked.
- Task and gate dependencies match the research backlog.

The final namespace entry criterion is not satisfied.

## Criterion findings

| Criterion | Finding | Basis |
|---|---|---|
| Initial platform | Approved at charter level | Single-player BG2:EE/EET with EEex; exact versions, paths, and capability floors remain Task 2/PREP-01 work. |
| Unique engine namespace | **Blocked** | Under the community two-character ownership convention, `BGSE` conflicts with the registered `BG` namespace; `BG` also appears in the pinned EET resource-name corpus. A replacement candidate has not been selected. |
| Support tiers | Approved | C0 pass-through, C1 observed, C2 cooperative, C3 adapted, and C4 native are per-family tiers; no naming heuristic promotes content. |
| Kill switches | Approved | Per-adapter, per-domain, and master disable paths restore legacy fallthrough and never clear unrelated queues/state. |
| Non-goals | Approved | No arbitrary conversion, global takeover, exactly-once promise for opaque effects, every-EE support, multiplayer guarantee, full path planner, or active-playthrough testing. |
| SCS attribution/provenance | Approved with shipping hold | SCS is a first-class knowledge source; unclassified SCS-derived material remains reference-only until Task 4/LIC-01. |
| Domain separation | Approved | Combat Intent state is ephemeral; WorldFlow state is durable, versioned, reconciled, and independently disabled. |
| Compatibility and safety | Approved | Unknown/modified/stale/ambiguous content remains legacy-owned; the active game is read-only and Task 3 needs separate authorization. |
| Evidence and task map | Approved | E0-E5 are independent proof environments; reviewed PREP-01 and PREP-02 artifact checkpoints keep PREP-01 → PREP-02 → PREP-03 acyclic, and COMP-I07 is executable at G2. |

### Namespace collision findings

The community ownership/reservation convention is based on a two-character registered prefix. The
primary forum rule could not be retrieved directly during this review, so it remains an E0 input;
the pinned public dataset separately records `BS` and `BSM` as a reciprocal nested-prefix
conflict. Under that convention, a four-character label beginning with `BG` does not create a new
registrable namespace distinct from the already registered `BG` prefix.

This is a namespace-ownership conflict and a collision risk, not a claim that every `BGSE...`
filename has a literal engine byte collision with every `BG...` filename. A full resource-name byte
collision depends on the complete engine-visible name and its format limits. The conservative hold
exists because `BGSE` cannot establish unique ownership under the observed convention and because
real `BG`-leading resources already exist in the pinned corpus.

Read-only checks performed on 2026-08-30:

1. The pinned unofficial public registry dataset/mirror at commit
   `34782745bfdfeb33013df17fb89cd29fbc0cb173` contains 828 project/personal rows. It records `BG` as
   owned by "Minotaur in Maze" and records `BS`/`BSM` as an explicit nested-prefix conflict. The
   mirror repository does not document an authoritative provenance chain to the live reservation
   service.
2. An independent scan of all 34 BG1/BG2 resource-list files at EET commit
   `74e91d72bca5d073fa11c1d088b90d7ff0c7105d` inspected 53,846 rows. Seven begin with `BG`:
   `BGDECBAR.MOS`, `BGPADB.MOS`, `BGPADL.MOS`, `BGPADR.MOS`, `BGUARD1.BCS`, `BGUARD1.CRE`, and
   `BGUARD1.DLG`.
3. The following two-character candidates have zero exact/nested hits in the pinned registry mirror
   and zero hits in that EET resource-list corpus:

   | Candidate | Benefit | Cost or limitation |
   |---|---|---|
   | `B-` | Shared-platform mnemonic; third character can distinguish Combat Intent, WorldFlow, and kernel artifacts. | Hyphen cannot appear in a bare Lua identifier and requires deliberate quoting/string keys. |
   | `E-` | Neutral engine mnemonic and clear visual boundary. | Same Lua-identifier/quoting caveat as `B-`. |
   | `#O` | Follows an allowed special-character prefix form and is visually distinctive. | Less keyboard-friendly; needs careful quoting and URL/path handling. |
   | `QG` | Plain alphanumeric and simple across WeiDU, Lua strings, paths, and tools. | Deliberately opaque and less memorable. |

`B-` is the preferred preliminary, collision-screened candidate because it is shared across both
policy domains and leaves the third character available for a stable class marker. This is not yet
a syntax-proved selection or a reservation; G0 must still record derivations for each engine and host
identifier class.

The public mirror commit is dated 2026-05-03 and its newest row is dated 2026-03-27. The old live
database endpoint currently serves unrelated content, while forum retrieval was unreliable during
this review. The EET scan covers filenames in those 34 lists, not public globals/locals or arbitrary
mod stacks. Therefore zero hits mean "clear in these pinned corpora," not "currently reserved" or
"globally collision-free."

## Compatibility

No engine-visible artifact may use `BGSE` or any candidate until G0 records the chosen prefix and
derivation rules. Host-only identifiers such as `BGSE_DISPOSABLE_GAME_ROOT`, repository names, test
scenario IDs, and documentation slugs may continue to use `BGSE` because they do not enter game
resources or saved variables.

The chosen engine prefix will later be enforced by Task 17's COMP-I07 fake-game collision fixtures.
Task 4 owns the detailed provenance schema/register/allowlist, and G8 owns the publication audit;
neither later task may retroactively make an unresolved G0 collision safe.

## Evidence

- E0 project contracts: `AGENTS.md`, the architecture design, research backlog, implementation plan,
  and compatibility matrix.
- E0 WeiDU distribution guidance:
  <https://weidu.org/WeiDU/README-WeiDU.html#Module-Distribution-Conventions>.
- E0 community registration rules:
  <https://forums.blackwyrmlair.net/index.php?mode=threaded&pid=1805&showtopic=113&start=>.
- E1 pinned public registry mirror:
  <https://github.com/krionashnald/InfinityModForge-Personal/blob/34782745bfdfeb33013df17fb89cd29fbc0cb173/data/prefix-registry.json>.
- E1 pinned EET resource oracle:
  <https://github.com/Gibberlings3/EET/tree/74e91d72bca5d073fa11c1d088b90d7ff0c7105d/EET/other/BGEE_to_EET_mod_checker/BGEE_to_EET_mod_checker/lib>.
- E2 deterministic host scans reproduced the case-insensitive exact/ancestor/descendant registry
  and resource-prefix findings above.
- E2 structural validation: `scripts/validate-g0-decisions.ps1` checks Task 1 metadata, section
  bodies, safety fields, required G0 rows, evidence wording, and PREP artifact barriers. Its success
  does not change the gate status.
- No E3 fake-game, E4 disposable-engine, E5 soak, active-game, or Task 3 evidence was used.

### Reproduction commands

Prerequisites: PowerShell 7, `gh` with public GitHub API access, and network access. Run from the
repository root. The command references only pinned public GitHub content and no local game path.
Matching is ordinal case-insensitive. A registry conflict is an exact match or either string being a
prefix of the other; an EET hit is a resource row beginning with the candidate.

```powershell
$ErrorActionPreference = 'Stop'
$registryCommit = '34782745bfdfeb33013df17fb89cd29fbc0cb173'
$eetCommit = '74e91d72bca5d073fa11c1d088b90d7ff0c7105d'

$registry = gh api "repos/krionashnald/InfinityModForge-Personal/contents/data/prefix-registry.json?ref=$registryCommit" `
    -H 'Accept: application/vnd.github.raw+json' | ConvertFrom-Json
$registryRows = @($registry.project) + @($registry.personal)

function Get-RegistryHits([string]$Candidate) {
    @($registryRows | Where-Object {
        $registered = [string]$_.prefix
        $registered.StartsWith($Candidate, [StringComparison]::OrdinalIgnoreCase) -or
        $Candidate.StartsWith($registered, [StringComparison]::OrdinalIgnoreCase)
    })
}

$eetBase = 'EET/other/BGEE_to_EET_mod_checker/BGEE_to_EET_mod_checker/lib'
$eetFiles = @(gh api "repos/Gibberlings3/EET/contents/$eetBase`?ref=$eetCommit" |
    ConvertFrom-Json | Where-Object {
        $_.type -eq 'file' -and $_.name -match '^bg[12]_[A-Z0-9]+\.2da$'
    })
$resourceRows = [System.Collections.Generic.List[string]]::new()

foreach ($file in $eetFiles) {
    $body = gh api "repos/Gibberlings3/EET/contents/$eetBase/$($file.name)?ref=$eetCommit" `
        -H 'Accept: application/vnd.github.raw+json'
    foreach ($line in ($body -split '\r?\n')) {
        $value = $line.Trim()
        if ($value.Length -gt 0) {
            $resourceRows.Add($value)
        }
    }
}

$bgRows = @($registryRows | Where-Object { $_.prefix -ceq 'BG' })
$nestedExample = @($registryRows | Where-Object {
    $_.prefix -cin @('BS', 'BSM') -and $_.status -ceq 'Conflict'
})

"Registry rows: $($registryRows.Count) (project=$(@($registry.project).Count), personal=$(@($registry.personal).Count))"
"BG owner: $($bgRows[0].owner)"
"BS/BSM conflict rows: $($nestedExample.Count)"
"EET files: $($eetFiles.Count)"
"EET nonblank rows: $($resourceRows.Count)"

foreach ($candidate in @('BGSE', 'B-', 'E-', '#O', 'QG')) {
    $registryHits = @(Get-RegistryHits $candidate)
    $resourceHits = @($resourceRows | Where-Object {
        $_.StartsWith($candidate, [StringComparison]::OrdinalIgnoreCase)
    })
    "$candidate registry=$($registryHits.Count) EET=$($resourceHits.Count)"
}

$bgResourceHits = @($resourceRows | Where-Object {
    $_.StartsWith('BG', [StringComparison]::OrdinalIgnoreCase)
} | Sort-Object)
"BG EET rows: $($bgResourceHits -join ', ')"
```

Expected output for the pinned inputs:

```text
Registry rows: 828 (project=41, personal=787)
BG owner: Minotaur in Maze
BS/BSM conflict rows: 2
EET files: 34
EET nonblank rows: 53846
BGSE registry=1 EET=0
B- registry=0 EET=0
E- registry=0 EET=0
#O registry=0 EET=0
QG registry=0 EET=0
BG EET rows: BGDECBAR.MOS, BGPADB.MOS, BGPADL.MOS, BGPADR.MOS, BGUARD1.BCS, BGUARD1.CRE, BGUARD1.DLG
```

## Safety boundary

The active game and active playthrough were not accessed. No disposable game was created,
provisioned, launched, or mutated. Task 3 remains separately unauthorized. Research was limited to
repository files, public read-only sources, pinned public corpora, and deterministic host commands.

No upstream author, registry maintainer, or community was contacted, and no prefix was requested or
reserved.

## Open blockers

1. The user must select the engine-visible prefix: preliminary preference `B-`, or `E-`, `#O`,
   `QG`, or another candidate subjected to the same scan.
2. The selected prefix and derivation rules for resources, globals, locals, Lua roots, bootstrap
   names, adapter IDs, and host-only slugs must be recorded here before G0 can pass.
3. Read-only current-registry checks do not require additional authorization and must be rerun after
   selection when a usable service is available. Contacting maintainers or requesting a reservation
   remains separately blocked until the user explicitly authorizes that external action.

Exact dependency/tool versions are intentionally not G0 blockers; Task 2/PREP-01 owns them. Detailed
artifact-class provenance conclusions are intentionally not G0 blockers; Task 4/PREP-02/LIC owns
them under ADR 0005's reference-only shipping hold.

## Downstream authorization

Task 1 remains `in_progress`. G0 is pending, so Tasks 2 and 4 remain blocked and no runtime or
installer implementation begins. Task 3 additionally requires the user's separate explicit
authorization naming a disposable destination, regardless of future G0 status.

The completed taxonomy, plan corrections, validator, and ADR drafts are durable Task 1 artifacts and
may be reviewed while this gate is pending.

## Revisit when

Revisit immediately after the user selects a candidate. Re-run the pinned scans and any available
read-only current registry check before changing this status. Ask separately before contacting a
maintainer or requesting a reservation. Any collision retains `Pending` and requires a new
candidate; it is not waived.

## Review date

2026-08-30; next review is the user-owned namespace decision at G0.
