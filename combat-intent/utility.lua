-- Deterministic arithmetic over admitted shadow proposals; never dispatches.
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local snapshot=require('combat-intent.snapshot')
local profile=require('combat-intent.profile')
local M={}

local function candidate(row)
    assert(type(row)=='table' and type(row.action)=='table','eligible candidate required')
    snapshot.assertKey(row.id)
    local kind=row.action.kind
    if kind=='shadow-spell' then
        snapshot.record(row,{'id','action','geometryId','notes'})
        snapshot.record(row.action,{'kind','resource','target'})
        snapshot.assertKey(row.geometryId)
        -- Reuse the pure shadow action's target and resource validation.
        require('combat-intent.actions').spell(row.action.resource,row.action.target)
        assert(row.id:find('@',1,true),'spell candidate id required')
    elseif kind=='shadow-preparation' then
        snapshot.record(row,{'id','action','notes'})
        snapshot.record(row.action,{'kind','resource','delivery','target','originalDebit','continueLegacy','setsInstantPrep'})
        snapshot.value('lastCast',row.action.resource);snapshot.value('lastCast',row.action.delivery)
        snapshot.record(row.action.target,{'kind','key'});snapshot.assertKey(row.action.target.key)
        assert(row.action.target.kind=='actor' and row.action.originalDebit==1 and
            row.action.continueLegacy==true and row.action.setsInstantPrep==false)
    elseif kind=='shadow-position' then
        snapshot.record(row,{'id','action','pathProofId','features','notes'})
        snapshot.record(row.action,{'kind','point'});snapshot.value('position',row.action.point)
        snapshot.assertKey(row.pathProofId);assert(row.id:sub(1,9)=='position/')
        snapshot.record(row.features,{'retreatGain','travelDistance'})
    elseif kind=='shadow-wait' then
        snapshot.record(row,{'id','action','notes'})
        snapshot.record(row.action,{'kind'});assert(row.id=='wait')
    elseif kind=='legacy-decline' then
        snapshot.record(row,{'id','action','notes'})
        snapshot.record(row.action,{'kind'});assert(row.id=='decline')
    else error('unrecognized candidate action') end
    snapshot.array(row.notes,function(note) assert(type(note)=='string','candidate note required') end)
end

function M.score(eligibleArray,termsByCandidateId,profileInput)
    local p=profile.new(profileInput)
    local eligible=copy(eligibleArray)
    local terms=copy(termsByCandidateId)
    local seen,rows={},{}
    snapshot.array(eligible,function(row)
        candidate(row)
        assert(not seen[row.id],'duplicate candidate id')
        seen[row.id]=true
    end)
    assert(type(terms)=='table','candidate terms map required')
    for id in pairs(terms) do assert(seen[id],'terms for disallowed candidate') end
    for _,row in ipairs(eligible) do
        local values=terms[row.id]
        assert(type(values)=='table','missing candidate terms')
        if row.action.kind=='shadow-position' then
            assert(equal(values,row.features),'spatial terms must match generated features')
        end
        local details={}
        for reason,value in pairs(values) do
            assert(p.weights[reason]~=nil,'unweighted or unknown term')
            assert(type(value)=='number' and value==value and value>-math.huge and
                value<math.huge and value>=-1000000 and value<=1000000,'invalid term value')
            local weight=p.weights[reason]
            local contribution=value*weight
            details[#details+1]={reason=reason,value=value,weight=weight,contribution=contribution}
        end
        table.sort(details,function(a,b) return a.reason<b.reason end)
        local score=0
        for _,detail in ipairs(details) do score=score+detail.contribution end
        rows[#rows+1]={id=row.id,score=score,terms=details}
    end
    table.sort(rows,function(a,b) return a.id<b.id end)
    return rows
end

return M
