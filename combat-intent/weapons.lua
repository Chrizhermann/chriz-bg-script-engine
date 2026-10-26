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
-- Seconds a creature takes to take up another weapon (F2c, SelectWeaponAbility): not measured yet,
-- a lab is to. A switch lowers the round's worth as a walk of that length does (M.paced), so a
-- creature changes its weapon only for one clearly better.
M.switchSeconds=1
-- Effects that keep a missile off by its projectile: immunity (opcode 83) and bounce (197).
local MISSILE_GUARDS={[83]=true,[197]=true}
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- Opcode 1's values 6 to 10 are half attacks: 6 is a half, 7 one and a half, up to 10.
local function decoded(v) if v>5 and v<=10 then return v-5.5 end return v end
local function average(dice,sides)
    if not number(dice) or not number(sides) or dice<=0 or sides<=0 then return 0 end
    return dice*(sides+1)/2
end

-- The average damage an item ability's own effects add to a hit: opcode 12 in its normal mode on
-- the creature hit, its amount and dice, times its chance (as combat-intent/spells.lua weighs
-- probability windows). A summoned jelly's acid and an elemental's fire come this way.
function M.onHit(ability)
    local total=0
    for _,e in ipairs(type(ability)=='table' and type(ability.effects)=='table' and ability.effects or {}) do
        if type(e)=='table' and e.opcode==12 and e.target==2 and number(e.p2) and e.p2%65536==0 then
            local high=number(e.prob1) and math.min(e.prob1,100) or 100
            local chance=math.max(0,math.min(1,(high-(number(e.prob2) and e.prob2 or 0)+1)/101))
            total=total+math.max(0,(number(e.p1) and e.p1 or 0)+average(e.dice,e.sides))*chance
        end
    end
    return total
end

-- The on-hit effects of a list (combat-intent/spells.lua's hits, F2a) that a hit with weapon w
-- brings: melee ones (opcode 248) with a melee weapon, those for fists only when w is the fist;
-- ranged ones (249) with missiles and thrown weapons.
function M.payloads(hits,w)
    local out={}
    if type(hits)~='table' or type(w)~='table' then return out end
    for _,h in ipairs(hits) do
        if type(h)=='table' and type(h.strike)=='table' then
            local fits
            if w.ranged then fits=h.ranged==true
            else fits=h.melee==true and (not h.fists or w.fist==true) end
            if fits then out[#out+1]=h end
        end
    end
    return out
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
-- Whether e keeps off the missiles of weapon w (F2c): an immunity to its projectile or one that
-- turns it back (opcodes 83 and 197, by the PROJECTL.IDS entry one below the projectile field, as
-- combat-intent/targeting.lua reads them for spells; EE Fixpack adds the entries of darts,
-- throwing daggers and throwing axes to Protection from Normal Missiles this way), and what SCS's
-- archers keep away from ([src] ssl/library.slb, ArrowSafe): protection from normal missiles
-- against a hit that is not magical, and a Physical Mirror. Melee weapons pass.
function M.missileBlocked(e,w)
    if type(e)~='table' or type(w)~='table' or not w.ranged then return false end
    if e.reflects==true then return true end
    local magical=(number(w.enchantment) and w.enchantment>0) or targeting.has(w.flags,FLAG.magical)
    if e.normalMissiles==true and not magical then return true end
    if not number(w.projectile) or type(e.protections)~='table' then return false end
    for _,p in ipairs(e.protections) do
        if type(p)=='table' and MISSILE_GUARDS[p.opcode] and number(p.p2) and p.p2+1==w.projectile then return true end
    end
    return false
end

-- How far, in world units, the caster goes for a melee hit: the profile's touchReach in range
-- units (SCS's touch attacks: within 10); any distance for a creature that chases (mind.chase:
-- fighters and monsters); no further than a weapon reaches (threat.reach) for one that cannot walk
-- (webbed or entangled: caster.rooted).
function M.reach(mind,caster)
    if type(caster)=='table' and caster.rooted==true then return threat.reach end
    if type(mind)=='table' and mind.chase==true then return math.huge end
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
    local far=type(w)=='table' and w.ranged and (number(w.range) and w.range or 0) or M.reach(mind,caster)
    if d>far then return false,'out-of-reach' end
    return true
end
-- Seconds the caster walks to come within far of p (a creature or a point), at its own speed or a
-- fighter's (threat.stride a round): none within far already; nil when it cannot walk there (webbed
-- or entangled: caster.rooted) or p has no spot.
function M.approach(caster,p,far)
    local d=targeting.distance(caster,p)
    if d==math.huge then return nil end
    if d<=far then return 0 end
    if caster.rooted==true then return nil end
    local speed=number(caster.speed) and caster.speed>0 and caster.speed or threat.stride/threat.ROUND
    return (d-far)/speed
end
-- Seconds the caster walks before it can strike e in melee: to a weapon's reach of e (threat.reach).
function M.walk(caster,e) return M.approach(caster,e,threat.reach) or 0 end
-- The share of a round of melee hits that counts as this round's when a walk of the given seconds
-- comes first: the hits take the round and the walk (a walk of half a round leaves two thirds).
function M.paced(walk)
    if not number(walk) or walk<=0 then return 1 end
    return threat.ROUND/(threat.ROUND+walk)
end

-- Hit points a round the caster takes at spot from melee weapons that reach it already: living
-- enemies not disabled within a weapon's reach (combat-intent/threat.lua), whatever they attack
-- now, against the caster's armour class.
function M.meleeAt(frame,spot)
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
    return math.max(0,M.meleeAt(frame,e)-M.meleeAt(frame,frame.self))
end

-- Hits a round on e of a weapon swung apr times with thac0 (bonuses in): d20 rolls against e's
-- armour class, less the hits its Mirror Images and Stoneskin skins take first; then the hits before
-- those and the hits they take.
function M.hits(apr,thac0,e)
    local raw=(number(apr) and apr>0 and apr or 0)*threat.hitChance(thac0,e.ac)
    local absorbed=(number(e.mirror) and e.mirror>0 and e.mirror or 0)+(number(e.skins) and e.skins>0 and e.skins or 0)
    return math.max(0,raw-absorbed),raw,absorbed
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
