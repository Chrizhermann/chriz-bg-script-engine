-- Challenge Mode Arena Exit Locks (Christopher, 2026-11-14).
--
-- Opt-in only (enabled by [BGSE] ArenaLocks=1 or [BGSE] ChallengeMode=1 in Baldur.lua, default off).
-- While active in configured boss arenas, deactivates listed travel triggers once combat starts
-- (region flags bit 0x100 at m_newEntryPoint + 0x20, tracking pre-lock state per trigger in area
-- variable BGSE_LK_<tag>) and restores them immediately when living hostiles in the area reach 0
-- or when Challenge Mode / ArenaLocks / the BGSE engine is turned off.
local hook=require('adapters.eeex.hook')
local M={}

M.DEACTIVATED_BIT=0x100
M.DEAD_STATE_MASK=0xFC0
M.TRIGGER_TRAVEL=2
M.HOSTILE_MIN_EA=200
M.CHARMED_PC_EA=254

local TICK_MENU=[[
menu
{
    name "BGSE_ARENA_TICK"
    ignoreEsc
    label
    {
        enabled "BGSE_Arena_Tick()"
    }
}
]]

local function cleanString(raw)
    if type(raw)~='string' then return '' end
    return (raw:match('^[^%z]*') or ''):upper()
end

local function readText(field)
    if field==nil then return '' end
    local ok,raw=pcall(function() return field:get() end)
    if not ok or type(raw)~='string' then
        ok,raw=pcall(function() return field.m_pchData:get() end)
    end
    return ok and cleanString(raw) or ''
end

local function isDeactivated(flags)
    return type(flags)=='number' and math.floor(flags/M.DEACTIVATED_BIT)%2==1
end

local function setDeactivated(flags)
    return isDeactivated(flags) and flags or flags+M.DEACTIVATED_BIT
end

local function clearDeactivated(flags)
    return isDeactivated(flags) and flags-M.DEACTIVATED_BIT or flags
end

local function normalizeLocks(raw)
    local byArea={}
    if type(raw)~='table' then return byArea end
    for area,names in pairs(raw) do
        if type(area)=='string' and area~='' and type(names)=='table' then
            local want={}
            for _,name in ipairs(names) do
                if type(name)=='string' and name~='' then want[name:upper()]=true end
            end
            if next(want)~=nil then byArea[area:upper()]=want end
        end
    end
    return byArea
end

local function triggerTag(name,trig,ordinal)
    local clean=name:upper():gsub('[^%w]','')
    if #clean>10 then clean=clean:sub(1,10) end
    local box=trig.m_rBounding
    local lx=box and math.floor(box.left or 0) or 0
    local ty=box and math.floor(box.top or 0) or 0
    return string.format('BGSE_LK_%s_%d_%d_%d',clean,lx,ty,ordinal or 0)
end

local function flagsAddress(g,trig)
    if type(rawget(g,'EEex_UDToPtr'))~='function' then return nil end
    local entry=trig.m_newEntryPoint
    if not entry then return nil end
    local ok,base=pcall(g.EEex_UDToPtr,entry)
    if ok and type(base)=='number' and base~=0 then return base+0x20 end
    return nil
end

local function readFlags(g,addr)
    if type(addr)~='number' then return nil end
    local fn=rawget(g,'EEex_ReadU32') or rawget(g,'EEex_Read32')
    if type(fn)~='function' then return nil end
    local ok,val=pcall(fn,addr)
    if ok and type(val)=='number' then
        if val<0 then val=val+4294967296 end
        return val
    end
    return nil
end

local function writeFlags(g,addr,flags)
    if type(addr)~='number' then return false end
    local fn=rawget(g,'EEex_Write32') or rawget(g,'EEex_WriteU32')
    if type(fn)~='function' then return false end
    local ok=pcall(fn,addr,flags)
    return ok==true
end

local function getAreaVar(g,area,name)
    local fn=rawget(g,'EEex_Area_GetVariableInt')
    if type(fn)~='function' then return 0 end
    local ok,val=pcall(fn,area,name)
    if ok and type(val)=='number' then return val end
    return 0
end

local function setAreaVar(g,area,name,val)
    local fn=rawget(g,'EEex_Area_SetVariableInt')
    if type(fn)~='function' then return false end
    local ok=pcall(fn,area,name,val)
    return ok==true
end

local function iterateList(g,list,fn)
    if not list then return end
    local iter=rawget(g,'EEex_Utility_IterateCPtrList')
    if type(iter)=='function' then
        pcall(iter,list,fn)
        return
    end
    if type(list)=='table' then
        for _,v in ipairs(list) do fn(v) end
    end
end

local function collectTriggers(g,area,want)
    local out,seen={},{}
    local lists={area.m_lVertSortBack,area.m_lVertSort}
    local getObj=rawget(g,'EEex_GameObject_Get')
    local castObj=rawget(g,'EEex_GameObject_CastUserType')
    local types=rawget(g,'CGameObjectType')
    local trigType=type(types)=='table' and types.TRIGGER or 0x41
    for _,list in ipairs(lists) do
        iterateList(g,list,function(id)
            if type(id)=='number' and not seen[id] and type(getObj)=='function' then
                seen[id]=true
                local obj=getObj(id)
                if obj and obj.m_objectType==trigType then
                    local trig=type(castObj)=='function' and castObj(obj) or obj
                    if trig and trig.m_triggerType==M.TRIGGER_TRAVEL then
                        local name=readText(trig.m_scriptName)
                        if want[name] then
                            out[#out+1]={name=name,trig=trig}
                        end
                    end
                end
            end
        end)
    end
    local ordinals={}
    for _,item in ipairs(out) do
        ordinals[item.name]=(ordinals[item.name] or 0)+1
        item.tag=triggerTag(item.name,item.trig,ordinals[item.name])
    end
    return out
end

local function isAliveSprite(g,sprite)
    if sprite.m_active~=nil and sprite.m_active==0 then return false end
    local getState=rawget(g,'EEex_Sprite_GetState')
    local state=nil
    if type(getState)=='function' then
        local ok,val=pcall(getState,sprite)
        if ok and type(val)=='number' then state=val end
    end
    local stats=sprite.m_baseStats
    if type(state)~='number' then state=stats and stats.m_generalState end
    if type(state)~='number' then return false end
    local band=rawget(g,'EEex_BAnd')
    if type(band)=='function' then
        if band(state,M.DEAD_STATE_MASK)~=0 then return false end
    elseif math.floor(state/64)%64~=0 then
        return false
    end
    local hp=stats and stats.m_hitPoints
    if type(hp)~='number' or hp<=0 then return false end
    return true
end

local function spriteEA(obj)
    local okLive,ea=pcall(function() return obj.m_liveTypeAI.m_EnemyAlly end)
    if okLive and type(ea)=='number' then return ea end
    local okType,ea2=pcall(function() return obj.m_typeAI.m_EnemyAlly end)
    if okType and type(ea2)=='number' then return ea2 end
    return 0
end

local function countLivingHostiles(g,area)
    local count,seen=0,{}
    local getObj=rawget(g,'EEex_GameObject_Get')
    local isSprite=rawget(g,'EEex_GameObject_IsSprite')
    if type(getObj)~='function' then return 0 end
    for _,list in ipairs({area.m_lVertSort,area.m_lVertSortBack}) do
        iterateList(g,list,function(id)
            if type(id)=='number' and not seen[id] then
                seen[id]=true
                local obj=getObj(id)
                if obj and (type(isSprite)~='function' or isSprite(obj,false)) then
                    local ea=spriteEA(obj)
                    if ea>=M.HOSTILE_MIN_EA and ea~=M.CHARMED_PC_EA and isAliveSprite(g,obj) then
                        count=count+1
                    end
                end
            end
        end)
    end
    return count
end

local function currentArea(g)
    local getArea=rawget(g,'EEex_Area_GetVisible')
    if type(getArea)=='function' then
        local okArea,area=pcall(getArea)
        if okArea and area~=nil then return area end
    end
    local getter=rawget(g,'EEex_Sprite_GetInPortrait')
    if type(getter)=='function' then
        for i=0,5 do
            local ok,sp=pcall(getter,i)
            if ok and sp then
                local okArea,pArea=pcall(function() return sp.m_pArea end)
                if okArea and pArea~=nil then return pArea end
            end
        end
    end
    return nil
end

local function partyInArea(g,areaKey)
    local party={}
    local getter=rawget(g,'EEex_Sprite_GetInPortrait')
    if type(getter)~='function' then return party end
    for i=0,5 do
        local ok,sp=pcall(getter,i)
        if ok and sp and sp.m_pArea and readText(sp.m_pArea.m_resref)==areaKey and isAliveSprite(g,sp) then
            party[#party+1]=sp
        end
    end
    return party
end

local function lockTrigger(g,area,item)
    local saved=getAreaVar(g,area,item.tag)
    local addr=flagsAddress(g,item.trig)
    local flags=readFlags(g,addr)
    if saved~=0 then
        if saved==1 and flags and not isDeactivated(flags) then
            if writeFlags(g,addr,setDeactivated(flags)) then
                pcall(function() item.trig:SetDrawPoly(0) end)
            end
        end
        return false
    end
    if not flags then return false end
    local prior=isDeactivated(flags) and 2 or 1
    if not setAreaVar(g,area,item.tag,prior) then return false end
    if prior==1 then
        if not writeFlags(g,addr,setDeactivated(flags)) then
            setAreaVar(g,area,item.tag,0)
            return false
        end
        pcall(function() item.trig:SetDrawPoly(0) end)
    end
    return true
end

local function unlockTrigger(g,area,item)
    local saved=getAreaVar(g,area,item.tag)
    if saved==0 then return false end
    local addr=flagsAddress(g,item.trig)
    local flags=readFlags(g,addr)
    if saved==1 then
        if not flags or not writeFlags(g,addr,clearDeactivated(flags)) then
            return false
        end
        pcall(function() item.trig:SetDrawPoly(1) end)
    end
    setAreaVar(g,area,item.tag,0)
    return true
end

function M.new(g,options)
    g=g or _G
    options=options or {}
    local enabled=options.enabled==true
    local isEngineEnabled=options.isEnabled
    local onTick=options.onTick
    local onInit=options.onInit
    local locks=normalizeLocks(options.locks)
    local counts={locked=0,unlocked=0,ticks=0}
    local lastArea,lastTick=nil,nil
    local dirty=true
    local checkPending=true
    local lastFastMs=nil
    local lastError=false
    local lastHostiles=nil
    local lastCombat=false
    local combatFile,seeEvilFile=nil,nil

    local function engineOn()
        if type(isEngineEnabled)=='function' then
            local ok,res=pcall(isEngineEnabled)
            return ok and res==true
        end
        return hook.ini(g,'Enabled')~=0
    end

    local function inCombat(party)
        if type(options.inCombat)=='function' then
            local ok,res=pcall(options.inCombat,party[1])
            return ok and res==true
        end
        if #party==0 then return false end
        local parse=rawget(g,'EEex_Trigger_ParseConditionalString')
        local eval=rawget(g,'EEex_Trigger_EvalScriptFileConditionalAsAIBase')
        if type(parse)~='function' or type(eval)~='function' then return false end
        if not combatFile then
            local ok,parsed=pcall(parse,'CombatCounterGT(0)')
            if ok and parsed then combatFile=parsed end
        end
        if combatFile then
            local ok,res=pcall(eval,combatFile,party[1])
            if ok and res==true then return true end
        end
        if not seeEvilFile then
            local ok,parsed=pcall(parse,'See([EVILCUTOFF])')
            if ok and parsed then seeEvilFile=parsed end
        end
        if seeEvilFile then
            for _,sp in ipairs(party) do
                local ok,res=pcall(eval,seeEvilFile,sp)
                if ok and res==true then return true end
            end
        end
        return false
    end

    local function announce(speaker)
        if hook.ini(g,'Shouts')==0 then return end
        local display=rawget(g,'EEex_Sprite_DisplayTextRef')
        if type(display)~='function' or not speaker then return end
        local refs=rawget(g,'BGSE_CALL_STRREFS')
        local strref=type(refs)=='table' and refs.arena_locked or nil
        if type(strref)=='number' then pcall(display,speaker,strref,{overHead=true}) end
    end

    local api={}

    function api:invalidate()
        lastArea,lastTick,lastFastMs=nil,nil,nil
        dirty,checkPending=true,true
        lastHostiles,lastCombat=nil,false
        if combatFile and type(combatFile.free)=='function' then
            pcall(combatFile.free,combatFile)
        end
        if seeEvilFile and type(seeEvilFile.free)=='function' then
            pcall(seeEvilFile.free,seeEvilFile)
        end
        combatFile,seeEvilFile=nil,nil
    end

    function api:onDestroyed()
        api:invalidate()
    end

    function api:step()
        lastError=false
        counts.ticks=counts.ticks+1
        local area=currentArea(g)
        if not area then return false end
        local key=readText(area.m_resref)
        local want=locks[key]
        if not want then
            lastArea,lastHostiles,lastCombat=key,nil,false
            dirty,checkPending=false,false
            return false
        end
        local tick=nil
        local okTime,gt=pcall(hook.gameTime,g)
        if okTime and type(gt)=='number' then tick=gt end
        if not dirty and key==lastArea and tick~=nil and tick==lastTick then
            return false
        end
        if key~=lastArea then checkPending=true end
        lastArea,lastTick,dirty=key,tick,false

        local items=collectTriggers(g,area,want)
        if #items==0 then
            lastHostiles,lastCombat=nil,false
            checkPending=false
            return false
        end

        local active=enabled and engineOn()
        local anyLocked=false
        for _,item in ipairs(items) do
            if getAreaVar(g,area,item.tag)~=0 then
                anyLocked=true
                break
            end
        end

        if not active then
            lastHostiles,lastCombat=nil,false
            if anyLocked then
                for _,item in ipairs(items) do
                    if unlockTrigger(g,area,item) then counts.unlocked=counts.unlocked+1 end
                end
            end
            checkPending=false
            return false
        end

        checkPending=true
        local hostiles=countLivingHostiles(g,area)
        lastHostiles=hostiles
        if hostiles==0 then
            lastCombat=false
            if anyLocked then
                for _,item in ipairs(items) do
                    if unlockTrigger(g,area,item) then counts.unlocked=counts.unlocked+1 end
                end
            end
            return false
        end

        local party=partyInArea(g,key)
        local combat=inCombat(party)
        lastCombat=combat
        if anyLocked or combat then
            local newlyLocked=0
            for _,item in ipairs(items) do
                if lockTrigger(g,area,item) then
                    newlyLocked=newlyLocked+1
                    counts.locked=counts.locked+1
                end
            end
            if newlyLocked>0 then announce(party[1]) end
        end
        return false
    end

    function api:guardedStep()
        local ok,res=pcall(api.step,api)
        if not ok then
            lastError=tostring(res)
            return false
        end
        return res==true
    end

    function api:fastStep()
        if not enabled and not dirty and not checkPending then return false end
        local getTicks=rawget(g,'Infinity_GetClockTicks')
        if type(getTicks)=='function' then
            local okMs,nowMs=pcall(getTicks)
            if okMs and type(nowMs)=='number' then
                if not dirty and lastFastMs~=nil and nowMs>=lastFastMs and (nowMs-lastFastMs)<20 then
                    return false
                end
                lastFastMs=nowMs
            end
        end
        return api:guardedStep()
    end

    function api:setEnabled(value)
        local nextVal=(value==true)
        if nextVal~=enabled then
            enabled=nextVal
            dirty=true
            lastFastMs=nil
            api:guardedStep()
        end
    end

    function api:setEngineCheck(fn)
        isEngineEnabled=fn
        dirty=true
        lastFastMs=nil
    end

    function api:inspect()
        return {
            enabled=enabled,
            lastError=lastError,
            lastArea=lastArea or false,
            lastHostiles=lastHostiles,
            lastCombat=lastCombat,
            counts={locked=counts.locked,unlocked=counts.unlocked,ticks=counts.ticks},
        }
    end

    rawset(g,'_bgseArenaApi',api)
    rawset(g,'_bgseArenaOnTick',type(onTick)=='function' and onTick or nil)
    rawset(g,'_bgseArenaOnInit',type(onInit)=='function' and onInit or nil)
    rawset(g,'BGSE_Arena_Tick',function()
        local current=rawget(g,'_bgseArenaApi')
        local res=false
        if type(current)=='table' and type(current.fastStep)=='function' then
            res=current:fastStep()
        end
        local extra=rawget(g,'_bgseArenaOnTick')
        if type(extra)=='function' then pcall(extra) end
        return res
    end)

    local function pushMenu()
        local push=rawget(g,'Infinity_PushMenu')
        if rawget(g,'_bgseArenaMenuLoaded')==true and rawget(g,'_bgseArenaInitSeen')==true and type(push)=='function' then
            pcall(push,'BGSE_ARENA_TICK')
        end
    end

    local addMenu=rawget(g,'EEex_Menu_AddAfterMainFileLoadedListener')
    if type(addMenu)=='function' and not rawget(g,'_bgseArenaMenuListener') then
        rawset(g,'_bgseArenaMenuListener',true)
        pcall(addMenu,function()
            local eval=rawget(g,'EEex_Menu_Eval')
            if type(eval)=='function' then pcall(eval,TICK_MENU) end
            rawset(g,'_bgseArenaMenuLoaded',true)
            pushMenu()
        end)
    end

    local addReload=rawget(g,'EEex_Menu_AddAfterMainFileReloadedListener')
    if type(addReload)=='function' and not rawget(g,'_bgseArenaMenuReloadListener') then
        rawset(g,'_bgseArenaMenuReloadListener',true)
        pcall(addReload,function() pushMenu() end)
    end

    local addInit=rawget(g,'EEex_GameState_AddInitializedListener')
    if type(addInit)=='function' and not rawget(g,'_bgseArenaInitListener') then
        rawset(g,'_bgseArenaInitListener',true)
        pcall(addInit,function()
            rawset(g,'_bgseArenaInitSeen',true)
            local current=rawget(g,'_bgseArenaApi')
            if type(current)=='table' and type(current.invalidate)=='function' then pcall(current.invalidate,current) end
            local extraInit=rawget(g,'_bgseArenaOnInit')
            if type(extraInit)=='function' then pcall(extraInit) end
            pushMenu()
        end)
    end

    local addLists=rawget(g,'EEex_Opcode_AddDeferredListsResolvedListener') or rawget(g,'EEex_Opcode_AddListsResolvedListener')
    if type(addLists)=='function' and not rawget(g,'_bgseArenaListsListener') then
        rawset(g,'_bgseArenaListsListener',true)
        pcall(addLists,function()
            local current=rawget(g,'_bgseArenaApi')
            if type(current)=='table' and type(current.fastStep)=='function' then pcall(current.fastStep,current) end
            local extra=rawget(g,'_bgseArenaOnTick')
            if type(extra)=='function' then pcall(extra) end
        end)
    end

    local addDestroy=rawget(g,'EEex_GameState_AddDestroyedListener')
    if options.hookDestroyed~=true and type(addDestroy)=='function' and not rawget(g,'_bgseArenaDestroyListener') then
        rawset(g,'_bgseArenaDestroyListener',true)
        pcall(addDestroy,function()
            local current=rawget(g,'_bgseArenaApi')
            if type(current)=='table' and type(current.onDestroyed)=='function' then pcall(current.onDestroyed,current) end
        end)
    end

    pushMenu()
    return api
end

return M
