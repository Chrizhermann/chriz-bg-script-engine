# Task9 ordinary cast observation

**Question:** Can we distinguish an ordinary self-cast request, its start, and its actual result?
**Status:** One ordinary self-cast proved on the stated fixture/stack. Task9/G1 remain open.

Same isolated comparison stack as [Task8](EEEX-03-observer-probe.md): BG2:EE2.7.3.0,
EET14.0, EEex1.2.0/LuaJIT, SCS35.21, SR4.21-chriz.5 and Bubb Spell Menu5.2. Exact
lab/executable/profile identities remain in the private staging record. No active-game use.

## Fixture and reproducible method

The original protagonist has no spells. Build a private technical fixture with
`experiments/action-observer/build-cast-fixture.tp2` using the pinned WeiDU24900 and `--nogame`:

```text
weidu.exe build-cast-fixture.tp2 --nogame --force-install-list 0
  --args <read-only-lab-override> --args <private-output-directory>
  --no-exit-pause --quick-log
```

Run in a new private working directory; the wrapped line above represents one command. No
installer runs against the lab. The generated ARE/CRE are derived private test artifacts, not
redistributable content. Retain SCS/DavidW and Spell Revisions/Demivrgvs provenance; no migration
or redistribution permission is inferred from using these local donors.

- Quiet room: privately patch BG2602.ARE actor/region/spawn counts and area script to empty.
  Keep WED/art references unchanged. Temporarily stage into the lab with an exact original
  backup; restore after the owned process stops. This avoids a new map/asset system.
- Caster: privately clone MAGE6B to B-XMAGE0, clear five scripts/dialogue and all CRE effects,
  set ally EA4 and unique `B-XCAST0` death variable. Keep the kit and add one SPWI212: two
  ready memorized copies total. Removed donor effects were eight op326 references to C0PR#*
  resources, not an assumed safe blank baseline. No party join or auto-levelling.
- Load only our earlier own save973, whose saved area archive contains BG2600 but not BG2602;
  enter the quiet room and create one synthetic caster. Save974 already bakes the old room/NPC
  and is unsuitable. Do not load imported personal-save copies or save this temporary fixture.
- After the actor settles, explicitly load `B-XACT02.lua`. Fresh-resolve the sole matching
  DV/resource/EA in the room. Inspect idle action/queue, state0, aura-1, two quick-list copies,
  two available memorized records and no source-SPWI212 timed effects before submission.
- Queue exactly one ordinary `SpellRES("SPWI212",Myself)`. Require its exact ID31/resref queue
  entry for acceptance, match the start listener, then independently sample after engine time
  advances. Completion requires both counts2->1, unchanged record total, and a new timed
  source-SPWI212 opcode159 effect. No forced cast, effect injection, aura reset or queue clear.

## Static/build evidence and review

Effective SPWI212 is Mirror Image on this SR stack, not a vanilla-name guess: wizard level2,
self-targeting, cast-time2, timed op159 plus op206 in its first ability. Other installations
must inspect their effective spell rather than reuse this mapping blindly.

| Input or private output | SHA256 |
|---|---|
| WeiDU24900 | `ad70f5897a6d0ba4b0d226f845a9b14cf345f56cc9697ca8d05cac9fe4932c1a` |
| Input BG2602.ARE | `b5dd336565c6f2d334b6f75857d8cb74f867b7403110329b3f846fd01c7f968b` |
| Input MAGE6B.CRE | `307409e704df61dafc604ffac04abc99951a2849cf96ad7596c354ba81e722f4` |
| Effective SPWI212.SPL | `2202b5946a1d1debac2c67ff24ce9aac4d14dd7c2a57fd5d9b099b84def4feee` |
| Private quiet BG2602.ARE | `1138e201a9a193ef5ca8f31bdda48b477f0434959cc6e9fe9f6108b177700c29` |
| Private B-XMAGE0.CRE | `02a291f6e307a45645316742527cdb6a715a1f8619331f7d44c2b53f011985df` |
| EEex_Sprite.lua | `ecd341bae5295d3db5a52279f84c55a4ff173150665a94b450ef3dfcf6cb3b4e` |
| B3EffMen.lua | `41b4af98091ffd2c072d9cf27ee8f50884053f7b6f421bbaad5bb7959d944db2` |

Action/IDS source pins are in [ACT-01](ACT-01-action-state-model.md). EEex's source documents
castCounter -1 as aura-free; zero must not be mistaken for that. B3Hotkey frees the owned
GetQuickButtons list; the observer follows that lifetime pattern. EEex_Debug shows the
action string field shape. B3EffMen demonstrates timed source-resource effect enumeration.
The research probe records copied scalars, never saves engine IDs/userdata, and does not
dereference sprites from the loaded callback.

Real WeiDU parse/build exited0. The lead independently checked the generated fields; original
inputs rehashed unchanged. Only the eight intended ARE bytes differ (spawn count already0).
No new test framework was added. A reviewer caught the Boolean disabled-field mismatch before
launch; a focused failing Lua assertion reproduced it, then true/1 normalization passed under
both Lua5.1 and LuaJIT along with parsing the complete probe. See the private build receipt for
exact commands and clearly labelled transcript-derived output summaries, not invented raw logs.

## Evidence boundary and remaining questions

The preparation above establishes E1 static/private build facts and limited E2 expression checks.
This `--nogame` fixture build is not an E3 fake-game install/uninstall/restoration test. The
runtime below specifically checks whether this nonparty ally actually debits the spell;
do not assume player and nonparty behavior match. Empty queue, next action, start or an aura
change alone is insufficient completion evidence.

The observer's450-simulation-tick limit is a bounded diagnostic cutoff, not a proved production
deadline. A timeout remains unknown and does not cancel or retry the action. Contention, silence,
busy aura, interruption, target loss/movement, transition/save invalidation and Project Image
owner-lock exclusion remain required Task9 research; this one success cannot silently cover them.

Private artifacts: `.work/task9/cast-fixture-build-v1/` and `.work/task9/cast-v1/`. Preserve failed
evidence. Restore temporary ARE/menu/config, remove exact temporary additions after identity
checks, stop our own job and release only our matching reservation. No new full game copy.

## Runtime result — E4 ordinary self-cast, 2026-09-28

One hidden launch after the randomizer task finished its test, released the shared reservation,
and a bounded OS snapshot showed no game/loader/installer. Our exclusive token preceded staging.
The inherited desktop-isolation probe passed, a fresh Remote Console pong arrived, and cloud
capability was false. No visible desktop control, shared profile or original-game change.

**Setup correction:** after submitting `MoveBetweenAreas("BG2602",[200.186],0)`, the next
setup command hit a Lua nil-area error before
creating a caster. A read-only observation still showed the named party character, action0,
empty queue, world menu and no transition, but no `m_pArea`. This is a failed setup path, not
a cast failure or native crash; the exact transition mechanics/destination were not observed.
Reset the exact own save973 using the existing queued-menu
runner; then `C:MoveToArea("BG2602")` worked. The subsequent room inspection found only the
protagonist before creating the single fixture caster. Use this latter recipe when reproducing;
do not rerun the failed setup action. Both commands' evidence is retained privately.
The [documented console helper](https://gibberlings3.github.io/iesdp/appendices/clua/bgee.htm)
is a fixture-setup shortcut only, not movement or casting acceptance evidence.

| Observation | Recorded result |
|---|---|
| Settled caster preflight | Unique DV/resource/EA match; position(304,192), current0, empty queue, state0, aura-1, count2/ready2/total2, no source-SPWI212 timed effects. Observed position differed from requested creation point(350,186); no pathfinding conclusion. |
| Submission at simulation tick32692 | Exactly one queued ID31/SPWI212; `accepted`, starts0. Counts unchanged and no effects. |
| Start callback at32693 | ID31/SPWI212 matched, reducer `started` applied exactly once. |
| Independent sample at32888 | Count1/ready1/total2; new timed source-SPWI212 op159 and206 (native timing4096), current0, empty queue. Reducer `completed`. |
| Cleanup | Own helper/loader/game gone; nine temporary additions plus IPC removed; ARE/menu/config restored byte-exactly; matching token released. No save created. |

This proves one normally queued Mirror Image cast consumed one of this nonparty ally's real
memorized copies and produced its substantive effect. It does not establish the precise cast
duration or aura progression: those were only sampled before and later, not continuously.
Do not generalize to every nonparty actor, player, spell, install stack or contested queue.

The same quiet session also ran the existing movement probe once: accepted ID23 at(232,186),
one matching start, and later independent position(232,186), from(200,186). This now supplies
the missing movement postcondition without dialogue. Neither completed probe repairs the
unobserved historical result in the original movement-v1 run.

Evidence combination: E1 source/fixture + E2 host reducer + these E4 ordinary-cast/movement
observations. Task9 remains in progress because its adverse-condition/ownership matrix is
unproved. No production runtime or adapter activation is authorized. The prepared450-tick
cutoff was not exercised by this successful cast. Exact authored payload hashes are in the
private staging ledger; the undeployed movement source was sent through the console as a Lua
chunk. All private generated resources/logs stay out of Git.

Independent Sol review checked the actual request/result JSON and cleanup receipts; lead
accepted its correction to keep the first area-transition mechanism unknown. Existing focused
host validation remains12passed; Lua5.1/LuaJIT syntax and the reviewed Boolean fix also passed.

## Adverse-condition follow-up — 2026-09-29

Same pinned stack, quiet fixture and own save973. Research-only `B-XACT03.lua` reuses the
cast probe's scalar snapshots and wraps the existing Remote Console poll. It samples once per
changed simulation tick while world-ready; no new scheduler or native hook. Each trial has a
450-tick observation window, one submission/intervention latch and no retries/queue clearing.
`observed-window` means observation ended, not action success or cancellation. Fresh own-save
reload and caster recreation separate conditions; no test save is made.

The first session used source SHA256 `aeb1ef4bb9bc108b8be306e69683679bbfa4c0f4dcbaa9ed1802b4f1ec0363a3`.
Source is retained privately in `adverse-v1/B-XACT03-deployed.lua`. A second session uses the
corrected windup predicate described below; this is not a repeated aura/silence trial.
Sol source review required substantive op159 before a second cast and a later-tick silence
check before submission; both corrections preceded deployment.

Additional E1 source: EEex/Bubb `EEex_GameObject.lua`, SHA256
`2b141ec407e3a649d8614863bfcb39b38048449fc8323613b3cf7b21904e74ee`, lines382–447,
defines ApplyEffect fields/defaults. The existing Sprite pin defines GetState as active derived
state (587–589), and GetCastTimer as castCounter with -1 aura-free (640–644). Base generalState
is not sufficient to observe temporary silence. Effective SPWI212 flags at0x18 are0;
[SPL flags](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/spl_v1.htm#Header_Flags)
and [silence](https://gibberlings3.github.io/iesdp/opcodes/bgee.htm#op38) are documentation inputs,
not substitutes for the measured active-state bit. This fixture's effective spell provenance
and hash remain as recorded above; the experiment changes none of its bytes.

### Busy aura: action start precedes actual casting

- Submission/start32643; at32644 one copy was already spent, current31 and aura0, **no effects**.
- First op159/215/206 appeared32664 with current0 and aura20. Only then was the second ordinary
  cast submitted, with the busy aura still independently observed and total records unchanged.
- Second start callback32664 did not mean an immediate cast: count/ready stayed1 through32743.
  At32744 they became0 and aura reset0; action exited and transient op215 reappeared32764.
- The substantive op159 persisted from the first cast, so its presence alone cannot prove a
  separate second effect application or expiry refresh. Second expenditure/delay and renewed
  transient effect were observed; exact refreshed mirror count/duration was not measured.

All450 samples32644–33093 were consecutive. This demonstrates busy-aura delay on this actor,
not a universal100-tick timing contract. It also disproves expenditure-alone completion:
the first slot was spent20 sampled ticks before the first substantive effect appeared.

### Silence: started does not mean successfully cast

Apply one temporary op38, duration60seconds, to the synthetic caster only; target1, effectList1,
noSave0, immediateResolve1. This directly imposed condition is not a fair spell-delivery test.
At32602, a later tick confirmed activeState4096 before ordinary SpellRES submission. The exact
queue entry and matching ID31 start were recorded. All450 samples32602–33051 retained silence,
count2/ready2/total2, aura-1, no source-SPWI212 effects and current0. No expenditure or delivery
occurred in the observed window. The quick-list disabled flag remained false: do not rely on
that flag alone for silence eligibility. No native rejection reason was supplied by this probe.

### Review-driven correction before the other conditions

The initial contention/damage trigger required ready2 during windup. The actual aura trace
showed ready1 during the entire windup, so that predicate would never exercise the intended
condition. Neither trial had been submitted. Close/clean the first session, change only that
predicate to both counts one below baseline with unchanged total, current31, no effects and
a matched start at least3ticks earlier, then use a fresh session for the two remaining trials.
Independent review confirmed the revised condition against the recorded trace before launch.
Do not hot-patch native callbacks or repeat a completed trial to conceal the correction.

See [queue contention](ACT-04-queue-contention.md) and
[interruption](ACT-03-interruption-and-invalidation.md) for the remaining batch results.
Private evidence is `.work/task9/adverse-v1/` and `adverse-v2/`; source/recipe and exact responses
are retained, generated game resources remain private. E1+limited E2 syntax/host contract+E4
bounded observations only. Task9/G1 remain open for the rest of the declared action matrix.

Independent Sol review checked all four actual response files, both deployed-source hashes and
both cleanup receipts against ACT-02/03/04. No claim correction remained. Lead rechecked every
450-sample range/maxgap1, ran the existing12 focused host checks, compiled the revised Lua chunk
under Lua5.1/LuaJIT via Lupa2.8, and parsed persisted task JSON. Both owned game/loader/helper
trees were verified absent before cleanup; each session removed ten additions plus IPC and
restored the three original ARE/menu/config files, then released its matching token. This is
verified process absence/owned-job cleanup, not a claimed graceful executable exit code0.
No new full copy, save, broad test suite, public payload or production runtime was introduced.
