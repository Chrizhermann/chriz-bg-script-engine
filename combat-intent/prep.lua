-- SCS's preparation, phases 2a and 2b (Christopher, 2026-10-28 and 2026-11-12: the engine takes
-- over how creatures prepare; Phase 2a runs long all-day prebuffs out of sight and short
-- combat-start prebuffs natively with zero delay in combat-intent/prebuff.lua, and Phase 2b runs
-- contingencies, chain contingencies, sequencers and spell triggers natively in
-- combat-intent/contingency.lua). SCS is the blueprint ([src] mage/ssl and
-- caster_shared, credit DavidW). The installer marks SCS's own preparation blocks above the hook
-- (tools/hook_rule.py: prep_kind): its prebuffs (prebuff), its contingencies and sequencers
-- (contingency), its chain contingencies (chain) and its first-round casts at the creature itself
-- (opener). Each block asks the engine first, naming its kind, the spell it casts and the spell it
-- takes from the spellbook as the script writes them, and a block that ran tells the engine so.
--
-- Phase 2a + 2b: the engine chooses the first round of a creature it drives itself (opener held),
-- holds SCS's prebuff blocks when nativePrebuffs is on, and holds SCS's contingency and chain
-- blocks when nativeContingencies is on; disabling either switch falls back cleanly to SCS's own
-- blocks, unless the creature's orders hold them back (combat-intent/orders.lua: prep=false,
-- noPrepIn, prepSkip). Plain values only; nothing here touches the engine.
local M={}
M.KINDS={prebuff=true,contingency=true,chain=true,opener=true}

local function named(s,name) return type(name)=='string' and name~='' and s==name:upper() end

-- Whether the engine holds back a preparation block of kind that casts cast and spends spent ('' for
-- none), by the creature's orders (nil for none), the area it stands in (nil or '' when unknown),
-- nativePrebuffs==true, and nativeContingencies==true.
function M.holds(kind,cast,spent,orders,area,nativePrebuffs,nativeContingencies)
    if not M.KINDS[kind] then return false end
    if kind=='opener' then return true end
    if kind=='prebuff' and nativePrebuffs==true then return true end
    if (kind=='contingency' or kind=='chain') and nativeContingencies==true then return true end
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
