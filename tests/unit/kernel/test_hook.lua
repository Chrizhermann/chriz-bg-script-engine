-- Host contract of the BCS handoff gate: kill switch, family switches, fail-soft declines,
-- one answer per creature and script pass, one deciding script per creature.
local raw=require('kernel.hook')
local tick=100
local function clock() return tick end
local function pass() tick=tick+1 end
local function rejects(fn) assert(not pcall(fn)) end
-- Unless a case says otherwise: script s1 is hooked and nothing sits below it.
local hook={new=function(config)
    if config.hooked==nil then config.hooked={s1='mage'} end
    if config.below==nil then config.below=function() return {} end end
    return raw.new(config)
end}
local actor={id=7,script='s1'}

-- 1. With no decider the gate declines everything; it never raises on bad input.
local g=hook.new({now=clock})
assert(g:claim(actor,'mage')==false)
assert(g:claim(nil,'mage')==false and g:claim({id=-1},'mage')==false and g:claim({id=1.5},'mage')==false)
assert(g:claim({id=7},'mage')==false and g:claim({id=7,script=''},'mage')==false)
assert(g:claim(actor,'dragon')==false and g:claim(actor,nil)==false)
local s=g:inspect()
assert(s.counts.reached==3 and s.counts.claimed==0)
assert(s.declines['no-decider']==1 and s.declines['bad-actor']==3 and s.declines['unknown-family']==2)
assert(s.declines['bad-script']==2)
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
assert(g:claim({id=8,script='s1'},'priest')==false)
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
assert(g:claim({id=8,script='s1'},'priest')==false and g:claim({id=8,script='s1'},'priest')==false and asked==2)
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
assert(g:claim({id=9,script='s1'},'mage')==true)
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

-- 12. Several hooked scripts on one creature: the first that asks in a pass decides, with its
-- own family; the others decline in that pass. Script names are not case-sensitive.
tick=200
local families={}
g=hook.new({now=clock,hooked={tanari='monster',DW2MS2GE='fighter'},
    decide=function(a,family) families[#families+1]=a.script..'/'..family;return {hold=true} end})
assert(g:claim({id=7,script='TANARI'},'monster')==true)
assert(g:claim({id=7,script='dw2ms2ge'},'fighter')==false and g:inspect().declines['lower-script']==1)
assert(g:claim({id=7,script='tanari'},'monster')==true and g:inspect().counts.repeats==1)
assert(#families==1 and families[1]=='tanari/monster')
-- In a pass where the higher script never reaches its hook, the lower one decides.
pass()
assert(g:claim({id=7,script='dw2ms2ge'},'fighter')==true and families[2]=='dw2ms2ge/fighter')
-- When the deciding script declines, the lower one still does not take over in that pass.
g:setDecider(function() return nil end);pass()
assert(g:claim({id=7,script='tanari'},'monster')==false and g:claim({id=7,script='dw2ms2ge'},'fighter')==false)
assert(g:inspect().declines['no-decision']==1 and g:inspect().declines['lower-script']==2)

-- 13. The script stack: hooked scripts below are fine, any other script below declines, and so
-- does a script that is not in the creature's stack or a stack reader that fails.
local stacks={[7]={'dw2ms2ge'},[8]={'shoutdlg'},[9]={'DW2MS2GE','None'}}
g=hook.new({now=clock,hooked={tanari='monster',dw2ms2ge='fighter',none='x'},
    below=function(id,script) if id==10 then error('freed') end;return stacks[id] end,
    decide=function() return {hold=true} end})
pass()
assert(g:claim({id=7,script='tanari'},'monster')==true)
assert(g:claim({id=8,script='tanari'},'monster')==false and g:inspect().declines['script-below']==1)
assert(g:claim({id=9,script='tanari'},'monster')==true)
assert(g:claim({id=11,script='tanari'},'monster')==false and g:inspect().declines['no-stack']==1)
assert(g:claim({id=10,script='tanari'},'monster')==false and g:inspect().counts.errors==1)

-- 14. Without the install's list of hooked scripts, or without a stack reader, the engine
-- declines; the list can arrive later.
g=raw.new({now=clock,decide=function() return {hold=true} end,below=function() return {} end})
pass()
assert(g:claim(actor,'mage')==false and g:inspect().declines['no-registry']==1)
assert(g:inspect().hookedScripts==nil)
g:setHooked({S1='mage'})
assert(g:claim(actor,'mage')==true and g:inspect().hookedScripts==1)
g=raw.new({now=clock,hooked={s1='mage'},decide=function() return {hold=true} end})
assert(g:claim(actor,'mage')==false and g:inspect().declines['no-stack']==1)
rejects(function() raw.new({now=clock,below=1}) end)
rejects(function() g:setHooked('s1') end)

-- 15. An observer (the director's check-in) sees each fresh question that passes the gate's
-- checks, with or without a decider; its errors are counted and change no answer. allows()
-- reports the switches.
local seen={}
g=hook.new({now=clock,observe=function(a,family)
    seen[#seen+1]=a.id..':'..a.script..':'..family
    if a.id==9 then error('observer broke') end
end})
pass()
assert(g:claim(actor,'mage')==false and g:claim(actor,'mage')==false)
assert(#seen==1 and seen[1]=='7:s1:mage' and g:inspect().declines['no-decider']==1)
assert(g:claim({id=9,script='s1'},'mage')==false and g:inspect().counts.observeErrors==1)
assert(g:inspect().counts.errors==0)
g:setFamily('mage',false);pass()
assert(g:claim(actor,'mage')==false and #seen==2 and g:allows('priest') and not g:allows('mage'))
g:setDecider(function() return {hold=true} end);g:setFamily('mage',true);pass()
assert(g:claim(actor,'mage')==true and #seen==3 and g:allows('mage') and not g:allows('dragon'))
g:setEnabled(false)
assert(not g:allows('mage'))
rejects(function() raw.new({now=clock,observe=1}) end)

-- 16. A performer may skip a decision that no longer fits (its target died meanwhile): no
-- error and no backoff, so the next pass decides again at once.
local skips=0
g=hook.new({now=clock,decide=function() return {response='NoAction()'} end,
    perform=function() skips=skips+1;return skips==1 and 'skipped' or true end})
pass()
assert(g:claim(actor,'mage')==true)
ok,why=g:act(actor);assert(ok==false and why=='skipped')
assert(g:inspect().counts.skipped==1 and g:inspect().counts.errors==0 and g:inspect().counts.acted==0)
pass()
assert(g:claim(actor,'mage')==true and g:act(actor)==true and g:inspect().counts.acted==1)

-- 17. drives() tells, without asking the decider, whether the gate would ask it: switches,
-- registry, the scripts below, a decider and no backoff after an error.
local drove=0
g=hook.new({now=clock,decide=function(a)
    drove=drove+1
    if a.id==9 then error('decider broke') end
    return {hold=true}
end,below=function(id) if id==8 then return {'other'} end;return {} end})
pass()
assert(g:drives(actor,'mage')==true and drove==0)
assert(g:drives({id=8,script='s1'},'mage')==false and g:drives(nil,'mage')==false and g:drives({id=7},'mage')==false)
assert(g:drives(actor,'dragon')==false)
g:setFamily('mage',false);assert(g:drives(actor,'mage')==false);g:setFamily('mage',true)
g:setEnabled(false);assert(g:drives(actor,'mage')==false);g:setEnabled(true)
assert(g:claim({id=9,script='s1'},'mage')==false and g:drives({id=9,script='s1'},'mage')==false)
tick=tick+151
assert(g:drives({id=9,script='s1'},'mage')==true)
g:setDecider(nil);assert(g:drives(actor,'mage')==false)
assert(raw.new({now=clock,decide=function() end,below=function() return {} end}):drives(actor,'mage')==false)
return 17
