# SPACE-01: bounded coordinate and query evidence

Date: 2026-10-04. Task28; E1 + bounded E4 query evidence and separate E2 reducers.
This is not general pathfinding, movement arrival or wall-LOS acceptance.

## Question and environment

Can the current pilot measure its footprint and nearby candidate positions without
confusing an open destination with a reachable route? Use the approved disposable
BG2:EE2.7.3.0 / EEex1.2.0 LuaJIT / EET14 / SCS35.21 / SR4.21-chriz.5 stack.
The exact executable and resource pins are in COMBAT-01 and the private receipt
`.work/task28/source-inspection.json`. Relevant installed source hashes:

- `EEex_Area.lua`: `884BA370221509C862DBE4BDC91E251C960F1A811BF05FC33D4A28AF8114D17C`.
- `EEex_Sprite.lua`: `ECD341BAE5295D3DB5A52279F84C55A4FF173150665A94B450EF3DFCF6CB3B4E`.

The source boundary divides raw coordinates by16 horizontally and12 vertically
when calling `GetNearestOpenSquare`, then multiplies the returned square by16/12.
`getPersonalSpace()` reads the animation's value or its declared override. Neither
operation returns a route. The range wrappers parse/free `CAIObjectType`; their
`flag or 1` expression means Lua `false` cannot disable LOS. Use numeric1/0 in the
reviewed wrapper, not a raw object-type integer or guessed native signature.

## Method and observations

One hidden session reused the existing13-target fixture recipe. Fresh pong and
cloud0 preceded loading only own save973, entering quiet BG2602, and creating the
same three authored mages/one target. No active-session harness was loaded, no
save created, and no movement or cast was requested by this probe.

The lead reviewed the installed definitions, aliases and parameter order; the
probe compiled on Lua5.1/LuaJIT before its single native invocation. Mage0 was at
(224,192), the other mages at(272,192)/(304,192), target at(384,216), and party
fixture at(200,186). Mage0 personal space returned3.

| Requested raw position | Nearest-open result |
| --- | --- |
| 224,192 | 192,204 |
| 192,192 | 176,204 |
| 256,192 | 224,216 |
| 224,168 | 176,204 |
| 224,216 | 224,216 |

The numericLOS1 and LOS0 range448 queries each returned all five sprites. That
proves these call shapes executed in this open room, not that the two flags are
equivalent around walls. The probe returned normally in3ms. The final party
action and queue were empty; cloud remained0. The owned job stopped, all13 staged
targets reconciled (three originals restored/ten additions removed), own IPC
removed and matching reservation released. No active game or personal save used.

## Product behavior and counterevidence

`spatial.sample` emits at most eight caller-selected offsets. `evaluate` requires
current perceived positions/relations, a declared path-proof identity, and a query
bound to scene, observer, tick, origin, destination and the exact actor frame.
Open, reachable, LOS and sufficient clearance are separate requirements. Current
nearest-open results supply **none of the missing path proof**. Native movement
therefore remains unavailable; the recorded five positions are all excluded.

Host examples cover occupied/unreachable/narrow destinations, unknown queries,
stale actor frames, caster threat and explicitly weighted retreat preference.
An independent review reproduced same-tick actor-frame reuse; focused RED/GREEN
fixed it. The integrated candidate/utility/choice/trace path now accepts
`shadow-position` proposals only with supplied proof; dispatch still rejects them.
Weights and metric scales are explicit test/caller inputs, not balance defaults.

The earlier active-pilot `MoveToPoint` endpoint failures remain failures: exact
arrival was not proved by this query batch. The matched legacy-control route in
G5 proves handback equivalence only. Personal-space3 is a native query value;
do not silently treat it as three raw pixels or a full footprint polygon.

## Reproduction, uncertainty and next decision

Private source/recipe/result: `.work/task28/spatial-query.lua`,
`spatial-runtime-v1/{README.md,source-identities.json,spatial-query-result.json,final-state.json,cleanup-result.json}`.
`analyze-query.py` replays recorded coordinates on both host Lua backends, with
path capability deliberately false. Host suite: `scripts/test.ps1 -Suite all -Seed 47`.

Task28 delivers the conservative scalar/query layer. SPACE-01/03 are not closed
for obstacles, different animations/terrain, path travel, collision avoidance or
arrival. Before activating movement, supply a reviewed route/clearance metric and
one representative movement batch with actual destinations observed. Do not expand
this into a custom path planner. No gameplay decision or native movement was added.
