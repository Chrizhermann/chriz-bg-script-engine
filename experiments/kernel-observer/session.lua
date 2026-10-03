-- Authored disposable-scene integration, explicitly loaded once after own fixture settles.
return function(config)
    assert(not rawget(_G,'B-'),'namespace already occupied')
    assert(config.identity=='task16-observer-v1' and type(config.logPath)=='string')
    local modules=assert(loadfile('override/B-KCORE0.lua'))()
    local native=assert(modules.eeex.new(_G,'bg273-eeex12-luajit-v1'))
    local microseconds=assert(EEex_Utility_GetMicroseconds)
    local clock=modules.clock.new(function() return native:now() end)
    local core=modules.new({clock=clock,traceCapacity=256,retryTicks=500})
    local old=io.open(config.logPath,'r');if old then old:close();error('trace already exists') end
    local file=assert(io.open(config.logPath,'w'))
    assert(file:write('event\tphase\ttick\tactor\tx\ty\taction\tqueued\tready\teffects\tscriptPhase\tdone\tdetail\n'))
    local probe={phase='baseline',phaseStart=nil,rows=0,starts={},moves={},counts={},costs={},results={},hooks={}}
    _G['B-']={project='chriz-bg-script-engine',schema=1,kernel=core,kernelBatch=probe}
    local function clean(v) return tostring(v or ''):match('^[^%z]*'):gsub('[\r\n\t]',' ') end
    local function emit(kind,index,data,detail)
        assert(probe.rows<16000,'trace bound')
        data=data or {}
        local values={kind,probe.phase,probe.tick or '',index or '',data.x or '',data.y or '',
            data.action or '',data.queued or '',data.ready or '',data.effects or '',data.scriptPhase or '',data.done or '',detail or ''}
        for i=1,#values do values[i]=clean(values[i]) end
        assert(file:write(table.concat(values,'\t')..'\n'));file:flush();probe.rows=probe.rows+1
    end
    local function scan()
        assert(native:ready() and EEex_Sprite_GetNumCharacters()==1)
        local owner=assert(EEex_Sprite_GetInPortrait(0))
        assert(EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea.m_resref:get()=='BG2602')
        local found,count={},0
        EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
            local o=EEex_GameObject_Get(id)
            if o and EEex_GameObject_IsSprite(o,true) then
                local s=EEex_GameObject_CastUserType(o);count=count+1
                local dv=clean(s.m_scriptName:get())
                local index=tonumber(dv:match('^B%-XKMAG([0-3])$'))
                if index then
                    assert(not found[index] and clean(s.m_resref:get())==dv and s.m_typeAI.m_EnemyAlly==4)
                    found[index]=s
                end
            end
        end)
        assert(count==5,'unexpected scene population')
        for i=0,3 do assert(found[i],'caster missing') end
        return found
    end
    local function details(s)
        local d={x=s.m_pos.x,y=s.m_pos.y,action=s.m_curAction.m_actionID,queued=s.m_queuedActions.m_nCount,
            ready=0,total=0,effects=0,scriptPhase=EEex_Sprite_GetLocalInt(s,'B-XKPHASE'),done=EEex_Sprite_GetLocalInt(s,'B-XKDONE')}
        EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(1),function(mem)
            if clean(mem.m_spellId:get())=='SPWI214' then
                d.total=d.total+1;if mem.m_flags%2==1 then d.ready=d.ready+1 end
            end
        end)
        EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(effect)
            if clean(effect.m_sourceRes:get())=='SPWI214' and effect.m_effectId==44 then d.effects=d.effects+1 end
        end)
        return d
    end
    local function observe(id,snapshot)
        local index=tonumber(id.key:match('([0-3])$'));assert(index and index~=1 and index~=3,'ineligible callback')
        if index==2 and probe.phase=='scripted' and not probe.faultInjected then
            probe.faultInjected=true;emit('injected-adapter-error',index);error('authored observer exception')
        end
        probe.counts[index]=(probe.counts[index] or 0)+1
        assert(snapshot.version==1 and not snapshot.objectId)
    end
    for i=0,2 do
        assert(core:register(config.manifests[i+1],observe))
        assert(core:enroll({adapterId=config.manifests[i+1].id,key='B-XKMAG'..i,resource='B-XKMAG'..i..'.CRE'}))
    end
    local function phase(name)
        probe.phase=name;probe.phaseStart=probe.tick;probe.wallStart=Infinity_GetClockTicks();emit('phase',nil,nil,name)
    end
    local function sampleCore()
        local before=microseconds()
        local candidates=native:candidates(config.environment.epoch)
        assert(core:sample(config.environment,candidates,function(id) return native:read(id) end))
        local us=microseconds()-before
        probe.costs[#probe.costs+1]={phase=probe.phase,us=us}
        emit('kernel-cost',nil,nil,us)
        local trace=core:inspect().trace
        for i=math.max(1,#trace-2),#trace do
            local row=trace[i];emit('kernel',row.actorKey,nil,row.adapterId..':'..row.reason)
        end
    end
    local function poll()
        if probe.closed or probe.failed or probe.phase=='complete' or probe.phase=='await-load' then return end
        assert(not probe.hooks.disabled,'native listener failure')
        assert(native:ready(),'world not ready')
        local tick=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
        if tick==probe.tick then return end;probe.tick=tick
        if not probe.phaseStart then probe.phaseStart=tick;probe.wallStart=Infinity_GetClockTicks() end
        assert(Infinity_GetClockTicks()-probe.wallStart<45000,'phase timeout')
        local sprites=scan();local states={}
        for i=0,3 do states[i]=details(sprites[i]);emit('actor',i,states[i]) end
        if probe.phase=='baseline' then
            local before=microseconds();native:candidates(config.environment.epoch)
            for _,i in ipairs({0,2}) do native:read({key='B-XKMAG'..i,resource='B-XKMAG'..i..'.CRE'}) end
            local us=microseconds()-before;probe.costs[#probe.costs+1]={phase='baseline',us=us}
            emit('boundary-cost',nil,nil,us)
            if tick-probe.phaseStart>=45 then
                probe.before=states
                for i=0,3 do assert(states[i].action==0 and states[i].queued==0 and states[i].ready==2 and states[i].effects==0 and states[i].done==0) end
                phase('observing')
            end
        elseif probe.phase=='observing' then
            sampleCore()
            if tick-probe.phaseStart>=45 then
                assert((probe.counts[0] or 0)>0 and (probe.counts[2] or 0)>0 and not probe.counts[1] and not probe.counts[3])
                phase('scripted')
                for i=0,3 do
                    EEex_Sprite_SetLocalInt(sprites[i],'B-XKCASE',i)
                    EEex_Sprite_SetLocalInt(sprites[i],'B-XKPHASE',1)
                end
                emit('armed',nil,nil,'four ordinary legacy scripts; not execution proof')
            end
        elseif probe.phase=='scripted' then
            sampleCore()
            local finished=true
            for i=0,3 do if states[i].done~=1 or states[i].action~=0 or states[i].queued~=0 then finished=false end end
            if finished then
                for i=0,3 do
                    local s=states[i];local dx=s.x-(304+i*48);local dy=s.y-240
                    assert(probe.starts[i]==1 and s.ready==1 and s.total==2 and s.effects>0,'ordinary cast evidence missing: '..i)
                    assert((probe.moves[i] or 0)>=1 and dx*dx+dy*dy<=24*24,'movement postcondition missing: '..i)
                    assert(s.x~=probe.before[i].x or s.y~=probe.before[i].y,'no displacement')
                    probe.results[#probe.results+1]={actor=i,castStarts=probe.starts[i],state=s}
                end
                assert(probe.faultInjected and core:inspect().circuits[config.manifests[3].id].errors==1)
                probe.countsBefore=modules.manifest.copy(probe.counts);phase('capability-loss')
                config.environment.capabilities.observe=false
            end
        elseif probe.phase=='capability-loss' then
            sampleCore()
            if tick-probe.phaseStart>=15 then
                assert(modules.manifest.equal(probe.counts,probe.countsBefore),'callback survived capability loss')
                config.environment.capabilities.observe=true;assert(core:disable(config.manifests[1].id,'batch-disabled'))
                phase('one-disabled')
            end
        elseif probe.phase=='one-disabled' then
            sampleCore()
            if tick-probe.phaseStart>=15 then
                assert(probe.counts[0]==probe.countsBefore[0] and probe.counts[2]>probe.countsBefore[2])
                probe.countsBefore=modules.manifest.copy(probe.counts)
                config.environment.epoch='changed-stack';phase('stale')
            end
        elseif probe.phase=='stale' then
            sampleCore()
            if tick-probe.phaseStart>=15 then
                config.environment.epoch='task16-scene-v1';phase('restored-old-epoch')
            end
        elseif probe.phase=='restored-old-epoch' then
            sampleCore()
            if tick-probe.phaseStart>=15 then
                assert(modules.manifest.equal(probe.counts,probe.countsBefore),'stale adapter reactivated')
                phase('await-load') -- parent loads only own baseline; no save is created
            end
        end
    end
    function probe.poll()
        if probe.inPoll then return end;probe.inPoll=true
        local ok,err=pcall(poll);probe.inPoll=false
        if not ok then probe.failed=tostring(err);emit('failed',nil,nil,err) end
    end
    modules.listeners.attach(probe.hooks,{
        started=EEex_Action_AddSpriteStartedActionListener,destroyed=EEex_GameState_AddDestroyedListener,
        loaded=EEex_Sprite_AddLoadedListener,
    },{
        started=function(sprite,action)
            if probe.phase~='scripted' then return end
            local dv=clean(sprite.m_scriptName:get());local i=tonumber(dv:match('^B%-XKMAG([0-3])$'))
            if i and clean(sprite.m_resref:get())==dv then
                local res=clean(action.m_string1.m_pchData:get())
                emit('start',i,{action=action.m_actionID},res)
                if action.m_actionID==31 and res=='SPWI214' then probe.starts[i]=(probe.starts[i] or 0)+1 end
                if action.m_actionID==23 then probe.moves[i]=(probe.moves[i] or 0)+1 end
            end
        end,
        loaded=function() probe.loaded=(probe.loaded or 0)+1 end, -- never inspect nascent userdata
        destroyed=function() core:invalidate('session-destroyed');probe.destroyed=(probe.destroyed or 0)+1;emit('destroyed') end,
    },function() return native:available() end)
    local originalPoll=assert(EEexRemote.Poll)
    EEexRemote.Poll=function(...) probe.poll();return originalPoll(...) end
    function probe.inspect()
        return {phase=probe.phase,failed=probe.failed,rows=probe.rows,results=probe.results,
            counts=probe.counts,starts=probe.starts,moves=probe.moves,destroyed=probe.destroyed,
            kernel=core:inspect(),hooksDisabled=probe.hooks.disabled}
    end
    function probe.completeLoad()
        assert(probe.phase=='await-load' and not probe.failed and native:ready())
        assert(probe.destroyed==1 and core:inspect().enrolled==0,'load failed to forget enrollment')
        assert(BGSELabTest.QA:inspect().status=='complete')
        local pc=assert(EEex_Sprite_GetInPortrait(0));assert(EEex_Sprite_GetName(pc)=='BGSE Lab Test')
        phase('complete');return probe.inspect()
    end
    function probe.close()
        assert(not probe.closed);emit('closed');assert(file:close());probe.closed=true
        core:shutdown();return {state=probe.inspect(),costs=probe.costs}
    end
    return {ready=true,identities=4,registered=3}
end
