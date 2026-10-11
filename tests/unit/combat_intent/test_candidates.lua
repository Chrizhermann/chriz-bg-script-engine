local candidates=require('combat-intent.candidates')
local perception=require('combat-intent.perception')
local copy=require('kernel.manifest').copy
local function fact(source,value)
    return {source=source,value=value,observedAt=10,expiresAt=20,confidence=1}
end
local function scene()
    return {schemaVersion=1,sceneKey='synthetic/scene-1',tick=10,observerKey='mage/one',eligibleAllies={},actors={
        {key='mage/one',visible=true,detected=true,facts={
            spellbook=fact('self',{'SPWI112','SPWI224','SPWI312'}),auraReady=fact('self',true),
            alive=fact('self',true),idle=fact('self',true),canAct=fact('self',true),
            silenced=fact('self',false),castingFailure=fact('self',0)}},
        {key='enemy/one',visible=true,detected=true,facts={alive=fact('sight',true),
            position=fact('sight',{x=100,y=200}),range=fact('sight',10),
            relation=fact('sight','enemy'),lineOfSight=fact('sight',true)}}}}
end
local function options()
    local owner={player=false,hardMode=false,world=false,encounter=false,forced=false,
        dialogue=false,cutscene=false,staging=false,imageOwner=false,
        alive=true,active=true,hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true}
    -- Authored E2 geometry/range fixtures. Not the installed SPL/PRO interpretation.
    local spells={}
    for _,row in ipairs({{'missile','SPWI112','actor'},{'dust','SPWI224','point'},{'slow','SPWI312','point'}}) do
        spells[#spells+1]={id=row[1],resource=row[2],target=row[3],range=30,
            geometry='exact',geometryId='synthetic/'..row[1],maxCastingFailure=.5,
            immunityTags={'immune/'..row[1]}}
    end
    local checks={};local frame=perception.build(scene()):export()
    for _,spell in ipairs(spells) do
        checks[spell.geometryId]={['enemy/one']={tick=10,complete=true,safe=true,
            sceneKey=frame.sceneKey,observerKey=frame.observerKey,actors=frame.actors,
            point={x=100,y=200},resource=spell.resource,anchorCovered=true}}
    end
    return {ownership=owner,ownershipContext={observerKey=frame.observerKey,tick=frame.tick,sceneKey=frame.sceneKey},
        spells=spells,targets={'enemy/one'},areaChecks=checks}
end
local function run(raw,config) return candidates.generate(perception.build(raw or scene()),config or options()) end
local function find(result,id)
    for _,v in ipairs(result.eligible) do if v.id==id then return v end end
end
local function excluded(result,id)
    for _,v in ipairs(result.excluded) do if v.id==id then return v.reason end end
end
-- One connected scene yields three spell proposals, wait and decline, never a dispatch request.
local result=run()
assert(#result.eligible==5 and #result.excluded==0)
assert(find(result,'missile@enemy/one').action.kind=='shadow-spell')
assert(find(result,'dust@enemy/one').action.target.kind=='point')
assert(find(result,'dust@enemy/one').action.target.x==100)
assert(find(result,'missile@enemy/one').notes[1]=='protection-knowledge-unknown')
assert(find(result,'wait').action.kind=='shadow-wait')
assert(find(result,'decline').action.kind=='legacy-decline')
assert(result.dispatchAuthorized==false)
-- Actual available copies and current readiness, not known spell names, admit casting.
for _,case in ipairs({
    {'spellbook',{},'spell-unavailable'}, {'auraReady',false,'aura-not-ready'},
    {'idle',false,'action-occupied'}, {'canAct',false,'caster-disabled'},
    {'alive',false,'caster-dead'}, {'silenced',true,'caster-silenced'},
    {'castingFailure',.75,'casting-failure-too-high'},
}) do
    local raw=scene();raw.actors[1].facts[case[1]]=fact('self',case[2])
    local r=run(raw);assert(excluded(r,'missile@enemy/one')==case[3],case[1])
end
local stale=scene();stale.tick=11
assert(excluded(run(stale),'missile@enemy/one')=='ownership-observation-stale')
stale=scene();stale.actors[1].facts.alive.observedAt=9
assert(excluded(run(stale),'missile@enemy/one')=='stale-caster-alive')
-- Current sensed legality and higher ownership remain mandatory, even in shadow.
for _,case in ipairs({{'alive',false,'target-dead'},{'relation','ally','target-not-enemy'},
    {'range',31,'out-of-range'},{'lineOfSight',false,'no-line-of-sight'}}) do
    local raw=scene();raw.actors[2].facts[case[1]]=fact('sight',case[2])
    assert(excluded(run(raw),'missile@enemy/one')==case[3])
end
local raw=scene();raw.actors[2].visible=false
assert(excluded(run(raw),'missile@enemy/one')=='stale-target-alive')
local config=options();config.ownership.dialogue=true
result=run(nil,config);assert(#result.eligible==1 and result.eligible[1].id=='decline')
assert(excluded(result,'missile@enemy/one')=='higher-world-owner')
config=options();config.ownership.actionIdle=false
assert(excluded(run(nil,config),'missile@enemy/one')=='blocked-actionIdle')
-- Unknown geometry/coverage never becomes an optimistic area or safe-target estimate.
config=options();config.spells[2].geometry='unknown'
assert(excluded(run(nil,config),'dust@enemy/one')=='geometry-unknown')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].safe=false
assert(excluded(run(nil,config),'dust@enemy/one')=='ally-risk')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].complete=false
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-unknown')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].tick=9
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-stale')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].point={x=99,y=200}
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-mismatch')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].resource='SPWI112'
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-mismatch')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].observerKey='mage/other'
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-mismatch')
config=options();config.areaChecks['synthetic/dust']['enemy/one'].anchorCovered=false
assert(excluded(run(nil,config),'dust@enemy/one')=='area-coverage-mismatch')
config=options();config.ownershipContext={observerKey='mage/other',tick=10,sceneKey='synthetic/scene-1'}
assert(excluded(run(nil,config),'missile@enemy/one')=='ownership-observation-stale')
raw=scene();raw.actors[1].facts.relation=fact('self','enemy')
config=options();config.targets={'mage/one'}
assert(excluded(run(raw,config),'missile@mage/one')=='offensive-self-target')
-- Fairly witnessed immunity can exclude; unknown or uncertain knowledge stays explicit.
raw=scene();raw.actors[2].facts.protections=fact('witnessed',{'immune/missile'})
raw.actors[2].facts.protections.basis='visible-protection/1'
assert(excluded(run(raw),'missile@enemy/one')=='known-protection')
raw.actors[2].facts.protections.source='engine-private'
assert(find(run(raw),'missile@enemy/one').notes[1]=='protection-knowledge-unknown')
-- Deterministic order, copy isolation and strict input shape.
config=options();config.spells={config.spells[3],config.spells[1],config.spells[2]}
local shuffled=run(nil,config);local ordinary=run()
for i,v in ipairs(ordinary.eligible) do assert(shuffled.eligible[i].id==v.id) end
local original=copy(config);local output=run(nil,config)
find(output,'dust@enemy/one').action.target.x=999
assert(find(run(nil,config),'dust@enemy/one').action.target.x==100)
assert(require('kernel.manifest').equal(original,config))
config=options();config.targets={'enemy/one','enemy/one'}
assert(not pcall(run,nil,config))
config=options();config.spells[1].rawObjectId=1234
assert(not pcall(run,nil,config))

-- Ordinary defensive casts consume a declared current copy and current self
-- protection knowledge. These scalar declarations do not identify SPL layouts.
local function selfSpell(id,resource,tag)
    return {id=id,resource=resource,target='self',range=0,geometry='exact',
        geometryId='synthetic/'..id,maxCastingFailure=.5,immunityTags={},buffTag=tag}
end
local function selfOptions(spells,targets)
    local result=options();result.spells=copy(spells);result.targets=copy(targets or {});return result
end
local function selfScene(resources,protections)
    local result=scene();result.actors[1].facts.spellbook=fact('self',resources)
    if protections then result.actors[1].facts.protections=fact('self',protections) end
    return result
end
local vanilla=selfSpell('shield','BGSHLD1','protect/shield')
local revised=selfSpell('mirror','SRMIRR1','protect/mirror')
local defensive=selfOptions({vanilla,revised})
raw=selfScene({'BGSHLD1','SRMIRR1'}, {})
result=run(raw,defensive)
assert(#result.eligible==4 and #result.excluded==0)
for _,id in ipairs({'shield@mage/one','mirror@mage/one'}) do
    local row=assert(find(result,id));assert(row.action.kind=='shadow-spell')
    assert(row.action.target.kind=='actor' and row.action.target.key=='mage/one')
    assert(row.geometryId=='synthetic/'..id:match('^([^@]+)'))
end
assert(result.dispatchAuthorized==false)
defensive.targets={'enemy/one','mage/one'}
result=run(raw,defensive)
assert(find(result,'shield@mage/one') and find(result,'mirror@mage/one'))
assert(not find(result,'shield@enemy/one') and not excluded(result,'shield@enemy/one'))
assert(#result.eligible==4 and #result.excluded==0)
-- An explicit self descriptor may not be offered against another actor.
local legality=require('combat-intent.legality')
assert(select(2,legality.check(perception.build(raw),vanilla,'enemy/one'))=='self-target-required')
raw=selfScene({'BGSHLD1','SRMIRR1'},{'protect/shield'})
assert(excluded(run(raw,defensive),'shield@mage/one')=='buff-already-present')
assert(find(run(raw,defensive),'mirror@mage/one'))
raw=selfScene({'BGSHLD1','SRMIRR1'})
assert(excluded(run(raw,defensive),'shield@mage/one')=='stale-self-protections')
raw=selfScene({'BGSHLD1','SRMIRR1'},{});raw.actors[1].facts.protections.observedAt=9
assert(excluded(run(raw,defensive),'shield@mage/one')=='stale-self-protections')
raw=selfScene({'BGSHLD1','SRMIRR1'},{});raw.actors[1].facts.protections.source='engine-private'
assert(excluded(run(raw,defensive),'shield@mage/one')=='stale-self-protections')
raw=selfScene({'BGSHLD1','SRMIRR1'},{'protect/shield'})
raw.actors[1].facts.protections.source='witnessed'
raw.actors[1].facts.protections.basis='visible-protection/self'
assert(excluded(run(raw,defensive),'shield@mage/one')=='buff-already-present')
raw=selfScene({'BGSHLD1'},{});
assert(excluded(run(raw,defensive),'mirror@mage/one')=='spell-unavailable')
raw=selfScene({'BGSHLD1'},{});raw.actors[1].facts.spellbook.observedAt=9
assert(excluded(run(raw,defensive),'shield@mage/one')=='stale-spell-allocation')
for _,case in ipairs({{'auraReady',false,'aura-not-ready'},
    {'silenced',true,'caster-silenced'}, {'castingFailure',.75,'casting-failure-too-high'}}) do
    raw=selfScene({'BGSHLD1'},{});raw.actors[1].facts[case[1]]=fact('self',case[2])
    assert(excluded(run(raw,defensive),'shield@mage/one')==case[3])
end
raw=selfScene({'BGSHLD1','SRMIRR1'},{});raw.actors[1].visible=false;raw.actors[1].detected=false
assert(find(run(raw,defensive),'shield@mage/one'))
config=selfOptions({selfSpell('shield','BGSHLD1','protect/shield')})
config.spells[1].geometry='unknown'
assert(excluded(run(selfScene({'BGSHLD1'},{}),config),'shield@mage/one')=='geometry-unknown')
config=selfOptions({vanilla});config.ownership.dialogue=true
assert(excluded(run(selfScene({'BGSHLD1'},{}),config),'shield@mage/one')=='higher-world-owner')
config=selfOptions({vanilla});config.ownership.capable=false
assert(excluded(run(selfScene({'BGSHLD1'},{}),config),'shield@mage/one')=='blocked-capable')
config=selfOptions({vanilla});local selfOriginal=copy(config)
result=run(selfScene({'BGSHLD1'},{}),config)
find(result,'shield@mage/one').action.target.key='changed'
assert(require('kernel.manifest').equal(config,selfOriginal))
assert(find(run(selfScene({'BGSHLD1'},{}),config),'shield@mage/one').action.target.key=='mage/one')
config=selfOptions({vanilla});config.spells[1].buffTag=nil
assert(not pcall(run,nil,config))
config=selfOptions({vanilla},{'enemy/one','enemy/one'})
local valid,problem=pcall(run,selfScene({'BGSHLD1'},{}),config)
assert(not valid and tostring(problem):find('duplicate target',1,true))
config=options();config.spells[1].buffTag='protect/unexpected'
assert(not pcall(run,nil,config))
return 6
