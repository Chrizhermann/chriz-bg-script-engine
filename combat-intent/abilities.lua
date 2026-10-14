-- A creature's abilities and what they do: each memorized spell and innate ability at the
-- creature's caster level for it, and each ability of the items it carries, classified by
-- combat-intent/spells from the installed game's records. Input is the plain snapshot of
-- adapters/eeex/creature.lua and a lookup(kind, key) such as the EEex resource reader's;
-- nothing here touches the engine. A record the game lacks marks only that entry missing.
local spells=require('combat-intent.spells')
local M={}

local function fetch(lookup,kind,key)
    local ok,value=pcall(lookup,kind,key)
    if ok and type(value)=='table' then return value end
end

function M.profile(snapshot,lookup)
    local profile={resref=snapshot.resref,scriptName=snapshot.scriptName,level=snapshot.level,
        spells={},items={}}
    for _,s in ipairs(snapshot.spells or {}) do
        local row={list=s.list,resref=s.resref,level=s.level,memorized=s.memorized,
            ready=s.ready,usable=s.usable,casterLevel=s.casterLevel}
        local record=fetch(lookup,'SPL',s.resref)
        if record==nil then row.missing=true
        else
            local level=s.casterLevel or snapshot.level or 1
            row.ability=spells.abilityForLevel(record,level)
            if row.ability then row.effect=spells.classify(record,row.ability,lookup,{level=level}) end
        end
        profile.spells[#profile.spells+1]=row
    end
    for _,item in ipairs(snapshot.items or {}) do
        local row={slot=item.slot,resref=item.resref,abilities={}}
        local record=fetch(lookup,'ITM',item.resref)
        if record==nil then row.missing=true
        else
            row.itemType=record.itemType
            for i,ability in ipairs(record.abilities) do
                -- The item keeps a use count for each of its first three abilities: charges,
                -- or the stack size for potions and ammunition.
                row.abilities[i]={location=ability.location,charges=ability.charges,
                    depletion=ability.depletion,uses=type(item.uses)=='table' and item.uses[i] or nil,
                    effect=spells.classify(record,i,lookup,{level=snapshot.level})}
            end
        end
        profile.items[#profile.items+1]=row
    end
    return profile
end
return M
