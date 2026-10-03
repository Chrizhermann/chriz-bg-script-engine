# G1: Bridge feasibility review

**Status:** PASS WITH NARROWED SCOPE — approved current-stack development envelope

**Date:** 2026-10-04

**Owners:** Integration owner; Christopher owns scope/profile approval

## Outcome

Christopher subsequently approved the tested current lab/toolchain as the development target,
prioritized implementation over older-version compatibility, and authorized substantial integrated
batches on2026-10-04. This resolves the prior evidence/scope hold without relabeling missing
evidence. G1 passes only for the measured research primitives and dependent development below;
it is not a release support claim, active combat gate, or general EEex compatibility pass.

Christopher approved moving true QuickLoad to later compatibility testing and including the
area-transition limitation in this review. That approval does not silently change the engine
baseline or waive other acceptance rows by itself. The subsequent explicit current-stack approval
adopts the narrowed envelope and checkpoint placement below. QuickLoad is tracked as COMP-P13 in Task40, before G8,
with an owner, closure criteria and a blocked outcome if no permitted route becomes available.

## Exact evidence envelope

The [support manifest](../../compatibility/support-manifest.md) separates the historic PREP-01
candidate from the now-approved development stack. E4 here is Windows, BG2:EE2.7.3.0, EET14,
EEex1.2.0/LuaJIT, SCS35.21, SR4.21-chriz.5 and Bubb Spell Menu5.2. WeiDU24900 compiled the
research fixtures. It does not prove the old BG2:EE2.6.6/EEex0.11/SR4.19/WeiDU251 candidate.
Executable/source hashes, experiment IDs, exact methods and private receipts are linked below;
release labels alone do not identify a supported environment.

| G1 criterion | Evidence reviewed | Disposition and boundary |
|---|---|---|
| Capability profile | [EEEX-01](../../research/EEEX-01-capability-catalog.md), E1+E2; later E4 probes below | Exact-name presence is not activation. Only exercised call shapes have runtime evidence. |
| Safe hook lifecycle | [Task8](../../research/EEEX-03-observer-probe.md), E1+E2+E4 | Startup,100 reloads, single registration, count-only loaded callback, later fresh sampling and session invalidation observed. No general scheduler or loaded-userdata readiness claim. |
| Normal actions and outcome observation | [ACT-01 exit](../../research/ACT-01-action-state-model.md#task9-research-exit--2026-10-03), ACT-02/03/04, E1+E2+E4 | Ordinary targeted cast has matching start, spent copy and later target effect. Competing action, target movement/death, PI-owner exclusion and named-load loss of continuation are bounded observations, not universal ownership. |
| BCS/Lua handoff and fallback | [BCS-01](../../research/BCS-01-lua-handoff.md), E1+E2+E3+E4 | Nine branches include higher-slot blocking/Continue, decline/error/capability loss and missing root/module. Accepted-block Continue defect fixed and regressed. No production leases or real actor enrollment. |
| Normal dialogue initiation | BCS-01, E3+E4 | Ordinary entry, accept/decline, missing-selector fallback, busy target and pending-initiation cancellation observed. Explicit target validation is required; do not infer nonexistent selector means rejection. |
| Dialogue area boundary | BCS-01, E4 negative evidence | Wait/dialogue queued before exit; after return actor was idle with empty queue and no reply through the deadline. Automatic continuation expectation failed. Do not resume/retry the old request or claim open-conversation interruption coverage. |
| Durable state and lifecycle | [EEEX-06](../../research/EEEX-06-persistence-lifecycle.md), E1+E2+E4 | Named save/load, migration/quarantine, area/menu/death/new-game, handler-only resave and cold module-absence retention measured. True QuickLoad deferred, not passed; no full EEex-removal or production handback proof. |
| Bounded cost | [PERF-01](../../research/PERF-01-observer-baseline.md), E4 | Idle/melee/two idle summons/33-actor crowd baseline; median snapshot68–654us. Contaminated final minimal window excluded from causal comparison. No production budget, general scheduler or E5 claim. |
| Isolation and recovery | [Lab runbook](../../research/disposable-lab-runbook.md), Task8–11 cleanup receipts | Existing hidden launcher and own saves; process stop, exact temporary-file restoration and token release recorded. No native crash in these accepted batches; Lua/harness failures retained, not called successes. |

## Normative acceptance rows still not discharged

These are existing matrix obligations, not newly invented test cases. `partial` is not `pass`.
No new game session or broad test suite was run to assemble this review.

| Case | Actual evidence / missing part |
|---|---|
| COMP-B01/B02/B03 | Synthetic E4 higher-slot and controlled policy-error branches observed. Production lease/plot-state integration remains later work; no broad SCS priority-stack equivalence. |
| COMP-X01 | Required v0.11 candidate not exercised by this packet; current E4 is the v1.2 comparison profile. |
| COMP-X03 | Missing trigger/action symbols prevent synthetic bridge publication (E3); not the specified missing-LuaJIT E3+E4 installer/runtime case. |
| COMP-X04 | Mixed-layout rejection is specified but unexecuted; function-presence tests do not prove layout rejection. No required E3 proof. |
| COMP-X05 | Private dependency loss/bridge capability false tested; not full production adapter/domain isolation. |
| COMP-X07 | Observer callback containment has E2 evidence; bridge policy error has E4. Neither proves an injected error at every engine callback. |
| COMP-X08 | Missing bridge module/root reaches legacy marker; separate cold runtime-absence session proves raw save retention. Do not combine these into an unperformed cold-start all-bridges fallback test. |
| COMP-X09 | EEex absent/partially removed with compiled EEex bridge resources has not been tested; no safe pass-through or tested removal-order enforcement claim. |
| COMP-P13 | User-approved deferral to Task40/G8; unexecuted. Named loading is not a replacement. |

The latest integrated runs already begin from the own baseline and preserve full traces.
For this admission, the combined relevant host suite was rerun:
`python -m pytest tests/unit tests/schemas tests/integration -q -p no:faulthandler`:
153 passed, no skips. This is E2/E3 evidence, not a new engine smoke run. The approved
validation adjustment reuses the existing reset-based E4 runs while the engine-facing payload
is unchanged. Documentation validation checks links, persisted state and whitespace only.
An independent read-only evidence cross-check confirmed the profile mismatch and the missing
matrix evidence; it corrected the draft's unsupported claim of host-tested mixed-layout rejection.
Lead verified the correction, task-state JSON, local document links and whitespace.

## Approved narrowed decision

Use the **already tested comparison stack as the first development target**, not as a new
release-wide compatibility promise. Continue the existing feature plan toward the representative
mage through G2–G5. The old version profile and broader install/removal compatibility remain
recorded obligations before their support claims; they are not lost or implicitly passed.

Within this approval, G1 establishes the measured bridge primitives needed for host kernel
and subsequent lab work. It does not admit untested native calls, all-callback containment,
arbitrary queue attribution, automatic area/save continuation, EEex-removal fallthrough or
WorldFlow recovery. Those operations remain unavailable/shadow-only until their dependent
implementation tests pass; a later gate cannot consume a broad capability from a narrow row.
The area result is a limitation to handle by fresh observation and ordinary legacy ownership,
not a gameplay choice to force the interrupted dialogue to finish.

The following obligations are assigned to the components that must satisfy them. Older-profile
support remains unclaimed. This placement is part of the approved development-first adjustment:

- COMP-X05/X07: Task16, before accepting the actual observer kernel or enabling a new native
  callback; test the implemented boundary, not hypothetical callbacks that do not yet exist.
- COMP-X03/X04/X09: the latest current-stack priority places missing/mixed/removed-runtime
  packaging combinations in Task40 before G8 or earlier distribution/support claims. They do
  not block an EEex-present, explicitly loaded development observer. These configurations are
  unavailable; no safe removal behavior is asserted. Task17/G2/G3 may admit only the exact lab.
- COMP-X08: retain the measured missing-root/module legacy branches. Cold all-bridge packaging
  coverage belongs before a corresponding package claim in Task40; it is not silently passed.
- COMP-X01 and version/toolchain parity: Task40 before claiming the older profile supported.
  Retain the old target as unaccepted; do not silently remove intended compatibility.
- Area/dialogue continuation: unavailable in the initial capability envelope; carry invalidation
  into Task15 and explicit WorldFlow recovery into Tasks31–35/G7. Do not force/replay the old
  request. Any new continuation capability needs its own evidence before use.

Task12 admission checks use the relevant combined host suite and the already recorded
reset-based integrated runs, with fresh engine smoke when the engine-facing payload changes.
No new fresh-smoke result is asserted by the scope adjustment. Task11's bounded bridge research
is accepted with automatic area continuation unavailable; production recovery remains later work.
Task13–17 may proceed under this exact envelope, with G2/G3 technical review before active decision
work. A failure still stops its dependent capability; no acceptance assertion is weakened.

Task16 now supplies the actual observer integration in KERNEL-01: four legacy casters, matching
and declined observers, contained callback error, capability decline, disable and named-load
invalidation. This remains representative implemented-boundary evidence, not proof of every
possible callback or production domain. The current-stack sequencing above supersedes the
earlier placement of the full removal/layout matrix in Task17.
