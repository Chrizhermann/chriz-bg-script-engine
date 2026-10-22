-- The engine's own summons (combat-intent/summons.lua, D3c) on synthetic spells classified by
-- combat-intent/spells.lua, synthetic creature records and plain frames. No game data.
local summons=require('combat-intent.summons')
local weapons=require('combat-intent.weapons')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spell(resref,level,effects,ability)
    local a={form=1,flags=0,location=2,target=4,targetCount=0,range=30,minLevel=1,speed=0,projectile=1,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    return spells.classify(r,1,function() end,{level=10})
end
local function itm(resref,ability,fields)
    local a={attackType=1,idRequired=0,location=1,target=1,targetCount=0,range=1,launcher=0,speed=0,
        thac0=0,sides=0,school=0,dice=0,secondary=0,damageBonus=0,damageType=2,charges=0,depletion=0,
        flags=0,projectile=1,isArrow=0,isBolt=0,isBullet=0,effects={}}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='ITM',resref=resref,name=0,identifiedName=0,flags=0,enchantment=0,itemType=20,abilities={a},equipping={}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function cre(fields)
    local c={kind='CRE',resref='TESTMON',hp=40,maxHp=40,ac=5,thac0=12,apr=2,level=6,strength=10,strengthExtra=0,
        ea=255,general=4,race=1,class=2,specific=0,gender=6,alignment=0x33,items={},slots={},opcodes={326}}
    for k,v in pairs(fields or {}) do c[k]=v end
    return c
end
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. A creature as a fighter. Its weapon's dice and bonus, what the weapon's own damage effects
-- add (normal mode, on the creature hit, times their chance) and strength for melee; THAC0 less
-- the weapon's and strength's bonuses; half attacks decoded; magical by enchantment or flag.
assert(select(1,summons.strength(18,0))==1 and select(2,summons.strength(18,0))==2)
assert(select(1,summons.strength(18,50))==1 and select(2,summons.strength(18,50))==3)
assert(select(1,summons.strength(18,100))==3 and select(2,summons.strength(18,100))==6)
assert(select(1,summons.strength(19,0))==3 and select(2,summons.strength(19,0))==7)
assert(select(1,summons.strength(25,0))==7 and select(2,summons.strength(10,0))==0)
local acid=fx(12,{p2=1*65536,dice=2,sides=4})
local claw=itm('TESTCLAW',{dice=1,sides=6,damageBonus=1,thac0=2,effects={acid,fx(12,{p1=10,p2=1}),fx(12,{p1=10,target=1}),
    fx(12,{p1=10,prob1=49}),fx(55)}})
assert(near(weapons.onHit(claw.abilities[1]),5+10*50/101) and weapons.onHit(nil)==0)
local p=summons.profile(cre({strength=18,strengthExtra=76,apr=7}),claw)
assert(p.fighter and p.maxHp==40 and p.ac==5 and p.apr==1.5 and p.thac0==12-2-2 and not p.magical and not p.ranged)
assert(near(p.damage,3.5+1+5+10*50/101+4) and p.gender==6 and p.ea==255)
assert(summons.profile(cre(),itm('TESTPLUS',{dice=1,sides=4},{enchantment=1})).magical)
assert(summons.profile(cre(),itm('TESTFLAG',{dice=1,sides=4},{flags=0x40})).magical)
-- A bow shoots the ammunition in the quiver; strength does not count; without ammunition it does
-- not fight.
local bow=itm('TESTBOW',{attackType=4,thac0=1},{enchantment=1})
local arrow=itm('TESTARRW',{attackType=2,dice=1,sides=6,thac0=1,effects={fx(12,{p1=2})}})
p=summons.profile(cre({strength=19}),bow,arrow)
assert(p.fighter and p.ranged and p.thac0==12-2 and near(p.damage,3.5+2) and p.magical)
assert(not summons.profile(cre(),bow).fighter)
-- No fighters: no weapon, one hit point, or its own effects hide its avatar or selection circle
-- (SCS's markers, a kit's helper). Invisibility (opcode 20) alone does not.
assert(not summons.profile(cre()).fighter)
assert(not summons.profile(cre({maxHp=1}),claw).fighter)
assert(not summons.profile(cre({opcodes={326,271}}),claw).fighter)
assert(not summons.profile(cre({opcodes={287,20}}),claw).fighter)
assert(summons.profile(cre({opcodes={20}}),claw).fighter)
assert(summons.profile(nil)==nil and summons.profile({maxHp='x'})==nil)
-- A creature of a monster table: twice the spell's level in hit dice.
local g=summons.generic(4)
assert(g.fighter and g.maxHp==48 and g.thac0==12 and g.apr==1 and g.damage==8.5 and g.gender==6)
groups=groups+1

-- 2. Which summoning spells the engine casts: creatures or monster tables on the caster's side,
-- landing on the caster (the creature appears where the spell is aimed). Not an image or a change
-- of shape alone, a summons against the caster, one cast at another creature, nor one the
-- classifier could not read in full. Mode 2 takes the side from the creature's file.
local horde=spell('TESTHORD',3,{fx(67,{res='TESTMON',target=1}),fx(67,{res='TESTMON',target=1})})
local role,why=summons.summon(horde)
assert(role and role.creatures.TESTMON==2 and role.who.self and not role.fromFile)
assert(select(2,summons.summon(nil))=='unclassified' and select(2,summons.summon(spell('TESTBOLT',3,{fx(12,{dice=6,sides=6})})))=='no-summon')
assert(select(2,summons.summon(spell('TESTIMAG',6,{fx(236,{target=1})},{target=5})))=='image')
assert(select(2,summons.summon(spell('TESTWOLF',3,{fx(151,{res='WOLF',p2=1,target=1})},{target=5})))=='transform')
assert(select(2,summons.summon(spell('TESTHOST',3,{fx(67,{res='TESTMON',p2=5,target=1})})))=='hostile')
assert(select(2,summons.summon(spell('TESTAIMD',3,{fx(67,{res='TESTMON'})},{target=1})))=='aimed')
assert(select(2,summons.summon(spell('TESTPART',3,{fx(67,{res='TESTMON',target=1}),fx(146,{res='NOSUCH',target=1})})))=='partial')
assert(summons.summon(spell('TESTWISH',7,{fx(67,{res='TESTGENI',p2=2,target=1})},{target=5})).fromFile.TESTGENI)
assert(summons.summon(spell('TESTMONS',4,{fx(127,{p1=2,p2=1,target=1})})).kinds.monsters)
assert(select(2,summons.summon(spell('TESTEVIL',4,{fx(127,{p1=2,p2=6,target=1})})))=='hostile')
groups=groups+1

-- 3. One summoned creature's fight over r rounds: the share of an enemy its hits take (its hits
-- against the enemies' mean armour class, of their mean hit points), and the share of a friend
-- its body spares by drawing its part of the enemies' blows, up to its own hit points. Disabled
-- enemies strike no one; a creature that does not fight is worth nothing.
local function enemy(id,fields)
    local e={id=id,x=300,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10,attack={apr=1,thac0=10,damage=10}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function frame(fields)
    local f={self={id=1,x=100,y=100,hp=50,maxHp=50,state=0,held=0,ac=5,ea=255,level=12,ids={class=1,gender=1},
        guard={roles={},stoneskins=0,mirror=0,sources={},recast={},conditions={},poison=0}},enemies={enemy(11)},allies={}}
    for k,v in pairs(fields or {}) do f[k]=v end
    return f
end
local monster={maxHp=40,ac=5,thac0=10,apr=2,damage=6,fighter=true,gender=6,ea=255}
-- Hits 0.8 a swing: offense 2*2*0.8*6/60; the enemy's 8 a round, half of them, for 2 rounds.
assert(near(summons.fight(monster,frame(),2,1/2),0.32+8/50))
assert(near(summons.fight(monster,frame(),2,1),0.32+16/50))
assert(near(summons.fight({maxHp=5,ac=5,thac0=10,apr=2,damage=6,fighter=true},frame(),2,1),0.32+5/50))
assert(near(summons.fight(monster,frame({enemies={enemy(11,{held=1})}}),2,1/2),0.32))
assert(summons.fight({maxHp=40,fighter=false},frame(),2,1)==0 and summons.fight(monster,frame({enemies={}}),2,1)==0)
groups=groups+1

-- 4. Options. Two of them in three rounds (no casting time): each 0.48 of the enemy, the first
-- one body among two drawing half the enemy's blows, the second a third; cost three spell levels.
-- Cast at the enemy's spot.
local function row(resref,s,level,fields)
    local r={resref=resref,level=level,ready=1,memorized=1,usable=true,list='wizard',spell=s}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function input(fields)
    local i={tick=100,family='mage',frame=frame(),spells={row('TESTHORD',horde,3)},plan={},memory={},mind=mind.new(),
        creatures={TESTMON=monster}}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local i=input()
local rejected={}
local list=summons.options(i,rejected)
local o=list[1]
assert(#list==1 and o.kind=='summon' and o.mode=='point' and o.point.x==300 and o.point.y==100 and o.count==2)
assert(near(o.worth,0.48+12/50+0.48+8/50) and near(o.cost,0.09) and near(o.score,o.worth-o.cost))
assert(o.creatures[1]=='TESTMON' and #o.hits==0 and o.resref=='TESTHORD' and next(rejected)==nil)
-- A spell slot costs input.slots of its price (combat-intent/choice.lua).
i.slots=0.5;assert(near(summons.options(i)[1].cost,0.045));i.slots=nil
-- Casting time: fewer rounds before the horizon, and harm while casting can break it.
i.spells={row('TESTHORD',spell('TESTHORD',3,{fx(67,{res='TESTMON',target=1}),fx(67,{res='TESTMON',target=1})},{speed=9}),3)}
i.frame.enemies[1].x=150
o=summons.options(i)[1]
assert(o.worth<(0.48+12/50+0.48+8/50)*(18-5.4)/18 and near(o.cost,0.09+0.02*5.4))
groups=groups+1

-- 5. Where it goes: the group's focus in range, else the nearest enemy in range, else toward the
-- nearest enemy at the edge of range; on the caster for a spell on itself; at an enemy for a spell
-- at a creature, none out of range.
i=input()
i.frame.enemies={enemy(11,{x=400}),enemy(12,{x=200})}
assert(summons.options(i)[1].point.x==200)
i.plan={focus=11}
assert(summons.options(i)[1].point.x==400)
i.plan={focus=13}
i.frame.enemies={enemy(11,{x=1100})}
o=summons.options(i)[1]
assert(o.point.x==100+480 and o.point.y==100)
i.spells={row('TESTSELF',spell('TESTSELF',7,{fx(67,{res='TESTMON',target=1})},{target=5,range=1}),7)}
o=summons.options(i)[1]
assert(o.self and o.mode=='self' and not o.point)
i.spells={row('TESTGATE',spell('TESTGATE',7,{fx(67,{res='TESTMON',target=1})},{target=1,range=10}),7)}
rejected={}
assert(#summons.options(i,rejected)==0 and rejected['summon-out-of-reach']==1)
i.frame.enemies={enemy(11,{x=200})}
o=summons.options(i)[1]
assert(o.target==11 and o.mode=='creature')
groups=groups+1

-- 6. Who joins: only fighters on the caster's side. A summons that takes its side from its file
-- (Wish's genie, neutral) brings no one; markers and helpers are no summons and count no reason;
-- a creature that cannot be read counts as unknown. Monster tables count as creatures of twice the
-- spell's level. At the cap of summoned allies in view no more summoned creatures come; a summoned
-- demon does not count for it.
i=input({spells={row('TESTWISH',spell('TESTWISH',7,{fx(67,{res='TESTGENI',p2=2,target=1})},{target=5}),7)},
    creatures={TESTGENI={maxHp=200,ac=3,thac0=-3,apr=1,damage=18,fighter=true,gender=4,ea=128}}})
rejected={}
assert(#summons.options(i,rejected)==0 and rejected['summon-other-side']==1)
i.creatures.TESTGENI.ea=255
assert(#summons.options(i)==1)
i=input({creatures={TESTMON={maxHp=1,fighter=false,gender=1,ea=255}}})
rejected={}
assert(#summons.options(i,rejected)==0 and next(rejected)==nil)
i.creatures={}
assert(#summons.options(i,rejected)==0 and rejected['summon-unknown-creature']==1)
i=input({spells={row('TESTMONS',spell('TESTMONS',4,{fx(127,{p1=2,p2=1,target=1})}),4)}})
o=summons.options(i)[1]
assert(o and o.count==2 and #o.creatures==0)
i=input()
for n=1,5 do i.frame.allies[n]={id=20+n,x=100,y=120,hp=10,maxHp=10,state=0,ids={gender=6}} end
rejected={}
assert(#summons.options(i,rejected)==0 and rejected['summon-cap']==1)
i.mind=mind.new({summonCap=6})
assert(#summons.options(i)==1)
i.mind=mind.new()
i.creatures={TESTMON={maxHp=40,ac=5,thac0=10,apr=2,damage=6,fighter=true,gender=9,ea=255}}
assert(#summons.options(i)==1)
i.frame.allies[1].hp=0
i.frame.allies[1].state=0x800
i.creatures={TESTMON=monster}
assert(#summons.options(i)==1)
assert(mind.new().summonCap==5 and select(2,mind.new({summonCap=-1}))=='summonCap')
-- Spells that are not ready or usable bring nothing; nor do images, changes of shape or hostile
-- summons, which are counted.
i=input()
i.spells[1].ready=0
assert(#summons.options(i)==0)
i.spells={row('TESTIMAG',spell('TESTIMAG',6,{fx(236,{target=1})},{target=5}),6),
    row('TESTHOST',spell('TESTHOST',3,{fx(67,{res='TESTMON',p2=5,target=1})}),3)}
rejected={}
assert(#summons.options(i,rejected)==0 and rejected['summon-image']==1 and rejected['summon-hostile']==1)
groups=groups+1

-- 7. In the choice: a summons competes with attacks and defences; without the creatures it brings
-- the caster attacks (a weak enemy in reach of the caster's mace).
i=input()
i.frame.enemies[1].x=200
i.frame.enemies[1].attack={apr=0.5,thac0=20,damage=1}
i.frame.self.weapon={item='TESTMACE',damage=4.5,damageType=2,apr=1,thac0=10,ranged=false,flags=0,enchantment=0}
local d,how=choice.decide(i)
assert(how=='best' and d.kind=='summon' and d.resref=='TESTHORD')
i.creatures={}
d,how=choice.decide(i)
assert(d.kind=='weapon' and how=='weapon')
groups=groups+1

return groups
