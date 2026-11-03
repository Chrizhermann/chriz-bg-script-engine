-- Talk on sight (combat-intent/talk.lua): the first ask starts the preparation and holds the talk; the
-- talk waits at least that pass, then while the creature is busy, at most TIMEOUT ticks; done stays
-- done; with the engine off the talk goes on and nothing is kept. Plain values; no game data.
local talk=require('combat-intent.talk')
local groups=0

-- 1. The first ask starts the preparation and holds the talk; the next pass with the creature idle
-- lets it go: SCS's preparation had that one pass.
local wait,state,event=talk.step(nil,{tick=100,on=true,busy=false})
assert(wait==true and event=='start' and state.phase=='preparing' and state.since==100 and state.passes==0)
wait,state,event=talk.step(state,{tick=104,on=true,busy=false})
assert(wait==false and event=='done' and state.phase=='done' and state.passes==1 and state.since==100)
groups=groups+1

-- 2. While the creature is busy (its prebuffs queued or running) the talk waits; once idle it goes.
wait,state,event=talk.step(nil,{tick=0,on=true,busy=false})
wait,state,event=talk.step(state,{tick=5,on=true,busy=true})
assert(wait==true and event=='wait' and state.passes==1)
wait,state,event=talk.step(state,{tick=20,on=true,busy=true})
assert(wait==true and event=='wait' and state.passes==2)
wait,state,event=talk.step(state,{tick=30,on=true,busy=false})
assert(wait==false and event=='done' and state.passes==3)
groups=groups+1

-- 3. Never stuck: at TIMEOUT ticks the talk goes even while busy; a clock that went back does too.
wait,state,event=talk.step(nil,{tick=10,on=true})
wait,state,event=talk.step(state,{tick=10+talk.TIMEOUT-1,on=true,busy=true})
assert(wait==true and event=='wait')
wait,state,event=talk.step(state,{tick=10+talk.TIMEOUT,on=true,busy=true})
assert(wait==false and event=='timeout' and state.phase=='done')
wait,state,event=talk.step({phase='preparing',since=50,passes=0},{tick=40,on=true,busy=true})
assert(wait==false and event=='timeout')
groups=groups+1

-- 4. Done stays done, without an event; the engine off lets the talk go and keeps what it had (nothing
-- before the first ask); facts that are missing count as off, a bad tick as 0.
wait,state,event=talk.step({phase='done',since=1,passes=2},{tick=500,on=true,busy=true})
assert(wait==false and event==nil and state.phase=='done' and state.passes==2)
wait,state,event=talk.step(nil,{tick=100,on=false,busy=false})
assert(wait==false and state==nil and event=='off')
local kept={phase='preparing',since=1,passes=0}
wait,state,event=talk.step(kept,{tick=2,on=false})
assert(wait==false and state==kept and event=='off')
wait,state,event=talk.step(nil,nil)
assert(wait==false and event=='off')
wait,state,event=talk.step(nil,{tick=0/0,on=true})
assert(wait==true and event=='start' and state.since==0)
groups=groups+1

return groups
