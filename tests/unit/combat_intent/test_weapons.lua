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
assert(sword.itemType==20)
assert(weapons.conjured(half,caster).apr==1.5)
assert(weapons.conjured(hand,caster)==nil and weapons.conjured(bolt,caster)==nil and weapons.conjured(nil,caster)==nil)
groups=groups+1

-- 2. Reach, immunities and hits. Melee goes to any enemy the caster sees (SCS's mages walk there
-- between casts, E8 v5), a touch strike's reach when one is given (160), a missile within its
-- range; an unseen enemy is no target. Protection from Magical Weapons keeps the +3 blade off, an
-- immunity up to +3 too, up to +2 not. Two swings at THAC0 10 against armour class 5 hit 1.6
-- times a round; a Mirror Image takes one, two skins the rest.
local m=mind.new()
assert(weapons.reachable(caster,enemy(11,{x=250}),m,sword) and weapons.reachable(caster,enemy(11,{x=900}),m,sword))
assert(weapons.reachable(caster,enemy(11,{x=250}),m,nil,nil,160))
assert(select(2,weapons.reachable(caster,enemy(11,{x=300}),m,nil,nil,160))=='out-of-reach')
assert(select(2,weapons.reachable({id=1,x=100,y=100,rooted=true},enemy(11,{x=300}),m,sword))=='out-of-reach')
assert(weapons.reachable(caster,enemy(11,{x=700}),m,met))
assert(select(2,weapons.reachable(caster,enemy(11,{x=800}),m,met))=='out-of-reach')
assert(select(2,weapons.reachable(caster,enemy(11,{x=150,state=targeting.STATE.invisible}),m,met))=='invisible')
-- An enemy the caster could not get to on foot (others block every way: caster.unreachable) is out
-- of melee reach for now; a missile still reaches it, a leap (a teleport) goes there anyway.
local boxed={id=1,x=100,y=100,thac0=12,apr=1,unreachable={[11]=true}}
assert(select(2,weapons.reachable(boxed,enemy(11,{x=250}),m,sword))=='unreachable')
assert(weapons.reachable(boxed,enemy(11,{x=250}),m,met) and weapons.reachable(boxed,enemy(11,{x=250}),m,sword,true))
assert(weapons.reachable(boxed,enemy(12,{x=250}),m,sword))
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
-- crushing resistance halves it. Standing next to the enemy costs what its weapon deals there. The
-- enemy stands 100 away, 36 beyond a weapon's reach: the walk of 0.36 seconds comes first, and the
-- round of hits counts as the round and the walk take it.
local i=input()
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=200})}
local list=choice.weaponOptions(i)
local o=list[1]
local pace=6/(6+0.36)
assert(#list==1 and o.kind=='weapon' and o.target==11 and o.resref=='TESTMACE' and o.mode=='creature')
assert(near(o.worth,0.8*4.5/60*pace) and o.cost>0 and near(o.score,o.worth-o.cost) and near(o.expected[11],3.6))
assert(near(o.walk,0.36))
-- The weapon's own range goes with a melee attack (how far it strikes, swing), not with a shot.
do
    assert(o.swing==nil)
    local long={}
    for k,v in pairs(MACE) do long[k]=v end
    long.swing=2
    i.frame.self.weapon=long
    assert(choice.weaponOptions(i)[1].swing==2)
    long.ranged,long.range=true,1000
    assert(choice.weaponOptions(i)[1].swing==nil)
    i.frame.self.weapon=MACE
end
i.frame.enemies={enemy(11,{x=200,hp=4})}
assert(near(choice.weaponOptions(i)[1].worth,(3.6/60+0.5*0.8)*pace))
-- A minimum keeps that enemy alive: the hits take what it has above it and kill no one; at its
-- minimum there is nothing to take.
i.frame.enemies={enemy(11,{x=200,hp=4,minHp=1})}
o=choice.weaponOptions(i)[1]
assert(near(o.worth,3/60*pace) and near(o.expected[11],3))
i.frame.enemies={enemy(11,{x=200,hp=1,minHp=1})}
assert(#choice.weaponOptions(i)==0)
i.frame.enemies={enemy(11,{x=200,resist={crushing=50}})}
assert(near(choice.weaponOptions(i)[1].worth,0.8*2.25/60*pace))
-- Immune: no attack, and why; one further off is worth its walk (1.36 seconds). Behind a Mirror
-- Image the round's 0.8 hits all go to the image and deal nothing, yet they bring the kill closer:
-- it takes 14 hits of 4.5 and one for the image, so the round counts 14/15 of its 3.6 (after a
-- walk of 0.46 seconds). A webbed caster reaches none of them: out of reach.
local rejected={}
i.frame.enemies={enemy(11,{x=300}),enemy(12,{x=200,protections={{opcode=120,p1=0,p2=2}}}),enemy(13,{x=210,mirror=1})}
list=choice.weaponOptions(i,rejected)
assert(#list==2 and list[1].target==13 and near(list[1].worth,3.6/60*14/15*6/6.46) and list[1].expected[13]==0)
assert(list[2].target==11 and near(list[2].worth,3.6/60*6/7.36) and near(list[2].walk,1.36))
assert(rejected['out-of-reach']==nil and rejected['weapon-immunity']==1 and rejected.absorbed==nil)
rejected={}
i.frame.self.rooted=true
assert(#choice.weaponOptions(i,rejected)==0 and rejected['out-of-reach']==3 and rejected['weapon-immunity']==nil)
i.frame.self.rooted=nil
-- One the caster found it cannot get to (lab batch E8 v3: boxed in by others) is no melee target;
-- the next one is.
rejected={}
i.frame.self.unreachable={[13]=true}
i.frame.enemies={enemy(13,{x=210}),enemy(14,{x=250})}
list=choice.weaponOptions(i,rejected)
assert(#list==1 and list[1].target==14 and rejected.unreachable==1)
i.frame.self.unreachable=nil
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
-- minValue, the caster attacks; a spell worth more is cast; a weapon attack worth more than the
-- best spell is taken (magic resistance halves the bolt, not the mace). Switched off, the caster
-- casts the dart that is worth something below the minimum, and with nothing ready it waits.
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
d,why=choice.decide(i)
assert(why=='weak' and d.resref=='TESTDART')
i.spells={}
d,why=choice.decide(i)
assert(why=='no-option' and d.kind=='wait')
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
-- Three skins take three of the eight hits, once: five land (25 hit points), and the eight are 8 of
-- the 15 hits the kill takes (12 of 5 and the three skins).
i.frame.enemies={enemy(11,{x=400,skins=3})}
o=choice.options(i)[1]
assert(o.kind=='arm' and near(o.worth,40/60*12/15) and near(o.expected[11],25))
i.frame.enemies={enemy(11,{x=400})}
-- A spell slot costs input.slots of its price (combat-intent/choice.lua).
i.slots=0.5;assert(near(choice.options(i)[1].cost,0.045));i.slots=nil
d,why=choice.decide(i)
assert(why=='best' and d.kind=='arm')
-- A melee blade costs the hit points lost standing next to its enemy, the rounds it fights.
local j=input({spells={row('TESTBLAD',blade,2)}})
j.frame.enemies={enemy(11,{x=200})}
local b=choice.options(j)[1]
assert(b.kind=='arm' and b.target==11 and b.cost>0.06)
-- The walk to its enemy takes its share of the three rounds it counts for (E8 v5: casters walk to
-- any enemy): 600 away, 5.36 seconds of 18; the meteors above walk nowhere.
j.frame.enemies={enemy(11,{x=164})}
local b0=choice.options(j)[1]
j.frame.enemies={enemy(11,{x=700})}
assert(near(choice.options(j)[1].worth,b0.worth*18/(18+5.36)))
-- Readiness (combat-intent/choice.lua): no weapon conjured for a foe out of play.
local away=input({spells={row('TESTMMM',mmm,3)},returning={enemy(11,{x=400,away='maze',back=5})}})
assert(#choice.options(choice.readied(away))==0)
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

-- 8. Chasing (F1d). Every creature walks to any enemy it sees for its melee weapon (a caster too,
-- as SCS's mages do between casts, E8 v5), one that cannot walk (webbed or entangled) no further
-- than a weapon reaches; a touch strike goes as far only for a creature that chases (fighters and
-- monsters), a caster's no further than touchReach (combat-intent/touch.lua). The walk lowers the
-- worth: an enemy 664 away takes six seconds at a fighter's hundred a second, so a round of hits
-- there counts half; twice as fast, two thirds. A wounded one far off is still worth the walk.
assert(near(weapons.walk({x=100,y=100},{x=364,y=100}),2) and weapons.walk({x=100,y=100},{x=150,y=100})==0)
assert(near(weapons.walk({x=100,y=100,speed=200},{x=364,y=100}),1))
assert(weapons.paced(0)==1 and near(weapons.paced(3),2/3) and weapons.paced(nil)==1)
-- The same walk to any reach (R3: a spell's range); within it none, rooted or nowhere to go nil.
assert(near(weapons.approach({x=100,y=100},{x=700,y=100},480),1.2) and weapons.approach({x=100,y=100},{x=500,y=100},480)==0)
assert(weapons.approach({x=100,y=100,rooted=true},{x=500,y=100},480)==0)
assert(weapons.approach({x=100,y=100,rooted=true},{x=700,y=100},480)==nil and weapons.approach({x=100,y=100},{},480)==nil)
assert(mind.forFamily(mind.new(),'fighter').chase and mind.forFamily(mind.new(),'monster').chase)
assert(not mind.new().chase and not mind.forFamily(mind.new(),'mage').chase)
assert(select(2,mind.new({chase=1}))=='chase')
assert(weapons.reach(mind.new({chase=true}))==math.huge and weapons.reach(mind.new())==math.huge)
assert(weapons.reach(mind.new({chase=true}),{rooted=true})==64 and weapons.reach(mind.new(),{rooted=true})==64)
do
    local touch=require('combat-intent.touch')
    assert(touch.reach(mind.new({chase=true}))==math.huge and touch.reach(mind.new())==160)
    assert(touch.reach(mind.new({chase=true}),{rooted=true})==64)
    -- E8 v5: Tarnesh, out of attack spells, stood eighty seconds beside the hero he had put to
    -- sleep 195 away, his staff out of a caster's reach. A mage walks to a sleeper now, at no cost
    -- (a sleeper strikes nobody); an awake fighter as far off costs it what it would lose there.
    local mage=input()
    mage.frame.self.weapon=MACE
    mage.frame.enemies={enemy(11,{x=600,state=targeting.STATE.sleeping,attack={apr=1,thac0=10,damage=8}})}
    local o=choice.weaponOptions(mage)[1]
    assert(o and o.target==11 and near(o.walk,(500-64)/100) and o.cost==0 and o.score>0)
    mage.frame.enemies[1].state=0
    o=choice.weaponOptions(mage)[1]
    assert(o and o.target==11 and o.cost>0 and o.score<o.worth)
end
i=input({mind=mind.forFamily(mind.new(),'fighter')})
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=164}),enemy(12,{x=764})}
list=choice.weaponOptions(i)
assert(#list==2 and list[1].target==11 and list[1].walk==nil and near(list[1].worth,0.8*4.5/60))
assert(list[2].target==12 and near(list[2].walk,6) and near(list[2].worth,0.8*4.5/60/2))
i.frame.self.speed=200
o=choice.weaponOptions(i)[2]
assert(o.target==12 and near(o.walk,3) and near(o.worth,0.8*4.5/60*2/3))
i.frame.self.speed=nil
i.frame.enemies={enemy(11,{x=164}),enemy(12,{x=764,hp=4})}
o=choice.weaponOptions(i)[1]
assert(o.target==12 and near(o.worth,(3.6/60+0.5*0.8)/2))
local d8,why8=choice.decide(i)
assert(why8=='weapon' and d8.target==12 and near(d8.walk,6))
-- A caster goes that far too (as SCS's mages do between casts, E8 v5); webbed, a fighter strikes
-- only what its weapon reaches.
i.mind=mind.new()
rejected={}
list=choice.weaponOptions(i,rejected)
assert(#list==2 and list[1].target==12 and near(list[1].walk,6) and list[2].target==11 and rejected['out-of-reach']==nil)
i.mind=mind.forFamily(mind.new(),'fighter')
i.frame.self.rooted=true
i.frame.enemies={enemy(11,{x=164}),enemy(12,{x=200})}
rejected={}
list=choice.weaponOptions(i,rejected)
assert(#list==1 and list[1].target==11 and rejected['out-of-reach']==1)
groups=groups+1

-- 9. The round (Christopher, 2026-10-25: the engine owns it all). While the casting aura runs,
-- casts wait for it. An attack now (a round) holds the best cast back by the part of a round the
-- aura leaves of it: with four seconds of aura left, the mace, worth less than a third of the bolt,
-- waits until half a second before the aura frees; with a whole round of aura left it holds nothing
-- back and is made. Half a second or less before the aura frees, the cast is chosen (it starts when
-- the aura frees). With nothing to cast the attack is made whatever the aura.
i=input({spells={row('TESTBOLT',bolt,3)}})
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=200})}
local cast=choice.decide(i)
local swing=choice.weaponOptions(i)[1]
assert(cast.resref=='TESTBOLT' and swing.score>0 and swing.score<cast.score*2/6)
i.frame.self.aura=4
d,why=choice.decide(i)
assert(why=='aura' and d.kind=='wait' and near(d.seconds,3.5) and d.score==0)
i.frame.self.aura=6
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon' and d.target==11)
i.frame.self.aura=0.5
assert(choice.decide(i).resref=='TESTBOLT')
i.spells={}
i.frame.self.aura=4
assert(choice.decide(i).kind=='weapon')
i.frame.self.weapon=nil
d,why=choice.decide(i)
assert(why=='aura' and d.kind=='wait' and near(d.seconds,3.5))
i.frame.self.aura=nil
d,why=choice.decide(i)
assert(why=='no-option' and d.kind=='wait' and d.seconds==choice.idle)
-- Standing next to a strong enemy costs a caster more than its mace is worth, so it waits; a
-- fighter attacks all the same (mind.alwaysAttack), and the cost only chooses its target: the weak
-- enemy further off.
local brute=enemy(11,{x=200,attack={apr=3,thac0=1,damage=20}})
i=input()
i.frame.self.weapon=MACE
i.frame.enemies={brute}
swing=choice.weaponOptions(i)[1]
assert(swing.worth>0 and swing.score<0)
d,why=choice.decide(i)
assert(why=='no-option' and d.kind=='wait')
i.mind=mind.forFamily(mind.new(),'fighter')
assert(i.mind.alwaysAttack and not mind.new().alwaysAttack and select(2,mind.new({alwaysAttack=1}))=='alwaysAttack')
d,why=choice.decide(i)
assert(why=='weapon' and d.target==11 and d.score<0)
i.frame.enemies={brute,enemy(12,{x=400})}
d,why=choice.decide(i)
assert(why=='weapon' and d.target==12 and d.walk>0)
groups=groups+1

-- 10. Jumps into the fight (Christopher, 2026-10-26: a real teleport whose name shows in the log). A
-- fighter with an innate teleport of Teleport Without Error's reach and an axe (two swings of 20,
-- hitting 0.8 each) sees an enemy 600 away: it lands 48 short of the enemy and strikes without the
-- walk of 5.36 seconds, worth a round of hits less the teleport's level and what standing there
-- costs; the walk keeps only 6/11.36 of them.
local zones=require('combat-intent.zones')
local fighter=mind.forFamily(mind.new(),'fighter')
local blink={resref='BGSETELE',range=3200,speed=0,level=1,innate=true}
local AXE={item='TESTAXE',damage=20,damageType=3,apr=2,thac0=10,ranged=false,flags=0,enchantment=0}
i=input({mind=fighter,teleports={blink}})
i.frame.self.weapon=AXE
i.frame.enemies={enemy(11,{x=700})}
local stand=weapons.exposure(i.frame,i.frame.enemies[1])/60
list=choice.jumpOptions(i)
o=list[1]
assert(#list==1 and o.kind=='teleport' and o.resref=='BGSETELE' and o.mode=='point' and o.target==11 and o.melee and o.innate)
assert(o.point.x==652 and o.point.y==100 and near(o.worth,32/60) and near(o.cost,0.03+stand) and o.speed==0 and o.level==1)
swing=choice.weaponOptions(i)[1]
assert(near(swing.worth,32/60*6/11.36) and swing.score<o.score)
d,why=choice.decide(i)
assert(why=='best' and d.kind=='teleport' and d.target==11 and d.point.x==652)
-- Behind two skins the round's 1.6 hits only take them, the kill's progress: three hits of 20 and
-- the two skins.
i.frame.enemies={enemy(11,{x=700,skins=2})}
o=choice.jumpOptions(i)[1]
assert(o and near(o.worth,32/60*3/5))
-- One others keep it from on foot (frame.self.unreachable): the jump still goes there, the walk not.
i.frame.enemies={enemy(11,{x=700})}
i.frame.self.unreachable={[11]=true}
assert(#choice.jumpOptions(i)==1 and #choice.weaponOptions(i)==0)
i.frame.self.unreachable=nil
-- Within a jump's walk of the landing (200) it walks.
i.frame.enemies={enemy(11,{x=290})}
rejected={}
assert(#choice.jumpOptions(i,rejected)==0 and rejected['jump-near']==1 and choice.decide(i).kind=='weapon')
-- None within 18 seconds of its last teleport, for a search or a jump.
i.frame.enemies={enemy(11,{x=700})}
i.jumped=i.tick-17*15
rejected={}
assert(#choice.jumpOptions(i,rejected)==0 and rejected['jump-no-teleport']==1)
i.jumped=i.tick-18*15
assert(#choice.jumpOptions(i)==1)
i.jumped=nil
-- A memorized teleport (Dimension Door, level 4, a speed point of casting) spends its slot: only for
-- a walk of 600 or more; its casting paces the hits.
i.teleports={{resref='SPWI402',range=16000,speed=1,level=4}}
assert(#choice.jumpOptions(i)==0)
i.frame.enemies={enemy(11,{x=800})}
o=choice.jumpOptions(i)[1]
assert(o.resref=='SPWI402' and o.innate==nil and o.point.x==752 and near(o.cost,0.12+stand))
assert(near(o.worth,32/60*weapons.paced(zones.speedSeconds)))
-- Beyond its reach it lands as far as it reaches and walks the rest.
i.teleports={{resref='TESTHOP',range=160,speed=0,level=1,innate=true}}
i.frame.enemies={enemy(11,{x=700})}
o=choice.jumpOptions(i)[1]
assert(o.point.x==260 and near(o.worth,32/60*weapons.paced((440-64)/100)))
i.teleports={blink}
-- A weak hit (a knife of 6): worth less than a spell must be, but more than the walk, and a fighter
-- that always attacks takes it over the walk. A weaker one still (the mace): the walk is worth more
-- than the teleport costs.
i.frame.self.weapon={item='TESTKNIF',damage=6,damageType=1,apr=1,thac0=10,ranged=false,flags=0,enchantment=0}
d,why=choice.decide(i)
assert(why=='jump' and d.kind=='teleport' and d.score<i.mind.minValue)
i.frame.self.weapon=MACE
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon')
i.frame.self.weapon=AXE
-- An order to always attack an enemy far off: the jump goes there, not the swing at the one beside.
i.frame.enemies={enemy(11,{x=700,player=1}),enemy(12,{x=150})}
assert(choice.decide(i).target==12)
i.orders={target='protagonist',always=true}
d=choice.decide(i)
assert(d.kind=='teleport' and d.target==11 and d.ordered)
i.orders=nil
-- A tactic: a normal fighter jumps when it notices (one draw a decision, and none without a jump to
-- see), a dull one never.
i.frame.enemies={enemy(11,{x=700})}
local draws=0
local function stub(v) return {nextInt=function() draws=draws+1;return v end} end
i.mind=mind.withWit(fighter,{step='normal',danger=1})
i.rng=stub(400)
assert(choice.decide(i).kind=='teleport' and draws==2)
i.rng=stub(600)
assert(choice.decide(i).kind=='weapon' and draws==3)
i.frame.enemies={enemy(11,{x=200})}
assert(choice.decide(i).kind=='weapon' and draws==3)
i.frame.enemies={enemy(11,{x=700})}
i.rng=nil
i.mind=mind.withWit(fighter,{step='dull',danger=1})
rejected={}
assert(#choice.jumpOptions(i,rejected)==0 and rejected['jump-unnoticed']==1 and choice.decide(i).kind=='weapon')
-- Not for a caster (it walks to no enemy), with a missile weapon, webbed, with a touch charge in hand,
-- or under Improved Alacrity.
i.mind=mind.new()
assert(#choice.jumpOptions(i)==0)
i.mind=fighter
i.frame.self.weapon={item='TESTSLNG',damage=3.5,damageType=2,apr=1,thac0=10,ranged=true,range=400,flags=0,enchantment=0}
assert(#choice.jumpOptions(i)==0)
i.frame.self.weapon=AXE
i.frame.self.rooted=true
assert(#choice.jumpOptions(i)==0)
i.frame.self.rooted=nil
i.frame.self.charge={item='TESTHND',touch=true}
assert(#choice.jumpOptions(i)==0)
i.frame.self.charge=nil
i.frame.self.alacrity=true
assert(#choice.jumpOptions(i)==0)
i.frame.self.alacrity=nil
assert(#choice.jumpOptions(i)==1)
groups=groups+1

-- 11. On-hit effects the creature carries (F2a: its guard's hits) come with every hit of a fitting
-- weapon. A poisoned blade adds 4 poison to each of the mace's 0.8 hits a round; Smite Evil's 1d6
-- magic comes with the first hit alone, and only on an enemy it works on (one SPLPROT check keeps
-- it off enemy 11), so the smite draws the attack to enemy 12. Missile ones (249) do not come with
-- the mace, fists-only ones only with fists.
RECORDS['EFF:TESTPSEF']={kind='EFF',resref='TESTPSEF',effect=fx(12,{p1=4,p2=32*65536,timing=1})}
RECORDS['EFF:TESTSMEF']={kind='EFF',resref='TESTSMEF',effect=fx(146,{p2=1,res='TESTSMHT',timing=1})}
RECORDS['SPL:TESTSMHT']=spl('TESTSMHT',1,{fx(324,{p1=156,p2=104,res='TESTSMHT'}),
    fx(321,{target=1,res='TESTSMIT',timing=1}),fx(12,{p2=64*65536,dice=1,sides=6,timing=1})})
local function carrying(effects) return classify(spl('',1,effects,{target=5})).hits end
local poisoned=carrying({fx(248,{target=1,duration=10,res='TESTPSEF',source='TESTPOIS'})})
local smiting=carrying({fx(248,{target=1,duration=10,res='TESTSMEF',source='TESTSMIT'})})
local evil=spells.conditionKey({row=104,value=156})
pace=6/(6+0.36)
i=input({mind=mind.forFamily(mind.new(),'fighter')})
i.frame.self.weapon=MACE
i.frame.enemies={enemy(11,{x=200,splprot={[evil]=true}}),enemy(12,{x=200,splprot={[evil]=false}})}
list=choice.weaponOptions(i)
assert(list[1].target==11 and near(list[1].worth,0.8*4.5/60*pace) and near(list[2].worth,list[1].worth))
i.frame.self.guard={hits=poisoned}
o=choice.weaponOptions(i)[1]
assert(near(o.worth,0.8*8.5/60*pace) and near(o.expected[11],6.8))
i.frame.self.guard={hits=smiting}
list=choice.weaponOptions(i)
assert(smiting[1].once and list[1].target==12 and near(list[1].worth,(3.6+0.8*3.5)/60*pace))
assert(list[2].target==11 and near(list[2].worth,0.8*4.5/60*pace))
local arrowsOnly=carrying({fx(249,{target=1,duration=10,res='TESTPSEF'})})
local fistsOnly=carrying({fx(248,{target=1,duration=10,p2=4,res='TESTPSEF'})})
i.frame.self.guard={hits={arrowsOnly[1],fistsOnly[1]}}
assert(near(choice.weaponOptions(i)[1].worth,0.8*4.5/60*pace))
i.frame.self.weapon={item='TESTFIST',damage=4.5,damageType=2,apr=1,thac0=10,ranged=false,flags=0,enchantment=0,fist=true}
assert(near(choice.weaponOptions(i)[1].worth,0.8*8.5/60*pace))
groups=groups+1

-- 12. Weapon choice (F2c): every weapon the creature carries is an option. An archer (a fighter's
-- profile) with a bow in hand (two shots of 3.5 that hit 0.8 each, range 400) and a sword in its
-- second weapon slot (two swings of 5): an enemy 350 away is shot, as the sword's walk of 2.86
-- seconds and the second it takes to take it up leave 6/9.86 of its round; one next to the archer
-- is struck with the sword, taken up first (SelectWeaponAbility at slot 36, ability 0), worth 6/7
-- of its round. A sword of 4 is worth more than the bow in hand, but not after that second.
local BOW={item='TESTBOW',damage=3.5,damageType=4,apr=2,thac0=10,ranged=true,range=400,flags=0,enchantment=0,
    ammo='TESTARRW',projectile=2,slot=35,abilityNum=0}
local function edge(damage)
    return {item='TESTSWRD',damage=damage,damageType=3,apr=2,thac0=10,ranged=false,flags=0,enchantment=0,slot=36,abilityNum=0}
end
local archer=mind.forFamily(mind.new(),'fighter')
local function shooter()
    local s=input({mind=archer})
    s.frame.self.x,s.frame.self.y=1000,1000
    s.frame.self.weapon=BOW
    s.frame.self.arsenal={edge(5)}
    return s
end
local function foe(id,x,fields)
    local f=enemy(id,{x=x,y=1000})
    for k,v in pairs(fields or {}) do f[k]=v end
    return f
end
i=shooter()
assert(#choice.arsenal(i.frame.self)==2 and choice.arsenal(i.frame.self)[1]==BOW)
i.frame.enemies={foe(11,1350)}
list=choice.weaponOptions(i)
assert(#list==2 and list[1].resref=='TESTBOW' and list[1].slot==nil and near(list[1].worth,1.6*3.5/60))
assert(list[2].resref=='TESTSWRD' and list[2].slot==36 and list[2].abilityNum==0 and near(list[2].walk,2.86))
assert(near(list[2].worth,1.6*5/60*6/9.86))
d,why=choice.decide(i)
assert(why=='weapon' and d.resref=='TESTBOW' and d.slot==nil)
i.frame.enemies={foe(11,1050)}
d,why=choice.decide(i)
assert(why=='weapon' and d.resref=='TESTSWRD' and d.slot==36 and d.abilityNum==0 and near(d.worth,1.6*5/60*6/7))
i.frame.self.arsenal={edge(4)}
d=choice.decide(i)
assert(d.resref=='TESTBOW' and d.slot==nil)
-- A magic weapon in hand stays there: no other is weighed. Weapons of unknown damage are left out.
i.frame.self.arsenal={edge(5)}
i.frame.self.magicItem=true
assert(#choice.arsenal(i.frame.self)==1 and choice.decide(i).resref=='TESTBOW')
i.frame.self.magicItem=nil
i.frame.self.arsenal={{item='TESTODD',ranged=false},false}
assert(#choice.arsenal(i.frame.self)==1)
-- Missiles kept off (what SCS's archers keep away from, and immunities to the arrows' projectile):
-- Protection from Normal Missiles keeps off plain arrows, not magical ones; a Physical Mirror any;
-- an immunity (opcode 83) or a bounce (197) those of the projectile's entry, one below its number.
i.frame.self.arsenal={}
i.frame.enemies={foe(11,1350,{normalMissiles=true})}
rejected={}
assert(#choice.weaponOptions(i,rejected)==0 and rejected['missile-blocked']==1)
local magicBow={}
for k,v in pairs(BOW) do magicBow[k]=v end
magicBow.enchantment=1
i.frame.self.weapon=magicBow
assert(#choice.weaponOptions(i)==1)
i.frame.enemies={foe(11,1350,{reflects=true})}
assert(#choice.weaponOptions(i)==0)
i.frame.self.weapon=BOW
assert(weapons.missileBlocked({protections={{opcode=83,p2=1}}},BOW) and weapons.missileBlocked({protections={{opcode=197,p2=1}}},BOW))
assert(not weapons.missileBlocked({protections={{opcode=83,p2=5}}},BOW) and not weapons.missileBlocked({normalMissiles=true},edge(5)))
assert(not weapons.missileBlocked({normalMissiles=true},{ranged=true,flags=0x40,enchantment=0}))
-- An enemy beyond the bow's range: the archer walks into range first (two seconds for the 200
-- beyond), which leaves 6/8 of the round; one that cannot walk has no shot.
i.frame.enemies={foe(11,1600)}
o=choice.weaponOptions(i)[1]
assert(o.resref=='TESTBOW' and near(o.walk,2) and near(o.worth,1.6*3.5/60*6/8))
i.frame.self.rooted=true
rejected={}
assert(#choice.weaponOptions(i,rejected)==0 and rejected['out-of-reach']==1)
i.frame.self.rooted=nil
groups=groups+1

-- 13. Kiting (F2c; SCS's retreat.ssl). An ogre (three swings of 20 that hit 19 times in 20) next to
-- the archer takes 57 hit points a round from it; a step of four seconds away (400 at a walk of 100
-- a second) keeps them off for two thirds of a round: worth 57/60*4/6, far more than the two thirds
-- of a round of shots it costs. The step goes straight away from the ogre, with four more spots as
-- exits.
i=shooter()
i.frame.self.arsenal={}
local ogre=foe(11,1050,{attack={apr=3,thac0=1,damage=20}})
i.frame.enemies={ogre}
o=choice.kite(i)
assert(o and o.kind=='kite' and o.resref=='KITE' and o.mode=='point' and o.point.x==600 and o.point.y==1000)
assert(near(o.worth,57/60*4/6) and o.score==o.worth and o.walk==4 and #o.exits==4)
d,why=choice.decide(i)
assert(why=='kite' and d.kind=='kite' and d.point.x==600)
-- With the ogre on its other side it steps the other way. Weak enemies (one swing of 2 that hits
-- three times in ten) stand at every spot a step could end: what they would take there (0.6 a round)
-- comes off what the step keeps off.
i.frame.enemies={foe(11,950,{attack={apr=3,thac0=1,damage=20}})}
o=choice.kite(i)
assert(o.point.x==1400 and o.point.y==1000)
local ring={ogre}
for _,p in ipairs({{1400,1000},{1283,1212},{1000,1300},{717,1212},{600,1000},{717,788},{1000,700},{1283,788}}) do
    ring[#ring+1]=enemy(20+#ring,{x=p[1],y=p[2],attack={apr=1,thac0=20,damage=2}})
end
i.frame.enemies=ring
o=choice.kite(i)
assert(o.point.x==600 and o.point.y==1000 and near(o.worth,(57-0.6)/60*4/6))
i.frame.enemies={ogre}
-- Not again within 18 seconds of its last step away: it shoots.
i.kited=i.tick-17*15
rejected={}
assert(choice.kite(i,rejected)==nil and rejected['kite-recent']==1)
d,why=choice.decide(i)
assert(why=='weapon' and d.resref=='TESTBOW')
i.kited=i.tick-18*15
assert(choice.kite(i))
i.kited=nil
-- One the adapter found no open step for lately (input.blocked): it shoots. A blocked walk into
-- position or behind an enemy leaves the step away as it is.
i.blocked={kite=true}
rejected={}
assert(choice.kite(i,rejected)==nil and rejected['kite-blocked']==1)
d,why=choice.decide(i)
assert(why=='weapon' and d.resref=='TESTBOW')
i.blocked={position=true,flank={[ogre.id]=true}}
assert(choice.kite(i))
i.blocked=nil
-- A weak enemy (one swing of 2 that hits three times in ten) is not worth stepping away from.
i.frame.enemies={foe(11,1050,{attack={apr=1,thac0=20,damage=2}})}
assert(choice.kite(i) and choice.decide(i).kind=='weapon')
-- Not from an enemy further than 6 (96) or one that shoots; not without a missile weapon, webbed or
-- invisible. A dull archer never steps away, a normal one when it notices (one draw).
i.frame.enemies={foe(11,1100,{attack={apr=3,thac0=1,damage=20}})}
assert(choice.kite(i)==nil)
i.frame.enemies={foe(11,1050,{attack={apr=3,thac0=1,damage=20,ranged=true}})}
assert(choice.kite(i)==nil)
i.frame.enemies={ogre}
i.frame.self.weapon=edge(5)
rejected={}
assert(choice.kite(i,rejected)==nil and rejected['kite-no-ranged']==1)
i.frame.self.weapon=BOW
i.frame.self.rooted=true
assert(choice.kite(i)==nil)
i.frame.self.rooted=nil
i.frame.self.state=targeting.STATE.invisible
assert(choice.kite(i)==nil)
i.frame.self.state=0
i.mind=mind.withWit(archer,{step='dull',danger=1})
rejected={}
assert(choice.kite(i,rejected)==nil and rejected['kite-unnoticed']==1 and choice.decide(i).kind=='weapon')
i.mind=mind.withWit(archer,{step='normal',danger=1})
draws=0
i.rng=stub(400)
assert(choice.decide(i).kind=='kite' and draws==1)
i.rng=stub(600)
assert(choice.decide(i).kind=='weapon' and draws==2)
-- An enemy that shoots, close by, is nothing to step away from, so nothing to notice: no draw.
i.frame.enemies={foe(11,1050,{attack={apr=3,thac0=1,damage=20,ranged=true}})}
assert(choice.decide(i).kind=='weapon' and draws==2)
i.frame.enemies={ogre}
i.rng=nil
-- A sword at hand changes nothing: the step is weighed against the best attack, here the sword's.
i.mind=archer
i.frame.self.arsenal={edge(5)}
assert(choice.decide(i).kind=='kite')
groups=groups+1

-- 14. Critical hit effects and on-hit debuffs (F2e). Of the hits that land with chance h, a share
-- of (1+crit)/20 over h are critical hits (no less likely than 1 in 20, all of them at most).
assert(near(weapons.critical(0.8,0),0.05/0.8) and near(weapons.critical(0.8,4),0.25/0.8) and weapons.critical(0.1,4)==1)
assert(near(weapons.critical(0.8,-5),0.05/0.8) and weapons.critical(0,0)==0 and weapons.critical(nil,0)==0)
-- A kit's critical hit effect with melee hits casts 10 fire at the creature hit: of the mace's 0.8
-- hits a round, 0.05/0.8 are critical hits, half of them past a helmet (0.025 a round), worth 0.25
-- more and counted as expected. Four critical hit points (opcode 301 on the creature) make five in
-- twenty. One with missiles alone does not come with the mace; one of a single weapon only with that
-- item; one of a category (fists, 28) only with a weapon of it.
RECORDS['SPL:TESTCRFI']=spl('TESTCRFI',1,{fx(12,{p1=10,p2=8*65536,timing=1})})
RECORDS['SPL:TESTCRST']=spl('TESTCRST',1,{fx(45,{duration=12})})
RECORDS['EFF:TESTWKEF']={kind='EFF',resref='TESTWKEF',effect=fx(54,{p1=-4,duration=12})}
pace=6/(6+0.36)
i=input({mind=mind.forFamily(mind.new(),'fighter')})
i.frame.self.weapon=MACE
i.frame.enemies={enemy(12,{x=200})}
local burning=carrying({fx(341,{target=1,timing=9,special=1,res='TESTCRFI',source='TESTKIT'})})
i.frame.self.guard={hits=burning}
o=choice.weaponOptions(i)[1]
assert(near(o.worth,(3.6+0.25)/60*pace) and near(o.expected[12],3.85))
i.frame.self.guard={hits=burning,roles={buff={amounts={critical=4}}}}
assert(near(choice.weaponOptions(i)[1].worth,(3.6+1.25)/60*pace))
i.frame.self.guard={hits=burning,roles={buff={amounts={critical=4}},debuff={amounts={critical=4}}}}
assert(near(choice.weaponOptions(i)[1].worth,(3.6+0.25)/60*pace))
i.frame.self.guard={hits=carrying({fx(341,{target=1,timing=9,special=2,res='TESTCRFI'})})}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
i.frame.self.guard={hits=carrying({fx(341,{target=1,timing=2,p2=1,res='TESTCRFI',source='TESTMACE'})})}
assert(near(choice.weaponOptions(i)[1].worth,(3.6+0.25)/60*pace))
i.frame.self.guard={hits=carrying({fx(341,{target=1,timing=2,p2=1,res='TESTCRFI',source='TESTAXE'})})}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
i.frame.self.guard={hits=carrying({fx(341,{target=1,timing=1,p3=28,res='TESTCRFI'})})}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
i.frame.self.weapon={item='TESTFIST',damage=4.5,damageType=2,apr=1,thac0=10,ranged=false,flags=0,enchantment=0,fist=true,
    itemType=28}
assert(near(choice.weaponOptions(i)[1].worth,(3.6+0.25)/60*pace))
-- A critical hit that stuns counts as likely as a critical hit lands (0.025 of the stun's 2/3).
i.frame.self.weapon=MACE
i.frame.self.guard={hits=carrying({fx(341,{target=1,timing=9,special=1,res='TESTCRST'})})}
assert(near(choice.weaponOptions(i)[1].worth,(3.6/60+0.025*2/3)*pace))
-- An on-hit effect that weakens (THAC0 4 worse for 12 seconds) takes a quarter of the fight of an
-- enemy that swings twice for 10 at the caster's armour class 5, for two thirds of the full time,
-- as likely as a hit lands (0.8); the weapon's own hit weakens alike. None on an enemy that carries
-- it already: an effect of the spell that holds it, or of the file it lands.
local weakening=carrying({fx(248,{target=1,duration=30,res='TESTWKEF',source='TESTKIT'})})
i.frame.self.guard={hits=weakening}
local brute=enemy(12,{x=200,attack={apr=2,thac0=10,damage=10}})
i.frame.enemies={brute}
assert(near(choice.weaponOptions(i)[1].worth,(3.6/60+0.8*0.25*2/3)*pace))
brute.wards={{source='TESTKIT'}}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
brute.wards={{source='TESTWKEF'}}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
brute.wards=nil
i.frame.self.guard={}
local weak=spells.classify(itm('TESTMACW',{effects={fx(54,{p1=-4,duration=12})}}),1,lookup,{level=12,weapons=false})
i.frame.self.weapon={item='TESTMACW',damage=4.5,damageType=2,apr=1,thac0=10,ranged=false,flags=0,enchantment=0,strike=weak}
assert(near(choice.weaponOptions(i)[1].worth,(3.6/60+0.8*0.25*2/3)*pace))
brute.wards={{source='TESTMACW'}}
assert(near(choice.weaponOptions(i)[1].worth,3.6/60*pace))
brute.wards=nil
-- The strongest disable and the strongest debuff a hit brings count side by side.
i.frame.self.weapon=MACE
i.frame.self.guard={hits={weakening[1],carrying({fx(341,{target=1,timing=9,special=1,res='TESTCRST'})})[1]}}
assert(near(choice.weaponOptions(i)[1].worth,(3.6/60+0.025*2/3+0.8*0.25*2/3)*pace))
-- What a hit's debuff takes counts more on an enemy the creature's orders name, as its damage does.
brute.resref='TESTBRUT'
i.frame.self.guard={hits=weakening}
i.orders={target='TESTBRUT'}
assert(near(choice.weaponOptions(i)[1].worth,2*(3.6/60+0.8*0.25*2/3)*pace))
i.orders=nil
-- A critical hit's fire counts where the weapon itself does nothing (crushing resistance 100).
i.frame.enemies={enemy(12,{x=200,resist={crushing=100}})}
i.frame.self.guard={hits=burning}
assert(near(choice.weaponOptions(i)[1].worth,0.25/60*pace))
-- A critical hit spell that takes the spell holding it off its holder again comes once: with every
-- hit critical (19 critical hit points) and three swings a round, 1.2 critical hits land past
-- helmets, but its 10 fire counts once beside the swings' 10.8.
RECORDS['SPL:TESTCRSG']=spl('TESTCRSG',1,{fx(12,{p1=10,p2=8*65536,timing=1}),fx(321,{target=1,res='TESTSIEG',timing=1})})
i.frame.enemies={enemy(12,{x=200})}
i.frame.self.weapon={item='TESTFLL3',damage=4.5,damageType=2,apr=3,thac0=10,ranged=false,flags=0,enchantment=0}
local function siege(source)
    return {hits=carrying({fx(341,{target=1,duration=60,special=1,res='TESTCRSG',source=source})}),
        roles={buff={amounts={critical=19}}}}
end
i.frame.self.guard=siege('TESTSIEG')
assert(i.frame.self.guard.hits[1].once and near(choice.weaponOptions(i)[1].worth,(10.8+10)/60*pace))
i.frame.self.guard=siege('TESTOTHR')
assert(near(choice.weaponOptions(i)[1].worth,(10.8+12)/60*pace))
groups=groups+1

-- 15. Behind Stoneskin and Mirror Images (lab batch J run 3: five skins on the party's last mage
-- took all of a round's hits, and the group waited two minutes in front of her). The hits the
-- skins and images take deal nothing now, but each one brings the kill a hit closer: the round
-- counts what it would deal with nothing in the way, times the share of real hits among all the
-- hits the kill takes. A fighter swings three times a round with a sword of 9 that hits four times
-- in five: 2.4 hits. The mage has 12 of 40 hit points and five skins: the kill takes two hits and
-- the five, so the round's 21.6 (12 of them count) counts 2/7.
i=input()
i.family='fighter'
i.frame.self.weapon={item='TESTSWRD',damage=9,damageType=1,apr=3,thac0=10,ranged=false,flags=0,enchantment=0}
i.frame.enemies={enemy(11,{x=150,hp=12,maxHp=40,skins=5})}
o=choice.weaponOptions(i)[1]
assert(o and o.target==11 and near(o.worth,12/40*2/7) and o.expected[11]==0 and o.interrupt==nil)
d,why=choice.decide(i)
assert(why=='weapon' and d.kind=='weapon' and d.target==11)
-- Beside an enemy as hurt with nothing in the way, that one comes first: its round kills.
i.frame.enemies={enemy(11,{x=150,hp=12,maxHp=40,skins=5}),enemy(12,{x=150,hp=12,maxHp=40})}
o=choice.weaponOptions(i)[1]
assert(o.target==12 and near(o.worth,12/40+i.mind.killBonus))
-- Hits past the images that kill this round count as the kill: one image takes one of the 2.4
-- hits, the other 1.4 take its last 9 hit points (more than the progress, half of it).
i.frame.enemies={enemy(11,{x=150,hp=9,maxHp=40,mirror=1})}
o=choice.weaponOptions(i)[1]
assert(near(o.worth,9/40+i.mind.killBonus) and near(o.expected[11],9))
-- A minimum of 3 leaves 9 to take: one hit and the five skins, and no kill.
i.frame.enemies={enemy(11,{x=150,hp=12,maxHp=40,skins=5,minHp=3})}
assert(near(choice.weaponOptions(i)[1].worth,9/40*1/6))
groups=groups+1

-- 16. Casters step away from melee too (E7; Christopher, 2026-11-03: mages step away from melee
-- foes now and then, by wit; SCS's mages do while they still have missile spells). A mage of 200
-- hit points without a missile weapon; a fighter next to it that attacks it swings twice a round for
-- 8 and hits 19 times in 20 (15.2 a round, little of its 200). Its best choice, a bolt of casting
-- speed 3 (two seconds) worth 0.3, breaks where it stands when one of the 1.9*2/6 hits expected
-- meanwhile lands. After the step (400 away, straight from the fighter) the fighter follows a second
-- late at 100 a second and is back 4.86 seconds after the step began, 0.86 into the casting.
i=input()
i.frame.self.x,i.frame.self.y,i.frame.self.hp,i.frame.self.maxHp=1000,1000,200,200
i.spells={row('TESTBOLT',bolt,3)}
i.frame.enemies={foe(11,1050,{attack={apr=2,thac0=6,damage=8},actee=1})}
local best={resref='TESTBOLT',kind='attack',mode='target',target=11,speed=3,worth=0.3,cost=0,score=0.3}
o=choice.kite(i,nil,best)
local here,after=1-math.exp(-1.9*2/6),1-math.exp(-1.9*(6-4.86)/6)
assert(o and o.kind=='kite' and o.point.x==600 and o.point.y==1000 and o.cast=='TESTBOLT')
assert(near(o.breaks.here,here) and near(o.breaks.after,after))
assert(near(o.worth,i.mind.caution*15.2/200*4/6+0.3*(here-after)))
-- A fighter that attacks someone else stays where it is: nothing breaks the bolt after the step. One
-- at half the pace is back only after the casting ends.
i.frame.enemies={foe(11,1050,{attack={apr=2,thac0=6,damage=8},actee=2})}
o=choice.kite(i,nil,best)
assert(near(o.breaks.after,0) and near(o.worth,i.mind.caution*15.2/200*4/6+0.3*here))
i.frame.enemies={foe(11,1050,{attack={apr=2,thac0=6,damage=8},actee=1,speed=50})}
assert(near(choice.kite(i,nil,best).breaks.after,0))
-- Mirror Images take hits first: with one, 1.9*2/6 hits come to none that land.
i.frame.self.mirror=1
o=choice.kite(i,nil,best)
assert(near(o.breaks.here,0) and near(o.worth,i.mind.caution*15.2/200*4/6))
i.frame.self.mirror=0
-- A fighter on its way, 80 off and not yet in reach, takes nothing from the mage where it stands, but
-- it would break the bolt all the same: in reach 0.16 seconds on (for 1.84 of the casting's two), and
-- back 5.16 seconds after the step began (0.84 into the casting).
i.frame.enemies={foe(11,1080,{attack={apr=2,thac0=6,damage=8},actee=1})}
o=choice.kite(i,nil,best)
here,after=1-math.exp(-1.9*1.84/6),1-math.exp(-1.9*0.84/6)
assert(o and near(o.breaks.here,here) and near(o.breaks.after,after) and near(o.worth,0.3*(here-after)))
-- A normal mage draws once a decision whether it notices the step, and only with a melee enemy close.
i.mind=mind.withWit(mind.new(),{step='normal',danger=1})
draws=0;i.rng=stub(400)
assert(choice.notices(i)==true and draws==1)
i.frame.enemies={foe(11,1200,{attack={apr=2,thac0=6,damage=8},actee=1})}
assert(choice.notices(i)==false and draws==1)
i.rng=nil;i.mind=mind.new()
i.frame.enemies={foe(11,1050,{attack={apr=2,thac0=6,damage=8},actee=1})}
-- Only a cast that damage can break counts: not a potion, a weapon or a release (ForceSpellRES), and
-- not one of no casting time. Without one and without a missile weapon, no step.
for _,other in ipairs({{use=true},{item='TESTSWRD',kind='weapon'},{release=true},{speed=0}}) do
    local o2={}
    for k,v in pairs(best) do o2[k]=v end
    for k,v in pairs(other) do o2[k]=v end
    rejected={}
    assert(choice.kite(i,rejected,o2)==nil and rejected['kite-no-ranged']==1)
end
rejected={}
assert(choice.kite(i,rejected,nil)==nil and rejected['kite-no-ranged']==1)
-- In the choice: a slow bolt (speed 9, six seconds) amid two fighters that attack someone else
-- breaks almost surely where the mage stands (3.8 hits expected) and not at all after the step, so
-- the step beats two thirds of the bolt's round although the hits it keeps off are few.
local slow=classify(spl('TESTSLOW',3,{fx(12,{p2=8*65536,dice=6,sides=6})},{speed=9}))
i.spells={row('TESTSLOW',slow,3)}
i.frame.self.hp,i.frame.self.maxHp=400,400
i.frame.enemies={foe(11,1050,{attack={apr=2,thac0=6,damage=8},actee=2}),foe(12,1050,{attack={apr=2,thac0=6,damage=8},actee=2})}
local list
d,why,list=choice.decide(i)
assert(why=='kite' and d.cast=='TESTSLOW' and near(d.breaks.here,1-math.exp(-3.8)) and near(d.breaks.after,0))
local cast
for _,c in ipairs(list) do if c.resref=='TESTSLOW' then cast=c end end
assert(cast and cast.score>0 and near(d.worth,i.mind.caution*30.4/400*4/6+cast.score*(1-math.exp(-3.8))))
-- A dull mage never steps away; nor one that stepped away within 18 seconds: it casts.
i.mind=mind.withWit(mind.new(),{step='dull',danger=1})
rejected={}
assert(choice.kite(i,rejected,cast)==nil and rejected['kite-unnoticed']==1 and choice.decide(i).resref=='TESTSLOW')
i.mind=mind.new()
i.kited=i.tick-17*15
assert(choice.decide(i).resref=='TESTSLOW')
groups=groups+1

return groups
