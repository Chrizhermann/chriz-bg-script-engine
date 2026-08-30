# ADR NNNN: Decision title

**Status:** Proposed

**Date:** YYYY-MM-DD

**Owners:** Integration owner

## Decision

State the decision as an enforceable rule. Name what is in scope, what is excluded, and which later
gate or task may authorize more.

## Context

Describe the problem, constraints, and why the decision is needed now. Separate known facts from
assumptions and unresolved research.

## Alternatives

List the credible alternatives and why each was rejected, deferred, or retained as a fallback.

## Consequences

Record the positive and negative consequences, including required tests, diagnostics, operational
cost, migration cost, and failure behavior.

## Compatibility

State the effect on C0-C4 content, legacy BCS/DLG fallthrough, install order, save/load, disable,
and uninstall where applicable.

**Unknown-content rule:** Unknown, modified, stale, or ambiguous content remains legacy-owned.

**Active-game boundary:** State whether the decision permits any read or write against the active
game. The default is no write and no runtime experiment.

## Evidence

List exact source revisions, artifacts, commands, observations, counterevidence, and applicable
evidence layers. Evidence layers are independent; use combinations such as E3+E4 when both are
required. State unexecuted environments explicitly.

## Revisit when

Name an observable condition that requires review. Do not use elapsed time or implementation effort
as a reason to weaken a safety invariant.

## Review date

YYYY-MM-DD, or the exact gate that performs the next review.
