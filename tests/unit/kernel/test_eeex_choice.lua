-- EEex side of the engine's own choice against fake engine globals: taking the round through
-- the gate, the response that casts, SCS's round timer as the round's marker, the target named
-- through EEex_Target, holding while the cast is queued, while it runs and while the creature
-- waits, the director's picture of the engine's own casts, outcomes and memory, re-checks,
-- switches, errors and loads.
local runtime=require('adapters.eeex.runtime')
local directors=require('adapters.eeex.director')
local choices=require('adapters.eeex.choice')
local sense=require('adapters.eeex.sense')
local spells=require('combat-intent.spells')
local intent=require('combat-intent.choice')
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
    -- A silenced caster's spell buttons are disabled, as the engine does it.
    function s:GetQuickButtons(kind)
        local list={}
        local off=band(self.state,0x1000)~=0 and 1 or 0
        if kind==2 then for _,r in ipairs(self.buttons) do list[#list+1]={m_count=1,m_bDisabled=off,m_abilityId={m_res=str(r)}} end end
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
    g.EEex_Sprite_SetLocalInt=function(s,name,value) s.locals[name]=value end
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
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
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
-- Weapons: a magical long sword, a bow (item category 15) and its arrows (launcher 1, a bow).
local function weapon(resref,fields,ability)
    local a={location=1,attackType=1,dice=1,sides=8,damageBonus=0,range=1,thac0=0,effects={}}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='ITM',resref=resref,flags=0x40,enchantment=0,abilities={a}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local ITEMS={TESTPOTN=POTION,TESTSWRD=weapon('TESTSWRD'),
    TESTBOW=weapon('TESTBOW',{flags=0,itemType=15},{attackType=4,dice=0,sides=0,range=100}),
    TESTARRW=weapon('TESTARRW',{flags=0,enchantment=1},{attackType=2,dice=1,sides=6,damageBonus=1,launcher=1})}
-- The names the game's IDS files give the creature values the tests use (wit's race groups).
local IDSNAMES={GENERAL={[1]='HUMANOID',[2]='ANIMAL',[4]='UNDEAD'},RACE={[1]='HUMAN',[113]='OGRE'},
    CLASS={[1]='MAGE',[2]='FIGHTER'}}
local reader={problems={},get=function(kind,resref)
        if kind=='SPL' then return records[resref] end
        if kind=='ITM' then return ITEMS[resref] end
    end,
    idsName=function(file,number) return IDSNAMES[file] and IDSNAMES[file][number] end,
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
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. Formats: the target is named by EEex_Target; SCS's round timer is no part of a response.
assert(choices.response({resref='SPWI304',target=12})=='SpellRES("SPWI304",EEex_Target("BGSE"))')
assert(choices.response({resref='SPWI304',point={x=430,y=107}})=='SpellPointRES("SPWI304",[430.107])')
assert(choices.response({resref='SPPR502',self=true})=='SpellRES("SPPR502",Myself)')
assert(choices.response({resref='BAD"X',target=1})==nil and choices.response({resref='SPWI304',point={x=-1,y=2}})==nil)
assert(choices.response({resref='SPWI304'})==nil)
groups=groups+1

-- 2. The round is the engine's: the Fire Bolt goes to the director's focus, the wounded 12,
-- which it kills; the response casts at EEex_Target, which names 12. SCS's round timer, run out,
-- marks the round: set for a round (90 ticks), which also covers the bolt's casting.
assert(claim(m1,'mage','s1',100)==true)
local c=last('choice')
assert(c.spell=='TESTBOLT' and c.target==12 and c.focus==12 and #c.top==3 and c.top[1].target==12)
g.BGSE_Act(m1)
assert(#g.queued==1 and g.queued[1].id==1 and g.queued[1].text=='SpellRES("TESTBOLT",EEex_Target("BGSE"))')
assert(m1.aux.EEex_Target.BGSE==12 and m1.locals.castspell==190)
local state=root.inspect()
assert(state.counts.acted==1 and state.choice.counts.claims==1 and state.choice.counts.performed==1 and state.choice.pending==1)
assert(state.choice.counts.marked==1)
-- Queued, not started: the next pass holds, so SCS's blocks cannot replace the cast, and the game
-- runs no response of the hook block while the cast it queued waits; the round's marker still runs.
assert(claim(m1,'mage','s1',101)==true)
assert(#g.queued==1 and root.inspect().counts.held==0 and root.inspect().choice.counts.holds==1)
assert(m1.locals.castspell==190 and root.inspect().choice.counts.marked==1)
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
-- While it is the mage's action the engine holds it, so that SCS's blocks below the hook do not
-- replace it.
m1.m_curAction=action(31,'TESTBOLT',12)
assert(claim(m1,'mage','s1',120)==true and root.inspect().choice.counts.holds==2)
local function claimed() local t=root.inspect().trace;return t[#t].kind=='claim' and t[#t].reason end
assert(claimed()=='hold')
-- It ends while its casting aura runs (counted from the start at 101): the engine keeps the round
-- and, without a weapon, waits until half a second before the aura frees, deciding again at least
-- every 15 ticks; 30 ticks after the bolt's end its effect is judged: 12 lost its hit points.
m1.m_curAction={m_actionID=0}
e12.m_baseStats.m_hitPoints=0
m1.castTimer=29
assert(claim(m1,'mage','s1',130)==true and root.inspect().choice.judging==1 and root.inspect().choice.waiting==1)
local w3=last('wait')
assert(w3.reason=='aura' and w3.member==1 and near(w3.aura,71/15) and near(w3.seconds,71/15-0.5) and w3.top[1].spell=='TESTBOLT')
-- A wait holds the round with the mage standing still: an action of the engine's own that still
-- ran would give way to it (adapters/eeex/hook.lua).
assert(claimed()=='idle')
g.BGSE_Act(m1)
assert(m1.locals.castspell==190 and root.inspect().choice.reasons.timer==nil)
m1.castTimer=64
assert(claim(m1,'mage','s1',165)==true)
state=root.inspect().choice
assert(state.counts.hits==1 and state.judging==0 and last('outcome').hit==true and state.counts.waits==1)
g.BGSE_Act(m1)
-- SCS's round timer runs out while the mage waits: the hold marks the next round once, so SCS's
-- own blocks above the hook get one pass a round.
m1.castTimer=90
assert(claim(m1,'mage','s1',191)==true)
g.BGSE_Act(m1)
state=root.inspect().choice
assert(m1.locals.castspell==281 and state.counts.marked==2 and state.counts.waits==1)
-- Half a second before the aura frees the next bolt is chosen: with 12 dead the focus moves on to
-- the nearer 11.
m1.castTimer=95
assert(claim(m1,'mage','s1',196)==true)
c=last('choice');assert(c.target==11 and c.focus==11 and near(c.aura,5/15))
groups=groups+1

-- 4. A bolt that leaves its target untouched, with no save or magic resistance to blame, met
-- an immunity: the mage remembers it and turns to 13. An interrupted cast says nothing.
g.BGSE_Act(m1)
assert(m1.aux.EEex_Target.BGSE==11 and m1.locals.castspell==281)
-- The queued bolt starts when the aura frees, and its casting aura with it.
g.ticks=201
start(m1,action(31,'TESTBOLT',-1))
m1.m_curAction=action(31,'TESTBOLT',11);m1.castTimer=9
assert(claim(m1,'mage','s1',210)==true)
m1.m_curAction={m_actionID=0};m1.castTimer=29
assert(claim(m1,'mage','s1',230)==true and last('wait').tick==230 and root.inspect().choice.counts.waits==2)
-- Decided again 15 ticks later, the wait goes on for the same reason, without a new row.
m1.castTimer=44
assert(claim(m1,'mage','s1',245)==true and root.inspect().choice.counts.waits==2 and root.inspect().choice.waiting==1)
m1.castTimer=93
assert(claim(m1,'mage','s1',294)==true)
state=root.inspect().choice
assert(state.counts.misses==1 and state.remembered==1 and last('outcome').hit==false and last('outcome').misses==1)
c=last('choice');assert(c.target==13 and c.tick==294)
g.BGSE_Act(m1)
assert(m1.locals.castspell==384)
g.ticks=301
start(m1,action(31,'TESTBOLT',-1))
-- Damage ends the cast four ticks in, long before its casting time.
g.ticks=305
start(m1,action(3,'',13))
m1.castTimer=34
assert(claim(m1,'mage','s1',335)==true and last('wait').tick==335)
state=root.inspect().choice
assert(state.counts.interrupted==1 and state.counts.misses==1 and state.counts.hits==1)
groups=groups+1

-- 5. Right before acting the target is checked again: one that died meanwhile skips the act
-- without an error or a backoff; a cast queued that never starts is given up.
local errors=root.inspect().counts.errors
m1.castTimer=93
assert(claim(m1,'mage','s1',394)==true)
c=last('choice');assert(c.target==13 and c.tick==394)
e13.state=0x800
g.BGSE_Act(m1)
state=root.inspect()
assert(state.counts.skipped==1 and state.counts.errors==errors and state.choice.counts.skipped==1 and state.choice.pending==0)
assert(m1.locals.castspell==384)
e13.state=0
local queued=#g.queued
m1.castTimer=94
assert(claim(m1,'mage','s1',395)==true)
g.BGSE_Act(m1)
assert(#g.queued==queued+1 and root.inspect().choice.pending==1 and m1.locals.castspell==485)
local holds=root.inspect().choice.counts.holds
m1.castTimer=nil
assert(claim(m1,'mage','s1',415)==true and root.inspect().choice.counts.holds==holds+1)
assert(claim(m1,'mage','s1',445)==true and root.inspect().choice.counts.lost==1)
assert(last('lost').spell=='TESTBOLT' and last('lost').queued==395 and last('lost').cut==nil)
groups=groups+1

-- 6. The creature's script keeps the round only with the switch off, while the creature casts what
-- the engine did not queue, for families the choice does not drive and on the good side. A silenced
-- mage with nothing it can cast waits, as one does while its casting aura runs.
g.BGSE_Act(m1)
start(m1,action(31,'TESTBOLT',-1))
start(m1,action(0,'',0))
root.setChoice(false)
assert(claim(m1,'mage','s1',450)==false and root.inspect().choice.reasons.off==1)
root.setChoice(true)
m1.state=0x1000
assert(claim(m1,'mage','s1',451)==true and root.inspect().choice.reasons['no-option']==nil)
local w6=last('wait')
assert(w6.tick==451 and w6.reason=='no-option' and w6.seconds==intent.idle and w6.rejected~=nil)
m1.state=0
m1.castTimer=40
assert(claim(m1,'mage','s1',467)==true and last('wait').tick==467 and last('wait').reason=='aura')
m1.castTimer=nil
m1.m_curAction=action(31,'SPWI112',11)
assert(claim(m1,'mage','s1',468)==false and root.inspect().choice.reasons.casting==1)
m1.m_curAction={m_actionID=0}
local fighter=g.add(sprite(4,0,40,255,{levels={[7]='S3'}}))
learn(fighter,2,'TESTBOLT')
-- The engine drives all four families (F1e); labs switch families on and off, and a bad table
-- changes nothing.
assert(ch:searches('fighter',4)==true and ch:setFamilies({mage=true,priest=true})==true)
assert(claim(fighter,'fighter','s3',469)==false and root.inspect().choice.reasons.family==1)
local okF,badF=ch:setFamilies({mage=true,dragon=true})
assert(okF==false and badF=='dragon' and ch:setFamilies({mage='yes'})==false and ch:setFamilies('mage')==false)
assert(claim(fighter,'fighter','s3',470)==false and root.inspect().choice.reasons.family==2)
assert(ch:setFamilies({fighter=true})==true and claim(m1,'mage','s1',470)==false)
assert(root.inspect().choice.reasons.family==3 and ch:searches('mage',1)==false and ch:searches('fighter',4)==true)
assert(ch:setFamilies({mage=true,priest=true})==true and ch:searches('fighter',4)==false)
assert(ch:setFamilies(nil)==true and ch:searches('mage',1)==true and ch:searches('fighter',4)==true)
local friend=g.add(sprite(5,0,-40,2))
learn(friend,2,'TESTBOLT')
assert(claim(friend,'mage','s1',470)==false and root.inspect().choice.reasons.side==1)
groups=groups+1

-- 7. An area spell at a point: the Fireball goes where it catches the whole cluster (the
-- middle ranks first; equal options are drawn at random), as a SpellPointRES, and its start
-- at that point is the engine's own.
local m6=g.add(sprite(6,0,100,255))
learn(m6,2,'TESTBALL')
local f21=g.add(sprite(21,300,100,2));local f22=g.add(sprite(22,330,100,2));g.add(sprite(23,360,100,2))
for _,e in ipairs({e11,e12,e13}) do e.state=0x800 end
assert(claim(m6,'mage','s1',510)==true)
c=last('choice')
assert(c.spell=='TESTBALL' and c.mode=='point-area' and #c.hits==3 and c.point.y==100 and c.target==nil)
assert(c.top[1].point.x==330 and c.top[1].hits==3)
g.BGSE_Act(m6)
assert(g.queued[#g.queued].text:find('SpellPointRES%("TESTBALL",%['..c.point.x..'%.100%]%)')~=nil)
start(m6,action(95,'TESTBALL',-1))
assert(root.inspect().choice.counts.started>=5)
groups=groups+1

-- 8. A priest heals a badly hurt ally of its level itself (D3a): the heal is cast at the ally,
-- named by EEex_Target, and claims it in the group; once it ends it is judged by the hit points
-- the ally gained. A whole ally gets no heal.
local p7=g.add(sprite(7,0,140,255,{levels={[7]='S2'},stats={[1]=40,[34]=10}}))
learn(p7,3,'TESTBOLT');learn(p7,3,'TESTHEAL')
-- One enemy of the cluster is left to threaten the ally.
f21.state=0;f22.state=0x800;g.objects[23].state=0x800
local hurt=g.add(sprite(8,20,140,255,{m_baseStats={m_hitPoints=4,m_generalState=0},stats={[1]=40,[34]=10}}))
assert(claim(p7,'priest','s2',520)==true)
c=last('choice')
assert(c.spell=='TESTHEAL' and c.castKind=='heal' and c.target==8 and c.mode=='ally')
g.BGSE_Act(p7)
assert(g.queued[#g.queued].text:find('SpellRES%("TESTHEAL",EEex_Target%("BGSE"%)%)')~=nil and p7.aux.EEex_Target.BGSE==8)
assert(root.inspect().choice.counts.heals==1)
start(p7,action(31,'TESTHEAL',-1))
p7.m_curAction={m_actionID=0}
hurt.m_baseStats.m_hitPoints=24
assert(claim(p7,'priest','s2',550)==true and root.inspect().choice.judging==1)
assert(claim(p7,'priest','s2',585)==true)
assert(last('care') and last('care').helped==1 and root.inspect().choice.counts.cared==1)
hurt.m_baseStats.m_hitPoints=40
assert(claim(p7,'priest','s2',586)==true and last('choice').spell=='TESTBOLT')
groups=groups+1

-- 9. Errors stay inside: a creature whose spellbook cannot be read, and a broken decision,
-- leave the round to SCS without a gate error; a load forgets every queued cast.
local before=root.inspect().counts.errors
local broken=g.add(sprite(9,0,180,255))
broken.m_memorizedSpellsMage={getReference=function() error('unreadable') end}
assert(claim(broken,'mage','s1',530)==false)
state=root.inspect()
assert(state.counts.errors==before and state.choice.counts.errors==1 and state.choice.lastError:find('^book: ')~=nil)
assert(ch:decide({id=1},nil)==nil)
assert(claim(m1,'mage','s1',540)==true)
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
caster.m_curAction=action(31,'TESTACID',11)
g2.ticks=120;assert(g2.BGSE_Claim(caster,'mage','s1')==true)
caster.m_curAction={m_actionID=0}
victim.m_timedEffectList={{m_effectId=142,m_sourceRes=str('TESTACDB')}}
g2.ticks=130;assert(g2.BGSE_Claim(caster,'mage','s1')==true)
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
-- never the log. Here the priest casts what its script started (a block of SCS's above the hook).
local traced={}
ch3:setSink(function(row) traced[#traced+1]=row end)
ch3:setTrace(true)
q1.m_curAction=action(31,'SPPR113',31)
g3.ticks=200
assert(g3.BGSE_Claim(q1,'priest','s2')==false)
local t=traced[#traced]
assert(t.kind=='declined' and t.reason=='casting' and t.member==1 and t.family=='priest' and t.tick==200)
local logged=false
for _,row in ipairs(root3.inspect().choice.log) do if row.kind=='declined' then logged=true end end
assert(not logged and root3.inspect().choice.trace==true)
-- With no option at all the priest waits, and the wait's row counts why: the second priest's only
-- enemy left is held by the first one's reservation.
g3.ticks=202
assert(g3.BGSE_Claim(q2,'priest','s2')==true)
t=traced[#traced]
assert(t.kind=='wait' and t.reason=='no-option' and t.member==2 and t.rejected['no-worth']==1)
ch3:setTrace(false)
local n=#traced
g3.ticks=201
assert(g3.BGSE_Claim(q1,'priest','s2')==false and #traced==n)
groups=groups+1

-- 13. A cast queued in the last half second of the casting aura waits for it: the creature holds
-- while the aura runs and pendingTicks after it was last seen busy, then the cast is given up.
local g4=world()
local w=g4.add(sprite(1,0,0,255))
learn(w,2,'TESTBOLT',3)
g4.add(sprite(11,100,0,2))
local dir4=directors.new(g4,{reader=reader})
local ch4=choices.new(g4,{reader=reader,director=dir4,seed=9})
local root4=runtime.install(g4,{director=dir4,choice=ch4,version='test'})
w.castTimer=95
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
    g5.ticks=tick
    assert(g5.BGSE_Claim(z,'mage','s1')==true)
    g5.BGSE_Act(z)
    assert(z.aux.EEex_Target.BGSE==11)
    g5.listeners.started[1](z,action(31,'TESTBOLT',-1))
    z.m_curAction=action(31,'TESTBOLT',11)
end
-- Each pass judges and decides; what it decides is never queued here.
local function pass5(tick) g5.ticks=tick;assert(g5.BGSE_Claim(z,'mage','s1')==true);return root5.inspect().choice end
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
    g6.ticks=tick;c6.m_curAction={m_actionID=0}
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
mage.m_curAction=action(31,'TESTSTON',1)
assert(mage.locals.castspell==190)
-- The cast ends; the mage carries its skins. It has no weapon, so it waits while its casting aura
-- runs.
g7.ticks=110
mage.m_curAction={m_actionID=0};mage.castTimer=10
mage.m_timedEffectList={{m_effectId=218,m_durationType=4096,m_duration=110+9000,m_effectAmount=8,m_dWFlags=0,
    m_res=str(''),m_sourceRes=str('TESTSTON')}}
mage.stats[88]=8
assert(g7.BGSE_Claim(mage,'mage','s1')==true and last7('wait',1).reason=='aura')
g7.ticks=141;mage.castTimer=41
assert(g7.BGSE_Claim(mage,'mage','s1')==true)
local s7=root7.inspect().choice
assert(s7.counts.guarded==1 and s7.counts.unguarded==0 and last7('guard').landed==1 and last7('guard').friends==1)
-- Within the pause, and with the skins up, the mage attacks once the aura is over.
g7.ticks=200;mage.castTimer=nil
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
-- The conditions on it a cure takes away, with their seconds left, and the hit points its poison
-- will still take (D3b): a hold with 12 seconds, a poison of 2 a second for 10 (type 2, 2 every
-- second), a feeblemind without an end; a Hold (II) of 20 seconds apart, as the cure of holds
-- leaves it (IESDP).
local function effect(op,ticks,kind,p1,p2,p3,p4)
    return {m_effectId=op,m_durationType=kind or 4096,m_duration=ticks,m_effectAmount=p1 or 0,m_dWFlags=p2 or 0,
        m_effectAmount2=p3,m_effectAmount3=p4,m_res=str(''),m_sourceRes=str('TESTCOND')}
end
local timed=mage.m_timedEffectList
mage.m_timedEffectList={effect(109,200+180),effect(25,200+150,4096,2,2),effect(185,200+300)}
mage.m_equipedEffectList={effect(76,0,1)}
guard=sense.guard(g7,mage,200,effectsOf)
assert(guard.conditions.hold==12 and guard.conditions.hold2==20 and guard.conditions.poison==10 and guard.poison==20)
assert(guard.conditions.feeblemind==math.huge and guard.conditions.sleep==nil)
-- Poison as EE deals it: type 1 a hit point a second; type 3 one every parameter 1 seconds; type
-- 2 with a frequency multiplier (parameter 4) of 2, 2 every 2 seconds; type 4 parameter 3 every
-- parameter 1 seconds; one without an end, its first minute.
local function poisonOf(...)
    mage.m_timedEffectList={effect(25,...)}
    return sense.guard(g7,mage,200,effectsOf).poison
end
assert(poisonOf(200+150,4096,2,1)==10 and near(poisonOf(200+600,4096,3,3),40/3))
assert(poisonOf(200+150,4096,2,2,0,2)==10 and near(poisonOf(200+450,4096,6,4,4),20))
assert(poisonOf(0,1,3,3)==20)
mage.m_timedEffectList,mage.m_equipedEffectList=timed,{}
-- A defence the creature's own script starts begins the pause too: a second mage under one
-- fighter would cast Stoneskin, but its script casts it first (a block of SCS's above the hook, in
-- a pass whose first ask the engine answered). While that cast runs the round is the script's;
-- once its aura is over the mage attacks.
local other=g7.add(sprite(2,0,600,255))
other.stats[2]=8
learn(other,2,'TESTBOLT',2);learn(other,3,'TESTSTON')
g7.add(sturdy(armed(sprite(14,40,600,2,{m_curAction=action(3,'',2)}),35,'TESTSWRD')))
g7.ticks=300
assert(g7.BGSE_Claim(other,'mage','s1')==true and last7('choice',2).spell=='TESTSTON')
g7.listeners.started[1](other,action(31,'TESTSTON',2))
other.m_curAction=action(31,'TESTSTON',2)
g7.ticks=301
assert(g7.BGSE_Claim(other,'mage','s1')==false and root7.inspect().choice.reasons.casting==1)
other.m_curAction={m_actionID=0};other.castTimer=93
g7.ticks=393
assert(g7.BGSE_Claim(other,'mage','s1')==true and last7('choice',2).spell=='TESTBOLT')
-- Labs can weigh no defences (caution 0): the first mage, its skins gone and the pause over,
-- attacks the swordsmen, now near death; a bad profile change is refused and changes nothing.
mage.m_timedEffectList={};mage.stats[88]=0
for _,id in ipairs({11,12}) do g7.objects[id].m_baseStats.m_hitPoints=20 end
assert(ch7:setMind({caution=-1})==false)
assert(ch7:setMind({caution=0})==true)
g7.ticks=400;mage.m_curAction={m_actionID=0}
assert(g7.BGSE_Claim(mage,'mage','s1')==true and last7('choice',1).spell=='TESTBOLT')
local weighed=false
for _,o in ipairs(last7('choice',1).top) do if o.kind=='defence' then weighed=true;assert(o.score<0) end end
assert(weighed)
assert(ch7:setMind(nil)==true)
-- So does a drink of a potion that defends: a third mage under one fighter would cast Stoneskin,
-- but its script has just drunk a potion of stoneskin. (Later than the rest, when the enemies the
-- others saw are no longer current, so the fighter at the third mage is the group's focus.)
ITEMS.TESTSKIN={kind='ITM',resref='TESTSKIN',flags=0,abilities={{form=3,flags=0,location=3,target=5,range=1,speed=0,
    projectile=1,effects={fx(218,{p1=4,duration=300,target=1})}}}}
local third=g7.add(sprite(3,0,1200,255))
third.stats[2]=8
learn(third,2,'TESTBOLT',2);learn(third,3,'TESTSTON')
g7.add(sturdy(armed(sprite(15,40,1200,2,{m_curAction=action(3,'',3)}),35,'TESTSWRD')))
g7.ticks=500
assert(g7.BGSE_Claim(third,'mage','s1')==true)
g7.listeners.started[1](third,action(34,'TESTSKIN',3))
g7.ticks=516
assert(g7.BGSE_Claim(third,'mage','s1')==true and last7('choice',3).spell=='TESTBOLT')
-- A mage with no spell for it drinks such a potion itself, and the engine judges the drink by the
-- effects the potion leaves (their source is the potion).
local fourth=g7.add(sprite(4,0,1800,255))
fourth.stats[2]=8
fourth.items[18]={cResRef=str('TESTSKIN'),m_useCount1=1}
g7.add(sturdy(armed(sprite(16,40,1800,2,{m_curAction=action(3,'',4)}),35,'TESTSWRD')))
g7.ticks=700
assert(g7.BGSE_Claim(fourth,'mage','s1')==true)
local d4=last7('choice',4)
assert(d4.spell=='TESTSKIN' and d4.use==true and d4.castKind=='defence' and d4.mode=='self')
g7.BGSE_Act(fourth)
assert(g7.queued[#g7.queued].text:find('UseItem%("TESTSKIN",Myself%)')~=nil)
g7.listeners.started[1](fourth,action(34,'TESTSKIN',4))
assert(fourth.locals.castspell==790)
-- With the skins up and nothing else to do, the mage waits.
g7.ticks=710
fourth.m_curAction={m_actionID=0}
fourth.m_timedEffectList={{m_effectId=218,m_durationType=4096,m_duration=710+4500,m_effectAmount=4,m_dWFlags=0,
    m_res=str(''),m_sourceRes=str('TESTSKIN')}}
fourth.stats[88]=4
assert(g7.BGSE_Claim(fourth,'mage','s1')==true and last7('wait',4).reason=='no-option')
g7.ticks=741
assert(g7.BGSE_Claim(fourth,'mage','s1')==true)
assert(last7('guard',4).spell=='TESTSKIN' and last7('guard',4).landed==1)
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
    g8.ticks=tick;caster.m_curAction={m_actionID=0}
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
-- strike; with the hand in its magic weapon slot it strikes that enemy at once (AttackOneRound at
-- EEex_Target) and is held while it swings; once the hand is gone the strike is judged by the hit
-- points the enemy lost. A swing that missed is followed by another; a charge spent on an enemy
-- left untouched is a miss of the touch spell there. A hand from a spell the priest has not
-- memorized is read from the item.
records.TESTHRMD=spl('TESTHRMD',6,{fx(208,{p1=1,duration=1}),fx(12,{p1=90,p2=64*65536,timing=1})},1,1)
records.TESTHARM=spl('TESTHARM',6,{fx(111,{target=1,p1=1,res='TESTHRM',duration=60})},5,1)
ITEMS.TESTHRM=weapon('TESTHRM',{itemType=28},{dice=0,sides=0,thac0=4,
    effects={fx(146,{res='TESTHRMD',timing=1}),fx(112,{target=1,res='TESTHRM',timing=1})}})
local reader9={problems={},idsName=reader.idsName,get=reader.get,
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
healer.m_curAction=action(31,'TESTHARM',1);healer.book[5][1].m_flags=0
-- The hand is in the magic weapon slot: the priest strikes.
g9.ticks=200;healer.m_curAction={m_actionID=0}
healer.items[34]={cResRef=str('TESTHRM')}
assert(g9.BGSE_Claim(healer,'priest','s2')==true)
c9=last9('choice')
assert(c9.spell=='TESTHRM' and c9.castKind=='strike' and c9.how=='strike' and c9.target==11)
g9.BGSE_Act(healer)
assert(g9.queued[#g9.queued].text=='AttackOneRound(EEex_Target("BGSE"))' and healer.locals.castspell==290)
assert(healer.aux.EEex_Target.BGSE==11 and last9('swing').target==11 and ch9:inspect().counts.strikes==1)
-- Held while it swings: SCS's own touch block does not take the charge elsewhere.
g9.listeners.started[1](healer,action(105,'',11))
healer.m_curAction=action(105,'',11)
g9.ticks=230
assert(g9.BGSE_Claim(healer,'priest','s2')==true and ch9:inspect().counts.holds==1)
-- The hand is gone and the enemy down to one hit point: the strike landed. Nothing else is ready,
-- so the priest waits.
healer.items[34]=nil;healer.m_curAction={m_actionID=0}
g9.objects[11].m_baseStats.m_hitPoints=1
g9.ticks=300
assert(g9.BGSE_Claim(healer,'priest','s2')==true and last9('wait',1).reason=='no-option')
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
-- The swing and its round are over, and the hand is still there: it swings again.
g9.ticks=500;other9.m_curAction={m_actionID=0}
assert(g9.BGSE_Claim(other9,'priest','s2')==true and last9('choice',2).castKind=='strike')
g9.BGSE_Act(other9)
assert(ch9:inspect().counts.strikes==3)
-- The hand is gone and the enemy untouched: a miss of Harm on it.
other9.items[34]=nil
g9.ticks=520
assert(g9.BGSE_Claim(other9,'priest','s2')==true and last9('wait',2).reason=='no-option')
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
-- 14 less the staff's 1, which the game holds in THAC0BONUSRIGHT, lab probe F), AttackOneRound at
-- EEex_Target, and is held while it attacks; once that is
-- over, the hit points its target lost are recorded. A target that died releases it. A mage with Melf's Minute Meteors casts them on itself, then throws them: five
-- attacks a round, each with its fire; no second casting while the meteors are in its hand. A
-- sling without bullets is no weapon. A summoned enemy is sent away by the engine's own removal
-- (D3d).
ITEMS.TESTSTAF=weapon('TESTSTAF',{flags=0},{dice=1,sides=6,damageType=2,thac0=1})
ITEMS.TESTMET=weapon('TESTMET',{equipping={fx(1,{p1=5,p2=1,target=1,timing=2})}},{attackType=2,range=40,dice=1,sides=4,
    damageType=4,thac0=2,charges=10,depletion=1,effects={fx(12,{dice=1,sides=4,p2=8*65536,timing=1})}})
ITEMS.TESTSLNG=weapon('TESTSLNG',{flags=0},{attackType=4,dice=0,sides=0,range=60})
records.TESTMMM=spl('TESTMMM',3,{fx(111,{target=1,p1=1,res='TESTMET',duration=60})},5,1)
local g10=world()
local fighter=g10.add(armed(sprite(1,0,0,255),35,'TESTSTAF'))
fighter.stats[8],fighter.stats[7],fighter.stats[2],fighter.stats[84]=1,14,8,1
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
assert(g10.queued[#g10.queued].text=='AttackOneRound(EEex_Target("BGSE"))')
assert(fighter.aux.EEex_Target.BGSE==11 and last10('swing').weapon==true and ch10:inspect().counts.attacks==1)
-- Held while it attacks.
fighter.m_curAction=action(105,'',11)
g10.ticks=130
assert(g10.BGSE_Claim(fighter,'mage','s1')==true and ch10:inspect().counts.holds==1)
-- The attack and its round are over; the enemy lost 4 hit points. It attacks again.
fighter.m_curAction={m_actionID=0}
foe.m_baseStats.m_hitPoints=36
g10.ticks=200
assert(g10.BGSE_Claim(fighter,'mage','s1')==true)
assert(last10('attack').hit==true and last10('attack').lost==4 and ch10:inspect().counts.attackHits==1)
assert(last10('choice').castKind=='weapon')
g10.BGSE_Act(fighter)
-- The enemy dies within the round: the mage is released and the attack recorded. With no enemy
-- left in sight, the mage's script has the round.
fighter.m_curAction={m_actionID=0}
foe.m_baseStats.m_hitPoints=0;foe.state=0x800
g10.ticks=260
assert(g10.BGSE_Claim(fighter,'mage','s1')==false and ch10:inspect().reasons['no-enemy']==1)
assert(last10('attack').hit==true and last10('attack').lost==36 and ch10:inspect().counts.attackHits==2)
-- A target that dies while the attack on it still runs releases the mage as well: the game's
-- attack can go on at a dead target for the rest of its round (once in lab batch I for a minute).
-- The attack is recorded and the mage decides again; with no enemy left, its script has the round.
local foe2=g10.add(sprite(15,60,0,2))
foe2.stats[2]=5
g10.ticks=270
assert(g10.BGSE_Claim(fighter,'mage','s1')==true and last10('choice').target==15)
g10.BGSE_Act(fighter)
fighter.m_curAction=action(105,'',15)
local holds10=ch10:inspect().counts.holds
g10.ticks=280
assert(g10.BGSE_Claim(fighter,'mage','s1')==true and ch10:inspect().counts.holds==holds10+1)
foe2.m_baseStats.m_hitPoints=0;foe2.state=0x800
g10.ticks=290
assert(g10.BGSE_Claim(fighter,'mage','s1')==false and ch10:inspect().reasons['no-enemy']==2)
assert(ch10:inspect().counts.holds==holds10+1 and last10('attack').target==15 and last10('attack').lost==40)
fighter.m_curAction={m_actionID=0}
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
thrower.m_curAction=action(31,'TESTMMM',2);thrower.book[2][1].m_flags=0
-- The meteors are in its hand: it throws them, five a round, at the enemy.
g10.ticks=400;thrower.m_curAction={m_actionID=0}
thrower.items[34]={cResRef=str('TESTMET')};thrower.m_equipment.m_selectedWeapon=34;thrower.stats[8]=5;thrower.stats[84]=2
assert(g10.BGSE_Claim(thrower,'mage','s1')==true)
c10=last10('choice',2)
assert(c10.castKind=='weapon' and c10.spell=='TESTMET' and c10.target==12)
-- Five throws at THAC0 12 (14 less the meteors' 2) against armour class 5 hit 3.5 times; each
-- deals 2.5 and 2.5 fire, 17.5 of 40 hit points.
assert(math.abs(c10.worth-(c10.focus==12 and 1.5 or 1)*17.5/40)<1e-9)
-- A sling without bullets is no weapon: with nothing else, the mage waits.
local slinger=g10.add(armed(sprite(3,0,1200,255),35,'TESTSLNG'))
g10.add(sprite(13,60,1200,2))
g10.ticks=500
assert(g10.BGSE_Claim(slinger,'mage','s1')==true and last10('choice',3)==nil and last10('wait',3).reason=='no-option')
-- A mage with a spell that sends summoned creatures away, a staff in hand and a summoned enemy:
-- the engine casts it at that enemy, worth a kill.
records.TESTUNSU=spl('TESTUNSU',5,{fx(68)},1,2)
local unsummoner=g10.add(armed(sprite(4,0,1800,255),35,'TESTSTAF'))
unsummoner.stats[8],unsummoner.stats[7],unsummoner.stats[2]=1,14,8
learn(unsummoner,4,'TESTUNSU')
local summonedFoe=g10.add(sprite(14,60,1800,2))
summonedFoe.stats[2]=5
summonedFoe.m_typeAI.m_Gender=6
g10.ticks=600
assert(g10.BGSE_Claim(unsummoner,'mage','s1')==true)
local unsummon=last10('choice',4)
assert(unsummon and unsummon.castKind=='removal' and unsummon.spell=='TESTUNSU' and unsummon.target==14 and
    unsummon.mode=='creature' and ch10:inspect().counts.removals==1)
-- A creature that chases (F1d: the profile of fighters and monsters) goes for an enemy 400 away
-- with its staff: AttackOneRound walks there first, and the choice row logs the 3.36 seconds. (Its
-- 400 hit points make what the enemy deals next to it a small price.)
;(function()
local profiles=require('combat-intent.mind')
local g=world()
local chaser=g.add(armed(sprite(1,0,0,255),35,'TESTSTAF'))
chaser.stats[8],chaser.stats[7],chaser.stats[2]=1,14,8
chaser.m_baseStats.m_hitPoints=400;chaser.stats[1]=400
g.add(sprite(11,400,0,2)).stats[2]=5
local dir=directors.new(g,{reader=reader9})
local ch=choices.new(g,{reader=reader9,director=dir,seed=19,
    mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
local rows={}
ch:setSink(function(row) rows[#rows+1]=row end)
runtime.install(g,{director=dir,choice=ch,version='test'})
g.ticks=100
assert(g.BGSE_Claim(chaser,'mage','s1')==true)
local c
for n=#rows,1,-1 do if rows[n].kind=='choice' then c=rows[n];break end end
assert(c.castKind=='weapon' and c.target==11 and math.abs(c.walk-3.36)<1e-9)
g.BGSE_Act(chaser)
assert(g.queued[#g.queued].text=='AttackOneRound(EEex_Target("BGSE"))')
end)()
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
assert(g11.queued[#g11.queued].text=='ForceSpellRES("TESTSEQ",EEex_Target("BGSE"))')
g11.listeners.started[1](sequencer,action(113,'TESTSEQ',11))
assert(ch11:inspect().counts.started==1 and last11('start').spell=='TESTSEQ')
assert(choices.response({resref='TESTSEQ',kind='defence',self=true,release=true})=='ForceSpellRES("TESTSEQ",Myself)')
assert(choices.response({resref='TESTSEQ',kind='damage',point={x=5,y=6},release=true})==
    'ForceSpellPointRES("TESTSEQ",[5.6])')
-- Under Improved Alacrity: no release; with nothing else, the mage waits.
local second=g11.add(sprite(2,0,600,255))
second.stats[2],second.stats[165]=8,1
gift(second,'TESTSEQ')
g11.add(sprite(12,200,600,2)).stats[2]=5
g11.ticks=200
assert(g11.BGSE_Claim(second,'mage','s1')==true and ch11:inspect().counts.releases==1 and last11('wait').reason=='no-option')
groups=groups+1

-- 21. Summons (D3c). A mage with a spell that brings two of TESTMON (a creature file with a claw
-- in its first weapon slot, read once) casts it at the enemy's spot with SpellPointRES; once it
-- ends it is judged by the allies of the file it names that it sees and did not see before,
-- whatever their gender (lab H: a Dark Planetar is female, Animate Dead's skeletons neither). A
-- TESTMON it saw before and a new summoned ally of another file do not count. A summons whose
-- creature cannot be read brings no one; one from a monster table names no file, and a new
-- summoned ally counts for it.
local slots12={}
for n=1,40 do slots12[n]=65535 end
slots12[10]=0
local CRES={TESTMON={kind='CRE',resref='TESTMON',hp=40,maxHp=40,ac=5,thac0=10,apr=2,level=6,strength=10,
    strengthExtra=0,ea=255,general=4,race=1,class=2,specific=0,gender=6,alignment=0,items={'TESTCLAW'},slots=slots12,
    opcodes={326}}}
ITEMS.TESTCLAW=weapon('TESTCLAW',{flags=0},{dice=1,sides=6,damageType=3})
records.TESTHORD=spl('TESTHORD',3,{fx(67,{target=1,res='TESTMON',duration=180}),
    fx(67,{target=1,res='TESTMON',duration=180})},4,1)
records.TESTVOID=spl('TESTVOID',3,{fx(67,{target=1,res='TESTNONE',duration=180})},4,1)
local reads12=0
local reader12={problems={},idsName=reader.idsName,lookup=reader.lookup,get=function(kind,resref)
        if kind=='CRE' then reads12=reads12+1;return CRES[resref] end
        return reader.get(kind,resref)
    end}
local g12=world()
local conjurer=g12.add(sprite(1,0,0,255))
learn(conjurer,2,'TESTHORD')
g12.add(sprite(11,200,0,2)).stats[2]=5
local old12=g12.add(sprite(19,100,100,255))
old12.m_resref=str('TESTMON');old12.m_typeAI.m_Gender=4
local dir12=directors.new(g12,{reader=reader12})
local ch12=choices.new(g12,{reader=reader12,director=dir12,seed=21})
local rows12={}
ch12:setSink(function(row) rows12[#rows12+1]=row end)
runtime.install(g12,{director=dir12,choice=ch12,version='test'})
local function last12(kind)
    for n=#rows12,1,-1 do if rows12[n].kind==kind then return rows12[n] end end
end
g12.ticks=100
assert(g12.BGSE_Claim(conjurer,'mage','s1')==true)
local c12=last12('choice')
assert(c12.castKind=='summon' and c12.spell=='TESTHORD' and c12.mode=='point' and c12.point.x==200 and c12.point.y==0)
assert(c12.count==2 and c12.creatures[1]=='TESTMON' and ch12:inspect().counts.summons==1 and reads12==1)
-- The log shows the seconds of the fight it reckoned with.
assert(type(c12.rest)=='number' and c12.rest>0)
g12.BGSE_Act(conjurer)
assert(g12.queued[#g12.queued].text=='SpellPointRES("TESTHORD",[200.0])')
g12.listeners.started[1](conjurer,action(95,'TESTHORD',-1))
-- The cast is over: two TESTMON stand at the enemy, a female one and one of neither gender, and a
-- summoned ally of another file beside them.
conjurer.m_curAction={m_actionID=0};conjurer.book[2][1].m_flags=0
for n=1,2 do
    local s=g12.add(sprite(20+n,190,10*n,255))
    s.m_resref=str('TESTMON');s.m_typeAI.m_Gender=n==1 and 2 or 4
end
g12.add(sprite(23,180,40,255)).m_typeAI.m_Gender=6
g12.ticks=130
assert(g12.BGSE_Claim(conjurer,'mage','s1')==true and ch12:inspect().judging==1)
g12.ticks=165
g12.BGSE_Claim(conjurer,'mage','s1')
local j12=last12('conjure')
assert(j12 and j12.joined==2 and j12.expected==2 and ch12:inspect().counts.conjured==1)
-- No creature file: no summons; the mage waits.
local voidCaster=g12.add(sprite(2,0,1200,255))
learn(voidCaster,2,'TESTVOID')
g12.add(sprite(12,200,1200,2))
g12.ticks=200
assert(g12.BGSE_Claim(voidCaster,'mage','s1')==true and ch12:inspect().counts.summons==1 and last12('wait').member==2)
-- From a monster table: a new summoned ally counts, a new ally of another gender does not.
records.TESTTABL=spl('TESTTABL',3,{fx(127,{target=1,p1=2,res='TESTMONS',duration=180})},4,1)
local tabler=g12.add(sprite(3,0,2400,255))
learn(tabler,2,'TESTTABL')
g12.add(sprite(13,200,2400,2)).stats[2]=5
g12.ticks=300
assert(g12.BGSE_Claim(tabler,'mage','s1')==true and last12('choice').spell=='TESTTABL')
g12.BGSE_Act(tabler)
g12.listeners.started[1](tabler,action(95,'TESTTABL',-1))
tabler.m_curAction={m_actionID=0};tabler.book[2][1].m_flags=0
g12.add(sprite(31,190,2410,255)).m_typeAI.m_Gender=6
g12.add(sprite(32,190,2420,255)).m_typeAI.m_Gender=4
g12.ticks=330
g12.BGSE_Claim(tabler,'mage','s1')
g12.ticks=365
g12.BGSE_Claim(tabler,'mage','s1')
local t12=last12('conjure')
assert(t12 and t12.spell=='TESTTABL' and t12.joined==1 and ch12:inspect().counts.conjured==2)
groups=groups+1

-- 22. Protection removal (D3d). A mage with Breach and a fighter ally with a magical sword at an
-- enemy whose Protection from Magical Weapons (a timed effect of secondary type 7) keeps the sword
-- out: the engine reads the enemy's effects (sense.wards, each classified once) and breaches it
-- with SpellRES at EEex_Target; once the cast is over and the protection gone, the removal took.
records.TESTBRCH=spl('TESTBRCH',5,{fx(221,{p1=9,p2=7,resist=2})},1,2)
local g13=world()
local breacher=g13.add(sprite(1,0,0,255))
learn(breacher,4,'TESTBRCH')
local warded=g13.add(sprite(11,60,0,2))
warded.stats[2]=5
local function pfmw()
    return {m_effectId=120,m_durationType=4096,m_duration=100+9000,m_effectAmount=0,m_dWFlags=1,m_res=str(''),
        m_sourceRes=str('TESTPFMW'),m_school=0,m_secondaryType=7,m_spellLevel=8,m_casterLevel=15,m_flags=1,
        m_numDice=0,m_diceSize=0,m_special=0}
end
warded.m_timedEffectList={pfmw()}
g13.add(armed(sprite(2,30,0,255),35,'TESTSWRD'))
local wards=sense.wards(g13,warded,100,function() return {} end)
assert(#wards==1 and wards[1].opcode==120 and wards[1].source=='TESTPFMW' and wards[1].secondary==7 and
    wards[1].power==8 and wards[1].level==15 and wards[1].dispellable and wards[1].timed and not wards[1].lasting)
local dir13=directors.new(g13,{reader=reader})
local ch13=choices.new(g13,{reader=reader,director=dir13,seed=22})
local rows13={}
ch13:setSink(function(row) rows13[#rows13+1]=row end)
runtime.install(g13,{director=dir13,choice=ch13,version='test'})
local function last13(kind)
    for n=#rows13,1,-1 do if rows13[n].kind==kind then return rows13[n] end end
end
g13.ticks=100
assert(g13.BGSE_Claim(breacher,'mage','s1')==true)
local c13=last13('choice')
assert(c13.castKind=='removal' and c13.spell=='TESTBRCH' and c13.mode=='creature' and c13.target==11)
assert(ch13:inspect().counts.removals==1 and ch13:inspect().counts.wardFailures==0)
g13.BGSE_Act(breacher)
assert(g13.queued[#g13.queued].text=='SpellRES("TESTBRCH",EEex_Target("BGSE"))')
g13.listeners.started[1](breacher,action(31,'TESTBRCH',11))
-- The cast is over and the protection is gone.
breacher.m_curAction={m_actionID=0};breacher.book[4][1].m_flags=0
warded.m_timedEffectList={}
g13.ticks=130
g13.BGSE_Claim(breacher,'mage','s1')
g13.ticks=165
g13.BGSE_Claim(breacher,'mage','s1')
local s13=last13('strip')
assert(s13 and s13.spell=='TESTBRCH' and s13.enemies==1 and s13.took==1 and ch13:inspect().counts.stripped==1)
-- Without the protection there is nothing to breach: the mage casts no removal.
g13.ticks=300
breacher.book[4][1].m_flags=1
g13.BGSE_Claim(breacher,'mage','s1')
assert(ch13:inspect().counts.removals==1)
-- A dispel that rolls (combat-intent/removal.lua, insight): a mage of level 20 dispels the
-- protection, cast again; the choice row tells the level it works at and how the mage judges it.
-- The protection stays: the group learns that the spell's one effect stayed against level 20, as
-- surely as the dispel got through the enemy's magic resistance of 50 (half), and counts the enemy
-- as tried. A ring's effect no dispel takes teaches nothing.
records.TESTDSPL=spl('TESTDSPL',3,{fx(58,{p2=1})},1,2)
;(function()
local dispeller=g13.add(sprite(3,0,30,255))
dispeller.stats[34]=20
learn(dispeller,2,'TESTDSPL')
local ring=pfmw()
ring.m_sourceRes,ring.m_flags,ring.m_effectId,ring.m_secondaryType=str('TESTRING'),0,0,0
warded.m_timedEffectList={pfmw(),ring}
warded.stats[18]=50
g13.ticks=400
assert(g13.BGSE_Claim(dispeller,'mage','s1')==true)
local d13=last13('choice')
assert(d13.castKind=='removal' and d13.spell=='TESTDSPL' and d13.target==11 and d13.at==20)
assert(d13.insight==({clever='estimate',normal='rough',dull='none'})[d13.wit])
g13.BGSE_Act(dispeller)
assert(g13.queued[#g13.queued].text=='SpellRES("TESTDSPL",EEex_Target("BGSE"))')
g13.listeners.started[1](dispeller,action(31,'TESTDSPL',11))
dispeller.m_curAction={m_actionID=0};dispeller.book[2][1].m_flags=0
g13.ticks=430
g13.BGSE_Claim(dispeller,'mage','s1')
g13.ticks=465
g13.BGSE_Claim(dispeller,'mage','s1')
local u13=last13('strip')
assert(u13 and u13.spell=='TESTDSPL' and u13.took==0 and u13.at==20 and u13.learned==1)
local seen13=ch13:inspect().dispels[11]
assert(seen13 and seen13.tried==1 and seen13.sources.TESTPFMW[20].stayed==0.5 and seen13.sources.TESTPFMW[20].went==0)
assert(seen13.sources.TESTRING==nil)
assert(ch13:inspect().counts.unstripped==1)
-- The next decision weighs a dispel at the same protection with what the group saw: worth less.
dispeller.book[2][1].m_flags=1
g13.ticks=600
assert(g13.BGSE_Claim(dispeller,'mage','s1')==true)
local d2=last13('choice')
assert(d2.castKind=='removal' and d2.spell=='TESTDSPL' and d2.worth<d13.worth)
end)()
groups=groups+1

-- 23. Danger zones (D3e). An enemy's cloud (an area projectile in the area's flight list that
-- explodes six more times, 20 fire a hit every 76 ticks, sparing its caster's allies) around a
-- mage with a Fire Bolt: the engine reads the zone (sense.zones) and its PRO file through the
-- ability's projectile field (one more than the engine's number), leads the mage out with
-- MoveToPoint to the nearest open spot where it fits (its personal space), holds it while it
-- walks, judges that it got out and casts from there. While it waits for its casting aura it
-- still leads a mage out of the cloud. BGSE_Zones is true while the engine weighs zones for the
-- mage: not while it casts in a zone the engine did not know when it chose the cast, nor for a
-- creature off the engine's side, nor with the choice off; a read that fails as a whole hands the
-- escape back to SCS.
-- Its own function: the file's main chunk holds as many locals as Lua allows.
;(function()
local AREA14={m_resref=str('AR0002'),m_lVertSortBack={},m_lVertSortFlight={900}}
local g14=world()
local isSprite14=g14.EEex_GameObject_IsSprite
g14.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.projectile==nil and isSprite14(o,allowDead) end
g14.EEex_Projectile_Type={CProjectileArea=8}
g14.EEex_Projectile_GetType=function(o) return o.projectile or 1 end
g14.EEex_CastUD=function(o) return o end
-- EEex's search map wants the creature's personal space (it raises without one).
local asked14={}
g14.EEex_Sprite_GetPersonalSpace=function(s) return 3 end
g14.EEex_Area_GetNearestOpenPosition=function(area,x,y,space)
    if type(space)~='number' then error("invalid type 'nil' for integer argument #5") end
    asked14[#asked14+1]={x=x,y=y,space=space}
    return x+3,y
end
local hot={m_effectId=12,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=8*65536,m_flags=1,m_probabilityUpper=100,
    m_probabilityLower=0,m_res=str(''),m_numDice=4,m_diceSize=9,m_savingThrow=0,m_saveMod=0,m_special=0,m_spellLevel=4,
    m_casterLevel=10,m_sourceRes=str('TESTCLDS')}
local cloud={m_id=900,projectile=8,state=0,m_nRepetitionCount=6,m_bReachedDestination=1,m_pos={x=500,y=500},m_posDest={x=500,y=500},
    m_explosionRange=150,m_nDelay=75,m_nDelayCount=0,m_sourceId=11,m_projectileType=3,m_resref=str('CLOUD'),
    m_effectList={hot}}
g14.objects[900]=cloud
local reader14={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='CLOUD',type=3,speed=20,flags=0,extFlags=0,areaFlags=64,trigger=150,radius=150,coneWidth=0}
        end
        return reader.lookup(kind,key)
    end}
local caster14=g14.add(sprite(1,500,500,255,{m_pArea=AREA14}))
learn(caster14,2,'TESTBOLT',2)
g14.add(sprite(11,500,800,2,{m_pArea=AREA14})).stats[2]=5
local read14=sense.zones(g14,AREA14,100)
assert(#read14==1 and read14[1].id==900 and read14[1].radius==150 and read14[1].repeats==6 and read14[1].delay==75 and
    read14[1].source==11 and read14[1].projectile==4 and read14[1].pro=='CLOUD' and read14[1].level==10 and
    read14[1].resref=='TESTCLDS' and read14[1].list=='m_lVertSortFlight')
local hit14=read14[1].effects[1]
assert(hit14.opcode==12 and hit14.p2==8*65536 and hit14.dice==4 and hit14.sides==9 and hit14.timing==1 and hit14.resist==1 and
    hit14.power==4 and hit14.target==2)
local dir14=directors.new(g14,{reader=reader14})
local ch14=choices.new(g14,{reader=reader14,director=dir14,seed=23})
local rows14={}
ch14:setSink(function(row) rows14[#rows14+1]=row end)
runtime.install(g14,{director=dir14,choice=ch14,version='test'})
local function last14(kind)
    for n=#rows14,1,-1 do if rows14[n].kind==kind then return rows14[n] end end
end
assert(g14.BGSE_Zones(caster14,'mage','s1')==true and g14.BGSE_Zones(caster14,'fighter','s3')==false)
g14.ticks=100
assert(g14.BGSE_Claim(caster14,'mage','s1')==true)
local c14=last14('choice')
assert(c14.castKind=='escape' and c14.spell=='ESCAPE' and c14.zones==1 and c14.worth>0 and c14.walk>0)
-- The zone's first classification leaves a row with what was read of it.
local z14=last14('zone')
assert(z14 and z14.id==900 and z14.tick==100 and z14.resref=='TESTCLDS' and z14.radius==150 and z14.repeats==6 and
    z14.delay==75 and z14.counter==0 and z14.source==11 and z14.projectile==4 and z14.pro=='CLOUD' and
    z14.list=='m_lVertSortFlight' and z14.level==10 and z14.effects==1 and z14.classified==true and z14.x==500 and
    z14.y==500 and z14.filter=='enemies')
local function zoneRows14()
    local n=0
    for _,row in ipairs(rows14) do if row.kind=='zone' then n=n+1 end end
    return n
end
local queued=#g14.queued
g14.BGSE_Act(caster14)
assert(#g14.queued==queued+1)
local move14=g14.queued[#g14.queued].text
local mx,my=move14:match('^MoveToPoint%(%[(%-?%d+)%.(%-?%d+)%]%)$')
assert(mx and my and not move14:find('castspell',1,true))
assert(math.sqrt((tonumber(mx)-500)^2+((tonumber(my)-500)*4/3)^2)>150)
-- The open spot the search map gave for the mage's personal space.
local spot14=asked14[#asked14]
assert(spot14 and spot14.space==3 and tonumber(mx)==spot14.x+3 and tonumber(my)==spot14.y and
    ch14:inspect().counts.zoneFailures==0)
local mv14=last14('move')
assert(mv14 and mv14.to.x==tonumber(mx) and mv14.to.y==tonumber(my) and ch14:inspect().moving==1)
-- It walks: held, nothing new queued (the game runs no response of the hook block while the walk
-- it queued runs).
caster14.m_curAction={m_actionID=23}
g14.ticks=105
assert(g14.BGSE_Claim(caster14,'mage','s1')==true)
assert(#g14.queued==queued+1 and ch14:inspect().moving==1)
-- Out of the cloud: judged, and the bolt from where it stands.
caster14.m_curAction={m_actionID=0};caster14.m_pos={x=tonumber(mx),y=tonumber(my)}
g14.ticks=140
assert(g14.BGSE_Claim(caster14,'mage','s1')==true)
assert(zoneRows14()==1)
local e14=last14('escaped')
assert(e14 and e14.out==true and ch14:inspect().counts.escaped==1 and ch14:inspect().moving==0)
-- Out of the cloud the bolt finishes for sure; the record names no zone around the mage.
assert(last14('choice').spell=='TESTBOLT' and last14('choice').finish==1 and last14('choice').inZones==nil)
g14.BGSE_Act(caster14)
assert(g14.queued[#g14.queued].text=='SpellRES("TESTBOLT",EEex_Target("BGSE"))')
-- The engine's cast waits to start: the cloud it knew when it chose the cast keeps SCS's escape
-- aside even with the mage back in it; a new cloud that hurts it lets SCS's escape run.
local outside14=caster14.m_pos
caster14.m_pos={x=500,y=500}
g14.ticks=141
assert(g14.BGSE_Zones(caster14,'mage','s1')==true)
local cloud2={}
for k,v in pairs(cloud) do cloud2[k]=v end
cloud2.m_id=901;cloud2.m_pos={x=520,y=500};cloud2.m_posDest={x=520,y=500}
g14.objects[901]=cloud2;AREA14.m_lVertSortFlight={900,901}
g14.ticks=142
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
assert(zoneRows14()==2 and last14('zone').id==901 and last14('zone').x==520)
g14.objects[901]=nil;AREA14.m_lVertSortFlight={900}
caster14.m_pos=outside14
g14.ticks=143
g14.listeners.started[1](caster14,action(31,'TESTBOLT',11))
caster14.m_curAction=action(31,'TESTBOLT',11)
-- The bolt is over; the mage has no weapon and waits for its casting aura.
g14.ticks=175
caster14.m_curAction={m_actionID=0};caster14.castTimer=32
assert(g14.BGSE_Claim(caster14,'mage','s1')==true and last14('wait').tick==175 and ch14:inspect().waiting==1)
-- Waiting, the mage stands in the cloud again: it walks out all the same.
caster14.m_pos={x=510,y=500};caster14.castTimer=42
g14.ticks=185
assert(g14.BGSE_Claim(caster14,'mage','s1')==true)
local f14=last14('choice')
assert(f14.tick==185 and f14.castKind=='escape' and f14.how=='flee' and ch14:inspect().counts.escapes==2)
assert(ch14:inspect().waiting==0)
g14.BGSE_Act(caster14)
assert(g14.queued[#g14.queued].text:find('^MoveToPoint') and ch14:inspect().moving==1)
caster14.castTimer=nil
-- Casting what the engine did not choose (a block of SCS's above the hook): the engine has no way
-- out now, and SCS's escape keeps its say (in a cloud that hurts).
caster14.m_curAction=action(31,'TESTBOLT',11)
g14.ticks=280
assert(g14.BGSE_Claim(caster14,'mage','s1')==false and ch14:inspect().counts.escapes==2)
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
-- Idle, the engine weighs zones again; not for a creature off its side, nor with the choice off.
-- A read that fails as a whole hands the escape back to SCS too.
caster14.m_curAction={m_actionID=0}
assert(g14.BGSE_Zones(caster14,'mage','s1')==true)
caster14.m_typeAI.m_EnemyAlly=2
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
caster14.m_typeAI.m_EnemyAlly=255
ch14:setEnabled(false)
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
ch14:setEnabled(true)
assert(g14.BGSE_Zones(caster14,'mage','s1')==true)
-- No enemy in sight (the cloud's caster has walked out of sight): the mage still walks out of the
-- cloud. SCS's escape and stand-still stand aside for that way out (lab batch H7); outside the
-- cloud, with no enemy in sight, they run as before.
g14.objects[11].m_pos={x=500,y=1500}
g14.ticks=290
assert(g14.BGSE_Zones(caster14,'mage','s1')==true)
local inside14=caster14.m_pos
caster14.m_pos=outside14
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
caster14.m_pos=inside14
assert(g14.BGSE_Claim(caster14,'mage','s1')==true)
assert(last14('choice').castKind=='escape' and last14('choice').how=='flee' and ch14:inspect().counts.escapes==3)
g14.objects[11].m_pos={x=500,y=800}
AREA14.m_lVertSortFlight=function() end
g14.ticks=300
g14.BGSE_Claim(caster14,'mage','s1')
assert(ch14:inspect().zoneError and ch14:inspect().counts.zoneFailures>=1)
assert(g14.BGSE_Zones(caster14,'mage','s1')==false)
end)()
groups=groups+1

-- 24. When a zone explodes next (D3e, lab batch H): every delay+1 ticks, the next time in
-- counter+1. Two mages each stand in an enemy cloud with one explosion left. Where it comes in a
-- tick, it hits the mage on any way out all the same, so leaving is worth nothing; where it comes
-- in five seconds, the mage walks out first. A search map that raises leaves the point as it is
-- and counts a zone failure.
;(function()
local AREA15={m_resref=str('AR0003'),m_lVertSortBack={},m_lVertSortFlight={950,951}}
local g15=world()
local isSprite15=g15.EEex_GameObject_IsSprite
g15.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.projectile==nil and isSprite15(o,allowDead) end
g15.EEex_Projectile_Type={CProjectileArea=8}
g15.EEex_Projectile_GetType=function(o) return o.projectile or 1 end
g15.EEex_CastUD=function(o) return o end
g15.EEex_Sprite_GetPersonalSpace=function() return 3 end
g15.EEex_Area_GetNearestOpenPosition=function() error('search map gone') end
local function cloud15(id,x,counter)
    local hot={m_effectId=12,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=8*65536,m_flags=1,
        m_probabilityUpper=100,m_probabilityLower=0,m_res=str(''),m_numDice=4,m_diceSize=9,m_savingThrow=0,m_saveMod=0,
        m_special=0,m_spellLevel=4,m_casterLevel=10,m_sourceRes=str('TESTCLDS')}
    g15.objects[id]={m_id=id,projectile=8,state=0,m_nRepetitionCount=1,m_bReachedDestination=1,m_pos={x=x,y=500},
        m_posDest={x=x,y=500},m_explosionRange=150,m_nDelay=75,m_nDelayCount=counter,m_sourceId=11,m_projectileType=3,
        m_resref=str('CLOUD'),m_effectList={hot}}
end
cloud15(950,500,0)
cloud15(951,900,75)
local reader15={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='CLOUD',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=150,radius=150,coneWidth=0}
        end
        return reader.lookup(kind,key)
    end}
local soon15=g15.add(sprite(1,500,500,255,{m_pArea=AREA15}))
learn(soon15,2,'TESTBOLT',2)
local late15=g15.add(sprite(2,900,500,255,{m_pArea=AREA15}))
learn(late15,2,'TESTBOLT',2)
g15.add(sprite(11,700,800,2,{m_pArea=AREA15})).stats[2]=5
local dir15=directors.new(g15,{reader=reader15})
local ch15=choices.new(g15,{reader=reader15,director=dir15,seed=24})
local rows15={}
ch15:setSink(function(row) rows15[#rows15+1]=row end)
runtime.install(g15,{director=dir15,choice=ch15,version='test'})
local function last15(kind,member)
    for n=#rows15,1,-1 do
        local row=rows15[n]
        if row.kind==kind and (member==nil or row.member==member) then return row end
    end
end
g15.ticks=100
g15.BGSE_Claim(soon15,'mage','s1')
local s15=last15('choice',1)
assert(not (s15 and s15.castKind=='escape') and ch15:inspect().counts.escapes==0)
assert(g15.BGSE_Claim(late15,'mage','s1')==true)
local c15=last15('choice',2)
assert(c15.castKind=='escape' and c15.spell=='ESCAPE' and c15.worth>0)
-- No search map: the mage walks to the point itself, and the failure is counted.
g15.BGSE_Act(late15)
local move15=last15('move',2)
assert(move15 and g15.queued[#g15.queued].text=='MoveToPoint(['..move15.to.x..'.'..move15.to.y..'])')
assert(ch15:inspect().counts.zoneFailures==1 and ch15:inspect().zoneError:find('zone-nearest',1,true))
end)()
groups=groups+1

-- 25. The engine's own drink or cast is held while it is the creature's action (lab batch H: a
-- potion drunk while the casting aura of the mage's last cast ran became its action at once and
-- waited for the aura; the engine left the round to SCS for SCS's timer, and SCS's attack block
-- replaced the drink). It is held while the aura runs, and for the casting time and pendingTicks
-- after; a creature frozen in a Time Stop is held until time resumes, and from then on as long
-- again. Past that, or once its action is another, the engine decides again; a cast still running
-- then is the creature's to finish.
;(function()
local g16=world()
local m16=g16.add(sprite(1,0,0,255,{m_baseStats={m_hitPoints=15,m_generalState=0}}))
m16.items[18]={cResRef=str('TESTPOTN'),m_useCount1=1}
local m17=g16.add(sprite(2,0,300,255,{m_baseStats={m_hitPoints=15,m_generalState=0}}))
m17.items[18]={cResRef=str('TESTPOTN'),m_useCount1=1}
g16.add(sprite(11,100,0,2))
local dir16=directors.new(g16,{reader=reader})
local ch16=choices.new(g16,{reader=reader,director=dir16,seed=25})
local rows16={}
ch16:setSink(function(row) rows16[#rows16+1]=row end)
runtime.install(g16,{director=dir16,choice=ch16,version='test'})
local function last16(kind,member)
    for n=#rows16,1,-1 do if rows16[n].kind==kind and rows16[n].member==member then return rows16[n] end end
end
local function claim16(s,tick) g16.ticks=tick;return g16.BGSE_Claim(s,'mage','s1') end
assert(claim16(m16,100)==true and last16('choice',1).use==true and last16('choice',1).spell=='TESTPOTN')
g16.BGSE_Act(m16)
assert(g16.queued[#g16.queued].text:find('UseItem%("TESTPOTN",Myself%)')~=nil)
-- The drink is the mage's action at once and waits for the casting aura of its last cast. The
-- round's marker covers it.
assert(m16.locals.castspell==190)
m16.castTimer=60
local drink=action(34,'TESTPOTN',1)
m16.m_curAction=drink
g16.listeners.started[1](m16,drink)
assert(ch16:inspect().running==1 and ch16:inspect().counts.started==1)
assert(claim16(m16,110)==true and claim16(m16,140)==true and ch16:inspect().counts.holds==2)
-- The aura was last seen busy at 140 and a drink has no casting time: held pendingTicks more.
m16.castTimer=nil
assert(claim16(m16,185)==true and ch16:inspect().counts.holds==3)
assert(claim16(m16,186)==true and ch16:inspect().counts.holds==3 and ch16:inspect().running==1 and
    last16('choice',1).tick==186)
-- Its action is another: no hold, and the drink is judged.
m16.m_curAction=action(3,'',11)
assert(claim16(m16,187)==true and ch16:inspect().running==0 and ch16:inspect().judging==1)
-- The second mage drinks; the enemy stops time, and the drink becomes the frozen mage's action.
assert(claim16(m17,300)==true and last16('choice',2).use==true)
g16.BGSE_Act(m17)
local game16=g16.EngineGlobals.g_pBaldurChitin.m_pObjectGame
game16.m_nTimeStop,game16.m_nTimeStopCaster=300,11
local drink17=action(34,'TESTPOTN',2)
m17.m_curAction=drink17
g16.listeners.started[1](m17,drink17)
local holds=ch16:inspect().counts.holds
assert(claim16(m17,320)==true and claim16(m17,600)==true and ch16:inspect().counts.holds==holds+2)
-- Time resumes at 610: held pendingTicks from there.
game16.m_nTimeStop,game16.m_nTimeStopCaster=0,0
assert(claim16(m17,610)==true and claim16(m17,655)==true and ch16:inspect().counts.holds==holds+4)
assert(claim16(m17,656)==true and ch16:inspect().counts.holds==holds+4 and last16('choice',2).tick==656)
-- A cast is held for its casting time as well: the bolt's three speed points (30 ticks), then
-- pendingTicks. A cast still running past that is the mage's to finish.
local m18=g16.add(sprite(3,0,-200,255))
learn(m18,2,'TESTBOLT')
assert(claim16(m18,700)==true and last16('choice',3).spell=='TESTBOLT')
g16.BGSE_Act(m18)
local bolt18=action(31,'TESTBOLT',11)
m18.m_curAction=bolt18
g16.listeners.started[1](m18,bolt18)
assert(claim16(m18,775)==true and ch16:inspect().counts.holds==holds+5)
assert(claim16(m18,776)==false and ch16:inspect().reasons.casting==1)
end)()
groups=groups+1

-- 26. The casting aura (lab batch H5): a cast chosen while the aura of the creature's last cast
-- runs starts casting when the aura frees, so the choice gets the seconds until then (zones count
-- the explosions during the casting from there).
;(function()
local logic=require('combat-intent.choice')
local g17=world()
local m19=g17.add(sprite(1,0,0,255))
learn(m19,2,'TESTBOLT',2)
g17.add(sprite(11,100,0,2))
local ch17=choices.new(g17,{reader=reader,seed=26})
runtime.install(g17,{choice=ch17,version='test'})
local decide,seen=logic.decide,{}
logic.decide=function(input) seen[#seen+1]=input.frame.self.aura;return decide(input) end
local ok,err=pcall(function()
    m19.castTimer=70
    g17.ticks=100
    assert(g17.BGSE_Claim(m19,'mage','s1')==true)
    m19.castTimer=-1
    g17.ticks=300
    g17.BGSE_Claim(m19,'mage','s1')
end)
logic.decide=decide
assert(ok,err)
assert(#seen==2 and math.abs(seen[1]-30/15)<1e-9 and seen[2]==0)
end)()
groups=groups+1

-- 27. Spell slots (Christopher, 2026-10-21): the choice gets the share of a slot's cost
-- (combat-intent/choice.lua, slotShare) for the caster's ready spells under the threat it sees,
-- and the record keeps it for the lab.
;(function()
local logic=require('combat-intent.choice')
local g18=world()
local m20=g18.add(sprite(1,0,0,255))
learn(m20,2,'TESTBOLT',12)
g18.add(sprite(11,100,0,2))
local ch18=choices.new(g18,{reader=reader,seed=27})
local rows={}
ch18:setSink(function(row) rows[#rows+1]=row end)
runtime.install(g18,{choice=ch18,version='test'})
local decide,seen=logic.decide,{}
logic.decide=function(input) seen[#seen+1]={given=input.slots,share=logic.slotShare(input)};return decide(input) end
local ok,err=pcall(function() g18.ticks=100;g18.BGSE_Claim(m20,'mage','s1') end)
logic.decide=decide
assert(ok,err)
local last
for _,r in ipairs(rows) do if r.kind=='choice' or r.kind=='decline' then last=r end end
assert(#seen==1 and type(seen[1].given)=='number' and seen[1].given==seen[1].share and seen[1].given<1)
assert(last and last.kind=='choice' and last.slots==seen[1].given)
end)()
groups=groups+1

-- 28. Lasting areas (D3e; Christopher, 2026-10-23): what the group sees its enemies do in zones
-- that hurt them. The mage's own cloud (4d9 fire a hit, sparing the mage's allies) holds four
-- enemies of the party: one stays,
-- one walks out, one is held, one minds no fire. The engine looks at most every five ticks for an
-- area: an enemy still inside after explosions stayed for each, one seen outside while the zone
-- is there left it; the held one counts nothing while held, the fireproof one nothing at all. A
-- zone that is gone is forgotten, and a load forgets everything. The choice gets what the group
-- saw (input.stays), and so does inspect.
;(function()
local logic=require('combat-intent.choice')
local AREA28={m_resref=str('AR0028'),m_lVertSortBack={},m_lVertSortFlight={950}}
local g28=world()
local isSprite28=g28.EEex_GameObject_IsSprite
g28.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.projectile==nil and isSprite28(o,allowDead) end
g28.EEex_Projectile_Type={CProjectileArea=8}
g28.EEex_Projectile_GetType=function(o) return o.projectile or 1 end
g28.EEex_CastUD=function(o) return o end
local hot={m_effectId=12,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=8*65536,m_flags=1,m_probabilityUpper=100,
    m_probabilityLower=0,m_res=str(''),m_numDice=4,m_diceSize=9,m_savingThrow=0,m_saveMod=0,m_special=0,m_spellLevel=4,
    m_casterLevel=10,m_sourceRes=str('TESTOWNC')}
local cloud={m_id=950,projectile=8,state=0,m_nRepetitionCount=4,m_bReachedDestination=1,m_pos={x=500,y=500},
    m_posDest={x=500,y=500},m_explosionRange=150,m_nDelay=75,m_nDelayCount=0,m_sourceId=1,m_projectileType=3,
    m_resref=str('CLOUD'),m_effectList={hot}}
g28.objects[950]=cloud
local reader28={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='CLOUD',type=3,speed=20,flags=0,extFlags=0,areaFlags=64,trigger=150,radius=150,
                coneWidth=0,repeats=10,delay=75}
        end
        return reader.lookup(kind,key)
    end}
local mage28=g28.add(sprite(1,700,500,255,{m_pArea=AREA28}))
learn(mage28,2,'TESTBOLT',2)
g28.add(sprite(11,500,500,2,{m_pArea=AREA28}))
local leaver=g28.add(sprite(12,520,500,2,{m_pArea=AREA28}))
local held=g28.add(sprite(13,480,500,2,{m_pArea=AREA28}))
held.stats[58]=1
g28.add(sprite(14,500,520,2,{m_pArea=AREA28})).stats[14]=100
local dir28=directors.new(g28,{reader=reader28})
local ch28=choices.new(g28,{reader=reader28,director=dir28,seed=28})
runtime.install(g28,{director=dir28,choice=ch28,version='test'})
local decide,seen=logic.decide,nil
logic.decide=function(input) seen=input.stays;return decide(input) end
local ok,err=pcall(function()
    local function claim(tick) g28.ticks=tick;g28.BGSE_Claim(mage28,'mage','s1') end
    local function stays() return ch28:inspect().stays end
    claim(100)
    assert(next(stays())==nil and ch28:inspect().counts.zoneFailures==0)
    -- An explosion goes by: the stayer is still inside, the other has walked out. Three ticks
    -- after the last look is too soon; five is not.
    cloud.m_nRepetitionCount=3;leaver.m_pos={x=800,y=500}
    claim(103)
    assert(next(stays())==nil)
    claim(105)
    local s=stays()
    assert(s[11].stay==1 and s[11].left==0 and s[12].stay==0 and s[12].left==1 and s[13]==nil and s[14]==nil)
    assert(ch28:inspect().counts.stayed==1 and ch28:inspect().counts.left==1)
    -- No explosion since: nothing new. Two more: two more stays. The held one is free and inside.
    claim(110)
    assert(stays()[11].stay==1)
    cloud.m_nRepetitionCount=1;held.stats[58]=0
    claim(115)
    s=stays()
    assert(s[11].stay==3 and s[13]==nil and s[14]==nil)
    assert(seen and seen[11].stay==3 and seen[12].left==1)
    -- Gone, then read again with the enemies outside: forgotten, so nobody left it.
    AREA28.m_lVertSortFlight={}
    claim(120)
    AREA28.m_lVertSortFlight={950}
    g28.objects[11].m_pos={x=800,y=520};held.m_pos={x=820,y=500}
    claim(125)
    s=stays()
    assert(s[11].left==0 and s[13]==nil and ch28:inspect().counts.zoneFailures==0)
    -- A load forgets it all, object ids being the session's own: one seen inside before it is no
    -- leaver after it, and the engine looks again at once (one seen inside a tick after the load
    -- left when next seen outside).
    g28.objects[11].m_pos={x=500,y=500}
    claim(130)
    ch28:invalidate()
    assert(next(stays())==nil)
    g28.objects[11].m_pos={x=800,y=520};leaver.m_pos={x=500,y=500}
    claim(131)
    assert(next(stays())==nil)
    leaver.m_pos={x=800,y=500}
    claim(136)
    s=stays()
    assert(s[11]==nil and s[12].left==1 and s[12].stay==0)
end)
logic.decide=decide
assert(ok,err)
end)()
groups=groups+1

-- 29. Wit (MIND-01; Christopher, 2026-10-24: "Reihenfolge Override, Art des Monsters, gewollte
-- Int- und Wisdom-Werte und Schwierigkeit"). Each creature thinks with the default profile and its
-- own wit, made from its INT and WIS (STATS.IDS 38 and 39), its IDS values, its file, its script
-- family and the game's difficulty, and made again only when one of them changes; a 'wit' row logs
-- it. In an enemy's cloud a dull mage (a meant INT of 4) sees no zone: SCS's cloud blocks stand
-- aside and it casts as if there were none. Each time its hit points have dropped while the cloud
-- hurts it, it draws once whether the pain drives it out ('pain' rows); once driven out it leaves
-- until it is out of the cloud, and SCS's escape may break a cast of its own meanwhile. A rage
-- (the Berserker's, SPLSTATE.IDS 77) keeps a clever mage in the cloud while it has more than half
-- its hit points; the fatigue after it (75) does not. On Insane the dull mage is normal and walks
-- out by itself. Overrides by creature file,
-- wit switched off, a load, and a stat that cannot be read (the default profile).
;(function()
local AREA29={m_resref=str('AR0029'),m_lVertSortBack={},m_lVertSortFlight={960}}
local g29=world()
local isSprite29=g29.EEex_GameObject_IsSprite
g29.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.projectile==nil and isSprite29(o,allowDead) end
g29.EEex_Projectile_Type={CProjectileArea=8}
g29.EEex_Projectile_GetType=function(o) return o.projectile or 1 end
g29.EEex_CastUD=function(o) return o end
g29.EEex_Sprite_GetPersonalSpace=function() return 3 end
g29.EEex_Area_GetNearestOpenPosition=function(area,x,y) return x,y end
-- The spell state each creature is in.
local states={}
g29.EEex_Sprite_GetSpellState=function(s,n) return states[s.m_id]==n end
local hot={m_effectId=12,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=8*65536,m_flags=1,m_probabilityUpper=100,
    m_probabilityLower=0,m_res=str(''),m_numDice=4,m_diceSize=9,m_savingThrow=0,m_saveMod=0,m_special=0,m_spellLevel=4,
    m_casterLevel=10,m_sourceRes=str('TESTCLDS')}
g29.objects[960]={m_id=960,projectile=8,state=0,m_nRepetitionCount=20,m_bReachedDestination=1,m_pos={x=500,y=500},
    m_posDest={x=500,y=500},m_explosionRange=150,m_nDelay=75,m_nDelayCount=0,m_sourceId=11,m_projectileType=3,
    m_resref=str('CLOUD'),m_effectList={hot}}
local reader29={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='CLOUD',type=3,speed=20,flags=0,extFlags=0,areaFlags=64,trigger=150,radius=150,coneWidth=0}
        end
        return reader.lookup(kind,key)
    end}
-- 1 is dull (INT 4, WIS 8: danger 0.9); 2 is clever by its kind (a mage's file without meant
-- values) and has 60 hit points; 3 is dull and of average wisdom (INT 3, WIS 10).
local dull=g29.add(sprite(1,500,500,255,{m_pArea=AREA29}))
dull.stats[38],dull.stats[39]=4,8
learn(dull,2,'TESTBOLT',2)
local clever=g29.add(sprite(2,520,500,255,{m_pArea=AREA29,m_baseStats={m_hitPoints=60,m_generalState=0}}))
clever.stats[1]=60
learn(clever,2,'TESTBOLT',2)
local calm=g29.add(sprite(3,480,500,255,{m_pArea=AREA29}))
calm.stats[38],calm.stats[39]=3,10
learn(calm,2,'TESTBOLT',2)
g29.add(sprite(11,500,800,2,{m_pArea=AREA29})).stats[2]=5
local dir29=directors.new(g29,{reader=reader29})
local ch29=choices.new(g29,{reader=reader29,director=dir29,seed=29})
local rows29={}
ch29:setSink(function(row) rows29[#rows29+1]=row end)
runtime.install(g29,{director=dir29,choice=ch29,version='test'})
local function all(kind,member)
    local list={}
    for _,row in ipairs(rows29) do if row.kind==kind and (member==nil or row.member==member) then list[#list+1]=row end end
    return list
end
local function last29(kind,member) local list=all(kind,member);return list[#list] end
local function claim29(s,tick) g29.ticks=tick;return g29.BGSE_Claim(s,'mage','s1') end
local function counts() return ch29:inspect().counts end
-- The dull mage casts as if there were no cloud; SCS's cloud blocks stand aside for it, also
-- while it casts. Asked again with nothing changed, it keeps its profile.
assert(claim29(dull,100)==true)
local w=last29('wit',1)
assert(w and w.tick==100 and w.step=='dull' and w.from=='stats' and w.int==4 and w.wis==8 and
    math.abs(w.danger-0.9)<1e-9 and w.difficulty==nil and w.family=='mage' and w.resref=='TEST1' and
    w.group=='high' and w.race=='HUMAN' and math.abs(w.best-0.4)<1e-9)
local c=last29('choice',1)
assert(c.tick==100 and c.spell=='TESTBOLT' and c.wit=='dull' and counts().pains==0)
assert(g29.BGSE_Zones(dull,'mage','s1')==true)
dull.m_curAction=action(31,'TESTBOLT',11)
assert(g29.BGSE_Zones(dull,'mage','s1')==true)
dull.m_curAction={m_actionID=0}
assert(claim29(dull,101)==true and #all('wit',1)==1 and counts().pains==0)
-- An explosion takes 24 of its 40 hit points: the pain drives it out for sure (2 x 0.6 x 0.9 is
-- more than 1), whatever it could cast.
dull.m_baseStats.m_hitPoints=16
assert(claim29(dull,110)==true)
local p=last29('pain',1)
assert(p and p.tick==110 and p.hp==16 and p.lost==24 and p.chance==1 and p.leaves==true and counts().pains==1)
c=last29('choice',1)
assert(c.tick==110 and c.castKind=='escape' and c.forced==true and c.wit=='dull')
g29.BGSE_Act(dull)
assert(g29.queued[#g29.queued].text:find('^MoveToPoint') and ch29:inspect().moving==1)
-- Still in the cloud after the walk: it leaves again, without a new draw. SCS's escape may break a
-- cast of its own meanwhile.
assert(claim29(dull,125)==true and counts().unescaped==1 and counts().pains==1)
c=last29('choice',1)
assert(c.tick==125 and c.castKind=='escape' and c.forced==true)
dull.m_curAction=action(31,'TESTBOLT',11)
assert(g29.BGSE_Zones(dull,'mage','s1')==false)
dull.m_curAction={m_actionID=0}
assert(g29.BGSE_Zones(dull,'mage','s1')==true)
-- Out of the cloud the pain is over, and hit points lost outside it draw nothing; back in, it
-- stays until they drop again.
dull.m_pos={x=700,y=600}
assert(claim29(dull,140)==true and last29('choice',1).spell=='TESTBOLT')
dull.m_baseStats.m_hitPoints=14
claim29(dull,150)
assert(counts().pains==1)
dull.m_pos={x=500,y=500}
assert(claim29(dull,160)==true and last29('choice',1).tick==160 and last29('choice',1).spell=='TESTBOLT' and
    counts().pains==1)
-- A scratch on the other dull mage: a small chance to leave (2 x 1/40 x 1), and the decision
-- follows the draw.
assert(claim29(calm,170)==true)
w=last29('wit',3)
assert(w.step=='dull' and w.from=='stats' and w.int==3 and w.wis==10 and w.danger==1)
calm.m_baseStats.m_hitPoints=39
claim29(calm,180)
p=last29('pain',3)
assert(p and p.tick==180 and p.hp==39 and p.lost==1 and math.abs(p.chance-0.05)<1e-9 and type(p.leaves)=='boolean')
c=last29('choice',3)
assert(c.tick==180 and (c.castKind=='escape')==p.leaves)
local pains=counts().pains
-- The clever mage walks out of the cloud, also tired after a rage. Raging, it stays while it has
-- more than half its hit points: no way out, and SCS's cloud blocks stand aside (its bolt would
-- break in the cloud, so it waits); at half it walks out.
states[2]=75
assert(claim29(clever,200)==true)
w=last29('wit',2)
assert(w and w.step=='clever' and w.from=='kind' and w.int==15 and w.wis==10 and w.danger==1 and
    math.abs(w.best-0.8)<1e-9)
c=last29('choice',2)
assert(c.castKind=='escape' and c.forced==nil and c.wit=='clever')
states[2]=77
local escapes=counts().escapes
assert(claim29(clever,210)==true and last29('wait',2).tick==210)
assert(counts().escapes==escapes and last29('choice',2).tick==200 and g29.BGSE_Zones(clever,'mage','s1')==true)
clever.m_baseStats.m_hitPoints=30
assert(claim29(clever,220)==true and last29('choice',2).tick==220 and last29('choice',2).castKind=='escape')
states[2]=nil
-- On Insane the dull mage's INT and WIS are four points higher: normal, it sees the cloud and
-- walks out by itself. At Normal it is dull again.
local game=g29.EngineGlobals.g_pBaldurChitin.m_pObjectGame
game.m_options={m_nDifficultyLevel=5}
dull.m_baseStats.m_hitPoints=40
assert(claim29(dull,300)==true)
w=last29('wit',1)
assert(w.tick==300 and w.step=='normal' and w.from=='stats' and w.int==8 and w.wis==12 and
    math.abs(w.danger-1.1)<1e-9 and w.difficulty==5)
c=last29('choice',1)
assert(c.tick==300 and c.castKind=='escape' and c.forced==nil and c.wit=='normal' and counts().pains==pains)
game.m_options.m_nDifficultyLevel=3
assert(claim29(dull,310)==true and last29('wit',1).step=='dull' and last29('wit',1).difficulty==3 and
    last29('choice',1).spell=='TESTBOLT')
-- An override by creature file sets the step: the dull mage thinks cleverly and keeps the WIS its
-- file means. A bad table is refused; nil ends the overrides.
assert(ch29:setWitOverrides({TEST1={step='clever'}})==true)
assert(claim29(dull,320)==true)
w=last29('wit',1)
assert(w.tick==320 and w.step=='clever' and w.from=='override' and w.int==15 and w.wis==8 and
    last29('choice',1).castKind=='escape')
local ok,why=ch29:setWitOverrides('TEST1')
assert(ok==false and why=='overrides')
assert(ch29:setWitOverrides(nil)==true and claim29(dull,330)==true and last29('wit',1).step=='dull')
-- Wit off: every creature thinks with the default profile (clever), without 'wit' rows; on again,
-- each profile is made anew.
ch29:setWit(false)
local made=#all('wit')
assert(claim29(dull,340)==true and last29('choice',1).wit=='clever' and last29('choice',1).castKind=='escape')
assert(#all('wit')==made and ch29:inspect().wit==false)
ch29:setWit(true)
assert(claim29(dull,350)==true and #all('wit')==made+1 and last29('wit',1).step=='dull' and ch29:inspect().wit==true)
-- A load forgets the profiles and the hit points last seen: the first look after it draws
-- nothing, the next drop does.
ch29:invalidate()
dull.m_baseStats.m_hitPoints=20
assert(claim29(dull,360)==true and #all('wit')==made+2 and counts().pains==pains and last29('choice',1).spell=='TESTBOLT')
dull.m_baseStats.m_hitPoints=10
assert(claim29(dull,370)==true and counts().pains==pains+1 and last29('pain',1).chance==1 and
    last29('choice',1).forced==true)
-- A stat that cannot be read leaves the creature the default profile, counted, and logged once.
local getStat=g29.EEex_Sprite_GetStat
g29.EEex_Sprite_GetStat=function(s,n) if n==choices.intStat then error('stat gone') end return getStat(s,n) end
ch29:invalidate()
dull.m_baseStats.m_hitPoints=40
assert(claim29(dull,380)==true)
local state=ch29:inspect()
local errors=0
for _,row in ipairs(all('error')) do if row.where=='wit' then errors=errors+1 end end
assert(state.counts.witFailures>=1 and state.witError:find('stat gone',1,true) and errors==1)
assert(last29('choice',1).tick==380 and last29('choice',1).wit=='clever')
g29.EEex_Sprite_GetStat=getStat
end)()
groups=groups+1

-- 30. Walking into range (R3). A mage's short bolt (range 10: 160) at its only enemy, 410 away:
-- SpellRES walks into range first, 2.5 seconds, which the choice row logs. The round's marker
-- covers the walk as well, for as long as the engine holds the cast: 75 ticks, twice the straight
-- walk, as paths bend. A queued cast is held that much longer, and a started one for its casting
-- time, the walk and pendingTicks. Its casting begins once the walk is over, when the casting aura
-- starts again: broken off right after, it says nothing of the target, nor does one that never
-- began to cast and ended on the way. A cast that runs its casting time after the walk is judged.
;(function()
local nearRec=spl('TESTNEAR',3,{fx(12,{p2=8*65536,dice=6,sides=6})})
nearRec.abilities[1].range=10
records.TESTNEAR=nearRec
local g30=world()
local m30=g30.add(sprite(1,0,0,255))
learn(m30,2,'TESTNEAR',3)
local e30=g30.add(sprite(11,410,0,2))
local dir30=directors.new(g30,{reader=reader})
local ch30=choices.new(g30,{reader=reader,director=dir30,seed=30})
local rows30={}
ch30:setSink(function(row) rows30[#rows30+1]=row end)
runtime.install(g30,{director=dir30,choice=ch30,version='test'})
local function last30(kind) for n=#rows30,1,-1 do if rows30[n].kind==kind then return rows30[n] end end end
local function claim30(tick) g30.ticks=tick;return g30.BGSE_Claim(m30,'mage','s1') end
local function counts30() return ch30:inspect().counts end
local function begin30(tick)
    g30.ticks=tick
    local cast=action(31,'TESTNEAR',11)
    m30.m_curAction=cast
    g30.listeners.started[1](m30,cast)
end
assert(claim30(100)==true)
local c30=last30('choice')
assert(c30.spell=='TESTNEAR' and c30.target==11 and c30.walk==2.5)
g30.BGSE_Act(m30)
assert(g30.queued[#g30.queued].text=='SpellRES("TESTNEAR",EEex_Target("BGSE"))' and m30.locals.castspell==100+30+75+15)
-- Queued, never started: held pendingTicks and the walk's 75 ticks, then given up.
assert(claim30(220)==true and counts30().holds==1)
assert(claim30(221)==true and counts30().lost==1 and last30('choice').tick==221)
g30.BGSE_Act(m30)
assert(m30.locals.castspell==221+120)
-- Started: held through the walk (78 ticks on, past casting time and pendingTicks alone).
begin30(222)
assert(claim30(300)==true and counts30().holds==2)
-- The casting begins at 310 and breaks off at 325, well short of its casting time.
m30.castTimer=5
assert(claim30(315)==true and counts30().holds==3)
m30.m_curAction={m_actionID=0};m30.castTimer=15
assert(claim30(325)==true and last30('choice').castKind=='position' and last30('choice').cast=='TESTNEAR')
m30.castTimer=45
assert(claim30(355)==true and counts30().interrupted==1 and counts30().misses==0 and ch30:inspect().remembered==0)
-- The aura frees; the next cast starts at 411 and ends on the way, never casting.
m30.castTimer=nil
assert(claim30(410)==true and last30('choice').walk==2.5)
g30.BGSE_Act(m30)
begin30(411)
local holds30=counts30().holds
assert(claim30(430)==true and counts30().holds==holds30+1)
m30.m_curAction={m_actionID=0}
assert(claim30(440)==true and last30('choice').tick==440)
assert(claim30(470)==true and counts30().interrupted==2 and counts30().misses==0)
-- The last walks 25 ticks, casts from 496 to 530 and burns the enemy: a hit.
g30.BGSE_Act(m30)
begin30(471)
m30.castTimer=4
assert(claim30(500)==true)
m30.m_curAction={m_actionID=0};m30.castTimer=34
e30.m_baseStats.m_hitPoints=20
assert(claim30(530)==true)
m30.castTimer=64
assert(claim30(560)==true and counts30().hits==1 and counts30().interrupted==2 and last30('outcome').hit==true)
end)()
groups=groups+1

-- 31. Orders and interrupting. A mage with a quick spell (speed 1) sees enemy 11, the protagonist
-- (the first character by joining), and enemy 12, which the spell would kill and the group focuses.
-- Ordered to always attack the protagonist, it does, and the choice row says so; a bad order table
-- changes nothing, and none at the start leaves none, saying why. Without orders, 11 casting a
-- ninth-level spell a second in draws the quick spell there, in time: the row logs what breaking
-- it adds (0.9). A forced cast cannot be broken.
;(function()
records.TESTQUIK=spl('TESTQUIK',1,{fx(12,{p1=1,p2=64*65536,dice=1,sides=4})})
records.TESTQUIK.abilities[1].speed=1
records.TESTWISH=spl('TESTWISH',9,{fx(17,{p1=20})})
records.TESTWISH.abilities[1].speed=9
local g31=world()
g31.EEex_Sprite_GetCharacterIndex=function(s) return s.m_id==11 and 0 or -1 end
local m31=g31.add(sprite(1,0,0,255))
learn(m31,0,'TESTQUIK',3)
local e31=g31.add(sprite(11,100,0,2))
g31.add(sprite(12,200,0,2,{m_baseStats={m_hitPoints=3,m_generalState=0}}))
local dir31=directors.new(g31,{reader=reader})
local ch31=choices.new(g31,{reader=reader,director=dir31,seed=31,orders={test1={target='protagonist',always=true}}})
local rows31={}
ch31:setSink(function(row) rows31[#rows31+1]=row end)
runtime.install(g31,{director=dir31,choice=ch31,version='test'})
local function last31(kind) for n=#rows31,1,-1 do if rows31[n].kind==kind then return rows31[n] end end end
local function claim31(tick) g31.ticks=tick;return g31.BGSE_Claim(m31,'mage','s1') end
assert(claim31(100)==true)
local c31=last31('choice')
assert(c31.spell=='TESTQUIK' and c31.target==11 and c31.ordered==true and c31.interrupt==nil and c31.focus==12)
local ok31,bad31=ch31:setOrders({TEST1={target='protagonist',always='yes'}})
assert(ok31==false and bad31=='TEST1: always')
assert(claim31(200)==true and last31('choice').target==11)
assert(ch31:setOrders(nil)==true)
assert(claim31(300)==true and last31('choice').target==12 and last31('choice').ordered==nil)
e31.m_curAction=action(31,'TESTWISH',1);e31.castTimer=15
assert(claim31(400)==true)
c31=last31('choice')
assert(c31.target==11 and near(c31.interrupt,0.9) and c31.ordered==nil)
e31.m_curAction=action(113,'TESTWISH',1)
assert(claim31(500)==true and last31('choice').target==12 and last31('choice').interrupt==nil)
assert(choices.new(g31,{reader=reader,orders={TEST1={target='protagonist',stay=true}}}):inspect().orderError=='TEST1: stay')
end)()
groups=groups+1

-- 32. Searching (combat-intent/search.lua, adapters/eeex/search.lua). A mage with a spell that lets
-- it see the invisible fights an enemy, which turns invisible on a spot the mage sees: it vanished.
-- The mage, clever and so tactical, casts the spell on itself; once it sees the enemy again, the
-- detection is judged by that. Where its fight began is its post. BGSE_Search is true for every
-- creature the engine drives, so SCS's own hunting stands aside.
;(function()
records.TESTSEE=spl('TESTSEE',2,{fx(193,{target=1,duration=30})},5,1)
local function setup(seed,orders)
    local w=world()
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,orders=orders})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    local function claimAt(s,tick,family,script) w.ticks=tick;return w.BGSE_Claim(s,family or 'mage',script or 's1') end
    return w,c,r,lastOf,claimAt
end
local g32,ch32,root32,last32,claim32=setup(32)
local m32=g32.add(sprite(1,0,0,255))
learn(m32,1,'TESTSEE')
local e32=g32.add(sprite(11,300,0,2))
assert(claim32(m32,100)==true and ch32:inspect().search.posts==1)
e32.state=0x10
assert(claim32(m32,116)==true)
local d32=last32('detect')
assert(d32 and d32.spell=='TESTSEE' and d32.self==true and d32.clue=='vanished' and d32.target==11 and d32.tactical==true)
assert(last32('hunt').tactical==true and last32('hunt').wit=='clever' and ch32:inspect().search.searching==1)
g32.BGSE_Act(m32)
assert(g32.queued[#g32.queued].text=='SpellRES("TESTSEE",Myself)' and ch32:inspect().search.counts.detects==1)
g32.ticks=117
g32.listeners.started[1](m32,action(31,'TESTSEE',-1))
m32.m_curAction=action(31,'TESTSEE',-1)
assert(claim32(m32,125)==true and ch32:inspect().running==1)
m32.m_curAction={m_actionID=0};m32.stats[81]=1
assert(claim32(m32,150)==true and ch32:inspect().search.searching==0)
assert(claim32(m32,185)==true and last32('reveal').seen==1 and ch32:inspect().counts.revealed==1)
assert(g32.BGSE_Search(m32,'mage','s1')==true and g32.BGSE_Search(m32,'fighter','s3')==false)
root32.setChoice(false)
assert(g32.BGSE_Search(m32,'mage','s1')==false)
root32.setChoice(true)
-- A creature off the engine's side (neutral, or charmed by the party) keeps SCS's own hunt.
m32.m_typeAI.m_EnemyAlly=128
assert(g32.BGSE_Search(m32,'mage','s1')==false)
m32.m_typeAI.m_EnemyAlly=255
assert(g32.BGSE_Search(m32,'mage','s1')==true)

-- A mage without any detection: its enemy walks out of its sight. It walks to where the group last
-- saw the enemy (MoveToPoint, held while it walks) and looks around there; once its patience (30
-- seconds, clever) is out, it gives up and walks back to its post, where its own life goes on.
local g33,ch33,root33,last33,claim33=setup(33)
local m33=g33.add(sprite(1,0,0,255))
local e33=g33.add(sprite(11,300,0,2))
local function seeker33() return ch33:inspect().search end
assert(claim33(m33,100)==true)
e33.m_pos={x=900,y=0}
assert(claim33(m33,140)==true and last33('hunt').clues==1)
g33.BGSE_Act(m33)
local s33=last33('search')
assert(g33.queued[#g33.queued].text=='MoveToPoint([300.0])' and s33.clue=='seen' and s33.target==11 and s33.to.x==300)
m33.m_curAction={m_actionID=23}
local holds33=ch33:inspect().counts.holds
assert(claim33(m33,150)==true and ch33:inspect().counts.holds==holds33+1)
m33.m_pos={x=300,y=0};m33.m_curAction={m_actionID=0}
assert(claim33(m33,200)==true and seeker33().counts.looks==1)
-- A look holds the round with the mage standing still, as a wait does.
local trail33=root33.inspect().trace
assert(trail33[#trail33].kind=='claim' and trail33[#trail33].reason=='idle')
-- The look goes on the same way: an idle hold, whose response runs while the mage stands and cuts
-- nothing.
assert(claim33(m33,210)==true and seeker33().counts.looks==1)
trail33=root33.inspect().trace
assert(trail33[#trail33].kind=='claim' and trail33[#trail33].reason=='idle')
g33.BGSE_Act(m33)
assert(ch33:inspect().counts.cut==0 and g33.queued[#g33.queued].text=='MoveToPoint([300.0])')
assert(claim33(m33,600)==true and last33('gave-up').since==140)
g33.BGSE_Act(m33)
assert(g33.queued[#g33.queued].text=='MoveToPoint([0.0])' and last33('return').gaveUp==true and seeker33().counts.gaveUp==1)
m33.m_pos={x=0,y=0}
assert(claim33(m33,700)==false and ch33:inspect().reasons['given-up']==1 and seeker33().posts==0)
-- Hit by the enemy, invisible now, from a spot it sees: anyone notices that. With nothing to detect
-- with and no heal worth casting, it searches toward where the attacker stands.
e33.state=0x10;e33.m_pos={x=200,y=0}
m33.m_lHitter={m_Instance=11};m33.m_baseStats.m_hitPoints=30
assert(claim33(m33,800)==true)
assert(last33('clue').clue=='hit' and last33('clue').near==true and last33('clue').lost==10 and seeker33().counts.hunts==2)
g33.BGSE_Act(m33)
assert(g33.queued[#g33.queued].text=='MoveToPoint([200.0])' and last33('search').clue=='hit')
-- A dead enemy is no clue: with none left the search is over.
e33.state=0x800
m33.m_curAction={m_actionID=0}
assert(claim33(m33,830)==false and ch33:inspect().reasons['given-up']==2 and last33('gave-up').why=='no-clue')

-- A mage whose last enemy vanishes into a maze (opcode 213 on it; its object stays where it vanished,
-- out of every area search) does not hunt it (Christopher, 2026-10-29): the director holds it out of
-- play, and the mage walks to its guard place 240 short of the spot (an 'await' row, then a 'guard'
-- walk), never handing the round to SCS. The maze over, the enemy is in sight again and no longer out
-- of play.
local g44,ch44,root44,last44,claim44=setup(44)
local m44=g44.add(sprite(1,0,0,255))
local e44=g44.add(sprite(11,300,0,2))
assert(claim44(m44,100)==true)
e44.m_timedEffectList={{m_effectId=213}}
table.remove(g44.order)
assert(claim44(m44,140)==true)
local w44=last44('await')
assert(w44 and w44.how=='guard' and w44.target==11 and w44.away=='maze' and last44('hunt')==nil)
assert(#root44.inspect().director.areas.AR0001.away==1)
g44.BGSE_Act(m44)
assert(g44.queued[#g44.queued].text=='MoveToPoint([60.0])' and last44('guard').target==11 and last44('search')==nil)
assert(ch44:inspect().search.counts.guardWalks==1 and ch44:inspect().reasons['given-up']==nil)
g44.order[#g44.order+1]=11
e44.m_timedEffectList={}
assert(claim44(m44,200)==true and #root44.inspect().director.areas.AR0001.away==0)
-- A party member the group charmed (EA 255 now, in the charmed state) stands on the mage's side: out
-- of play, not hunted, guarded like a mazed one; its wounds are no friend's (choices.ailing).
local g45,ch45,root45,last45,claim45=setup(45)
local m45=g45.add(sprite(1,0,0,255))
local e45=g45.add(sprite(11,300,0,2))
assert(claim45(m45,100)==true)
e45.m_typeAI.m_EnemyAlly=255;e45.state=0x2000
assert(claim45(m45,140)==true)
local w45=last45('await')
assert(w45 and w45.how=='guard' and w45.target==11 and w45.away=='charm' and last45('hunt')==nil)
local held45=root45.inspect().director.areas.AR0001.away
assert(#held45==1 and held45[1].id==11 and held45[1].kind=='charm')
assert(choices.ailing({self={hp=20,maxHp=20,state=0},allies={{hp=4,maxHp=20,state=0x2000}}})==false)
assert(choices.ailing({self={hp=20,maxHp=20,state=0},allies={{hp=4,maxHp=20,state=0}}})==true)

-- With no enemy in sight a priest heals a hurt ally; with nobody hurt and no clue, its own life goes
-- on.
local g34,ch34,_,last34,claim34=setup(34)
local p34=g34.add(sprite(7,0,0,255,{levels={[7]='S2'},stats={[1]=40,[34]=10}}))
learn(p34,3,'TESTHEAL')
local hurt34=g34.add(sprite(8,20,0,255,{stats={[1]=40,[34]=10}}))
assert(claim34(p34,100,'priest','s2')==false and ch34:inspect().reasons['no-enemy']==1)
hurt34.m_baseStats.m_hitPoints=4
assert(claim34(p34,200,'priest','s2')==true)
local c34=last34('choice')
assert(c34.castKind=='heal' and c34.target==8 and c34.spell=='TESTHEAL')

-- A boss (level 12, with two members of level 5 in its group) guards where its fight began: an
-- enemy last seen 400 away from there is not followed, it looks around at its post. Its orders can
-- let it search like anyone.
local function bossFight(seed,orders)
    local w,c,_,lastOf,claimAt=setup(seed,orders)
    local boss=w.add(sprite(1,0,0,255,{stats={[1]=40,[34]=12}}))
    local a=w.add(sprite(2,0,40,255,{stats={[1]=40,[34]=5}}))
    local b=w.add(sprite(3,0,-40,255,{stats={[1]=40,[34]=5}}))
    local e=w.add(sprite(11,400,0,2))
    assert(claimAt(a,100)==true and claimAt(b,100)==true and claimAt(boss,100)==true)
    e.m_pos={x=1200,y=0}
    return w,c,boss,lastOf,claimAt
end
local g35,ch35,boss35,last35,claim35=bossFight(35)
assert(ch35:inspect().search.counts.guards==1)
assert(claim35(boss35,140)==true and last35('search')==nil and ch35:inspect().search.counts.looks==1)
local g36,ch36,boss36,last36,claim36=bossFight(36,{TEST1={guard=false}})
assert(ch36:inspect().search.counts.guards==0 and claim36(boss36,140)==true)
g36.BGSE_Act(boss36)
assert(g36.queued[#g36.queued].text=='MoveToPoint([400.0])' and last36('search').member==1)

-- A creature with an innate teleport cast at a point (a phase spider's) whose enemy walks out of its
-- sight teleports to where the group last saw the enemy instead of walking: cast like the engine's
-- other spells (SpellPointRES, held while it runs) and judged by where the creature stands after.
records.TESTBLNK=spl('TESTBLNK',1,{fx(124,{target=1})},4)
records.TESTDOOR=spl('TESTDOOR',4,{fx(124,{target=1})},4)
local g37,ch37,_,last37,claim37=setup(37)
local s37=g37.add(sprite(1,0,0,255))
gift(s37,'TESTBLNK')
local e37=g37.add(sprite(11,300,0,2))
assert(claim37(s37,100)==true)
e37.m_pos={x=900,y=0}
assert(claim37(s37,140)==true)
g37.BGSE_Act(s37)
local t37=last37('teleport')
assert(g37.queued[#g37.queued].text=='SpellPointRES("TESTBLNK",[300.0])' and t37.spell=='TESTBLNK' and t37.to.x==300 and
    t37.clue=='seen' and t37.target==11 and t37.innate==true and ch37:inspect().search.counts.teleports==1)
g37.ticks=141
g37.listeners.started[1](s37,action(95,'TESTBLNK',-1))
s37.m_curAction=action(95,'TESTBLNK',-1)
assert(claim37(s37,150)==true and ch37:inspect().running==1)
s37.m_pos={x=300,y=0};s37.m_curAction={m_actionID=0}
assert(claim37(s37,175)==true)
assert(claim37(s37,210)==true and last37('landed').off==0 and ch37:inspect().counts.landed==1)

-- A memorized teleport spends its slot: a clever mage uses it for a longer walk, as far toward the
-- spot as it reaches (range 30: 480 of 700); a dull one walks.
local function doorFight(seed,int,wis)
    local w,c,_,lastOf,claimAt=setup(seed)
    local m=w.add(sprite(1,0,0,255))
    if int then m.stats[38],m.stats[39]=int,wis end
    learn(m,4,'TESTDOOR')
    local e=w.add(sprite(11,400,0,2))
    assert(claimAt(m,100)==true)
    e.m_pos={x=2000,y=0};m.m_pos={x=-300,y=0}
    assert(claimAt(m,140)==true)
    w.BGSE_Act(m)
    return w,c,lastOf
end
local g38,ch38,last38=doorFight(38)
assert(g38.queued[#g38.queued].text=='SpellPointRES("TESTDOOR",[180.0])' and last38('teleport').innate==nil and
    ch38:inspect().search.counts.teleports==1)
local g39,ch39,last39=doorFight(39,4,8)
assert(g39.queued[#g39.queued].text=='MoveToPoint([400.0])' and last39('teleport')==nil and
    ch39:inspect().search.counts.teleports==0)

-- A jump that would land in a danger zone short of its spot walks there instead; a spot in a zone
-- counts as searched, whether the creature would jump or walk there (range 30: it lands at 180 of
-- the 700 to the spot at 400).
local seekers=require('adapters.eeex.search')
local g40=world()
local s40=g40.add(sprite(1,-300,0,255))
g40.add(sprite(11,2000,0,2))
local director40={clues=function() return {{id=11,x=400,y=0,tick=100}} end,group=function() return {} end}
local seeker40=seekers.new(g40,{director=director40})
local rows40={{resref='TESTBLNK',ready=1,usable=true,list='innate',level=1,
    spell={target='point',range=30,speed=0,roles={move={kinds={teleport=true},who={self=true}}}}}}
local frame40={area='AR0002',self={id=1,x=-300,y=0,hp=40,maxHp=40,ea=255},enemies={}}
local function decide40(zoneAt) return seeker40:decide(s40,frame40,150,'mage',{wit='clever',tactics=1},rows40,{},zoneAt) end
local d40=decide40(nil)
assert(d40.kind=='teleport' and d40.resref=='TESTBLNK' and d40.point.x==180 and d40.toward.x==400)
d40=decide40(function(p) return p.x>=100 and p.x<=300 end)
assert(d40.kind=='search' and d40.point.x==400 and d40.clue=='seen' and d40.target==11)
d40=decide40(function(p) return p.x>=300 end)
assert(d40.kind=='look' and d40.zone==true and d40.searched==d40.key)
-- A jump into the fight counts for the search's gap too: 10 ticks after one, the creature walks.
local seeker41=seekers.new(g40,{director=director40})
seeker41:leapt(1,140)
assert(seeker41:jumped(1)==140 and seekers.new(g40,{}):jumped(1)==nil)
local d41=seeker41:decide(s40,frame40,150,'mage',{wit='clever',tactics=1},rows40,{},nil)
assert(d41.kind=='search' and d41.point.x==400)
-- Foes out of play (the director's away: one the group charmed, one in a maze) are no clues, not
-- even ones the creature kept. A clever mage guards the mazed one's spot from 240 (a 'guard' walk,
-- with one 'await' row for each new way of awaiting); at its place it keeps the place for the group's
-- spreading. A place in a danger zone makes a look. A dull one stands; orders can send it back to
-- its post. Once the foe is back, its clue counts again.
local rows42={}
local away42={{id=11,kind='maze',x=400,y=0,since=140,lastTick=150}}
local director42={clues=function() return {{id=11,x=400,y=0,tick=100}} end,group=function() return {} end,
    away=function() return away42 end}
local seeker42=seekers.new(g40,{director=director42,record=function(row) rows42[#rows42+1]=row end})
local function rows42of(kind)
    local out={}
    for _,row in ipairs(rows42) do if row.kind==kind then out[#out+1]=row end end
    return out
end
local function decide42(seeker,mind,zoneAt,orders)
    return seeker:decide(s40,frame40,150,'mage',mind or {wit='clever',tactics=1},{},{},zoneAt,orders)
end
local d42=decide42(seeker42)
assert(d42.kind=='guard' and d42.point.x==160 and d42.point.y==0 and d42.await==11 and d42.away=='maze' and d42.how=='guard')
local await42=rows42of('await')
assert(#await42==1 and await42[1].target==11 and await42[1].how=='guard' and await42[1].away=='maze' and
    await42[1].wit=='clever' and await42[1].point.x==160 and seeker42:inspect().counts.awaits==1)
d42=decide42(seeker42)
assert(d42.kind=='guard' and #rows42of('await')==1 and #rows42of('hunt')==0)
seeker42:walk(s40,d42,{x=160,y=0},150)
local walk42=rows42of('guard')
assert(#walk42==1 and walk42[1].target==11 and walk42[1].to.x==160 and seeker42:inspect().counts.guardWalks==1)
-- Arrived: it looks out there.
frame40.self.x=160
d42=decide42(seeker42)
assert(d42.kind=='look' and d42.point.x==160 and #rows42of('await')==1)
frame40.self.x=-300
d42=decide42(seeker42,nil,function(p) return p.x>=100 and p.x<=200 end)
assert(d42.kind=='look' and d42.zone==true and d42.point==nil and d42.how=='guard')
local seeker43=seekers.new(g40,{director=director42,record=function(row) rows42[#rows42+1]=row end})
local d43=decide42(seeker43,{wit='dull',tactics=0})
assert(d43.kind=='look' and d43.how=='stand' and rows42of('await')[2].how=='stand')
seeker43:fight(s40,{area='AR0002',self={id=1,x=600,y=0,hp=40,maxHp=40,ea=255},enemies={{id=11}}},140,nil)
d43=decide42(seeker43,{wit='dull',tactics=0},nil,{await='post'})
assert(d43.kind=='return' and d43.point.x==600 and d43.how=='post')
-- A way back that comes no nearer: stuck, it looks out where it is (no hand-over to SCS).
d43=decide42(seeker43,{wit='dull',tactics=0},nil,{await='post'})
assert(d43.kind=='return')
d43=decide42(seeker43,{wit='dull',tactics=0},nil,{await='post'})
assert(d43.kind=='look' and d43.how=='post' and #rows42of('stuck')==1 and rows42of('gave-up')[1].why=='stuck')
-- The foe is back: its clue counts again, and nothing is awaited.
away42={}
d42=decide42(seeker42)
assert(d42.kind=='search' and d42.target==11 and d42.await==nil and #rows42of('hunt')==1)
-- Two guards of one foe keep apart: the second takes the next place on the ring while the first
-- walks to its own, and a guard looking out at its place keeps it longer than a walk would.
local away47={{id=11,kind='maze',x=400,y=400,since=140,lastTick=150}}
local seeker47=seekers.new(g40,{director={clues=function() return {} end,group=function() return {} end,
    away=function() return away47 end}})
local s47=g40.add(sprite(2,100,400,255))
local fa={area='AR0002',self={id=1,x=100,y=400,hp=40,maxHp=40,ea=255},enemies={}}
local fb={area='AR0002',self={id=2,x=100,y=400,hp=40,maxHp=40,ea=255},enemies={}}
local clever={wit='clever',tactics=1}
local da=seeker47:decide(s40,fa,150,'mage',clever,{},{},nil)
assert(da.kind=='guard' and da.point.x==160 and da.point.y==400)
seeker47:walk(s40,da,da.point,150)
local db=seeker47:decide(s47,fb,151,'mage',clever,{},{},nil)
assert(db.kind=='guard' and db.point.x==230 and db.point.y==273)
fa.self.x=160
local la=seeker47:decide(s40,fa,300,'mage',clever,{},{},nil)
assert(la.kind=='look' and la.point.x==160 and la.point.y==400)
db=seeker47:decide(s47,fb,400,'mage',clever,{},{},nil)
assert(db.kind=='guard' and db.point.x==230 and db.point.y==273)
end)()
groups=groups+1

-- 33. Jumps into the fight (combat-intent/choice.lua). A creature that walks to enemies for its
-- weapon (a fighter's profile) with a staff and an innate teleport of BGSETELE's kind (instant,
-- Teleport Without Error's reach) sees an enemy 400 away: it teleports next to it, worth more than
-- the walk though less than a spell must be (SpellPointRES at the nearest open spot, 48 short of
-- the enemy, with a 'leap' row), cast and held like the engine's other casts and judged by where it
-- lands; then it strikes. 18 seconds after the jump it may jump again, not before.
;(function()
local profiles=require('combat-intent.mind')
local leap=spl('TESTLEAP',1,{fx(124,{target=1})},4)
leap.spellType,leap.abilities[1].speed,leap.abilities[1].range=4,0,200
records.TESTLEAP=leap
local g=world()
local jumper=g.add(armed(sprite(1,0,0,255),35,'TESTSTAF'))
jumper.stats[8],jumper.stats[7],jumper.stats[2]=2,14,8
jumper.m_baseStats.m_hitPoints=400;jumper.stats[1]=400
gift(jumper,'TESTLEAP')
local foe=g.add(sprite(11,400,0,2))
foe.stats[2]=5
local dir=directors.new(g,{reader=reader9})
local ch=choices.new(g,{reader=reader9,director=dir,seed=41,
    mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
local rows={}
ch:setSink(function(row) rows[#rows+1]=row end)
runtime.install(g,{director=dir,choice=ch,version='test'})
local function last(kind) for n=#rows,1,-1 do if rows[n].kind==kind then return rows[n] end end end
local function claim(tick) g.ticks=tick;return g.BGSE_Claim(jumper,'mage','s1') end
assert(claim(100)==true)
local c=last('choice')
assert(c.castKind=='teleport' and c.how=='jump' and c.spell=='TESTLEAP' and c.target==11 and c.point.x==352 and
    c.point.y==0 and ch:inspect().counts.jumps==1)
g.BGSE_Act(jumper)
local l=last('leap')
assert(g.queued[#g.queued].text=='SpellPointRES("TESTLEAP",[352.0])' and l.to.x==352 and l.target==11 and
    l.spell=='TESTLEAP' and l.innate==true and l.from.x==0)
g.ticks=101
g.listeners.started[1](jumper,action(95,'TESTLEAP',-1))
jumper.m_curAction=action(95,'TESTLEAP',-1)
assert(claim(105)==true and ch:inspect().running==1)
jumper.m_pos={x=352,y=0};jumper.m_curAction={m_actionID=0}
assert(claim(110)==true)
c=last('choice')
assert(c.castKind=='weapon' and c.target==11 and c.walk==nil)
g.BGSE_Act(jumper)
assert(g.queued[#g.queued].text=='AttackOneRound(EEex_Target("BGSE"))')
assert(claim(145)==true and last('landed').off==0 and ch:inspect().counts.landed==1)
-- The enemy steps back out of reach, 428 away: within the gap the creature walks to it, after the
-- gap it jumps again.
foe.m_pos={x=780,y=0}
assert(claim(220)==true)
c=last('choice')
assert(c.castKind=='weapon' and c.target==11 and math.abs(c.walk-3.64)<1e-9)
assert(claim(400)==true)
c=last('choice')
assert(c.castKind=='teleport' and c.target==11 and c.point.x==732 and ch:inspect().counts.jumps==2)
end)()
groups=groups+1

-- 34. Debuffs (F2b). A mage whose only spell is Slow (a debuff: it halves what an enemy does in a
-- round) facing a fighter: the engine reads the enemy's effects, casts Slow at it with SpellRES at
-- EEex_Target and claims it in the group for that spell, so that a second mage with Slow, deciding
-- before the first one's cast is even queued, leaves it alone; the cast's start holds the claim.
-- Once the cast is over the Slow took when the enemy carries an effect of it (its state is left
-- alone here, so only its effects tell), and an enemy that carries it gets no second Slow; one
-- that carries none afterwards was missed.
;(function()
records.TESTSLOW=spl('TESTSLOW',3,{fx(40,{duration=60})})
local g=world()
local slower=g.add(sprite(1,0,0,255))
learn(slower,2,'TESTSLOW',2)
local other=g.add(sprite(2,0,40,255))
learn(other,2,'TESTSLOW')
local foe=g.add(sprite(11,100,0,2))
local dir=directors.new(g,{reader=reader})
local ch=choices.new(g,{reader=reader,director=dir,seed=43})
local rows={}
ch:setSink(function(row) rows[#rows+1]=row end)
local root=runtime.install(g,{director=dir,choice=ch,version='test'})
local function last(kind,member)
    for n=#rows,1,-1 do
        if rows[n].kind==kind and (member==nil or rows[n].member==member) then return rows[n] end
    end
end
local function claim(s,tick) g.ticks=tick;return g.BGSE_Claim(s,'mage','s1') end
local function curses() return root.inspect().director.areas.AR0001.curses end
assert(claim(slower,100)==true)
local c=last('choice',1)
assert(c.castKind=='debuff' and c.spell=='TESTSLOW' and c.mode=='creature' and c.target==11 and c.hits[1]==11)
local held=curses()
assert(#held==1 and held[1].target==11 and held[1].spell=='TESTSLOW' and held[1].owner==1 and held[1].claim==true)
assert(claim(other,102)==true and last('choice',2)==nil and last('wait',2).reason=='no-option')
g.BGSE_Act(slower)
assert(g.queued[#g.queued].text=='SpellRES("TESTSLOW",EEex_Target("BGSE"))' and slower.aux.EEex_Target.BGSE==11)
g.ticks=103
g.listeners.started[1](slower,action(31,'TESTSLOW',-1))
slower.m_curAction=action(31,'TESTSLOW',11)
held=curses()
assert(#held==1 and held[1].owner==1 and held[1].claim==nil)
assert(claim(slower,120)==true and ch:inspect().running==1)
-- The cast is over and the enemy carries its effect.
slower.m_curAction={m_actionID=0};slower.book[2][1].m_flags=0
foe.m_timedEffectList={{m_effectId=40,m_durationType=4096,m_duration=135+900,m_effectAmount=0,m_dWFlags=0,
    m_res=str(''),m_sourceRes=str('TESTSLOW'),m_school=0,m_secondaryType=0,m_spellLevel=3,m_casterLevel=10,
    m_flags=1,m_numDice=0,m_diceSize=0,m_special=0}}
assert(claim(slower,135)==true and ch:inspect().judging==1 and last('wait',1).reason=='no-option')
assert(claim(slower,170)==true)
local o=last('outcome')
assert(o.hit==true and o.spell=='TESTSLOW' and o.target==11 and ch:inspect().counts.hits==1)
-- The Slow wears off; the second one leaves the enemy without its effect.
foe.m_timedEffectList={}
assert(claim(slower,200)==true and last('choice',1).tick==200 and last('choice',1).castKind=='debuff')
g.BGSE_Act(slower)
g.ticks=201
g.listeners.started[1](slower,action(31,'TESTSLOW',-1))
slower.m_curAction=action(31,'TESTSLOW',11)
assert(claim(slower,220)==true)
slower.m_curAction={m_actionID=0};slower.book[2][2].m_flags=0
assert(claim(slower,240)==true and claim(slower,275)==true)
o=last('outcome')
assert(o.hit==false and o.misses==1 and ch:inspect().counts.misses==1)
assert(ch:inspect().counts.debuffs==2 and ch:inspect().counts.wardFailures==0)
end)()
groups=groups+1

-- The game's weapon tables (F2c, F2d) as EEex's 2DA functions give them: labels as strings, the
-- width counting the row labels too, a missing cell the table's default. One local for the whole
-- file (the main chunk is near Lua's limit of 200).
local tablesOf=(function()
    local function twoda(columns,list)
        local t={columns={},labels={},cells={}}
        for n,c in ipairs(columns) do t.columns[c]=n-1 end
        for n,r in ipairs(list) do
            t.labels[n-1]=r[1];t.cells[n-1]={}
            for k=2,#r do t.cells[n-1][k-2]=tostring(r[k]) end
        end
        t.width,t.height=#columns+1,#list
        return t
    end
    local function attacks(label,low,mid,high)
        local r={label}
        for level=1,12 do r[#r+1]=level<7 and low or level<13 and mid or high end
        return r
    end
    local LEVELS={'LEVEL1'}
    for level=2,12 do LEVELS[#LEVELS+1]=tostring(level) end
    local GAME2DA={
        WSPECIAL=twoda({'HIT','DAMAGE','SPEED'},{{'0',0,0,0},{'1',0,0,0},{'2',1,2,0},{'3',3,3,0},{'4',3,4,-1},{'5',3,5,-3}}),
        WSPATCK=twoda(LEVELS,{attacks('0',0,-1),attacks('1',0,-1),attacks('2',-1,1),attacks('3',-1,1),attacks('4',-1,1),
            attacks('5',-2,2)}),
        STRMOD=twoda({'TO_HIT','DAMAGE'},{{'16',0,1},{'17',1,1},{'18',1,2},{'22',2,5}}),
        STRMODEX=twoda({'TO_HIT','DAMAGE'},{{'0',0,0}}),
        DEXMOD=twoda({'REACTION','MISSILE','AC'},{{'16',1,1,-2}}),
        CLSWPBON=twoda({'GETS_PROF_APR','UNARMED_DIVISOR','ZERO_SKILL_THAC0'},{{'MAGE',0,0,5},{'FIGHTER',1,0,2}})}
    return function(g)
        g.EEex_Resource_Load2DA=function(name) return GAME2DA[name] or twoda({},{}) end
        g.EEex_Resource_Get2DADimensions=function(t) return t.width,t.height end
        g.EEex_Resource_Get2DARowLabel=function(t,n) return t.labels[n] or '' end
        g.EEex_Resource_Find2DARowLabel=function(t,label)
            for n=0,t.height-1 do if t.labels[n]==label:upper() then return n end end
            return -1
        end
        g.EEex_Resource_GetAt2DAPoint=function(t,x,y) return t.cells[y] and t.cells[y][x] or '*' end
        g.EEex_Resource_GetAt2DALabels=function(t,column,row)
            local x,y=t.columns[column],g.EEex_Resource_Find2DARowLabel(t,row)
            return x and y>=0 and t.cells[y][x] or '*'
        end
    end
end)()

-- 35. Weapon choice and kiting (F2c). The game's tables come through EEex's 2DA functions (labels
-- as strings, the width counting the row labels too, a missing cell the table's default). An archer
-- (a fighter's profile) at lab probe F's numbers: level 8, strength 18, dexterity 16, a longbow +1
-- in high mastery and arrows +1 in hand (the game's selected slot is the quiver's), a short sword +1
-- it is specialized in. An 'arms' row logs the bow: THAC0 7, 9.5 a hit, three shots, the tables'
-- parts of its bonuses beside the game's (6 and 4). Next to an enemy behind a Physical Mirror it
-- takes up the sword (SelectWeaponAbility at its slot before AttackOneRound; a 'swing' row names
-- the slot). Next to an ogre a second archer steps away instead: MoveToPoint to the spot 400
-- straight away, held while it walks, with a 'kite' and a 'kited' row; within 18 seconds it does not
-- step away again but shoots. Without the tables the engine logs that once and weighs the weapon in
-- hand alone.
;(function()
local profiles=require('combat-intent.mind')
ITEMS.TESTLBOW=weapon('TESTLBOW',{itemType=15,proficiency=104,equipping={fx(1,{p1=2,p2=1,target=1,timing=2})}},
    {attackType=4,dice=0,sides=0,thac0=1,damageBonus=1,range=100})
ITEMS.TESTARR1=weapon('TESTARR1',{flags=0,enchantment=1},{attackType=2,launcher=1,dice=1,sides=6,thac0=1,damageBonus=1,
    damageType=4,projectile=2})
ITEMS.TESTSSWD=weapon('TESTSSWD',{proficiency=89,enchantment=1},{dice=1,sides=6,thac0=1,damageBonus=1,flags=1})
ITEMS.TESTCLUB=weapon('TESTCLUB',{flags=0},{dice=4,sides=8,damageBonus=2,damageType=2})
local function bowman(id,x,y)
    local s=sprite(id,x,y,255)
    s.items[11]={cResRef=str('TESTARR1')};s.items[35]={cResRef=str('TESTSSWD')};s.items[36]={cResRef=str('TESTLBOW')}
    s.m_equipment.m_selectedWeapon=11
    for n,v in pairs({[7]=13,[8]=3,[84]=6,[86]=4,[36]=18,[40]=16,[34]=8,[89]=2,[104]=4}) do s.stats[n]=v end
    s.m_baseStats.m_numberOfAttacksBase=1
    return s
end
local g=world()
tablesOf(g)
local archer=g.add(bowman(1,1000,1000))
local mirrored=g.add(sprite(12,1050,1000,2))
mirrored.stats[7],mirrored.stats[122]=20,1
local dir=directors.new(g,{reader=reader9})
local ch=choices.new(g,{reader=reader9,director=dir,seed=47,
    mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
local rows={}
ch:setSink(function(row) rows[#rows+1]=row end)
runtime.install(g,{director=dir,choice=ch,version='test'})
local function last(kind,member)
    for n=#rows,1,-1 do
        if rows[n].kind==kind and (member==nil or rows[n].member==member) then return rows[n] end
    end
end
local function claim(s,tick) g.ticks=tick;return g.BGSE_Claim(s,'mage','s1') end
-- What the engine reads: the bow in hand at probe F's numbers, and the sword it could take up.
local own,others,missing=sense.arsenal(g,archer,reader9)
assert(missing==nil and own.item=='TESTLBOW' and own.ammo=='TESTARR1' and own.slot==36 and own.thac0==7 and
    own.damage==9.5 and own.apr==3 and own.model.hit==6 and own.model.damage==4)
assert(#others==1 and others[1].item=='TESTSSWD' and others[1].slot==35 and others[1].thac0==10 and
    others[1].damage==8.5 and others[1].apr==2)
-- The Physical Mirror keeps the arrows off: the archer takes up the sword.
assert(claim(archer,100)==true)
local a=last('arms',1)
assert(a.item=='TESTLBOW' and a.ammo=='TESTARR1' and a.thac0==7 and a.damage==9.5 and a.apr==3 and a.others==1)
assert(a.model.hit==6 and a.model.damage==4 and a.game.hit==6 and a.game.damage==4)
local c=last('choice',1)
assert(c.castKind=='weapon' and c.spell=='TESTSSWD' and c.target==12 and c.slot==35)
g.BGSE_Act(archer)
assert(g.queued[#g.queued].text=='SelectWeaponAbility(35,0)\nAttackOneRound(EEex_Target("BGSE"))')
assert(last('swing',1).slot==35 and ch:inspect().counts.switches==1 and archer.aux.EEex_Target.BGSE==12)
-- The weapon in hand is the same: no second 'arms' row.
local count=0
for _,r in ipairs(rows) do if r.kind=='arms' then count=count+1 end end
archer.m_curAction={m_actionID=0}
assert(claim(archer,300)==true)
for _,r in ipairs(rows) do if r.kind=='arms' then count=count-1 end end
assert(count==0)
-- A second archer next to an ogre (three swings of 20 that always land but one in twenty) steps away.
local kiter=g.add(bowman(2,5000,5000))
local ogre=g.add(armed(sprite(13,5050,5000,2),35,'TESTCLUB'))
ogre.stats[8],ogre.stats[7]=3,1
ogre.m_baseStats.m_hitPoints=80;ogre.stats[1]=80
assert(claim(kiter,400)==true)
c=last('choice',2)
assert(c.castKind=='kite' and c.spell=='KITE' and c.how=='kite' and c.point.x==4600 and c.point.y==5000)
g.BGSE_Act(kiter)
assert(g.queued[#g.queued].text=='MoveToPoint([4600.5000])')
local k=last('kite',2)
assert(k.from.x==5000 and k.to.x==4600 and k.to.y==5000 and ch:inspect().counts.kites==1)
-- Held while it walks; then the 'kited' row. The ogre followed: within 18 seconds of the step the
-- archer shoots it where it stands, after them it steps away again.
kiter.m_curAction={m_actionID=23}
local holds=ch:inspect().counts.holds
assert(claim(kiter,430)==true and ch:inspect().counts.holds==holds+1)
kiter.m_curAction={m_actionID=0};kiter.m_pos={x=4600,y=5000};ogre.m_pos={x=4650,y=5000}
assert(claim(kiter,470)==true)
local done=last('kited',2)
assert(done.at.x==4600 and done.near==50 and done.took==70 and ch:inspect().counts.kited==1)
c=last('choice',2)
assert(c.castKind=='weapon' and c.spell=='TESTLBOW' and c.target==13 and c.slot==nil)
g.BGSE_Act(kiter)
assert(g.queued[#g.queued].text=='AttackOneRound(EEex_Target("BGSE"))')
kiter.m_curAction={m_actionID=0}
assert(claim(kiter,670)==true and last('choice',2).castKind=='kite' and last('choice',2).point.x==4200)
-- Without the game's tables: one 'tables' error row, and the weapon in hand alone.
local g2=world()
local lone=g2.add(bowman(1,1000,1000))
local foe2=g2.add(sprite(12,1050,1000,2))
foe2.stats[7],foe2.stats[122]=20,1
own,others,missing=sense.arsenal(g2,lone,reader9)
assert(missing~=nil and #others==0 and own.item=='TESTLBOW' and own.model==nil)
local dir2=directors.new(g2,{reader=reader9})
local ch2=choices.new(g2,{reader=reader9,director=dir2,seed=53,
    mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
local rows2={}
ch2:setSink(function(row) rows2[#rows2+1]=row end)
runtime.install(g2,{director=dir2,choice=ch2,version='test'})
for _,tick in ipairs({100,300}) do
    g2.ticks=tick;lone.m_curAction={m_actionID=0}
    assert(g2.BGSE_Claim(lone,'mage','s1')==true)
end
local errors,swings=0,0
for _,r in ipairs(rows2) do
    if r.kind=='error' and r.where=='tables' then errors=errors+1 end
    if r.kind=='choice' and r.castKind=='weapon' then swings=swings+1 end
end
assert(errors==1 and swings==0 and type(ch2:inspect().tableError)=='string' and ch:inspect().tableError==false)
end)()
groups=groups+1

-- 36. Backstabs (F2d). A hidden thief (a fighter's profile, clever) with a short sword that can
-- backstab (its "unusable by thieves" bit clear) and a backstab multiplier of 3, west of an ogre
-- that faces it: the engine walks it behind the ogre (MoveToPoint to the spot 48 behind it, a
-- 'flank' row), holds it while it walks, logs where it ended ('flanked': behind the ogre, still
-- hidden, 48 away) and then attacks; choice, 'swing' and 'attack' rows carry the chance that the
-- first hit is a backstab. A sword with the bit set, or an ogre whose facing is unknown, gets no
-- walk behind it. A flank that takes up another weapon first starts with SelectWeaponAbility and is
-- held while the thief takes it up. A seen thief whose backstab multiplies by five drinks a potion of
-- invisibility first; its choice row carries what the backstab after it adds.
;(function()
local profiles=require('combat-intent.mind')
assert(choices.response({resref='FLANK',kind='flank',point={x=248,y=100}})=='MoveToPoint([248.100])')
assert(choices.response({resref='FLANK',kind='flank',point={x=248,y=100},slot=36,abilityNum=0})==
    'SelectWeaponAbility(36,0)\nMoveToPoint([248.100])')
assert(choices.response({resref='FLANK',kind='flank',point={x=248,y=100},slot=11,abilityNum=0})==nil)
assert(choices.response({resref='FLANK',kind='flank',point={x=248,y=100},slot=36})==nil)
ITEMS.TESTSTAB=weapon('TESTSTAB',{flags=0,usability=0x20000000},{dice=1,sides=8,damageBonus=0})
ITEMS.TESTNOST=weapon('TESTNOST',{flags=0,usability=0x00400000},{dice=1,sides=8,damageBonus=0})
ITEMS.TESTLONG=weapon('TESTLONG',{flags=0,usability=0x20000000},{dice=1,sides=14,damageBonus=0})
ITEMS.TESTINVP={kind='ITM',resref='TESTINVP',flags=0,abilities={{form=3,flags=0,location=3,target=5,range=1,speed=0,
    projectile=1,effects={fx(20,{p2=0,duration=120,target=1})}}}}
local function thief(id,x,y,resref,opts)
    opts=opts or {}
    local s=sprite(id,x,y,255,{state=opts.state or 0x10})
    s.items[35]={cResRef=str(resref)};s.m_equipment.m_selectedWeapon=35
    if opts.spare then s.items[36]={cResRef=str(opts.spare)} end
    if opts.potion then s.items[18]={cResRef=str(opts.potion),m_useCount1=1} end
    s.stats[8],s.stats[7],s.stats[56]=1,10,opts.multiplier or 3
    return s
end
local function ogre(id,x,y,facing)
    local s=sprite(id,x,y,2,{m_nDirection=facing})
    s.stats[2],s.stats[1]=5,60;s.m_baseStats.m_hitPoints=60
    return s
end
local function scene(resref,facing,opts)
    local g=world()
    local stabber=g.add(thief(1,100,100,resref,opts))
    local foe=g.add(ogre(11,200,100,facing))
    local dir=directors.new(g,{reader=reader})
    local ch=choices.new(g,{reader=reader,director=dir,seed=59,
        mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
    local rows={}
    ch:setSink(function(row) rows[#rows+1]=row end)
    runtime.install(g,{director=dir,choice=ch,version='test'})
    local function last(kind,member)
        for n=#rows,1,-1 do
            if rows[n].kind==kind and (member==nil or rows[n].member==member) then return rows[n] end
        end
    end
    local function claim(tick) g.ticks=tick;return g.BGSE_Claim(stabber,'mage','s1') end
    return g,stabber,foe,ch,last,claim
end
-- What the engine reads: the sword can backstab, the thief multiplies by 3, the ogre faces west.
local g,stabber,foe,ch,last,claim=scene('TESTSTAB',4)
local own=sense.arsenal(g,stabber,reader)
assert(own.item=='TESTSTAB' and own.backstab==true and own.thac0==10)
local seen=sense.actor(g,stabber)
assert(seen.backstab==3 and seen.state==0x10 and sense.actor(g,foe).facing==4)
assert(claim(100)==true)
local c=last('choice',1)
assert(c.castKind=='flank' and c.spell=='FLANK' and c.target==11 and c.point.x==248 and c.point.y==100)
assert(near(c.backstab,0.8) and near(c.walk,1.48) and c.slot==nil)
g.BGSE_Act(stabber)
assert(g.queued[#g.queued].text=='MoveToPoint([248.100])')
local f=last('flank',1)
assert(f.target==11 and f.to.x==248 and f.from.x==100 and near(f.backstab,0.8) and ch:inspect().counts.flanks==1)
-- Held while it walks; then the 'flanked' row and the swing with its backstab.
stabber.m_curAction={m_actionID=23}
local holds=ch:inspect().counts.holds
assert(claim(120)==true and ch:inspect().counts.holds==holds+1)
stabber.m_curAction={m_actionID=0};stabber.m_pos={x=248,y=100}
assert(claim(130)==true)
local done=last('flanked',1)
assert(done.target==11 and done.behind==true and done.hidden==true and done.near==48 and done.took==30)
assert(ch:inspect().counts.flanked==1)
c=last('choice',1)
assert(c.castKind=='weapon' and c.spell=='TESTSTAB' and c.target==11 and near(c.backstab,0.8))
g.BGSE_Act(stabber)
assert(g.queued[#g.queued].text=='AttackOneRound(EEex_Target("BGSE"))' and stabber.aux.EEex_Target.BGSE==11)
assert(near(last('swing',1).backstab,0.8))
-- The stab lands for 13 (three times a hit); the attack is over a round later.
stabber.m_curAction={m_actionID=105};foe.m_baseStats.m_hitPoints=47
assert(claim(150)==true)
stabber.m_curAction={m_actionID=0}
assert(claim(225)==true)
local a=last('attack',1)
assert(a.hit==true and a.lost==13 and near(a.backstab,0.8))
-- A sword with the thieves' bit set cannot backstab: the thief attacks from the front.
g,stabber,foe,ch,last,claim=scene('TESTNOST',4)
assert(sense.arsenal(g,stabber,reader).backstab==nil)
assert(claim(100)==true)
c=last('choice',1)
assert(c.castKind=='weapon' and c.backstab==nil and ch:inspect().counts.flanks==0)
-- An ogre whose facing the engine cannot read: no walk behind it; the swing counts the chance of
-- happening to stand behind it (5 of 16 directions).
g,stabber,foe,ch,last,claim=scene('TESTSTAB',16)
assert(sense.actor(g,foe).facing==nil)
assert(claim(100)==true)
c=last('choice',1)
assert(c.castKind=='weapon' and near(c.backstab,0.8*5/16) and ch:inspect().counts.flanks==0)
-- The sword in hand cannot backstab, the spare one in slot 36 can: the walk behind the ogre takes it
-- up first and is held while the thief does (SelectWeaponAbility, action 92), then while it walks.
g,stabber,foe,ch,last,claim=scene('TESTNOST',4,{spare='TESTSTAB'})
tablesOf(g)
assert(claim(100)==true)
c=last('choice',1)
assert(c.castKind=='flank' and c.slot==36 and near(c.backstab,0.8))
g.BGSE_Act(stabber)
assert(g.queued[#g.queued].text=='SelectWeaponAbility(36,0)\nMoveToPoint([248.100])')
f=last('flank',1)
assert(f.slot==36 and ch:inspect().counts.flanks==1 and ch:inspect().counts.switches==1)
stabber.m_curAction={m_actionID=92}
holds=ch:inspect().counts.holds
assert(claim(120)==true and ch:inspect().counts.holds==holds+1)
stabber.m_curAction={m_actionID=23}
assert(claim(130)==true and ch:inspect().counts.holds==holds+2)
-- Seen, with a long sword (7.5 a hit) and a backstab of five against an ogre that faces away: the
-- potion first, for two thirds of the ogre's hit points as likely as the stab lands (with the bonus
-- for the group's focus, the ogre), less the walk.
g,stabber,foe,ch,last,claim=scene('TESTLONG',12,{state=0,multiplier=5,potion='TESTINVP'})
assert(claim(100)==true)
c=last('choice',1)
local fighter=profiles.forFamily(profiles.new(),'fighter')
local focus=1+fighter.focusBonus*fighter.coordination
assert(c.castKind=='defence' and c.spell=='TESTINVP' and c.use==true and near(c.opening,0.8*30/60*focus*6/(6+0.36)))
g.BGSE_Act(stabber)
assert(g.queued[#g.queued].text:find('UseItem%("TESTINVP",Myself%)')~=nil)
end)()
groups=groups+1

-- 37. Critical hit effects (F2e). A brawler (a fighter's profile) whose kit casts fire at each
-- creature its fists hit critically (opcode 341 from an EFF file: melee, weapon category 28) stands
-- next to an ogre. The engine reads the effect from the brawler's own effects, the spell at the
-- brawler's level (40 fire from level 9 on, 10 below) and the category of the fists in its hand: the
-- swing is worth more for it, four times as much more at level 9 as at level 1. With a club in hand
-- the effect brings nothing.
;(function()
local profiles=require('combat-intent.mind')
local function tier(minLevel,fire)
    return {form=1,flags=0,location=2,target=1,targetCount=0,range=1,minLevel=minLevel,speed=0,projectile=1,
        effects={fx(12,{p1=fire,p2=8*65536,timing=1})}}
end
records.TESTCRFX={kind='SPL',resref='TESTCRFX',name=0,flags=0,spellType=4,exclusion=0,school=0,secondary=0,level=1,
    casting={},abilities={tier(1,10),tier(9,40)}}
ITEMS.TESTFST2=weapon('TESTFST2',{flags=0,itemType=28},{dice=1,sides=4,damageType=2})
ITEMS.TESTCLB2=weapon('TESTCLB2',{flags=0,itemType=17},{dice=1,sides=4,damageType=2})
local function swing(level,carried,slot,resref)
    local g=world()
    local brawler=sprite(1,100,100,255)
    brawler.items[slot]={cResRef=str(resref)};brawler.m_equipment.m_selectedWeapon=slot
    brawler.stats[8],brawler.stats[7],brawler.stats[34]=1,10,level
    if carried then
        brawler.m_timedEffectList={{m_effectId=341,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=0,
            m_effectAmount2=28,m_effectAmount3=0,m_numDice=0,m_diceSize=0,m_special=1,m_spellLevel=0,
            m_res=str('TESTCRFX'),m_sourceRes=str('TESTBRWL')}}
    end
    g.add(brawler)
    local ogre=g.add(sprite(11,150,100,2))
    ogre.stats[2],ogre.stats[1]=5,60;ogre.m_baseStats.m_hitPoints=60
    local dir=directors.new(g,{reader=reader})
    local ch=choices.new(g,{reader=reader,director=dir,seed=61,
        mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
    local rows={}
    ch:setSink(function(row) rows[#rows+1]=row end)
    runtime.install(g,{director=dir,choice=ch,version='test'})
    g.ticks=100
    assert(g.BGSE_Claim(brawler,'mage','s1')==true)
    for n=#rows,1,-1 do if rows[n].kind=='choice' then return rows[n] end end
end
local plain,low,high=swing(9,false,10,'TESTFST2'),swing(1,true,10,'TESTFST2'),swing(9,true,10,'TESTFST2')
assert(plain.castKind=='weapon' and plain.spell=='TESTFST2' and high.castKind=='weapon' and high.target==11)
assert(low.worth>plain.worth and high.worth>low.worth and near(high.worth-plain.worth,4*(low.worth-plain.worth)))
local club=swing(9,true,35,'TESTCLB2')
assert(club.spell=='TESTCLB2' and near(club.worth,swing(9,false,35,'TESTCLB2').worth))
end)()
groups=groups+1

-- 38. Hiding (F2f, combat-intent/stealth.lua, adapters/eeex/stealth.lua). A thief (CLASS.IDS 4, Hide
-- in Shadows 60) that sees no enemy hides in shadows: the game's Hide(), with a 'hide' row, held
-- while it tries; once the game makes it invisible, a 'hidden' row says so, and with nothing to
-- search its own life goes on. A try that comes to nothing waits a round before the next; one in
-- the game's stealth mode is held until it ends or hideTicks pass. A dull thief never thinks of
-- hiding, unless its orders say so. BGSE_Hide is true for a thief the engine drives that can hide
-- by its skill, for SCS's plain free invisibility only. A hiding rogue keeps its hide: no Find Traps
-- for its Detect Illusion.
;(function()
local function setup(seed,orders)
    local w=world()
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,orders=orders})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    local function count(kind) local n=0;for _,row in ipairs(list) do if row.kind==kind then n=n+1 end end;return n end
    local function claimAt(s,tick) w.ticks=tick;return w.BGSE_Claim(s,'mage','s1') end
    return w,c,r,lastOf,count,claimAt
end
local function thief(fields)
    local s=sprite(1,0,0,255,fields)
    s.m_typeAI.m_Class=4;s.stats[135]=60;s.m_nModalState=0
    return s
end
local g,ch,root,last,count,claim=setup(71)
local t=g.add(thief())
assert(claim(t,100)==true)
g.BGSE_Act(t)
assert(g.queued[#g.queued].text=='Hide()')
local h=last('hide')
assert(h.member==1 and h.skill==60 and h.wit=='clever' and h.tactical==true and h.ordered==nil)
local seen=ch:inspect().stealth
assert(seen.counts.hides==1 and seen.counts.draws==1 and seen.trying==1)
-- Held while it runs Hide() (a plain hold); invisible ten ticks after the try, the 'hidden' row;
-- nothing to search.
t.m_curAction={m_actionID=18}
local holds=ch:inspect().counts.holds
assert(claim(t,105)==true and ch:inspect().counts.holds==holds+1)
local trail=root.inspect().trace
assert(trail[#trail].kind=='claim' and trail[#trail].reason=='hold')
t.state=0x10;t.m_nModalState=3;t.m_curAction={m_actionID=0}
assert(claim(t,110)==false and ch:inspect().reasons['no-enemy']==1)
local done=last('hidden')
assert(done.hidden==true and done.why=='hidden' and done.took==10 and done.modal==3)
seen=ch:inspect().stealth
assert(seen.counts.hidden==1 and seen.counts.unhidden==0 and seen.trying==0 and count('hide')==1)
-- Seen by nobody it stays hidden: no second try.
assert(claim(t,300)==false and count('hide')==1)
-- An enemy shows: the stretch out of sight is over; once it is gone again the thief, its hide lost
-- meanwhile, draws afresh and hides again.
t.state=0;t.m_nModalState=0
local e=g.add(sprite(11,200,0,2))
assert(claim(t,320)==true)
e.m_pos={x=5000,y=0}
assert(claim(t,400)==true and ch:inspect().stealth.counts.draws==2)
g.BGSE_Act(t)
assert(g.queued[#g.queued].text=='Hide()' and count('hide')==2)
-- This try comes to nothing: the action ends after the grace without the stealth mode; the next
-- waits for the round (90 ticks after the try), meanwhile the engine's search goes on.
t.m_curAction={m_actionID=0}
assert(claim(t,410)==true)
done=last('hidden')
assert(done.hidden==false and done.why=='ended' and done.took==10 and ch:inspect().stealth.counts.unhidden==1)
assert(last('hide').tick==400 and count('hide')==2)
g.BGSE_Act(t)
assert(g.queued[#g.queued].text:find('MoveToPoint')~=nil)
t.m_curAction={m_actionID=0};t.m_pos={x=200,y=0}
assert(claim(t,490)==true)
g.BGSE_Act(t)
assert(g.queued[#g.queued].text=='Hide()' and count('hide')==3)
-- A try in the game's stealth mode is held until hideTicks (45) pass, then judged. With Hide() over
-- and only the stealth mode running, the thief stands still in it: an idle hold, whose response
-- cuts nothing.
t.m_nModalState=3
assert(claim(t,520)==true and count('hidden')==2)
trail=root.inspect().trace
assert(trail[#trail].kind=='claim' and trail[#trail].reason=='idle')
local queued=#g.queued
g.BGSE_Act(t)
assert(#g.queued==queued and ch:inspect().counts.cut==0 and ch:inspect().stealth.trying==1)
claim(t,535)
assert(last('hidden').why=='limit' and last('hidden').took==45 and last('hidden').hidden==false)
-- Hurt during a try: it is over at once.
local g2,ch2,_,last2,_,claim2=setup(72)
local t2=g2.add(thief())
assert(claim2(t2,100)==true)
g2.BGSE_Act(t2)
t2.m_curAction={m_actionID=18};t2.m_baseStats.m_hitPoints=30
claim2(t2,104)
assert(last2('hidden').why=='hurt' and last2('hidden').hidden==false and ch2:inspect().stealth.trying==0)

-- A dull thief (INT 4, WIS 8) never thinks of hiding; with orders to hide, it does.
local g3,ch3,_,last3,_,claim3=setup(73)
local t3=g3.add(thief({stats={[1]=40,[38]=4,[39]=8}}))
t3.stats[135]=60
assert(claim3(t3,100)==false and last3('hide')==nil and ch3:inspect().stealth.counts.draws==1)
local g4,_,_,last4,_,claim4=setup(74,{TEST1={hide=true}})
local t4=g4.add(thief({stats={[1]=40,[38]=4,[39]=8}}))
t4.stats[135]=60
assert(claim4(t4,100)==true)
g4.BGSE_Act(t4)
assert(g4.queued[#g4.queued].text=='Hide()' and last4('hide').ordered==true and last4('hide').wit=='dull')
-- Orders never to hide: a clever thief searches instead.
local g5,_,_,last5,_,claim5=setup(75,{TEST1={hide=false}})
local t5=g5.add(thief())
assert(claim5(t5,100)==false and last5('hide')==nil)

-- BGSE_Hide: true for the thief the engine drives, for SCS's plain free invisibility only; false for
-- one without the skill, a fighter, one off the engine's side and with the choice off.
assert(g.BGSE_Hide(t,'mage','s1','plain')==true and g.BGSE_Hide(t,'mage','s1','improved')==false)
assert(g.BGSE_Hide(t,'fighter','s3','plain')==false)
t.stats[135]=0
assert(g.BGSE_Hide(t,'mage','s1','plain')==false)
t.stats[135]=60;t.m_typeAI.m_Class=2
assert(g.BGSE_Hide(t,'mage','s1','plain')==false)
t.m_typeAI.m_Class=9
assert(g.BGSE_Hide(t,'mage','s1','plain')==true)
t.m_typeAI.m_EnemyAlly=128
assert(g.BGSE_Hide(t,'mage','s1','plain')==false)
t.m_typeAI.m_EnemyAlly=255
root.setChoice(false)
assert(g.BGSE_Hide(t,'mage','s1','plain')==false)
root.setChoice(true)
assert(g.BGSE_Hide(t,'mage','s1','plain')==true and ch:inspect().counts.errors==0)

-- A rogue with Detect Illusion 80 whose enemy turned invisible on a spot it sees uses its Find
-- Traps mode for it; hiding in shadows (the stealth mode) it keeps its hide and searches on foot.
local function rogue(seed,mode)
    local w,c,_,lastOf,_,claimAt=setup(seed)
    local s=w.add(thief())
    s.stats[136]=80;s.state=0x10;s.m_nModalState=mode
    local foe=w.add(sprite(11,150,0,2))
    assert(claimAt(s,100)==true)
    foe.state=0x10
    assert(claimAt(s,116)==true)
    return w,lastOf
end
local g6,last6=rogue(76,0)
assert(last6('detect') and last6('detect').modal==true)
g6.BGSE_Act(g6.objects[1])
assert(g6.queued[#g6.queued].text=='FindTraps()')
local g7,last7=rogue(77,3)
assert(last7('detect')==nil)
g7.BGSE_Act(g7.objects[1])
local q7=g7.queued[#g7.queued]
assert(q7==nil or (q7.text~='FindTraps()' and q7.text~='Hide()'))
end)()
groups=groups+1

-- 39. A monster's veil (F2f-5, combat-intent/stealth.lua, adapters/eeex/stealth.lua). A fiend (no
-- thief) with the installer's innate Invisibility that comes back after a round (172 and a delayed
-- 171 of itself) sees no enemy: it casts it at itself like the engine's other casts, with a 'veil'
-- row, held while it runs; once it is over and the fiend is invisible, a 'veiled' row says so, and
-- it stays invisible without a second cast. Its Improved Invisibility that comes back after 1000
-- seconds stays for the fight; one back after a round veils. A thief with an innate invisibility
-- hides instead; a dull fiend does not think of it unless its orders say so; one that turned
-- invisible before its cast is queued needs none. BGSE_Hide: plain for one that may veil itself,
-- improved for one with an improved innate invisibility, also while the one it used comes back
-- (its delayed 171 waits in its timed effects); never for a creature without one.
;(function()
local function innate(resref,improved,recharge)
    local effects={fx(20,{target=1,timing=1,p2=improved and 1 or 0}),fx(172,{target=1,timing=1,res=resref})}
    if recharge then effects[#effects+1]=fx(171,{target=1,timing=4,duration=recharge,res=resref}) end
    local r=spl(resref,1,effects,5,1)
    r.spellType,r.flags,r.abilities[1].speed,r.abilities[1].range=4,0,2,0
    records[resref]=r
end
innate('BGW20606',false,6);innate('BGW405RS',true,1000);innate('BGW40506',true,6)
local function setup(seed,orders)
    local w=world()
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,orders=orders})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    local function count(kind) local n=0;for _,row in ipairs(list) do if row.kind==kind then n=n+1 end end;return n end
    local function claimAt(s,tick) w.ticks=tick;return w.BGSE_Claim(s,'mage','s1') end
    return w,c,r,lastOf,count,claimAt
end
local g,ch,root,last,count,claim=setup(81)
local f=g.add(sprite(1,0,0,255))
gift(f,'BGW20606')
assert(claim(f,100)==true)
g.BGSE_Act(f)
assert(g.queued[#g.queued].text=='SpellRES("BGW20606",Myself)')
local v=last('veil')
assert(v.member==1 and v.spell=='BGW20606' and v.recharge==6 and v.improved==nil and v.wit=='clever' and v.tactical==true)
local seen=ch:inspect()
assert(seen.stealth.counts.veils==1 and seen.stealth.counts.draws==1 and seen.pending==1 and last('hide')==nil)
-- The cast starts and runs: held. It ends with the fiend invisible, the spell gone until its 171
-- gives it back; judged outcomeTicks later.
g.ticks=101
g.listeners.started[1](f,action(31,'BGW20606',-1))
f.m_curAction=action(31,'BGW20606',-1)
assert(claim(f,110)==true and ch:inspect().running==1)
f.m_curAction={m_actionID=0};f.state=0x10
f.innate[0]={};f.innateButtons={}
f.m_timedEffectList={{m_effectId=171,m_durationType=7,m_duration=215,m_res=str('BGW20606')}}
assert(claim(f,125)==false and ch:inspect().reasons['no-enemy']==1)
assert(claim(f,160)==false)
local done=last('veiled')
assert(done.member==1 and done.spell=='BGW20606' and done.hidden==true and done.tick==125)
seen=ch:inspect().stealth
assert(seen.counts.veiled==1 and seen.counts.unveiled==0 and count('veil')==1)
-- Coming back, the Invisibility still counts for BGSE_Hide: SCS's free one stands aside meanwhile.
assert(g.BGSE_Hide(f,'mage','s1','plain')==true and g.BGSE_Hide(f,'mage','s1','improved')==false)
-- Back again and seen by nobody, invisible: no second cast.
gift(f,'BGW20606');f.m_timedEffectList={}
assert(claim(f,300)==false and count('veil')==1)
-- Seen, its invisibility lost, the enemy gone again: it veils itself again.
f.state=0
local e=g.add(sprite(11,200,0,2))
assert(claim(f,320)==true)
e.m_pos={x=5000,y=0}
assert(claim(f,400)==true)
g.BGSE_Act(f)
assert(g.queued[#g.queued].text=='SpellRES("BGW20606",Myself)' and count('veil')==2)

-- Improved Invisibility back after 1000 seconds stays for the fight: no veil, and BGSE_Hide is true for
-- SCS's improved invisibility only. Back after a round, it veils, and counts for both.
local g2,_,_,last2,_,claim2=setup(82)
local m=g2.add(sprite(1,0,0,255))
gift(m,'BGW405RS')
assert(claim2(m,100)==false and last2('veil')==nil)
assert(g2.BGSE_Hide(m,'mage','s1','improved')==true and g2.BGSE_Hide(m,'mage','s1','plain')==false)
m.innate[0]={};m.innateButtons={}
m.m_timedEffectList={{m_effectId=171,m_durationType=7,m_duration=15100,m_res=str('BGW405RS')}}
g2.ticks=101
assert(g2.BGSE_Hide(m,'mage','s1','improved')==true)
-- Asked once a tick: within the tick the answer stands. A 171 that already fired (permanent now)
-- gives nothing back: the creature has none.
m.m_timedEffectList={{m_effectId=171,m_durationType=1,m_duration=15100,m_res=str('BGW405RS')}}
assert(g2.BGSE_Hide(m,'mage','s1','improved')==true)
g2.ticks=102
assert(g2.BGSE_Hide(m,'mage','s1','improved')==false)
local g3,ch3,_,last3,count3,claim3=setup(83)
local illithid=g3.add(sprite(1,0,0,255))
gift(illithid,'BGW40506')
assert(claim3(illithid,100)==true)
g3.BGSE_Act(illithid)
assert(g3.queued[#g3.queued].text=='SpellRES("BGW40506",Myself)' and last3('veil').improved==true)
assert(g3.BGSE_Hide(illithid,'mage','s1','plain')==true and g3.BGSE_Hide(illithid,'mage','s1','improved')==true)
-- Its cast never starts: held, then given up; the next veil waits for the round (90 ticks after the
-- last), meanwhile the engine's search goes on.
assert(claim3(illithid,140)==true and ch3:inspect().pending==1)
assert(claim3(illithid,150)==false and ch3:inspect().counts.lost==1 and count3('veil')==1)
assert(claim3(illithid,190)==true)
g3.BGSE_Act(illithid)
assert(g3.queued[#g3.queued].text=='SpellRES("BGW40506",Myself)' and count3('veil')==2)

-- A thief with an innate invisibility hides by its skill.
local g4,_,_,last4,_,claim4=setup(84)
local t=g4.add(sprite(1,0,0,255))
t.m_typeAI.m_Class=4;t.stats[135]=60;t.m_nModalState=0
gift(t,'BGW20606')
assert(claim4(t,100)==true)
g4.BGSE_Act(t)
assert(g4.queued[#g4.queued].text=='Hide()' and last4('veil')==nil)
-- A dull fiend (INT 4, WIS 8) does not think of it; with orders to hide it veils.
local g5,ch5,_,last5,_,claim5=setup(85)
local dull=g5.add(sprite(1,0,0,255,{stats={[1]=40,[38]=4,[39]=8}}))
gift(dull,'BGW20606')
assert(claim5(dull,100)==false and last5('veil')==nil and ch5:inspect().stealth.counts.draws==1)
local g6,_,_,last6,_,claim6=setup(86,{TEST1={hide=true}})
local ordered=g6.add(sprite(1,0,0,255,{stats={[1]=40,[38]=4,[39]=8}}))
gift(ordered,'BGW20606')
assert(claim6(ordered,100)==true)
g6.BGSE_Act(ordered)
assert(g6.queued[#g6.queued].text=='SpellRES("BGW20606",Myself)' and last6('veil').ordered==true)
-- Invisible before its cast is queued (a friend's spell): skipped, no 'veil' row.
local g7,ch7,_,last7,_,claim7=setup(87)
local quick=g7.add(sprite(1,0,0,255))
gift(quick,'BGW20606')
assert(claim7(quick,100)==true)
quick.state=0x10
g7.BGSE_Act(quick)
assert(#g7.queued==0 and last7('veil')==nil and ch7:inspect().counts.skipped==1)

-- BGSE_Hide is false for a creature without an innate invisibility (no thief), one off the engine's
-- side and with the choice off.
local g8=setup(88)
local plain=g8.add(sprite(1,0,0,255))
assert(g8.BGSE_Hide(plain,'mage','s1','plain')==false and g8.BGSE_Hide(plain,'mage','s1','improved')==false)
gift(plain,'BGW20606');g8.ticks=101
assert(g8.BGSE_Hide(plain,'mage','s1','plain')==true and g8.BGSE_Hide(plain,'mage','s1','other')==false)
plain.m_typeAI.m_EnemyAlly=128
assert(g8.BGSE_Hide(plain,'mage','s1','plain')==false)
plain.m_typeAI.m_EnemyAlly=255
root.setChoice(false)
assert(g.BGSE_Hide(f,'mage','s1','plain')==false)
root.setChoice(true)
assert(g.BGSE_Hide(f,'mage','s1','plain')==true and ch:inspect().counts.errors==0)
end)()
groups=groups+1

-- 40. Positioning in the casting pause (combat-intent/choice.lua, M.position). The mage of group 30
-- with its short bolt (range 160) and its enemy 410 away, four seconds of casting aura left: it
-- walks the bolt's 2.5 seconds of walk meanwhile (MoveToPoint to 250, 160 short of the enemy), with
-- a choice row for the walk and a 'position' row naming the cast it walks for. Held while it walks
-- until the aura is about to free (auraLead); then a 'positioned' row says where it ended and how
-- near the enemy stands, and the bolt is cast from there. A walk over before the aura frees ends
-- the hold too: in range, the mage waits for the aura. A dull mage never walks for its cast: its
-- wait row says why.
;(function()
local nearRec=spl('TESTNEAR',3,{fx(12,{p2=8*65536,dice=6,sides=6})})
nearRec.abilities[1].range=10
records.TESTNEAR=nearRec
local function setup(seed,stats)
    local w=world()
    local m=w.add(sprite(1,0,0,255,stats and {stats=stats} or nil))
    learn(m,2,'TESTNEAR',3)
    w.add(sprite(11,410,0,2))
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    runtime.install(w,{director=d,choice=c,version='test'})
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    local function claimAt(tick) w.ticks=tick;return w.BGSE_Claim(m,'mage','s1') end
    return w,m,c,lastOf,claimAt
end
local g,m,ch,last,claim=setup(40)
m.castTimer=40
assert(claim(100)==true)
local c=last('choice')
assert(c.castKind=='position' and c.spell=='POSITION' and c.how=='position' and c.cast=='TESTNEAR' and c.toward==11)
assert(c.point.x==250 and c.point.y==0 and math.abs(c.walk-2.5)<1e-9 and math.abs(c.aura-4)<1e-9)
g.BGSE_Act(m)
assert(g.queued[#g.queued].text=='MoveToPoint([250.0])')
local p=last('position')
assert(p.from.x==0 and p.to.x==250 and p.to.y==0 and p.cast=='TESTNEAR' and p.toward==11 and ch:inspect().counts.positions==1)
-- Held while it walks and the aura runs.
m.m_curAction={m_actionID=23};m.castTimer=50
local holds=ch:inspect().counts.holds
assert(claim(110)==true and ch:inspect().counts.holds==holds+1 and last('positioned')==nil)
-- A third of a second of aura left: the walk is judged, and the bolt is cast from where it ended.
m.m_pos={x=250,y=0};m.castTimer=95
assert(claim(140)==true)
local done=last('positioned')
assert(done.at.x==250 and done.to.x==250 and done.near==160 and done.took==40 and done.cast=='TESTNEAR')
assert(ch:inspect().counts.positioned==1)
c=last('choice')
assert(c.spell=='TESTNEAR' and c.target==11 and c.castKind~='position')
g.BGSE_Act(m)
assert(g.queued[#g.queued].text=='SpellRES("TESTNEAR",EEex_Target("BGSE"))')
-- The walk over with three seconds of aura left: judged, and the mage, in range now, waits.
g,m,ch,last,claim=setup(41)
m.castTimer=40
assert(claim(100)==true and last('choice').castKind=='position')
g.BGSE_Act(m)
m.m_curAction={m_actionID=0};m.m_pos={x=250,y=0};m.castTimer=55
assert(claim(110)==true)
done=last('positioned')
assert(done.at.x==250 and done.took==10 and ch:inspect().counts.positioned==1)
local w=last('wait')
assert(w.reason=='aura' and w.tick==110 and w.positioning==nil)
-- A dull mage (INT 4, WIS 8) waits for the aura without the walk, and its wait row says why.
g,m,ch,last,claim=setup(42,{[1]=40,[38]=4,[39]=8})
m.castTimer=40
assert(claim(100)==true)
w=last('wait')
assert(w.reason=='aura' and w.wit=='dull' and w.positioning.unnoticed==1 and last('position')==nil)
assert(ch:inspect().counts.positions==0 and ch:inspect().counts.errors==0)
end)()
groups=groups+1

-- 41. SCS's preparation (combat-intent/prep.lua). BGSE_Prep holds back SCS's first-round casts of a
-- creature the engine drives, with one 'prep' row (held=true) for each creature, kind and spell, and
-- lets its prebuffs, contingencies and chains run unless its orders hold them back. BGSE_Prepped logs a
-- 'prep' row of what ran. Neither for a creature off the engine's side, a script it does not carry or
-- with the choice off. A load forgets the held rows.
;(function()
local function setup(seed,orders)
    local w=world()
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,orders=orders})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function rows() local out={};for _,row in ipairs(list) do if row.kind=='prep' then out[#out+1]=row end end;return out end
    return w,c,r,rows
end
local g,ch,root,rows=setup(81)
local m=g.add(sprite(1,0,0,255))
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==true)
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==true and #rows()==1)
local r=rows()[1]
assert(r.member==1 and r.resref=='TEST1' and r.family=='mage' and r.prep=='opener' and r.cast=='WIZARD_MIRROR_IMAGE')
assert(r.spent=='' and r.held==true)
assert(g.BGSE_Prep(m,'mage','s1','prebuff','dwsw408','WIZARD_STONE_SKIN')==false)
assert(g.BGSE_Prep(m,'mage','s1','contingency','WIZARD_IMPROVED_INVISIBILITY','')==false)
assert(g.BGSE_Prep(m,'mage','s1','chain','dw#cc12','')==false and #rows()==1)
g.BGSE_Prepped(m,'mage','s1','prebuff','dwsw408','WIZARD_STONE_SKIN')
r=rows()[2]
assert(r.member==1 and r.prep=='prebuff' and r.cast=='dwsw408' and r.spent=='WIZARD_STONE_SKIN' and r.held==false)
assert(ch:inspect().counts.preps==1 and ch:inspect().counts.prepHolds==1)
assert(g.BGSE_Prep(m,'fighter','s3','opener','WIZARD_MIRROR_IMAGE','')==false)
m.m_typeAI.m_EnemyAlly=128
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==false)
g.BGSE_Prepped(m,'mage','s1','prebuff','dwsw408','')
assert(#rows()==2 and ch:inspect().counts.preps==1)
m.m_typeAI.m_EnemyAlly=255
root.setChoice(false)
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==false)
root.setChoice(true)
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==true and #rows()==2)
ch:invalidate()
assert(g.BGSE_Prep(m,'mage','s1','opener','WIZARD_MIRROR_IMAGE','')==true and #rows()==3)
assert(ch:inspect().counts.errors==0)
-- Orders: prepSkip holds back what it names (a spell spent, a kind), prep=false all of it.
local g2,ch2,_,rows2=setup(82,{TEST1={prepSkip={'WIZARD_STONE_SKIN','chain'}}})
local m2=g2.add(sprite(1,0,0,255))
assert(g2.BGSE_Prep(m2,'mage','s1','prebuff','dwsw408','WIZARD_STONE_SKIN')==true)
assert(g2.BGSE_Prep(m2,'mage','s1','prebuff','dwsw212','WIZARD_MIRROR_IMAGE')==false)
assert(g2.BGSE_Prep(m2,'mage','s1','chain','dw#cc12','')==true and g2.BGSE_Prep(m2,'mage','s1','chain','dw#cc12','')==true)
assert(#rows2()==2 and rows2()[1].spent=='WIZARD_STONE_SKIN' and rows2()[2].prep=='chain' and ch2:inspect().counts.prepHolds==2)
local g3,_,_,rows3=setup(83,{TEST1={prep=false}})
local m3=g3.add(sprite(1,0,0,255))
assert(g3.BGSE_Prep(m3,'mage','s1','contingency','WIZARD_IMPROVED_INVISIBILITY','')==true and #rows3()==1)
end)()
groups=groups+1

-- 42. A hold's response runs only once the action it held is gone (lab batch J): a block of SCS's
-- above the hook cut the engine's attack short (a call for help, with Continue()), or the attack
-- ended early. The engine then ends its record of the attack, with a 'cut' row, and decides again
-- at once; the gate queues that decision in the same response ('renewed'). A queued cast cut before
-- it started is lost and cast again. A wait's response (an idle hold) cuts nothing.
;(function()
local function setup(seed)
    local w=world()
    local d=directors.new(w,{reader=reader9})
    local c=choices.new(w,{reader=reader9,director=d,seed=seed})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function last(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    return w,c,r,last
end
local w,c,r,last=setup(91)
local f=w.add(armed(sprite(1,0,0,255),35,'TESTSWRD'))
w.add(sprite(11,60,0,2)).stats[2]=5
w.ticks=100
assert(w.BGSE_Claim(f,'mage','s1')==true and last('choice').castKind=='weapon')
w.BGSE_Act(f)
assert(#w.queued==1 and w.queued[1].text=='AttackOneRound(EEex_Target("BGSE"))')
-- It attacks: held; the game runs no response of the hook block meanwhile.
f.m_curAction=action(105,'',11)
w.ticks=116
assert(w.BGSE_Claim(f,'mage','s1')==true and #w.queued==1 and c:inspect().counts.holds==1)
-- A block of SCS's above the hook fires: the claim still sees the attack and holds, then the game
-- runs the response (its EEex_LuaAction the creature's action). The attack is over (an 'attack'
-- row, a 'cut' row) and the engine attacks again in that response.
w.ticks=132
assert(w.BGSE_Claim(f,'mage','s1')==true and c:inspect().counts.holds==2)
f.m_curAction=action(472,'',-1)
w.BGSE_Act(f)
assert(#w.queued==2 and w.queued[2].text=='AttackOneRound(EEex_Target("BGSE"))')
local cut=last('cut')
assert(cut.tick==132 and cut.member==1 and #cut.ended==1 and cut.ended[1]=='attack')
assert(last('attack').started==100 and last('attack').tick==132 and last('swing').tick==132)
local s=r.inspect()
assert(s.counts.held==1 and s.counts.renewed==1 and s.counts.acted==2 and s.choice.counts.cut==1)
assert(s.trace[#s.trace].reason=='renewed')
-- The new attack ends early, within its round: the next pass still holds (a round from the attack)
-- and the game runs the response at once, the creature having nothing left to do. Again the engine
-- attacks at once.
f.m_curAction={m_actionID=0}
w.ticks=148
assert(w.BGSE_Claim(f,'mage','s1')==true)
w.BGSE_Act(f)
assert(#w.queued==3 and last('cut').tick==148 and r.inspect().counts.renewed==2 and c:inspect().counts.cut==2)
assert(c:inspect().counts.errors==0 and r.inspect().counts.heldErrors==0)
-- A mage's bolt, queued and cut before it started: lost (cut=true), then cast again.
local w2,c2,r2,last2=setup(92)
local m=w2.add(sprite(1,0,0,255))
learn(m,2,'TESTBOLT',2)
w2.add(sprite(11,100,0,2))
w2.ticks=100
assert(w2.BGSE_Claim(m,'mage','s1')==true and last2('choice').spell=='TESTBOLT')
w2.BGSE_Act(m)
w2.ticks=110
assert(w2.BGSE_Claim(m,'mage','s1')==true and c2:inspect().pending==1)
m.m_curAction=action(472,'',-1)
w2.BGSE_Act(m)
local lost=last2('lost')
assert(lost.cut==true and lost.queued==100 and lost.spell=='TESTBOLT' and last2('cut').ended[1]=='queued')
assert(#w2.queued==2 and w2.queued[2].text=='SpellRES("TESTBOLT",EEex_Target("BGSE"))' and r2.inspect().counts.renewed==1)
-- With its casting aura running and nothing else to do, a mage waits: an idle hold, whose response
-- runs while it stands still and cuts nothing.
local w3,c3,r3,last3=setup(93)
local m3=w3.add(sprite(1,0,0,255))
learn(m3,2,'TESTBOLT',2)
w3.add(sprite(11,100,0,2))
m3.castTimer=40
w3.ticks=100
assert(w3.BGSE_Claim(m3,'mage','s1')==true and last3('wait').tick==100)
m3.m_curAction=action(472,'',-1)
w3.BGSE_Act(m3)
m3.m_curAction={m_actionID=0}
w3.ticks=105
assert(w3.BGSE_Claim(m3,'mage','s1')==true)
m3.m_curAction=action(472,'',-1)
w3.BGSE_Act(m3)
assert(#w3.queued==0 and c3:inspect().counts.cut==0 and last3('cut')==nil and r3.inspect().counts.held==2)
assert(r3.inspect().counts.renewed==0)
end)()
groups=groups+1

-- 43. A giant strength potion at the start of a fight (lab batch J): a fighter of strength 18 whose
-- sword takes strength's bonuses drinks it before it swings, its strength and the sword's flags going
-- from the game's stats through the weapon in hand to the choice, which counts the potion over the
-- rest of the fight. The installed strength table counts (here 22 gives 2 to hit and 5 damage): an
-- installed table that gives 22 the shipped 4 and 10 makes the potion worth more. Without the game's
-- tables the shipped one counts, and the fighter still drinks first.
;(function()
local profiles=require('combat-intent.mind')
ITEMS.TESTGIAN={kind='ITM',resref='TESTGIAN',flags=0,abilities={{form=3,flags=0,location=3,target=5,range=1,speed=0,
    projectile=1,effects={fx(44,{p1=22,p2=1,target=1,duration=600})}}}}
ITEMS.TESTSTRS=weapon('TESTSTRS',{},{flags=1})
local function fight(tables,seed)
    local w=world()
    if tables then tablesOf(w) end
    if tables=='strong' then
        local load=w.EEex_Resource_Load2DA
        w.EEex_Resource_Load2DA=function(name)
            local t=load(name)
            if name~='STRMOD' then return t end
            local copy={columns=t.columns,labels=t.labels,cells={},width=t.width,height=t.height}
            for y=0,t.height-1 do copy.cells[y]=t.labels[y]=='22' and {[0]='4','10'} or t.cells[y] end
            return copy
        end
    end
    local d=directors.new(w,{reader=reader9})
    local c=choices.new(w,{reader=reader9,director=d,seed=seed,
        mindFor=function() return profiles.forFamily(profiles.new(),'fighter') end})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    runtime.install(w,{director=d,choice=c,version='test'})
    local f=w.add(armed(sprite(1,0,0,255),35,'TESTSTRS'))
    f.stats[36]=18
    f.items[18]={cResRef=str('TESTGIAN'),m_useCount1=1}
    f.m_baseStats.m_hitPoints=200;f.stats[1]=200
    local foe=w.add(sprite(11,60,0,2))
    foe.stats[2]=5;foe.m_baseStats.m_hitPoints=100;foe.stats[1]=100
    w.ticks=100
    assert(w.BGSE_Claim(f,'mage','s1')==true)
    local picked
    for n=#list,1,-1 do if list[n].kind=='choice' then picked=list[n];break end end
    w.BGSE_Act(f)
    return picked,w,c
end
local installed,w,c=fight(true,94)
assert(installed.spell=='TESTGIAN' and installed.use==true and installed.castKind=='defence' and installed.rest>0)
assert(w.queued[#w.queued].text:find('UseItem%("TESTGIAN",Myself%)')~=nil and c:inspect().counts.errors==0)
local strong=fight('strong',94)
assert(strong.spell=='TESTGIAN' and strong.worth>installed.worth)
local shipped=fight(false,94)
assert(shipped.spell=='TESTGIAN' and shipped.use==true)
end)()
groups=groups+1

-- 44. Readiness (Christopher, 2026-10-29: clever creatures guard a mazed foe's spot, re-buff and
-- strike when it is back; combat-intent/choice.lua). A clever mage's last enemy, a fighter with a
-- magical long sword, goes into a maze (opcode 213 by intelligence): while it awaits the fighter the
-- mage casts Stoneskin, as the search reads the foe where it vanished, with its sword and its
-- intelligence (10: 4d4 rounds in the game's INTMOD), likely back in a minute ('choice' row with ready
-- and calm). With skins up nothing is worth casting: it walks to its guard place. A normal mage waits
-- at its post and a dull one forgets the foe: neither casts anything. A party member the group charmed
-- counts without its charm, back when the charm ends.
;(function()
local profiles=require('combat-intent.mind')
local INTMOD={columns={MAZE_DURATION_DICE_NUM=0,MAZE_DURATION_DICE_SIZE=1},labels={[0]='3','10'},
    cells={[0]={[0]='10','4'},{[0]='4','4'}},width=3,height=2}
local function scene(seed,wit)
    local w=world()
    tablesOf(w)
    local load=w.EEex_Resource_Load2DA
    w.EEex_Resource_Load2DA=function(name) if name=='INTMOD' then return INTMOD end return load(name) end
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,
        mindFor=wit and function() return profiles.forFamily(profiles.new({wit=wit,tactics=0}),'mage') end or nil})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    runtime.install(w,{director=d,choice=c,version='test'})
    local m=w.add(sprite(1,0,0,255))
    m.stats[2]=8
    local e=w.add(sturdy(armed(sprite(11,300,0,2),35,'TESTSWRD')))
    e.stats[38]=10
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    w.ticks=100
    assert(w.BGSE_Claim(m,'mage','s1')==true)
    learn(m,3,'TESTSTON')
    return w,c,m,e,lastOf
end
-- What the search reads of the foe out of play: an enemy's facts, its sword and intelligence; its
-- maze by intelligence; a charm's seconds left, one without an end lasting.
local w,c,m,e,lastOf=scene(441)
local foe=sense.foe(w,e,reader)
assert(foe.int==10 and foe.attack.damage==4.5 and foe.attack.magical==true and foe.ids.class==2 and foe.hp==80)
e.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
assert(sense.outOfPlay(w,e,100).maze==0 and sense.outOfPlay(w,e,100).charm==nil)
assert(sense.tables(w).maze[10].num==4 and sense.tables(w).maze[10].size==4)
assert(sense.tables(w).maze[3].num==10 and sense.tables(w).maze[3].size==4 and sense.tables(w).maze[9]==nil)
-- The maze: out of every area search, held out of play by the director; the mage casts Stoneskin.
table.remove(w.order)
w.ticks=140
assert(w.BGSE_Claim(m,'mage','s1')==true)
local chosen=lastOf('choice')
assert(chosen and chosen.spell=='TESTSTON' and chosen.castKind=='defence' and chosen.ready==true and math.abs(chosen.calm-60)<1e-9)
assert(lastOf('await')==nil and c:inspect().counts.readies==1 and c:inspect().search.counts.readyFailures==0)
w.BGSE_Act(m)
assert(w.queued[#w.queued].text=='SpellRES("TESTSTON",Myself)')
-- The search's reading on its own (a director that lists the maze since tick 140): twenty seconds
-- on, what is left of 4d4 rounds after twenty seconds; for a foe of intelligence 3 (10d4 rounds)
-- longer. Only a guard readies itself: not a normal creature, a dull one or one ordered to its post.
local seekers=require('adapters.eeex.search')
local search=require('combat-intent.search')
local function reading(g,kind)
    return seekers.new(g,{director={away=function() return {{id=11,kind=kind,x=300,y=0,since=140}} end},reader=reader})
end
local frame,clever={self={id=1,x=0,y=0}},{wit='clever'}
local back=reading(w,'maze'):returning(frame,440,clever,nil)
assert(#back==1 and back[1].id==11 and back[1].away=='maze' and back[1].x==300 and back[1].action==0)
assert(math.abs(back[1].back-search.mazeLeft(4,4,20))<1e-9 and back[1].back<60)
e.stats[38]=3
assert(math.abs(reading(w,'maze'):returning(frame,440,clever,nil)[1].back-search.mazeLeft(10,4,20))<1e-9)
e.stats[38]=10
assert(reading(w,'maze'):returning(frame,440,{wit='normal'},nil)==nil and reading(w,'maze'):returning(frame,440,{wit='dull'},nil)==nil)
assert(reading(w,'maze'):returning(frame,440,clever,{await='post'})==nil)
-- Later, its skins up (cast and over): nothing more is worth it, the mage walks to its guard place
-- 240 short of the spot.
local w2,c2,m2,e2,lastOf2=scene(442)
e2.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
table.remove(w2.order)
m2.m_timedEffectList={{m_effectId=218,m_durationType=4096,m_duration=140+9000,m_effectAmount=8,m_dWFlags=0,
    m_res=str(''),m_sourceRes=str('TESTSTON')}}
m2.stats[88]=8
w2.ticks=140
assert(w2.BGSE_Claim(m2,'mage','s1')==true and lastOf2('choice')==nil and lastOf2('await').how=='guard')
w2.BGSE_Act(m2)
assert(w2.queued[#w2.queued].text=='MoveToPoint([60.0])' and c2:inspect().counts.readies==0)
-- A dull mage forgets the foe and stands: no Stoneskin.
local w3,c3,m3,e3,lastOf3=scene(443,'dull')
e3.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
table.remove(w3.order)
w3.ticks=140
assert(w3.BGSE_Claim(m3,'mage','s1')==true and lastOf3('choice')==nil and lastOf3('await').how=='stand')
assert(c3:inspect().counts.readies==0)
-- A normal mage goes back to its post and waits there: no Stoneskin either.
local w6,c6,m6,e6,lastOf6=scene(446,'normal')
e6.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
table.remove(w6.order)
w6.ticks=140
assert(w6.BGSE_Claim(m6,'mage','s1')==true and lastOf6('choice')==nil and lastOf6('await').how=='post')
assert(c6:inspect().counts.readies==0)
-- A maze of a set duration (parameter 2 = 1): when it ends is unknown, it may be any moment; the
-- mage still renews its Stoneskin, at once.
local w4,c4,m4,e4,lastOf4=scene(444)
e4.m_timedEffectList={{m_effectId=213,m_dWFlags=1,m_durationType=1}}
table.remove(w4.order)
w4.ticks=140
assert(w4.BGSE_Claim(m4,'mage','s1')==true)
assert(lastOf4('choice').spell=='TESTSTON' and lastOf4('choice').calm==0)
-- The fighter charmed by the group (EA 255, in the charmed state) for 30 seconds more: back when the
-- charm ends, its charm left out of what the mage weighs.
local w5,c5,m5,e5,lastOf5=scene(445)
e5.m_typeAI.m_EnemyAlly=255;e5.state=0x2000
e5.m_timedEffectList={{m_effectId=5,m_dWFlags=2,m_durationType=4096,m_duration=140+30*15}}
assert(sense.outOfPlay(w5,e5,140).charm==30)
w5.ticks=140
assert(w5.BGSE_Claim(m5,'mage','s1')==true)
local charmed=lastOf5('choice')
assert(charmed and charmed.spell=='TESTSTON' and charmed.ready==true and math.abs(charmed.calm-30)<1e-9)
local held=reading(w5,'charm'):returning(frame,140,clever,nil)
assert(held[1].away=='charm' and held[1].state==0 and math.abs(held[1].back-30)<1e-9)
e5.m_timedEffectList={{m_effectId=5,m_durationType=1}}
assert(sense.outOfPlay(w5,e5,140).charm==math.huge)
end)()
groups=groups+1

-- 45. Readiness with a storm (Christopher, 2026-10-29: "Was für eine geile Idee"). The clever mage of
-- group 44 knows a fire storm instead of Stoneskin (ten explosions 46 ticks apart, 10 fire each, on
-- everyone in its area, none on a creature its SPLPROT check names), and its foe of intelligence 10
-- goes into a maze of 1d2 rounds (this lab's INTMOD): likely back in 9 seconds. The engine answers
-- the storm's check for the foe out of play too, and the mage lays the storm where the foe vanished:
-- SpellPointRES at its spot, a 'choice' row with ready, calm and the explosions it counts on the foe
-- (seven staying, one walking out). On a foe the check names, or one the group charmed, it lays
-- nothing.
;(function()
local INTMOD={columns={MAZE_DURATION_DICE_NUM=0,MAZE_DURATION_DICE_SIZE=1},labels={[0]='10'},
    cells={[0]={[0]='1','2'}},width=3,height=1}
records.TESTRAIN=spl('TESTRAIN',4,{fx(324,{res='TESTRAIN',p2=110,p1=41,duration=1}),fx(12,{p1=10,p2=8*65536})},4,4)
local reader45={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='STORM',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=150,radius=150,
                coneWidth=0,repeats=10,delay=45}
        end
        return reader.lookup(kind,key)
    end}
local function scene(seed)
    local w=world()
    tablesOf(w)
    local load=w.EEex_Resource_Load2DA
    w.EEex_Resource_Load2DA=function(name) if name=='INTMOD' then return INTMOD end return load(name) end
    w.EngineGlobals.g_pBaldurChitin.m_pObjectGame.m_ruleTables={IsProtectedFromSpell=function(_,row,stats,mine,value)
        return (row==110 and value==41 and stats.state41) and 1 or 0
    end}
    local d=directors.new(w,{reader=reader45})
    local c=choices.new(w,{reader=reader45,director=d,seed=seed})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    runtime.install(w,{director=d,choice=c,version='test'})
    local m=w.add(sprite(1,0,0,255))
    m.stats[2]=8
    local e=w.add(sturdy(armed(sprite(11,300,0,2),35,'TESTSWRD')))
    e.stats[38]=10
    local function lastOf(kind) for n=#list,1,-1 do if list[n].kind==kind then return list[n] end end end
    w.ticks=100
    assert(w.BGSE_Claim(m,'mage','s1')==true)
    learn(m,3,'TESTRAIN')
    return w,c,m,e,lastOf
end
local w,c,m,e,lastOf=scene(451)
e.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
table.remove(w.order)
w.ticks=140
assert(w.BGSE_Claim(m,'mage','s1')==true)
local chosen=lastOf('choice')
assert(chosen and chosen.spell=='TESTRAIN' and chosen.castKind=='damage' and chosen.ready==true and math.abs(chosen.calm-9)<1e-9)
assert(chosen.point.x==300 and chosen.point.y==0 and #chosen.lasting==1 and chosen.lasting[1].id==11)
assert(chosen.lasting[1].stay==7 and chosen.lasting[1].leave==1 and c:inspect().counts.readies==1)
assert(c:inspect().counts.marks==1 and c:inspect().counts.markFailures==0)
w.BGSE_Act(m)
assert(w.queued[#w.queued].text=='SpellPointRES("TESTRAIN",[300.0])')
-- The check names the foe: the storm would do nothing to it.
local w3,c3,m3,e3,lastOf3=scene(453)
e3.state41=true
e3.m_timedEffectList={{m_effectId=213,m_dWFlags=0,m_durationType=1}}
table.remove(w3.order)
w3.ticks=140
assert(w3.BGSE_Claim(m3,'mage','s1')==true and lastOf3('choice')==nil and c3:inspect().counts.marks==1)
-- Charmed by the group for 30 seconds more: the storm would hurt it where it stands.
local w2,c2,m2,e2,lastOf2=scene(452)
e2.m_typeAI.m_EnemyAlly=255;e2.state=0x2000
e2.m_timedEffectList={{m_effectId=5,m_dWFlags=2,m_durationType=4096,m_duration=140+30*15}}
w2.ticks=140
assert(w2.BGSE_Claim(m2,'mage','s1')==true and lastOf2('choice')==nil and c2:inspect().counts.readies==0)
end)()
groups=groups+1

-- 46. The fight as the group knows it, for how long it lasts (lab batch J, run 4: at the start the
-- group's fighter saw 2 of the party's 7 and counted the fight at 13 seconds; it lasted 120). A mage
-- of the group with group 21's summons stands beside a swordsman of the party; 1000 off another mage
-- of the group stands beside two more. The summoner's frame holds neither that mage nor its
-- swordsmen; the group's picture holds them all, so its summons reckons with two against three (the
-- 'choice' row's fight: allies with itself, enemies), a shorter fight than its own one against one.
-- A creature read for it counts as it was for a second: the far mage, charmed over to the party,
-- still counts with the group for a third mage deciding at once, and against it for a fourth a
-- second on.
;(function()
local function scene(far)
    local w=world()
    tablesOf(w)
    local d=directors.new(w,{reader=reader12})
    local c=choices.new(w,{reader=reader12,director=d,seed=461})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    runtime.install(w,{director=d,choice=c,version='test'})
    local function mage(id,x,resref)
        local m=w.add(sprite(id,x,0,255))
        m.stats[2]=8
        learn(m,2,resref or 'TESTBOLT',resref and 1 or 2)
        return m
    end
    local function chosen(member)
        for n=#list,1,-1 do if list[n].kind=='choice' and list[n].member==member then return list[n] end end
    end
    w.add(sturdy(armed(sprite(12,1100,0,2),35,'TESTSWRD')))
    local first
    w.ticks=100
    if far then
        first=mage(1,0)
        w.add(sturdy(armed(sprite(11,100,0,2),35,'TESTSWRD')))
        w.add(sturdy(armed(sprite(13,100,40,2),35,'TESTSWRD')))
        assert(w.BGSE_Claim(first,'mage','s1')==true and chosen(1).fight==nil)
    end
    w.ticks=101
    assert(w.BGSE_Claim(mage(2,1000,'TESTHORD'),'mage','s1')==true)
    assert(chosen(2) and chosen(2).castKind=='summon' and type(chosen(2).rest)=='number')
    return w,c,mage,chosen,first
end
local _,_,_,lone=scene(false)
assert(lone(2).fight==nil)
local w,c,mage,chosen,first=scene(true)
assert(chosen(2).fight[1]==2 and chosen(2).fight[2]==3 and chosen(2).rest<lone(2).rest)
first.m_typeAI.m_EnemyAlly=2
w.ticks=105
assert(w.BGSE_Claim(mage(3,1020),'mage','s1')==true and chosen(3).fight[1]==3 and chosen(3).fight[2]==3)
w.ticks=120
assert(w.BGSE_Claim(mage(4,1040),'mage','s1')==true and chosen(4).fight[1]==3 and chosen(4).fight[2]==4)
assert(c:inspect().counts.fightFailures==0)
end)()
groups=groups+1

-- 47. Doors (combat-intent/doors.lua, adapters/eeex/doors.lua; Christopher, 2026-10-29: doors are in
-- the first release). An area's doors are the CGameDoors among its objects, in any of its lists: the
-- ARE flags (open, locked, secret, found), the closed box, the two spots the game gives for opening
-- one, its travel trigger, key and trap. A door that cannot be read is left out and counted; one
-- whose trap or travel trigger cannot be read counts as trapped or as a way out. A clever mage (a
-- humanoid, with hands for doors) whose enemy walked out of its sight beyond a closed door walks to
-- the door's near spot and opens it at EEex_Target, which names the door, held while it walks and
-- opens; standing again with the door open, it counts the door as opened and walks on through, and
-- at the spot it looks behind the next door near it. A door it could not open is shut and left for
-- doors.retrySeconds; a locked one counts only with its key; one that stands open by the time the
-- gate queues needs nothing. Orders say yes or no to doors; a dull mage or an animal has no hands for
-- them. The search keeps out of danger zones, and a try cut short leaves the door to try again.
;(function()
local doorReader=require('adapters.eeex.doors')
local seekers=require('adapters.eeex.search')
local DOOR=8
-- A closed door across x (its leaf from y=-40 to 40, an outline of 4 points that impedes 6 cells),
-- with the spots on either side the game gives for opening it.
local function door(id,x,fields)
    local d={m_id=id,m_objectType=DOOR,m_dwFlags=0,m_rClosedBounding={left=x-10,top=-40,right=x+10,bottom=40},
        m_nClosedPolygon=4,m_nClosedSearch=6,m_ptDest1={x=x-20,y=0},m_ptDest2={x=x+20,y=0},m_triggerName=str(''),
        m_keyType=str(''),m_trapActivated=0}
    for k,v in pairs(fields or {}) do d[k]=v end
    return d
end
-- A world that knows doors (EEex's object types and casts), with an area of its own.
local function doorWorld()
    local w=world()
    w.CGameObjectType={DOOR=DOOR,SPRITE=49}
    w.EEex_GameObject_CastUserType=function(o) return o end
    local isSprite=w.EEex_GameObject_IsSprite
    w.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.m_objectType~=DOOR and isSprite(o,allowDead) end
    w.area={m_resref=str('AR0001'),m_lVertSort={},m_lVertSortBack={}}
    function w.door(d,list) w.objects[d.m_id]=d;table.insert(w.area[list or 'm_lVertSortBack'],d.m_id);return d end
    return w
end

-- The reader: doors in the back list and the front list, a creature lying there passed over, and
-- doors that cannot be read left out and counted, the last error kept. A "door" without a closed leaf
-- (a harp kept as a door, a barrier for a script) or whose leaf impedes no cell blocks nothing.
local w=doorWorld()
local s=w.add(sprite(1,0,0,255,{m_pArea=w.area}))
table.insert(w.area.m_lVertSortBack,1)
w.door(door(50,150))
w.door(door(51,600,{m_dwFlags=0x3,m_keyType=str('TestKey'),m_trapActivated=1,m_triggerName=str('Tran0001')}),'m_lVertSort')
local blind=door(52,700,{m_dwFlags=0x80,m_ptDest1={x=0,y=0}})
blind.m_trapActivated,blind.m_triggerName=nil,nil
w.door(blind)
w.door(door(53,800,{m_dwFlags=0x180}))
w.door(door(54,900,{m_dwFlags='x'}))
w.door(door(55,950,{m_rClosedBounding={left=1}}))
w.door(door(56,1000,{m_rClosedBounding={left=-1,top=-1,right=0,bottom=0},m_nClosedPolygon=0,m_nClosedSearch=0}))
w.door(door(57,1050,{m_nClosedPolygon=0,m_nClosedSearch=10}))
w.door(door(58,1100,{m_nClosedPolygon=1}))
w.door(door(59,1150,{m_nClosedSearch=0}))
local leafless=door(60,1200)
leafless.m_nClosedSearch=nil
w.door(leafless)
local list,failed,last=doorReader.read(w,w.area)
assert(#list==8 and failed==3 and last:find('door leaf')~=nil)
local d50,d51,d52,d53=list[1],list[2],list[3],list[4]
assert(d50.id==50 and d50.open==false and d50.locked==false and d50.hidden==false and d50.trapped==false and
    d50.travel==false and d50.keyType==nil and #d50.points==2 and d50.points[1].x==130 and d50.points[2].x==170)
assert(d50.blocks==true and d51.blocks==true and d53.blocks==true)
for i=5,8 do assert(list[i].id==55+i-4 and list[i].blocks==false) end
assert(d50.box.left==140 and d50.box.top==-40 and d50.box.right==160 and d50.box.bottom==40)
assert(d51.id==51 and d51.open==true and d51.locked==true and d51.keyType=='TESTKEY' and d51.trapped==true and
    d51.travel==true)
assert(d52.id==52 and d52.hidden==true and d52.trapped==true and d52.travel==true and #d52.points==1 and
    d52.points[1].x==720)
assert(d53.id==53 and d53.hidden==false and d53.open==false)
assert(doorReader.open(w,50)==false and doorReader.open(w,51)==true and doorReader.open(w,1)==nil and
    doorReader.open(w,99)==nil and doorReader.open(w,54)==nil)
assert(#doorReader.read(w,nil)==0)
s.items[18]={cResRef=str('TestKey')}
local keys,n=doorReader.carried(w,s),0
for _ in pairs(keys) do n=n+1 end
assert(keys.TESTKEY==true and n==1)
-- Without EEex's object types nothing is a door.
w.CGameObjectType=nil
list,failed=doorReader.read(w,w.area)
assert(#list==0 and failed==0 and doorReader.open(w,50)==nil)
-- The response: the walk to the door, OpenDoor at EEex_Target, and the walk behind it when that is a
-- whole spot.
assert(choices.doorResponse({x=130,y=0})=='MoveToPoint([130.0])\nOpenDoor(EEex_Target("BGSE"))')
assert(choices.doorResponse({x=380.6,y=10},{x=496,y=0})==
    'MoveToPoint([380.10])\nOpenDoor(EEex_Target("BGSE"))\nMoveToPoint([496.0])')
assert(choices.doorResponse({x=130,y=0},{x=1.5,y=0})=='MoveToPoint([130.0])\nOpenDoor(EEex_Target("BGSE"))')
-- A locked door: its lock first (picked, the unlocking spell cast at it, or bashed), then OpenDoor; a key
-- needs nothing more, and a spell name that cannot go into the response is left out.
assert(choices.doorResponse({x=130,y=0},nil,'pick')==
    'MoveToPoint([130.0])\nPickLock(EEex_Target("BGSE"))\nOpenDoor(EEex_Target("BGSE"))')
assert(choices.doorResponse({x=130,y=0},{x=496,y=0},'knock','SPWI207')==
    'MoveToPoint([130.0])\nSpellRES("SPWI207",EEex_Target("BGSE"))\nOpenDoor(EEex_Target("BGSE"))\nMoveToPoint([496.0])')
assert(choices.doorResponse({x=130,y=0},nil,'bash')==
    'MoveToPoint([130.0])\nBashDoor(EEex_Target("BGSE"))\nOpenDoor(EEex_Target("BGSE"))')
assert(choices.doorResponse({x=130,y=0},nil,'key')==choices.doorResponse({x=130,y=0}))
assert(choices.doorResponse({x=130,y=0},nil,'knock','SP")X')==choices.doorResponse({x=130,y=0}))
-- One action a line: the game reads one action from each line of a queued response, so an action
-- after another on the same line never runs (the door probe, 2026-11-02: only the walk to the door
-- ran; lab batch J: a weapon switch never attacked). Every response of several actions holds one
-- call a line.
local function oneEach(text)
    for line in (text..'\n'):gmatch('(.-)\n') do
        local depth,calls=0,0
        for c in line:gmatch('.') do
            if c=='(' then
                if depth==0 then calls=calls+1 end
                depth=depth+1
            elseif c==')' then depth=depth-1 end
        end
        if calls~=1 or depth~=0 then return false end
    end
    return true
end
assert(not oneEach('MoveToPoint([130.0])OpenDoor(X)') and not oneEach('SelectWeaponAbility(35,0) AttackOneRound(X)'))
assert(oneEach(choices.doorResponse({x=380.6,y=10},{x=496,y=0})) and oneEach(choices.doorResponse({x=130,y=0})))
assert(oneEach(choices.doorResponse({x=130,y=0},{x=496,y=0},'knock','SPWI207')) and
    oneEach(choices.doorResponse({x=130,y=0},nil,'bash')))
assert(oneEach(choices.response({resref='TESTSSWD',kind='weapon',target=12,slot=35,abilityNum=0})))
assert(oneEach(choices.response({resref='FLANK',kind='flank',point={x=248,y=100},slot=36,abilityNum=0})))
assert(choices.chain('SelectWeaponAbility(35,0)','','AttackOneRound(X)')=='SelectWeaponAbility(35,0)\nAttackOneRound(X)')

-- The mage of group 33 behind doors: its enemy, last seen 300 away, walked out of its sight; a closed
-- door stands across the way at 150, another beyond the spot at 400.
local function scene(seed,orders,mage,gate,extra)
    local g=doorWorld()
    local rd=extra and extra(g) or reader
    local d=directors.new(g,{reader=rd})
    local c=choices.new(g,{reader=rd,director=d,seed=seed,orders=orders})
    local rows={}
    c:setSink(function(row) rows[#rows+1]=row end)
    runtime.install(g,{director=d,choice=c,version='test'})
    local function lastOf(kind) for i=#rows,1,-1 do if rows[i].kind==kind then return rows[i] end end end
    local m=g.add(sprite(1,0,0,255,{m_pArea=g.area}))
    if mage then mage(m) end
    local e=g.add(sprite(11,300,0,2,{m_pArea=g.area}))
    local first=g.door(door(50,150))
    if gate then gate(first) end
    g.door(door(60,400))
    local function claimAt(tick) g.ticks=tick;return g.BGSE_Claim(m,'mage','s1') end
    assert(claimAt(100)==true)
    e.m_pos={x=900,y=0}
    assert(claimAt(140)==true)
    return g,c,m,first,lastOf,claimAt
end
local function walks(g,m,lastOf)
    g.BGSE_Act(m)
    return g.queued[#g.queued].text=='MoveToPoint([300.0])' and lastOf('door')==nil and lastOf('search').to.x==300
end
local g1,c1,m1,gate1,last1,claim1=scene(471)
g1.BGSE_Act(m1)
local r1=last1('door')
assert(g1.queued[#g1.queued].text=='MoveToPoint([130.0])\nOpenDoor(EEex_Target("BGSE"))' and m1.aux.EEex_Target.BGSE==50)
assert(r1 and r1.door==50 and r1.to.x==130 and r1.toward.x==300 and r1.clue=='seen' and r1.target==11 and
    r1.behind==nil and r1.tactical==true)
assert(c1:inspect().search.counts.doors==1 and last1('search')==nil)
-- Held while it walks and opens.
local holds1=c1:inspect().counts.holds
m1.m_curAction={m_actionID=23}
assert(claim1(150)==true)
m1.m_curAction={m_actionID=143}
assert(claim1(160)==true and c1:inspect().counts.holds==holds1+2 and last1('door-end')==nil)
-- Standing at the door, open now: opened, and the search walks on through it.
gate1.m_dwFlags=1;m1.m_curAction={m_actionID=0};m1.m_pos={x=130,y=0}
assert(claim1(170)==true)
local e1=last1('door-end')
assert(e1 and e1.door==50 and e1.open==true and e1.why=='done' and c1:inspect().search.counts.doorsOpened==1)
g1.BGSE_Act(m1)
assert(g1.queued[#g1.queued].text=='MoveToPoint([300.0])' and last1('search').to.x==300)
-- At the spot: it looks behind the door near it, past its middle on the far side, and the spot counts
-- as searched.
m1.m_pos={x=300,y=0}
assert(claim1(200)==true)
g1.BGSE_Act(m1)
local b1=last1('door')
assert(g1.queued[#g1.queued].text=='MoveToPoint([380.0])\nOpenDoor(EEex_Target("BGSE"))\nMoveToPoint([496.0])' and
    m1.aux.EEex_Target.BGSE==60 and b1.door==60 and b1.behind.x==496 and b1.toward==nil)
assert(c1:inspect().search.counts.doors==2)
-- A door that stays shut: when the mage stands without having opened it, the door is left and the
-- mage walks the way all the same (the game finds its way round, where there is one).
local g2,c2,m2,_,last2,claim2=scene(472)
g2.BGSE_Act(m2)
m2.m_curAction={m_actionID=23}
assert(claim2(150)==true)
m2.m_curAction={m_actionID=0}
assert(claim2(170)==true)
local e2=last2('door-end')
assert(e2.open==false and e2.why=='done' and c2:inspect().search.counts.doorsShut==1 and
    c2:inspect().search.counts.doorsOpened==0)
assert(walks(g2,m2,function(kind) if kind~='door' then return last2(kind) end end))
assert(c2:inspect().search.counts.doors==1)
-- A block of SCS's above the hook cuts the try short (the hold's response runs, kernel/hook.lua):
-- right after the door was queued it is tried again at once; once the mage was under way it counts
-- as a try that ended, the door shut and left, and the mage walks on in the same response.
local g10,c10,m10,_,last10,claim10=scene(480)
g10.BGSE_Act(m10)
m10.m_curAction={m_actionID=23}
assert(claim10(145)==true)
m10.m_curAction=action(472,'',-1)
g10.BGSE_Act(m10)
local cut10=last10('cut')
assert(cut10.ended[1]=='search' and last10('door-end').why=='cut' and last10('door-end').open==false)
assert(g10.queued[#g10.queued].text=='MoveToPoint([130.0])\nOpenDoor(EEex_Target("BGSE"))' and
    c10:inspect().search.counts.doors==2 and c10:inspect().search.counts.doorsShut==0)
m10.m_curAction={m_actionID=23}
assert(claim10(160)==true)
m10.m_curAction=action(472,'',-1)
g10.BGSE_Act(m10)
assert(last10('door-end').why=='done' and c10:inspect().search.counts.doorsShut==1)
assert(g10.queued[#g10.queued].text=='MoveToPoint([300.0])' and last10('search').to.x==300)
-- A cloud comes up round the mage on its way to the door, its explosion five seconds off (group
-- 24's): the mage walks out of it first. The door's try ends ('zone'), the door not left.
local readerZ={problems={},idsName=reader.idsName,get=reader.get,lookup=function(kind,key)
        if kind=='PRO' and key==4 then
            return {kind='PRO',resref='CLOUD',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=150,radius=150,coneWidth=0}
        end
        return reader.lookup(kind,key)
    end}
local function clouded(g)
    g.EEex_Projectile_Type={CProjectileArea=8}
    g.EEex_Projectile_GetType=function(o) return o.projectile or 1 end
    g.EEex_CastUD=function(o) return o end
    local isSprite=g.EEex_GameObject_IsSprite
    g.EEex_GameObject_IsSprite=function(o,allowDead) return o~=nil and o.projectile==nil and isSprite(o,allowDead) end
    g.area.m_lVertSortFlight={}
    return readerZ
end
local g11,c11,m11,_,last11,claim11=scene(481,nil,nil,nil,clouded)
g11.BGSE_Act(m11)
m11.m_curAction={m_actionID=23}
local hot={m_effectId=12,m_durationType=1,m_duration=0,m_effectAmount=0,m_dWFlags=8*65536,m_flags=1,
    m_probabilityUpper=100,m_probabilityLower=0,m_res=str(''),m_numDice=4,m_diceSize=9,m_savingThrow=0,m_saveMod=0,
    m_special=0,m_spellLevel=4,m_casterLevel=10,m_sourceRes=str('TESTCLDS')}
g11.objects[950]={m_id=950,projectile=8,state=0,m_nRepetitionCount=1,m_bReachedDestination=1,m_pos={x=0,y=0},
    m_posDest={x=0,y=0},m_explosionRange=150,m_nDelay=75,m_nDelayCount=75,m_sourceId=11,m_projectileType=3,
    m_resref=str('CLOUD'),m_effectList={hot}}
table.insert(g11.area.m_lVertSortFlight,950)
assert(claim11(150)==true)
local end11=last11('door-end')
assert(end11 and end11.why=='zone' and end11.open==false and c11:inspect().search.counts.doorsShut==0)
assert(last11('choice').castKind=='escape')
-- One that stands open by the time the gate queues needs nothing.
local g3,c3,m3,gate3,last3=scene(473)
local queued3=#g3.queued
gate3.m_dwFlags=1
g3.BGSE_Act(m3)
assert(#g3.queued==queued3 and last3('door')==nil and c3:inspect().counts.skipped==1)
-- Orders say no; a dull mage or an animal has no hands for doors; orders let the dull one open.
local g4,_,m4,_,last4=scene(474,{TEST1={doors=false}})
assert(walks(g4,m4,last4))
local function dull(m) m.stats[38],m.stats[39]=4,8 end
local g5,_,m5,_,last5=scene(475,nil,dull)
assert(walks(g5,m5,last5))
local g6,_,m6,_,last6=scene(476,{TEST1={doors=true}},dull)
g6.BGSE_Act(m6)
assert(last6('door').door==50 and m6.aux.EEex_Target.BGSE==50)
local g7,_,m7,_,last7=scene(477,nil,function(m) m.m_typeAI.m_General=2 end)
assert(walks(g7,m7,last7))
-- A locked door: shut to a mage without its key, opened by one that carries it.
local function locked(d) d.m_dwFlags=2;d.m_keyType=str('TESTKEY') end
local g8,_,m8,_,last8=scene(478,nil,nil,locked)
assert(walks(g8,m8,last8))
local g9,_,m9,_,last9=scene(479,nil,function(m) m.items[18]={cResRef=str('TESTKEY')} end,locked)
g9.BGSE_Act(m9)
assert(last9('door').door==50 and m9.aux.EEex_Target.BGSE==50)
-- A lock of difficulty 50 (Christopher, 2026-11-03): a mage of Open Locks 60 picks it, held while it
-- picks; one of 40 cannot, nor one at a lock whose difficulty cannot be read.
local function hard(d) d.m_dwFlags=2;d.m_lockDifficulty=50 end
local function picker(skill) return function(m) m.stats[26]=skill end end
local g12,c12,m12,_,last12,claim12=scene(482,nil,picker(60),hard)
g12.BGSE_Act(m12)
assert(g12.queued[#g12.queued].text=='MoveToPoint([130.0])\nPickLock(EEex_Target("BGSE"))\nOpenDoor(EEex_Target("BGSE"))')
assert(last12('door').way=='pick' and c12:inspect().search.counts.unlocks==1)
m12.m_curAction={m_actionID=145}
assert(claim12(160)==true and last12('door-end')==nil)
local g13,_,m13,_,last13=scene(483,nil,picker(40),hard)
assert(walks(g13,m13,last13))
local g14,_,m14,_,last14=scene(484,nil,picker(100),function(d) d.m_dwFlags=2;d.m_lockDifficulty=nil end)
assert(walks(g14,m14,last14))

-- The seeker on its own (adapters/eeex/search.lua): a spot beyond a door in a danger zone counts as
-- searched; a door whose spot lies in a zone is left for now and the search walks on; a try cut short
-- or ended by a hit leaves the door to try again, one whose time ran out leaves it shut. Without a
-- reader for its kind the creature opens no door; a reader that fails is logged once.
local wz=doorWorld()
local sz=wz.add(sprite(1,0,0,255,{m_pArea=wz.area}))
wz.add(sprite(11,2000,0,2,{m_pArea=wz.area}))
wz.door(door(50,150))
local rowsz={}
local function lastz(kind) for i=#rowsz,1,-1 do if rowsz[i].kind==kind then return rowsz[i] end end end
local director={clues=function() return {{id=11,x=300,y=0,tick=100}} end,group=function() return {} end}
local function fresh(options)
    local o={director=director,reader=reader,record=function(row) rowsz[#rowsz+1]=row end}
    for k,v in pairs(options or {}) do o[k]=v end
    return seekers.new(wz,o)
end
local frame={area='AR0001',self={id=1,x=0,y=0,hp=40,maxHp=40,ea=255},enemies={}}
local clever={wit='clever',tactics=1}
local function decide(seeker,tick,zoneAt,orders) return seeker:decide(sz,frame,tick,'mage',clever,{},{},zoneAt,orders) end
local sk=fresh()
local dz=decide(sk,150)
assert(dz.kind=='door' and dz.door==50 and dz.point.x==130 and dz.toward.x==300)
assert(decide(sk,150,nil,{doors=false}).kind=='search')
dz=decide(fresh(),150,function(p) return p.x>=250 end)
assert(dz.kind=='look' and dz.zone==true and dz.searched==dz.key)
sk=fresh()
dz=decide(sk,150,function(p) return p.x>=120 and p.x<=140 end)
assert(dz.kind=='look' and dz.zone==true and dz.searched==nil)
dz=decide(sk,151)
assert(dz.kind=='search' and dz.point.x==300)
-- A try cut short (by a block of SCS's) is judged 'cut': the door is tried again.
sk=fresh()
dz=decide(sk,150)
sk:door(sz,dz,dz.point,nil,150)
sz.m_curAction={m_actionID=23}
assert(sk:holding(sz,1,152)=='door')
sk:stop(1,153,'cut')
assert(lastz('door-end').why=='cut' and lastz('door-end').open==false and sk:inspect().counts.doorsShut==0)
assert(sk:holding(sz,1,154)==false and decide(sk,154).kind=='door')
-- Hurt on the way: judged, not left.
sk:door(sz,dz,dz.point,nil,154)
sz.m_baseStats.m_hitPoints=30
assert(sk:holding(sz,1,156)==false and lastz('door-end').why=='hurt' and sk:inspect().counts.doorsShut==0)
sz.m_baseStats.m_hitPoints=40
-- Out of time (twice the walk's seconds and the margins: 84 ticks for 130): shut and left.
dz=decide(sk,160)
assert(dz.kind=='door')
sk:door(sz,dz,dz.point,nil,160)
assert(sk:holding(sz,1,243)=='door')
assert(sk:holding(sz,1,244)==false and lastz('door-end').why=='time' and sk:inspect().counts.doorsShut==1)
assert(decide(sk,245).kind=='search')
sz.m_curAction={m_actionID=0}
-- Without a reader, no door and no error; a reader that fails is logged once.
local quiet=fresh({reader=false})
assert(decide(quiet,150).kind=='search' and quiet:inspect().counts.doorFailures==0)
local broken=fresh({reader={idsName=function() error('no ids') end}})
local errors=0
for _,row in ipairs(rowsz) do if row.kind=='error' then errors=errors+1 end end
assert(decide(broken,150).kind=='search' and decide(broken,151).kind=='search')
assert(broken:inspect().counts.doorFailures==2 and lastz('error').where=='door-opener')
local after=0
for _,row in ipairs(rowsz) do if row.kind=='error' then after=after+1 end end
assert(after==errors+1)
-- With nothing to go on, in a fight and indoors (the area's type, ARE header bit 0 clear), the seeker
-- looks behind the closed door near it (SCS's door block); not outdoors, not a minute after its last
-- sight of an enemy, not where the area's type cannot be read.
local wq=doorWorld()
local sq=wq.add(sprite(1,0,0,255,{m_pArea=wq.area}))
wq.door(door(50,150))
local frameq={area='AR0001',self={id=1,x=0,y=0,hp=40,maxHp=40,ea=255},enemies={}}
local function quietSeeker()
    return seekers.new(wq,{director={clues=function() return {} end,group=function() return {} end},reader=reader,
        record=function() end})
end
local function lookAt(seeker,tick) return seeker:decide(sq,frameq,tick,'mage',clever,{},{},nil,nil) end
local sq1=quietSeeker()
sq1:fight(sq,frameq,100)
wq.area.m_header={m_areaType=0}
local dq=lookAt(sq1,200)
assert(dq.kind=='door' and dq.door==50 and dq.behind and dq.behind.x>150)
wq.area.m_header={m_areaType=1}
assert(select(2,lookAt(sq1,200))=='no-clue')
wq.area.m_header={m_areaType=0}
assert(select(2,lookAt(sq1,100+61*15))=='no-clue')
wq.area.m_header=nil
assert(select(2,lookAt(sq1,200))=='no-clue')
assert(select(2,lookAt(quietSeeker(),200))=='no-clue')
-- A door that cannot be read is logged once ('door-read') and left out; the others still count.
wz.door(door(56,200,{m_dwFlags='x'}))
local faulty=fresh()
dz=decide(faulty,150)
assert(dz.kind=='door' and dz.door==50 and faulty:inspect().counts.doorFailures==1 and lastz('error').where=='door-read')
end)()
groups=groups+1

-- 48. Staying (Christopher, 2026-10-28: nobody leaves for good). BGSE_Stay keeps a creature the engine
-- drives in the fight, so SCS's vanishing exit stands aside, with one 'stay' row a creature; not for a
-- creature off the engine's side, a script it does not carry, with the choice off, or when its orders
-- let it leave (leave=true). A load forgets the rows.
;(function()
local function setup(seed,orders)
    local w=world()
    local d=directors.new(w,{reader=reader})
    local c=choices.new(w,{reader=reader,director=d,seed=seed,orders=orders})
    local list={}
    c:setSink(function(row) list[#list+1]=row end)
    local r=runtime.install(w,{director=d,choice=c,version='test'})
    local function rows() local out={};for _,row in ipairs(list) do if row.kind=='stay' then out[#out+1]=row end end;return out end
    return w,c,r,rows
end
local g,ch,root,rows=setup(91)
local m=g.add(sprite(1,0,0,255))
assert(g.BGSE_Stay(m,'mage','s1')==true and g.BGSE_Stay(m,'mage','s1')==true and #rows()==1)
local r=rows()[1]
assert(r.member==1 and r.resref=='TEST1' and r.family=='mage' and ch:inspect().counts.kept==1)
assert(g.BGSE_Stay(m,'fighter','s3')==false)
m.m_typeAI.m_EnemyAlly=128
assert(g.BGSE_Stay(m,'mage','s1')==false)
m.m_typeAI.m_EnemyAlly=255
root.setChoice(false)
assert(g.BGSE_Stay(m,'mage','s1')==false)
root.setChoice(true)
assert(g.BGSE_Stay(m,'mage','s1')==true and #rows()==1)
ch:invalidate()
assert(g.BGSE_Stay(m,'mage','s1')==true and #rows()==2 and ch:inspect().counts.errors==0)
-- Orders: leave=true lets SCS's exit run for that creature file, and only for it.
local g2,ch2,_,rows2=setup(92,{TEST1={leave=true}})
local m2=g2.add(sprite(1,0,0,255))
local o2=g2.add(sprite(2,0,0,255))
assert(g2.BGSE_Stay(m2,'mage','s1')==false and g2.BGSE_Stay(o2,'mage','s1')==true)
assert(#rows2()==1 and rows2()[1].member==2 and ch2:inspect().counts.errors==0)
end)()
groups=groups+1

return groups
