# EEEX-02: static lifecycle map (not runtime proof)

**Outcome:** Task 7 static map, not completion of EEEX-02 or Task 8.
**Question:** Where could observation attach, and which lifecycle assumptions remain unsafe?
**Environment / versions:** Same offline EEex 1.2.0 comparison copy as the
[capability catalog](EEEX-01-capability-catalog.md), which records the shared raw-byte source pins.
**Method:** Follow initialization, registration and dispatch bodies without loading EEex.

| Boundary | Source observation | Not established / next probe |
|---|---|---|
| Native/bootstrap setup | `EEex_Main.lua:75–143` opens bindings, loads source modules, registers delayed initialization and eventually sets EEex_Active. | A visible function or active flag does not prove an actor/area is ready. Observe actual startup separately. |
| Engine Lua initialized | `EEex_GameState.lua:82–96,134–141` calls immediately for late registration; otherwise dispatches registered callbacks and clears that startup list. | Not a per-save/new-game event. Establish exactly when our later bootstrap runs; no assumed M_ autoload order. |
| Game session destroyed | `EEex_GameState.lua:100–109,143–147` appends listeners, then dispatches after cleanup. | Menu/load examples do not establish all transitions or thread/cadence. Discard transient references; do not inspect dead objects. |
| Sprite loaded | `EEex_Sprite.lua:1588–1602` dispatches after effect-list unmarshal. | Does not prove other actors, lists or area state are ready. Measure before using this as an observation entry point. |
| Action started | `EEex_Action.lua:326–339` sends sprite/current action; `EEex_Action_Patch.lua:65–84` filters NoAction. | Not proof of cast effect, spell spending, interruption or completion. Task 9 must correlate an independent postcondition. |
| Sprite marshal | `EEex_Sprite.lua:983–990,1268–1294,1431–1438` registers keyed export/import handlers and invokes them around stored data. | Save coverage, allowed data types and ordering require Task 10. Persist no userdata, leases or raw object IDs. |
| Area changes / save boundaries / general tick | Scoped Lua search found no reviewed public registration; private time-step code and native area hooks are insufficient. | Leave these mappings unresolved. Do not repurpose a frequently called stat/list hook without measured cadence and safe-access proof. |

## Registration and reload consequences

Initialized-before-start, destroyed, loaded and action-start registration use lists. Reexecuting a
future bootstrap can add duplicates; the inspected definitions show no matching removal API.
The initialized callback may even execute during registration. Neither function presence nor
catching Lua errors solves this lifecycle problem.

`EEex_Action_AddEnabledSpriteStartedActionListener(funcName,func)` at Action.lua:186–190 uses
a named key; this differs from the one-argument general action-start listener. Marshal registration
is keyed too. Key replacement alone does not prove old callback/state cleanup or safe reload.
No keyed-listener switch, trampoline, registration helper or runtime guard is implemented here.

Task 8 should use the already planned one-root registration and representative startup/load/area
change/reload observations. Record callback counts/order and object validity; stop on an actual
native crash, retaining the exact call/lifecycle. Task 9 separately proves normal action outcomes.
These remain original roadmap work, not new lab setup prerequisites or an all-encounters matrix.

Additional file pins for this map:

| File | SHA-256 |
|---|---|
| EEex_Main.lua | `FDA7220723E357F5EF646F27ACFD1AC2ED87767AA62F281F65D1960674C5C368` |
| EEex_GameState_Patch.lua | `852155D021BC48B86FA490EF483ACB32C7E23DC7D98E1212C107FD8838096075` |

**Observations:** Several plausible hooks exist, but their meanings and registration forms differ.
**Counterevidence:** Initialized can be synchronous; loaded does not guarantee all dependent
objects; action-start says nothing about completed gameplay effects; cleanup is after teardown.
**Artifacts:** Authored map and private copied source only; reproduce with catalog pins and these
line anchors. No callbacks registered, tracing installed, native code loaded or game launched.
**Applicable evidence:** E1 source bodies/comments, not measured E4 lifecycle safety.
**Residual uncertainty:** Cadence, thread context, ordering, mutable-field lifetime, reload cleanup,
save/area coverage and actual bootstrap order.
**Later checkpoint:** Task3 is complete and the [Task8 observer probe](EEEX-03-observer-probe.md)
records bounded E4 startup/reload/session evidence. Consult its limits before action research;
this original E1 map does not itself prove additional hooks or a general scheduler.
