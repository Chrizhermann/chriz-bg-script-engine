-- The weapons a creature carries (combat-intent/arsenal.lua): the one in its hand as the game
-- reports it, and the others as the game's tables give them. The numbers are lab probe F's
-- (docs/learned.md): a level 8 fighter (THAC0 13) with strength 18 and dexterity 16, specialized
-- (two stars) in short swords and in high mastery (four) of longbows, a short sword +1, a longbow +1
-- and arrows +1. The game reported THAC0BONUSRIGHT 3 and DAMAGEBONUSRIGHT 2 with the sword in hand
-- (strength 1, specialization 1, the sword 1; specialization's 2), 6 and 4 with the bow (dexterity
-- 1, high mastery 3, bow 1, arrows 1; high mastery's 4): THAC0 10, 8.5 a hit, 2 attacks a round
-- with the sword; THAC0 7, 9.5 a hit, 3 attacks with the bow. Synthetic tables with those rows; no
-- game data.
local arsenal=require('combat-intent.arsenal')
local groups=0
local function near(a,b) return math.abs(a-b)<1e-9 end

local TABLES={
    wspecial={[0]={hit=0,damage=0},[1]={hit=0,damage=0},[2]={hit=1,damage=2},[3]={hit=2,damage=2},[4]={hit=3,damage=4},
        [5]={hit=3,damage=5}},
    wspatck={[0]={[1]=0},[1]={[1]=0},[2]={[1]=0,[7]=1,[13]=-2},[3]={[1]=0,[7]=-2},[4]={[1]=0,[7]=1},[5]={[1]=0,[7]=-2}},
    strmod={[16]={hit=0,damage=1},[18]={hit=1,damage=2}},
    strmodex={[50]={hit=1,damage=1}},
    dexmod={[16]=1,[18]=2},
    classes={FIGHTER={profApr=true,penalty=2}}}
local function ability(fields)
    local a={location=1,attackType=1,dice=0,sides=0,damageBonus=0,thac0=0,flags=0,range=1,damageType=1,projectile=1}
    for k,v in pairs(fields) do a[k]=v end
    return a
end
local function item(fields,abilities)
    local r={flags=0,enchantment=0,itemType=19,proficiency=0,equipping={},abilities=abilities}
    for k,v in pairs(fields) do r[k]=v end
    return r
end
-- Proficiency stats: short sword 89, longbow 104, axe 95.
local SWORD=item({flags=0x40,enchantment=1,proficiency=89},{ability({dice=1,sides=6,damageBonus=1,thac0=1,flags=1})})
local BOW=item({flags=0x40,enchantment=1,itemType=15,proficiency=104,equipping={{opcode=1,p1=2,p2=1}}},
    {ability({attackType=4,thac0=1,damageBonus=1,range=100})})
local ARROWS=item({flags=0x40,enchantment=1,itemType=5},{ability({attackType=2,launcher=1,dice=1,sides=6,thac0=1,
    damageBonus=1,damageType=4,projectile=2})})
local BOLTS=item({itemType=31},{ability({attackType=2,launcher=2,dice=1,sides=8,damageType=4,projectile=3})})
local FIST=item({itemType=28},{ability({dice=1,sides=2,damageType=2,flags=1})})
local AXE=item({itemType=25,proficiency=95},{ability({dice=1,sides=6,flags=1}),
    ability({attackType=2,dice=1,sides=6,flags=1,range=30,damageType=3,projectile=24})})
local function fighter(selected,ability,stats)
    local c={stats={thac0=13,hitBonus=0,meleeHit=0,missileHit=0,damageBonus=0,meleeDamage=0,missileDamage=0},
        str=18,strExtra=0,dex=16,level=8,pips={[89]=2,[104]=4,[95]=0},penalty=2,profApr=true,baseApr=1,
        items={[10]={resref='FIST',record=FIST},[11]={resref='ARROWS',record=ARROWS},[35]={resref='SWORD',record=SWORD},
            [36]={resref='BOW',record=BOW}},selected=selected,ability=ability}
    for k,v in pairs(stats or {}) do c.stats[k]=v end
    return c
end
local function find(list,resref,n)
    for _,w in ipairs(list) do if w.item==resref and (n==nil or w.abilityNum==n) then return w end end
end

-- 1. The sword in hand, as the game reports it: THAC0 10, 8.5 a hit (1d6, the sword's 1, strength's
-- 2, specialization's 2), two attacks; the tables give the game's 3 and 2 for its bonuses. Taken
-- up, the bow would hit at THAC0 7 for 9.5, three times a round (the bow sets two, high mastery adds
-- one), shooting the arrows in the first quiver slot; magical, as the arrows are.
local hand=arsenal.hand(TABLES,fighter(35,0,{apr=2,thac0Right=3,damageRight=2}))
assert(hand.item=='SWORD' and hand.slot==35 and hand.abilityNum==0 and hand.ability==1 and not hand.ranged)
assert(hand.thac0==10 and near(hand.damage,8.5) and hand.apr==2 and hand.model.hit==3 and hand.model.damage==2)
assert(hand.magical and hand.damageType==1 and hand.range==nil and hand.fist==nil)
local others=arsenal.others(TABLES,fighter(35,0,{apr=2,thac0Right=3,damageRight=2}))
local bow=find(others,'BOW')
assert(#others==1 and bow.slot==36 and bow.abilityNum==0 and bow.ammo=='ARROWS' and bow.ranged and bow.launcher)
assert(bow.thac0==7 and near(bow.damage,9.5) and bow.apr==3 and bow.range==1600 and bow.projectile==2 and bow.damageType==4)
assert(bow.magical and bow.enchantment==1)
groups=groups+1

-- 2. The bow in hand: the game's selected slot is the arrows' quiver slot, and the bow the first
-- weapon slot that shoots them. THAC0 7, 9.5, three attacks; the tables give the game's 6 and 4. The
-- sword taken up: THAC0 10, 8.5, two attacks.
hand=arsenal.hand(TABLES,fighter(11,0,{apr=3,thac0Right=6,damageRight=4}))
assert(hand.item=='BOW' and hand.slot==36 and hand.ammo=='ARROWS' and hand.ranged and hand.launcher)
assert(hand.thac0==7 and near(hand.damage,9.5) and hand.apr==3 and hand.model.hit==6 and hand.model.damage==4)
others=arsenal.others(TABLES,fighter(11,0,{apr=3,thac0Right=6,damageRight=4}))
local sword=find(others,'SWORD')
assert(#others==1 and sword.slot==35 and sword.thac0==10 and near(sword.damage,8.5) and sword.apr==2 and not sword.ranged)
groups=groups+1

-- 3. Attacks a round: haste and the like stay (three with the sword hasted, four with the bow taken
-- up). One that sets the last word (opcode 1, mode 3) keeps it: in hand, the others count from the
-- creature's own; taken up, it is its own number.
others=arsenal.others(TABLES,fighter(35,0,{apr=3,thac0Right=3,damageRight=2}))
assert(find(others,'BOW').apr==4)
local c=fighter(35,0,{apr=5,thac0Right=3,damageRight=2})
c.items[35].record=item({proficiency=89},{ability({dice=1,sides=6})})
c.items[35].record.equipping={{opcode=1,p1=5,p2=3}}
assert(find(arsenal.others(TABLES,c),'BOW').apr==3)
c=fighter(11,0,{apr=3,thac0Right=6,damageRight=4})
c.items[35].record=item({proficiency=89},{ability({dice=1,sides=6})})
c.items[35].record.equipping={{opcode=1,p1=4,p2=3}}
assert(find(arsenal.others(TABLES,c),'SWORD').apr==4)
-- Half attacks as the game keeps them, and WSPATCK's: 7 is one and a half, -7 its mirror; WSPATCK's
-- -2 is one and a half (a specialist from level 13: the sword taken up swings two and a half times).
assert(arsenal.decode(7)==1.5 and arsenal.decode(-7)==-1.5 and arsenal.decode(3)==3 and arsenal.decode('x')==nil)
c=fighter(11,0,{apr=3,thac0Right=6,damageRight=4})
c.level=13
assert(find(arsenal.others(TABLES,c),'SWORD').apr==2.5)
-- A launcher of no range of its own shoots as far as its ammunition flies.
c=fighter(35,0,{apr=2,thac0Right=3,damageRight=2})
c.items[36]={resref='SHORT',record=item({itemType=15,proficiency=104},{ability({attackType=4,range=0})})}
c.items[11]={resref='DARTS',record=item({itemType=5},{ability({attackType=2,launcher=1,dice=1,sides=3,range=60})})}
assert(find(arsenal.others(TABLES,c),'SHORT').range==960)
groups=groups+1

-- 4. Proficiencies: without a star the class's penalty to hit; stars not known, or an item of no
-- proficiency, give nothing. Exceptional strength adds STRMODEX's row on top of 18's.
assert(select(1,arsenal.skill(TABLES,{pips={[95]=0},penalty=2},95))==-2)
assert(select(1,arsenal.skill(TABLES,{pips={},penalty=2},95))==0 and select(1,arsenal.skill(TABLES,{pips={}},0))==0)
local hit,damage=arsenal.strength(TABLES,18,50)
assert(hit==2 and damage==3 and select(1,arsenal.strength(TABLES,18,0))==1 and select(1,arsenal.strength(nil,18,0))==0)
-- A thrown axe (no star: 2 worse to hit) is two weapons, swung and thrown; thrown, dexterity's
-- missile bonus comes on top of strength's (the ability's flag gives both; not measured yet).
c=fighter(35,0,{apr=2,thac0Right=3,damageRight=2})
c.items[37]={resref='AXE',record=AXE}
others=arsenal.others(TABLES,c)
local swung,thrown=find(others,'AXE',0),find(others,'AXE',1)
assert(#others==3 and swung.slot==37 and not swung.ranged and thrown.ranged and thrown.range==480 and thrown.projectile==24)
assert(swung.thac0==13-(1-2) and near(swung.damage,3.5+2) and swung.apr==1 and thrown.thac0==swung.thac0-1)
groups=groups+1

-- 5. What strikes nothing: a launcher without ammunition it shoots (bolts for a bow), ammunition
-- without its launcher. With the fist selected, the fist strikes. A magic weapon in hand (the game
-- keeps it there) or tables that cannot be read leave no others; the one in hand is still known,
-- without the tables' parts and strength's bonus to damage.
c=fighter(35,0,{apr=2,thac0Right=3,damageRight=2})
c.items[11]={resref='BOLTS',record=BOLTS}
assert(#arsenal.others(TABLES,c)==0 and arsenal.striker(c.items,36,0)==nil and arsenal.striker(c.items,11,0)==nil)
c.items[36]=nil;c.items[11]={resref='ARROWS',record=ARROWS}
assert(arsenal.striker(c.items,11,0)==nil)
hand=arsenal.hand(TABLES,fighter(10,0,{apr=1,thac0Right=1,damageRight=0}))
assert(hand.item=='FIST' and hand.fist and near(hand.damage,1.5+2) and hand.thac0==12)
c=fighter(34,0,{apr=1})
c.items[34]={resref='MAGIC',record=SWORD}
assert(#arsenal.others(TABLES,c)==0)
c=fighter(35,0,{apr=2,thac0Right=3,damageRight=2})
assert(#arsenal.others(nil,c)==0 and #arsenal.others({wspecial={}},c)==0)
hand=arsenal.hand(nil,c)
assert(hand.thac0==10 and near(hand.damage,6.5) and hand.model==nil)
hand=arsenal.hand(TABLES,{stats={thac0=15,apr=1,thac0Right=2},items={}})
assert(hand.item==nil and hand.apr==1 and hand.thac0==13)
groups=groups+1

-- 6. Backstabs (F2d): a melee weapon whose item leaves the usability bit "unusable by thieves"
-- clear can backstab, whoever wields it (a fist too); one with the bit set cannot, nor can a weapon
-- thrown or shot, and an item whose usability was not read says nothing.
c=fighter(35,0,{apr=2,thac0Right=3,damageRight=2})
c.items[35].record=item({proficiency=89,usability=0x20000000},{ability({dice=1,sides=6})})
c.items[36].record=item({itemType=15,proficiency=104,usability=0},{ability({attackType=4,range=100})})
c.items[37]={resref='GREAT',record=item({itemType=20,proficiency=93,usability=0x604cd780},{ability({dice=2,sides=6})})}
c.items[38]={resref='AXE',record=item({itemType=25,proficiency=95,usability=0},AXE.abilities)}
hand=arsenal.hand(TABLES,c)
assert(hand.backstab==true)
others=arsenal.others(TABLES,c)
assert(find(others,'BOW').backstab==nil and find(others,'GREAT').backstab==nil)
assert(find(others,'AXE',0).backstab==true and find(others,'AXE',1).backstab==nil)
c.items[10].record=item({itemType=28,usability=0},FIST.abilities)
assert(arsenal.hand(TABLES,fighter(10,0,{apr=1})).backstab==nil and arsenal.hand(TABLES,c).backstab==true)
c.selected=10
assert(arsenal.hand(TABLES,c).backstab==true)
groups=groups+1

return groups
