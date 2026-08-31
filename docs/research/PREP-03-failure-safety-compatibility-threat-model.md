# PREP-03 failure, safety, and compatibility threat model

**Research ID:** PREP-03

**Status:** Conditional

**Date:** 2026-08-31

**Owners:** Integration owner; subsystem owners named per risk

**Domains:** Shared kernel and engine boundary, installer/adapters, Combat Intent, WorldFlow

**Applicable evidence:** evidence:E0 design and hazard inputs plus evidence:E1 revision-pinned
source and environment identities. Evidence:E4 disposable-engine proof and evidence:E5
supported-corpus soak are explicitly unexecuted.

## Question and outcome

Which failures can corrupt combat, quests, saves, install compatibility, or engine stability, and
how must each be prevented, contained, detected, handed back, recovered, owned, and validated?

**Outcome: Conditional.** This initial register satisfies the PREP-03 repository checkpoint: every
critical failure class named by the backlog, architecture, and acceptance matrix has at least one
prevention or containment control and one planned validation. It does not prove that any control
works inside the engine. A missing or failed control blocks only the affected feature or adapter;
an unknown high-severity native, persistence, ownership, or irreversible-side-effect risk blocks
the affected mutation path rather than becoming a known limitation.

Once independently reviewed, this result completes PREP-03's contribution to research gate RG0
only. It does not pass or supply entry evidence for G1. Evidence:E3, evidence:E4, and evidence:E5
are distinct, non-substitutable proof environments; no later-numbered result may erase a required
lower-layer proof or vice versa.

The governing response remains:

> Unknown, modified, stale, or ambiguous content remains under its original BCS/DLG ownership.
> A failed check disables only the affected adapter and yields to legacy behavior.

Combat Intent and WorldFlow are separate fault domains. Combat Intent state is ephemeral and may
own at most one ordinary action lease. WorldFlow state is durable, versioned, and may own only one
declared transition. Neither domain may use failure in the other as permission to broaden a claim.

## Environment and safety boundary

- **Host:** Windows 11 x64, OS version `10.0.26200.0`; PowerShell Core `7.6.5`; CPython `3.11.9`;
  pytest `8.4.2`; Git `2.55.0.windows.4`.
- **Repository snapshot:** commit `c1220d0f11e716181ab78b57314d46931ace7edd` on the existing
  Task 1/Task 2 worktree. Only repository documentation and Git objects were inspected.
- **Game boundary:** no game installation, save, loader, installed resource, `WeiDU.log`, or game
  process was searched, opened, written, or launched.
- **Lab boundary:** no disposable game was provisioned, inspected, or mutated. Task 3 still needs
  separate explicit authorization naming its destination.
- **Evidence boundary:** the matrix rows below are planned proof, not observed results. No
  evidence:E3 installation experiment, evidence:E4 engine experiment, or evidence:E5 soak was run
  for PREP-03. Host-side schema/checker results elsewhere in Task 2 do not prove these runtime
  controls.

## Pinned inputs and fingerprints

The Git blob IDs make the exact project inputs reproducible. Their contents remain E0 design or
policy inputs where they describe untested runtime behavior; pinning a design statement does not
promote that behavior to E1 engine evidence.

| Source ID | Exact identity | Fingerprint or version | Use in this register |
|---|---|---|---|
| `PJT-ARCH` | `c1220d0:docs/plans/2026-08-27-script-engine-architecture-design.md` | Git blob SHA-1 `93ea6a1b981047dfdd8d9bcd8713b04b95de9545` | Ownership hierarchy, persistence split, containment ladder, core hazards |
| `PJT-PLAN` | `c1220d0:docs/plans/2026-08-27-research-and-vertical-slices.md` | Git blob SHA-1 `9e901ff3df36952e34f3da2d39ae027f1acac40e` | Task 2 sequencing, gates, stop conditions, required evidence |
| `PJT-BACKLOG` | `c1220d0:docs/research/research-backlog.md` | Git blob SHA-1 `2f4785ebe0955d8d036585207088ed158437b0d1` | PREP-03 named hazard list and exit criterion |
| `PJT-MATRIX` | `c1220d0:docs/compatibility/acceptance-matrix.md` | Git blob SHA-1 `0bb4cf19cdec230b1b4457324c8c64c89ed6fa04` | Required evidence layers, gates, and `COMP-*` cases |
| `PJT-PREP01` | `c1220d0:docs/research/PREP-01-support-baseline.md` | Git blob SHA-1 `74c803a0678d391ee8fd0e09912e540156a87340` | Candidate ecosystem and deterministic no-claim behavior |
| `PJT-PREP02` | `c1220d0:docs/research/PREP-02-evidence-and-provenance-index.md` | Git blob SHA-1 `c80d9c853a0169b337ac54620cc2a44c86cff141` | Trace rules and the boundary between static evidence and runtime proof |
| `GAME-266` | Retained historical candidate only | BG2:EE `2.6.6.0`; `Baldur.exe` SHA-256 `FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580` | Candidate executable identity; not re-read and not current support evidence |
| `UP-EEEX-011` | EEex tag `v0.11.0-alpha`, commit [`89e524640766aa61d6963070299eaaac86f883d8`](https://github.com/Bubb13/EEex/tree/89e524640766aa61d6963070299eaaac86f883d8) | Release asset SHA-256 `BFC5133C8118A83AE4F6C5BFDFD40E8177F401A653E1CD5D4074AF082716D87B` from upstream metadata | Initial capability-profile source candidate; no native behavior inferred |
| `UP-WEIDU-251` | WeiDU tag `v251.00`, commit [`5d94cb73661d74a6fd5126ede39c4c7b3748e188`](https://github.com/WeiDUorg/weidu/tree/5d94cb73661d74a6fd5126ede39c4c7b3748e188) | Annotated tag object `ed63cc84e9e6c67a6edde635f6d9b88703865420`; Windows asset SHA-256 `A54C6198D6EBED8139793FCACB225500D563657C23FC775B840383F9750493D8` | Required future installer/compiler identity; executable unavailable and unexecuted here |
| `UP-EET-140` | EET tag `v14.0`, commit [`ad20ca29ae797e773fffb10c25537c1b1a674716`](https://github.com/Gibberlings3/EET/tree/ad20ca29ae797e773fffb10c25537c1b1a674716) | Exact source commit; no attached package digest | Candidate finalized campaign profile; version labels alone are insufficient |
| `UP-SCS-3521` | SCS tag `v35.21`, commit [`5dc240e9ff85d3909b6436e54b56297d3b61e33b`](https://github.com/Gibberlings3/SwordCoastStratagems/tree/5dc240e9ff85d3909b6436e54b56297d3b61e33b) | Pinned readme: 345,027 bytes, SHA-256 `1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA` | Optional SCS-family identity and provenance input; generated behavior still needs per-family evidence |
| `UP-SR-419` | Spell Revisions tag `v4.19`, commit [`e97435afeb14ff5c83cfa41e14c23940c9a0cf8e`](https://github.com/Gibberlings3/SpellRevisions/tree/e97435afeb14ff5c83cfa41e14c23940c9a0cf8e) | Release asset SHA-256 `E1F7E9E31E806FAE70850870E3F7103E30EB181D865AD3233C4DFB4EAA4E3185` from upstream metadata | Optional effective-spell-semantics candidate; no resref or semantic equivalence inferred |

The upstream asset digests were already recorded by PREP-01/PREP-02. They were not downloaded or
recomputed in this checkpoint. The SCS readme digest has an acquisition procedure in `PJT-PREP02`;
the other asset values remain upstream-metadata identities until a later authorized acquisition.

## Method and reproduction

1. Read the PREP-03 question, named hazards, and exit criterion from `PJT-BACKLOG`.
2. Read the ownership, persistence, failure-containment, compatibility, test, gate, and risk
   sections of `PJT-ARCH` and the complete acceptance-case catalog in `PJT-MATRIX`.
3. Read the candidate/no-claim boundaries in `PJT-PREP01` and the evidence-trace rules in
   `PJT-PREP02`.
4. Split hazards by responsible fault domain. Merge hazards only when they have the same owner,
   containment boundary, fallback, recovery, and validation path; otherwise retain separate rows.
5. Map every risk to at least one prevention/containment mechanism and one future validation with
   explicit evidence layer, gate, and acceptance or backlog case ID.
6. Classify current evidence separately from planned evidence. An acceptance matrix expectation is
   not a passing test, and an E1 source pin is not E4 runtime proof.

Read-only source pin reproduction from the repository root:

```powershell
$revision = 'c1220d0'
git rev-parse $revision
foreach ($path in @(
    'docs/plans/2026-08-27-script-engine-architecture-design.md',
    'docs/plans/2026-08-27-research-and-vertical-slices.md',
    'docs/research/research-backlog.md',
    'docs/compatibility/acceptance-matrix.md',
    'docs/research/PREP-01-support-baseline.md',
    'docs/research/PREP-02-evidence-and-provenance-index.md'
)) {
    git rev-parse "${revision}:$path"
}
```

Observed output was the commit and blob identities in the table above. The command reads Git
objects only and has no game path input.

## Assessment vocabulary

- **Severity — Critical:** can crash or lock the engine, poison or corrupt a save, make a quest
  materially incorrect, duplicate an irreversible effect, or silently suppress/overwrite content
  outside the declared claim. **High:** can invalidate release/install integrity or starve a domain
  broadly but has a deterministic no-mutation refusal path before gameplay damage is established.
- **Detectability:** `High` means deterministic pre-mutation detection is designed; `Medium` means
  bounded runtime observation or postcondition evidence is required; `Low` means the first reliable
  signal may be delayed state divergence, reload failure, hang, or process crash.
- **Reversibility:** `High` means no mutation occurs or exact restoration is designed;
  `Conditional` means recovery depends on a declared marker, postcondition, backup, or stable
  state; `Low` means automatic reversal cannot be promised after the effect escapes.
- **Blast radius:** the largest scope at risk before controls: candidate, actor/flow, adapter,
  domain, install/save, package/corpus, or process.

## Validation gaps that need dedicated scenarios

The acceptance matrix is a future minimum, but it does not contain a precise row for every hazard
discovered by PREP-03. The following local scenario IDs record real gaps; they are not aliases for
existing `COMP-*` rows and are not passing evidence. Before implementation reaches the named gate,
the integration owner must add them to the applicable backlog/test plan or add equivalent reviewed
acceptance rows.

| Scenario ID | Gap | Minimum planned proof | Gate relationship |
|---|---|---|---|
| `PREP03-PATH-01` | Active-game alias/hard-link/reparse/TOCTOU refusal and Task 3 named-destination authorization have no dedicated `COMP-*` row | evidence:E2 guard tests, then authorized Task 3 isolation/reset proof; no active-game write | G1 entry prerequisite, not G1 proof |
| `PREP03-NATIVE-01` | Native access violation and partial-sprite/load initialization are not exactly exercised by `COMP-X07`, which is a controlled Lua exception | evidence:E1 call-shape/source preflight plus one bounded evidence:E4 call-shape experiment; stop on first crash | G1 |
| `PREP03-HOOK-01` | A single correctly registered hook may fire earlier or more often than assumed, including repeated AI passes over unchanged semantic state | evidence:E4 cadence/safe-window measurement plus repeated unchanged-state and relative-write/action/transition probes; evidence:E5 cadence soak | G3/G8 |
| `PREP03-XDOMAIN-01` | No dedicated case injects a Combat Intent fault while WorldFlow remains healthy and the inverse | evidence:E2 domain-supervisor model plus evidence:E4 two-domain fault injection | G3/G7 |
| `PREP03-DIAG-01` | No dedicated case asserts secret/path/payload redaction and zero diagnostic mutation across every boundary | evidence:E2 format/property tests plus evidence:E4 bounded runtime emission and evidence:E5 log soak | G1/G8 |
| `PREP03-FAIR-01` | No single case proves perception-only inputs and ordinary action semantics versus direct-effect/forced-cast bypass | evidence:E2 snapshot/candidate tests plus evidence:E4 aura, casting, interruption, expenditure and target-legality proof | G4/G5 |

## Shared kernel, engine-boundary, install, and extension risks

### K-01 — Unknown, ambiguous, or conflicting content is claimed

- **Domain:** Shared eligibility/ownership kernel; both domains.
- **Failure mode:** A naming convention, class/hostility heuristic, fuzzy fingerprint, duplicate ID,
  or incomplete dependency closure promotes unknown content out of C0 and suppresses its BCS/DLG.
- **Severity:** Critical.
- **Detectability:** High before mutation when exact manifests and conflict checks exist; Low after a
  permissive claim silently takes ownership.
- **Reversibility:** High if refused before bridge publication or runtime claim; Conditional after a
  bridge has been installed.
- **Blast radius:** Adapter to unrelated third-party content and actors.
- **Prevention / containment:** Require exact selectors, initial whole-file hashes, complete declared
  dependencies/control closure, capabilities, non-overlapping exclusive claims, and a preserved
  legacy branch. Naming/prefix similarity never establishes eligibility.
- **Detection:** Validate manifests and the frozen ownership graph; reject duplicates, opaque syntax,
  missing dependencies, ambiguous canonicalization, and unexpected selector matches.
- **Fallback:** Keep the resource/actor/transition C0 and execute the original BCS/DLG path.
- **Recovery:** Quarantine only conflicting adapters, remove or regenerate only their bridges through
  WeiDU, refresh the manifest from the final effective stack, and require eligibility review again.
- **Responsible subsystem:** Install inventory, manifest validator, ownership graph, adapter loader.
- **Planned validation:** evidence:E2+E3+E4; G2/G8; `COMP-I01`–`COMP-I03`, `COMP-I07`,
  `COMP-SCS04`, `COMP-SCS05`, `COMP-API02`, `COMP-API03`, `COMP-API08`, `COMP-API10`.
- **Current evidence / uncertainty:** `PJT-ARCH`, `PJT-BACKLOG`, and `PJT-MATRIX` give E1
  traceability for the E0 rule. No parser/control-closure proof or E3/E4 pass exists; semantic
  fingerprints remain ineligible.

### K-02 — Effective resources, control closure, or stack identity drifts after installation

- **Domain:** Shared compatibility kernel; both domains.
- **Failure mode:** A later component replaces a claimed BCS/DLG/ARE/CRE slot, spell semantic,
  public-variable writer, or runtime asset while the old bridge still appears present; a missing or
  corrupt epoch/manifest is treated as current.
- **Severity:** Critical.
- **Detectability:** Medium; direct hashes are detectable, but external controllers and new public
  writers require refreshed closure scans.
- **Reversibility:** High before a stale adapter acts; Conditional after a world mutation.
- **Blast radius:** Adapter, actor family, or WorldFlow quest.
- **Prevention / containment:** Bind activation to an immutable stack epoch and full dependency
  fingerprints; make both domains stale on unknown drift; require Combat Intent external-control
  closure and WorldFlow public-state reverse references before reactivation.
- **Detection:** Compare normalized epoch, exact dependencies, script slots, capability/bootstrap
  identities, and reader/writer sets at install refresh and runtime claim boundaries.
- **Fallback:** Mark only affected claims stale/ineligible and leave later effective content in
  legacy ownership. Ambiguous or unreadable epoch means mutation-free pass-through.
- **Recovery:** Perform a read-only tail refresh after the stack is final, review changed closure,
  regenerate affected manifests/bridges, and reactivate only exact reviewed variants.
- **Responsible subsystem:** Stack inventory, dependency graph, fingerprint service, runtime
  eligibility boundary.
- **Planned validation:** evidence:E3+E4; G2/G8; `COMP-I02`, `COMP-I04`–`COMP-I06`,
  `COMP-I10`–`COMP-I12`, `COMP-D07`, `COMP-A06`, `COMP-A08`.
- **Current evidence / uncertainty:** Fail-closed behavior is an E0 requirement pinned by
  `PJT-PREP01`; stack canonicalization, refresh safety, Combat Intent control closure, and WorldFlow
  reverse-reference completeness are unresolved P0 research.

### K-03 — EEex/runtime capability is absent, mixed, stale, or partially removed

- **Domain:** Engine boundary, bootstrap, installer.
- **Failure mode:** A version label substitutes for capabilities; mixed v0.11/v1 layouts are guessed;
  a bridge calls missing Lua/native symbols; or compiled triggers/actions remain after the bootstrap
  or EEex is removed.
- **Severity:** Critical.
- **Detectability:** High for static layout/configuration mismatch; Low for unproved partial-removal
  runtime semantics.
- **Reversibility:** High if refused before payload/TLK mutation; Low if partial removal leaves an
  unsafe compiled bridge in a running/save-bearing install.
- **Blast radius:** Domain, install, or process.
- **Prevention / containment:** Use version-specific capability profiles, reject mixed layouts, gate
  components before mutation, make absent bootstrap handlers decline, and block unsupported EEex
  removal order until exact E4 behavior/restoration is known.
- **Detection:** Installer preflight plus runtime symbol/layout/bootstrap probes, with missing optional
  capability disabling only its dependent feature.
- **Fallback:** Keep active components uninstalled/inert and legacy artifacts usable. Partial EEex
  removal with compiled bridges is `unsupported`, not claimed safe fallthrough.
- **Recovery:** Shut down the disposable process, restore the exact supported runtime/bridge set or
  restore legacy resources through WeiDU, then re-run the complete capability profile.
- **Responsible subsystem:** WeiDU installer, bootstrap, versioned EEex adapter, capability service.
- **Planned validation:** evidence:E3+E4; G1/G2/G8; `COMP-X01`–`COMP-X05`, `COMP-X08`,
  `COMP-X09`, `COMP-I06`, `COMP-P12`.
- **Current evidence / uncertainty:** `UP-EEEX-011` pins a source candidate and `PJT-PREP01` pins
  non-claim policy. No EEex symbol, bootstrap lifecycle, bridge-removal, or loader behavior was
  executed. `COMP-X09` remains explicitly unknown.

### K-04 — Unsafe native access or partially initialized engine objects crash the process

- **Domain:** Versioned EEex/native engine boundary.
- **Failure mode:** A wrong argument type/layout, unsupported native symbol, stale pointer, or callback
  during partial sprite/load construction reaches C++; `pcall`/`xpcall` cannot catch an access
  violation.
- **Severity:** Critical.
- **Detectability:** Low; a native crash may be the first reliable observation.
- **Reversibility:** Low for an unsaved session and possibly the save if mutation serialized before
  crash; High only when the call is rejected before native entry.
- **Blast radius:** Process and potentially current save.
- **Prevention / containment:** Keep native calls behind a narrow versioned boundary; validate symbol,
  object lifecycle, scalar argument shape, and capability before entry; never probe a suspected
  crash call repeatedly; exclude partial-load callbacks until proved safe.
- **Detection:** Boundary assertions and reason-coded refusal before call; disposable crash logs and
  an independent world/save postcondition after engine progress. Lua exception handling is not
  native-crash detection.
- **Fallback:** Disable the dependent capability/adapter or enter kernel-wide mutation-free safe mode
  when the boundary itself is uncertain.
- **Recovery:** Stop after the first native crash, preserve crash artifacts, record the exact call
  shape/profile, restore the disposable baseline, and quarantine the capability pending review.
- **Responsible subsystem:** EEex adapter, boundary preflight, lifecycle observer, crash procedure.
- **Planned validation:** evidence:E1+E4; G1/G5; `PREP03-NATIVE-01`; adjacent cases
  `COMP-X01`, `COMP-X05`, `COMP-X07`, `COMP-P11`; backlog cases `EEEX-01`, `EEEX-02`,
  `EEEX-05`. No current `COMP-*` row directly exercises a native access violation or partially
  initialized object; `COMP-X07` is controlled Lua-exception coverage only.
- **Current evidence / uncertainty:** `UP-EEEX-011` is an exact source identity, but no relevant
  source call path was adjudicated by this memo and no native call ran. Partial initialization and
  crash behavior remain hypotheses requiring one-call-shape-at-a-time E4 proof.

### K-05 — Listener registration or callback cadence duplicates work

- **Domain:** Shared bootstrap and observer lifecycle.
- **Failure mode:** Hot reload, area/load transitions, or repeated initialization append callbacks;
  or one correctly registered hook fires earlier or much more often than assumed. Repeated callbacks
  over unchanged semantic state can duplicate relative writes, actions, traces, or WorldFlow
  transitions even when registration itself is unique.
- **Severity:** Critical.
- **Detectability:** Medium through registration/dispatch counters; Low if duplicate side effects are
  first noticed much later.
- **Reversibility:** Conditional; duplicate ephemeral observers can be disabled, but emitted world
  effects may not be reversible.
- **Blast radius:** Domain or every enrolled actor/flow.
- **Prevention / containment:** Register stable root-level trampolines once; swap versioned delegate
  tables atomically; use generation/registration guards; measure cadence and safe-access windows;
  coalesce on stable semantic event/state identities rather than raw callback count; prefer absolute
  or monotonic idempotent writes; and never queue an action or advance a durable transition without
  fresh ownership, postcondition, and one-shot-claim checks. Never let reload append anonymous
  listeners.
- **Detection:** Record raw callback cadence, registration IDs/generations, safe-access state, and
  coalesced decisions. Hold semantic state unchanged across repeated AI passes, then assert zero
  duplicate relative write/action/transition across reload, area change, save load, and
  disable/re-enable.
- **Fallback:** Disable the affected observer/domain and preserve legacy evaluation; do not clear
  engine queues or compensate without ownership proof.
- **Recovery:** Remove/retire only owned registrations where the profile proves it, reload a clean
  bootstrap generation, and re-establish eligibility before enabling.
- **Responsible subsystem:** Bootstrap lifecycle manager and event boundary.
- **Planned validation:** evidence:E4+E5; G3/G8; `PREP03-HOOK-01`, `COMP-X06`, `COMP-X10`,
  `COMP-P12`; backlog cases `EEEX-02`, `EEEX-05`, `TEST-08`.
- **Current evidence / uncertainty:** Single-registration is a revision-pinned E0 architecture rule.
  Callback cadence, safe-access windows, and semantic coalescing are unresolved. No callback
  registration, repeated unchanged-state pass, hot reload, area transition, or load cycle executed.

### K-06 — Unsafe runtime identity or scalar payload is persisted

- **Domain:** Shared persistence boundary.
- **Failure mode:** Userdata, pointers, raw object IDs, action-queue owners, cyclic/aliased tables, or
  unsupported scalars enter a save; a missing handler strips/corrupts data; a recycled identity is
  attached to another object.
- **Severity:** Critical.
- **Detectability:** Medium with export validation and payload inspection; Low if the defect appears
  only on later load/resave.
- **Reversibility:** Low after a save is poisoned or unrelated handler data is stripped; High before
  serialization.
- **Blast radius:** Save, actor/flow, and potentially process on load.
- **Prevention / containment:** Persist only stable IDs, schema/version, numbers, strings, and acyclic
  sanitized tables; use numeric 0/1 where the declared v0.11 profile requires it; never persist
  Combat Intent leases/plans/targets; define handler-absent behavior per profile.
- **Detection:** Validate fresh export copies, reject cycles/unsupported types, inspect representative
  payloads, and compare load/resave behavior with and without each handler.
- **Fallback:** Refuse the dependent durable feature before it writes; Combat Intent discards all
  ephemeral identity and re-resolves after lifecycle discontinuity.
- **Recovery:** Load only a known-good prior save or run an explicitly reviewed schema-specific
  recovery; never guess pointer/object identity from serialized numbers.
- **Responsible subsystem:** Persistence serializer, schema registry, identity resolver.
- **Planned validation:** evidence:E1+E2+E4; G5/G7/G8; `COMP-P03`, `COMP-P05`,
  `COMP-P06`, `COMP-P09`–`COMP-P11`.
- **Current evidence / uncertainty:** `PJT-ARCH` pins the allowed payload rule and `PJT-MATRIX`
  defines required tests. No save bytes, marshal handler, handler-absence path, or object-reuse
  lifecycle was inspected in this checkpoint.

### K-07 — Fault containment, circuit breaking, or diagnostics widen the failure

- **Domain:** Shared error boundary and diagnostics.
- **Failure mode:** One candidate/actor/adapter exception disables unrelated behavior, repeats every
  tick, clears queues, mutates quest state while reporting, or is silently masked and treated as
  success.
- **Severity:** Critical.
- **Detectability:** Medium; controlled fault injection can prove scope and bounded emission.
- **Reversibility:** High when failure occurs before mutation; Conditional after a partial action or
  transition.
- **Blast radius:** Candidate through kernel, depending on a broken containment boundary.
- **Prevention / containment:** Preserve the candidate → actor/flow → adapter → domain → kernel
  hierarchy; wrap only labeled engine boundaries while leaving internals loud in tests; bound
  retries/diagnostics; represent unknown outcomes explicitly; prohibit diagnostic mutation.
- **Detection:** Fault-inject every boundary and assert exact quarantine scope, legacy fallthrough,
  one/bounded diagnostic, and no post-failure mutation.
- **Fallback:** Reject candidate, release actor/flow, quarantine adapter, disable one domain, or enter
  read-only safe mode—whichever is the smallest safe scope.
- **Recovery:** Require a fresh capability/eligibility check and explicit circuit reset; reconcile
  only owned durable transitions and never replay an unknown action as successful.
- **Responsible subsystem:** Boundary wrappers, circuit breaker, diagnostics, domain supervisors.
- **Planned validation:** evidence:E2+E4; G1/G5/G7/G8; `COMP-B03`, `COMP-B11`, `COMP-B12`,
  `COMP-X05`, `COMP-X07`, `COMP-P12`.
- **Current evidence / uncertainty:** Containment order is E0 policy pinned by `PJT-ARCH`; no
  injected Lua/native/policy failure or diagnostic-rate test ran.

### K-08 — Install, reinstall, disable, or uninstall damages the effective stack

- **Domain:** WeiDU installer, artifact publisher, lifecycle handback.
- **Failure mode:** Installation overwrites unowned files/TLK state, uninstall removes another mod's
  artifact, a component targets an intermediate pre-`EET_end` shape, a locked/failed TLK update
  leaves dangling references, mid-stack reinstall changes later content, compiled bridges survive
  without runtime, or disable/uninstall occurs while owned state is not legacy-safe.
- **Severity:** Critical.
- **Detectability:** High in a synthetic byte-exact harness for artifacts; Medium for runtime and save
  handback.
- **Reversibility:** Conditional on intact WeiDU backups, allowlists, and every persisted state having
  a legacy-safe or deterministic recovery path.
- **Blast radius:** Entire mod stack, save, and both domains.
- **Prevention / containment:** Keep WeiDU as installer of record; publish only allowlisted files;
  require the declared finalized stack/`EET_end` state and a closed game process before installer
  mutation; test byte-exact restoration and supported mid-stack semantics; preserve original
  bridges/scripts; and admit only persisted phases that are already legacy-safe or have a
  deterministic recovery path executable independently of the runtime being removed. Correctness
  must not depend on the player remembering a detach step before uninstall.
- **Detection:** Synthetic install/reinstall/uninstall diffs plus E4 disable/uninstall at every
  reachable lease/flow phase, including offline saves not opened by the installer, and post-restore
  legacy execution checks.
- **Fallback:** If safe independent handback cannot be guaranteed for every supported persisted
  phase, do not ship the runtime-dependent claim; keep the flow legacy-owned from the start. An
  installer must not infer that all offline saves were inspected.
- **Recovery:** Restore through the original WeiDU stack/backups, not manual `WeiDU.log` edits. Any
  required durable-state reconciliation must remain executable after runtime removal and without a
  remembered pre-uninstall detach step.
- **Responsible subsystem:** WeiDU package, publication allowlist, domain lifecycle managers.
- **Planned validation:** evidence:E3+E4; G1/G2/G5/G7; `COMP-I08`, `COMP-I09`, `COMP-B09`,
  `COMP-X03`, `COMP-X08`, `COMP-X09`, `COMP-P07`, `COMP-P08`, `COMP-A08`.
- **Current evidence / uncertainty:** Installer/restoration expectations are E0 and the WeiDU source
  candidate is pinned as `UP-WEIDU-251`; no WeiDU executable, fake game, game install, disable, or
  uninstall was run. In-flight removal remains unproved.

### K-09 — Runtime cost or diagnostics starve legacy behavior

- **Domain:** Shared scheduler, resource cache, tracing, diagnostics.
- **Failure mode:** Per-tick scans, allocation/GC, spatial queries, capability checks, or unbounded
  logs scale with actors/flows until legacy AI, input, saving, or engine stability is impaired.
- **Severity:** High; Critical if starvation causes watchdog/cutscene/action failure or save damage.
- **Detectability:** Medium with baseline counters and soak; poor without explicit budgets.
- **Reversibility:** High if degradation disables enhancements before starvation; Conditional after
  runaway logs/state growth.
- **Blast radius:** Domain to process and storage.
- **Prevention / containment:** Event/staggered scheduling, dirty-state caching, bounded traces,
  rate-limited diagnostics, actor/flow caps, measured budgets, and a deterministic degradation
  ladder ending in read-only/pass-through.
- **Detection:** Compare unmodified/observer/active CPU, allocations, GC, memory, log and save size
  under representative actor/flow counts and long-run failure injection.
- **Fallback:** Disable expensive candidate classes, tracing, adapter families, then the affected
  domain before legacy behavior is starved.
- **Recovery:** Clear only owned ephemeral caches/log buffers, restart from a clean process if
  required, and keep the feature disabled until its budget is re-proved.
- **Responsible subsystem:** Scheduler, cache, diagnostics, performance circuit breaker.
- **Planned validation:** evidence:E4+E5; G3/G8; `COMP-X10`; backlog cases `PERF-01`–`PERF-05`,
  `TEST-08`.
- **Current evidence / uncertainty:** Only the need for budgets is pinned. No engine baseline,
  scheduler measurement, actor-count stress, save-size measurement, or soak was executed.

### K-10 — Extension registration introduces collisions or unsafe operations

- **Domain:** Future mod-author extension API.
- **Failure mode:** Duplicate IDs, incompatible API ranges, overlapping exclusive claims,
  registration-order dependence, malformed typed actions, unknown fields, or raw native/BCS escape
  paths bypass ownership and validation.
- **Severity:** Critical.
- **Detectability:** High before mutation with a deterministic frozen registry.
- **Reversibility:** High when registration is transactional and pre-mutation; Conditional after any
  partial publication or durable state.
- **Blast radius:** Adapter, claimed resources, or kernel boundary.
- **Prevention / containment:** Declarative namespaced/versioned schema; validate then freeze the
  ownership graph; reject ambiguous precedence and raw calls; make registration order immaterial;
  keep removed extensions' content C0.
- **Detection:** Deterministic property/ordering tests, collision corpus, malformed descriptor tests,
  and synthetic cooperative-mod install/uninstall.
- **Fallback:** Reject the entire offending registration with no partial mutation and quarantine
  both sides of unresolved exclusive conflicts.
- **Recovery:** Remove inert extension metadata, restore C0 pass-through, and require a new compatible
  registration/version; do not reinterpret unknown saved fields.
- **Responsible subsystem:** Extension schema validator, registry, ownership graph, typed boundary.
- **Planned validation:** evidence:E2+E3+E4; G2/G8; `COMP-API01`–`COMP-API10`, `COMP-I07`.
- **Current evidence / uncertainty:** This is a future API contract only. No extension runtime,
  schema range, typed action, registration-order, or synthetic extension test exists yet.

### K-11 — Provenance or packaging redistributes forbidden artifacts

- **Domain:** Research corpus, migration ledger, packaging/release.
- **Failure mode:** Installed game resources, saves, TLK, binaries, full SCS source/generated BCS,
  or personal-path logs enter fixtures or release artifacts; derived knowledge loses attribution or
  source identity.
- **Severity:** High for repository/release integrity and potentially irreversible distribution.
- **Detectability:** High before publication with a complete allowlist; Low after external copies
  propagate.
- **Reversibility:** Low after publication; High while packaging remains blocked.
- **Blast radius:** Repository, release package, upstream relationships, and supported corpus.
- **Prevention / containment:** Artifact-level provenance records, original/derived separation,
  explicit redistribution classification, synthetic/minimal fixtures, visible credit, and a
  deny-by-default publication allowlist.
- **Detection:** Scan staged/package manifests, validate every artifact's source/revision/digest,
  transformation and distribution decision, and independently inspect positive/negative fixtures.
- **Fallback:** Do not package or release unclassified content; keep upstream material reference-only
  and generate metadata/fingerprints locally.
- **Recovery:** Remove the artifact from repository/package, preserve an audit record, rebuild from
  allowed synthetic/independently authored inputs, and notify/coordinate only with explicit user
  authorization if external publication occurred.
- **Responsible subsystem:** Provenance ledger, fixture allowlist, package builder, release review.
- **Planned validation:** evidence:E1+E2+E3; G8; backlog cases `LIC-01`–`LIC-04`, `TEST-03`,
  `IR-05`; Task 41 publication/security review.
- **Current evidence / uncertainty:** `PJT-PREP02` provides a pinned SCS statement and E1 provenance
  chain, but its conservative interpretation is E0 policy, not legal advice or redistribution
  permission. The final allowlist and package audit are not complete.

### K-12 — A host or lab operation reaches the active game or an unapproved destination

- **Domain:** Host environment guard, Task 3 provision/reset tooling, execution governance.
- **Failure mode:** A lexical alias, 8.3 path, junction/reparse point, hard link, descendant escape,
  marker spoof, broad directory target, or check/use race directs a write into the active game; a
  disposable lab is provisioned without separate authorization naming its destination.
- **Severity:** Critical.
- **Detectability:** High for known preflight forms; Medium for time-of-check/time-of-use changes
  unless identity is revalidated immediately before every write.
- **Reversibility:** Low after active installation/save mutation; High when refused before mutation.
- **Blast radius:** Active installation, playthrough, mod stack, and personal state.
- **Prevention / containment:** Require explicit active/disposable roots and exact intended file
  targets, a strict exact-root disposable marker, local fixed-volume physical identity checks,
  reparse/hard-link/directory-scope refusal, repeated guard immediately before mutation, process
  isolation, and separate user authorization naming the Task 3 destination.
- **Detection:** Synthetic temporary-directory alias/reparse/hard-link/escape cases plus authorized
  source/destination identity, shared-userdir, loader/log/save and reset-isolation checks. A prior
  safe result is never a durable authorization token.
- **Fallback:** Exit before all writes. Missing/ambiguous path, marker, identity, authorization, or
  intended-target information is refusal, not a best-effort lab.
- **Recovery:** Stop immediately, preserve evidence, and do not attempt automated cleanup of an
  active game. The integration owner and user decide restoration from known backups; re-provision
  only a separately authorized destination.
- **Responsible subsystem:** Environment checker, provisioning/reset scripts, task/gate runner,
  integration owner.
- **Planned validation:** evidence:E2 followed by separately authorized isolation/reset proof;
  G1 entry prerequisite; `PREP03-PATH-01`; backlog cases `TEST-05`, `TEST-06`, `LIC-03` and Task 3
  guard/reset tests. There is no dedicated `COMP-*` row.
- **Current evidence / uncertainty:** `PJT-PLAN` and `PJT-BACKLOG` pin the no-active-game and Task 3
  authorization rules. The Task 2 checker protects exact game-root file targets and refuses existing
  directory scopes; it does not yet authorize or protect separate documents/save/config/log/evidence
  roots. Task 3 must stop until that multi-root ownership contract is separately reviewed. No lab or
  game path was used. Filesystem TOCTOU remains a residual risk even after a read-only preflight.

### K-13 — Diagnostics leak paths, secrets, payloads, or unbounded data

- **Domain:** Shared diagnostics, evidence export, crash/log handling.
- **Failure mode:** Errors include personal absolute paths, credentials, save/TLK/upstream payloads,
  action strings, or unbounded repeated state; logging itself mutates gameplay or exhausts storage.
- **Severity:** High; Critical when a leaked payload is redistributed or log growth destabilizes the
  process/install.
- **Detectability:** High with format/property tests and package review; Medium for native crash
  artifacts and long-run repetition.
- **Reversibility:** Conditional before publication; Low after external disclosure.
- **Blast radius:** User privacy, repository/package, disk, and process.
- **Prevention / containment:** Structured reason codes and scalar/provenance identities only;
  redact/omit absolute paths, secrets and copyrighted payloads; cap message size/rate/count;
  separate evidence export from game mutation; diagnostics never write quest/combat state.
- **Detection:** Inject synthetic sensitive paths/tokens/payload-shaped text and repeated failures,
  then assert exact redaction, bounded output, no state mutation, and allowlisted evidence/package
  contents.
- **Fallback:** Suppress unsafe detail, retain a bounded correlation/reason code, and disable the
  emitting adapter/domain if safe reporting cannot be guaranteed.
- **Recovery:** Quarantine/remove unsafe logs before publication, rotate bounded host-only evidence,
  invalidate any exposed credential through the owning service, and fix the emitter before reenable.
- **Responsible subsystem:** Diagnostic formatter/rate limiter, evidence exporter, package review.
- **Planned validation:** evidence:E2+E4+E5; G1/G8; `PREP03-DIAG-01`; adjacent cases
  `COMP-X07`, `COMP-X10`, and backlog case `LIC-03`. No current `COMP-*` row covers path/secret
  redaction exactly.
- **Current evidence / uncertainty:** Bounded non-mutating diagnostics are E0 policy. No diagnostic
  format, synthetic leakage test, runtime emission, crash artifact, or soak exists.

### K-14 — A domain fault crosses the Combat Intent/WorldFlow boundary

- **Domain:** Shared kernel supervisors with separate Combat Intent and WorldFlow policy/state.
- **Failure mode:** A Combat policy failure disables/reconciles WorldFlow, a WorldFlow fault leaves
  Combat leases alive or broadens combat ownership, or a shared-kernel fallback confuses ephemeral
  and durable state.
- **Severity:** Critical.
- **Detectability:** Medium through explicit two-domain fault injection and independent state traces.
- **Reversibility:** High before mutation; Conditional if a durable WorldFlow transition or combat
  action has already started.
- **Blast radius:** Both domains, quest, encounter, save.
- **Prevention / containment:** Separate stores, supervisors, feature flags, kill switches, lease and
  claim types, recovery policies, and adapter circuits; only a kernel/native capability fault may
  force both into mutation-free safe mode, never into broader ownership.
- **Detection:** Inject candidate/actor/adapter/domain faults in each domain while the other has an
  eligible but nonconflicting workload; assert only the named scope changes and public/durable state
  remains untouched by Combat recovery.
- **Fallback:** Disable only the faulted actor/flow, adapter, or domain. At shared native uncertainty,
  both domains become read-only and all original BCS/DLG remains authoritative.
- **Recovery:** Revalidate and reset only the faulted circuit/store; reconcile an owned durable flow
  independently; discard Combat ephemeral state rather than persisting or importing it.
- **Responsible subsystem:** Kernel/domain supervisors, kill-switch service, persistence boundary.
- **Planned validation:** evidence:E2+E4; G3/G7; `PREP03-XDOMAIN-01`; adjacent cases
  `COMP-B11`, `COMP-B12`, `COMP-X05`, `COMP-P12`. No current `COMP-*` row directly exercises
  cross-domain fault isolation.
- **Current evidence / uncertainty:** Separation and the containment hierarchy are E0 decisions
  pinned by `PJT-ARCH`. No two-domain runtime or fault-injection harness exists.

## Combat Intent risks

### CI-01 — Queue acceptance is mistaken for start or completion

- **Domain:** Combat Intent action lifecycle.
- **Failure mode:** An accepted action is delayed, suppressed, cleared, interrupted, or never starts,
  yet policy records success, retries, consumes a plan step, or queues a conflicting action.
- **Severity:** Critical.
- **Detectability:** Medium; acceptance is observable but completion needs action-family-specific
  events and postconditions.
- **Reversibility:** Conditional; an unstarted request can expire, while a late or partial spell may
  not be reversible.
- **Blast radius:** Actor, target, encounter.
- **Prevention / containment:** End the dispatch lease on queue result; create a read-only in-flight
  token with distinct accepted/started/completed/failed/interrupted/invalidated/timed-out/unknown
  states; block conflicting Combat Intent claims; use finite timeouts and no success inference.
- **Detection:** Correlate action-family start/outcome observations with scalar postconditions and
  resource/aura state after engine progress; deliberately suppress/delay events.
- **Fallback:** While unresolved, yield to player/higher/legacy control without clearing their queue;
  on unknown timeout, release Combat Intent state and report unknown rather than retry as success.
- **Recovery:** Reobserve current engine state, release reservations, and replan only if a new lease
  is independently legal; never compensate an unknown action generically.
- **Responsible subsystem:** Action dispatcher, attempt observer, reservation ledger.
- **Planned validation:** evidence:E4; G5; `COMP-B04`–`COMP-B06`, `COMP-P03`; backlog cases
  `ACT-01`, `ACT-02`, `ACT-04`.
- **Current evidence / uncertainty:** The E0 rule is revision-pinned in `PJT-ARCH` and
  `PJT-PREP02`. No action was queued or observed; generic versus family-specific outcomes remain an
  open research question.

### CI-02 — Script-slot shadowing or encounter priority suppresses legacy choreography

- **Domain:** Combat Intent BCS handoff and ownership arbitration.
- **Failure mode:** A bridge is inserted above `NoAction()` staging, reorders `Continue()` behavior,
  replaces a runtime script slot, hardcodes an SCS-generated resref, or acts while a higher
  encounter/world controller owns the actor.
- **Severity:** Critical.
- **Detectability:** Medium; direct slot changes are visible statically, while external-control
  ownership requires runtime and closure evidence.
- **Reversibility:** High before dispatch; Conditional after encounter choreography is skipped.
- **Blast radius:** Actor, encounter, and quest phase.
- **Prevention / containment:** Preserve script identity and higher blocks; use only a reviewed
  generic handoff; never mutate normal production script slots at runtime; exact-register actors;
  treat higher world/encounter ownership as absolute.
- **Detection:** Analyze ordered BCS/slot topology and effective CRE assignments, inventory external
  controllers, and trace that the handoff is reached exactly once only after higher logic declines.
- **Fallback:** Bridge returns false/declines and the original block/script evaluation continues.
- **Recovery:** Disable/quarantine the adapter, restore published artifacts through WeiDU if needed,
  and refresh against the final effective scripts; never force an earlier slot assignment back.
- **Responsible subsystem:** BCS bridge generator, ownership arbiter, effective-resource inventory.
- **Planned validation:** evidence:E3+E4; G1/G2/G4/G5; `COMP-B01`–`COMP-B03`, `COMP-B09`,
  `COMP-B10`, `COMP-I05`, `COMP-SCS02`, `COMP-SCS06`.
- **Current evidence / uncertainty:** The priority rules are pinned E0 design. Safe same-resref versus
  sidecar handoff and complete external-control closure remain P0 unknowns; no BCS bridge ran.

### CI-03 — Actor, target, ownership, or legality changes between decision and dispatch

- **Domain:** Combat Intent snapshot, lease, and dispatcher.
- **Failure mode:** Target dies/despawns/moves, actor is charmed/replaced, aura/action state changes,
  higher ownership begins, or resource legality changes after scoring but before queueing.
- **Severity:** Critical.
- **Detectability:** High at a deliberately immediate revalidation boundary; Low if policy trusts a
  stale decision snapshot.
- **Reversibility:** High before queue; Conditional after an illegal/wrong action starts.
- **Blast radius:** Actor and target; encounter for AoE or choreography-sensitive actions.
- **Prevention / containment:** Keep decision snapshots immutable, leases short, and revalidate actor,
  target, higher authority, aura/action, range/LOS/fairness and effective semantic identity
  immediately before dispatch.
- **Detection:** Fault-inject each state change between scoring and dispatch and require a
  reason-coded rejection with no queue mutation.
- **Fallback:** Release the lease and yield or request a fresh snapshot; never clear unrelated queues.
- **Recovery:** Discard the stale intent/reservations and re-resolve stable identities before any new
  lease.
- **Responsible subsystem:** Snapshot builder, ownership arbiter, legality service, dispatcher.
- **Planned validation:** evidence:E2+E4; G4/G5; `COMP-B05`, `COMP-B08`, `COMP-SR04`;
  backlog cases `ACT-03`, `ACT-04`, `SPACE-04`.
- **Current evidence / uncertainty:** Revalidation is an E0 requirement only. Exact observable
  lifecycle, target legality, LOS/range, and action-family semantics need later E2/E4 proof.

### CI-04 — Project Image owner lock produces delayed zombie actions

- **Domain:** Combat Intent lifecycle exclusions and dispatcher.
- **Failure mode:** An action queued on a Project Image owner remains latent and fires much later when
  the lock ends, after its intent, target, or encounter is obsolete.
- **Severity:** Critical.
- **Detectability:** Medium if the owner-lock relationship can be identified before queueing; Low if
  queue acceptance is trusted.
- **Reversibility:** Low after the action is latent in an engine-owned queue.
- **Blast radius:** Actor, target, encounter, and later unrelated scene.
- **Prevention / containment:** Exclude a proven Project Image owner state before lease and again at
  dispatch; never probe by queueing; distinguish it from other clone/summon states only through a
  proved lifecycle profile.
- **Detection:** Construct the exact disposable owner/puppet case and require a reason-coded
  exclusion and zero queued action across lock creation/expiry.
- **Fallback:** Yield the owner entirely to legacy behavior while the lock exists.
- **Recovery:** Do not clear or rewrite the queue without ownership proof; if an old attempt is
  detected, mark unknown/invalidated and keep Combat Intent disabled for that actor until the
  lifecycle discontinuity resolves.
- **Responsible subsystem:** Clone/puppet lifecycle adapter, lease eligibility, dispatcher.
- **Planned validation:** evidence:E4; G5; `COMP-B07`, `COMP-P11`; backlog case `ACT-05`.
- **Current evidence / uncertainty:** The hazard is explicitly named by `PJT-BACKLOG` and forbidden
  by `PJT-ARCH`, but PREP-03 did not reproduce it. Detection fields and version stability require
  `UP-EEEX-011` source analysis followed by E4 proof.

### CI-05 — Stale object IDs attach intent or reservations to a different actor

- **Domain:** Combat Intent identity and lifecycle.
- **Failure mode:** Raw object IDs/userdata survive actor deletion, area change, summon/clone,
  charm, death/resurrection, or load, then resolve to a new object and inherit another actor's
  intent/ownership.
- **Severity:** Critical.
- **Detectability:** Medium with lifecycle generations and stable-identity re-resolution; Low with
  an ID-only cache.
- **Reversibility:** High before queueing; Conditional after the wrong actor acts.
- **Blast radius:** Actor, target, encounter.
- **Prevention / containment:** Never persist raw IDs/userdata; expire leases, attempts, beliefs and
  reservations on lifecycle discontinuity; pair ephemeral references with a validated generation or
  stable semantic identity and re-resolve before use.
- **Detection:** Exercise ID reuse/replacement lifecycle and assert no state inheritance, plus inspect
  persistent payloads for forbidden handles.
- **Fallback:** Treat resolution ambiguity as actor ineligibility and let legacy AI run.
- **Recovery:** Drop all affected ephemeral maps/reservations and rebuild from a new scalar snapshot;
  do not migrate state by raw numeric equality.
- **Responsible subsystem:** Identity resolver, lifecycle observer, ephemeral state store.
- **Planned validation:** evidence:E2+E4; G3/G5/G7; `COMP-B08`, `COMP-P03`, `COMP-P10`,
  `COMP-P11`; backlog cases `EEEX-04`, `ACT-05`.
- **Current evidence / uncertainty:** The no-persistence rule is pinned, but object recycling,
  replacement, charm, clone, resurrection, and despawn behavior were not exercised.

### CI-06 — Save/load interrupts or duplicates an ordinary action

- **Domain:** Combat Intent save lifecycle.
- **Failure mode:** A queued/started/interrupted action, lease, attempt token, target, or reservation
  survives load incorrectly; the action is duplicated or a completed effect is assumed.
- **Severity:** Critical.
- **Detectability:** Medium through save/load at each action state and fresh post-load observation.
- **Reversibility:** Conditional; duplicate resource use/effects may not be reversible.
- **Blast radius:** Actor, target, encounter, save.
- **Prevention / containment:** Persist none of the combat lease/attempt/queue ownership; clear all
  unsafe ephemeral state on load; observe any engine action already present; wait for a new handoff
  before deciding.
- **Detection:** Save/load at accepted, started, interrupted, completed, and unknown boundaries and
  compare action/resource/postcondition state without relying on the old token.
- **Fallback:** Post-load legacy ownership until a fresh eligible lease exists.
- **Recovery:** Rebuild snapshots and identity maps, release old reservations, and classify observed
  state without retrying the pre-save action automatically.
- **Responsible subsystem:** Save lifecycle listener, ephemeral store, attempt observer.
- **Planned validation:** evidence:E4; G5; `COMP-B04`–`COMP-B06`, `COMP-P03`, `COMP-P11`;
  backlog cases `ACT-01`, `ACT-04`.
- **Current evidence / uncertainty:** Required behavior is E0 design only. Engine serialization of
  queued/started/interrupted actions is a P0 unknown and no save was accessed.

### CI-07 — Effective spell/item/marker semantics are guessed

- **Domain:** Combat Intent resource semantics and candidate generation.
- **Failure mode:** Vanilla or generated resrefs, SPLSTATE uniqueness, MSECTYPE bounds, projectile,
  target, fairness, or item/spell behavior are assumed after SR/SCS/unknown modifications, causing
  the wrong or unsafe action.
- **Severity:** Critical.
- **Detectability:** Medium with exact effective dependency parsing; Low when a plausible resref
  points to different semantics.
- **Reversibility:** Low after the wrong spell/item action affects combat.
- **Blast radius:** Actor, target, party/area for AoE, encounter.
- **Prevention / containment:** Resolve effective resources and all semantics required by the typed
  candidate; begin exact-hash-only; reject unknown projectile/ability/marker meaning; never
  hardcode generated SCS or assumed vanilla/SR slots.
- **Detection:** Compare vanilla/SR/SCS+SR fixtures, relocated spells, marker false positives, and
  unknown modified resources through static dependencies plus disposable outcomes.
- **Fallback:** Exclude only the candidate or dependent adapter and yield to effective legacy/SCS AI.
- **Recovery:** Quarantine the semantic record, refresh exact resources/dependencies, and add a
  reviewed fixture before reenabling; do not patch a live action after dispatch.
- **Responsible subsystem:** Effective-resource inventory, semantic registry, candidate validator.
- **Planned validation:** evidence:E1+E3+E4; G2/G4/G5/G6; `COMP-SCS02`–`COMP-SCS04`,
  `COMP-SR01`–`COMP-SR04`.
- **Current evidence / uncertainty:** Exact upstream candidate versions are pinned, but no effective
  SPL/ITM/PRO/SPLSTATE or generated SCS artifact was inspected here. Semantic identity and
  fingerprints remain unproved.

### CI-08 — Policy uses imperceptible facts or bypasses ordinary action semantics

- **Domain:** Combat Intent perception, fairness, candidate validation, dispatcher.
- **Failure mode:** Policy reads engine truth the actor should not know, or uses direct effect/
  forced-cast mutation where aura, casting time, interruption, inventory/resource expenditure,
  range/LOS, target legality, or counterplay must apply.
- **Severity:** Critical for declared fair-combat behavior and compatibility with scripts/effects.
- **Detectability:** Medium through snapshot provenance and observed ordinary-action lifecycle;
  Low when direct mutation superficially produces the desired effect.
- **Reversibility:** Low after an unfair/illegal effect changes combat; High when the candidate is
  rejected before dispatch.
- **Blast radius:** Actor, target, party/area, encounter balance.
- **Prevention / containment:** Policy consumes only scalar facts present in a provenance-tagged
  perception snapshot; candidate APIs expose typed ordinary actions; direct/instant effects are
  excluded from Combat Intent and reserved only for separately reviewed WorldFlow semantics.
- **Detection:** Property tests reject absent/impossible facts; E4 compares aura, casting time,
  interruption, spell/item expenditure, target legality and effect postconditions against normal
  engine actions under visible/hidden/changed conditions.
- **Fallback:** Exclude the candidate or adapter and yield to legacy/SCS behavior; never downgrade to
  a direct effect as a compatibility fallback.
- **Recovery:** Release the lease/reservations and replan from a fresh lawful snapshot; quarantine
  any semantic/action descriptor that bypassed the boundary.
- **Responsible subsystem:** Perception snapshot builder, fairness policy, typed candidate registry,
  dispatcher.
- **Planned validation:** evidence:E2+E4; G4/G5; `PREP03-FAIR-01`; adjacent cases
  `COMP-B04`–`COMP-B08`, `COMP-SR03`, `COMP-SR04`; backlog cases `SPACE-04`, `ACT-01`,
  `ACT-02`. No single current `COMP-*` row proves the whole fairness/direct-effect boundary.
- **Current evidence / uncertainty:** Fairness and ordinary-action use are E0 architecture rules.
  No perception model, candidate descriptor, spell/item dispatch, or engine comparison ran.

## WorldFlow risks

### WF-01 — A non-idempotent side effect is duplicated or lost

- **Domain:** WorldFlow saga and side-effect registry.
- **Failure mode:** Reward, spawn, journal change, dialogue start, variable update, item grant, door,
  or other irreversible effect repeats after retry/reload or is marked committed before occurring.
- **Severity:** Critical.
- **Detectability:** Medium; reliable detection needs durable markers plus independent world
  postconditions.
- **Reversibility:** Low for unique rewards, deaths, consumed dialogue, or external-mod-visible state;
  Conditional for explicitly compensatable effects.
- **Blast radius:** Flow, quest, save, and downstream mods reading public state.
- **Prevention / containment:** Classify every effect as naturally idempotent, conditionally
  repeatable, at-most-once with pre-action marker, at-least-once/duplicate-tolerant, compensatable,
  or unsupported; maintain a typed side-effect registry and never schedule an unclassified effect.
- **Detection:** Save/fault injection immediately before/after marker, engine action, postcondition,
  and commit; count externally visible effects and verify final invariants.
- **Fallback:** Yield to the preserved legacy route before an unsupported effect; stop with an
  actionable diagnostic rather than retry infinitely.
- **Recovery:** Reconcile actual world state against markers/postconditions, then continue, safely
  retry, compensate, commit, or enter `LEGACY_YIELD` according to the declared class.
- **Responsible subsystem:** WorldFlow saga engine, side-effect registry, postcondition observer.
- **Planned validation:** evidence:E2+E3+E4; G7; `COMP-D10`, `COMP-P01`–`COMP-P04`,
  `COMP-P07`, `COMP-P08`; backlog cases `WF-01`, `WF-04`, `WF-05`.
- **Current evidence / uncertainty:** The saga taxonomy is E0 architecture. No transition model,
  effect registry, save boundary, or runtime effect was exercised.

### WF-02 — Save/load or area transition interrupts a durable transition

- **Domain:** WorldFlow persistence and reconciliation.
- **Failure mode:** Save/autosave/load occurs after claim, pre-action marker, action, postcondition,
  or commit; a lost queued continuation is trusted, phase becomes ambiguous, or recovery loops.
- **Severity:** Critical.
- **Detectability:** Medium through exhaustive boundary-state enumeration and post-load snapshots.
- **Reversibility:** Conditional on every reachable phase having a declared legacy-safe or
  deterministic reconciliation path.
- **Blast radius:** Flow, quest, area, save.
- **Prevention / containment:** Use stable versioned phases and semantic identities; persist minimal
  reconciliation evidence; never trust queued continuations; reject any design with an unreachable
  handback state or unbounded retry.
- **Detection:** Model every boundary, then save/load/area-transition at each phase and compare public
  and actual world postconditions to one allowed next state.
- **Fallback:** Before mutation, an unknown/ambiguous state remains legacy-owned. After any partial
  mutation, quarantine the flow and perform no further mutation unless actual and public
  postconditions prove a declared legacy-safe boundary or deterministic reconciliation path;
  `ABORTED_SAFE`/`LEGACY_YIELD` labels alone do not make handback safe.
- **Recovery:** Detect already-completed effects and compare actual/public postconditions to the
  declared state model. Only then safely retry a classified effect, continue from the next valid
  state, compensate, or hand back at a proved legacy-safe boundary; otherwise stop with diagnostics.
- **Responsible subsystem:** WorldFlow state machine, persistence adapter, reconciliation engine.
- **Planned validation:** evidence:E2+E4; G7; `COMP-A05`, `COMP-P01`–`COMP-P06`,
  `COMP-P08`; backlog cases `WF-01`–`WF-05`.
- **Current evidence / uncertainty:** Required state fields and outcomes are pinned E0 design; no
  state-space exploration, save/load, autosave, area transition, or postcondition proof ran.

### WF-03 — Cutscene launch stacks or recovery unwinds ownership it does not own

- **Domain:** WorldFlow cutscene transition and watchdog.
- **Failure mode:** A still-true launcher repeats across script passes, `StartCutSceneMode()` stacks,
  downstream dialogue no longer restores control, or a watchdog clears another mod/engine mode,
  leaving the player locked or unrelated choreography damaged.
- **Severity:** Critical.
- **Detectability:** Medium; repeated launch/ownership tokens and control-state postconditions are
  observable, but lock may appear only after alternate paths.
- **Reversibility:** Conditional when the exact owned lease and prior state are recorded; Low when
  ownership is ambiguous.
- **Blast radius:** Player control, area, quest, save.
- **Prevention / containment:** Durable once/claim guard before launch; one declared cutscene lease;
  explicit completion/control postcondition; watchdog may unwind only mode/script/breakability state
  created by the same claim.
- **Detection:** Keep launch condition true across passes, decline/delay dependent dialogue, inject
  error/load, and assert one launch plus restoration of only owned state.
- **Fallback:** Do not launch when ownership or cleanup is ambiguous; preserved legacy sequence owns
  the scene.
- **Recovery:** Execute the claim-specific recovery end state, restore the exact prior area script
  and owned mode, or stop for manual diagnostic if ownership cannot be proved.
- **Responsible subsystem:** Cutscene claim adapter, area-script bridge, WorldFlow watchdog.
- **Planned validation:** evidence:E4; G7; `COMP-D05`, `COMP-D06`, `COMP-A04`, `COMP-A05`;
  backlog cases `FLOW-01`, `WF-04`.
- **Current evidence / uncertainty:** Cutscene stacking is a named hazard and the ownership rule is
  pinned. No cutscene, dialogue, control state, or watchdog executed.

### WF-04 — Normal, skip, and recovery paths drift to different end states

- **Domain:** WorldFlow cutscene/skip convergence.
- **Failure mode:** A cutscene edit omits its `CUTSKIP*` mirror or recovery path, so skipped play
  replays removed effects, misses required actions, restores wrong state, or duplicates rewards.
- **Severity:** Critical.
- **Detectability:** Medium with complete skip-rig dependency mapping and semantic snapshots; Low
  when the skip path is omitted from the corpus.
- **Reversibility:** Conditional for doors/actors/variables with exact restoration; Low for
  irreversible effects.
- **Blast radius:** Flow, area, quest, save.
- **Prevention / containment:** Derive or validate normal, skip, and recovery from one final-state
  contract; include every matching skip rig and carried action in dependency closure; do not claim a
  skippable flow with an opaque/unmapped path.
- **Detection:** Execute normal and skip routes plus every injected recovery boundary, then compare
  semantic world/public-variable postconditions and effect counts.
- **Fallback:** Leave the complete original cutscene and skip rig legacy-owned.
- **Recovery:** Apply only the shared declared convergence operation when its ownership and
  idempotency are proved; otherwise quarantine the flow and retain diagnostics.
- **Responsible subsystem:** Flow compiler/validator, skip-rig analyzer, snapshot comparator.
- **Planned validation:** evidence:E2+E3+E4; G7; `COMP-D03`–`COMP-D06`, `COMP-A05`;
  backlog cases `FLOW-01`, `FLOW-02`, `WF-05`.
- **Current evidence / uncertainty:** `PJT-ARCH` and `PJT-MATRIX` pin the convergence contract, not
  an implementation. No skip rig, real/synthetic dialogue, or semantic snapshot was inspected.

### WF-05 — Public quest state has an unknown value or external writer race

- **Domain:** WorldFlow public compatibility ABI and ownership claim.
- **Failure mode:** A new/legacy BCS/DLG reads or writes a claimed global/local/timer, a value lies
  outside the known state model, or WorldFlow races/normalizes it and breaks another mod's contract.
- **Severity:** Critical.
- **Detectability:** Medium; direct writers are statically discoverable only for supported syntax and
  must be rechecked after stack drift.
- **Reversibility:** Low after overwriting public quest state; High if claim is refused.
- **Blast radius:** Quest, dialogue/area dependencies, downstream mods, save.
- **Prevention / containment:** Treat public variables as ABI; declare meanings/access modes and all
  readers/writers; require refreshed reverse references; compare expected phase/value immediately
  before transition; never normalize unknown values.
- **Detection:** Typed-IR reader/writer scan plus E4 external-writer/value fault injection while a
  claim is active.
- **Fallback:** Stop at a safe boundary and yield the flow to legacy ownership with an actionable
  diagnostic.
- **Recovery:** Reconcile only a reviewed known value/postcondition; otherwise leave the external
  value untouched, quarantine the adapter, and require dependency review.
- **Responsible subsystem:** Public-state registry, IR reverse-reference index, WorldFlow arbiter.
- **Planned validation:** evidence:E2+E3+E4; G2/G7/G8; `COMP-I10`, `COMP-I11`,
  `COMP-D08`, `COMP-D09`, `COMP-P01`, `COMP-P02`; backlog cases `BCS-03`, `WF-03`,
  `WF-06`.
- **Current evidence / uncertainty:** `PJT-PREP02` provides a revision-pinned E0 example of mandatory
  yield. Reverse-reference completeness and runtime race handling are unresolved P0 research.

### WF-06 — Dialogue ordering, interjections, or carried actions change semantics

- **Domain:** WorldFlow DLG/BCS bridge and compatibility analyzer.
- **Failure mode:** A bridge state hijacks dialogue start, changes last-valid continuation ordering,
  loses inbound/outbound `EXTERN`, breaks vocabulary-dependent interjections, or omits plot-critical
  actions carried on alternate routes.
- **Severity:** Critical.
- **Detectability:** Medium with loss-aware graph analysis and runtime path cases; Low with numeric
  state assumptions or incomplete decompilation.
- **Reversibility:** Conditional before public/plot actions; Low after the wrong branch commits.
- **Blast radius:** Dialogue, quest, companions, save.
- **Prevention / containment:** Use semantic anchors, preserve start ordering/continuations/links/
  actions/text dependencies, keep unknown constructs opaque, and retain a valid legacy transition
  until every persisted state has proved handback.
- **Detection:** Static graph/source-map checks plus synthetic and E4 dialogues covering competing
  start states, guarded continuations, interjections, and alternate action carriers.
- **Fallback:** Decline the bridge and use the original DLG/BCS graph unchanged.
- **Recovery:** Quarantine the flow/adapter and restore the original graph through WeiDU; reconcile
  only public state whose exact postconditions are known.
- **Responsible subsystem:** DLG/BCS loss-aware IR, bridge generator, WorldFlow adapter.
- **Planned validation:** evidence:E2+E3+E4; G2/G7; `COMP-D01`–`COMP-D03`, `COMP-D07`,
  `COMP-I04`; backlog cases `DLG-01`–`DLG-03`, `IR-01`, `IR-02`.
- **Current evidence / uncertainty:** Ordering and preservation requirements are E0 design inputs.
  No dialogue was parsed, compiled, installed, or executed; supported IR coverage is unknown.

### WF-07 — Save-baked area state or temporary area-script mutation is misread/restored

- **Domain:** WorldFlow ARE/area-script boundary.
- **Failure mode:** Override defaults are assumed for an already visited area, campaign/EET variants
  are guessed, or a temporary area script/door/region/ambient mutation fails to restore the exact
  prior effective runtime state across success, skip, error, load, or uninstall.
- **Severity:** Critical.
- **Detectability:** Medium through separate fresh/save-baked fixtures and semantic snapshots.
- **Reversibility:** Conditional on capturing exact installed defaults and actual runtime prior
  state; Low when the prior state is unknown.
- **Blast radius:** Area, travel graph, cutscene, quest, save.
- **Prevention / containment:** Treat unvisited effective ARE and save-baked visited state separately;
  derive campaign variants from effective data; allow temporary `SetAreaScript()` only under an
  owned transition; record/restore exact prior state and verify postconditions.
- **Detection:** Exercise fresh/previsited areas, EET variants, area transition/autosave, later ARE
  changes, and every success/skip/error/recovery restoration path.
- **Fallback:** Leave area and script ownership with effective legacy content when state/defaults are
  ambiguous.
- **Recovery:** Restore only recorded owned state; otherwise quarantine and stop rather than applying
  a hardcoded default.
- **Responsible subsystem:** ARE inventory, runtime world snapshot, area-script claim adapter.
- **Planned validation:** evidence:E3+E4; G2/G7/G8; `COMP-A01`–`COMP-A08`, `COMP-D04`–
  `COMP-D06`.
- **Current evidence / uncertainty:** The distinction and required cases are pinned, but no ARE,
  visited save, EET variant, area script, or region/door state was accessed.

### WF-08 — Schema migration, future state, or missing marshal handler corrupts durable flow

- **Domain:** WorldFlow durable schema and persistence adapter.
- **Failure mode:** Upgrade skips a generation, stamps current version before postconditions pass,
  old runtime down-converts future state, absent handler strips data, or unsupported scalar/cycle
  breaks save/load.
- **Severity:** Critical.
- **Detectability:** Medium with pure migration and load/resave matrices; Low without older/future
  fixtures and handler-absence cases.
- **Reversibility:** Low after destructive migration/resave; High if the flow disables before write.
- **Blast radius:** Flow and save, potentially unrelated handler data.
- **Prevention / containment:** Sequential pure migrations; validate shape/public contracts/world
  postconditions before stamping; preserve/reject future fields per version rule; future schema
  disables only that flow; profile-specific handler-absence contract.
- **Detection:** Run two older generations, a future generation, malformed state, and handler
  absence through pure tests and disposable save/load/resave while inspecting persistent payloads.
- **Fallback:** Do not migrate or mutate unknown/future state; disable the flow and yield.
- **Recovery:** Restore a prior known-good save or apply an explicit forward migration with verified
  postconditions; never reverse-migrate by guessing.
- **Responsible subsystem:** WorldFlow schema registry, migrator, marshal adapter, reconciliation.
- **Planned validation:** evidence:E1+E2+E4; G7/G8; `COMP-P05`, `COMP-P06`, `COMP-P09`,
  `COMP-P10`, `COMP-API09`; backlog cases `WF-02`, `WF-07`.
- **Current evidence / uncertainty:** Schema policy is E0 only. The declared v0.11 persistence shape,
  absent-handler behavior, future-state preservation, and save resave behavior were not tested.

### WF-09 — Disable or uninstall occurs during a non-legacy-safe WorldFlow phase

- **Domain:** WorldFlow handback and installer lifecycle.
- **Failure mode:** Runtime/adapter/EEex is disabled or removed while a durable claim is pending,
  leaving original scripts unable to complete, or recovery repeats rewards/spawns/dialogue.
- **Severity:** Critical.
- **Detectability:** High at design/model time if every reachable state is enumerated; Medium in the
  engine due to save timing and external state.
- **Reversibility:** Conditional; only phases with a proven legacy-safe state or deterministic
  reconciliation qualify.
- **Blast radius:** Flow, quest, save, installation.
- **Prevention / containment:** Reject any flow unless every reachable persisted phase is already
  legacy-safe or has deterministic recovery executable independently of the runtime being removed;
  make disable domain-specific; preserve public ABI and original resources; never require a player
  to remember a detach step before uninstall.
- **Detection:** Disable/remove adapter, domain, bootstrap, and supported runtime at every phase,
  including offline saves not pre-opened by the installer; reload restored legacy resources and
  count all irreversible effects.
- **Fallback:** If independent handback cannot be guaranteed for every supported persisted phase,
  refuse the migration design and leave the full flow legacy-owned from the start. Do not assume an
  installer can discover or reconcile every offline save.
- **Recovery:** Hand back only through an already-proved legacy-safe phase or a deterministic recovery
  path that remains executable independently of the removed runtime. Restore resources through
  WeiDU; do not make correctness depend on a pre-uninstall reconciliation having run.
- **Responsible subsystem:** WorldFlow lifecycle manager, saga reconciler, WeiDU installer.
- **Planned validation:** evidence:E2+E3+E4; G1/G7/G8; `COMP-D10`, `COMP-P07`, `COMP-P08`,
  `COMP-P12`, `COMP-X08`, `COMP-X09`; backlog case `WF-07`.
- **Current evidence / uncertainty:** Handback is an E0 acceptance requirement. No state model,
  disable, uninstall, restored script, or partial-runtime case ran; `COMP-X09` remains unknown.

## Cross-check against the PREP-03 named hazards

| Named backlog hazard | Register coverage |
|---|---|
| Queue success versus execution | `CI-01` |
| Script-slot shadowing | `CI-02`, `K-02` |
| Repeated listener registration or over-frequent invocation | `K-05` |
| Stale object IDs | `K-06`, `CI-05` |
| Partial sprite initialization | `K-04` |
| Save/load interruption | `CI-06`, `WF-02`, `WF-08` |
| Non-idempotent side effects | `WF-01` |
| Cutscene stacking | `WF-03` |
| Skip-path drift | `WF-04` |
| Project Image owner lock | `CI-04` |
| Action races | `CI-03` |
| Resource replacement after installation | `K-02`, `CI-07`, `WF-05`, `WF-07` |
| Native access violations | `K-04` |
| Uninstall during in-flight state | `K-08`, `WF-09` |

Additional architecture/matrix-critical classes are covered by `K-01` (unknown takeover), `K-03`
(capability/partial removal), `K-07` (fault scope), `K-09` (starvation), `K-10` (extension
boundary), `K-11` (redistribution), `K-12` (host/lab isolation), `K-13` (diagnostic leakage),
`K-14` (cross-domain isolation), `CI-07` (effective semantic identity), `CI-08` (fairness/ordinary
action semantics), and `WF-05` through `WF-08` (public ABI, dialogue, area, and durable-schema
safety).

## Observations

- Every one of the 31 critical/high-risk entries has a prevention or containment control,
  detection path, legacy-safe fallback, bounded recovery, responsible subsystem, and planned test
  with explicit evidence layer/gate/case IDs.
- Combat Intent and WorldFlow share eligibility, native, persistence, installer, and diagnostic
  infrastructure but never share lease/claim semantics or failure recovery.
- Many designed fallbacks are only safe if refusal occurs before mutation. Rows with conditional or
  low reversibility retain a blocking E4 gate rather than promising rollback.
- `COMP-X09`, action/save serialization, safe BCS handoff, stack-epoch refresh, external-control
  closure, public-variable reverse-reference completeness, and WorldFlow handback remain P0 unknowns.
- No dedicated `COMP-*` row currently covers active-path/TOCTOU isolation, native access violation
  or partial sprite initialization, over-frequent hook cadence/safe-access windows, cross-domain
  fault injection, diagnostic leakage, or the full fairness/direct-effect boundary. The
  `PREP03-*` scenarios above retain those gaps explicitly.
- The candidate dependency pins identify research inputs only. They do not establish support for the
  active installation, a newly built stack, another store executable, or another release.

## Counterevidence and residual uncertainty

- `PJT-MATRIX` describes required future behavior. It is not test output, and no row is marked
  passed by this register.
- Revision-pinned project prose proves what rule was recorded, not that EEex, BCS/DLG, save, or
  action lifecycle follows it. Most current hazard propositions therefore remain E0 with E1
  traceability.
- The historical `GAME-266` and mod-version observations were not refreshed. The active game may
  differ and is deliberately not a validation target.
- The project has not selected or run an available WeiDU executable, standalone Near Infinity
  workflow, disposable engine, or supported-corpus soak for these hazards.
- E2 model/IR/property tests are still future work except for unrelated PREP-02 schema mechanics and
  Task 2 host-path safety. Those results do not validate gameplay controls.
- A process crash can bypass Lua containment and may leave incomplete evidence. Each native call
  shape therefore remains blocked until preflight plus a single scoped E4 experiment is reviewed.
- WorldFlow cannot claim ACID rollback or generic exactly-once semantics. Some effects may remain
  unsupported even after the model exists.
- Full public-variable/external-control closure across arbitrary mod stacks may be impossible. If
  so, the affected adapters remain exact-stack-only or legacy-owned rather than weakening closure.
- Evidence:E4 and evidence:E5 remain unexecuted for every risk in this document.

## Artifacts and retention

| Artifact | Retention | Purpose |
|---|---|---|
| This memo | Repository | Initial PREP-03 risk register and test map |
| `PJT-ARCH`, `PJT-PLAN`, `PJT-BACKLOG`, `PJT-MATRIX` | Git history at the pinned blobs | Normative design, execution, and acceptance inputs |
| `PJT-PREP01`, `PJT-PREP02` | Git history at the pinned blobs | Candidate/no-claim boundary and evidence trace |
| Terminal source-pin/self-check output | Ephemeral and summarized here | Reproduce exact repository inputs without personal paths |
| Game resources, saves, binaries, TLK, installed logs | Not accessed or retained | Forbidden for this host-only checkpoint |
| Disposable game and E4/E5 evidence | Not created | Remains behind Task 3 authorization and later gates |

## Focused structural validation

The following host-only check is intentionally structural. It verifies that every register entry has
all required fields and that every named PREP-03 hazard is cross-referenced. It does not validate
the truth or runtime efficacy of any control.

```powershell
$path = 'docs/research/PREP-03-failure-safety-compatibility-threat-model.md'
$text = Get-Content -Raw -LiteralPath $path
$riskMatches = [regex]::Matches($text, '(?ms)^### (?<id>(?:K|CI|WF)-\d{2}) — .+?(?=^### |^## )')
$required = @(
    'Domain', 'Failure mode', 'Severity', 'Detectability', 'Reversibility', 'Blast radius',
    'Prevention / containment', 'Detection', 'Fallback', 'Recovery', 'Responsible subsystem',
    'Planned validation', 'Current evidence / uncertainty'
)
if ($riskMatches.Count -ne 31) { throw "Expected 31 risks; found $($riskMatches.Count)" }
foreach ($risk in $riskMatches) {
    foreach ($field in $required) {
        if ($risk.Value -notmatch "(?m)^- \*\*$([regex]::Escape($field)):\*\*") {
            throw "$($risk.Groups['id'].Value) missing $field"
        }
    }
    if ($risk.Value -notmatch '(?m)^- \*\*Planned validation:\*\* evidence:E[0-5]') {
        throw "$($risk.Groups['id'].Value) has no evidence-layer test"
    }
    if ($risk.Value -notmatch '(?:COMP-|backlog cases? |Task 41)') {
        throw "$($risk.Groups['id'].Value) has no validation case ID"
    }
}
$namedRows = [regex]::Matches(
    $text,
    '(?m)^\| (?!Named backlog hazard|---)[^|]+ \| `(?:K|CI|WF)-\d{2}`'
)
if ($namedRows.Count -ne 14) { throw "Expected 14 named-hazard mappings; found $($namedRows.Count)" }
"PREP-03 structure OK: $($riskMatches.Count) risks; $($namedRows.Count) named hazards mapped."
```

Final Task 2 integration verification on 2026-08-31 recorded:

- `python -X utf8 -m pytest tests/tooling/test_environment_contract.py -q` — `62 passed in 62.02s`;
- `python -X utf8 -m pytest -q` — `68 passed in 63.19s`;
- `./scripts/validate-g0-decisions.ps1`, `./scripts/test-g0-line-endings.ps1`, and
  `./scripts/validate-g0-namespace.ps1` — direct, LF, CRLF, and namespace checks passed;
- PowerShell parsing for every repository script, task-JSON and `pyproject.toml` parsing, the
  pinned-input and structural checks above, and both `git diff --check` and
  `git diff --cached --check` — passed.

No game or lab path was an input.

## Next decision

Independent review confirmed that the risk inventory covers the named and matrix-critical classes,
every critical risk has a concrete containment path, and planned cases retain the evidence layers
required by `PJT-MATRIX`. The review found and closed unsafe hook-cadence, ambiguous WorldFlow
handback, uninstall/offline-save, multi-root, and gate/evidence-mapping gaps before Task 2 closed.
PREP-03 therefore completes Task 2's repository threat-model step. It does not authorize Task 3,
any game/lab access, native/runtime work, or any G1–G8 pass. Later implementation must turn these
controls into tests at their named gates; failure narrows or stops the affected feature.
