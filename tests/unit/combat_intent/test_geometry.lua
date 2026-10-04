-- Synthetic metric/metadata: not effective SPL/PRO radius or engine admission.
local geometry=require('combat-intent.geometry')
local perception=require('combat-intent.perception')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local groups=0
local function fact(source,value) return {source=source,value=value,observedAt=10,expiresAt=20,confidence=1} end
local function actor(key,relation,x,y,alive)
    local source=relation=='self' and 'self' or 'sight'
    return {key=key,visible=true,detected=true,facts={alive=fact(source,alive~=false),
        relation=fact(source,relation),position=fact(source,{x=x,y=y})}}
end
local function raw()
    return {schemaVersion=1,sceneKey='synthetic/room',tick=10,observerKey='mage/one',eligibleAllies={},actors={
        actor('mage/one','self',0,0),actor('enemy/anchor','enemy',100,100),
        actor('enemy/other','enemy',108,100),actor('ally/one','ally',113,100)}}
end
local function descriptor()
    return {geometryId='synthetic/dust',resource='SPWI224',shape='circle',radius=10,scaleX=1,scaleY=4/3}
end
local function coverage(frame)
    local keys={};for _,row in ipairs(frame.actors) do keys[#keys+1]=row.key end
    return {sceneKey=frame.sceneKey,observerKey=frame.observerKey,tick=frame.tick,
        complete=true,actorKeys=keys,padding=2}
end
local function assess(input,shape,report)
    local view=perception.build(input or raw());local frame=view:export()
    return geometry.assess(view,shape or descriptor(),'enemy/anchor',report or coverage(frame))
end
local function bad(fn) assert(not pcall(fn),'malformed geometry accepted') end

local view=perception.build(raw());local frame=view:export()
local safe=geometry.assess(view,descriptor(),'enemy/anchor',coverage(frame))
assert(safe.complete and safe.safe and safe.anchorCovered and safe.dispatchAuthorized==false)
assert(safe.point.x==100 and safe.point.y==100 and safe.resource=='SPWI224')
assert(#safe.affectedKeys==2 and safe.affectedKeys[1]=='enemy/anchor' and safe.affectedKeys[2]=='enemy/other')
assert(#safe.riskKeys==0 and equal(safe.actors,frame.actors))
safe.point.x=999;safe.actors[1].facts.position.value.x=999
assert(assess().point.x==100 and raw().actors[1].facts.position.value.x==0)
groups=groups+1

local borderline=raw();borderline.actors[4].facts.position.value.x=112
local risk=assess(borderline)
assert(risk.complete and not risk.safe and risk.reason=='ally-risk' and risk.riskKeys[1]=='ally/one')
local noPadding=coverage(perception.build(borderline):export());noPadding.padding=0
assert(assess(borderline,nil,noPadding).safe)
borderline.actors[4].facts.position.value={x=100,y=109}
assert(assess(borderline).riskKeys[1]=='ally/one','vertical metric or padding ignored')
borderline.actors[4].facts.position.value.y=107.5
assert(assess(borderline,nil,noPadding).riskKeys[1]=='ally/one','vertical scale ignored')
groups=groups+1

local unknown=descriptor();unknown.shape='unknown'
assert(not assess(nil,unknown).complete and not assess(nil,unknown).safe)
unknown=descriptor();unknown.radius=false
assert(not assess(nil,unknown).complete)
unknown=descriptor();unknown.radius=0;bad(function() assess(nil,unknown) end)
unknown=descriptor();unknown.scaleY=math.huge;bad(function() assess(nil,unknown) end)
local incomplete=coverage(frame);incomplete.complete=false
assert(not assess(nil,nil,incomplete).complete)
local stale=coverage(frame);stale.tick=9
assert(not assess(nil,nil,stale).complete)
local wrong=coverage(frame);wrong.actorKeys[2]='enemy/alien'
assert(not assess(nil,nil,wrong).complete)
wrong=coverage(frame);wrong.actorKeys[2]='enemy/other'
bad(function() assess(nil,nil,wrong) end)
wrong=coverage(frame);wrong.sceneKey='other/room'
assert(not assess(nil,nil,wrong).complete)
groups=groups+1

local missing=raw();missing.actors[4].facts.relation.value='unknown'
assert(not assess(missing).complete and not assess(missing).safe and #assess(missing).affectedKeys==0)
missing=raw();missing.actors[4].visible=false
assert(not assess(missing).complete)
missing=raw();missing.actors[4].facts.position.observedAt=9
assert(not assess(missing).complete)
missing=raw();missing.actors[4].facts.alive.confidence=.9
assert(not assess(missing).complete)
missing=raw();missing.actors[2].facts.relation.value='ally'
assert(not assess(missing).complete and not assess(missing).anchorCovered)
missing=raw();missing.actors[4].facts.alive.value=false
missing.actors[4].facts.position=nil;missing.actors[4].facts.relation=nil
assert(assess(missing).complete and assess(missing).safe,'known dead actor not skipped')
groups=groups+1

local permuted=raw();permuted.actors={permuted.actors[4],permuted.actors[3],permuted.actors[2],permuted.actors[1]}
assert(equal(assess(permuted).affectedKeys,assess().affectedKeys))
local caller=raw();local shape=descriptor();local report=coverage(perception.build(caller):export())
local before={caller=copy(caller),shape=copy(shape),report=copy(report)}
local result=assess(caller,shape,report);result.affectedKeys[1]='changed'
assert(equal(caller,before.caller) and equal(shape,before.shape) and equal(report,before.report))
bad(function() assess(nil,{geometryId='x',resource='SPWI224',shape='circle',radius=10,
    scaleX=1,scaleY=1,rawObjectId=123}) end)
groups=groups+1

-- Existing legality consumes the exact exported frame/point linkage, still shadow-only.
local legality=require('combat-intent.legality')
local rawScene=raw();rawScene.actors[1].facts.spellbook=fact('self',{'SPWI224'})
for _,row in ipairs({{'auraReady',true},{'idle',true},{'canAct',true},{'silenced',false},
    {'castingFailure',0}}) do rawScene.actors[1].facts[row[1]]=fact('self',row[2]) end
rawScene.actors[2].facts.lineOfSight=fact('sight',true)
rawScene.actors[2].facts.range=fact('sight',10)
local linked=perception.build(rawScene);local attestation=geometry.assess(linked,descriptor(),'enemy/anchor',coverage(linked:export()))
local spell={id='dust',resource='SPWI224',target='point',range=30,geometry='exact',
    geometryId='synthetic/dust',maxCastingFailure=.5,immunityTags={}}
local accepted=legality.check(linked,spell,'enemy/anchor',{['synthetic/dust']={['enemy/anchor']=attestation}})
assert(accepted and accepted.target.kind=='point' and accepted.target.x==100)
rawScene.actors[4].facts.position.value.x=112
linked=perception.build(rawScene);attestation=geometry.assess(linked,descriptor(),'enemy/anchor',coverage(linked:export()))
local denied,why=legality.check(linked,spell,'enemy/anchor',{['synthetic/dust']={['enemy/anchor']=attestation}})
assert(not denied and why=='ally-risk')
groups=groups+1
return groups
