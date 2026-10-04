local intentions=require('combat-intent.intention')
local copy=require('kernel.manifest').copy
local owner={adapterId='B-/combat/lab-mage',key='mage/one',resource='B-XPMAG0.CRE'}
local function frame(tick)
    return {sceneKey='combat/one',tick=tick,identity=copy(owner),enabled=true,combatActive=true,
        facts={target='enemy/one',targetAlive=true,route='route/one'},
        legalSteps={reposition=true,slow=true}}
end
local function plan()
    return {purpose='reposition then attempt Slow',steps={'reposition','slow'},expiresAt=20,
        assumptions={target='enemy/one',targetAlive=true,route='route/one'}}
end
local function setup()
    local p=intentions.new({identity=owner,sceneKey='combat/one',maxSteps=3,maxLifetimeTicks=20})
    assert(p:begin(plan(),frame(0)));return p
end
local function complete(p,step,tick)
    assert(p:observe(step.token,{kind='accepted'},frame(tick)))
    assert(p:observe(step.token,{kind='started'},frame(tick)))
    return p:observe(step.token,{kind='completed',proof='independent-postcondition'},frame(tick))
end
-- Next step is inert; accepted/started alone cannot unlock the second step.
local p=setup();local first=assert(p:next(frame(0)))
assert(first.step=='reposition' and first.index==1 and first.dispatchAuthorized==false)
assert(first.purpose=='reposition then attempt Slow')
assert(p:observe(first.token,{kind='accepted'},frame(1)))
assert(select(2,p:next(frame(1)))=='step-in-flight')
assert(p:observe(first.token,{kind='started'},frame(2)))
local denied,why=p:observe(first.token,{kind='completed'},frame(2))
assert(not denied and why=='missing-proof')
assert(p:observe(first.token,{kind='completed',proof='independent-postcondition'},frame(3)))
local second=assert(p:next(frame(3)));assert(second.step=='slow' and second.index==2 and second.token~=first.token)
assert(select(2,p:observe(first.token,{kind='completed',proof='independent-postcondition'},frame(3)))=='stale-step')
assert(complete(p,second,4));assert(p:inspect().status=='completed' and p:next(frame(4))==nil)

-- Every next step revalidates current assumptions and legal proposals, never a stored queue.
for _,change in ipairs({function(f) f.facts.targetAlive=false end,
    function(f) f.facts.route='changed/route' end,function(f) f.facts.target=nil end,
    function(f) f.identity=false end,function(f) f.identity.resource='B-XPMAG1.CRE' end,
    function(f) f.enabled=false end,function(f) f.combatActive=false end,
    function(f) f.sceneKey='combat/other' end,function(f) f.legalSteps.reposition=false end}) do
    local p=setup();local f=frame(1);change(f)
    assert(not p:next(f));assert(p:inspect().status=='aborted')
    assert(not p:next(frame(2))) -- a fresh-looking frame cannot revive the old plan
end
local p=setup();local first=p:next(frame(0));assert(complete(p,first,1))
local f=frame(2);f.legalSteps.slow=false
assert(not p:next(f) and p:inspect().status=='aborted')

-- Abort/unknown ends the intention; a new proposal gets a new token, not an automatic retry.
for _,kind in ipairs({'failed','interrupted','unknown','invalidated','timed-out'}) do
    local p=setup();local step=p:next(frame(0))
    assert(p:observe(step.token,{kind='accepted'},frame(1)))
    assert(p:observe(step.token,{kind='started'},frame(1)))
    assert(p:observe(step.token,{kind=kind,reason='observed test outcome'},frame(2)))
    assert(p:inspect().status=='aborted' and p:inspect().reason==kind)
    assert(not p:next(frame(3)))
    assert(p:begin(plan(),frame(3)))
    local later=p:next(frame(3));assert(later.token~=step.token)
    assert(select(2,p:observe(step.token,{kind='started'},frame(3)))=='stale-step')
end

-- Lifetimes are not renewed by reading; scope invalidation is permanent for this instance.
local p=setup();assert(p:next(frame(19)));assert(not p:next(frame(20)))
assert(p:inspect().reason=='expired')
local p=setup();p:invalidate('load');assert(not p:next(frame(1)))
assert(not p:begin(plan(),frame(1)))
local p=setup();p:cancel('target changed');assert(p:inspect().reason=='target changed')
assert(not p:next(frame(1)))

-- An event routed from another actor's first plan is not this actor's first step.
local p=setup();local mine=p:next(frame(0))
local other=copy(owner);other.key='mage/two';other.resource='B-XPMAG1.CRE'
local q=intentions.new({identity=other,sceneKey='combat/one',maxSteps=3,maxLifetimeTicks=20})
local f=frame(0);f.identity=other;assert(q:begin(plan(),f));local theirs=q:next(f)
assert(select(2,p:observe(theirs.token,{kind='accepted'},frame(1)))=='stale-step')
assert(p:observe(mine.token,{kind='accepted'},frame(1)))

-- Copies, bounded steps/lifetime, scalar assumptions and transactional bad-input checks.
local p=setup();local exported=p:inspect();exported.plan.steps[1]='caller mutation'
local step=p:next(frame(2));step.step='caller mutation'
assert(p:next(frame(2)).step=='reposition')
assert(not pcall(function() p:next(frame(1)) end))
assert(p:next(frame(3)).step=='reposition')
for _,change in ipairs({function(x) x.steps={'a','b','c','d'} end,
    function(x) x.steps={} end,function(x) x.expiresAt=30 end,
    function(x) x.assumptions.target={} end,function(x) x.steps[3]=function() end end}) do
    local p=intentions.new({identity=owner,sceneKey='combat/one',maxSteps=3,maxLifetimeTicks=20})
    local bad=plan();change(bad);assert(not pcall(function() p:begin(bad,frame(0)) end))
    assert(p:inspect().status=='idle' and p:begin(plan(),frame(0)))
end
return 5
