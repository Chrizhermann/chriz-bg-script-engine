# ADR 0006: Runtime and host language boundaries

**Status:** Provisional

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

Use Lua 5.1-compatible policy and runtime code for the EEex/LuaJIT environment. All direct EEex and
native-object access stays behind a narrow, versioned engine adapter. Policy modules receive scalar
snapshots and issue typed semantic requests; they never receive or persist EEex userdata or raw
engine object IDs.

Use WeiDU for public installation and BAF/D compilation. Use Python 3 plus `pytest` for deterministic
host tooling, parsers, schemas, replay, simulation, and integration orchestration. Use PowerShell for
Windows environment guards and disposable-lab orchestration. Use JSON/JSONL for host artifacts and
generated Lua tables for runtime manifests where required.

Exact interpreter paths, supported versions, command lines, encoding/path constraints, dependency
versions, and minimum floors remain provisional until Task 2 records the host/runtime toolchain
decision and support baseline. This ADR does not authorize production runtime code before its
research gate.

## Context

EEex embeds LuaJIT-compatible Lua with version-specific APIs and native userdata hazards. Pure policy
must be replayable without constructing C++ objects, while inventory, schema, graph, and packaging
tests benefit from a mature host language. Windows-specific path isolation needs explicit guards.
Keeping these responsibilities separated limits native blast radius and makes large, repetitive
script families amenable to deterministic data-driven tooling.

## Alternatives

- **Direct EEex objects throughout policy code:** rejected because native lifecycles cannot be
  simulated safely and stale handles can cross save/load.
- **All tooling in embedded Lua:** rejected because host parsing, schemas, property tests, and file
  orchestration would be harder to isolate and test.
- **Embed Python in the game runtime:** rejected because it adds an unsupported native/runtime
  surface and is unnecessary for the policy boundary.
- **Replace WeiDU with Python or PowerShell installation:** rejected by ADR 0003.
- **Freeze exact versions now:** deferred because PREP-01 and Task 2 have not produced a pinned
  support/toolchain inventory.

## Consequences

Interfaces between engine adapters and policy are typed and serializable. Host tools cannot become a
hidden in-game runtime dependency. Lua code stays compatible with the chosen 5.1/LuaJIT subset and
does not assume newer Lua syntax. Task 2 must prove tool discovery, path refusal, encoding, and
reproducible commands before changing this ADR to Accepted.

## Compatibility

Capability negotiation occurs inside the engine adapter. A missing function, incompatible layout,
unavailable interpreter, or unsupported version disables only dependent tooling or adapters and
never guesses a compatible shape. Conventional WeiDU and preserved legacy scripts remain the
fallback.

**Unknown-content rule:** Language/tool availability never enrolls unknown resources or broadens an
adapter claim.

**Active-game boundary:** Host tools default to read-only inspection and must refuse active-game
write targets. No disposable game is created or mutated without the user's separate explicit Task 3
authorization naming its destination.

## Evidence

- E0 implementation-plan tech stack and Task 2 contract.
- E0 architecture sections 7.2, 7.3, 16, and 20.
- E0 EEex/LuaJIT and WeiDU source/documentation inputs referenced by the research backlog.
- Exact paths, versions, interpreter behavior, and environment guard tests are unexecuted and remain
  Task 2 work; no evidence:E3 synthetic-game integration or evidence:E4 disposable-engine runtime
  claim is made.

## Revisit when

Task 2 completes the host/runtime toolchain decision; a supported EEex capability profile requires a
different Lua subset; a host tool cannot meet determinism/isolation requirements; or packaging proves
a different boundary necessary.

## Review date

2026-08-30; mandatory Task 2 review before status can become Accepted.
