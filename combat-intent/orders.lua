-- Orders (Christopher, 2026-10-25): what a fight's designer tells one creature to do, over the
-- engine's own weighing. For target choice "und bei solchen ähnlichen Entscheidungen, die KI treffen
-- muss, immer auch einen Override", for example "wenn ein bestimmter Gegner immer auf den
-- Main-Charakter gehen soll". Worth still decides whatever an order leaves open. The adapter finds a
-- creature's orders by its creature file (input.orders); the enemies in its frame carry their own
-- creature file (resref) and, for the party, their place in it (player: 1 for Player1, the
-- protagonist, up to 6, as the game's Player1 to Player6 count them, by joining). Plain values;
-- nothing here touches the engine.
--
-- A target order names whom (target): 'protagonist', 'player1' to 'player6' or a creature file, or a
-- list of them, of which the first that names an enemy the creature sees counts. always=true keeps
-- the creature's attacks on that enemy while it can attack it at all; otherwise the enemy is
-- preferred, as the group's focus is: what an attack does to it counts bonus (default 1) more. A
-- bonus given with always counts as well.
--
-- guard=true keeps the creature near the spot where its fight began while it searches for enemies it
-- cannot see (combat-intent/search.lua); guard=false lets it search like anyone, also as its
-- group's boss, which guards by default.
--
-- await says what the creature does about a foe out of play (one its side charmed, one in a maze)
-- while it sees no enemy, whatever its wit (combat-intent/search.lua): 'guard' its spot from a
-- distance, wait at its 'post' or 'stand' where it is.
--
-- hide=true has a thief hide in shadows whenever it sees no enemy, whatever its wit; hide=false never
-- (combat-intent/stealth.lua).
--
-- doors=true lets the creature open doors while it searches, whatever its kind or wit; doors=false
-- never (combat-intent/doors.lua).
--
-- prep=false holds back all of SCS's preparation for the creature (its prebuffs, contingencies and
-- chain contingencies); prepSkip holds back what it names: kinds ('prebuff', 'contingency', 'chain')
-- or spells, as SCS's blocks cast or spend them (combat-intent/prep.lua).
local targeting=require('combat-intent.targeting')
local M={}
M.bonus=1
-- The decisions an order to always attack an enemy keeps to it: attacks, touch charges, strikes,
-- weapon attacks, jumps into the fight (teleport) and protection removal. Defences, heals, cures,
-- summons, openers, ways out of a zone and waits stay free.
M.ATTACKS={damage=true,disable=true,removal=true,touch=true,strike=true,weapon=true,teleport=true}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function selector(v)
    if type(v)~='string' then return false end
    local w=v:lower()
    return w=='protagonist' or w:match('^player[1-6]$')~=nil or (#v<=8 and v:match('^[%w#_%-]+$')~=nil)
end

-- Whether o is a creature's orders as the adapter takes them, else false and the bad field.
function M.check(o)
    if type(o)~='table' then return false,'orders' end
    for k,v in pairs(o) do
        if k=='target' then
            if type(v)=='table' then
                if #v==0 then return false,'target' end
                for i,s in pairs(v) do if type(i)~='number' or not selector(s) then return false,'target' end end
            elseif not selector(v) then return false,'target' end
        elseif k=='always' then
            if type(v)~='boolean' then return false,'always' end
        elseif k=='guard' or k=='hide' or k=='prep' or k=='doors' then
            if type(v)~='boolean' then return false,k end
        elseif k=='await' then
            if v~='guard' and v~='post' and v~='stand' then return false,k end
        elseif k=='prepSkip' then
            if type(v)~='table' or #v==0 then return false,k end
            for i,s in pairs(v) do
                if type(i)~='number' or type(s)~='string' or #s>64 or not s:match('^[%w#_%-]+$') then return false,k end
            end
        elseif k=='bonus' then
            if not number(v) or v<0 or v>100 then return false,'bonus' end
        else return false,tostring(k) end
    end
    return true
end

-- Whether e is the creature selector s names.
local function names(e,s)
    local w=s:lower()
    if w=='protagonist' then return e.player==1 end
    local n=w:match('^player([1-6])$')
    if n then return e.player==tonumber(n) end
    return type(e.resref)=='string' and e.resref:upper()==s:upper()
end

-- The creature's target order at this decision: {ids (the enemies it names, as a set), always,
-- bonus, target (the selector that named them)}, or nil without one or when it names no living
-- enemy the creature sees.
function M.of(input)
    local o=type(input)=='table' and input.orders or nil
    if type(o)~='table' or o.target==nil or not M.check(o) then return nil end
    local frame=input.frame
    local enemies=type(frame)=='table' and type(frame.enemies)=='table' and frame.enemies or {}
    for _,s in ipairs(type(o.target)=='table' and o.target or {o.target}) do
        local ids,any={},false
        for _,e in ipairs(enemies) do
            if type(e)=='table' and e.id~=nil and targeting.alive(e) and names(e,s) then ids[e.id]=true;any=true end
        end
        if any then
            return {ids=ids,always=o.always==true,bonus=number(o.bonus) and o.bonus or (o.always and 0 or M.bonus),target=s}
        end
    end
    return nil
end
-- The creature's target order: input.ordered once the choice has worked it out (false for none),
-- else M.of's answer.
local function order(input)
    local t=input.ordered
    if t==nil then t=M.of(input) end
    return type(t)=='table' and t or nil
end

-- What an attack's worth on e counts by the creature's orders: 1 and the bonus on an enemy its
-- target order names, else 1.
function M.favour(input,e)
    local t=order(input)
    if not t or type(e)~='table' or not t.ids[e.id] then return 1 end
    return 1+t.bonus
end

-- Whether option o reaches an enemy of ids: aimed at it or hitting it.
local function reaches(o,ids)
    if o.target~=nil and ids[o.target] then return true end
    for _,h in ipairs(type(o.hits)=='table' and o.hits or {}) do if ids[h] then return true end end
    return false
end
-- Whether the creature's orders name the enemy option o reaches (an attack only).
function M.on(input,o)
    local t=order(input)
    return t~=nil and type(o)=='table' and M.ATTACKS[o.kind]==true and reaches(o,t.ids)
end
-- What an order to always attack an enemy leaves of the options and the weapon attacks: the attacks
-- on that enemy alone when one of them reaches it, else everything; and whether it left any out.
function M.keep(input,options,swings)
    local t=order(input)
    if not t or not t.always then return options,swings,false end
    local any=false
    for _,list in ipairs({options,swings}) do
        for _,o in ipairs(list) do
            if M.ATTACKS[o.kind] and reaches(o,t.ids) then any=true;break end
        end
    end
    if not any then return options,swings,false end
    local cut=false
    local function left(list)
        local out={}
        for _,o in ipairs(list) do
            if M.ATTACKS[o.kind] and not reaches(o,t.ids) then cut=true else out[#out+1]=o end
        end
        return out
    end
    local a,b=left(options),left(swings)
    return a,b,cut
end
return M
