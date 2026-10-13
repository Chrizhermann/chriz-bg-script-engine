# ADR 0005: SCS provenance, attribution, and reuse holds

**Status:** Amended 2026-10-14. Still in force: SCS as the knowledge base, prominent credit,
and no copying or redistribution of SCS files. Retired: per-family migration ledgers and reuse
holds (archived in `archive/2026-10-process/docs/provenance/`).

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

SCS is a first-class tactical knowledge source and transitional compatibility partner. For every
adopted family, preserve its behavioral intent, fairness and resource rules, compatibility learning,
encounter exceptions, and provenance; do not copy generated control flow blindly or describe all
differences as improvements.

Every rule or artifact is classified as original, game-derived, SCS-derived, SCS compatibility, or
reference-only. Until LIC-01 completes the required revision-pinned artifact-class review, all
candidate SCS-derived material remains **reference-only and shipping-blocked**. Any upstream reuse
statement used for a class decision must first be revision-pinned as E1 static evidence. PREP-02
now supplies that pin; Task 4's host governance does not settle the derived-artifact reuse holds.
The project's interpretation is an E0 policy input,
is not legal advice, and does not authorize redistribution by itself.

Each migrated family requires a ledger naming upstream version/component, source and effective
artifacts, behavior summary, preserved and changed rules, omitted/opaque cases, dependency closure,
tests, attribution, redistribution decision, fallback, and support tier. SCS (DavidW), Spell
Revisions (Demivrgvs/G3), and other upstream authors receive specific visible credit.

## Context

SCS contains years of tactical and compatibility work, while source, generated BCS, tables,
documentation, bundled third-party material, and observed behavior may have different provenance and
reuse constraints. Generated `dw#*` resrefs are not stable semantic identities. A whole-project
license assumption would be too coarse for either compatibility or redistribution.

## Alternatives

- **Rewrite from memory without provenance:** rejected because it loses tactical intent and makes
  independent versus derived work impossible to audit.
- **Copy SCS source/generated BCS wholesale:** rejected because it defeats the new architecture and
  bypasses artifact-class provenance and redistribution review.
- **Treat SCS only as a black-box oracle:** retained for some shadow comparisons, but insufficient
  where a rule is intentionally preserved or adapted.
- **Delay all SCS study until licensing work finishes:** rejected; read-only reference research may
  proceed, while commit and packaging holds protect unclassified material.

## Consequences

Kernel code and original policy remain separable from SCS adapters. Migration costs include source
reading, ledger maintenance, fixtures, attribution, and review. Unresolved categories cannot be
committed as distributable content or fixtures. No repository publication, upstream contact, or
redistribution occurs without separate authorization and the later gate.

## Compatibility

An SCS adapter activates only for its exact supported version, features, effective dependency
closure, and encounter ownership. Missing SCS, a changed generated artifact, an unknown controller,
or a provenance hold disables only that adapter and returns behavior to the installed legacy/SCS
scripts.

**Unknown-content rule:** No `dw#*` name, SCS-like script shape, or tactical similarity enrolls an
unknown family.

**Active-game boundary:** This decision permits read-only research only. It authorizes no active-game
installation, mutation, runtime experiment, extraction for redistribution, or packaging of installed
artifacts.

## Evidence

- E0 project policy: `AGENTS.md`, "SCS and upstream provenance."
- E0 architecture: sections 2, 6.7, and 14.
- E0 backlog questions and hold points: LIC-01 through LIC-04.
- E1 follow-up, 2026-09-22: PREP-02 pins the SCS v35.21 reuse statement; its readme digest was
  reproduced without game access. See `archive/2026-10-process/docs/provenance/upstream-register.md` for the exact identity.
- E2 Task 4 fixture admission is limited to reviewed original JSON. Class-by-class permission for
  SCS-derived material and complete bundled-content tracing remain LIC-01 work.

## Revisit when

Review when LIC-01 produces artifact-class decisions, whenever the upstream version or
reuse statement changes, or before any SCS-derived artifact enters a fixture, package, release, or
public repository.

## Review date

2026-08-30; reviewed again 2026-09-22 for Task 4. Reuse holds remain; next review at an LIC-01
class decision and G8.
