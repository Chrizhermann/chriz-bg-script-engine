local decision=require('combat-intent.decision')
local trace=require('combat-intent.trace')
local manifest=require('kernel.manifest')
local copy,equal=manifest.copy,manifest.equal
local function fails(fn) assert(not pcall(fn),'invalid decision input accepted') end
local function fact(source,value)
    return {source=source,value=value,observedAt=10,expiresAt=20,confidence=1}
end
local function input()
    local frame={schemaVersion=1,sceneKey='synthetic/scene',tick=10,observerKey='mage/one',eligibleAllies={},actors={
        {key='mage/one',visible=true,detected=true,facts={spellbook=fact('self',{'SPWI112'}),
            auraReady=fact('self',true),alive=fact('self',true),idle=fact('self',true),
            canAct=fact('self',true),silenced=fact('self',false),castingFailure=fact('self',0)}},
        {key='enemy/one',visible=true,detected=true,facts={alive=fact('sight',true),
            position=fact('sight',{x=100,y=200}),range=fact('sight',10),relation=fact('sight','enemy'),
            lineOfSight=fact('sight',true)}}}}
    local candidates={ownership={player=false,hardMode=false,world=false,encounter=false,
        forced=false,dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,
        active=true,hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true},
        ownershipContext={sceneKey=frame.sceneKey,observerKey=frame.observerKey,tick=frame.tick},
        spells={{id='missile',resource='SPWI112',target='actor',range=30,geometry='exact',
            geometryId='synthetic/missile',maxCastingFailure=.5,immunityTags={}}},
        targets={'enemy/one'},areaChecks={}}
    local profile={id='synthetic/decision',weights={control=1,resourceCost=-1,urgency=0.5},nearBestBand=0,
        reactionTicks=0,commitmentTicks=0,maxMemoryAge=0,minConfidence=0}
    return {frame=frame,candidates=candidates,profile=profile,
        terms={['missile@enemy/one']={control=2,urgency=1},wait={resourceCost=0},decline={resourceCost=1}},seed=7}
end

local source=input()
local before=copy(source)
local result=decision.evaluate(source)
assert(equal(source,before) and result.schemaVersion==1 and equal(result.input,before))
assert(#result.candidates.eligible==3 and #result.candidates.excluded==0)
assert(#result.scores==3 and result.choice.id=='missile@enemy/one')
assert(result.candidates.dispatchAuthorized==false)
local saved=trace.record(result)
assert(equal(saved,result) and equal(trace.replay(saved),result))
source.frame.actors[1].facts.spellbook.value[1]='SPWI999'
result.input.terms['missile@enemy/one'].control=9
assert(saved.input.frame.actors[1].facts.spellbook.value[1]=='SPWI112')
assert(saved.input.terms['missile@enemy/one'].control==2)

local reorder=input()
local values=reorder.terms['missile@enemy/one']
reorder.terms['missile@enemy/one']={}
reorder.terms['missile@enemy/one'].urgency=values.urgency
reorder.terms['missile@enemy/one'].control=values.control
assert(equal(decision.evaluate(reorder),saved))
local tampered=copy(saved);tampered.scores[1].score=123
local regenerated,reason=trace.replay(tampered)
assert(regenerated==nil and reason=='trace-disagreement')
tampered=copy(saved);tampered.extra=true
fails(function() trace.replay(tampered) end)

local unavailable=input()
unavailable.frame.actors[1].facts.spellbook=fact('self',{})
fails(function() decision.evaluate(unavailable) end)
unavailable.terms['missile@enemy/one']=nil
local excluded=decision.evaluate(unavailable)
assert(#excluded.candidates.eligible==2 and excluded.candidates.excluded[1].reason=='spell-unavailable')
assert(#excluded.scores==2 and excluded.choice.id=='wait')

local bad=input();bad.frame.actors[1].facts.spellbook.value[1]=function() end
fails(function() decision.evaluate(bad) end)
bad=input();bad.extra=true;fails(function() decision.evaluate(bad) end)
bad=input();bad.seed=0;fails(function() decision.evaluate(bad) end)
return 5
