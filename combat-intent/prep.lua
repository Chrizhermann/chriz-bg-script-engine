-- SCS's preparation, phase 1 (Christopher, 2026-10-28: the engine takes over how creatures
-- prepare, first exactly as SCS does, "außer eben, dass AOE spells wirklich als AOE spells gecastet
-- werden", and is rebuilt later). SCS is the blueprint ([src] mage/ssl and caster_shared, credit
-- DavidW). The installer marks SCS's own preparation blocks above the hook (tools/hook_rule.py:
-- prep_kind): its prebuffs, which it casts at once while instantprep is still 0 (prebuff: a helper of
-- the spell, then the memorized spell spent, or a free precast such as its Stoneskin), its
-- contingencies and sequencers (contingency), its chain contingencies (chain) and its first-round
-- casts at the creature itself (opener). Each block asks the engine first, naming its kind, the spell
-- it casts and the spell it takes from the spellbook as the script writes them, and a block that ran
-- tells the engine so. SCS's helpers keep the spell's own area: its Haste prebuff reaches the allies
-- near the caster as the spell does.
--
-- Phase 1: the engine chooses the first round of a creature it drives itself, so SCS's openers wait;
-- the rest runs as SCS has it unless the creature's orders hold it back (combat-intent/orders.lua):
-- prep=false holds all of it, noPrepIn holds all of it in the areas it names, and prepSkip names kinds
-- or spells to hold (the cast or the spent spell, in any case). An unknown kind runs as SCS has it.
-- Plain values only; nothing here touches the engine.
local M={}
M.KINDS={prebuff=true,contingency=true,chain=true,opener=true}

local function named(s,name) return type(name)=='string' and name~='' and s==name:upper() end

-- Whether the engine holds back a preparation block of kind that casts cast and spends spent ('' for
-- none), by the creature's orders (nil for none) and the area it stands in (nil or '' when unknown).
function M.holds(kind,cast,spent,orders,area)
    if not M.KINDS[kind] then return false end
    if kind=='opener' then return true end
    if type(orders)~='table' then return false end
    if orders.prep==false then return true end
    if type(area)=='string' and area~='' then
        local where=area:upper()
        for _,a in ipairs(type(orders.noPrepIn)=='table' and orders.noPrepIn or {}) do
            if named(where,a) then return true end
        end
    end
    for _,s in ipairs(type(orders.prepSkip)=='table' and orders.prepSkip or {}) do
        if type(s)=='string' then
            s=s:upper()
            if s==kind:upper() or named(s,cast) or named(s,spent) then return true end
        end
    end
    return false
end
return M
