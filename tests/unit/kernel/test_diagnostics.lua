-- Seven host-only diagnostic contract scenarios; no EEex or game state.
local path = ...
local M = assert(loadfile(path))()
local function fresh(config)
    return M.new(config or {
        traceCapacity = 3, errorAdapterCapacity = 2,
        errorsPerAdapter = 2, maxTextBytes = 16,
    })
end

-- 1. Configuration is a programming contract and cannot request unbounded storage.
for _, key in ipairs({'traceCapacity','errorAdapterCapacity','errorsPerAdapter','maxTextBytes'}) do
    local config = {traceCapacity=3,errorAdapterCapacity=2,errorsPerAdapter=2,maxTextBytes=16}
    config[key] = 0
    assert(not pcall(M.new,config))
    config[key] = math.huge
    assert(not pcall(M.new,config))
    config[key] = 1.5
    assert(not pcall(M.new,config))
end
assert(not pcall(M.new,{}))
assert(not pcall(M.new,{traceCapacity=1000000,errorAdapterCapacity=2,
    errorsPerAdapter=2,maxTextBytes=16}))

-- 2. The trace is fixed-size, chronological, and contains copied whitelisted scalars.
local d = fresh()
local event = {kind='queued',adapterId='pilot.1',tick=10,unexpected={engine='handle'}}
assert(d:record(event))
event.kind='changed';event.unexpected.engine='changed'
assert(d:snapshot().trace[1].kind=='queued' and
    d:snapshot().trace[1].unexpected==nil)
assert(d:record({kind='started',tick=11}))
assert(d:record({kind='advanced',tick=12}))
assert(d:record({kind='completed',tick=13}))
local snap=d:snapshot()
assert(#snap.trace==3 and snap.trace[1].kind=='started' and
    snap.trace[2].kind=='advanced' and snap.trace[3].kind=='completed')
assert(snap.trace[1].unexpected==nil and snap.trace[3].tick==13)
snap.trace[1].kind='corrupted';table.remove(snap.trace)
assert(d:snapshot().trace[1].kind=='started' and #d:snapshot().trace==3)

-- 3. Freeform text, paths, oversized strings and unsupported values never escape.
d=fresh()
local hostile={kind='event',adapterId='C:/private/log.txt',attemptId='ok_2',
    outcome='a b',reason='0123456789abcdefg',tick=math.huge,raw='secret'}
assert(d:record(hostile))
local row=d:snapshot().trace[1]
assert(row.kind=='event' and row.adapterId=='[redacted]' and
    row.attemptId=='ok_2' and row.outcome=='[redacted]' and
    row.reason=='[redacted]' and row.tick==nil and row.raw==nil)
assert(hostile.adapterId=='C:/private/log.txt' and hostile.raw=='secret')
assert(d:record({kind='phase-1',adapterId='adapter:%2',tick=-4}))
row=d:snapshot().trace[2]
assert(row.kind=='phase-1' and row.adapterId=='[redacted]' and row.tick==-4)
assert(d:record({kind='phase-2',adapterId='adapter:part-2'}))
assert(d:snapshot().trace[3].adapterId=='adapter:part-2')
assert(d:record({kind='event',reason={secret='path'},tick=0/0}))
row=d:snapshot().trace[3]
assert(row.reason=='[redacted]' and row.tick==nil)

-- 4. Invalid input declines without throwing or changing the trace.
local before=#d:snapshot().trace
for _, bad in ipairs({'text',5,{}, {adapterId='pilot'}, {kind=false}}) do
    local ok,result,why=pcall(d.record,d,bad)
    assert(ok and result==false and why=='invalid-event')
end
assert(#d:snapshot().trace==before)

-- 5. Error counts saturate; later errors are suppressed and never add rows.
d=fresh()
assert(d:error('pilot.1','bad_state'))
assert(d:error('pilot.1','C:/secret.txt'))
local yes,why=d:error('pilot.1','third')
assert(yes==false and why=='error-limit')
snap=d:snapshot()
assert(snap.errors['pilot.1']==2 and snap.suppressedErrors==1)
assert(#snap.trace==2 and snap.trace[1].kind=='error' and
    snap.trace[2].reason=='[redacted]')
snap.errors['pilot.1']=99
assert(d:snapshot().errors['pilot.1']==2)

-- 6. The adapter table is bounded without eviction or an unbounded error row.
assert(d:error('pilot.2','bad_state'))
yes,why=d:error('pilot.3','bad_state')
assert(yes==false and why=='adapter-capacity')
snap=d:snapshot()
assert(snap.capacityRejected==1 and snap.errors['pilot.1']==2 and
    snap.errors['pilot.2']==1 and snap.errors['pilot.3']==nil and #snap.trace==3)

-- 7. Invalid adapter identifiers never become keys or leak raw text.
for _, id in ipairs({'C:/private', 'a b', 'adapter:%2', string.rep('x',17), 42}) do
    local ok,result,reason=pcall(d.error,d,id,'bad_state')
    assert(ok and result==false and reason=='invalid-adapter')
end
snap=d:snapshot()
assert(snap.errors['C:/private']==nil and #snap.trace==3 and
    snap.capacityRejected==1)
local missing=fresh()
assert(missing:error('pilot.1',nil))
assert(missing:snapshot().trace[1].reason=='[redacted]')
return 7
