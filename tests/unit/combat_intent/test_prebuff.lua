local candidates=require('combat-intent.candidates')
local perception=require('combat-intent.perception')
local function fact(value)
    return {source='self',value=value,observedAt=10,expiresAt=11,confidence=1}
end
local function input()
    local raw={schemaVersion=1,sceneKey='prep/scene',tick=10,observerKey='mage/one',eligibleAllies={},
        actors={{key='mage/one',visible=true,detected=true,facts={alive=fact(true),
            spellbook=fact({'SPWI114','SPWI212'}),protections=fact({})}}}}
    local config={spells={},targets={},areaChecks={},ownershipContext={sceneKey='prep/scene',tick=10,observerKey='mage/one'},
        ownership={player=false,hardMode=false,world=false,encounter=false,forced=false,
            dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,active=true,
            hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true},
        prebuffs={{id='shield',original='SPWI114',helper='DWSW114',window='long',protectionTag='buff/shield'},
            {id='mirror',original='SPWI212',helper='DWSW212',window='short',protectionTag='buff/mirror'}},
        preparation={sceneKey='prep/scene',tick=10,observerKey='mage/one',enabled=true,
            seenEnemy=true,detectedEnemy=true,nearParty=false,offscreenPrep=false,hostile=true,
            instantPrep=false,shortDifficulty=true,longDifficulty=true,accountingReady=true}}
    return raw,config
end
local function run(raw,config) return candidates.generate(perception.build(raw),config) end
local function find(r,id,which)
    for _,v in ipairs(r[which or 'eligible']) do if v.id==id then return v end end
end
local raw,c=input();local result=run(raw,c)
local mirror=find(result,'prep-mirror@mage/one')
assert(mirror and mirror.action.kind=='shadow-preparation')
assert(mirror.action.resource=='SPWI212' and mirror.action.delivery=='DWSW212')
assert(mirror.action.originalDebit==1 and mirror.action.continueLegacy==true)
assert(mirror.action.setsInstantPrep==false and result.dispatchAuthorized==false)
-- The long/short distinction is perception/configuration, not a made-up duration.
c.preparation.seenEnemy=false
assert(find(run(raw,c),'prep-shield@mage/one'))
assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason=='preparation-window-closed')
c.preparation.detectedEnemy=false;c.preparation.nearParty=true
assert(find(run(raw,c),'prep-shield@mage/one'))
c.preparation.hostile=false
assert(find(run(raw,c),'prep-shield@mage/one','excluded').reason=='preparation-window-closed')
c.preparation.offscreenPrep=true
assert(find(run(raw,c),'prep-mirror@mage/one'))
-- Existing buff, actual allocation, one-shot state, difficulty and accounting.
for _,case in ipairs({{'enabled',false,'preparation-disabled'}, {'instantPrep',true,'preparation-finished'},
    {'shortDifficulty',false,'preparation-difficulty'}, {'accountingReady',false,'preparation-accounting-unknown'}}) do
    raw,c=input();c.preparation[case[1]]=case[2]
    assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason==case[3])
end
raw,c=input();raw.actors[1].facts.protections=fact({'buff/mirror'})
assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason=='buff-already-present')
raw.actors[1].facts.protections=nil
assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason=='buff-presence-unknown')
raw,c=input();raw.actors[1].facts.spellbook=fact({'SPWI114'})
assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason=='spell-unavailable')
raw,c=input();c.preparation.tick=9
assert(find(run(raw,c),'prep-mirror@mage/one','excluded').reason=='preparation-observation-stale')
raw,c=input();c.ownership.dialogue=true
assert(#run(raw,c).eligible==1)
-- No submission-shaped action; malformed or missing preparation inputs reject.
raw,c=input();c.preparation.accountingReady=nil
assert(not pcall(run,raw,c))
raw,c=input();c.prebuffs[1].window='anything'
assert(not pcall(run,raw,c))
return 4
