-- The engine's own attack choice (combat-intent/choice.lua), creature filters (ids.lua) and
-- profiles (mind.lua), on synthetic spells classified by combat-intent/spells.lua. No game data.
local choice=require('combat-intent.choice')
local ids=require('combat-intent.ids')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local rng=require('kernel.rng')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
local function area(radius,flags,cone)
    return {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=flags or 0,trigger=30,
        radius=radius,coneWidth=cone or 0}
end
local function spell(resref,level,effects,ability,pro)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' and key==2 then return pro or SINGLE end end,{level=10})
end
local FIRE=8*65536
local bolt=spell('TESTBOLT',3,{fx(12,{p2=FIRE,dice=6,sides=6})})
local missile=spell('TESTMM',1,{fx(12,{p1=1,p2=64*65536,dice=1,sides=4})},{projectile=69})
local finger=spell('TESTFOD',7,{fx(13,{save=4})})
local hold=spell('TESTHOLD',2,{fx(175,{p2=3,p1=1,duration=30,save=1})})
local silence=spell('TESTSIL',2,{fx(38,{duration=60})})
local ball=spell('TESTBALL',3,{fx(12,{p2=FIRE,dice=6,sides=6,save=1,special=256})},{target=4},area(64))
local screen=spell('TESTSCRN',3,{fx(12,{p2=FIRE,dice=6,sides=6})},nil,area(64,64))
local cone=spell('TESTCONE',5,{fx(12,{p2=2*65536,dice=6,sides=6})},nil,area(200,2048,90))
local heal=spell('TESTHEAL',4,{fx(17,{p1=20})})
local breach=spell('TESTBRCH',5,{fx(221,{p2=1,p1=9})})
local odd=spell('TESTODD',3,{fx(12,{p1=5})},{projectile=66})
local storm=spell('TESTGLOB',5,{fx(12,{p1=10,target=4})})
local potion=spells.classify({kind='ITM',resref='TESTPOTN',flags=0,abilities={{form=3,flags=0,location=3,target=5,
    range=1,speed=0,projectile=1,effects={fx(17,{p1=20,target=1})}}}},1,function() end,{level=1})

local function enemy(id,fields)
    local e={id=id,x=100+id*10,y=100,hp=50,maxHp=50,state=0,held=0,sanctuary=0,mr=0,action=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function row(resref,s,level,fields)
    local r={resref=resref,level=level,ready=1,memorized=1,usable=true,list='mage',spell=s}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function input(fields)
    local i={tick=100,family='mage',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=0},enemies={},allies={}},
        spells={},plan={},memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function enemies(i,list) i.frame.enemies=list;return i end

-- 1. Creature filters: EA cutoffs, the *_ALL classes, alignment masks, plain entries; what
-- cannot be judged answers nil.
local pc={ids={ea=2,general=1,race=1,class=13,specific=0,gender=1,alignment=0x13}}
assert(ids.matches({ids=2,entry=30},pc)==true and ids.matches({ids=2,entry=200},pc)==false)
assert(ids.matches({ids=2,entry=31},{ids={ea=255}})==true and ids.matches({ids=2,entry=199},pc)==true)
assert(ids.matches({ids=5,entry=202},pc)==true and ids.matches({ids=5,entry=203},pc)==false)
assert(ids.matches({ids=5,entry=205},pc)==true and ids.matches({ids=5,entry=13},pc)==true)
assert(ids.matches({ids=8,entry=0x03},pc)==true and ids.matches({ids=8,entry=0x10},pc)==true)
assert(ids.matches({ids=8,entry=0x01},pc)==false and ids.matches({ids=8,entry=0x30},pc)==false)
assert(ids.matches({ids=3,entry=1},pc)==true and ids.matches({ids=3,entry=4},pc)==false)
assert(ids.matches({ids=2,entry=28},pc)==nil and ids.matches({ids=9,entry=1},pc)==nil)
assert(ids.matches({ids=4,entry=1},{ids={}})==nil and ids.matches({ids=4,entry=0},{ids={}})==true)
assert(ids.caster(pc) and not ids.caster({ids={class=2}}) and not ids.caster({}))
groups=groups+1

-- 2. Profiles: a fresh copy of the default each time; changes are checked field by field.
local m1,m2=mind.new(),mind.new()
m1.allySpells.TESTX=true
assert(m2.allySpells.TESTX==nil and mind.default.allySpells.TESTX==nil)
local sharp=assert(mind.new({best=0.95,band=0.05,coordination=0}))
assert(sharp.best==0.95 and sharp.coordination==0 and sharp.band==0.05)
local bad,why=mind.new({best=2});assert(bad==nil and why=='best')
bad,why=mind.new({knowledge='all'});assert(bad==nil and why=='knowledge')
bad,why=mind.new({defer={allyHealth=0.5}});assert(bad==nil and why=='defer')
bad,why=mind.new({clever=1});assert(bad==nil and why=='clever')
groups=groups+1

-- 3. What counts as an attack and how it is aimed.
local k,mode=choice.attack(bolt);assert(k=='damage' and mode=='creature')
k,mode=choice.attack(hold);assert(k=='disable' and mode=='creature')
k,mode=choice.attack(ball);assert(k=='damage' and mode=='point-area')
k,mode=choice.attack(screen);assert(k=='damage' and mode=='creature-area')
k,mode=choice.attack(missile);assert(k=='damage' and mode=='creature')
assert(select(2,choice.attack(heal))=='role-heal' and select(2,choice.attack(breach))=='role-removal')
assert(select(2,choice.attack(odd))=='unknown-projectile' and select(2,choice.attack(storm))=='global')
assert(select(2,choice.attack(nil))=='unclassified')
-- A cone that pauses its caster for two seconds is still an attack; a long self-pause is not.
local paused=spell('TESTSHOU',4,{fx(165,{target=1,duration=2}),fx(12,{p2=FIRE,dice=4,sides=6})},{target=4},area(200,2048,30))
k,mode=choice.attack(paused);assert(k=='damage' and mode=='point-area' and paused.pause==2)
local frozen=spell('TESTFRZ',4,{fx(165,{target=1,duration=60}),fx(12,{p2=FIRE,dice=4,sides=6})})
assert(select(2,choice.attack(frozen))=='self-harm')
groups=groups+1

-- 4. Damage goes to the group's focus, unless another target is clearly better: a kill.
local i=enemies(input({spells={row('TESTBOLT',bolt,3)},plan={focus=12}}),{enemy(11,{x=150}),enemy(12,{x=300})})
local d,reason,options=choice.decide(i)
assert(d.target==12 and reason=='best' and #options==2 and options[2].target==11)
assert(math.abs(d.worth-0.63)<1e-9 and math.abs(d.cost-0.09)<1e-9)
i=enemies(input({spells={row('TESTBOLT',bolt,3)},plan={focus=12}}),{enemy(11,{x=150,hp=15}),enemy(12,{x=300})})
d=choice.decide(i);assert(d.target==11)
-- Without coordination the focus counts for nothing: the nearer of two equal enemies is no
-- better, so the lower id wins the tie.
i=enemies(input({spells={row('TESTBOLT',bolt,3)},plan={focus=12},mind=mind.new({coordination=0})}),
    {enemy(11,{x=150}),enemy(12,{x=300})})
assert(choice.decide(i).target==11)
groups=groups+1

-- 5. Economical casting: a small spell finishes a nearly dead enemy; a strong one is kept for
-- a strong enemy.
i=enemies(input({spells={row('TESTMM',missile,1),row('TESTFOD',finger,7)}}),{enemy(11,{hp=3})})
d=choice.decide(i);assert(d.resref=='TESTMM' and d.target==11)
i=enemies(input({spells={row('TESTMM',missile,1),row('TESTFOD',finger,7)}}),{enemy(11)})
d=choice.decide(i);assert(d.resref=='TESTFOD')
assert(math.abs(d.worth-1.5*0.95)<1e-9)
-- A spell not ready or not usable is no option.
i=enemies(input({spells={row('TESTFOD',finger,7,{ready=0}),row('TESTBOLT',bolt,3,{usable=false})}}),{enemy(11)})
local _,why,_,rejected=choice.decide(i)
assert(why=='no-option' and next(rejected)==nil)
groups=groups+1

-- 6. Disables: never at an enemy already disabled, nor at one another member reserved
-- (unless the profile ignores the plan); the spell's creature filter decides who can be held;
-- silence is worth most against casters.
i=enemies(input({spells={row('TESTHOLD',hold,2)}}),{enemy(11,{x=150,state=0x80000000}),enemy(12,{x=300})})
d=choice.decide(i);assert(d.target==12 and d.kind=='disable' and #d.hits==1)
assert(math.abs(d.worth-0.95)<1e-9)
i=enemies(input({spells={row('TESTHOLD',hold,2)},plan={reserved={[12]=5}}}),{enemy(11,{state=0x80000000}),enemy(12)})
_,why,_,rejected=choice.decide(i)
-- The reasons come along: 11 is held already, 12 reserved by member 5 (worth nothing).
assert(why=='no-option' and rejected.disabled==1 and rejected['no-worth']==1)
i.plan.reserved[12]=1;assert(choice.decide(i).target==12)
i.plan.reserved[12]=5;i.mind=mind.new({coordination=0});assert(choice.decide(i).target==12)
i=enemies(input({spells={row('TESTHOLD',hold,2)}}),{enemy(11,{ids={ea=2,general=2,class=2}})})
assert(select(2,choice.decide(i))=='no-option')
i=enemies(input({spells={row('TESTSIL',silence,2)}}),{enemy(11,{x=120}),enemy(12,{x=300,ids={ea=2,general=1,class=1}})})
assert(choice.decide(i).target==12)
-- A level limit on the disable: an enemy above it is no target.
local snooze=spell('TESTSLP',1,{fx(39,{dice=4,duration=30})})
i=enemies(input({spells={row('TESTSLP',snooze,1)}}),{enemy(11,{x=120,level=9}),enemy(12,{x=300,level=3})})
d=choice.decide(i);assert(d.target==12 and math.abs(d.worth-0.8*0.6)<1e-9)
groups=groups+1

-- 7. What the enemy resists: resistances, magic resistance, saves.
i=enemies(input({spells={row('TESTBOLT',bolt,3)},plan={focus=11}}),{enemy(11,{x=150,resist={fire=100}}),enemy(12,{x=300})})
assert(choice.decide(i).target==12)
i=enemies(input({spells={row('TESTBOLT',bolt,3)}}),{enemy(11,{mr=100}),enemy(12,{mr=100})})
assert(select(2,choice.decide(i))=='no-option')
local role={save={spell=true},saveBonus=-2}
assert(math.abs(choice.saveChance(role,{saves={spell=12}})-0.35)<1e-9)
assert(choice.saveChance(role,{})==0.5 and choice.saveChance({},{saves={spell=1}})==0)
assert(choice.saveChance({save={spell=true,death=true}},{saves={spell=18,death=1}})==0.95)
-- A sleep the enemy may break with a save every round (Spell Revisions' Greater Command): the
-- first round for sure, each later one while every save so far failed.
local free={every=6,save={spell=true},saveBonus=-4}
assert(math.abs(choice.brokenFree(60,free,{saves={spell=10}})-6*(1-0.65^10)/0.35)<1e-9)
assert(math.abs(choice.brokenFree(60,free,{})-6*(1-0.5^10)/0.5)<1e-9)
assert(choice.brokenFree(60,{every=6},{})==60 and choice.brokenFree(nil,free,{})==0)
groups=groups+1

-- 8. Area spells: the middle of a cluster beats one enemy's spot; never with an ally or the
-- caster inside; an enemies-only area ignores allies.
local cluster={enemy(11,{x=400,y=100}),enemy(12,{x=430,y=100}),enemy(13,{x=460,y=120}),enemy(14,{x=250,y=400})}
i=enemies(input({spells={row('TESTBALL',ball,3)}}),cluster)
d=choice.decide(i)
assert(d.mode=='point-area' and #d.hits==3 and d.point.x==430 and d.point.y==107 and d.target==nil)
i.frame.allies={{id=2,x=440,y=100,hp=10,maxHp=10,state=0}}
d=choice.decide(i);assert(d.point.x==250 and d.point.y==400 and #d.hits==1)
i=enemies(input({spells={row('TESTBALL',ball,3)}}),{enemy(11,{x=120,y=100})})
assert(select(2,choice.decide(i))=='no-option')
i=enemies(input({spells={row('TESTSCRN',screen,3)}}),{enemy(11,{x=400}),enemy(12,{x=430})})
i.frame.allies={{id=2,x=415,y=100,hp=10,maxHp=10,state=0}}
d=choice.decide(i);assert(d.mode=='creature-area' and #d.hits==2 and (d.target==11 or d.target==12))
groups=groups+1

-- 9. Cones start at the caster: they hit the enemies in the direction aimed, not with an ally
-- in the way.
i=enemies(input({spells={row('TESTCONE',cone,5)}}),{enemy(11,{x=250,y=100}),enemy(12,{x=260,y=140}),enemy(13,{x=100,y=240})})
d=choice.decide(i);assert(#d.hits==2 and (d.target==11 or d.target==12))
i.frame.allies={{id=2,x=200,y=100,hp=10,maxHp=10,state=0}}
d=choice.decide(i);assert(d.target==13 and #d.hits==1)
groups=groups+1

-- 10. Memory: a spell that missed without a save or magic resistance to blame met an
-- immunity; with a save, an earlier miss halves the worth.
i=enemies(input({spells={row('TESTBOLT',bolt,3)},memory={['TESTBOLT:11']=1}}),{enemy(11,{x=150}),enemy(12,{x=300})})
d,reason,options=choice.decide(i);assert(d.target==12 and #options==1)
i.frame.enemies[1].mr=20
d,reason,options=choice.decide(i)
assert(d.target==12 and #options==2 and options[2].target==11 and math.abs(options[2].worth-0.42*0.8*0.5)<1e-9)
i.mind=mind.new({memory=false});i.frame.enemies[1].mr=0
assert(choice.decide(i).target==11)
groups=groups+1

-- 11. The engine heals itself (D3a): no round goes to SCS for wounds or silence. A badly hurt
-- ally of its level gets the heal over a bolt; a nearly whole one does not; a drink for the
-- caster when hurt, while the potion lasts. A silenced caster's spells are not usable, so it has
-- no option.
i=enemies(input({spells={row('TESTBOLT',bolt,3)}}),{enemy(11)})
i.frame.self.level=10
i.frame.allies={{id=2,x=150,y=150,hp=10,maxHp=100,state=0,level=10}}
i.spells[2]=row('TESTHEAL',heal,4,{list='priest'})
i.family='priest'
d,reason=choice.decide(i)
assert(d.kind=='heal' and d.resref=='TESTHEAL' and d.target==2 and d.mode=='ally' and reason=='best')
i.frame.allies[1].hp=90;assert(choice.decide(i).resref=='TESTBOLT')
i.spells[2]=nil;i.frame.self.hp=10
i.items={{resref='TESTPOTN',abilities={{effect=potion,uses=2}}}}
d=choice.decide(i);assert(d.kind=='heal' and d.use==true and d.self==true and d.resref=='TESTPOTN')
i.items[1].abilities[1].uses=0;assert(choice.decide(i).resref=='TESTBOLT')
i.spells[1].usable=false;i.frame.self.state=0x1000
assert(select(2,choice.decide(i))=='no-option')
assert(select(2,choice.decide({}))=='bad-input')
groups=groups+1

-- 12. Worth below the profile's minimum leaves the round to SCS; otherwise the best option,
-- or with the profile's odds a random near-best one.
i=enemies(input({spells={row('TESTMM',missile,1)}}),{enemy(11,{hp=200,maxHp=200})})
d,reason=choice.decide(i);assert(d==nil and reason=='nothing-good')
local four={enemy(11,{x=200}),enemy(12,{x=220}),enemy(13,{x=240}),enemy(14,{x=260})}
local seen={}
for seed=1,40 do
    local r=enemies(input({spells={row('TESTBOLT',bolt,3)},mind=mind.new({best=0,band=1}),rng=rng.new(seed)}),four)
    local pick,how=choice.decide(r)
    assert(how=='near-best');seen[pick.target]=true
end
local kinds=0;for _ in pairs(seen) do kinds=kinds+1 end
assert(kinds>=3)
for seed=1,10 do
    local r=enemies(input({spells={row('TESTBOLT',bolt,3)},plan={focus=13},mind=mind.new({best=1}),rng=rng.new(seed)}),four)
    assert(choice.decide(r).target==13)
end
groups=groups+1

-- 15. Creature conditions belong to what they deliver: a fire bolt with a troll extra is a
-- damage option against anyone; a charm elves resist nine times in ten is worth a tenth as
-- much on an elf; a hold of humanoids is no option against an animal.
local function classified(resref,level,effects,files)
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,level=level,
        abilities={{form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,
        effects=effects}},casting={}}
    return spells.classify(r,1,function(kind,key)
        if kind=='PRO' and key==2 then return SINGLE end
        return files[kind..':'..tostring(key)]
    end,{level=10})
end
local trollBolt=classified('TESTTRBL',3,{fx(12,{p2=FIRE,dice=6,sides=6}),fx(177,{p1=129,p2=4,res='TESTTRX'})},
    {['EFF:TESTTRX']={kind='EFF',resref='TESTTRX',effect=fx(13,{})}})
assert(choice.attack(trollBolt)=='damage')
i=enemies(input({spells={row('TESTTRBL',trollBolt,3)}}),{enemy(11)})
opts=choice.options(i)
assert(#opts==1 and opts[1].kind=='damage' and opts[1].target==11)
local dire=classified('TESTDIRE',3,{fx(177,{p1=2,p2=4,prob1=89,res='TESTELFI'}),fx(5,{duration=60})},
    {['EFF:TESTELFI']={kind='EFF',resref='TESTELFI',effect=fx(101,{p2=5,duration=1})}})
i=enemies(input({spells={row('TESTDIRE',dire,3)}}),
    {enemy(11),enemy(12,{ids={ea=2,general=1,race=2,class=2,specific=0,gender=1,alignment=0x11}})})
opts=choice.options(i)
assert(#opts==2 and opts[1].target==11 and opts[2].target==12)
assert(math.abs(opts[2].worth/opts[1].worth-(1-90/101))<1e-9)
local rejected={}
i=enemies(input({spells={row('TESTHOLD',hold,2)}}),{enemy(11,{ids={ea=2,general=2,class=2}})})
assert(#choice.options(i,rejected)==0 and rejected.filter==1)
groups=groups+1

-- 16. A spell's own immunity check, read through the engine for each enemy (e.splprot): an
-- enemy in the spell state it checks is no target; one whose mark is unknown still is.
local srCharm=classified('TESTSRCH',3,{fx(324,{res='TESTSRCH',p2=110,p1=41,duration=1}),fx(5,{duration=60})},{})
local state41=spells.conditionKey({row=110,value=41})
i=enemies(input({spells={row('TESTSRCH',srCharm,3)}}),
    {enemy(11,{splprot={[state41]=true}}),enemy(12,{splprot={[state41]=false}}),enemy(13)})
rejected={}
opts=choice.options(i,rejected)
assert(#opts==2 and opts[1].target==12 and opts[2].target==13 and rejected.filter==1)
groups=groups+1

-- 13. Who can be aimed at: in range, no sanctuary, seen, alive.
i=enemies(input({spells={row('TESTBOLT',bolt,3)}}),{enemy(11,{x=700}),enemy(12,{x=300})})
assert(choice.decide(i).target==12)
i.frame.enemies[2].sanctuary=1;assert(select(2,choice.decide(i))=='no-option')
i.frame.enemies[2].sanctuary=0;i.frame.enemies[2].state=0x10;assert(select(2,choice.decide(i))=='no-option')
i.frame.self.seeInvisible=true;assert(choice.decide(i).target==12)
i.frame.enemies[2].state=0x800;assert(select(2,choice.decide(i))=='no-option')
groups=groups+1

-- 14. Aims of one spell that hit the same enemies are one option: the one centred on a
-- creature the spell counts, then the one holding its enemies furthest inside. An area hold
-- at a held enemy beside a free one goes to the free one.
local holdArea=spell('TESTHLDA',2,{fx(175,{p2=3,p1=1,duration=30,save=1})},nil,area(64))
i=enemies(input({spells={row('TESTHLDA',holdArea,2)}}),{enemy(11,{x=400,state=0x20,held=1}),enemy(12,{x=430})})
local opts=choice.options(i)
assert(#opts==1 and opts[1].mode=='creature-area' and opts[1].target==12 and #opts[1].hits==1 and opts[1].hits[1]==12)
-- Two enemies close together: every point that catches both is the same option, the one
-- between them.
i=enemies(input({spells={row('TESTBALL',ball,3)}}),{enemy(11,{x=400,y=100}),enemy(12,{x=410,y=100})})
opts=choice.options(i)
assert(#opts==1 and #opts[1].hits==2 and opts[1].point.x==405 and opts[1].point.y==100)
-- Different enemies hit stay different options.
i=enemies(input({spells={row('TESTBALL',ball,3)}}),{enemy(11,{x=400,y=100}),enemy(12,{x=530,y=100})})
assert(#choice.options(i)==2)
groups=groups+1

-- 17. Spell slots (Christopher, 2026-10-21): a slot costs less when the caster has more spells
-- ready than rounds it can expect to live. Two fighters deal the caster 38 hit points a round
-- (40 left): with eight bolts ready a slot costs the rounds it lives over eight. The round it is
-- in always counts; without threat, or with no more spells than rounds, a slot costs in full.
-- Copies count; spells it cannot cast now or that do nothing in a fight do not. Skins keep it
-- standing longer. A drink costs in full.
local threat=require('combat-intent.threat')
local function near(a,b) return math.abs(a-b)<1e-9 end
local function brute(id,fields)
    local e=enemy(id,{x=130,ac=4,action=3,actee=1,attack={apr=2,thac0=5,damage=10,magical=true}})
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function bolts(n)
    local list={}
    for k=1,n do list[k]=row('TESTBOLT',bolt,3) end
    return list
end
i=enemies(input({spells=bolts(8)}),{brute(11),brute(12)})
local t=threat.picture(i.frame)[1]
assert(near(t.weapon.hp,38) and t.spell.hp==0)
assert(near(choice.slotShare(i),(40/38)/8))
i=enemies(input({spells=bolts(2)}),{brute(11)})
assert(choice.slotShare(i)==1)
i.spells=bolts(4);assert(near(choice.slotShare(i),(40/19)/4))
i=enemies(input({spells=bolts(4)}),{brute(11),brute(12),brute(13),brute(14)})
assert(near(choice.slotShare(i),1/4))
i.spells=bolts(1);assert(choice.slotShare(i)==1)
i=enemies(input({spells=bolts(8)}),{enemy(11,{x=1000}),enemy(12,{x=1020})})
assert(choice.slotShare(i)==1)
i=enemies(input({spells=bolts(4)}),{brute(11),brute(12)})
i.spells[1].ready=3
i.spells[5]=row('TESTBOLT',bolt,3,{usable=false})
i.spells[6]=row('TESTBOLT',bolt,3,{ready=0})
i.spells[7]=row('TESTODD',nil,3)
i.spells[8]=row('TESTNONE',{roles={}},3)
assert(near(choice.slotShare(i),(40/38)/6))
i=enemies(input({spells=bolts(8)}),{brute(11),brute(12)})
i.frame.self.guard={stoneskins=8}
assert(near(choice.slotShare(i),(8/3.8+40/38)/8))
-- In decide the share comes along unless given (input.slots). A bolt worth 0.26 against fighters
-- of 80 hit points stays below the minimum worth at full price; with about a round to live and
-- eight bolts ready the caster casts it.
local function brutes(hp) return {brute(11,{hp=hp,maxHp=hp}),brute(12,{hp=hp,maxHp=hp})} end
i=enemies(input({spells=bolts(1)}),brutes(80))
d,reason=choice.decide(i);assert(d==nil and reason=='nothing-good')
i.spells=bolts(8)
d,reason=choice.decide(i)
assert(d.resref=='TESTBOLT' and reason=='best' and near(d.cost,0.09*(40/38)/8) and i.slots==nil)
i.slots=1;assert(select(2,choice.decide(i))=='nothing-good')
i.slots=0.5;assert(near(choice.decide(i).cost,0.045))
i=enemies(input({spells=bolts(8),items={{resref='TESTPOTN',abilities={{effect=potion,uses=1}}}}}),brutes(80))
i.frame.self.hp=10
local _,_,listed=choice.decide(i)
local drink,cast
for _,o in ipairs(listed) do
    if o.resref=='TESTPOTN' then drink=o elseif o.resref=='TESTBOLT' then cast=cast or o end
end
assert(near(drink.cost,0.03) and near(cast.cost,0.09/8))
groups=groups+1

return groups
