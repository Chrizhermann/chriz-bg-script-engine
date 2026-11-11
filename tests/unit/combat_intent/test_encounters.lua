-- The designed encounters (combat-intent/encounters.lua): every creature's orders pass the orders'
-- check, the book hands out copies, and the light preference makes an attack on the protagonist
-- count a quarter more and nobody else's; the runtime hands the orders to the engine's choice.
-- Plain values; no game data.
local encounters=require('combat-intent.encounters')
local orders=require('combat-intent.orders')
local groups=0

-- 1. Each entry is a creature file of at most eight characters in capitals and passes the orders'
-- check; the bounty hunters have the light preference for the protagonist, never "always".
local count=0
for resref,o in pairs(encounters.ORDERS) do
    assert(type(resref)=='string' and #resref>0 and #resref<=8 and resref==resref:upper(),resref)
    assert(orders.check(o),resref)
    count=count+1
end
assert(count==19)
for _,resref in ipairs({'TARNES','KARLAT','NEIRA','LAMALH','ZEELA','TELKA','MANEIR','MOLKAR','DRAKAR','HALACA','MORVIN'}) do
    local o=encounters.ORDERS[resref]
    assert(o.target=='protagonist' and o.bonus==encounters.LIGHT and not o.always,resref)
end
assert(encounters.LIGHT>0 and encounters.LIGHT<1)
groups=groups+1

-- 2. Copies: what orders() hands out can be changed without changing the book.
local copy=encounters.orders()
assert(copy.TARNES~=encounters.ORDERS.TARNES and copy.TARNES.bonus==encounters.LIGHT)
copy.TARNES.bonus=5;copy.KARLAT=nil
assert(encounters.ORDERS.TARNES.bonus==encounters.LIGHT and encounters.ORDERS.KARLAT~=nil)
assert(encounters.orders().KARLAT.target=='protagonist')
groups=groups+1

-- 3. The light preference: with the protagonist in sight an attack on it counts 1.25 and on anyone
-- else 1; without the protagonist in sight the order names nobody, and a dead protagonist neither.
local hero={id=1,player=1,resref='CHARNAME',hp=12}
local friend={id=2,player=2,resref='IMOEN',hp=9}
local input={orders=encounters.orders().KARLAT,frame={enemies={hero,friend}}}
assert(orders.favour(input,hero)==1+encounters.LIGHT and orders.favour(input,friend)==1)
local t=orders.of(input)
assert(t and t.ids[1] and not t.ids[2] and t.always==false and t.target=='protagonist')
assert(orders.of({orders=encounters.orders().NEIRA,frame={enemies={friend}}})==nil)
assert(orders.of({orders=encounters.orders().TARNES,frame={enemies={{id=1,player=1,hp=0},friend}}})==nil)
groups=groups+1

-- 4. The runtime builds the engine's choice with the book's orders (the choice's constructor is
-- stood in for; the rest of the installation may fail against the bare globals).
local choices=require('adapters.eeex.choice')
local runtime=require('adapters.eeex.runtime')
local real,seen=choices.new,nil
choices.new=function(_,options) seen=options;error('stand-in') end
pcall(runtime.install,{},{director=false})
choices.new=real
assert(type(seen)=='table' and type(seen.orders)=='table')
assert(seen.orders.NEIRA.target=='protagonist' and seen.orders.NEIRA~=encounters.ORDERS.NEIRA)
assert(choices.orderBook(seen.orders).KARLAT.bonus==encounters.LIGHT)
groups=groups+1

-- 5. Neira (BOSS-01 sheet 4, Christopher 2026-11-04): from Hard she casts her own Aid and Protection
-- From Good at once before she speaks, each spending its spell; from Hard she opens with the Potion of
-- Invisibility, a watch, then Doom or Hold Person, then Hold Person. The book's nested lists are copied
-- too.
local neira=encounters.ORDERS.NEIRA
assert(neira.talkFrom==4 and neira.openerFrom==4 and #neira.talkPrep==2)
for _,e in ipairs(neira.talkPrep) do assert(e.cast==e.spend and (e.cast=='SPPR201' or e.cast=='SPPR117')) end
assert(neira.opener[1]=='POTN10' and neira.opener[2].watch>0 and neira.opener[3][1]=='SPPR113' and
    neira.opener[3][2]=='SPPR208' and neira.opener[4]=='SPPR208')
local mine=encounters.orders().NEIRA
mine.opener[1]='POTN11';mine.talkPrep[1].cast='X'
assert(neira.opener[1]=='POTN10' and neira.talkPrep[1].cast=='SPPR201')
-- Karlat (sheet 3): from Hard his best buff potion before he speaks.
local karlat=encounters.ORDERS.KARLAT
assert(#karlat.talkPrep==1 and karlat.talkPrep[1]=='buff-potion' and karlat.talkFrom==4 and karlat.opener==nil)
-- Greywolf (sheet 5): his archer Kestrel comes with him, the seasoned one from Hard, the apprentice below; no
-- orders of his own besides.
local greywolf=encounters.ORDERS.GREYWO
assert(greywolf.companion.weak=='BGSEKES1' and greywolf.companion.strong=='BGSEKES2' and greywolf.companion.strongFrom==4)
assert(greywolf.target==nil and greywolf.opener==nil and greywolf.talkPrep==nil)
groups=groups+1

-- 6. BOSS-02 encounters (Christopher, 2026-11-12): Mulahey's Prayer/Silence opener; Zeela's instant
-- Animate Dead + Bless prebuffs and the Telka/Maneira sniper vs stealth split; Drakar's Hold/DUHM opener;
-- Venkt's infiltrated-tent hold (BG1901/AR1901) with long Armor prebuff and Britik's guard post; Drasus's
-- pre-talk potion, Genthore's Oil of Speed, and Rezdan & Kysus's coordinated Hard+ openers.
local mulahe=encounters.ORDERS.MULAHE
assert(mulahe.openerFrom==4 and mulahe.opener[1][1]=='SPPR316' and mulahe.opener[1][2]=='SPPR211')
local zeela=encounters.ORDERS.ZEELA
assert(zeela.prebuffFrom==4 and zeela.prebuff[1].cast=='SPPR301' and zeela.prebuff[2].cast=='SPPR101')
assert(encounters.ORDERS.TELKA.hide==false and encounters.ORDERS.MANEIR.hide==true)
assert(encounters.ORDERS.LAMALH.openerFrom==4 and encounters.ORDERS.DRAKAR.openerFrom==4)
local venkt=encounters.ORDERS.VENKT
assert(venkt.noPrepIn[1]=='BG1901' and venkt.noPrepIn[2]=='AR1901')
assert(venkt.prebuffFrom==2 and venkt.prebuff[1].cast=='SPWI102' and venkt.openerFrom==4)
assert(encounters.ORDERS.BRITIK.guard==true)
assert(encounters.ORDERS.DRASUS.talkPrep[1]=='buff-potion' and encounters.ORDERS.DRASUS.talkFrom==4)
assert(encounters.ORDERS.GENTHO.opener[1]=='POTN14' and encounters.ORDERS.GENTHO.openerFrom==4)
assert(encounters.ORDERS.REZDAN.opener[1][1]=='SPWI508' and encounters.ORDERS.REZDAN.openerFrom==4)
assert(encounters.ORDERS.KYSUS.opener[1][3]=='SPWI504' and encounters.ORDERS.KYSUS.opener[2]=='DW#MS0')
groups=groups+1

return groups
