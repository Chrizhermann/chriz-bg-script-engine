-- Explicit, copied scoring parameters. This module supplies no gameplay defaults.
local copy=require('kernel.manifest').copy
local snapshot=require('combat-intent.snapshot')
local M={}
local reasons={control=true,affectedTargets=true,friendlyRisk=true,redundancy=true,
    resourceCost=true,interruptionRisk=true,urgency=true,uncertainty=true,
    duration=true,preparation=true,archetype=true,retreatGain=true,travelDistance=true}

local function bounded(value,minimum,maximum)
    return type(value)=='number' and value==value and value>-math.huge and
        value<math.huge and value>=minimum and value<=maximum
end
local function tick(value)
    return bounded(value,0,1000000) and value%1==0
end

function M.new(config)
    local p=copy(config)
    snapshot.record(p,{'id','weights','nearBestBand','reactionTicks','commitmentTicks',
        'maxMemoryAge','minConfidence'})
    snapshot.assertKey(p.id)
    assert(type(p.weights)=='table','weights map required')
    for reason,weight in pairs(p.weights) do
        assert(reasons[reason] and bounded(weight,-1000000,1000000),'invalid weight')
    end
    assert(bounded(p.nearBestBand,0,1000000),'invalid near-best band')
    assert(tick(p.reactionTicks) and tick(p.commitmentTicks) and tick(p.maxMemoryAge),
        'invalid timing or memory ticks')
    assert(bounded(p.minConfidence,0,1),'invalid minimum confidence')
    return p
end

return M
