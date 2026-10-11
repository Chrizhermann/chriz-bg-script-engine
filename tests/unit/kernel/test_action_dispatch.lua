-- Orchestration is tested independently of the separately tested decision revalidator.
package.loaded['combat-intent.dispatch']={revalidate=function(_,fresh,age,admission)
    if fresh.expectedResource then assert(admission[fresh.expectedResource],'admission was not frozen/passed') end
    if fresh.unexpected then error('unexpected-revalidator') end
    if fresh.illegal then return nil,'no-current-choice' end
    return {kind='spell',resource='SPWI112',targetKey='target/one'}
end}
local boundary=require('kernel.action_dispatch')
local copy=require('kernel.manifest').copy
local function setup(admission)
    local now,reads,submits=0,0,0
    local id={adapterId='B-/combat/lab-mage',key='mage/one',resource='B-XPMAG0.CRE'}
    local frame={decision={input={frame={observerKey=id.key}}},
        ownership={player=false,hardMode=false,world=false,encounter=false,forced=false,
            dialogue=false,cutscene=false,staging=false,imageOwner=false,alive=true,active=true,
            hostile=true,actionIdle=true,auraReady=true,capable=true,eligible=true},
        context={epoch='test/epoch',session=1,area='BG2602.ARE',allegiance=255,adapterVersion='1.0.0',
            candidates={{key=id.key,resource=id.resource,area='BG2602.ARE',epoch='test/epoch'}}}}
    local mutate,submitHook
    local api=boundary.new({clock={now=function() return now end},leaseTicks=3,attemptTicks=20,maxProposalAgeTicks=2,
        admission=admission,
        read=function() reads=reads+1;local f=copy(frame);if mutate then mutate(f,reads) end;return f end,
        submit=function(who,request) submits=submits+1;assert(who.key==id.key and request.kind=='spell');
            if submitHook then return submitHook() end;return true end})
    return api,id,frame,function() return reads,submits end,function(v) now=v end,
        function(fn) mutate=fn end,function(fn) submitHook=fn end
end
-- Default-off, two fresh reads, one pending attempt even after start, independent completion.
local a,id,f,count=setup()
assert(select(2,a:dispatch(id,{}))=='runtime-disabled' and count()==0)
a:setEnabled(true)
local r=assert(a:dispatch(id,{}));assert(r.state=='accepted');local reads,calls=count();assert(reads==2 and calls==1)
assert(select(2,a:dispatch(id,{}))=='actor-in-flight')
assert(a:observe(r.attemptId,{kind='started'}).state=='started')
assert(select(2,a:dispatch(id,{}))=='actor-in-flight')
local no,why=a:observe(r.attemptId,{kind='completed'});assert(no.state=='started' and why=='missing-proof')
assert(a:observe(r.attemptId,{kind='completed',proof='independent-postcondition'}).state=='completed')
assert(a:inspect().pending==0)
-- Immediate reread defeats changed owner/epoch/target and callback errors; never submits.
for _,change in ipairs({function(s) s.ownership.dialogue=true end,
    function(s) s.ownership.auraReady=false end,function(s) s.context.epoch='changed' end,
    function(s) s.decision.illegal=true end,function() error('read failed') end}) do
    local a,id,_,count,_,mutate=setup();a:setEnabled(true)
    mutate(function(s,n) if n==2 then change(s) end end)
    assert(not a:dispatch(id,{}));local _,calls=count();assert(calls==0)
end
-- Disable/load return ownership without clearing an engine queue or retrying.
local a,id,_,count=setup();a:setEnabled(true);local r=assert(a:dispatch(id,{}))
a:disable(id.adapterId,'test-disabled');assert(a:inspect().pending==0)
assert(not a:dispatch(id,{}));local _,calls=count();assert(calls==1)
local a,id=setup();a:setEnabled(true);local r=assert(a:dispatch(id,{}));a:invalidate('load')
assert(not a:observe(r.attemptId,{kind='started'}));assert(not a:inspect().enabled)
-- A submission exception may have queued; hold the actor until expiry, never count success.
local a,id,_,count,time,_,submit=setup();a:setEnabled(true);submit(function() error('maybe queued') end)
local r=assert(a:dispatch(id,{}));assert(r.state=='unknown')
assert(select(2,a:dispatch(id,{}))=='actor-in-flight');time(21);assert(#a:tick()==1 and a:inspect().pending==0)
-- Feature disable during a callback cannot be overwritten by a late successful return.
local a,id,_,count,_,mutate=setup();a:setEnabled(true)
mutate(function(_,n) if n==2 then a:setEnabled(false) end end)
assert(not a:dispatch(id,{}));local _,calls=count();assert(calls==0)
local a,id,_,_,_,_,submit=setup();a:setEnabled(true)
submit(function() a:invalidate('load-during-submit');return true end)
assert(a:dispatch(id,{}).state=='invalidated' and a:inspect().pending==0)
-- A read callback cannot race its own outer dispatch into a second submission.
local a,id,_,count,_,mutate=setup();a:setEnabled(true)
local nested,nestedWhy
mutate(function(_,n) if n==1 then nested,nestedWhy=a:dispatch(id,{}) end end)
local outer=assert(a:dispatch(id,{}))
assert(nested==nil and nestedWhy=='dispatch-in-progress')
local reads,submits=count();assert(outer.state=='accepted' and reads==2 and submits==1)

-- The same refusal applies during submission, without an extra queue request.
local a,id,_,count,_,_,submit=setup();a:setEnabled(true)
submit(function() nested,nestedWhy=a:dispatch(id,{});return true end)
outer=assert(a:dispatch(id,{}))
reads,submits=count()
assert(nested==nil and nestedWhy=='dispatch-in-progress')
assert(outer.state=='accepted' and reads==2 and submits==1)

-- An unexpected error cannot leave the manager permanently guarded.
local a,id,_,count,_,mutate=setup();a:setEnabled(true)
mutate(function(s,n) if n==1 then s.decision.unexpected=true end end)
local ok,err=pcall(function() a:dispatch(id,{}) end)
assert(not ok and tostring(err):find('unexpected-revalidator',1,true))
mutate(nil)
outer=assert(a:dispatch(id,{}));reads,submits=count()
assert(outer.state=='accepted' and reads==3 and submits==1)
local admission={SPWI114={target='self',geometryId='test/shield'}}
local a,id,f,count=setup(admission)
admission.SPWI114=nil;f.decision.expectedResource='SPWI114';a:setEnabled(true)
assert(a:dispatch(id,{}).state=='accepted');assert(count()==2)
return 5
