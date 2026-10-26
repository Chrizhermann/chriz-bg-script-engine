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
-- One area; its back list holds the ids of the creatures lying down (asleep or dead).
local AREA={m_resref=str('AR0001'),m_lVertSortBack={}}
-- The AI type a sprite would give an object: its IDS values and its instance.
local function aiType(s)
    local t={m_Instance=s.m_id}
    for k,v in pairs(s.m_typeAI) do t[k]=v end
    return t
end
-- A sprite at (x, y) with EA ea; stats by STATS.IDS number.
local function sprite(id,x,y,ea,fields)
    local s={m_id=id,m_pos={x=x,y=y},m_typeAI={m_EnemyAlly=ea,m_General=1,m_Race=1,m_Class=1,m_Specifics=0,
        m_Gender=1,m_Alignment=0},m_baseStats={m_hitPoints=20,m_generalState=0},m_curAction={m_actionID=0},
        m_pArea=AREA,m_timedEffectList=list(),m_equipedEffectList=list(),
        state=0,stats={[1]=20},levels={[7]='S1'},virtual_GetAIType=aiType}
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
    -- The area searches walk the front list only: creatures lying down are not in it.
    local function search(x,y,range,fn)
        for _,id in ipairs(g.order) do
            local o=g.objects[id]
            local dx,dy=o.m_pos.x-x,o.m_pos.y-y
            if dx*dx+dy*dy<=range*range and not o.blocked and not o.lying then fn(o) end
        end
    end
    g.EEex_Sprite_ForAllOfTypeStringInRange=function(s,what,range,fn,los,nonSprites)
        assert(what=='[ANYONE]' and range==448 and los==1 and nonSprites==0)
        search(s.m_pos.x,s.m_pos.y,range,fn)
    end
    -- g.wall: no line of sight from where the searching creature lies.
    g.EEex_Area_ForAllOfTypeStringInRange=function(area,x,y,what,range,fn,los,nonSprites)
        assert(area==AREA and what=='[ANYONE]' and range==448 and los==1 and nonSprites==0)
        g.searchesFromLying=(g.searchesFromLying or 0)+1
        if not g.wall then search(x,y,range,fn) end
    end
    -- An object names g.named; EEex evaluates a copy of it.
    g.EEex_Object_EvalAsAIBase=function(object,caller,checkBackList)
        assert(checkBackList==false and caller~=nil)
        if g.decodeError then error(g.decodeError) end
        return g.named and g.objects[g.named]
    end
    g.EEex_GameState_AddDestroyedListener=function(fn) table.insert(g.listeners.destroyed,fn) end
    g.EEex_Action_AddSpriteStartedActionListener=function(fn) table.insert(g.listeners.started,fn) end
    function g.add(s) g.objects[s.m_id]=s;g.order[#g.order+1]=s.m_id;return s end
    return g
end
local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
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
-- A Spell action at a kind of creature: no instance yet, the class named.
local function typed(resref,class)
    local a=action(31,resref,-1)
    local t=a.m_acteeID
    t.m_EnemyAlly,t.m_General,t.m_Race,t.m_Class,t.m_Specifics,t.m_Gender,t.m_Alignment=2,0,0,class,0,0,0
    function t:Set(other) for k,v in pairs(other) do self[k]=v end end
    return a
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

-- 1. Frames: sides by EA, invisible enemies left out unless the observer sees them (invisible
-- allies stay), details carry IDS values and protections; a creature on no side has no frame.
g.add(sprite(14,150,0,2,{state=0x10}))
g.objects[13].m_timedEffectList={effect(101,0,175),effect(12,5,0)}
local f=sense.frame(g,m1,100,true)
assert(f.area=='AR0001' and f.self.id==1 and #f.allies==1 and f.allies[1].id==2)
assert(#f.enemies==3 and f.enemies[1].id==11 and f.enemies[3].id==13)
assert(#f.enemies[3].protections==1 and f.enemies[3].protections[1].p2==175 and f.enemies[1].ids.general==1)
-- A protection with time left is marked timed; one from an item is not. Drained levels come along.
local spell,worn=effect(102,5,0),effect(120,0,0)
spell.m_durationType,worn.m_durationType=4096,2
g.objects[13].m_timedEffectList={effect(101,0,175),spell}
g.objects[13].m_equipedEffectList={worn}
m2.stats[200]=2
f=sense.frame(g,m1,100,true)
local p=f.enemies[3].protections
assert(#p==3 and p[1].timed==false and p[2].opcode==102 and p[2].timed==true and p[3].opcode==120 and p[3].timed==false)
assert(f.allies[1].drained==2 and f.self.drained==0 and #f.fallen==0)
-- Minimum hit points (MINHITPOINTS, which opcode 208 sets) come with where they come from: the
-- sources of the 208s above 0 in both lists. One without a source names none.
local timed,equipped=g.objects[13].m_timedEffectList,g.objects[13].m_equipedEffectList
local regen,spent,unnamed=effect(208,1,0),effect(208,0,0),effect(208,10,0)
regen.m_sourceRes,spent.m_sourceRes=str('dwtrrg2'),str('OTHER')
g.objects[13].stats[83]=1
g.objects[13].m_timedEffectList,g.objects[13].m_equipedEffectList={regen,spent},{}
f=sense.frame(g,m1,100,true)
assert(f.enemies[3].minHp==1 and f.enemies[3].minHpFrom.DWTRRG2 and f.enemies[3].minHpFrom.OTHER==nil)
assert(f.enemies[1].minHp==0 and f.enemies[1].minHpFrom==nil)
g.objects[13].m_equipedEffectList={unnamed}
f=sense.frame(g,m1,100,true)
assert(f.enemies[3].minHp==1 and f.enemies[3].minHpFrom==nil)
g.objects[13].stats[83]=nil
g.objects[13].m_timedEffectList,g.objects[13].m_equipedEffectList=timed,equipped
-- An invisible ally stays in sight: its side knows where it is.
m2.state=0x400000
f=sense.frame(g,m1,100,false)
assert(#f.allies==1 and f.allies[1].id==2 and f.allies[1].state==0x400000 and #f.enemies==3)
m2.state=0
-- What a backstab needs (F2d): the multiplier, who cannot be backstabbed (IMMUNITY_TO_BACKSTAB,
-- or a barbarian by its kit's two halves) and the direction each one faces, nil when the engine
-- gives none it could mean.
m1.stats[56]=3
g.objects[11].stats[175]=1
local stats12=g.objects[12].m_baseStats
g.objects[12].m_baseStats={m_hitPoints=5,m_generalState=0,m_mageSpecUpperWord=0x4000,m_mageSpecialization=0}
g.objects[13].m_nDirection=12
g.objects[11].m_nDirection=16
f=sense.frame(g,m1,100,false)
assert(f.self.backstab==3 and f.allies[1].backstab==0)
assert(f.enemies[1].backstabImmune==true and f.enemies[2].backstabImmune==true and f.enemies[3].backstabImmune==false)
assert(f.enemies[3].facing==12 and f.enemies[1].facing==nil and f.enemies[2].facing==nil and f.self.facing==nil)
-- Another kit is no barbarian (TRUECLASS sits in the lower half).
g.objects[12].m_baseStats={m_hitPoints=5,m_generalState=0,m_mageSpecUpperWord=0,m_mageSpecialization=0x4000}
assert(sense.frame(g,m1,100,false).enemies[2].backstabImmune==false)
m1.stats[56],g.objects[11].stats[175],g.objects[12].m_baseStats=nil,nil,stats12
g.objects[13].m_nDirection,g.objects[11].m_nDirection=nil,nil
-- Each friend's spell protections come with its guard (lab batch H: an ally's globe kept the
-- engine's Remove Paralysis out).
m2.m_timedEffectList={effect(102,3,0)}
f=sense.frame(g,m1,100,true)
sense.defend(g,f,100,reader,function() return {roles={}} end)
assert(#f.allies[1].protections==1 and f.allies[1].protections[1].p1==3 and #f.self.protections==0)
m2.m_timedEffectList={}
g.objects[13].m_timedEffectList={effect(101,0,175),effect(12,5,0)}
g.objects[13].m_equipedEffectList={}
m2.stats[200]=nil
assert(f.enemies[2].hp==5 and f.enemies[2].maxHp==20 and sense.frame(g,m1,100,false).enemies[1].ids==nil)
-- Lying down (15 asleep, 16 dead) means the back list, which the area search leaves out: a
-- living one counts as seen when the search from where it lies finds the observer.
g.add(sprite(15,120,0,2,{lying=true,state=0x1}))
g.add(sprite(16,130,0,2,{lying=true,state=0x800}))
AREA.m_lVertSortBack={16,15}
f=sense.frame(g,m1,100,true)
assert(#f.enemies==4 and f.enemies[4].id==15 and f.enemies[4].state==0x1 and f.enemies[4].ids.class==1)
assert(g.searchesFromLying==1 and #f.fallen==0)
-- A dead ally seen the same way is listed apart with its state and gender; a dead enemy is not.
g.add(sprite(17,140,0,255,{lying=true,state=0x880}))
AREA.m_lVertSortBack={16,15,17}
f=sense.frame(g,m1,100,true)
assert(#f.fallen==1 and f.fallen[1].id==17 and f.fallen[1].state==0x880 and f.fallen[1].gender==1)
assert(#f.allies==1 and #f.enemies==4 and g.searchesFromLying==3)
AREA.m_lVertSortBack={16,15}
g.wall=true
assert(#sense.frame(g,m1,100,false).enemies==3)
AREA.m_lVertSortBack={16,15,17}
assert(#sense.frame(g,m1,100,false).fallen==0)
g.wall=nil
AREA.m_lVertSortBack={}
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
-- A check-in that cannot read its creature is the director's error, named, not the gate's.
local before=root.inspect().counts.observeErrors
g.objects[4]=setmetatable({m_id=4},{__index=function() error('unreadable') end})
dir:observe({id=4},'mage')
state=root.inspect()
assert(state.director.counts.errors==2 and state.director.lastError:find('^observe: ')~=nil)
assert(state.counts.observeErrors==before)
g.listeners.destroyed[1]()
state=root.inspect().director
assert(next(state.areas)==nil)
assert(start(m1,action(31,'SPWI112',11)).m_acteeID.m_Instance==11)
groups=groups+1

-- 7. A cast at a kind of creature has no instance when it starts: a decoded copy of its object
-- names the target, which a disable then reserves; another member's hold at the same kind
-- goes elsewhere, to the focus 12 (no mage: any legal target will do), taking its AI type.
g.ticks=400
g.objects[12].m_typeAI.m_Class=2
g.objects[13].m_timedEffectList={}
assert(g.BGSE_Claim(m1,'mage','s1')==false and g.BGSE_Claim(m2,'priest','s2')==false)
g.named=11
a=start(m1,typed('TESTHOLD',1))
assert(a.m_acteeID.m_Instance==-1)
state=root.inspect().director
assert(state.areas.AR0001.reservations[1].target==11 and state.areas.AR0001.reservations[1].owner==1)
local redirected=state.counts.redirected
a=start(m2,typed('TESTHOLD',1))
assert(a.m_acteeID.m_Instance==12 and a.m_acteeID.m_Class==2)
local typedRows=0
for _,row in ipairs(rows) do if row.typed then typedRows=typedRows+1 end end
assert(root.inspect().director.counts.redirected==redirected+1 and typedRows>=3)
-- Nothing named: the cast stays as its script chose it; a failing decode is named, not raised.
g.named=nil
assert(start(m1,typed('TESTHOLD',1)).m_acteeID.m_Instance==-1)
g.decodeError='bad object'
assert(start(m1,typed('TESTHOLD',1)).m_acteeID.m_Instance==-1)
state=root.inspect().director
assert(state.counts.errors==3 and state.lastError:find('^decode: ')~=nil)
groups=groups+1

-- 8. A spell's own SPLPROT check, answered by the engine for each enemy (row, enemy, caster,
-- value; here row 110, a spell state): the focus takes the cast unless the engine marks it
-- immune where the original is not; without the engine's answer neither is judged and the cast
-- stays where its script aimed it. A hold at a reserved enemy that is immune to it moves to one
-- it works on.
records.TESTSRDM=spl('TESTSRDM',{fx(324,{res='TESTSRDM',p2=110,p1=41,duration=1}),fx(12,{dice=6,sides=6})})
local calls,immune={},{}
g.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_ruleTables={IsProtectedFromSpell=function(_,row,stats,mine,value)
    calls[#calls+1]={row,stats.m_id,mine.m_id,value}
    if g.splprotError then error(g.splprotError) end
    return (row==110 and immune[stats.m_id]==value) and 1 or 0
end}
local function kept()
    for i=#rows,1,-1 do if rows[i].kind=='keep' and rows[i].member==1 then return rows[i].reason end end
end
g.ticks=500
assert(g.BGSE_Claim(m1,'mage','s1')==false)
assert(start(m1,action(31,'TESTSRDM',11)).m_acteeID.m_Instance==12)
assert(#calls==3 and calls[1][1]==110 and calls[1][2]==11 and calls[1][3]==1 and calls[1][4]==41)
immune[12]=41
assert(start(m1,action(31,'TESTSRDM',11)).m_acteeID.m_Instance==11 and kept()=='focus-filter')
g.splprotError='no binding'
assert(start(m1,action(31,'TESTSRDM',11)).m_acteeID.m_Instance==11 and kept()=='focus-unknown-filter')
state=root.inspect().director
assert(state.counts.marks==6 and state.counts.markFailures==3 and state.markError:find('no binding')~=nil)
assert(state.counts.errors==3)
records.TESTSRHD=spl('TESTSRHD',{fx(324,{res='TESTSRHD',p2=110,p1=29,duration=1}),fx(175,{duration=30})})
g.splprotError=nil
immune={[11]=29}
g.ticks=1000
assert(g.BGSE_Claim(m1,'mage','s1')==false and g.BGSE_Claim(m2,'priest','s2')==false)
assert(start(m2,action(31,'TESTSRHD',11)).m_acteeID.m_Instance==11)
assert(root.inspect().director.areas.AR0001.reservations[1].target==11)
assert(start(m1,action(31,'TESTSRHD',11)).m_acteeID.m_Instance==12)
groups=groups+1

return groups
