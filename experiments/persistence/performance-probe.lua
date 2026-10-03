-- Research telemetry only: paired minimal/observer windows, no gameplay decisions.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and not root.performanceProbe)
local directory=assert(BGSEPerformanceSource)
assert(directory:match('/experiments/persistence/$'))
local diagnostics=assert(loadfile(directory..'diagnostics.lua'))()
local timer=assert(EEex_Utility_GetMicroseconds)
local path=assert(BGSEPerformanceLog)
assert(path:match('/%.work/task10/performance%-runtime%-v%d+/frames%.tsv$'))
local prior=io.open(path,'r');if prior then prior:close();error('refuse existing trace') end
local file=assert(io.open(path,'w'))
assert(file:write('scene\tphase\tmode\tframe\tdelta_us\ttick\twork_us\tactors\tactions\thp_sum\tlua_kib\n'))
local probe={rows=0,scenes={},done=true}
root.performanceProbe=probe
local modes={'minimal','observer','observer','minimal'}
local function owner()
    assert(Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not Infinity_GetTransitionInProgress())
    assert(EEex_Sprite_GetNumCharacters()==1)
    local sprite=assert(EEex_Sprite_GetInPortrait(0))
    assert(EEex_Sprite_GetName(sprite)=='BGSE Lab Test' and sprite.m_pArea)
    assert(sprite.m_pArea.m_resref:get()=='BG2602','not private arena')
    return sprite
end
local function observe(area,record)
    local count,actions,hp=0,0,0
    EEex_Utility_IterateCPtrList(area.m_lVertSort,function(id)
        local object=EEex_GameObject_Get(id)
        if object and EEex_GameObject_IsSprite(object,true) then
            local sprite=EEex_GameObject_CastUserType(object)
            count=count+1;assert(count<=128,'fixture actor cap')
            local snapshot={hp=sprite.m_baseStats.m_hitPoints,state=EEex_Sprite_GetState(sprite),
                action=sprite.m_curAction.m_actionID,queued=sprite.m_queuedActions.m_nCount,
                x=sprite.m_pos.x,y=sprite.m_pos.y}
            if snapshot.action~=0 then actions=actions+1 end
            hp=hp+snapshot.hp
            if record then
                probe.ring:record({kind='snapshot',adapterId='research:observer',
                    tick=probe.lastTick,outcome=snapshot.action==0 and 'idle' or 'active'})
            end
            -- Snapshots and native handles are not retained across this call.
        end
    end)
    return count,actions,hp
end
local function finishPhase()
    if not probe.failed then
        local actors,actions,hp=observe(owner().m_pArea,false)
        probe.boundaries[#probe.boundaries+1]={phase=probe.phase,point='end',
            actors=actors,actions=actions,hp=hp}
    end
    for _,row in ipairs(probe.buffer) do assert(file:write(table.concat(row,'\t')..'\n')) end
    assert(file:flush())
    probe.buffer={};probe.phase=probe.phase+1
    probe.lastFrame=nil;probe.lastTime=nil;probe.lastTick=nil;probe.started=nil
    if probe.phase>4 then probe.done=true end
end
local function sample()
    local frame=Infinity_GetFrameCounter()
    if frame==probe.lastFrame then return end
    local now=timer()
    local tick=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
    local area=owner().m_pArea -- identical validation in both modes.
    if not probe.started then
        local actors,actions,hp=observe(area,false)
        probe.boundaries[#probe.boundaries+1]={phase=probe.phase,point='start',
            actors=actors,actions=actions,hp=hp}
        probe.started=now;probe.startKiB=collectgarbage('count')
    end
    local previous=probe.lastTime
    probe.lastFrame=frame;probe.lastTime=now
    local start=timer()
    local actors,actions,hp=-1,-1,-1
    if modes[probe.phase]=='observer' and tick~=probe.lastTick then
        probe.lastTick=tick;actors,actions,hp=observe(area,true)
    else probe.lastTick=tick end
    local cost=timer()-start
    assert(cost>=0 and (not previous or now>=previous),'non-monotonic timer')
    -- Two seconds warmup per window; no disk writes inside measured windows.
    if previous and now-probe.started>=2000000 then
        assert(#probe.buffer<4000 and probe.rows<64000,'bounded measurement exhausted')
        probe.rows=probe.rows+1
        local row={probe.scene,probe.phase,modes[probe.phase],frame,now-previous,tick,
            cost,actors,actions,hp,collectgarbage('count')}
        for i=1,#row do row[i]=tostring(row[i]) end
        probe.buffer[#probe.buffer+1]=row
    end
    if now-probe.started>=probe.windowUs+2000000 then finishPhase() end
end
local oldPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    oldPoll(...)
    if not probe.closed and not probe.done and not probe.failed then
        local ok,reason=pcall(sample)
        if not ok then
            probe.failed='sampling-failed';probe.privateFailure=tostring(reason):sub(1,512)
            probe.done=true
        end
    end
end
function probe.begin(scene,seconds)
    assert(not probe.closed and not probe.failed and probe.done)
    assert(type(scene)=='string' and scene:match('^[a-z][a-z0-9-]*$') and #scene<=24)
    assert(not probe.scenes[scene] and type(seconds)=='number' and seconds>=10 and seconds<=30)
    owner()
    probe.scenes[scene]=true;probe.scene=scene;probe.phase=1;probe.windowUs=seconds*1000000
    probe.buffer={};probe.boundaries={};probe.lastFrame=nil;probe.lastTime=nil;probe.lastTick=nil;probe.started=nil
    probe.ring=diagnostics.new({traceCapacity=256,errorAdapterCapacity=4,errorsPerAdapter=2,maxTextBytes=64})
    probe.done=false
end
function probe.inspect()
    return {scene=probe.scene,phase=probe.phase,done=probe.done,failed=probe.failed,
        rows=probe.rows,luaKiB=collectgarbage('count'),startKiB=probe.startKiB,
        privateFailure=probe.privateFailure,boundaries=probe.boundaries,
        ringRows=probe.ring and #probe.ring:snapshot().trace or 0}
end
function probe.close()
    assert(probe.done or probe.failed,'measurement in progress')
    if not probe.closed then
        if probe.buffer and #probe.buffer>0 then finishPhase() end
        probe.closed=true;assert(file:close())
    end
end
