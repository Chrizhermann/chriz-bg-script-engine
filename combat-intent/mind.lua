-- How a creature thinks: the knobs that may differ between groups and single creatures
-- (Christopher, 2026-10-18: "Gruppen und einzelne Kreaturen müssen verschiedene Intelligenzen
-- haben"). The default profile, and each creature's wit around danger zones (M.wit); further
-- profiles for creatures or groups are designed with him fight by fight. Plain values; nothing
-- here touches the engine.
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
    -- Its own weapon counts for its own buffs (Kai, Whirlwind Attack, rages, potions): fighters and
    -- monsters swing (M.FAMILIES), casters cast.
    ownWeapon=false,
    -- It walks to any enemy it sees for a melee attack, as SCS's fighters and monsters do (their
    -- MoveToObject blocks), the walk lowering what the attack is worth (combat-intent/weapons.lua):
    -- fighters and monsters (M.FAMILIES). A caster goes no further than touchReach.
    chase=false,
    -- Summons (D3c): no more summoning once this many summoned allies are in view (the game's own
    -- limit for summoned creatures is five).
    summonCap=5,
    -- Seconds the rest of a fight counts for at most (combat-intent/threat.lua, M.rest): a summons
    -- fights over the rest of the fight, as both sides' strength makes it.
    fightCap=60,
    -- The caster's own clouds and storms (combat-intent/choice.lua): 'learned' counts the
    -- explosions each enemy is expected to sit through, by the cheaper of staying and walking out
    -- and by what the group has seen it do in clouds; 'best' only by the cheaper choice; 'once'
    -- counts one explosion.
    clouds='learned',
    -- Wit around danger zones (M.wit): 'clever', 'normal' or 'dull'; and how seriously the creature
    -- takes harm from them (1 for a WIS of 10).
    wit='clever',
    danger=1,
}

local function share(v) return type(v)=='number' and v==v and v>=0 and v<=1 end
local function amount(v) return type(v)=='number' and v==v and v>=0 and v<=1000 end
local function positive(v) return amount(v) and v>0 end
local function resrefs(v)
    if type(v)~='table' then return false end
    for k,x in pairs(v) do
        if type(k)~='string' or not k:match('^[%w#_%-]+$') or #k>8 or x~=true then return false end
    end
    return true
end
local CHECKS={coordination=share,best=share,band=share,economy=amount,minValue=amount,
    focusBonus=amount,killBonus=amount,caution=amount,horizon=amount,redefend=amount,acute=share,
    castCost=amount,allySpells=resrefs,slowSpeed=amount,touchReach=amount,summonCap=amount,fightCap=amount,
    openers=function(v) return type(v)=='boolean' end,
    touch=function(v) return type(v)=='boolean' end,
    weapons=function(v) return type(v)=='boolean' end,
    ownWeapon=function(v) return type(v)=='boolean' end,
    chase=function(v) return type(v)=='boolean' end,
    memory=function(v) return type(v)=='boolean' end,
    knowledge=function(v) return v=='scs' end,
    clouds=function(v) return v=='learned' or v=='best' or v=='once' end,
    wit=function(v) return v=='clever' or v=='normal' or v=='dull' end,
    danger=positive}

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

-- What a family's script changes in the profile: fighters and monsters fight with their weapons
-- and walk to the enemies they attack.
M.FAMILIES={fighter={ownWeapon=true,chase=true},monster={ownWeapon=true,chase=true}}
-- The profile base as a creature of the family ('mage', 'priest', 'fighter' or 'monster') thinks.
function M.forFamily(base,family)
    local changes=M.FAMILIES[family]
    if not changes then return base end
    local m=copy(base)
    for k,v in pairs(changes) do m[k]=v end
    return m
end

-- Wit (docs/research/MIND-01-wit-and-difficulty.md; Christopher, 2026-10-23 and 2026-10-24):
-- how clever a creature fights around danger zones, from an override for it, its kind, the INT
-- and WIS its file means and the game's difficulty, in this order. A dull creature sees no zone
-- until it hurts and works nothing out ahead; a normal one sees the zone it stands in and leaves
-- once staying costs more than it gains; a clever one also times the explosions and learns how
-- enemies behave in its own clouds (combat-intent/zones.lua, choice.lua). WIS sets how seriously
-- it takes harm from zones.
M.STEPS={dull=true,normal=true,clever=true}
-- The INT a step stands for when the creature's file says nothing (a kind or an override's step):
-- animal intelligence, average, exceptional.
M.STEP_INT={dull=1,normal=10,clever=15}
-- Steps by INT: dull up to DULL_INT, clever from CLEVER_INT, normal between.
M.DULL_INT=5
M.CLEVER_INT=14
-- INT and WIS pairs creature files carry as templates (MIND-01's census): they say nothing.
M.TEMPLATES={[9]={[9]=true},[16]={[9]=true}}
-- Difficulty (1 to 5, Normal 3): this many points of INT and WIS for each step above Normal, as
-- many fewer below.
M.DIFFICULTY_STEP=2
M.NORMAL_DIFFICULTY=3
-- Danger weight: 1 at a WIS of 10, this much more or less for each point, within its bounds.
M.DANGER_PER_WIS=0.05
M.DANGER_MIN=0.5
M.DANGER_MAX=1.5
-- The kinds (Christopher, 2026-10-24: a few categories after SCS first, split finer later). Casters
-- (mage and priest scripts) are clever. Dull, after SCS's test for unintelligent creatures
-- (sfo/filetype/lib_cre.tpa, CRE_check_if_moron; credit DavidW) but only the really dull ("nur für
-- wirklich sehr dumme Kreaturen"): animals and animated weapons (GENERAL.IDS 2, 101); zombies,
-- gibberlings, golems, slimes, carrion crawlers, ankhegs and basilisks (RACE.IDS 148, 109, 144,
-- 119, 104, 101, 102); skeletons and golems (CLASS.IDS 134, 182 to 185, 215). Everyone else is
-- normal: SCS counts most monsters unintelligent, but trolls, umber hulks, yuan-ti and the like
-- are no animals.
M.CASTERS={mage=true,priest=true}
M.DULL_GENERAL={[2]=true,[101]=true}
M.DULL_RACE={[148]=true,[109]=true,[144]=true,[119]=true,[104]=true,[101]=true,[102]=true}
M.DULL_CLASS={[134]=true,[182]=true,[183]=true,[184]=true,[185]=true,[215]=true}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- The step of c's kind (c.family, c.general, c.race, c.class).
function M.kind(c)
    if M.CASTERS[c.family] then return 'clever' end
    if M.DULL_GENERAL[c.general] or M.DULL_RACE[c.race] or M.DULL_CLASS[c.class] then return 'dull' end
    return 'normal'
end
-- Whether a file's INT and WIS mean something: an INT above 0 that is not part of a template pair.
function M.meant(int,wis)
    if not number(int) or int<=0 then return false end
    return not (M.TEMPLATES[int] and M.TEMPLATES[int][wis])
end
-- The step an INT makes.
function M.step(int)
    if int<=M.DULL_INT then return 'dull' end
    if int>=M.CLEVER_INT then return 'clever' end
    return 'normal'
end
-- A creature's wit from plain values: c.int and c.wis (its stats), c.general, c.race and c.class
-- (IDS values), c.family ('mage', 'priest', 'fighter' or 'monster'), c.difficulty (1 to 5) and
-- c.resref. overrides (optional) holds, by resref, a step and a WIS that stand for the creature's
-- own; the difficulty shifts them as well. Returns {step, danger, int, wis, from}: from tells
-- whether an override, the file's values or the kind set the step.
function M.wit(c,overrides)
    c=type(c)=='table' and c or {}
    local o=type(overrides)=='table' and type(c.resref)=='string' and overrides[c.resref:upper()] or nil
    if type(o)~='table' then o=nil end
    local meant=M.meant(c.int,c.wis)
    local int,wis,from
    if o and M.STEPS[o.step] then int,from=M.STEP_INT[o.step],'override'
    elseif meant then int,from=c.int,'stats'
    else int,from=M.STEP_INT[M.kind(c)],'kind' end
    if o and number(o.wis) then wis=o.wis elseif meant and number(c.wis) then wis=c.wis else wis=10 end
    local shift=0
    if number(c.difficulty) then shift=M.DIFFICULTY_STEP*(clamp(c.difficulty,1,5)-M.NORMAL_DIFFICULTY) end
    int,wis=int+shift,wis+shift
    return {step=M.step(int),danger=clamp(1+(wis-10)*M.DANGER_PER_WIS,M.DANGER_MIN,M.DANGER_MAX),int=int,wis=wis,
        from=from}
end
-- The profile base with wit w: its step and danger weight, and its own clouds weighed as its step
-- works them out: a clever creature as base says, a normal one by the cheaper of staying and
-- walking out at most, a dull one by one explosion.
function M.withWit(base,w)
    local m=copy(base)
    m.wit,m.danger=w.step,w.danger
    if w.step=='dull' then m.clouds='once' elseif w.step=='normal' and m.clouds=='learned' then m.clouds='best' end
    return m
end
return M
