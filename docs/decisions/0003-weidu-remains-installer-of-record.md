# ADR 0003: WeiDU remains the installer of record

**Status:** Accepted

**Date:** 2026-08-30

**Owners:** Integration owner

## Decision

WeiDU remains the public install-time system of record for patching, backups, BAF/D compilation,
component state, uninstall order, and inter-mod cooperation. Host tools may inspect or generate
authored BAF, D, 2DA, manifest, or Lua inputs, but they do not imitate WeiDU's backup stack, edit
`WeiDU.log`, or publish directly into a game override.

Public components must be conventional, reversible, independently gated, and tested with real
WeiDU against a synthetic fake game before any disposable-engine validation. Installation and
uninstallation operate only on an explicit publication allowlist and must restore fixture-owned
pre-existing bytes exactly.

## Context

The project needs small BCS/DLG bridges and effective-resource inventory, but install order remains
part of compatibility semantics. Replacing or bypassing WeiDU would create a second uninstaller and
would discard mature cross-mod patching behavior precisely where conservative coexistence matters.

## Alternatives

- **A custom installer or direct override writer:** rejected because it cannot safely replace WeiDU
  stack, backup, dialogue, and uninstall semantics.
- **A host package manager wrapping filesystem mutations:** deferred unless it invokes ordinary
  WeiDU components and adds no independent game-state authority.
- **Manual file-copy instructions:** rejected because they are not reproducible or reversibly
  ordered with other mods.
- **WeiDU-only analysis tooling:** rejected; Python and Lua host tools may analyze data without
  becoming installers.

## Consequences

Installer behavior is a distinct E3 proof layer even after E4 runtime behavior is known. Fake-game
tests must cover install, reinstall, upgrade, disable, uninstall, collisions, publication allowlists,
and byte-exact restoration. The project must pin and record the WeiDU executable used for evidence.

## Compatibility

Unknown mods installed before or after the engine remain effective unless an explicit dependency
claim is invalidated. Later stack drift makes affected adapters stale; it does not authorize the
engine to restore an older resource. Disabling or uninstalling the engine preserves ordinary WeiDU
stack semantics and legacy BCS/DLG artifacts.

**Unknown-content rule:** The installer does not patch or enroll unknown resources by naming pattern
or inferred similarity.

**Active-game boundary:** This ADR authorizes no install, reinstall, uninstall, or write against the
active game. E3 work uses a synthetic fake game; E4 work requires a separately approved disposable
game.

## Evidence

- E0 project rule: `AGENTS.md`, "Compatibility and install order."
- E0 architecture: section 7.3, "Install-time boundary," and section 16, "Testing strategy."
- E0 WeiDU documentation: <https://the-mod-elephant.github.io/weidu/>.
- E3 installer/restoration proof is scheduled for Tasks 11, 17, 34, and 39 and is unexecuted.

## Revisit when

Review only if a supported distribution layer can preserve conventional WeiDU components, stack
ordering, backups, uninstall, and cross-mod cooperation without acquiring independent mutation
authority. Replacing WeiDU itself requires a separate ADR and equivalent E3 counterexamples.

## Review date

2026-08-30; next mandatory review at G2 and packaging Task 39.
