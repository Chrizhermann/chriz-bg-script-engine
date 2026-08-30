# ADR 0001: Legacy ownership by default

**Status:** Accepted

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

Unknown, modified, stale, or ambiguous actors, resources, script decisions, dialogue transitions,
and world states remain under their original BCS/DLG ownership. An adapter may request control only
for an explicitly identified and supported scope after both static eligibility and runtime ownership
checks pass. Any missing capability, failed fingerprint, ownership conflict, stale stack identity,
exception, or ambiguity disables or quarantines only the affected adapter and yields completely to
the preserved legacy path.

No naming convention, class, hostility state, spellbook, equipment set, generated resref pattern,
or similarity score can enroll content by itself. No fallback may clear or replace player, encounter,
quest, or third-party action queues.

## Context

Infinity Engine behavior is composed from install-order-sensitive BCS/DLG resources, script slots,
public variables, action queues, and external controllers. A broad takeover cannot reliably
distinguish ordinary combat from staging, dialogue, cutscenes, quests, or mod-owned exceptions.
Compatibility therefore requires the new layer to prove a narrow claim rather than asking legacy
content to prove that it should be left alone.

## Alternatives

- **Global runtime takeover:** rejected because it suppresses unknown encounter and quest ownership.
- **Best-effort heuristic enrollment:** rejected because a false positive mutates content whose
  semantics and fallback are unknown.
- **Fail-open activation after a partial check:** rejected because one stale dependency can make a
  previously valid claim unsafe.
- **Observation-only C1 behavior:** retained as the safe enhancement level when mutation authority
  has not been proved.

## Consequences

Support expands family by family through explicit manifests, dependency closure, exact hashes,
runtime leases or durable claims, and independent fallback tests. Some enhancements will remain
inactive after harmless-looking changes until later loss-aware fingerprint research proves a safe
narrower match. This cost is intentional: a false negative preserves gameplay, while a false
positive can suppress or corrupt it.

## Compatibility

C0 content is untouched and legacy-owned. C1 may be observed without mutation. C2-C4 require
explicit registration or a reviewed adapter, and each retains a separately testable fallthrough or
handback path. Install, upgrade, disable, and failure cannot promote unknown content or widen another
adapter's authority.

**Unknown-content rule:** Unknown, modified, stale, or ambiguous content always remains
legacy-owned; this rule is the prime compatibility invariant.

**Active-game boundary:** This decision authorizes no active-game write or runtime experiment.
Read-only source inspection does not establish runtime safety.

## Evidence

- E0 design contract: `AGENTS.md`, "Prime compatibility invariant" and "Compatibility and install
  order."
- E0 architecture: `docs/plans/2026-08-27-script-engine-architecture-design.md`, sections 2, 6, 8,
  and 11.
- E0 acceptance contract: `docs/compatibility/acceptance-matrix.md`, sections 1, 3, 4, and 10.1.
- E3/E4 pass-through behavior is planned for Tasks 17-18 and is not yet executed.

## Revisit when

Review only if a later proposal can preserve the same fail-closed compatibility outcome with a
narrower activation mechanism and passes the relevant G2/G8 counterexample suites. A proposal to
enroll unsupported content heuristically requires a new ADR and cannot silently amend this one.

## Review date

2026-08-30; next mandatory review at G2.
