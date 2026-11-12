-- SCS's preparation, phase 2a (Christopher, 2026-10-28 and 2026-11-12: the engine takes over how
-- creatures prepare; Phase 2a runs long all-day prebuffs out of sight and short combat-start
-- prebuffs natively with zero delay in combat-intent/prebuff.lua, while Phase 2b will take over
-- contingencies, spell sequencers and triggers next). SCS is the blueprint ([src] mage/ssl and
-- caster_shared, credit DavidW). The installer marks SCS's own preparation blocks above the hook
-- (tools/hook_rule.py: prep_kind): its prebuffs (prebuff), its contingencies and sequencers
-- (contingency), its chain contingencies (chain) and its first-round casts at the creature itself
-- (opener). Each block asks the engine first, naming its kind, the spell it casts and the spell it
-- takes from the spellbook as the script writes them, and a block that ran tells the engine so.
--
-- Phase 2a: the engine chooses the first round of a creature it drives itself (opener held), and
-- when nativePrebuffs is on it holds SCS's prebuff blocks as well because the engine applies
-- long-duration and combat-start prebuffs natively; contingencies and chain contingencies continue
-- to run as SCS built them until Phase 2b unless the creature's orders hold them back
-- (combat-intent/orders.lua: prep=false, noPrepIn, prepSkip). Plain values only; nothing here
-- touches the engine.
local M={}
M.KINDS={prebuff=true,contingency=true,chain=true,opener=true}

local function named(s,name) return type(name)=='string' and name~='' and s==name:upper() end

-- Whether the engine holds back a preparation block of kind that casts cast and spends spent ('' for
-- none), by the creature's orders (nil for none), the area it stands in (nil or '' when unknown),
-- and whether native prebuffs are active (nativePrebuffs==true).
function M.holds(kind,cast,spent,orders,area,nativePrebuffs)
    if not M.KINDS[kind] then return false end
    if kind=='opener' then return true end
    if kind=='prebuff' and nativePrebuffs==true then return true end
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
