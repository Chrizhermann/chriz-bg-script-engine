-- Explicitly loaded disposable-scene experiment, not an autoloading SCS adapter.
-- The policy sees scalar observations. Only the separate harness changes the world.
return function(config)
    assert(config.identity=='task24-shadow-v1' or config.identity=='task24-shadow-v2' or config.identity=='task24-shadow-v3')
    local previous=rawget(_G,'B-')
    assert(not previous or (previous.project=='chriz-bg-script-engine' and
        previous.combatShadow and previous.combatShadow.closed and not previous.combatShadow.hooks.disabled))
    local m=assert(loadfile('override/B-KCORE0.lua'))()
    assert(not m.dispatch,'shadow bundle must not export dispatch')
    local native=assert(m.eeex.new(_G,'bg273-eeex12-luajit-v1'))
    local core=m.new({clock=m.clock.new(function() return native:now() end),retryTicks=500,traceCapacity=256})
    local function clean(v) return tostring(v or ''):match('^[^%z]*'):upper() end
    -- Data-only JSONL for the existing offline replayer, not executable trace chunks.
    local arrayFields={eligibleAllies=true,actors=true,notes=true,excluded=true,eligible=true,
        bandCandidates=true,immunityTags=true,spells=true,targets=true,prebuffs=true,scores=true,terms=false,reasons=true}
    local function json(v,field,parent)
        local t=type(v)
        if t=='boolean' then return tostring(v) end
        if t=='number' then assert(v==v and v>-math.huge and v<math.huge);return string.format('%.17g',v) end
        if t=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
            return string.format('\\u%04x',c:byte()) end)..'"' end
        assert(t=='table' and not getmetatable(v))
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        if #keys==0 and (arrayFields[field] or field=='terms' and parent~='input' or field=='value' and
            (parent=='spellbook' or parent=='protections')) then return '[]' end
        if #keys>0 and type(keys[1])=='number' then
            local items={};for i=1,#keys do assert(v[i]~=nil);items[i]=json(v[i]) end
            return '['..table.concat(items,',')..']'
        end
        table.sort(keys);local items={}
        for _,k in ipairs(keys) do assert(type(k)=='string');items[#items+1]=json(k)..':'..json(v[k],k,field) end
        return '{'..table.concat(items,',')..'}'
    end
    local function freshFile(path)
        local old=io.open(path,'r');if old then old:close();error('existing experiment output') end
        return assert(io.open(path,'w'))
    end
    local events,decisions=freshFile(config.eventPath),freshFile(config.decisionPath)
    local p={phase='baseline',rows=0,decisionRows=0,decisionBytes=0,counts={},starts={},costs={},
        hooks=previous and previous.combatShadow.hooks or {},choices={}}
    _G['B-']={project='chriz-bg-script-engine',schema=1,kernel=core,combatShadow=p}
    local function emit(kind,data)
        assert(p.rows<10000,'event bound')
        assert(events:write(json({event=kind,phase=p.phase,tick=p.tick or 0,data=data or {}})..'\n'))
        events:flush();p.rows=p.rows+1
    end
    local function scan()
        assert(native:ready() and EEex_Sprite_GetNumCharacters()==1)
        local pc=assert(EEex_Sprite_GetInPortrait(0))
        assert(EEex_Sprite_GetName(pc)=='BGSE Lab Test' and clean(pc.m_pArea.m_resref:get())=='BG2602')
        local found,count={},0
        EEex_Utility_IterateCPtrList(pc.m_pArea.m_lVertSort,function(id)
            local o=EEex_GameObject_Get(id)
            if o and EEex_GameObject_IsSprite(o,true) then
                local s=EEex_GameObject_CastUserType(o);count=count+1
                local dv=clean(s.m_scriptName:get())
                local i=tonumber(dv:match('^B%-XPMAG([0-2])$'))
                if i then
                    assert(not found[i] and clean(s.m_resref:get())==dv and s.m_typeAI.m_EnemyAlly==255)
                    found[i]=s
                elseif dv=='B-XPTRG0' then
                    assert(not found.target and clean(s.m_resref:get())==dv and s.m_typeAI.m_EnemyAlly==4)
                    found.target=s
                end
            end
        end)
        assert(count==5 and found[0] and found[1] and found[2] and found.target,'unexpected scene')
        return found,pc
    end
    local function details(s)
        local d={x=s.m_pos.x,y=s.m_pos.y,hp=s.m_baseStats.m_hitPoints,action=s.m_curAction.m_actionID,
            queued=s.m_queuedActions.m_nCount,aura=EEex_Sprite_GetCastTimer(s),ready={},effects={},
            scriptPhase=EEex_Sprite_GetLocalInt(s,'B-XKPHASE'),done=EEex_Sprite_GetLocalInt(s,'B-XKDONE'),
            instantPrep=EEex_Sprite_GetLocalInt(s,'instantprep')}
        for level=0,8 do EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(level),function(mem)
            if mem.m_flags%2==1 then local r=clean(mem.m_spellId:get());d.ready[r]=(d.ready[r] or 0)+1 end
        end) end
        EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(e)
            local r=clean(e.m_sourceRes:get())
            if r=='SPWI114' or r=='SPWI212' or r=='SPWI214' or r=='SPWI224' or r=='SPWI312' then
                local key=r..':'..e.m_effectId..':'..e.m_dWFlags;d.effects[key]=(d.effects[key] or 0)+1
            end
        end)
        return d
    end
    local controllers={}
    local lastSprites -- transient inside sampleCore; cleared immediately afterward
    local function observe(id)
        local i=tonumber(id.key:match('([0-2])$'))
        assert(i==0 or i==1,'unregistered observer')
        local sprites=assert(lastSprites);local scene={}
        for j=0,2 do scene[#scene+1]={key='B-XPMAG'..j,sprite=sprites[j],relation=i==j and 'self' or 'ally'} end
        scene[#scene+1]={key='B-XPTRG0',sprite=sprites.target,relation='enemy'}
        local frame=m.inputs.sample(_G,id.key,scene,'task24/room',p.tick)
        local view=m.snapshot.new(frame)
        local function own(field) return view:get(id.key,field).value end
        local targetSeen=view:get('B-XPTRG0','lineOfSight').value==true
        local c={ownership={player=false,hardMode=false,world=false,encounter=false,forced=false,
            dialogue=not not Infinity_IsMenuOnStack('DIALOGUE'),cutscene=false,staging=false,imageOwner=false,
            alive=own('alive')==true,active=true,hostile=sprites[i].m_typeAI.m_EnemyAlly==255,
            actionIdle=own('idle')==true,auraReady=own('auraReady')==true,capable=own('canAct')==true,eligible=true},
            ownershipContext={sceneKey=frame.sceneKey,observerKey=id.key,tick=p.tick},
            spells=config.spells,targets={'B-XPTRG0'},areaChecks={},prebuffs=config.prebuffs,
            preparation={sceneKey=frame.sceneKey,observerKey=id.key,tick=p.tick,enabled=true,
                seenEnemy=targetSeen,detectedEnemy=targetSeen,nearParty=false,offscreenPrep=false,hostile=true,
                instantPrep=EEex_Sprite_GetLocalInt(sprites[i],'instantprep')~=0,
                shortDifficulty=true,longDifficulty=true,accountingReady=true}}
        -- Authored test weights are explicitly not difficulty/balance defaults.
        local legal=m.candidates.generate(view,c);local terms={}
        for _,row in ipairs(legal.eligible) do
            if row.action.kind=='shadow-preparation' then
                terms[row.id]={preparation=row.action.resource=='SPWI212' and 30 or 20}
            elseif row.action.kind=='shadow-spell' then terms[row.id]={control=10,resourceCost=1}
            else terms[row.id]={urgency=row.id=='wait' and 0 or -1} end
        end
        local result=controllers[i]:consider({frame=frame,candidates=c,terms=terms})
        p.counts[i]=(p.counts[i] or 0)+1
        if result then
            assert(not result.candidates.dispatchAuthorized)
            local line=json(result)..'\n'
            assert(p.decisionRows<1000 and p.decisionBytes+#line<=16*1024*1024,'decision bound')
            assert(decisions:write(line));decisions:flush()
            p.decisionRows=p.decisionRows+1;p.decisionBytes=p.decisionBytes+#line
            local choice=result.choice and result.choice.id or 'none';p.choices[choice]=(p.choices[choice] or 0)+1
            emit('decision',{actor=id.key,choice=choice,row=p.decisionRows})
        end
    end
    for i=0,1 do
        controllers[i]=m.controller.new(config.profile,470+i)
        assert(core:register(config.manifests[i+1],observe))
        assert(core:enroll({adapterId=config.manifests[i+1].id,key='B-XPMAG'..i,resource='B-XPMAG'..i..'.CRE'}))
    end
    local function phase(name)
        p.phase=name;p.phaseStart=p.tick;p.wallStart=Infinity_GetClockTicks();emit('phase')
    end
    local function sampleCore(sprites)
        local before={};for i=0,2 do before[i]=details(sprites[i]) end
        local us=EEex_Utility_GetMicroseconds()
        lastSprites=sprites
        local ok,reason=core:sample(config.environment,native:candidates(config.environment.epoch),function(id) return native:read(id) end)
        lastSprites=nil
        assert(ok,reason)
        local cost=EEex_Utility_GetMicroseconds()-us;p.costs[#p.costs+1]=cost
        assert(cost<150000,'shadow callback exceeded development ceiling')
        for _,circuit in pairs(core:inspect().circuits) do assert(circuit.errors==0,'shadow observer exception') end
        for i=0,2 do assert(m.manifest.equal(before[i],details(sprites[i])),'shadow changed observable actor state') end
    end
    local function idle(d) return d.action==0 and d.queued==0 and d.aura==-1 end
    local function hasEffect(d,res,op,param)
        local prefix=res..':'..op..':'
        for key in pairs(d.effects) do if key:sub(1,#prefix)==prefix and (not param or key==prefix..param) then return true end end
        return false
    end
    local function request(s,res,target)
        emit('harness-request',{actor=clean(s.m_scriptName:get()),resource=res,target=target,
            source='research harness, not Combat Intent dispatch'})
        EEex_Action_QueueResponseStringOnAIBase('SpellRES("'..res..'",'..target..')',s)
    end
    local function poll()
        if p.closed or p.failed or p.phase=='await-load' or p.phase=='complete' then return end
        assert(not p.hooks.disabled and native:ready(),'world or listener unavailable')
        local tick=EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
        if p.tick and tick-p.tick<5 then return end;p.tick=tick
        if not p.phaseStart then p.phaseStart=tick;p.wallStart=Infinity_GetClockTicks() end
        assert(Infinity_GetClockTicks()-p.wallStart<60000,'phase timeout')
        local sprites,pc=scan();local states={}
        assert(pc.m_curAction.m_actionID==0 and pc.m_queuedActions.m_nCount==0,'unplanned party action')
        emit('party-idle',{action=pc.m_curAction.m_actionID,queued=pc.m_queuedActions.m_nCount})
        for i=0,2 do states[i]=details(sprites[i]);emit('actor',{actor=i,state=states[i]}) end
        local target=details(sprites.target);emit('target',target)
        sampleCore(sprites)
        if p.phase=='baseline' and tick-p.phaseStart>=45 then
            assert(p.counts[0]>0 and p.counts[1]>0 and not p.counts[2])
            for i=0,2 do assert(idle(states[i]) and states[i].done==0 and states[i].instantPrep==0) end
            for i=0,1 do
                -- First hostile-actor boundary check: no allied-only quick-list assumption.
                assert(p.choices['prep-mirror@B-XPMAG'..i],'hostile quick-button/preparation admission missing')
            end
            p.baseline=states;p.targetBefore=target
            phase('preparation')
            request(sprites[0],'SPWI114','Myself');request(sprites[1],'SPWI212','Myself')
        elseif p.phase=='preparation' and tick-p.phaseStart>=100 and idle(states[0]) and idle(states[1]) then
            assert((states[0].ready.SPWI114 or 0)==p.baseline[0].ready.SPWI114-1 and hasEffect(states[0],'SPWI114',328,126),'Shield postcondition')
            assert((states[1].ready.SPWI212 or 0)==p.baseline[1].ready.SPWI212-1 and hasEffect(states[1],'SPWI212',159),'Mirror postcondition')
            assert((p.starts['B-XPMAG0:SPWI114'] or 0)==1 and (p.starts['B-XPMAG1:SPWI212'] or 0)==1)
            phase('remaining-preparation')
            request(sprites[0],'SPWI212','Myself');request(sprites[1],'SPWI114','Myself')
        elseif p.phase=='remaining-preparation' and tick-p.phaseStart>=100 and idle(states[0]) and idle(states[1]) then
            for i=0,1 do
                assert(hasEffect(states[i],'SPWI114',328,126) and hasEffect(states[i],'SPWI212',159))
                assert((states[i].ready.SPWI114 or 0)==p.baseline[i].ready.SPWI114-1 and (states[i].ready.SPWI212 or 0)==0)
                assert((p.starts['B-XPMAG'..i..':SPWI114'] or 0)==1 and (p.starts['B-XPMAG'..i..':SPWI212'] or 0)==1)
            end
            assert((p.choices['missile@B-XPTRG0'] or 0)>0,'missing live offensive decision after prep')
            phase('offensive-harness')
            request(sprites[0],'SPWI112','"B-XPTRG0"')
            request(sprites[1],'SPWI224','"B-XPTRG0"')
            request(sprites[2],'SPWI312','"B-XPTRG0"')
        elseif p.phase=='offensive-harness' and tick-p.phaseStart>=130 and idle(states[0]) and idle(states[1]) and idle(states[2]) then
            for i,res in ipairs({'SPWI112','SPWI224','SPWI312'}) do
                assert((p.starts['B-XPMAG'..(i-1)..':'..res] or 0)==1,'missing cast start')
                assert((states[i-1].ready[res] or 0)==0,'copy was not spent')
            end
            assert(target.hp<p.targetBefore.hp and target.hp>0,'missile health postcondition')
            emit('offensive-outcome',{beforeHP=p.targetBefore.hp,after=target,
                limitation='control-spell delivery may resist/save; no recipient model inferred'})
            phase('legacy-sentinel')
            for i=0,2 do
                EEex_Sprite_SetLocalInt(sprites[i],'B-XKCASE',i)
                EEex_Sprite_SetLocalInt(sprites[i],'B-XKPHASE',1)
            end
            emit('legacy-armed',{count=3})
        elseif p.phase=='legacy-sentinel' then
            local done=true;for i=0,2 do if not idle(states[i]) or states[i].done~=1 then done=false end end
            if done then
                for i=0,2 do
                    assert((p.starts['B-XPMAG'..i..':SPWI214'] or 0)==1 and (states[i].ready.SPWI214 or 0)==1)
                    assert(hasEffect(states[i],'SPWI214',44),'legacy effect missing')
                    local dx,dy=states[i].x-(304+i*48),states[i].y-240
                    assert(dx*dx+dy*dy<=24*24 and (states[i].x~=p.baseline[i].x or states[i].y~=p.baseline[i].y))
                end
                p.results=states;phase('await-load')
            end
        end
    end
    function p.poll()
        if p.inPoll then return end;p.inPoll=true
        local ok,err=pcall(poll);p.inPoll=false;lastSprites=nil
        if not ok then p.failed=tostring(err);emit('failed',{reason=p.failed}) end
    end
    m.listeners.attach(p.hooks,{started=EEex_Action_AddSpriteStartedActionListener,
        destroyed=EEex_GameState_AddDestroyedListener,loaded=EEex_Sprite_AddLoadedListener},{
        started=function(sprite,action)
            if p.closed then return end
            local dv=clean(sprite.m_scriptName:get())
            if dv:match('^B%-XPMAG[0-2]$') and clean(sprite.m_resref:get())==dv then
                local res=clean(action.m_string1.m_pchData:get())
                emit('start',{actor=dv,action=action.m_actionID,resource=res})
                if action.m_actionID==31 then local key=dv..':'..res;p.starts[key]=(p.starts[key] or 0)+1 end
            end
        end,
        loaded=function() end,
        destroyed=function()
            if p.closed then return end
            core:invalidate('session-destroyed');controllers={};lastSprites=nil
            p.destroyed=(p.destroyed or 0)+1;emit('destroyed')
        end,
    },function() return native:available() end)
    local originalPoll=previous and previous.combatShadow.basePoll or assert(EEexRemote.Poll)
    p.basePoll=originalPoll
    EEexRemote.Poll=function(...) p.poll();return originalPoll(...) end
    function p.inspect()
        return {phase=p.phase,failed=p.failed,rows=p.rows,decisionRows=p.decisionRows,choices=p.choices,
            counts=p.counts,starts=p.starts,destroyed=p.destroyed,kernel=core:inspect(),hooksDisabled=p.hooks.disabled}
    end
    function p.completeLoad()
        assert(p.phase=='await-load' and not p.failed and native:ready())
        assert(p.destroyed==1 and core:inspect().enrolled==0 and BGSELabTest.QA:inspect().status=='complete')
        assert(EEex_Sprite_GetName(EEex_Sprite_GetInPortrait(0))=='BGSE Lab Test')
        phase('complete');return p.inspect()
    end
    function p.close()
        assert(not p.closed);emit('closed');assert(events:close());assert(decisions:close());p.closed=true
        EEexRemote.Poll=originalPoll
        core:shutdown();return {state=p.inspect(),costs=p.costs,results=p.results}
    end
    return {ready=true,observers=2,unregistered=1,mode='shadow-only'}
end
