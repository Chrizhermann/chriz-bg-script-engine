-- What one creature perceives right now, as plain values: itself and the living creatures it
-- can see, found with EEex's area search (sight range and line of sight, as the NumCreature()
-- trigger counts them) and minus the invisible enemies unless it sees invisible creatures; its
-- own side knows where its invisible allies are (SCS's priests cure them, lab batch H). That
-- search walks only the area's front list; creatures lying down (asleep, unconscious) are in
-- the back list with the dead, and one counts as seen when the same search from where it lies
-- finds this creature; the dead allies seen that way are listed apart (frame.fallen). Sides
-- follow the engine's EA groups: for a creature on the evil side (EA 200 and up) the good side
-- (EA 2 to 30) are enemies and the evil side are allies. With details, each enemy also carries
-- its creature IDS values, saves, resistances, level and the spell protections a script can
-- test (SCS's triggers read the same); M.splprot adds the engine's own answers to the SPLPROT
-- checks of the spells in question. M.defend adds what the defence slice weighs: what protects
-- each friend now and the weapons of the creatures around. M.zones reads the danger zones in an
-- area (D3e): its area projectiles that explode again and again. M.foe and M.outOfPlay read a foe
-- out of play for its side's readiness. Only plain values leave this module; no engine object is
-- kept.
local targeting=require('combat-intent.targeting')
local spells=require('combat-intent.spells')
local arsenal=require('combat-intent.arsenal')
local M={}
-- A sprite's default visual range in EEex's area search.
M.sightRange=448
M.GOOD_CUTOFF,M.EVIL_CUTOFF=30,200
-- STATS.IDS: MAXHITPOINTS, RESISTMAGIC, HELD, SANCTUARY, SEEINVISIBLE, TRUE_SIGHT, LEVELDRAIN,
-- ENTANGLE, WEB, MINHITPOINTS (opcode 208 sets it, IESDP).
M.stats={maxHp=1,mr=18,held=58,sanctuary=63,seeInvisible=81,trueSight=118,levelDrain=200,entangle=62,web=67,
    minHp=83}
-- Opcode 208, minimum hit points.
M.minimumHp=208
-- Opcodes that take a creature out of the game for a while (IESDP): Maze (213) until the delayed
-- opcode 212 it applies itself ends it, where it vanished; Imprisonment (211) until a Freedom
-- (opcode 212) frees it. Either stays in the creature's effect list meanwhile, and the creature's
-- object and position remain while no area search finds it (lab batch J).
M.outOfGame={[213]='maze',[211]='prison'}
-- The spell mod imprisons Player1 through opcode 213 from CBMP1IM and petrifies Player1 through
-- CBMP1ST so neither state ends the game at once: CBMP1IM is a prison (never returns on its own),
-- and a creature held by CBMP1ST is a tough statue that enemies attack only at low priority.
M.prisonSource='CBMP1IM'
M.statueSource='CBMP1ST'
-- STATE_INVISIBLE and STATE_IMPROVEDINVISIBILITY; STATE_BLIND.
M.unseen,M.blind=0x400010,0x40000
-- What a backstab needs to know (F2d): STATS.IDS BACKSTABDAMAGEMULTIPLIER and
-- IMMUNITY_TO_BACKSTAB (opcode 292 sets it), and KIT.IDS BARBARIAN, a kit the engine makes immune
-- by itself (GemRB does the same, [src] core/Scriptable/Actor.cpp), read as EEex builds a kit from
-- its two halves (docs/learned.md).
M.backstab={multiplier=56,immune=175}
M.barbarian=0x40000000
-- Directions a creature can face (DIR.IDS: 0 south, 4 west, 8 north, 12 east).
M.directions=16
-- STATS.IDS: the saving throws, resistances and levels SCS's attack blocks read about their
-- targets; the engine's own choice reads the same (Christopher, 2026-10-18: as much as SCS).
M.saves={death=9,wand=10,poly=11,breath=12,spell=13}
M.resists={fire=14,cold=15,electricity=16,acid=17,magicfire=19,magiccold=20,slashing=21,crushing=22,
    piercing=23,missile=24,magic=73,poison=74}
M.levels={34,68,69}
-- Effect opcodes that protect against spells (combat-intent/targeting.lua matches them).
M.protections={}
for _,op in ipairs({83,101,102,120,197,198,199,200,201,202,203,204,205,206,207,223,226,227,228,259,318,324}) do
    M.protections[op]=true
end
-- Effects read per list at most, so a creature with a runaway effect list costs little.
M.maxEffects=1024
-- Searches from lying creatures per frame at most (each one is an area search), and from dead
-- allies.
M.maxLying=32
M.maxFallen=8
-- m_durationType of an effect with time left (the lab's effect timing, learned.md).
M.timedEffect=4096
-- STATS.IDS for the defence slice: ARMORCLASS, THAC0, NUMBEROFATTACKS, DAMAGEBONUS,
-- THAC0BONUSRIGHT, DAMAGEBONUSRIGHT, STONESKINS, HITBONUS; and for a weapon's parts (F2c,
-- combat-intent/arsenal.lua) the bonuses for melee or missiles alone: MELEE_THACO_BONUS,
-- MISSILETHAC0BONUS, MELEE_DAMAGE_BONUS, MISSILE_DAMAGE_BONUS (opcodes 284, 167, 285, 286). In the
-- lab the right-hand bonuses held the bonus to hit of strength (dexterity for a bow), the
-- proficiency and the weapon's own, and the proficiency's bonus to damage (probe F: a level-8
-- fighter with 18 strength and 16 dexterity had 3 and 2 specialised in a Short Sword +1, 6 and 4
-- as a high master of the long bow with a Composite Long Bow and Arrows +1; docs/learned.md).
M.combat={ac=2,thac0=7,apr=8,damageBonus=50,thac0Right=84,damageRight=86,stoneskins=88,hitBonus=151,
    meleeHit=166,missileHit=72,meleeDamage=167,missileDamage=168}
-- STATS.IDS: STR, STREXTRA, INT, DEX.
M.scores={str=36,strExtra=37,int=38,dex=40}
-- Opcodes that keep a foe out of play while its side awaits it (M.outOfPlay): Charm and Maze.
M.charm,M.maze=5,213
-- The quiver slots, whose ammunition a launcher shoots, the fist slot, the magic weapon slot and
-- the weapon slots (SLOTS.IDS).
M.quiver={11,12,13,14}
M.fistSlot=10
M.magicSlot=34
M.weaponSlots={35,36,37,38}
-- What SCS's archers look for before they shoot ([src] ssl/library.slb, ArrowSafe): SPLSTATE.IDS
-- PROTECTION_FROM_NORMAL_MISSILES and STATS.IDS CLERIC_PHYSICAL_MIRROR, the same in every install
-- read.
M.normalMissiles=109
M.physicalMirror=122
-- The game's tables a weapon's parts come from (combat-intent/arsenal.lua): the rows read of each.
M.maxStars=5
M.maxLevel=50
M.maxScore=25
M.maxExceptional=100
-- An effect that ends within this many seconds no longer protects.
M.expiring=6
-- What a creature's effects and weapon say is read once for all who look at it (M.memory, recall):
-- it stands for knownTicks, and no longer than the creature's effect lists keep their lengths and
-- its hand keeps its weapon. Lab prof-camp-1 (2026-11-10, 37 creatures around one enemy): every
-- decision read every creature in sight afresh, four walks through its effects each, and that was
-- more than half of the engine's time. A second is also what the engine allows itself for a
-- creature beyond its frame (adapters/eeex/choice.lua, knownTicks).
M.knownTicks=15
-- A creature none of whose effects runs out or waits to begin (settled: each is permanent or lasts while
-- its item is worn, M.lasting) has none that begins after a delay or is about to end: what its effects,
-- gear and weapon say stands for settledTicks, as long as its lists stay as they are. (A change to its
-- base values that leaves no effect behind is seen then at the latest.) Most creatures of a crowd are
-- such: the effects of their creature files and of other mods' markers are permanent ones in the list
-- of timed effects (lab prof-camp-5, 2026-11-10: with "no timed effect at all" as the rule the 43
-- creatures of the Bandit Camp were still read every second).
M.settledTicks=75
-- An effect's kinds of duration (m_durationType) that time does not change: permanent (1), while its
-- item is worn (2) and permanent past death (9).
M.lasting={[1]=true,[2]=true,[9]=true}
M.memoryLimit=1024
-- Opcodes that deliver other effects; what they delivered is in the list already.
M.delivered={[146]=true,[148]=true,[177]=true,[272]=true,[283]=true,[326]=true,[333]=true,[366]=true}
-- Casts that damage breaks (ACTION.IDS): Spell, SpellPoint, SpellNoDec and SpellPointNoDec (their
-- RES forms share the numbers). Forced casts cannot be broken.
M.breakable={[31]=true,[95]=true,[191]=true,[192]=true}
-- SPELL.IDS numbers name their resref by thousands: 1 priest, 2 wizard, 3 innate, 4 class.
M.prefixes={'SPPR','SPWI','SPIN','SPCL'}
-- Conditions a cure takes away, by the opcode that sets them (combat-intent/spells.lua's labels;
-- combat-intent/care.lua weighs them). Hold (II) (185) stands apart: opcode 162, the cure of
-- holds, does not remove it (IESDP). Temporary attribute drain (M.abilityDrain: CHA, CON, DEX,
-- INT, STR, WIS) is recognized on timed effects the same way the spell mod's CBMLRES cures it.
M.conditions={[39]='sleep',[3]='berserk',[24]='panic',[45]='stun',[210]='stun',[38]='silence',[74]='blind',
    [76]='feeblemind',[78]='disease',[80]='deaf',[109]='hold',[175]='hold',[185]='hold2',[128]='confusion',
    [165]='pause',[25]='poison'}
M.abilityDrain={[6]=true,[10]=true,[15]=true,[19]=true,[44]=true,[49]=true}

local function band(g,a,b) return g.EEex_BAnd(a,b) end
local function stat(g,sprite,n)
    local value=g.EEex_Sprite_GetStat(sprite,n)
    if type(value)=='number' then return value end
    return 0
end
local function text(value) return (value:match('^[^%z]*'):upper()) end
local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge and v or 0 end
local function name(field)
    if field==nil then return '' end
    local ok,v=pcall(function() return field:get() end)
    return ok and type(v)=='string' and text(v) or ''
end

-- Where a creature's minimum hit points come from: the spells and items whose opcode 208 with a
-- minimum above 0 is in its effect lists, by source, for what a spell must take away to end the
-- minimum (combat-intent/targeting.lua's floor). nil when one of them names no source.
function M.minimumSources(g,sprite)
    local from,named={},true
    for _,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(effect)
            seen=seen+1
            if seen>M.maxEffects then return true end
            if effect.m_effectId==M.minimumHp and number(effect.m_effectAmount)>0 then
                local source=name(effect.m_sourceRes)
                if source=='' then named=false else from[source]=true end
            end
        end)
    end
    if not named then return nil end
    return from
end

-- Whether a creature is out of the game for now (M.outOfGame): 'maze' or 'prison', else nil.
function M.removed(g,sprite)
    local found
    for _,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(effect)
            seen=seen+1
            if seen>M.maxEffects then return true end
            local kind=M.outOfGame[effect.m_effectId]
            if kind=='maze' and name(effect.m_sourceRes)==M.prisonSource then kind='prison' end
            if kind then found=kind;return true end
        end)
        if found then return found end
    end
    return nil
end

-- Whether any effect in a creature's timed or equipped lists came from resref.
function M.hasSource(g,sprite,resref)
    local target=type(resref)=='string' and resref:upper() or ''
    if target=='' then return false end
    local found=false
    for _,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(effect)
            seen=seen+1
            if seen>M.maxEffects then return true end
            if name(effect.m_sourceRes)==target then found=true;return true end
        end)
        if found then return true end
    end
    return false
end

-- A party member's place in the party (1 for Player1, the protagonist, up to 6, by joining, as the
-- game's Player1 to Player6 count; EEex_Sprite_GetCharacterIndex), nil for anyone else.
local function partyPlace(g,sprite)
    local place=rawget(g,'EEex_Sprite_GetCharacterIndex')
    if type(place)~='function' then return nil end
    local ok,n=pcall(place,sprite)
    if ok and type(n)=='number' and n>=0 and n<=5 then return n+1 end
    return nil
end

-- The direction a creature faces (M.directions), or nil when the engine gives none it could mean.
local function direction(sprite) return sprite.m_nDirection end
local function facing(sprite)
    local ok,v=pcall(direction,sprite)
    if ok and type(v)=='number' and v>=0 and v<M.directions and v%1==0 then return v end
    return nil
end
-- Whether a creature is a barbarian (M.barbarian), by its kit's two halves; false when unread.
local function barbarian(sprite)
    local ok,v=pcall(function()
        local base=sprite.m_baseStats
        local upper,lower=base.m_mageSpecUpperWord,base.m_mageSpecialization
        if type(upper)~='number' or type(lower)~='number' then return nil end
        return upper*65536+lower
    end)
    return ok and v==M.barbarian
end

-- The plain facts every frame carries for one creature: also its armour class, the creature
-- its current action is aimed at (-1 for none), its Stoneskin skins and Mirror Images, the
-- levels drained from it, whether it is webbed or entangled (rooted: it cannot walk), the hit
-- points it cannot drop below (minHp, 0 without a minimum) with where they come from (minHpFrom,
-- M.minimumSources), what its backstab multiplies a first hit by (backstab, 0 for none), whether
-- it cannot be backstabbed (backstabImmune) and the direction it faces (facing, nil unknown).
-- Of those, what only a creature's effects and gear change (standing) comes from the memory when one
-- is given with the tick (recall, further down): a frame of a crowd read these twelve stats of every
-- creature in sight, a third of the engine's time in lab prof-camp-3 (2026-11-10). Where it stands,
-- its hit points, state, action, skins and images are read every time; a check right before an action
-- passes no memory and reads everything.
-- A creature others look at (shared) is read once a tick: the fight director's check-in and the decision
-- of one creature look at the same crowd in the same tick, and so do all who decide in it (lab
-- prof-camp-4: reading the creatures in sight was a quarter of the engine's time). Each who looks gets
-- its own copy. The creature that looks reads itself every time: its own action changes between its
-- script's question and its response.
local recall
local function copied(t)
    local c={}
    for k,v in pairs(t) do c[k]=v end
    return c
end
local function standing(g,sprite)
    local minimum=stat(g,sprite,M.stats.minHp)
    local held=stat(g,sprite,M.stats.held)
    return {held=held,statue=held>0 and M.hasSource(g,sprite,M.statueSource) or nil,
        sanctuary=stat(g,sprite,M.stats.sanctuary),
        maxHp=stat(g,sprite,M.stats.maxHp),mr=stat(g,sprite,M.stats.mr),ac=stat(g,sprite,M.combat.ac),
        drained=stat(g,sprite,M.stats.levelDrain),
        rooted=stat(g,sprite,M.stats.entangle)>0 or stat(g,sprite,M.stats.web)>0,
        minHp=minimum>0 and minimum or 0,minHpFrom=minimum>0 and M.minimumSources(g,sprite) or nil,
        backstab=stat(g,sprite,M.backstab.multiplier),
        backstabImmune=stat(g,sprite,M.backstab.immune)>0 or barbarian(sprite)}
end
function M.actor(g,sprite,memory,tick,shared)
    local id=sprite.m_id
    shared=shared and type(memory)=='table' and type(tick)=='number'
    if shared then
        local seen=memory.actors[id]
        if seen and seen.tick==tick then
            memory.actorHits=memory.actorHits+1
            return copied(seen.actor)
        end
    end
    local state=g.EEex_Sprite_GetState(sprite)
    local action=sprite.m_curAction
    local target=action.m_acteeID
    local actee=target and target.m_Instance
    local mirror=sprite.m_nMirrorImages
    local at=sprite.m_pos
    local s=recall(memory,sprite,tick,'standing',function() return standing(g,sprite) end)
    local actor={id=id,x=at.x,y=at.y,ea=sprite.m_typeAI.m_EnemyAlly,
        state=state,held=s.held,statue=s.statue,sanctuary=s.sanctuary,
        hp=sprite.m_baseStats.m_hitPoints,maxHp=s.maxHp,
        mr=s.mr,action=action.m_actionID,ac=s.ac,
        actee=type(actee)=='number' and actee or -1,skins=stat(g,sprite,M.combat.stoneskins),
        mirror=type(mirror)=='number' and mirror or 0,drained=s.drained,
        rooted=s.rooted,
        minHp=s.minHp,minHpFrom=s.minHpFrom,
        backstab=s.backstab,
        backstabImmune=s.backstabImmune,facing=facing(sprite)}
    if not shared then return actor end
    if memory.actors[id]==nil then
        if memory.actorCount>=M.memoryLimit then memory.actors,memory.actorCount={},0 end
        memory.actorCount=memory.actorCount+1
    end
    memory.actors[id]={tick=tick,actor=actor}
    return copied(actor)
end
-- A creature's THAC0 with its right-hand and general hit bonuses (as M.attack counts it).
function M.thac0(g,sprite)
    return stat(g,sprite,M.combat.thac0)-stat(g,sprite,M.combat.thac0Right)-stat(g,sprite,M.combat.hitBonus)
end

-- A creature's IDS values and level (the highest of its classes'), for a friend: what healing,
-- curing and summoning weigh (combat-intent/care.lua). M.details reads the same for enemies.
-- With a memory and the tick its level comes from the memory (recall); its IDS values are read every time
-- (a script changes a creature's side without an effect).
function M.identity(g,sprite,entry,memory,tick)
    local t=sprite.m_typeAI
    entry.ids={ea=t.m_EnemyAlly,general=t.m_General,race=t.m_Race,class=t.m_Class,
        specific=t.m_Specifics,gender=t.m_Gender,alignment=t.m_Alignment}
    entry.level=recall(memory,sprite,tick,'level',function()
        local level=0
        for _,n in ipairs(M.levels) do level=math.max(level,stat(g,sprite,n)) end
        return level
    end)
    return entry
end

-- A memory for what creatures' effects and weapons say (recall), for one runtime: session-local, a
-- load starts a new one. hits and reads count what it spared and what it read; unsigned counts the
-- looks at a creature whose effect lists do not tell their length (then nothing is kept).
-- It also keeps what was found in an area's object lists (areaRecall): areas by area and part,
-- areaHits, areaReads and areaUnsigned count the same for them.
-- And each creature as others saw it in the current tick (M.actor): actors, with actorHits for the looks
-- it spared.
-- With the game's table (g) it can walk a creature's timed effects to see whether any runs out or waits
-- (settled); without, only a creature with no timed effect at all counts as settled.
function M.memory(g)
    return {entries={},count=0,hits=0,reads=0,unsigned=0,areas={},areaCount=0,areaHits=0,areaReads=0,areaUnsigned=0,
        actors={},actorCount=0,actorHits=0,game=type(g)=='table' and g or nil}
end
-- Whether none of a creature's timed effects (count of them: t) runs out or waits to begin (M.lasting). A
-- list that cannot be walked counts as one that has such an effect.
local function settled(memory,timed,t)
    if t==0 then return true end
    local iterate=memory.game and memory.game.EEex_Utility_IterateCPtrList
    if type(iterate)~='function' then return false end
    local all,seen=true,0
    local ok=pcall(iterate,timed,function(e)
        seen=seen+1
        if seen>M.maxEffects or not M.lasting[e.m_durationType] then all=false;return true end
    end)
    return ok and all
end
-- One part ('standing', 'details', 'level', 'protections', 'guard' or 'attack') of what a creature's effects and
-- weapon say, read
-- with read() or taken from memory: the same answer while its two effect lists keep their lengths
-- (a spell that lands, ends or is dispelled changes one), its hand keeps its weapon and ability, and
-- knownTicks have not passed since the first part was read (settledTicks for a creature none of whose
-- effects runs out or waits: settled). What comes back is shared between the
-- frames of all who look: the policy modules read it and never change it. Without a memory, or for
-- a creature whose lists do not tell their length, it is read every time. An error in read() goes
-- to the caller, and nothing is kept.
-- Whether the lists and the hand are as they were is looked up once a tick for each creature (checked):
-- the looks of one tick at a creature, for all its parts, share that answer.
function recall(memory,sprite,tick,part,read)
    if type(memory)~='table' then return read() end
    if type(tick)~='number' then
        memory.unsigned=memory.unsigned+1
        return read()
    end
    local id=sprite.m_id
    local k=memory.entries[id]
    if not k or k.checked~=tick then
        local timed,equipped=sprite.m_timedEffectList,sprite.m_equipedEffectList
        local t,e=timed and timed.m_nCount,equipped and equipped.m_nCount
        if type(t)~='number' or type(e)~='number' then
            memory.unsigned=memory.unsigned+1
            return read()
        end
        local equipment=sprite.m_equipment
        local w,a=equipment and equipment.m_selectedWeapon,equipment and equipment.m_selectedWeaponAbility
        local stands=k and k.settled and M.settledTicks or M.knownTicks
        if not k or k.t~=t or k.e~=e or k.w~=w or k.a~=a or tick<k.tick or tick-k.tick>=stands then
            if not k then
                if memory.count>=M.memoryLimit then memory.entries,memory.count={},0 end
                memory.count=memory.count+1
            end
            k={tick=tick,t=t,e=e,w=w,a=a,parts={},settled=settled(memory,timed,t)}
            memory.entries[id]=k
        end
        k.checked=tick
    end
    local kept=k.parts[part]
    if kept then
        memory.hits=memory.hits+1
        return kept[1]
    end
    local value=read()
    memory.reads=memory.reads+1
    k.parts[part]={value}
    return value
end
-- What a walk through some of an area's object lists (names) finds, for one part (the zones of a list,
-- 'lying'):
-- found with scan() or taken from memory while each of those lists keeps its length (an object that
-- comes or goes changes one) and knownTicks have not passed. In a crowd's area every decision walked
-- every object of the area for its lasting spells and every frame its back list for the creatures lying
-- there (lab prof-camp-3, 2026-11-10: a seventh of the engine's time with no cloud and no one lying).
-- What is kept are object ids, looked up again at each use. Without a memory or the tick, or for a list
-- that does not tell its length, the lists are walked every time; an error in scan() goes to the caller.
local function areaRecall(memory,area,tick,part,names,scan)
    if type(memory)~='table' or type(tick)~='number' then return scan() end
    local counts={}
    for i,listName in ipairs(names) do
        local list=area[listName]
        local n=-1
        if list~=nil then n=list.m_nCount end
        if type(n)~='number' then
            memory.areaUnsigned=memory.areaUnsigned+1
            return scan()
        end
        counts[i]=n
    end
    local key=text(area.m_resref:get())..'/'..part
    local k=memory.areas[key]
    local same=k~=nil and tick>=k.tick and tick-k.tick<M.knownTicks
    if same then
        for i=1,#counts do if k.counts[i]~=counts[i] then same=false;break end end
    end
    if same then
        memory.areaHits=memory.areaHits+1
        return k.value
    end
    local value=scan()
    memory.areaReads=memory.areaReads+1
    if not k then
        if memory.areaCount>=M.memoryLimit then memory.areas,memory.areaCount={},0 end
        memory.areaCount=memory.areaCount+1
    end
    memory.areas[key]={tick=tick,counts=counts,value=value}
    return value
end

-- The spell protections in a creature's two effect lists, as {opcode, p1, p2, res, timed} rows
-- (combat-intent/targeting.lua matches them). A protection with time left (from a spell or a
-- potion, not an item or the creature itself) is marked timed.
function M.protectionRows(g,sprite)
    local found={}
    for n,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(effect)
            seen=seen+1
            if seen>M.maxEffects then return true end
            if M.protections[effect.m_effectId] then
                found[#found+1]={opcode=effect.m_effectId,p1=effect.m_effectAmount,p2=effect.m_dWFlags,
                    res=text(effect.m_res:get()),timed=n==1 and effect.m_durationType==M.timedEffect}
            end
        end)
    end
    return found
end

-- Creature IDS values, saving throws, resistances, level and the spell protections in both
-- effect lists (M.protectionRows); whether it is protected from normal missiles or carries a
-- Physical Mirror (normalMissiles, reflects: what SCS's archers look for); its creature file
-- (resref) and, for a party member, its place in the party (player: 1 for Player1, the
-- protagonist, up to 6, by joining, as the game's Player1 to Player6 count;
-- EEex_Sprite_GetCharacterIndex), for a designer's orders (combat-intent/orders.lua). With a memory
-- and the tick the protections come from it, and so do its saving throws, resistances, level, missile
-- protection and creature file, as one part ('details': some twenty stats for each enemy of each
-- decision); its IDS values and its place in the party are read every time. The tables of saving throws
-- and resistances are then shared between all who look: the policy modules read them and never change
-- them.
function M.details(g,sprite,entry,memory,tick)
    local t=sprite.m_typeAI
    entry.ids={ea=t.m_EnemyAlly,general=t.m_General,race=t.m_Race,class=t.m_Class,
        specific=t.m_Specifics,gender=t.m_Gender,alignment=t.m_Alignment}
    local d=recall(memory,sprite,tick,'details',function()
        local saves,resist={},{}
        for name,n in pairs(M.saves) do saves[name]=stat(g,sprite,n) end
        for name,n in pairs(M.resists) do resist[name]=stat(g,sprite,n) end
        local level=0
        for _,n in ipairs(M.levels) do level=math.max(level,stat(g,sprite,n)) end
        local missiles
        local spellState=rawget(g,'EEex_Sprite_GetSpellState')
        if type(spellState)=='function' then
            local ok,v=pcall(spellState,sprite,M.normalMissiles)
            if ok and v==true then missiles=true end
        end
        local resref=name(sprite.m_resref)
        return {saves=saves,resist=resist,level=level,normalMissiles=missiles,
            reflects=stat(g,sprite,M.physicalMirror)>0 or nil,resref=resref~='' and resref or nil}
    end)
    entry.saves,entry.resist,entry.level=d.saves,d.resist,d.level
    entry.normalMissiles,entry.reflects,entry.resref=d.normalMissiles,d.reflects,d.resref
    entry.protections=recall(memory,sprite,tick,'protections',function() return M.protectionRows(g,sprite) end)
    entry.player=partyPlace(g,sprite)
    return entry
end

-- The spell an action casts: its resref string, else the resref its SPELL.IDS number names; nil
-- for none.
function M.spellOf(action)
    local resref=text(action.m_string1.m_pchData:get())
    if resref~='' then return resref end
    local number=action.m_specificID
    if type(number)~='number' or number<1000 or number>=5000 or number%1~=0 then return nil end
    return M.prefixes[math.floor(number/1000)]..string.format('%03d',number%1000)
end
-- The cast a creature is in that damage can break (M.breakable), as plain values: its spell
-- (resref) and the count of its casting aura (timer, -1 while the aura is free; it counts from 0
-- when the casting begins); nil for none.
function M.casting(g,sprite)
    local action=sprite.m_curAction
    if not M.breakable[action.m_actionID] then return nil end
    local resref=M.spellOf(action)
    if not resref then return nil end
    local timer=g.EEex_Sprite_GetCastTimer(sprite)
    return {resref=resref,timer=type(timer)=='number' and timer or -1}
end

-- The engine's own SPLPROT check, CRuleTables::IsProtectedFromSpell(row, stats, mine, value) as
-- EEex's LuaBindings expose it: whether stats meets the row, with mine as the other creature for
-- rows that compare two. The engine's opcode 326 passes the creature that receives the effect
-- as stats and the effect's source as mine.
local function ruleTables(g)
    local chitin=rawget(g,'EEex_EngineGlobal_CBaldurChitin')
    local engine=rawget(g,'EngineGlobals')
    if not chitin and engine then chitin=engine.g_pBaldurChitin end
    return chitin.m_pObjectGame.m_ruleTables
end
-- Marks which of rows ({key={row,value,flip,caster}}, the SPLPROT conditions of the spells in
-- question) each enemy of the frame meets as the target of this caster's spell:
-- entry.splprot[key]=true or false. flip swaps the two creatures, as EEex's 326 does with special
-- bit 0; a caster row is the caster's own check (a 326 that lands on it, whoever receives what
-- follows), the same mark on every enemy. A row the engine does not answer stays unmarked, and
-- nothing that depends on it is judged. Returns the marks read, the checks that failed and the
-- last failure.
function M.splprot(g,sprite,frame,rows)
    if next(rows)==nil or #frame.enemies==0 then return 0,0 end
    local ok,rt=pcall(ruleTables,g)
    if not ok or rt==nil then return 0,1,tostring(rt) end
    local read,failed,last=0,0,nil
    local own={}
    for _,entry in ipairs(frame.enemies) do
        local enemy=g.EEex_GameObject_Get(entry.id)
        if enemy and g.EEex_GameObject_IsSprite(enemy,false) then
            local marks=entry.splprot or {}
            entry.splprot=marks
            for key,f in pairs(rows) do
                if marks[key]==nil and f.caster and own[key]~=nil then marks[key]=own[key]
                elseif marks[key]==nil then
                    local stats,mine=enemy,sprite
                    if f.caster then stats=sprite elseif f.flip then stats,mine=sprite,enemy end
                    local done,v=pcall(function() return rt:IsProtectedFromSpell(f.row,stats,mine,f.value) end)
                    if done and type(v)=='number' then marks[key]=v~=0;read=read+1
                    elseif done and type(v)=='boolean' then marks[key]=v;read=read+1
                    else failed=failed+1;last=done and 'answer '..type(v) or tostring(v) end
                    if f.caster then own[key]=marks[key] end
                end
            end
        end
    end
    return read,failed,last
end

local function itemAt(equipment,slot,reader)
    if equipment==nil or type(slot)~='number' then return nil end
    local item=equipment.m_items:get(slot)
    if item==nil then return nil end
    local resref=name(item.cResRef)
    if resref=='' then return nil end
    return reader.get('ITM',resref),resref
end

-- The game's tables a weapon's parts come from (combat-intent/arsenal.lua), read once through
-- EEex as plain values: WSPECIAL's bonuses and WSPATCK's attacks by stars (and level), STRMOD's
-- and STRMODEX's bonuses by strength, DEXMOD's missile bonus by dexterity and CLSWPBON's rows by
-- class name. nil and why when they cannot be read; that is kept too.
local tableCache=setmetatable({},{__mode='k'})
local function readTables(g)
    local function at(t,column,row)
        local v=g.EEex_Resource_GetAt2DALabels(t,column,tostring(row))
        return tonumber(v)
    end
    local out={wspecial={},wspatck={},strmod={},strmodex={},dexmod={},classes={}}
    local t=g.EEex_Resource_Load2DA('WSPECIAL')
    for n=0,M.maxStars do
        local hit,damage=at(t,'HIT',n),at(t,'DAMAGE',n)
        if hit and damage then out.wspecial[n]={hit=hit,damage=damage} end
    end
    -- WSPATCK's columns are the levels from 1 (the game's own has 50); its width counts the label
    -- column too.
    t=g.EEex_Resource_Load2DA('WSPATCK')
    local width=g.EEex_Resource_Get2DADimensions(t)
    local levels=math.min(M.maxLevel,(tonumber(width) or 1)-1)
    for n=0,M.maxStars do
        local index=g.EEex_Resource_Find2DARowLabel(t,tostring(n))
        if type(index)=='number' and index>=0 then
            local row={}
            for level=1,levels do
                local v=g.EEex_Resource_GetAt2DAPoint(t,level-1,index)
                row[level]=tonumber(v)
            end
            out.wspatck[n]=row
        end
    end
    for file,key in pairs({STRMOD={'strmod',M.maxScore},STRMODEX={'strmodex',M.maxExceptional}}) do
        t=g.EEex_Resource_Load2DA(file)
        for n=0,key[2] do
            local hit,damage=at(t,'TO_HIT',n),at(t,'DAMAGE',n)
            if hit and damage then out[key[1]][n]={hit=hit,damage=damage} end
        end
    end
    t=g.EEex_Resource_Load2DA('DEXMOD')
    for n=0,M.maxScore do out.dexmod[n]=at(t,'MISSILE',n) end
    -- INTMOD's maze dice by intelligence (IESDP opcode 213; the SR lab's table differs from the
    -- IESDP's), apart, so that a table without them takes none of the others along.
    out.maze={}
    pcall(function()
        local intmod=g.EEex_Resource_Load2DA('INTMOD')
        for n=0,M.maxScore do
            local num,size=at(intmod,'MAZE_DURATION_DICE_NUM',n),at(intmod,'MAZE_DURATION_DICE_SIZE',n)
            if num and size then out.maze[n]={num=num,size=size} end
        end
    end)
    t=g.EEex_Resource_Load2DA('CLSWPBON')
    local _,rows=g.EEex_Resource_Get2DADimensions(t)
    for n=0,(tonumber(rows) or 0)-1 do
        local label=g.EEex_Resource_Get2DARowLabel(t,n)
        if type(label)=='string' and label~='' then
            out.classes[label:upper()]={profApr=(at(t,'GETS_PROF_APR',label) or 0)~=0,penalty=at(t,'ZERO_SKILL_THAC0',label) or 0}
        end
    end
    return out
end
function M.tables(g)
    local known=tableCache[g]
    if known==nil then
        local ok,value=pcall(readTables,g)
        known=ok and {tables=value} or {error=tostring(value)}
        tableCache[g]=known
    end
    return known.tables,known.error
end

-- The plain values combat-intent/arsenal.lua works on for a creature (arsenal.hand): its weapon
-- stats, strength, dexterity and level, the items in its fist, quiver, magic weapon and weapon
-- slots, and the selected slot and ability; with full also its stars in the proficiencies of those
-- items, its class's CLSWPBON row and the attacks its creature file gives it.
local function facts(g,sprite,reader,tables,full)
    local c={stats={},items={},str=stat(g,sprite,M.scores.str),strExtra=stat(g,sprite,M.scores.strExtra),
        dex=stat(g,sprite,M.scores.dex),level=0}
    for key,n in pairs(M.combat) do c.stats[key]=stat(g,sprite,n) end
    for _,n in ipairs(M.levels) do c.level=math.max(c.level,stat(g,sprite,n)) end
    local equipment=sprite.m_equipment
    if equipment==nil then return c end
    c.selected=equipment.m_selectedWeapon
    c.ability=number(equipment.m_selectedWeaponAbility)
    local slots={c.selected,M.fistSlot,M.magicSlot}
    for _,list in ipairs({M.quiver,M.weaponSlots}) do for _,slot in ipairs(list) do slots[#slots+1]=slot end end
    for _,slot in ipairs(slots) do
        if c.items[slot]==nil then
            local record,resref=itemAt(equipment,slot,reader)
            if type(record)=='table' then c.items[slot]={resref=resref,record=record} end
        end
    end
    if full then
        c.pips={}
        for _,it in pairs(c.items) do
            local p=it.record.proficiency
            if type(p)=='number' and p>0 and c.pips[p]==nil then c.pips[p]=stat(g,sprite,p) end
        end
        local class=type(reader.idsName)=='function' and reader.idsName('CLASS',sprite.m_typeAI.m_Class)
        local row=type(class)=='string' and type(tables)=='table' and tables.classes[class] or nil
        c.profApr,c.penalty=row~=nil and row.profApr or false,row and row.penalty or 0
        local ok,base=pcall(function() return sprite.m_baseStats.m_numberOfAttacksBase end)
        if ok and type(base)=='number' then c.baseApr=base end
    end
    return c
end

-- A creature's weapon as plain values (combat-intent/threat.lua's attack data;
-- combat-intent/arsenal.lua's hand): attacks a round with half attacks decoded, THAC0 with the
-- bonuses the game reports for the weapon in hand, the average damage of a hit with strength's
-- bonus, whether it shoots and how far, and whether the weapon is magical (for Protection from
-- Magical Weapons). A launcher shoots the ammunition in the first quiver slot it fits (while one is
-- in hand, the selected slot is that quiver slot). For the caster's own weapon attack
-- (combat-intent/weapons.lua) also the item and its ability (1 for the first), the ammunition, the
-- damage type, the hitting item's flags and enchantment, the projectile of a missile, the slot and
-- ability number SelectWeaponAbility takes, and whether it fights with its fists (the fist slot
-- selected: on-hit effects for fists only). Without a weapon that strikes, damage and magic stay
-- unknown.
-- With a memory and the tick it comes from the memory (recall).
function M.attack(g,sprite,reader,memory,tick)
    return recall(memory,sprite,tick,'attack',function()
        local tables=M.tables(g)
        return arsenal.hand(tables,facts(g,sprite,reader,tables,false))
    end)
end
-- The weapon in the creature's hand (M.attack, with the parts the game's tables give for its two
-- right-hand bonuses) and the other weapons it could take up (arsenal.others), and why the tables
-- could not be read (then there are no others).
function M.arsenal(g,sprite,reader)
    local tables,err=M.tables(g)
    local c=facts(g,sprite,reader,tables,true)
    return arsenal.hand(tables,c),arsenal.others(tables,c),err
end

-- What protects a creature now, as plain values (combat-intent/defence.lua's guard): its
-- active effects classified as one record (classify(record,level), combat-intent/spells.lua; level:
-- the creature's, at which what its hits cast counts) for their roles, the engine's counts of
-- Stoneskin skins and Mirror Images, the spells its effects come from, the spells opcode 206 keeps
-- off it, and the conditions on it a cure takes away with the seconds each has left (math.huge for
-- one without an end) and the hit points its poison will still take; hits: the on-hit and critical
-- hit effects it carries (each effect names the spell or item it comes from, for one that its first
-- hit ends and one of a single weapon). Effects that end within M.expiring seconds and delayed ones
-- that have not started are left out of its roles. With a memory, what the effects say comes from it
-- (recall: a condition's seconds left are then up to knownTicks old); the skins and images are
-- counted afresh every time, as hits use them up without an effect coming or going.
local function drainsAbility(e)
    if (e.m_done or 0)~=0 or not M.abilityDrain[e.m_effectId] then return false end
    local amount,mode=number(e.m_effectAmount),number(e.m_dWFlags)%65536
    if amount>=2147483648 then amount=amount-4294967296 end
    return (mode==0 and amount<0) or (mode==1 and amount<12) or (mode==2 and amount<100)
end
function M.abilityDrained(g,sprite,tick)
    local found=false
    local seen=0
    g.EEex_Utility_IterateCPtrList(sprite.m_timedEffectList,function(e)
        seen=seen+1
        if seen>M.maxEffects then return true end
        if e.m_durationType==M.timedEffect and drainsAbility(e) and number(e.m_duration)>tick then
            found=true;return true
        end
    end)
    return found
end
local function shields(g,sprite,tick,classify,level)
    local list,sources,recast,conditions={},{},{},{}
    local poison=0
    for n,effects in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(effects,function(e)
            seen=seen+1
            if seen>M.maxEffects then return true end
            local kind=e.m_durationType
            local timing,duration
            if kind==4096 then
                local left=(number(e.m_duration)-tick)/15
                if left>=M.expiring then timing,duration=0,math.floor(left) end
            elseif kind==1 or kind==9 then timing,duration=1,0
            elseif kind==2 then timing,duration=2,0 end
            local op=e.m_effectId
            -- A condition counts with any time left; one without an end lasts.
            local label=type(op)=='number' and M.conditions[op]
            if label then
                local left
                if kind==4096 then left=(number(e.m_duration)-tick)/15
                elseif kind==1 or kind==9 or kind==2 then left=math.huge end
                if left and left>0 then
                    conditions[label]=math.max(conditions[label] or 0,left)
                    -- Poison's hit points left as the classifier counts them: per second by
                    -- its type, over its first minute (one without an end too). Parameters 3
                    -- and 4 are m_effectAmount2 and 3, the EFF file's order.
                    if label=='poison' then
                        local rate=spells.perSecond({opcode=op,p1=number(e.m_effectAmount),p2=number(e.m_dWFlags),
                            p3=number(e.m_effectAmount2),p4=number(e.m_effectAmount3)}) or 0
                        poison=poison+rate*math.min(left,spells.overTime)
                    end
                end
            elseif n==1 and kind==M.timedEffect and drainsAbility(e) then
                local left=(number(e.m_duration)-tick)/15
                if left>0 then conditions.abilityDrain=math.max(conditions.abilityDrain or 0,left) end
            end
            if timing and type(op)=='number' then
                local source=name(e.m_sourceRes)
                if source~='' then sources[source]=true end
                local res=name(e.m_res)
                if op==206 and res~='' then recast[res]=true end
                if not M.delivered[op] then
                    list[#list+1]={opcode=op,target=1,power=number(e.m_spellLevel),p1=number(e.m_effectAmount),
                        p2=number(e.m_dWFlags),p3=number(e.m_effectAmount2),p4=number(e.m_effectAmount3),
                        timing=timing,resist=0,duration=duration,prob1=100,prob2=0,res=res,
                        dice=number(e.m_numDice),sides=number(e.m_diceSize),save=0,saveBonus=0,special=number(e.m_special),
                        source=source}
                end
            end
        end)
    end
    local record={kind='SPL',resref='',name=0,flags=0,spellType=0,exclusion=0,school=0,secondary=0,level=1,
        casting={},abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=0,minLevel=1,speed=0,
        projectile=1,effects=list}}}
    local classified=classify(record,level)
    return {roles=type(classified)=='table' and classified.roles or {},sources=sources,recast=recast,
        conditions=conditions,poison=poison,hits=type(classified)=='table' and classified.hits or nil}
end
function M.guard(g,sprite,tick,classify,level,memory)
    local s=recall(memory,sprite,tick,'guard',function() return shields(g,sprite,tick,classify,level) end)
    local mirror=sprite.m_nMirrorImages
    return {roles=s.roles,stoneskins=stat(g,sprite,M.combat.stoneskins),mirror=type(mirror)=='number' and mirror or 0,
        sources=s.sources,recast=s.recast,conditions=s.conditions,poison=s.poison,hits=s.hits}
end

-- What a removal can take from a creature (combat-intent/removal.lua): each of its active effects
-- as plain values, in list order: its opcode, parameters and resource, the spell or item it comes from
-- (source), its school, secondary type, power and caster level, whether a dispel can take it
-- (m_flags bit 0, as EEex's EEex_HasDispellableEffect tests), whether it runs on time (timed, with
-- the seconds left), comes with an item (equipped) or lasts after death (lasting: timing 9, which
-- removals by type and opcode leave), and its roles: classify(effect) of the effect alone, a plain
-- effect record (callers may cache by its fields). Delivered effects (what they delivered is in the
-- list already) and ones about to end are left out, except active removal screens: even a
-- screen with less than a round left still absorbs a removal that lands now.
function M.wards(g,sprite,tick,classify)
    local out={}
    for n,effects in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(effects,function(e)
            seen=seen+1
            if seen>M.maxEffects then return true end
            local op=e.m_effectId
            if type(op)~='number' or M.delivered[op] then return end
            local kind=e.m_durationType
            local timing,duration,left
            if kind==4096 then
                left=(number(e.m_duration)-tick)/15
                local screen=(op==101 and e.m_dWFlags==58) or (op==206 and name(e.m_res)~='')
                if left<=0 or (left<M.expiring and not screen) then return end
                timing,duration=0,math.floor(left)
            elseif kind==1 or kind==9 then timing,duration,left=1,0,math.huge
            elseif kind==2 then timing,duration,left=2,0,math.huge
            else return end
            local effect={opcode=op,target=1,power=number(e.m_spellLevel),p1=number(e.m_effectAmount),
                p2=number(e.m_dWFlags),p3=number(e.m_effectAmount2),p4=number(e.m_effectAmount3),timing=timing,
                resist=0,duration=duration,prob1=100,prob2=0,res=name(e.m_res),
                dice=number(e.m_numDice),sides=number(e.m_diceSize),save=0,saveBonus=0,special=number(e.m_special)}
            out[#out+1]={opcode=op,p1=effect.p1,p2=effect.p2,res=effect.res,source=name(e.m_sourceRes),school=number(e.m_school),
                secondary=number(e.m_secondaryType),power=number(e.m_spellLevel),level=number(e.m_casterLevel),
                dispellable=band(g,number(e.m_flags),1)~=0,timed=n==1 and kind==4096,equipped=n==2,
                lasting=kind==9,left=left,roles=classify(effect)}
        end)
    end
    return out
end

-- The lists an area keeps its objects in (learned.md): standing creatures and objects, lying
-- creatures and the dead, flying objects and those drawn underneath. A projectile goes to the one
-- its own m_addToListType names, so every list is read.
M.areaLists={'m_lVertSort','m_lVertSortBack','m_lVertSortFlight','m_lVertSortUnder'}
-- Objects looked at per list and read at most, and effects per projectile.
M.maxObjects=2048
M.maxZoneEffects=64

-- An effect a projectile carries, as a plain record for the classifier: it reaches the creatures
-- the projectile hits. Effects carried are not started yet, so their timing and duration are still
-- the file's (a started one, timing 4096, counts its seconds left).
local function carried(g,e,tick)
    local kind=number(e.m_durationType)
    local timing,duration=kind,number(e.m_duration)
    if kind==M.timedEffect then timing,duration=0,math.max(0,math.floor((duration-tick)/15))
    elseif kind>10 then timing=0 end
    return {opcode=number(e.m_effectId),target=2,power=number(e.m_spellLevel),p1=number(e.m_effectAmount),
        p2=number(e.m_dWFlags),p3=number(e.m_effectAmount2),p4=number(e.m_effectAmount3),timing=timing,
        resist=band(g,number(e.m_flags),0xFF),duration=duration,
        prob1=number(e.m_probabilityUpper),prob2=number(e.m_probabilityLower),res=name(e.m_res),
        dice=number(e.m_numDice),sides=number(e.m_diceSize),save=number(e.m_savingThrow),saveBonus=number(e.m_saveMod),
        special=number(e.m_special)}
end
-- The danger zones in an area at tick, as plain values: every area projectile (EEex's
-- CProjectileArea) that has reached its place and has explosions left: its object id, centre and
-- the place it flew to (dest), radius (explosion range), explosions left (repeats), ticks between
-- them (delay) and its tick counter, the object id of its source, its projectile as a spell's
-- ability names it (the engine counts PROJECTL.IDS from 0, the ability's field from 1; lab batch H)
-- and its PRO file (pro), the highest caster level among its effects, the spell or item they come
-- from (resref), the list it lies in, and its effects as plain records (carried). A projectile
-- that cannot be read is left out; returns the zones, the count of those that failed and the last
-- failure.
-- With a memory, which of the area's objects are area projectiles comes from it, list by list
-- (areaRecall, a part for each list): each of those is read anew every time, the others are not looked
-- at again until their list changes its length. (Arrows come and go in the list of flying objects all
-- through a fight, lab prof-camp-4; the standing creatures and objects are in another.)
function M.zones(g,area,tick,memory)
    local out,failed,last={},0,nil
    if area==nil then return out,0 end
    local getType,types,cast=g.EEex_Projectile_GetType,g.EEex_Projectile_Type,g.EEex_CastUD
    local wanted=types.CProjectileArea
    -- The objects that are area projectiles, or whose kind cannot be read (they fail again below), as
    -- their id and the list they lie in.
    local found={}
    for _,listName in ipairs(M.areaLists) do
        local some=areaRecall(memory,area,tick,'zones/'..listName,{listName},function()
            local list,kept=area[listName],{}
            if list==nil then return kept end
            local ids,seen={},0
            g.EEex_Utility_IterateCPtrList(list,function(id)
                seen=seen+1
                if seen>M.maxObjects then return true end
                ids[#ids+1]=id
            end)
            for _,id in ipairs(ids) do
                local object=g.EEex_GameObject_Get(id)
                if object~=nil and not g.EEex_GameObject_IsSprite(object,true) then
                    local ok,kind=pcall(getType,object)
                    if not ok or kind==wanted then kept[#kept+1]={id=id,list=listName} end
                end
            end
            return kept
        end)
        for _,f in ipairs(some) do found[#found+1]=f end
    end
    for _,f in ipairs(found) do
        local id,listName=f.id,f.list
        local object=g.EEex_GameObject_Get(id)
        if object~=nil and not g.EEex_GameObject_IsSprite(object,true) then
            local ok,z=pcall(function()
                if getType(object)~=wanted then return nil end
                local p=cast(object,'CProjectileArea')
                local repeats=number(p.m_nRepetitionCount)
                if number(p.m_bReachedDestination)==0 or repeats<=0 then return nil end
                local effects,level,resref={},0,''
                local n=0
                g.EEex_Utility_IterateCPtrList(p.m_effectList,function(e)
                    n=n+1
                    if n>M.maxZoneEffects then return true end
                    effects[#effects+1]=carried(g,e,tick)
                    level=math.max(level,number(e.m_casterLevel))
                    if resref=='' then resref=name(e.m_sourceRes) end
                end)
                return {id=id,x=number(p.m_pos.x),y=number(p.m_pos.y),dest={x=number(p.m_posDest.x),y=number(p.m_posDest.y)},
                    radius=number(p.m_explosionRange),repeats=repeats,delay=number(p.m_nDelay),
                    counter=number(p.m_nDelayCount),source=number(p.m_sourceId),
                    projectile=number(p.m_projectileType)+1,pro=name(p.m_resref),
                    level=level,resref=resref,list=listName,effects=effects}
            end)
            if not ok then failed=failed+1;last=tostring(z)
            elseif z then out[#out+1]=z end
        end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out,failed,last
end

-- Marks which of rows (the SPLPROT conditions of the spells in question) a creature meets as the
-- receiver (stats) of a spell from mine, as M.splprot does for enemies: entry.splprot[key]; a
-- caster row is mine's own check. Returns the marks read, the checks that failed and the last
-- failure.
function M.mark(g,entry,stats,mine,rows)
    if next(rows)==nil then return 0,0 end
    local ok,rt=pcall(ruleTables,g)
    if not ok or rt==nil then return 0,1,tostring(rt) end
    local read,failed,last=0,0,nil
    local marks=entry.splprot or {}
    entry.splprot=marks
    for key,f in pairs(rows) do
        if marks[key]==nil then
            local a,b=stats,mine
            if f.caster then a=mine elseif f.flip then a,b=mine,stats end
            local done,v=pcall(function() return rt:IsProtectedFromSpell(f.row,a,b,f.value) end)
            if done and type(v)=='number' then marks[key]=v~=0;read=read+1
            elseif done and type(v)=='boolean' then marks[key]=v;read=read+1
            else failed=failed+1;last=done and 'answer '..type(v) or tostring(v) end
        end
    end
    return read,failed,last
end

-- Adds what the defence slice weighs to a frame read with details: each friend's guard (false
-- if it could not be read) and spell protections (what keeps an ally's heal, cure or defence off
-- it; lab batch H: SCS's Minor Globe of Invulnerability), the weapons of enemies and allies, and
-- whether each enemy sees invisible creatures. A creature whose engine data fails keeps what it
-- has; returns the count of failures and the last one. With a memory, what the effects and weapons
-- say comes from it (recall), so a crowd is read once a second and not once a decision.
function M.defend(g,frame,tick,reader,classify,memory)
    local failed,last=0,nil
    local function each(entry,fn)
        local sprite=g.EEex_GameObject_Get(entry.id)
        if not sprite or not g.EEex_GameObject_IsSprite(sprite,false) then return end
        local ok,err=pcall(fn,sprite)
        if not ok then failed=failed+1;last=tostring(err) end
    end
    local function friend(entry)
        entry.guard=false
        each(entry,function(sprite)
            M.identity(g,sprite,entry,memory,tick)
            entry.protections=recall(memory,sprite,tick,'protections',function() return M.protectionRows(g,sprite) end)
            entry.guard=M.guard(g,sprite,tick,classify,entry.level,memory)
            if entry~=frame.self then entry.attack=M.attack(g,sprite,reader,memory,tick) end
        end)
    end
    friend(frame.self)
    for _,a in ipairs(frame.allies) do friend(a) end
    for _,e in ipairs(frame.enemies) do
        each(e,function(sprite)
            e.seeInvisible=stat(g,sprite,M.stats.seeInvisible)>0 or stat(g,sprite,M.stats.trueSight)>0
            e.attack=M.attack(g,sprite,reader,memory,tick)
        end)
    end
    return failed,last
end

-- A foe out of play as its side will meet it again (combat-intent/choice.lua's readiness): what an
-- enemy in sight carries (M.actor, M.details), its weapon and whether it sees invisible creatures
-- (as M.defend reads them), and its intelligence (int), by which a maze lasts.
function M.foe(g,sprite,reader)
    local entry=M.actor(g,sprite)
    M.details(g,sprite,entry)
    entry.seeInvisible=stat(g,sprite,M.stats.seeInvisible)>0 or stat(g,sprite,M.stats.trueSight)>0
    entry.attack=M.attack(g,sprite,reader)
    entry.int=stat(g,sprite,M.scores.int)
    return entry
end
-- What keeps a foe out of play, as plain values: charm, the seconds left of the longest charm on it
-- (M.charm; math.huge for one without an end), and maze, how its maze lasts (M.maze's parameter 2:
-- 0 by intelligence, 1 by the effect's duration); nil for what it does not carry.
function M.outOfPlay(g,sprite,tick)
    local out={}
    for _,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(e)
            seen=seen+1
            if seen>M.maxEffects then return true end
            local op=e.m_effectId
            if op==M.charm then
                local kind,left=e.m_durationType,nil
                if kind==M.timedEffect then left=(number(e.m_duration)-tick)/15
                elseif kind==1 or kind==9 or kind==2 then left=math.huge end
                if left and left>0 then out.charm=math.max(out.charm or 0,left) end
            elseif op==M.maze and out.maze==nil then
                out.maze=number(e.m_dWFlags)
            end
        end)
    end
    return out
end

function M.side(ea)
    if type(ea)~='number' then return nil end
    if ea>=M.EVIL_CUTOFF then return 'evil' end
    if ea>=2 and ea<=M.GOOD_CUTOFF then return 'good' end
end

-- The creatures lying in the area's back list that this creature sees: the area search from
-- where each one lies, with this creature's terrain table for line of sight, finds it. A living
-- one goes to consider(object), which files it as ally or enemy; a dead ally goes to fallen, as
-- its id, position, state and gender. seen holds the ids already filed.
local function lying(g,sprite,self,seen,consider,fallen,memory,tick)
    local area=sprite.m_pArea
    local back=area and area.m_lVertSortBack
    if not back then return end
    -- The creatures in the back list (with a memory from it: areaRecall, part 'lying'), as their ids.
    local ids=areaRecall(memory,area,tick,'lying',{'m_lVertSortBack'},function()
        local all,some={},{}
        g.EEex_Utility_IterateCPtrList(back,function(id) all[#all+1]=id end)
        for _,id in ipairs(all) do
            local object=g.EEex_GameObject_Get(id)
            if object and g.EEex_GameObject_IsSprite(object,true) then some[#some+1]=id end
        end
        return some
    end)
    if #ids==0 then return end
    local ok,terrain=pcall(function() return sprite:virtual_GetVisibleTerrainTable() end)
    if not ok then terrain=nil end
    local own=M.side(self.ea)
    local searches,dead=0,0
    for _,id in ipairs(ids) do
        local object=not seen[id] and id~=self.id and g.EEex_GameObject_Get(id)
        if object and g.EEex_GameObject_IsSprite(object,true) then
            local side=M.side(object.m_typeAI.m_EnemyAlly)
            local living=g.EEex_GameObject_IsSprite(object,false)
            if side~=nil and ((living and searches<M.maxLying) or (not living and side==own and dead<M.maxFallen)) then
                seen[id]=true
                if living then searches=searches+1 else dead=dead+1 end
                local found=false
                g.EEex_Area_ForAllOfTypeStringInRange(area,object.m_pos.x,object.m_pos.y,'[ANYONE]',M.sightRange,
                    function(other) if other~=nil and other.m_id==self.id then found=true end end,1,0,terrain)
                if found and living then consider(object)
                elseif found then
                    fallen[#fallen+1]={id=object.m_id,x=object.m_pos.x,y=object.m_pos.y,
                        state=g.EEex_Sprite_GetState(object),gender=object.m_typeAI.m_Gender}
                end
            end
        end
    end
end

-- The creature's frame at tick, or nil when it is on no side. detailed adds IDS values and
-- protections for each enemy (the protections from memory, when one is given: recall). A blind
-- creature perceives no one.
function M.frame(g,sprite,tick,detailed,memory)
    local self=M.actor(g,sprite,memory,tick)
    local side=M.side(self.ea)
    if side==nil then return nil end
    self.seeInvisible=stat(g,sprite,M.stats.seeInvisible)>0 or stat(g,sprite,M.stats.trueSight)>0
    local area=sprite.m_pArea
    local frame={tick=tick,area=area and text(area.m_resref:get()) or '',self=self,enemies={},allies={},fallen={}}
    if band(g,self.state,M.blind)~=0 then return frame end
    local seen={}
    local function consider(object)
        local other=M.side(object.m_typeAI.m_EnemyAlly)
        if other==nil then return end
        if other~=side and not self.seeInvisible and band(g,g.EEex_Sprite_GetState(object),M.unseen)~=0 then return end
        local entry=M.actor(g,object,memory,tick,true)
        if other==side then
            -- A charmed ally from the party is a foe its side charmed (combat-intent/director.lua).
            if targeting.charmed(entry) then entry.player=partyPlace(g,object) end
            frame.allies[#frame.allies+1]=entry
        else
            if detailed then M.details(g,object,entry,memory,tick) end
            frame.enemies[#frame.enemies+1]=entry
        end
    end
    -- Numeric flags: EEex's wrapper turns a Lua false into its default.
    g.EEex_Sprite_ForAllOfTypeStringInRange(sprite,'[ANYONE]',M.sightRange,function(object)
        if object==nil or seen[object.m_id] or object.m_id==self.id or not g.EEex_GameObject_IsSprite(object,false) then return end
        seen[object.m_id]=true
        consider(object)
    end,1,0)
    lying(g,sprite,self,seen,consider,frame.fallen,memory,tick)
    table.sort(frame.enemies,function(a,b) return a.id<b.id end)
    table.sort(frame.allies,function(a,b) return a.id<b.id end)
    table.sort(frame.fallen,function(a,b) return a.id<b.id end)
    return frame
end

-- Whether the creature could see a spot (x, y) now (the engine's search): within its sight range
-- and line of sight, by the area search from the spot with the creature's own terrain table, as
-- M.frame finds creatures lying down. A blind creature sees no spot.
function M.sees(g,sprite,x,y)
    if band(g,g.EEex_Sprite_GetState(sprite),M.blind)~=0 then return false end
    local area=sprite.m_pArea
    if not area or type(x)~='number' or type(y)~='number' then return false end
    local ok,terrain=pcall(function() return sprite:virtual_GetVisibleTerrainTable() end)
    if not ok then terrain=nil end
    local found=false
    g.EEex_Area_ForAllOfTypeStringInRange(area,math.floor(x+0.5),math.floor(y+0.5),'[ANYONE]',M.sightRange,
        function(other) if other~=nil and other.m_id==sprite.m_id then found=true end end,1,0,terrain)
    return found
end

-- Whether the creature sees a living enemy now, as M.frame would list one standing (not one lying
-- down): a light look for holds that end when an enemy shows.
function M.seesEnemy(g,sprite)
    local side=M.side(sprite.m_typeAI.m_EnemyAlly)
    if side==nil or band(g,g.EEex_Sprite_GetState(sprite),M.blind)~=0 then return false end
    local seeInvisible=stat(g,sprite,M.stats.seeInvisible)>0 or stat(g,sprite,M.stats.trueSight)>0
    local found=false
    g.EEex_Sprite_ForAllOfTypeStringInRange(sprite,'[ANYONE]',M.sightRange,function(object)
        if found or object==nil or object.m_id==sprite.m_id or not g.EEex_GameObject_IsSprite(object,false) then return end
        local other=M.side(object.m_typeAI.m_EnemyAlly)
        if other~=nil and other~=side and (seeInvisible or band(g,g.EEex_Sprite_GetState(object),M.unseen)==0) then
            found=true
        end
    end,1,0)
    return found
end
return M
