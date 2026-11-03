-- The designed encounters (combat-intent/encounters.lua): every creature's orders pass the orders'
-- check, the book hands out copies, and the light preference makes an attack on the protagonist
-- count a quarter more and nobody else's; the runtime hands the orders to the engine's choice.
-- Plain values; no game data.
local encounters=require('combat-intent.encounters')
local orders=require('combat-intent.orders')
local groups=0

-- 1. Each entry is a creature file of at most eight characters in capitals and passes the orders'
-- check; Tarnesh, Karlat and Neira have the light preference for the protagonist, never "always".
local count=0
for resref,o in pairs(encounters.ORDERS) do
    assert(type(resref)=='string' and #resref>0 and #resref<=8 and resref==resref:upper(),resref)
    assert(orders.check(o),resref)
    count=count+1
end
assert(count==3)
for _,resref in ipairs({'TARNES','KARLAT','NEIRA'}) do
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
groups=groups+1

return groups
