-- Narrow read-only boundary for the pinned G1 lab call shapes. No scheduler or dispatcher.
-- A profile label is not a binary check: the installer/lab must verify its pinned identities.
local snapshot=require('kernel.engine').snapshot
local M={}
local required={'Infinity_IsMenuOnStack','Infinity_GetTransitionInProgress','Infinity_GetClockTicks',
    'EEex_Sprite_GetInPortrait','EEex_Utility_IterateCPtrList','EEex_GameObject_Get',
    'EEex_GameObject_IsSprite','EEex_GameObject_CastUserType','EEex_BAnd'}
local function clean(v) return v:match('^[^%z]*') end
function M.new(globals,profile)
    if profile~='bg273-eeex12-luajit-v1' then return nil,'unsupported-profile' end
    if type(globals)~='table' or not rawget(globals,'EEex_Active') or
        type(rawget(globals,'jit'))~='table' then return nil,'runtime-unavailable' end
    local functions={}
    for _,name in ipairs(required) do
        functions[name]=rawget(globals,name)
        if type(functions[name])~='function' then return nil,'missing-capability' end
    end
    local jit=rawget(globals,'jit')
    local api={}
    function api:available()
        if not rawget(globals,'EEex_Active') or rawget(globals,'jit')~=jit then return false end
        for _,name in ipairs(required) do if rawget(globals,name)~=functions[name] then return false end end
        return true
    end
    function api:ready()
        return self:available() and functions.Infinity_IsMenuOnStack('WORLD_ACTIONBAR')
            and not functions.Infinity_GetTransitionInProgress()
    end
    function api:now() assert(self:available(),'capability-lost');return functions.Infinity_GetClockTicks() end
    local function walk(visit)
        assert(api:ready(),'world-not-ready')
        local pc=functions.EEex_Sprite_GetInPortrait(0)
        assert(pc and pc.m_pArea,'no-current-area')
        local area=pc.m_pArea
        local areaName=clean(area.m_resref:get())..'.ARE'
        functions.EEex_Utility_IterateCPtrList(area.m_lVertSort,function(id)
            local object=functions.EEex_GameObject_Get(id)
            if object and functions.EEex_GameObject_IsSprite(object,true) then
                local sprite=functions.EEex_GameObject_CastUserType(object)
                local key=clean(sprite.m_scriptName:get())
                local resource=clean(sprite.m_resref:get())
                if #key>0 and #key<=128 and not key:find('%c') and not tonumber(key)
                    and #resource>0 and #resource<=8 and not resource:find('[^A-Z0-9_#%-]') then
                    visit(sprite,key,resource..'.CRE',areaName)
                end
            end
        end)
    end
    function api:candidates(epoch)
        assert(type(epoch)=='string' and #epoch>0)
        local rows={}
        walk(function(_,key,resource,area) rows[#rows+1]={key=key,resource=resource,area=area,epoch=epoch} end)
        return rows
    end
    function api:read(identity)
        local result
        walk(function(sprite,key,resource,area)
            if key~=identity.key or resource~=identity.resource then return end
            assert(not result,'ambiguous-identity')
            result=snapshot({version=1,tick=self:now(),area=area,x=sprite.m_pos.x,y=sprite.m_pos.y,
                actionId=sprite.m_curAction.m_actionID,queuedActions=sprite.m_queuedActions.m_nCount,
                alive=functions.EEex_BAnd(sprite.m_baseStats.m_generalState,0xFC0)==0})
        end)
        return assert(result,'absent-identity')
    end
    return api
end
return M
