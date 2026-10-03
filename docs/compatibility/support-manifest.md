# Support manifest — G1 review inventory

**Status:** G1 current-stack development envelope; no release-wide support claim

**Date:** 2026-10-04

This is not an activation manifest. All real content remains C0/legacy-owned. Christopher
approved the tested comparison stack as the first development target on2026-10-04 and made
older-version compatibility secondary. The old candidate remains unaccepted historical scope,
not a blocker or an inferred equivalent. Future adapters still need exact eligibility/ownership.

| Field | Historic PREP-01 candidate, not runtime accepted | Approved tested development profile |
|---|---|---|
| Game | BG2:EE2.6.6.0 | BG2:EE2.7.3.0 |
| EEex | v0.11.0-alpha + LuaJIT | v1.2.0 + LuaJIT |
| Campaign | EET14 finalized | EET14 copied effective stack |
| Project compiler | WeiDU251 target | WeiDU24900 used for experiments |
| SCS | Optional v35.21 | v35.21 installed; no real AI adapter enabled |
| Spell Revisions | Optional v4.19 | v4.21-chriz.5 |
| Bubb Spell Menu | No initial claim | v5.2 present in observed stack |

Comparison engine SHA-256:
`B51093A49140B2B8A7C046B4652BB8E535BE24EBBC12B1D735E0B94217A14D57`.
Comparison loader SHA-256:
`DF0D3604CB91C127643126B7960429194F3333BCE8BAC0E59AECB6A178AC84B9`.
Experiment compiler SHA-256:
`AD70F5897A6D0BA4B0D226F845A9B14CF345F56CC9697CA8D05CAC9FE4932C1A`.
Source-file pins are in EEEX-01/02 and BCS-01; exact private install/staging identities are in
their linked receipts. A few file hashes alone do not authenticate a whole future mod stack.

Upstream release check on 2026-10-04 found [EEex v1.3.0](https://github.com/Bubb13/EEex/releases/tag/v1.3.0)
and [WeiDU v251.00](https://github.com/WeiDUorg/weidu/releases/tag/v251.00). They were not installed
or tested by that check. The current batch retains the working profile above; a later deliberate
upgrade needs a representative smoke batch and updated pins, not a new compatibility project.

## Capability disposition for this research inventory

`supported` below means only the exact observed research operation, not production activation.
`unavailable` means not admitted by this evidence, not a claim that the engine lacks it.

| Capability | Disposition | Exact limit / evidence |
|---|---|---|
| Function-presence reporting | supported, E1+E2 | Injected named table; no native execution or automatic activation |
| Observer trampolines and fresh own-actor sampling | supported, E1+E2+E4 | Task8's void callbacks/world-ready sample; no cached handles or generic scheduler |
| Ordinary targeted-cast observation | supported, E1+E2+E4 | Authored fixture with independent spent-copy and target-effect evidence; explicit unknown outcomes |
| Authored BCS trigger/action and legacy branch | supported, E1+E2+E3+E4 | Task11 synthetic branches only; no production lease or actor enrollment |
| Ordinary authored dialogue entry/reply | supported, E3+E4 | Exact tested cases, with explicit target checks; not general dialogue ownership |
| Scalar schema/diagnostics and native marshal research | supported, E1+E2+E4 | Exact schemas and named-load/migration/absence observations; no production WorldFlow state |
| Production observer, leases and durable transitions | unavailable | Implementation and G2–G7 admission still required; not supplied by the research fixtures |
| Automatic continuation across area/load or blind retry | unavailable | Negative/unknown ACT/BCS evidence; invalidate old observation scope and re-resolve |
| True QuickLoad acceptance | unavailable | Deferred COMP-P13, integration owner, Task40 before G8; no equivalent-load substitution |
| EEex-removal/partial-runtime fallthrough | unavailable | COMP-X09 unexecuted; no uninstall-order guarantee |
| All-callback error containment and broad version parity | unavailable | Matrix evidence gaps listed in G1 review; presence/version labels are insufficient |

No native-call shape was newly executed or quarantined in this documentation review. Recorded
Lua/harness failures remain in the research memos. Consult the
[G1 review](../decisions/gates/G1-bridge-feasibility.md) before interpreting any row as permission.

## Kernel contract v1

`kernel/manifest.lua` validates an authored scalar declaration: schema/API identity, exact adapter
version, C0–C4 tier, profile/stack epoch, SHA-256 v1, required capabilities, explicit roots and
external-control closure, each resource's hash/dependencies/slots, public-state reader/writer
closure, legacy fallback, provenance and evidence. It does not discover resources or authenticate
an installed corpus. The earlier Task5 JSON shapes remain analysis-only; they cannot activate this
contract by being renamed or marked true.

`kernel/eligibility.lua.evaluate(manifest, environment, identity)` returns copied diagnostic data,
`eligible`, a stable reason and `dispatchAuthorized=false`. The environment supplies independently
observed exact resources, the declared closure's complete public-state map and control closure,
profile/epoch/capabilities and explicit completeness flags. Flags alone are insufficient: closure
maps/lists must match. Identity is a unique, fresh, explicitly rooted semantic key. The engine
boundary, not this pure reducer, is responsible for truthful fresh observations. No userdata,
functions, automatic tier promotion or semantic matching is accepted.

`adapters/registry.lua.new()` retains independent declarations, rejects duplicate IDs, quarantines
one adapter locally and latches all adapters stale after observed epoch drift. Merely restoring an
old epoch value does not reactivate it. Reports name tier, profile, version and evidence, not a
blanket compatibility claim. Fresh reactivation is not implemented.

Reproduce focused E2 checks with `pwsh -File scripts/test.ps1 -Suite unit -Filter eligibility`.
The fixture is authored dummy data, not an installed-game fingerprint. No C2–C4 action can run
without later runtime ownership and the applicable active-behavior gate.

## Ephemeral ownership contract

`kernel/identity.lua` accepts only semantic adapter/key/resource records and re-resolves an exact
unique match from each scalar candidate snapshot. `kernel/ownership.lua` implements the approved
authority order; missing facts deny combat. `kernel/lease.lua` requires that resolution again
at acquisition and dispatch, unchanged stack/session/area/allegiance/adapter version, current
eligibility/capability/aura/action state and target legality. Typed spell/attack/move requests are
passed once to an injected dispatcher; arbitrary BAF and queue-clearing requests are unavailable.

Acceptance creates an observation token, not queue ownership or completion. The promoted
`kernel/action_attempt.lua` retains the tested research reducer's proof requirements. Start
releases the duplicate-prevention lock while ordinary busy/aura checks still apply. A submission
error is unknown, not accepted, and retains a bounded duplicate-prevention lock. `tick()` reports
expired attempts; the boundary calls it before new acquisition. `invalidate()` drops leases and
tokens without altering engine actions. Neither manager state nor raw object IDs is persisted.
This E2 implementation is not permission to dispatch in a game before the active-behavior gate.

Reproduce: `pwsh -File scripts/test.ps1 -Suite unit -Filter 'ownership or identity_attempt'`.

## Observer kernel integration

`kernel/bootstrap.lua` connects explicit enrollment, fresh semantic resolution, exact eligibility,
scalar snapshots, bounded trace and per-adapter error circuits. `adapters/eeex/engine.lua` is a
read-only boundary for the pinned BG2:EE2.7.3/EEex1.2/LuaJIT call shapes; its profile label is not
a binary verification substitute. `adapters/eeex/listeners.lua` preserves one registration and
void-only protected callbacks. The bundle exports no action dispatcher or persistence mutation.

Task16's four-character E4 batch observed ordinary legacy casting/movement, local observer-error
recovery, individual disable, capability decline, sticky epoch drift and load invalidation.
See [KERNEL-01](../research/KERNEL-01-integrated-observer.md) for exact evidence, cost and limits.
Its C1 admission used an injected authored fixture envelope, not a real-game dependency scanner;
the intentionally wrong expected digest was not a modified installed resource. No C2–C4 or
active mage support follows from this batch. Task17 subsequently verified an actually changed
script/CRE and an independent unknown controller. G2/G3 now pass only for the fixed current-stack,
explicit observer development envelope; see their decisions. Pure/shadow Combat Intent work may
proceed, but real-content closure, public packaging and active dispatch remain separate gates.
