-- EEex side of the fight director against fake engine globals: perception frames, check-ins
-- through the gate, redirecting a member's starting Spell action, switches, errors and loads.
local hook=require('adapters.eeex.hook')
local adapter=require('adapters.eeex.director')
local sense=require('adapters.eeex.sense')
local groups=0

local function band(a,b)
    a,b=a%4294967296,b%4294967296
    local r,bit=0,1
    while a>0 and b>0 do
        local x,y=a%2,b%2
        if x==1 and y==1 then r=r+bit end
        a,b,bit=(a-x)/2,(b-y)/2,bit*2
    end
    return r
end
local function str(v) return {get=function() return v end} end
local function list(t) return t or {} end
-- A sprite at (x, y) with EA ea; stats by STATS.IDS number.
local function sprite(id,x,y,ea,fields)
    local s={m_id=id,m_pos={x=x,y=y},m_typeAI={m_EnemyAlly=ea,m_General=1,m_Race=1,m_Class=1,m_Specifics=0,
        m_Gender=1,m_Alignment=0},m_baseStats={m_hitPoints=20,m_generalState=0},m_curAction={m_actionID=0},
        m_pArea={m_resref=str('AR0001')},m_timedEffectList=list(),m_equipedEffectList=list(),
        state=0,stats={[1]=20},levels={[7]='S1'}}
    for k,v in pairs(fields or {}) do s[k]=v end
    return s
end
local function effect(op,p1,p2,res) return {m_effectId=op,m_effectAmount=p1 or 0,m_dWFlags=p2 or 0,m_res=str(res or '')} end
local function world()
    local g={ticks=100,objects={},order={},listeners={destroyed={},started={}},BGSE_HOOKED={s1='mage'}}
    local time=setmetatable({},{__index=function(_,key) if key=='m_gameTime' then return g.ticks end end})
    g.EngineGlobals={g_pBaldurChitin={m_pObjectGame={m_worldTime=time}}}
    g.EEex_BAnd=band
    g.EEex_GameObject_Get=function(id) return g.objects[id] end
    g.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and (allowDead or band(o.state,0xFC0)==0) end
    g.EEex_Sprite_GetState=function(s) return s.state end
    g.EEex_Sprite_GetStat=function(s,n) return s.stats[n] or 0 end
    g.EEex_Sprite_GetCasterLevelForSpell=function() return 10 end
    g.EEex_Utility_IterateCPtrList=function(t,fn) for _,x in ipairs(t) do if fn(x) then break end end end
    g.EEex_AIBase_GetScriptLevelResRef=function(o,level) return o.levels[level] or '' end
    g.EEex_Sprite_ForAllOfTypeStringInRange=function(s,what,range,fn,los,nonSprites)
        assert(what=='[ANYONE]' and range==448 and los==1 and nonSprites==0)
        for _,id in ipairs(g.order) do
            local o=g.objects[id]
            local dx,dy=o.m_pos.x-s.m_pos.x,o.m_pos.y-s.m_pos.y
            if dx*dx+dy*dy<=range*range and not o.blocked then fn(o) end
        end
    end
    g.EEex_GameState_AddDestroyedListener=function(fn) table.insert(g.listeners.destroyed,fn) end
    g.EEex_Action_AddSpriteStartedActionListener=function(fn) table.insert(g.listeners.started,fn) end
    function g.add(s) g.objects[s.m_id]=s;g.order[#g.order+1]=s.m_id;return s end
    return g
end
local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spl(resref,effects,target)
    return {kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,level=3,
        casting={},abilities={{form=1,flags=0,location=2,target=target or 1,targetCount=0,range=30,minLevel=1,
        speed=3,projectile=2,effects=effects}}}
end
local records={SPWI112=spl('SPWI112',{fx(12,{dice=6,sides=6})}),TESTHOLD=spl('TESTHOLD',{fx(175,{duration=30})}),
    TESTSELF=spl('TESTSELF',{fx(0,{p1=2,target=1})},5)}
local reader={problems={},get=function(kind,resref) if kind=='SPL' then return records[resref] end end,
    lookup=function(kind,key)
        if kind=='PRO' and key==2 then return {kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0} end
        if kind=='SPL' then return records[key] end
    end}
local function action(id,resref,target)
    return {m_actionID=id,m_string1={m_pchData=str(resref or '')},m_specificID=0,m_acteeID={m_Instance=target}}
end

-- The scene: mages 1 and 2 (EA 255) near enemies 11-13 (EA 2); 12 is wounded.
local g=world()
local m1=g.add(sprite(1,0,0,255))
local m2=g.add(sprite(2,50,0,255,{levels={[7]='S2'}}))
g.add(sprite(11,100,0,2));g.add(sprite(12,200,0,2,{m_baseStats={m_hitPoints=5,m_generalState=0}}));g.add(sprite(13,300,0,2))
g.BGSE_HOOKED={s1='mage',s2='priest'}
local rows={}
local dir=adapter.new(g,{reader=reader})
dir:setSink(function(row) rows[#rows+1]=row end)
local root=hook.install(g,{director=dir,version='test'})
assert(root.director==dir and #g.listeners.started==1 and #g.listeners.destroyed==1)
local function start(s,a) g.listeners.started[1](s,a);return a end

-- 1. Frames: sides by EA, the invisible left out unless the observer sees them, details carry
-- IDS values and protections; a creature on no side has no frame.
g.add(sprite(14,150,0,2,{state=0x10}))
g.objects[13].m_timedEffectList={effect(101,0,175),effect(12,5,0)}
local f=sense.frame(g,m1,100,true)
assert(f.area=='AR0001' and f.self.id==1 and #f.allies==1 and f.allies[1].id==2)
assert(#f.enemies==3 and f.enemies[1].id==11 and f.enemies[3].id==13)
assert(#f.enemies[3].protections==1 and f.enemies[3].protections[1].p2==175 and f.enemies[1].ids.general==1)
assert(f.enemies[2].hp==5 and f.enemies[2].maxHp==20 and sense.frame(g,m1,100,false).enemies[1].ids==nil)
m1.stats[81]=1
assert(#sense.frame(g,m1,100,false).enemies==4)
m1.stats[81]=nil
assert(sense.frame(g,sprite(9,0,0,128),100)==nil)
m1.state=0x40000
f=sense.frame(g,m1,100,false)
assert(#f.enemies==0 and #f.allies==0 and f.self.id==1)
m1.state=0
g.objects[14].blocked=true
groups=groups+1

-- 2. Check-ins come with the gate's own questions, at most every 15 ticks per creature.
assert(g.BGSE_Claim(m1,'mage','s1')==false and g.BGSE_Claim(m2,'priest','s2')==false)
local state=root.inspect()
assert(state.declines['no-decider']==2 and state.director.counts.checkIns==2)
assert(state.director.areas.AR0001.members==2 and state.director.areas.AR0001.enemies==3)
g.ticks=105
assert(g.BGSE_Claim(m1,'mage','s1')==false and root.inspect().director.counts.checkIns==2)
groups=groups+1

-- 3. A mage's damage cast at 11 is redirected to the focus, the wounded 12; the cast is the
-- creature's own, only its target changes.
local a=start(m1,action(31,'SPWI112',11))
assert(a.m_acteeID.m_Instance==12 and a.m_actionID==31)
state=root.inspect().director
assert(state.counts.redirected==1 and state.areas.AR0001.focus==12)
-- Not on the focus but more wounded than it: kept.
g.objects[11].m_baseStats.m_hitPoints=2
assert(start(m1,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
g.objects[11].m_baseStats.m_hitPoints=20
groups=groups+1

-- 4. One disabler per target: the first hold on 13 stays and reserves it... except that 13 is
-- immune to holds here, so first a hold on 11; the priest's hold on 11 gives way to 12.
assert(start(m1,action(31,'TESTHOLD',11)).m_acteeID.m_Instance==11)
a=start(m2,action(31,'TESTHOLD',11))
assert(a.m_acteeID.m_Instance==12)
-- 13 is immune to the hold opcode, so with 11 and 12 taken the third hold stays on 11.
local m3=g.add(sprite(3,0,50,255,{levels={[7]='S1'}}))
g.ticks=130
assert(g.BGSE_Claim(m3,'mage','s1')==false)
assert(start(m3,action(31,'TESTHOLD',11)).m_acteeID.m_Instance==11)
local reason
for _,row in ipairs(rows) do if row.kind=='keep' and row.member==3 then reason=row.reason end end
assert(reason=='reserved-no-alternative')
groups=groups+1

-- 5. Outside the director's reach: other actions close a cast, self casts and non-members are
-- left alone, SPELL.IDS numbers name the resref.
start(m1,action(3,'',11))
assert(start(m1,action(31,'TESTSELF',1)).m_acteeID.m_Instance==1)
local outsider=g.add(sprite(20,0,0,255))
assert(start(outsider,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
local byNumber=action(31,'',11);byNumber.m_specificID=2112
assert(adapter.resref(byNumber)=='SPWI112' and adapter.resref(action(31,'spwi112',11))=='SPWI112')
local bad=action(31,'',11);bad.m_specificID=7;assert(adapter.resref(bad)==nil)
groups=groups+1

-- 6. The kill switch and the family switches stop redirects; errors stay inside; a load
-- forgets the group.
root.setEnabled(false)
assert(start(m2,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
root.setEnabled(true)
root.setFamily('priest',false)
assert(start(m2,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
root.setFamily('priest',true)
assert(start(m2,action(31,'SPWI112',11)).m_acteeID.m_Instance==12)
local hostile=setmetatable({},{__index=function() error('freed object') end})
g.listeners.started[1](m1,hostile)
assert(root.inspect().director.counts.errors==1)
g.listeners.destroyed[1]()
state=root.inspect().director
assert(next(state.areas)==nil)
assert(start(m1,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
groups=groups+1

return groups
