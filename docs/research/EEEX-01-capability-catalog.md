# EEEX-01: initial capability catalog and pure presence contract

**Outcome:** Task 7 host contract implemented; EEEX-01 research and G1 remain open.
**Question:** Which named functions can we identify without making speculative engine calls?
**Environment:** Offline SCS-reference copy described in the [lab runbook](disposable-lab-runbook.md):
BG2:EE 2.7.3.0, EEex 1.2.0/LuaJIT. This is observed-only, not a new supported baseline.
**Method:** Read exact copied Lua files, pin their bytes below, distinguish global wrappers from
userdata methods, then test an authored function-presence module with injected inert functions.
No upstream EEex file or DLL was executed. A version label alone is not the source pin.

## Contract

`adapters/eeex/capabilities.lua` exports `detect(functions)`. Supply an explicit named-function
table. It checks direct entries using `rawget` and `type`; it never calls or retains a supplied
function, reads an EEex global, registers a listener, or creates an engine object.

The data-only result has `schemaVersion=1`, `kind="function-presence"`, `runtimeVerified=false`
and an ordered `capabilities` array. Each entry has an ID, status and reason:

- `present`: the named functions exist; signature, implementation and runtime safety are unproved.
- `unavailable`: at least one exact name is absent or not a function; the reason lists those names.
- `unresolved`: no reviewed mapping yet. Tick and clock stay unresolved even if similarly named
  functions are injected. No guessed aliases, whole-profile success flag or implicit activation.

Eleven initial groups cover initialization/cleanup, sprite loading, actor lookup, party/area
iteration, script slots, action start/queue, marshal and resource lookup. Presence is deliberately
not a full dependency-closure check. A present wrapper with absent native dependencies, a changed
signature or a wrong EEex version still cannot authorize use. Additional rows below are cataloged
for later wrappers, not silently included as supported operations in v1.

The JSON schema describes output shape, not runtime admission or complete/unique capability
membership. The producer/tests enforce stable ordering and unique IDs. A future activation layer
must additionally validate the runtime/version profile and required disposable probes.
Nothing installs or bootstraps this module yet. Unknown content stays legacy-owned.

## Candidate API map (all E1, runtime unverified)

Paths are under the copied `EEex_scripts/`. Signatures below are global Lua wrappers unless
explicitly labeled as fields. Several also have userdata-method aliases; never confuse the two.
None should be called merely to discover whether it exists.

| Need / signature | Source anchor | Convention, limit and next proof |
|---|---|---|
| `EEex_GameState_AddInitializedListener(listener)` | `EEex_GameState.lua:82–96` | No arguments to listener; may invoke immediately during registration. Engine-Lua initialization is not new-game/save readiness. Task 8. |
| `EEex_GameState_AddDestroyedListener(listener)` | `EEex_GameState.lua:100–109,143–147` | Cleanup after a game session; source mentions menu/load. Append-only registration; no removal shown. Task 8 lifecycle trace. |
| `EEex_Sprite_AddLoadedListener(func)` | `EEex_Sprite.lua:6–10,1588–1602` | Callback receives sprite after effect-list unmarshal. Does not prove every field, other actor or area is ready. Task 8. |
| `EEex_GameObject_Get(objectID)`; `EEex_GameObject_IsSprite(object,allowDead)` | `EEex_GameObject.lua:194–204,230–246` | Numeric session ID to userdata/nil; boolean sprite check, `allowDead` documented boolean default false. Re-resolve, do not persist ID/userdata. Invalid/stale handle may cross native boundary; disposable proof required. |
| `EEex_Sprite_GetNumCharacters()`; `EEex_Sprite_GetInPortrait(portraitIndex)` | `EEex_Sprite.lua:163–182` | Number of party members; zero-based portrait index to sprite/nil. Party only, not general encounter enumeration. |
| `EEex_Area_ForAllOfTypeInRange(area,x,y,aiObjectType,range,func,los,nonSprites,terrainTable)` | `EEex_Area.lua:110–155` | Callback receives resolved object; requires live area and parsed object filter. Comments describe boolean defaults, but code uses `los or 1` / `nonSprites or 0`: Lua false and numeric 0 differ. Do not guess native boolean encoding; probe before wrapper use. |
| `EEex_AIBase_GetScriptLevelResRef(aiBase,scriptLevel)` | `EEex_AIBase.lua:25–71` | Levels 0/1/2/4/5/6/7; returns resref string or empty string. Native object lifecycle/actual slot priority still require engine proof. |
| `EEex_Action_AddSpriteStartedActionListener(func)` | `EEex_Action.lua:180–184,326–339`; `EEex_Action_Patch.lua:65–84` | `(sprite,action)` callback, excludes NoAction at hook. Start only, not success/completion. Append-only. Task 9 postconditions still required. |
| `EEex_Action_QueueResponseStringOnAIBase(responseStr,pGameAIBase)` | `EEex_Action.lua:56–77` | String plus actor userdata; parses and queues. No completion result. Invalid parse/object/lifecycle can fail; never probe by queuing. Task 9. |
| `EEex_Sprite_AddMarshalHandlers(handlerName,exporter,importer)` | `EEex_Sprite.lua:983–990,1268–1294,1431–1438` | Named handlers; exporter(sprite) returns table/nil, importer(sprite,table). Key replacement, not append. Scalar durable schema and actual save/load ordering remain Task 10. |
| `EEex_Resource_Fetch(resref,extension)` | `EEex_Resource.lua:95–127` | Strings to resource userdata/nil, not a safe decoded payload. Invalid extension/native layout/lifetime unproved. Use a known resource in a disposable read probe later. |
| Current action: `sprite.m_curAction.m_actionID` field | `EEex_Action.lua:326–339`; `EEex_Debug.lua:127–143` | Ephemeral userdata view, not a dedicated completion API. No field probing in the presence module. Task 9. |
| `EEex_Sprite_GetCastTimer(sprite)` / `GetCastTimerPercentage(sprite)` | `EEex_Sprite.lua:640–666` | Source comments: timer -1..99, -1 aura-free; percentage `(timer+1)/100`. Nil returns 0, so numeric output alone cannot establish actor validity. Not cast completion. |
| `EEex_Sprite_GetSpellState(sprite,spellStateID)` | `EEex_Sprite.lua:577–580` | Numeric ID to boolean via active stats; no proof of safe partially loaded stats or complete spell legality. |
| `EEex_AIBase_SetStoredScriptingTarget(aiBase,targetKey,target)` / `GetStoredScriptingTarget(aiBase,targetKey)` | `EEex_AIBase.lua:180–190` | String key; setter stores session ID in UDAux, getter re-resolves. Getter is not a durable identity contract; setter mutates. Never persist these IDs. |
| `EEex_Area_GetVisible()` | `EEex_Area.lua:2–11` | Area userdata/nil; not an area-transition listener. Absence of a current area must prevent dependent reads. |
| `EEex_FunctionLog(message)` / `EEex_TracebackPrint(message,levelMod)` | `EEex_Assembly.lua:122–142` | Console diagnostics; `EEex_Error` throws, `EEex_MessageBox` pauses the game. Do not substitute modal UI for logging. Bounded diagnostics remain future kernel work. |
| General tick, clock, area enter/leave, save-start/save-finish | `B3TimeStep.lua:48–88`; `EEex_UncapFPS_Patch.lua:170–217` | Private tick/game-time access and `Infinity_GetClockTicks()` call sites are not a reviewed public interface. Area hooks found are native-only. Deferred, not claimed absent from the whole engine. |

For all userdata/native rows, a Lua `pcall` is not a native-crash containment guarantee. Until
the corresponding E4 probe passes, the fallback is no dependent engine operation and legacy
ownership. Missing optional functions eventually disable only their dependent features;
missing core lifecycle safety prevents kernel activation. This module performs neither activation
nor fallback mutations; it reports facts for that later boundary.

## Source identities and reproduction

The approved lab path is private in `.work/task3/practical-lab-20260927.json`. Read, do not execute,
the following files; reproduce pins with `Get-FileHash -Algorithm SHA256`. These are raw-byte
installed-source pins, not a claim that an upstream release tag matches every installed file.

| File | SHA-256 |
|---|---|
| EEex_GameState.lua | `0B7088F2E0C366FCCD5B08E425EB70A7D009223377140788FD298CECBF3A9FF9` |
| EEex_GameObject.lua | `2B141EC407E3A649D8614863BFCB39B38048449FC8323613B3CF7B21904E74EE` |
| EEex_Area.lua | `884BA370221509C862DBE4BDC91E251C960F1A811BF05FC33D4A28AF8114D17C` |
| EEex_AIBase.lua | `0DC10FD165EFF282BC907DE7B982E5A07352ACAD77298447014C186A8A634A7F` |
| EEex_Action.lua | `18EA2ED7974984D7DA66AC315CA035574CC4FAA2802F55C4F431EFCA2862787B` |
| EEex_Action_Patch.lua | `29D4D0981788E77F41A7D00DFAE1F6949426CD6CCBEB04608AD97FE16433F761` |
| EEex_Sprite.lua | `ECD341BAE5295D3DB5A52279F84C55A4FF173150665A94B450EF3DFCF6CB3B4E` |
| EEex_Resource.lua | `405FF08EEFD4E50CECC66FEC5871992A7D118CCBD70EE1CDADEBADFE994734CF` |
| EEex_Debug.lua | `3F3B6A16B9DBBF5FCB2E82EA65757A15CC4BEA893220A5D7086AC9E6DF06FF3C` |
| EEex_Assembly.lua | `7C0CC25023F084BF679EE6CEB3A1D8E34DB82B3BA15D02973AB0BF04727AAB0D` |
| B3TimeStep.lua | `8B500C8901344A9B22B7959250C247401EC2C68F0978AB019A2F483BF16CDFAC` |
| EEex_UncapFPS_Patch.lua | `E441B41CEC1CBC9C00D2091F49E034BBB5D4FD3F512C888458CDBF16E1579552` |

**Observations:** Exact-name presence is detectable without invoking EEex. Function existence
cannot reveal signature drift or safe access windows. See the [lifecycle map](EEEX-02-lifecycle-and-hook-map.md).
**Counterevidence:** Init may synchronously invoke; append-only listeners can duplicate; action
start is not completion; clock and cadence remain unresolved. Do not infer readiness from EEex_Active.
**Artifacts:** Authored catalog, Lua module/test, JSON schema and small pytest bridge only. Upstream
source remains private and reference-only; credit EEex by Bubb. No upstream payload committed.
**Applicable evidence:** E1 source inspection plus E2 pure contract; no E4 or EEEX research closure.
**Residual uncertainty:** Native safety, runtime versions, hook lifetime/cadence, boolean encoding,
save/load ordering, complete dependency closure and all action outcomes.
**Next decision:** Task 8 disposable observation after Task 3 launch/save permission and completion;
no gameplay/design decision is made by this host-only contract.

## Verification

Seven Lua behavior cases: empty input; present-but-never-called functions; renamed functions;
partial capability loss; proxy/callable-table rejection; deterministic isolated snapshots; invalid
input rejection. Each backend also checks the returned data against the schema shape. Tests do not
load upstream code, game DLLs or game files. Lupa is the optional `lua-test` development extra.

Initial RED: both explicit Lupa backends failed because `adapters/eeex/capabilities.lua` did not
exist. GREEN after implementation: both passed (seven cases each), initially in 0.04s. Runner:
CPython 3.11.9, pytest 8.4.2, Lupa 2.8, Lua 5.1 and LuaJIT 2.1.1774896198. This is host execution,
not the game's LuaJIT. The Windows LuaJIT run also printed `0xE24C4A02` diagnostics despite
passing with exit 0. Source diagnosis identifies the interaction: [LuaJIT uses Windows SEH for
Lua errors](https://github.com/LuaJIT/LuaJIT/blob/v2.1/src/lj_err.c), while [CPython 3.11.9 logs
the exception before continuing its handler search](https://github.com/python/cpython/blob/v3.11.9/Modules/faulthandler.c#L358-L417).
This supports a handled-error explanation here, not a general license to ignore crashes.

For the final focused run only, pytest's [documented per-run fault-handler switch](https://docs.pytest.org/en/stable/how-to/failures.html#fault-handler)
removed that misleading first-chance diagnostic. Assertions/negative cases remained unchanged;
the tradeoff is no fault-handler traceback if that process genuinely crashes. No repository-wide
setting was disabled. Final command, exit 0, 26 passed in 0.09s, no skips:

```powershell
python -X utf8 -m pytest -p no:faulthandler -q tests/schemas/test_capability_profile.py tests/schemas/test_scs_source_checkpoint.py tests/schemas/test_research_evidence_schema.py
```

Independent Sol review accepted the contract/test/schema boundaries and checked all 14 catalog/map
source pins. The lead rechecked those pins and consequential call bodies. No correction was needed
for this packet. Only Task 7's pure contract is complete; EEEX-01/02 runtime research remains open.
