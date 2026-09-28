-- Research-only one-cast probe. Explicit load after the private caster has settled.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and not root.castProbe,'probe/root occupied')
local model=assert(loadfile('override/B-XACT00.lua'))()
local trampoline=assert(loadfile('override/B-XOBS00.lua'))()
local probe={events={},starts=0}
root.castProbe=probe
local spell='SPWI212'
local names={'EEex_Action_AddSpriteStartedActionListener','EEex_GameState_AddDestroyedListener',
    'EEex_Action_QueueResponseStringOnAIBase','EEex_Sprite_GetInPortrait','EEex_Sprite_GetName',
    'EEex_Sprite_GetNumCharacters','EEex_Sprite_GetCastTimer','EEex_GameObject_Get',
    'EEex_GameObject_IsSprite','EEex_GameObject_CastUserType','EEex_Utility_IterateCPtrList',
    'EEex_Utility_FreeCPtrList','Infinity_IsMenuOnStack','Infinity_GetTransitionInProgress'}
local api={}
for _,name in ipairs(names) do api[name]=assert(_G[name],name) end
local function available()
    if not EEex_Active then return false end
    for _,name in ipairs(names) do if type(api[name])~='function' or _G[name]~=api[name] then return false end end
    return true
end
local function tick() return EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime end
local function event(kind,id,resref,reason)
    if #probe.events==32 then table.remove(probe.events,1) end
    probe.events[#probe.events+1]={kind=kind,id=id,resref=resref,reason=reason,tick=tick()}
end
local function fresh()
    assert(available() and not probe.disabled,'probe unavailable')
    assert(api.Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not api.Infinity_GetTransitionInProgress(),'not world-ready')
    assert(api.EEex_Sprite_GetNumCharacters()==1,'wrong fixture party')
    local owner=assert(api.EEex_Sprite_GetInPortrait(0))
    assert(api.EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea.m_resref:get()=='BG2602','wrong room/owner')
    local found,count=nil,0
    api.EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
        local obj=api.EEex_GameObject_Get(id)
        if obj and api.EEex_GameObject_IsSprite(obj,false) then
            local sprite=api.EEex_GameObject_CastUserType(obj)
            if sprite.m_scriptName:get()=='B-XCAST0' then found=sprite; count=count+1 end
        end
    end)
    assert(count==1 and found.m_resref:get()=='B-XMAGE0' and found.m_typeAI.m_EnemyAlly==4,'wrong/ambiguous caster')
    return found -- never retained beyond the current call
end
local function snapshot(sprite)
    local count,disabled=0,false
    local buttons=sprite:GetQuickButtons(2,false)
    local ok,err=pcall(function()
        api.EEex_Utility_IterateCPtrList(buttons,function(button)
            if button.m_abilityId.m_res:get()==spell then
                count=count+button.m_count
                disabled=disabled or button.m_bDisabled==true or button.m_bDisabled==1
            end
        end)
    end)
    api.EEex_Utility_FreeCPtrList(buttons)
    assert(ok,err)
    local ready,total=0,0
    api.EEex_Utility_IterateCPtrList(sprite.m_memorizedSpellsMage:getReference(1),function(record)
        if record.m_spellId:get()==spell then
            total=total+1
            if record.m_flags%2==1 then ready=ready+1 end
        end
    end)
    local effects={}
    api.EEex_Utility_IterateCPtrList(sprite.m_timedEffectList,function(effect)
        if effect.m_sourceRes:get()==spell then
            effects[#effects+1]={opcode=effect.m_effectId,timing=effect.m_durationType}
        end
    end)
    local queued={}
    api.EEex_Utility_IterateCPtrList(sprite.m_queuedActions,function(action)
        queued[#queued+1]={id=action.m_actionID,resref=action.m_string1.m_pchData:get()}
    end)
    return {tick=tick(),count=count,ready=ready,total=total,disabled=disabled,effects=effects,queued=queued,
        current=sprite.m_curAction.m_actionID,aura=api.EEex_Sprite_GetCastTimer(sprite),
        x=sprite.m_pos.x,y=sprite.m_pos.y,state=sprite.m_baseStats.m_generalState}
end
trampoline.attach(probe,{
    started=api.EEex_Action_AddSpriteStartedActionListener,
    destroyed=api.EEex_GameState_AddDestroyedListener,
},{
    started=function(sprite,action)
        if not probe.attempt or sprite.m_scriptName:get()~='B-XCAST0' or sprite.m_resref:get()~='B-XMAGE0' then return end
        local id=action.m_actionID
        if id~=31 then event('other-action-start',id); return end
        local resref=action.m_string1.m_pchData:get()
        if resref~=spell then event('other-spell-start',id,resref); return end
        probe.starts=probe.starts+1
        local why
        probe.attempt,why=model.reduce(probe.attempt,{attemptId='cast-1',kind='started'})
        event('start-reduction',id,resref,why)
    end,
    destroyed=function()
        if probe.attempt then probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='invalidated',reason='session-destroyed'}) end
    end,
},available)
function probe.sample()
    local state=snapshot(fresh())
    if probe.attempt and probe.attempt.state=='started' then
        local mirror=false
        for _,effect in ipairs(state.effects) do if effect.opcode==159 then mirror=true end end
        if probe.starts==1 and state.tick>probe.before.tick and state.count==probe.before.count-1 and
            state.ready==probe.before.ready-1 and state.total==probe.before.total and mirror then
            probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='completed',proof='independent-postcondition'})
        elseif state.tick-probe.before.tick>450 then
            probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='timed-out',reason='postcondition-not-observed-within450ticks'})
        end
    end
    if probe.attempt and probe.attempt.state=='accepted' and state.tick-probe.before.tick>450 then
        probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='timed-out',reason='start-not-observed-within450ticks'})
    end
    return {attempt=probe.attempt,before=probe.before,observed=state,starts=probe.starts,events=probe.events,disabled=probe.disabled}
end
function probe.begin()
    assert(not probe.attempt,'one attempt only; no retry')
    local sprite=fresh()
    local before=snapshot(sprite)
    assert(before.current==0 and #before.queued==0,'caster busy; do not clear queue')
    assert(before.count==2 and before.ready==2 and before.total==2 and not before.disabled and
        before.aura==-1 and #before.effects==0 and before.state==0,'caster not baseline-ready')
    probe.before=before
    probe.attempt=model.new('cast-1')
    api.EEex_Action_QueueResponseStringOnAIBase('SpellRES("SPWI212",Myself)',sprite)
    local after=snapshot(sprite)
    local q=after.queued
    if probe.starts~=0 or #q~=1 or q[1].id~=31 or q[1].resref~=spell then
        probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='unknown',reason='unexpected-submission-order-or-queue'})
    else
        probe.attempt=model.reduce(probe.attempt,{attemptId='cast-1',kind='accepted'})
    end
    event('submission',31,spell,probe.attempt.state)
    return {attempt=probe.attempt,before=before,observed=after,starts=probe.starts}
end
return {ready=not probe.disabled,registrations=probe.registrations}
