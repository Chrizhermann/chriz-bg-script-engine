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
    -- Bad luck of 3 for base weapon damage (opcode 250) lowers a 1d8 sword's roll by 3, at least 1:
    -- 2.25 off its 4.5, so 5.75 of the 8 a hit; unknown dice, nothing.
    assert(harm.weaken(role({'damageLuck'},{amounts={damageLuck=3}}),f,5)==0)
    local rolled=creature({attack={apr=2,thac0=10,damage=8,damageType=3,rolls={{dice=1,sides=8}}}})
    assert(near(harm.weaken(role({'damageLuck'},{amounts={damageLuck=3}}),rolled,5),1-9.2/12.8))
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

-- Damage roles with their rolls (combat-intent/spells.lua) and a counter of n dice with s sides
-- by hand: the chance of each total (index total + 1).
local function hurt(rolls,fields)
    local r=role({'damage'},{rolls=rolls})
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function roll(label,dice,sides,flat,fields)
    local r={label=label,dice=dice,sides=sides,flat=flat or 0,p=1,times=1}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function count(n,s)
    local p={1}
    for _=1,n do
        local q={}
        for i=1,#p+s do q[i]=0 end
        for i=1,#p do for k=1,s do q[i+k]=q[i+k]+p[i]/s end end
        p=q
    end
    return p
end
-- The hit points expected of totals p, no more than left, and the chance they reach it.
local function capped(p,left)
    local taken,all=0,0
    for i=1,#p do
        if i-1>=left then taken=taken+left*p[i];all=all+p[i] else taken=taken+(i-1)*p[i] end
    end
    return taken,all
end
local function same(a,b)
    if #a~=#b then return false end
    for i=1,#a do if not near(a[i],b[i]) then return false end end
    return true
end

-- 6. Damage by the dice: a die's spread on a creature it cannot kill, its mean and no kill; 2d6 on
-- 7 hit points kills on 7 or more (21 in 36) and counts at most the 7; a minimum of 1 hit point
-- takes the kill and a point; half fire resistance halves each total, the halves split between the
-- two whole numbers around them; a save for half on 11 (half the time) and magic resistance 50.
do
    local d6=hurt({roll('magic',1,6)})
    local f=creature()
    assert(same(harm.spread(d6,f),{0,1/6,1/6,1/6,1/6,1/6,1/6}))
    local w,x=harm.damage(d6,f,0.5,0)
    assert(near(w,3.5/60) and near(x,3.5))
    local two=hurt({roll('magic',2,6)})
    local seven=creature({hp=7})
    local taken,all=capped(count(2,6),7)
    assert(near(all,21/36) and near(taken,217/36))
    w,x=harm.damage(two,seven,0.5,0)
    assert(near(w,taken/60+0.5*all) and near(x,taken))
    taken=capped(count(2,6),6)
    w,x=harm.damage(two,seven,0.5,1)
    assert(near(x,taken) and near(w,taken/60))
    local fire=hurt({roll('fire',1,6)})
    assert(same(harm.spread(fire,creature({resist={fire=50}})),{1/12,1/3,1/3,1/4}))
    local saved=hurt({roll('fire',1,6)},{saveForHalf=true,save={spell=true}})
    local half=harm.spread(saved,creature({saves={spell=11,breath=14,death=14,wand=14,poly=14}}))
    assert(same(half,{1/24,1/4,1/4,5/24,1/12,1/12,1/12}))
    assert(same(harm.spread(d6,creature({mr=50})),{0.5,1/12,1/12,1/12,1/12,1/12,1/12}))
    assert(harm.spread(d6,creature({resist={magic=100}}))==nil)
    groups=groups+1
end

-- 7. A cloud's explosions add up before the kill counts (by the average, before 2026-10-28, a
-- creature about one explosion's average from death saw no worth in leaving): 4d6 on 14 hit
-- points kills 721 times in 1296, two of them as 8d6 do; a half explosion as likely as not. The flat rest of a roll, a
-- share of the creature's maximum, damage by type where a role carries no rolls, a roll's own
-- chance and copies, and dice past M.manyDice at their average.
do
    local cloud=hurt({roll('fire',4,6)})
    local f=creature({hp=14})
    local taken,all=capped(count(4,6),14)
    assert(near(all,721/1296))
    local w,x=harm.damage(cloud,f,0.5,0)
    assert(near(w,taken/60+0.5*all) and near(x,taken))
    local taken2,all2=capped(count(8,6),14)
    w,x=harm.damage(cloud,f,0.5,0,2)
    assert(near(w,taken2/60+0.5*all2) and near(x,taken2))
    w,x=harm.damage(cloud,f,0.5,0,1.5)
    assert(near(x,(taken+taken2)/2) and near(w,(taken+taken2)/120+0.25*(all+all2)))
    local s=harm.spread(cloud,f)
    w=harm.outcome({{spread=s,n=1},{spread=s,n=1}},f,0.5,0)
    assert(near(w,taken2/60+0.5*all2))
    -- Far from a kill: the mean, as the averages give it.
    w,x=harm.damage(cloud,creature({hp=100,maxHp=100}),0.5,0,3)
    assert(near(x,42) and near(w,0.42))
    assert(same(harm.spread(hurt({roll('magic',1,4,1)}),creature()),{0,0,1/4,1/4,1/4,1/4}))
    assert(same(harm.spread(hurt({},{percent=25}),creature()),(function()
        local t={} for i=1,16 do t[i]=0 end t[16]=1 return t end)()))
    local typed=role({'damage'},{types={fire=2.5}})
    assert(same(harm.spread(typed,creature()),{0,0,0.5,0.5}))
    assert(same(harm.spread(hurt({roll('magic',1,6,0,{p=0.5})}),creature()),{0.5,1/12,1/12,1/12,1/12,1/12,1/12}))
    local copies=harm.spread(hurt({roll('magic',1,6,0,{times=2})}),creature())
    assert(same(copies,count(2,6)))
    local many=harm.spread(hurt({roll('magic',1000,6)}),creature({hp=5000,maxHp=5000}))
    assert(#many==3501 and many[3501]==1)
    -- Twelve explosions on 40 hit points and ten copies of a roll (added up by squaring).
    local taken12,all12=capped(count(12,6),40)
    w,x=harm.damage(hurt({roll('magic',1,6)}),creature({hp=40}),0.5,0,12)
    assert(all12>0 and near(w,taken12/60+0.5*all12) and near(x,taken12))
    assert(same(harm.spread(hurt({roll('magic',1,2,0,{times=10})}),creature()),count(10,2)))
    groups=groups+1
end

-- 8. Disables on the last foe in play (alone): a charm or a maze puts it out of the side's reach,
-- so there it counts for nothing (lab batch J run 3); a hold, which lets the side strike, counts as
-- before, and a role that holds as well as charms counts as the hold.
do
    local f=creature()
    local charm,maze,hold=role({'charm'}),role({'maze'}),role({'hold'})
    assert(near(harm.disable(charm,f,0.5),1.2) and near(harm.disable(maze,f,0.5),1.2))
    assert(harm.disable(charm,f,0.5,0,true)==0 and harm.disable(maze,f,0.5,0,true)==0)
    assert(near(harm.disable(hold,f,0.5,0,true),1) and near(harm.disable(hold,f,0.5,0,true),harm.disable(hold,f,0.5)))
    assert(near(harm.disable(role({'charm','hold'}),f,0.5,0,true),1))
    -- Petrification takes a creature out for good, as a kill does: alone or not.
    assert(near(harm.disable(role({'petrify'}),f,0.5,0,true),1*(1+0.5)))
    groups=groups+1
end

-- 9. One the other side charmed (charmed, among the enemies) fights for it: no disabled creature,
-- so a hold counts on it as on any enemy, and its weapon counts against the side it fights; a
-- charm counts for nothing on it, as it is freed, not charmed over (a charm of the evil side would
-- set it against its own group once it ends).
do
    local thrall=creature({state=0x2000})
    assert(harm.disable(role({'charm'}),thrall,0.5)==0 and near(harm.disable(role({'hold'}),thrall,0.5),1))
    assert(near(harm.disable(role({'charm','hold'}),thrall,0.5),1))
    local frame={self={id=1,x=0,y=0,hp=40,maxHp=40,state=0,ac=5},allies={},enemies={creature({x=20,state=0x2000})}}
    assert(threat.picture(frame)[1].weapon.hp>0)
    frame.enemies[1].held=1
    assert(threat.picture(frame)[1].weapon.hp==0)
    groups=groups+1
end

-- 10. Strength-lowering debuffs (Ray of Enfeeblement sets STR 5; poison/contagion subtract points):
-- count through arsenal.might (installed tables when given, else shipped STRMOD/STRMODEX) on weapons
-- that take strength's hit or damage bonuses. A target already weaker or a bow without strength flags
-- loses nothing.
do
    -- Fighter with STR 18/76 (+2 hit, +4 damage shipped) swinging 2 APR at THAC0 10 for 10 against AC 5:
    -- 2 * 0.8 * 10 = 16 a round. Ray of Enfeeblement sets STR 5 (-2 hit, -1 damage: 4 worse THAC0, 5 less
    -- damage) -> 2 * 0.6 * 5 = 6 a round, losing 10/16 = 0.625.
    local strong=creature({attack={apr=2,thac0=10,damage=10,damageType=3,str=18,strExtra=76,
        strengthHit=true,strengthDamage=true}})
    local enfeeble=role({'strength'},{strengthSet=5})
    assert(near(harm.weaken(enfeeble,strong,5),1-6/16))
    assert(near(harm.debuff(enfeeble,strong,5),1-6/16))

    -- Installed tables override shipped ones, including row 0 when STR drops to 0.
    local custom={strmod={[0]={hit=-10,damage=-8},[5]={hit=-1,damage=-2},[18]={hit=1,damage=2}},
        strmodex={[76]={hit=2,damage=3}}}
    -- Custom 18/76 gives +3 hit, +5 damage; STR 5 gives -1 hit, -2 damage -> 4 worse THAC0, 7 less damage:
    -- 2 * 0.6 * 3 = 3.6 of 16.
    assert(near(harm.weaken(enfeeble,strong,5,custom),1-3.6/16))
    local drainedZero=role({'strength'},{amounts={strength=20}})
    -- Without tables row 0 clamps to shipped row 1 (-5 hit, -4 damage -> 7 worse THAC0, 8 less damage:
    -- 2 * 0.45 * 2 = 1.8 of 16); with custom row 0 (-10 hit, -8 damage -> damage 0).
    assert(near(harm.weaken(drainedZero,strong,5),1-1.8/16))
    assert(near(harm.weaken(drainedZero,strong,5,custom),1))

    -- Exceptional strength lowered alone (18/100 +3/+6 -> 18/40 +1/+3: 2 worse THAC0, 3 less damage).
    local champ=creature({attack={apr=2,thac0=10,damage=10,damageType=3,str=18,strExtra=100,
        strengthHit=true,strengthDamage=true}})
    assert(near(harm.weaken(role({'strengthExtra'},{amounts={strengthExtra=60}}),champ,5),1-(2*0.7*7)/16))
    assert(near(harm.weaken(role({'strengthExtra'},{strengthExtraSet=40}),champ,5),1-(2*0.7*7)/16))

    -- Partial weapon flags (thrown/sling with damage only, or hit only), bow with neither, unknown STR,
    -- or target already at STR 3 (< 5): no negative gain.
    local sling=creature({attack={apr=2,thac0=10,damage=10,ranged=true,str=18,strExtra=76,
        strengthHit=false,strengthDamage=true}})
    assert(near(harm.weaken(enfeeble,sling,5),1-(2*0.8*5)/16))
    local hitOnly=creature({attack={apr=2,thac0=10,damage=10,str=18,strExtra=76,
        strengthHit=true,strengthDamage=false}})
    assert(near(harm.weaken(enfeeble,hitOnly,5),1-(2*0.6*10)/16))
    local archer=creature({attack={apr=2,thac0=10,damage=10,ranged=true,str=18,strExtra=76}})
    assert(harm.weaken(enfeeble,archer,5)==0)
    assert(harm.weaken(enfeeble,creature({attack={apr=2,thac0=10,damage=10,strengthHit=true,strengthDamage=true}}),5)==0)
    local weakling=creature({attack={apr=2,thac0=10,damage=10,str=3,strengthHit=true,strengthDamage=true}})
    assert(harm.weaken(enfeeble,weakling,5)==0)

    -- Through choice.decide, Rezdan's Ray of Enfeeblement aims at the high-STR fighter over the archer
    -- and uses input.tables.
    local spells=require('combat-intent.spells')
    local choice=require('combat-intent.choice')
    local mind=require('combat-intent.mind')
    local ray=spells.classify({kind='SPL',resref='TESTRAY',name=0,flags=1024,spellType=1,exclusion=0,school=0,
        secondary=0,level=2,casting={},abilities={{form=1,flags=0,location=2,target=1,targetCount=0,range=40,
        minLevel=1,speed=0,projectile=1,effects={{opcode=44,target=2,power=2,p1=5,p2=1,timing=0,resist=1,
        duration=60,prob1=100,prob2=0,res='',dice=0,sides=0,save=1,saveBonus=0,special=0}}}}},1,function() end,{level=7})
    local inp={tick=100,family='mage',frame={
        self={id=1,x=0,y=0,hp=30,maxHp=30,state=0,held=0,ac=5,level=7,ids={class=1}},
        allies={},
        enemies={
            creature({id=11,x=120,ac=4,sanctuary=0,action=0,protections={},attack=archer.attack}),
            creature({id=12,x=120,ac=4,sanctuary=0,action=0,protections={},attack=strong.attack}),
        }},
        spells={{resref='TESTRAY',level=2,ready=1,memorized=1,usable=true,list='mage',spell=ray}},
        plan={},memory={},mind=mind.new(),tables=custom}
    local dec=choice.decide(inp)
    assert(dec and dec.resref=='TESTRAY' and dec.target==12)
    assert(near(dec.worth,(1-3.6/16)*harm.chance(ray.roles.debuff,inp.frame.enemies[2])))
    groups=groups+1
end

return groups
