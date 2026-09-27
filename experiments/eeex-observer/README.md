# Task 8: read-only observer experiment

Research source, not production activation. No actions, game variables, save payloads, script
replacement or content enrollment. The separate test driver may change its disposable fixture.

## Explicit resource allocation (recorded before source creation)

| Logical artifact | Engine filename | Purpose |
|---|---|---|
| `synthetic.observer-probe` | `B-XOBS00.lua` | Authored observer / injected host trampoline |
| Fixed project bootstrap (G0 exception) | `M_B-K.lua` | Guarded loader; actual ordering to be measured |

`B-XOBS00` is synthetic-only, not an adapter ID or truncated name. No cross-extension reuse.
Check both filenames are absent case-insensitively in the lab before staging. Never publish
these experiment resources in a release. The only Lua root is `_G["B-"]`; an occupied root
with another identity must remain unchanged.

Bounded scope: exactly the throwaway party character `BGSE Lab Test`. All incoming sprite
events are counted without dereferencing the callback object. Only a later world-ready sample
records that fixture's scalar name. No object, pointer or
object ID is retained. Session cleanup clears the last scalar area sample. An explicit probe
sample re-resolves portrait0 only while the world screen is open, with no transition active.
This is NOT a scheduler, ownership check or support selector for production content.

Append-only listeners register once, through replaceable root-level dispatch. Hot reload changes
handlers, not listener registrations. A missing dependency or callback error disables the probe;
restart the process after an uncertain registration failure. `pcall` contains Lua errors only.
At most256 recent scalar events are retained; no per-frame file output or copied game resources.

Host test: `tests/unit/kernel/test_listener_trampoline.lua`, executed using the small Python
bridge on Lua5.1 and LuaJIT. Seven scenarios, including occupied-root rejection and no sprite
field reads in the loaded hook. Runtime recipe/results and limits are recorded in
`docs/research/EEEX-03-observer-probe.md`. Stage only in the approved lab with both files absent;
auto-bootstrap first, then explicit `loadfile` for hot reload (engine resource caches may differ).
Require non-disabled state, generation/callback counts and actual events, not file presence.
