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
