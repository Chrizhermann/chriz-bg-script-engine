-- Bounded scalar decision records, checked by deterministic regeneration.
local manifest=require('kernel.manifest')
local snapshot=require('combat-intent.snapshot')
local decision=require('combat-intent.decision')
local M={}

local function entry(value)
    local saved=manifest.copy(value)
    snapshot.record(saved,{'schemaVersion','input','candidates','scores','choice'})
    assert(saved.schemaVersion==1,'decision trace schema')
    return saved
end

function M.record(result)
    return entry(result)
end

function M.replay(result)
    local saved=entry(result)
    local regenerated=decision.evaluate(saved.input)
    if not manifest.equal(regenerated,saved) then return nil,'trace-disagreement' end
    return regenerated
end

return M
