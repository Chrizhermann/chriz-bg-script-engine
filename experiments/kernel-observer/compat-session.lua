-- Current-stack observation only. Legacy scripts own every action/public-state write.
return function(config)
    assert(config.identity=='task17-compat-v1' and not rawget(_G,'B-'))
    local modules=assert(loadfile('override/B-KCORE0.lua'))()
    local native=assert(modules.eeex.new(_G,'bg273-eeex12-luajit-v1'))
    local core=modules.new({clock=modules.clock.new(function() return native:now() end),traceCapacity=256,retryTicks=500})
    local prior=io.open(config.logPath,'r');if prior then prior:close();error('trace exists') end
    local file=assert(io.open(config.logPath,'w'))
    assert(file:write('event\tphase\ttick\tactor\taction\tready\teffects\tx\ty\tcontroller\tdetail\n'))
    local p={phase='baseline',rows=0,counts={},starts={},results={},hooks={}}
    _G['B-']={project='chriz-bg-script-engine',schema=1,kernel=core,compatBatch=p}
    local function clean(v) return tostring(v or ''):match('^[^%z]*'):gsub('[\r\n\t]',' ') end
    local function emit(event,actor,s,detail)
        assert(p.rows<16000);s=s or {}
        local row={event,p.phase,p.tick or '',actor or '',s.action or '',s.ready or '',s.effects or '',s.x or '',s.y or '',p.controller or '',detail or ''}
        for i=1,#row do row[i]=clean(row[i]) end
        assert(file:write(table.concat(row,'\t')..'\n'));file:flush();p.rows=p.rows+1
    end
    local function inspectScene()
        local pc=assert(EEex_Sprite_GetInPortrait(0))
        assert(EEex_Sprite_GetNumCharacters()==1 and EEex_Sprite_GetName(pc)=='BGSE Lab Test')
        assert(pc.m_pArea.m_resref:get()=='BG2602')
        local sprites,count,controller={},0,nil
        EEex_Utility_IterateCPtrList(pc.m_pArea.m_lVertSort,function(id)
            local o=EEex_GameObject_Get(id)
            if o and EEex_GameObject_IsSprite(o,true) then
                local s=EEex_GameObject_CastUserType(o);count=count+1
                local dv=clean(s.m_scriptName:get());local index=tonumber(dv:match('^B%-XKMAG([0-3])$'))
                if index then assert(not sprites[index] and clean(s.m_resref:get())==dv);sprites[index]=s end
                if dv=='B-XKCTR0' then assert(not controller and clean(s.m_resref:get())==dv);controller=s end
            end
        end)
        assert(count==6 and controller,'unexpected scene')
        for i=0,3 do assert(sprites[i] and sprites[i].m_typeAI.m_EnemyAlly==4) end
        return sprites,controller
    end
    local function state(s)
        local result={x=s.m_pos.x,y=s.m_pos.y,action=s.m_curAction.m_actionID,queued=s.m_queuedActions.m_nCount,
            ready=0,total=0,effects=0,done=EEex_Sprite_GetLocalInt(s,'B-XKDONE'),alt=EEex_Sprite_GetLocalInt(s,'B-XKALT0')}
        EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(1),function(mem)
            if clean(mem.m_spellId:get())=='SPWI214' then
                result.total=result.total+1;if mem.m_flags%2==1 then result.ready=result.ready+1 end
            end
        end)
        EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(effect)
            if effect.m_effectId==44 and clean(effect.m_sourceRes:get())=='SPWI214' then result.effects=result.effects+1 end
        end)
        return result
    end
    local function phase(name)
        p.phase=name;p.phaseStart=p.tick;p.wallStart=Infinity_GetClockTicks();p.counterBefore=p.controller
        p.countsBefore=modules.manifest.copy(p.counts);emit('phase',nil,nil,name)
    end
    for i=0,2 do
        assert(core:register(config.manifests[i+1],function(id,snapshot)
            local index=tonumber(id.key:match('([0-3])$'))
            if index~=0 and index~=2 then p.unexpectedCallback=true;error('ineligible callback') end
            if index==2 and p.phase=='active' and not p.injected then p.injected=true;error('authored adapter error') end
            assert(snapshot.version==1);p.counts[index]=(p.counts[index] or 0)+1
        end))
        assert(core:enroll({adapterId=config.manifests[i+1].id,key='B-XKMAG'..i,resource='B-XKMAG'..i..'.CRE'}))
    end
    local function poll()
        if p.closed or p.failed or p.phase=='await-load' or p.phase=='complete' then return end
        assert(native:ready() and not p.hooks.disabled)
        local tick=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
        if tick==p.tick then return end;p.tick=tick
        p.phaseStart=p.phaseStart or tick;p.wallStart=p.wallStart or Infinity_GetClockTicks()
        assert(Infinity_GetClockTicks()-p.wallStart<45000,'phase timeout')
        local sprites,controller=inspectScene()
        p.controller=EEex_GameState_GetGlobalInt('B-XQST00')
        local states={};for i=0,3 do states[i]=state(sprites[i]);emit('actor',i,states[i]) end
        assert(core:sample(config.environment,native:candidates(config.environment.epoch),function(id) return native:read(id) end))
        assert(not p.unexpectedCallback,'kernel invoked declined content')
        local rows=core:inspect().trace
        for i=math.max(1,#rows-2),#rows do emit('kernel',rows[i].actorKey,nil,rows[i].reason) end
        if p.phase=='baseline' and tick-p.phaseStart>=30 then
            assert(p.controller==0 and states[1].alt==1,'altered script marker missing')
            assert((p.counts[0] or 0)>0 and (p.counts[2] or 0)>0)
            assert(core:inspect().circuits[config.manifests[2].id].errors==0)
            local declined=false
            for _,row in ipairs(rows) do
                if row.actorKey=='B-XKMAG1' and row.reason=='hash-mismatch' then declined=true end
            end
            assert(declined,'changed effective CRE was not explicitly declined')
            for i=0,3 do assert(states[i].ready==2 and states[i].effects==0 and states[i].done==0) end
            p.before=states;phase('active')
            EEex_Sprite_SetLocalInt(controller,'B-XKGO00',1)
            for i=0,3 do EEex_Sprite_SetLocalInt(sprites[i],'B-XKCASE',i);EEex_Sprite_SetLocalInt(sprites[i],'B-XKPHASE',1) end
        elseif p.phase=='active' then
            local done=true;for i=0,3 do if states[i].done~=1 or states[i].action~=0 or states[i].queued~=0 then done=false end end
            if done then
                for i=0,3 do
                    local s=states[i];local dx=s.x-(304+i*48);local dy=s.y-240
                    assert(p.starts[i]==1 and s.ready==1 and s.total==2 and s.effects>0)
                    assert(dx*dx+dy*dy<=576 and (s.x~=p.before[i].x or s.y~=p.before[i].y))
                    p.results[#p.results+1]={actor=i,state=s,starts=p.starts[i]}
                end
                assert(p.controller>p.counterBefore and p.injected and core:inspect().circuits[config.manifests[3].id].errors==1)
                phase('capability-loss');config.environment.capabilities.observe=false
            end
        elseif p.phase=='capability-loss' and tick-p.phaseStart>=45 then
            assert(modules.manifest.equal(p.counts,p.countsBefore) and p.controller>p.counterBefore)
            config.environment.capabilities.observe=true;assert(core:disable(config.manifests[1].id,'batch-disabled'));phase('one-disabled')
        elseif p.phase=='one-disabled' and tick-p.phaseStart>=45 then
            assert(p.counts[0]==p.countsBefore[0] and p.counts[2]>p.countsBefore[2] and p.controller>p.counterBefore)
            phase('stale');config.environment.epoch='changed-stack'
        elseif p.phase=='stale' and tick-p.phaseStart>=45 then
            assert(modules.manifest.equal(p.counts,p.countsBefore) and p.controller>p.counterBefore)
            phase('restored-old-epoch');config.environment.epoch='task16-scene-v1'
        elseif p.phase=='restored-old-epoch' and tick-p.phaseStart>=45 then
            assert(modules.manifest.equal(p.counts,p.countsBefore) and p.controller>p.counterBefore)
            phase('await-load')
        end
    end
    modules.listeners.attach(p.hooks,{started=EEex_Action_AddSpriteStartedActionListener,destroyed=EEex_GameState_AddDestroyedListener},{
        started=function(s,a)
            if p.phase~='active' then return end
            local dv=clean(s.m_scriptName:get());local index=tonumber(dv:match('^B%-XKMAG([0-3])$'))
            if index and clean(s.m_resref:get())==dv then
                local res=clean(a.m_string1.m_pchData:get());emit('start',index,{action=a.m_actionID},res)
                if a.m_actionID==31 and res=='SPWI214' then p.starts[index]=(p.starts[index] or 0)+1 end
            end
        end,
        destroyed=function() core:invalidate('session-destroyed');p.destroyed=(p.destroyed or 0)+1;emit('destroyed') end,
    },function() return native:available() end)
    local previous=EEexRemote.Poll
    EEexRemote.Poll=function(...)
        if not p.inPoll then p.inPoll=true;local ok,err=pcall(poll);p.inPoll=false
            if not ok then p.failed=tostring(err);emit('failed',nil,nil,err) end
        end
        return previous(...)
    end
    function p.inspect()
        return {phase=p.phase,failed=p.failed,rows=p.rows,controller=p.controller,results=p.results,
            counts={actor0=p.counts[0] or 0,actor1=p.counts[1] or 0,actor2=p.counts[2] or 0,actor3=p.counts[3] or 0},
            destroyed=p.destroyed,kernel=core:inspect()}
    end
    function p.close()
        assert(p.phase=='await-load' and not p.failed and p.destroyed==1 and core:inspect().enrolled==0)
        assert(BGSELabTest.QA:inspect().status=='complete' and native:ready())
        assert(EEex_Sprite_GetName(EEex_Sprite_GetInPortrait(0))=='BGSE Lab Test')
        assert(EEex_GameState_GetGlobalInt('B-XQST00')==0,'own baseline did not reset controller')
        phase('complete');emit('closed');assert(file:close());p.closed=true;core:shutdown();return p.inspect()
    end
    return {ready=true,casters=4,unknownControllers=1}
end
