# KERNEL-01 — Four-character observer integration

Date: 2026-10-04 (local)

## Question and scope

Can the new scalar-only observer kernel identify explicitly enrolled characters, contain an
adapter exception, decline mismatched/unknown content, disable independently and forget
enrollment on load, while four ordinary legacy scripts continue casting and moving?

Evidence: **E1 + E2 + bounded E4**. This is an observer integration, not active Combat Intent,
an SCS migration, a real dependency-discovery result or a general compatibility guarantee.
Task16's exit is met. G2/G3 remain separate; Task17 carries the installer/control-content cases.

## Environment and artifacts

Current tested lab: BG2:EE2.7.3.0, EEex1.2.0/LuaJIT, EET14, SCS35.21,
SR4.21-chriz.5, Bubb's Spell Menu5.2. Offline fixture compiler: WeiDU24900.
Lab Steam DLL remains disabled. Only the separate lab, profile and own baseline973 were used;
no new save or game copy, active-game access or visible-desktop control.

Authored sources: `kernel/{bootstrap,engine,trace}.lua`, `adapters/eeex/{engine,listeners}.lua`,
`experiments/kernel-observer/` and `tools/build_observer_bundle.py`. Private build receipts,
source/tool identities, exact commands, deployed source, logs and cleanup are under
`.work/task16/{fixture-build-v1,bundle-v1,host-final-v1,observer-runtime-v1}`.

| Artifact | SHA256 |
| --- | --- |
| Loaded observer bundle | `5bde1e0826b909a27e919137c3b8f72d46bc5a9b7cfa1bf5b582e4100c622ab0` |
| Deployed behavior-session glue | `d4e66e2a598370bc63871d1ca06326e2712b119ef64d64aec925d61ee79eb642` |
| Closed1683-row behavior trace | `a6b4d074af53aa0db159ad1f928492d5553a967de6d33a604f09e1c3a27bcad4` |
| Closed360-row timing trace | `6f79d06e6148e53599d2b1191e22d66ddcdcb03a02476ab912d4831a588e6565` |
| Behavior/load result receipt | `3d94363a334688e8a54d602427dfc6fd3fe302cba98f4d17ba7b5d10512f3581` |

Engine, loader, Remote Console and two EEex source hashes matched the prior G1 pins.
Private generated CRE/BCS and upstream-derived donor bytes are not published.

## Method

One hidden session, one listener registration, ordinary BCS `SpellRES("SPWI214",Myself)`
followed by distinct `MoveToPoint` goals for four private synthetic casters. No ForceSpell,
queue clearing, effects substituted for casting or kernel action dispatch. Start, memorized
expenditure, later source-SPWI214 opcode44, displacement and completion were checked separately.

Actors0/2 had matching C1 declarations; actor1 had an intentionally false expected CRE digest;
actor3 was not registered. All actual CRE/BCS hashes were recorded. Eligibility environment
completeness flags were **injected for this authored observer fixture**, not discovered from
the installed game. They do not prove full spell, public-state or external-control closure.

The batch followed baseline → observing → four scripts → capability loss → one-adapter disable
→ epoch change → attempted old-epoch reuse → own named-load invalidation. Scalar trace stayed
bounded; no native objects were handed to observer callbacks or persisted.

## Observations

| Case | Result |
| --- | --- |
| Four ordinary casts | Exactly one action31/SPWI214 start each; ready copies2→1 of2; one later opcode44 effect each |
| Four ordinary moves | One action23 start each, independent displacement, within24pixels of requested goals, then idle/empty queue/done1 |
| Eligible observers | Actor0 received117 callbacks; actor2 received124 |
| Mismatched declaration / unknown actor | Zero callbacks for actors1/3; both completed their legacy casting/movement |
| Adapter-local exception | Actor2 alone had one error, seven circuit-open samples, then64 successful scripted-phase observations; actor0 continued |
| Capability loss | Fifteen missing-capability samples per enrolled actor, no additional callbacks |
| Individual disable | Actor0 declined; actor2 continued observing |
| Epoch drift and old-tag restoration | Fifteen stale-stack samples per actor in each window; no reactivation |
| Own named load | One destroyed event, enrollment3→0, own baseline restored, no remaining attempt/actor enrollment |

Final coordinates0–3 were (296,234), (360,246), (408,246), (456,246); engine position snapping
was allowed by the declared24pixel tolerance, not treated as exact-coordinate success.

This proves continued legacy behavior during ordinary observation and the injected callback
exception. Casting/movement finished before the capability/stale/load phases: it does **not**
prove new legacy actions under each later failure condition. It also does not prove post-load
re-enrollment, native-listener exception behavior or full unknown quest/controller pass-through.

## Counterevidence and corrections

Setup initially omitted the existing BG2600→BG2602 room-entry step, then returned the session
factory instead of invoking it. Neither attempt ran test actions. A space-separated response
created only the first caster; the population assertion stopped baseline before any observation
or scripted trial. The corrected helper reused the already-proved newline-separated action
recipe, verified all five scene actors and resumed that same untouched baseline/listeners.
An intermediate helper incorrectly compared userdata wrapper equality; it was replaced with
the explicit semantic protagonist/fixture checks before any remaining spawn action was queued.
All failed receipts and the first trace row remain preserved; these are not passed trials.

Host review also exposed recursive sampling, absent-actor drift detection, and invalidation
during a callback. Focused regressions pass; no unrelated validation was disabled. Host suite:
167passed across16files, Python3.11.9/pytest8.4.2/Lupa2.8, Lua5.1 and LuaJIT2.1.1774896198.

## Cost and comparison

The behavior glue initially used `os.clock`, whose coarse values are **not** microsecond
evidence. Before closing the same game session, a separate paired idle scene used Task10's
already-tested `EEex_Utility_GetMicroseconds`. Four windows of90samples each compared matching
native candidate scan + two admitted actor reads, with/without kernel eligibility/copies/trace.
All four characters were present; this follow-up did not repeat their spells.

| Window | Median µs | p95 µs (nearest rank) | Maximum µs |
| --- | ---: | ---: | ---: |
| Boundary1 | 379.5 | 813 | 7557 |
| Kernel2 | 779 | 1880 | 7001 |
| Kernel3 | 675.5 | 1493 | 1850 |
| Boundary4 | 380.5 | 784 | 933 |

Median intervals were66.65–66.77ms. Two kernel windows issued360 successful callbacks total.
Task10's five-actor basic snapshot medians138–142µs were a different workload: this boundary
rescans the area for each fresh identity. Extra manifest validation/copying and trace work is
visible here; no zero-overhead or production-scale budget claim. Outliers remain in the table;
GC/native scheduling were not separately attributed. G3 must name its tested scale explicitly.

Current session source uses the proved microsecond timer and matched two-read baseline for
future runs. That timing-only correction was syntax checked, not substituted into the already
completed behavior trial; the separate paired receipt is the actual timing evidence.

## Review, cleanup and next decision

Independent Sol source review and full-trace review accepted the bounded claims; lead checked
the receipts, independent postconditions and exact identities. Own helper/game job stopped;
all13 staged targets reconciled (three originals restored, ten additions removed), IPC preserved
then removed, matching reservation released. No new saves or large copies to delete.

Proceed to Task17's current-stack integration and G2/G3 evidence review. Preserve deferred
QuickLoad and area/dialogue continuation limitations from G1. No production AI ownership is
implied by the four characters completing their authored legacy scripts.
