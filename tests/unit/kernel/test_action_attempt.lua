-- Kernel action attempt retains the already observed reducer contract.
local attempt=assert(loadfile(...))()
local function step(record,kind,extra)
    local event={attemptId=record.attemptId,kind=kind}
    if extra then for key,value in pairs(extra) do event[key]=value end end
    return attempt.reduce(record,event)
end

-- 1. Queue acceptance and action start do not assert completion.
local proposed=attempt.new('cast-1')
assert(proposed.state=='proposed' and proposed.attemptId=='cast-1')
local accepted,why=step(proposed,'accepted')
local started=step(accepted,'started')
local advanced=step(started,'advanced')
assert(why=='applied' and accepted.state=='accepted' and started.state=='started'
    and advanced.state=='advanced')

-- 2. Completion requires declared independent proof; failure remains distinct.
for _,record in ipairs({accepted,started,advanced}) do
    assert(select(2,step(record,'completed'))=='missing-proof')
    assert(select(2,step(record,'completed',{proof='queue-return'}))=='missing-proof')
    for _,proof in ipairs({'independent-postcondition','trusted-engine-completion'}) do
        assert(step(record,'completed',{proof=proof}).state=='completed')
    end
end
local failed=step(accepted,'failed',{reason='cast-refused'})
assert(failed.state=='failed' and failed.reason=='cast-refused')

-- 3. Stale, invalid, and terminal transitions return copies without progressing.
local stale,staleWhy=attempt.reduce(accepted,{attemptId='cast-2',kind='started'})
assert(stale~=accepted and stale.state=='accepted' and staleWhy=='stale-attempt')
assert(select(2,step(proposed,'started'))=='invalid-transition')
local completed=step(started,'completed',{proof='independent-postcondition'})
local stopped,stoppedWhy=step(completed,'advanced')
assert(stopped.state=='completed' and stoppedWhy=='terminal-attempt')

-- 4. Invalidation/unknown/timeout carry reasons, never infer success.
for _,kind in ipairs({'invalidated','unknown'}) do
    local result=step(proposed,kind,{reason='fixture-'..kind})
    assert(result.state==kind and result.reason=='fixture-'..kind)
end
local timed=step(accepted,'timed-out',{reason='deadline'})
assert(timed.state=='timed-out' and timed.reason=='deadline')
assert(select(2,step(proposed,'timed-out',{reason='deadline'}))=='invalid-transition')
assert(not pcall(step,accepted,'unknown'))

-- 5. Neither input is mutated and engine handles never reach output.
local handle={}
local input={attemptId='cast-3',state='accepted',engineHandle=handle}
local event={attemptId='cast-3',kind='started',engineHandle=handle}
local result=attempt.reduce(input,event)
assert(input.state=='accepted' and input.engineHandle==handle and event.engineHandle==handle)
assert(result~=input and result.state=='started' and result.engineHandle==nil)
for key,value in pairs(result) do
    assert(key=='attemptId' or key=='state' or key=='reason')
    assert(type(value)=='string')
end
return 5
