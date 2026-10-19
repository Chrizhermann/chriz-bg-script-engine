-- What one creature perceives right now, as plain values: itself and the living creatures it
-- can see, found with EEex's area search (sight range and line of sight, as the NumCreature()
-- trigger counts them) and minus the invisible ones unless it sees invisible creatures. That
-- search walks only the area's front list; creatures lying down (asleep, unconscious) are in
-- the back list with the dead, and one counts as seen when the same search from where it lies
-- finds this creature. Sides
-- follow the engine's EA groups: for a creature on the evil side (EA 200 and up) the good side
-- (EA 2 to 30) are enemies and the evil side are allies. With details, each enemy also carries
-- its creature IDS values, saves, resistances, level and the spell protections a script can
-- test (SCS's triggers read the same); M.splprot adds the engine's own answers to the SPLPROT
-- checks of the spells in question. M.defend adds what the defence slice weighs: what protects
-- each friend now and the weapons of the creatures around. Only plain values leave this module;
-- no engine object is kept.
local targeting=require('combat-intent.targeting')
local M={}
-- A sprite's default visual range in EEex's area search.
M.sightRange=448
M.GOOD_CUTOFF,M.EVIL_CUTOFF=30,200
-- STATS.IDS: MAXHITPOINTS, RESISTMAGIC, HELD, SANCTUARY, SEEINVISIBLE, TRUE_SIGHT.
M.stats={maxHp=1,mr=18,held=58,sanctuary=63,seeInvisible=81,trueSight=118}
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
-- Searches from lying creatures per frame at most (each one is an area search).
M.maxLying=32
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

-- The plain facts every frame carries for one creature: also its armour class, the creature
-- its current action is aimed at (-1 for none), and its Stoneskin skins and Mirror Images.
function M.actor(g,sprite)
    local state=g.EEex_Sprite_GetState(sprite)
    local action=sprite.m_curAction
    local actee=action.m_acteeID and action.m_acteeID.m_Instance
    local mirror=sprite.m_nMirrorImages
    return {id=sprite.m_id,x=sprite.m_pos.x,y=sprite.m_pos.y,ea=sprite.m_typeAI.m_EnemyAlly,
        state=state,held=stat(g,sprite,M.stats.held),sanctuary=stat(g,sprite,M.stats.sanctuary),
        hp=sprite.m_baseStats.m_hitPoints,maxHp=stat(g,sprite,M.stats.maxHp),
        mr=stat(g,sprite,M.stats.mr),action=action.m_actionID,ac=stat(g,sprite,M.combat.ac),
        actee=type(actee)=='number' and actee or -1,skins=stat(g,sprite,M.combat.stoneskins),
        mirror=type(mirror)=='number' and mirror or 0}
end
-- A creature's THAC0 with its right-hand and general hit bonuses (as M.attack counts it).
function M.thac0(g,sprite)
    return stat(g,sprite,M.combat.thac0)-stat(g,sprite,M.combat.thac0Right)-stat(g,sprite,M.combat.hitBonus)
end

-- Creature IDS values, saving throws, resistances, level and the spell protections in both
-- effect lists.
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
    local found={}
    for _,list in ipairs({sprite.m_timedEffectList,sprite.m_equipedEffectList}) do
        local seen=0
        g.EEex_Utility_IterateCPtrList(list,function(effect)
            seen=seen+1
            if seen>M.maxEffects then return true end
            if M.protections[effect.m_effectId] then
                found[#found+1]={opcode=effect.m_effectId,p1=effect.m_effectAmount,p2=effect.m_dWFlags,
                    res=text(effect.m_res:get())}
            end
        end)
    end
    entry.protections=found
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
    return resref~='' and reader.get('ITM',resref) or nil
end
local function magical(g,record)
    return number(record.enchantment)>0 or band(g,number(record.flags),0x40)~=0
end
-- A creature's weapon as plain values (combat-intent/threat.lua's attack data): attacks a round
-- with half attacks decoded, THAC0 with its bonuses, the average damage of a hit, whether it
-- shoots and how far, and whether the weapon is magical (for Protection from Magical Weapons).
-- A launcher hits with the ammunition in the first filled quiver slot. Without a readable
-- weapon, damage and magic stay unknown.
function M.attack(g,sprite,reader)
    local apr=stat(g,sprite,M.combat.apr)
    if apr>5 and apr<=10 then apr=apr-5.5 end
    local out={apr=apr>0 and apr or nil,
        thac0=stat(g,sprite,M.combat.thac0)-stat(g,sprite,M.combat.thac0Right)-stat(g,sprite,M.combat.hitBonus)}
    local equipment=sprite.m_equipment
    local record=itemAt(equipment,equipment and equipment.m_selectedWeapon,reader)
    local abilities=record and type(record.abilities)=='table' and record.abilities or {}
    local ability=abilities[number(equipment and equipment.m_selectedWeaponAbility)+1] or abilities[1]
    if type(ability)~='table' then return out end
    local damage=average(ability.dice,ability.sides)+number(ability.damageBonus)
    local magic=magical(g,record)
    if ability.attackType==4 then
        out.ranged=true
        for _,slot in ipairs(M.quiver) do
            local ammo=itemAt(equipment,slot,reader)
            local hit=ammo and type(ammo.abilities)=='table' and ammo.abilities[1]
            if type(hit)=='table' then
                damage=damage+average(hit.dice,hit.sides)+number(hit.damageBonus)
                magic=magic or magical(g,ammo)
                break
            end
        end
    elseif ability.attackType==2 then out.ranged=true end
    if out.ranged and number(ability.range)>0 then out.range=ability.range*targeting.rangeUnit end
    out.damage=math.max(0,damage+stat(g,sprite,M.combat.damageBonus)+stat(g,sprite,M.combat.damageRight))
    out.magical=magic
    return out
end

-- What protects a creature now, as plain values (combat-intent/defence.lua's guard): its
-- active effects classified as one record (classify(record), combat-intent/spells.lua) for
-- their roles, the engine's counts of Stoneskin skins and Mirror Images, the spells its effects
-- come from, and the spells opcode 206 keeps off it. Effects that end within M.expiring
-- seconds and delayed ones that have not started are left out.
function M.guard(g,sprite,tick,classify)
    local list,sources,recast={},{},{}
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
        mirror=type(mirror)=='number' and mirror or 0,sources=sources,recast=recast}
end

-- Adds what the defence slice weighs to a frame read with details: each friend's guard (false
-- if it could not be read), the weapons of enemies and allies, and whether each enemy sees
-- invisible creatures. A creature whose engine data fails keeps what it has; returns the count
-- of failures and the last one.
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

-- The living creatures lying in the area's back list that this creature sees: the area search
-- from where each one lies, with this creature's terrain table for line of sight, finds it.
-- consider(object) files a sprite as ally or enemy; seen holds the ids already filed.
local function lying(g,sprite,self,seen,consider)
    local area=sprite.m_pArea
    local back=area and area.m_lVertSortBack
    if not back then return end
    local ids={}
    g.EEex_Utility_IterateCPtrList(back,function(id) ids[#ids+1]=id end)
    local ok,terrain=pcall(function() return sprite:virtual_GetVisibleTerrainTable() end)
    if not ok then terrain=nil end
    local searches=0
    for _,id in ipairs(ids) do
        if searches>=M.maxLying then return end
        local object=not seen[id] and id~=self.id and g.EEex_GameObject_Get(id)
        if object and g.EEex_GameObject_IsSprite(object,false) and M.side(object.m_typeAI.m_EnemyAlly)~=nil then
            seen[id]=true
            searches=searches+1
            local found=false
            g.EEex_Area_ForAllOfTypeStringInRange(area,object.m_pos.x,object.m_pos.y,'[ANYONE]',M.sightRange,
                function(other) if other~=nil and other.m_id==self.id then found=true end end,1,0,terrain)
            if found then consider(object) end
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
    local frame={tick=tick,area=area and text(area.m_resref:get()) or '',self=self,enemies={},allies={}}
    if band(g,self.state,M.blind)~=0 then return frame end
    local seen={}
    local function consider(object)
        local other=M.side(object.m_typeAI.m_EnemyAlly)
        if other==nil then return end
        if not self.seeInvisible and band(g,g.EEex_Sprite_GetState(object),M.unseen)~=0 then return end
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
    lying(g,sprite,self,seen,consider)
    table.sort(frame.enemies,function(a,b) return a.id<b.id end)
    table.sort(frame.allies,function(a,b) return a.id<b.id end)
    return frame
end
return M
