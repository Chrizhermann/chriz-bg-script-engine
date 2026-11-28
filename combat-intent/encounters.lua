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
    -- Greywolf, Prism's quest (2026-11-04): his archer Kestrel comes in with him, very weak on Core and
    -- below (a young apprentice), clearly stronger above (a seasoned partner); both creature files come from
    -- the installer (bgse/encounters.tpa). Greywolf himself stays as SCS has him.
    GREYWO={companion={weak='BGSEKES1',strong='BGSEKES2',strongFrom=4}},
    -- Mulahey, Nashkel Mines (BOSS-02, 2026-11-12): WIS 17 and Prayer in his 3rd-level book come from the
    -- installer, together with the staggered second reinforcement wave from the northern passage on Hard+.
    -- From Hard he opens with Prayer on himself and his guards/skeletons, or enemy-only Silence by worth.
    MULAHE={opener={{'SPPR316','SPPR211'}},openerFrom=4},
    -- Lamalha's assassin party, Valley of the Tombs exit (BOSS-02, 2026-11-12): bounty hunters sent after
    -- the protagonist. From Hard, Zeela's Animate Dead skeletons stand beside her right as the fight starts
    -- and her AoE Bless catches the skeletons too; Lamalha prepares before speaking (BGSELAMA) and opens
    -- with Silence or Hold Person. Telka stays out of stealth as the dedicated elemental-arrow sniper, while
    -- Maneira handles stealth pressure and Darts of Wounding.
    LAMALH={target='protagonist',bonus=M.LIGHT,opener={{'SPPR211','SPPR208'}},openerFrom=4},
    ZEELA={target='protagonist',bonus=M.LIGHT,
        prebuff={{cast='SPPR301',spend='SPPR301'},{cast='SPPR101',spend='SPPR101'}},prebuffFrom=4},
    TELKA={target='protagonist',bonus=M.LIGHT,hide=false},
    MANEIR={target='protagonist',bonus=M.LIGHT,hide=true},
    -- Molkar's bounty-hunter party (BOSS-02, 2026-11-12): kept close to SCS; Molkar's talk waits while the
    -- group prepares (BGSEMOLK), Drakar gets a slotted Potion of Heroism in the installer and opens from
    -- Hard with Hold Person for the three melee fighters or Draw Upon Holy Might.
    MOLKAR={target='protagonist',bonus=M.LIGHT},
    DRAKAR={target='protagonist',bonus=M.LIGHT,opener={{'SPPR208','SPPR214'}},openerFrom=4},
    HALACA={target='protagonist',bonus=M.LIGHT},
    MORVIN={target='protagonist',bonus=M.LIGHT},
    -- Bandit Camp & Tazok's tent (BOSS-02, 2026-11-12): inside the infiltrated tent (BG1901/AR1901) nobody
    -- expects an attack, so Venkt holds back SCS's short combat prebuffs and wears only his long Armor
    -- (SPWI102); when the outdoor camp alarm brings him out into BG1900 two rounds in, he steps out fully
    -- prepared. From Hard he opens with Remove Magic or Monster Summoning I; Britik guards the tent post.
    VENKT={noPrepIn={'BG1901','AR1901'},prebuff={{cast='SPWI102',spend='SPWI102'}},prebuffFrom=2,
        opener={{'SPWI302','SPWI309'}},openerFrom=4},
    BRITIK={guard=true},
    -- Drasus, Genthore, Kysus & Rezdan, Cloakwood Mine entrance (BOSS-02, 2026-11-12): full Iron Throne
    -- guard prebuffs stay. From Hard, Drasus drinks his battle potion before speaking (BGSEDRAS), Genthore
    -- drinks his Oil of Speed on round 1, Rezdan opens with Chaos or Glitterdust, and Kysus opens with
    -- Remove Magic, Slow or Monster Summoning III (never gambling round 1 on the 3-round Lesser Elemental
    -- contest) followed by his twin Acid Arrow Minor Sequencer.
    DRASUS={talkPrep={'buff-potion'},talkFrom=4},
    GENTHO={opener={'POTN14'},openerFrom=4},
    REZDAN={opener={{'SPWI508','SPWI224'}},openerFrom=4},
    KYSUS={opener={{'SPWI302','SPWI312','SPWI504'},'DW#MS0'},openerFrom=4},
    -- Natasha, Cloakwood Mines L3 (BOSS-03, 2026-11-13): ruthless Invoker who fires AoE spells even when
    -- prison guards stand in the blast, backed by a twin Snilloc's Snowball Swarm Minor Sequencer.
    NATASH={ruthless=true,sequencers={minor={'SPWI204','SPWI204'}}},
    -- Oni / Ogre Mage, Cloakwood Mines L3 (BOSS-03, 2026-11-13): opens instantly hasted on every difficulty.
    OGREMA03={talkPrep={{cast='SPWI305',spend='SPWI305'}},talkFrom=1,
        prebuff={{cast='SPWI305',spend='SPWI305'}},prebuffFrom=1},
    -- Davaeorn, Cloakwood Mines L4 (BOSS-03, 2026-11-13): from Hard, enters combat with his Lesser Fire
    -- Elemental already bound (BGSE516P, no 3-round self-paralysis; prebuff only so WIZELSUM sees ENEMY).
    DAVAEO={prebuff={{cast='BGSE516P',spend='SPWI516'}},prebuffFrom=4},
    -- Iron Throne top floor, Baldur's Gate (BOSS-03, 2026-11-13): from Core, Alai hastes the team and Diyab
    -- lays down Protection from Evil 10' Radius and Defensive Harmony.
    ALAI={talkPrep={{cast='SPWI305',spend='SPWI305'}},talkFrom=3,
        prebuff={{cast='SPWI305',spend='SPWI305'}},prebuffFrom=3},
    DIYAB={talkPrep={{cast='SPPR408',spend='SPPR408'},{cast='SPPR406',spend='SPPR406'}},talkFrom=3,
        prebuff={{cast='SPPR408',spend='SPPR408'},{cast='SPPR406',spend='SPPR406'}},prebuffFrom=3},
}

-- Boss arena exit travel-region names keyed by area resref (BG1-in-EET BG* and standalone AR*).
M.ARENA_LOCKS={
    BG5405={'Door5404'},
    AR5405={'Door5404'},
    BG2101={'Door2100'},
    AR2101={'Door2100'},
    BG1803={'Door1802','Door1801'},
    AR1803={'Door1802','Door1801'},
    BG0615={'Door0614','Door0621'},
    AR0615={'Door0614','Door0621'},
}

local function copy(v)
    if type(v)~='table' then return v end
    local c={}
    for k,x in pairs(v) do c[k]=copy(x) end
    return c
end
-- A copy of the orders, so that whoever takes them cannot change this book.
function M.orders() return copy(M.ORDERS) end
-- A copy of the boss arena exit lock table.
function M.arenaLocks() return copy(M.ARENA_LOCKS) end
return M
