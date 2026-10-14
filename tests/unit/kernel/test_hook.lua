-- Host contract of the BCS handoff gate: kill switch, family switches, fail-soft declines,
-- one answer per creature and script pass.
local hook=require('kernel.hook')
local tick=100
local function clock() return tick end
local function pass() tick=tick+1 end
local function rejects(fn) assert(not pcall(fn)) end
local actor={id=7}

-- 1. With no decider the gate declines everything; it never raises on bad input.
local g=hook.new({now=clock})
assert(g:claim(actor,'mage')==false)
assert(g:claim(nil,'mage')==false and g:claim({id=-1},'mage')==false and g:claim({id=1.5},'mage')==false)
assert(g:claim(actor,'dragon')==false and g:claim(actor,nil)==false)
local s=g:inspect()
assert(s.counts.reached==3 and s.counts.claimed==0)
assert(s.declines['no-decider']==1 and s.declines['bad-actor']==3 and s.declines['unknown-family']==2)
assert(g:act(actor)==false)
rejects(function() hook.new({}) end)
rejects(function() hook.new({now=clock,backoffTicks=-1}) end)

-- 2. A decision is claimed, then performed once by the response; the next act has nothing.
local performed,asked={},0
g=hook.new({now=clock,decide=function(a,family)
    asked=asked+1
    if a.id==7 then return {response='Attack(NearestEnemyOf(Myself))',family=family} end
end,perform=function(a,d) performed[#performed+1]=a.id..':'..d.response;return true end})
pass()
assert(g:claim({id=8},'priest')==false)
assert(g:claim(actor,'mage')==true)
assert(g:act(actor)==true and performed[1]=='7:Attack(NearestEnemyOf(Myself))')
local ok,why=g:act(actor);assert(ok==false and why=='no-pending')
s=g:inspect()
assert(s.counts.claimed==1 and s.counts.acted==1 and s.declines['no-decision']==1)
assert(s.trace[1].kind=='claim' and s.trace[2].kind=='act' and s.trace[2].family=='mage')

-- 3. Within one pass the guarded copies and the hook get the same answer; the decider runs
-- once. The next pass asks again.
pass();asked=0
assert(g:claim(actor,'mage')==true and g:claim(actor,'mage')==true and g:claim(actor,'mage')==true)
assert(asked==1 and g:inspect().counts.repeats==2)
assert(g:claim({id=8},'priest')==false and g:claim({id=8},'priest')==false and asked==2)
assert(g:act(actor)==true)
pass()
assert(g:claim(actor,'mage')==true and asked==3)
-- A special copy that fired ends the pass before the hook: the claim is never acted on and
-- the next pass decides afresh.
pass()
assert(g:claim(actor,'mage')==true and asked==4 and g:act(actor)==true and #performed==3)

-- 4. The global kill switch declines at once and drops a claim made before it was thrown.
pass()
assert(g:claim(actor,'mage')==true)
g:setEnabled(false)
ok,why=g:act(actor);assert(ok==false and why=='no-pending')
assert(g:claim(actor,'mage')==false and g:inspect().declines.disabled==1)
g:setEnabled(true)
assert(g:claim(actor,'mage')==true and g:act(actor)==true)
rejects(function() g:setEnabled(1) end)

-- 5. Family switches are independent; turning one off drops only its pending claims.
pass()
assert(g:claim(actor,'fighter')==true)
g:setFamily('fighter',false)
assert(g:act(actor)==false and g:claim(actor,'fighter')==false and g:claim(actor,'mage')==true)
assert(g:inspect().declines['family-off']==1 and g:inspect().families.fighter==false)
assert(g:act(actor)==true)
rejects(function() g:setFamily('dragon',true) end)
local off=hook.new({now=clock,enabled=false,families={monster=false},decide=function() return {} end})
assert(off:claim(actor,'mage')==false and off:inspect().enabled==false and off:inspect().families.monster==false)
off:setEnabled(true)
assert(off:claim(actor,'monster')==false and off:claim(actor,'mage')==true)

-- 6. Errors decline, back that actor off for a while and leave other actors alone.
local fail=true
tick=100
g=hook.new({now=clock,backoffTicks=10,decide=function(a)
    if fail and a.id==7 then error('boom') end
    return {response='NoAction()'}
end,perform=function() return true end})
assert(g:claim(actor,'mage')==false and g:inspect().counts.errors==1)
fail=false;pass()
assert(g:claim(actor,'mage')==false and g:inspect().declines.backoff==1)
assert(g:claim({id=9},'mage')==true)
tick=110
assert(g:claim(actor,'mage')==true)
-- A tick far below the backoff (a load restarted the count) does not keep the actor blocked.
pass();fail=true;assert(g:claim(actor,'mage')==false);fail=false
tick=3
assert(g:claim(actor,'mage')==true)
tick=110

-- 7. A decision that is not plain data, or a performer that fails, is an error, not a claim.
g=hook.new({now=clock,backoffTicks=0,decide=function() return {f=function() end} end,perform=function() return true end})
assert(g:claim(actor,'mage')==false and g:inspect().counts.errors==1)
g:setDecider(function() return 'text' end)
assert(g:claim(actor,'mage')==false and g:inspect().counts.errors==2)
g:setDecider(function() return {hold='yes'} end)
assert(g:claim(actor,'mage')==false and g:inspect().counts.errors==3)
g:setDecider(function() return {response='NoAction()'} end)
g:setPerformer(function() return false end)
assert(g:claim(actor,'mage')==true)
ok,why=g:act(actor);assert(ok==false and why=='error' and g:inspect().counts.errors==4)
g:setPerformer(function() error('queue failed') end)
assert(g:claim(actor,'mage')==true and g:act(actor)==false and g:inspect().counts.errors==5)
g:setPerformer(nil)
assert(g:claim(actor,'mage')==true and g:act(actor)==false)

-- 8. A held round is claimed but nothing is performed.
local calls=0
g=hook.new({now=clock,decide=function() return {hold=true} end,perform=function() calls=calls+1;return true end})
pass()
assert(g:claim(actor,'priest')==true)
ok,why=g:act(actor);assert(ok==true and why=='held' and calls==0)
assert(g:inspect().counts.held==1 and g:inspect().counts.acted==0)

-- 9. A stale claim is not performed: too old, or from before the tick count restarted.
g=hook.new({now=clock,maxDecisionAgeTicks=5,decide=function() return {response='NoAction()'} end,
    perform=function() return true end})
assert(g:claim(actor,'mage')==true)
tick=tick+6
ok,why=g:act(actor);assert(ok==false and why=='stale' and g:inspect().counts.stale==1)
assert(g:claim(actor,'mage')==true)
tick=2
assert(g:act(actor)==false and g:inspect().counts.stale==2)
tick=110

-- 10. The decider and performer see copies; invalidate forgets claims, answers and backoffs.
local seen,decided=nil,0
g=hook.new({now=clock,decide=function(a) decided=decided+1;a.id=99;seen=a;return {response='NoAction()'} end,
    perform=function(a,d) d.response='changed';return true end})
assert(g:claim(actor,'mage')==true and actor.id==7 and seen.id==99 and decided==1)
g:invalidate()
assert(g:act(actor)==false and g:inspect().pending==0)
assert(g:claim(actor,'mage')==true and decided==2)

-- 11. A broken clock declines instead of raising.
g=hook.new({now=function() error('no clock') end,decide=function() return {} end})
assert(g:claim(actor,'mage')==false and g:inspect().declines['no-clock']==1)
return 11
