-- Host-sent research chunk, not a production adapter. Never autoload.
-- Three single trials, each after own baseline reset and fresh synthetic pair.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and not root.targetProbe)
local probe={trials={}}
local spell='SPWI214'
local names={'EEex_Action_AddSpriteStartedActionListener','EEex_GameState_AddDestroyedListener',
    'EEex_Action_QueueResponseStringOnAIBase','EEex_Sprite_GetState','EEex_Sprite_GetCastTimer',
    'EEex_Sprite_GetInPortrait','EEex_Sprite_GetName','EEex_Sprite_GetNumCharacters',
    'EEex_GameObject_Get','EEex_GameObject_IsSprite','EEex_GameObject_CastUserType',
    'EEex_Utility_IterateCPtrList','Infinity_IsMenuOnStack','Infinity_GetTransitionInProgress'}
local api={}
for _,name in ipairs(names) do api[name]=assert(_G[name],name) end
local band=assert(bit and bit.band)
local function available()
    if not EEex_Active then return false end
    for _,name in ipairs(names) do if _G[name]~=api[name] then return false end end
    return true
end
local function tick() return EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime end
local function fresh()
    assert(available() and not probe.disabled,'probe unavailable')
    assert(api.Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not api.Infinity_GetTransitionInProgress())
    assert(api.EEex_Sprite_GetNumCharacters()==1)
    local owner=assert(api.EEex_Sprite_GetInPortrait(0))
    assert(api.EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea and
        owner.m_pArea.m_resref:get()=='BG2602','wrong test room/owner')
    local caster,target,casters,targets=nil,nil,0,0
    api.EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
        local obj=api.EEex_GameObject_Get(id)
        -- Corpses must remain observable; absence alone is not proof of death.
        if obj and api.EEex_GameObject_IsSprite(obj,true) then
            local s=api.EEex_GameObject_CastUserType(obj)
            local dv=s.m_scriptName:get()
            if dv=='B-XCAST1' then caster=s;casters=casters+1 end
            if dv=='B-XTARG0' then target=s;targets=targets+1 end
        end
    end)
    assert(casters==1 and caster.m_resref:get()=='B-XMAGE1' and caster.m_typeAI.m_EnemyAlly==4)
    assert(targets<=1,'ambiguous target')
    if target then assert(target.m_resref:get()=='B-XTARG0' and target.m_typeAI.m_EnemyAlly==4) end
    return caster,target -- stack-local only; never stored between callbacks
end
local function actor(s)
    if not s then return {present=false} end
    local state=api.EEex_Sprite_GetState(s)
    local baseState=s.m_baseStats.m_generalState
    local effects,queue={},{}
    api.EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(e)
        if e.m_sourceRes:get()==spell then effects[#effects+1]={opcode=e.m_effectId,timing=e.m_durationType} end
    end)
    api.EEex_Utility_IterateCPtrList(s.m_queuedActions,function(a)
        queue[#queue+1]={id=a.m_actionID,resref=a.m_string1.m_pchData:get(),x=a.m_dest.x,y=a.m_dest.y}
    end)
    return {present=true,hp=s.m_baseStats.m_hitPoints,state=state,baseState=baseState,
        dead=band(state,0xFC0)~=0 or band(baseState,0xFC0)~=0,
        current=s.m_curAction.m_actionID,queued=queue,x=s.m_pos.x,y=s.m_pos.y,effects=effects}
end
local function snapshot()
    local caster,target=fresh()
    local c=actor(caster)
    c.ready=0;c.total=0;c.aura=api.EEex_Sprite_GetCastTimer(caster)
    api.EEex_Utility_IterateCPtrList(caster.m_memorizedSpellsMage:getReference(1),function(record)
        if record.m_spellId:get()==spell then
            c.total=c.total+1
            if record.m_flags%2==1 then c.ready=c.ready+1 end
        end
    end)
    return {tick=tick(),caster=c,target=actor(target)}
end
local trampoline=assert(loadfile('override/B-XOBS00.lua'))()
trampoline.attach(probe,{
    started=api.EEex_Action_AddSpriteStartedActionListener,
    destroyed=api.EEex_GameState_AddDestroyedListener,
},{
    started=function(s,a)
        local t=probe.active
        if not t then return end
        local dv,res=s.m_scriptName:get(),s.m_resref:get()
        if not ((dv=='B-XCAST1' and res=='B-XMAGE1') or (dv=='B-XTARG0' and res=='B-XTARG0')) then return end
        assert(#t.starts<32,'start bound')
        local entry={tick=tick(),actor=dv,id=a.m_actionID,resref=a.m_string1.m_pchData:get()}
        t.starts[#t.starts+1]=entry
        if dv=='B-XCAST1' and entry.id==31 and entry.resref==spell then
            t.castStarts=t.castStarts+1;t.castStart=t.castStart or entry.tick
        end
    end,
    destroyed=function()
        if probe.active then probe.active.status='invalidated-session';probe.active=nil end
    end,
},available)
root.targetProbe=probe
local function poll()
    local t=probe.active
    if not t or not t.accepted then return end
    assert(Infinity_GetClockTicks()-t.startedMs<60000,'wall-clock deadline')
    local now=tick()
    if now==t.lastTick then return end
    assert(now>t.lastTick,'time reversed without invalidation')
    local s=snapshot()
    t.lastTick=now;t.samples[#t.samples+1]=s
    if s.target.present and s.target.dead then t.firstDeadTick=t.firstDeadTick or now end
    if now-t.before.tick>=450 or #t.samples>=451 then
        t.status='observed-window';probe.active=nil;return -- cutoff is not success or cancellation
    end
    if t.kind~='baseline' and not t.intervention and t.castStarts==1 and
        s.caster.current==31 and s.caster.ready==1 and s.caster.total==2 and
        s.target.present and not s.target.dead and #s.target.effects==0 then
        assert(s.target.current==0 and #s.target.queued==0,'target busy')
        local _,target=fresh()
        t.intervention={before=s} -- latch before submitting, never retry partial work
        local command=t.kind=='death' and 'Kill(Myself)' or 'MoveToPoint([232.264])'
        api.EEex_Action_QueueResponseStringOnAIBase(command,assert(target))
        t.intervention.command=command;t.intervention.after=snapshot()
        local q=t.intervention.after.target.queued
        assert(#q==1 and q[1].id==(t.kind=='death' and 131 or 23),'unexpected intervention queue')
        if t.kind=='movement' then assert(q[1].x==232 and q[1].y==264) end
    end
end
local oldPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    if probe.active then
        local active=probe.active
        local ok,err=pcall(poll)
        if not ok then
            active.status='observer-error';active.error=tostring(err)
            probe.active=nil;probe.disabled='poll-error'
        end
    end
    return oldPoll(...)
end
function probe.begin(kind)
    assert(kind=='baseline' or kind=='movement' or kind=='death')
    assert(not probe.active and not probe.trials[kind] and not probe.disabled,'no repeat')
    local s=snapshot()
    for _,a in ipairs({s.caster,s.target}) do
        assert(a.present and not a.dead and a.hp>0 and a.current==0 and #a.queued==0 and #a.effects==0,'fresh idle pair required')
    end
    assert(s.caster.ready==2 and s.caster.total==2 and s.caster.aura==-1)
    if kind=='movement' then assert(math.abs(s.target.y-264)>12,'target already at movement goal') end
    local t={kind=kind,status='submitting',before=s,lastTick=s.tick,startedMs=Infinity_GetClockTicks(),
        castStarts=0,starts={},samples={}}
    probe.trials[kind]=t;probe.active=t
    local ok,err=pcall(function()
        local caster=fresh()
        api.EEex_Action_QueueResponseStringOnAIBase('SpellRES("SPWI214","B-XTARG0")',caster)
        t.submission=snapshot()
        local q=t.submission.caster.queued
        assert(t.castStarts==0 and #q==1 and q[1].id==31 and q[1].resref==spell,'unexpected cast queue')
    end)
    if not ok then
        t.status='submission-error';t.error=tostring(err)
        probe.active=nil;probe.disabled='submission-error'
        error(err) -- trial remains latched; poll cannot intervene or retry
    end
    t.accepted=true;t.status='observing'
    return {kind=kind,status=t.status,before=s,submission=t.submission}
end
return {ready=not probe.disabled,registrations=probe.registrations}
