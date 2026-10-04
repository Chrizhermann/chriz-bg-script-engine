-- Actor-local reaction/commitment timing around pure shadow decisions.
local copy=require('kernel.manifest').copy
local snapshot=require('combat-intent.snapshot')
local profile=require('combat-intent.profile')
local decision=require('combat-intent.decision')
local rng=require('kernel.rng')
local M={}

function M.new(profileInput,seed)
    local p=profile.new(profileInput)
    local currentSeed=rng.new(seed):state()
    local observerKey,sceneKey,nextDue,lastChoice,lastTick
    local api={}
    function api:consider(raw)
        local input=copy(raw)
        snapshot.record(input,{'frame','candidates','terms'})
        local frame=snapshot.new(input.frame):export()
        if observerKey and observerKey~=frame.observerKey then error('controller actor mismatch') end
        observerKey=observerKey or frame.observerKey
        if sceneKey~=frame.sceneKey then
            -- A new scene cannot inherit pending timing or an old commitment.
            sceneKey=frame.sceneKey;lastChoice=nil;nextDue=frame.tick+p.reactionTicks
            lastTick=frame.tick
            if p.reactionTicks>0 then return nil,'reaction-delay' end
        end
        assert(frame.tick>=lastTick,'controller tick regression')
        lastTick=frame.tick
        if frame.tick<nextDue then return nil,'reaction-delay' end
        local request={frame=input.frame,candidates=input.candidates,terms=input.terms,
            profile=p,seed=currentSeed}
        if lastChoice then request.prior=lastChoice end
        local result=decision.evaluate(request)
        if result.choice then
            currentSeed=result.choice.seedAfter
            lastChoice={sceneKey=frame.sceneKey,observerKey=frame.observerKey,
                selectedAt=result.choice.retained and lastChoice.selectedAt or frame.tick,
                choiceId=result.choice.id}
        else lastChoice=nil end
        nextDue=frame.tick+p.reactionTicks
        return result
    end
    return api
end

return M
