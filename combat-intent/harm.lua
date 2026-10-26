-- What an attack's damage, disable or debuff does to one creature, on the attack's scale (shares
-- of a creature taken out of the fight), as plain numbers. The engine's own attacks weigh their enemies
-- with it (combat-intent/choice.lua, which adds its focus and what it remembers of misses), and
-- danger zones weigh the caster with it (combat-intent/zones.lua): what a cloud does to a creature
-- counts as much as the same spell on an enemy. Nothing here touches the engine or raises on odd
-- data.
local targeting=require('combat-intent.targeting')
local ids=require('combat-intent.ids')
local threat=require('combat-intent.threat')
local weapons=require('combat-intent.weapons')
local M={}
-- A disable lasting this long counts in full (three rounds).
M.fullSeconds=18
-- What each kind of disable is worth on a creature in full health, for the full time. Death,
-- petrification and imprisonment take it out for good.
M.DISABLE={hold=1,stun=1,sleep=0.8,charm=1.2,confusion=0.8,panic=0.7,berserk=0.4,feeblemind=1,
    silence=0.7,nocast=0.7,entangle=0.5,web=0.6,root=0.3,polymorph=1,pause=0.8,maze=1.2,
    turnUndead=1,petrify=1,imprison=1,death=1}
M.FOR_GOOD={petrify=true,imprison=true,death=true}
-- Disables that matter only against casters.
M.CASTERS_ONLY={feeblemind=true,silence=true,nocast=true}
-- Damage types to the resistance a creature's details carry (adapters/eeex/sense.lua reads
-- SCS's stats).
M.RESIST={fire='fire',cold='cold',electricity='electricity',acid='acid',magic='magic',
    magicfire='magicfire',magiccold='magiccold',slashing='slashing',crushing='crushing',
    piercing='piercing',missile='missile',poison='poison'}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- The share of a damage type that gets through e's resistance.
function M.resisted(e,label)
    local r=type(e.resist)=='table' and e.resist[M.RESIST[label] or '']
    if not number(r) then return 1 end
    return math.max(0,1-r/100)
end

-- How long a condition holds on e when e gets a save every bf.every seconds to break free
-- (breakFree, combat-intent/spells.lua: Spell Revisions' Greater Command): the first stretch for
-- sure, each later one while every save so far failed, up to the condition's duration.
function M.brokenFree(duration,bf,e)
    if not number(duration) or duration<=0 then return 0 end
    local every=type(bf)=='table' and number(bf.every) and bf.every>0 and bf.every or duration
    local s=type(bf)=='table' and targeting.saveChance({save=bf.save,saveBonus=bf.saveBonus},e) or 0
    local held,stay,t,steps=0,1,0,0
    while t<duration and steps<100 do
        local span=math.min(every,duration-t)
        held=held+span*stay
        t=t+span;steps=steps+1
        stay=stay*(1-s)
    end
    return held
end

-- The worth of a damage role on e and the hit points it is expected to take (no more than e has
-- left above floor): the share of e's maximum, and the kill bonus as likely as the hit points it
-- deals (halved on a save, if it allows half) reach those e has left. floor: the hit points e
-- keeps at least (its minimum, targeting.floor; one for a strike that keeps its target alive, as
-- Harm does); no kill while one holds (lab batch H9: a priest stayed 39 seconds in an Incendiary
-- Cloud to finish a mage whose minimum kept it at one hit point).
function M.damage(role,e,killBonus,floor)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    floor=number(floor) and floor>0 and floor or 0
    hp=hp-floor
    if hp<=0 then return 0,0 end
    local amount=0
    for label,v in pairs(type(role.types)=='table' and role.types or {}) do
        if number(v) then amount=amount+v*M.resisted(e,label) end
    end
    if number(role.percent) then amount=amount+maxHp*role.percent/100 end
    if amount<=0 then return 0,0 end
    local land=targeting.landing(role,e)
    local save=targeting.saveChance(role,e)
    local expected=amount*land*(role.saveForHalf and 1-save/2 or 1-save)
    local worth=math.min(expected,hp)/maxHp
    local kill=0
    if amount>=hp and floor<=0 then
        kill=land*((role.saveForHalf and amount/2>=hp) and 1 or 1-save)
    end
    worth=worth+(number(killBonus) and killBonus or 0)*kill
    return worth,math.min(expected,hp)
end

-- Whether e's level lies within the role's levels (any level when e's is unknown).
function M.within(role,e)
    local level=type(e)=='table' and e.level
    return not (number(level) and ((number(role.maxLevel) and level>role.maxLevel) or
        (number(role.minLevel) and level<role.minLevel)))
end
-- The chance a role lands on e and holds: magic resistance, the saving throw and the effect's own
-- chance.
function M.chance(role,e)
    return targeting.landing(role,e)*(1-targeting.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
end
-- How long a role holds on e, as a share of fullSeconds: its duration, or what e keeps of it where
-- it breaks free; all of it when it lasts, half when its duration is unknown.
local function length(role,e)
    if role.duration=='permanent' then return 1 end
    if number(role.duration) and role.duration>0 then
        local span=role.duration
        if type(role.breakFree)=='table' then span=M.brokenFree(span,role.breakFree,e) end
        return clamp(span/M.fullSeconds,0,1)
    end
    return 0.5
end

-- The worth of a disable role on e: what its strongest kind is worth for as long as it holds
-- (taking a nearly dead creature out is worth less than taking out a healthy one; taking one out
-- for good is worth what killing it is), times the chance it lands: magic resistance, the saving
-- throw and the effect's own chance. Nothing on a creature already disabled, outside the role's
-- levels or at or above its hit point limit. While a minimum holds on e (floor above 0, as for
-- M.damage), only a death that slays (role.slays, combat-intent/spells.lua) kills it.
function M.disable(role,e,killBonus,floor)
    if targeting.disabled(e) or not M.within(role,e) then return 0 end
    -- A power word works by the hit points e has now: in a Time Stop, not counting what lands
    -- when time resumes (hpNow).
    local now=number(e.hpNow) and e.hpNow or e.hp
    if number(role.belowHp) and number(now) and now>=role.belowHp then return 0 end
    local factor,forGood=0,false
    for label in pairs(type(role.kinds)=='table' and role.kinds or {}) do
        local f=M.DISABLE[label] or 0
        if M.CASTERS_ONLY[label] and not ids.caster(e) then f=f*0.2 end
        if label=='turnUndead' and not (type(e.ids)=='table' and e.ids.general==4) then f=0 end
        if label=='sleep' and role.wakesOnDamage then f=f*0.6 end
        if label=='death' and number(floor) and floor>0 and not role.slays then f=0 end
        if f>factor then factor,forGood=f,M.FOR_GOOD[label]==true end
    end
    if factor<=0 then return 0 end
    local health=targeting.health(e)
    local bonus=number(killBonus) and killBonus or 0
    local worth=forGood and factor*(health+bonus) or factor*length(role,e)*(0.5+0.5*health)
    return worth*M.chance(role,e)
end

-- Weakening (F2b; IESDP): what a debuff takes from a creature's own fight while it holds, as a
-- share of the harm it deals as combat-intent/threat.lua counts it: its weapon's hits a round
-- (attacks, the chance to hit the armour class it meets, the damage of a hit) and its spells (how
-- much of its class casts, times its level). Slow halves all a creature does: it acts every second
-- tick, so it makes half its attacks and casts in twice the time (ie-duration.md). On EE blindness
-- costs 4 to hit, and two blindnesses no more. Luck counts on attack rolls point for point, a
-- negative chant's too, and fatigue above fatigueFree costs a point of luck each (FATIGMOD.2DA, as
-- for a rested creature). Casting failure counts by kind of spell (wizard, priest, innate), and
-- deafness fails half of wizard and priest spells besides. A lower casting level weakens a
-- creature's spells by the levels it takes, and drained levels weaken its weapon and its spells by
-- theirs. A creature already slowed or blind gets nothing more from another slow or blindness.
-- Lower strength, dexterity and constitution do not count yet: the engine reads neither the stats
-- nor their tables.
M.blindHit=4
M.blindArmor=4
M.deafFailure=50
M.fatigueFree=6
-- The damage types opcode 332 lowers (its parameter 2) for each kind of weapon damage; 0 lowers all.
local PERCENT_TYPES={slashing=7,piercing=8,crushing=9,missile=10}
local function amount(role,label)
    local a=type(role)=='table' and role.amounts
    local v=type(a)=='table' and a[label]
    return number(v) and v or 0
end
-- The share of e's spells that fail under role: by the kinds of spell its classes cast, half each
-- for one that casts both; one of no casting class casts innate abilities.
local function failing(role,e)
    local by=type(role.miscastBy)=='table' and role.miscastBy or {}
    local deaf=type(role.kinds)=='table' and role.kinds.deaf and M.deafFailure or 0
    local total,n=0,0
    for _,kind in ipairs({'arcane','divine'}) do
        if ids[kind](e) then
            total,n=total+math.min(100,(number(by[kind]) and by[kind] or 0)+deaf),n+1
        end
    end
    if n==0 then return clamp((number(by.innate) and by.innate or 0)/100,0,1) end
    return total/n/100
end
-- What role takes from e's fight while it holds, a share from 0 to 1. ac: the armour class e's
-- weapon meets (threat.hitChance's default when nil). The caster itself carries the weapon in its
-- hand (weapon) rather than attack data.
function M.weaken(role,e,ac)
    if type(role)~='table' or type(e)~='table' then return 0 end
    local k=type(role.kinds)=='table' and role.kinds or {}
    local held=e.attack
    if held==nil and type(e.weapon)=='table' then held=threat.wielded(e) end
    local a=threat.attack({attack=held})
    local level=number(e.level) and e.level>0 and e.level or 1
    local armed=held~=false
    local weapon=armed and a.apr*threat.hitChance(a.thac0,ac)*a.damage or 0
    local spell=threat.casting(e)*threat.spellPerLevel*level
    if weapon+spell<=0 then return 0 end
    local slow=(k.slow and not targeting.has(e.state,targeting.STATE.slowed)) and 0.5 or 1
    local kept=math.max(0,level-amount(role,'drain'))/level
    local worse=amount(role,'thac0')+amount(role,'luck')+math.max(0,amount(role,'fatigue')-M.fatigueFree)+
        math.max(0,a.thac0)*amount(role,'thac0Percent')/100
    if number(role.thac0Set) then worse=worse+math.max(0,role.thac0Set-a.thac0) end
    if k.blind and not targeting.has(e.state,targeting.STATE.blind) then worse=worse+M.blindHit end
    local by=type(role.damagePercentBy)=='table' and role.damagePercentBy or {}
    local label=weapons.DAMAGE[a.damageType]
    local typed=label and by[PERCENT_TYPES[label]]
    local percent=(number(by[0]) and by[0] or 0)+(number(typed) and typed or 0)
    local apr=math.max(0,a.apr-threat.attacks(amount(role,'attacks')))*slow
    local damage=math.max(0,a.damage-amount(role,'damage'))*math.max(0,1-percent/100)
    local after=armed and apr*threat.hitChance(a.thac0+worse,ac)*damage*kept or 0
    local power=math.max(0,level-amount(role,'castingLevel'))/level
    local cast=spell*slow*kept*power*(1-failing(role,e))
    return clamp(1-(after+cast)/(weapon+spell),0,1)
end

-- Whether e carries a spell's effects already: one of its active effects (e.wards,
-- adapters/eeex/sense.lua) comes from the spell or from what it delivers (spell.sources, the
-- spell's own resref among them; resref when the spell names none), or the spell is among those
-- that land on e when time resumes (e.carried, combat-intent/choice.lua's frozen). Without wards
-- read, only those.
function M.carries(e,spell,resref)
    if type(e)~='table' or (type(e.wards)~='table' and type(e.carried)~='table') then return false end
    local from={}
    for res in pairs(type(spell)=='table' and type(spell.sources)=='table' and spell.sources or {}) do
        if type(res)=='string' and res~='' then from[res:upper()]=true end
    end
    if type(resref)=='string' and resref~='' then from[resref:upper()]=true end
    for res in pairs(type(e.carried)=='table' and e.carried or {}) do
        if type(res)=='string' and from[res:upper()] then return true end
    end
    for _,w in ipairs(type(e.wards)=='table' and e.wards or {}) do
        if type(w)=='table' and type(w.source)=='string' and from[w.source:upper()] then return true end
    end
    return false
end

-- The worth of a debuff role on e: the share of e's fight it takes (M.weaken, with ac as there)
-- for as long as it holds, as a disable counts its kind (a hold that takes all of a healthy
-- creature's fight for the full time is worth 1), times the chance it lands. Nothing on a creature
-- already disabled or outside the role's levels.
function M.debuff(role,e,ac)
    if type(role)~='table' or type(e)~='table' or targeting.disabled(e) or not M.within(role,e) then return 0 end
    local share=M.weaken(role,e,ac)
    if share<=0 then return 0 end
    return share*length(role,e)*(0.5+0.5*targeting.health(e))*M.chance(role,e)
end

-- e as it stands under role's lower defences, for what other attacks gain from them: a copy with
-- its saving throws worse by the role's points per save, its magic resistance and resistances
-- lower and its armour class worse by the role's points and blindness's 4 (once, on EE); nil when
-- the role lowers none of them.
function M.weakened(role,e)
    if type(role)~='table' or type(e)~='table' then return nil end
    local by=type(role.saveBy)=='table' and role.saveBy or {}
    local resist=type(role.resist)=='table' and role.resist or {}
    local k=type(role.kinds)=='table' and role.kinds or {}
    local armor=number(e.ac) and amount(role,'armor') or 0
    if number(e.ac) and k.blind and not targeting.has(e.state,targeting.STATE.blind) then armor=armor+M.blindArmor end
    local mr=amount(role,'magicResistance')
    local saves=next(by)~=nil and type(e.saves)=='table'
    if not saves and next(resist)==nil and armor<=0 and mr<=0 then return nil end
    local c={}
    for key,v in pairs(e) do c[key]=v end
    if saves then
        c.saves={}
        for name,v in pairs(e.saves) do c.saves[name]=number(v) and number(by[name]) and v+by[name] or v end
    end
    if next(resist)~=nil then
        c.resist={}
        for name,v in pairs(type(e.resist)=='table' and e.resist or {}) do c.resist[name]=v end
        for label,v in pairs(resist) do
            local key=M.RESIST[label] or label
            if number(v) then c.resist[key]=(number(c.resist[key]) and c.resist[key] or 0)-v end
        end
    end
    if armor>0 then c.ac=e.ac+armor end
    if mr>0 then c.mr=math.max(0,(number(e.mr) and e.mr or 0)-mr) end
    return c
end
return M
