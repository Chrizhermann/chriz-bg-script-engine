-- Host-sent research chunk; not an engine resource or production load handler.
-- Load once after B-XACT02 and the quiet caster settle. No new save is written.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and root.castProbe and not root.loadBoundary)
local cast=root.castProbe
assert(not cast.attempt and not cast.disabled)
local qa=assert(BGSELabTest)
assert(qa.QA:inspect().status=='complete')
local trace={phase='watch-cast',samples={},startedMs=Infinity_GetClockTicks()}
root.loadBoundary=trace
local function tick() return EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime end
local function world()
    return Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not Infinity_GetTransitionInProgress()
end
local function restored()
    assert(world() and EEex_Sprite_GetNumCharacters()==1)
    local owner=assert(EEex_Sprite_GetInPortrait(0))
    assert(EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea)
    local area=owner.m_pArea.m_resref:get()
    assert(area=='BG2600','wrong restored area')
    local fixtureCount=0
    EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
        local obj=EEex_GameObject_Get(id)
        if obj and EEex_GameObject_IsSprite(obj,false) then
            local sprite=EEex_GameObject_CastUserType(obj)
            if sprite.m_scriptName:get()=='B-XCAST0' then fixtureCount=fixtureCount+1 end
        end
    end)
    return {tick=tick(),area=area,current=owner.m_curAction.m_actionID,
        queued=owner.m_queuedActions.m_nCount,fixtureCount=fixtureCount,starts=cast.starts}
end
local function poll()
    if trace.phase=='complete' or trace.phase=='failed' then return end
    assert(Infinity_GetClockTicks()-trace.startedMs<60000,'observation deadline')
    assert(not cast.disabled,'cast observer disabled')
    if trace.phase=='watch-cast' then
        assert(world(),'world left before load request')
        local s=cast.sample()
        if s.observed.tick~=trace.lastTick then
            assert(#trace.samples<128,'sample bound')
            trace.samples[#trace.samples+1]=s.observed
            trace.lastTick=s.observed.tick
        end
        assert(s.attempt.state~='completed','missed casting window')
        if s.attempt.state=='started' and s.starts==1 and s.observed.current==31 and
            s.observed.ready==1 and s.observed.count==1 and s.observed.total==2 and
            #s.observed.effects==0 then
            trace.beforeLoad=s
            trace.phase='loading' -- latch before requesting; never retry a partial load
            qa.QA:start_load('000000973-BGSE Local Only 0928',qa.revision)
        end
    elseif trace.phase=='loading' then
        local state=qa.QA:inspect()
        assert(state.status~='failed',state.error)
        -- Do not inspect sprites while the old session is being destroyed/loaded.
        if state.status=='complete' then
            trace.afterAttempt=cast.attempt
            assert(cast.attempt.state=='invalidated' and cast.attempt.reason=='session-destroyed')
            trace.afterLoad=restored()
            assert(trace.afterLoad.fixtureCount==0 and trace.afterLoad.starts==1)
            trace.phase='post-load'
        end
    elseif trace.phase=='post-load' then
        local s=restored()
        assert(s.fixtureCount==0 and s.starts==1,'unexpected post-load continuation')
        if s.tick-trace.afterLoad.tick>=100 then
            trace.final=s; trace.phase='complete'
        end
    end
end
local originalPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    local ok,err=pcall(poll)
    if not ok then trace.error=tostring(err); trace.phase='failed' end
    return originalPoll(...)
end
trace.submission=cast.begin()
return {phase=trace.phase,submission=trace.submission}
