# ADR 0006: Runtime and host language boundaries

**Status:** Accepted

**Date:** 2026-08-30

**Accepted:** 2026-08-31

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

The initial host floor is Windows x64 with an x64 PowerShell Core `>=7.4,<8` process, CPython
`>=3.11,<3.12`, and pytest `>=8.4,<9`. Lupa `>=2.8,<3` is an optional E2 Lua runner and must select
its `lua51` or `luajit21` backend explicitly. The executed profile is PowerShell 7.6.5, CPython
3.11.9, pytest 8.4.2, and Lupa 2.8; other versions inside the selected bounds are not claimed tested
until they run the same suite.

Host text and structured artifacts use explicit UTF-8. Python commands use `-X utf8`; tools never
rely on console code page, culture, or a personal executable path. A missing or unexecuted tool is
reported as such and is never treated as passing. This ADR does not authorize production runtime
code before its research gate.

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
- **Use the observed Windows PowerShell 5.1:** rejected because it does not meet the selected
  PowerShell Core boundary and its observed Windows-1252/US-ASCII defaults violate the explicit
  UTF-8 contract.
- **Treat every version inside a broad range as tested:** rejected. The floor is a compatibility
  boundary; support evidence names the exact profile that ran its required suite.

## Consequences

Interfaces between engine adapters and policy are typed and serializable. Host tools cannot become a
hidden in-game runtime dependency. Lua code stays compatible with the chosen 5.1/LuaJIT subset and
does not assume newer Lua syntax. `pyproject.toml` records Python/pytest bounds; the host toolchain
decision records exact observations and reproduction commands. PowerShell path guards use native
no-follow/follow metadata handles and complete file identity, not lexical normalization alone.

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
- E1 host inventory in `docs/research/host-runtime-toolchain-decision.md`: exact PowerShell, .NET,
  Python, pytest, Lupa, Lua/LuaJIT, Java, VC++ metadata, command discoverability, filesystem, and
  encoding observations.
- E2 temporary-directory guard matrix in `tests/tooling/test_environment_contract.py`, including
  lexical refusal, type-strict marker validation, junction/reparse rejection,
  final-path/file-identity checks, 8.3 and hard-link alias refusal, rejection of unaudited directory
  write scopes, multi-target containment, path redaction, and no checked-fixture-tree mutation.
- E1 pinned WeiDU v251.00 source/release identity in `docs/research/PREP-01-support-baseline.md`; the
  executable remains unavailable and no parser/compiler run is claimed.
- No evidence:E3 synthetic-game integration or evidence:E4 disposable-engine runtime claim is made.

## Revisit when

A supported EEex capability profile requires a different Lua subset; a selected host version cannot
meet determinism/isolation requirements; a second OS/profile is proposed; WeiDU/Near Infinity
acquisition changes the compiler/decompiler boundary; or packaging proves a different boundary
necessary.

## Review date

2026-08-31; mandatory review when any selected runtime/version boundary changes.
