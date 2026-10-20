-- How a creature thinks: the knobs that may differ between groups and single creatures
-- (Christopher, 2026-10-18: "Gruppen und einzelne Kreaturen müssen verschiedene Intelligenzen
-- haben"). Only the default profile exists so far; which creature or group gets which profile
-- is designed later with him. Plain values; nothing here touches the engine.
local M={}
M.default={
    -- 0 to 1: how much the group's plan counts (its focus target, one disabler per target).
    coordination=1,
    -- Chance to take the best option outright; otherwise a random near-best one. A strategic
    -- mind such as Irenicus would sit close to 1, never at it.
    best=0.6,
    -- Near-best: within this share below the best score.
    band=0.2,
    -- Weight of a spell's level against what it does: small spells for small jobs, strong
    -- spells kept for strong enemies.
    economy=1,
    -- Leaves a target out for a spell that had no effect on it before.
    memory=true,
    -- What it knows about enemies. 'scs': what SCS's scripts read (magic resistance,
    -- resistances, saves, level, spell protections). Knowledge a creature could not have
    -- goes in a later step.
    knowledge='scs',
    -- An attack must be worth at least this much (about a share of one enemy taken out of
    -- the fight), or SCS keeps the round.
    minValue=0.2,
    -- Extra weight of damage on the group's focus, times coordination.
    focusBonus=0.5,
    -- Worth of killing an enemy beyond the hit points taken.
    killBonus=0.5,
    -- Defences (step 3, third slice; Christopher, 2026-10-19: weigh them against attacks every
    -- round). Weight of what protections and buffs save against what attacks take.
    caution=1,
    -- Seconds of a fight a protection or buff counts for at most.
    horizon=18,
    -- Seconds after a defence before the next one, like SCS's redefend timer (7 or 8), so the
    -- caster attacks in between, unless it is in acute danger: it would lose this share of its
    -- hit points left in a round, with what protects it now.
    redefend=7,
    acute=0.5,
    -- Cost of each second of casting time.
    castCost=0.02,
    -- Single-target defences cast on allies too, by resref (exceptions agreed with Christopher;
    -- none yet). Others are cast on the caster itself or as areas around it.
    allySpells={},
    -- Openers (D2a): Time Stop and Improved Alacrity when SCS would cast them, before the
    -- ranking. Under Improved Alacrity a spell of this casting time or more waits while a quicker
    -- one reaches minValue (SCS's slow spells).
    openers=true,
    slowSpeed=6,
    -- Touch charges (D2c): touch spells cast and struck by the engine, at enemies within
    -- touchReach range units (SCS: 10).
    touch=true,
    touchReach=10,
    -- Weapon attacks (D2c): the weapon in hand as an attack, and spells that conjure one.
    weapons=true,
    -- Summons (D3c): no more summoning once this many summoned allies are in view (the game's own
    -- limit for summoned creatures is five).
    summonCap=5,
    -- Instead of no cast, a weapon attack waits while the caster has a spell ready that the
    -- engine does not cast yet (removal, raising) and that fits now (combat-intent/choice.lua,
    -- M.fits); SCS keeps the round.
    keepScsSpells=true,
}

local function share(v) return type(v)=='number' and v==v and v>=0 and v<=1 end
local function amount(v) return type(v)=='number' and v==v and v>=0 and v<=1000 end
local function resrefs(v)
    if type(v)~='table' then return false end
    for k,x in pairs(v) do
        if type(k)~='string' or not k:match('^[%w#_%-]+$') or #k>8 or x~=true then return false end
    end
    return true
end
local CHECKS={coordination=share,best=share,band=share,economy=amount,minValue=amount,
    focusBonus=amount,killBonus=amount,caution=amount,horizon=amount,redefend=amount,acute=share,
    castCost=amount,allySpells=resrefs,slowSpeed=amount,touchReach=amount,summonCap=amount,
    openers=function(v) return type(v)=='boolean' end,
    touch=function(v) return type(v)=='boolean' end,
    weapons=function(v) return type(v)=='boolean' end,
    keepScsSpells=function(v) return type(v)=='boolean' end,
    memory=function(v) return type(v)=='boolean' end,
    knowledge=function(v) return v=='scs' end}

local function copy(t)
    local c={}
    for k,v in pairs(t) do c[k]=type(v)=='table' and copy(v) or v end
    return c
end

-- The default profile with the given changes, or nil and the first bad field.
function M.new(changes)
    local mind=copy(M.default)
    if changes==nil then return mind end
    if type(changes)~='table' then return nil,'changes' end
    for k,v in pairs(changes) do
        local check=CHECKS[k]
        if not check or not check(v) then return nil,tostring(k) end
        mind[k]=v
    end
    return mind
end
return M
