-- Research-only adverse trials on the fresh private caster; no production policy.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and root.castProbe and not root.adverseProbe)
local probe={trials={}}
root.adverseProbe=probe
local trampoline=assert(loadfile('override/B-XOBS00.lua'))()
local names={'EEex_Action_AddSpriteStartedActionListener','EEex_GameState_AddDestroyedListener',
    'EEex_Action_QueueResponseStringOnAIBase','EEex_GameObject_ApplyEffect','EEex_Sprite_GetState',
    'EEex_Sprite_GetInPortrait','EEex_Sprite_GetName','EEex_Sprite_GetNumCharacters',
    'EEex_GameObject_Get','EEex_GameObject_IsSprite','EEex_GameObject_CastUserType',
    'EEex_Utility_IterateCPtrList','Infinity_IsMenuOnStack','Infinity_GetTransitionInProgress'}
local api={}
for _,name in ipairs(names) do api[name]=assert(_G[name],name) end
local function available()
    if not EEex_Active or root.castProbe.disabled then return false end
    for _,name in ipairs(names) do if type(api[name])~='function' or _G[name]~=api[name] then return false end end
    return true
end
local function fresh()
    assert(available() and not probe.disabled,'capability lost')
    assert(api.Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not api.Infinity_GetTransitionInProgress())
    assert(api.EEex_Sprite_GetNumCharacters()==1)
    local owner=assert(api.EEex_Sprite_GetInPortrait(0))
    assert(api.EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea and owner.m_pArea.m_resref:get()=='BG2602')
    local found,count=nil,0
    api.EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
        local obj=api.EEex_GameObject_Get(id)
        if obj and api.EEex_GameObject_IsSprite(obj,false) then
            local sprite=api.EEex_GameObject_CastUserType(obj)
            if sprite.m_scriptName:get()=='B-XCAST0' then found=sprite; count=count+1 end
        end
    end)
    assert(count==1 and found.m_resref:get()=='B-XMAGE0' and found.m_typeAI.m_EnemyAlly==4)
    return found -- stack-local only; never retain across callbacks/load
end
local function snapshot()
    local s=root.castProbe.sample().observed
    local sprite=fresh()
    s.activeState=api.EEex_Sprite_GetState(sprite)
    s.silenced=math.floor(s.activeState/4096)%2==1
    s.hp=sprite.m_baseStats.m_hitPoints
    return s
end
local function event(t,kind,s)
    assert(#t.events<32,'event bound')
    t.events[#t.events+1]={kind=kind,observed=s}
end
local function hasMirror(s)
    for _,effect in ipairs(s.effects) do if effect.opcode==159 then return true end end
    return false
end
local function queue(t,command,kind)
    api.EEex_Action_QueueResponseStringOnAIBase(command,fresh())
    event(t,kind,snapshot())
end
trampoline.attach(probe,{
    started=api.EEex_Action_AddSpriteStartedActionListener,
    destroyed=api.EEex_GameState_AddDestroyedListener,
},{
    started=function(sprite,action)
        local t=probe.active
        if not t or sprite.m_scriptName:get()~='B-XCAST0' or sprite.m_resref:get()~='B-XMAGE0' then return end
        local now=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
        assert(#t.starts<16,'start bound')
        t.starts[#t.starts+1]={tick=now,id=action.m_actionID,resref=action.m_string1.m_pchData:get()}
        if action.m_actionID==31 and action.m_string1.m_pchData:get()=='SPWI212' then
            t.castStart=t.castStart or now
        end
    end,
    destroyed=function()
        if probe.active then probe.active.status='invalidated-session'; probe.active=nil end
    end,
},available)
local function poll()
    local t=probe.active
    if not t then return end
    assert(available() and not probe.disabled)
    local now=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
    if now==t.lastTick then return end
    assert(now>t.lastTick,'time reversed without session invalidation')
    local s=snapshot()
    t.lastTick=now
    t.samples[#t.samples+1]=s
    if now-t.before.tick>=450 or #t.samples>=451 then
        t.status='observed-window'; probe.active=nil; return -- not action cancellation or success
    end
    if t.pendingSilence then
        if s.silenced then
            t.pendingSilence=nil
            event(t,'silence-observed-before-cast',s)
            queue(t,'SpellRES("SPWI212",Myself)','first-cast-submitted')
        elseif now-t.before.tick>=30 then
            t.status='silence-not-observed'; probe.active=nil
        end
    elseif t.kind=='aura' and not t.injected and t.castStart and s.ready==1 and s.count==1 and
        s.total==t.before.total and hasMirror(s) and
        s.current==0 and #s.queued==0 then
        t.injected=true
        if s.aura<0 then t.missed='busy-aura-window'; return end
        event(t,'before-second-cast',s)
        queue(t,'SpellRES("SPWI212",Myself)','second-cast-submitted')
    elseif (t.kind=='contention' or t.kind=='damage') and not t.injected and t.castStart and
        now-t.castStart>=3 and s.current==31 and s.ready==t.before.ready-1 and
        s.count==t.before.count-1 and s.total==t.before.total and #s.effects==0 then
        t.injected=true
        event(t,'before-intervention',s)
        if t.kind=='contention' then
            queue(t,string.format('MoveToPoint([%d.%d])',t.before.x+32,t.before.y),'move-appended')
        else
            assert(s.hp>10,'fixture HP too low')
            api.EEex_GameObject_ApplyEffect(fresh(),{effectID=12,effectAmount=1,dwFlags=0,
                targetType=1,durationType=1,effectList=1,noSave=0,immediateResolve=1})
            event(t,'damage-applied',snapshot())
        end
    end
end
local originalPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    if probe.active then
        local ok,err=pcall(poll)
        if not ok then
            probe.active.status='observer-error'; probe.active.error=tostring(err)
            probe.active=nil; probe.disabled='poll-error'
        end
    end
    return originalPoll(...)
end
function probe.begin(kind)
    assert(kind=='aura' or kind=='silence' or kind=='contention' or kind=='damage')
    assert(not probe.active and not probe.trials[kind] and not probe.disabled,'no repeat')
    local before=snapshot()
    assert(before.current==0 and #before.queued==0 and before.aura==-1 and before.ready==2 and
        before.count==2 and before.total==2 and not before.disabled and #before.effects==0 and
        before.activeState==0,'reload fresh own fixture before each trial')
    local t={kind=kind,status='observing',before=before,lastTick=before.tick,events={},starts={},samples={}}
    probe.trials[kind]=t; probe.active=t -- latch before any mutation; never retry a partial attempt
    if kind=='silence' then
        t.pendingSilence=true
        api.EEex_GameObject_ApplyEffect(fresh(),{effectID=38,targetType=1,durationType=0,
            duration=60,effectList=1,noSave=0,immediateResolve=1})
        local after=snapshot()
        event(t,'silence-applied',after)
    else
        queue(t,'SpellRES("SPWI212",Myself)','first-cast-submitted')
    end
    return {kind=kind,before=before,events=t.events,status=t.status}
end
return {ready=not probe.disabled,registrations=probe.registrations}
