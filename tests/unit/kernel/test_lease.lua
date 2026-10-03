local ownership=require('kernel.ownership')
local lease=require('kernel.lease')
local clock=require('kernel.clock')
local rng=require('kernel.rng')
local function fixture()
    local now=0
    local manager=lease.new({clock=clock.new(function() return now end),leaseTicks=3,attemptTicks=10})
    local id={adapterId='B-/combat/lab-mage',key='lab/mage',resource='B-XTEST1.CRE'}
    local s={player=false,hardMode=false,world=false,encounter=false,forced=false,
        dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,
        active=true,hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true,targetLegal=true}
    local c={epoch='stack-1',session=1,area='BG2602.ARE',allegiance=4,adapterVersion='1.0.0',
        candidates={{key=id.key,resource=id.resource,epoch='stack-1',area='BG2602.ARE'}}}
    return manager,id,s,c,function(t) now=t end
end
local request={kind='spell',resource='SPWI214',targetKey='lab/target'}

-- 1. Every higher authority and unknown/missing fact defeats combat ownership.
for _,flag in ipairs({'player','hardMode','world','encounter','forced','dialogue','cutscene','staging','imageOwner'}) do
    local _,_,s=fixture();s[flag]=true;assert(not ownership.decide(s).combat)
end
for _,flag in ipairs({'alive','active','hostile','actionIdle','auraReady','capable','eligible'}) do
    local _,_,s=fixture();s[flag]=false;assert(not ownership.decide(s).combat)
    s[flag]=nil;assert(not ownership.decide(s).combat)
end
local _,_,s=fixture();s.world=true;s.player=true;assert(ownership.decide(s).owner=='player')
s.player=false;assert(ownership.decide(s).owner=='world')
local _,_,s=fixture();s.player=true;s.eligible=nil;assert(ownership.decide(s).owner=='player')

-- 2. One use, fresh pre-dispatch checks and a separate accepted-but-not-started token.
local m,id,s,c=fixture();local token=assert(m:acquire(id,s,c));local calls=0
local result=assert(m:dispatch(token,s,c,request,function(r)
    calls=calls+1;assert(r.kind=='spell');r.resource='MUTATED'
    assert(not m:acquire(id,s,c)) -- no reentrant second dispatch
    return true
end))
assert(result.state=='accepted' and calls==1 and request.resource=='SPWI214')
assert(not m:dispatch(token,s,c,request,function() error('duplicate') end))
assert(not m:acquire(id,s,c))
local started=assert(m:observe(result.attemptId,{kind='started'}));assert(started.state=='started')
s.actionIdle=false;assert(not m:acquire(id,s,c))
local stale,staleReason=m:observe(result.attemptId,{attemptId='foreign-attempt',kind='completed',proof='independent-postcondition'})
assert(stale.state=='started' and staleReason=='stale-attempt')
local unproved,why=m:observe(result.attemptId,{kind='completed'})
assert(unproved.state=='started' and why=='missing-proof')
assert(m:observe(result.attemptId,{kind='completed',proof='independent-postcondition'}).state=='completed')

-- 3. Lost eligibility, lifecycle, target and context changes never call the dispatcher.
for _,flag in ipairs({'player','dialogue','cutscene','staging','imageOwner'}) do
    local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e));d[flag]=true
    assert(not a:dispatch(t,d,e,request,function() error('must not dispatch') end))
end
for _,field in ipairs({'epoch','session','area','allegiance','adapterVersion'}) do
    local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e));e[field]='changed'
    assert(not a:dispatch(t,d,e,request,function() error('must not dispatch') end))
end
for _,flag in ipairs({'eligible','capable','targetLegal','actionIdle','auraReady'}) do
    local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e));d[flag]=false
    assert(not a:dispatch(t,d,e,request,function() error('must not dispatch') end))
end
local a,b,d,e=fixture();e.candidates[2]=e.candidates[1];assert(not a:acquire(b,d,e))
local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e));e.candidates[2]=e.candidates[1]
assert(not a:dispatch(t,d,e,request,function() error('ambiguous actor') end))

-- 4. Unknown submission is not called accepted, retried, or released immediately.
local a,b,d,e,set=fixture();local t=assert(a:acquire(b,d,e))
local unknown=a:dispatch(t,d,e,request,function() error('queued then failed?') end)
assert(unknown.state=='unknown' and unknown.reason=='submission-unknown')
assert(not a:acquire(b,d,e));set(11);assert(a:acquire(b,d,e))
local a,b,d,e,set=fixture();local t=assert(a:acquire(b,d,e));set(3)
assert(not a:dispatch(t,d,e,request,function() error('expired') end))
local a,b,d,e,set=fixture();local t=assert(a:acquire(b,d,e))
local waiting=a:dispatch(t,d,e,request,function() return true end);set(10)
local expired=a:tick();assert(#expired==1 and expired[1].attemptId==waiting.attemptId and expired[1].state=='timed-out')
local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e))
local invalid=a:dispatch(t,d,e,request,function() a:invalidate('load');return true end)
assert(invalid.state=='invalidated' and invalid.reason=='during-dispatch')

-- 5. Invalidation clears ephemeral attempts; cross-adapter actor locks cannot overlap.
local a,b,d,e=fixture();local t=assert(a:acquire(b,d,e))
local other={adapterId='B-/combat/other',key=b.key,resource=b.resource}
assert(not a:acquire(other,d,e))
local result=a:dispatch(t,d,e,request,function() return true end)
local ended=a:invalidate('load');assert(#ended==1 and ended[1].state=='invalidated')
assert(not a:observe(result.attemptId,{kind='started'}))
assert(a:acquire(other,d,e))

-- 6. Seeded event mixes end through invalidation/expiry without native queue operations.
local random=rng.new(9127)
for _=1,32 do
    local a,b,d,e,set=fixture();local t=assert(a:acquire(b,d,e))
    local result=a:dispatch(t,d,e,request,function() return true end)
    local choice=random:nextInt(1,3)
    if choice==1 then a:observe(result.attemptId,{kind='started'})
    elseif choice==2 then a:invalidate('area-change')
    else a:observe(result.attemptId,{kind='failed',reason='rejected'}) end
    set(20);assert(a:acquire(b,d,e))
end
return 6
