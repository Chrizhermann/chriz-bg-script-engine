-- What an attack's damage or disable does to one creature, on the attack's scale (shares of a
-- creature taken out of the fight), as plain numbers. The engine's own attacks weigh their enemies
-- with it (combat-intent/choice.lua, which adds its focus and what it remembers of misses), and
-- danger zones weigh the caster with it (combat-intent/zones.lua): what a cloud does to a creature
-- counts as much as the same spell on an enemy. Nothing here touches the engine or raises on odd
-- data.
local targeting=require('combat-intent.targeting')
local ids=require('combat-intent.ids')
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

-- The worth of a disable role on e: what its strongest kind is worth for as long as it holds
-- (taking a nearly dead creature out is worth less than taking out a healthy one; taking one out
-- for good is worth what killing it is), times the chance it lands: magic resistance, the saving
-- throw and the effect's own chance. Nothing on a creature already disabled, outside the role's
-- levels or at or above its hit point limit. While a minimum holds on e (floor above 0, as for
-- M.damage), only a death that slays (role.slays, combat-intent/spells.lua) kills it.
function M.disable(role,e,killBonus,floor)
    if targeting.disabled(e) then return 0 end
    local level=e.level
    if number(level) and ((number(role.maxLevel) and level>role.maxLevel) or (number(role.minLevel) and level<role.minLevel)) then
        return 0
    end
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
    local length
    if forGood then length=1
    elseif role.duration=='permanent' then length=1
    elseif number(role.duration) and role.duration>0 then
        local span=role.duration
        if type(role.breakFree)=='table' then span=M.brokenFree(span,role.breakFree,e) end
        length=clamp(span/M.fullSeconds,0,1)
    else length=0.5 end
    local bonus=number(killBonus) and killBonus or 0
    local worth=forGood and factor*(health+bonus) or factor*length*(0.5+0.5*health)
    local chance=targeting.landing(role,e)*(1-targeting.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
    return worth*chance
end
return M
