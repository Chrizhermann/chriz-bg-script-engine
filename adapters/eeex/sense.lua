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
-- checks of the spells in question. Only plain values leave this module; no engine object is
-- kept.
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
for _,op in ipairs({83,101,102,197,198,199,200,201,202,203,204,205,206,207,223,226,227,228,259,318,324}) do
    M.protections[op]=true
end
-- Effects read per list at most, so a creature with a runaway effect list costs little.
M.maxEffects=1024
-- Searches from lying creatures per frame at most (each one is an area search).
M.maxLying=32

local function band(g,a,b) return g.EEex_BAnd(a,b) end
local function stat(g,sprite,n)
    local value=g.EEex_Sprite_GetStat(sprite,n)
    if type(value)=='number' then return value end
    return 0
end
local function text(value) return (value:match('^[^%z]*'):upper()) end

-- The plain facts every frame carries for one creature.
function M.actor(g,sprite)
    local state=g.EEex_Sprite_GetState(sprite)
    return {id=sprite.m_id,x=sprite.m_pos.x,y=sprite.m_pos.y,ea=sprite.m_typeAI.m_EnemyAlly,
        state=state,held=stat(g,sprite,M.stats.held),sanctuary=stat(g,sprite,M.stats.sanctuary),
        hp=sprite.m_baseStats.m_hitPoints,maxHp=stat(g,sprite,M.stats.maxHp),
        mr=stat(g,sprite,M.stats.mr),action=sprite.m_curAction.m_actionID}
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
