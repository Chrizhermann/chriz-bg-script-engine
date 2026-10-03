local perception=require('combat-intent.perception')
local beliefs=require('combat-intent.beliefs')
local function fact(source,value,extra)
    local f={source=source,value=value,observedAt=10,expiresAt=20,confidence=1}
    for k,v in pairs(extra or {}) do f[k]=v end;return f
end
local function frame()
    return {schemaVersion=1,tick=10,observerKey='mage/one',eligibleAllies={'ally/one'},actors={
        {key='mage/one',visible=true,detected=true,facts={spellbook=fact('self',{'SPWI112'}),auraReady=fact('self',true)}},
        {key='enemy/one',visible=true,detected=true,facts={position=fact('sight',{x=10,y=20}),alive=fact('sight',true),
            protections=fact('witnessed',{'mirror-image'},{basis='visible-cast/123'}),
            resistances=fact('engine-private',{fire=100}),spellbook=fact('sight',{'SPWI900'})}},
    }}
end
-- Direct perception distinguishes public observations from forbidden engine knowledge.
local input=frame();local view=perception.build(input)
assert(view:get('enemy/one','position').kind=='observed')
assert(view:get('enemy/one','protections').kind=='observed')
assert(view:get('enemy/one','resistances').kind=='unknown' and view:get('enemy/one','resistances').value==nil)
assert(view:get('enemy/one','spellbook').kind=='unknown')
assert(view:get('mage/one','spellbook').value[1]=='SPWI112')
assert(require('combat-intent.snapshot').new(frame()):get('enemy/one','resistances').kind=='unknown')
-- Seeing an actor does not reveal a spell cast before it was observed.
local unwitnessed=frame()
unwitnessed.actors[2].facts.lastCast=fact('sight','SPWI214')
assert(perception.build(unwitnessed):get('enemy/one','lastCast').kind=='unknown')
local privateReport=frame()
privateReport.actors[1].facts.spellbook=fact('shared',{'SPWI900'},{origin='ally/one',basis='guess/1',evidenceSource='inference'})
assert(perception.build(privateReport):get('mage/one','spellbook').kind=='unknown')
unwitnessed.actors[2].facts.lastCast=fact('witnessed','SPWI214',{basis='visible-cast/124'})
assert(perception.build(unwitnessed):get('enemy/one','lastCast').kind=='observed')
unwitnessed.actors[2].facts.lastCast=fact('shared','SPWI214',{origin='ally/one',basis='actor-seen/125',evidenceSource='sight'})
assert(perception.build(unwitnessed):get('enemy/one','lastCast').kind=='unknown')
-- Visibility and detection are separate necessary facts. Neither grants omniscience.
for _,field in ipairs({'visible','detected'}) do
    local raw=frame();raw.actors[2][field]=false
    local hidden=perception.build(raw)
    assert(hidden:get('enemy/one','position').kind=='unknown')
    assert(hidden:get('enemy/one','protections').kind=='unknown')
end
-- Immutable-by-copy snapshots, guarded declared-field reader, no raw native objects.
input.actors[2].facts.position.value.x=999
local returned=view:get('enemy/one','position');returned.value.x=888
assert(view:get('enemy/one','position').value.x==10)
local exported=view:export();exported.actors[2].facts.position.value.x=777
assert(view:get('enemy/one','position').value.x==10)
local reader=view:reader({'position','alive'})
assert(reader('enemy/one','position').value.x==10)
assert(not pcall(reader,'enemy/one','spellbook'))
assert(not pcall(function() view.anything=true end))
assert(not pcall(function() view:get('enemy/one','rawObjectId') end))
local bad=frame();bad.actors[2].facts.position.value={native=function() end}
assert(not pcall(perception.build,bad))
bad=frame();bad.actors[2].key='12345';assert(not pcall(perception.build,bad))
-- Inferences and eligible ally reports never become direct current observation.
local raw=frame()
raw.actors[2].facts.resistances=fact('inference',{fire=50},{basis='observed-damage/2',confidence=.6})
raw.actors[2].facts.lastCast=fact('shared','SPWI214',{origin='ally/one',basis='observed-cast/3',evidenceSource='witnessed'})
local inferred=perception.build(raw)
assert(inferred:get('enemy/one','resistances').kind=='inferred')
assert(inferred:get('enemy/one','resistances').confidence==.6)
assert(inferred:get('enemy/one','lastCast').kind=='shared')
raw.eligibleAllies={}
assert(perception.build(raw):get('enemy/one','lastCast').kind=='unknown')
raw=frame();raw.actors[2].facts.resistances=fact('inference',{fire=50})
assert(perception.build(raw):get('enemy/one','resistances').kind=='unknown')
-- Missing, future, stale and expired evidence have distinct bounded outcomes.
raw=frame();raw.actors[2].facts.position.observedAt=11
assert(perception.build(raw):get('enemy/one','position').kind=='unknown')
raw=frame();raw.tick=11
assert(perception.build(raw):get('enemy/one','position').kind=='remembered')
raw.tick=20
local expired=perception.build(raw):get('enemy/one','position')
assert(expired.kind=='expired' and expired.value==nil)
assert(view:get('missing/actor','position').kind=='unknown')
-- Beliefs remember only admitted evidence, retain its origin, and expire explicitly.
local memory=beliefs.new({observerKey='mage/one',maxEntries=16})
assert(memory:observe(view))
local remembered=memory:read('enemy/one','position',15)
assert(remembered.kind=='remembered' and remembered.observedAt==10 and remembered.age==5)
assert(remembered.value.x==10)
local hiddenFrame=frame();hiddenFrame.tick=15;hiddenFrame.actors[2].visible=false
memory:observe(perception.build(hiddenFrame))
assert(memory:read('enemy/one','position',15).kind=='remembered')
assert(memory:read('enemy/one','resistances',15).kind=='unknown')
assert(memory:read('enemy/one','position',20).kind=='expired')
memory:invalidate();assert(memory:read('enemy/one','position',20).kind=='unknown')
-- Shared/inferred evidence preserves its epistemic category in memory; stale updates do not win.
memory=beliefs.new({observerKey='mage/one',maxEntries=16});memory:observe(inferred)
local shared=memory:read('enemy/one','lastCast',15)
assert(shared.kind=='shared' and shared.origin=='ally/one' and shared.age==5)
assert(memory:read('enemy/one','resistances',15).kind=='inferred')
local newer=frame();newer.tick=12;newer.actors[2].facts.position=fact('sight',{x=30,y=40},{observedAt=12,expiresAt=22})
memory:observe(perception.build(newer));memory:observe(view)
assert(memory:read('enemy/one','position',15).value.x==30)
local tiny=beliefs.new({observerKey='mage/one',maxEntries=1});local ok,why=tiny:observe(view)
assert(not ok and why=='capacity' and tiny:size()==0) -- no partial memory replacement
return 7
