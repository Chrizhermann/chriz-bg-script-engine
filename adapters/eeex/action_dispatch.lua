-- Only the admitted ordinary SPWI112 actor-target call shape. No global activation.
-- resolve must freshly return the unique actor/target from the exact admitted scene.
local engine=require('adapters.eeex.engine')
local M={}
local function clean(v) return v:match('^[^%z]*'):upper() end
local function name(v) return type(v)=='string' and #v>0 and #v<=32 and not v:find('[^A-Z0-9_#%-]') end
function M.new(g,profile,resolve)
    local native,why=engine.new(g,profile);if not native then return nil,why end
    if type(resolve)~='function' then return nil,'missing-resolver' end
    local queue,timer=g.EEex_Action_QueueResponseStringOnAIBase,g.EEex_Sprite_GetCastTimer
    if type(queue)~='function' or type(timer)~='function' then return nil,'missing-capability' end
    local api={}
    function api:submit(id,request)
        if not native:ready() or g.EEex_Action_QueueResponseStringOnAIBase~=queue or g.EEex_Sprite_GetCastTimer~=timer then return false end
        if type(request)~='table' or getmetatable(request) or request.kind~='spell' or
            request.resource~='SPWI112' or not name(request.targetKey) then return false end
        for key in pairs(request) do if key~='kind' and key~='resource' and key~='targetKey' then return false end end
        local caster,target=resolve(id,request.targetKey)
        if not caster or not target or caster.m_id==target.m_id then return false end
        if clean(caster.m_scriptName:get())~=id.key or clean(caster.m_resref:get())..'.CRE'~=id.resource or
            clean(target.m_scriptName:get())~=request.targetKey then return false end
        if caster.m_typeAI.m_EnemyAlly~=255 or target.m_typeAI.m_EnemyAlly~=4 or
            caster.m_curAction.m_actionID~=0 or caster.m_queuedActions.m_nCount~=0 or timer(caster)~=-1 or
            caster.m_baseStats.m_hitPoints<=0 or target.m_baseStats.m_hitPoints<=0 or
            g.EEex_BAnd(caster.m_baseStats.m_generalState,0xFC0)~=0 or
            g.EEex_BAnd(target.m_baseStats.m_generalState,0xFC0)~=0 then return false end
        -- The current decision/lease checked sensed legality, resource allocation and ownership.
        -- A successful void queue-helper return means submission only, never spell completion.
        queue('SpellRES("SPWI112","'..request.targetKey..'")',caster)
        return true
    end
    return api
end
return M
