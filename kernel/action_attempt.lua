-- Host-side action observation model. Proof labels must be established by an
-- engine adapter; this reducer only enforces the declared transition contract.
local M = {}

local states = {
    proposed = true, accepted = true, started = true, advanced = true,
    completed = true, failed = true, interrupted = true, invalidated = true,
    ["timed-out"] = true, unknown = true,
}
local terminal = {
    completed = true, failed = true, interrupted = true, invalidated = true,
    ["timed-out"] = true, unknown = true,
}
local reasoned = {
    failed = true, interrupted = true, invalidated = true,
    ["timed-out"] = true, unknown = true,
}
local progress = {
    proposed = {accepted = true},
    accepted = {started = true, completed = true, ["timed-out"] = true},
    started = {advanced = true, completed = true, interrupted = true, ["timed-out"] = true},
    advanced = {advanced = true, completed = true, interrupted = true, ["timed-out"] = true},
}
local proof = {
    ["independent-postcondition"] = true,
    ["trusted-engine-completion"] = true,
}

local function nonempty_string(value)
    return type(value) == "string" and #value > 0
end

local function scalar_copy(record)
    return {attemptId = record.attemptId, state = record.state, reason = record.reason}
end

function M.new(attempt_id)
    assert(nonempty_string(attempt_id), "attemptId must be a nonempty string")
    return {attemptId = attempt_id, state = "proposed"}
end

function M.reduce(record, event)
    assert(type(record) == "table" and nonempty_string(record.attemptId)
        and states[record.state], "invalid action record")
    assert(record.reason == nil or nonempty_string(record.reason), "invalid record reason")
    assert(type(event) == "table" and nonempty_string(event.attemptId)
        and states[event.kind], "invalid action event")
    assert(event.proof == nil or type(event.proof) == "string", "invalid proof shape")
    assert(event.reason == nil or nonempty_string(event.reason), "invalid reason shape")
    if reasoned[event.kind] then
        assert(nonempty_string(event.reason), "outcome requires a nonempty reason")
    end

    if record.attemptId ~= event.attemptId then
        return scalar_copy(record), "stale-attempt"
    end
    if terminal[record.state] then
        return scalar_copy(record), "terminal-attempt"
    end
    local allowed = progress[record.state][event.kind]
        or (event.kind == "failed" or event.kind == "invalidated" or event.kind == "unknown")
    if not allowed then
        return scalar_copy(record), "invalid-transition"
    end
    if event.kind == "completed" and not proof[event.proof] then
        return scalar_copy(record), "missing-proof"
    end

    return {attemptId = record.attemptId, state = event.kind, reason = event.reason}, "applied"
end

return M
