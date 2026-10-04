-- Pure, replayable shadow decision. No engine reads or action submission.
local copy=require('kernel.manifest').copy
local snapshot=require('combat-intent.snapshot')
local candidates=require('combat-intent.candidates')
local utility=require('combat-intent.utility')
local choose=require('combat-intent.choose')
local profile=require('combat-intent.profile')
local rng=require('kernel.rng')
local M={}

local function retained(scores,p,prior,frame,seed)
    if not prior or prior.sceneKey~=frame.sceneKey or prior.observerKey~=frame.observerKey or
        frame.tick<prior.selectedAt or frame.tick-prior.selectedAt>=p.commitmentTicks then return nil end
    local best,selected=nil,nil
    for _,row in ipairs(scores) do
        if best==nil or row.score>best then best=row.score end
        if row.id==prior.choiceId then selected=row end
    end
    if not selected or selected.score<best-p.nearBestBand then return nil end
    local band={}
    for _,row in ipairs(scores) do
        if row.score>=best-p.nearBestBand then band[#band+1]=row.id end
    end
    return {id=selected.id,score=selected.score,seedBefore=seed,seedAfter=seed,
        bandCandidates=band,retained=true}
end

function M.evaluate(raw)
    local input=copy(raw)
    snapshot.record(input,{'frame','candidates','profile','terms','seed'},{'prior'})
    if input.prior then
        snapshot.record(input.prior,{'sceneKey','observerKey','selectedAt','choiceId'})
        snapshot.assertKey(input.prior.sceneKey);snapshot.assertKey(input.prior.observerKey)
        snapshot.assertTick(input.prior.selectedAt);snapshot.assertKey(input.prior.choiceId)
    end
    local view=snapshot.new(input.frame)
    local frame=view:export()
    local p=profile.new(input.profile)
    local generated=candidates.generate(view,input.candidates)
    local scores=utility.score(generated.eligible,input.terms,p)
    local stream=rng.new(input.seed)
    local selected=retained(scores,p,input.prior,frame,stream:state()) or choose.select(scores,p,stream)
    return copy({schemaVersion=1,input=input,candidates=generated,scores=scores,
        choice=selected or false})
end

return M
