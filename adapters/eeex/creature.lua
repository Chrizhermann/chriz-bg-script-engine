-- What one creature carries right now, read from the engine: its memorized spells and innate
-- abilities (copies, ready copies, and whether the engine offers them on its spell buttons),
-- its items with their remaining uses, and its level. Only plain values leave this module;
-- combat-intent/abilities.lua turns the snapshot into a classified profile.
local M={}
-- Memorized spell lists on the sprite and how many spell levels each has.
M.lists={{'mage','m_memorizedSpellsMage',9},{'priest','m_memorizedSpellsPriest',7},
    {'innate','m_memorizedSpellsInnate',1}}
-- The engine's button lists for the spell and the innate-ability menus.
M.buttons={2,4}
-- Item slots in SLOTS.IDS order, which the engine's item array uses: 0-9 worn, 10 fist,
-- 11-14 ammo, 15-17 quick items, 18-33 backpack, 34 magic weapon, 35-38 weapons.
M.slots=39
-- LEVEL, LEVEL2 and LEVEL3 in STATS.IDS.
M.levelStats={34,68,69}

local function clean(value)
    return (value:match('^[^%z]*'):gsub('[a-z]',function(c) return string.char(c:byte()-32) end))
end

-- Spells the engine would let the creature cast now (a silenced caster's buttons are disabled).
local function usable(g,sprite)
    local found={}
    for _,kind in ipairs(M.buttons) do
        local list=sprite:GetQuickButtons(kind,false)
        if list~=nil then
            local ok,err=pcall(g.EEex_Utility_IterateCPtrList,list,function(button)
                if button.m_count>0 and (button.m_bDisabled==0 or button.m_bDisabled==false) then
                    found[clean(button.m_abilityId.m_res:get())]=true
                end
            end)
            g.EEex_Utility_FreeCPtrList(list)
            if not ok then error(err,0) end
        end
    end
    return found
end

local function memorized(g,sprite)
    local rows,index={},{}
    for _,list in ipairs(M.lists) do
        local name,field,levels=list[1],list[2],list[3]
        for level=0,levels-1 do
            g.EEex_Utility_IterateCPtrList(sprite[field]:getReference(level),function(spell)
                local resref=clean(spell.m_spellId:get())
                if resref=='' then return end
                local row=index[name..':'..resref]
                if not row then
                    row={list=name,resref=resref,level=level+1,memorized=0,ready=0}
                    index[name..':'..resref]=row;rows[#rows+1]=row
                end
                row.memorized=row.memorized+1
                if spell.m_flags%2==1 then row.ready=row.ready+1 end
            end)
        end
    end
    return rows
end

local function items(g,equipment)
    local rows={}
    local toPtr=rawget(g,'EEex_UDToPtr')
    for slot=0,M.slots-1 do
        local item=equipment.m_items:get(slot)
        if item~=nil and (type(toPtr)~='function' or toPtr(item)~=0) then
            local resref=clean(item.cResRef:get())
            if resref~='' then
                rows[#rows+1]={slot=slot,resref=resref,flags=item.m_flags,
                    uses={item.m_useCount1,item.m_useCount2,item.m_useCount3}}
            end
        end
    end
    return rows
end

local function read(g,sprite,resources)
    local level=0
    for _,stat in ipairs(M.levelStats) do
        local value=g.EEex_Sprite_GetStat(sprite,stat)
        if type(value)=='number' and value>level then level=value end
    end
    local equipment=sprite.m_equipment
    local snapshot={resref=clean(sprite.m_resref:get()),
        scriptName=sprite.m_scriptName:get():match('^[^%z]*'),
        level=level,spells=memorized(g,sprite),items=items(g,equipment),
        selectedWeapon=equipment.m_selectedWeapon,selectedAbility=equipment.m_selectedWeaponAbility}
    local found=usable(g,sprite)
    for _,row in ipairs(snapshot.spells) do
        row.usable=found[row.resref]==true
        -- The engine's level check reads the spell file, so ask only for spells the game has.
        if resources and resources.get('SPL',row.resref) then
            local ok,value=pcall(g.EEex_Sprite_GetCasterLevelForSpell,sprite,row.resref,false)
            if ok and type(value)=='number' then row.casterLevel=value end
        end
    end
    return snapshot
end

-- The creature's snapshot, or nil and the error. resources is an adapters.eeex.resources reader.
function M.read(g,sprite,resources)
    local ok,value=pcall(read,g,sprite,resources)
    if ok then return value end
    return nil,tostring(value)
end
return M
