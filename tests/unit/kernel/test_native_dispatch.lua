local bridge=require('adapters.eeex.action_dispatch')
local caster={m_id=1,m_scriptName={get=function() return 'B-XPMAG0' end},m_resref={get=function() return 'B-XPMAG0' end},
    m_typeAI={m_EnemyAlly=255},m_baseStats={m_hitPoints=37,m_generalState=0},m_curAction={m_actionID=0},m_queuedActions={m_nCount=0}}
local target={m_id=2,m_scriptName={get=function() return 'B-XPTRG0' end},m_typeAI={m_EnemyAlly=4},
    m_baseStats={m_hitPoints=37,m_generalState=0}}
local calls=0
local g={EEex_Active=true,jit={},Infinity_IsMenuOnStack=function() return true end,
    Infinity_GetTransitionInProgress=function() return false end,Infinity_GetClockTicks=function() return 1 end,
    EEex_Sprite_GetInPortrait=function() end,EEex_Utility_IterateCPtrList=function() end,
    EEex_GameObject_Get=function() end,EEex_GameObject_IsSprite=function() end,EEex_GameObject_CastUserType=function() end,
    EEex_BAnd=function() return 0 end,EEex_Sprite_GetCastTimer=function() return -1 end,
    EEex_Action_QueueResponseStringOnAIBase=function(response,s)
        calls=calls+1;assert(response=='SpellRES("SPWI112","B-XPTRG0")' and s==caster)
    end}
local b=assert(bridge.new(g,'bg273-eeex12-luajit-v1',function() return caster,target end))
local id={adapterId='B-/combat/lab-mage',key='B-XPMAG0',resource='B-XPMAG0.CRE'}
local request={kind='spell',resource='SPWI112',targetKey='B-XPTRG0'}
assert(b:submit(id,request)==true and calls==1)
caster.m_queuedActions.m_nCount=1;assert(b:submit(id,request)==false and calls==1)
caster.m_queuedActions.m_nCount=0
local bad={kind='spell',resource='SPWI114',targetKey='B-XPTRG0'};assert(b:submit(id,bad)==false)
bad.resource='SPWI112';bad.targetKey='x")\nKill(Myself)';assert(b:submit(id,bad)==false)
request.extra=true;assert(b:submit(id,request)==false);request.extra=nil
target.m_baseStats.m_hitPoints=0;assert(b:submit(id,request)==false);target.m_baseStats.m_hitPoints=37
g.EEex_Action_QueueResponseStringOnAIBase=function() error('changed capability') end
assert(b:submit(id,request)==false and calls==1)
-- New resources require an explicit map. Self mode uses the engine's Myself
-- object, never an unquoted DV or an arbitrary actor argument.
local admission={SPWI114={target='self',geometryId='lab/shield'}}
local responseSeen
g.EEex_Action_QueueResponseStringOnAIBase=function(response,s) responseSeen=response;assert(s==caster) end
local own=assert(bridge.new(g,'bg273-eeex12-luajit-v1',function() return caster,caster end,admission))
admission.SPWI114.target='actor' -- constructor owns a frozen copy
local defense={kind='spell',resource='SPWI114',targetKey=id.key}
assert(own:submit(id,defense) and responseSeen=='SpellRES("SPWI114",Myself)')
defense.targetKey='B-XPTRG0';assert(not own:submit(id,defense));defense.targetKey=id.key
local wrong=assert(bridge.new(g,'bg273-eeex12-luajit-v1',function() return caster,target end,
    {SPWI114={target='self',geometryId='lab/shield'}}))
assert(not wrong:submit(id,defense))
assert(not own:submit(id,request))
assert(not bridge.new(g,'bg273-eeex12-luajit-v1',function() end,{SPWI114={target='point',geometryId='x'}}))
return 2
