local bootstrap=require('kernel.bootstrap')
local clock=require('kernel.clock')
local fixture=require('tests.unit.kernel.eligibility_fixture')
local listeners=require('adapters.eeex.listeners')
local eeex=require('adapters.eeex.engine')
local m,e,a,copy=fixture()
local tick,calls=0,0
local candidates={{key=a.key,resource=a.resource,epoch=e.epoch,area='BG2602.ARE'},
    {key='unknown/npc',resource='UNKNOWN.CRE',epoch=e.epoch,area='BG2602.ARE'}}
local snapshot={version=1,tick=0,area='BG2602.ARE',x=10,y=20,actionId=0,queuedActions=0,alive=true}
local function read(id) assert(id.key==a.key);return copy(snapshot) end
local k=bootstrap.new({clock=clock.new(function() return tick end),traceCapacity=8,retryTicks=5})
assert(k:register(m,function(id,s) calls=calls+1;id.key='mutated';s.x=99 end))
assert(k:enroll({adapterId=m.id,key=a.key,resource=a.resource}))

-- 1. Only explicitly enrolled, exact eligible actors reach the read-only callback.
k:sample(e,candidates,read);assert(calls==1 and snapshot.x==10 and a.key=='lab/mage-1')
assert(not k.dispatch and not k.save and not k.setLocal)
assert(k:inspect().enrolled==1)
e.resources['B-XTEST0.BCS'].sha256=string.rep('c',64)
k:sample(e,candidates,read);assert(calls==2)
assert(k:inspect().trace[2].reason=='observed')
e.resources['B-XTEST0.BCS'].sha256=string.rep('b',64)

-- 2. Local reader/policy errors open only that adapter, then one bounded half-open probe.
local other=copy(m);other.id='B-/combat/other';local otherCalls=0
assert(k:register(other,function() otherCalls=otherCalls+1 end))
assert(k:enroll({adapterId=other.id,key=a.key,resource=a.resource}))
k:sample(e,candidates,function(id)
    if id.adapterId==m.id then error('private native failure text') end
    return copy(snapshot)
end)
assert(otherCalls==1 and k:inspect().circuits[m.id].state=='open')
k:sample(e,candidates,read);assert(calls==2 and otherCalls==2)
tick=5;k:sample(e,candidates,read)
assert(calls==3 and otherCalls==3 and k:inspect().circuits[m.id].state=='closed')
for _,row in ipairs(k:inspect().trace) do
    assert(not tostring(row.reason):find('private',1,true))
end

-- 3. Missing capability/disable/session change removes observation, not legacy actions.
e.capabilities.observe=false;k:sample(e,candidates,read);assert(calls==3)
e.capabilities.observe=true;k:disable(m.id,'user-disabled');k:sample(e,candidates,read)
assert(calls==3 and otherCalls==4)
k:invalidate('load');assert(k:inspect().enrolled==0)
k:sample(e,candidates,function() error('old enrollment survived') end)
assert(k:enroll({adapterId=other.id,key=a.key,resource=a.resource}))
e.epoch='stack-2';k:sample(e,candidates,read);e.epoch='stack-1';k:sample(e,candidates,read)
assert(otherCalls==4 and k:inspect().trace[#k:inspect().trace].reason=='stale-stack')

-- 4. Snapshot boundary rejects raw objects/IDs; trace is bounded and detached.
local fresh=bootstrap.new({clock=clock.new(function() return tick end),traceCapacity=4,retryTicks=5})
assert(fresh:register(m,function() error('must not receive object ID') end))
assert(fresh:enroll({adapterId=m.id,key=a.key,resource=a.resource}))
fresh:sample(e,candidates,function() local s=copy(snapshot);s.objectId=42;return s end)
assert(fresh:inspect().circuits[m.id].state=='open')
for _=1,12 do tick=tick+1;fresh:sample(e,candidates,read) end
local result=fresh:inspect();assert(#result.trace==4);result.trace[1].reason='mutated'
assert(fresh:inspect().trace[1].reason~='mutated')

-- 5. Native void-listener trampoline registers once, swaps handlers, contains errors.
local state,registered={},{}
local registers={loaded=function(fn) registered[#registered+1]=fn end}
local count=0
listeners.attach(state,registers,{loaded=function() count=count+1 end},function() return true end)
listeners.attach(state,registers,{loaded=function() count=count+2 end},function() return true end)
assert(#registered==1);registered[1]();assert(count==2)
listeners.attach(state,registers,{loaded=function() error('callback error') end},function() return true end)
assert(pcall(registered[1]) and state.disabled=='callback:loaded')

-- Reentrant adapter code must not resurrect a circuit or old enrollment batch.
local reentrant,nestedCalls
reentrant=bootstrap.new({clock=clock.new(function() return tick end),traceCapacity=4,retryTicks=5})
nestedCalls=0
assert(reentrant:register(m,function()
    nestedCalls=nestedCalls+1
    if nestedCalls==1 then assert(reentrant:sample(e,candidates,read)==false)
    else error('recursive observer reached') end
end))
assert(reentrant:enroll({adapterId=m.id,key=a.key,resource=a.resource}))
reentrant:sample(e,candidates,read);assert(nestedCalls==1)
local retiring=bootstrap.new({clock=clock.new(function() return tick end),traceCapacity=4,retryTicks=5})
assert(retiring:register(m,function() retiring:invalidate('load') end))
assert(retiring:register(other,function() error('old batch continued') end))
assert(retiring:enroll({adapterId=m.id,key=a.key,resource=a.resource}))
assert(retiring:enroll({adapterId=other.id,key=a.key,resource=a.resource}))
assert(pcall(function() retiring:sample(e,candidates,read) end))
assert(retiring:inspect().circuits[other.id].errors==0 and retiring:inspect().enrolled==0)
local drifted=bootstrap.new({clock=clock.new(function() return tick end),traceCapacity=4,retryTicks=5})
local driftCalls=0;assert(drifted:register(m,function() driftCalls=driftCalls+1 end))
e.epoch='stack-2';drifted:sample(e,{},read)
e.epoch='stack-1';assert(drifted:enroll({adapterId=m.id,key=a.key,resource=a.resource}))
drifted:sample(e,candidates,read);assert(driftCalls==0)
local function ref(v) return {get=function() return v end} end
local area={m_resref=ref('BG2602'),m_lVertSort={10}}
local sprite={m_pArea=area,m_scriptName=ref('lab/mage-1'),m_resref=ref('B-XTEST1'),
    m_pos={x=10,y=20},m_curAction={m_actionID=0},m_queuedActions={m_nCount=0},m_baseStats={m_generalState=0}}
local globals={EEex_Active=true,jit={version='LuaJIT test'},
    Infinity_IsMenuOnStack=function() return true end,Infinity_GetTransitionInProgress=function() return false end,
    Infinity_GetClockTicks=function() return 12 end,EEex_Sprite_GetInPortrait=function() return sprite end,
    EEex_Utility_IterateCPtrList=function(list,fn) for _,v in ipairs(list) do fn(v) end end,
    EEex_GameObject_Get=function() return sprite end,EEex_GameObject_IsSprite=function() return true end,
    EEex_GameObject_CastUserType=function(v) return v end,EEex_BAnd=function() return 0 end}
local native=assert(eeex.new(globals,'bg273-eeex12-luajit-v1'))
local selected=native:candidates('stack-1');assert(#selected==1)
local scalar=native:read({key=a.key,resource=a.resource});assert(scalar.x==10 and not scalar.objectId)
sprite.m_pos.x=25;assert(native:read({key=a.key,resource=a.resource}).x==25)
globals.EEex_GameObject_Get=function() return sprite end;assert(not native:available())
assert(not eeex.new(globals,'unknown-layout'));globals.jit=nil
assert(not eeex.new(globals,'bg273-eeex12-luajit-v1'))
return 5
