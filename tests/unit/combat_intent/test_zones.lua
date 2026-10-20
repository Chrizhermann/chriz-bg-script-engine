-- Danger zones (combat-intent/zones.lua) on synthetic zones classified by combat-intent/spells.lua,
-- and their place in the choice (combat-intent/choice.lua). No game data.
local zones=require('combat-intent.zones')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
local function area(radius,flags)
    return {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=flags or 0,trigger=30,radius=radius,coneWidth=0}
end
local function spell(resref,level,effects,ability,pro)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' and key==2 then return pro or SINGLE end end,{level=15})
end
-- What one explosion of each zone does: an Incendiary Cloud's fire (20 a hit of power 4, save vs
-- breath at -4 for half), a Cloudkill's poison (5) and death up to level 4 (save vs death at -5), a
-- Stinking Cloud's spell failure, a gentle cloud (1 a hit), a storm that makes those it hits
-- immune to it for 12 seconds (its own guard against stacking names another resource).
local fire=spell('TESTFIRE',8,{fx(12,{p2=8*65536,dice=4,sides=9,save=2,saveBonus=-4,special=256,power=4})},{target=4},
    area(256))
local kill=spell('TESTKILL',5,{fx(12,{p2=32*65536,p1=5}),fx(13,{p2=4,save=4,saveBonus=-5,dice=4})},{target=4},area(256))
local stink=spell('TESTSTNK',2,{fx(60,{p1=100,duration=7,save=4,saveBonus=-2})},{target=4},area(256))
local gentle=spell('TESTGNTL',1,{fx(12,{p2=8*65536,p1=1})},{target=4},area(256))
local storm=spell('TESTSTRM',7,{fx(12,{p2=8*65536,p1=20}),fx(206,{res='TESTSTRX',duration=12})},{target=4},area(256))
local bolt=spell('TESTBOLT',3,{fx(12,{p2=8*65536,dice=10,sides=6})})

local function zone(s,fields)
    local z={id=900,x=100,y=100,radius=150,left=30,every=5,filter='all',side='enemy',spell=s}
    for k,v in pairs(fields or {}) do z[k]=v end
    return z
end
local function enemy(id,fields)
    local e={id=id,x=500,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,skins=0,mirror=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10,attack={apr=1,thac0=10,damage=8}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function row(resref,s,level)
    return {resref=resref,level=level,ready=1,memorized=1,usable=true,list='wizard',spell=s}
end
local function input(fields,self)
    local me={id=1,x=100,y=100,hp=40,maxHp=40,state=0,held=0,ac=8,mr=0,level=15,thac0=17,
        ids={ea=255,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11},guard={},protections={},
        saves={spell=10,breath=12,death=10,wand=11,poly=11},resist={}}
    for k,v in pairs(self or {}) do me[k]=v end
    local i={tick=100,family='mage',frame={self=me,enemies={},allies={}},spells={},plan={},memory={},mind=mind.new(),zones={}}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function near(a,b,eps) return math.abs(a-b)<(eps or 1e-9) end

-- 1. One explosion on the creature in it: what gets through its resistance, magic resistance and
-- saves; Cloudkill's death only up to level 4; spell failure counts for casters; a zone for its
-- caster's enemies spares that caster's side; a globe keeps a low-level zone out.
do
    local i=input()
    local me=i.frame.self
    local h=zones.hit(i,zone(fire),me)
    -- 4d9 (20) at breath 12 with -4: saves 5 in 20, half on a save.
    local save=targeting.saveChance(fire.roles.damage,me)
    assert(near(save,0.25))
    assert(near(h,20*(1-save/2)/40))
    me.resist={fire=100}
    assert(zones.hit(i,zone(fire),me)==0)
    me.resist={fire=50}
    assert(near(zones.hit(i,zone(fire),me),10*(1-save/2)/40))
    me.resist={}
    -- Magic resistance lets three in four through.
    me.mr=25
    assert(near(zones.hit(i,zone(fire),me),0.75*20*(1-save/2)/40))
    me.mr=0
    -- Cloudkill: poison, and death up to level 4 (save vs death at -5: 10 fails 20 in 20).
    local low=input({}, {level=3})
    local high=input({}, {level=15})
    local deadly=zones.hit(low,zone(kill),low.frame.self)
    local mild=zones.hit(high,zone(kill),high.frame.self)
    assert(deadly>mild and mild>0)
    -- Stinking Cloud's spell failure: a caster loses more than a fighter.
    local mage=zones.hit(i,zone(stink),me)
    local warrior=input({}, {ids={ea=255,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11}})
    local fighter=zones.hit(warrior,zone(stink),warrior.frame.self)
    assert(mage>0 and fighter>0 and near(fighter,mage*0.2))
    -- A zone for its caster's enemies, cast by a friend, spares the friend's side.
    assert(zones.hit(i,zone(fire,{filter='enemies',side='friend'}),me)==0)
    assert(zones.hit(i,zone(fire,{filter='enemies',side='enemy'}),me)>0)
    assert(zones.hit(i,zone(fire,{filter='allies',side='enemy'}),me)==0)
    -- A globe against power 4 stops the fire; one against power 5 does not.
    me.protections={{opcode=102,p1=4}}
    assert(zones.hit(i,zone(fire),me)==0)
    me.protections={{opcode=102,p1=5}}
    assert(zones.hit(i,zone(fire),me)>0)
    me.protections={}
    groups=groups+1
end

-- 2. Counting explosions: spread evenly when the next one is unknown, exactly from the next one
-- when it is known, none after the zone ends, at most one per immunity a zone gives those it hits.
do
    local z=zone(fire,{every=5,left=30})
    assert(near(zones.count(z,0,6),6/5))
    assert(near(zones.count(z,28,40),2/5))
    assert(zones.count(z,30,40)==0)
    z.next=1
    -- Explosions at 1, 6, 11, ...: two in (0,6], one in (1,6].
    assert(zones.count(z,0,6)==2 and zones.count(z,1,6)==1 and zones.count(z,6,10)==0)
    local s=zone(storm,{every=5,left=60})
    assert(zones.period(s)==12 and near(zones.count(s,0,6),0.5))
    -- An immunity shorter than the explosions changes nothing.
    assert(zones.period(zone(storm,{every=15}))==15)
    groups=groups+1
end

-- 3. What walking to a point is worth in the zones: out of harm gains what a round there would
-- take, into harm costs it; nothing without zones or where nothing hurts.
do
    local i=input({zones={zone(fire)}})
    local out=zones.delta(i,{x=400,y=100})
    local h=zones.hit(i,zone(fire),i.frame.self)
    assert(out>0 and out<=h*(6+3)/5+1e-9)
    -- Standing still is worth nothing either way.
    assert(near(zones.delta(i,{x=100,y=100}),0))
    -- From outside into the cloud costs.
    local away=input({zones={zone(fire)}},{x=600,y=100})
    assert(zones.delta(away,{x=100,y=100})<0)
    assert(zones.delta(input(),{x=400,y=100})==0)
    local immune=input({zones={zone(fire)}},{resist={fire=100}})
    assert(zones.delta(immune,{x=400,y=100})==0)
    groups=groups+1
end

-- 4. The way out: the shortest walk beyond every zone that hurts; none for a creature nothing
-- hurts, one that cannot walk, or one whose zone ends before it would be out.
do
    local i=input({zones={zone(fire)}})
    local o,why=zones.escape(i)
    assert(o and o.kind=='escape' and o.mode=='point' and o.worth>0 and o.score==o.worth and o.cost==0)
    assert(targeting.distance(o.point,{x=100,y=100})>=150+zones.margin-1)
    assert(o.walk>0 and o.walk<(150+zones.margin+2)/zones.walkSpeed+1e-9)
    assert(#o.zones==1 and o.zones[1].radius==150 and #o.exits>=1)
    -- Two clouds side by side: out of both.
    local two=input({zones={zone(fire),zone(fire,{id=901,x=300})}})
    local p=zones.escape(two)
    assert(p and targeting.distance(p.point,{x=100,y=100})>=150+zones.margin-1 and
        targeting.distance(p.point,{x=300,y=100})>=150+zones.margin-1)
    _,why=zones.escape(input({zones={zone(fire)}},{resist={fire=100}}))
    assert(why=='unharmed')
    _,why=zones.escape(input({zones={zone(fire)}},{rooted=true}))
    assert(why=='rooted')
    _,why=zones.escape(input({zones={zone(fire)}},{held=1}))
    assert(why=='rooted')
    -- Explosions every 5 seconds with 1 second left: gone before the creature is out.
    _,why=zones.escape(input({zones={zone(fire,{left=1})}}))
    assert(why=='no-worth')
    _,why=zones.escape(input({zones={zone(fire)}},{x=600}))
    assert(why=='unharmed')
    _,why=zones.escape(input({zones={}}))
    assert(why=='no-zone')
    -- Zones that cannot be read are left out.
    _,why=zones.escape(input({zones={{x=100,y=100}}}))
    assert(why=='unharmed')
    groups=groups+1
end

-- 5. Casts where the caster stands: each explosion whose damage lands may break them; a save for
-- half still breaks; none outside the zones or without damage.
do
    local i=input({zones={zone(fire,{next=1})}})
    assert(near(zones.through(i,3),math.exp(-1)))
    assert(near(zones.through(i,0.5),1))
    local o={resref='TESTBOLT',kind='damage',worth=1,cost=0.1,score=0.9,speed=5}
    zones.adjust(i,o,{})
    assert(near(o.worth,math.exp(-1)) and near(o.score,o.worth-0.1))
    -- A potion is not broken; a ranged weapon stays where it is.
    local potion={resref='POTN',kind='heal',worth=1,cost=0,score=1,speed=0,use=true}
    zones.adjust(i,potion,{})
    assert(potion.worth==1)
    local bow={resref='BOW',kind='weapon',worth=1,cost=0,score=1,speed=0,target=5}
    zones.adjust(i,bow,{[5]={id=5,x=900,y=100}})
    assert(bow.worth==1)
    assert(zones.through(input({zones={zone(stink,{next=1})}}),3)==1)
    assert(zones.through(input({zones={zone(fire,{next=1})}},{x=600}),3)==1)
    groups=groups+1
end

-- 6. Melee: walking to a target out of the cloud gains, into one costs.
do
    local i=input({zones={zone(fire)}})
    local sword={resref='SWORD',kind='weapon',melee=true,worth=0.3,cost=0,score=0.3,speed=0,target=5}
    zones.adjust(i,sword,{[5]={id=5,x=420,y=100}})
    assert(sword.worth>0.3)
    local outside=input({zones={zone(fire)}},{x=600})
    local into={resref='SWORD',kind='weapon',melee=true,worth=0.3,cost=0,score=0.3,speed=0,target=6}
    zones.adjust(outside,into,{[6]={id=6,x=120,y=100}})
    assert(into.worth<0.3)
    groups=groups+1
end

-- 7. The choice: in a cloud that hurts, the way out comes first unless the best option is worth
-- more than leaving by more than the walk's share of a round; nothing changes without zones or in
-- the caster's own Time Stop.
do
    local foe=enemy(5,{x=400,y=100})
    local base={spells={row('TESTBOLT',bolt,3)}}
    local plain=input(base)
    plain.frame.enemies={foe}
    local d,why=choice.decide(plain)
    assert(d and d.resref=='TESTBOLT' and why~='escape')
    local hot=input({spells=base.spells,zones={zone(fire,{next=1})}})
    hot.frame.enemies={foe}
    d,why=choice.decide(hot)
    assert(d and d.kind=='escape' and why=='escape')
    -- A gentle cloud (one hit point now and then) against a bolt: the bolt.
    local mild=input({spells=base.spells,zones={zone(gentle)}},{hp=40,maxHp=40})
    mild.frame.enemies={foe}
    d,why=choice.decide(mild)
    assert(d and d.resref=='TESTBOLT')
    -- With nothing to cast, the way out.
    local idle=input({zones={zone(gentle)}})
    idle.frame.enemies={foe}
    d,why=choice.decide(idle)
    assert(d and d.kind=='escape')
    -- In the caster's own Time Stop the zones are frozen.
    local stopped=input({spells=base.spells,zones={zone(fire)},timeStop={caster=1,left=6}})
    stopped.frame.enemies={foe}
    d,why=choice.decide(stopped)
    assert(d and d.kind~='escape')
    groups=groups+1
end
return groups
