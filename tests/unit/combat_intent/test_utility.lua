-- Synthetic arithmetic only: these weights are not a mage or SCS policy.
local profile=require('combat-intent.profile')
local utility=require('combat-intent.utility')
local choose=require('combat-intent.choose')
local rng=require('kernel.rng')
local actions=require('combat-intent.actions')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local groups=0

local function fails(fn)
    local ok=pcall(fn)
    assert(not ok,'invalid input was accepted')
end
local config={id='synthetic/math',weights={control=2,resourceCost=-1,uncertainty=-0.5},
    nearBestBand=2,reactionTicks=1,commitmentTicks=3,maxMemoryAge=5,minConfidence=0.7}
local p=profile.new(config)
assert(p.id==config.id and p.weights.control==2)
config.weights.control=99
assert(p.weights.control==2)
fails(function() profile.new({id='x',weights={},nearBestBand=0,reactionTicks=0,commitmentTicks=0,
    maxMemoryAge=0,minConfidence=1,extra=true}) end)
local invalid=copy(p);invalid.weights.cheat=1;fails(function() profile.new(invalid) end)
invalid=copy(p);invalid.weights.control=0/0;fails(function() profile.new(invalid) end)
invalid=copy(p);invalid.nearBestBand=-1;fails(function() profile.new(invalid) end)
invalid=copy(p);invalid.reactionTicks=1.5;fails(function() profile.new(invalid) end)
groups=groups+1

local eligible={
    {id='b@enemy',action=actions.spell('SPWI112',{kind='actor',key='enemy'}),geometryId='single',notes={}},
    {id='a@enemy',action=actions.spell('SPWI112',{kind='actor',key='enemy'}),geometryId='single',notes={}},
    {id='decline',action=actions.decline(),notes={'legacy'}},
}
local terms={['a@enemy']={control=2,resourceCost=1},['b@enemy']={control=0,resourceCost=1},decline={uncertainty=2}}
local eligibleBefore,termsBefore=copy(eligible),copy(terms)
local rows=utility.score(eligible,terms,p)
assert(#rows==3 and rows[1].id=='a@enemy' and rows[1].score==3)
assert(rows[2].id=='b@enemy' and rows[2].score==-1 and rows[3].id=='decline' and rows[3].score==-1)
assert(#rows[1].terms==2 and rows[1].terms[1].reason=='control' and rows[1].terms[1].contribution==4)
assert(rows[1].terms[2].reason=='resourceCost' and rows[1].terms[2].contribution==-1)
assert(equal(eligible,eligibleBefore) and equal(terms,termsBefore))
rows[1].terms[1].value=500
assert(terms['a@enemy'].control==2)
-- Canonical reason order is control (+1e12), duration (-1e12), urgency (+1e-6).
-- In hash iteration, the small term can be rounded away between the large terms.
local precisionProfile=profile.new({id='synthetic/cancellation',
    weights={control=1000000,duration=-1000000,urgency=1},nearBestBand=0,
    reactionTicks=0,commitmentTicks=0,maxMemoryAge=0,minConfidence=0})
local precisionTerms={decline={control=1000000,duration=1000000,urgency=0.000001}}
local scoreA=utility.score({eligible[3]},precisionTerms,precisionProfile)[1].score
local reordered={decline={}}
reordered.decline.urgency=0.000001
reordered.decline.duration=1000000
reordered.decline.control=1000000
local scoreB=utility.score({eligible[3]},reordered,precisionProfile)[1].score
assert(scoreA==0.000001 and scoreB==scoreA,'score must sum in reason order')
groups=groups+1

local bad=copy(terms);bad['a@enemy']=nil;fails(function() utility.score(eligible,bad,p) end)
bad=copy(terms);bad['invented']={control=1};fails(function() utility.score(eligible,bad,p) end)
bad=copy(terms);bad['a@enemy'].urgency=1;fails(function() utility.score(eligible,bad,p) end)
bad=copy(terms);bad['a@enemy'].cheat=1;fails(function() utility.score(eligible,bad,p) end)
bad=copy(terms);bad['a@enemy'].control=math.huge;fails(function() utility.score(eligible,bad,p) end)
bad=copy(eligible);bad[1].rawObjectId=123;fails(function() utility.score(bad,terms,p) end)
bad=copy(eligible);bad[2].id=bad[1].id;fails(function() utility.score(bad,terms,p) end)
groups=groups+1

local bandProfile=copy(p);bandProfile.nearBestBand=2
local scored={{id='far',score=-9,terms={}}, {id='high',score=5,terms={}}, {id='near',score=4,terms={}}}
local reversed={scored[3],scored[2],scored[1]}
for seed=1,30 do
    local left=choose.select(scored,bandProfile,rng.new(seed))
    local right=choose.select(reversed,bandProfile,rng.new(seed))
    assert(equal(left,right) and (left.id=='high' or left.id=='near'))
    assert(#left.bandCandidates==2 and left.bandCandidates[1]=='high' and left.bandCandidates[2]=='near')
end
groups=groups+1

local first=choose.select(scored,bandProfile,rng.new(1))
local inner=rng.new(9);local draws=0
local counted={state=function() return inner:state() end,
    nextInt=function(_,lo,hi) assert(lo==1 and hi==1000000);draws=draws+1;return inner:nextInt(lo,hi) end}
local countedResult=choose.select(scored,bandProfile,counted)
assert(draws==1 and countedResult.seedBefore==9 and countedResult.seedAfter==inner:state())
local different=false
for seed=2,40 do if choose.select(scored,bandProfile,rng.new(seed)).id~=first.id then different=true end end
assert(different,'seeds should vary selections within band')
local soloProfile=copy(p);soloProfile.nearBestBand=0
local stream=rng.new(7);local before=stream:state()
local solo=choose.select(scored,soloProfile,stream)
assert(solo.id=='high' and solo.seedBefore==before and solo.seedAfter==before and stream:state()==before)
local none,why=choose.select({},p,stream);assert(none==nil and why=='no-candidates' and stream:state()==before)
groups=groups+1

fails(function() choose.select({{id='x',score=1,terms={}}, {id='x',score=2,terms={}}},p,rng.new(1)) end)
fails(function() choose.select({{id='x',score=math.huge,terms={}}},p,rng.new(1)) end)
local selected=choose.select(scored,bandProfile,rng.new(11));selected.bandCandidates[1]='tampered'
assert(scored[2].id=='high' and bandProfile.nearBestBand==2)
groups=groups+1
return groups
