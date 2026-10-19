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
-- Aura cleansing (Improved Alacrity) is a casting-speed buff of its own kind.
c=one(fx(188,{p2=1,target=1,duration=12}),{target=5})
assert(c.roles.buff.kinds.alacrity and c.roles.buff.kinds.castingSpeed and c.roles.buff.who.self)
assert(not one(fx(189,{p1=10,target=1}),{target=5}).roles.buff.kinds.alacrity)
-- Power Word, Kill and Stun work only below 60 and 90 hit points.
assert(one(fx(209)).roles.disable.kinds.death and one(fx(209)).roles.disable.belowHp==60)
assert(one(fx(210)).roles.disable.kinds.stun and one(fx(210)).roles.disable.belowHp==90)
assert(one(fx(13)).roles.disable.belowHp==nil)
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
c=classify(spl('TESTLOST',{ability({fx(111,{target=1,p1=1,res='TESTNONE',duration=60})},{target=5})}),world({}))
assert(c.weapons==nil and c.partial and c.reasons['missing:ITM:TESTNONE'])
-- Read without weapons (options.weapons=false), as a strike is.
c=classify(harm,harmWorld,{weapons=false})
assert(c.weapons==nil and c.roles.buff.kinds.weapon)
groups=groups+1

return groups
