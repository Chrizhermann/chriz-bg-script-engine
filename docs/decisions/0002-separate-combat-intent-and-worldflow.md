# ADR 0002: Separate Combat Intent and WorldFlow policy domains

**Status:** Accepted

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

Combat Intent and WorldFlow share a narrow runtime kernel but not policy, ownership semantics,
persistence, failure domains, or kill switches.

Combat Intent uses immutable scalar snapshots, short-lived perceptions and beliefs, and normally one
ordinary-action lease. Its leases, in-flight attempts, runtime object identities, and coordination
records are ephemeral and are invalidated across save/load or capability loss.

WorldFlow uses versioned durable saga state for one explicitly claimed transition at a time. It must
declare stable identities, public state, side-effect idempotency, postconditions, reconciliation,
legacy handback, and schema migration. It never persists EEex userdata or raw object IDs.

## Context

Combat decisions tolerate frequent replanning and safe decline. Quest, dialogue, cutscene, reward,
and encounter transitions can persist into saves and may contain irreversible side effects. Treating
both as one generic state machine would either make combat needlessly durable or make world state
unsafe and non-recoverable.

## Alternatives

- **One shared policy/state store:** rejected because a combat exception or reload could corrupt
  durable story state, and WorldFlow recovery could seize unrelated combat actors.
- **Two unrelated runtimes:** rejected because capability negotiation, identity resolution,
  diagnostics, manifests, clocks, and failure containment should be implemented once.
- **Persist Combat Intent queues and leases:** rejected because engine action queues and object
  handles cannot be assumed stable across save/load.
- **Keep WorldFlow entirely in reactive BCS:** retained as the legacy fallback, but insufficient for
  owned transitions that require explicit recovery and postconditions.

## Consequences

The shared kernel exposes mechanisms only. Domain APIs, schemas, traces, circuit breakers, feature
flags, and tests remain separate. Cross-domain ownership has an explicit hierarchy: player/hard
engine state and WorldFlow or legacy encounter ownership defeat Combat Intent. WorldFlow work must
meet the stricter persistent-mutation gates before it can schedule a side effect.

## Compatibility

Disabling Combat Intent removes its ephemeral claims and returns the next eligible decision to
legacy AI without changing WorldFlow. Disabling WorldFlow must leave each persisted transition at a
declared legacy-safe, recoverable, or quarantined state without changing unrelated combat behavior.
Public quest variables and dialogue entry points keep their established meanings.

**Unknown-content rule:** Neither domain may claim an unknown actor, resource, controller, or
transition; unsupported content remains under its original BCS/DLG.

**Active-game boundary:** This separation authorizes no active-game write. Persistent WorldFlow
experiments require a separately approved disposable environment and the relevant gate.

## Evidence

- E0 project charter: `AGENTS.md`, "Project charter," "Engineering rules," and "Scope control and
  delegation."
- E0 architecture: sections 1, 4, 7, 8, 12, and 13 of the architecture design.
- E0 acceptance contract: sections 4.2 and 4.3 of the compatibility matrix.
- E2 state-machine and E4 lifecycle evidence are future Tasks 13, 15, 25, and 31-35; none is claimed
  by this ADR.

## Revisit when

Review if a proved kernel mechanism cannot serve both domains without sharing policy or failure
state, or if a WorldFlow transition cannot hand back safely at every reachable persisted boundary.

## Review date

2026-08-30; next mandatory reviews at G3 for kernel boundaries and G7 for durable convergence.
