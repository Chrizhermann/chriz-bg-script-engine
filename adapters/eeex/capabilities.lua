-- Task 7 host contract only. Presence is not native-call safety or activation permission.
-- This file has no bootstrap and must not be installed as an auto-loaded M_ script.
local requirements = {
    { "initialized", "EEex_GameState_AddInitializedListener" },
    { "session_destroyed", "EEex_GameState_AddDestroyedListener" },
    { "sprite_loaded", "EEex_Sprite_AddLoadedListener" },
    { "actor_lookup", "EEex_GameObject_Get", "EEex_GameObject_IsSprite" },
    { "party_iteration", "EEex_Sprite_GetNumCharacters", "EEex_Sprite_GetInPortrait" },
    { "area_iteration", "EEex_Area_ForAllOfTypeInRange" },
    { "script_slots", "EEex_AIBase_GetScriptLevelResRef" },
    { "action_started", "EEex_Action_AddSpriteStartedActionListener" },
    { "action_queue", "EEex_Action_QueueResponseStringOnAIBase" },
    { "sprite_persistence", "EEex_Sprite_AddMarshalHandlers" },
    { "resource_lookup", "EEex_Resource_Fetch" },
}
local unresolved = {
    { "tick", "no-reviewed-public-tick-registration" },
    { "clock", "clock-definition-and-units-unverified" },
}

local M = {}

-- The caller supplies an explicit snapshot of named functions, not an engine object.
-- rawget avoids proxy lookups; do not call, retain, or return any supplied function.
function M.detect(functions)
    assert(type(functions) == "table", "expected an injected function table")
    local profile = {
        schemaVersion = 1,
        kind = "function-presence",
        runtimeVerified = false,
        capabilities = {},
    }
    for _, requirement in ipairs(requirements) do
        local missing = {}
        for i = 2, #requirement do
            local name = requirement[i]
            if type(rawget(functions, name)) ~= "function" then
                missing[#missing + 1] = name
            end
        end
        local present = #missing == 0
        profile.capabilities[#profile.capabilities + 1] = {
            id = requirement[1],
            status = present and "present" or "unavailable",
            reason = present and "functions-present-runtime-unverified"
                or "missing-or-not-function: " .. table.concat(missing, ", "),
        }
    end
    for _, entry in ipairs(unresolved) do
        profile.capabilities[#profile.capabilities + 1] = {
            id = entry[1], status = "unresolved", reason = entry[2],
        }
    end
    return profile
end

return M
