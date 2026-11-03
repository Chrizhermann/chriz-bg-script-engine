-- Talk on sight (combat-intent/talk.lua): the first ask starts the preparation and holds the talk; the
-- next ask puts SCS's switch back; the talk waits while the creature is busy; the designer's extras
-- are queued once by the engine's own block and waited for; never more than TIMEOUT ticks; done stays
-- done; with the engine off the talk goes on and nothing is kept. Plain values; no game data.
local talk=require('combat-intent.talk')
local groups=0

-- 1. The first ask starts the preparation and holds the talk; the next pass, with the creature idle and
-- nothing added by the designer, puts the switch back and lets the talk go: SCS's preparation had that
-- one pass.
local wait,state,event,restore=talk.step(nil,{tick=100,on=true,busy=false})
assert(wait==true and event=='start' and restore==false and state.phase=='preparing' and state.since==100
    and state.passes==0)
wait,state,event,restore=talk.step(state,{tick=104,on=true,busy=false})
assert(wait==false and event=='done' and restore==true and state.phase=='done' and state.passes==1)
groups=groups+1

-- 2. While the creature is busy (its prebuffs queued or running) the talk waits; the switch goes back on
-- the first of those asks only; once idle the talk goes.
wait,state=talk.step(nil,{tick=0,on=true})
wait,state,event,restore=talk.step(state,{tick=5,on=true,busy=true})
assert(wait==true and event=='wait' and restore==true and state.passes==1)
wait,state,event,restore=talk.step(state,{tick=20,on=true,busy=true})
assert(wait==true and event=='wait' and restore==false and state.passes==2)
wait,state,event,restore=talk.step(state,{tick=30,on=true,busy=false})
assert(wait==false and event=='done' and restore==false and state.passes==3)
groups=groups+1

-- 3. The designer's extras: once SCS's preparation is over and the creature idle, the talk keeps waiting
-- and the engine's block fires once (queue); the talk waits while the extras run, then goes. The block
-- fires neither before that nor twice, nor with the engine off.
wait,state=talk.step(nil,{tick=0,on=true})
local fire,kept=talk.extras(state,{on=true})
assert(fire==false and kept==state)
wait,state,event,restore=talk.step(state,{tick=3,on=true,busy=false,extras=true})
assert(wait==true and event=='wait' and restore==true and state.phase=='extras' and state.queued==nil)
assert(talk.extras(state,{on=false})==false)
wait,state,event=talk.step(state,{tick=6,on=true,busy=false,extras=true})
assert(wait==true and event=='wait' and state.phase=='extras')
local queued
fire,queued,event=talk.extras(state,{on=true})
assert(fire==true and event=='queue' and queued.queued==true and queued.phase=='extras' and state.queued==nil)
assert(talk.extras(queued,{on=true})==false)
wait,state,event,restore=talk.step(queued,{tick=9,on=true,busy=true,extras=true})
assert(wait==true and event=='wait' and restore==false)
wait,state,event=talk.step(state,{tick=30,on=true,busy=false,extras=true})
assert(wait==false and event=='done' and state.phase=='done')
assert(talk.extras(state,{on=true})==false)
groups=groups+1

-- 4. Never stuck: at TIMEOUT ticks the talk goes even while busy or before the extras were queued; a
-- clock that went back does too.
wait,state=talk.step(nil,{tick=10,on=true})
wait,state,event=talk.step(state,{tick=10+talk.TIMEOUT-1,on=true,busy=true})
assert(wait==true and event=='wait')
wait,state,event=talk.step(state,{tick=10+talk.TIMEOUT,on=true,busy=true})
assert(wait==false and event=='timeout' and state.phase=='done')
wait,state,event,restore=talk.step({phase='extras',since=0,passes=4},{tick=talk.TIMEOUT,on=true,busy=false})
assert(wait==false and event=='timeout' and restore==false)
wait,state,event,restore=talk.step({phase='preparing',since=50,passes=0},{tick=40,on=true,busy=true})
assert(wait==false and event=='timeout' and restore==true)
groups=groups+1

-- 5. Done stays done, without an event; the engine off lets the talk go and keeps what it had (nothing
-- before the first ask); facts that are missing count as off, a bad tick as 0.
wait,state,event,restore=talk.step({phase='done',since=1,passes=2},{tick=500,on=true,busy=true})
assert(wait==false and event==nil and restore==false and state.phase=='done' and state.passes==2)
wait,state,event=talk.step(nil,{tick=100,on=false,busy=false})
assert(wait==false and state==nil and event=='off')
local had={phase='preparing',since=1,passes=0}
wait,state,event=talk.step(had,{tick=2,on=false})
assert(wait==false and state==had and event=='off')
wait,state,event=talk.step(nil,nil)
assert(wait==false and event=='off')
wait,state,event=talk.step(nil,{tick=0/0,on=true})
assert(wait==true and event=='start' and state.since==0)
assert(talk.extras(nil,{on=true})==false and talk.extras({phase='extras'},nil)==false)
groups=groups+1

return groups
