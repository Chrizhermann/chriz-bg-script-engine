-- What one creature perceives right now, as plain values: itself and the living creatures it
-- can see, found with EEex's area search (sight range and line of sight, as the NumCreature()
-- trigger counts them) and minus the invisible ones unless it sees invisible creatures. Sides
-- follow the engine's EA groups: for a creature on the evil side (EA 200 and up) the good side
-- (EA 2 to 30) are enemies and the evil side are allies. With details, each enemy also carries
-- its creature IDS values and the spell protections a script can test (SCS's triggers read the
-- same). Only plain values leave this module; no engine object is kept.
local M={}
-- A sprite's default visual range in EEex's area search.
M.sightRange=448
M.GOOD_CUTOFF,M.EVIL_CUTOFF=30,200
-- STATS.IDS: MAXHITPOINTS, RESISTMAGIC, HELD, SANCTUARY, SEEINVISIBLE, TRUE_SIGHT.
M.stats={maxHp=1,mr=18,held=58,sanctuary=63,seeInvisible=81,trueSight=118}
-- STATE_INVISIBLE and STATE_IMPROVEDINVISIBILITY; STATE_BLIND.
M.unseen,M.blind=0x400010,0x40000
-- Effect opcodes that protect against spells (combat-intent/targeting.lua matches them).
M.protections={}
for _,op in ipairs({83,101,102,197,198,199,200,201,202,203,204,205,206,207,223,226,227,228,259,318,324}) do
    M.protections[op]=true
end
-- Effects read per list at most, so a creature with a runaway effect list costs little.
M.maxEffects=1024

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

-- Creature IDS values and the spell protections in both effect lists.
function M.details(g,sprite,entry)
    local t=sprite.m_typeAI
    entry.ids={ea=t.m_EnemyAlly,general=t.m_General,race=t.m_Race,class=t.m_Class,
        specific=t.m_Specifics,gender=t.m_Gender,alignment=t.m_Alignment}
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

function M.side(ea)
    if type(ea)~='number' then return nil end
    if ea>=M.EVIL_CUTOFF then return 'evil' end
    if ea>=2 and ea<=M.GOOD_CUTOFF then return 'good' end
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
    -- Numeric flags: EEex's wrapper turns a Lua false into its default.
    g.EEex_Sprite_ForAllOfTypeStringInRange(sprite,'[ANYONE]',M.sightRange,function(object)
        if object==nil or seen[object.m_id] or object.m_id==self.id or not g.EEex_GameObject_IsSprite(object,false) then return end
        seen[object.m_id]=true
        local other=M.side(object.m_typeAI.m_EnemyAlly)
        if other==nil then return end
        if not self.seeInvisible and band(g,g.EEex_Sprite_GetState(object),M.unseen)~=0 then return end
        local entry=M.actor(g,object)
        if other==side then frame.allies[#frame.allies+1]=entry
        else
            if detailed then M.details(g,object,entry) end
            frame.enemies[#frame.enemies+1]=entry
        end
    end,1,0)
    table.sort(frame.enemies,function(a,b) return a.id<b.id end)
    table.sort(frame.allies,function(a,b) return a.id<b.id end)
    return frame
end
return M
