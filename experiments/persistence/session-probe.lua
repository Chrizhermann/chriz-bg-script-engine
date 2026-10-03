-- Host-sent Task10 research probe. Own synthetic caster/handler only, no production state.
local root=assert(rawget(_G,'B-'))
assert(root.project=='chriz-bg-script-engine' and not root.persistenceProbe)
local base=assert(BGSEPersistenceSource)
assert(base:match('/experiments/persistence/$'))
local state=assert(loadfile(base..'state_schema.lua'))()
local diagnostics=assert(loadfile(base..'diagnostics.lua'))()
local logPath=assert(BGSEPersistenceLog)
assert(logPath:match('/%.work/task10/persistence%-runtime%-v%d+/events%.tsv$'))
local old=io.open(logPath,'r');if old then old:close();error('refuse existing trace') end
local file=assert(io.open(logPath,'w'))
assert(file:write('sequence\tevent\tepoch\tcase\trecord\tstatus\tversion\tdetail\n'))
local probe={epoch=0,events=0,exports=0,imports=0,loaded=0,case='setup',expectedStack='fixture:stack-a'}
root.persistenceProbe=probe
local handler='B-'
local registry=assert(EEex_Sprite_Private_MarshalHandlers)
assert(registry[handler]==nil,'handler already owned')
local log=diagnostics.new({traceCapacity=64,errorAdapterCapacity=8,errorsPerAdapter=3,maxTextBytes=64})
local limits={maxDepth=8,maxNodes=256,maxBytes=8192,maxStringBytes=128}
local text={kind='string',maxBytes=64,minBytes=1}
local function number(max) return {kind='number',integer=true,min=0,max=max} end
local function fields(version,wire)
    local f={flowId=text,phase=text,stackEpoch=text,marker=number(100000)}
    if version>=2 then f.epoch=number(wire and 1000 or 10) end
    if version>=3 then
        f.committed=number(1);f.actorKeys={kind='array',maxItems=4,items=text}
        f.numbers={kind='array',maxItems=5,items=number(4294967295)}
    end
    if wire then
        f.epoch.optional=true;f.committed.optional=true;f.actorKeys.optional=true;f.numbers.optional=true
    end
    return {kind='record',fields=f}
end
local contract={schemaId='research:durable-fixture',version=3,limits=limits,
    shapes={[1]=fields(1),[2]=fields(2),[3]=fields(3)},migrations={
        [1]=function(p) p.epoch=0;return p end,
        [2]=function(p) p.committed=0;p.actorKeys={};p.numbers={};return p end,
    }}
local wire={kind='record',fields={schemaId=text,schemaVersion=number(100),payload=fields(3,true)}}
local keys={'good','old','future','corrupt'}
local function emit(event,key,result,detail)
    if probe.closed then return end
    assert(probe.events<2000,'bounded trace exhausted')
    probe.events=probe.events+1
    local row={probe.events,event,probe.epoch,probe.case,key or '',result and result.status or '',
        result and result.value and result.value.schemaVersion or '',detail or ''}
    for i=1,#row do row[i]=tostring(row[i]):gsub('[\r\n\t]',' ') end
    assert(file:write(table.concat(row,'\t')..'\n'));assert(file:flush())
end
local function fault(code)
    probe.failed=code;log:error('research:persistence',code)
end
local function currentCaster()
    assert(Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not Infinity_GetTransitionInProgress())
    assert(EEex_Sprite_GetNumCharacters()==1)
    local owner=assert(EEex_Sprite_GetInPortrait(0))
    assert(EEex_Sprite_GetName(owner)=='BGSE Lab Test' and owner.m_pArea)
    local area=owner.m_pArea.m_resref:get()
    if area~='BG2602' then return nil,area end
    local found
    EEex_Utility_IterateCPtrList(owner.m_pArea.m_lVertSort,function(id)
        local object=EEex_GameObject_Get(id)
        if object and EEex_GameObject_IsSprite(object,true) then
            local s=EEex_GameObject_CastUserType(object)
            if s.m_scriptName:get()=='B-XCAST2' then
                assert(not found,'ambiguous fixture')
                assert(s.m_resref:get()=='B-XMAGE2' or
                    (s.m_resref:get():sub(1,1)=='*' and EEex_Sprite_GetLocalInt(s,'B-XIDENT')==93301))
                found=s
            end
        end
    end)
    return found,area
end
local function exportSprite(sprite)
    if probe.failed then return nil end
    local aux=EEex_GetUDAux(sprite)[handler]
    if not aux then return nil end
    local packet={}
    for _,key in ipairs(keys) do
        if aux.records[key] then
            local copied,reason=state.copy(aux.records[key],wire,limits)
            if copied then packet[key]=copied
            else log:error('research:'..key,reason);emit('export-quarantine',key,{status='quarantined'},reason) end
        end
    end
    probe.exports=probe.exports+1;emit('export',nil,nil,'independent wire copies')
    return packet
end
local function importSprite(sprite,packet)
    if probe.failed then return end
    assert(type(packet)=='table' and getmetatable(packet)==nil)
    local aux={records={},results={}}
    for _,key in ipairs(keys) do
        local incoming=rawget(packet,key)
        if incoming then
            local copied,reason=state.copy(incoming,wire,limits)
            local result=copied and state.load(copied,contract) or {status='quarantined',reason=reason}
            if result.status=='ready' and result.value.payload.stackEpoch~=probe.expectedStack then
                result={status='quarantined',reason='stack-epoch'}
            end
            aux.results[key]=result
            log:record({kind='import',adapterId='research:'..key,outcome=result.status,reason=result.reason})
            -- Retain only sanitized wire facts; ready versions are upgraded on a later save.
            aux.records[key]=result.status=='ready' and result.value or copied
            emit('import-record',key,result,result.reason or ('migrations:'..result.migrated))
        end
    end
    EEex_GetUDAux(sprite)[handler]=aux
    probe.imports=probe.imports+1;emit('import',nil,nil,'own aux only; no native sprite reads')
end
local function guardedExport(sprite)
    local ok,result=pcall(exportSprite,sprite)
    if ok then return result end
    fault('export-callback');return nil
end
local function guardedImport(sprite,packet)
    if not pcall(importSprite,sprite,packet) then fault('import-callback') end
end
local function install()
    assert(registry[handler]==nil,'handler collision')
    EEex_Sprite_AddMarshalHandlers(handler,guardedExport,guardedImport)
    probe.registration=registry[handler]
    emit('handler-installed')
end
install()
local trampoline=assert(loadfile('override/B-XOBS00.lua'))()
trampoline.attach(probe,{
    destroyed=EEex_GameState_AddDestroyedListener,
    loaded=EEex_Sprite_AddLoadedListener,
},{
    destroyed=function()
        probe.epoch=probe.epoch+1;probe.ephemeral=nil;probe.area=nil
        emit('session-destroyed',nil,nil,'ephemeral cleared')
    end,
    loaded=function(sprite)
        -- Same narrow UDAux-only pattern as the installed EEex importer/loaded hook.
        if EEex_GetUDAux(sprite)[handler] then probe.loaded=probe.loaded+1;emit('own-sprite-loaded') end
    end,
},function() return EEex_Active and EEex_Sprite_Private_MarshalHandlers==registry end)
local oldPoll=assert(EEexRemote.Poll)
EEexRemote.Poll=function(...)
    if not probe.closed and not probe.failed and Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and
        not Infinity_GetTransitionInProgress() then
        local ok=pcall(function()
            local caster,area=currentCaster()
            if probe.area~=area then
                probe.ephemeral=nil;probe.area=area;emit('area',nil,nil,area..'; ephemeral cleared')
            end
            if probe.ephemeral then
                if not caster then
                    probe.ephemeral=nil;emit('actor-unavailable',nil,nil,'absent; death not inferred')
                elseif caster.m_baseStats.m_hitPoints<=0 or bit.band(EEex_Sprite_GetState(caster),0xFC0)~=0 then
                    probe.ephemeral=nil;emit('actor-dead',nil,nil,
                        'hp:'..caster.m_baseStats.m_hitPoints..';state:'..EEex_Sprite_GetState(caster))
                end
            end
        end)
        if not ok then fault('world-observation') end
    end
    return oldPoll(...)
end
function probe.seed()
    assert(not probe.failed and not probe.seeded)
    local caster=assert(currentCaster());assert(not EEex_GetUDAux(caster)[handler])
    EEex_Sprite_SetLocalInt(caster,'B-XIDENT',93301)
    local function payload(marker)
        return {flowId='research:flow',phase='fixture-ready',stackEpoch='fixture:stack-a',
            marker=marker,epoch=2,committed=1,actorKeys={'research:caster'},
            numbers={255,256,65535,65536,4294967295}}
    end
    local good=assert(state.export(payload(10031),contract))
    local old={schemaId=contract.schemaId,schemaVersion=1,payload=payload(10032)}
    old.payload.epoch=nil;old.payload.committed=nil;old.payload.actorKeys=nil;old.payload.numbers=nil
    local future=assert(state.export(payload(10033),contract));future.schemaVersion=99
    local corrupt=assert(state.export(payload(10034),contract));corrupt.payload.epoch=999
    EEex_GetUDAux(caster)[handler]={records={good=good,old=old,future=future,corrupt=corrupt},results={}}
    probe.seeded=true;probe.case='seeded';emit('seeded')
    return probe.inspect()
end
function probe.armEphemeral(label)
    assert(type(label)=='string' and #label<64 and not probe.failed)
    assert(currentCaster());probe.ephemeral={attemptId=label,epoch=probe.epoch}
    emit('ephemeral-armed',nil,nil,label)
end
function probe.changeUnsavedMarker()
    local caster=assert(currentCaster())
    local good=assert(EEex_GetUDAux(caster)[handler].records.good)
    assert(good.payload.marker==10031)
    good.payload.marker=20031;emit('unsaved-marker',nil,nil,'20031 must disappear on load')
end
function probe.killFixture()
    local caster=assert(currentCaster())
    assert(caster.m_baseStats.m_hitPoints>0 and caster.m_curAction.m_actionID==0 and
        caster.m_queuedActions.m_nCount==0 and probe.ephemeral)
    EEex_Action_QueueResponseStringOnAIBase('Kill(Myself)',caster)
    emit('kill-submitted',nil,nil,'own synthetic actor; not death proof')
end
function probe.setCase(label)
    assert(type(label)=='string' and #label<64);probe.case=label;emit('case')
end
function probe.setExpectedStack(epoch)
    assert(epoch=='fixture:stack-a' or epoch=='fixture:stack-b')
    probe.expectedStack=epoch;emit('expected-stack',nil,nil,epoch)
end
function probe.removeHandler()
    assert(not probe.failed and registry[handler]==probe.registration)
    registry[handler]=nil;emit('handler-removed',nil,nil,'only our exact named Lua entry')
end
function probe.restoreHandler()
    -- Host must first load the no-state baseline, avoiding exporter+fallback duplication.
    local caster,area=currentCaster();assert(not caster and area=='BG2600')
    install()
end
function probe.inspect()
    local result={epoch=probe.epoch,events=probe.events,exports=probe.exports,imports=probe.imports,
        loaded=probe.loaded,failed=probe.failed,disabled=probe.disabled,registrations=probe.registrations,
        ephemeral=probe.ephemeral~=nil,handlerPresent=registry[handler]==probe.registration,
        diagnostics=log:snapshot(),case=probe.case}
    if Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and not Infinity_GetTransitionInProgress() then
        local caster,area=currentCaster();result.area=area
        if caster then
            result.caster={hp=caster.m_baseStats.m_hitPoints,state=EEex_Sprite_GetState(caster)}
            local aux=EEex_GetUDAux(caster)
            local own=aux[handler];result.records={}
            for _,key in ipairs(keys) do
                local r=own and own.results[key]
                local record=own and own.records[key]
                result.records[key]={status=r and r.status,reason=r and r.reason,migrated=r and r.migrated,
                    version=record and record.schemaVersion,marker=record and record.payload.marker,
                    numbers=record and record.payload.numbers and
                        state.copy(record.payload.numbers,contract.shapes[3].fields.numbers,limits)}
            end
            local fallback=aux.EEex_Sprite_FallbackMarshalStorage
            result.fallbackPresent=fallback~=nil and fallback[handler]~=nil
        end
    end
    return result
end
function probe.close()
    assert(not probe.closed);emit('closed');probe.closed=true;assert(file:close())
    return {closed=true,events=probe.events}
end
return {ready=true,registrations=probe.registrations}
