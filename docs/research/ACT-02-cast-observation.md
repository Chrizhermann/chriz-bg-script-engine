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
