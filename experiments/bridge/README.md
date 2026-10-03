# Integrated engine-connection fixture

Research-only prerequisite for the representative mage pilot. Not a production adapter,
combat policy, or permission to claim a real actor. Task10 lifecycle and Task11 bridge work
share a batch; G1 still needs explicit review before downstream production work.

## Allocation (before creation)

| Logical artifact | Engine resource | Scope |
|---|---|---|
| synthetic.bridge-module | `B-XBRDG0.lua` | Explicitly loaded experiment; no bootstrap |
| synthetic.bridge-script | `B-XBRSC0.bcs` | Compiled authored BAF; legacy sentinel follows claim block |
| synthetic.bridge-dialogue | `B-XBRDL0.dlg` | Compiled authored D; ordinary entry, accept/decline exits |
| synthetic.bridge-higher-script | `B-XBRHI0.bcs` | Override NoAction/Continue cases above the default bridge |
| synthetic.bridge-caster | `B-XBRCRE.cre` | Private clone of the existing stripped research caster |

Stems are distinct case-insensitively across extensions and synthetic-only. Lua root is
`_G["B-"].bridge`; BAF/D strings quote the prefix. Locals `B-XBRCASE`, `B-XBRDONE`,
`B-XBRREPLY`, `B-XBRHIGH`, `B-XBRMARK` are fixture markers, not public quest variables. No adapter IDs are converted
to resource names. `bgse-bridge` is a host-only component slug.

## Frozen research boundary

`new(capable)` returns an isolated bridge. `arm(actorId, mode)` explicitly selects a single
synthetic runtime actor for one case (`allow`, `decline`, or deliberate Lua `error`). No raw ID
is persisted. `claim(actorId)` returns a literal Boolean, catches the deliberate policy failure,
and declines if disabled, capability missing, actor not armed, or the case already consumed.
`note(actorId)` records the later BCS action separately from the trigger decision. `disable()`
clears ephemeral enrollment. `snapshot()` copies a bounded scalar event history. No method
queues actions, edits an actor, or registers a native listener.

The BAF guards an absent root/module before calling Lua. A true research claim reaches its
own marker/action; false/error/disabled/missing module reaches the ordinary legacy marker.
The surrounding BCS/DLG fixture, not this module, supplies engine behavior. This explicitly
does not implement Task15's production leases or prove every script-priority combination.

The accepted block deliberately does **not** `Continue()`: the first engine batch found
that the following block could still see the old marker and queue the legacy sentinel too.
The higher-priority script's separate `Continue()` remains, so one batch checks both
blocking and handoff across slots. A compiled-code regression guards this distinction.

## Combined acceptance

- Host: allow/decline/error/capability loss, disable and one-case consumption; copied traces.
- Synthetic WeiDU: real compilation, exact publication set, reinstall and uninstall restoration.
- Engine: actual trigger/action correlation and legacy sentinel for each branch, module absent
  and disabled, ordinary dialogue entry/response, and remaining persistence checks in one
  useful session where their required disk state permits. Missing observations stay open.
- Review the integrated changes and results; rerun only affected cases after concrete fixes.

Source and checks are authored here. Generated game assets, saves and raw logs stay private.
The [integrated evidence memo](../../docs/research/BCS-01-lua-handoff.md) records nine observed
bridge branches, six completed dialogue paths, pending-initiation cancellation, and the
failed expectation that a queued dialogue would resume after area exit/return. These are
bounded research results, not production ownership or automatic G1 acceptance.
