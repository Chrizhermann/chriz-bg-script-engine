-- The designed encounters (docs/research/BOSS-01-bg1-early-encounters.md, designed one by one with
-- Christopher in story order, SCS as the blueprint, credit DavidW): what the fight's designer tells
-- each creature, by its creature file. The runtime passes the orders to the engine's choice
-- (combat-intent/orders.lua); worth decides whatever they leave open. Plain values; nothing here
-- touches the engine.
local M={}

-- A light preference for the protagonist (Christopher, 2026-11-03, for Tarnesh: a small, light
-- preference, not "always"): an attack on the protagonist counts this much more.
M.LIGHT=0.25

-- Orders by creature file, the resref in capitals.
M.ORDERS={
    -- Tarnesh, Friendly Arm Inn: hired to kill the protagonist (2026-11-03).
    TARNES={target='protagonist',bonus=M.LIGHT},
    -- Karlat, Red Sheaf, Beregost: carries the bounty notice on the protagonist (2026-11-04). A bounty
    -- hunter who finds his mark drinks his battle potion in sight of the party, then speaks at once
    -- ("solange er versucht sofort mit der Gruppe zu sprechen, ja"); from Hard, as every encounter's hard
    -- parts; below it he drinks in the fight as SCS's Karlat does. His talk is his own copy of the game's
    -- INITDLG (bgse/encounters.tpa).
    KARLAT={target='protagonist',bonus=M.LIGHT,talkPrep={'buff-potion'},talkFrom=4},
    -- Neira, Nashkel Inn: carries the later bounty notice on the protagonist (2026-11-04). From Hard
    -- she prepares in sight before she speaks: her own Aid and Protection From Good, cast at once and
    -- spent (SCS's own preparation adds Armor of Faith and her hammer). After the talk she opens like a
    -- priestess of Mask: a Potion of Invisibility, a moment's watch from invisibility, then Doom or Hold
    -- Person, and Hold Person after Doom; worth decides each step ("das muss alles nicht komplett starr
    -- sein"). Her book, WIS 15 and the potion come from the installer (bgse/encounters.tpa).
    NEIRA={target='protagonist',bonus=M.LIGHT,
        talkPrep={{cast='SPPR201',spend='SPPR201'},{cast='SPPR117',spend='SPPR117'}},talkFrom=4,
        opener={'POTN10',{watch=4},{'SPPR113','SPPR208'},'SPPR208'},openerFrom=4},
}

local function copy(v)
    if type(v)~='table' then return v end
    local c={}
    for k,x in pairs(v) do c[k]=copy(x) end
    return c
end
-- A copy of the orders, so that whoever takes them cannot change this book.
function M.orders() return copy(M.ORDERS) end
return M
