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
local threat=require('combat-intent.threat')
local weapons=require('combat-intent.weapons')
local targeting=require('combat-intent.targeting')
local M={}
-- Rounds the caster stands in reach of its target's friends: the strike, and another after a
-- miss now and then.
M.exposedRounds=1.5

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

-- The touch charge a classified spell gives, or nil: its first weapon of one melee hit.
function M.charge(spell)
    if type(spell)~='table' or type(spell.weapons)~='table' then return nil end
    for _,w in ipairs(spell.weapons) do
        if type(w)=='table' and w.touch==true and type(w.strike)=='table' then return w end
    end
end

-- How far, in world units, the caster goes for a strike: the profile's touchReach in range
-- units (SCS: within 10), as for any melee hit (combat-intent/weapons.lua).
M.reach=weapons.reach

-- Whether the caster can go for e: alive, no sanctuary, seen, within reach. Else false and why.
function M.reachable(caster,e,mind) return weapons.reachable(caster,e,mind,nil) end

-- The chance a swing of w hits e: a d20 against the caster's THAC0 less the weapon's bonus, and
-- e's armour class.
function M.hitChance(caster,e,w)
    local thac0=number(caster.thac0) and caster.thac0 or nil
    if thac0 and number(w.toHit) then thac0=thac0-w.toHit end
    return threat.hitChance(thac0,e.ac)
end

-- Why the charge would not work on e, or nil: a hit takes a Mirror Image or a Stoneskin skin
-- instead, e is immune to the hand as a weapon (opcode 120), or a spell protection stops the
-- strike or a spell it casts (Spell Turning, Deflection, a globe: one is enough, so the charge is
-- not spent on a hit that does half its work; targeting.protected). Unknown protections count as
-- protecting.
function M.blocked(e,w)
    if number(e.mirror) and e.mirror>0 then return 'mirror' end
    if number(e.skins) and e.skins>0 then return 'stoneskin' end
    if type(e.protections)~='table' then return 'protected' end
    if weapons.immuneTo(e,w) then return 'weapon-immunity' end
    if targeting.protected(e,w.strike) then return 'protected' end
end

-- Hit points a round the caster would take more standing next to e than where it stands
-- (combat-intent/weapons.lua).
M.exposure=weapons.exposure
return M
