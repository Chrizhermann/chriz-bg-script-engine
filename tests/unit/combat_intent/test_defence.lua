-- The engine's own defences (combat-intent/defence.lua) and the threat picture behind them
-- (combat-intent/threat.lua), on synthetic spells classified by combat-intent/spells.lua and
-- plain frames. No game data.
local defence=require('combat-intent.defence')
local threat=require('combat-intent.threat')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=1,power=0,p1=0,p2=0,timing=0,resist=1,duration=60,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function area(radius,flags)
    return {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=flags or 0,trigger=30,radius=radius,coneWidth=0}
end
local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
-- A spell of one ability; pros maps projectile numbers to PRO records, subs names sub-spells.
local function spell(resref,level,effects,ability,pros,subs)
    local a={form=1,flags=0,location=2,target=5,targetCount=0,range=30,minLevel=1,speed=1,projectile=1,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    local function lookup(kind,key)
        if kind=='PRO' then return (pros or {})[key] or (key==2 and SINGLE or nil) end
        if kind=='SPL' then return (subs or {})[key] end
    end
    return spells.classify(r,1,lookup,{level=10})
end
local function sub(resref,effects,projectile)
    return {kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,level=1,
        abilities={{form=1,flags=0,location=2,target=4,targetCount=0,range=30,minLevel=1,speed=1,
        projectile=projectile,effects=effects}},casting={}}
end

local pfmw=spell('TESTPFMW',6,{fx(120,{p1=6,duration=24})})
local slowPfmw=spell('TESTSLOW',6,{fx(120,{p1=6,duration=24})},{speed=9})
local stoneskin=spell('TESTSTON',4,{fx(218,{p1=8,duration=600})})
local mirror=spell('TESTMIRR',2,{fx(159,{p1=6,duration=300})})
local armour=spell('TESTARMR',1,{fx(0,{p1=4,duration=600})})
local resistance=spell('TESTRESI',5,{fx(166,{p1=50,duration=120})})
local globe=spell('TESTGLOB',4,{fx(102,{p1=1,duration=120}),fx(102,{p1=2,duration=120}),fx(102,{p1=3,duration=120})})
local deflection=spell('TESTDEFL',5,{fx(201,{p1=9,p2=6,duration=120})})
local improved=spell('TESTIINV',4,{fx(20,{p2=1,duration=60,target=2})},{target=1})
local free=spell('TESTFREE',4,{fx(101,{p2=109,target=2,duration=1200}),fx(101,{p2=175,target=2,duration=1200}),
    fx(101,{p2=185,target=2,duration=1200}),fx(101,{p2=40,target=2,duration=1200})},{target=1})
local chaos=spell('TESTCHAO',5,{fx(101,{p2=5,target=2,duration=1200}),fx(101,{p2=128,target=2,duration=1200}),
    fx(101,{p2=39,target=2,duration=1200})},{target=1})
-- Spell Revisions' Recitation: a blessing through an allies-only area, a curse through an
-- enemies-only one, both cast by the caster on itself.
local recitation=spell('TESTRECI',4,{fx(146,{res='TESTRECG',p2=1,duration=0,timing=1}),
    fx(146,{res='TESTRECB',p2=1,duration=0,timing=1})},{speed=7},
    {[337]=area(512,192),[338]=area(426,64)},
    {TESTRECG=sub('TESTRECG',{fx(54,{p1=2,target=2,duration=120})},337),
     TESTRECB=sub('TESTRECB',{fx(54,{p1=-2,target=2,duration=120})},338)})
-- Spell Revisions' Haste: half an attack for allies in an area at a point; the fatigue comes
-- when it ends.
local haste=spell('TESTHAST',3,{fx(1,{p1=6,target=2,duration=144}),fx(176,{p1=6,target=2,duration=144}),
    fx(146,{res='TESTHASD',p2=1,timing=4,duration=144,target=2})},{target=4,projectile=99,speed=3},
    {[99]=area(256,192)},{TESTHASD=sub('TESTHASD',{fx(0,{p1=-2,target=2,duration=18}),fx(54,{p1=-2,target=2,duration=18})},1)})
-- Armour for the caster and blades around it that cut everyone near it.
local blades=spell('TESTBLAD',6,{fx(0,{p1=4,target=1,duration=60}),fx(12,{p1=10,target=2,duration=0})},
    {projectile=98},{[98]=area(128,0)})
local bolt=spell('TESTBOLT',3,{fx(12,{p2=8*65536,dice=6,sides=6,target=2,duration=0})},{target=1,projectile=2})

local function fighter(id,x,fields)
    local e={id=id,x=x,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=3,actee=1,ac=4,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=14,breath=14,death=14,wand=14,poly=14},resist={},level=8,
        attack={apr=2,thac0=10,damage=10,magical=true}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function mage(id,x,fields)
    local e=fighter(id,x,{ids={ea=2,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11},level=10,
        action=0,actee=-1,attack={apr=1,thac0=17,damage=3,magical=false}})
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function row(resref,s,level,fields)
    local r={resref=resref,level=level,ready=1,memorized=1,usable=true,list='mage',spell=s}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function input(enemies,list,fields)
    local i={tick=1000,family='mage',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=0,ac=8,mr=0,guard={}},
        enemies=enemies or {},allies={}},spells=list or {},plan={},memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function find(options,resref)
    for _,o in ipairs(options) do if o.resref==resref then return o end end
end
local function near(a,b) return math.abs(a-b)<1e-6 end

-- 1. The threat picture: an enemy hits the friend it attacks, else the nearest one it reaches;
-- hidden friends are safe from weapons and aimed spells of enemies that do not see invisible
-- creatures; a caster's spells spread over the friends it sees.
local i=input({fighter(11,130),fighter(12,135,{actee=-1})})
i.frame.allies={{id=2,x=60,y=100,hp=80,maxHp=80,state=0,ac=2}}
local t=threat.picture(i.frame)
assert(near(t[1].weapon.attacks,4) and near(t[1].weapon.hits,3.8) and near(t[1].weapon.hp,38))
assert(t[2].weapon.attacks==0 and #t[1].attackers==2)
assert(near(threat.hitChance(10,8),0.95) and near(threat.hitChance(20,0),0.05) and near(threat.hitChance(12,5),0.7))
i.frame.self.state=0x400000
t=threat.picture(i.frame)
assert(t[1].weapon.attacks==0 and t[2].weapon.attacks==4)
i.frame.enemies[1].seeInvisible=true
t=threat.picture(i.frame)
assert(t[1].weapon.attacks==2 and t[2].weapon.attacks==2)
-- What comes from enemies that see invisible creatures stays apart (seeing): invisibility does
-- not keep it away.
assert(near(t[1].weapon.seeing,t[1].weapon.hp) and t[1].weapon.seeing>0 and t[2].weapon.seeing==0)
i=input({mage(21,300)})
i.frame.allies={{id=2,x=120,y=100,hp=80,maxHp=80,state=0,ac=2}}
t=threat.picture(i.frame)
assert(near(t[1].spell.hp,6) and near(t[2].spell.hp,6) and near(t[1].spell.personal,3.6) and near(t[1].spell.disable,0.075))
assert(t[1].spell.level==5 and t[1].weapon.attacks==0 and t[1].spell.seeing==0)
i.frame.enemies[1].seeInvisible=true
assert(near(threat.picture(i.frame)[1].spell.seeing,3.6))
i.frame.enemies[1].seeInvisible=nil
i.frame.enemies[1].action=31;i.frame.enemies[1].actee=2
t=threat.picture(i.frame)
assert(t[1].spell.hp==0 and near(t[2].spell.hp,12))
-- A held enemy threatens no one; one too far for a round's walk neither.
i=input({fighter(11,130,{held=1}),fighter(12,1000,{actee=-1})})
t=threat.picture(i.frame)
assert(t[1].weapon.attacks==0)
groups=groups+1

-- 2. Shields and what they block. Protection from Magical Weapons stops magical weapons while
-- it holds; Stoneskin's skins and Mirror Images absorb hits one by one first; globes keep out
-- every spell of their levels, deflections only aimed ones; Free Action keeps holds out.
-- Independent ways compound; globes and deflections count by the levels they cover together.
local s=defence.shield(pfmw.roles)
assert(s.magicalUpTo==6 and not s.nonmagical)
local w={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=4},spell={hp=12,personal=7.2,area=4.8,disable=0.15,casters=1,level=5}}
local b=defence.blocks(s,w,3)
assert(near(b.rate,1) and b.pool==0)
local mundane={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=0},spell=w.spell}
assert(near(defence.blocks(s,mundane,3).rate,0))
b=defence.blocks(defence.shield(stoneskin.roles),w,3)
assert(b.rate==0 and b.pool==8)
assert(near(defence.blocks(defence.shield(mirror.roles),w,3).pool,6*0.95))
b=defence.blocks(defence.shield(globe.roles),w,3)
assert(near(b.spell,7.2*0.6+4.8*0.6) and near(b.disable,0.6))
b=defence.blocks(defence.shield(deflection.roles),w,3)
assert(near(b.spell,7.2) and b.rate==0 and near(b.personal,1))
b=defence.blocks(defence.shield(free.roles),w,3)
assert(near(b.disable,0.3) and b.spell==0)
b=defence.blocks(defence.shield(chaos.roles),w,3)
assert(near(b.disable,0.15+0.1+0.05))
b=defence.blocks(defence.shield(improved.roles),w,3)
assert(near(b.rate,0.9) and near(b.spell,7.2*0.9+4.8*0))
-- Half the attacks magical: Protection from Magical Weapons stops half, armour lowers the rest.
local mixed={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=2},spell=w.spell}
local plated=defence.union(defence.shield(armour.roles),defence.shield(pfmw.roles))
assert(near(defence.blocks(defence.shield(pfmw.roles),mixed,3).rate,0.5))
assert(near(defence.blocks(defence.shield(armour.roles),mixed,3).rate,1-0.75/0.95))
assert(near(defence.blocks(plated,mixed,3).rate,1-0.5*0.75/0.95))
-- Magic resistance and a globe compound; a globe and a deflection cover levels together.
b=defence.blocks(defence.union(defence.shield(resistance.roles),defence.shield(globe.roles)),w,3)
assert(near(b.spell,12*(1-0.5*0.4)) and near(b.disable,1-0.4*0.5))
b=defence.blocks(defence.union(defence.shield(globe.roles),defence.shield(deflection.roles)),w,3)
assert(near(b.spell,7.2+4.8*0.6))
assert(defence.attacks(6)==0.5 and defence.attacks(7)==1.5 and defence.attacks(1)==1 and defence.attacks(-1)==0)
-- What protects a friend now: its guard's roles, the engine's counts, its invisibility; its
-- armour class already holds its armour bonuses.
local held=defence.held({state=0x400010,mr=30,guard={roles={protection={kinds={armor=true},amounts={armor=4}}},stoneskins=5,mirror=2}})
assert(held.armor==0 and held.stoneskin==5 and held.mirror==2 and held.invisible and held.improved and held.mr==30)
local both=defence.union(defence.shield(stoneskin.roles),defence.shield(pfmw.roles))
assert(both.stoneskin==8 and both.magicalUpTo==6)
groups=groups+1

-- 3. Harm over time. Two fighters kill an unprotected caster of 40 hit points in about a round;
-- Stoneskin's eight skins hold two rounds, so the caster lives through three. A friend out of
-- the fight loses a round of disable's worth for each round of the horizon it is dead.
local f={hp=40,maxHp=40}
local melee={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=4},spell={hp=0,personal=0,area=0,disable=0,casters=0,level=0}}
local harm,death=defence.course(defence.held({}),f,melee,3)
assert(near(harm,114) and near(death,40/38))
harm,death=defence.course(defence.shield(stoneskin.roles),f,melee,3)
assert(near(harm,34) and near(death,8/3.8+40/38))
harm,death=defence.course(defence.shield(pfmw.roles),f,melee,3)
assert(harm==0 and death==math.huge)
local bare=defence.loss(defence.held({}),f,melee,3,0.5)
assert(near(bare,1.5+(3-40/38)/3))
assert(near(defence.loss(defence.shield(stoneskin.roles),f,melee,3,0.5),0.85+0.5*0.7))
assert(near(defence.loss(defence.shield(mirror.roles),f,melee,3,0.5),1.5+(3-1.5-40/38)/3))
-- A friend with minimum hit points (opcode 208) loses no more than it has above them and lives:
-- 30 of 40 with a minimum of 10, no kill bonus and no rounds out of the fight.
local tough={hp=40,maxHp=40,minHp=10}
harm,death=defence.course(defence.held({}),tough,melee,3)
assert(near(harm,30) and death==math.huge)
assert(near(defence.loss(defence.held({}),tough,melee,3,0.5),30/40))
-- Temporary hit points go first; spell harm runs alongside absorbed hits.
local burned={weapon=melee.weapon,spell={hp=10,personal=6,area=4,disable=0,casters=1,level=5}}
harm,death=defence.course(defence.shield(stoneskin.roles),f,burned,3)
assert(near(harm,30+34) and near(death,8/3.8+(40-10*8/3.8)/48))
local padded=defence.shield(stoneskin.roles);padded.hp=20
harm=defence.course(padded,f,burned,3)
assert(near(harm,44))
-- Invisibility keeps away only harm from enemies that do not see invisible creatures. A friend
-- hidden now meets only enemies that see it (threat.picture), so what hides it keeps nothing
-- more away; against half from such enemies, half of what it would.
local hiddenNow=defence.held({state=0x400000})
local seen={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=4,seeing=38},
    spell={hp=10,personal=6,area=4,disable=0.15,casters=1,level=5,seeing=6}}
harm,death=defence.course(hiddenNow,f,seen,3)
assert(near(harm,144) and near(death,40/48))
local b=defence.blocks(hiddenNow,seen,3)
assert(b.rate==0 and b.personal==0 and b.spell==0 and b.disable==0)
local halfSeen={weapon={hp=38,hits=3.8,attacks=4,magicalAttacks=4,seeing=19},
    spell={hp=10,personal=6,area=4,disable=0.15,casters=1,level=5,seeing=3}}
b=defence.blocks(hiddenNow,halfSeen,3)
assert(near(b.rate,0.45) and near(b.personal,0.45) and near(b.disable,0.45))
assert(near(defence.blocks(hiddenNow,burned,3).rate,0.9))
groups=groups+1

-- 4. Weighing: two fighters at a caster with no protection make Protection from Magical
-- Weapons worth more than Stoneskin, Stoneskin more than Mirror Image (SCS's order); no worth
-- when no one threatens; a caster already protected gains nothing from a second protection of
-- the same kind.
local list={row('TESTPFMW',pfmw,6),row('TESTSTON',stoneskin,4),row('TESTMIRR',mirror,2),row('TESTBOLT',bolt,3)}
i=input({fighter(11,130),fighter(12,135)},list)
local rejected={}
local opts=defence.options(i,rejected)
local o=find(opts,'TESTPFMW')
assert(o and o.kind=='defence' and o.self and o.mode=='self' and o.hits[1]==1)
-- (Hits that break the casting come 0.38 times in 0.6 seconds, below.)
assert(near(o.worth,bare*math.exp(-0.38/0.6*defence.speedSeconds)) and near(o.cost,0.18+0.02*defence.speedSeconds))
assert(find(opts,'TESTSTON').worth<o.worth and find(opts,'TESTMIRR').worth<find(opts,'TESTSTON').worth)
-- A spell slot costs input.slots of its price (combat-intent/choice.lua); the casting time does not.
i.slots=0.25
assert(near(find(defence.options(i,{}),'TESTPFMW').cost,0.18*0.25+0.02*defence.speedSeconds))
-- Held enemies threaten no one.
i=input({fighter(11,130,{held=1}),fighter(12,135,{held=1})},list)
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==3)
-- Protection from Magical Weapons up already: Stoneskin adds nothing. Skins left that hold
-- through the horizon leave little to gain from new ones.
i=input({fighter(11,130),fighter(12,135)},list)
i.frame.self.guard={roles=pfmw.roles}
opts=defence.options(i,{})
assert(find(opts,'TESTSTON')==nil)
i.frame.self.guard={stoneskins=12}
assert(find(defence.options(i,{}),'TESTSTON')==nil)
-- A spell running on the friend, or one it is guarded against, is not cast again.
i.frame.self.guard={sources={TESTPFMW=true}}
assert(find(defence.options(i,{}),'TESTPFMW')==nil)
i.frame.self.guard={recast={TESTPFMW=true}}
assert(find(defence.options(i,{}),'TESTPFMW')==nil)
-- A long cast under attack is often interrupted: worth less than a quick one. Skins up keep
-- hits from breaking the cast.
i=input({fighter(11,130),fighter(12,135)},{row('TESTPFMW',pfmw,6),row('TESTSLOW',slowPfmw,6)})
opts=defence.options(i,{})
assert(find(opts,'TESTSLOW').worth<find(opts,'TESTPFMW').worth)
local ct=threat.picture(i.frame)[1]
assert(near(defence.through(i,ct,0.6),math.exp(-0.38)) and near(defence.through(i,ct,5.4),math.exp(-3.42)))
i.frame.self.guard={stoneskins=8}
assert(defence.through(i,ct,0.6)==1 and defence.through(i,ct,5.4)==1)
-- Improved Invisibility is worth casting at fighters that cannot see it, not at fighters that
-- see invisible creatures; hidden already from those, the caster is in their full danger.
i=input({fighter(11,130),fighter(12,135)},{row('TESTIINV',improved,4)})
assert(find(defence.options(i,{}),'TESTIINV').worth>0)
i.frame.enemies[1].seeInvisible=true;i.frame.enemies[2].seeInvisible=true
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==1)
i.frame.self.state=0x400000
i.mind.acute=0.5
assert(defence.acute(i,threat.picture(i.frame)))
groups=groups+1

-- 5. The pause after a defence, like SCS's redefend timer, unless the caster is in acute danger.
local light={fighter(11,130,{attack={apr=1,thac0=10,damage=6,magical=true}})}
i=input(light,{row('TESTPFMW',pfmw,6)},{lastDefence=1000-30})
rejected={}
assert(#defence.options(i,rejected)==0 and rejected.redefend==1)
i.lastDefence=1000-120
assert(#defence.options(i,{})==1)
i=input({fighter(11,130),fighter(12,135)},{row('TESTPFMW',pfmw,6)},{lastDefence=1000-30})
assert(#defence.options(i,{})==1)
groups=groups+1

-- 6. Areas around the caster: a blessing counts for allies that fight (attack data, an enemy
-- within a round's walk), not for the casting caster; an area that cuts allies is no defence;
-- Haste's fatigue later does not count against it now.
local ally={id=2,x=140,y=100,hp=80,maxHp=80,state=0,ac=2,attack={apr=2,thac0=8,damage=12},guard={}}
local far={id=3,x=2000,y=100,hp=80,maxHp=80,state=0,ac=2,attack={apr=2,thac0=8,damage=12},guard={}}
i=input({fighter(11,200,{actee=2,held=1})},{row('TESTRECI',recitation,4)})
i.frame.allies={ally,far}
opts=defence.options(i,{})
o=find(opts,'TESTRECI')
assert(o and o.self and #o.hits==1 and o.hits[1]==2)
assert(near(o.worth,2*(0.95-0.85)*12*3/60))
i.frame.allies={far}
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==1)
rejected={}
assert(#defence.options(input({fighter(11,130)},{row('TESTBLAD',blades,6)}),rejected)==0 and rejected['harms-friends']==1)
local given=defence.defence(haste)
assert(given and given.buff and given.buff.kinds.attacks and haste.later.debuff)
i=input({fighter(11,200,{actee=2,held=1})},{row('TESTHAST',haste,3)})
i.frame.allies={ally}
o=find(defence.options(i,{}),'TESTHAST')
assert(o and o.point and o.hits[1]==2 and near(o.worth,0.5*0.85*12*3/60))
-- An ally whose spell protections keep the spell out gains nothing from it (lab batch H: a globe).
local haste3=spell('TESTHST3',3,{fx(1,{p1=6,target=2,duration=144,power=3}),fx(176,{p1=6,target=2,duration=144,power=3})},
    {target=4,projectile=99,speed=3},{[99]=area(256,192)})
local globed={id=2,x=140,y=100,hp=80,maxHp=80,state=0,ac=2,attack={apr=2,thac0=8,damage=12},guard={},
    protections={{opcode=102,p1=3}}}
i=input({fighter(11,200,{actee=2,held=1})},{row('TESTHST3',haste3,3)})
i.frame.allies={globed}
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==1)
globed.protections={}
assert(find(defence.options(i,{}),'TESTHST3').hits[1]==2)
groups=groups+1

-- 7. Single-target spells go on the caster only, unless the profile names them as exceptions
-- for allies (Christopher, 2026-10-19: most such casts on allies take too long).
local m=mage(21,300,{action=31,actee=2})
i=input({m},{row('TESTFREE',free,4)})
i.frame.allies={{id=2,x=120,y=100,hp=80,maxHp=80,state=0,ac=2,guard={}}}
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==1)
i.mind=mind.new({allySpells={TESTFREE=true}})
o=find(defence.options(i,{}),'TESTFREE')
assert(o and o.mode=='ally' and o.target==2 and near(o.worth,0.15*0.3*3/3))
assert(mind.new({allySpells={['bad name!']=true}})==nil and mind.new({caution=-1})==nil)
groups=groups+1

-- 8. The choice weighs both kinds on one scale: under two fighters Protection from Magical
-- Weapons, else even Stoneskin beats a solid attack; with no one threatening, the attack.
i=input({fighter(11,130),fighter(12,135)},list)
local pick,why=choice.decide(i)
assert(pick.resref=='TESTPFMW' and pick.kind=='defence' and why=='best')
i=input({fighter(11,130),fighter(12,135)},{row('TESTSTON',stoneskin,4),row('TESTBOLT',bolt,3)})
assert(choice.decide(i).resref=='TESTSTON')
i=input({fighter(11,130,{held=1}),fighter(12,135,{held=1})},list)
pick=choice.decide(i)
assert(pick.resref=='TESTBOLT' and pick.kind=='damage')
groups=groups+1

-- 9. A heal or removal that reaches the caster alone rides along on a defence (Barbarian Rage,
-- Potion of Haste and Potion of Free Action take earlier copies or slowing effects off the user,
-- Enrage heals it a little); one that reaches others keeps the spell out.
local rage=spell('TESTRAGE',1,{fx(221,{p1=10,p2=26,duration=30}),fx(0,{p1=4,duration=30}),fx(44,{p1=4,duration=30})},
    {speed=0})
local enrage=spell('TESTENRA',1,{fx(0,{p1=4}),fx(17,{p1=15})},{speed=0})
given=defence.defence(rage)
assert(given and given.protection and given.buff and rage.roles.removal.who.self)
given=defence.defence(enrage)
assert(given and given.protection and enrage.roles.heal.who.self)
opts=defence.options(input({fighter(11,130),fighter(12,135)},{row('TESTRAGE',rage,1),row('TESTENRA',enrage,1)}),{})
assert(find(opts,'TESTRAGE').self and find(opts,'TESTENRA').self)
local purge=spell('TESTPURG',3,{fx(221,{p1=10,p2=26,target=2,duration=0}),fx(0,{p1=4,target=2})},
    {target=4,projectile=99},{[99]=area(256,0)})
assert(select(2,defence.defence(purge))=='role-removal')
local mend=spell('TESTMEND',1,{fx(17,{p1=15,target=2}),fx(0,{p1=4,target=2})},{target=1,projectile=2})
assert(select(2,defence.defence(mend))=='role-heal')
groups=groups+1

-- 10. A creature that fights with its weapon (fighters and monsters, mind.ownWeapon) counts its own
-- weapon for its own buffs: Kai's sure hits and more damage of the weapon's kind, Whirlwind
-- Attack's doubled attacks less its own penalties, Critical Strike's sure critical hits, a THAC0
-- scaled down (Potion of Power). A caster that casts does not.
local kai=spell('TESTKAI',1,{fx(278,{p1=50,p2=1,duration=12}),fx(332,{p1=20,p2=7,duration=12}),
    fx(332,{p1=20,p2=8,duration=12}),fx(332,{p1=20,p2=9,duration=12})},{speed=0})
local whirl=spell('TESTWHRL',1,{fx(317,{p2=1,duration=12}),fx(73,{p1=-4,duration=12}),fx(54,{p1=-4,duration=12})},
    {speed=0})
local critical=spell('TESTCRIT',1,{fx(301,{p1=20,duration=6})},{speed=0})
local power=spell('TESTPOWR',1,{fx(54,{p1=80,p2=2,duration=240})},{speed=0})
i=input({fighter(11,130)},{row('TESTKAI',kai,1),row('TESTWHRL',whirl,1),row('TESTCRIT',critical,1),
    row('TESTPOWR',power,1)})
i.frame.self.weapon={damage=10,damageType=3,apr=2,thac0=10}
rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==4)
i.mind=mind.new({ownWeapon=true})
opts=defence.options(i,{})
o=find(opts,'TESTKAI')
assert(o.self and near(o.worth,(2*0.95*12-2*0.75*10)*2/60))
assert(near(find(opts,'TESTCRIT').worth,(2*10*(1+0.95*defence.critOpen)-2*0.75*10)/60))
assert(near(find(opts,'TESTPOWR').worth,(2*0.85*10-2*0.75*10)*3/60))
-- Whirlwind Attack's penalties outweigh its doubled attacks for a weapon that hits three times in
-- four, not for one that nearly always hits.
assert(find(opts,'TESTWHRL')==nil)
i.frame.self.weapon.thac0=0
assert(near(find(defence.options(i,{}),'TESTWHRL').worth,(4*0.95*6-2*0.95*10)*2/60))
-- A family's script sets it: fighters and monsters swing.
assert(mind.forFamily(mind.new(),'fighter').ownWeapon and mind.forFamily(mind.new(),'monster').ownWeapon)
assert(not mind.forFamily(mind.new(),'mage').ownWeapon and not mind.new().ownWeapon)
groups=groups+1

-- 11. Potions that protect or buff (F1c): drunk on the caster itself while uses are left, as cheap
-- as a first-level spell and never interrupted; the first ability of an item that defends counts.
-- A healing potion is care's (care.lua), and a drink waits out the redefend pause like a cast.
-- The drink's own time costs as a cast's does (care.lua's potions).
i=input(light,{},{mind=mind.new({ownWeapon=true})})
i.frame.self.weapon={damage=10,damageType=3,apr=2,thac0=10}
i.items={{resref='TESTPOWR',abilities={{effect=power,uses=1}}},
    {resref='TESTHEAL',abilities={{effect=spell('TESTHEAL',1,{fx(17,{p1=20})},{speed=0}),uses=2}}},
    {resref='TESTSKIN',abilities={{effect=bolt,uses=1},{effect=stoneskin,uses=1}}},
    {resref='TESTEMPT',abilities={{effect=armour,uses=0}}}}
rejected={}
opts=defence.options(i,rejected)
assert(#opts==2 and next(rejected)==nil)
o=find(opts,'TESTPOWR')
assert(o.use and o.self and o.mode=='self' and near(o.worth,0.1) and near(o.cost,defence.costPerLevel))
o=find(opts,'TESTSKIN')
assert(o.use and o.self and o.worth>0)
-- Stoneskin cast takes a round; drunk, the same skins are not interrupted.
local cast=find(defence.options(input({fighter(11,130),fighter(12,135)},{row('TESTSTON',stoneskin,4)}),{}),'TESTSTON')
local drunk=find(defence.options(input({fighter(11,130),fighter(12,135)},{},{items={{resref='TESTSKIN',
    abilities={{effect=stoneskin,uses=1}}}}}),{}),'TESTSKIN')
assert(drunk.worth>cast.worth and near(drunk.cost,defence.costPerLevel+mind.new().castCost*defence.speedSeconds))
i.lastDefence=1000-30
rejected={}
assert(#defence.options(i,rejected)==0 and rejected.redefend==2)
groups=groups+1

-- 12. On-hit effects (F2a): a buff whose opcode 248 lands an EFF on each creature a melee hit
-- strikes is worth what that does on the hits the weapon lands: Smite Evil's 1d6 magic on its first
-- hit alone (the hit takes the smite off), a poisoned blade's 4 poison on every hit, a stun once.
-- Fists-only ones need fists, missile ones (249) a missile weapon; Mirror Images and skins take
-- hits first; one already on the creature is not cast again.
local hitWorld={
    ['EFF:TESTSMEF']={kind='EFF',resref='TESTSMEF',effect=fx(146,{p2=1,res='TESTSMHT',timing=1,target=2,duration=0})},
    ['SPL:TESTSMHT']=sub('TESTSMHT',{fx(321,{target=1,res='TESTSMIT',timing=1,duration=0}),
        fx(12,{p2=64*65536,dice=1,sides=6,timing=1,target=2,duration=0})},1),
    ['EFF:TESTPSEF']={kind='EFF',resref='TESTPSEF',effect=fx(12,{p1=4,p2=32*65536,timing=1,target=2,duration=0})},
    ['EFF:TESTSTEF']={kind='EFF',resref='TESTSTEF',effect=fx(45,{target=2,duration=12})}}
local function onHits(resref,effects)
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=4,exclusion=0,school=0,secondary=0,level=1,
        abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=1,minLevel=1,speed=0,projectile=1,
        effects=effects}},casting={}}
    return spells.classify(r,1,function(kind,key) return hitWorld[kind..':'..tostring(key)] end,{level=10})
end
local smite=onHits('TESTSMIT',{fx(248,{duration=12,res='TESTSMEF'})})
local poison=onHits('TESTPOIS',{fx(248,{duration=30,res='TESTPSEF'})})
local stun=onHits('TESTSTUN',{fx(248,{duration=12,res='TESTSTEF'})})
local fists=onHits('TESTFSTS',{fx(248,{duration=30,p2=4,res='TESTPSEF'})})
local arrows=onHits('TESTARRW',{fx(249,{duration=30,res='TESTPSEF'})})
i=input({fighter(11,130)},{row('TESTSMIT',smite,1),row('TESTPOIS',poison,1),row('TESTSTUN',stun,1),
    row('TESTFSTS',fists,1),row('TESTARRW',arrows,1)},{mind=mind.new({ownWeapon=true})})
i.frame.self.weapon={damage=10,damageType=3,apr=2,thac0=10}
rejected={}
opts=defence.options(i,rejected)
-- Two swings hit three times in four: 3 hits in Smite Evil's two rounds, 4.5 in the poison's three.
assert(#opts==3 and rejected['no-worth']==2)
assert(near(find(opts,'TESTSMIT').worth,3.5/60) and near(find(opts,'TESTPOIS').worth,4.5*4/60))
assert(near(find(opts,'TESTSTUN').worth,(12/18)*1))
i.frame.self.weapon.fist=true
assert(near(find(defence.options(i,{}),'TESTFSTS').worth,4.5*4/60))
i.frame.self.weapon={damage=10,damageType=4,apr=2,thac0=10,ranged=true,range=400}
opts=defence.options(i,{})
assert(near(find(opts,'TESTARRW').worth,4.5*4/60) and find(opts,'TESTPOIS')==nil and find(opts,'TESTSMIT')==nil)
-- Six Mirror Images take six of the 4.5 hits: none lands; one hit is enough for the smite's.
i.frame.self.weapon={damage=10,damageType=3,apr=2,thac0=10}
i.frame.enemies[1].mirror=6
assert(find(defence.options(i,{}),'TESTPOIS')==nil)
i.frame.enemies[1].mirror=2
assert(near(find(defence.options(i,{}),'TESTPOIS').worth,2.5*4/60) and near(find(defence.options(i,{}),'TESTSMIT').worth,3.5/60))
i.frame.enemies[1].mirror=nil
i.frame.self.guard={sources={TESTPOIS=true}}
assert(find(defence.options(i,{}),'TESTPOIS')==nil)
-- Deathblow's hit slays up to level 10 only (its EFF keeps its levels apart from its dice).
hitWorld['EFF:TESTDBEF']={kind='EFF',resref='TESTDBEF',effect=fx(55,{target=2,p2=2,timing=1,duration=0,minLevel=0,maxLevel=10})}
local blow=input({fighter(11,130)},{row('TESTDBLW',onHits('TESTDBLW',{fx(248,{duration=12,res='TESTDBEF'})}),1)},
    {mind=mind.new({ownWeapon=true})})
blow.frame.self.weapon={damage=10,damageType=3,apr=2,thac0=10}
assert(find(defence.options(blow,{}),'TESTDBLW').worth>0.5)
blow.frame.enemies[1].level=11
assert(find(defence.options(blow,{}),'TESTDBLW')==nil)
-- A caster that casts does not swing.
i.frame.self.guard={}
i.mind=mind.new()
assert(#defence.options(i,{})==0)
groups=groups+1

return groups
