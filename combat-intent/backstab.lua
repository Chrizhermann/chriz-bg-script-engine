-- Backstabs (F2d; Christopher, 2026-10-26: thieves next, SCS as the blueprint): what the first hit
-- of an invisible creature from behind its target is worth. SCS's thieves drink invisibility or read
-- its scroll when they see an enemy, then stab the weakest close enemy that has no Mirror Images and
-- no Stoneskin, going a little way for a good one while no enemy sees through invisibility ([src]
-- genai/ssl/backstab.ssl, dw#wtacor.ssl; BackstabSafe in ssl/library.slb; credit DavidW).
--
-- The game's rule, as GemRB reads BG2 ([src] core/Scriptable/Actor.cpp, GetBackstabDamage and
-- IsBehind; core/Inventory.cpp): the attacker is invisible, the weapon can backstab (a melee weapon
-- thieves may use, combat-intent/arsenal.lua), the target is not immune (IMMUNITY_TO_BACKSTAB, a
-- barbarian), and the attacker stands behind the target: the target faces within behindArc of the
-- 16 directions of the way from the attacker to it (where the attacker faces does not matter). The
-- hit's damage is then multiplied by the attacker's BACKSTABDAMAGEMULTIPLIER; attacking ends plain
-- invisibility, so only the first hit can be one. What EE does of this is not measured yet (whether
-- it needs the attacker behind, how wide behind is, whether Improved Invisibility counts); a lab is
-- to, and these values follow it. Plain values only; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local M={}
-- Directions a creature faces (DIR.IDS: 0 south, 4 west, 8 north, 12 east, turning clockwise on
-- the screen), and how many on either side of the way to the target still count as behind it.
M.DIRECTIONS=16
M.behindArc=2
-- Whether the attacker must stand behind (BG2's rule; BG1's needs none).
M.needsBehind=true
-- STATE_INVISIBLE, which a backstab needs, and STATE_IMPROVEDINVISIBILITY, which alone does not
-- count (BG2's rule as players know it; not measured in EE yet).
M.INVISIBLE=targeting.STATE.invisible
M.IMPROVED=targeting.STATE.improvedInvisible
-- A spot behind a target lies this far from it, within a weapon's reach (threat.reach).
M.behindDistance=48

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local atan2=math.atan2 or math.atan

-- The direction (M.DIRECTIONS) of the way from a to b on the screen, or nil when either has no spot
-- or they share one.
function M.direction(a,b)
    if type(a)~='table' or type(b)~='table' or not number(a.x) or not number(a.y) or not number(b.x) or
        not number(b.y) then return nil end
    local dx,dy=b.x-a.x,b.y-a.y
    if dx==0 and dy==0 then return nil end
    return math.floor(atan2(-dx,dy)/(2*math.pi/M.DIRECTIONS)+0.5)%M.DIRECTIONS
end
-- Whether attacker stands behind target (see the top), or nil when the target's facing is unknown.
function M.behind(attacker,target)
    local f=type(target)=='table' and target.facing
    local d=M.direction(attacker,target)
    if not number(f) or d==nil then return nil end
    local diff=(f-d)%M.DIRECTIONS
    return math.min(diff,M.DIRECTIONS-diff)<=M.behindArc
end
-- The share of directions behind a creature: the chance to stand behind one whose facing is unknown.
function M.prior() return (2*M.behindArc+1)/M.DIRECTIONS end
-- The spot far (world units, M.behindDistance without) behind target, opposite the way it faces, or
-- nil when its facing is unknown. The screen's height counts 3/4 of a world unit, as distances do.
function M.spot(target,far)
    local f=type(target)=='table' and target.facing
    if not number(f) or not number(target.x) or not number(target.y) then return nil end
    far=number(far) and far or M.behindDistance
    local turn=f*2*math.pi/M.DIRECTIONS
    return {x=math.floor(target.x+math.sin(turn)*far+0.5),y=math.floor(target.y-math.cos(turn)*far*3/4+0.5)}
end

-- Whether the creature is invisible as a backstab needs it (M.INVISIBLE without M.IMPROVED).
function M.hidden(creature)
    local state=type(creature)=='table' and creature.state
    return targeting.has(state,M.INVISIBLE) and not targeting.has(state,M.IMPROVED)
end
-- Whether the caster could backstab with weapon arms at all: a backstab multiplier above 1 and a
-- weapon that can backstab.
function M.able(caster,arms)
    return type(caster)=='table' and number(caster.backstab) and caster.backstab>1 and type(arms)=='table' and
        arms.backstab==true and not arms.ranged
end
-- Whether e can be backstabbed: alive, not immune, and no Mirror Image or Stoneskin skin to take
-- the first hit (SCS's BackstabSafe).
function M.open(e)
    return type(e)=='table' and targeting.alive(e) and e.backstabImmune~=true and
        not (number(e.mirror) and e.mirror>0) and not (number(e.skins) and e.skins>0)
end
-- The backstab the caster's first hit with weapon arms on e would be: {chance, multiplier}, the
-- chance its first swing lands as one (the swing hits, and the caster stands behind e: by e's
-- facing, M.prior when unknown, certain when behind is true), or nil and why there is none. hidden:
-- count the caster as invisible (for a hide it has yet to take).
function M.chance(caster,arms,e,behind,hidden)
    if not M.able(caster,arms) then return nil,'unable' end
    if not hidden and not M.hidden(caster) then return nil,'seen' end
    if not M.open(e) then return nil,'closed' end
    local back=1
    if M.needsBehind and behind~=true then
        local b=M.behind(caster,e)
        if b==nil then back=M.prior() elseif b then back=1 else back=0 end
    end
    if back<=0 then return nil,'front' end
    return {chance=threat.hitChance(arms.thac0,e.ac)*back,multiplier=caster.backstab}
end
return M
