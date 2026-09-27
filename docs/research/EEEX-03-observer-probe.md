# Task8: bounded observer lifecycle proof

**Question:** Can read-only callbacks register once, survive code/save reloads, and decline
after a dependency is lost without retaining stale game objects?
**Outcome:** A narrow observer lifecycle is proved on the comparison stack. This is not a
production scheduler, actor-identity contract, action outcome proof or G1 acceptance.

## Environment and method

Steam-disconnected, dedicated BGSE lab/profile from the [runbook](disposable-lab-runbook.md):
BG2:EE2.7.3.0, EET14.0, EEex1.2.0/LuaJIT, SCS35.21, SR4.21-chriz.5, Bubb Spell Menu5.2.
Executable SHA256 `b51093a49140b2b8a7c046b4652bb8e535be24ebbc12b1d735e0b94217a14d57`.
EEex source identities are in the [catalog](EEEX-01-capability-catalog.md) and
[static map](EEEX-02-lifecycle-and-hook-map.md); independent review rechecked the relevant pins.

Authored synthetic files: `experiments/eeex-observer/M_B-K.lua` and `B-XOBS00.lua`.
The README records their allocation before source creation. Seven focused host scenarios ran
on Lua5.1 and LuaJIT. Then one hidden engine process exercised the same files using existing
queued-menu lab helpers. No visible desktop/input control, active-game changes or new lab tool.

The observer writes only its Lua table. No actions, game variables, save payload or queue edits.
It counts load callbacks without touching their sprite argument. Only an explicit world-ready
sample resolves portrait0 anew and reads the exact throwaway character's name/current area.
This fixture selector is not a production ownership/identity rule. At most256 scalar records;
no userdata or object IDs retained. All registered callbacks here have void return contracts.

## Observations — E4, one run

| Boundary | Observed result | Allowed interpretation |
|---|---|---|
| Automatic startup | Root present without manual first load; generation1; bootstrap record then initialized record; EEex active. | Exact `M_B-K.lua` autoload worked on this stack, before initialized dispatch. Not every mod/order/version. |
| Load own baseline | 105 sprite-loaded notifications; manual sample found own fixture in BG2600. | Unmarshal notifications occur; their objects are not dereferenced or declared fully ready. |
| 100 code reloads | Generation101, one registration per hook; native destroyed/loaded list sizes remained3/4. | Root trampoline updates code without appending another listener. Counts include other mods, not three/four BGSE listeners. |
| Area change | Driver requested BG2602; later fresh sample observed BG2602 at generation101; total loaded106. | Area change independently observed. No invented area-enter callback or simulation-tick cadence. |
| Save then reload | Named fixture saved/reloaded; session epoch became1; total loaded199; new area sample at generation101. | Existing Lua root survives reload; teardown notification invalidates last scalar sample, then actor is re-resolved. |
| Main menu | Session epoch2; last area cleared; off-world sample added no observation. | Post-session cleanup is safe for invalidation, not dead-object access. |
| Capability loss | Removed a dependency from the probe's private capability table;100 samples yielded one disabled state/failure; original EEex global stayed callable. | Probe-local missing-dependency path declines; not an EEex uninstall or another mod's capability failure. |

The area driver used the documented [CLUA MoveToArea string call](https://gibberlings3.github.io/iesdp/appendices/clua/bgee.htm)
only on this disposable character. BG2600/BG2602 are the exact effective area resources used;
their original provenance and final mod ownership are not audited by this lifecycle test.
The request response alone was not treated as movement proof; the later sample established it.

No Lua observer failure or native crash was observed before the deliberate dependency loss.
The helper closed its owned process tree after main-menu return; all three owned PIDs were
verified absent. Original menu/config restored, all experiment/console/QA additions removed,
matching reservation released. No graceful executable-exit or helper exit0 claim.

## Counterevidence and review correction

Source review found that the first draft read a sprite name while its unmarshal was still in
progress. That native field-read safety was unproved. A focused failing host case caught the
access; implementation now ignores the callback argument entirely and samples later. No unsafe
draft was launched. Review also caught that dependency loss is latched: a later error injection
would not exercise the handler. Lua-error containment is E2 only, not COMP-X07 E4 closure.
`Infinity_GetTransitionInProgress` was already exercised by the Task3 helper, not guessed.

Host RED: missing module; second RED: load callback attempted a field read. Both became GREEN
without weaker assertions. Command: `python -X utf8 -m pytest -p no:faulthandler -q tests/unit/test_listener_trampoline.py`.
Two backend executions, seven scenarios each; no skips. The per-run fault-handler switch retains
the previously diagnosed LuaJIT/Windows handling from Task7; no repository-wide setting changed.

## Artifacts, limits and next step

Private reproducible commands, staging/cleanup recipes, exact console responses and bounded
event arrays: `.work/task8/lifecycle-v1/`; RED/GREEN logs in `.work/task8/`. The cleanup ledger
lists the one new retained lab fixture. No upstream Lua/resources, saved game or personal path
is committed. Authored experiment source is redistributable; upstream EEex is credited to Bubb.

**Evidence:** E1 pinned registration/dispatch bodies + E2 injected contract + E4 above.
**Residual uncertainty:** no per-actor destruction callback, general AI tick scheduler, pause/
simulation cadence, loaded-object field safety, other EEex builds, optional-module uninstall,
performance or durable state proof. Session teardown covers destruction only at that boundary;
individual despawns cannot leave stale handles here because the probe never caches any.
Missing specific destruction events are recorded, not replaced with a guessed native hook.
**Next decision:** Task8's narrow observer exit is met after independent review. Continue Task9
ordinary-action research; G1 and broader EEEX-02/05 acceptance remain open. No action ownership
or content migration is activated by this result.
