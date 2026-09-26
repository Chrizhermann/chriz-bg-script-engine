-- Pure contract tests. No EEex source, DLL, userdata or game is loaded.
local module_path = ...
local chunk = assert(loadfile(module_path))
setfenv(chunk, setmetatable({
    assert = assert, type = type, rawget = rawget, ipairs = ipairs, table = table,
}, { __index = function(_, key) error("unexpected global: " .. key) end }))
local capabilities = chunk()

local names = {
    "EEex_GameState_AddInitializedListener", "EEex_GameState_AddDestroyedListener",
    "EEex_Sprite_AddLoadedListener", "EEex_GameObject_Get", "EEex_GameObject_IsSprite",
    "EEex_Sprite_GetNumCharacters", "EEex_Sprite_GetInPortrait",
    "EEex_Area_ForAllOfTypeInRange", "EEex_AIBase_GetScriptLevelResRef",
    "EEex_Action_AddSpriteStartedActionListener", "EEex_Action_QueueResponseStringOnAIBase",
    "EEex_Sprite_AddMarshalHandlers", "EEex_Resource_Fetch",
}
local function forbidden() error("capability detection called an engine function") end
local function complete()
    local functions = {}
    for _, name in ipairs(names) do functions[name] = forbidden end
    return functions
end
local function find(profile, id)
    for _, item in ipairs(profile.capabilities) do
        if item.id == id then return item end
    end
    error("missing capability: " .. id)
end
local function data_only(value)
    local kind = type(value)
    if kind == "table" then
        assert(getmetatable(value) == nil)
        for key, child in pairs(value) do
            assert(type(key) == "string" or type(key) == "number")
            data_only(child)
        end
    else
        assert(kind == "string" or kind == "boolean" or kind == "number")
    end
end

-- 1. Empty input: explicit reasons, never a silent fully-capable profile.
local empty = capabilities.detect({})
assert(empty.schemaVersion == 1 and empty.kind == "function-presence")
assert(empty.runtimeVerified == false)
for _, item in ipairs(empty.capabilities) do
    assert(item.status == "unavailable" or item.status == "unresolved")
    assert(#item.reason > 0)
end

-- 2. Complete named functions are observed, not called or treated as safe.
local full = capabilities.detect(complete())
for _, id in ipairs({"initialized", "session_destroyed", "sprite_loaded", "actor_lookup",
    "party_iteration", "area_iteration", "script_slots", "action_started", "action_queue",
    "sprite_persistence", "resource_lookup"}) do
    assert(find(full, id).status == "present", id)
end
assert(full.runtimeVerified == false)
assert(find(full, "tick").status == "unresolved")
assert(find(full, "clock").status == "unresolved")
data_only(full)

-- 3. Renamed function: exact supported spelling only, no guessed alias.
local renamed = complete()
renamed.EEex_Resource_Fetch = nil
renamed.EEex_Resource_FetchV2 = forbidden
local missing = find(capabilities.detect(renamed), "resource_lookup")
assert(missing.status == "unavailable")
assert(missing.reason == "missing-or-not-function: EEex_Resource_Fetch")

-- 4. Partial compound capability fails locally; unrelated ones remain present.
local partial = complete()
partial.EEex_Sprite_GetInPortrait = false
local reduced = capabilities.detect(partial)
assert(find(reduced, "party_iteration").status == "unavailable")
assert(find(reduced, "actor_lookup").status == "present")
assert(partial.EEex_Sprite_GetInPortrait == false) -- input was not changed

-- 5. Proxy lookups and callable tables are not function-presence evidence.
local proxy = setmetatable({}, { __index = forbidden })
proxy.EEex_Resource_Fetch = setmetatable({}, { __call = forbidden })
assert(find(capabilities.detect(proxy), "resource_lookup").status == "unavailable")

-- 6. Stable ordering/reasons and independent returned snapshots.
local again = capabilities.detect(complete())
assert(#again.capabilities == #full.capabilities)
for i, item in ipairs(full.capabilities) do
    local other = again.capabilities[i]
    assert(item.id == other.id and item.status == other.status and item.reason == other.reason)
end
full.capabilities[1].status = "changed-by-caller"
assert(again.capabilities[1].status == "present")

-- 7. Non-table input is a caller error, not evidence of engine capability.
assert(not pcall(capabilities.detect, nil))
return again
