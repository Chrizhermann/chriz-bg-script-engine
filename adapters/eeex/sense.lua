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
-- area (D3e): its area projectiles that explode again and again. Only plain values leave this
-- module; no engine object is kept.
local targeting=require('combat-intent.targeting')
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
-- STATE_INVISIBLE and STATE_IMPROVEDINVISIBILITY; STATE_BLIND.
M.unseen,M.blind=0x400010,0x40000
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
-- THAC0BONUSRIGHT, DAMAGEBONUSRIGHT, STONESKINS, HITBONUS. In the lab the right-hand bonuses
-- held strength, proficiency and the weapon's own bonus to hit (probe F: a fighter with 18
-- strength, specialised in a Short Sword +1, had THAC0BONUSRIGHT 3).
M.combat={ac=2,thac0=7,apr=8,damageBonus=50,thac0Right=84,damageRight=86,stoneskins=88,hitBonus=151}
-- The quiver slots, whose ammunition a launcher shoots (SLOTS.IDS).
M.quiver={11,12,13}
-- An effect that ends within this many seconds no longer protects.
M.expiring=6
-- Opcodes that deliver other effects; what they delivered is in the list already.
M.delivered={[146]=true,[148]=true,[177]=true,[272]=true,[283]=true,[326]=true,[333]=true,[366]=true}
-- Conditions a cure takes away, by the opcode that sets them (combat-intent/spells.lua's labels;
-- combat-intent/care.lua weighs them). Hold (II) (185) stands apart: opcode 162, the cure of
-- holds, does not remove it (IESDP).
M.conditions={[39]='sleep',[3]='berserk',[24]='panic',[45]='stun',[210]='stun',[38]='silence',[74]='blind',
    [76]='feeblemind',[78]='disease',[80]='deaf',[109]='hold',[175]='hold',[185]='hold2',[128]='confusion',
    [165]='pause',[25]='poison'}

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

-- The plain facts every frame carries for one creature: also its armour class, the creature
-- its current action is aimed at (-1 for none), its Stoneskin skins and Mirror Images, the
-- levels drained from it, whether it is webbed or entangled (rooted: it cannot walk), and the hit
-- points it cannot drop below (minHp, 0 without a minimum) with where they come from (minHpFrom,
-- M.minimumSources).
function M.actor(g,sprite)
    local state=g.EEex_Sprite_GetState(sprite)
    local action=sprite.m_curAction
    local actee=action.m_acteeID and action.m_acteeID.m_Instance
    local mirror=sprite.m_nMirrorImages
    local minimum=stat(g,sprite,M.stats.minHp)
    return {id=sprite.m_id,x=sprite.m_pos.x,y=sprite.m_pos.y,ea=sprite.m_typeAI.m_EnemyAlly,
        state=state,held=stat(g,sprite,M.stats.held),sanctuary=stat(g,sprite,M.stats.sanctuary),
        hp=sprite.m_baseStats.m_hitPoints,maxHp=stat(g,sprite,M.stats.maxHp),
        mr=stat(g,sprite,M.stats.mr),action=action.m_actionID,ac=stat(g,sprite,M.combat.ac),
        actee=type(actee)=='number' and actee or -1,skins=stat(g,sprite,M.combat.stoneskins),
        mirror=type(mirror)=='number' and mirror or 0,drained=stat(g,sprite,M.stats.levelDrain),
        rooted=stat(g,sprite,M.stats.entangle)>0 or stat(g,sprite,M.stats.web)>0,
        minHp=minimum>0 and minimum or 0,minHpFrom=minimum>0 and M.minimumSources(g,sprite) or nil}
end
-- A creature's THAC0 with its right-hand and general hit bonuses (as M.attack counts it).
function M.thac0(g,sprite)
    return stat(g,sprite,M.combat.thac0)-stat(g,sprite,M.combat.thac0Right)-stat(g,sprite,M.combat.hitBonus)
end

-- A creature's IDS values and level (the highest of its classes'), for a friend: what healing,
-- curing and summoning weigh (combat-intent/care.lua). M.details reads the same for enemies.
function M.identity(g,sprite,entry)
    local t=sprite.m_typeAI
    entry.ids={ea=t.m_EnemyAlly,general=t.m_General,race=t.m_Race,class=t.m_Class,
        specific=t.m_Specifics,gender=t.m_Gender,alignment=t.m_Alignment}
    local level=0
    for _,n in ipairs(M.levels) do level=math.max(level,stat(g,sprite,n)) end
    entry.level=level
    return entry
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
-- effect lists (M.protectionRows).
function M.details(g,sprite,entry)
    local t=sprite.m_typeAI
    entry.ids={ea=t.m_EnemyAlly,general=t.m_General,race=t.m_Race,class=t.m_Class,
        specific=t.m_Specifics,gender=t.m_Gender,alignment=t.m_Alignment}
    entry.saves,entry.resist={},{}
    for name,n in pairs(M.saves) do entry.saves[name]=stat(g,sprite,n) end
    for name,n in pairs(M.resists) do entry.resist[name]=stat(g,sprite,n) end
    local level=0
    for _,n in ipairs(M.levels) do level=math.max(level,stat(g,sprite,n)) end
    entry.level=level
    entry.protections=M.protectionRows(g,sprite)
    return entry
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
-- Marks which of rows ({key={row,value,flip}}, the SPLPROT conditions of the spells in question)
-- each enemy of the frame meets as the target of this caster's spell: entry.splprot[key]=true
-- or false. flip swaps the two creatures, as EEex's 326 does with special bit 0. A row the
-- engine does not answer stays unmarked, and nothing that depends on it is judged. Returns the
-- marks read, the checks that failed and the last failure.
function M.splprot(g,sprite,frame,rows)
    if next(rows)==nil or #frame.enemies==0 then return 0,0 end
    local ok,rt=pcall(ruleTables,g)
    if not ok or rt==nil then return 0,1,tostring(rt) end
    local read,failed,last=0,0,nil
    for _,entry in ipairs(frame.enemies) do
        local enemy=g.EEex_GameObject_Get(entry.id)
        if enemy and g.EEex_GameObject_IsSprite(enemy,false) then
            local marks=entry.splprot or {}
            entry.splprot=marks
            for key,f in pairs(rows) do
                if marks[key]==nil then
                    local stats,mine=enemy,sprite
                    if f.flip then stats,mine=sprite,enemy end
                    local done,v=pcall(function() return rt:IsProtectedFromSpell(f.row,stats,mine,f.value) end)
                    if done and type(v)=='number' then marks[key]=v~=0;read=read+1
                    elseif done and type(v)=='boolean' then marks[key]=v;read=read+1
                    else failed=failed+1;last=done and 'answer '..type(v) or tostring(v) end
                end
            end
        end
    end
    return read,failed,last
end

local function average(dice,sides)
    dice,sides=number(dice),number(sides)
    return dice>0 and sides>0 and dice*(sides+1)/2 or 0
end
local function itemAt(equipment,slot,reader)
    if equipment==nil or type(slot)~='number' then return nil end
    local item=equipment.m_items:get(slot)
    if item==nil then return nil end
    local resref=name(item.cResRef)
    if resref=='' then return nil end
    return reader.get('ITM',resref),resref
end
local function magical(g,record)
    return number(record.enchantment)>0 or band(g,number(record.flags),0x40)~=0
end
-- A creature's weapon as plain values (combat-intent/threat.lua's attack data): attacks a round
-- with half attacks decoded, THAC0 with its bonuses and the weapon's own, the average damage of a
-- hit, whether it shoots and how far, and whether the weapon is magical (for Protection from
-- Magical Weapons). A launcher hits with the ammunition in the first filled quiver slot; their
-- to-hit bonuses add up, the ammunition's damage type counts, and the higher enchantment. For the
-- caster's own weapon attack (combat-intent/weapons.lua) also the item and its ability (1 for
-- the first), the ammunition, the damage type and the hitting item's flags and enchantment.
-- Without a readable weapon, damage and magic stay unknown.
function M.attack(g,sprite,reader)
    local apr=stat(g,sprite,M.combat.apr)
    if apr>5 and apr<=10 then apr=apr-5.5 end
    local out={apr=apr>0 and apr or nil,
        thac0=stat(g,sprite,M.combat.thac0)-stat(g,sprite,M.combat.thac0Right)-stat(g,sprite,M.combat.hitBonus)}
    local equipment=sprite.m_equipment
    local record,resref=itemAt(equipment,equipment and equipment.m_selectedWeapon,reader)
    local abilities=record and type(record.abilities)=='table' and record.abilities or {}
    local index=number(equipment and equipment.m_selectedWeaponAbility)+1
    if type(abilities[index])~='table' then index=1 end
    local ability=abilities[index]
    if type(ability)~='table' then return out end
    local damage=average(ability.dice,ability.sides)+number(ability.damageBonus)
    local magic=magical(g,record)
    local toHit=number(ability.thac0)
    out.item,out.ability,out.damageType=resref,index,ability.damageType
    out.flags,out.enchantment=number(record.flags),number(record.enchantment)
    if ability.attackType==4 then
        out.ranged,out.launcher=true,true
        for _,slot in ipairs(M.quiver) do
            local ammo,ammoRef=itemAt(equipment,slot,reader)
            local hit=ammo and type(ammo.abilities)=='table' and ammo.abilities[1]
            if type(hit)=='table' then
                damage=damage+average(hit.dice,hit.sides)+number(hit.damageBonus)
                toHit=toHit+number(hit.thac0)
                magic=magic or magical(g,ammo)
                out.ammo,out.damageType=ammoRef,hit.damageType
                out.flags,out.enchantment=number(ammo.flags),math.max(out.enchantment,number(ammo.enchantment))
                break
            end
        end
    elseif ability.attackType==2 then out.ranged=true end
    if out.ranged and number(ability.range)>0 then out.range=ability.range*targeting.rangeUnit end
    out.thac0=out.thac0-toHit
    out.damage=math.max(0,damage+stat(g,sprite,M.combat.damageBonus)+stat(g,sprite,M.combat.damageRight))
    out.magical=magic
    -- Plain ammunition from a magical launcher hits as magical.
    if magic and band(g,out.flags,0x40)==0 and out.enchantment<=0 then out.flags=out.flags+0x40 end
    return out
end

-- What protects a creature now, as plain values (combat-intent/defence.lua's guard): its
-- active effects classified as one record (classify(record), combat-intent/spells.lua) for
-- their roles, the engine's counts of Stoneskin skins and Mirror Images, the spells its effects
-- come from, the spells opcode 206 keeps off it, and the conditions on it a cure takes away
-- with the seconds each has left (math.huge for one without an end) and the hit points its
-- poison will still take. Effects that end within M.expiring seconds and delayed ones that have
-- not started are left out of its roles.
function M.guard(g,sprite,tick,classify)
    local list,sources,recast,conditions={},{},{},{}
    local poison=0
    for _,effects in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
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
                    -- Poison's hit points left: per second by its type, as the classifier counts it.
                    if label=='poison' and left<math.huge then
                        local p1,mode=number(e.m_effectAmount),number(e.m_dWFlags)%65536
                        local rate=({[0]=1,[1]=p1,[2]=p1>0 and 1/p1 or 0,[3]=p1})[mode] or 1
                        poison=poison+rate*left
                    end
                end
            end
            if timing and type(op)=='number' then
                local source=name(e.m_sourceRes)
                if source~='' then sources[source]=true end
                local res=name(e.m_res)
                if op==206 and res~='' then recast[res]=true end
                if not M.delivered[op] then
                    list[#list+1]={opcode=op,target=1,power=number(e.m_spellLevel),p1=number(e.m_effectAmount),
                        p2=number(e.m_dWFlags),timing=timing,resist=0,duration=duration,prob1=100,prob2=0,res=res,
                        dice=number(e.m_numDice),sides=number(e.m_diceSize),save=0,saveBonus=0,special=number(e.m_special)}
                end
            end
        end)
    end
    local record={kind='SPL',resref='',name=0,flags=0,spellType=0,exclusion=0,school=0,secondary=0,level=1,
        casting={},abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=0,minLevel=1,speed=0,
        projectile=1,effects=list}}}
    local classified=classify(record)
    local mirror=sprite.m_nMirrorImages
    return {roles=type(classified)=='table' and classified.roles or {},stoneskins=stat(g,sprite,M.combat.stoneskins),
        mirror=type(mirror)=='number' and mirror or 0,sources=sources,recast=recast,conditions=conditions,poison=poison}
end

-- What a removal can take from a creature (combat-intent/removal.lua): each of its active effects
-- as plain values, in list order: its opcode and parameter 2, the spell or item it comes from
-- (source), its school, secondary type, power and caster level, whether a dispel can take it
-- (m_flags bit 0, as EEex's EEex_HasDispellableEffect tests), whether it runs on time (timed, with
-- the seconds left), comes with an item (equipped) or lasts after death (lasting: timing 9, which
-- removals by type and opcode leave), and its roles: classify(effect) of the effect alone, a plain
-- effect record (callers may cache by its fields). Delivered effects (what they delivered is in the
-- list already) and ones about to end are left out.
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
                if left<M.expiring then return end
                timing,duration=0,math.floor(left)
            elseif kind==1 or kind==9 then timing,duration,left=1,0,math.huge
            elseif kind==2 then timing,duration,left=2,0,math.huge
            else return end
            local effect={opcode=op,target=1,power=number(e.m_spellLevel),p1=number(e.m_effectAmount),
                p2=number(e.m_dWFlags),timing=timing,resist=0,duration=duration,prob1=100,prob2=0,res=name(e.m_res),
                dice=number(e.m_numDice),sides=number(e.m_diceSize),save=0,saveBonus=0,special=number(e.m_special)}
            out[#out+1]={opcode=op,p2=effect.p2,source=name(e.m_sourceRes),school=number(e.m_school),
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
-- Objects looked at per read at most, and effects per projectile.
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
        p2=number(e.m_dWFlags),timing=timing,resist=band(g,number(e.m_flags),0xFF),duration=duration,
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
function M.zones(g,area,tick)
    local out,failed,last={},0,nil
    if area==nil then return out,0 end
    local getType,types,cast=g.EEex_Projectile_GetType,g.EEex_Projectile_Type,g.EEex_CastUD
    local wanted=types.CProjectileArea
    local seen=0
    for _,listName in ipairs(M.areaLists) do
        local list=area[listName]
        if list~=nil and seen<M.maxObjects then
            local ids={}
            g.EEex_Utility_IterateCPtrList(list,function(id)
                seen=seen+1
                if seen>M.maxObjects then return true end
                ids[#ids+1]=id
            end)
            for _,id in ipairs(ids) do
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
        end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out,failed,last
end

-- Marks which of rows (the SPLPROT conditions of the spells in question) a creature meets as the
-- receiver (stats) of a spell from mine, as M.splprot does for enemies: entry.splprot[key]. Returns
-- the marks read, the checks that failed and the last failure.
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
            if f.flip then a,b=mine,stats end
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
-- has; returns the count of failures and the last one.
function M.defend(g,frame,tick,reader,classify)
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
            M.identity(g,sprite,entry)
            entry.protections=M.protectionRows(g,sprite)
            entry.guard=M.guard(g,sprite,tick,classify)
            if entry~=frame.self then entry.attack=M.attack(g,sprite,reader) end
        end)
    end
    friend(frame.self)
    for _,a in ipairs(frame.allies) do friend(a) end
    for _,e in ipairs(frame.enemies) do
        each(e,function(sprite)
            e.seeInvisible=stat(g,sprite,M.stats.seeInvisible)>0 or stat(g,sprite,M.stats.trueSight)>0
            e.attack=M.attack(g,sprite,reader)
        end)
    end
    return failed,last
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
local function lying(g,sprite,self,seen,consider,fallen)
    local area=sprite.m_pArea
    local back=area and area.m_lVertSortBack
    if not back then return end
    local ids={}
    g.EEex_Utility_IterateCPtrList(back,function(id) ids[#ids+1]=id end)
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
-- protections for each enemy. A blind creature perceives no one.
function M.frame(g,sprite,tick,detailed)
    local self=M.actor(g,sprite)
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
        local entry=M.actor(g,object)
        if other==side then frame.allies[#frame.allies+1]=entry
        else
            if detailed then M.details(g,object,entry) end
            frame.enemies[#frame.enemies+1]=entry
        end
    end
    -- Numeric flags: EEex's wrapper turns a Lua false into its default.
    g.EEex_Sprite_ForAllOfTypeStringInRange(sprite,'[ANYONE]',M.sightRange,function(object)
        if object==nil or seen[object.m_id] or object.m_id==self.id or not g.EEex_GameObject_IsSprite(object,false) then return end
        seen[object.m_id]=true
        consider(object)
    end,1,0)
    lying(g,sprite,self,seen,consider,frame.fallen)
    table.sort(frame.enemies,function(a,b) return a.id<b.id end)
    table.sort(frame.allies,function(a,b) return a.id<b.id end)
    table.sort(frame.fallen,function(a,b) return a.id<b.id end)
    return frame
end
return M
