-- Research-only, host-sent once. Reuse one hidden process and reset own fixture
-- between sequences. No production ownership policy, retries or queue clearing.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and not root.sessionBatch)
local logPath=assert(BGSEBatchLog)
assert(type(logPath)=='string' and logPath:match('/%.work/task9/integrated%-runtime%-v%d+/events%.tsv$'))
local existing=io.open(logPath,'r')
if existing then existing:close();error('refuse existing trace') end
local file=assert(io.open(logPath,'w'))
local batch={cases={},epoch=0,rows=0}
root.sessionBatch=batch
local qa=assert(BGSELabTest)
local getLocal=assert(EEex_Sprite_GetLocalInt)
local setLocal=assert(EEex_Sprite_SetLocalInt)
local queue=assert(EEex_Action_QueueResponseStringOnAIBase)
local getStat=assert(EEex_Sprite_GetStat)
local function tick() return EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime end
local function clean(v) return tostring(v==nil and '' or v):gsub('[\r\n\t]',' ') end
local columns={'event','case','phase','epoch','tick','actor','resref','area','x','y',
    'current','queue','ready','total','aura','hp','state','effects','legacy',
    'cloneType','ownerType','parentMatch','detail'}
assert(file:write(table.concat(columns,'\t')..'\n'));file:flush()
local function row(event,s,detail)
    if batch.closed then return end
    assert(batch.rows<12000,'trace bound')
    local t=batch.active or {}
    local values={event,t.kind or '',t.phase or '',batch.epoch,(s and s.tick) or batch.lastTick or ''}
    for i=6,22 do values[i]=s and s[columns[i]] or '' end
    values[23]=detail or ''
    for i=1,23 do values[i]=clean(values[i]) end
    assert(file:write(table.concat(values,'\t')..'\n'));assert(file:flush())
    batch.rows=batch.rows+1
end
local function world()
    return Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not Infinity_GetTransitionInProgress()
end
local function copied(s) return s.m_bInCopy==true or s.m_bInCopy==1 end
local function scan()
    assert(world() and EEex_Sprite_GetNumCharacters()==1,'wrong world/party')
    local owner=assert(EEex_Sprite_GetInPortrait(0))
    assert(EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea,'wrong protagonist')
    local area=owner.m_pArea.m_resref:get()
    local caster,target,clones,candidates=nil,nil,{},{}
    if area=='BG2602' then
        EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
            local obj=EEex_GameObject_Get(id)
            if obj and EEex_GameObject_IsSprite(obj,true) then
                local s=EEex_GameObject_CastUserType(obj)
                if copied(s) then clones[#clones+1]=s
                elseif s.m_scriptName:get()=='B-XCAST2' then candidates[#candidates+1]=s
                elseif s.m_scriptName:get()=='B-XTARG0' then assert(not target);target=s end
            end
        end)
    end
    local pending=#candidates>1 and batch.active and batch.active.phase=='creating-image'
    if #candidates>1 then assert(pending,'ambiguous caster outside clone setup') end
    if #candidates==1 then caster=candidates[1] end
    -- A nascent clone can briefly copy the DV before its copy flag/parent settles.
    -- Do not pick either candidate or claim exclusion until identity is unambiguous.
    return owner,area,caster,target,clones,pending
end
local function identity(s,dv,resref,marker)
    assert(s and s.m_scriptName:get()==dv and s.m_typeAI.m_EnemyAlly==4,'fixture identity')
    local r=s.m_resref:get()
    local restored=batch.active and batch.active.allowSavedIdentity
    assert(r==resref or (restored and r:sub(1,1)=='*' and getLocal(s,'B-XIDENT')==marker),
        'fixture resource/restore marker')
end
local function actor(s,area,relation)
    local r={tick=tick(),actor=s.m_scriptName:get(),resref=s.m_resref:get(),area=area,
        x=s.m_pos.x,y=s.m_pos.y,current=s.m_curAction.m_actionID,hp=s.m_baseStats.m_hitPoints,
        state=EEex_Sprite_GetState(s),ready=0,total=0,aura=EEex_Sprite_GetCastTimer(s),
        legacy=getLocal(s,'B-XLEGACY'),cloneType=getStat(s,139),ownerType=getStat(s,140),
        parentMatch=relation and 1 or 0}
    local actions,effects={},{}
    EEex_Utility_IterateCPtrList(s.m_queuedActions,function(a)
        actions[#actions+1]=table.concat({a.m_actionID,a.m_string1.m_pchData:get(),a.m_dest.x,a.m_dest.y},':')
    end)
    EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(e)
        local source=e.m_sourceRes:get()
        if source=='SPWI214' or source=='SPWI703' then
            effects[#effects+1]=source..':'..e.m_effectId..':'..e.m_durationType
        end
    end)
    EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(1),function(m)
        if m.m_spellId:get()=='SPWI214' then
            r.total=r.total+1;if m.m_flags%2==1 then r.ready=r.ready+1 end
        end
    end)
    r.queue=table.concat(actions,'|');r.effects=table.concat(effects,'|')
    return r
end
local function snapshot()
    local owner,area,caster,target,clones,pending=scan()
    local result={tick=tick(),area=area,clones={}}
    row('sample',actor(owner,area))
    if pending then
        result.pending=true;row('identity-pending',nil,'unsettled duplicate during PI setup');return result
    end
    if area=='BG2602' then
        identity(caster,'B-XCAST2','B-XMAGE2',93301)
        identity(target,'B-XTARG0','B-XTARG0',93302)
        result.caster=actor(caster,area);result.target=actor(target,area)
        row('sample',result.caster);row('sample',result.target)
        for _,clone in ipairs(clones) do
            local c=actor(clone,area,clone.m_nCopyParent==caster.m_id)
            result.clones[#result.clones+1]=c;row('sample',c)
        end
    end
    return result
end
local function phase(name)
    batch.active.phase=name;row('phase',nil,name)
end
local function complete(note)
    local t=batch.active;t.status='observed';t.note=note
    row('case-end',nil,note);batch.active=nil
end
local function cast()
    local _,area,caster=scan();assert(area=='BG2602')
    queue('SpellRES("SPWI214","B-XTARG0")',caster)
    local observed=actor(caster,area)
    row('cast-submitted',observed,'ordinary SpellRES; not completion')
    assert(batch.active.castStarts==0 and observed.queue:match('^31:SPWI214:') and
        not observed.queue:find('|',1,true),'unexpected cast submission')
end
local trampoline=assert(loadfile('override/B-XOBS00.lua'))()
trampoline.attach(batch,{
    started=EEex_Action_AddSpriteStartedActionListener,
    destroyed=EEex_GameState_AddDestroyedListener,
},{
    started=function(s,a)
        if not batch.active then return end
        local dv=s.m_scriptName:get()
        if dv=='B-XCAST2' or dv=='B-XTARG0' or dv=='COPY' then
            row('start',{tick=tick(),actor=dv,current=a.m_actionID,resref=s.m_resref:get()},
                a.m_string1.m_pchData:get())
            if dv=='B-XCAST2' and a.m_actionID==31 and a.m_string1.m_pchData:get()=='SPWI214' then
                batch.active.castStarts=(batch.active.castStarts or 0)+1
            end
        end
    end,
    destroyed=function()
        batch.epoch=batch.epoch+1
        row('session-destroyed',nil,'invalidate old action attempt; no handles retained')
    end,
},function() return EEex_Active and EEex_Action_QueueResponseStringOnAIBase==queue end)
local function windup(t,s)
    return t.castStarts==1 and s.caster.current==31 and s.caster.ready==1 and
        s.caster.total==2 and s.target.effects==''
end
local function poll()
    local t=batch.active;if not t then return end
    assert(not batch.disabled,'listener disabled')
    local wall=Infinity_GetClockTicks()
    if t.phase=='saved-await-host-load' then
        assert(wall-t.hostWaitMs<60000,'host verification deadline; not an engine failure')
    else assert(wall-(t.resumedMs or t.startedMs)<150000,'case observation deadline') end
    local q=qa.QA:inspect()
    if t.phase=='saving' or t.phase=='loading' then
        if q.status~=t.lastQA then row('qa',nil,q.status..':'..tostring(q.step));t.lastQA=q.status end
        assert(q.status~='failed',q.error)
        if q.status~='complete' or not world() then return end
        if t.phase=='saving' then
            t.hostWaitMs=wall
            phase('saved-await-host-load')
            t.afterSave=snapshot();return
        else
            t.restored=true;t.allowSavedIdentity=true;phase('post-load');t.postLoad=tick();t.lastTick=nil
            t.afterLoad=snapshot();return
        end
    end
    if not world() then return end
    local now=tick();if now==t.lastTick then return end
    t.lastTick=now;batch.lastTick=now
    local s=snapshot()
    if s.pending then return end
    if t.kind=='legacy' then
        if t.phase=='casting' and windup(t,s) then
            local _,_,caster=scan();setLocal(caster,'B-XLEGACY',1)
            t.armed=now;phase('legacy-observing')
        end
        if now-t.before.tick>=300 then complete('compare script marker, starts, position and effects; cutoff only') end
    elseif t.kind=='lifecycle' then
        if t.phase=='casting' and windup(t,s) then
            phase('leaving-area');t.leftRequest=now
            C:MoveToArea('BG2600')
        elseif t.phase=='leaving-area' and s.area=='BG2600' then
            t.away=now;t.allowSavedIdentity=true
            row('area-invalidated',nil,'old caster outside current observation scope')
            phase('away')
        elseif t.phase=='away' and now-t.away>=45 then
            phase('returning');C:MoveToArea('BG2602')
        elseif t.phase=='returning' and s.area=='BG2602' then
            t.returned=s;phase('settle-before-save')
        elseif t.phase=='settle-before-save' and s.caster.current==0 and s.caster.queue=='' then
            local _,_,caster,target=scan()
            setLocal(caster,'B-XIDENT',93301);setLocal(target,'B-XIDENT',93302)
            -- Ordinary multi-action chain creates a reproducible in-flight save window.
            queue('Wait(20)\nMoveToPoint([232.264])',caster)
            phase('waiting-to-save')
        elseif t.phase=='waiting-to-save' and s.caster.current==63 and s.caster.queue~='' then
            t.beforeSave=s;phase('saving');qa.QA:start_save('BGSE Batch Flight 0930',qa.revision)
        elseif t.phase=='post-load' and now-t.postLoad>=360 then
            t.final=s;complete('compare restored wait/movement chain; no automatic new submission')
        end
    elseif t.kind=='image' then
        local matching={}
        for _,c in ipairs(s.clones) do if c.cloneType==2 and c.parentMatch==1 and
            bit.band(c.state,0xFC0)==0 then matching[#matching+1]=c end end
        if t.phase=='creating-image' and #matching==1 and s.caster.ownerType==2 then
            assert(s.caster.queue=='','owner already has queued work')
            t.excluded=now;t.exclusion=s;phase('owner-excluded')
            row('request-declined',s.caster,'Project Image owner; no ordinary action submitted')
        elseif t.phase=='owner-excluded' and now-t.excluded>=30 then
            assert(#matching==1,'image condition changed before cleanup')
            local _,area,caster,_,clones=scan()
            local selected
            for _,c in ipairs(clones) do
                if getStat(c,139)==2 and c.m_nCopyParent==caster.m_id then assert(not selected);selected=c end
            end
            assert(selected and selected.m_curAction.m_actionID==0 and selected.m_queuedActions.m_nCount==0)
            phase('removing-image');queue('Kill(Myself)',selected)
            row('clone-kill-submitted',actor(selected,area,true),'fixture cleanup, not proof')
        elseif t.phase=='removing-image' and #matching==0 and s.caster.ownerType~=2 and
            s.caster.current==0 and s.caster.queue=='' and s.caster.aura==-1 then
            t.released=now;phase('released-casting');cast()
        elseif t.phase=='released-casting' and now-t.released>=150 then
            t.final=s;complete('compare refusal and later ordinary debit/delivery; no queued locked-owner experiment')
        end
    end
end
local oldPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    if batch.active then
        local ok,err=pcall(poll)
        if not ok then
            batch.active.status='failed';batch.active.error=tostring(err)
            row('case-error',nil,err);batch.active=nil;batch.failed=tostring(err)
        end
    end
    return oldPoll(...)
end
function batch.begin(kind)
    assert(kind=='legacy' or kind=='lifecycle' or kind=='image')
    assert(not batch.active and not batch.cases[kind] and not batch.failed and not batch.disabled,'no repeat')
    assert(qa.QA:inspect().status=='complete')
    local t={kind=kind,phase='preflight',status='running',startedMs=Infinity_GetClockTicks(),castStarts=0}
    batch.cases[kind]=t;batch.active=t
    local ok,err=pcall(function()
        local s=snapshot();t.before=s
        assert(s.area=='BG2602' and #s.clones==0)
        for _,a in ipairs({s.caster,s.target}) do
            assert(a.current==0 and a.queue=='' and a.hp>0 and a.state==0 and a.effects=='','fresh idle pair')
        end
        assert(s.caster.ready==2 and s.caster.total==2 and s.caster.aura==-1 and s.caster.legacy==0)
        local _,_,caster,target=scan()
        setLocal(caster,'B-XIDENT',93301);setLocal(target,'B-XIDENT',93302)
        if kind=='image' then
            phase('creating-image')
            queue('ReallyForceSpellRES("SPWI703",Myself)',caster)
            row('image-setup-submitted',nil,'forced condition setup only; no fair PI-cast claim')
        else phase('casting');cast() end
    end)
    if not ok then t.status='failed';t.error=tostring(err);row('case-error',nil,err);batch.active=nil;batch.failed=tostring(err);error(err) end
    return {kind=kind,phase=t.phase,rows=batch.rows}
end
function batch.loadSaved(folder)
    local t=assert(batch.active);assert(t.kind=='lifecycle' and t.phase=='saved-await-host-load')
    assert(folder:match('^%d%d%d%d%d%d%d%d%d%-BGSE Batch Flight 0930$'))
    phase('loading');t.savedFolder=folder;t.lastQA=nil;t.resumedMs=Infinity_GetClockTicks()
    qa.QA:start_load(folder,qa.revision)
end
function batch.inspect()
    local t=batch.active
    return {active=t and t.kind,phase=t and t.phase,failed=batch.failed,disabled=batch.disabled,
        epoch=batch.epoch,rows=batch.rows,cases=batch.cases}
end
function batch.close()
    assert(not batch.active);batch.closed=true;assert(file:close());return {closed=true,rows=batch.rows}
end
return {ready=true,registrations=batch.registrations}
