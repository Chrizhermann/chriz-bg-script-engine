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
    -- Karlat, Red Sheaf, Beregost: carries the bounty notice on the protagonist (2026-11-04).
    KARLAT={target='protagonist',bonus=M.LIGHT},
    -- Neira, Nashkel Inn: carries the later bounty notice on the protagonist (2026-11-04).
    NEIRA={target='protagonist',bonus=M.LIGHT},
}

-- A copy of the orders, so that whoever takes them cannot change this book.
function M.orders()
    local copy={}
    for resref,o in pairs(M.ORDERS) do
        local c={}
        for k,v in pairs(o) do c[k]=v end
        copy[resref]=c
    end
    return copy
end
return M
