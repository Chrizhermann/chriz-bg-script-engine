-- Weapon attacks (combat-intent/weapons.lua) and the choice around them (combat-intent/choice.lua):
-- the weapon a spell conjures, reach, immunities and hits, attacks with the weapon in hand, the
-- spells that conjure one, and how a weapon attack stands against spells (no minimum worth).
-- Synthetic records classified by combat-intent/spells.lua; no game data.
local weapons=require('combat-intent.weapons')
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
local function spl(resref,level,effects,ability)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=1,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    return {kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
end
local function itm(resref,ability,fields)
    local a={attackType=1,idRequired=0,location=1,target=1,targetCount=0,range=1,launcher=0,speed=0,
        thac0=0,sides=0,school=0,dice=0,secondary=0,damageBonus=0,damageType=2,charges=0,depletion=0,
        flags=0,projectile=1,isArrow=0,isBolt=0,isBullet=0,effects={}}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='ITM',resref=resref,name=0,identifiedName=0,flags=0x40,enchantment=0,itemType=20,abilities={a},equipping={}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
-- Melf's Minute Meteors in miniature (Spell Revisions' item sets five attacks a round): ten
-- thrown meteors, each 1d4 missile and 1d4 fire, gone once thrown; a +3 blade that adds an attack
-- and lasts as long as the spell; a hand of one hit (a touch charge, no weapon attack); a weapon
-- that sets one and a half attacks.
local RECORDS={
    ['ITM:TESTMET']=itm('TESTMET',{attackType=2,range=40,dice=1,sides=4,damageType=4,thac0=2,charges=10,depletion=1,
        effects={fx(12,{dice=1,sides=4,p2=8*65536,timing=1})}},{equipping={fx(1,{p1=5,p2=1,target=1,timing=2})}}),
    ['ITM:TESTBLD']=itm('TESTBLD',{dice=1,sides=6,damageType=3},{enchantment=3,equipping={fx(1,{p1=1,p2=0,target=1,timing=2})}}),
    ['ITM:TESTHND']=itm('TESTHND',{effects={fx(12,{p1=10,p2=4*65536,timing=1}),fx(112,{target=1,res='TESTHND',timing=1})},
        charges=1,depletion=1}),
    ['ITM:TESTHALF']=itm('TESTHALF',{dice=1,sides=8},{equipping={fx(1,{p1=7,p2=1,target=1,timing=2})}})}
local function lookup(kind,key) return RECORDS[kind..':'..tostring(key)] end
local function classify(record) return spells.classify(record,1,lookup,{level=12}) end
local function conjure(resref,level,item,seconds)
    return classify(spl(resref,level,{fx(111,{target=1,p1=1,res=item,duration=seconds})},{target=5,range=1,speed=3}))
end
local mmm=conjure('TESTMMM',3,'TESTMET',60)
local blade=conjure('TESTBLAD',2,'TESTBLD',120)
local hand=conjure('TESTHAND',1,'TESTHND',60)
local half=conjure('TESTHALS',1,'TESTHALF',60)
local bolt=classify(spl('TESTBOLT',3,{fx(12,{p2=8*65536,dice=6,sides=6})}))
local dart=classify(spl('TESTDART',1,{fx(12,{p2=64*65536,dice=1,sides=4,p1=1})}))
local cure=classify(spl('TESTCURE',1,{fx(17,{p1=8})}))
local dispel=classify(spl('TESTDISP',3,{fx(58,{p1=10})}))

local function enemy(id,fields)
    local e={id=id,x=100+id*10,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,
        skins=0,mirror=0,ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10,attack={apr=0.5,thac0=20,damage=1}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function row(resref,s,level)
    return {resref=resref,level=level,ready=1,memorized=1,usable=true,list='wizard',spell=s}
end
local MACE={item='TESTMACE',damage=4.5,damageType=2,apr=1,thac0=10,ranged=false,flags=0,enchantment=0}
local function input(fields)
    local i={tick=100,family='mage',frame={self={id=1,x=100,y=100,hp=60,maxHp=60,state=0,ac=5,mr=0,thac0=12,apr=1,guard={}},
        enemies={},allies={}},spells={},plan={},memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. The weapon a spell conjures: its attacks a round (set, added or half), its THAC0 with the
-- weapon's bonus, its average damage and range, and how many rounds it lasts (its uses at its
-- attacks a round, or its duration). A touch charge and a plain attack spell conjure none.
local caster={id=1,x=100,y=100,thac0=12,apr=1}
local met=weapons.conjured(mmm,caster)
assert(met.item=='TESTMET' and met.apr==5 and met.thac0==10 and met.damage==2.5 and met.damageType==4)
assert(met.ranged and met.range==640 and met.rounds==2 and met.flags==0x40)
assert(met.strike and met.strike.roles.damage.types.fire==2.5)
local sword=weapons.conjured(blade,caster)
assert(sword.apr==2 and sword.thac0==12 and sword.damage==3.5 and not sword.ranged and sword.rounds==20 and sword.enchantment==3)
assert(weapons.conjured(half,caster).apr==1.5)
assert(weapons.conjured(hand,caster)==nil and weapons.conjured(bolt,caster)==nil and weapons.conjured(nil,caster)==nil)
groups=groups+1

-- 2. Reach, immunities and hits. Melee goes within touchReach (160), a missile within its range;
-- an unseen enemy is no target. Protection from Magical Weapons keeps the +3 blade off, an
-- immunity up to +3 too, up to +2 not. Two swings at THAC0 10 against armour class 5 hit 1.6
-- times a round; a Mirror Image takes one, two skins the rest.
local m=mind.new()
assert(weapons.reachable(caster,enemy(11,{x=250}),m,sword))
assert(select(2,weapons.reachable(caster,enemy(11,{x=300}),m,sword))=='out-of-reach')
assert(weapons.reachable(caster,enemy(11,{x=700}),m,met))
assert(select(2,weapons.reachable(caster,enemy(11,{x=800}),m,met))=='out-of-reach')
assert(select(2,weapons.reachable(caster,enemy(11,{x=150,state=targeting.STATE.invisible}),m,met))=='invisible')
assert(weapons.immuneTo(enemy(11,{protections={{opcode=120,p1=0,p2=1}}}),sword))
assert(not weapons.immuneTo(enemy(11,{protections={{opcode=120,p1=0,p2=2}}}),sword))
assert(weapons.immuneTo(enemy(11,{protections={{opcode=120,p1=3,p2=0}}}),sword))
assert(not weapons.immuneTo(enemy(11,{protections={{opcode=120,p1=2,p2=0}}}),sword))
assert(weapons.immuneTo(enemy(11,{protections=false}),sword))
assert(near(weapons.hits(2,10,{ac=5}),1.6) and near(weapons.hits(2,10,{ac=5,mirror=1}),0.6))
assert(weapons.hits(2,10,{ac=5,mirror=1,skins=2})==0)
groups=groups+1

-- 3. Attacks with the weapon in hand: a round of its hits on each enemy it reaches. A mace (4.5,
-- crushing) hits 0.8 times a round; an enemy at four hit points dies as likely as the hit lands;
-- crushing resistance halves it. Standing next to the enemy costs what its weapon deals there.
local i=input()
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=200})}
local list=choice.weaponOptions(i)
local o=list[1]
assert(#list==1 and o.kind=='weapon' and o.target==11 and o.resref=='TESTMACE' and o.mode=='creature')
assert(near(o.worth,0.8*4.5/60) and o.cost>0 and near(o.score,o.worth-o.cost) and near(o.expected[11],3.6))
i.frame.enemies={enemy(11,{x=200,hp=4})}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60+0.5*0.8))
-- A minimum keeps that enemy alive: the hits take what it has above it and kill no one; at its
-- minimum there is nothing to take.
i.frame.enemies={enemy(11,{x=200,hp=4,minHp=1})}
o=choice.weaponOptions(i)[1]
assert(near(o.worth,3/60) and near(o.expected[11],3))
i.frame.enemies={enemy(11,{x=200,hp=1,minHp=1})}
assert(#choice.weaponOptions(i)==0)
i.frame.enemies={enemy(11,{x=200,resist={crushing=50}})}
assert(near(choice.weaponOptions(i)[1].worth,0.8*2.25/60))
-- Out of reach, immune, behind a Mirror Image: no attack, and why.
local rejected={}
i.frame.enemies={enemy(11,{x=300}),enemy(12,{x=200,protections={{opcode=120,p1=0,p2=2}}}),enemy(13,{x=210,mirror=1})}
assert(#choice.weaponOptions(i,rejected)==0)
assert(rejected['out-of-reach']==1 and rejected['weapon-immunity']==1 and rejected.absorbed==1)
-- A sling reaches its range and costs nothing to use from afar.
i.frame.self.weapon={item='TESTSLNG',damage=3.5,damageType=2,apr=1,thac0=10,ranged=true,range=400,flags=0,enchantment=0}
i.frame.enemies={enemy(11,{x=450,attack={apr=2,thac0=5,damage=10}})}
o=choice.weaponOptions(i)[1]
assert(o and o.target==11 and o.cost==0 and near(o.worth,0.8*3.5/60))
-- Not with a touch charge in hand, in the caster's own Time Stop or under Improved Alacrity.
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=200})}
i.frame.self.charge={item='TESTHND',touch=true}
assert(#choice.weaponOptions(i)==0)
i.frame.self.charge=nil
i.timeStop={caster=1,left=10}
assert(#choice.weaponOptions(i)==0)
i.timeStop=nil
i.frame.self.alacrity=true
assert(#choice.weaponOptions(i)==0)
i.frame.self.alacrity=nil
groups=groups+1

-- 4. Against spells: a weapon attack needs no minimum worth. With nothing ready, or nothing worth
-- minValue, the caster attacks instead of leaving the round to SCS; a spell worth more is cast;
-- a weapon attack worth more than the best spell is taken (magic resistance halves the bolt,
-- not the mace). Switched off, the round goes back to SCS.
local d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon' and d.target==11)
i.spells={row('TESTDART',dart,1)}
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon')
i.spells={row('TESTBOLT',bolt,3),row('TESTDART',dart,1)}
d,why=choice.decide(i)
assert(why=='best' and d.resref=='TESTBOLT')
i.frame.enemies={enemy(11,{x=200,hp=4,mr=50})}
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon' and d.target==11)
i.frame.enemies={enemy(11,{x=200})}
-- Healing (D3a), summons (D3c) and protection removal (D3d) are the engine's own and keep no round
-- for SCS: eight hit points are worth less than a round of the mace, and a dispel finds nothing to
-- take on the enemy.
i.spells={row('TESTCURE',cure,1)}
i.frame.self.hp=25
assert(choice.decide(i).kind=='weapon')
i.frame.self.hp=60
i.spells={row('TESTDISP',dispel,3),row('TESTDART',dart,1)}
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon')
i.mind=mind.new({weapons=false})
i.spells={row('TESTDART',dart,1)}
assert(select(2,choice.decide(i))=='nothing-good')
i.spells={}
assert(select(2,choice.decide(i))=='no-option')
groups=groups+1

-- 5. A spell that conjures a weapon: cast on the caster, worth the hits of the rounds it lasts
-- within the horizon at the enemy where they are worth most. The meteors: four hits a round of
-- 2.5 missile and 2.5 fire for two rounds, 40 of 60 hit points, short of a kill. Not with the
-- magic weapon slot taken, nor out of range.
i=input({spells={row('TESTMMM',mmm,3)}})
i.frame.enemies={enemy(11,{x=400})}
o=choice.options(i)[1]
assert(o.kind=='arm' and o.self and o.mode=='self' and o.target==11 and o.resref=='TESTMMM' and o.item=='TESTMET')
assert(near(o.worth,40/60) and near(o.cost,0.09) and near(o.expected[11],40))
-- A spell slot costs input.slots of its price (combat-intent/choice.lua).
i.slots=0.5;assert(near(choice.options(i)[1].cost,0.045));i.slots=nil
d,why=choice.decide(i)
assert(why=='best' and d.kind=='arm')
-- A melee blade costs the hit points lost standing next to its enemy, the rounds it fights.
local j=input({spells={row('TESTBLAD',blade,2)}})
j.frame.enemies={enemy(11,{x=200})}
local b=choice.options(j)[1]
assert(b.kind=='arm' and b.target==11 and b.cost>0.06)
i.frame.self.magicItem=true
assert(#choice.options(i)==0)
i.frame.self.magicItem=nil
rejected={}
i.frame.enemies={enemy(11,{x=800})}
assert(#choice.options(i,rejected)==0 and rejected['out-of-reach']==1)
i.frame.enemies={enemy(11,{x=400})}
i.mind=mind.new({weapons=false})
assert(#choice.options(i)==0)
groups=groups+1

-- 6. The profile: weapons is a switch; keepScsSpells is gone (D3d: no spell keeps a round for SCS).
assert(mind.new().weapons==true and mind.new({weapons=false}).weapons==false)
assert(select(2,mind.new({weapons=1}))=='weapons')
assert(mind.new().keepScsSpells==nil and select(2,mind.new({keepScsSpells=true}))=='keepScsSpells')
groups=groups+1

-- 7. No spell keeps the round for SCS any more (D3, 2026-10-20): with Vocalize, a cure, a dispel
-- and a raise ready and nothing for them to do, the caster attacks (SCS's scripts never raise).
local vocal=classify(spl('TESTVOC',2,{fx(48,{target=1})},{target=5}))
local free=classify(spl('TESTFREE',3,{fx(162)}))
local raise=classify(spl('TESTRAIS',5,{fx(32)},{target=3}))
i=input({spells={row('TESTVOC',vocal,2),row('TESTFREE',free,3),row('TESTDISP',dispel,3),row('TESTRAIS',raise,5)}})
i.frame.self.weapon=MACE
i.frame.allies={{id=2,x=120,y=100,hp=60,maxHp=60,state=0,held=0,drained=0}}
i.frame.enemies={enemy(11,{x=200})}
i.frame.fallen={{id=3,x=130,y=100,state=0x800,gender=1}}
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon')
groups=groups+1

return groups
