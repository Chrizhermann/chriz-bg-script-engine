-- EEex side of the engine's own choice against fake engine globals: taking the round through
-- the gate, the response that casts and sets SCS's round timer, the target named through
-- EEex_Target, holding while the cast is queued, the director's picture of the engine's own
-- casts, outcomes and memory, re-checks, switches, errors and loads.
local runtime=require('adapters.eeex.runtime')
local directors=require('adapters.eeex.director')
local choices=require('adapters.eeex.choice')
local sense=require('adapters.eeex.sense')
local spells=require('combat-intent.spells')
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
local AREA={m_resref=str('AR0001'),m_lVertSortBack={}}
local function memorized(list) return {getReference=function(_,level) return list[level] or {} end} end
-- A sprite at (x, y) with EA ea; stats by STATS.IDS number. book: memorized spells by spell
-- level (0-based) as {resref, ready}; buttons: the resrefs its spell buttons offer.
local function sprite(id,x,y,ea,fields)
    local s={m_id=id,m_pos={x=x,y=y},m_typeAI={m_EnemyAlly=ea,m_General=1,m_Race=1,m_Class=2,m_Specifics=0,
        m_Gender=1,m_Alignment=0},m_baseStats={m_hitPoints=40,m_generalState=0},m_curAction={m_actionID=0},
        m_pArea=AREA,m_timedEffectList={},m_equipedEffectList={},m_resref=str('TEST'..id),m_scriptName=str('c'..id),
        state=0,stats={[1]=40},levels={[7]='S1'},locals={},book={},buttons={},items={},innate={},innateButtons={}}
    s.m_memorizedSpellsMage=memorized(s.book)
    s.m_memorizedSpellsPriest=memorized({})
    s.m_memorizedSpellsInnate=memorized(s.innate)
    s.m_equipment={m_selectedWeapon=10,m_selectedWeaponAbility=0,m_items={get=function(_,slot) return s.items[slot] end}}
    function s:GetQuickButtons(kind)
        local list={}
        if kind==2 then for _,r in ipairs(self.buttons) do list[#list+1]={m_count=1,m_bDisabled=0,m_abilityId={m_res=str(r)}} end end
        if kind==4 then for _,r in ipairs(self.innateButtons) do list[#list+1]={m_count=1,m_bDisabled=0,m_abilityId={m_res=str(r)}} end end
        return list
    end
    for k,v in pairs(fields or {}) do s[k]=v end
    return s
end
local function learn(s,level,resref,count)
    s.book[level]=s.book[level] or {}
    for _=1,count or 1 do table.insert(s.book[level],{m_spellId=str(resref),m_flags=1}) end
    s.buttons[#s.buttons+1]=resref
end
-- An innate ability (the innate list has one level).
local function gift(s,resref)
    s.innate[0]=s.innate[0] or {}
    table.insert(s.innate[0],{m_spellId=str(resref),m_flags=1})
    s.innateButtons[#s.innateButtons+1]=resref
end
local function world()
    local g={ticks=100,objects={},order={},listeners={destroyed={},started={}},queued={},
        BGSE_HOOKED={s1='mage',s2='priest',s3='fighter'}}
    local time=setmetatable({},{__index=function(_,key) if key=='m_gameTime' then return g.ticks end end})
    g.EngineGlobals={g_pBaldurChitin={m_pObjectGame={m_worldTime=time}}}
    g.EEex_BAnd=band
    g.EEex_GameObject_Get=function(id) return g.objects[id] end
    g.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and (allowDead or band(o.state,0xFC0)==0) end
    g.EEex_Sprite_GetState=function(s) return s.state end
    g.EEex_Sprite_GetStat=function(s,n) return s.stats[n] or 0 end
    g.EEex_Sprite_GetCasterLevelForSpell=function() return 10 end
    g.EEex_Sprite_GetLocalInt=function(s,name) return s.locals[name] or 0 end
    g.EEex_Sprite_GetCastTimer=function(s) return s.castTimer or -1 end
    g.EEex_GetUDAux=function(o) o.aux=o.aux or {};return o.aux end
    g.EEex_Utility_GetOrCreateTable=function(t,key) t[key]=t[key] or {};return t[key] end
    g.EEex_Utility_IterateCPtrList=function(t,fn) for _,x in ipairs(t) do if fn(x) then break end end end
    g.EEex_Utility_FreeCPtrList=function() end
    g.EEex_AIBase_GetScriptLevelResRef=function(o,level) return o.levels[level] or '' end
    g.EEex_Action_QueueResponseStringOnAIBase=function(text,o) g.queued[#g.queued+1]={id=o.m_id,text=text} end
    local function search(x,y,range,fn)
        for _,id in ipairs(g.order) do
            local o=g.objects[id]
            local dx,dy=o.m_pos.x-x,o.m_pos.y-y
            if dx*dx+dy*dy<=range*range then fn(o) end
        end
    end
    g.EEex_Sprite_ForAllOfTypeStringInRange=function(s,what,range,fn) search(s.m_pos.x,s.m_pos.y,range,fn) end
    g.EEex_Area_ForAllOfTypeStringInRange=function(area,x,y,what,range,fn) search(x,y,range,fn) end
    g.EEex_Object_EvalAsAIBase=function() return nil end
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
local function spl(resref,level,effects,target,projectile)
    return {kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,level=level,
        casting={},abilities={{form=1,flags=0,location=2,target=target or 1,targetCount=0,range=30,minLevel=1,
        speed=3,projectile=projectile or 2,effects=effects}}}
end
local records={
    TESTBOLT=spl('TESTBOLT',3,{fx(12,{p2=8*65536,dice=6,sides=6})}),
    TESTBALL=spl('TESTBALL',3,{fx(12,{p2=8*65536,dice=6,sides=6})},4,3),
    TESTHEAL=spl('TESTHEAL',4,{fx(17,{p1=20})})}
local POTION={kind='ITM',resref='TESTPOTN',flags=0,abilities={{form=3,flags=0,location=3,target=5,range=1,speed=0,
    projectile=1,effects={fx(17,{p1=20,target=1})}}}}
-- Weapons: a magical long sword, a bow and its arrows.
local function weapon(resref,fields,ability)
    local a={attackType=1,dice=1,sides=8,damageBonus=0,range=1,thac0=0,effects={}}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='ITM',resref=resref,flags=0x40,enchantment=0,abilities={a}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local ITEMS={TESTPOTN=POTION,TESTSWRD=weapon('TESTSWRD'),
    TESTBOW=weapon('TESTBOW',{flags=0},{attackType=4,dice=0,sides=0,range=100}),
    TESTARRW=weapon('TESTARRW',{flags=0,enchantment=1},{attackType=2,dice=1,sides=6,damageBonus=1})}
local reader={problems={},get=function(kind,resref)
        if kind=='SPL' then return records[resref] end
        if kind=='ITM' then return ITEMS[resref] end
    end,
    lookup=function(kind,key)
        if kind=='PRO' and key==2 then return {kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0} end
        if kind=='PRO' and key==3 then
            return {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=64,coneWidth=0}
        end
        if kind=='SPL' then return records[key] end
    end}
local function action(id,resref,target)
    return {m_actionID=id,m_string1={m_pchData=str(resref or '')},m_specificID=0,m_acteeID={m_Instance=target}}
end

-- The scene: mage 1 (EA 255) with two Fire Bolts; enemies 11-13 (EA 2), 12 badly wounded.
local g=world()
local m1=g.add(sprite(1,0,0,255))
learn(m1,2,'TESTBOLT',2)
local e11=g.add(sprite(11,100,0,2))
local e12=g.add(sprite(12,200,0,2,{m_baseStats={m_hitPoints=5,m_generalState=0}}))
local e13=g.add(sprite(13,300,0,2))
local dir=directors.new(g,{reader=reader})
local ch=choices.new(g,{reader=reader,director=dir,seed=7})
local rows,picture={},{}
ch:setSink(function(row) rows[#rows+1]=row end)
dir:setSink(function(row) picture[#picture+1]=row end)
local root=runtime.install(g,{director=dir,choice=ch,version='test'})
assert(root.choice==ch and root.director==dir and #g.listeners.started==1)
local function claim(s,family,script,tick)
    g.ticks=tick
    return g.BGSE_Claim(s,family,script)
end
local function start(s,a) g.listeners.started[1](s,a);return a end
local function last(kind) for i=#rows,1,-1 do if rows[i].kind==kind then return rows[i] end end end

-- 1. Formats and the timer: SCS's round timer is set before the cast; the target is named by
-- EEex_Target; a game timer runs while it holds a later game time.
assert(choices.response({resref='SPWI304',target=12})==
    'SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nSpellRES("SPWI304",EEex_Target("BGSE"))')
assert(choices.response({resref='SPWI304',point={x=430,y=107}})==
    'SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nSpellPointRES("SPWI304",[430.107])')
assert(choices.response({resref='SPPR502',self=true}):find('SpellRES%("SPPR502",Myself%)')~=nil)
assert(choices.response({resref='BAD"X',target=1})==nil and choices.response({resref='SPWI304',point={x=-1,y=2}})==nil)
assert(choices.response({resref='SPWI304'})==nil)
m1.locals.castspell=150
assert(choices.timerRunning(g,m1,100) and not choices.timerRunning(g,m1,150))
m1.locals.castspell=nil
assert(choices.timerRunning({},m1,100))
groups=groups+1

-- 2. The round is the engine's: the Fire Bolt goes to the director's focus, the wounded 12,
-- which it kills; the response sets SCS's timer and casts at EEex_Target, which names 12.
assert(claim(m1,'mage','s1',100)==true)
local c=last('choice')
assert(c.spell=='TESTBOLT' and c.target==12 and c.focus==12 and #c.top==3 and c.top[1].target==12)
g.BGSE_Act(m1)
assert(#g.queued==1 and g.queued[1].id==1 and g.queued[1].text:find('SpellRES%("TESTBOLT",EEex_Target%("BGSE"%)%)')~=nil)
assert(m1.aux.EEex_Target.BGSE==12)
local state=root.inspect()
assert(state.counts.acted==1 and state.choice.counts.claims==1 and state.choice.counts.performed==1 and state.choice.pending==1)
-- Queued, not started: the next pass holds, so SCS's blocks cannot replace the cast.
assert(claim(m1,'mage','s1',101)==true)
g.BGSE_Act(m1)
assert(#g.queued==1 and root.inspect().counts.held==1 and root.inspect().choice.counts.holds==1)
groups=groups+1

-- 3. The cast starts: the director records it as the engine's own and never advises on it.
local a=start(m1,action(31,'TESTBOLT',-1))
assert(a.m_acteeID.m_Instance==-1)
local own
for _,row in ipairs(picture) do if row.kind=='start' and row.own then own=row end end
assert(own and own.spell=='TESTBOLT' and own.target==12 and own.role=='damage')
state=root.inspect()
assert(state.choice.counts.started==1 and state.choice.running==1 and state.director.counts.own==1 and
    state.director.counts.advised==0)
-- While it runs, SCS's round timer (set by the response) leaves the round to SCS's filler.
m1.m_curAction=action(31,'TESTBOLT',12)
m1.locals.castspell=190
assert(claim(m1,'mage','s1',120)==false and root.inspect().choice.reasons.timer==1)
-- It ends; 30 ticks later its effect is judged: 12 lost its hit points.
m1.m_curAction={m_actionID=0}
e12.m_baseStats.m_hitPoints=0
assert(claim(m1,'mage','s1',130)==false and root.inspect().choice.judging==1)
m1.locals.castspell=0
assert(claim(m1,'mage','s1',165)==true)
state=root.inspect().choice
assert(state.counts.hits==1 and state.judging==0 and last('outcome').hit==true)
-- With 12 dead the focus moves on to the nearer 11, and so does the next bolt.
c=last('choice');assert(c.target==11 and c.focus==11)
groups=groups+1

-- 4. A bolt that leaves its target untouched, with no save or magic resistance to blame, met
-- an immunity: the mage remembers it and turns to 13. An interrupted cast says nothing.
g.BGSE_Act(m1)
assert(m1.aux.EEex_Target.BGSE==11)
start(m1,action(31,'TESTBOLT',-1))
m1.m_curAction=action(31,'TESTBOLT',11);m1.locals.castspell=300
assert(claim(m1,'mage','s1',200)==false)
m1.m_curAction={m_actionID=0}
assert(claim(m1,'mage','s1',201)==false)
m1.locals.castspell=0
assert(claim(m1,'mage','s1',235)==true)
state=root.inspect().choice
assert(state.counts.misses==1 and state.remembered==1 and last('outcome').hit==false and last('outcome').misses==1)
c=last('choice');assert(c.target==13)
g.BGSE_Act(m1)
start(m1,action(31,'TESTBOLT',-1))
-- Damage ends the cast four ticks in, long before its casting time.
start(m1,action(3,'',13))
m1.locals.castspell=0
assert(claim(m1,'mage','s1',275)==true)
state=root.inspect().choice
assert(state.counts.interrupted==1 and state.counts.misses==1 and state.counts.hits==1)
groups=groups+1

-- 5. Right before acting the target is checked again: one that died meanwhile skips the act
-- without an error or a backoff; a cast queued that never starts is given up.
local errors=root.inspect().counts.errors
c=last('choice');assert(c.target==13)
e13.state=0x800
g.BGSE_Act(m1)
state=root.inspect()
assert(state.counts.skipped==1 and state.counts.errors==errors and state.choice.counts.skipped==1 and state.choice.pending==0)
e13.state=0
local queued=#g.queued
assert(claim(m1,'mage','s1',280)==true)
g.BGSE_Act(m1)
assert(#g.queued==queued+1 and root.inspect().choice.pending==1)
assert(claim(m1,'mage','s1',300)==true and root.inspect().choice.counts.holds==2)
g.BGSE_Act(m1)
assert(claim(m1,'mage','s1',330)==true and root.inspect().choice.counts.lost==1)
assert(last('lost').spell=='TESTBOLT' and last('lost').queued==280)
groups=groups+1

-- 6. SCS keeps the round: the switch off, a silenced mage, a cast already running, families the
-- choice does not drive, a creature on the good side. A busy casting aura does not: the cast
-- waits for it.
g.BGSE_Act(m1)
start(m1,action(31,'TESTBOLT',-1))
start(m1,action(0,'',0))
root.setChoice(false)
assert(claim(m1,'mage','s1',400)==false and root.inspect().choice.reasons.off==1)
root.setChoice(true)
m1.state=0x1000
assert(claim(m1,'mage','s1',401)==false and root.inspect().choice.reasons['urgent-silenced']==1)
m1.state=0
m1.castTimer=40
assert(claim(m1,'mage','s1',402)==true and root.inspect().choice.reasons.aura==nil)
m1.castTimer=nil
m1.m_curAction=action(31,'SPWI112',11)
assert(claim(m1,'mage','s1',403)==false and root.inspect().choice.reasons.casting==1)
m1.m_curAction={m_actionID=0}
local fighter=g.add(sprite(4,0,40,255,{levels={[7]='S3'}}))
learn(fighter,2,'TESTBOLT')
assert(claim(fighter,'fighter','s3',404)==false and root.inspect().choice.reasons.family==1)
local friend=g.add(sprite(5,0,-40,2))
learn(friend,2,'TESTBOLT')
assert(claim(friend,'mage','s1',405)==false and root.inspect().choice.reasons.side==1)
groups=groups+1

-- 7. An area spell at a point: the Fireball goes where it catches the whole cluster (the
-- middle ranks first; equal options are drawn at random), as a SpellPointRES, and its start
-- at that point is the engine's own.
local m6=g.add(sprite(6,0,100,255))
learn(m6,2,'TESTBALL')
local f21=g.add(sprite(21,300,100,2));local f22=g.add(sprite(22,330,100,2));g.add(sprite(23,360,100,2))
for _,e in ipairs({e11,e12,e13}) do e.state=0x800 end
assert(claim(m6,'mage','s1',410)==true)
c=last('choice')
assert(c.spell=='TESTBALL' and c.mode=='point-area' and #c.hits==3 and c.point.y==100 and c.target==nil)
assert(c.top[1].point.x==330 and c.top[1].hits==3)
g.BGSE_Act(m6)
assert(g.queued[#g.queued].text:find('SpellPointRES%("TESTBALL",%['..c.point.x..'%.100%]%)')~=nil)
start(m6,action(95,'TESTBALL',-1))
assert(root.inspect().choice.counts.started>=5)
groups=groups+1

-- 8. A priest leaves the round to SCS while an ally is badly hurt and healing is ready.
local p7=g.add(sprite(7,0,140,255,{levels={[7]='S2'}}))
learn(p7,3,'TESTBOLT');learn(p7,3,'TESTHEAL')
f21.state=0;f22.state=0
local hurt=g.add(sprite(8,20,140,255,{m_baseStats={m_hitPoints=10,m_generalState=0}}))
assert(claim(p7,'priest','s2',420)==false and root.inspect().choice.reasons['urgent-ally-hurt']==1)
hurt.m_baseStats.m_hitPoints=40
assert(claim(p7,'priest','s2',421)==true)
groups=groups+1

-- 9. Errors stay inside: a creature whose spellbook cannot be read, and a broken decision,
-- leave the round to SCS without a gate error; a load forgets every queued cast.
local before=root.inspect().counts.errors
local broken=g.add(sprite(9,0,180,255))
broken.m_memorizedSpellsMage={getReference=function() error('unreadable') end}
assert(claim(broken,'mage','s1',430)==false)
state=root.inspect()
assert(state.counts.errors==before and state.choice.counts.errors==1 and state.choice.lastError:find('^book: ')~=nil)
assert(ch:decide({id=1},nil)==nil)
assert(claim(m1,'mage','s1',440)==true)
g.BGSE_Act(m1)
assert(root.inspect().choice.pending>=1)
g.listeners.destroyed[1]()
state=root.inspect().choice
assert(state.pending==0 and state.running==0 and state.remembered==0)
groups=groups+1

-- 10. A spell that lands its effects through a sub-spell: they name the sub-spell as their
-- source, so a target that kept its hit points but carries them was still hit, not immune.
records.TESTACID=spl('TESTACID',3,{fx(146,{res='TESTACDB'})})
records.TESTACDB=spl('TESTACDB',3,{fx(12,{p2=8*65536,dice=6,sides=6}),fx(142,{p2=102,duration=30})})
local g2=world()
local caster=g2.add(sprite(1,0,0,255))
learn(caster,2,'TESTACID')
local victim=g2.add(sprite(11,100,0,2))
local dir2=directors.new(g2,{reader=reader})
local ch2=choices.new(g2,{reader=reader,director=dir2,seed=3})
local root2=runtime.install(g2,{director=dir2,choice=ch2,version='test'})
g2.ticks=100
assert(g2.BGSE_Claim(caster,'mage','s1')==true)
g2.BGSE_Act(caster)
assert(caster.aux.EEex_Target.BGSE==11)
g2.listeners.started[1](caster,action(31,'TESTACID',-1))
caster.m_curAction=action(31,'TESTACID',11);caster.locals.castspell=190
g2.ticks=120;assert(g2.BGSE_Claim(caster,'mage','s1')==false)
caster.m_curAction={m_actionID=0}
victim.m_timedEffectList={{m_effectId=142,m_sourceRes=str('TESTACDB')}}
g2.ticks=130;assert(g2.BGSE_Claim(caster,'mage','s1')==false)
caster.locals.castspell=0
g2.ticks=165;assert(g2.BGSE_Claim(caster,'mage','s1')==true)
state=root2.inspect().choice
assert(state.counts.hits==1 and state.counts.misses==0 and state.remembered==0)
groups=groups+1

-- 11. A disable the engine chose claims its target in the group at once: a second priest
-- deciding before the first one's hold is even queued takes the other enemy. The start turns
-- the claim into the cast's reservation; a cast given up before it is queued releases it.
records.TESTHOLD=spl('TESTHOLD',2,{fx(175,{duration=30})})
local g3=world()
local q1=g3.add(sprite(1,0,0,255,{levels={[7]='S2'}}))
local q2=g3.add(sprite(2,0,40,255,{levels={[7]='S2'}}))
learn(q1,1,'TESTHOLD');learn(q2,1,'TESTHOLD')
g3.add(sprite(31,100,0,2))
local e32=g3.add(sprite(32,100,60,2,{m_baseStats={m_hitPoints=20,m_generalState=0}}))
local dir3=directors.new(g3,{reader=reader})
local ch3=choices.new(g3,{reader=reader,director=dir3,seed=5})
local rows3={}
ch3:setSink(function(row) rows3[#rows3+1]=row end)
local root3=runtime.install(g3,{director=dir3,choice=ch3,version='test'})
local function choiceOf(member) for i=#rows3,1,-1 do if rows3[i].kind=='choice' and rows3[i].member==member then return rows3[i] end end end
g3.ticks=100
assert(g3.BGSE_Claim(q1,'priest','s2')==true)
assert(choiceOf(1).target==31 and choiceOf(1).castKind=='disable')
g3.ticks=102
assert(g3.BGSE_Claim(q2,'priest','s2')==true)
assert(choiceOf(2).target==32)
local held=root3.inspect().director.areas.AR0001.reservations
assert(#held==2 and held[1].target==31 and held[1].owner==1 and held[1].claim==true and held[2].owner==2)
g3.BGSE_Act(q1)
g3.listeners.started[1](q1,action(31,'TESTHOLD',-1))
held=root3.inspect().director.areas.AR0001.reservations
assert(#held==2 and held[1].target==31 and held[1].owner==1 and held[1].claim==nil)
e32.state=0x800
g3.BGSE_Act(q2)
held=root3.inspect().director.areas.AR0001.reservations
assert(#held==1 and held[1].owner==1 and root3.inspect().choice.counts.skipped==1)
groups=groups+1

-- 12. Labs can trace every decline: each reaches the sink as a 'declined' row with its reason,
-- never the log.
local traced={}
ch3:setSink(function(row) traced[#traced+1]=row end)
ch3:setTrace(true)
q1.locals.castspell=500
g3.ticks=200
assert(g3.BGSE_Claim(q1,'priest','s2')==false)
local t=traced[#traced]
assert(t.kind=='declined' and t.reason=='timer' and t.member==1 and t.family=='priest' and t.tick==200)
local logged=false
for _,row in ipairs(root3.inspect().choice.log) do if row.kind=='declined' then logged=true end end
assert(not logged and root3.inspect().choice.trace==true)
-- With no option at all, the row counts why: the second priest's only enemy left is held
-- by the first one's reservation.
g3.ticks=202
assert(g3.BGSE_Claim(q2,'priest','s2')==false)
t=traced[#traced]
assert(t.reason=='no-option' and t.member==2 and t.rejected['no-worth']==1)
ch3:setTrace(false)
local n=#traced
g3.ticks=201
assert(g3.BGSE_Claim(q1,'priest','s2')==false and #traced==n)
groups=groups+1

-- 13. A cast queued while the casting aura runs waits for it: the creature holds while the aura
-- runs and pendingTicks after it was last seen busy, then the cast is given up.
local g4=world()
local w=g4.add(sprite(1,0,0,255))
learn(w,2,'TESTBOLT',3)
g4.add(sprite(11,100,0,2))
local dir4=directors.new(g4,{reader=reader})
local ch4=choices.new(g4,{reader=reader,director=dir4,seed=9})
local root4=runtime.install(g4,{director=dir4,choice=ch4,version='test'})
w.castTimer=60
g4.ticks=100
assert(g4.BGSE_Claim(w,'mage','s1')==true)
g4.BGSE_Act(w)
assert(#g4.queued==1 and root4.inspect().choice.pending==1)
g4.ticks=180
assert(g4.BGSE_Claim(w,'mage','s1')==true and root4.inspect().choice.counts.holds==1)
w.castTimer=nil
g4.ticks=225
assert(g4.BGSE_Claim(w,'mage','s1')==true and root4.inspect().choice.counts.holds==2)
g4.ticks=226
assert(g4.BGSE_Claim(w,'mage','s1')==true and root4.inspect().choice.counts.lost==1)
groups=groups+1

-- 14. Time Stop: a cast that ends while another creature's Time Stop freezes its target is
-- judged only outcomeTicks after time resumes, when what reached the target takes effect. A
-- target immune to Time Stop is judged as usual.
local g5=world()
local game5=g5.EngineGlobals.g_pBaldurChitin.m_pObjectGame
local z=g5.add(sprite(1,0,0,255))
learn(z,2,'TESTBOLT',3)
local t11=g5.add(sprite(11,100,0,2))
local dir5=directors.new(g5,{reader=reader})
local ch5=choices.new(g5,{reader=reader,director=dir5,seed=5})
local root5=runtime.install(g5,{director=dir5,choice=ch5,version='test'})
local function cast5(tick)
    g5.ticks=tick;z.locals.castspell=0
    assert(g5.BGSE_Claim(z,'mage','s1')==true)
    g5.BGSE_Act(z)
    assert(z.aux.EEex_Target.BGSE==11)
    g5.listeners.started[1](z,action(31,'TESTBOLT',-1))
    -- From here SCS's round timer runs, so each pass only judges.
    z.m_curAction=action(31,'TESTBOLT',11);z.locals.castspell=100000
end
local function pass5(tick) g5.ticks=tick;assert(g5.BGSE_Claim(z,'mage','s1')==false);return root5.inspect().choice end
cast5(100)
-- The mage stops time; its bolt ends with its next action while 11 is frozen.
game5.m_nTimeStop,game5.m_nTimeStopCaster=539,1
g5.ticks=150
z.m_curAction={m_actionID=0}
g5.listeners.started[1](z,action(63,'',-1))
local s5=pass5(200)
assert(s5.judging==1 and s5.counts.frozen==1 and s5.counts.hits==0 and s5.counts.misses==0)
s5=pass5(400)
assert(s5.judging==1 and s5.counts.hits==0 and s5.counts.misses==0)
-- Time resumes and the damage lands; the judgement comes outcomeTicks after time was seen
-- running again.
game5.m_nTimeStop,game5.m_nTimeStopCaster=0,-1
t11.m_baseStats.m_hitPoints=20
s5=pass5(450);assert(s5.judging==1 and s5.counts.hits==0)
s5=pass5(479);assert(s5.judging==1 and s5.counts.hits==0)
s5=pass5(480);assert(s5.judging==0 and s5.counts.hits==1 and s5.counts.misses==0 and s5.counts.frozen==1)
-- An immune target is judged as usual, Time Stop or not: here the bolt left it untouched.
t11.m_derivedStats={m_bImmuneToTimeStop=1}
cast5(600)
game5.m_nTimeStop,game5.m_nTimeStopCaster=539,1
g5.ticks=650
z.m_curAction={m_actionID=0}
g5.listeners.started[1](z,action(63,'',-1))
s5=pass5(679);assert(s5.judging==1)
s5=pass5(680);assert(s5.judging==0 and s5.counts.misses==1 and s5.counts.frozen==1)
groups=groups+1

-- 15. The ready spells' own SPLPROT checks, answered by the engine for each enemy it sees (row,
-- enemy, caster, value): an enemy the engine marks immune is no target. When the engine gives
-- no answer, the check is not judged, the spell stays an option and the first failure is
-- recorded once.
records.TESTSRBO=spl('TESTSRBO',3,{fx(324,{res='TESTSRBO',p2=110,p1=41,duration=1}),fx(12,{p2=8*65536,dice=6,sides=6})})
local g6=world()
local calls={}
g6.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_ruleTables={IsProtectedFromSpell=function(_,row,stats,mine,value)
    calls[#calls+1]={row,stats.m_id,mine.m_id,value}
    if g6.splprotError then error(g6.splprotError) end
    return (row==110 and value==41 and stats.state41) and 1 or 0
end}
local c6=g6.add(sprite(1,0,0,255))
learn(c6,2,'TESTSRBO',3)
g6.add(sprite(11,100,0,2,{state41=true}))
g6.add(sprite(12,200,0,2))
local dir6=directors.new(g6,{reader=reader})
local ch6=choices.new(g6,{reader=reader,director=dir6,seed=3})
local root6=runtime.install(g6,{director=dir6,choice=ch6,version='test'})
local traced6={}
ch6:setSink(function(row) traced6[#traced6+1]=row end)
g6.ticks=100
assert(g6.BGSE_Claim(c6,'mage','s1')==true)
g6.BGSE_Act(c6)
assert(c6.aux.EEex_Target.BGSE==12)
assert(#calls==2 and calls[1][1]==110 and calls[1][2]==11 and calls[1][3]==1 and calls[1][4]==41 and calls[2][2]==12)
local s6=root6.inspect().choice
assert(s6.counts.marks==2 and s6.counts.markFailures==0 and s6.markError==false)
g6.splprotError='no binding'
for _,tick in ipairs({300,500}) do
    g6.ticks=tick;c6.locals.castspell=0;c6.m_curAction={m_actionID=0}
    assert(g6.BGSE_Claim(c6,'mage','s1')==true)
end
s6=root6.inspect().choice
assert(s6.counts.claims==3 and s6.counts.markFailures==4 and s6.markError:find('no binding')~=nil)
local failures=0
for _,row in ipairs(traced6) do if row.kind=='error' and row.where=='splprot' then failures=failures+1 end end
assert(failures==1 and s6.counts.errors==0)
groups=groups+1

-- 16. Defences (third slice). Two fighters with magical long swords at a mage: the engine reads
-- their weapons and what protects the mage, casts Stoneskin on the mage itself, judges that it
-- took, and waits out the redefend pause, attacking in between. A defence the creature's own
-- script starts begins the pause as well. Effects about to end do not protect.
records.TESTSTON=spl('TESTSTON',4,{fx(218,{p1=8,duration=600,target=1})},5,1)
records.TESTSTON.abilities[1].speed=1
local g7=world()
local function armed(s,slot,resref)
    s.items[slot]={cResRef=str(resref)};s.m_equipment.m_selectedWeapon=slot
    s.stats[8],s.stats[7]=2,10
    return s
end
local function sturdy(s) s.m_baseStats.m_hitPoints=80;s.stats[1]=80;return s end
local mage=g7.add(sprite(1,0,0,255))
mage.stats[2]=8
learn(mage,2,'TESTBOLT',2);learn(mage,3,'TESTSTON')
local swordA=g7.add(sturdy(armed(sprite(11,40,0,2,{m_curAction=action(3,'',1)}),35,'TESTSWRD')))
g7.add(sturdy(armed(sprite(12,50,0,2,{m_curAction=action(3,'',1)}),35,'TESTSWRD')))
local dir7=directors.new(g7,{reader=reader})
local ch7=choices.new(g7,{reader=reader,director=dir7,seed=11})
local rows7={}
ch7:setSink(function(row) rows7[#rows7+1]=row end)
local root7=runtime.install(g7,{director=dir7,choice=ch7,version='test'})
local function last7(kind,member)
    for i=#rows7,1,-1 do if rows7[i].kind==kind and (member==nil or rows7[i].member==member) then return rows7[i] end end
end
-- What the engine reads: attacks, THAC0 and damage of each sword; a bow shoots its arrows.
local seen=sense.attack(g7,swordA,reader)
assert(seen.apr==2 and seen.thac0==10 and seen.damage==4.5 and seen.magical==true and not seen.ranged)
local archer=armed(sprite(13,500,0,2),35,'TESTBOW')
archer.items[11]={cResRef=str('TESTARRW')};archer.stats[8]=7;archer.stats[86]=2
seen=sense.attack(g7,archer,reader)
assert(seen.apr==1.5 and seen.ranged and seen.range==1600 and seen.damage==0+3.5+1+2 and seen.magical==true)
g7.ticks=100
assert(g7.BGSE_Claim(mage,'mage','s1')==true)
local d7=last7('choice')
assert(d7.spell=='TESTSTON' and d7.castKind=='defence' and d7.mode=='self' and d7.hits[1]==1 and d7.top[1].kind=='defence')
g7.BGSE_Act(mage)
assert(g7.queued[#g7.queued].text:find('SpellRES%("TESTSTON",Myself%)')~=nil)
assert(root7.inspect().choice.counts.defences==1 and root7.inspect().choice.guardError==false)
g7.listeners.started[1](mage,action(31,'TESTSTON',1))
mage.m_curAction=action(31,'TESTSTON',1);mage.locals.castspell=190
-- The cast ends; the mage carries its skins.
g7.ticks=110
mage.m_curAction={m_actionID=0}
mage.m_timedEffectList={{m_effectId=218,m_durationType=4096,m_duration=110+9000,m_effectAmount=8,m_dWFlags=0,
    m_res=str(''),m_sourceRes=str('TESTSTON')}}
mage.stats[88]=8
assert(g7.BGSE_Claim(mage,'mage','s1')==false)
g7.ticks=141
assert(g7.BGSE_Claim(mage,'mage','s1')==false)
local s7=root7.inspect().choice
assert(s7.counts.guarded==1 and s7.counts.unguarded==0 and last7('guard').landed==1 and last7('guard').friends==1)
-- Within the pause, and with the skins up, the mage attacks.
g7.ticks=200;mage.locals.castspell=0
assert(g7.BGSE_Claim(mage,'mage','s1')==true)
d7=last7('choice')
assert(d7.spell=='TESTBOLT' and d7.castKind=='damage')
-- What protects the mage: the skins and their source; an effect that ends within six seconds
-- does not count.
local function effectsOf(record) return spells.classify(record,1,reader.lookup,{level=1}) end
local guard=sense.guard(g7,mage,200,effectsOf)
assert(guard.stoneskins==8 and guard.sources.TESTSTON and guard.roles.protection.stoneskin==8)
mage.m_timedEffectList[1].m_duration=200+80
guard=sense.guard(g7,mage,200,effectsOf)
assert(guard.sources.TESTSTON==nil and guard.roles.protection==nil)
-- A defence the creature's own script starts begins the pause too: a second mage under one
-- fighter would cast Stoneskin, but its script has just cast it.
local other=g7.add(sprite(2,0,600,255))
other.stats[2]=8
learn(other,2,'TESTBOLT',2);learn(other,3,'TESTSTON')
g7.add(sturdy(armed(sprite(14,40,600,2,{m_curAction=action(3,'',2)}),35,'TESTSWRD')))
other.locals.castspell=400
g7.ticks=300
assert(g7.BGSE_Claim(other,'mage','s1')==false)
g7.listeners.started[1](other,action(31,'TESTSTON',2))
other.locals.castspell=0
g7.ticks=316
assert(g7.BGSE_Claim(other,'mage','s1')==true and last7('choice',2).spell=='TESTBOLT')
-- Labs can weigh no defences (caution 0): the first mage, its skins gone and the pause over,
-- attacks the swordsmen, now near death; a bad profile change is refused and changes nothing.
mage.m_timedEffectList={};mage.stats[88]=0
for _,id in ipairs({11,12}) do g7.objects[id].m_baseStats.m_hitPoints=20 end
assert(ch7:setMind({caution=-1})==false)
assert(ch7:setMind({caution=0})==true)
g7.ticks=400;mage.locals.castspell=0;mage.m_curAction={m_actionID=0}
assert(g7.BGSE_Claim(mage,'mage','s1')==true and last7('choice',1).spell=='TESTBOLT')
local weighed=false
for _,o in ipairs(last7('choice',1).top) do if o.kind=='defence' then weighed=true;assert(o.score<0) end end
assert(weighed)
assert(ch7:setMind(nil)==true)
groups=groups+1

-- 17. Openers (D2a). A mage with Time Stop, Improved Alacrity and two holds stops time first
-- and quickens itself as the first cast in its own stop; the hold it starts in the stop counts
-- as landed, so the next goes to the other enemy; when time resumes that list is dropped.
records.TESTSTOP=spl('TESTSTOP',9,{fx(231,{target=1,duration=36})},5,1)
records.TESTALAC=spl('TESTALAC',9,{fx(188,{target=1,p2=1,duration=12})},5,1)
records.TESTHOLD=spl('TESTHOLD',2,{fx(175,{p2=3,p1=1,duration=30,save=1})})
local g8=world()
local game8=g8.EngineGlobals.g_pBaldurChitin.m_pObjectGame
local caster=g8.add(sprite(1,0,0,255))
learn(caster,8,'TESTSTOP');learn(caster,8,'TESTALAC');learn(caster,1,'TESTHOLD',2)
for _,id in ipairs({11,12}) do g8.add(sprite(id,id*10,0,2)).stats[13]=20 end
local dir8=directors.new(g8,{reader=reader})
local ch8=choices.new(g8,{reader=reader,director=dir8,seed=13})
local rows8={}
ch8:setSink(function(row) rows8[#rows8+1]=row end)
runtime.install(g8,{director=dir8,choice=ch8,version='test'})
local function last8(kind) for n=#rows8,1,-1 do if rows8[n].kind==kind then return rows8[n] end end end
local function turn8(tick,resref)
    g8.ticks=tick;caster.locals.castspell=0;caster.m_curAction={m_actionID=0}
    assert(g8.BGSE_Claim(caster,'mage','s1')==true)
    local c8=last8('choice')
    assert(c8.spell==resref,tostring(c8.spell))
    g8.BGSE_Act(caster)
    g8.listeners.started[1](caster,action(31,resref,-1))
    caster.m_curAction=action(31,resref,c8.target or 1)
    return c8
end
local c8=turn8(100,'TESTSTOP')
assert(c8.castKind=='opener' and c8.rule=='time-stop' and c8.stop==nil)
assert(g8.queued[#g8.queued].text:find('SpellRES%("TESTSTOP",Myself%)')~=nil)
game8.m_nTimeStop,game8.m_nTimeStopCaster=539,1
c8=turn8(200,'TESTALAC')
assert(c8.rule=='alacrity' and math.abs(c8.stop-539/30)<1e-9)
caster.stats[165]=1
c8=turn8(300,'TESTHOLD')
assert(c8.castKind=='disable' and c8.target==11 and c8.alacrity==true)
c8=turn8(400,'TESTHOLD')
assert(c8.target==12)
game8.m_nTimeStop,game8.m_nTimeStopCaster=0,-1
caster.stats[165]=0
-- Aura cleansing that an item could hold (AURACLEANSING) is not Improved Alacrity.
caster.stats[76]=1
-- Both openers are spent (with one left, the next Time Stop would follow, as SCS's do).
for _,known in ipairs(caster.book[8]) do known.m_flags=0 end
c8=turn8(500,'TESTHOLD')
assert(c8.target==11 and c8.stop==nil and c8.alacrity==nil)
assert(ch8:inspect().counts.openers==2)
groups=groups+1

-- 18. Touch charges (D2c). A priest with Harm casts it on itself, aimed at the enemy it will
-- strike; with the hand in its magic weapon slot it strikes that enemy at once (SCS's round timer,
-- then AttackOneRound at EEex_Target) and is held while it swings; once the hand is gone the
-- strike is judged by the hit points the enemy lost. A swing that missed is followed by another;
-- a charge spent on an enemy left untouched is a miss of the touch spell there. A hand from a
-- spell the priest has not memorized is read from the item.
records.TESTHRMD=spl('TESTHRMD',6,{fx(208,{p1=1,duration=1}),fx(12,{p1=90,p2=64*65536,timing=1})},1,1)
records.TESTHARM=spl('TESTHARM',6,{fx(111,{target=1,p1=1,res='TESTHRM',duration=60})},5,1)
ITEMS.TESTHRM=weapon('TESTHRM',{itemType=28},{dice=0,sides=0,thac0=4,
    effects={fx(146,{res='TESTHRMD',timing=1}),fx(112,{target=1,res='TESTHRM',timing=1})}})
local reader9={problems={},get=reader.get,
    lookup=function(kind,key) if kind=='ITM' then return ITEMS[key] end return reader.lookup(kind,key) end}
local g9=world()
local healer=g9.add(sprite(1,0,0,255,{levels={[7]='S2'}}))
healer.stats[7],healer.stats[2]=10,5
learn(healer,5,'TESTHARM')
g9.add(sprite(11,100,0,2)).stats[2]=5
local dir9=directors.new(g9,{reader=reader9})
local ch9=choices.new(g9,{reader=reader9,director=dir9,seed=17})
local rows9={}
ch9:setSink(function(row) rows9[#rows9+1]=row end)
runtime.install(g9,{director=dir9,choice=ch9,version='test'})
local function last9(kind,member)
    for n=#rows9,1,-1 do if rows9[n].kind==kind and (member==nil or rows9[n].member==member) then return rows9[n] end end
end
g9.ticks=100
assert(g9.BGSE_Claim(healer,'priest','s2')==true)
local c9=last9('choice')
assert(c9.spell=='TESTHARM' and c9.castKind=='touch' and c9.mode=='self' and c9.target==11)
g9.BGSE_Act(healer)
assert(g9.queued[#g9.queued].text:find('SpellRES%("TESTHARM",Myself%)')~=nil and ch9:inspect().counts.touches==1)
g9.listeners.started[1](healer,action(31,'TESTHARM',1))
healer.m_curAction=action(31,'TESTHARM',1);healer.locals.castspell=190;healer.book[5][1].m_flags=0
-- The hand is in the magic weapon slot: the priest strikes.
g9.ticks=200;healer.locals.castspell=0;healer.m_curAction={m_actionID=0}
healer.items[34]={cResRef=str('TESTHRM')}
assert(g9.BGSE_Claim(healer,'priest','s2')==true)
c9=last9('choice')
assert(c9.spell=='TESTHRM' and c9.castKind=='strike' and c9.how=='strike' and c9.target==11)
g9.BGSE_Act(healer)
assert(g9.queued[#g9.queued].text=='SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nAttackOneRound(EEex_Target("BGSE"))')
assert(healer.aux.EEex_Target.BGSE==11 and last9('swing').target==11 and ch9:inspect().counts.strikes==1)
-- Held while it swings and SCS's timer runs: SCS's own touch block does not take the charge
-- elsewhere.
g9.listeners.started[1](healer,action(105,'',11))
healer.m_curAction=action(105,'',11);healer.locals.castspell=290
g9.ticks=230
assert(g9.BGSE_Claim(healer,'priest','s2')==true and ch9:inspect().counts.holds==1)
-- The hand is gone and the enemy down to one hit point: the strike landed. Nothing else is ready.
healer.items[34]=nil;healer.m_curAction={m_actionID=0};healer.locals.castspell=0
g9.objects[11].m_baseStats.m_hitPoints=1
g9.ticks=300
assert(g9.BGSE_Claim(healer,'priest','s2')==false)
assert(last9('strike').hit==true and last9('strike').item=='TESTHRM' and last9('strike').spell=='TESTHARM')
assert(ch9:inspect().counts.strikeHits==1 and ch9:inspect().remembered==0)
-- A second priest whose script cast its Harm.
local other9=g9.add(sprite(2,0,600,255,{levels={[7]='S2'}}))
other9.stats[7],other9.stats[2]=10,5
learn(other9,5,'TESTHARM');other9.book[5][1].m_flags=0
other9.items[34]={cResRef=str('TESTHRM')}
g9.add(sprite(12,100,600,2)).stats[2]=5
g9.ticks=400
assert(g9.BGSE_Claim(other9,'priest','s2')==true and last9('choice',2).castKind=='strike' and last9('choice',2).target==12)
g9.BGSE_Act(other9)
other9.m_curAction=action(105,'',12)
-- The swing is over, SCS's timer too, and the hand is still there: it swings again.
g9.ticks=500;other9.m_curAction={m_actionID=0}
assert(g9.BGSE_Claim(other9,'priest','s2')==true and last9('choice',2).castKind=='strike')
g9.BGSE_Act(other9)
assert(ch9:inspect().counts.strikes==3)
-- The hand is gone and the enemy untouched: a miss of Harm on it.
other9.items[34]=nil
g9.ticks=520
assert(g9.BGSE_Claim(other9,'priest','s2')==false)
assert(last9('strike',2).hit==false and last9('strike',2).spell=='TESTHARM' and ch9:inspect().counts.strikeMisses==1)
assert(ch9:inspect().remembered==1)
-- A third priest holds a hand from a spell it has not memorized (a scroll, a forced cast).
local third9=g9.add(sprite(3,0,1200,255,{levels={[7]='S2'}}))
third9.stats[7],third9.stats[2]=10,5
third9.items[34]={cResRef=str('TESTHRM')}
g9.add(sprite(13,100,1200,2)).stats[2]=5
g9.ticks=600
assert(g9.BGSE_Claim(third9,'priest','s2')==true and last9('choice',3).castKind=='strike' and last9('choice',3).target==13)
g9.BGSE_Act(third9)
assert(last9('swing',3).item=='TESTHRM' and ch9:inspect().counts.strikes==4)
groups=groups+1

-- 19. Weapon attacks (D2c). A mage with nothing ready attacks with the staff in its hand (THAC0
-- 14 less the staff's 1), AttackOneRound at EEex_Target after SCS's round timer, and is held while
-- it attacks; once that is over, the hit points its target lost are recorded. A target that died
-- releases it. A mage with Melf's Minute Meteors casts them on itself, then throws them: five
-- attacks a round, each with its fire; no second casting while the meteors are in its hand. A
-- sling without bullets is no weapon.
ITEMS.TESTSTAF=weapon('TESTSTAF',{flags=0},{dice=1,sides=6,damageType=2,thac0=1})
ITEMS.TESTMET=weapon('TESTMET',{equipping={fx(1,{p1=5,p2=1,target=1,timing=2})}},{attackType=2,range=40,dice=1,sides=4,
    damageType=4,thac0=2,charges=10,depletion=1,effects={fx(12,{dice=1,sides=4,p2=8*65536,timing=1})}})
ITEMS.TESTSLNG=weapon('TESTSLNG',{flags=0},{attackType=4,dice=0,sides=0,range=60})
records.TESTMMM=spl('TESTMMM',3,{fx(111,{target=1,p1=1,res='TESTMET',duration=60})},5,1)
local g10=world()
local fighter=g10.add(armed(sprite(1,0,0,255),35,'TESTSTAF'))
fighter.stats[8],fighter.stats[7],fighter.stats[2]=1,14,8
local foe=g10.add(sprite(11,60,0,2))
foe.stats[2]=5
local dir10=directors.new(g10,{reader=reader9})
local ch10=choices.new(g10,{reader=reader9,director=dir10,seed=19})
local rows10={}
ch10:setSink(function(row) rows10[#rows10+1]=row end)
runtime.install(g10,{director=dir10,choice=ch10,version='test'})
local function last10(kind,member)
    for n=#rows10,1,-1 do if rows10[n].kind==kind and (member==nil or rows10[n].member==member) then return rows10[n] end end
end
local own=sense.attack(g10,fighter,reader9)
assert(own.item=='TESTSTAF' and own.ability==1 and own.thac0==13 and own.damage==3.5 and own.damageType==2 and own.flags==0)
g10.ticks=100
assert(g10.BGSE_Claim(fighter,'mage','s1')==true)
local c10=last10('choice')
assert(c10.castKind=='weapon' and c10.how=='weapon' and c10.spell=='TESTSTAF' and c10.target==11)
-- The director's focus is that enemy: its worth counts half again.
assert(c10.focus==11 and math.abs(c10.worth-1.5*0.65*3.5/40)<1e-9)
g10.BGSE_Act(fighter)
assert(g10.queued[#g10.queued].text=='SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nAttackOneRound(EEex_Target("BGSE"))')
assert(fighter.aux.EEex_Target.BGSE==11 and last10('swing').weapon==true and ch10:inspect().counts.attacks==1)
-- Held while it attacks.
fighter.m_curAction=action(105,'',11);fighter.locals.castspell=190
g10.ticks=130
assert(g10.BGSE_Claim(fighter,'mage','s1')==true and ch10:inspect().counts.holds==1)
-- The attack and SCS's timer are over; the enemy lost 4 hit points. It attacks again.
fighter.m_curAction={m_actionID=0};fighter.locals.castspell=0
foe.m_baseStats.m_hitPoints=36
g10.ticks=200
assert(g10.BGSE_Claim(fighter,'mage','s1')==true)
assert(last10('attack').hit==true and last10('attack').lost==4 and ch10:inspect().counts.attackHits==1)
assert(last10('choice').castKind=='weapon')
g10.BGSE_Act(fighter)
-- The enemy dies while SCS's timer still runs: the mage is released and the attack recorded.
fighter.m_curAction={m_actionID=0};fighter.locals.castspell=400
foe.m_baseStats.m_hitPoints=0;foe.state=0x800
g10.ticks=260
assert(g10.BGSE_Claim(fighter,'mage','s1')==false)
assert(last10('attack').hit==true and last10('attack').lost==36 and ch10:inspect().counts.attackHits==2)
-- A mage with the meteors ready, a staff in hand, and an enemy 300 away.
local thrower=g10.add(armed(sprite(2,0,600,255),35,'TESTSTAF'))
thrower.stats[8],thrower.stats[7],thrower.stats[2]=1,14,8
learn(thrower,2,'TESTMMM')
g10.add(sprite(12,300,600,2)).stats[2]=5
g10.ticks=300
assert(g10.BGSE_Claim(thrower,'mage','s1')==true)
c10=last10('choice',2)
assert(c10.castKind=='arm' and c10.spell=='TESTMMM' and c10.mode=='self' and c10.target==12)
g10.BGSE_Act(thrower)
assert(g10.queued[#g10.queued].text:find('SpellRES%("TESTMMM",Myself%)')~=nil and ch10:inspect().counts.arms==1)
g10.listeners.started[1](thrower,action(31,'TESTMMM',2))
thrower.m_curAction=action(31,'TESTMMM',2);thrower.locals.castspell=390;thrower.book[2][1].m_flags=0
-- The meteors are in its hand: it throws them, five a round, at the enemy.
g10.ticks=400;thrower.locals.castspell=0;thrower.m_curAction={m_actionID=0}
thrower.items[34]={cResRef=str('TESTMET')};thrower.m_equipment.m_selectedWeapon=34;thrower.stats[8]=5
assert(g10.BGSE_Claim(thrower,'mage','s1')==true)
c10=last10('choice',2)
assert(c10.castKind=='weapon' and c10.spell=='TESTMET' and c10.target==12)
-- Five throws at THAC0 12 (14 less the meteors' 2) against armour class 5 hit 3.5 times; each
-- deals 2.5 and 2.5 fire, 17.5 of 40 hit points.
assert(math.abs(c10.worth-(c10.focus==12 and 1.5 or 1)*17.5/40)<1e-9)
-- A sling without bullets is no weapon: with nothing else, the round goes to SCS.
local slinger=g10.add(armed(sprite(3,0,1200,255),35,'TESTSLNG'))
g10.add(sprite(13,60,1200,2))
g10.ticks=500
assert(g10.BGSE_Claim(slinger,'mage','s1')==false and last10('choice',3)==nil)
-- A mage with a summons ready and a staff in hand: SCS keeps the round, and the decline names the
-- spell it keeps it for.
records.TESTSUMN=spl('TESTSUMN',3,{fx(67,{target=1,res='TESTMON'})},5,1)
local summoner=g10.add(armed(sprite(4,0,1800,255),35,'TESTSTAF'))
summoner.stats[8],summoner.stats[7],summoner.stats[2]=1,14,8
learn(summoner,3,'TESTSUMN')
g10.add(sprite(14,60,1800,2)).stats[2]=5
g10.ticks=600
assert(g10.BGSE_Claim(summoner,'mage','s1')==false)
local kept=last10('decline',4)
assert(kept and kept.reason=='scs-summon' and kept.kept=='TESTSUMN' and kept.top[1].kind=='weapon')
groups=groups+1

-- 20. Releases (D2b). A mage with SCS's kind of sequencer (an innate that casts two bolts at its
-- target, range 5 written on it) and an enemy 200 away: it goes off with ForceSpellRES at
-- EEex_Target, and the ForceSpell that starts is the engine's own cast. Under Improved Alacrity
-- the mage keeps it.
local seqRec=spl('TESTSEQ',1,{fx(146,{p2=1,res='TESTBOLT'}),fx(146,{p2=1,res='TESTBOLT'}),fx(172,{target=1,res='TESTSEQ'}),
    fx(171,{target=1,timing=4,duration=1440,res='TESTSEQ'})},1,1)
seqRec.spellType,seqRec.flags,seqRec.abilities[1].range,seqRec.abilities[1].speed=4,0,5,0
records.TESTSEQ=seqRec
local g11=world()
local sequencer=g11.add(sprite(1,0,0,255))
sequencer.stats[2]=8
gift(sequencer,'TESTSEQ')
g11.add(sprite(11,200,0,2)).stats[2]=5
local dir11=directors.new(g11,{reader=reader})
local ch11=choices.new(g11,{reader=reader,director=dir11,seed=20})
local rows11={}
ch11:setSink(function(row) rows11[#rows11+1]=row end)
runtime.install(g11,{director=dir11,choice=ch11,version='test'})
local function last11(kind)
    for n=#rows11,1,-1 do if rows11[n].kind==kind then return rows11[n] end end
end
g11.ticks=100
assert(g11.BGSE_Claim(sequencer,'mage','s1')==true)
local c11=last11('choice')
assert(c11.spell=='TESTSEQ' and c11.release==true and c11.target==11 and ch11:inspect().counts.releases==1)
g11.BGSE_Act(sequencer)
assert(g11.queued[#g11.queued].text=='SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nForceSpellRES("TESTSEQ",EEex_Target("BGSE"))')
g11.listeners.started[1](sequencer,action(113,'TESTSEQ',11))
assert(ch11:inspect().counts.started==1 and last11('start').spell=='TESTSEQ')
assert(choices.response({resref='TESTSEQ',kind='defence',self=true,release=true})==
    'SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nForceSpellRES("TESTSEQ",Myself)')
assert(choices.response({resref='TESTSEQ',kind='damage',point={x=5,y=6},release=true})==
    'SetGlobalTimer("castspell","LOCALS",ONE_ROUND)\nForceSpellPointRES("TESTSEQ",[5.6])')
-- Under Improved Alacrity: no release.
local second=g11.add(sprite(2,0,600,255))
second.stats[2],second.stats[165]=8,1
gift(second,'TESTSEQ')
g11.add(sprite(12,200,600,2)).stats[2]=5
g11.ticks=200
assert(g11.BGSE_Claim(second,'mage','s1')==false and ch11:inspect().counts.releases==1)
groups=groups+1

return groups
