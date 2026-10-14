-- Synthetic records in the shape of tools/ie_resources.py output; no game data.
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,
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
c=classify(fireball,world({['PRO:99']=pro({areaFlags=64})}))
assert(c.area.filter=='enemies' and not c.friendlyFire)
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
carrier.abilities[1].effects[1].p1=4;carrier.abilities[1].effects[1].p2=4
c=classify(carrier,effs)
assert(c.conditional and c.filters[1].ids==4 and c.filters[1].entry==4 and c.roles.damage.amount==4)
groups=groups+1

-- 272 repeats an EFF: once a second, every p1 seconds, or p1 times a second.
local rep=spl('TESTREP',{ability({fx(272,{res='TESTEFF',duration=10})})})
c=classify(rep,effs)
assert(c.approximate and near(c.roles.damage.amount,40))
rep.abilities[1].effects[1].p2=3;rep.abilities[1].effects[1].p1=2
assert(near(classify(rep,effs).roles.damage.amount,20))
rep.abilities[1].effects[1].p2=2
assert(near(classify(rep,effs).roles.damage.amount,80))
groups=groups+1

-- 333 casts the holder's resref plus B, at level 1 unless parameter 2 gives one.
local charge=spl('TESTSC',{ability({fx(333,{p1=3})})})
local strike=spl('TESTSCB',{ability({fx(12,{dice=1,sides=6})},{minLevel=1}),ability({fx(12,{p1=100})},{minLevel=10})})
local strikes=world({['SPL:TESTSCB']=strike})
c=classify(charge,strikes,{level=15})
assert(near(c.roles.damage.amount,10.5) and c.approximate and c.roles.damage.who.target)
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
c=one(fx(151,{res='CHICKEN'}))
assert(c.roles.removal.kinds.replace and c.roles.summon.creatures.CHICKEN==1 and c.offensive)
assert(not one(fx(151,{res='CHICKEN',p2=3})).roles.removal)
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
assert(c.roles.buff.kinds.damagePercent and c.roles.buff.amounts.damagePercent==20)
assert(one(fx(332,{p1=-25})).roles.debuff.kinds.damagePercent)
c=one(fx(0,{p1=4,p2=2,target=1}),{target=5})
assert(c.roles.protection.kinds.armor and c.roles.protection.amounts.armor==4)
assert(one(fx(0,{p1=-2})).roles.debuff.kinds.armor)
assert(one(fx(222,{p1=160})).roles.debuff.kinds.teleportField)
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
assert(spells.neutral[321] and not spells.neutral[93] and not spells.neutral[168] and not spells.neutral[214])
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
-- Bits above 4 of the save type are flags, not saves.
c=one(fx(12,{p1=1,save=2^24+2^10}))
assert(c.roles.damage.save==nil)
groups=groups+1

return groups
