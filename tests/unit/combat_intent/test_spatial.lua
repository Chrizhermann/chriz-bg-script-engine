local spatial=require('combat-intent.spatial')
local perception=require('combat-intent.perception')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local function fact(source,value) return {source=source,value=value,observedAt=10,expiresAt=20,confidence=1} end
local function actor(key,relation,x,y)
    local source=relation=='self' and 'self' or 'sight'
    return {key=key,visible=true,detected=true,facts={alive=fact(source,true),relation=fact(source,relation),
        position=fact(source,{x=x,y=y})}}
end
local function raw()
    return {schemaVersion=1,sceneKey='room/test',observerKey='mage/one',tick=10,eligibleAllies={},actors={
        actor('mage/one','self',100,100),actor('enemy/one','enemy',110,100)}}
end
local function config()
    return {scaleX=1,scaleY=4/3,maxDistance=30,personalSpace=2,margin=1,
        pathProofId='synthetic/path-v1',weights={retreatGain=1,travelDistance=-.1},
        offsets={{id='left',x=-16,y=0},{id='right',x=16,y=0},{id='up',x=0,y=-12}}}
end
local function reports(view,cfg)
    local result={}
    for _,sample in ipairs(spatial.sample(view,cfg)) do
        result[sample.id]={sceneKey='room/test',observerKey='mage/one',tick=10,
            from={x=100,y=100},point=copy(sample.point),actors=view:export().actors,pathProofId='synthetic/path-v1',
            reachable=true,open=true,lineOfSight=true,clearance=3}
    end
    return result
end
local view=perception.build(raw());local cfg=config();local probes=reports(view,cfg)
local result=spatial.evaluate(view,cfg,probes)
assert(result.dispatchAuthorized==false and #result.eligible==3 and #result.excluded==0)
assert(result.eligible[1].id=='left' and result.eligible[1].retreatGain==16)
assert(result.eligible[1].travelDistance==16 and result.eligible[1].score==14.4)
assert(result.eligible[1].action.kind=='shadow-position' and result.eligible[1].action.point.x==84)
local samples=spatial.sample(view,cfg);assert(samples[3].point.y==88)
local before=copy(probes);result.eligible[1].action.point.x=999
assert(equal(probes,before) and spatial.evaluate(view,cfg,probes).eligible[1].action.point.x==84)
local groups=1

probes.left.reachable=false;probes.right.open=false;probes.up.clearance=2
result=spatial.evaluate(view,cfg,probes)
assert(#result.eligible==0 and #result.excluded==3)
assert(result.excluded[1].reason=='unreachable' and result.excluded[2].reason=='occupied' and
    result.excluded[3].reason=='insufficient-clearance')
probes=reports(view,cfg);probes.left.lineOfSight=false;probes.right.reachable='unknown';probes.up=nil
result=spatial.evaluate(view,cfg,probes)
assert(result.excluded[1].reason=='line-of-sight-blocked' and result.excluded[2].reason=='reachability-unknown'
    and result.excluded[3].reason=='query-unknown')
groups=groups+1

probes=reports(view,cfg);probes.left.tick=9;probes.right.from.x=101;probes.up.point.y=99
result=spatial.evaluate(view,cfg,probes)
for _,row in ipairs(result.excluded) do assert(row.reason=='query-stale-or-mismatched') end
local changed=raw();changed.actors[#changed.actors+1]=actor('ally/new','ally',84,100)
local changedResult=spatial.evaluate(perception.build(changed),cfg,reports(view,cfg))
assert(#changedResult.eligible==0 and changedResult.excluded[1].reason=='query-stale-or-mismatched',
    'query reused after same-tick actor-frame change')
cfg.pathProofId=false;result=spatial.evaluate(view,cfg,reports(view,cfg))
assert(#result.eligible==0 and result.excluded[1].reason=='path-capability-unadmitted')
cfg=config();probes=reports(view,cfg);probes.left.pathProofId='different/proof'
assert(spatial.evaluate(view,cfg,probes).excluded[1].reason=='path-capability-unadmitted')
groups=groups+1

local unknown=raw();unknown.actors[2].facts.position.observedAt=9
result=spatial.evaluate(perception.build(unknown),cfg,reports(view,cfg))
assert(#result.eligible==0 and result.excluded[1].reason=='threat-knowledge-unknown')
unknown=raw();unknown.actors[2].facts.relation.value='unknown'
assert(#spatial.evaluate(perception.build(unknown),cfg,reports(view,cfg)).eligible==0)
unknown=raw();unknown.actors[2].facts.alive.value=false
local deadView=perception.build(unknown)
result=spatial.evaluate(deadView,cfg,reports(deadView,cfg))
assert(#result.eligible==3 and result.eligible[1].retreatGain==0,'dead actor counted as threat')
groups=groups+1

local function bad(f) assert(not pcall(f),'bad spatial input accepted') end
cfg=config();cfg.offsets[2].id='left';bad(function() spatial.sample(view,cfg) end)
cfg=config();cfg.weights.retreatGain=math.huge;bad(function() spatial.sample(view,cfg) end)
cfg=config();cfg.offsets[1].x=-100;result=spatial.evaluate(view,cfg,reports(view,cfg))
assert(result.excluded[1].reason=='outside-sample-radius')
cfg=config();probes=reports(view,cfg);probes.left.reachable=1
bad(function() spatial.evaluate(view,cfg,probes) end)
cfg=config();cfg.weights.retreatGain=0;cfg.weights.travelDistance=-1
result=spatial.evaluate(view,cfg,reports(view,cfg))
assert(result.eligible[1].id=='left' and result.eligible[2].id=='right' and result.eligible[3].id=='up',
    'equal-distance ranking must use stable semantic IDs')
groups=groups+1
return groups
