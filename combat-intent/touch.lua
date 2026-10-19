-- Touch charges (step 3, D2c; DEFENCE-01): spells that put a weapon of one hit in the caster's
-- hand, such as Spell Revisions' Harm, the Cause Wounds spells, Slay Living, Shocking Grasp and
-- Chill Touch (combat-intent/spells.lua reads them: a weapon entry with touch=true). The caster
-- casts the spell on itself, walks up and strikes; the hit delivers the charge.
--
-- As SCS's touch attacks do (priest/ssl/combatblocks/touch_attacks.ssl and
-- meleeblocks/touchattack.ssl): only at an enemy within reach, which the strike can hit and the
-- charge can work on; and the strike follows at once, again and again until the charge lands
-- (Christopher, 2026-10-19: Harm is very strong, so choose the moment with care and make sure it
-- lands and deals its damage). Plain values only; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local M={}
-- Rounds the caster stands in reach of its target's friends: the strike, and another after a
-- miss now and then.
M.exposedRounds=1.5
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

-- The touch charge a classified spell gives, or nil: its first weapon of one melee hit.
function M.charge(spell)
    if type(spell)~='table' or type(spell.weapons)~='table' then return nil end
    for _,w in ipairs(spell.weapons) do
        if type(w)=='table' and w.touch==true and type(w.strike)=='table' then return w end
    end
end

-- How far, in world units, the caster goes for a strike: the profile's touchReach in range
-- units (SCS: within 10).
function M.reach(mind)
    return (type(mind)=='table' and number(mind.touchReach) and mind.touchReach or 0)*targeting.rangeUnit
end

-- Whether the caster can go for e: alive, no sanctuary, seen, within reach. Else false and why.
function M.reachable(caster,e,mind)
    if not targeting.alive(e) then return false,'dead' end
    if number(e.sanctuary) and e.sanctuary>0 then return false,'sanctuary' end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    local d=targeting.distance(caster,e)
    if d==math.huge then return false,'no-position' end
    if d>M.reach(mind) then return false,'out-of-reach' end
    return true
end

-- The chance a swing of w hits e: a d20 against the caster's THAC0 less the weapon's bonus, and
-- e's armour class.
function M.hitChance(caster,e,w)
    local thac0=number(caster.thac0) and caster.thac0 or nil
    if thac0 and number(w.toHit) then thac0=thac0-w.toHit end
    return threat.hitChance(thac0,e.ac)
end

-- Item flags (ITM header): two-handed, cursed, magical, silver, cold iron.
local FLAG={twoHanded=0x2,cursed=0x10,magical=0x40,silver=0x100,coldIron=0x200}

-- Whether an immunity to weapons (opcode 120, by its type p2) keeps weapon w off. Type 0 keeps
-- off weapons up to +p1, as combat-intent/defence.lua reads it; a weapon is magical with the flag
-- or an enchantment (SR's Chill Touch hand is neither). Unknown types count as keeping it off.
local function immune(p,w)
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

-- Why the charge would not work on e, or nil: a hit takes a Mirror Image or a Stoneskin skin
-- instead, e is immune to the hand as a weapon (opcode 120), or a spell protection stops the
-- strike or a spell it casts (Spell Turning, Deflection, a globe: one is enough, so the charge is
-- not spent on a hit that does half its work). Unknown protections count as protecting.
function M.blocked(e,w)
    if number(e.mirror) and e.mirror>0 then return 'mirror' end
    if number(e.skins) and e.skins>0 then return 'stoneskin' end
    if type(e.protections)~='table' then return 'protected' end
    for _,p in ipairs(e.protections) do
        if type(p)=='table' and p.opcode==120 and immune(p,w) then return 'weapon-immunity' end
    end
    if targeting.protected(e,w.strike) then return 'protected' end
    for _,d in ipairs(type(w.strike.delivered)=='table' and w.strike.delivered or {}) do
        if targeting.protected(e,d) then return 'protected' end
    end
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
return M
