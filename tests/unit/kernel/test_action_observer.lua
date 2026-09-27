-- Pure action-state contract: seven focused scenarios, no engine calls.
local path = ...
local action = assert(loadfile(path))()

local function step(record, kind, extra)
    local event = {attemptId = record.attemptId, kind = kind}
    if extra then for key, value in pairs(extra) do event[key] = value end end
    return action.reduce(record, event)
end

-- 1. Acceptance, start and progress are observations, not completion.
local proposed = action.new("movement-1")
assert(proposed.attemptId == "movement-1" and proposed.state == "proposed")
local accepted, why = step(proposed, "accepted")
assert(accepted.state == "accepted" and why == "applied")
local started = step(accepted, "started")
local advanced = step(started, "advanced")
local again = step(advanced, "advanced")
assert(started.state == "started" and advanced.state == "advanced" and again.state == "advanced")

-- 2. Completion needs one of the two declared proof labels.
for _, state in ipairs({accepted, started, advanced}) do
    for _, proof in ipairs({"independent-postcondition", "trusted-engine-completion"}) do
        local completed, result = step(state, "completed", {proof = proof})
        assert(completed.state == "completed" and result == "applied")
    end
end

-- 3. Queue return, action start, next action and empty queue are not proof.
for _, proof in ipairs({"queue-return", "action-start", "next-action", "empty-queue"}) do
    local unchanged, result = step(accepted, "completed", {proof = proof})
    assert(unchanged.state == "accepted" and result == "missing-proof")
end
local no_proof, no_proof_reason = step(accepted, "completed")
assert(no_proof.state == "accepted" and no_proof_reason == "missing-proof")

-- 4. Stale attempts, terminal attempts and invalid edges cannot progress.
local stale, stale_reason = action.reduce(accepted, {attemptId = "movement-2", kind = "started"})
assert(stale.state == "accepted" and stale_reason == "stale-attempt")
local invalid, invalid_reason = step(proposed, "started")
assert(invalid.state == "proposed" and invalid_reason == "invalid-transition")
local completed = step(accepted, "completed", {proof = "independent-postcondition"})
local terminal, terminal_reason = step(completed, "started")
assert(terminal.state == "completed" and terminal_reason == "terminal-attempt")

-- 5. Failure and uncertainty outcomes preserve the given reason and terminate.
for _, kind in ipairs({"failed", "invalidated", "unknown"}) do
    local result, result_reason = step(proposed, kind, {reason = "fixture-" .. kind})
    assert(result.state == kind and result.reason == "fixture-" .. kind and result_reason == "applied")
    assert(select(2, step(result, "accepted")) == "terminal-attempt")
end
for _, state in ipairs({accepted, started, advanced}) do
    local timed = step(state, "timed-out", {reason = "deadline"})
    assert(timed.state == "timed-out" and timed.reason == "deadline")
end
for _, state in ipairs({started, advanced}) do
    local interrupted = step(state, "interrupted", {reason = "interruption"})
    assert(interrupted.state == "interrupted" and interrupted.reason == "interruption")
end
assert(select(2, step(proposed, "timed-out", {reason = "deadline"})) == "invalid-transition")
assert(select(2, step(accepted, "interrupted", {reason = "interruption"})) == "invalid-transition")

-- 6. Neither input is mutated; output contains only independent scalar fields.
local handle = {}
local input = {attemptId = "movement-3", state = "accepted", reason = "prior", engineHandle = handle}
local event = {attemptId = "movement-3", kind = "started", callbackArg = handle}
local output = action.reduce(input, event)
assert(input.state == "accepted" and input.reason == "prior" and input.engineHandle == handle)
assert(event.kind == "started" and event.callbackArg == handle)
assert(output ~= input and output.state == "started" and output.engineHandle == nil)
for key, value in pairs(output) do
    assert(key == "attemptId" or key == "state" or key == "reason")
    assert(type(value) == "string")
end

-- 7. Malformed caller inputs fail loudly, including missing outcome reasons.
assert(not pcall(action.new, ""))
assert(not pcall(action.new, {}))
assert(not pcall(action.reduce, nil, {attemptId = "x", kind = "accepted"}))
assert(not pcall(action.reduce, proposed, {attemptId = "x"}))
assert(not pcall(action.reduce, {attemptId = "x", state = "invented"}, {attemptId = "x", kind = "accepted"}))
assert(not pcall(step, proposed, "failed"))
assert(not pcall(step, proposed, "unknown", {reason = ""}))
assert(not pcall(step, accepted, "started", {reason = ""}))
assert(not pcall(step, accepted, "completed", {proof = {}}))
return 7
