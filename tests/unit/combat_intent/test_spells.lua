-- Synthetic records in the shape of tools/ie_resources.py output; no game data.
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function ability(effects,fields)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,
        projectile=1,effects=effects}
    for k,v in pairs(fields or {}) do a[k]=v end
    return a
end
local function spl(resref,abilities,fields)
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,
        level=1,abilities=abilities,casting={}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function itm(resref,itemType,abilities)
    return {kind='ITM',resref=resref,name=0,identifiedName=0,flags=0,itemType=itemType,
        abilities=abilities,equipping={}}
end
local function pro(fields)
    local r={kind='PRO',resref='TESTPRO',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,
        radius=256,coneWidth=0,targetDice=0,targetSides=0}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
-- lookup over a table keyed 'KIND:KEY'.
local function world(t) return function(kind,key) return t[kind..':'..tostring(key)] end end
local function classify(record,lookup,options) return spells.classify(record,1,lookup,options) end
local function one(e,fields,lookup) return classify(spl('TESTONE',{ability({e},fields)}),lookup or world({})) end
local function near(a,b) return math.abs(a-b)<1e-9 end

-- Single-target damage from a hostile spell.
local missile=spl('SPWI112',{ability({fx(12,{p1=1,p2=64*65536,dice=1,sides=4})},{projectile=69})},{flags=1024})
local c=classify(missile,world({['PRO:69']=SINGLE}))
assert(#c.kinds==1 and c.kinds[1]=='damage' and c.target=='creature' and c.hostile==true)
assert(c.roles.damage.who.target and near(c.roles.damage.amount,3.5) and near(c.roles.damage.types.magic,3.5))
assert(c.offensive and not c.friendlyFire and not c.area and not c.projectileUnknown and not c.partial)
-- Each roll kept for damage by the dice (combat-intent/harm.lua): 1d4 and a flat 1.
local r=c.roles.damage.rolls[1]
assert(#c.roles.damage.rolls==1 and r.label=='magic' and r.dice==1 and r.sides==4 and near(r.flat,1) and r.p==1 and r.times==1)
missile.flags=0
assert(classify(missile,world({['PRO:69']=SINGLE})).hostile==false)
groups=groups+1

-- An area that hits everyone: friendly fire, saves, half damage on a save.
local fireball=spl('SPWI304',{ability({fx(12,{p2=8*65536,dice=10,sides=6,save=1,special=256})},
    {target=4,projectile=99})})
c=classify(fireball,world({['PRO:99']=pro({radius=480})}))
assert(c.target=='point' and c.area.radius==480 and c.area.filter=='all' and c.roles.damage.who.area)
assert(near(c.roles.damage.amount,35) and c.roles.damage.saveForHalf and c.roles.damage.save.spell)
assert(c.friendlyFire and c.offensive)
r=c.roles.damage.rolls[1]
assert(r.label=='fire' and r.dice==10 and r.sides==6 and r.flat==0)
c=classify(fireball,world({['PRO:99']=pro({areaFlags=64})}))
assert(c.area.filter=='enemies' and not c.friendlyFire)
groups=groups+1

-- An area that explodes again and again (clouds and storms): its explosions, the seconds between
-- them (delay+1 ticks) and a first explosion that reaches no one (area flag 14). Where flag 8 or
-- 9 says so the caster's casting level replaces the repetitions (IESDP). One explosion, or no
-- delay read, is no lasting area. A sub-spell's area counts the same.
local cloud=spl('TESTCLD',{ability({fx(12,{p2=2*65536,p1=10})},{target=4,projectile=98})})
c=classify(cloud,world({['PRO:98']=pro({repeats=4,delay=100})}),{level=12})
assert(c.area.explosions==4 and near(c.area.every,101/15) and not c.area.skipFirst)
c=classify(cloud,world({['PRO:98']=pro({repeats=10,delay=75,areaFlags=16384})}),{level=12})
assert(c.area.explosions==10 and near(c.area.every,76/15) and c.area.skipFirst)
for _,flag in ipairs({256,512}) do
    c=classify(cloud,world({['PRO:98']=pro({repeats=3,delay=75,areaFlags=flag})}),{level=12})
    assert(c.area.explosions==12)
end
c=classify(cloud,world({['PRO:98']=pro({repeats=1,delay=75})}),{level=12})
assert(c.area and c.area.explosions==nil and c.area.every==nil)
c=classify(cloud,world({['PRO:98']=pro({repeats=4})}),{level=12})
assert(c.area and c.area.explosions==nil)
local outer=spl('TESTOUT',{ability({fx(146,{p2=1,res='TESTCLD'})},{target=4,projectile=1})})
c=classify(outer,world({['SPL:TESTCLD']=cloud,['PRO:98']=pro({repeats=4,delay=100})}),{level=12})
assert(c.area and c.area.explosions==4)
groups=groups+1

-- Sleep: waking on damage (parameter 2 = 0) and the level range in the dice fields.
local sleep=spl('SPWI116',{ability({fx(39,{dice=4,save=1})},{target=4,projectile=99})})
c=classify(sleep,world({['PRO:99']=pro()}))
assert(c.roles.disable.kinds.sleep and c.roles.disable.wakesOnDamage and not c.roles.disable.staysAsleep)
assert(c.roles.disable.maxLevel==4 and c.roles.disable.save.spell)
sleep.abilities[1].effects[1]=fx(39,{p2=1,dice=5,sides=1})
c=classify(sleep,world({['PRO:99']=pro()}))
assert(c.roles.disable.staysAsleep and c.roles.disable.maxLevel==5 and c.roles.disable.minLevel==1)
groups=groups+1

-- An allies-only area buff.
local haste=spl('SPWI305',{ability({fx(16,{duration=60})},{target=4,projectile=98})})
c=classify(haste,world({['PRO:98']=pro({areaFlags=64+128})}))
assert(c.area.filter=='allies' and c.roles.buff.kinds.haste and c.roles.buff.who.area)
assert(c.beneficial and not c.offensive and not c.friendlyFire and c.roles.buff.duration==60)
haste.abilities[1].effects[1].p2=1
assert(classify(haste,world({['PRO:98']=pro({areaFlags=192})})).roles.buff.kinds.improvedHaste)
groups=groups+1

-- Stoneskin: its 321 refresh of itself is bookkeeping, not dispelling.
local skin=spl('SPWI408',{ability({fx(321,{target=1,res='SPWI408'}),fx(218,{target=1,p1=8,duration=3600})},
    {target=5})})
c=classify(skin,world({}))
assert(#c.kinds==1 and c.kinds[1]=='protection' and c.roles.protection.stoneskin==8)
assert(c.roles.protection.who.self and next(c.unknown)==nil and not c.roles.removal)
skin.abilities[1].effects[2]=fx(218,{target=1,p2=1,dice=1,sides=4})
assert(near(classify(skin,world({})).roles.protection.stoneskin,2.5))
groups=groups+1

-- Breach strips secondary types; an enemies-only dispel spares allies.
local breach=spl('SPWI513',{ability({fx(221,{p1=9,p2=1}),fx(221,{p1=9,p2=7})},{projectile=69})})
c=classify(breach,world({['PRO:69']=SINGLE}))
assert(c.roles.removal.kinds.secondaries and c.roles.removal.secondaries[1]==9 and c.roles.removal.secondaries[7]==9)
assert(c.offensive)
local dispel=spl('SPWI302',{ability({fx(58,{p2=1})},{target=4,projectile=97})})
c=classify(dispel,world({['PRO:97']=pro({areaFlags=64})}))
assert(c.roles.removal.dispel.mode=='caster' and c.area.filter=='enemies' and not c.friendlyFire)
groups=groups+1

-- Sub-spells: casting level from 146, the caster's level for instant type 1 or level 0.
local sub=spl('TESTSUB',{ability({fx(12,{p1=5})},{minLevel=1}),ability({fx(12,{p1=50})},{minLevel=10})})
local parent=spl('TESTPAR',{ability({fx(146,{res='TESTSUB',p1=12})})})
local subs=world({['SPL:TESTSUB']=sub})
assert(classify(parent,subs,{level=3}).roles.damage.amount==50)
parent.abilities[1].effects[1].p2=1
assert(classify(parent,subs,{level=3}).roles.damage.amount==5)
parent.abilities[1].effects[1].p1=0;parent.abilities[1].effects[1].p2=0
assert(classify(parent,subs,{level=14}).roles.damage.amount==50)
assert(classify(parent,subs).roles.damage.amount==5)
-- The effects it lands carry the sub-spell as their source, so both names are kept.
c=classify(parent,subs)
assert(c.sources.TESTPAR and c.sources.TESTSUB and not c.sources.NOPE)
groups=groups+1

-- A cycle back to the classified spell repeats effects already seen (amounts become a lower
-- bound); a chain deeper than the limit is cut off and partial.
local a=spl('CYCA',{ability({fx(146,{res='CYCB'})})})
local b=spl('CYCB',{ability({fx(146,{res='CYCA'}),fx(12,{p1=3})})})
c=classify(a,world({['SPL:CYCA']=a,['SPL:CYCB']=b}))
assert(c.approximate and not c.partial and c.reasons['cycle:SPL:CYCA'] and c.roles.damage.amount==3)
local limit,chain=spells.limits.depth,{}
for i=1,limit+3 do
    local effects=i<limit+3 and {fx(146,{res='D'..(i+1)})} or {fx(12,{p1=1})}
    chain['SPL:D'..i]=spl('D'..i,{ability(effects)})
end
c=classify(chain['SPL:D1'],world(chain))
assert(c.partial and c.reasons['depth:SPL:D'..(limit+2)] and not c.roles.damage)
chain['SPL:D'..(limit+1)].abilities[1].effects={fx(12,{p1=1})}
c=classify(chain['SPL:D1'],world(chain))
assert(not c.partial and c.roles.damage.amount==1)
groups=groups+1

-- EFF files: 177 with IDS entry 0 applies to anyone, a non-zero entry only to that type.
local eff={kind='EFF',resref='TESTEFF',effect=fx(12,{p1=4,target=1})}
local effs=world({['EFF:TESTEFF']=eff})
local carrier=spl('TESTCAR',{ability({fx(177,{res='TESTEFF',p2=2})})})
c=classify(carrier,effs)
assert(c.roles.damage.amount==4 and c.roles.damage.who.target and not c.conditional)
assert(c.sources.TESTCAR and c.sources.TESTEFF)
carrier.abilities[1].effects[1].p1=4;carrier.abilities[1].effects[1].p2=4
c=classify(carrier,effs)
assert(c.conditional and c.conditions[1].ids==4 and c.conditions[1].entry==4 and c.roles.damage.amount==4)
-- The type is a condition of what the 177 brings: only a creature of that type takes it.
local yes,no=function() return true end,function() return false end
assert(spells.view(c,yes).damage.amount==4 and spells.view(c,no).damage==nil and spells.common(c).damage==nil)
-- The EFF's effect runs with the 177's timing and duration, not the file's (IESDP): a summons the
-- file names for good lasts the 177's 114 seconds (Conjure Lesser Water Elemental), a 30-second
-- hold behind a permanent 177 stays.
local carried=world({['EFF:TESTSUMN']={kind='EFF',resref='TESTSUMN',effect=fx(67,{res='TESTCRE',timing=1,target=1})},
    ['EFF:TESTHLDE']={kind='EFF',resref='TESTHLDE',effect=fx(175,{duration=30,p2=3,target=1})}})
c=classify(spl('TESTCONJ',{ability({fx(177,{res='TESTSUMN',p2=2,duration=114,target=1})},{target=4})}),carried)
assert(c.roles.summon and c.roles.summon.duration==114)
c=classify(spl('TESTHLDC',{ability({fx(177,{res='TESTHLDE',p2=2,timing=1})})}),carried)
assert(c.roles.disable and c.roles.disable.duration=='permanent')
groups=groups+1

-- 272 repeats an EFF (IESDP): once a second (parameter 1 set), once every p1 seconds, p1 times a
-- second; type 1 and type 0 without parameter 1 never apply it. Type 4 applies it parameter 3
-- times every p1 seconds, from an EFF file only; a frequency multiplier (parameter 4) of 2 halves it.
local rep=spl('TESTREP',{ability({fx(272,{res='TESTEFF',p1=1,duration=10})})})
c=classify(rep,effs)
assert(c.approximate and near(c.roles.damage.amount,40))
r=c.roles.damage.rolls[1]
assert(r.dice==0 and r.flat==4 and r.times==10)
rep.abilities[1].effects[1].p2=3;rep.abilities[1].effects[1].p1=2
assert(near(classify(rep,effs).roles.damage.amount,20))
rep.abilities[1].effects[1].p2=2
assert(near(classify(rep,effs).roles.damage.amount,80))
rep.abilities[1].effects[1].p2=1
c=classify(rep,effs)
assert(next(c.roles)==nil and not c.approximate)
rep.abilities[1].effects[1].p2=0;rep.abilities[1].effects[1].p1=0
assert(next(classify(rep,effs).roles)==nil)
rep.abilities[1].effects[1].p2=4;rep.abilities[1].effects[1].p1=2
assert(next(classify(rep,effs).roles)==nil)
local repeats=world({['EFF:TESTEFF']=eff,
    ['EFF:TESTREP4']={kind='EFF',resref='TESTREP4',effect=fx(272,{res='TESTEFF',p1=2,p2=4,p3=3,target=1})},
    ['EFF:TESTREPF']={kind='EFF',resref='TESTREPF',effect=fx(272,{res='TESTEFF',p1=2,p2=4,p3=3,p4=2,target=1})}})
c=classify(spl('TESTREPE',{ability({fx(177,{res='TESTREP4',p2=2,duration=10})})}),repeats)
assert(c.approximate and near(c.roles.damage.amount,60))
c=classify(spl('TESTREPE',{ability({fx(177,{res='TESTREPF',p2=2,duration=10})})}),repeats)
assert(near(c.roles.damage.amount,30))
groups=groups+1

-- 333 casts the holder's resref plus B, at level 1 unless parameter 2 gives one.
local charge=spl('TESTSC',{ability({fx(333,{p1=3})})})
local strike=spl('TESTSCB',{ability({fx(12,{dice=1,sides=6})},{minLevel=1}),ability({fx(12,{p1=100})},{minLevel=10})})
local strikes=world({['SPL:TESTSCB']=strike})
c=classify(charge,strikes,{level=15})
assert(near(c.roles.damage.amount,10.5) and c.approximate and c.roles.damage.who.target)
r=c.roles.damage.rolls[1]
assert(#c.roles.damage.rolls==1 and r.dice==1 and r.sides==6 and r.flat==0 and r.times==3)
charge.abilities[1].effects[1].p2=12
assert(near(classify(charge,strikes,{level=1}).roles.damage.amount,300))
charge.abilities[1].effects[1].res='OTHERB'
c=classify(charge,strikes)
assert(c.partial and c.reasons['missing:SPL:OTHERB'])
local long=spl('TESTSCXY',{ability({fx(333,{p1=1})})})
c=classify(long,world({['SPL:TESTSCXY']=long}))
assert(c.approximate and c.reasons['cycle:SPL:TESTSCXY'] and not c.partial)
groups=groups+1

-- Summons, hostile summons and replacing a creature.
local summon=spl('TESTSUM',{ability({fx(67,{res='MONST1',target=1})},{target=5})})
c=classify(summon,world({}))
assert(c.roles.summon.creatures.MONST1==1 and c.roles.summon.count==1 and not c.roles.summon.hostile and c.beneficial)
summon.abilities[1].effects[1].p2=5
assert(classify(summon,world({})).roles.summon.hostile)
c=one(fx(127,{p1=2,p2=6,target=1}),{target=5})
assert(c.roles.summon.count==2 and c.roles.summon.hostile)
assert(not one(fx(127,{p1=2,p2=1,target=1}),{target=5}).roles.summon.hostile)
assert(not c.roles.summon.fromFile)
summon.abilities[1].effects[1].p2=2
c=classify(summon,world({}))
assert(c.roles.summon.fromFile.MONST1 and not c.roles.summon.hostile)
c=one(fx(151,{res='CHICKEN'}))
assert(c.roles.removal.kinds.replace and c.roles.summon.creatures.CHICKEN==1 and c.offensive)
assert(c.roles.summon.fromFile.CHICKEN)
assert(not one(fx(151,{res='CHICKEN',p2=3})).roles.removal)
-- Replacing the caster itself changes its shape: no creature joins.
c=one(fx(151,{res='WOLF',p2=1,target=1}),{target=5})
assert(c.roles.summon.kinds.transform and not c.roles.summon.creatures and not c.roles.summon.kinds.creature)
assert(one(fx(151,{res='WOLF',p2=3,target=1}),{target=5}).roles.summon.creatures.WOLF==1)
groups=groups+1

-- Unknown opcodes are counted; probability windows weigh amounts and chance.
local odd=spl('TESTODD',{ability({fx(999),fx(12,{p1=10,prob1=49}),fx(12,{p1=20,prob2=50}),
    fx(12,{p1=99,prob1=10,prob2=20})})})
c=classify(odd,world({}))
assert(c.unknown[999]==1 and near(c.roles.damage.amount,10*50/101+20*51/101) and near(c.roles.damage.chance,51/101))
groups=groups+1

-- Nothing raises: broken effects, records, abilities and lookups are reported.
c=classify(spl('TESTBAD',{ability({{opcode=12}})}),world({}))
assert(c.partial and c.reasons['bad-effect'])
assert(classify(nil,world({})).reasons['no-record'])
assert(spells.classify(odd,7,world({})).reasons['no-ability'])
local lost=spl('TESTLOST',{ability({fx(146,{res='NOPE'})})})
assert(classify(lost,world({})).reasons['missing:SPL:NOPE'])
assert(classify(lost,function() error('boom') end).reasons['missing:SPL:NOPE'])
assert(classify(lost,function() return 'not a record' end).reasons['missing:SPL:NOPE'])
assert(classify(lost,nil).reasons['missing:SPL:NOPE'])
local saved=spells.limits.effects
spells.limits.effects=3
c=classify(spl('TESTMANY',{ability({fx(12),fx(12),fx(12),fx(12),fx(12)})}),world({}))
spells.limits.effects=saved
assert(c.partial and c.reasons['too-many-effects'])
groups=groups+1

-- The ability for a caster level.
local tiers=spl('TESTLVL',{ability({},{minLevel=1}),ability({},{minLevel=5}),ability({},{minLevel=10})})
assert(spells.abilityForLevel(tiers,7)==2 and spells.abilityForLevel(tiers,0)==1)
assert(spells.abilityForLevel(tiers,5)==2 and spells.abilityForLevel(tiers,20)==3)
assert(spells.abilityForLevel(spl('EMPTY',{}),5)==nil and spells.abilityForLevel(nil,5)==nil)
groups=groups+1

-- Items: a healing potion and a wand whose ability is marked hostile.
local potion=itm('POTN08',9,{ability({fx(17,{p1=10,target=1})},{target=5})})
c=classify(potion,world({}))
assert(c.kind=='ITM' and c.itemType==9 and c.roles.heal.amount==10 and c.roles.heal.who.self)
assert(c.beneficial and not c.offensive and c.hostile==false)
local wand=itm('WAND05',35,{ability({fx(12,{p2=8*65536,dice=6,sides=6,save=8,special=256})},
    {target=4,projectile=99,flags=1024})})
c=classify(wand,world({['PRO:99']=pro()}))
assert(c.hostile and c.roles.damage.who.area and near(c.roles.damage.amount,21) and c.friendlyFire)
assert(c.roles.damage.save.wand and c.roles.damage.saveForHalf)
groups=groups+1

-- The casting slice applies to the caster; role names come sorted.
local cast=spl('TESTCAST',{ability({fx(12,{p1=6})})})
cast.casting={fx(16,{target=1})}
c=classify(cast,world({}))
assert(#c.kinds==2 and c.kinds[1]=='buff' and c.kinds[2]=='damage' and c.roles.buff.who.self)
groups=groups+1

-- Stats with a class-based roll, fatigue, removing a creature, wild magic, turning undead.
assert(one(fx(15,{p2=3,target=1}),{target=5}).roles.buff.kinds.dexterity)
assert(one(fx(44,{p2=3,target=1}),{target=5}).roles.buff.kinds.strength)
assert(next(one(fx(6,{p2=3})).roles)==nil)
c=one(fx(93,{p1=4}))
assert(c.roles.debuff.kinds.fatigue and c.offensive)
assert(one(fx(93,{p2=1})).roles.cure.kinds.fatigue)
assert(one(fx(93,{p1=-2})).roles.buff.kinds.fatigue)
assert(one(fx(93,{p1=150,p2=2})).roles.debuff.kinds.fatigue)
c=one(fx(168))
assert(c.roles.removal.kinds.destroy and c.offensive)
assert(next(one(fx(168,{target=1})).roles)==nil)
assert(one(fx(280,{p2=2})).roles.debuff.kinds.wildSurge)
assert(next(one(fx(280,{p2=2,target=1})).roles)==nil)
c=one(fx(334,{target=1}),{target=5})
assert(c.roles.disable.kinds.turnUndead and c.roles.disable.who.area and c.offensive and not c.selfHarm)
groups=groups+1

-- Items in slots, choosing a spell, bonuses against a creature type, damage percent, AC by
-- damage type, the teleport field and protection from weapons.
c=one(fx(143,{p1=35,res='SWORD1',target=1}),{target=5})
assert(c.roles.buff.kinds.weapon and c.roles.buff.items.SWORD1==35)
assert(one(fx(143,{p1=1,res='PLAT1',target=1}),{target=5}).roles.buff.kinds.armor)
assert(one(fx(143,{p1=15,res='MISC1',target=1}),{target=5}).roles.buff.kinds.item)
c=one(fx(214,{target=1}),{target=5})
assert(c.choice and next(c.unknown)==nil)
c=one(fx(178,{p1=4,p2=4,special=2,target=1}),{target=5})
assert(c.roles.buff.kinds.thac0VsType and c.roles.buff.amounts.thac0VsType==2)
c=one(fx(178,{p1=4,p2=4,special=2^32-2}))
assert(c.roles.debuff.kinds.thac0VsType and c.roles.debuff.amounts.thac0VsType==2)
assert(one(fx(179,{special=3,target=1}),{target=5}).roles.buff.kinds.damageVsType)
assert(one(fx(219,{p1=4,p2=4,target=1}),{target=5}).roles.protection.kinds.armorVsType)
c=one(fx(332,{p1=20,p2=2,target=1}),{target=5})
assert(c.roles.buff.kinds.damagePercent and c.roles.buff.damagePercentBy[2]==20)
c=classify(spl('TESTKAI',{ability({fx(332,{p1=20,p2=7,target=1}),fx(332,{p1=20,p2=8,target=1}),
    fx(332,{p1=20,p2=9,target=1})},{target=5})}),world({}))
local by=c.roles.buff.damagePercentBy
assert(by[7]==20 and by[8]==20 and by[9]==20 and by[0]==nil)
assert(one(fx(332,{p1=-25})).roles.debuff.damagePercentBy[0]==25)
-- THAC0 (opcode 54): a bonus by type 0, the value itself by types 1 and 2, where less is better.
assert(one(fx(54,{p1=2,target=1}),{target=5}).roles.buff.amounts.thac0==2)
assert(one(fx(54,{p1=-2})).roles.debuff.amounts.thac0==2)
c=one(fx(54,{p1=80,p2=2,target=1}),{target=5})
assert(c.roles.buff.kinds.thac0 and c.roles.buff.amounts.thac0Percent==20 and c.roles.buff.amounts.thac0==nil)
assert(one(fx(54,{p1=125,p2=2})).roles.debuff.amounts.thac0Percent==25)
assert(next(one(fx(54,{p1=100,p2=2})).roles)==nil)
c=classify(spl('TESTSET',{ability({fx(54,{p1=6,p2=1,target=1}),fx(54,{p1=-12,p2=1,target=1})},{target=5})}),world({}))
assert(c.roles.buff.thac0Set==-12 and c.roles.debuff==nil)
c=one(fx(54,{p1=20,p2=1}))
assert(c.roles.debuff.thac0Set==20 and c.roles.buff==nil)
-- Critical hits: parameter 2 names the hand, not a type.
assert(one(fx(301,{p1=20,p2=2,target=1}),{target=5}).roles.buff.amounts.critical==20)
c=one(fx(0,{p1=4,p2=2,target=1}),{target=5})
assert(c.roles.protection.kinds.armor and c.roles.protection.amounts.armor==4)
assert(one(fx(0,{p1=-2})).roles.debuff.kinds.armor)
assert(one(fx(222,{p1=160})).roles.debuff.kinds.teleportField)
-- Knock's unlocking, for the engine's door search.
assert(one(fx(125)).roles.unlock.kinds.door)
-- Teleport Field's range, the farthest of its deliveries.
assert(one(fx(222,{p1=160})).roles.debuff.amounts.teleportRange==160)
assert(one(fx(120,{p1=3,target=1}),{target=5}).roles.protection.weapons[0]==3)
assert(one(fx(120,{p2=1,target=1}),{target=5}).roles.protection.weapons[1]==true)
groups=groups+1

-- A spell or sub-spell naming itself filters its own targets; other names are protections.
local own=spl('TESTOWN',{ability({fx(324,{res='TESTOWN',p2=1}),fx(146,{res='TESTOWNB'})})})
local ownSub=spl('TESTOWNB',{ability({fx(318,{res='TESTOWNB',p2=1}),fx(318,{res='OTHER',target=1}),fx(12,{p1=1})})})
c=classify(own,world({['SPL:TESTOWNB']=ownSub}))
local spellsBlocked=c.roles.protection.immuneBy.spells
assert(spellsBlocked.OTHER==1 and spellsBlocked.TESTOWN==nil and spellsBlocked.TESTOWNB==nil)
groups=groups+1

-- Projectiles without a PRO file are built into the engine: their shape is unknown.
assert(one(fx(12,{p1=1}),{projectile=66}).projectileUnknown)
assert(not one(fx(12,{p1=1}),{projectile=1}).projectileUnknown)
assert(spells.neutral[266] and not spells.neutral[321] and not spells.neutral[93] and not spells.neutral[168] and
    not spells.neutral[214])
groups=groups+1

-- Shapechanging oneself is a buff, polymorphing others a disable; a time stop held by the
-- caster freezes everyone else, allies included; positive casting-time values cast faster.
assert(one(fx(135,{res='WEREWOLF',target=1}),{target=5}).roles.buff.kinds.shapechange)
assert(one(fx(135,{res='SQUIRREL'})).roles.disable.kinds.polymorph)
c=one(fx(231,{target=1,duration=14}),{target=5})
assert(c.roles.disable.kinds.timestop and c.roles.disable.who.everyone and not c.roles.disable.who.self)
assert(c.offensive and c.friendlyFire and not c.selfHarm)
assert(one(fx(189,{p1=10,target=1}),{target=5}).roles.buff.kinds.castingSpeed)
assert(one(fx(189,{p1=-2})).roles.debuff.kinds.castingSpeed)
assert(one(fx(189,{p1=0,p2=1,target=1}),{target=5}).roles.buff.kinds.castingSpeed)
assert(one(fx(189,{p1=9,p2=1})).roles.debuff.kinds.castingSpeed)
assert(one(fx(189,{p1=3,p2=2,target=1}),{target=5}).roles.buff.kinds.castingSpeed)
-- Aura cleansing (Improved Alacrity) is a casting-speed buff of its own kind.
c=one(fx(188,{p2=1,target=1,duration=12}),{target=5})
assert(c.roles.buff.kinds.alacrity and c.roles.buff.kinds.castingSpeed and c.roles.buff.who.self)
assert(not one(fx(189,{p1=10,target=1}),{target=5}).roles.buff.kinds.alacrity)
-- Power Word, Kill and Stun work only below 60 and 90 hit points.
assert(one(fx(209)).roles.disable.kinds.death and one(fx(209)).roles.disable.belowHp==60)
assert(one(fx(210)).roles.disable.kinds.stun and one(fx(210)).roles.disable.belowHp==90)
assert(one(fx(13)).roles.disable.belowHp==nil)
-- Power Word, Sleep sleeps below 20 hit points, five rounds whatever its duration says, waking on
-- damage when parameter 2 is 0. Beside a plain sleep with a save (an install's Power Word Sleep that
-- lets stronger creatures save), the role has no limit, whichever comes first.
local pws=one(fx(217,{timing=1})).roles.disable
assert(pws.kinds.sleep and pws.belowHp==20 and pws.duration==30 and pws.wakesOnDamage and not pws.staysAsleep)
assert(one(fx(217,{p2=1})).roles.disable.staysAsleep)
local function both(a,b) return classify(spl('TESTPWS',{ability({a,b})}),world({})).roles.disable end
local mixed=both(fx(217),fx(39,{save=1,duration=30}))
assert(mixed.belowHp==nil and mixed.anyHp and mixed.save.spell and mixed.duration==30)
assert(both(fx(39,{save=1,duration=30}),fx(217)).belowHp==nil)
assert(both(fx(209),fx(217)).belowHp==60)
-- Bits above 4 of the save type are flags, not saves.
c=one(fx(12,{p1=1,save=2^24+2^10}))
assert(c.roles.damage.save==nil)
groups=groups+1

-- The opcodes that reach others, sub-spells included; what stays on the caster is left out.
local holdSub=spl('TESTHLDB',{ability({fx(175,{p2=3,p1=2}),fx(142,{p2=13})})})
c=classify(spl('TESTHLD',{ability({fx(146,{res='TESTHLDB'}),fx(18,{p1=5,target=1})})}),
    world({['SPL:TESTHLDB']=holdSub}))
assert(c.opcodes[146] and c.opcodes[175] and c.opcodes[142] and not c.opcodes[18])
assert(next(one(fx(18,{p1=5,target=1}),{target=5}).opcodes)==nil)
groups=groups+1

-- A short pause of the caster (a cone's two seconds) is a casting cost, not self-harm; a long
-- one still harms the caster.
c=classify(spl('TESTCONE',{ability({fx(165,{target=1,duration=2}),fx(12,{p1=10})},{target=4,projectile=97})}),
    world({['PRO:97']=pro({areaFlags=2048,coneWidth=60})}))
assert(c.pause==2 and not c.selfHarm and c.offensive and not c.roles.disable and c.area.cone==60)
c=classify(spl('TESTLONG',{ability({fx(165,{target=1,duration=30}),fx(12,{p1=10})})}),world({}))
assert(c.selfHarm and c.roles.disable.kinds.pause and c.pause==nil)
c=one(fx(165,{duration=2}))
assert(c.roles.disable.kinds.pause and c.roles.disable.who.target and c.pause==nil)
groups=groups+1

-- Conditions belong to what they deliver. SCS's troll extra on an acid arrow: everyone takes
-- the acid, trolls a little more. Spell Revisions' charms: elves keep nine charms in ten out,
-- with an immunity to the charm opcode (Dire Charm) or with the charm's sub-spell protecting
-- them from itself (DVHCHRM); its fear spares the undead with a protection from the parent
-- spell. A hold that names a creature type holds that type only. A delivery's saving throw goes
-- to what it brings (Charm Person saves on its 177s).
local function only(...)
    local wanted={...}
    return function(f)
        for _,x in ipairs(wanted) do if f.ids==x.ids and f.entry==x.entry then return true end end
        return false
    end
end
local troll,elf,undead,humanoid={ids=4,entry=129},{ids=4,entry=2},{ids=3,entry=4},{ids=3,entry=1}
local evil,notEvil={ids=2,entry=200},{ids=2,entry=199}
local sr=world({
    ['EFF:TESTTRLX']={kind='EFF',resref='TESTTRLX',effect=fx(146,{res='TESTTRLS',p2=1})},
    ['SPL:TESTTRLS']=spl('TESTTRLS',{ability({fx(12,{p1=1,p2=65536})})}),
    ['EFF:TESTELF']={kind='EFF',resref='TESTELF',effect=fx(101,{p2=5,duration=1})},
    ['EFF:TESTSELF']={kind='EFF',resref='TESTSELF',effect=fx(206,{res='TESTCHRB'})},
    ['SPL:TESTCHRB']=spl('TESTCHRB',{ability({fx(177,{p1=2,p2=4,prob1=89,res='TESTSELF'}),fx(5,{duration=30})})}),
    ['EFF:TESTCHRE']={kind='EFF',resref='TESTCHRE',effect=fx(146,{res='TESTCHRB',p2=1})},
    ['EFF:TESTUND']={kind='EFF',resref='TESTUND',effect=fx(206,{res='TESTFEAR'})},
    ['SPL:TESTFERD']=spl('TESTFERD',{ability({fx(177,{p1=4,p2=3,res='TESTUND'}),fx(24,{duration=30,save=1})})}),
})
local nine=90/101
c=classify(spl('TESTACID',{ability({fx(12,{p2=65536,dice=2,sides=4}),fx(177,{p1=129,p2=4,res='TESTTRLX'})})}),sr)
assert(c.conditional and #c.conditions==1 and c.conditions[1].ids==4 and c.conditions[1].entry==129)
assert(near(c.roles.damage.amount,6) and near(spells.common(c).damage.amount,5))
assert(near(spells.view(c,only(troll)).damage.amount,6))
-- Dire Charm: an elf is immune to the charm opcode, nine times in ten, before the charm comes.
c=classify(spl('TESTDIRE',{ability({fx(177,{p1=2,p2=4,prob1=89,res='TESTELF'}),fx(5,{duration=60,save=1,saveBonus=-9})})}),sr)
assert(c.roles.disable.kinds.charm and not c.roles.protection and not c.beneficial)
assert(near(spells.common(c).disable.chance,1) and near(spells.view(c,only(elf)).disable.chance,1-nine))
-- Charm Person: the evil side saves at -5, the rest at -9; an elf of either side is also
-- protected by the charm's own sub-spell. A creature of neither side is not charmed at all.
c=classify(spl('TESTCHRM',{ability({fx(177,{p1=200,p2=2,save=1,saveBonus=-5,res='TESTCHRE'}),
    fx(177,{p1=199,p2=2,save=1,saveBonus=-9,res='TESTCHRE'})})}),sr)
local v=spells.view(c,only(evil))
assert(v.disable.kinds.charm and v.disable.save.spell and v.disable.saveBonus==-5 and near(v.disable.chance,1))
assert(spells.view(c,only(notEvil)).disable.saveBonus==-9 and near(spells.view(c,only(evil,elf)).disable.chance,1-nine))
assert(spells.common(c).disable==nil and c.roles.disable.saveBonus==-9)
-- Horror's sub-spell: the undead get a protection from the parent spell before the fear.
c=classify(spl('TESTFEAR',{ability({fx(146,{res='TESTFERD',p2=1})})}),sr)
assert(spells.common(c).disable.kinds.panic and spells.view(c,only(undead)).disable==nil and not c.beneficial)
-- A hold of humanoids holds humanoids; a view is kept by its key.
c=classify(spl('TESTHPER',{ability({fx(175,{p1=1,p2=3,duration=60,save=1})})}),sr)
assert(c.roles.disable.kinds.hold and #c.conditions==1 and c.conditions[1].ids==3 and c.conditions[1].entry==1)
assert(spells.view(c,only(humanoid)).disable.kinds.hold and spells.common(c).disable==nil)
assert(spells.view(c,only(humanoid))==spells.view(c,only(humanoid)))
-- An unjudged condition brings nothing and cuts nothing; the key marks it.
local roles,key=spells.view(c,function() return nil end)
assert(roles.disable==nil and key=='?')
c=classify(spl('TESTDIR2',{ability({fx(177,{p1=2,p2=4,res='TESTELF'}),fx(5,{duration=60})})}),sr)
roles,key=spells.view(c,function() error('unreadable') end)
assert(roles.disable.kinds.charm and near(roles.disable.chance,1) and key=='?')
-- Without conditions there is nothing to replay: every creature gets the spell's roles.
c=one(fx(12,{p1=1}))
assert(c.conditions==nil and c.log==nil and spells.view(c,no)==c.roles and select(2,spells.view(c,no))=='')
groups=groups+1

-- A spell's own immunity check: a 318 or 324 that names the spell, or a spell it comes through,
-- with a SPLPROT row keeps creatures that meet the row out of what follows (Spell Revisions
-- starts most spells with one; its charms check spell state 41). Row 0 without a condition is
-- the guard against stacking. 326 applies its spell only to creatures that meet its row, and
-- EEex swaps the row's source and target with special bit 0.
local function rows(...)
    local wanted={...}
    return function(f)
        for _,x in ipairs(wanted) do if spells.conditionKey(f)==spells.conditionKey(x) then return true end end
        return false
    end
end
c=classify(spl('TESTSRCH',{ability({fx(324,{res='TESTSRCH',p2=110,p1=41,duration=1}),fx(5,{duration=60,save=1}),
    fx(318,{res='TESTSRCH',duration=6})})}),world({}))
assert(#c.conditions==1 and spells.conditionKey(c.conditions[1])=='row:110:41')
assert(spells.common(c).disable.kinds.charm and spells.view(c,rows({row=110,value=41})).disable==nil)
assert(not c.roles.protection and not c.beneficial)
-- The check in a sub-spell that names its parent (Spell Revisions' Fireball, row 186).
local fireSub=spl('TESTFIRD',{ability({fx(324,{res='TESTFIRE',p2=186,duration=1}),fx(12,{p2=8*65536,dice=5,sides=6})})})
c=classify(spl('TESTFIRE',{ability({fx(146,{res='TESTFIRD',p2=1})})}),world({['SPL:TESTFIRD']=fireSub}))
assert(near(spells.common(c).damage.amount,17.5) and spells.view(c,rows({row=186,value=0})).damage==nil)
local extra=spl('TESTXTRA',{ability({fx(12,{p1=10})})})
c=classify(spl('TESTAPPL',{ability({fx(12,{p1=5}),fx(326,{res='TESTXTRA',p2=104,p1=2,special=1})})}),
    world({['SPL:TESTXTRA']=extra}))
assert(c.conditional and spells.conditionKey(c.conditions[1])=='row:104:2:flip')
assert(spells.common(c).damage.amount==5 and spells.view(c,rows({row=104,value=2,flip=true})).damage.amount==15)
c=classify(spl('TESTAPP0',{ability({fx(326,{res='TESTXTRA'})})}),world({['SPL:TESTXTRA']=extra}))
assert(c.conditions==nil and c.roles.damage.amount==10)
groups=groups+1

-- The defence slice's reads. Improved Invisibility is invisibility attacks do not break; Spell
-- Deflection (201) takes single-target spells and wears down, globes (102) keep out every spell
-- of their levels. Effects that come long after the cast are kept apart: Spell Revisions' Haste
-- casts its fatigue on its receivers when it ends, which is not what Haste does now.
c=one(fx(20,{target=1,p2=1,duration=60}),{target=5})
assert(c.roles.protection.kinds.invisible and c.roles.protection.kinds.improvedInvisible)
c=one(fx(20,{target=1,duration=60}),{target=5})
assert(c.roles.protection.kinds.invisible and not c.roles.protection.kinds.improvedInvisible)
c=classify(spl('TESTDEFL',{ability({fx(201,{target=1,p1=9,p2=6,duration=60}),fx(102,{target=1,p1=3,duration=60})},
    {target=5})}),world({}))
local prot=c.roles.protection
assert(prot.kinds.deflect and prot.deflectBy.levels[6]==9 and prot.kinds.immune and prot.immuneBy.levels[3]==1)
assert(prot.immuneBy.levels[6]==nil)
local fatigue=spl('TESTHASD',{ability({fx(0,{p1=-2,duration=18}),fx(54,{p1=-2,duration=18})})})
local haste=spl('TESTHAST',{ability({fx(1,{p1=1,duration=144}),fx(176,{p1=6,duration=144}),
    fx(146,{res='TESTHASD',p2=1,timing=4,duration=144}),fx(206,{res='TESTHAST',duration=144})},{target=4,projectile=99})})
c=classify(haste,world({['SPL:TESTHASD']=fatigue,['PRO:99']=pro({areaFlags=64+128})}))
assert(c.roles.buff.kinds.attacks and c.roles.buff.kinds.movement and c.roles.debuff==nil and c.roles.protection==nil)
assert(c.later.debuff.kinds.armor and c.later.debuff.amounts.armor==2 and c.later.debuff.kinds.thac0 and not c.partial)
assert(c.opcodes[0]==nil and c.opcodes[54]==nil and c.opcodes[1] and c.beneficial and not c.offensive)
-- A short wait is still now: a cast two seconds in counts with the spell.
haste.abilities[1].effects[3].duration=2
c=classify(haste,world({['SPL:TESTHASD']=fatigue,['PRO:99']=pro({areaFlags=64+128})}))
assert(c.later==nil and c.roles.debuff.kinds.thac0)
groups=groups+1

-- Spell Revisions' Recitation: the caster casts two sub-spells, the blessing through an
-- allies-only area, the curse through an enemies-only one. Each area role names its side.
local bless=spl('TESTRECG',{ability({fx(54,{p1=2,duration=120})},{target=4,projectile=337})})
local curse=spl('TESTRECB',{ability({fx(54,{p1=-2,duration=120})},{target=4,projectile=338})})
c=classify(spl('TESTRECI',{ability({fx(146,{target=1,res='TESTRECG',p2=1}),fx(146,{target=1,res='TESTRECB',p2=1})},
    {target=5})}),world({['SPL:TESTRECG']=bless,['SPL:TESTRECB']=curse,
    ['PRO:337']=pro({areaFlags=192,radius=512}),['PRO:338']=pro({areaFlags=64,radius=426})}))
assert(c.roles.buff.who.area and c.roles.buff.filters.allies and not c.roles.buff.filters.enemies)
assert(c.roles.debuff.who.area and c.roles.debuff.filters.enemies and not c.roles.debuff.filters.allies)
c=classify(fireball,world({['PRO:99']=pro({radius=480})}))
assert(c.roles.damage.filters.all)
groups=groups+1

-- Weapons a spell puts in the caster's hand (opcode 111, D2c), read from the created item's
-- first ability. A hand like Spell Revisions' Harm: its one hit (the hand takes itself away with
-- opcode 112) casts 90 magic damage that leaves at least 1 hit point, unless the target's race
-- makes it immune (opcode 324, SPLPROT row 104).
local function weaponAbility(fields)
    local a={attackType=1,idRequired=0,location=1,target=1,targetCount=0,range=1,launcher=0,speed=0,
        thac0=0,sides=0,school=0,dice=0,secondary=0,damageBonus=0,damageType=2,charges=0,depletion=0,
        flags=0,projectile=1,isArrow=0,isBolt=0,isBullet=0,effects={}}
    for k,v in pairs(fields) do a[k]=v end
    return a
end
local harmHit=spl('TESTHRMD',{ability({fx(208,{p1=1,duration=1}),fx(12,{p1=90,p2=64*65536,timing=1})},
    {range=1,speed=0})})
local hand=itm('TESTHRM',28,{weaponAbility({thac0=4,charges=1,depletion=1,effects={
    fx(324,{p1=156,p2=104,res='TESTHRM'}),fx(146,{res='TESTHRMD'}),fx(112,{target=1,res='TESTHRM',timing=1})}})})
local harm=spl('TESTHARM',{ability({fx(111,{target=1,p1=1,res='TESTHRM',duration=60})},{target=5,range=1,speed=6})})
local harmWorld=world({['ITM:TESTHRM']=hand,['SPL:TESTHRMD']=harmHit})
c=classify(harm,harmWorld,{level=12})
local w=c.weapons[1]
assert(#c.weapons==1 and w.item=='TESTHRM' and w.attack=='melee' and w.uses==1 and w.touch==true)
assert(w.toHit==4 and w.seconds==60 and w.range==1 and not c.partial)
assert(c.roles.buff.kinds.weapon and c.roles.damage==nil)
assert(w.strike.roles.damage.who.target and w.strike.roles.damage.types.magic==90 and not w.strike.partial)
assert(w.strike.conditions and w.strike.conditions[1].row==104 and w.strike.conditions[1].value==156)
-- The race that is immune keeps nothing of the hit; others take it.
local immune=spells.view(w.strike,function() return true end)
assert(immune.damage==nil)
assert(spells.view(w.strike,function() return false end).damage.types.magic==90)
-- The adapter asks about the strike's rows too.
local rows=spells.rows(c)
assert(rows[spells.conditionKey(w.strike.conditions[1])])
-- Melf's Minute Meteors as Spell Revisions makes them: five at level 5, each thrown once (one
-- charge that vanishes), 2d4 fire. Not a touch: they last five hits.
local meteor=itm('TESTMET',24,{weaponAbility({attackType=2,range=30,thac0=5,charges=1,depletion=1,
    effects={fx(12,{dice=2,sides=4,p2=8*65536,timing=1})}})})
c=classify(spl('TESTMMM',{ability({fx(111,{target=1,p1=5,res='TESTMET',duration=50})},{target=5,range=1})}),
    world({['ITM:TESTMET']=meteor}),{level=5})
w=c.weapons[1]
assert(w.attack=='ranged' and w.uses==5 and w.touch==nil and w.range==30 and w.seconds==50)
assert(w.strike.roles.damage.types.fire==5)
-- A blade with no charges lasts as long as the item (uses nil); an item that cannot be read
-- leaves the spell partial and no weapon.
local blade=itm('TESTBLD',20,{weaponAbility({dice=1,sides=8,effects={fx(12,{dice=1,sides=6,p2=8*65536,timing=1})}})})
c=classify(spl('TESTBLAD',{ability({fx(111,{target=1,p1=1,res='TESTBLD',duration=240})},{target=5})}),
    world({['ITM:TESTBLD']=blade}))
assert(c.weapons[1].uses==nil and c.weapons[1].touch==nil and c.weapons[1].dice==1 and c.weapons[1].sides==8)
assert(c.weapons[1].itemType==20)
c=classify(spl('TESTLOST',{ability({fx(111,{target=1,p1=1,res='TESTNONE',duration=60})},{target=5})}),world({}))
assert(c.weapons==nil and c.partial and c.reasons['missing:ITM:TESTNONE'])
-- An empty item reference creates nothing: no weapon, and nothing is missing. A kit mod's Shocking
-- Grasp gives one kit (SPLPROT row 418) the charge in the fist instead, through a spell whose 111
-- names no item.
local fist=spl('TESTFIST',{ability({fx(111,{}),fx(248,{duration=120,res='TESTFIST'})})})
c=classify(spl('TESTGRSP',{ability({fx(111,{target=1,p1=1,res='TESTBLD',duration=60}),
    fx(326,{target=1,p1=16441,p2=418,res='TESTFIST'})},{target=5,range=1})}),
    world({['ITM:TESTBLD']=blade,['SPL:TESTFIST']=fist}))
assert(not c.partial and #c.weapons==1 and c.weapons[1].item=='TESTBLD' and c.roles.buff.kinds.onHit)
c=classify(spl('TESTNULL',{ability({fx(111,{target=1})},{target=5})}),world({}))
assert(not c.partial and c.weapons==nil and c.roles.buff==nil)
-- Read without weapons (options.weapons=false), as a strike is.
c=classify(harm,harmWorld,{weapons=false})
assert(c.weapons==nil and c.roles.buff.kinds.weapon)
groups=groups+1

-- On-hit effects (F2a): opcode 248 lands its EFF on each creature a melee hit strikes, 249 on each
-- a missile strikes; the EFF is read as cast at the creature hit (strike), apart from the spell's
-- own roles. A Smite Evil whose hit casts 1d6 magic damage and takes the smite off its holder
-- (opcode 321 on the smite) lasts one hit (once).
local smiteHit=spl('TESTSMHT',{ability({fx(321,{target=1,res='TESTSMIT',timing=1}),
    fx(12,{p2=64*65536,dice=1,sides=6,timing=1})})})
local hitWorld={['EFF:TESTSMEF']={kind='EFF',resref='TESTSMEF',effect=fx(146,{p2=1,res='TESTSMHT',timing=1})},
    ['SPL:TESTSMHT']=smiteHit}
local smite=spl('TESTSMIT',{ability({fx(248,{target=1,duration=12,res='TESTSMEF'})},{target=5,range=1})})
c=classify(smite,world(hitWorld))
local h=c.hits[1]
assert(not c.partial and #c.hits==1 and c.roles.buff.kinds.onHit and c.roles.damage==nil)
assert(h.melee and not h.ranged and h.fists==nil and h.who=='self' and h.seconds==12 and h.once==true and h.eff=='TESTSMEF')
assert(h.strike.roles.damage.who.target and near(h.strike.roles.damage.types.magic,3.5))
assert(h.strike.roles.strips.who.self and h.strike.roles.strips.res.TESTSMIT)
-- The hit takes the whole smite off, so its buff lasts until that hit lands (untilHit).
assert(c.roles.buff.untilHit==true)
-- Artisan's Kitpack's Ki Strike (Kensai Overhaul): luck 20 for base weapon damage for a round (opcode 250: every die at its top,
-- no flat damage), a critical bonus set to last (timing 9), and a hit that takes the strike off
-- again: all of it lasts until that hit lands. A bad-luck spell (250 below 0) is a debuff.
hitWorld['EFF:TESTKIEF']={kind='EFF',resref='TESTKIEF',effect=fx(146,{p2=1,res='TESTKIHT',timing=1})}
hitWorld['SPL:TESTKIHT']=spl('TESTKIHT',{ability({fx(321,{target=1,res='TESTKIST',timing=1})})})
c=classify(spl('TESTKIST',{ability({fx(250,{target=1,p1=20,duration=6}),fx(301,{target=1,p1=2,timing=9}),
    fx(248,{target=1,duration=6,res='TESTKIEF'})},{target=5,range=1})}),world(hitWorld))
assert(c.roles.buff.amounts.damageLuck==20 and c.roles.buff.amounts.critical==2 and c.roles.buff.amounts.damage==nil)
assert(c.roles.buff.kinds.damageLuck and c.roles.buff.duration=='permanent' and c.roles.buff.untilHit==true)
assert(c.hits[1].once==true)
c=classify(spl('TESTCURS',{ability({fx(250,{target=2,p1=-3,duration=12})},{target=1})}),world({}))
assert(c.roles.debuff.amounts.damageLuck==3 and c.roles.buff==nil)
-- A poisoned blade and arrows: every hit poisons (no once), 249 for missiles; fists only by bit 2.
hitWorld['EFF:TESTPSEF']={kind='EFF',resref='TESTPSEF',effect=fx(12,{p1=4,p2=32*65536,timing=1})}
c=classify(spl('TESTPOIS',{ability({fx(248,{target=1,duration=30,res='TESTPSEF'}),
    fx(249,{target=1,duration=30,res='TESTPSEF'}),fx(248,{target=1,duration=30,p2=4,res='TESTPSEF'})},{target=5})}),
    world(hitWorld))
assert(#c.hits==3 and c.hits[1].melee and c.hits[2].ranged and not c.hits[2].melee and c.hits[3].fists==true)
assert(c.hits[1].once==false and c.hits[1].strike.roles.damage.types.poison==4 and c.roles.buff.untilHit==nil)
-- An on-hit effect that comes through another spell is spent by a hit that takes off the spell
-- holding it, not the one that cast that spell (opcode 321 matches an effect's own source).
hitWorld['SPL:TESTKITB']=spl('TESTKITB',{ability({fx(248,{target=1,duration=12,res='TESTKTEF'})},{target=5})})
hitWorld['EFF:TESTKTEF']={kind='EFF',resref='TESTKTEF',effect=fx(146,{p2=1,res='TESTKTHT',timing=1})}
hitWorld['SPL:TESTKTHT']=spl('TESTKTHT',{ability({fx(321,{target=1,res='TESTKITB',timing=1}),fx(45,{duration=12})})})
local kit=spl('TESTKIT',{ability({fx(146,{target=1,p2=1,res='TESTKITB'})},{target=5})})
c=classify(kit,world(hitWorld))
assert(c.hits[1].once==true and c.hits[1].strike.roles.disable.kinds.stun)
hitWorld['SPL:TESTKTHT'].abilities[1].effects[1].res='TESTKIT'
assert(classify(kit,world(hitWorld)).hits[1].once==false)
-- All on-hit effects of one spell go together: one whose hit ends the spell spends the others too
-- (a kit's Poison Weapon poisons with one and ends with another); another spell's stay.
hitWorld['EFF:TESTENEF']={kind='EFF',resref='TESTENEF',effect=fx(146,{p2=1,res='TESTENHT',timing=1})}
hitWorld['SPL:TESTENHT']=spl('TESTENHT',{ability({fx(321,{target=1,res='TESTPWPN',timing=1})})})
c=classify(spl('TESTPWPN',{ability({fx(248,{target=1,duration=30,res='TESTPSEF'}),fx(248,{target=1,duration=30,res='TESTENEF'})},
    {target=5})}),world(hitWorld))
assert(c.hits[1].once==true and c.hits[2].once==true and c.hits[1].own==nil and c.hits[1].ends==nil)
c=classify(spl('',{ability({fx(248,{target=1,duration=30,res='TESTPSEF',source='TESTPWPN'}),
    fx(248,{target=1,duration=30,res='TESTENEF',source='TESTPWPN'}),fx(248,{target=1,duration=30,res='TESTPSEF',source='TESTFURY'})},
    {target=5})}),world(hitWorld))
assert(c.hits[1].once==true and c.hits[2].once==true and c.hits[3].once==false)
-- An active effect read from a creature names the spell it comes from (sense.guard).
local active=spl('',{ability({fx(248,{target=1,timing=0,duration=10,res='TESTSMEF',source='TESTSMIT'})},{target=5})})
c=classify(active,world(hitWorld))
assert(c.hits[1].once==true and c.hits[1].who=='self')
active.abilities[1].effects[1].source=nil
assert(classify(active,world(hitWorld)).hits[1].once==false)
-- An EFF that cannot be read leaves the spell whole and the hit unknown; a strike is read without
-- on-hit effects (options.weapons=false).
c=classify(spl('TESTLSTH',{ability({fx(248,{target=1,duration=12,res='TESTNONE'})},{target=5})}),world({}))
assert(not c.partial and c.approximate and c.reasons['missing:EFF:TESTNONE'] and c.hits==nil and c.roles.buff.kinds.onHit)
assert(classify(smite,world(hitWorld),{weapons=false}).hits==nil)
-- The adapter asks about the SPLPROT rows of what a hit brings.
smiteHit.abilities[1].effects[3]=fx(324,{p1=156,p2=104,res='TESTSMHT'})
c=classify(smite,world(hitWorld))
assert(c.hits[1].strike.conditions[1].row==104 and spells.rows(c)[spells.conditionKey(c.hits[1].strike.conditions[1])])
groups=groups+1

-- A release (SCS's sequencers and triggers, D2b): an innate that casts two or more spells at its
-- target at once and lands nothing else there. It reaches as far as its shortest spell, not the
-- range written on it, and its spells come together. One spell cast through an innate, a spell
-- that is no innate, and an innate that also lands an effect itself are no releases.
local arrow=spl('TESTARW',{ability({fx(12,{p2=64*65536,dice=2,sides=4})},{range=30,projectile=69})},{level=2})
local bolt3=spl('TESTBLT',{ability({fx(12,{p2=8*65536,dice=3,sides=6})},{range=20})},{level=3})
local parts=world({['SPL:TESTARW']=arrow,['SPL:TESTBLT']=bolt3,['PRO:69']=SINGLE})
local function innate(resref,effects,fields)
    return spl(resref,{ability(effects,{range=5,speed=0})},fields or {spellType=4})
end
local twice={fx(146,{p2=1,res='TESTARW'}),fx(146,{p2=1,res='TESTARW'}),fx(172,{target=1,res='TESTSEQ'}),
    fx(171,{target=1,timing=4,duration=1440,res='TESTSEQ'})}
c=classify(innate('TESTSEQ',twice),parts,{level=12})
assert(c.release and c.range==30 and c.ownRange==5 and c.roles.damage.who.target and near(c.roles.damage.amount,10))
c=classify(innate('TESTSEQ',{fx(146,{p2=1,res='TESTARW'}),fx(146,{p2=1,res='TESTBLT'})}),parts,{level=12})
assert(c.release and c.range==20)
c=classify(innate('TESTONE',{fx(146,{p2=1,res='TESTARW'})}),parts)
assert(not c.release and c.range==5)
c=classify(innate('TESTSEQ',{fx(146,{p2=1,res='TESTARW'}),fx(146,{p2=1,res='TESTBLT'})},{spellType=1}),parts)
assert(not c.release and c.range==5)
c=classify(innate('TESTSEQ',{fx(146,{p2=1,res='TESTARW'}),fx(146,{p2=1,res='TESTBLT'}),fx(12,{dice=1,sides=4})}),parts)
assert(not c.release and c.range==5)
groups=groups+1

-- A spell that ends its own condition. Spell Revisions' Greater Command: the target sleeps for
-- 60 seconds, and a spell cast at it every 6 seconds wakes it on a successful save: on a failed
-- save its protection from itself keeps its cure off and it casts the next one. The waking is no
-- cure; the sleep keeps its 60 seconds and a save every 6 to break free, in each creature's view
-- too (the immunity makes a view).
local wake2=spl('TESTGCB',{ability({fx(206,{duration=2,res='TESTGCB',save=1,saveBonus=-4}),fx(2,{duration=1})})})
local wake1=spl('TESTGCA',{ability({fx(146,{p2=1,timing=4,duration=6,res='TESTGCB',save=1,saveBonus=-4}),
    fx(206,{duration=2,res='TESTGCA',save=1,saveBonus=-4}),fx(2,{duration=1})})})
local sleeps=spl('TESTGCJ',{ability({fx(324,{p1=41,p2=110,duration=1,res='TESTGC'}),fx(39,{duration=60,save=1,saveBonus=-4}),
    fx(146,{p2=1,timing=4,duration=6,res='TESTGCA',save=1,saveBonus=-4})})})
local nap=spl('TESTNAP',{ability({fx(39,{duration=60})})})
local alarm=spl('TESTALRM',{ability({fx(2,{duration=1})})})
local gc=world({['SPL:TESTGCJ']=sleeps,['SPL:TESTGCA']=wake1,['SPL:TESTGCB']=wake2,['SPL:TESTNAP']=nap,
    ['SPL:TESTALRM']=alarm})
c=classify(spl('TESTGC',{ability({fx(146,{p2=1,timing=1,res='TESTGCJ'})})}),gc,{level=12})
local bf=c.roles.disable.breakFree
assert(c.roles.cure==nil and c.roles.disable.kinds.sleep and c.roles.disable.duration==60 and c.roles.disable.wakesOnDamage)
assert(bf and bf.every==6 and bf.save.spell and bf.saveBonus==-4 and not c.approximate)
assert(c.later==nil or c.later.cure==nil)
local slept=spells.view(c,function() return false end)
assert(slept.cure==nil and slept.disable.duration==60 and slept.disable.breakFree.every==6)
-- A waking that comes for sure ends the sleep then.
c=classify(spl('TESTSURE',{ability({fx(39,{duration=60}),fx(146,{p2=1,timing=4,duration=6,res='TESTALRM'})})}),gc)
assert(c.roles.cure==nil and c.roles.disable.duration==6 and c.roles.disable.breakFree==nil)
-- What else follows such a protection comes only on a save: it is left out.
c=classify(spl('TESTHALF',{ability({fx(12,{p2=0,dice=6,sides=6,save=1}),fx(206,{duration=1,res='TESTHALF',save=1}),
    fx(12,{p2=0,dice=3,sides=6})})}),world({}))
assert(near(c.roles.damage.amount,21) and c.approximate and c.reasons['on-save:TESTHALF'])
-- A protection from itself without a save of its own is no such protection, also when its
-- delivery has one.
local keep=spl('TESTKEEP',{ability({fx(206,{duration=1,res='TESTKEEP'}),fx(12,{p2=0,dice=3,sides=6})})})
c=classify(spl('TESTDLV',{ability({fx(146,{p2=1,res='TESTKEEP',save=1})})}),world({['SPL:TESTKEEP']=keep}))
assert(near(c.roles.damage.amount,10.5) and not c.approximate)
-- Waking the caster, or waking the target first and putting it to sleep later, is a cure.
c=classify(spl('TESTSELF',{ability({fx(39,{duration=60}),fx(146,{target=1,p2=1,timing=4,duration=6,res='TESTGCB'})})}),gc)
assert(c.roles.cure.who.self and c.roles.disable.duration==60)
c=classify(spl('TESTFIRST',{ability({fx(2,{duration=1}),fx(146,{p2=1,timing=4,duration=6,res='TESTNAP'})})}),gc)
assert(c.roles.cure.kinds.sleep and c.roles.disable.duration==60)
groups=groups+1

-- What 321 takes away, by the resource that put it there (strips.res, upper case), is no kind
-- of its own and neither harms nor helps. SCS's fire spells take troll regeneration away from
-- trolls only, through a 177 for the troll race. Death by opcode 13 does not slay (a minimum
-- keeps it out); 55, 209 and 238 do.
c=one(fx(321,{res='dwtrrg2'}))
assert(c.roles.strips.who.target and c.roles.strips.res.DWTRRG2 and #c.kinds==0)
assert(not c.beneficial and not c.offensive and not c.selfHarm)
local regen=world({
    ['EFF:TESTTFI']={kind='EFF',resref='TESTTFI',effect=fx(146,{res='TESTTROL',p2=1})},
    ['SPL:TESTTROL']=spl('TESTTROL',{ability({fx(321,{res='TESTRG2'}),fx(321,{res='TESTRG4'}),
        fx(177,{timing=4,res='TESTTFX'})})}),
    ['EFF:TESTTFX']={kind='EFF',resref='TESTTFX',effect=fx(146,{res='TESTTFD',p2=1})},
    ['SPL:TESTTFD']=spl('TESTTFD',{ability({fx(12,{p1=1,p2=8*65536})})}),
})
c=classify(spl('TESTFIRE',{ability({fx(177,{p1=129,p2=4,res='TESTTFI'}),fx(12,{p2=8*65536,dice=6,sides=6})})}),regen)
local onTroll=spells.view(c,only(troll))
assert(onTroll.strips.res.TESTRG2 and onTroll.strips.res.TESTRG4 and near(onTroll.damage.amount,22))
assert(spells.common(c).strips==nil and near(spells.common(c).damage.amount,21))
assert(#c.kinds==1 and c.kinds[1]=='damage' and c.offensive and not c.beneficial)
assert(one(fx(13,{})).roles.disable.kinds.death and not one(fx(13,{})).roles.disable.slays)
for _,op in ipairs({55,209,238}) do assert(one(fx(op,{})).roles.disable.kinds.death and one(fx(op,{})).roles.disable.slays) end
assert(one(fx(209,{})).roles.disable.belowHp==60)
groups=groups+1

-- Levels (IESDP; GemRB's CheckLevel). A spell's or item's effect keeps the levels it reaches in
-- its dice fields (sides the lowest, dice the highest), an EFF file in fields of its own, where its
-- dice are only dice. Effects that roll their dice reach any level: damage, healing, maximum hit
-- points, Stoneskin's skins by dice (parameter 2 at 1), 331 and 333. Each creature sees what
-- reaches its level (view), so the tiers of one spell stay apart.
local function atLevel(n)
    return function(f)
        if f.minLevel==nil and f.maxLevel==nil then return false end
        return not ((f.minLevel and n<f.minLevel) or (f.maxLevel and n>f.maxLevel))
    end
end
c=classify(spl('TESTTIER',{ability({fx(13,{dice=4}),fx(45,{dice=8,sides=5,duration=12}),fx(12,{dice=2,sides=6})})}),world({}))
local low,mid,high=spells.view(c,atLevel(3)),spells.view(c,atLevel(6)),spells.view(c,atLevel(10))
assert(low.disable.kinds.death and not low.disable.kinds.stun and low.disable.maxLevel==4 and low.disable.minLevel==nil)
assert(mid.disable.kinds.stun and not mid.disable.kinds.death and mid.disable.minLevel==5 and mid.disable.maxLevel==8)
assert(high.disable==nil and near(high.damage.amount,7) and near(low.damage.amount,7) and c.conditional)
local r=one(fx(98,{p1=6,dice=12,sides=8})).roles.buff
assert(r.kinds.regeneration and r.minLevel==8 and r.maxLevel==12)
assert(one(fx(25,{p1=1,duration=6,dice=6})).roles.damage.maxLevel==6)
assert(one(fx(331,{p1=1,dice=1,sides=2})).roles.summon.maxLevel==nil)
r=one(fx(218,{p1=4,dice=10})).roles.protection
assert(r.stoneskin==4 and r.maxLevel==10)
r=one(fx(218,{p2=1,dice=1,sides=4})).roles.protection
assert(near(r.stoneskin,2.5) and r.maxLevel==nil and r.minLevel==nil)
-- An EFF's own levels: Deathblow's hit slays up to level 10; its dice say nothing about levels.
local levelWorld={['EFF:TESTDBEF']={kind='EFF',resref='TESTDBEF',effect=fx(55,{p2=2,minLevel=0,maxLevel=10,dice=19,sides=2})},
    ['SPL:TESTCSSL']=spl('TESTCSSL',{ability({fx(39,{duration=12})})}),
    ['SPL:TESTTIRA']=spl('TESTTIRA',{ability({fx(45,{duration=6})})}),
    ['SPL:TESTTIRB']=spl('TESTTIRB',{ability({fx(13,{})})})}
c=classify(spl('TESTDB',{ability({fx(248,{target=1,duration=12,res='TESTDBEF'})},{target=5})}),world(levelWorld))
local strike=c.hits[1].strike
assert(spells.view(strike,atLevel(1)).disable.slays and spells.view(strike,atLevel(10)).disable.kinds.death)
assert(spells.view(strike,atLevel(11)).disable==nil and strike.roles.disable.maxLevel==10)
-- A delivery reaches only creatures within its levels, and so does what it brings: a sleep for
-- level 1 through a 146 and a blindness up to level 3 (as Spell Revisions' Color Spray tiers its
-- effects); a kit power that casts one of two spells by the target's level (326).
c=classify(spl('TESTCS',{ability({fx(146,{p2=1,res='TESTCSSL',dice=1}),fx(74,{dice=3,duration=18})})}),world(levelWorld))
assert(spells.view(c,atLevel(1)).disable.kinds.sleep and spells.view(c,atLevel(2)).disable==nil)
assert(spells.view(c,atLevel(3)).debuff.kinds.blind and spells.view(c,atLevel(4)).debuff==nil)
c=classify(spl('TESTTIR',{ability({fx(326,{res='TESTTIRA',dice=8}),fx(326,{res='TESTTIRB',sides=9})})}),world(levelWorld))
assert(spells.view(c,atLevel(8)).disable.kinds.stun and not spells.view(c,atLevel(8)).disable.kinds.death)
assert(spells.view(c,atLevel(9)).disable.kinds.death and not spells.view(c,atLevel(9)).disable.kinds.stun)
-- An immunity within levels keeps those creatures out of what follows.
c=classify(spl('TESTIMM',{ability({fx(101,{p2=13,sides=10,duration=1}),fx(13,{})})}),world({}))
assert(spells.view(c,atLevel(9)).disable.kinds.death and spells.view(c,atLevel(10)).disable==nil)
-- What lands on the caster by a preset target does so only within its levels, by the caster
-- level (extra attacks from level 7 and from 13); a self-targeted effect (target 1) always lands.
local whirl=spl('TESTWHL',{ability({fx(1,{p1=1,sides=7,duration=30}),fx(1,{p1=1,sides=13,duration=30})},{target=5})})
assert(classify(whirl,world({}),{level=6}).roles.buff==nil)
assert(classify(whirl,world({}),{level=9}).roles.buff.amounts.attacks==1)
assert(classify(whirl,world({}),{level=13}).roles.buff.amounts.attacks==2)
whirl.abilities[1].effects[1].target=1
assert(classify(whirl,world({}),{level=6}).roles.buff.amounts.attacks==1)
groups=groups+1

-- Debuff amounts (F2b): saving throw points by save (the five saves one by one, or all five at
-- once), casting failure by kind of spell, disease by its type (poison damage over its first
-- minute, a lower stat, slow, Contagion, Mold Touch), the luck a negative chant takes.
c=classify(spl('TESTMAL',{ability({fx(33,{p1=-2,duration=120}),fx(34,{p1=-2,duration=120}),
    fx(35,{p1=-2,duration=120}),fx(36,{p1=-2,duration=120}),fx(37,{p1=-2,duration=120}),
    fx(22,{p1=-1,duration=120})})}),world({}))
local d=c.roles.debuff
assert(d.amounts.saves==10 and d.saveBy.spell==2 and d.saveBy.death==2 and d.saveBy.poly==2 and d.amounts.luck==1)
d=one(fx(325,{p1=-1,duration=60})).roles.debuff
assert(d.amounts.saves==1 and d.saveBy.spell==1 and d.saveBy.breath==1 and d.saveBy.wand==1)
assert(one(fx(37,{p1=2,target=1}),{target=5}).roles.protection.saveBy.spell==2)
assert(one(fx(346,{p1=-2})).roles.debuff.saveBy==nil)
-- Miscast Magic: 80 per cent for wizard and priest spells; a negative per cent harms no one.
c=classify(spl('TESTMIS',{ability({fx(60,{p1=80,duration=60}),fx(60,{p1=80,p2=1,duration=60})})}),world({}))
d=c.roles.debuff
assert(d.kinds.miscast and d.miscastBy.arcane==80 and d.miscastBy.divine==80 and d.miscastBy.innate==nil)
assert(one(fx(60,{p1=30,p2=5})).roles.debuff.miscastBy.innate==30)
assert(next(one(fx(60,{p1=-20})).roles)==nil)
-- Disease: a hit point a second for its first minute (an hour-long one too), 3 a second for 10
-- seconds, one every 4 seconds; strength 2 lower; slowed; Contagion; Mold Touch.
d=one(fx(78,{p1=1,duration=3600})).roles
assert(d.debuff.kinds.disease and d.damage.types.poison==60)
assert(one(fx(78,{p1=3,p2=2,duration=10})).roles.damage.types.poison==30)
assert(near(one(fx(78,{p1=4,p2=3,duration=60})).roles.damage.types.poison,15))
d=one(fx(78,{p1=2,p2=4,duration=60})).roles
assert(d.damage==nil and d.debuff.kinds.strength and d.debuff.amounts.strength==2 and d.debuff.kinds.disease)
assert(one(fx(78,{p2=10,duration=60})).roles.debuff.kinds.slow)
d=one(fx(78,{p1=2,p2=13,duration=60})).roles.debuff
assert(d.kinds.slow and d.amounts.strength==2 and d.amounts.dexterity==2 and d.amounts.charisma==2 and d.kinds.disease)
assert(one(fx(78,{p2=11})).roles.damage.types.magic==3.5)
assert(one(fx(78,{p1=3,p2=12})).roles.damage.types.magic==21)
r=one(fx(78,{p2=11})).roles.damage.rolls[1]
assert(r.dice==1 and r.sides==6 and r.flat==0)
r=one(fx(78,{p1=3,p2=12})).roles.damage.rolls[1]
assert(r.dice==6 and r.sides==6 and r.flat==0)
-- A negative chant lowers luck by its parameter; below 0 it helps.
d=one(fx(137,{p1=1,duration=60})).roles.debuff
assert(d.kinds.chant and d.amounts.luck==1)
assert(one(fx(137,{p1=255,duration=60})).roles.buff.kinds.chant)
groups=groups+1

-- Poison as EE deals it (IESDP opcode 25), over its first minute: types 0 and 1 a hit point a
-- second (0 only with parameter 1 set); 2 parameter 1 every second, Bolt of Biting's "30 points
-- of poison damage in 15 seconds"; 3 one every parameter 1 seconds, the Poisoned Arrow's "1 point
-- of poison damage every 3 seconds" for 40 seconds; 4 parameter 3 every parameter 1 seconds, from
-- an EFF file: an assassin's poison of 4 every 6 seconds (Artisan's Kitpack), through a 177 for 30
-- seconds. A frequency multiplier (parameter 4) of 2 halves each; one without an end counts its
-- first minute; types 5 and up (they crash the game) count no damage.
local function poison(fields,lookup) local r=one(fx(25,fields),nil,lookup).roles return r.damage and r.damage.types.poison end
assert(poison({p1=1,duration=600})==60 and poison({duration=20})==nil and one(fx(25,{duration=20})).roles.debuff.kinds.poison)
assert(poison({p1=30,p2=1,duration=20})==20)
assert(poison({p1=2,p2=2,duration=15})==30 and near(poison({p1=3,p2=3,duration=40}),40/3))
assert(poison({p1=6,p2=4,duration=30})==nil)
local venom=world({['EFF:TESTVNM']={kind='EFF',resref='TESTVNM',effect=fx(25,{p1=6,p2=4,p3=4,timing=1,target=1})},
    ['EFF:TESTVNMF']={kind='EFF',resref='TESTVNMF',effect=fx(25,{p1=6,p2=4,p3=4,p4=2,timing=1,target=1})}})
d=one(fx(177,{res='TESTVNM',p2=2,duration=30}),nil,venom).roles
assert(near(d.damage.types.poison,20) and d.debuff.kinds.poison)
assert(near(one(fx(177,{res='TESTVNMF',p2=2,duration=30}),nil,venom).roles.damage.types.poison,10))
assert(poison({p1=2,p2=2,p4=2,duration=15})==15 and near(poison({p1=3,p2=3,p4=2,duration=60}),10))
assert(poison({p1=3,p2=3,timing=1})==20 and poison({p1=3,p2=3,timing=9})==20 and poison({p1=3,p2=5,duration=60})==nil)
-- Disease's damage follows the same rule: a frequency multiplier of 2 halves it; type 1 a hit point
-- a second.
assert(one(fx(78,{p1=3,p2=2,p4=2,duration=10})).roles.damage.types.poison==15)
assert(one(fx(78,{p1=30,p2=1,duration=20})).roles.damage.types.poison==20)
assert(spells.perSecond(fx(78,{p1=2,p2=4}))==nil and spells.perSecond(fx(272,{p1=5,p2=1}))==0)
groups=groups+1

-- Critical hit effects (opcode 341, F2e): the spell it names is cast at each creature its holder
-- hits critically. A kit's lasting one with melee hits (special 1): its spell at the holder's level
-- (2d6 fire from level 10 on, 1d6 below), read as cast at the creature hit without its projectile;
-- what it puts on its caster lands on the holder.
local critHit=spl('TESTCRHT',{ability({fx(12,{p2=8*65536,dice=1,sides=6,timing=1}),fx(0,{target=1,p1=2,duration=6})},
    {projectile=99}),ability({fx(12,{p2=8*65536,dice=2,sides=6,timing=1})},{minLevel=10,projectile=99})})
local critWorld={['SPL:TESTCRHT']=critHit,['PRO:99']=pro({radius=480})}
assert(spells.neutral[341]==nil)
local critKit=spl('TESTCRKT',{ability({fx(341,{target=1,timing=9,special=1,res='TESTCRHT'})},{target=5})})
c=classify(critKit,world(critWorld))
h=c.hits[1]
assert(not c.partial and #c.hits==1 and c.roles.buff.kinds.onCrit and c.roles.buff.who.self and c.roles.damage==nil)
assert(h.critical==true and h.melee==true and h.ranged==false and h.fists==nil and h.weapon==nil and h.category==nil)
assert(h.who=='self' and h.seconds=='permanent' and h.once==false and h.eff=='TESTCRHT' and h.source=='TESTCRKT')
assert(h.strike.area==nil and h.strike.roles.damage.who.target and near(h.strike.roles.damage.types.fire,3.5))
assert(h.strike.roles.protection.who.self and h.strike.roles.protection.who.target==nil)
assert(near(classify(critKit,world(critWorld),{level=12}).hits[1].strike.roles.damage.types.fire,7))
-- Any attack (special 0) brings it with melee and missiles alike, ranged ones (2) with missiles
-- alone; magical attacks (3) and unknown kinds count nothing.
local function critOf(fields,lookup)
    return classify(spl('',{ability({fx(341,fields)},{target=5})}),lookup or world(critWorld)).hits[1]
end
h=critOf({target=1,res='TESTCRHT'})
assert(h.melee and h.ranged)
h=critOf({target=1,special=2,res='TESTCRHT'})
assert(h.ranged and not h.melee)
for _,kind in ipairs({3,7}) do
    h=critOf({target=1,special=kind,res='TESTCRHT'})
    assert(h.melee==false and h.ranged==false)
end
-- By this weapon only (parameter 2 at 1): with the item it comes from, as an active effect names it
-- (sense.guard), else the item or spell that holds it; one without either matches no weapon. From an
-- EFF file only with weapons of one category (parameter 3, ITEMCAT.IDS: 28 for fists).
assert(critOf({target=1,p2=1,res='TESTCRHT',source='testaxe'}).weapon=='TESTAXE')
assert(classify(spl('TESTSWRD',{ability({fx(341,{target=1,p2=1,res='TESTCRHT'})},{target=5})}),world(critWorld)).hits[1].weapon=='TESTSWRD')
assert(critOf({target=1,p2=1,res='TESTCRHT'}).weapon=='')
local anonymous=spl('',{ability({fx(341,{target=1,p2=1,res='TESTCRHT'})},{target=5})})
anonymous.resref=nil
assert(classify(anonymous,world(critWorld)).hits[1].weapon=='')
assert(critOf({target=1,p3=28,res='TESTCRHT'}).category==28 and critOf({target=1,p3=0,res='TESTCRHT'}).category==nil)
-- A critical hit spell that takes the spell holding it off its holder again (opcode 321) comes once.
critWorld['SPL:TESTCRSG']=spl('TESTCRSG',{ability({fx(12,{p2=8*65536,dice=1,sides=6,timing=1}),fx(321,{target=1,res='TESTSIEG',timing=1})})})
assert(critOf({target=1,timing=0,duration=60,special=2,res='TESTCRSG',source='TESTSIEG'}).once==true)
assert(critOf({target=1,timing=0,duration=60,special=2,res='TESTCRSG',source='TESTOTHR'}).once==false)
-- A spell that cannot be read leaves the hit unknown; a strike is read without critical hit effects.
c=classify(spl('TESTCRLS',{ability({fx(341,{target=1,timing=9,res='TESTNONE'})},{target=5})}),world({}))
assert(not c.partial and c.approximate and c.reasons['missing:SPL:TESTNONE'] and c.hits==nil and c.roles.buff.kinds.onCrit)
assert(classify(critKit,world(critWorld),{weapons=false}).hits==nil)
groups=groups+1

-- Opcode 326 aimed at "self" or "original caster" (IESDP) still applies its spell to the ability
-- target, while its SPLPROT row tests the creature it lands on: the caster. Inside the spell a 326
-- applies, "self" is the creature the 326 lands on, and so is "original caster" when that spell has
-- no projectile (0). Artisan's Kitpack's Dreadnought stuns the creature its critical hit strikes
-- this way, when its own strength is high enough.
;(function()
local sub=spl('TESTSUB',{ability({fx(12,{p1=10,p2=8*65536,timing=1}),fx(0,{target=1,p1=2,duration=6}),
    fx(44,{target=9,p1=1,duration=6})})})
local bare=spl('TESTBARE',{ability({fx(44,{target=9,p1=1,duration=6})},{projectile=0})})
local w=world({['SPL:TESTSUB']=sub,['SPL:TESTBARE']=bare})
-- At a creature: the spell's damage and its "self" (armour class) land on the target, its
-- "original caster" (strength) on the caster; the row is the caster's, so its mark decides for
-- every creature reached.
for _,t in ipairs({1,9}) do
    local c=classify(spl('TESTAIM',{ability({fx(326,{target=t,p1=16,p2=125,res='TESTSUB'}),fx(17,{target=1,p1=5})})}),w)
    assert(c.roles.damage.who.target and not c.roles.damage.who.self and not c.approximate)
    assert(c.roles.heal.who.self and not c.roles.heal.who.target and c.aim==nil and c.remap==nil)
    assert(c.roles.protection.who.target and not c.roles.protection.who.self)
    assert(c.roles.buff.who.self and not c.roles.buff.who.target)
    assert(#c.conditions==1 and c.conditions[1].caster==true and spells.conditionKey(c.conditions[1])=='row:125:16:caster')
    assert(spells.rows(c)['row:125:16:caster'].caster==true)
    assert(spells.view(c,function() return true end).damage and spells.view(c,function() return false end).damage==nil)
end
assert(classify(spl('TESTAIM',{ability({fx(326,{target=1,res='TESTBARE'})})}),w).roles.buff.who.target)
-- A 326 on the target: its "self" lands on the target too; its row is the target's.
local c=classify(spl('TESTON',{ability({fx(326,{target=2,p1=16,p2=125,res='TESTSUB'})})}),w)
assert(c.roles.protection.who.target and not c.roles.protection.who.self and c.roles.buff.who.self)
assert(c.conditions[1].caster==nil and spells.conditionKey(c.conditions[1])=='row:125:16')
-- Cast at oneself everything lands on the caster, and the row is still the caster's; aimed at a
-- point there is no creature to apply it to: on the caster, approximate.
c=classify(spl('TESTSELF',{ability({fx(326,{target=1,p1=16,p2=125,res='TESTSUB'})},{target=5})}),w)
assert(c.roles.damage.who.self and not c.roles.damage.who.target and c.conditions[1].caster==true)
c=classify(spl('TESTPNT',{ability({fx(326,{target=1,res='TESTSUB'})},{target=4})}),w)
assert(c.approximate and c.reasons['326-unaimed:TESTSUB'] and c.roles.damage.who.self)
-- What a 148 casts is aimed at a point too; what a 146 casts at a creature is aimed at that
-- creature, also when it explodes there.
local spot=spl('TESTSPOT',{ability({fx(326,{target=1,res='TESTSUB'})},{target=4})})
local burst=spl('TESTBRST',{ability({fx(326,{target=1,res='TESTSUB'})},{projectile=99})})
local around=world({['SPL:TESTSUB']=sub,['SPL:TESTSPOT']=spot,['SPL:TESTBRST']=burst,['PRO:99']=pro()})
c=classify(spl('TESTTHRW',{ability({fx(148,{p2=1,res='TESTSPOT'})})}),around)
assert(c.approximate and c.reasons['326-unaimed:TESTSUB'] and c.roles.damage.who.self)
c=classify(spl('TESTBLST',{ability({fx(146,{p2=1,res='TESTBRST'})})}),around)
assert(c.area and c.roles.damage.who.target and not c.roles.damage.who.area and not c.approximate)
-- A 326 on the preset target of an area spell reaches each creature there, by each one's row.
c=classify(spl('TESTWIDE',{ability({fx(326,{target=2,p1=16,p2=125,res='TESTSUB'})},{target=4,projectile=99})}),around)
assert(c.roles.damage.who.area and c.roles.protection.who.area and not c.roles.damage.who.target)
assert(not c.approximate and c.conditions[1].caster==nil)
-- Through a cast: the creature a 146 casts at is the ability target of what it casts. A cast inside
-- a 326's spell lands on the creature the 326 lands on and keeps its own rule: its "self" is the
-- caster.
local relay=spl('TESTRLY',{ability({fx(326,{target=1,res='TESTSUB'})})})
local inner=spl('TESTINR',{ability({fx(0,{target=1,p1=2,duration=6}),fx(12,{p1=4,p2=8*65536,timing=1})})})
local outer=spl('TESTOUT',{ability({fx(146,{target=1,p2=1,res='TESTINR'})})})
w=world({['SPL:TESTSUB']=sub,['SPL:TESTRLY']=relay,['SPL:TESTINR']=inner,['SPL:TESTOUT']=outer})
c=classify(spl('TESTCAST',{ability({fx(146,{target=2,p2=1,res='TESTRLY'})})}),w)
assert(c.roles.damage.who.target and not c.roles.damage.who.self)
c=classify(spl('TESTCSLF',{ability({fx(146,{target=1,p2=1,res='TESTRLY'})})}),w)
assert(c.roles.damage.who.self and not c.roles.damage.who.target)
c=classify(spl('TESTNEST',{ability({fx(326,{target=2,res='TESTOUT'})})}),w)
assert(c.roles.damage.who.target and c.roles.protection.who.self and not c.roles.protection.who.target)
-- After a cast at oneself the ability's next 326 is aimed at its own target again; a dead
-- creature is a target too.
c=classify(spl('TESTSEQ',{ability({fx(146,{target=1,p2=1,res='TESTINR'}),fx(326,{target=1,res='TESTSUB'})})}),w)
assert(c.roles.damage.who.self and c.roles.damage.who.target)
c=classify(spl('TESTDEAD',{ability({fx(326,{target=1,res='TESTSUB'})},{target=3})}),w)
assert(c.roles.damage.who.target and not c.roles.damage.who.self and not c.approximate)
-- The Dreadnought's critical hit: by its strength (the holder's row), damage and a stun on the
-- creature hit.
local stun=spl('TESTSTUN',{ability({fx(12,{p1=6,timing=1}),fx(45,{duration=10})})})
local massive=spl('TESTMASV',{ability({fx(326,{target=1,p1=16,p2=125,res='TESTSTUN'})},{target=5})})
w=world({['SPL:TESTSTUN']=stun,['SPL:TESTMASV']=massive})
local h=classify(spl('TESTDRED',{ability({fx(341,{target=1,timing=9,special=1,res='TESTMASV'})},{target=5})}),w).hits[1]
assert(h.strike.roles.disable.who.target and h.strike.roles.damage.who.target and not h.strike.roles.damage.who.self)
assert(h.strike.conditions[1].caster==true)
end)()
groups=groups+1

-- When an ability is back after its use (recharge): a 171 that gives the spell itself back to its
-- caster, delayed by its duration (the installer's innate copies, Planar Travel) or at once
-- (Teleport Without Error), in its effects or its casting effects, whatever the case of its name.
-- None without one (spent until the caster rests), for a 171 of another spell or one that gives the
-- spell to the creature it is cast at; the shortest of two counts.
;(function()
local function veil(effects,fields,casting)
    local r=spl('BGW20606',{ability(effects,fields)},{spellType=4})
    r.casting=casting or {}
    return classify(r,world({}))
end
local invisible=fx(20,{target=1,timing=1})
local gone=fx(172,{target=1,timing=1,res='BGW20606'})
local c=veil({invisible,gone,fx(171,{target=1,timing=4,duration=6,res='BGW20606'})},{target=5})
assert(c.recharge==6 and c.roles.protection.kinds.invisible and c.spellType==4)
assert(veil({invisible,gone,fx(171,{target=1,timing=1,res='BGW20606'})},{target=5}).recharge==0)
assert(veil({invisible,fx(171,{target=1,timing=4,duration=1000,res='bgw20606'})},{target=5}).recharge==1000)
assert(veil({invisible},{target=5}).recharge==nil)
assert(veil({invisible,fx(171,{target=1,timing=4,duration=6,res='SPWI206'})},{target=5}).recharge==nil)
assert(veil({invisible,fx(171,{target=2,timing=4,duration=6,res='BGW20606'})},{target=1}).recharge==nil)
assert(veil({invisible,fx(171,{target=2,timing=4,duration=6,res='BGW20606'})},{target=5}).recharge==6)
assert(veil({invisible},{target=5},{fx(171,{target=1,timing=3,duration=12,res='BGW20606'})}).recharge==12)
assert(veil({invisible,fx(171,{target=1,timing=4,duration=18,res='BGW20606'}),
    fx(171,{target=1,timing=4,duration=30,res='BGW20606'})},{target=5}).recharge==18)
end)()
groups=groups+1

-- Strength and haste as combat-intent/defence.lua weighs them (lab batch J's potions): a giant
-- strength potion sets strength (opcode 44, mode 1) and keeps the highest set, a lowering one the
-- lowest; points added are amounts; a percentage and Bull's Strength count by their sign alone.
-- Exceptional strength (97) is a stat of its own, never strength points. A weak haste (16, type 2)
-- hastens movement alone; an improved one doubles the attacks.
;(function()
local function self(e) return one(e,{target=5}) end
local c=classify(spl('TESTGIAN',{ability({fx(44,{p1=22,p2=1,target=1}),fx(44,{p1=19,p2=1,target=1})},{target=5})}),world({}))
assert(c.roles.buff.kinds.strength and c.roles.buff.strengthSet==22 and c.roles.buff.amounts==nil)
c=classify(spl('TESTWEAK',{ability({fx(44,{p1=5,p2=1,target=1}),fx(44,{p1=3,p2=1,target=1})},{target=5})}),world({}))
assert(c.roles.debuff.kinds.strength and c.roles.debuff.strengthSet==3 and c.roles.buff==nil)
assert(next(self(fx(44,{p1=12,p2=1,target=1})).roles)==nil)
c=self(fx(44,{p1=2,target=1}))
assert(c.roles.buff.amounts.strength==2 and c.roles.buff.strengthSet==nil)
c=self(fx(44,{p1=150,p2=2,target=1}))
assert(c.roles.buff.kinds.strength and c.roles.buff.amounts==nil)
assert(self(fx(44,{p1=50,p2=2,target=1})).roles.debuff.kinds.strength and next(self(fx(44,{p1=100,p2=2,target=1})).roles)==nil)
c=self(fx(97,{p1=25,target=1}))
assert(c.roles.buff.kinds.strengthExtra and c.roles.buff.amounts.strengthExtra==25 and not c.roles.buff.kinds.strength)
assert(c.roles.buff.amounts.strength==nil)
c=self(fx(97,{p1=100,p2=1,target=1}))
assert(c.roles.buff.strengthExtraSet==100 and next(self(fx(97,{p1=0,p2=1,target=1})).roles)==nil)
assert(self(fx(97,{p1=10,target=1})).roles.buff.amounts.strengthExtra==10)
assert(self(fx(97,{p1=-10,target=1})).roles.debuff.amounts.strengthExtra==10)
c=self(fx(97,{p1=150,p2=2,target=1}))
assert(c.roles.buff.kinds.strengthExtra and c.roles.buff.amounts==nil)
assert(self(fx(97,{p1=50,p2=2,target=1})).roles.debuff.kinds.strengthExtra and next(self(fx(97,{p1=100,p2=2,target=1})).roles)==nil)
c=self(fx(16,{p2=2,target=1}))
assert(c.roles.buff.kinds.movement and not c.roles.buff.kinds.haste)
c=self(fx(16,{p2=1,target=1}))
assert(c.roles.buff.kinds.haste and c.roles.buff.kinds.improvedHaste)
c=self(fx(16,{target=1}))
assert(c.roles.buff.kinds.haste and not c.roles.buff.kinds.improvedHaste)
end)()
groups=groups+1

return groups
