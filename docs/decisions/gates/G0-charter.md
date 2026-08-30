# G0: Charter gate

**Status:** Pass with narrowed scope

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

The compatibility charter, domain separation, evidence vocabulary, coarse platform scope, support
tiers, kill-switch policy, non-goals, WeiDU boundary, conservative SCS provenance policy, and
engine-visible namespace are approved at architecture level through ADRs 0001-0006 and this gate.

Christopher explicitly selected the ASCII prefix `B-` on 2026-08-30. G0 passes with narrowed scope:
`B-` is a locally allocated, syntax-checked, collision-screened project namespace, not a claim of a
current external reservation or global uniqueness across arbitrary mod stacks. Installation and
adapter registration must fail closed on an occupied resource, bootstrap, Lua root, adapter ID, or
exclusive private-variable claim. Contacting a maintainer or requesting a reservation remains a
separate external action that was not authorized or performed.

`BGSE` remains a repository, environment-variable, test, and documentation slug only; it is not an
Infinity Engine resource/global/local prefix or a Lua runtime root.

## Entry criteria

- Architecture draft and compatibility matrix exist and are internally reviewable.
- The prime unknown-content pass-through invariant is normative.
- Initial platform, terminology, safety boundaries, provenance hold points, support tiers,
  kill-switch behavior, and non-goals are explicit.
- A unique engine-visible namespace is chosen and collision-checked.
- Task and gate dependencies match the research backlog.

All G0 entry criteria are satisfied within the narrowed namespace scope recorded below. Required
evidence:E3 synthetic-game and evidence:E4 disposable-engine proof layers remain unexecuted and
gate later work separately.

## Criterion findings

| Criterion | Finding | Basis |
|---|---|---|
| Initial platform | Approved at charter level | Single-player BG2:EE/EET with EEex; exact versions, paths, and capability floors remain Task 2/PREP-01 work. |
| Unique engine namespace | **Approved with narrowed scope** | `B-` was explicitly selected, has zero exact/nested hits in the pinned registry mirror and zero prefix hits in the pinned EET filename corpus, and has syntax-checked derivations below. No current external reservation or arbitrary-stack uniqueness is claimed. |
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

`B-` is the selected collision-screened prefix. It is shared across both policy domains and leaves
the third character available for a stable domain marker. Revision-pinned WeiDU lexer/parser source,
the fixed-width resref/variable formats, revision-pinned EEex use of the hyphenated `X-en_US.lua`
resource, and deterministic host checks found no technical invalidity. This is not an external
reservation, evidence:E3 synthetic-game proof, or evidence:E4 engine-runtime guarantee.

The public mirror commit is dated 2026-05-03 and its newest row is dated 2026-03-27. The old live
database endpoint currently serves unrelated content, while forum retrieval was unreliable during
this review. The EET scan covers filenames in those 34 lists, not public globals/locals, Lua
bootstraps, or arbitrary mod stacks. A dated public GitHub code search also found no exact
`M_B-K.lua` filename, but that search is not a registry or a complete corpus. Therefore zero hits
mean "clear in these inspected sources," not "currently reserved" or "globally collision-free."

### Namespace derivation contract

All values below are ASCII. Validators accept only canonical case even when the engine compares a
class case-insensitively. Overlength, invalid, ambiguous, or colliding input is rejected before
publication; it is never truncated, silently case-normalized, or replaced by a digest-only
identity. Every shortened resource code must have a one-to-one logical-artifact allocation in the
future checked manifest/ledger before the resource is authored. Allocation IDs are host data keys,
not engine names. Duplicate or noncanonical logical IDs, duplicate codes, domain mismatches, and
case-folded collisions fail validation.

Every `B-` value is a quoted string (or WeiDU tilde-delimited string) when represented in BAF, D,
or WeiDU source. It is never emitted as an unquoted symbolic identifier.

| Identifier class | Exact derivation | Additional rule |
|---|---|---|
| Engine resource stem | `^B-[KCWX][A-Z0-9]{5}$` | Exactly eight characters. `K` = shared kernel/bridge, `C` = Combat Intent, `W` = WorldFlow, and `X` = synthetic experiment/test only. The five-character code is explicitly allocated, never derived by truncation. A stem is unique case-insensitively across all project resource types, even when extensions differ. `X` resources cannot enter a release publication allowlist. WeiDU paths and resource operands are tilde-delimited. |
| Allocation-ledger logical-artifact ID | `^(kernel\|combat\|worldflow\|synthetic)\.[a-z0-9]+(?:[.-][a-z0-9]+)*$` | Host-only exact-case ASCII key, maximum 64 characters. Its first component must map to `K`, `C`, `W`, or `X` respectively. It is never converted to an engine name: every mapping is explicit and one-to-one, and no adapter ID or logical ID is truncated or hashed into a resource stem. |
| Private GLOBAL/LOCALS/area variable or timer | `^B-[KCWX][GLA]-[A-Z0-9]+(?:-[A-Z0-9]+)*$` | Maximum 32 characters. The first marker is the domain above; `G`, `L`, or `A` must agree with the actual `GLOBAL`, `LOCALS`, or area/`MYAREA` scope. Names are always quoted in BAF/D. `X` variables/timers cannot enter release source or a production manifest. Existing public quest variables keep their established names and are not rewritten into this namespace. |
| Planned EE bootstrap | `M_B-K.lua` | This is the fixed project filename under the observed `M_` naming convention. An existing case-insensitive filename blocks installation before overwrite. The file must remain a guarded, idempotent loader. Autoload, ordering, and runtime safety are not G0 guarantees; they require later evidence:E4 at G1-G3. |
| Lua runtime root | `_G["B-"]` | Access only through a string key, normally `rawget(_G, "B-")`/`rawset`. A local alias may use a normal Lua identifier, but no public `B_`, `BGSE`, or bare `B-` global alias is created. An occupied root with the wrong type or project identity fails closed. |
| Lua module resource | Engine resource grammar above, for example `B-KCORE0.lua` | `Infinity_DoFile("B-KCORE0")` receives the quoted stem without `.lua`. The example is a grammar vector, not an allocation. Flat engine-loaded filenames remain eight characters or fewer. |
| First-party adapter ID | `^B-/(kernel\|combat\|worldflow)/[a-z0-9]+(?:-[a-z0-9]+)*$` | Quoted data key, maximum 64 ASCII characters, exact-case comparison. It is never used as a path, resref, or variable, and maps to resources only through an explicit allocation. Schema/API versions are separate fields. Third-party IDs must use their author's namespace under the future Task 38 contract. |
| Host-only names | `chriz-bg-script-engine`, `bgse`, and `BGSE_*` | Repository/package directory, short CLI/test/docs slug, and environment-variable prefix respectively. No mechanical derivation into engine resources, variables, the Lua root/bootstrap, or adapter IDs is permitted. |

Examples that satisfy the contract include resource stems `B-KCORE0`, `B-CMAGE0`, `B-WMINI0`,
and synthetic-only `B-XPROB0`; private names `B-KG-ENABLED`, `B-CL-LEASE`, and
`B-WG-MINI-PHASE`; logical-artifact IDs `kernel.core`, `combat.mage-pilot`,
`worldflow.mini-dialogue`, and `synthetic.probe`; and adapter IDs `B-/kernel/core`,
`B-/combat/scs-mage-pilot`, and `B-/worldflow/mini-quest`. These are syntax/collision vectors, not
reserved artifact allocations.

`scripts/validate-g0-namespace.ps1` encodes positive and negative boundary vectors, including
seven/eight/nine-character resources, 32/33-character variables, scope mismatches, invalid case and
punctuation, non-ASCII input, 64/65-character adapter IDs, a canonical cross-extension collision,
a separate lowercase rejection, 64/65-character logical-artifact IDs, logical-domain mismatches,
duplicate logical IDs, exact host-only slugs, host-slug leakage, case-insensitive bootstrap
occupancy, the quoted Lua root, and synthetic-only resource/variable release checks. It performs no
compiler or engine call; those proof layers remain separate and explicit.

## Compatibility

New private engine-visible artifacts use only the selected `B-` derivations above. Host-only
identifiers such as `BGSE_DISPOSABLE_GAME_ROOT`, repository names, test scenario IDs, and
documentation slugs may continue to use `BGSE` because they do not enter game resources, saved
variables, bootstrap files, Lua runtime roots, or adapter IDs.

The namespace grants no ownership over content merely because a resource or variable begins with
`B-`. An unknown pre-existing `B-` resource, `M_B-K.lua`, `_G["B-"]` root, adapter ID, or exclusive
private-variable claim is a collision: installation/registration declines before mutation and the
unknown content remains legacy-owned. Existing public quest variables and resource identities are
preserved exactly where an adapter declares them as compatibility ABI.

The chosen engine prefix will later be enforced by Task 17's COMP-I07 fake-game collision fixtures.
Task 4 owns the detailed provenance schema/register/allowlist, and G8 owns the publication audit;
neither later task may retroactively make an observed collision safe by overwriting, truncating, or
guessing a replacement.

## Evidence

- E0 project contracts: `AGENTS.md`, the architecture design, research backlog, implementation plan,
  and compatibility matrix.
- E0 WeiDU distribution guidance:
  <https://weidu.org/WeiDU/README-WeiDU.html#Module-Distribution-Conventions>.
- E0 Lua 5.1 identifier, table-key, and global-environment grammar:
  <https://www.lua.org/manual/5.1/manual.html#2.1>,
  <https://www.lua.org/manual/5.1/manual.html#2.3>, and
  <https://www.lua.org/manual/5.1/manual.html#pdf-_G>.
- E0 EEex/Beamdog loader inputs:
  <https://eeex-docs.readthedocs.io/en/latest/EE%20Game%20Lua%20Functions/Infinity/#infinity-dofile>
  and <https://forums.beamdog.com/discussion/57210/m-lua-files-and-bgee-lua>.
- E0 community registration rules:
  <https://forums.blackwyrmlair.net/index.php?mode=threaded&pid=1805&showtopic=113&start=>.
- E1 pinned public registry mirror:
  <https://github.com/krionashnald/InfinityModForge-Personal/blob/34782745bfdfeb33013df17fb89cd29fbc0cb173/data/prefix-registry.json>.
- E1 pinned EET resource oracle:
  <https://github.com/Gibberlings3/EET/tree/74e91d72bca5d073fa11c1d088b90d7ff0c7105d/EET/other/BGEE_to_EET_mod_checker/BGEE_to_EET_mod_checker/lib>.
- E1 pinned format/tool source: IESDP
  [resref](https://github.com/Gibberlings3/iesdp/blob/28326f4597722ddb2ea514df7f0472fdbad2c34e/file_formats/general.htm#L62),
  and [KEY](https://github.com/Gibberlings3/iesdp/blob/28326f4597722ddb2ea514df7f0472fdbad2c34e/file_formats/ie_formats/key_v1.htm#L12)
  definitions plus its
  [32-character variable rule](https://github.com/Gibberlings3/iesdp/blob/28326f4597722ddb2ea514df7f0472fdbad2c34e/appendices/variables.htm);
  GemRB's
  [case-insensitive eight-byte `ResRef`](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/includes/ie_types.h#L103-L104);
  Near Infinity's
  [length-checking resource editor](https://github.com/NearInfinityBrowser/NearInfinity/blob/50021b834e0360c6400a6a818626b50edabdd868/src/org/infinity/datatype/ResourceRef.java);
  and WeiDU's pinned
  [BAF lexer](https://github.com/WeiDUorg/weidu/blob/13f207b12833ce9bbbb119625a9b43b287738c52/src/baflexer.mll#L61-L79),
  [D lexer](https://github.com/WeiDUorg/weidu/blob/13f207b12833ce9bbbb119625a9b43b287738c52/src/dlexer.mll#L114-L123),
  [32-character variable check](https://github.com/WeiDUorg/weidu/blob/13f207b12833ce9bbbb119625a9b43b287738c52/src/bafparser.mly#L65-L94),
  and [low-level resref writer](https://github.com/WeiDUorg/weidu/blob/13f207b12833ce9bbbb119625a9b43b287738c52/src/util.ml#L308-L309).
- E1 pinned EEex hyphenated Lua-resource evidence: v0.11, v1.0, and v1.2 source loads the shipped
  `X-en_US.lua` resource through `Infinity_DoFile` at pinned commits
  [v0.11](https://github.com/Bubb13/EEex/blob/89e524640766aa61d6963070299eaaac86f883d8/EEex/copy/EEex_Menu.lua#L447-L450),
  [v1.0](https://github.com/Bubb13/EEex/blob/1487384cf4d5974482e596ca654bec35c340149a/EEex/copy/EEex_scripts/EEex_Menu.lua#L463-L466),
  and [v1.2](https://github.com/Bubb13/EEex/blob/204040502ac920161d60046d90b766b8d2d08152/EEex/copy/EEex_scripts/EEex_Menu.lua#L506-L509).
  The same v1.2 revision pins the shipped bootstrap filename
  [`M___EEex.lua`](https://github.com/Bubb13/EEex/blob/204040502ac920161d60046d90b766b8d2d08152/EEex/copy/override/M___EEex.lua).
  This is static filename evidence only; bootstrap autoload and ordering remain evidence:E4
  questions at G1-G3.
- E2 deterministic host scans reproduced the case-insensitive exact/ancestor/descendant registry
  and resource-prefix findings above.
- E2 syntax/contract validation: Lupa 2.8's `lupa.lua51` runtime reported `_VERSION=Lua 5.1` and no
  JIT; `lupa.luajit21` reported `_VERSION=Lua 5.1` and `LuaJIT 2.1.1774896198`. Both accepted
  `_G["B-"]` and rejected bare `B-` assignment. `scripts/validate-g0-namespace.ps1` exercised the
  deterministic grammar, boundary, scope, and collision vectors above. A WeiDU executable parser
  run was not used: Windows security blocked the downloaded v251 archive, so WeiDU syntax evidence
  in this gate is the revision-pinned lexer/parser source above, not an executed compiler claim.
- E2 structural validation: `scripts/validate-g0-decisions.ps1` checks Task 1 metadata, section
  bodies, safety fields, required G0 rows, namespace contract, terminal gate/task-state correlation,
  evidence wording, and PREP artifact barriers.
- No evidence:E3 fake-game, evidence:E4 disposable-engine, evidence:E5 soak, active-game, or Task 3
  evidence was used.

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

### Namespace grammar reproduction commands

These commands are host-only. They do not locate, create, or write a game. The GitHub code-search
result is a dated supplemental screen and may change; it is not a reservation check.

```powershell
& ./scripts/validate-g0-namespace.ps1

$pythonCode = @'
import lupa
from lupa import lua51, luajit21

print(f"lupa={lupa.__version__}")
for name, module in (("lua51", lua51), ("luajit21", luajit21)):
    runtime = module.LuaRuntime()
    lua_version = runtime.eval("_VERSION")
    jit_version = runtime.eval('jit and jit.version or "none"')
    runtime.execute('local root = {}; rawset(_G, "B-", root); assert(rawget(_G, "B-") == root); assert(_G["B-"] == root)')
    try:
        runtime.execute('B- = {}')
    except module.LuaSyntaxError:
        print(f"lupa.{name}: _VERSION={lua_version}, jit={jit_version}; quoted root accepted; bare identifier rejected")
    else:
        raise AssertionError(f"{name} accepted bare B-")
'@

python --version
python -c $pythonCode

$bootstrapSearch = gh api -X GET search/code -f q='filename:M_B-K.lua' -f per_page=100 |
    ConvertFrom-Json
"M_B-K.lua public GitHub code matches: $($bootstrapSearch.total_count)"
```

Observed on 2026-08-30:

```text
G0 namespace grammar and collision vectors passed.
Python 3.11.9
lupa=2.8
lupa.lua51: _VERSION=Lua 5.1, jit=none; quoted root accepted; bare identifier rejected
lupa.luajit21: _VERSION=Lua 5.1, jit=LuaJIT 2.1.1774896198; quoted root accepted; bare identifier rejected
M_B-K.lua public GitHub code matches: 0
```

No WeiDU executable output is listed because no WeiDU parser run is claimed at G0. The revision-pinned
WeiDU lexer/parser source above is the applicable static evidence; executable discovery and version
floor selection remain Task 2 work.

### TDD record

The core durable assertions were added to `scripts/validate-g0-decisions.ps1` before the charter or
task state changed. The intentional RED exited 1 and reported seven errors: the missing namespace
derivation section, resource grammar, variable grammar, bootstrap filename, Lua root, adapter-ID
grammar, and namespace validator. After the namespace validator existed but while this charter was
still pending, the focused namespace vectors passed and the main validator remained RED on the six
missing charter contracts. The explicit quoting assertion was added during final review and verified
against the completed charter.

A later independent adversarial review confirmed that the duplicate canonical `B-KCORE0` rows
reach the cross-extension collision branch rather than failing the grammar first. It also exposed
four omissions: case-insensitive bootstrap occupancy, production exclusion for `X` variables,
canonical logical-artifact IDs, and stale mechanical filename tokens in Tasks 8 and 11. Before the
plan or charter was corrected, the main validator was extended and produced a second intentional
RED with five errors: the missing logical-ID grammar, forbidden mechanical interpolation, and three
missing fixed/allocated host-plan paths. The namespace validator then gained direct occupancy,
release, logical-ID boundary, and logical/resource-domain vectors. After those corrections, the
specification review reproduced a GFM table split at the unescaped regex alternations; escaped-form
assertions produced a two-error RED before the table was corrected. A final evidence-taxonomy check
then produced a three-error RED for the evidence-layer/gate conflations identified by review before
each proof layer and authorization gate was named separately. Extending that check across the Task 1
ADRs and research backlog produced another three-error RED for ambiguous proof-layer shorthand;
those records now name required static, synthetic-integration, and runtime evidence separately. The
final GREEN outputs were:

```text
G0 namespace grammar and collision vectors passed.
Task 1 decision-record structure validation passed. G0 gate status: Pass with narrowed scope (evaluated separately).
```

## Safety boundary

The active game and active playthrough were not accessed. No disposable game was created,
provisioned, launched, or mutated. Task 3 remains separately unauthorized. Research was limited to
repository files, public read-only sources, pinned public corpora, and deterministic host commands.

No upstream author, registry maintainer, or community was contacted, and no prefix was requested or
reserved.

## Open blockers

None for Task 1 or G0 within the approved narrowed scope.

The unavailable authoritative current registry, lack of an external reservation, deferred
evidence:E3 synthetic integration, and deferred evidence:E4 runtime proof are declared limitations,
not silently waived evidence. A future usable read-only registry may be checked without additional
authorization. Contacting maintainers or requesting a reservation remains outside this decision and
requires explicit authorization.

Exact dependency/tool versions are intentionally not G0 blockers; Task 2/PREP-01 owns them. Detailed
artifact-class provenance conclusions are intentionally not G0 blockers; Task 4/PREP-02/LIC owns
them under ADR 0005's reference-only shipping hold.

## Downstream authorization

Task 1 is `completed` and releases Task 2's documented host/toolchain work. Task 4 remains pending
until Task 2 publishes and reviews `docs/research/PREP-01-support-baseline.md`; its dependency on
Task 1 alone does not waive that artifact barrier. No runtime or installer implementation begins at
G0.

Task 3 remains pending and separately requires Christopher's explicit authorization naming a
disposable destination. This G0 decision does not authorize provisioning, mutation, launch, or any
active-game interaction.

## Revisit when

Revisit if a current registry or stack inventory reports a `B-` or `M_B-K.lua` collision; a pinned
tool/source revision invalidates a syntax assumption; an evidence:E3 packaging/module counterexample
or evidence:E4 bootstrap/autoload counterexample invalidates an assumption; a case-insensitive
allocation collision reaches a manifest; or Task 17's COMP-I07 fixture cannot fail closed before
mutation. A real collision narrows, replaces, or fails the affected namespace claim; it is never
overwritten or waived. Ask separately before contacting a maintainer or requesting a reservation.

## Review date

2026-08-30; mandatory review on the first namespace counterexample or COMP-I07 implementation,
whichever comes first.
