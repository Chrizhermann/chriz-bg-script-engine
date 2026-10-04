-- Pure, fail-closed bridge from two replayable decisions to one narrow request.
-- No native calls, ownership lease, or activation switch live here.
local trace=require('combat-intent.trace')
local snapshot=require('combat-intent.snapshot')
local M={}

local function replay(record)
    local ok,saved=pcall(trace.replay,record)
    if ok then return saved end
end

local function eligible(result,id)
    for _,row in ipairs(result.candidates.eligible) do
        if row.id==id then return row end
    end
end

function M.revalidate(proposalDecisionRecord,freshDecisionRecord,maxAgeTicks)
    if not pcall(snapshot.assertTick,maxAgeTicks) then return nil,'invalid-max-age' end
    local proposal=replay(proposalDecisionRecord)
    if not proposal then return nil,'invalid-proposal-trace' end
    local fresh=replay(freshDecisionRecord)
    if not fresh then return nil,'invalid-fresh-trace' end

    local earlier,later=proposal.input.frame,fresh.input.frame
    if earlier.sceneKey~=later.sceneKey then return nil,'scene-changed' end
    if earlier.observerKey~=later.observerKey then return nil,'observer-changed' end
    if later.tick<earlier.tick then return nil,'clock-regressed' end
    if later.tick-earlier.tick>maxAgeTicks then return nil,'proposal-expired' end

    local choice=proposal.choice
    if not choice then return nil,'unsupported-action' end
    local before=eligible(proposal,choice.id)
    local after=eligible(fresh,choice.id)
    if not before or not after then return nil,'action-not-eligible' end
    if not fresh.choice or fresh.choice.id~=choice.id then return nil,'choice-changed' end

    local oldAction,newAction=before.action,after.action
    if oldAction.kind~='shadow-spell' or oldAction.target.kind~='actor' then
        return nil,'unsupported-action'
    end
    if oldAction.resource~='SPWI112' then return nil,'unsupported-resource' end
    if before.geometryId~=after.geometryId or newAction.kind~=oldAction.kind or
        newAction.target.kind~='actor' or
        newAction.resource~=oldAction.resource or newAction.target.key~=oldAction.target.key then
        return nil,'action-changed'
    end
    return {kind='spell',resource='SPWI112',targetKey=newAction.target.key}
end

return M
