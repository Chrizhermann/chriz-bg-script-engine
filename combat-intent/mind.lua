-- How a creature thinks: the knobs that may differ between groups and single creatures
-- (Christopher, 2026-10-18: "Gruppen und einzelne Kreaturen müssen verschiedene Intelligenzen
-- haben"). The default profile, and each creature's wit around danger zones (M.wit); further
-- profiles for creatures or groups are designed with him fight by fight. Plain values; nothing
-- here touches the engine.
local M={}
M.default={
    -- 0 to 1: how much the group's plan counts (its focus target, one disabler per target).
    coordination=1,
    -- Chance to take the best option outright; otherwise a random near-best one. Its wit scales
    -- how often it strays (M.STRAY). A strategic mind such as Irenicus would sit close to 1, never
    -- at it.
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
    -- A spell must be worth at least this much (about a share of one enemy taken out of the
    -- fight) to be taken over a weapon attack; below it, only when no attack is worth anything.
    minValue=0.2,
    -- Extra weight of damage on the group's focus, times coordination.
    focusBonus=0.5,
    -- Worth of killing an enemy beyond the hit points taken.
    killBonus=0.5,
    -- Worth of breaking an enemy's spell, for each of its spell levels, when an attack's damage lands
    -- while the enemy casts (combat-intent/choice.lua, interrupting).
    interrupt=0.1,
    -- How often the creature sees the chance a tactic needs some wit for (interrupting a cast, for
    -- now): 1 in every decision, 0 never. Its wit scales it (M.TACTICS).
    tactics=1,
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
    -- It goes for its enemies as SCS's fighters and monsters do (their MoveToObject blocks): a touch
    -- strike at any enemy it sees, and a teleport it has into melee (combat-intent/choice.lua):
    -- fighters and monsters (M.FAMILIES). A caster strikes no further than touchReach. Every
    -- creature that can walk goes to the enemy its weapon attacks, the walk lowering the worth
    -- (combat-intent/weapons.lua).
    chase=false,
    -- It attacks whenever nothing else is worth more, whatever standing next to the enemy costs;
    -- that cost only chooses between targets (Christopher, 2026-10-25): fighters and monsters
    -- (M.FAMILIES). Casters weigh it.
    alwaysAttack=false,
    -- Body weapons (a bite and a spit, a sting, a gaze: weapons the creature cannot lay down,
    -- combat-intent/arsenal.lua): how much of the times it does not take its best option it draws
    -- among all of them by their worth (combat-intent/choice.lua, M.varied), and whether it steps back
    -- from melee to use one that shoots, whatever its wit. 0 and false: always the best one, and a
    -- step back only as a tactic. Christopher, 2026-11-10: a creature the engine takes over keeps what
    -- it was known for.
    bodyMix=1,
    bodyRetreat=true,
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
    -- How long the creature searches for enemies it cannot see, as a share of its wit's patience
    -- (combat-intent/search.lua): labs and fight designs can stretch or shorten it.
    searchPatience=1,
    -- Hiding (F2f, combat-intent/stealth.lua): a thief that sees no enemy hides in shadows with the
    -- game's own skill and roll, by its wit; labs can switch it off.
    hide=true,
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
    focusBonus=amount,killBonus=amount,interrupt=amount,tactics=share,caution=amount,horizon=amount,redefend=amount,acute=share,
    castCost=amount,allySpells=resrefs,slowSpeed=amount,touchReach=amount,summonCap=amount,fightCap=amount,
    searchPatience=amount,bodyMix=share,
    bodyRetreat=function(v) return type(v)=='boolean' end,
    openers=function(v) return type(v)=='boolean' end,
    touch=function(v) return type(v)=='boolean' end,
    weapons=function(v) return type(v)=='boolean' end,
    ownWeapon=function(v) return type(v)=='boolean' end,
    chase=function(v) return type(v)=='boolean' end,
    alwaysAttack=function(v) return type(v)=='boolean' end,
    hide=function(v) return type(v)=='boolean' end,
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

-- What a family's script changes in the profile: fighters and monsters fight with their weapons,
-- walk to the enemies they attack and always attack when nothing else is worth more.
M.FAMILIES={fighter={ownWeapon=true,chase=true,alwaysAttack=true},
    monster={ownWeapon=true,chase=true,alwaysAttack=true}}
-- The profile base as a creature of the family ('mage', 'priest', 'fighter' or 'monster') thinks.
function M.forFamily(base,family)
    local changes=M.FAMILIES[family]
    if not changes then return base end
    local m=copy(base)
    for k,v in pairs(changes) do m[k]=v end
    return m
end

-- Wit (docs/research/MIND-01-wit-and-difficulty.md; Christopher, 2026-10-23 to 2026-10-25):
-- how clever a creature fights around danger zones, from an override for it, its kind, the INT
-- and WIS its file means and the game's difficulty, in this order. A dull creature sees no zone
-- until it hurts and works nothing out ahead; a normal one sees the zone it stands in and leaves
-- once staying costs more than it gains; a clever one also times the explosions and learns how
-- enemies behave in its own clouds (combat-intent/zones.lua, choice.lua). WIS sets how seriously
-- it takes harm from zones.
M.STEPS={dull=true,normal=true,clever=true}
M.RANK={dull=1,normal=2,clever=3}
-- The INT an override's step stands for: animal intelligence, average, exceptional.
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
-- The kinds: race groups (Christopher, 2026-10-24: a few categories first, split finer later;
-- 2026-10-25: "Wir können gerne Rassengruppen erstmal machen"), after the intelligence classes of
-- the old AD&D monster books, coarsened to four. Each stands for an INT where the creature's file
-- means nothing; the dull and low groups also for the highest step the difficulty lifts a creature
-- to, so that animals stay dull and ogres and trolls never turn clever on Insane ("Sowas darf nicht
-- klug sein"). A step the creature's own INT or an override gives stays.
M.GROUPS={
    -- Animals and the mindless: dull on every setting.
    dull={int=1,top='dull'},
    -- Brutes: normal, dull below Normal, never clever by the difficulty.
    low={int=7,top='normal'},
    -- The peoples and everyone not listed: normal, clever on Insane.
    average={int=10},
    -- Clever, normal below Normal.
    high={int=15},
}
-- Casters (mage and priest scripts) think as the high group, whatever their race.
M.CASTERS={mage=true,priest=true}
M.CASTER_GROUP='high'
-- Groups by IDS name, as the installed game's CLASS.IDS, RACE.IDS and GENERAL.IDS name a creature's
-- values, so that a race a mod adds counts by its name; the class before the race, the race before
-- the general. Dull after SCS's test for unintelligent creatures (sfo/filetype/lib_cre.tpa,
-- CRE_check_if_moron; credit DavidW), but only the really dull ("nur für wirklich sehr dumme
-- Kreaturen"): animals and animated weapons, the mindless dead and constructs, slimes and a few
-- beasts. Skeleton warriors are no mindless skeletons.
M.BY_CLASS={SKELETON='dull',GOLEM_IRON='dull',GOLEM_FLESH='dull',GOLEM_STONE='dull',GOLEM_CLAY='dull',
    GOLEM_ICE='dull',SKELETON_WARRIOR='average'}
M.BY_RACE={
    ANKHEG='dull',BASILISK='dull',BEAR='dull',BEETLE='dull',BIRD='dull',CARRIONCRAWLER='dull',CAT='dull',
    CHIMERA='dull',DOG='dull',GIBBERLING='dull',GOLEM='dull',KEG='dull',MAMMAL='dull',MIMIC='dull',RABBIT='dull',
    REPTILE='dull',SHRIEKER='dull',SKELETON='dull',SLIME='dull',WOLF='dull',ZOMBIE='dull',
    BUGBEAR='low',ELEMENTAL='low',ETTERCAP='low',ETTIN='low',GHOUL='low',GIANT='low',GNOLL='low',HARPY='low',
    HOOK_HORROR='low',LIZARDMAN='low',MINOTAUR='low',OGRE='low',OTYUGH='low',SHAMBLING_MOUND='low',
    SPIDER='low',TROLL='low',UMBERHULK='low',WYVERN='low',YETI='low',
    ANTISOLAR='high',BEHOLDER='high',DARKPLANATAR='high',DEMILICH='high',DEMONIC='high',DRAGON='high',
    GENIE='high',GITHYANKI='high',HALF_DRAGON='high',LICH='high',MIND_FLAYER='high',PLANATAR='high',
    RAKSHASA='high',SALAMANDER='high',SOLAR='high',SUCCUBUS='high',VAMPIRE='high',VAMPYRE='high',
    ['WILL-O-WISP']='high',YUANTI='high',
}
M.BY_GENERAL={ANIMAL='dull',WEAPON='dull'}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- The group of c's kind: c.family ('mage', 'priest', 'fighter' or 'monster') and the IDS names
-- c.class, c.race and c.general.
function M.group(c)
    if M.CASTERS[c.family] then return M.CASTER_GROUP end
    return M.BY_CLASS[c.class] or M.BY_RACE[c.race] or M.BY_GENERAL[c.general] or 'average'
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
-- (IDS names), c.family ('mage', 'priest', 'fighter' or 'monster'), c.difficulty (1 to 5) and
-- c.resref. overrides (optional) holds, by resref, a step and a WIS that stand for the creature's
-- own; the difficulty shifts them as well. Returns {step, danger, int, wis, from, group}: from
-- tells whether an override, the file's values or the kind set the INT, group the kind's group.
function M.wit(c,overrides)
    c=type(c)=='table' and c or {}
    local o=type(overrides)=='table' and type(c.resref)=='string' and overrides[c.resref:upper()] or nil
    if type(o)~='table' then o=nil end
    local meant=M.meant(c.int,c.wis)
    local group=M.group(c)
    local top=M.GROUPS[group].top
    local int,wis,from
    if o and M.STEPS[o.step] then int,from=M.STEP_INT[o.step],'override'
    elseif meant then int,from=c.int,'stats'
    else int,from=M.GROUPS[group].int,'kind' end
    if o and number(o.wis) then wis=o.wis elseif meant and number(c.wis) then wis=c.wis else wis=10 end
    local shift=0
    if number(c.difficulty) then shift=M.DIFFICULTY_STEP*(clamp(c.difficulty,1,5)-M.NORMAL_DIFFICULTY) end
    -- The difficulty lifts the step no higher than the group's top, unless the creature's own INT
    -- stands above it already.
    local own,step=M.step(int),M.step(int+shift)
    if top and M.RANK[step]>M.RANK[top] then step=M.RANK[own]>M.RANK[top] and own or top end
    int,wis=int+shift,wis+shift
    return {step=step,danger=clamp(1+(wis-10)*M.DANGER_PER_WIS,M.DANGER_MIN,M.DANGER_MAX),int=int,wis=wis,
        from=from,group=group}
end
-- How often each step sees the chance for a tactic that needs some wit (Christopher, 2026-10-25:
-- not every creature does the clever thing, "um ein bisschen Varianz ins Spiel zu bringen"): a
-- clever creature always, a normal one in half its decisions, a dull one never.
M.TACTICS={clever=1,normal=0.5,dull=0}
-- How often each step strays from the best option to a near-best one, as a share of how often the
-- profile does (Christopher, 2026-10-29: our creatures play imperfectly on purpose, and clever
-- groups end up more dangerous than SCS's): a clever creature half as often, a normal one as often,
-- a dull one half as often again. The default profile's 0.6 makes 0.8, 0.6 and 0.4; a profile that
-- always takes the best keeps doing so.
M.STRAY={clever=0.5,normal=1,dull=1.5}
-- The profile base with wit w: its step and danger weight, how often it sees a tactic's chance
-- (base's tactics times its step's), how often it takes the best option (M.STRAY), and its own
-- clouds weighed as its step works them out: a clever creature as base says, a normal one by the
-- cheaper of staying and walking out at most, a dull one by one explosion.
function M.withWit(base,w)
    local m=copy(base)
    m.wit,m.danger=w.step,w.danger
    m.tactics=(type(base.tactics)=='number' and base.tactics or 1)*(M.TACTICS[w.step] or 1)
    local best=share(base.best) and base.best or M.default.best
    m.best=clamp(1-(1-best)*(M.STRAY[w.step] or 1),0,1)
    if w.step=='dull' then m.clouds='once' elseif w.step=='normal' and m.clouds=='learned' then m.clouds='best' end
    return m
end
return M
