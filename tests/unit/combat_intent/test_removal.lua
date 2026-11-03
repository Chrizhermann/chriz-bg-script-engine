-- The engine's own protection removal (combat-intent/removal.lua) on synthetic spells, wards and
-- frames classified by combat-intent/spells.lua, and its place in the choice
-- (combat-intent/choice.lua). No game data.
local removal=require('combat-intent.removal')
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
-- An active effect on its own, as adapters/eeex/sense.lua reads and classifies it (M.wards).
local function ward(op,fields,effect)
    local e=fx(op,effect)
    e.target=1
    local record={kind='SPL',resref='',name=0,flags=0,spellType=0,exclusion=0,school=0,secondary=0,level=1,casting={},
        abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=0,minLevel=1,speed=0,projectile=1,effects={e}}}}
    local w={opcode=op,p2=e.p2,source='TESTSRC',school=0,secondary=0,power=5,level=10,dispellable=true,timed=true,
        equipped=false,lasting=false,left=60,roles=spells.classify(record,1,nil,{level=1}).roles}
    for k,v in pairs(fields or {}) do w[k]=v end
    return w
end
local function enemy(id,fields)
    local e={id=id,x=200,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,skins=0,mirror=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10,attack={apr=1,thac0=10,damage=8},wards={}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
-- A fighter ally whose magical sword strikes twice a round (THAC0 5, 10 a hit).
local function fighter(id,fields)
    local a={id=id,x=180,y=100,hp=80,maxHp=80,state=0,held=0,ac=2,level=12,
        ids={ea=255,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},attack={apr=2,thac0=5,damage=10,magical=true}}
    for k,v in pairs(fields or {}) do a[k]=v end
    return a
end
local function row(resref,s,level)
    return {resref=resref,level=level,ready=1,memorized=1,usable=true,list='wizard',spell=s}
end
-- A caster of level 15. Groups 1 to 8 weigh dispels by the effects' own caster levels, as a creature
-- whose orders grant it (insight 'exact'); group 9 by what the caster believes.
local function input(fields)
    local i={tick=100,family='mage',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=0,ac=8,mr=0,level=15,thac0=17,
        ids={ea=255,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11},guard={}},enemies={},allies={}},
        spells={},plan={},memory={},mind=mind.new(),orders={insight='exact'}}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function near(a,b) return math.abs(a-b)<1e-9 end

-- Breach (secondary types 2 and 7 up to 9, power 0, ignoring magic resistance), Spell Revisions'
-- Dispel Magic in miniature (by caster level, an area at a point), Secret Word (one spell
-- protection), an unsummoning, an invisibility purge, a removal of one opcode, a cloud removal,
-- one on the caster itself.
local breach=spell('TESTBRCH',5,{fx(221,{p1=9,p2=2,resist=2}),fx(221,{p1=9,p2=7,resist=2})},{range=40})
local dispel=spell('TESTDISP',3,{fx(58,{p2=1})},{target=4},area(190,64))
local word=spell('TESTWORD',4,{fx(230,{p1=9,p2=1,resist=2})})
local unsummon=spell('TESTUNSU',5,{fx(68)})
local purge=spell('TESTPURG',3,{fx(116)},{target=4},area(256,64))
local strip=spell('TESTSTRP',5,{fx(337,{p1=-1,p2=120})})
local sweet=spell('TESTAIR',3,{fx(273)})
local own=spell('TESTOWND',3,{fx(58,{target=1,p1=10})},{target=5})
local remove=spell('TESTREMV',3,{fx(58,{p2=1})},{target=4},area(190))
local bolt=spell('TESTBOLT',3,{fx(12,{p2=8*65536,dice=6,sides=6})})

-- 1. What the engine weighs as a removal: kinds of its own that reach an enemy, from a spell it
-- can place that harms no friend. Clouds, sanctuary and spells on the caster are not.
assert(removal.removal(breach) and removal.removal(dispel) and removal.removal(word) and removal.removal(unsummon))
assert(removal.removal(purge) and removal.removal(strip) and removal.removal(remove))
assert(select(2,removal.removal(sweet))=='other-removal' and select(2,removal.removal(own))=='no-enemy')
assert(select(2,removal.removal(bolt))=='no-removal' and select(2,removal.removal(nil))=='unclassified')
local scorch=spell('TESTSCOR',3,{fx(58,{p2=1}),fx(12,{target=1,p1=5})},{target=4},area(190,64))
assert(select(2,removal.removal(scorch))=='harms-friends')
local wide=spell('TESTWIDE',3,{fx(58,{p2=1})},{target=4},{kind='PRO',resref='LINE',type=3,speed=20,flags=0,extFlags=0,
    areaFlags=64,trigger=30,radius=0,coneWidth=0})
assert(select(2,removal.removal(wide))=='unknown-shape')
-- Breach's effects ignore magic resistance, Dispel Magic's do not (resistance field bits, IESDP);
-- both deliver power 0, which spell protections by level let through.
assert(breach.roles.removal.resisted==false and dispel.roles.removal.resisted==true and breach.power==0)
assert(word.roles.removal.single.secondaries[1]==9 and word.roles.removal.secondaries==nil)
assert(strip.roles.removal.opcodes[120][-1]==true)
groups=groups+1

-- 2. A dispel's chance (opcode 58, IESDP): 49% at the effect's caster level, 5% more a level
-- above, 10% less a level below, nothing from five levels below, 99% at most.
assert(near(removal.dispelChance(10,10),0.49) and near(removal.dispelChance(12,10),0.59))
assert(near(removal.dispelChance(8,10),0.29) and removal.dispelChance(5,10)==0 and removal.dispelChance(30,1)==0.99)
assert(near(removal.dispelChance(10,nil),0.49) and removal.dispelChance(nil,10)==0)
groups=groups+1

-- 3. What each kind takes of an enemy's wards (in list order).
local skin=ward(218,{source='TESTSKIN',secondary=7,power=4},{p1=8})
local pfmw=ward(120,{source='TESTPFMW',secondary=7,power=8},{p2=1})
local pfmwArmor=ward(0,{source='TESTPFMW',secondary=0,power=8},{p1=2})
local turning=ward(200,{source='TESTTURN',secondary=1,power=7},{p1=10,p2=7})
local deflect=ward(201,{source='TESTDEFL',secondary=1,power=6},{p1=10,p2=6})
local ring=ward(201,{source='TESTRING',secondary=1,power=6,equipped=true,timed=false,dispellable=false},{p1=10,p2=6})
local held=ward(175,{source='TESTHOLD',secondary=11,power=3,level=12},{duration=30})
local undying=ward(120,{source='TESTPFMW',secondary=7,power=8,lasting=true},{p2=1})
-- Dispel: every effect a dispel can take, by its caster level against each effect's.
local chance=removal.taken(dispel.roles.removal,{skin,ring,held},15)
assert(near(chance[1],0.74) and chance[2]==nil and near(chance[3],0.64))
-- Breach: the spells with an effect of a stripped type, all their effects up to its power (the
-- PfMW's armour too), but those that last after death; Secret Word's kind leaves them.
chance=removal.taken(breach.roles.removal,{skin,pfmw,pfmwArmor,held,undying},15)
assert(chance[1]==1 and chance[2]==1 and chance[3]==1 and chance[4]==nil and chance[5]==nil)
-- Secret Word: of spell protections only the first spell's (Spell Turning), and the first item's
-- (the ring); a spell protection of power 0 marks none but goes with its spell.
local quiet=ward(201,{source='TESTDEFL',secondary=1,power=0},{p1=10,p2=6})
chance=removal.taken(word.roles.removal,{turning,deflect,ring,quiet},15)
assert(chance[1]==1 and chance[2]==nil and chance[3]==1 and chance[4]==nil)
chance=removal.taken(word.roles.removal,{quiet,deflect},15)
assert(chance[1]==1 and chance[2]==1)
-- By opcode: those effects, any parameter for -1, not those that last after death.
chance=removal.taken(strip.roles.removal,{pfmw,skin,undying},15)
assert(chance[1]==1 and chance[2]==nil and chance[3]==nil)
local _,purged=removal.taken(purge.roles.removal,{},15)
assert(purged==true)
groups=groups+1

-- 4. Worth: what the removal opens for the caster's side. Protection from Magical Weapons on an
-- enemy keeps the fighter's sword out; Breach opens it, worth a share of the enemy, its kill
-- bonus and its rounds. Nothing to take is no worth; a turning of Breach's power stops it, one of
-- another power does not; magic resistance does not stop it, as it would one that it resists.
local i=input()
i.frame.allies={fighter(2)}
local e=enemy(11,{wards={pfmw}})
i.frame.enemies={e}
local w=removal.on(i,breach,e,3)
assert(w>0.3)
local w2,why=removal.on(i,breach,enemy(11,{wards={held}}),3)
assert(w2==0 and why=='nothing')
assert(select(2,removal.on(i,breach,enemy(11,{wards={pfmw},protections={{opcode=200,p1=10,p2=5}}}),3))==nil)
local turned=spell('TESTBRC5',5,{fx(221,{p1=9,p2=7,resist=2,power=5})},{range=40})
assert(select(2,removal.on(i,turned,enemy(11,{wards={pfmw},protections={{opcode=200,p1=10,p2=5}}}),3))=='protected')
local w80=removal.on(i,breach,enemy(11,{wards={pfmw},mr=80}),3)
local resisted=spell('TESTBRCR',5,{fx(221,{p1=9,p2=2}),fx(221,{p1=9,p2=7})},{range=40})
assert(w80>0 and near(removal.on(i,resisted,enemy(11,{wards={pfmw},mr=80}),3),0.2*w80))
-- A dispel takes each ward as likely as its chance (49% at the same caster level), and lands as
-- likely as magic resistance lets it: half as often against MR 50 as one that ignores it.
local pfmw15=ward(120,{source='TESTPFMW',secondary=7,power=8,level=15},{p2=1})
local dw=removal.on(i,dispel,enemy(11,{wards={pfmw15}}),3)
assert(dw>0 and near(dw,0.49*removal.on(i,breach,enemy(11,{wards={pfmw15}}),3)))
local through=spell('TESTDISB',3,{fx(58,{p2=1,resist=3})},{target=4},area(190,64))
local dh=removal.on(i,dispel,enemy(11,{wards={pfmw15},mr=50}),3)
assert(dh>0 and near(dh,0.5*removal.on(i,through,enemy(11,{wards={pfmw15},mr=50}),3)))
-- Without the fighter, the caster's own side cannot use what opens: no worth.
i.frame.allies={}
assert(select(2,removal.on(i,breach,e,3))=='no-worth')
-- An invisibility purge opens a hidden enemy to the side as far as it cannot see it: less with a
-- fighter that sees invisible creatures, nothing when the caster sees them too.
local hidden=enemy(11,{state=0x400000})
i.frame.allies={fighter(2)}
local pw=removal.on(i,purge,hidden,3)
i.frame.allies={fighter(2,{seeInvisible=true})}
local pw2=removal.on(i,purge,hidden,3)
assert(pw2>0 and pw2<pw)
i.frame.self.seeInvisible=true
assert(select(2,removal.on(i,purge,hidden,3))=='no-worth')
i.frame.self.seeInvisible=nil
groups=groups+1

-- 5. What a removal frees an enemy of counts against it: a dispel on an enemy the caster's side
-- holds, with nothing else on it, is worth less than nothing; with Protection from Magical Weapons
-- as well, the fighter's opening outweighs it, less than the protection alone. A Slow on the enemy
-- gives its sword back once dispelled.
i.frame.allies={fighter(2)}
local hw,hwhy=removal.on(i,dispel,enemy(11,{wards={held},held=1}),3)
assert(hw<0 and hwhy=='frees')
local both=removal.on(i,dispel,enemy(11,{wards={ward(120,{source='TESTPFMW',power=8,level=15},{p2=1}),held}}),3)
assert(both<dw and both>hw)
local slow=ward(40,{source='TESTSLOW',secondary=21,power=3,level=12},{duration=30})
local sw=removal.on(i,dispel,enemy(11,{wards={slow},x=190}),3)
assert(sw<0)
groups=groups+1

-- 6. Sending a summoned enemy away is a kill: its health and the kill bonus. Others have nothing
-- an unsummoning takes. A destroyed creature counts the same.
local summoned=enemy(11,{ids={ea=2,general=1,race=1,class=2,specific=0,gender=6,alignment=0x11},hp=30})
assert(near(removal.on(i,unsummon,summoned,3),0.5+i.mind.killBonus))
assert(select(2,removal.on(i,unsummon,enemy(11),3))=='nothing')
local banish=spell('TESTBANI',7,{fx(168,{resist=2})})
assert(near(removal.on(i,banish,enemy(11),3),1+i.mind.killBonus))
groups=groups+1

-- 7. Options and the choice, with a fighter at each of two enemies. Breach at the enemy whose
-- protection keeps its fighter out, cast as a creature spell; Dispel Magic at a point near both
-- protected enemies counts both; Remove Magic, which spares no one, not with a fighter in its area. A removal worth more than the caster's
-- weapon is cast; an attack that also removes stays an attack (its removal adds to it) and is no
-- removal option. Beyond its range (R3) a breach is cast after the walk into range: one of range
-- 3 (48) at the enemy 100 away walks 0.52 seconds first, which lower the worth as a walk to a
-- melee enemy does.
i=input({spells={row('TESTBRCH',breach,5)}})
i.frame.allies={fighter(2,{x=150}),fighter(3,{x=310})}
i.frame.enemies={enemy(11,{wards={pfmw}}),enemy(12,{x=260,wards={ward(120,{source='TESTPFMW',power=8,level=15},{p2=1})}})}
local list=removal.options(i)
assert(#list==1 and list[1].kind=='removal' and list[1].mode=='creature' and list[1].target==11 and list[1].score>0)
assert(list[1].walk==nil)
-- A spell slot costs input.slots of its price (combat-intent/choice.lua); the casting time does not.
i.slots=0.5;assert(near(list[1].cost-removal.options(i)[1].cost,0.15*0.5));i.slots=nil
local short=spell('TESTBRC3',5,{fx(221,{p1=9,p2=2,resist=2}),fx(221,{p1=9,p2=7,resist=2})},{range=3})
i.spells={row('TESTBRC3',short,5)}
local walked=removal.options(i)
assert(#walked==1 and walked[1].target==11 and near(walked[1].walk,0.52) and near(walked[1].worth,list[1].worth*6/6.52))
i.spells={row('TESTDISP',dispel,3)}
i.frame.enemies[1].wards={ward(120,{source='TESTPFMW',power=8,level=15},{p2=1})}
list=removal.options(i)
assert(#list==1 and list[1].mode=='point-area' and #list[1].hits==2)
i.spells={row('TESTREMV',remove,3)}
local rejected={}
assert(#removal.options(i,rejected)==0 and rejected['removal-ally-in-area']==1)
i.spells={row('TESTBRCH',breach,5)}
i.frame.enemies[1].wards={pfmw}
i.frame.self.weapon={item='TESTSTAF',damage=3.5,damageType=2,apr=1,thac0=13,ranged=false,flags=0,enchantment=0}
local d,how=choice.decide(i)
assert(how=='best' and d.kind=='removal' and d.resref=='TESTBRCH' and d.target==11)
local orb=spell('TESTORB',1,{fx(12,{p2=8*65536,dice=2,sides=4}),fx(221,{p1=9,p2=20})})
assert(choice.attack(orb)=='damage')
i.spells={row('TESTORB',orb,1)}
assert(#removal.options(i,nil,function(s) return choice.attack(s)~=nil end)==0)
local haste=ward(16,{source='TESTHAST',secondary=20,power=3,level=12})
i.frame.enemies={enemy(11,{wards={haste},x=190})}
local plain=choice.options(input({spells={row('TESTORB',orb,1)},frame={self=i.frame.self,allies=i.frame.allies,
    enemies={enemy(11,{x=190})}}}))[1]
local stripping=choice.options(i)[1]
assert(plain.kind=='damage' and stripping.kind=='damage' and stripping.worth>plain.worth)
groups=groups+1

-- 8. Freeing (Christopher, 2026-10-29): an enemy in the charmed state is one the other side
-- charmed. A dispel that takes its charm frees it, worth what the same charm on an enemy is
-- (harm.DISABLE, 1.2 for the full 18 seconds) as likely as the charm goes (74% at level 15 against
-- 10); its other effects count neither way then, and as on any enemy as far as it stays charmed.
-- Seeing it is a tactic: one that does not weighs the dispel as on any enemy. A charm a dispel
-- cannot take, one about to end, two charms, and the options and the choice.
local charm=ward(5,{source='TESTCHRM',power=1,level=10},{p2=1})
assert(charm.roles.disable and charm.roles.disable.kinds.charm)
local thrall=enemy(11,{state=0x2000,wards={charm}})
i=input()
i.frame.allies={fighter(2)}
i.frame.enemies={thrall}
chance=removal.taken(dispel.roles.removal,{charm},15)
assert(near(chance[1],0.74))
local p,gain=removal.freed(thrall,{charm},chance,3)
assert(near(p,0.74) and near(gain,1.2))
i.tactical=true
assert(near(removal.on(i,dispel,thrall,3),0.74*1.2))
i.tactical=false
assert(select(2,removal.on(i,dispel,thrall,3))=='no-worth')
i.tactical=true
-- Half its hit points: as harm counts a disable, (0.5+0.5*0.5) of it.
assert(near(removal.on(i,dispel,enemy(11,{state=0x2000,hp=30,wards={charm}}),3),0.74*1.2*0.75))
-- A charm no dispel takes (an innate one) frees nothing; nor does a creature no longer charmed.
local fixed=ward(5,{source='TESTCHRM',power=1,level=10,dispellable=false},{p2=1})
assert(select(2,removal.on(i,dispel,enemy(11,{state=0x2000,wards={fixed}}),3))=='nothing')
assert(select(2,removal.on(i,dispel,enemy(11,{wards={charm}}),3))=='no-worth')
-- With Protection from Magical Weapons on it too: freed, the protection counts neither way; kept
-- charmed, its fall opens the thrall to the fighter as on any enemy.
local guarded=enemy(11,{state=0x2000,wards={charm,ward(120,{source='TESTPFMW',secondary=7,power=8,level=15},{p2=1})}})
i.tactical=false
local asAny=removal.on(i,dispel,guarded,3)
i.tactical=true
assert(asAny>0 and near(removal.on(i,dispel,guarded,3),0.74*1.2+0.26*asAny))
-- A charm with 9 seconds left counts half; two charms must both go.
assert(near(select(2,removal.freed(thrall,{ward(5,{left=9},{p2=1})},{0.74},3)),0.6))
p=removal.freed(thrall,{charm,ward(5,{level=15},{p2=1})},{0.74,0.49},3)
assert(near(p,0.74*0.49))
-- The options: Dispel Magic at the thrall, worth more than the caster's staff, is the choice.
i.spells={row('TESTDISP',dispel,3)}
i.frame.self.weapon={item='TESTSTAF',damage=3.5,damageType=2,apr=1,thac0=13,ranged=false,flags=0,enchantment=0}
i.tactical=nil
list=removal.options(i)
assert(#list==1 and list[1].mode=='point-area' and list[1].hits[1]==11)
d,how=choice.decide(i)
assert(how=='best' and d.kind=='removal' and d.resref=='TESTDISP')
-- A dull one never sees it: then the dispel opens nothing on the thrall.
i.mind=mind.new({tactics=0})
assert(#removal.options(i)==0)
-- A normal one draws once a decision whether it notices, and only with a thrall to free.
local noticed={mind={tactics=0.5},frame={self=i.frame.self,enemies={thrall},allies={}},spells={row('TESTDISP',dispel,3)},
    rng={nextInt=function() return 1 end}}
assert(choice.notices(noticed)==true)
noticed.frame.enemies={enemy(11,{wards={charm}})}
assert(choice.notices(noticed)==false)
groups=groups+1

-- 9. Insight (Christopher, 2026-11-03): a dispel's chance is what the caster believes of each
-- effect's caster level, by its wit, unless its orders grant it the effects' own ('exact', for a
-- special boss). A clever caster ('estimate') guesses whoever cast the protection: the enemy when it
-- casts spells, else the strongest caster on its side in view, at least what a spell of that level
-- takes; a normal one ('rough') the enemy's own level, less sure; a dull one ('none') the base
-- chance. What the group has seen dispels do narrows the guess; an area dispel is worth one try at
-- enemies no dispel has been tried at.
local orders=require('combat-intent.orders')
assert(removal.insight({mind=mind.new()})=='estimate' and removal.insight({})=='estimate')
assert(removal.insight({mind=mind.new({wit='normal'})})=='rough' and removal.insight({mind=mind.new({wit='dull'})})=='none')
assert(removal.insight({mind=mind.new({wit='dull'}),orders={insight='exact'}})=='exact')
assert(removal.insight({mind=mind.new({wit='normal'}),orders={insight='bogus'}})=='rough')
assert(orders.check({insight='exact'}) and orders.check({insight='none',guard=true}) and select(2,orders.check({insight='all'}))=='insight')
-- The level a dispel works at: the caster's, a fixed one's own, none for one that always takes.
assert(removal.dispelAt({kinds={dispel=true},dispel={mode='caster'}},15)==15)
assert(removal.dispelAt({kinds={dispel=true},dispel={mode='fixed',level=24}},15)==24)
assert(removal.dispelAt({kinds={dispel=true},dispel={mode='always'}},15)==nil and removal.dispelAt({kinds={}},15)==nil)
-- The least caster level of a spell level: a wizard's.
assert(removal.floor(nil)==1 and removal.floor(0)==1 and removal.floor(1)==1 and removal.floor(3)==5)
assert(removal.floor(6)==11 and removal.floor(9)==17)
-- Whose work a protection looks like: the enemy's own when it casts spells, else the strongest
-- living caster on its side in view, else the enemy's own.
local MAGE={ea=2,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11}
local fighterFoe=enemy(21,{level=9})
local mageFoe=enemy(22,{level=14,ids=MAGE})
assert(removal.source({enemies={fighterFoe,mageFoe}},mageFoe)==14 and removal.source({enemies={fighterFoe,mageFoe}},fighterFoe)==14)
assert(removal.source({enemies={fighterFoe}},fighterFoe)==9)
assert(removal.source({enemies={fighterFoe,enemy(23,{level=20,hp=0,ids=MAGE})}},fighterFoe)==9)
local apprentice=enemy(24,{level=8,ids=MAGE})
assert(removal.source({enemies={apprentice,mageFoe}},apprentice)==8)
assert(removal.source({enemies={apprentice,fighterFoe,mageFoe}},fighterFoe)==14)
-- The guess: Protection from Magical Weapons (an eighth-level spell) on the fighter alone is at
-- least level 15; Haste (third level) with the mage of 14 beside it is the mage's; a normal caster
-- takes the fighter's own 9, less sure and without a floor.
local pf8=ward(120,{source='TESTPFMW',secondary=7,power=8,level=5},{p2=1})
local g9,s9,f9=removal.guess('estimate',{enemies={fighterFoe}},fighterFoe,pf8)
assert(g9==15 and s9==removal.spread.estimate and f9==15)
g9,s9,f9=removal.guess('estimate',{enemies={fighterFoe,mageFoe}},fighterFoe,ward(16,{power=3}))
assert(g9==14 and f9==5)
g9,s9,f9=removal.guess('rough',{enemies={fighterFoe,mageFoe}},fighterFoe,pf8)
assert(g9==9 and s9==removal.spread.rough and f9==1 and removal.spread.rough>removal.spread.estimate)
-- A belief: unsure at the same level, a little below 49% (the chance falls faster below than it
-- rises above); far above, 99%; far below, nothing; a floor leaves out the weaker levels.
local even=removal.believed(15,15,2,1,nil,1)
assert(even<0.49 and even>0.4)
-- The levels three spreads either way, weighted as a normal curve.
local sum,total=0,0
for x=9,21 do
    local p=math.exp(-0.5*((x-15)/2)^2)
    sum,total=sum+p*removal.dispelChance(15,x),total+p
end
assert(near(even,sum/total))
assert(near(removal.believed(30,10,2,1,nil,1),0.99) and removal.believed(5,20,2,1,nil,1)==0)
assert(removal.believed(12,13,2,13,nil,1)<removal.believed(12,13,2,1,nil,1))
-- What was seen: effects that stayed lower it, effects that went raise it; two failures more than
-- one; weight 0 sees nothing, a half sees half; what cannot be (a dispel at level 5 took an effect
-- of a caster of at least 15) leaves the chance at the guess.
local base=removal.believed(12,12,2,1,nil,1)
local failed={[12]={stayed=1,went=0}}
assert(removal.believed(12,12,2,1,failed,1)<base and removal.believed(12,12,2,1,{[12]={stayed=0,went=1}},1)>base)
assert(removal.believed(12,12,2,1,{[12]={stayed=2,went=0}},1)<removal.believed(12,12,2,1,failed,1))
assert(near(removal.believed(12,12,2,1,failed,0),base))
local half=removal.believed(12,12,2,1,failed,0.5)
assert(half<base and half>removal.believed(12,12,2,1,failed,1))
assert(near(removal.believed(15,15,2,15,{[5]={stayed=0,went=1}},1),removal.dispelChance(15,15)))
-- The belief as M.taken uses it: none for 'exact' (the effects' own levels); the base chance for a
-- dull caster, whatever the levels; the guess for a clever one, in place of the effect's level
-- (5: the effect's own would go 99% of the time).
local i9=input()
i9.frame.enemies={fighterFoe}
assert(removal.belief(i9,fighterFoe)==nil)
i9.orders=nil
i9.mind=mind.new({wit='dull'})
local dull=removal.belief(i9,fighterFoe)
assert(near(dull(pf8,5),0.49) and near(dull(pf8,30),0.49))
i9.mind=mind.new()
local clever=removal.belief(i9,fighterFoe)(pf8,15)
assert(near(clever,removal.believed(15,15,removal.spread.estimate,15,nil,1)))
assert(near(removal.taken(dispel.roles.removal,{pf8},15,removal.belief(i9,fighterFoe))[1],clever))
assert(near(removal.taken(dispel.roles.removal,{pf8},15)[1],0.99))
-- A mage of 20 at the fighter's side: the protection looks like its work, and less likely to go.
i9.frame.enemies={fighterFoe,enemy(22,{level=20,ids=MAGE})}
assert(removal.belief(i9,fighterFoe)(pf8,15)<clever)
i9.mind=mind.new({wit='normal'})
assert(near(removal.belief(i9,fighterFoe)(pf8,15),removal.believed(15,9,removal.spread.rough,1,nil,0.5)))
-- An area dispel at an enemy no dispel was tried at counts at least the base chance, once.
i9.mind=mind.new()
i9.frame.enemies={fighterFoe,enemy(22,{level=25,ids=MAGE})}
local far=removal.belief(i9,fighterFoe)(pf8,15)
assert(far<0.1 and near(removal.belief(i9,fighterFoe,true)(pf8,15),0.49))
i9.dispels={[21]={tried=1}}
assert(near(removal.belief(i9,fighterFoe,true)(pf8,15),far))
-- What the group saw a dispel at 15 leave of that spell lowers it; another spell's stays.
i9.frame.enemies={fighterFoe}
i9.dispels={[21]={tried=1,sources={TESTPFMW={[15]={stayed=1,went=0}}}}}
local seen9=removal.belief(i9,fighterFoe)
assert(seen9(pf8,15)<clever and near(seen9(ward(16,{source='TESTHAST',power=8}),15),clever))
assert(near(seen9(pf8,15),removal.believed(15,15,removal.spread.estimate,15,{[15]={stayed=1,went=0}},1)))
i9.mind=mind.new({wit='normal'})
assert(near(removal.belief(i9,fighterFoe)(pf8,15),removal.believed(15,9,removal.spread.rough,1,{[15]={stayed=1,went=0}},0.5)))
i9.mind=mind.new()
-- Learning: each spell once, by the share of its dispellable effects that stayed and went; when
-- none went, what stayed counts as likely as the dispel got through; one that cannot have got
-- through, or has no level, counts only as tried; a spell cast again since stays whole; effects
-- without a spell teach nothing.
local book=removal.learn(nil,{A=2,B=1},{A=1,B=1},12,0.5)
assert(book.tried==1 and near(book.sources.A[12].stayed,0.5) and near(book.sources.A[12].went,0.5))
assert(book.sources.B[12].stayed==1 and book.sources.B[12].went==0)
book=removal.learn(book,{A=1,B=1},{A=1,B=1},12,0.5)
assert(book.tried==2 and near(book.sources.A[12].stayed,1) and near(book.sources.B[12].stayed,1.5))
book=removal.learn(book,{A=1},{A=1},12,0)
assert(book.tried==3 and near(book.sources.A[12].stayed,1))
book=removal.learn(book,{A=1},{},nil,1)
assert(book.tried==4 and near(book.sources.A[12].went,0.5))
book=removal.learn({},{C=1,['']=3},{C=2,['']=0},9,1)
assert(book.tried==1 and book.sources.C[9].stayed==1 and book.sources['']==nil)
-- Worth: the fighter's protection was cast at level 5 by a weak hand, a mage of 20 at its side. The
-- boss whose orders read levels takes it 99% of the time; a clever caster takes it for the mage's
-- work and expects little; a dull one the base chance; a normal one, by the fighter's level 10,
-- in between. An area dispel tries once at the base chance; after a try that left it, less than at
-- first.
local single=spell('TESTDIS1',3,{fx(58,{p2=1})})
local foe=enemy(11,{wards={ward(120,{source='TESTPFMW',secondary=7,power=8,level=5},{p2=1})}})
i9=input()
i9.frame.allies={fighter(2,{x=150})}
i9.frame.enemies={foe,enemy(12,{x=600,level=20,ids=MAGE})}
local boss=removal.on(i9,single,foe,3)
i9.orders=nil
local guessed=removal.on(i9,single,foe,3)
assert(boss>0 and guessed>0 and guessed<0.1*boss)
assert(near(removal.on(i9,dispel,foe,3,true),boss*0.49/0.99))
i9.dispels={[11]={tried=1,sources={TESTPFMW={[15]={stayed=1,went=0}}}}}
assert(removal.on(i9,dispel,foe,3,true)<guessed)
i9.dispels=nil
i9.mind=mind.new({wit='dull'})
assert(near(removal.on(i9,single,foe,3),boss*0.49/0.99))
i9.mind=mind.new({wit='normal'})
local rough=removal.on(i9,single,foe,3)
assert(rough>guessed and rough<boss)
-- The options: a dispel that rolls carries the level it works at and, by enemy, the chance it
-- lands (M.learn takes them); Breach none.
i9=input({spells={row('TESTDISP',dispel,3)}})
i9.frame.allies={fighter(2,{x=150})}
i9.frame.enemies={enemy(11,{wards={ward(120,{source='TESTPFMW',secondary=7,power=8,level=15},{p2=1})}})}
local opt=removal.options(i9)[1]
assert(opt and opt.at==15 and opt.lands[11]==1)
i9.spells={row('TESTBRCH',breach,5)}
opt=removal.options(i9)[1]
assert(opt and opt.at==nil and opt.lands==nil)
-- A clever caster with Dispel Magic, the weakly cast protection and the mage of 20: the area tries
-- once, as likely as the base chance; after a try that left the protection, less.
i9=input({spells={row('TESTDISP',dispel,3)}})
i9.orders=nil
i9.frame.allies={fighter(2,{x=150})}
i9.frame.enemies={foe,enemy(12,{x=600,level=20,ids=MAGE})}
local once=removal.options(i9)[1]
assert(once and once.insight=='estimate' and once.hits[1]==11)
i9.dispels={[11]={tried=1,sources={TESTPFMW={[15]={stayed=1,went=0}}}}}
local again=removal.options(i9)[1]
assert(not again or again.worth<0.2*once.worth)
groups=groups+1

return groups
