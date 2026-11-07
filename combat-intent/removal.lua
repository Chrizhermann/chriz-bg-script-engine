-- The engine's own protection removal for one caster (step 3, D3d; Christopher, 2026-10-20: "Mach
-- alles"; on improving on SCS: "Wir können uns da gerne an SCS orientieren, aber ich bin auch offen
-- für eine bessere Implementierung"). SCS is the blueprint ([src] mage/ssl/combatblocks/
-- attacks_on_pc_defences.ssl, attack_antimagic.ssl, first_dispel.ssl, remove_magic.ssl,
-- kill_summons.ssl): its mages breach an enemy whose protections from weapons, damage or effects or
-- whose Stoneskin keep their side out; take down Spell Shield, turnings and Spell Immunity with
-- Secret Word, Spell Thrust, Ruby Ray, Spell Strike, Pierce Magic or Warding Whip; lower magic
-- resistance from 40 up; dispel enemies with protections or enhancements, but not while their side
-- holds an enemy disabled or under Malison, which the dispel would free; and kill summoned
-- creatures with Death Spell. Fixed timers of 12 to 18 seconds keep such casts apart.
--
-- Here worth decides instead, on the attack's scale, as combat-intent/defence.lua weighs
-- protections, seen from the other side:
-- - what the removal opens for the caster's whole side: the share of the enemy, the kill bonus and
--   the rounds out of the fight that the side's weapons and spells take from it over the horizon
--   once the protections are gone, less what they take with them (defence.loss under the side's
--   pressure on that enemy, M.pressure: the friends as attackers, as combat-intent/threat.lua
--   pictures enemies);
-- - the share of a friend the enemy's own buffs (haste, extra attacks, bonuses) would take with its
--   weapon, as defence.offense weighs a buff;
-- - less what the removal takes from the caster's side: the conditions its side holds the enemy in
--   (as freeing a friend of them is worth, combat-intent/care.lua) and the harm the enemy's weapon
--   gets back once its slowing and penalties are gone;
-- - a summoned enemy unsummoned or destroyed counts as a kill.
-- All of it as likely as the removal lands: magic resistance unless all its effects ignore it, the
-- saving throw, the effect's own chance. A spell protection by level stops a removal only by the
-- power of what it delivers (power 0 passes; combat-intent/targeting.lua).
--
-- Freeing (Christopher, 2026-10-29: clever creatures free a member of their group whom the party
-- charmed, with Dispel Magic when they have it; "klingt gut"): a creature among the enemies in the
-- charmed state is one the other side charmed, since a charm puts its creature on its charmer's
-- side (lab batch J, run 3: the party's charms put the group's assassin, kensai and archer on its
-- side). A removal that takes every charm on it frees it: it goes back to its own side, the
-- caster's group when it came from there (a charm leaves its creature's allegiance as it was or
-- sets it against the charmer; IESDP, opcode 5). That is worth what the same charm on an enemy is
-- (harm.DISABLE) for as long as the charm would still hold it, as likely as the removal takes every
-- charm; its other effects count neither way then (they go with a creature that comes back), and as
-- on any enemy as far as it stays charmed. Seeing it is a tactic: a clever creature always, a normal
-- one when it notices, a dull one never (combat-intent/choice.lua, M.tactical); one that does not
-- weighs the removal on it as on any enemy.
--
-- Insight (Christopher, 2026-11-03: a clever mage judges from what it can see whether it beats an
-- enemy's magic, a normal one roughly, a dull one casts without regard to levels; "es zu 100% wissen
-- wäre blöd. Außer vielleicht ein Irenicus oder so"): a dispel's chance at each ward is what the
-- caster believes, not the effect's caster level, which only a creature its designer grants it reads
-- (orders insight='exact', combat-intent/orders.lua). A clever creature ('estimate') guesses the
-- level of whoever cast the protection: the enemy itself when it casts spells, else the strongest
-- caster on its side in view, and at least what a spell of that level takes (M.floor). A normal one
-- ('rough') takes the enemy's own level and is less sure of it (M.spread). A dull one ('none')
-- counts the base chance, as if the levels were equal. A guess is a spread of levels around it, and
-- what the group has seen dispels do to the same spell's effects on that enemy narrows it
-- (input.dispels, kept by adapters/eeex/choice.lua with M.learn): effects that stayed make a higher
-- level likelier, effects that went a lower one; a normal creature takes in half as much. An area
-- dispel is worth casting once at enemies no dispel has been tried at ("Mit einem dispelling screen
-- wäre es halt auch gut generell ein mal zu casten, damit es AOE auf mehrere weg ist. Egal ob es
-- dispellen könnte oder nicht"): until then each of their wards counts at least the base chance.
--
-- Screens (Christopher, 2026-11-04): immunity to dispel (101 against 58) stops only the dispel;
-- immunity to a delivered spell (206) stops only that branch. Removals by type, school or opcode
-- still work, including a dispel's separate removal of the screen itself. A clever caster reads
-- the screen, a normal one when it sees the tactic, a dull one never; insight='exact' always does.
-- The group still learns from a wasted dispel as above. No spell name or secondary type is fixed.
-- Taking a screen down also earns M.screenFollow of what the best removal still ready after this
-- cast would open with it gone, one step only. The first cast's own opening counts as before.
-- A release (sequencer, contingency or trigger) with a dispel gets M.sequencerShare of its removal
-- worth: it is allowed, but rarely worth spending. Both shares are named for tuning in the lab.
--
-- What a removal takes follows the engine (IESDP):
-- - a dispel (opcode 58) takes each effect that can be dispelled (resistance field bit 0), with a
--   chance of 49% plus 5% a level the dispel is above the effect's caster level, less 10% a level
--   below, 99% at most (always for type 0);
-- - a removal by school or secondary type (220, 221) takes, for each effect of that type up to its
--   power level, every effect of the same spell or item (source) up to that power, but those that
--   last after death; the single kind (229, 230) takes the matching effects of the first spell and
--   of the first item with a matching effect above power 0;
-- - a removal by opcode (337) takes those effects (with a matching parameter 2 unless it names -1);
-- - a purge of invisibility takes the invisible state.
-- Stoneskin skins and Mirror Images go with the spell that gave them. What a removal opens on an
-- enemy the creature's orders name counts more (combat-intent/orders.lua). Inputs are plain values:
-- each enemy's wards (adapters/eeex/sense.lua, M.wards) and the frame. Nothing here touches the
-- engine.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local defence=require('combat-intent.defence')
local care=require('combat-intent.care')
local ids=require('combat-intent.ids')
local spells=require('combat-intent.spells')
local weapons=require('combat-intent.weapons')
local orders=require('combat-intent.orders')
local harm=require('combat-intent.harm')
local M={}
M.ROUND=6
-- A speed point of casting time is 10 game ticks (as for defences).
M.speedSeconds=10/15
M.costPerLevel=0.03
M.screenFollow=0.5
M.sequencerShare=0.1
-- Allies keep this much room beyond an area's edge (as for attacks).
M.allyMargin=32
-- GENDER.IDS: summoned, illusionary and demonic summoned creatures.
M.SUMMONED={[6]=true,[7]=true,[9]=true}
-- Opcodes of Stoneskin's skins, Mirror Images and invisibility, which the engine counts apart.
M.SKINS={[218]=true,[314]=true}
M.MIRROR={[119]=true,[159]=true}
M.INVISIBLE={[20]=true}
-- Opcode 58 (IESDP): 49% base, 5% a level above the effect's caster level, 10% a level below, 99%
-- at most.
M.dispelBase,M.dispelAbove,M.dispelBelow,M.dispelMax=0.49,0.05,0.10,0.99
-- Insight by wit and the insights orders may give (see the top); the spread of each guess in
-- levels (a standard deviation; a belief reaches M.tails spreads either way); how much of what it
-- has seen each takes in.
M.INSIGHT={clever='estimate',normal='rough',dull='none'}
M.INSIGHTS={exact=true,estimate=true,rough=true,none=true}
M.spread={estimate=2,rough=4}
M.tails=3
M.learnWeight={estimate=1,rough=0.5}
-- The kinds of removal weighed here; clouds (zones), sanctuary, nondetection and replacing a
-- creature are not.
M.KINDS={dispel=true,schools=true,secondaries=true,opcodes=true,invisibility=true,summons=true,destroy=true}
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible
local FRIENDS={self=true,party=true,everyone=true,casterGroup=true}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- The share of a spell slot's cost that counts now (combat-intent/choice.lua, M.slotShare).
local function slots(input) return number(input.slots) and input.slots or 1 end
local function list(t) return type(t)=='table' and t or {} end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function range(spell) return number(spell.range) and spell.range*targeting.rangeUnit or 0 end
local function summoned(e) return type(e.ids)=='table' and M.SUMMONED[e.ids.gender]==true end
-- Whether the caster sees a tactic's chance in this decision, as combat-intent/choice.lua's
-- M.tactical has it: input.tactical once the decision has drawn it, else a chance of a half or more.
local function tactical(input)
    if input.tactical~=nil then return input.tactical==true end
    local p=type(input.mind)=='table' and number(input.mind.tactics) and input.mind.tactics or 1
    return p>=0.5
end

-- The removal role of a spell the engine weighs, or nil and why not: none, an unread spell, only
-- kinds weighed elsewhere, one that reaches no enemy, harms the caster's side or has a shape the
-- engine cannot place.
function M.removal(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    local r=spell.roles.removal
    if type(r)~='table' or type(r.who)~='table' or next(r.who)==nil then return nil,'no-removal' end
    local weighed=false
    for k in pairs(list(r.kinds)) do if M.KINDS[k] then weighed=true end end
    if not weighed then return nil,'other-removal' end
    if not (r.who.target or r.who.area) then return nil,'no-enemy' end
    if spell.partial then return nil,'partial' end
    local a=type(spell.area)=='table' and spell.area or nil
    if r.who.area and not r.who.target and a and a.filter=='allies' then return nil,'allies-area' end
    for _,name in ipairs({'damage','disable','debuff'}) do
        local x=spell.roles[name]
        if type(x)=='table' and type(x.who)=='table' then
            for who in pairs(x.who) do if FRIENDS[who] then return nil,'harms-friends' end end
        end
    end
    if spell.projectileUnknown and not targeting.builtinSingle[spell.projectile] then return nil,'unknown-projectile' end
    if a and (a.cone or a.line or a.rectangle or not (number(a.radius) and a.radius>0)) then return nil,'unknown-shape' end
    return r
end

-- The chance of a dispel of the given level against an effect of caster level of.
function M.dispelChance(level,of)
    if not number(level) then return 0 end
    of=number(of) and of or level
    local p
    if level>=of then p=M.dispelBase+M.dispelAbove*(level-of) else p=M.dispelBase-M.dispelBelow*(of-level) end
    return clamp(p,0,M.dispelMax)
end
-- The level removal r's dispel works at when cast at caster level level: its own for a fixed one,
-- else the caster's; nil without a dispel that rolls.
function M.dispelAt(r,level)
    if type(r)~='table' or not list(r.kinds).dispel or type(r.dispel)~='table' or r.dispel.mode=='always' then return nil end
    if r.dispel.mode=='fixed' then return r.dispel.level end
    return level
end

-- The insight the caster weighs a dispel's chance with (see the top): its orders', else its wit's.
function M.insight(input)
    local o=type(input)=='table' and type(input.orders)=='table' and input.orders.insight or nil
    if o~=nil and M.INSIGHTS[o] then return o end
    local m=type(input)=='table' and input.mind or nil
    return type(m)=='table' and M.INSIGHT[m.wit] or 'estimate'
end
-- Whether this creature reads a screen in this decision, using the same insight and tactic
-- draw as the rest of removal. Exact orders also let a dull boss see it.
function M.readScreen(input)
    local insight=M.insight(input)
    return insight=='exact' or insight=='estimate' or (insight=='rough' and tactical(input))
end
local function screen(w)
    return type(w)=='table' and ((w.opcode==101 and w.p2==58) or
        (w.opcode==206 and type(w.res)=='string' and w.res~=''))
end
local function blocksRemoval(w,spell)
    if not screen(w) then return false end
    local role=type(spell.roles)=='table' and spell.roles.removal
    if w.opcode==101 then return type(role)=='table' and list(role.kinds).dispel==true end
    return type(spell.sources)=='table' and spell.sources[w.res]==true
end
-- Whether a screen is there to notice (choice.notices), with a ready removal to use on it.
function M.screening(input)
    for _,e in ipairs(list(input.frame.enemies)) do
        for _,w in ipairs(list(e.wards)) do
            if screen(w) then
                for _,row in ipairs(list(input.spells)) do
                    if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and
                        M.removal(row.spell) and blocksRemoval(w,row.spell) then return true end
                end
            end
        end
    end
    return false
end
-- A removal as it reaches this enemy. The general protection check treats an opcode immunity
-- or a blocked delivery as stopping the whole spell; here the surviving parts must still count.
-- A caster that misses the screen believes the original delivery and dispel will work.
function M.against(input,spell,e)
    local hasScreen,dispel,blocked=false,false,nil
    for _,w in ipairs(list(e.wards)) do
        if type(w)=='table' then
            if screen(w) then hasScreen=true end
            if w.opcode==101 and w.p2==58 then dispel=true
            elseif w.opcode==206 and type(w.res)=='string' and w.res~='' and w.res~=spell.resref and
                type(spell.sources)=='table' and spell.sources[w.res] then
                blocked=blocked or {};blocked[w.res]=true
            end
        end
    end
    local reads=hasScreen and M.readScreen(input)
    if not dispel and not blocked then return spell,e,reads end
    local effective=reads and blocked and spells.without(spell,blocked) or spell
    local target=e
    if type(e.protections)=='table' then
        local kept={}
        for _,p in ipairs(e.protections) do
            local skip=type(p)=='table' and ((dispel and p.opcode==101 and p.p2==58) or
                (p.opcode==206 and blocked and blocked[p.res] and
                (not reads or effective~=spell)))
            if not skip then kept[#kept+1]=p end
        end
        if #kept<#e.protections then
            target={}
            for k,v in pairs(e) do target[k]=v end
            target.protections=kept
        end
    end
    return effective,target,reads
end
-- The least caster level a spell of level power takes: a wizard's 1, 3, 5 up to 17, a priest's the
-- same up to its sixth level.
function M.floor(power)
    if not number(power) or power<1 then return 1 end
    return 2*math.floor(power)-1
end
-- The level of whoever a clever creature takes enemy e's protections to come from: e's own when e
-- casts spells, else the highest of the casters on e's side in view (frame.enemies), else e's own.
function M.source(frame,e)
    local own=number(e.level) and e.level or 1
    if ids.caster(e) then return own end
    local best
    for _,o in ipairs(list(type(frame)=='table' and frame.enemies)) do
        if targeting.alive(o) and ids.caster(o) and number(o.level) and (not best or o.level>best) then best=o.level end
    end
    return best or own
end
-- What a caster of insight ('estimate' or 'rough') believes of the caster level of ward w on enemy
-- e: the level it guesses, how sure it is (a spread of levels) and the least it can be.
function M.guess(insight,frame,e,w)
    if insight=='rough' then return number(e.level) and e.level or 1,M.spread.rough,1 end
    local floor=M.floor(w.power)
    return math.max(floor,M.source(frame,e)),M.spread.estimate,floor
end
-- The chance a dispel at level at takes a ward whose caster level is believed near guess (spread
-- and floor as M.guess has them), after what has been seen of dispels at the same spell's effects
-- on the same enemy: seen, by dispel level, the shares of them that stayed and that went, each
-- taken in weight times. When nothing is left to believe (what was seen cannot be), the chance at
-- the guess.
function M.believed(at,guess,spread,floor,seen,weight)
    local sum,total=0,0
    weight=number(weight) and weight or 0
    for x=math.max(floor,math.floor(guess-M.tails*spread)),math.ceil(guess+M.tails*spread) do
        local d=(x-guess)/spread
        local p=math.exp(-0.5*d*d)
        if weight>0 then
            for level,o in pairs(list(seen)) do
                if number(level) and type(o)=='table' then
                    local c=M.dispelChance(level,x)
                    p=p*(1-c)^(weight*(number(o.stayed) and o.stayed or 0))*c^(weight*(number(o.went) and o.went or 0))
                end
            end
        end
        sum=sum+p*M.dispelChance(at,x);total=total+p
    end
    if total<=0 then return M.dispelChance(at,guess) end
    return sum/total
end
-- How the caster weighs a dispel's chance at enemy e's wards (see the top): chanceOf(w,at) for
-- M.taken, or nil for the effects' own caster levels (insight 'exact'). area: the dispel is cast as
-- an area.
function M.belief(input,e,area)
    local insight=M.insight(input)
    if insight=='exact' then return nil end
    if insight=='none' then return function(_,at) return M.dispelChance(at,at) end end
    local book=type(input.dispels)=='table' and e.id~=nil and input.dispels[e.id] or nil
    book=type(book)=='table' and book or {}
    local first=area==true and not (number(book.tried) and book.tried>0)
    local sources=type(book.sources)=='table' and book.sources or {}
    local weight=M.learnWeight[insight] or 0
    local cache={}
    return function(w,at)
        local s=type(w.source)=='string' and w.source or ''
        local key=s..'|'..tostring(w.power)..'|'..tostring(at)
        local c=cache[key]
        if c==nil then
            local guess,spread,floor=M.guess(insight,input.frame,e,w)
            c=M.believed(at,guess,spread,floor,s~='' and sources[s] or nil,weight)
            if first then c=math.max(c,M.dispelChance(at,at)) end
            cache[key]=c
        end
        return c
    end
end
-- What the group learns from a dispel at level at that was judged on one enemy, into book (what it
-- has seen of dispels at that enemy; a new one when nil), which it returns. before and after count
-- the enemy's effects a dispel can take by the spell or item they come from. Each spell counts once:
-- the share of its effects that stayed and the share that went. When none went at all the dispel
-- may not have got through: what stayed counts only as likely as it did (land, the chance it got
-- through the enemy's magic resistance). The dispel counts as tried either way.
function M.learn(book,before,after,at,land)
    book=type(book)=='table' and book or {}
    book.tried=(number(book.tried) and book.tried or 0)+1
    if not number(at) or type(before)~='table' then return book end
    after=type(after)=='table' and after or {}
    local function left(s) return number(after[s]) and after[s] or 0 end
    local any=false
    for s,n in pairs(before) do
        if number(n) and n>0 and left(s)<n then any=true end
    end
    local weight=any and 1 or clamp(number(land) and land or 1,0,1)
    if weight<=0 then return book end
    book.sources=type(book.sources)=='table' and book.sources or {}
    for s,n in pairs(before) do
        if type(s)=='string' and s~='' and number(n) and n>0 then
            local stayed=clamp(left(s)/n,0,1)
            local seen=type(book.sources[s])=='table' and book.sources[s] or {}
            book.sources[s]=seen
            local o=type(seen[at])=='table' and seen[at] or {stayed=0,went=0}
            seen[at]=o
            o.stayed=o.stayed+weight*stayed
            o.went=o.went+weight*(1-stayed)
        end
    end
    return book
end

-- What removal r takes of wards (an enemy's, in list order), cast at caster level level: the
-- chance each ward goes, by index, and whether the invisible state goes. chanceOf(w,at) (optional,
-- M.belief) gives a dispel's chance at ward w; without it, its effect's own caster level does.
-- readScreen=false is the belief of a caster that did not see the dispel immunity.
function M.taken(r,wards,level,chanceOf,readScreen)
    local chance={}
    local function take(i,p) chance[i]=math.max(chance[i] or 0,p) end
    local kinds=list(r.kinds)
    local screened=false
    if kinds.dispel and readScreen~=false then
        for _,w in ipairs(wards) do
            if type(w)=='table' and w.opcode==101 and w.p2==58 then screened=true;break end
        end
    end
    if kinds.dispel and type(r.dispel)=='table' and not screened then
        local at=r.dispel.mode=='fixed' and r.dispel.level or level
        for i,w in ipairs(wards) do
            if type(w)=='table' and w.dispellable then
                local p
                if r.dispel.mode=='always' then p=1
                elseif chanceOf then p=chanceOf(w,at)
                else p=M.dispelChance(at,w.level) end
                take(i,p)
            end
        end
    end
    -- Type 0 (none) marks no spell.
    for field,key in pairs({schools='school',secondaries='secondary'}) do
        local caps=list(r[field])
        local single=type(r.single)=='table' and list(r.single[field]) or {}
        local swept,spellOf,itemOf={},{},{}
        for i,w in ipairs(wards) do
            local value=type(w)=='table' and w[key]
            if number(value) and value~=0 and number(w.power) and w.power>=0 then
                local s=type(w.source)=='string' and w.source or ''
                local cap=caps[value]
                if number(cap) and w.power<=cap then
                    if s~='' then swept[s]=math.max(swept[s] or -1,cap) else take(i,1) end
                end
                local one=single[value]
                if number(one) and w.power<=one and w.power>0 and s~='' then
                    if w.equipped then itemOf[value]=itemOf[value] or s else spellOf[value]=spellOf[value] or s end
                end
            end
        end
        for i,w in ipairs(wards) do
            if type(w)=='table' and type(w.source)=='string' and w.source~='' and number(w.power) then
                local cap=swept[w.source]
                if cap and w.power<=cap and not w.lasting then take(i,1) end
                local value=w[key]
                local one=number(value) and single[value]
                if number(one) and w.power<=one and (spellOf[value]==w.source or itemOf[value]==w.source) then take(i,1) end
            end
        end
    end
    local ops=list(r.opcodes)
    for i,w in ipairs(wards) do
        local params=type(w)=='table' and ops[w.opcode]
        if type(params)=='table' and not w.lasting and (params[-1] or params[w.p2]) then take(i,1) end
    end
    return chance,kinds.invisibility==true
end

-- Enemy e's shield from its wards, all but those gone (a set of indices): what defence.blocks
-- weighs. Stoneskin skins, Mirror Images and invisibility are the engine's counts and states;
-- they go with the spell that gave them. Magic resistance is e's own, less what the gone wards
-- added. Also the armour the gone wards gave (e's armour class holds it now) and whether e is
-- seen once they are gone.
function M.shield(e,wards,gone,visible)
    local s=defence.shield(nil)
    local armor,mr,skins,mirror,unseen=0,0,false,false,false
    for i,w in ipairs(wards) do
        if type(w)=='table' then
            local ws=defence.shield(w.roles)
            if gone and gone[i] then
                armor=armor+ws.armor;mr=mr+ws.mr
                if M.SKINS[w.opcode] or ws.stoneskin>0 then skins=true end
                if M.MIRROR[w.opcode] or ws.mirror>0 then mirror=true end
                if M.INVISIBLE[w.opcode] or ws.invisible then unseen=true end
            else s=defence.union(s,ws) end
        end
    end
    s.armor=0
    s.stoneskin=skins and 0 or (number(e.skins) and e.skins or 0)
    s.mirror=mirror and 0 or (number(e.mirror) and e.mirror or 0)
    s.mr=math.max(0,(number(e.mr) and e.mr or 0)-mr)
    local seen=visible or unseen
    s.invisible,s.improved=false,false
    if not seen then
        if targeting.has(e.state,targeting.STATE.improvedInvisible) then s.invisible,s.improved=true,true
        elseif targeting.has(e.state,targeting.STATE.invisible) then s.invisible=true end
    end
    return s,armor,seen
end

-- The caster's side's pressure on enemy target: threat.picture's entry for it, with the friends
-- (the caster and its living allies, with their attack data, levels and classes) as the attackers
-- and the living enemies as the side they spread over. The caster strikes with the weapon in its
-- hand, or not at all without one.
function M.pressure(frame,target)
    local attackers={}
    local caster=frame.self
    if targeting.alive(caster) then
        local c={}
        for k,v in pairs(caster) do c[k]=v end
        c.attack=threat.wielded(caster)
        attackers[1]=c
    end
    for _,a in ipairs(list(frame.allies)) do if targeting.alive(a) then attackers[#attackers+1]=a end end
    local others={}
    for _,e in ipairs(list(frame.enemies)) do
        if e.id~=target.id and targeting.alive(e) then others[#others+1]=e end
    end
    return threat.picture({self=target,allies=others,enemies=attackers})[target.id]
end

-- Two buff roles as one: every kind of either, amounts added.
local function buffs(a,b)
    local out={kinds={},amounts={}}
    local function add(r)
        if type(r)~='table' then return end
        for k,v in pairs(list(r.kinds)) do if v then out.kinds[k]=true end end
        for k,v in pairs(list(r.amounts)) do if number(v) then out.amounts[k]=(out.amounts[k] or 0)+v end end
    end
    add(a);add(b)
    return out
end

-- What the removal takes from the caster's side on e over r rounds, given the chance each ward
-- goes: the conditions it holds e in, each worth what freeing a friend of it is worth for what is
-- left of it (care.CONDITION; those that hinder only casters a fifth on others), and the weapon
-- harm e gets back once a slowing or a penalty to its attacks, hits or damage is gone (its
-- current attack holds them; defence.offense of their reverse, against the friends).
function M.lost(e,wards,chance,friends,r)
    local worth=0
    local health=targeting.health(e)
    for i,p in pairs(chance) do
        local w=wards[i]
        if p>0 and type(w)=='table' and type(w.roles)=='table' then
            local factor=0
            for _,name in ipairs({'disable','debuff'}) do
                local role=w.roles[name]
                for label in pairs(type(role)=='table' and list(role.kinds) or {}) do
                    local f=care.CONDITION[label] or 0
                    if care.CASTERS_ONLY[label] and not ids.caster(e) then f=f*0.2 end
                    factor=math.max(factor,f)
                end
            end
            if factor>0 then
                local left=number(w.left) and w.left or math.huge
                worth=worth+p*factor*clamp(math.min(left,r*M.ROUND)/care.fullSeconds,0,1)*(0.5+0.5*health)
            end
            local d=w.roles.debuff
            if type(d)=='table' then
                local slow=list(d.kinds).slow==true
                local back={kinds={haste=slow,improvedHaste=slow},amounts={}}
                for _,k in ipairs({'attacks','thac0','damage','luck'}) do
                    local v=type(d.amounts)=='table' and d.amounts[k]
                    if number(v) then back.amounts[k]=v end
                end
                worth=worth+p*defence.offense(back,e,{enemies=friends},r)
            end
        end
    end
    return worth
end

-- Freeing enemy e, one the other side charmed (see the top), given the chance each of its wards
-- goes: the chance that every charm on it goes, and what freeing it is worth over r rounds: the
-- same charm on an enemy (harm.DISABLE) for as long as the longest of them would still hold, as
-- harm counts a disable. Nothing without a charm the removal can take.
function M.freed(e,wards,chance,r)
    local p,left,any=1,0,false
    for i,w in ipairs(wards) do
        local d=type(w)=='table' and type(w.roles)=='table' and w.roles.disable
        if type(d)=='table' and type(d.kinds)=='table' and d.kinds.charm then
            any=true
            p=p*(chance[i] or 0)
            left=math.max(left,number(w.left) and w.left or math.huge)
        end
    end
    if not any or p<=0 or r<=0 then return 0,0 end
    local span=clamp(math.min(left,r*M.ROUND)/harm.fullSeconds,0,1)
    return p,harm.DISABLE.charm*span*(0.5+0.5*targeting.health(e))
end

-- The worth of a removal spell on enemy e once it lands, r rounds before the horizon ends, the
-- reason when it is none, and the chance it lands. It can be below zero: then the removal frees e
-- of more than it opens. area: the spell is cast as an area (a dispel's chance, M.belief).
function M.on(input,spell,e,r,area,following)
    local mind=input.mind
    local killBonus=number(mind.killBonus) and mind.killBonus or 0
    local effective,target,reads=M.against(input,spell,e)
    local roles,key=spells.view(effective,targeting.holds(e))
    if type(roles)~='table' or (type(key)=='string' and key:find('?',1,true)) then return 0,'unknown-filter' end
    local role=roles.removal
    if type(role)~='table' or type(role.who)~='table' or not (role.who.target or role.who.area) then return 0,'filter' end
    if targeting.protected(target,effective) then return 0,'protected' end
    local kinds=list(role.kinds)
    local land=targeting.landing(role,e)*(1-targeting.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
    local original=type(spell.roles)=='table' and spell.roles.removal
    local share=spell.release and type(original)=='table' and list(original.kinds).dispel and M.sequencerShare or 1
    if land<=0 then return 0,'resisted' end
    -- Unsummoned or destroyed: out of the fight for good, as a kill. Unsummoning takes summons only.
    if kinds.destroy or (kinds.summons and summoned(e)) then return share*land*(targeting.health(e)+killBonus) end
    if r<=0 then return 0,'no-time' end
    local wards=type(e.wards)=='table' and e.wards or {}
    local chance,purge=M.taken(role,wards,input.frame.self.level,M.belief(input,e,area),reads)
    local gone,n,sum=nil,0,0
    for i,p in pairs(chance) do
        if p>0 then gone=gone or {};gone[i]=true;n=n+1;sum=sum+p end
    end
    local hidden=targeting.has(e.state,UNSEEN)
    if not gone and not (purge and hidden) then return 0,'nothing' end
    local before=M.shield(e,wards,nil,false)
    local after,armor,seen=M.shield(e,wards,gone,purge)
    local changed=e
    if armor~=0 or (seen and hidden) then
        changed={}
        for k,v in pairs(e) do changed[k]=v end
        changed.ac=(number(e.ac) and e.ac or 10)+armor
        if seen and hidden then
            local state=number(e.state) and e.state or 0
            if targeting.has(state,targeting.STATE.invisible) then state=state-targeting.STATE.invisible end
            if targeting.has(state,targeting.STATE.improvedInvisible) then state=state-targeting.STATE.improvedInvisible end
            changed.state=state
        end
    end
    local frame=input.frame
    local t0=M.pressure(frame,e)
    local t1=changed==e and t0 or M.pressure(frame,changed)
    local opened=0
    if t0 and t1 then
        opened=math.max(0,defence.loss(after,changed,t1,r,killBonus)-defence.loss(before,e,t0,r,killBonus))
    end
    local buff
    for i in pairs(gone or {}) do
        local w=wards[i]
        if type(w)=='table' and type(w.roles)=='table' and type(w.roles.buff)=='table' then buff=buffs(buff,w.roles.buff) end
    end
    local friends=threat.friends(frame)
    if buff then opened=opened+defence.offense(buff,e,{enemies=friends},r) end
    -- What opens is weighed by the mean chance of what goes; what it frees e of, ward by ward.
    local worth=opened*(n>0 and sum/n or 1)-M.lost(e,wards,chance,friends,r)
    -- One the other side charmed, freed: back on its side, as far as the caster sees it.
    if targeting.charmed(e) and tactical(input) then
        local p,gain=M.freed(e,wards,chance,r)
        worth=p*gain+(1-p)*worth
    end
    if not following and gone and reads then
        worth=worth+M.follow(input,spell,e,changed,after,wards,gone,chance,r)
    end
    worth=worth*land*share
    if worth==0 then return 0,'no-worth' end
    return worth,worth<0 and 'frees' or nil,land
end

-- Seconds the caster walks before it can cast spell at p (a creature or a point): none in range,
-- else the walk into range, as for attacks (combat-intent/choice.lua); nil for a cone, a release
-- (ForceSpellRES goes off where the caster stands) and a caster that cannot walk.
local function approach(caster,p,spell)
    if targeting.distance(caster,p)<=range(spell) then return 0 end
    if spell.release or (type(spell.area)=='table' and spell.area.cone) then return nil end
    return weapons.approach(caster,p,range(spell))
end
-- Where the caster casts spell at p from: where it stands in range, else where its walk ends, at
-- the spell's range from p on the way.
local function castFrom(caster,p,spell)
    local d,far=targeting.distance(caster,p),range(spell)
    if d<=far or d==math.huge then return caster end
    return {x=p.x+(caster.x-p.x)*far/d,y=p.y+(caster.y-p.y)*far/d}
end

-- The seconds the caster walks before it can aim at e directly (none in range), or nil: e must be
-- alive, without sanctuary and seen.
local function aimable(caster,e,spell)
    if not targeting.alive(e) then return nil end
    if number(e.sanctuary) and e.sanctuary>0 then return nil end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return nil end
    return approach(caster,e,spell)
end

-- Where the spell can go: an enemy it can aim at (with the enemies around it for an area), each
-- enemy's spot and the middle of the enemies around it for an area at a point, the caster's spot
-- for its own area. An aim beyond the spell's range carries the seconds of the walk into range
-- (walk).
local function aims(input,spell)
    local frame=input.frame
    local caster=frame.self
    local a=type(spell.area)=='table' and spell.area or nil
    local out={}
    if spell.target=='self' then
        if a then out[1]={point={x=caster.x,y=caster.y},self=true} end
        return out
    end
    local function add(aim,walk)
        if not walk then return end
        if walk>0 then aim.walk=walk end
        out[#out+1]=aim
    end
    for _,e in ipairs(list(frame.enemies)) do
        if spell.target=='creature' then
            add({enemy=e,point={x=e.x,y=e.y}},aimable(caster,e,spell))
        elseif spell.target=='point' and a then
            if targeting.alive(e) and number(e.x) and number(e.y) then
                local p={x=e.x,y=e.y}
                add({point=p},approach(caster,p,spell))
                local sx,sy,n=0,0,0
                for _,o in ipairs(frame.enemies) do
                    if targeting.alive(o) and number(o.x) and number(o.y) and targeting.distance(e,o)<=a.radius then
                        sx,sy,n=sx+o.x,sy+o.y,n+1
                    end
                end
                if n>1 then
                    local m={x=sx/n,y=sy/n}
                    add({point=m},approach(caster,m,spell))
                end
            end
        end
    end
    return out
end

-- The enemy after these wards go, for one following removal only. Match protection rows one
-- at a time so a second, surviving copy of an immunity still protects it.
local function afterWards(e,changed,shield,wards,gone)
    local out={}
    for k,v in pairs(changed) do out[k]=v end
    out.wards={}
    for i,w in ipairs(wards) do if not gone[i] then out.wards[#out.wards+1]=w end end
    out.mr=shield.mr;out.skins=shield.stoneskin;out.mirror=shield.mirror
    if type(e.protections)=='table' then
        out.protections={}
        local used={}
        for _,p in ipairs(e.protections) do
            local take=false
            for i in pairs(gone) do
                local w=wards[i]
                if not used[i] and type(p)=='table' and p.opcode==w.opcode and p.p2==w.p2 and
                    (w.p1==nil or p.p1==w.p1) and (p.res or '')==(w.res or '') then
                    used[i]=true;take=true;break
                end
            end
            if not take then out.protections[#out.protections+1]=p end
        end
    end
    return out
end
-- A following removal must have a legal aim that reaches e and spares the caster's side,
-- just as the options below. Keep the best walk's pacing; a release cannot walk into range.
local function followReach(input,spell,role,e)
    local best=0
    local a=type(spell.area)=='table' and spell.area
    for _,aim in ipairs(aims(input,spell)) do
        local reaches=aim.enemy and aim.enemy.id==e.id
        if a and (not aim.enemy or role.who.area) then
            reaches=targeting.distance(aim.point,e)<=a.radius
            if reaches and a.filter~='enemies' then
                for _,ally in ipairs(list(input.frame.allies)) do
                    if targeting.alive(ally) and targeting.distance(aim.point,ally)<=a.radius+M.allyMargin then reaches=false end
                end
                local caster=input.frame.self
                local at=aim.walk and castFrom(caster,aim.point,spell) or caster
                if (not aim.self and targeting.distance(aim.point,at)<=a.radius+M.allyMargin) or
                    (aim.self and not a.skipsCenter) then reaches=false end
            end
        end
        if reaches then best=math.max(best,aim.walk and weapons.paced(aim.walk) or 1) end
    end
    return best
end
-- The best next removal that this screen kept out, discounted once. Spend this cast's ready
-- copy before looking ahead. A second step never looks ahead again (M.on's following flag).
function M.follow(input,spell,e,changed,shield,wards,gone,chance,r)
    local screens={}
    for i in pairs(gone) do if screen(wards[i]) then screens[#screens+1]=i end end
    if #screens==0 then return 0 end
    local after=afterWards(e,changed,shield,wards,gone)
    local best=0
    for _,row in ipairs(list(input.spells)) do
        if type(row)=='table' and number(row.ready) and row.usable then
            local same=row.spell==spell or row.resref==spell.resref
            local nextSpell=row.spell
            local role=row.ready>(same and 1 or 0) and M.removal(nextSpell)
            if role then
                local p=0
                for _,i in ipairs(screens) do
                    if blocksRemoval(wards[i],nextSpell) then p=math.max(p,chance[i] or 0) end
                end
                if p>0 then
                    local pace=followReach(input,nextSpell,role,after)
                    if pace>0 then
                        local value=M.on(input,nextSpell,after,r,nextSpell.area~=nil,true)
                        best=math.max(best,value*p*pace)
                    end
                end
            end
        end
    end
    return best*M.screenFollow
end

-- Every removal the caster can cast now, best aim per spell: {resref, kind='removal', mode, worth,
-- cost, score, hits (the enemies it opens), slack=0, speed, and target, point or self; walk, the
-- seconds of the walk into range, for an aim beyond it; for a dispel that rolls, at (the level it
-- works at), lands (by enemy id among hits, the chance it lands), which M.learn takes, and the
-- insight it was weighed with}. An area
-- counts every enemy in it, also those it would free. attack (optional) names the spells
-- combat-intent/choice.lua weighs as attacks, with their removal (left out here). rejected
-- (optional) counts why ready removal spells gave none.
function M.options(input,rejected,attack)
    local out={}
    local function reject(why) if rejected then rejected['removal-'..why]=(rejected['removal-'..why] or 0)+1 end end
    local mind=input.mind
    local frame=input.frame
    if type(frame)~='table' or type(frame.self)~='table' or type(mind)~='table' then return out end
    local caster=frame.self
    local horizon=number(mind.horizon) and mind.horizon or 18
    local pictures
    for _,row in ipairs(list(input.spells)) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and not (attack and attack(row.spell)) then
            local spell=row.spell
            local role,why=M.removal(spell)
            if not role then
                if why=='partial' or why=='harms-friends' or why=='unknown-projectile' or why=='unknown-shape' then reject(why) end
            else
                local cast=(number(spell.speed) and spell.speed or 0)*M.speedSeconds
                local r=math.max(0,horizon-cast)/M.ROUND
                local a=type(spell.area)=='table' and spell.area or nil
                local best,reason
                for _,aim in ipairs(aims(input,spell)) do
                    local worth,hits,lands,blocked=0,{},{},false
                    if a and (not aim.enemy or role.who.area) then
                        local center=aim.point
                        if a.filter~='enemies' then
                            for _,ally in ipairs(list(frame.allies)) do
                                if targeting.alive(ally) and targeting.distance(center,ally)<=a.radius+M.allyMargin then blocked=true end
                            end
                            local at=aim.walk and castFrom(caster,center,spell) or caster
                            if not aim.self and targeting.distance(center,at)<=a.radius+M.allyMargin then blocked=true end
                            if aim.self and not a.skipsCenter then blocked=true end
                        end
                        if not blocked then
                            for _,e in ipairs(list(frame.enemies)) do
                                if targeting.alive(e) and targeting.distance(center,e)<=a.radius then
                                    local w,no,land=M.on(input,spell,e,r,true)
                                    if w>0 then w=w*orders.favour(input,e) end
                                    worth=worth+w
                                    if w>0 then hits[#hits+1]=e.id;lands[e.id]=land else reason=reason or no end
                                end
                            end
                        else reason=reason or 'ally-in-area' end
                    elseif aim.enemy then
                        local w,no,land=M.on(input,spell,aim.enemy,r)
                        if w>0 then worth=w*orders.favour(input,aim.enemy);hits[1]=aim.enemy.id;lands[aim.enemy.id]=land
                        else reason=reason or no end
                    end
                    -- A walk into range comes first and lowers the worth (combat-intent/choice.lua).
                    if aim.walk then worth=worth*weapons.paced(aim.walk) end
                    if worth>0 and #hits>0 and (not best or worth>best.worth) then best={aim=aim,worth=worth,hits=hits,lands=lands} end
                end
                if not best then reject(reason or 'out-of-reach')
                else
                    pictures=pictures or threat.picture(frame)
                    local through=defence.through(input,pictures[caster.id],cast)
                    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
                    local cost=(number(mind.economy) and mind.economy or 1)*slots(input)*M.costPerLevel*level+
                        (number(mind.castCost) and mind.castCost or 0)*cast
                    local value=best.worth*through
                    local option={resref=row.resref,kind='removal',worth=value,cost=cost,score=value-cost,hits=best.hits,
                        slack=0,speed=number(spell.speed) and spell.speed or 0,release=spell.release or nil,walk=best.aim.walk}
                    option.at=M.dispelAt(role,caster.level)
                    if option.at then option.lands=best.lands;option.insight=M.insight(input) end
                    local aim=best.aim
                    if aim.self then option.self=true;option.mode='self-area'
                    elseif aim.enemy then option.target=aim.enemy.id;option.mode='creature'
                    else option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)};option.mode='point-area' end
                    out[#out+1]=option
                end
            end
        end
    end
    return out
end
return M
