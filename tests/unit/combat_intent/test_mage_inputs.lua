local sample=require('adapters.eeex.mage_inputs').sample
local perception=require('combat-intent.perception')
local function str(v) return {get=function() return v end} end
local function sprite(id)
    return {m_id=id,m_typeAI={m_EnemyAlly=id==1 and 4 or 255},m_pos={x=id*32,y=100},m_baseStats={m_generalState=0,m_hitPoints=100},
        m_curAction={m_actionID=0},m_queuedActions={m_nCount=0},m_timedEffectList={},
        GetQuickButtons=function(s)
            return {{m_abilityId={m_res=str('SPWI112')},m_count=1,m_bDisabled=s.disabled or 0}}
        end,
        m_memorizedSpellsMage={getReference=function(_,level)
            if level==0 then return {{m_spellId=str('SPWI112'),m_flags=1},{m_spellId=str('SPWI114'),m_flags=0}} end
            return {}
        end}}
end
local a,b=sprite(1),sprite(2)
local g={EEex_Sprite_GetState=function(s) return s.state or 0 end,
    EEex_Sprite_GetCastTimer=function() return -1 end,EEex_Sprite_GetStat=function() return 0 end,
    EEex_Utility_IterateCPtrList=function(list,fn) for _,v in ipairs(list) do fn(v) end end,
    EEex_Utility_FreeCPtrList=function() end,
    EEex_Sprite_ForAllOfTypeStringInRange=function(s,filter,radius,fn,los,others)
        assert(s==a and filter=='[ANYONE]' and radius==448 and los==1 and others==0);fn(a);fn(b)
    end,
    EEex_BAnd=function(n,mask)
        local value,bit=0,1
        while n>0 and mask>0 do if n%2==1 and mask%2==1 then value=value+bit end;n=math.floor(n/2);mask=math.floor(mask/2);bit=bit*2 end
        return value
    end}
local scene={{key='mage/one',sprite=a,relation='self'}, {key='target/one',sprite=b,relation='enemy'}}
local raw=sample(g,'mage/one',scene,'test/scene',10)
local view=perception.build(raw)
assert(#view:get('mage/one','spellbook').value==1)
assert(view:get('mage/one','spellbook').value[1]=='SPWI112')
assert(view:get('target/one','range').value==2)
assert(view:get('target/one','protections').kind=='unknown')
assert(view:get('target/one','spellbook').kind=='unknown')
b.state=16
view=perception.build(sample(g,'mage/one',scene,'test/scene',11))
assert(view:get('target/one','position').kind=='unknown')
a.state=4096
view=perception.build(sample(g,'mage/one',scene,'test/scene',12))
assert(view:get('mage/one','silenced').value==true)
g.EEex_Sprite_GetStat=function(_,stat) return stat==51 and 75 or 0 end
view=perception.build(sample(g,'mage/one',scene,'test/scene',13))
assert(view:get('mage/one','castingFailure').value==.75)
a.m_timedEffectList={{m_sourceRes=str('SPWI114'),m_effectId=328,m_dWFlags=126,m_effectAmount2=0}}
view=perception.build(sample(g,'mage/one',scene,'test/scene',14))
assert(view:get('mage/one','protections').value[1]=='buff/shield')
b.state=0;b.m_typeAI.m_EnemyAlly=4
view=perception.build(sample(g,'mage/one',scene,'test/scene',15))
assert(view:get('target/one','relation').value=='ally')
scene[2].sprite=a
assert(not pcall(sample,g,'mage/one',scene,'test/scene',16))
scene[2].sprite=b;a.disabled=1
view=perception.build(sample(g,'mage/one',scene,'test/scene',17))
assert(#view:get('mage/one','spellbook').value==0)
a.state=0;a.m_typeAI.m_EnemyAlly=255
view=perception.build(sample(g,'mage/one',scene,'test/scene',18))
assert(view:get('mage/one','canAct').value==true)
assert(view:get('target/one','relation').value=='enemy')
b.m_typeAI.m_EnemyAlly=255
view=perception.build(sample(g,'mage/one',scene,'test/scene',19))
assert(view:get('target/one','relation').value=='ally')

-- Default replay still recognizes the two historical tags and helper sources.
a.m_timedEffectList={{m_sourceRes=str('DWSW212'),m_effectId=159,m_dWFlags=17},
    {m_sourceRes=str('SPWI114'),m_effectId=328,m_dWFlags=126},
    {m_sourceRes=str('DWSW114'),m_effectId=328,m_dWFlags=126}}
view=perception.build(sample(g,'mage/one',scene,'test/scene',20))
local tags=view:get('mage/one','protections').value
assert(#tags==2 and tags[1]=='buff/mirror' and tags[2]=='buff/shield')

-- A profile supplies the effective resource identity; effect order and extra
-- unrelated effects do not change the mapped tags or mutate input records.
local descriptors={{tag='buff/shield',resource='SRSHLD1',opcode=328,parameter2=126},
    {tag='buff/mirror',resource='SRMIRR1',opcode=159}}
local unrelated={m_sourceRes=str('OTHER001'),m_effectId=328,m_dWFlags=126}
local matchedShield={m_sourceRes=str('SRSHLD1'),m_effectId=328,m_dWFlags=126}
local matchedMirror={m_sourceRes=str('SRMIRR1'),m_effectId=159,m_dWFlags=42}
a.m_timedEffectList={unrelated,{m_sourceRes=str('SPWI114'),m_effectId=328,m_dWFlags=126},
    {m_sourceRes=str('SRSHLD1'),m_effectId=328,m_dWFlags=125},matchedMirror,
    matchedShield,{m_sourceRes=str('SRMIRR1'),m_effectId=159,m_dWFlags=7},
    {m_sourceRes=str('SRSHLD1'),m_effectId=159,m_dWFlags=126},matchedShield}
view=perception.build(sample(g,'mage/one',scene,'test/scene',21,descriptors))
tags=view:get('mage/one','protections').value
assert(#tags==2 and tags[1]=='buff/mirror' and tags[2]=='buff/shield')
assert(a.m_timedEffectList[1]==unrelated and unrelated.m_effectId==328)
assert(a.m_timedEffectList[5]==matchedShield and a.m_timedEffectList[4]==matchedMirror)
a.m_timedEffectList={matchedShield,unrelated,matchedMirror}
tags=perception.build(sample(g,'mage/one',scene,'test/scene',22,descriptors)):get('mage/one','protections').value
assert(#tags==2 and tags[1]=='buff/mirror' and tags[2]=='buff/shield')
local vanillaDescriptors={{tag='buff/shield',resource='SPWI114',opcode=328,parameter2=126},
    {tag='buff/mirror',resource='SPWI212',opcode=159}}
a.m_timedEffectList={{m_sourceRes=str('SPWI212'),m_effectId=159,m_dWFlags=0},
    {m_sourceRes=str('SPWI114'),m_effectId=328,m_dWFlags=126},unrelated}
tags=perception.build(sample(g,'mage/one',scene,'test/scene',23,vanillaDescriptors)):get('mage/one','protections').value
assert(#tags==2 and tags[1]=='buff/mirror' and tags[2]=='buff/shield')
tags=perception.build(sample(g,'mage/one',scene,'test/scene',23,{})):get('mage/one','protections').value
assert(#tags==0)
for _,bad in ipairs({
    {{tag='',resource='SRSHLD1',opcode=328}},
    {{tag='buff/shield',resource='TOO-LONG1',opcode=328}},
    {{tag='buff/shield',resource='SRSHLD1',opcode=-1}},
    {{tag='buff/shield',resource='SRSHLD1',opcode=328,parameter2='126'}},
    {{tag='buff/shield',resource='SRSHLD1',opcode=328,other=true}},
}) do assert(not pcall(sample,g,'mage/one',scene,'test/scene',24,bad)) end
return 2
