-- Synthetic handoff research only. No native calls, dispatch, persistence or listeners.
local module = {}

function module.new(capable)
    assert(type(capable) == 'function', 'capability predicate required')
    local bridge = {}
    local actorId, mode, consumed, accepted, noted
    local enabled, reason, sequence, events = true, 'unarmed', 0, {}
    local function emit(event, id, outcome)
        sequence = sequence + 1
        if #events == 32 then table.remove(events, 1) end
        events[#events + 1] = {sequence=sequence, event=event, actorId=id, outcome=outcome}
    end
    local function scalarId(id)
        return type(id) == 'number' and id >= 0 and id < 4294967295 and id == math.floor(id)
    end
    function bridge.arm(id, selectedMode)
        assert(scalarId(id), 'synthetic actor ID required')
        assert(selectedMode == 'allow' or selectedMode == 'decline' or selectedMode == 'error',
            'unknown research case')
        actorId, mode = id, selectedMode
        enabled, consumed, accepted, noted, reason = true, false, false, false, 'armed'
        emit('armed', id, selectedMode)
    end
    function bridge.claim(id)
        if not scalarId(id) then return false end
        if not enabled or id ~= actorId or consumed then
            emit('declined', id, not enabled and 'disabled' or 'not-armed')
            return false
        end
        consumed = true
        local ok, available = pcall(capable)
        if not ok or available ~= true then
            reason = ok and 'capability-missing' or 'capability-error'
            emit('declined', id, reason)
            return false
        end
        local success, result = pcall(function()
            if mode == 'error' then error('deliberate synthetic policy failure') end
            return mode == 'allow'
        end)
        accepted = success and result == true
        reason = not success and 'policy-error' or (accepted and 'accepted' or 'policy-decline')
        emit('claim', id, reason)
        return accepted
    end
    function bridge.note(id)
        if not enabled or id ~= actorId or not accepted or noted then return false end
        noted = true
        emit('action-observed', id, 'not-completion-proof')
        return true
    end
    function bridge.disable()
        enabled, actorId, mode, accepted, noted, consumed = false, nil, nil, false, false, true
        reason = 'disabled'
        emit('disabled', nil, reason)
    end
    function bridge.snapshot()
        local copy = {}
        for i, row in ipairs(events) do
            copy[i] = {sequence=row.sequence, event=row.event, actorId=row.actorId, outcome=row.outcome}
        end
        return {enabled=enabled, actorId=actorId, accepted=not not accepted, noted=not not noted,
            reason=reason, eventCount=sequence, events=copy}
    end
    return bridge
end

return module
