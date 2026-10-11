-- Pure, fail-closed bridge from two replayable decisions to one narrow request.
-- No native calls, ownership lease, or activation switch live here.
local trace=require('combat-intent.trace')
local snapshot=require('combat-intent.snapshot')
local M={}

-- A capability profile admits reviewed ordinary call shapes, not every known
-- spell. Omission retains the original missile-only development envelope.
function M.compileAdmission(raw)
    if raw==nil then return {SPWI112={target='actor'}} end
    local ok,result=pcall(function()
        local out=require('kernel.manifest').copy(raw)
        assert(type(out)=='table')
        for resource,rule in pairs(out) do
            assert(type(resource)=='string' and #resource>0 and #resource<=8 and
                not resource:find('[^A-Z0-9_#%-]'))
            snapshot.record(rule,{'target','geometryId'})
            assert(rule.target=='actor' or rule.target=='self')
            snapshot.assertKey(rule.geometryId)
        end
        return out
    end)
    if ok then return result end
    return nil,'invalid-admission'
end

local function descriptor(record,row)
    for _,spell in ipairs(record.input.candidates.spells) do
        if row.id==spell.id..'@'..row.action.target.key then return spell end
    end
end

local function replay(record)
    local ok,saved=pcall(trace.replay,record)
    if ok then return saved end
end

local function eligible(result,id)
    for _,row in ipairs(result.candidates.eligible) do
        if row.id==id then return row end
    end
end

function M.revalidate(proposalDecisionRecord,freshDecisionRecord,maxAgeTicks,admission)
    if not pcall(snapshot.assertTick,maxAgeTicks) then return nil,'invalid-max-age' end
    local admitted,why=M.compileAdmission(admission)
    if not admitted then return nil,why end
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
    local rule=admitted[oldAction.resource]
    if not rule then return nil,'unsupported-resource' end
    if before.geometryId~=after.geometryId or newAction.kind~=oldAction.kind or
        newAction.target.kind~='actor' or
        newAction.resource~=oldAction.resource or newAction.target.key~=oldAction.target.key then
        return nil,'action-changed'
    end
    local oldSpell,newSpell=descriptor(proposal,before),descriptor(fresh,after)
    if not oldSpell or not newSpell or oldSpell.target~=rule.target or newSpell.target~=rule.target or
        rule.geometryId and rule.geometryId~=before.geometryId then return nil,'admission-mismatch' end
    if not require('kernel.manifest').equal(oldSpell,newSpell) then return nil,'spell-metadata-changed' end
    return {kind='spell',resource=oldAction.resource,targetKey=newAction.target.key}
end

return M
