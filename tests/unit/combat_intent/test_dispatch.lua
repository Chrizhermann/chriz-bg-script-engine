local decision=require('combat-intent.decision')
local dispatch=require('combat-intent.dispatch')
local perception=require('combat-intent.perception')
local copy,equal=require('kernel.manifest').copy,require('kernel.manifest').equal
local function fact(source,value,tick)
    return {source=source,value=value,observedAt=tick,expiresAt=tick+10,confidence=1}
end
local function input(tick)
    tick=tick or 10
    local frame={schemaVersion=1,sceneKey='synthetic/scene',tick=tick,observerKey='mage/one',eligibleAllies={},actors={
        {key='mage/one',visible=true,detected=true,facts={spellbook=fact('self',{'SPWI112'},tick),
            auraReady=fact('self',true,tick),alive=fact('self',true,tick),idle=fact('self',true,tick),
            canAct=fact('self',true,tick),silenced=fact('self',false,tick),castingFailure=fact('self',0,tick)}},
        {key='enemy/one',visible=true,detected=true,facts={alive=fact('sight',true,tick),
            position=fact('sight',{x=100,y=200},tick),range=fact('sight',10,tick),relation=fact('sight','enemy',tick),
            lineOfSight=fact('sight',true,tick)}}}}
    local candidates={ownership={player=false,hardMode=false,world=false,encounter=false,
        forced=false,dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,
        active=true,hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true},
        ownershipContext={sceneKey=frame.sceneKey,observerKey=frame.observerKey,tick=frame.tick},
        spells={{id='missile',resource='SPWI112',target='actor',range=30,geometry='exact',
            geometryId='synthetic/missile',maxCastingFailure=.5,immunityTags={}}},
        targets={'enemy/one'},areaChecks={}}
    local profile={id='synthetic/dispatch',weights={control=1,resourceCost=-1,urgency=0.5},nearBestBand=0,
        reactionTicks=0,commitmentTicks=0,maxMemoryAge=0,minConfidence=0}
    return {frame=frame,candidates=candidates,profile=profile,
        terms={['missile@enemy/one']={control=2,urgency=1},wait={resourceCost=0},decline={resourceCost=1}},seed=7}
end
local function check(proposal,fresh,maxAge)
    return dispatch.revalidate(proposal,fresh,maxAge or 2)
end
local proposal=decision.evaluate(input(10))
local fresh=decision.evaluate(input(11))
local savedProposal,savedFresh=copy(proposal),copy(fresh)
local request,reason=check(proposal,fresh)
assert(reason==nil and equal(request,{kind='spell',resource='SPWI112',targetKey='enemy/one'}))
assert(equal(proposal,savedProposal) and equal(fresh,savedFresh))
request.targetKey='caller-mutated'
assert(check(proposal,fresh).targetKey=='enemy/one')

local tampered=copy(proposal);tampered.scores[1].score=999
assert(select(2,check(tampered,fresh))=='invalid-proposal-trace')
tampered=copy(fresh);tampered.choice.id='forged'
assert(select(2,check(proposal,tampered))=='invalid-fresh-trace')
tampered=copy(proposal);tampered.extra=true
assert(select(2,check(tampered,fresh))=='invalid-proposal-trace')
assert(select(2,dispatch.revalidate(proposal,fresh,-1))=='invalid-max-age')

local changed=input(11);changed.frame.sceneKey='other/scene'
changed.candidates.ownershipContext.sceneKey=changed.frame.sceneKey
assert(select(2,check(proposal,decision.evaluate(changed)))=='scene-changed')
changed=input(11);changed.frame.observerKey='mage/two'
changed.frame.actors[1].key='mage/two';changed.candidates.ownershipContext.observerKey='mage/two'
assert(select(2,check(proposal,decision.evaluate(changed)))=='observer-changed')
assert(select(2,check(proposal,decision.evaluate(input(9))))=='clock-regressed')
assert(select(2,check(proposal,decision.evaluate(input(13))))=='proposal-expired')

changed=input(11);changed.candidates.targets={};changed.terms['missile@enemy/one']=nil
assert(select(2,check(proposal,decision.evaluate(changed)))=='action-not-eligible')
changed=input(11);changed.terms['missile@enemy/one']={control=0,urgency=0}
changed.terms.wait={resourceCost=-5}
assert(select(2,check(proposal,decision.evaluate(changed)))=='choice-changed')
changed=input(11);changed.candidates.spells[1].resource='SPWI224'
changed.frame.actors[1].facts.spellbook.value={'SPWI224'}
assert(select(2,check(proposal,decision.evaluate(changed)))=='action-changed')
changed=input(11);changed.candidates.spells[1].geometryId='synthetic/other-geometry'
assert(select(2,check(proposal,decision.evaluate(changed)))=='action-changed')

local function paired(changedInput)
    return check(decision.evaluate(changedInput),decision.evaluate(changedInput))
end
changed=input();changed.candidates.spells[1].resource='SPWI224'
changed.frame.actors[1].facts.spellbook.value={'SPWI224'}
assert(select(2,paired(changed))=='unsupported-resource')
changed=input();changed.candidates.spells[1].target='point'
changed.candidates.areaChecks['synthetic/missile']={['enemy/one']={complete=true,tick=10,resource='SPWI112',
    observerKey='mage/one',sceneKey='synthetic/scene',anchorCovered=true,
    point={x=100,y=200},actors=perception.build(changed.frame):export().actors,safe=true}}
assert(select(2,paired(changed))=='unsupported-action')
changed=input();changed.terms.wait={resourceCost=-5}
assert(select(2,paired(changed))=='unsupported-action')
changed=input();changed.candidates.ownership.dialogue=true
changed.terms['missile@enemy/one']=nil;changed.terms.wait=nil
assert(select(2,paired(changed))=='unsupported-action')
changed=input();changed.candidates.prebuffs={{id='mirror',original='SPWI112',helper='DWSW112',
    window='short',protectionTag='buff/mirror'}}
changed.candidates.preparation={sceneKey='synthetic/scene',observerKey='mage/one',tick=10,enabled=true,
    seenEnemy=true,detectedEnemy=true,nearParty=false,offscreenPrep=false,hostile=true,
    instantPrep=false,shortDifficulty=true,longDifficulty=true,accountingReady=true}
changed.frame.actors[1].facts.protections=fact('self',{},10)
changed.terms['prep-mirror@mage/one']={control=10}
assert(select(2,paired(changed))=='unsupported-action')
-- Explicit reviewed admission can add ordinary self defenses, but not helpers,
-- altered geometry, or an actor-target interpretation of that same resource.
local admission={SPWI114={target='self',geometryId='synthetic/shield'}}
local function defense(tick)
    local i=input(tick)
    i.candidates.spells={{id='shield',resource='SPWI114',target='self',range=0,
        geometry='exact',geometryId='synthetic/shield',maxCastingFailure=0,immunityTags={},buffTag='buff/shield'}}
    i.frame.actors[1].facts.spellbook.value={'SPWI114'}
    i.frame.actors[1].facts.protections=fact('self',{},tick)
    i.terms={['shield@mage/one']={control=5},wait={},decline={resourceCost=1}}
    return i
end
local a,b=decision.evaluate(defense(10)),decision.evaluate(defense(11))
assert(select(2,check(a,b))=='unsupported-resource')
assert(equal(dispatch.revalidate(a,b,2,admission),{kind='spell',resource='SPWI114',targetKey='mage/one'}))
local wrong=copy(admission);wrong.SPWI114.geometryId='different/geometry'
assert(select(2,dispatch.revalidate(a,b,2,wrong))=='admission-mismatch')
wrong=copy(admission);wrong.SPWI114.target='actor'
assert(select(2,dispatch.revalidate(a,b,2,wrong))=='admission-mismatch')
local drift=defense(11);drift.candidates.spells[1].buffTag='buff/another'
assert(select(2,dispatch.revalidate(a,decision.evaluate(drift),2,admission))=='spell-metadata-changed')
local refreshed=defense(11);refreshed.frame.actors[1].facts.protections.value={'buff/shield'}
refreshed.terms['shield@mage/one']=nil
assert(select(2,dispatch.revalidate(a,decision.evaluate(refreshed),2,admission))=='action-not-eligible')
assert(select(2,dispatch.revalidate(a,b,2,{['bad"']={target='self',geometryId='x'}}))=='invalid-admission')
return 10
