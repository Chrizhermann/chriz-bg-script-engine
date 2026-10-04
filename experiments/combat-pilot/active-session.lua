-- Explicit disposable-scene runner. Not an autoloading or general SCS adapter.
-- Only the default-off product dispatch path queues the selected attack spell.
return function(config)
    local previous=rawget(_G,'B-')
    assert(config.identity=='task25-active-v1' and (not previous or previous.project=='chriz-bg-script-engine' and
        previous.combatActive and previous.combatActive.closed and not previous.combatActive.hooks.disabled))
    local m=assert(loadfile('override/B-KCORE0.lua'))()
    local native=assert(m.eeex.new(_G,'bg273-eeex12-luajit-v1'))
    local function clean(v) return tostring(v or ''):match('^[^%z]*'):upper() end
    local function now() return EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime end
    local arrayFields={eligibleAllies=true,actors=true,notes=true,excluded=true,eligible=true,
        bandCandidates=true,immunityTags=true,spells=true,targets=true,prebuffs=true,scores=true,reasons=true}
    local function json(v,field,parent)
        local t=type(v)
        if t=='boolean' then return tostring(v) end
        if t=='number' then assert(v==v and v>-math.huge and v<math.huge);return string.format('%.17g',v) end
        if t=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c) return string.format('\\u%04x',c:byte()) end)..'"' end
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
    local old=io.open(config.eventPath,'r');if old then old:close();error('existing output') end
    local output=assert(io.open(config.eventPath,'w'))
    local p={phase='idle',rows=0,hooks=previous and previous.combatActive.hooks or {},session=0,cases={},costs={}}
    _G['B-']={project='chriz-bg-script-engine',schema=1,combatActive=p}
    local core,dispatch,attempts,proposals,identities={},{},{},{},{}
    local function emit(event,data)
        assert(p.rows<12000,'event bound')
        assert(output:write(json({event=event,case=p.case or 'none',phase=p.phase,tick=now(),data=data or {}})..'\n'))
        output:flush();p.rows=p.rows+1
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
                local dv=clean(s.m_scriptName:get());local i=tonumber(dv:match('^B%-XPMAG([0-2])$'))
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
        assert(p.expectedPartyAction or pc.m_curAction.m_actionID==0 and pc.m_queuedActions.m_nCount==0,'unplanned party action')
        return found,pc
    end
    local function details(s)
        local d={x=s.m_pos.x,y=s.m_pos.y,hp=s.m_baseStats.m_hitPoints,action=s.m_curAction.m_actionID,
            queued=s.m_queuedActions.m_nCount,aura=EEex_Sprite_GetCastTimer(s),ready={},strength=false,
            scriptPhase=EEex_Sprite_GetLocalInt(s,'B-XKPHASE'),done=EEex_Sprite_GetLocalInt(s,'B-XKDONE')}
        for level=0,8 do EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(level),function(mem)
            if mem.m_flags%2==1 then local r=clean(mem.m_spellId:get());d.ready[r]=(d.ready[r] or 0)+1 end
        end) end
        EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(e)
            if clean(e.m_sourceRes:get())=='SPWI214' and e.m_effectId==44 then d.strength=true end
        end)
        return d
    end
    local function idle(d) return d.action==0 and d.queued==0 and d.aura==-1 end
    local function sample(id,sprites)
        local i=assert(tonumber(id.key:match('([01])$')));local scene={}
        for j=0,2 do scene[#scene+1]={key='B-XPMAG'..j,sprite=sprites[j],relation=i==j and 'self' or 'ally'} end
        scene[#scene+1]={key='B-XPTRG0',sprite=sprites.target,relation='enemy'}
        local tick=now();local frame=m.inputs.sample(_G,id.key,scene,'task25/room/'..p.session,tick)
        local view=m.snapshot.new(frame)
        local function own(field) return view:get(id.key,field).value end
        local ownership={player=false,hardMode=false,world=false,
            encounter=EEex_Sprite_GetLocalInt(sprites[i],'B-XKPHASE')~=0,forced=false,
            dialogue=not not Infinity_IsMenuOnStack('DIALOGUE'),cutscene=false,staging=false,
            imageOwner=EEex_Sprite_GetStat(sprites[i],139)==2,alive=own('alive')==true,active=true,
            hostile=sprites[i].m_typeAI.m_EnemyAlly==255,actionIdle=own('idle')==true,
            auraReady=own('auraReady')==true,capable=own('canAct')==true,eligible=true}
        -- Combat phase only: preparation/helper dispatch remains outside this gate.
        local candidates={ownership=ownership,ownershipContext={sceneKey=frame.sceneKey,observerKey=id.key,tick=tick},
            spells=config.spells,targets={'B-XPTRG0'},areaChecks={}}
        local legal=m.candidates.generate(view,candidates);local terms={}
        for _,row in ipairs(legal.eligible) do
            terms[row.id]=row.action.kind=='shadow-spell' and {control=10,resourceCost=1} or {urgency=row.id=='wait' and 0 or -1}
        end
        local decision=m.decision.evaluate({frame=frame,candidates=candidates,profile=config.profile,terms=terms,seed=470+i})
        emit('decision',decision)
        return {decision=decision,ownership=ownership,context={epoch=config.environment.epoch,session=p.session,
            area='BG2602.ARE',allegiance=255,adapterVersion='1.0.0',candidates=native:candidates(config.environment.epoch)}}
    end
    local sampledSprites
    local function fresh(id)
        local sprites=scan();sampledSprites=sprites;proposals={}
        local ok,why=core:sample(config.environment,native:candidates(config.environment.epoch),function(who) return native:read(who) end)
        sampledSprites=nil;assert(ok,why)
        for _,c in pairs(core:inspect().circuits) do assert(c.errors==0,'observer error') end
        return assert(proposals[id.key],'fixture no longer eligible')
    end
    local function phase(name) p.phase=name;p.phaseAt=now();p.wallAt=Infinity_GetClockTicks();emit('phase') end
    local function try(i)
        local id=identities[i];local proposal=fresh(id).decision
        local before=scan();local actorBefore=details(before[i]);local targetBefore=details(before.target)
        local result,why=dispatch:dispatch(id,proposal)
        emit('dispatch',{actor=id.key,result=result or false,reason=why or false})
        if result and result.state=='accepted' then
            attempts[i]={attemptId=result.attemptId,before=actorBefore,targetHP=targetBefore.hp,submittedAt=now()}
        end
        return result,why
    end
    local function armLegacy(sprites)
        dispatch:setEnabled(false)
        for i=0,2 do EEex_Sprite_SetLocalInt(sprites[i],'B-XKCASE',i);EEex_Sprite_SetLocalInt(sprites[i],'B-XKPHASE',1) end
        phase('legacy');emit('legacy-armed',{count=3})
    end
    function p.begin(name)
        assert(not p.closed and not p.failed and (p.phase=='idle' or p.phase=='reset-ready'))
        assert(name=='baseline' or name=='disable-during-cast' or name=='replacement' or name=='load-after-start')
        assert(not p.cases[name],'one attempt per case');p.cases[name]={};p.case=name;p.session=p.session+1
        local sprites=scan();attempts={};p.starts={};p.baseline={};p.lastTick=nil;p.destroyedForCase=0;p.expectedPartyAction=false
        for i=0,2 do
            p.baseline[i]=details(sprites[i]);assert(idle(p.baseline[i]) and p.baseline[i].done==0 and p.baseline[i].scriptPhase==0)
            assert(p.baseline[i].ready.SPWI112==1 and p.baseline[i].ready.SPWI214==2)
        end
        core=m.new({clock=m.clock.new(function() return native:now() end),retryTicks=500,traceCapacity=64})
        for i=0,1 do
            identities[i]={adapterId=config.manifests[i+1].id,key='B-XPMAG'..i,resource='B-XPMAG'..i..'.CRE'}
            assert(core:register(config.manifests[i+1],function(id) proposals[id.key]=sample(id,assert(sampledSprites)) end))
            assert(core:enroll(identities[i]))
        end
        local bridge=assert(m.nativeDispatch.new(_G,'bg273-eeex12-luajit-v1',function(id,target)
            local current=scan();assert(target=='B-XPTRG0');return current[tonumber(id.key:match('([01])$'))],current.target
        end))
        dispatch=m.activeDispatch.new({clock={now=now},leaseTicks=5,attemptTicks=300,maxProposalAgeTicks=5,
            read=fresh,submit=function(id,r) return bridge:submit(id,r) end})
        assert(not dispatch:inspect().enabled)
        phase('default-off');return p.inspect()
    end
    local function poll()
        if p.closed or p.failed or p.phase=='idle' or p.phase=='await-load' or p.phase=='reset-ready' then return end
        assert(not p.hooks.disabled and native:ready())
        local tick=now();if p.lastTick and tick-p.lastTick<2 then return end;p.lastTick=tick
        assert(Infinity_GetClockTicks()-p.wallAt<65000,'case phase timeout')
        local startUs=EEex_Utility_GetMicroseconds();local sprites,pc=scan();local states={}
        for i=0,2 do states[i]=details(sprites[i]);emit('actor',{actor=i,state=states[i]}) end
        local target=details(sprites.target);emit('target',target)
        emit('party-idle',{action=pc.m_curAction.m_actionID,queued=pc.m_queuedActions.m_nCount})
        for i,a in pairs(attempts) do
            if p.case~='replacement' and not a.finished and a.started and (states[i].ready.SPWI112 or 0)==a.before.ready.SPWI112-1 and
                target.hp<a.targetHP and target.hp>0 and idle(states[i]) then
                a.finished=true;a.afterHP=target.hp
                if not a.invalidated then
                    local result,why=dispatch:observe(a.attemptId,{kind='completed',proof='independent-postcondition'})
                    assert(result and result.state=='completed',why);emit('outcome',result)
                end
                emit('ordinary-cast-proof',{actor=i,attemptId=a.attemptId,startedAt=a.started,
                    spent=1,beforeHP=a.targetHP,afterHP=target.hp,idle=true,invalidated=a.invalidated or false})
            end
        end
        for _,ended in ipairs(dispatch:tick()) do emit('deadline',ended);error('missing action outcome') end
        if p.phase=='replacement-observe' then
            local a=attempts[0];local dx,dy=states[0].x-a.before.x,states[0].y-a.before.y
            if not a.displaced and dx*dx+dy*dy>8*8 then
                a.displaced=now();a.hpAtDisplacement=target.hp
                emit('replacement-movement',{state=states[0],targetHP=target.hp,beforeHP=a.targetHP})
            end
            if now()-p.phaseAt>=150 and idle(states[0]) and pc.m_curAction.m_actionID==0 and pc.m_queuedActions.m_nCount==0 then
                assert(a.displaced,'replacement movement not observed')
                local interrupted=a.hpAtDisplacement==a.targetHP and target.hp==a.targetHP
                local result,why=dispatch:observe(a.attemptId,{kind=interrupted and 'interrupted' or 'unknown',
                    reason=interrupted and 'ordinary-replacement-before-delivery' or 'intervention-order-ambiguous'})
                assert(result,why);emit('outcome',result);a.finished=true;a.interruption=result.state
                p.expectedPartyAction=false;armLegacy(sprites)
            end
        elseif p.phase=='default-off' and tick-p.phaseAt>=15 then
            local result,why=try(0);assert(not result and why=='runtime-disabled')
            assert((p.starts['B-XPMAG0:SPWI112'] or 0)==0 and states[0].ready.SPWI112==1)
            dispatch:setEnabled(true);phase('cast-0');assert(try(0))
        elseif p.phase=='cast-0' and attempts[0] and attempts[0].finished then
            if p.case=='baseline' then phase('cast-1');assert(try(1)) else armLegacy(sprites) end
        elseif p.phase=='cast-1' and attempts[1] and attempts[1].finished then armLegacy(sprites)
        elseif p.phase=='legacy' then
            local done=true;for i=0,2 do if not idle(states[i]) or states[i].done~=1 then done=false end end
            if done then
                for i=0,2 do
                    assert(p.starts['B-XPMAG'..i..':SPWI214']==1 and states[i].ready.SPWI214==1 and states[i].strength)
                    local dx,dy=states[i].x-(304+i*48),states[i].y-240
                    assert(dx*dx+dy*dy<=24*24 and (states[i].x~=p.baseline[i].x or states[i].y~=p.baseline[i].y))
                end
                assert(not attempts[2] and not p.starts['B-XPMAG2:SPWI112'])
                p.cases[p.case]={attempts=attempts,legacy='three casts and moves',dispatch=dispatch:inspect()}
                phase('await-load')
            end
        end
        local cost=EEex_Utility_GetMicroseconds()-startUs;p.costs[#p.costs+1]=cost
        assert(cost<300000,'active batch callback exceeded development ceiling')
    end
    function p.poll()
        if p.inPoll then return end;p.inPoll=true;local ok,err=pcall(poll);p.inPoll=false;sampledSprites=nil
        if not ok then p.failed=tostring(err);if dispatch.setEnabled then dispatch:setEnabled(false) end;emit('failed',{reason=p.failed}) end
    end
    m.listeners.attach(p.hooks,{started=EEex_Action_AddSpriteStartedActionListener,
        destroyed=EEex_GameState_AddDestroyedListener,loaded=EEex_Sprite_AddLoadedListener},{
        started=function(sprite,action)
            if p.closed then return end
            local dv=clean(sprite.m_scriptName:get());local i=tonumber(dv:match('^B%-XPMAG([0-2])$'))
            if not i or clean(sprite.m_resref:get())~=dv then return end
            local res=clean(action.m_string1.m_pchData:get());emit('start',{actor=dv,action=action.m_actionID,resource=res})
            if action.m_actionID~=31 then return end
            p.starts[dv..':'..res]=(p.starts[dv..':'..res] or 0)+1
            local a=attempts[i]
            if res=='SPWI112' and a and not a.started then
                a.started=now();local result,why=dispatch:observe(a.attemptId,{kind='started'})
                assert(result and result.state=='started',why);emit('outcome',result)
                if p.case=='disable-during-cast' then
                    dispatch:setEnabled(false);a.invalidated=true;emit('disabled-during-cast',dispatch:inspect())
                elseif p.case=='replacement' then
                    local pc=assert(EEex_Sprite_GetInPortrait(0));p.expectedPartyAction=true
                    phase('replacement-observe')
                    emit('harness-replacement-request',{command='ordinary ActionOverride MoveToPoint',actor=dv})
                    EEex_Action_QueueResponseStringOnAIBase('ActionOverride("B-XPMAG0",MoveToPoint([232.216]))',pc)
                elseif p.case=='load-after-start' then
                    p.cases[p.case]={started=true,pending=dispatch:inspect()};phase('await-load')
                end
            end
        end,
        loaded=function() end,
        destroyed=function()
            if p.closed then return end
            if dispatch.invalidate then emit('load-invalidated',{attempts=dispatch:invalidate('session-destroyed')}) end
            if core.invalidate then core:invalidate('session-destroyed') end
            sampledSprites=nil;proposals={};p.destroyedForCase=(p.destroyedForCase or 0)+1;emit('destroyed')
        end,
    },function() return native:available() end)
    local originalPoll=previous and previous.combatActive.basePoll or assert(EEexRemote.Poll)
    p.basePoll=originalPoll
    EEexRemote.Poll=function(...) p.poll();return originalPoll(...) end
    function p.inspect() return {phase=p.phase,case=p.case,failed=p.failed,rows=p.rows,cases=p.cases,
        starts=p.starts,dispatch=dispatch.inspect and dispatch:inspect() or {},hooksDisabled=p.hooks.disabled} end
    function p.requestLoad()
        assert(p.phase=='await-load' and not p.failed)
        local sprites=scan()
        emit('before-load',{actor=details(sprites[0]),target=details(sprites.target),dispatch=dispatch:inspect(),
            limitation='pending bookkeeping after observed start; native continuation at destruction is not inferred'})
        return BGSELabTest.QA:start_load('000000973-BGSE Local Only 0928',BGSELabTest.revision)
    end
    function p.completeLoad()
        assert(p.phase=='await-load' and not p.failed and native:ready() and not p.hooks.disabled)
        assert(p.destroyedForCase==1 and core:inspect().enrolled==0 and BGSELabTest.QA:inspect().status=='complete')
        assert(not dispatch:inspect().enabled and dispatch:inspect().pending==0)
        p.cases[p.case].loadReset=true;phase('reset-ready');return p.inspect()
    end
    function p.close()
        assert(not p.closed);dispatch:setEnabled(false);core:shutdown();emit('closed');assert(output:close())
        p.closed=true;EEexRemote.Poll=originalPoll;return {state=p.inspect(),costs=p.costs}
    end
    return {ready=true,mode='default-off',activeActors=2,legacyOnly=1,cases={'baseline','disable-during-cast','replacement','load-after-start'}}
end
