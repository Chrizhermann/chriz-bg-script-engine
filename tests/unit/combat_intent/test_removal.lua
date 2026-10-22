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
local function input(fields)
    local i={tick=100,family='mage',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=0,ac=8,mr=0,level=15,thac0=17,
        ids={ea=255,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11},guard={}},enemies={},allies={}},
        spells={},plan={},memory={},mind=mind.new()}
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
-- removal option.
i=input({spells={row('TESTBRCH',breach,5)}})
i.frame.allies={fighter(2,{x=150}),fighter(3,{x=310})}
i.frame.enemies={enemy(11,{wards={pfmw}}),enemy(12,{x=260,wards={ward(120,{source='TESTPFMW',power=8,level=15},{p2=1})}})}
local list=removal.options(i)
assert(#list==1 and list[1].kind=='removal' and list[1].mode=='creature' and list[1].target==11 and list[1].score>0)
-- A spell slot costs input.slots of its price (combat-intent/choice.lua); the casting time does not.
i.slots=0.5;assert(near(list[1].cost-removal.options(i)[1].cost,0.15*0.5));i.slots=nil
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

return groups
