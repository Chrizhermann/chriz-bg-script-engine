# G3 — Safe observer

**Status:** PASS WITH NARROWED SCOPE — measured development workload only

**Date:** 2026-10-04

**Owners:** Integration owner; Christopher owns gameplay and support-scope decisions

## Decision

Pass with narrowed scope for two admitted scalar observers, a small authored scene, the fixed
BG2:EE2.7.3/EEex1.2/LuaJIT boundary, and the observed roughly15Hz sampling. No production scheduler,
all-creature polling, new native layouts, action dispatch or durable claims are admitted.

[KERNEL-01](../../../../../docs/research/KERNEL-01-integrated-observer.md) supplies E2/E4 boundary isolation,
one callback error/circuit recovery, capability decline, individual disable and named-load
invalidation; [Task17](../../../../../docs/research/compatibility-lab-results.md) adds actual changed-content
and running unknown-controller observations. Earlier Task8 supplies the measured void-listener
single-registration/hot-reload pattern. Raw userdata stays within the trusted native adapter/
listener handlers; kernel policy snapshots and trace are bounded scalar copies. The exported
listener helper itself forwards native callback arguments and is not a policy-facing snapshot
API or security sandbox. Enrollment/leases are ephemeral, not serialized. Invalidation clears
enrollment, not declarations/circuit diagnostics; listener disable alone is not full invalidation.

Matched same-session timings: kernel median675.5/779µs, p951493/1880µs, maximum7001µs;
boundary-only median379.5/380.5µs, with a7557µs outlier. This is acceptable for continuing the
two-observer development slice, not a proved production budget or causal zero-slowdown result.
The initial coarse os.clock figures are rejected; the separate microsecond-timed windows are
the evidence. Do not scale this polling approach to a full encounter from these numbers.

## Admission limits and next measurement

The engineering acceptance here is the **measured fixed workload**, not an invented universal
numeric budget. Before G4 accepts the shadow mage, measure the connected perception/scoring work
and declare its scene/cadence/cost ceiling; before broad active scaling, Task26/G5 and Task40/G8
must measure the actual workload. Missing observations stay unknown. No untested native callback
is enabled merely because this gate passes. Real corpus closure, active ownership and WorldFlow
durability retain their own gates. True QuickLoad remains deferred COMP-P13; area continuation
remains unavailable, with fresh observation/legacy control instead of automatic retry.

Independent source/export audit and full-trace/document cross-checks accepted these limits.
The lead reviewed the workload cost, scoped native handlers, transient state and172 passing host
checks. Proceed to pure/shadow Combat Intent implementation within this envelope. No game action
may be dispatched through the new kernel before its later active-action gate.
