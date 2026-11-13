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

local function triggerName(trig)
    if not trig or not trig.m_scriptName or type(trig.m_scriptName.get)~='function' then return '' end
    local ok,raw=pcall(trig.m_scriptName.get,trig.m_scriptName)
    return ok and cleanString(raw) or ''
end

local function areaName(area)
    if not area or not area.m_resref or type(area.m_resref.get)~='function' then return '' end
    local ok,raw=pcall(area.m_resref.get,area.m_resref)
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
    if type(addr)~='number' or type(rawget(g,'EEex_ReadU32'))~='function' then return nil end
    local ok,val=pcall(g.EEex_ReadU32,addr)
    if ok and type(val)=='number' then return val end
    return nil
end

local function writeFlags(g,addr,flags)
    if type(addr)~='number' then return false end
    local fn=rawget(g,'EEex_WriteU32') or rawget(g,'EEex_Write32')
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
                        local name=triggerName(trig)
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
    local stats=sprite.m_baseStats
    local state=stats and stats.m_generalState
    if type(state)~='number' then return false end
    local band=rawget(g,'EEex_BAnd')
    if type(band)=='function' then
        if band(state,M.DEAD_STATE_MASK)~=0 then return false end
    elseif math.floor(state/64)%64~=0 then
        return false
    end
    local hp=stats.m_hitPoints
    if type(hp)=='number' and hp<=0 then return false end
    return true
end

local function countLivingHostiles(g,area)
    local count=0
    local getObj=rawget(g,'EEex_GameObject_Get')
    local isSprite=rawget(g,'EEex_GameObject_IsSprite')
    iterateList(g,area.m_lVertSort,function(id)
        if type(id)=='number' and type(getObj)=='function' then
            local obj=getObj(id)
            if obj and (type(isSprite)~='function' or isSprite(obj,false)) then
                local ea=obj.m_typeAI and obj.m_typeAI.m_EnemyAlly or 0
                if ea>=M.HOSTILE_MIN_EA and ea~=M.CHARMED_PC_EA and isAliveSprite(g,obj) then
                    count=count+1
                end
            end
        end
    end)
    return count
end

local function findPartySpeaker(g,areaKey)
    local getter=rawget(g,'EEex_Sprite_GetInPortrait')
    if type(getter)~='function' then return nil end
    for i=0,5 do
        local ok,sp=pcall(getter,i)
        if ok and sp and sp.m_pArea and areaName(sp.m_pArea)==areaKey and isAliveSprite(g,sp) then
            return sp
        end
    end
    return nil
end

local function lockTrigger(g,area,item)
    if getAreaVar(g,area,item.tag)~=0 then return false end
    local addr=flagsAddress(g,item.trig)
    local flags=readFlags(g,addr)
    if not flags then return false end
    local prior=isDeactivated(flags) and 2 or 1
    if not setAreaVar(g,area,item.tag,prior) then return false end
    if prior==1 then
        writeFlags(g,addr,setDeactivated(flags))
        if type(item.trig.SetDrawPoly)=='function' then pcall(item.trig.SetDrawPoly,item.trig,0) end
    end
    return true
end

local function unlockTrigger(g,area,item)
    local saved=getAreaVar(g,area,item.tag)
    if saved==0 then return false end
    local addr=flagsAddress(g,item.trig)
    local flags=readFlags(g,addr)
    if saved==1 and flags then
        writeFlags(g,addr,clearDeactivated(flags))
        if type(item.trig.SetDrawPoly)=='function' then pcall(item.trig.SetDrawPoly,item.trig,0) end
    end
    setAreaVar(g,area,item.tag,0)
    return true
end

function M.new(g,options)
    g=g or _G
    options=options or {}
    local enabled=options.enabled==true
    local isEngineEnabled=options.isEnabled
    local locks=normalizeLocks(options.locks)
    local counts={locked=0,unlocked=0,ticks=0}
    local lastArea,lastTick=nil,nil
    local dirty=true
    local combatFile=nil

    local function engineOn()
        if type(isEngineEnabled)=='function' then
            local ok,res=pcall(isEngineEnabled)
            return ok and res==true
        end
        return hook.ini(g,'Enabled')~=0
    end

    local function inCombat(speaker)
        if type(options.inCombat)=='function' then
            local ok,res=pcall(options.inCombat,speaker)
            return ok and res==true
        end
        if not speaker then return false end
        local parse=rawget(g,'EEex_Trigger_ParseConditionalString')
        local eval=rawget(g,'EEex_Trigger_EvalScriptFileConditionalAsAIBase')
        if type(parse)~='function' or type(eval)~='function' then return false end
        if not combatFile then
            local ok,parsed=pcall(parse,'CombatCounterGT(0)')
            if ok and parsed then combatFile=parsed end
        end
        if not combatFile then return false end
        local ok,res=pcall(eval,combatFile,speaker)
        return ok and res==true
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

    function api:setEnabled(value)
        local nextVal=(value==true)
        if nextVal~=enabled then
            enabled=nextVal
            dirty=true
        end
    end

    function api:setEngineCheck(fn)
        isEngineEnabled=fn
        dirty=true
    end

    function api:invalidate()
        lastArea,lastTick=nil,nil
        dirty=true
        if combatFile and type(combatFile.free)=='function' then
            pcall(combatFile.free,combatFile)
        end
        combatFile=nil
    end

    function api:onDestroyed()
        rawset(g,'_bgseArenaInitSeen',false)
        api:invalidate()
    end

    function api:step()
        counts.ticks=counts.ticks+1
        local getArea=rawget(g,'EEex_Area_GetVisible')
        if type(getArea)~='function' then return false end
        local okArea,area=pcall(getArea)
        if not okArea or not area then return false end
        local key=areaName(area)
        local want=locks[key]
        if not want then
            lastArea=key
            dirty=false
            return false
        end
        local tick=nil
        local okTime,gt=pcall(hook.gameTime,g)
        if okTime and type(gt)=='number' then tick=gt end
        if not dirty and key==lastArea and tick~=nil and tick==lastTick then
            return false
        end
        lastArea,lastTick,dirty=key,tick,false

        local items=collectTriggers(g,area,want)
        if #items==0 then return false end

        local active=enabled and engineOn()
        local anyLocked=false
        for _,item in ipairs(items) do
            if getAreaVar(g,area,item.tag)~=0 then
                anyLocked=true
                break
            end
        end

        if not active then
            if anyLocked then
                for _,item in ipairs(items) do
                    if unlockTrigger(g,area,item) then counts.unlocked=counts.unlocked+1 end
                end
            end
            return false
        end

        local hostiles=countLivingHostiles(g,area)
        if hostiles==0 then
            if anyLocked then
                for _,item in ipairs(items) do
                    if unlockTrigger(g,area,item) then counts.unlocked=counts.unlocked+1 end
                end
            end
            return false
        end

        local speaker=findPartySpeaker(g,key)
        if anyLocked or inCombat(speaker) then
            local newlyLocked=0
            for _,item in ipairs(items) do
                if lockTrigger(g,area,item) then
                    newlyLocked=newlyLocked+1
                    counts.locked=counts.locked+1
                end
            end
            if newlyLocked>0 then announce(speaker) end
        end
        return false
    end

    function api:inspect()
        return {
            enabled=enabled,
            counts={locked=counts.locked,unlocked=counts.unlocked,ticks=counts.ticks},
        }
    end

    rawset(g,'_bgseArenaApi',api)
    rawset(g,'BGSE_Arena_Tick',function()
        local current=rawget(g,'_bgseArenaApi')
        if type(current)=='table' and type(current.step)=='function' then
            local ok,res=pcall(current.step,current)
            if ok then return res==true end
        end
        return false
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

    local addInit=rawget(g,'EEex_GameState_AddInitializedListener')
    if type(addInit)=='function' and not rawget(g,'_bgseArenaInitListener') then
        rawset(g,'_bgseArenaInitListener',true)
        pcall(addInit,function()
            rawset(g,'_bgseArenaInitSeen',true)
            local current=rawget(g,'_bgseArenaApi')
            if type(current)=='table' and type(current.invalidate)=='function' then pcall(current.invalidate,current) end
            pushMenu()
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
