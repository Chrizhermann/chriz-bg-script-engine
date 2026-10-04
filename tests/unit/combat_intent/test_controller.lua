local controller=require('combat-intent.controller')
local trace=require('combat-intent.trace')
local equal=require('kernel.manifest').equal
local function fact(source,value,tick,confidence)
    return {source=source,value=value,observedAt=tick,expiresAt=tick+10,confidence=confidence or 1}
end
local profile={id='synthetic/timing',weights={control=1},nearBestBand=1,
    reactionTicks=2,commitmentTicks=5,maxMemoryAge=0,minConfidence=0}
local function input(tick,options)
    options=options or {}
    local scene=options.scene or 'synthetic/scene-one'
    local spells=options.depleted and {} or {'SPWI112'}
    local frame={schemaVersion=1,sceneKey=scene,tick=tick,observerKey=options.actor or 'mage/one',
        eligibleAllies={},actors={
            {key='mage/one',visible=true,detected=true,facts={spellbook=fact('self',spells,tick,options.confidence),
                auraReady=fact('self',true,tick),alive=fact('self',true,tick),idle=fact('self',true,tick),
                canAct=fact('self',true,tick),silenced=fact('self',false,tick),castingFailure=fact('self',0,tick)}},
            {key='enemy/one',visible=true,detected=true,facts={alive=fact('sight',true,tick),
                relation=fact('sight','enemy',tick),lineOfSight=fact('sight',true,tick),
                range=fact('sight',10,tick)}}}}
    local candidates={ownership={player=false,hardMode=false,world=false,encounter=false,
        forced=false,dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,
        active=true,hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true},
        ownershipContext={sceneKey=scene,observerKey=frame.observerKey,tick=tick},
        spells={{id='missile',resource='SPWI112',target='actor',range=30,geometry='exact',
            geometryId='synthetic/missile',maxCastingFailure=.5,immunityTags={}}},
        targets={'enemy/one'},areaChecks={}}
    local terms={wait={control=2},decline={control=0}}
    if not options.depleted and options.confidence~=0.5 then
        terms['missile@enemy/one']={control=options.degraded and -10 or 3}
    end
    return {frame=frame,candidates=candidates,terms=terms}
end
local function excluded(result,id)
    for _,row in ipairs(result.candidates.excluded) do if row.id==id then return row.reason end end
end

-- The decision uses the current due-tick frame, not the opening frame.
local c=controller.new(profile,1)
local delayed,why=c:consider(input(10));assert(delayed==nil and why=='reaction-delay')
delayed,why=c:consider(input(11));assert(delayed==nil and why=='reaction-delay')
local result=c:consider(input(12,{depleted=true}))
assert(result.input.frame.tick==12 and excluded(result,'missile@enemy/one')=='spell-unavailable')
assert(result.choice.id=='wait' and result.choice.seedBefore==1)
assert(equal(trace.replay(result),result))

-- A held choice is a replayable row and consumes no RNG draw.
c=controller.new(profile,1)
assert(select(2,c:consider(input(10)))=='reaction-delay')
local selected=c:consider(input(12))
assert(selected.choice.id=='missile@enemy/one' and selected.choice.seedBefore==1)
assert(selected.choice.seedAfter~=selected.choice.seedBefore)
assert(equal(trace.replay(selected),selected))
local seedAfterSelection=selected.choice.seedAfter
selected.choice.id='caller-mutated';selected.input.frame.sceneKey='caller-mutated'
assert(select(2,c:consider(input(13)))=='reaction-delay')
local held=c:consider(input(14))
assert(held.choice.id=='missile@enemy/one' and held.choice.retained==true)
assert(held.choice.seedBefore==seedAfterSelection and held.choice.seedAfter==seedAfterSelection)
assert(held.input.prior.selectedAt==12 and held.input.prior.choiceId=='missile@enemy/one')
assert(equal(trace.replay(held),held))
local degraded=c:consider(input(16,{degraded=true}))
assert(degraded.choice.id=='wait' and degraded.choice.retained==nil)
assert(degraded.choice.seedBefore==seedAfterSelection)
assert(equal(trace.replay(degraded),degraded))

-- Repeated holds do not extend the original commitment window.
c=controller.new(profile,1)
assert(select(2,c:consider(input(10)))=='reaction-delay')
assert(c:consider(input(12)).choice.id=='missile@enemy/one')
assert(c:consider(input(14)).choice.retained==true)
assert(c:consider(input(16)).choice.retained==true)
local expired=c:consider(input(18))
assert(expired.choice.id=='missile@enemy/one' and expired.choice.retained==nil)
assert(equal(trace.replay(expired),expired))

-- Context invalidation restarts reaction and discards commitment.
c=controller.new(profile,11)
assert(select(2,c:consider(input(10)))=='reaction-delay')
assert(c:consider(input(12)).choice.id=='missile@enemy/one')
assert(select(2,c:consider(input(14,{scene='synthetic/scene-two'})))=='reaction-delay')
assert(select(2,c:consider(input(15,{scene='synthetic/scene-two'})))=='reaction-delay')
local fresh=c:consider(input(16,{scene='synthetic/scene-two'}))
assert(fresh.input.prior==nil and fresh.choice.retained==nil)
assert(not pcall(function() c:consider(input(18,{actor='mage/two'})) end))

-- Timing metadata must not relax current-confidence legality.
c=controller.new(profile,1)
assert(select(2,c:consider(input(10)))=='reaction-delay')
local uncertain=c:consider(input(12,{confidence=0.5}))
assert(excluded(uncertain,'missile@enemy/one')=='stale-spell-allocation')
assert(uncertain.choice.id=='wait')

-- Zero reaction means the opening and changed-scene frames are due immediately.
local zero=require('kernel.manifest').copy(profile);zero.reactionTicks=0
local stream=require('kernel.rng').new(17)
stream:nextInt(1,1000000);local afterFirst=stream:state()
stream:nextInt(1,1000000);local afterSecond=stream:state()
c=controller.new(zero,17)
local immediate=c:consider(input(10))
assert(immediate and immediate.input.frame.tick==10 and immediate.choice.seedBefore==17)
assert(immediate.choice.seedAfter==afterFirst and equal(trace.replay(immediate),immediate))
local moved=c:consider(input(20,{scene='synthetic/scene-two'}))
assert(moved and moved.input.frame.tick==20 and moved.input.prior==nil)
assert(moved.choice.seedBefore==afterFirst and moved.choice.seedAfter==afterSecond)
assert(equal(trace.replay(moved),moved))
return 4
