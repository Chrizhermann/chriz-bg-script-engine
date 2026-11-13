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
-- or spells, as SCS's blocks cast or spend them; noPrepIn holds back all of SCS's preparation when
-- the creature stands in one of the areas it names (combat-intent/prep.lua).
--
-- ruthless=true allows area offensive, debuff and removal spells even when allies stand in the blast
-- area; foes charmed by the caster's side and the caster itself are still protected.
--
-- leave=true lets the creature leave the fight for good as its SCS script has it (its vanishing exit
-- when badly hurt, bgse/lib/hook.tpa); by default the engine keeps it in the fight (Christopher,
-- 2026-10-28: nobody leaves for good, or almost nobody).
--
-- insight says how the creature judges its dispels against enemies' protections, whatever its wit
-- (combat-intent/removal.lua): 'exact' reads the caster levels of their effects, for a special boss
-- (Christopher, 2026-11-03: "Außer vielleicht ein Irenicus oder so"); 'estimate', 'rough' and
-- 'none' as a clever, a normal and a dull creature judge them.
--
-- talkPrep says what a talk-on-sight creature adds to its preparation before it speaks
-- (combat-intent/talk.lua), from the game's difficulty talkFrom (1 to 5, default 1) up: a spell it has
-- ready, cast at once, {cast=spell or a copy of it, spend=spell}, which spends that spell; or
-- 'buff-potion', its best potion that strengthens or protects it. prebuff adds the same at once when
-- the creature's fight begins in sight of an enemy, from prebuffFrom (1 to 5, default 1) up
-- (Christopher, 2026-11-12: Zeela's skeletons and AoE buff, Venkt's long Armor inside Tazok's tent).
--
-- opener says how the creature opens its fight, from the game's difficulty openerFrom (1 to 5, default
-- 1) up (Christopher, 2026-11-04, for Neira: "das muss alles nicht komplett starr sein"): steps in
-- order, each a spell or item (its file), a list of them (the best counts), or {watch=seconds}, a
-- moment's wait while the creature is invisible. At each decision the first step left with a choice
-- worth making (allowed, and worth more than it costs) is taken, and the steps before it are passed
-- over; a step not worth making now waits. The adapter keeps which step comes next (input.opener), for
-- at most openerSeconds from the creature's first decision in sight of an enemy.
--
-- companion names the creature that comes with this one when its cutscene asks (Christopher, 2026-11-04,
-- for Greywolf's archer): {weak=file, strong=file, strongFrom=difficulty 1 to 5}, the strong one from that
-- difficulty up, the weak one below (adapters/eeex/choice.lua, api:companion).
local targeting=require('combat-intent.targeting')
local M={}
M.bonus=1
-- How long an opener holds, in seconds from the creature's first decision with an enemy in sight, and
-- the longest watch it may hold.
M.openerSeconds=30
M.watchLimit=12
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
local function resref(v) return type(v)=='string' and #v>0 and #v<=8 and v:match('^[%w#_%-]+$')~=nil end
-- One thing a talk-on-sight creature adds before it speaks (talkPrep).
local function extra(v)
    if v=='buff-potion' then return true end
    if type(v)~='table' then return false end
    for k in pairs(v) do if k~='cast' and k~='spend' then return false end end
    return resref(v.cast) and resref(v.spend)
end
local function level(v) return number(v) and v>=1 and v<=5 and v==math.floor(v) end
local CONDITIONS={seen=true,hp75=true,hp50=true,emergency=true}
local function validSpellList(v,minN,maxN)
    if type(v)~='table' or #v<minN or #v>maxN then return false end
    for i,s in pairs(v) do if type(i)~='number' or not resref(s) then return false end end
    return true
end
local function validContingency(v)
    if v==false or resref(v) then return true end
    if type(v)~='table' or not resref(v.spell) then return false end
    for f,val in pairs(v) do
        if f=='condition' then if not CONDITIONS[val] then return false end
        elseif f~='spell' then return false end
    end
    return true
end
local function validChain(v)
    if v==false or validSpellList(v,1,3) then return true end
    if type(v)~='table' or not validSpellList(v.spells,1,3) then return false end
    for f,val in pairs(v) do
        if f=='condition' then if not CONDITIONS[val] then return false end
        elseif f~='spells' then return false end
    end
    return true
end
local function validSequencers(v)
    if v==false then return true end
    if type(v)~='table' or next(v)==nil then return false end
    local caps={minor=2,sequencer=3,trigger=3}
    for f,val in pairs(v) do
        local cap=caps[f]
        if not cap then return false end
        if val~=false and not validSpellList(val,2,cap) then return false end
    end
    return true
end
-- One step of an opener: a spell or item, a list of them, or {watch=seconds}.
local function step(v)
    if resref(v) then return true end
    if type(v)~='table' then return false end
    if v.watch~=nil then
        for k in pairs(v) do if k~='watch' then return false end end
        return number(v.watch) and v.watch>0 and v.watch<=M.watchLimit
    end
    if #v==0 then return false end
    for i,s in pairs(v) do if type(i)~='number' or not resref(s) then return false end end
    return true
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
        elseif k=='guard' or k=='hide' or k=='prep' or k=='doors' or k=='leave' or k=='ruthless' then
            if type(v)~='boolean' then return false,k end
        elseif k=='await' then
            if v~='guard' and v~='post' and v~='stand' then return false,k end
        elseif k=='insight' then
            if v~='exact' and v~='estimate' and v~='rough' and v~='none' then return false,k end
        elseif k=='call' then
            if v~='silent' and v~='pack' and v~='warband' and v~='map' then return false,k end
        elseif k=='prepSkip' then
            if type(v)~='table' or #v==0 then return false,k end
            for i,s in pairs(v) do
                if type(i)~='number' or type(s)~='string' or #s>64 or not s:match('^[%w#_%-]+$') then return false,k end
            end
        elseif k=='noPrepIn' then
            if type(v)~='table' or #v==0 then return false,k end
            for i,a in pairs(v) do if type(i)~='number' or not resref(a) then return false,k end end
        elseif k=='bonus' then
            if not number(v) or v<0 or v>100 then return false,'bonus' end
        elseif k=='talkPrep' or k=='prebuff' then
            if type(v)~='table' or #v==0 then return false,k end
            for i,e in pairs(v) do if type(i)~='number' or not extra(e) then return false,k end end
        elseif k=='opener' then
            if type(v)~='table' or #v==0 then return false,k end
            for i,s in pairs(v) do if type(i)~='number' or not step(s) then return false,k end end
        elseif k=='talkFrom' or k=='openerFrom' or k=='prebuffFrom' then
            if not level(v) then return false,k end
        elseif k=='companion' then
            if type(v)~='table' or not resref(v.weak) or not resref(v.strong) or not level(v.strongFrom) then return false,k end
            for f in pairs(v) do if f~='weak' and f~='strong' and f~='strongFrom' then return false,k end end
        elseif k=='contingency' then
            if not validContingency(v) then return false,k end
        elseif k=='chain' then
            if not validChain(v) then return false,k end
        elseif k=='sequencers' then
            if not validSequencers(v) then return false,k end
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

local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible
-- The step of the creature's opener to take now (input.opener: {steps, next, the number of the step
-- left first}): {option=the best of options a spell or item step offers that is worth more than it
-- costs, step=its number}, or {watch=seconds, step=its number} while the creature is invisible
-- (input.frame.self.state); the first step from next on that offers one. Nil when none does.
function M.openerStep(input,options)
    local o=type(input)=='table' and input.opener or nil
    if type(o)~='table' or type(o.steps)~='table' then return nil end
    local self=type(input.frame)=='table' and type(input.frame.self)=='table' and input.frame.self or nil
    local hidden=self~=nil and targeting.has(self.state,UNSEEN)
    for k=number(o.next) and math.max(1,math.floor(o.next)) or 1,#o.steps do
        local s=o.steps[k]
        if type(s)=='table' and s.watch~=nil then
            if hidden and number(s.watch) and s.watch>0 then return {watch=s.watch,step=k} end
        else
            local names={}
            for _,r in ipairs(type(s)=='table' and s or {s}) do if type(r)=='string' then names[r:upper()]=true end end
            local best
            for _,c in ipairs(type(options)=='table' and options or {}) do
                if type(c)=='table' and type(c.resref)=='string' and names[c.resref:upper()] and number(c.score) and
                    c.score>0 and (not best or c.score>best.score) then best=c end
            end
            if best then return {option=best,step=k} end
        end
    end
    return nil
end
return M
