-- What an attack's damage, disable or debuff does to one creature (combat-intent/harm.lua), on
-- plain roles and creatures. No game data.
local harm=require('combat-intent.harm')
local threat=require('combat-intent.threat')
local groups=0

local function near(a,b,eps) return math.abs(a-b)<(eps or 1e-9) end
local function creature(fields)
    local c={id=11,x=0,y=0,hp=60,maxHp=60,state=0,held=0,level=10,ac=5,mr=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},
        saves={spell=14,breath=14,death=14,wand=14,poly=14},resist={},
        attack={apr=2,thac0=10,damage=8,damageType=3}}
    for k,v in pairs(fields or {}) do c[k]=v end
    return c
end
local function role(kinds,fields)
    local r={who={target=true},kinds={},amounts={},chance=1,power=1,resisted=true,duration=60}
    for _,k in ipairs(kinds) do r.kinds[k]=true end
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local MAGE={ea=2,general=1,race=1,class=1,specific=0,gender=1,alignment=0x11}
local CLERIC_MAGE={ea=2,general=1,race=1,class=14,specific=0,gender=1,alignment=0x11}

-- 1. What a debuff takes from a fighter's fight (2 attacks at THAC0 10 for 8 against armour class 5:
-- 12.8 a round): slow halves it; Doom's 2 to hit and 2 damage take 11/32; blindness's 4 to hit a
-- quarter; a point of luck and a rested creature's 7 fatigue (a point of luck) as 2 to hit; an
-- attack fewer, half the damage of its type or of all types, half its levels drained each half;
-- THAC0 set to 20 five eighths. Nothing more on a creature already slowed or blind, and nothing
-- that only weakens spells.
do
    local f=creature()
    assert(near(harm.weaken(role({'slow'}),f,5),0.5))
    assert(near(harm.weaken(role({'damage','thac0'},{amounts={damage=2,thac0=2}}),f,5),1-8.4/12.8))
    assert(near(harm.weaken(role({'blind'}),f,5),0.25))
    assert(near(harm.weaken(role({'luck','fatigue'},{amounts={luck=1,fatigue=7}}),f,5),1-11.2/12.8))
    assert(near(harm.weaken(role({'attacks'},{amounts={attacks=1}}),f,5),0.5))
    assert(near(harm.weaken(role({'damagePercent'},{damagePercentBy={[7]=50}}),f,5),0.5))
    assert(near(harm.weaken(role({'damagePercent'},{damagePercentBy={[0]=50}}),f,5),0.5))
    assert(harm.weaken(role({'damagePercent'},{damagePercentBy={[8]=50}}),f,5)==0)
    assert(near(harm.weaken(role({'drain'},{amounts={drain=5}}),f,5),0.5))
    assert(near(harm.weaken(role({'thac0'},{thac0Set=20}),f,5),1-4.8/12.8))
    assert(harm.weaken(role({'slow'}),creature({state=0x10000}),5)==0)
    assert(harm.weaken(role({'blind'}),creature({state=0x40000}),5)==0)
    assert(harm.weaken(role({'miscast','deaf'},{miscastBy={arcane=80,divine=80}}),f,5)==0)
    -- The caster itself fights with the weapon in its hand; without one it only casts.
    local me=creature({weapon={damage=8,apr=1,thac0=10,damageType=3}})
    me.attack=nil
    assert(near(harm.weaken(role({'slow'}),me,5),0.5))
    assert(near(harm.weaken(role({'attacks'},{amounts={attacks=6}}),me,5),0.5))
    me.weapon=nil;me.attack=false;me.ids=MAGE
    assert(near(harm.weaken(role({'damage','thac0'},{amounts={damage=2,thac0=2}}),me,5),0))
    groups=groups+1
end

-- 2. A caster's spells (one class level's worth a round): casting failure by kind of spell, half
-- each for a creature of both kinds; deafness fails half of wizard and priest spells and adds up
-- with it, at most all; a lower casting level and drained levels by their share; slow halves them.
do
    local mage=creature({ids=MAGE,attack=false})
    local miscast=role({'miscast'},{miscastBy={arcane=80,divine=80}})
    assert(near(harm.weaken(miscast,mage,5),0.8))
    assert(near(harm.weaken(miscast,creature({ids=CLERIC_MAGE,attack=false}),5),0.8))
    assert(near(harm.weaken(role({'miscast'},{miscastBy={arcane=80}}),creature({ids=CLERIC_MAGE,attack=false}),5),0.4))
    assert(near(harm.weaken(role({'deaf'}),mage,5),0.5))
    assert(near(harm.weaken(role({'deaf','miscast'},{miscastBy={arcane=80}}),mage,5),1))
    assert(near(harm.weaken(role({'castingLevel'},{amounts={castingLevel=5}}),mage,5),0.5))
    assert(near(harm.weaken(role({'drain'},{amounts={drain=4}}),mage,5),0.4))
    assert(near(harm.weaken(role({'slow'}),mage,5),0.5))
    -- A monster of no casting class: only failure of innate abilities, and it has no spells here.
    assert(harm.weaken(role({'miscast'},{miscastBy={innate=50}}),creature(),5)==0)
    -- A mage with a staff: the failure takes its spells, not its staff (12 of 12 + 1.05 a round).
    local armed=creature({ids=MAGE,attack={apr=1,thac0=20,damage=3.5}})
    assert(near(harm.weaken(miscast,armed,5),0.8*12/(12+0.3*3.5)))
    groups=groups+1
end

-- 3. The worth of a debuff: what it takes, for as long as it holds (a full 18 seconds counts in
-- full), at the creature's health (half counts three quarters), times the chance it lands (magic
-- resistance unless the role ignores it, the save, the effect's own chance). Nothing on a disabled
-- creature or one outside the role's levels.
do
    local f=creature()
    local slow=role({'slow'})
    assert(near(harm.debuff(slow,f,5),0.5))
    assert(near(harm.debuff(role({'slow'},{duration=9}),f,5),0.25))
    assert(near(harm.debuff(role({'slow'},{duration='permanent'}),f,5),0.5))
    assert(near(harm.debuff(slow,creature({hp=30}),5),0.375))
    assert(near(harm.debuff(slow,creature({mr=50}),5),0.25))
    assert(near(harm.debuff(role({'slow'},{resisted=false}),creature({mr=50}),5),0.5))
    -- Save vs polymorph at -3 against 14: it saves on 17 or more, 4 in 20.
    assert(near(harm.debuff(role({'slow'},{save={poly=true},saveBonus=-3}),f,5),0.5*(1-4/20)))
    assert(near(harm.debuff(role({'slow'},{chance=0.5}),f,5),0.25))
    assert(harm.debuff(slow,creature({held=1}),5)==0)
    assert(harm.debuff(role({'slow'},{maxLevel=4}),f,5)==0)
    assert(near(harm.debuff(role({'slow'},{maxLevel=10}),f,5),0.5))
    groups=groups+1
end

-- 4. What a debuff opens for other attacks: Greater Malison's 2 on every save (a copy; the
-- creature itself stays as it was), Lower Resistance's magic resistance (not below 0), a lower fire
-- resistance below 0 lets more through, armour 2 worse and blindness's 4 (once); nil when a role
-- lowers nothing.
do
    local f=creature({mr=50,resist={fire=30}})
    local malison=role({'saves','luck'},{saveBy={spell=2,breath=2,death=2,wand=2,poly=2},amounts={saves=10,luck=1}})
    local c=harm.weakened(malison,f)
    assert(c.saves.spell==16 and c.saves.poly==16 and f.saves.spell==14 and c.mr==50 and c.ac==5)
    assert(harm.weakened(role({'magicResistance'},{amounts={magicResistance=24}}),f).mr==26)
    assert(harm.weakened(role({'magicResistance'},{amounts={magicResistance=60}}),f).mr==0)
    c=harm.weakened(role({'resist'},{resist={fire=50}}),f)
    assert(c.resist.fire==-20 and near(harm.resisted(c,'fire'),1.2) and f.resist.fire==30)
    assert(harm.weakened(role({'armor'},{amounts={armor=2}}),f).ac==7)
    assert(harm.weakened(role({'armor','blind'},{amounts={armor=2}}),f).ac==11)
    assert(harm.weakened(role({'blind'}),creature({state=0x40000}))==nil)
    assert(harm.weakened(role({'slow'}),f)==nil)
    groups=groups+1
end

-- 5. Shared pieces: attacks a round with half attacks decoded, the mean armour class of the living.
do
    assert(threat.attacks(6)==0.5 and threat.attacks(7)==1.5 and threat.attacks(2)==2 and threat.attacks(-1)==0)
    assert(threat.armour({creature({ac=4}),creature({ac=8}),creature({ac=0,hp=0})})==6)
    assert(threat.armour({})==nil)
    groups=groups+1
end

return groups
