-- Trusted native boundary for the explicitly admitted small lab scene only.
-- No enrollment, action queueing, private enemy stats/spellbooks, or retained userdata.
-- Installed API/resource identities and scene/control closure are checked by its caller.
local schema=require('combat-intent.snapshot')
local M={}
local function clean(value) return value:match('^[^%z]*'):upper() end
-- Legacy replay mapping only; an admitted profile may declare its own sources.
local defaultBuffs={
    {tag='buff/mirror',resource='SPWI212',opcode=159},
    {tag='buff/mirror',resource='DWSW212',opcode=159},
    {tag='buff/shield',resource='SPWI114',opcode=328,parameter2=126},
    {tag='buff/shield',resource='DWSW114',opcode=328,parameter2=126},
}
local function integer(value,maximum)
    return type(value)=='number' and value%1==0 and value>=0 and value<=maximum
end
function M.sample(g,observerKey,scene,sceneKey,tick,descriptors)
    schema.assertKey(observerKey);schema.assertKey(sceneKey);schema.assertTick(tick)
    local buffs=descriptors or defaultBuffs
    schema.array(buffs,function(row)
        schema.record(row,{'tag','resource','opcode'},{'parameter2'})
        schema.assertKey(row.tag);schema.value('lastCast',row.resource)
        assert(integer(row.opcode,65535),'invalid buff opcode')
        if row.parameter2~=nil then assert(integer(row.parameter2,4294967295),'invalid buff parameter2') end
    end)
    local observer,keys,ids=nil,{},{}
    for _,row in ipairs(scene) do
        schema.assertKey(row.key);assert(not keys[row.key]);keys[row.key]=true
        local id=row.sprite.m_id;assert(type(id)=='number' and id>=0 and not ids[id],'duplicate native actor');ids[id]=true
        assert(row.relation=='self' or row.relation=='enemy' or row.relation=='ally')
        if row.key==observerKey then assert(row.relation=='self');observer=row.sprite
        else assert(row.relation~='self') end
    end
    assert(observer,'absent observer')
    local seen={}
    -- Numeric flags avoid the EEex wrapper's `false or 1` LOS trap.
    g.EEex_Sprite_ForAllOfTypeStringInRange(observer,'[ANYONE]',448,function(object)
        if object then seen[object.m_id]=true end
    end,1,0)
    local function fact(source,value)
        return {source=source,value=value,observedAt=tick,expiresAt=tick+1,confidence=1}
    end
    local frame={schemaVersion=1,sceneKey=sceneKey,tick=tick,observerKey=observerKey,eligibleAllies={},actors={}}
    for _,row in ipairs(scene) do
        local s=row.sprite;local own=row.key==observerKey
        local state=g.EEex_Sprite_GetState(s)
        -- No see-invisible capability is admitted for this fixture family.
        local visible=own or (seen[s.m_id]==true and g.EEex_BAnd(state,0x10)==0)
        local facts={}
        if visible then
            local source=own and 'self' or 'sight'
            facts.position=fact(source,{x=s.m_pos.x,y=s.m_pos.y})
            facts.alive=fact(source,s.m_baseStats.m_hitPoints>0 and
                g.EEex_BAnd(state,0xFC0)==0 and g.EEex_BAnd(s.m_baseStats.m_generalState,0xFC0)==0)
            local ea=s.m_typeAI.m_EnemyAlly
            -- Current pinned fixture factions, not stale caller labels or a universal faction model.
            local observerEA=observer.m_typeAI.m_EnemyAlly
            local relation='unknown'
            if own then relation='self'
            elseif observerEA==4 then
                relation=ea==255 and 'enemy' or ((ea==2 or ea==4) and 'ally' or 'unknown')
            elseif observerEA==255 then
                relation=ea==255 and 'ally' or ((ea==2 or ea==4) and 'enemy' or 'unknown')
            end
            facts.relation=fact(source,relation)
            if not own then
                -- Documented pixel scale, used only in the near-target open-room shadow envelope.
                local dx,dy=s.m_pos.x-observer.m_pos.x,(s.m_pos.y-observer.m_pos.y)*4/3
                facts.range=fact('sight',math.sqrt(dx*dx+dy*dy)/16)
                facts.lineOfSight=fact('sight',true)
            end
        end
        if own then
            facts.idle=fact('self',s.m_curAction.m_actionID==0 and s.m_queuedActions.m_nCount==0)
            facts.auraReady=fact('self',g.EEex_Sprite_GetCastTimer(s)==-1)
            facts.silenced=fact('self',g.EEex_BAnd(state,0x1000)~=0)
            facts.canAct=fact('self',(s.m_typeAI.m_EnemyAlly==4 or s.m_typeAI.m_EnemyAlly==255) and g.EEex_BAnd(state,0x80102FE9)==0 and
                g.EEex_Sprite_GetStat(s,58)==0 and g.EEex_Sprite_GetStat(s,196)==0)
            local failure=g.EEex_Sprite_GetStat(s,51)
            if type(failure)=='number' and failure>=0 and failure<=100 then facts.castingFailure=fact('self',failure/100) end
            local book,usable={},{}
            local buttons=s:GetQuickButtons(2,false)
            local ok,err=pcall(function()
                g.EEex_Utility_IterateCPtrList(buttons,function(button)
                    if button.m_count>0 and (button.m_bDisabled==0 or button.m_bDisabled==false) then
                        usable[clean(button.m_abilityId.m_res:get())]=true
                    end
                end)
            end)
            g.EEex_Utility_FreeCPtrList(buttons);assert(ok,err)
            for level=0,8 do
                g.EEex_Utility_IterateCPtrList(s.m_memorizedSpellsMage:getReference(level),function(mem)
                    local resource=clean(mem.m_spellId:get())
                    if mem.m_flags%2==1 and usable[resource] then book[#book+1]=resource end
                end)
            end
            table.sort(book);facts.spellbook=fact('self',book)
            local present={}
            g.EEex_Utility_IterateCPtrList(s.m_timedEffectList,function(effect)
                local resource=clean(effect.m_sourceRes:get())
                for _,buff in ipairs(buffs) do
                    if resource==buff.resource and effect.m_effectId==buff.opcode and
                        (buff.parameter2==nil or effect.m_dWFlags==buff.parameter2) then
                        present[buff.tag]=true
                    end
                end
            end)
            local tags={};for tag in pairs(present) do tags[#tags+1]=tag end;table.sort(tags)
            facts.protections=fact('self',tags)
        end
        frame.actors[#frame.actors+1]={key=row.key,visible=visible,detected=visible,facts=facts}
    end
    table.sort(frame.actors,function(a,b) return a.key<b.key end)
    return frame
end
return M
