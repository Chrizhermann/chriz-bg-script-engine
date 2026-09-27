-- Authored synthetic probe. Void listeners only; no gameplay writes or retained userdata.
local M = {}

local function disable(state, reason)
    if not state.disabled then
        state.disabled = reason
        state.failures = (state.failures or 0) + 1
    end
end

function M.dispatch(state, key, ...)
    if state.disabled then return end
    local ok, available = pcall(state.available)
    if not ok or not available then disable(state, 'capability-lost'); return end
    local handler = state.handlers[key]
    if not handler then return end
    -- Arguments live only on this stack. These particular listeners have no return contract.
    if not pcall(handler, ...) then disable(state, 'callback:' .. key) end
end

function M.attach(state, register, handlers, available)
    if state.disabled then return state end
    state.handlers, state.available = handlers, available
    state.registrations = state.registrations or {}
    state.generation = (state.generation or 0) + 1
    local keys = {}
    for key in pairs(register) do keys[#keys+1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        if not state.registrations[key] then
            state.registrations[key] = 1 -- before registration, which may invoke synchronously
            local callback = function(...) return M.dispatch(state, key, ...) end
            if not pcall(register[key], callback) then
                disable(state, 'registration:' .. key)
                break -- append-then-error is ambiguous; never retry it in this process
            end
        end
    end
    return state
end

local required = {
    'EEex_GameState_AddInitializedListener', 'EEex_GameState_AddDestroyedListener',
    'EEex_Sprite_AddLoadedListener', 'EEex_Sprite_GetName', 'EEex_Sprite_GetInPortrait',
    'Infinity_IsMenuOnStack', 'Infinity_GetTransitionInProgress',
}

function M.boot(globals)
    local root = rawget(globals, 'B-')
    if root ~= nil and (type(root) ~= 'table' or
        rawget(root, 'project') ~= 'chriz-bg-script-engine' or rawget(root, 'schema') ~= 1) then
        return nil, 'occupied-root'
    end
    if not root then
        root = {project='chriz-bg-script-engine', schema=1}
        rawset(globals, 'B-', root)
    end
    local state = root.observerProbe
    if state ~= nil and (type(state) ~= 'table' or state.identity ~= 'synthetic.observer-probe/v1') then
        return nil, 'occupied-probe'
    end
    if not state then
        state = {identity='synthetic.observer-probe/v1', events={}, sequence=0,
            epoch=0, loadedAll=0, capabilities={}}
        root.observerProbe = state
        for _, name in ipairs(required) do state.capabilities[name] = rawget(globals, name) end
    end
    local function available()
        if not rawget(globals, 'EEex_Active') then return false end
        for _, name in ipairs(required) do
            if type(state.capabilities[name]) ~= 'function' or
                rawget(globals, name) ~= state.capabilities[name] then return false end
        end
        return true
    end
    local function record(kind, name, area)
        state.sequence = state.sequence + 1
        if #state.events == 256 then table.remove(state.events, 1) end
        state.events[#state.events+1] = {seq=state.sequence, kind=kind,
            generation=state.generation or 0, epoch=state.epoch, name=name, area=area}
    end
    if not available() then disable(state, 'capability-lost'); return state end
    local api = state.capabilities
    local handlers = {
        initialized=function() record('initialized') end,
        destroyed=function()
            state.epoch = state.epoch + 1
            state.lastArea = nil
            record('session-destroyed') -- never inspect objects after cleanup
        end,
        loaded=function()
            state.loadedAll = state.loadedAll + 1
            record('sprite-loaded') -- counts only: no field is assumed safe during unmarshal
        end,
        sample=function()
            if not api.Infinity_IsMenuOnStack('WORLD_ACTIONBAR') or
                api.Infinity_GetTransitionInProgress() then return end
            local sprite = api.EEex_Sprite_GetInPortrait(0) -- re-resolved on each call
            if not sprite then return end
            local name = api.EEex_Sprite_GetName(sprite)
            if name ~= 'BGSE Lab Test' then return end
            local area = sprite.m_pArea
            local resref = area and area.m_resref:get() or ''
            if resref ~= state.lastArea then
                state.lastArea = resref
                record('fixture-area-sampled', name, resref)
            end
        end,
    }
    M.attach(state, {
        initialized=api.EEex_GameState_AddInitializedListener,
        destroyed=api.EEex_GameState_AddDestroyedListener,
        loaded=api.EEex_Sprite_AddLoadedListener,
    }, handlers, available)
    state.sample = function() M.dispatch(state, 'sample') end
    if not state.disabled then record('bootstrap') end
    return state
end

return M
