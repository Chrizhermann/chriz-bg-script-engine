-- Weapon attacks (step 3, D2c; DEFENCE-01): the weapon in the caster's hand, ordinary or
-- conjured, as an attack the engine weighs against its spells, and the spells that conjure one,
-- worth the hits the weapon deals in the rounds after (Christopher, 2026-10-20: conjured weapons
-- as an attack option; the engine should take every round it can). Touch charges
-- (combat-intent/touch.lua) build on the same reach and immunities. Plain values only; nothing
-- here touches the engine.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local M={}
-- Item flags (ITM header): two-handed, cursed, magical, silver, cold iron.
local FLAG={twoHanded=0x2,cursed=0x10,magical=0x40,silver=0x100,coldIron=0x200}
-- An item ability's damage type as a resistance (ITM): the mixed types count as their first,
-- non-lethal fists as crushing.
M.DAMAGE={[1]='piercing',[2]='crushing',[3]='slashing',[4]='missile',[5]='crushing',[6]='piercing',
    [7]='piercing',[8]='crushing',[9]='crushing'}
-- Weapon attacks a round of a caster whose own is unknown.
M.baseApr=1
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- Opcode 1's values 6 to 10 are half attacks: 6 is a half, 7 one and a half, up to 10.
local function decoded(v) if v>5 and v<=10 then return v-5.5 end return v end
local function average(dice,sides)
    if not number(dice) or not number(sides) or dice<=0 or sides<=0 then return 0 end
    return dice*(sides+1)/2
end

-- Whether an immunity to weapons (opcode 120, by its type p2) keeps weapon w off (its flags and
-- enchantment). Type 0 keeps off weapons up to +p1, as combat-intent/defence.lua reads it; a
-- weapon is magical with the flag or an enchantment (SR's Chill Touch hand is neither). Unknown
-- types count as keeping it off.
function M.immune(p,w)
    local flags=number(w.flags) and w.flags or 0
    local plus=number(w.enchantment) and w.enchantment or 0
    local magical=plus>0 or targeting.has(flags,FLAG.magical)
    local silver,cold=targeting.has(flags,FLAG.silver),targeting.has(flags,FLAG.coldIron)
    local two,cursed=targeting.has(flags,FLAG.twoHanded),targeting.has(flags,FLAG.cursed)
    local by={[0]=plus<=(number(p.p1) and p.p1 or 0),[1]=magical,[2]=not magical,[3]=silver,[4]=not silver,
        [5]=not silver and not magical,[6]=two,[7]=not two,[8]=cursed,[9]=not cursed,[10]=cold,[11]=not cold}
    local v=by[p.p2]
    if v==nil then return true end
    return v
end
-- Whether e is immune to weapon w (opcode 120). Unknown protections count as protecting.
function M.immuneTo(e,w)
    if type(e.protections)~='table' then return true end
    for _,p in ipairs(e.protections) do
        if type(p)=='table' and p.opcode==120 and M.immune(p,w) then return true end
    end
    return false
end

-- How far, in world units, the caster goes for a melee hit: the profile's touchReach in range
-- units (SCS's touch attacks: within 10).
function M.reach(mind)
    return (type(mind)=='table' and number(mind.touchReach) and mind.touchReach or 0)*targeting.rangeUnit
end
-- Whether the caster can attack e with weapon w: alive, no sanctuary, seen, within the weapon's
-- range for missiles and thrown weapons, within reach for melee. Else false and why. A weapon
-- without its own (w nil) counts as melee.
function M.reachable(caster,e,mind,w)
    if not targeting.alive(e) then return false,'dead' end
    if number(e.sanctuary) and e.sanctuary>0 then return false,'sanctuary' end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    local d=targeting.distance(caster,e)
    if d==math.huge then return false,'no-position' end
    local far=type(w)=='table' and w.ranged and (number(w.range) and w.range or 0) or M.reach(mind)
    if d>far then return false,'out-of-reach' end
    return true
end

-- Hit points a round the caster takes at spot from melee weapons that reach it already: living
-- enemies not disabled within a weapon's reach (combat-intent/threat.lua), whatever they attack
-- now, against the caster's armour class.
local function melee(frame,spot)
    local hp=0
    for _,o in ipairs(frame.enemies) do
        if targeting.alive(o) and not targeting.disabled(o) then
            local a=threat.attack(o)
            if not a.ranged and targeting.distance(o,spot)<=threat.reach then
                hp=hp+a.apr*threat.hitChance(a.thac0,frame.self.ac)*a.damage
            end
        end
    end
    return hp
end
-- Hit points a round the caster would take more standing next to e than where it stands: the
-- melee at e's spot (e's own among it) less the melee at the caster's. Not threat.picture's
-- round: in it every melee enemy within a round's walk strikes wherever the caster stands.
-- Ranged weapons reach the caster anywhere and do not count.
function M.exposure(frame,e)
    return math.max(0,melee(frame,e)-melee(frame,frame.self))
end

-- Hits a round on e of a weapon swung apr times with thac0 (bonuses in): d20 rolls against e's
-- armour class, less the hits its Mirror Images and Stoneskin skins take first.
function M.hits(apr,thac0,e)
    local raw=(number(apr) and apr>0 and apr or 0)*threat.hitChance(thac0,e.ac)
    local absorbed=(number(e.mirror) and e.mirror>0 and e.mirror or 0)+(number(e.skins) and e.skins>0 and e.skins or 0)
    return math.max(0,raw-absorbed)
end

-- The weapon a classified spell conjures for the caster as an attack (arms), or nil: its first
-- weapon that is no touch charge, with the caster's THAC0 less the weapon's bonus, its attacks a
-- round (set or raised by the item, opcode 1), its average damage and its range in world units.
-- Rounds: how long it lasts, from its uses and its duration (nil when neither is known).
function M.conjured(spell,caster)
    if type(spell)~='table' or type(spell.weapons)~='table' then return nil end
    for _,w in ipairs(spell.weapons) do
        if type(w)=='table' and w.touch~=true and (w.attack=='melee' or w.attack=='ranged' or w.attack=='launcher') then
            local apr=number(w.aprSet) and decoded(w.aprSet) or (number(caster.apr) and caster.apr>0 and caster.apr or
                M.baseApr)+(number(w.aprAdd) and w.aprAdd or 0)
            local thac0=number(caster.thac0) and caster.thac0 or nil
            if thac0 and number(w.toHit) then thac0=thac0-w.toHit end
            local rounds
            if number(w.uses) and w.uses>0 and apr>0 then rounds=w.uses/apr end
            if number(w.seconds) and w.seconds>0 then rounds=math.min(rounds or math.huge,w.seconds/6) end
            return {item=w.item,damage=average(w.dice,w.sides)+(number(w.bonus) and w.bonus or 0),damageType=w.damageType,
                apr=apr,thac0=thac0,ranged=w.attack~='melee',range=number(w.range) and w.range*targeting.rangeUnit or nil,
                flags=w.flags,enchantment=w.enchantment,strike=w.strike,rounds=rounds}
        end
    end
end
return M
