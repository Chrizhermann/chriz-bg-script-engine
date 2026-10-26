-- The engine's own choice of an attack spell and its target or aim point for one caster (step
-- 3, second slice; Christopher's answers of 2026-10-18 are in the plan). Inputs are plain
-- values: the caster's perception frame with enemy details (adapters/eeex/sense.lua), its
-- ready and usable spells classified by combat-intent/spells.lua, the fight director's plan,
-- what it remembers about casts that had no effect, and its profile (combat-intent/mind.lua).
-- Nothing here touches the engine. Odd data drops one option, never the whole choice.
--
-- The round (Christopher, 2026-10-25: "wir müssen SCS nichts überlassen", and what is quick does
-- not take the round): the engine leaves no round to SCS. While the casting aura of the last cast
-- runs, casts and drinks wait for it; an attack is made meanwhile when it is worth more than the
-- part of the best cast it holds back, else the creature waits until the aura frees. With nothing
-- worth doing it waits a moment and decides again. A fighter or monster attacks whenever nothing
-- else is worth more (mind.alwaysAttack); a caster that has no attack worth anything takes the best
-- spell that is worth something.
--
-- Worth is counted in shares of an enemy taken out of the fight: the hit points a cast takes
-- (as a share of the enemy's maximum, no more than it has left), the worth of a kill, or the
-- chance and length of a disable. A spell's level costs a little, so small spells do small
-- jobs. An attack must reach the profile's minimum worth.
--
-- Walking into range (R3: with no round left to SCS, an enemy out of range is no reason to wait):
-- a spell aimed beyond its range is cast after a walk into range, as the game's spell actions walk
-- there first. The walk lowers the worth as a walk to a melee enemy does, and an area must keep
-- the caster out where the walk ends. Not for a cone, a release or a caster that cannot walk; an
-- area around the caster goes off where it stands.
--
-- Since the third slice (Christopher, 2026-10-19) the caster's protections and buffs compete on
-- the same scale (combat-intent/defence.lua): the best option of either kind is cast. Openers
-- (combat-intent/openers.lua: Time Stop, Improved Alacrity) come first, as in SCS's order. In the
-- caster's own Time Stop its enemies stand frozen, and what it casts lands when time resumes:
-- the enemies it has disabled in the stop count as disabled, the damage it dealt them as dealt.
-- Under Improved Alacrity slow spells wait while a quick one is good enough, as SCS's do.
--
-- Touch charges (D2c, combat-intent/touch.lua): a touch spell is cast on the caster and aimed at
-- the enemy it will strike, worth what its hit does there times the chance to hit, less what
-- standing next to that enemy costs. A charge in hand is struck first, again until it lands.
-- Neither in the caster's own Time Stop nor under Improved Alacrity, as SCS keeps weapons out of
-- both.
--
-- Weapon attacks (D2c, combat-intent/weapons.lua; Christopher, 2026-10-20): the weapon in the
-- caster's hand, conjured or not, is worth a round of its hits on the enemy it attacks, less what
-- standing next to that enemy costs for melee. The walk to a melee enemy comes first and lowers
-- the worth; fighters and monsters walk to any enemy they see (mind.chase, F1d), casters only
-- within touchReach. It spends nothing, so it needs no minimum worth:
-- when no spell reaches minValue, the engine attacks. A spell
-- that conjures a weapon is worth the hits the weapon deals in the rounds after, as many as it
-- lasts within the horizon. Neither in the caster's own Time Stop nor under Improved Alacrity.
-- Releases (D2b): SCS's sequencers and triggers are innates that cast their spells at once. The
-- classifier reads them as their spells together, with the reach of the shortest
-- (combat-intent/spells.lua); their options carry release, and the adapter sets them off with
-- ForceSpellRES as SCS does. None under Improved Alacrity, as SCS keeps them for after it.
--
-- Healing and curing (D3a, D3b; Christopher, 2026-10-20: "Mach alles"): heals and cures for the
-- caster and its allies, and potions, compete on the same scale (combat-intent/care.lua). The
-- engine no longer leaves a hurt group or a silenced caster to SCS.
--
-- Summons (D3c): the creatures a summoning spell brings, by their fight on the caster's side,
-- compete on the same scale (combat-intent/summons.lua).
--
-- Protection removal (D3d): breaching, dispelling and stripping enemies and unsummoning summoned
-- ones compete on the same scale (combat-intent/removal.lua). An attack that also removes (Spell
-- Revisions' Chromatic Orb takes haste, Disintegrate destroys some creatures) stays an attack and
-- adds what its removal is worth on each enemy it hits. SCS keeps no round for spells of its own
-- (its scripts never raise).
--
-- Danger zones (D3e, combat-intent/zones.lua): clouds and storms around the caster count in every
-- option. Harm from them can break a cast where it stands; a melee attack or a strike counts what
-- walking to its target and standing there does in them. A way out of a zone that hurts the
-- caster comes first when what leaving is worth beats the share of a round the walk takes from
-- the best other choice. How much of this a creature sees is its wit (combat-intent/mind.lua): a
-- dull one counts no zone and leaves only when the pain drives it out, then whatever else it
-- could do.
--
-- Lasting areas (D3e; Christopher, 2026-10-23: "Ich würde eine Mischung aus A und C machen"): a
-- cloud or storm of the caster's own counts the explosions each enemy inside is expected to sit
-- through, not one. The first goes off where it lands (unless the projectile skips it), the next
-- every few seconds while it lasts; one that Spell Revisions' clouds make immune to them for a
-- while is hit when that wears off (combat-intent/zones.lua, period). Only explosions in the rest
-- of the fight count (combat-intent/threat.lua, rest), the first always, and those the enemy's
-- turnings, deflections and traps stop come first. An enemy that cannot walk sits through all of
-- them. Any other takes the cheaper of staying and walking out (A): out, it takes the explosions
-- until it is out, starting M.react seconds after the landing, and loses the walk's seconds as a
-- hold of that length. Some enemies stay anyway (C): the chance an enemy stays is what the group
-- has seen it do in zones that hurt it (input.stays: the explosions it stayed for and the zones it
-- left, adapters/eeex/choice.lua), from M.stayPrior worth M.stayWeight sightings. An ally or the
-- caster may stand in the caster's own area when the area does nothing to it. The profile's
-- clouds switch: 'learned', 'best' (A alone) or 'once' (one explosion, as before).
--
-- Orders (combat-intent/orders.lua; Christopher, 2026-10-25): a designer's target order makes what
-- the creature's attacks do to the enemy it names count more, or keeps its attacks on that enemy
-- while it can attack it at all.
--
-- Interrupting (Christopher, 2026-10-25: worth decides, with a bonus for interrupting an enemy that
-- is casting): damage that lands while an enemy casts breaks its spell, and its spell slot stays
-- spent (ACT-03, batch H5). The creature may know the spell, as SCS's scripts can learn it from the
-- game's SpellCast triggers: an enemy carries cast {level, speed, timer} while it casts in a way
-- damage can break (adapters/eeex/choice.lua). Breaking the spell is worth mind.interrupt for each
-- of its levels, times the chance the attack's damage lands while the casting runs
-- (M.castWindow). Only damage counts yet; whether a hold, sleep or silence breaks a cast is open.
-- How often a creature sees the chance is its wit (mind.tactics): a clever one always, a normal
-- one in half its decisions, a dull one never.
--
-- Jumps into the fight (Christopher, 2026-10-26: a real ability, named in the log and with a
-- cooldown, instead of SCS's scripted jump; SCS's fiends jump to a party member who is weak, a mage
-- or easy to hit, [src] fiend/ssl/jump.ssl, credit DavidW): a creature that walks to any enemy it
-- sees for its melee weapon (mind.chase) may cast a teleport it has (input.teleports,
-- combat-intent/search.lua) at a spot next to an enemy a long walk away instead, picked as the
-- search picks one: an innate teleport for a walk of search.jumpMin or more, a memorized spell
-- from search.jumpSlotMin on, none within search.jumpGap of its last teleport (input.jumped). It
-- is worth the round of hits it brings without the walk, and costs what a spell of its level costs
-- and what standing next to the enemy costs. As it ends next to the enemy like the walk, a creature
-- that always attacks takes it over the walk whenever it is worth more. A tactic (M.tactical): a
-- clever creature always, a normal one when it notices, a dull one never.
local targeting=require('combat-intent.targeting')
local harm=require('combat-intent.harm')
local defence=require('combat-intent.defence')
local care=require('combat-intent.care')
local summons=require('combat-intent.summons')
local removal=require('combat-intent.removal')
local zones=require('combat-intent.zones')
local threat=require('combat-intent.threat')
local openers=require('combat-intent.openers')
local touch=require('combat-intent.touch')
local weapons=require('combat-intent.weapons')
local spells=require('combat-intent.spells')
local orders=require('combat-intent.orders')
local search=require('combat-intent.search')
local M={}
M.rangeUnit=targeting.rangeUnit
-- Allies keep this much room beyond an area's edge; positions are up to a check-in old.
M.allyMargin=32
-- Worth of one spell level, times the profile's economy.
M.costPerLevel=0.03
-- A disable lasting this long counts in full (three rounds).
M.fullSeconds=harm.fullSeconds
-- STATE_SILENCED, in the active state.
M.SILENCED=0x1000
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible
-- What each kind of disable is worth on an enemy, which kinds take it out for good, which matter
-- only against casters, and the resistance each damage type meets (combat-intent/harm.lua).
M.DISABLE=harm.DISABLE
M.FOR_GOOD=harm.FOR_GOOD
M.CASTERS_ONLY=harm.CASTERS_ONLY
M.RESIST=harm.RESIST
-- Roles that make a spell something other than an attack: healing, curing, raising, summoning,
-- and protection removal unless the spell also attacks, are other decisions.
local OTHER={'removal','heal','raise','cure','summon'}
local GLOBAL={everyone=true,nonparty=true,casterGroup=true,party=true}
-- GENDER.IDS: SUMMONED, ILLUSIONARY, SUMMONED_DEMON.
M.SUMMONED=removal.SUMMONED
-- Lasting areas: the seconds an enemy takes to start walking out of a fresh cloud, and the chance
-- it stays before the group has seen it in one, worth this many sightings.
M.react=1
M.stayPrior=0.25
M.stayWeight=4
-- The round (Christopher, 2026-10-25: the engine owns it all, and what is quick does not take it):
-- casts, drinks and openers wait for the casting aura (frame.self.aura, seconds until it frees),
-- and one chosen this many seconds or less before it frees is queued and starts when it frees. A
-- weapon attack lasts a round. A creature with nothing worth doing waits this many seconds before
-- it decides again.
M.ROUND=threat.ROUND
M.auraLead=0.5
M.idle=1
-- Interrupting (see the top): a casting aura counts from 0 at a cast's start to about 99, a tick at
-- a time (adapters/eeex/choice.lua reads it); a count up to castSlack seconds past the casting time
-- is still the cast's own.
M.auraTicks=100
M.ticksPerSecond=15
M.castSlack=0.4
-- A jump into the fight lands this far short of its enemy, within a weapon's reach (threat.reach).
M.landShort=48

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
local function benefits(role)
    return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area or role.who.point or role.who.party)
end

-- Spell slots (Christopher, 2026-10-21: a slot costs less when the caster has more spells left
-- than rounds it can expect to live, "ja, auf jeden Fall"): the share of a slot's cost that
-- counts now, the rounds the caster lives under the threat it sees, with what protects it now
-- (combat-intent/defence.lua), over the copies it has ready of spells that do something in a
-- fight; 1 while it has the rounds for all of them. Every spell's cost counts the share
-- (input.slots), an item's does not.
function M.slotShare(input)
    local left=0
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and type(row.spell)=='table' and
            type(row.spell.roles)=='table' and next(row.spell.roles)~=nil then left=left+row.ready end
    end
    if left<=1 then return 1 end
    local caster=input.frame.self
    local t=threat.picture(input.frame)[caster.id]
    if not t then return 1 end
    local _,rounds=defence.course(defence.held(caster),caster,t,1)
    if type(rounds)~='number' or rounds~=rounds then return 1 end
    return clamp(math.max(1,rounds)/left,0,1)
end
local function slots(input) return number(input.slots) and input.slots or 1 end

-- 'damage' or 'disable' and how the spell is aimed, or nil and why the engine leaves it out.
function M.attack(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    local roles=targeting.kindRoles(spell)
    local attacks=reaches(roles.disable) or reaches(roles.damage)
    for _,name in ipairs(OTHER) do
        if benefits(spell.roles[name]) and not (name=='removal' and attacks) then return nil,'role-'..name end
    end
    for _,name in ipairs({'damage','disable','debuff'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' then
            for who in pairs(r.who) do if GLOBAL[who] then return nil,'global' end end
            if r.who.self then return nil,'self-harm' end
        end
    end
    if type(spell.roles.disable)=='table' and spell.roles.disable.kinds and spell.roles.disable.kinds.timestop then
        return nil,'time-stop'
    end
    local kind=reaches(roles.disable) and 'disable' or reaches(roles.damage) and 'damage' or nil
    if not kind then return nil,'no-attack' end
    local a=spell.area
    if spell.projectileUnknown and not targeting.builtinSingle[spell.projectile] then return nil,'unknown-projectile' end
    if a and a.filter=='allies' then return nil,'allies-area' end
    if a and (a.line or a.rectangle) and a.filter~='enemies' then return nil,'unknown-shape' end
    if a and a.cone and not (number(a.cone) and a.cone>0 and a.cone<360) then return nil,'unknown-cone' end
    if a and not (number(a.radius) and a.radius>0) then return nil,'unknown-radius' end
    if spell.target=='creature' then return kind,a and 'creature-area' or 'creature' end
    if spell.target=='point' and a then return kind,'point-area' end
    if spell.target=='self' and a then return kind,'self-area' end
    return nil,'not-aimed'
end

local function range(spell) return number(spell.range) and spell.range*M.rangeUnit or 0 end
-- Seconds the caster walks before it can cast spell at p (a creature or a point): none in range,
-- else the walk into range, as the game's spell actions walk there first (lab batch G3); nil for a
-- cone, which starts where the caster stands, a release (ForceSpellRES goes off where the caster
-- stands, D2b) and a caster that cannot walk.
local function approach(caster,p,spell)
    if targeting.distance(caster,p)<=range(spell) then return 0 end
    if spell.release or (type(spell.area)=='table' and spell.area.cone) then return nil end
    return weapons.approach(caster,p,range(spell))
end
-- The caster where it casts spell at p from: where it stands in range, else where its walk ends,
-- at the spell's range from p on the way.
local function castFrom(caster,p,spell)
    local d,far=targeting.distance(caster,p),range(spell)
    if d<=far or d==math.huge then return caster end
    local at={}
    for k,v in pairs(caster) do at[k]=v end
    at.x,at.y=p.x+(caster.x-p.x)*far/d,p.y+(caster.y-p.y)*far/d
    return at
end

-- Whether e can be aimed at directly: alive, no sanctuary, seen, in range or a walk away from it;
-- the seconds of the walk come third.
local function aimable(caster,e,spell)
    if not targeting.alive(e) then return false,'dead' end
    if number(e.sanctuary) and e.sanctuary>0 then return false,'sanctuary' end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    if targeting.distance(caster,e)==math.huge then return false,'no-position' end
    local walk=approach(caster,e,spell)
    if not walk then return false,'out-of-range' end
    return true,nil,walk
end
-- What the spell does to e, or nil and why it does not work on e: its roles for e's kind of
-- creature (spells.view) must hold the attack, and e's spell protections must not stop it. A
-- lasting area gets through once the turnings, deflections and traps that count down are spent.
local function affects(spell,e,kind,lasting)
    local roles,key=spells.view(spell,targeting.holds(e))
    if type(roles)~='table' or not reaches(roles[kind]) then
        return nil,type(key)=='string' and key:find('?',1,true) and 'unknown-filter' or 'filter'
    end
    if lasting then
        if targeting.stopped(e,spell)==math.huge then return nil,'protected' end
    elseif targeting.protected(e,spell) then return nil,'protected' end
    return roles
end

local resisted=harm.resisted
-- The chance e makes its saving throw against role (targeting.saveChance), and the share of casts
-- its magic resistance lets through (targeting.landing).
M.saveChance=targeting.saveChance
local landing=targeting.landing
-- How long a condition holds on e when e gets a save every few seconds to break free
-- (combat-intent/harm.lua).
M.brokenFree=harm.brokenFree
-- How much of a remembered failure still counts: a spell that missed e without a save and
-- without magic resistance to blame met an immunity.
local function remembered(input,resref,e,role)
    if not input.mind.memory or type(input.memory)~='table' then return 1 end
    local misses=input.memory[resref..':'..tostring(e.id)]
    if not number(misses) or misses<=0 then return 1 end
    local saves=type(role.save)=='table' and next(role.save)~=nil
    if not saves and not (number(e.mr) and e.mr>0) then return 0 end
    if misses>=3 then return 0 end
    return 0.5^misses
end

-- The worth of a damage role on e (combat-intent/harm.lua), more on the group's focus and on an
-- enemy the creature's orders name, and the hit points it is expected to take. floor: the hit
-- points e keeps at least (targeting.floor).
local function damageOn(input,row,role,e,floor)
    local worth,expected=harm.damage(role,e,input.mind.killBonus,floor)
    if expected<=0 then return 0,0 end
    local plan=input.plan
    if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    worth=worth*orders.favour(input,e)
    local still=remembered(input,row.resref,e,role)
    return worth*still,expected*still
end

-- The worth of a disable role on e (combat-intent/harm.lua), more on an enemy the creature's orders
-- name: none on an enemy another member has claimed for its disable. floor as for damageOn.
local function disableOn(input,row,role,e,floor)
    if targeting.disabled(e) then return 0 end
    local plan=input.plan
    local reserved=type(plan)=='table' and type(plan.reserved)=='table' and plan.reserved[e.id]
    if reserved and reserved~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    return harm.disable(role,e,input.mind.killBonus,floor)*remembered(input,row.resref,e,role)*orders.favour(input,e)
end

local function offset(a,b) return b.x-a.x,(b.y-a.y)*4/3 end
local function inCone(origin,aim,p,radius,half)
    local ax,ay=offset(origin,aim)
    local px,py=offset(origin,p)
    local d=math.sqrt(px*px+py*py)
    if d>radius then return false end
    if d<1 then return true end
    local la=math.sqrt(ax*ax+ay*ay)
    if la<1 then return false end
    return (ax*px+ay*py)/(la*d)>=math.cos(math.rad(math.min(half,180)))
end

-- Who an area at center (aimed at aim for a cone) reaches, by edge: inside returns whether p
-- is in it, near whether p is within the ally margin of it.
local function shape(spell,caster,center,aim)
    local a=spell.area
    if a.cone then
        local half=a.cone/2
        return function(p) return inCone(caster,aim,p,a.radius,half) end,
            function(p) return inCone(caster,aim,p,a.radius+M.allyMargin,half+10) end
    end
    return function(p) return targeting.distance(center,p)<=a.radius end,
        function(p) return targeting.distance(center,p)<=a.radius+M.allyMargin end
end

-- The worth of the spell's kind of attack on e, and for damage the hit points it is expected to
-- take.
local function worthOn(input,row,kind,roles,e)
    local floor=targeting.floor(e,roles)
    if kind=='damage' then return damageOn(input,row,roles.damage,e,floor) end
    return disableOn(input,row,roles.disable,e,floor),0
end

-- What an attack's removal (combat-intent/removal.lua) adds on e, over the rounds left after the
-- cast: below zero when it frees e of more than it opens.
local function stripped(input,spell,e)
    if not reaches(spell.roles.removal) then return 0 end
    local horizon=number(input.mind.horizon) and input.mind.horizon or 18
    local cast=(number(spell.speed) and spell.speed or 0)*removal.speedSeconds
    return (removal.on(input,spell,e,math.max(0,horizon-cast)/removal.ROUND))
end

-- Lasting areas (see the top). Whether the spell's area is one the profile counts by its
-- explosions.
local function lastingArea(input,spell)
    local a=spell.area
    return input.mind.clouds~='once' and type(a)=='table' and number(a.explosions) and a.explosions>1 and
        number(a.every) and a.every>0 or false
end
-- The hits of a schedule (the first at first seconds after the landing, then one every step up
-- to the last explosion) during [from, to].
local function hitsIn(first,step,last,from,to)
    to=math.min(to,last)
    if to<from then return 0 end
    local lo=math.max(0,math.ceil((from-first)/step-1e-9))
    local hi=math.floor((to-first)/step+1e-9)
    return math.max(0,hi-lo+1)
end
-- Whether e cannot walk out of a cloud (zones.rooted), unless it only sleeps and the cloud's
-- damage wakes it.
local SLEEP=targeting.STATE.sleeping
local function stuck(e,damages)
    if not zones.rooted(e) then return false end
    if damages and e.rooted~=true and not (number(e.held) and e.held>0) and targeting.has(e.state,SLEEP) and
        not targeting.has(e.state,targeting.DISABLED-SLEEP) then return false end
    return true
end
-- The chance e stays in a cloud that hurts it: what the group has seen, after the prior.
local function stayChance(input,e)
    local s=type(input.stays)=='table' and input.stays[e.id] or nil
    local stay=type(s)=='table' and number(s.stay) and s.stay>0 and s.stay or 0
    local left=type(s)=='table' and number(s.left) and s.left>0 and s.left or 0
    return (M.stayPrior*M.stayWeight+stay)/(M.stayWeight+stay+left)
end
-- role with n times its amounts: the damage of n explosions together.
local function times(role,n)
    local r={}
    for k,v in pairs(role) do r[k]=v end
    r.types={}
    for label,v in pairs(type(role.types)=='table' and role.types or {}) do r.types[label]=number(v) and v*n or v end
    if number(role.percent) then r.percent=role.percent*n end
    return r
end
-- The share of casts of role that land on e and hold: magic resistance, the saving throw and the
-- effect's own chance.
local function sticks(role,e)
    return landing(role,e)*(1-M.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
end
-- What a lasting area is worth on e inside it at center: the worth of its kind of attack over the
-- explosions e is expected to sit through, the hit points it is expected to take, and for the log
-- how many it would sit through staying and walking out and the chance it stays. ctx keeps the
-- rest of the fight for one choice; walk: the seconds the caster walks into range first.
local function lastingOn(input,row,spell,kind,roles,e,center,ctx,walk)
    local a=spell.area
    local caster=input.frame.self
    local every=a.every
    local step=every*math.max(1,math.ceil(zones.period({every=every,spell=spell})/every-1e-9))
    local first=a.skipFirst and every or 0
    local last=first+(a.explosions-1)*every
    ctx.rest=ctx.rest or threat.rest(input.frame,number(input.mind.fightCap) and input.mind.fightCap or 60)
    local cast=(number(spell.speed) and spell.speed or 0)*zones.speedSeconds+(number(caster.aura) and caster.aura>0 and caster.aura or 0)+
        (number(walk) and walk>0 and walk or 0)
    local upto=math.max(first,ctx.rest-cast)
    local stay=hitsIn(first,step,last,0,upto)
    local leave,walk=stay,0
    if not stuck(e,reaches(roles.damage)) then
        local speed=number(e.speed) and e.speed>0 and e.speed or zones.walkSpeed
        walk=math.max(0,a.radius-targeting.distance(a.cone and caster or center,e)+zones.margin)/speed
        leave=hitsIn(first,step,last,0,math.min(upto,M.react+walk))
    end
    local stopped=targeting.stopped(e,spell)
    local floor=targeting.floor(e,roles)
    local function over(n)
        n=n-stopped
        if n<=0 then return 0,0 end
        if kind=='damage' then return damageOn(input,row,times(roles.damage,n),e,floor) end
        local c=math.min(1,sticks(roles.disable,e))
        if c<=0 then return 0,0 end
        return disableOn(input,row,roles.disable,e,floor)*(1-(1-c)^n)/c,0
    end
    local ws,hs=over(stay)
    local wl,hl=over(leave)
    if walk>0 then wl=wl+walk/M.fullSeconds*(0.5+0.5*targeting.health(e)) end
    local q=input.mind.clouds=='best' and 0 or stayChance(input,e)
    local wb,hb=ws,hs
    if wl<ws then wb,hb=wl,hl end
    return q*ws+(1-q)*wb,q*hs+(1-q)*hb,{id=e.id,stay=stay,leave=leave,q=q,stopped=stopped>0 and stopped or nil}
end
-- Whether an area of the caster's own does nothing to friend f in it (the caster or an ally): its
-- spell protections stop every explosion, or the spell's roles for f's kind of creature, judged
-- on all their conditions, hold no damage, disable or condition that gets through (zones.hit
-- weighs it as it would a zone around f).
local function spared(input,spell,f)
    if type(f)~='table' then return false end
    local worth,first=zones.hit(input,{spell=spell,side='friend',filter=spell.area.filter},f)
    if first>=(number(spell.area.explosions) and spell.area.explosions or 1) then return true end
    local _,key=spells.view(spell,targeting.holds(f))
    if type(key)~='string' or key:find('?',1,true) then return false end
    return worth<=0
end

-- Interrupting (see the top). When the cast c of an enemy (e.cast: its speed, and timer, the count
-- of its casting aura, -1 while the aura is free) can be broken, in seconds from now: from start
-- until finish; nil when its casting is over, instant or unknown. A count past the casting time is
-- the last cast's aura, which the cast waits for: it begins casting when the aura frees. With the
-- aura free the cast has not begun (it may still walk into range): all its casting is ahead.
function M.castWindow(c)
    if type(c)~='table' or not number(c.speed) or c.speed<=0 then return nil end
    local casting=c.speed*zones.speedSeconds
    local timer=number(c.timer) and c.timer or -1
    if timer<0 then return 0,casting end
    local since=timer/M.ticksPerSecond
    if since<=casting+M.castSlack then
        if since>=casting then return nil end
        return 0,casting-since
    end
    local start=math.max(0,(M.auraTicks-timer)/M.ticksPerSecond)
    return start,start+casting
end
-- Whether the creature sees the chance a tactic needs wit for in this decision: input.tactical once
-- the decision has drawn it (M.notices), else whether its chance (mind.tactics) is a half or more.
function M.tactical(input)
    if input.tactical~=nil then return input.tactical==true end
    local p=number(input.mind.tactics) and input.mind.tactics or 1
    return p>=0.5
end
-- Whether a jump into the fight is there to notice (M.jumpOptions): the creature walks to enemies
-- for its melee weapon, has a teleport ready and sees an enemy a jump's walk away.
local function leaping(input)
    if type(input.teleports)~='table' or #input.teleports==0 or input.mind.chase~=true then return false end
    local caster=input.frame.self
    if type(caster.weapon)~='table' or caster.weapon.ranged then return false end
    for _,e in ipairs(input.frame.enemies) do
        local d=type(e)=='table' and targeting.distance(caster,e) or math.huge
        if d<math.huge and d-M.landShort>=search.jumpMin then return true end
    end
    return false
end
-- Draws once a decision whether the creature sees a tactic's chance (mind.tactics), and only when
-- there is one to see (an enemy casts, or a jump into the fight is there), so that other decisions
-- draw nothing. Without input.rng: when its chance is a half or more.
function M.notices(input)
    local p=number(input.mind.tactics) and input.mind.tactics or 1
    if p>=1 then return true end
    if p<=0 then return false end
    local any=false
    for _,e in ipairs(input.frame.enemies) do
        if type(e)=='table' and type(e.cast)=='table' then any=true;break end
    end
    if not any and not leaping(input) then return false end
    local rng=input.rng
    if not rng then return p>=0.5 end
    return rng:nextInt(1,1000)<=math.floor(p*1000+0.5)
end
-- What breaking e's spell is worth to an attack whose damage lands how.at seconds from now with
-- chance how.chance, or whose hits come how.rate a round from how.from seconds on, less how.absorbed
-- hits that Mirror Images and Stoneskin take first: mind.interrupt for each level of the spell, times
-- the chance damage lands while the casting runs. Nothing when the creature does not see the chance
-- (M.tactical).
function M.interruption(input,e,how)
    local c=type(e)=='table' and e.cast or nil
    local per=number(input.mind.interrupt) and input.mind.interrupt or 0
    if type(c)~='table' or per<=0 or not number(c.level) or c.level<=0 or not M.tactical(input) then return 0 end
    local start,finish=M.castWindow(c)
    if not start then return 0 end
    local p
    if number(how.rate) then
        local from=math.max(number(how.from) and how.from or 0,start)
        local span=math.min(finish,from+M.ROUND)-from
        if span<=0 then return 0 end
        local n=how.rate*span/M.ROUND-(number(how.absorbed) and how.absorbed or 0)
        if n<=0 then return 0 end
        p=1-math.exp(-n)
    else
        if not number(how.at) or how.at<start or how.at>=finish then return 0 end
        p=clamp(number(how.chance) and how.chance or 0,0,1)
    end
    return per*c.level*p
end
-- The chance a damage role hurts e at all: magic resistance, a saving throw that keeps all of it off
-- (one for half still hurts) and the effect's own chance.
local function hurts(role,e)
    local save=role.saveForHalf and 0 or M.saveChance(role,e)
    return landing(role,e)*(1-save)*clamp(number(role.chance) and role.chance or 1,0,1)
end

-- One option: the spell aimed at a creature or a point, its worth, cost and score, or nil
-- and why it is no option. ctx keeps what one choice works out once (the rest of the fight). An
-- aim with a walk into range must keep the caster out of its area where the walk ends, and the
-- walk comes first and lowers the worth as a walk to a melee enemy does (weapons.paced). Damage on
-- a casting enemy adds what breaking its spell is worth (interrupt), once the walk has lowered the
-- rest: the damage lands after the casting aura, the walk and the casting, and an area that skips
-- its first explosion a round of explosions later.
local function evaluate(input,row,spell,kind,mode,aim,ctx)
    local frame=input.frame
    local caster=frame.self
    local a=spell.area
    local worth,hits,slack,expected=0,{},0,{}
    local sat
    local walk=number(aim.walk) and aim.walk>0 and aim.walk or nil
    local stop=0
    local land=(number(caster.aura) and caster.aura>0 and caster.aura or 0)+(walk or 0)+
        (number(spell.speed) and spell.speed or 0)*zones.speedSeconds+
        (type(a)=='table' and a.skipFirst and number(a.every) and a.every or 0)
    local function breaks(roles,e,hp)
        if kind=='damage' and number(hp) and hp>0 then
            stop=stop+M.interruption(input,e,{at=land,chance=hurts(roles.damage,e)})
        end
    end
    if mode=='creature' then
        local e=aim.enemy
        local roles,why=affects(spell,e,kind)
        if not roles then return nil,why end
        if kind=='disable' and targeting.disabled(e) then return nil,'disabled' end
        worth,expected[e.id]=worthOn(input,row,kind,roles,e)
        worth=worth+stripped(input,spell,e)
        breaks(roles,e,expected[e.id])
        hits[1]=e.id
    else
        local center=aim.point
        if a.line or a.rectangle then
            -- An enemies-only line or box: counted for the creature aimed at only.
            local e=aim.enemy
            local roles=e and affects(spell,e,kind)
            if not roles then return nil,'shape' end
            worth,expected[e.id]=worthOn(input,row,kind,roles,e)
            worth=worth+stripped(input,spell,e)
            breaks(roles,e,expected[e.id])
            hits[1]=e.id
        else
            local inside,near=shape(spell,caster,center,aim.point)
            if a.filter~='enemies' then
                for _,ally in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
                    if targeting.alive(ally) and near(ally) and not spared(input,spell,ally) then return nil,'ally-in-area' end
                end
                -- A cone starts at the caster; any other area must keep it out where it casts
                -- from, unless it does nothing to the caster.
                if not a.cone then
                    local at=walk and castFrom(caster,center,spell) or caster
                    local within
                    if mode=='self-area' then within=not a.skipsCenter else within=near(at) end
                    if within and not spared(input,spell,at) then return nil,'caster-in-area' end
                end
            end
            local lasting=lastingArea(input,spell)
            if lasting then sat={} end
            -- How far the nearest hit enemy is from the area's edge: an area that holds its
            -- enemies well inside still hits them after a step.
            slack=math.huge
            for _,e in ipairs(frame.enemies) do
                local roles=targeting.alive(e) and inside(e) and affects(spell,e,kind,lasting)
                if roles then
                    local w,hp,seen
                    if lasting then w,hp,seen=lastingOn(input,row,spell,kind,roles,e,center,ctx,walk)
                    else w,hp=worthOn(input,row,kind,roles,e) end
                    w=w+stripped(input,spell,e)
                    if w>0 then
                        worth=worth+w;hits[#hits+1]=e.id;expected[e.id]=hp
                        breaks(roles,e,hp)
                        if seen then sat[#sat+1]=seen end
                        slack=math.min(slack,a.radius-targeting.distance(a.cone and caster or center,e))
                    end
                end
            end
            if slack==math.huge then slack=0 end
        end
    end
    if worth<=0 then return nil,'no-worth' end
    if walk then worth=worth*weapons.paced(walk) end
    worth=worth+stop
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=input.mind.economy*slots(input)*M.costPerLevel*level
    local option={resref=row.resref,kind=kind,mode=mode,worth=worth,cost=cost,score=worth-cost,hits=hits,slack=slack,
        speed=number(spell.speed) and spell.speed or 0,release=spell.release or nil,walk=walk,
        interrupt=stop>0 and stop or nil}
    if kind=='damage' then option.expected=expected end
    if sat and #sat>0 then option.lasting=sat end
    if aim.enemy and (mode=='creature' or mode=='creature-area') then option.target=aim.enemy.id
    elseif mode=='point-area' then option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)}
    elseif mode=='self-area' then option.self=true
    elseif aim.enemy then option.target=aim.enemy.id end
    return option
end

-- What the hit of touch charge w does to e (the strike's roles for e's kind of creature): the
-- worth of its damage and disable together, and the hit points it is expected to take. A strike
-- that keeps e at one hit point or more (a minimum it puts on e) cannot kill, nor can one while
-- e's own minimum holds.
local function strikeOn(input,row,w,e)
    local roles=spells.view(w.strike,targeting.holds(e))
    if type(roles)~='table' then return 0,0 end
    local own=roles.protection
    local spare=type(own)=='table' and type(own.kinds)=='table' and own.kinds.minimumHp and
        type(own.who)=='table' and own.who.target and true or false
    local floor=math.max(spare and 1 or 0,targeting.floor(e,roles))
    local worth,expected=0,0
    if reaches(roles.damage) then worth,expected=damageOn(input,row,roles.damage,e,floor) end
    if reaches(roles.disable) then worth=worth+disableOn(input,row,roles.disable,e,floor) end
    return worth,expected
end
-- Whether weapons are out for the caster: its own Time Stop or Improved Alacrity.
local function weaponsOut(input)
    return openers.ownStop(input)~=nil or input.frame.self.alacrity==true
end

-- Touch options of one ready spell: cast on the caster, aimed at each enemy in reach the charge
-- would work on. Worth: the hit's worth times the chance to hit, and on a casting enemy what
-- breaking its spell is worth when the strike comes after the casting aura and the casting. Cost:
-- the spell's level, and the caster's hit points lost to the weapons around the target while it
-- strikes, times caution.
local function touchOptions(input,row,spell,w,out,reject)
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local ahead=(number(caster.aura) and caster.aura>0 and caster.aura or 0)+
        (number(spell.speed) and spell.speed or 0)*zones.speedSeconds
    for _,e in ipairs(frame.enemies) do
        local ok,why=touch.reachable(caster,e,mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,row,w,e)
            if worth>0 then
                local p=touch.hitChance(caster,e,w)
                local stop=expected>0 and M.interruption(input,e,{from=ahead,rate=p}) or 0
                local exposure=maxHp and mind.caution*touch.exposure(frame,e)*touch.exposedRounds/maxHp or 0
                local cost=mind.economy*slots(input)*M.costPerLevel*level+exposure
                local value=worth*p+stop
                out[#out+1]={resref=row.resref,kind='touch',mode='self',self=true,target=e.id,worth=value,
                    cost=cost,score=value-cost,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},
                    speed=number(spell.speed) and spell.speed or 0,item=w.item,interrupt=stop>0 and stop or nil}
            else reject('no-worth') end
        else reject(why) end
    end
end

-- The worth of hits of weapon arms on e (hits: those expected, over one round or more), and the
-- hit points e is expected to take. A hit deals the weapon's own damage, which neither magic
-- resistance nor a save lessens, and what it casts or applies, which both do; no spell
-- protection stops the weapon, one against what its hit casts stops that part. The hits kill
-- when those expected reach those needed, as likely as the last one lands (two swings that each
-- hit four times in five, needing both: 0.6), unless e's minimum holds against them
-- (targeting.floor): then they take what it has above it. The hit's disable counts as likelier
-- the more hits land.
local function hitsOn(input,arms,hits,e)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hits) or hits<=0 or not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    local per=number(arms.damage) and arms.damage>0 and arms.damage*resisted(e,weapons.DAMAGE[arms.damageType] or '') or 0
    local roles=type(arms.strike)=='table' and spells.view(arms.strike,targeting.holds(e)) or nil
    if type(roles)~='table' or targeting.protected(e,arms.strike) then roles=nil end
    local floor=targeting.floor(e,roles)
    if roles and reaches(roles.damage) then
        local role=roles.damage
        local each=0
        for label,v in pairs(type(role.types)=='table' and role.types or {}) do
            if number(v) then each=each+v*resisted(e,label) end
        end
        local save=M.saveChance(role,e)
        per=per+each*landing(role,e)*(role.saveForHalf and 1-save/2 or 1-save)
    end
    local worth,expected=0,0
    if per>0 and hp>floor then
        expected=math.min(hits*per,hp-floor)
        worth=expected/maxHp
        if floor<=0 then worth=worth+input.mind.killBonus*clamp(hits-math.ceil(hp/per)+1,0,1) end
        local plan=input.plan
        if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
        worth=worth*orders.favour(input,e)
    end
    if roles and reaches(roles.disable) then
        worth=worth+disableOn(input,{resref=arms.item or ''},roles.disable,e,floor)*math.min(1,hits)
    end
    return worth,expected
end

-- Options of one ready spell that conjures a weapon (arms, combat-intent/weapons.lua): cast on
-- the caster, worth the hits the weapon deals in the rounds after, as many as it lasts within
-- the horizon, at the enemy in its reach where they are worth most. Cost: the spell's level, and
-- for a melee weapon the hit points lost standing next to that enemy those rounds, times caution.
local function armOptions(input,row,spell,arms,out,reject)
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    local horizon=(number(mind.horizon) and mind.horizon or 18)/6
    local rounds=math.min(number(arms.rounds) and arms.rounds or horizon,horizon)
    if rounds<=0 then reject('no-worth');return end
    local best,target,expected=0,nil,0
    for _,e in ipairs(frame.enemies) do
        local ok,why=weapons.reachable(caster,e,mind,arms)
        if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
        if ok then
            local worth,hp=hitsOn(input,arms,weapons.hits(arms.apr,arms.thac0,e)*rounds,e)
            if worth>best or (worth==best and worth>0 and e.id<target) then best,target,expected=worth,e.id,hp end
        else reject(why) end
    end
    if not target then reject('no-worth');return end
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=mind.economy*slots(input)*M.costPerLevel*level
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    if not arms.ranged and maxHp then
        for _,e in ipairs(frame.enemies) do
            if e.id==target then cost=cost+mind.caution*weapons.exposure(frame,e)*rounds/maxHp end
        end
    end
    out[#out+1]={resref=row.resref,kind='arm',mode='self',self=true,target=target,worth=best,cost=cost,
        score=best-cost,hits={target},slack=0,expected={[target]=expected},
        speed=number(spell.speed) and spell.speed or 0,item=arms.item}
end

-- The strike of the touch charge the caster holds (frame.self.charge, a weapon entry): at the
-- enemy in reach where the hit is worth most times its chance to land, with what breaking a casting
-- enemy's spell is worth, or nil; an order to always attack an enemy keeps it there while it can
-- strike that enemy (combat-intent/orders.lua). No minimum: the charge is spent already.
-- rejected (a table, optional) counts why each enemy got no strike: 'strike-' and the reason.
function M.strike(input,rejected)
    local function reject(why) if rejected then rejected['strike-'..why]=(rejected['strike-'..why] or 0)+1 end end
    local caster=input.frame.self
    local w=caster.charge
    if type(w)~='table' then return nil end
    if type(w.strike)~='table' then reject('unread');return nil end
    if weaponsOut(input) then reject('weapons-out');return nil end
    local list={}
    for _,e in ipairs(input.frame.enemies) do
        local ok,why=touch.reachable(caster,e,input.mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,{resref=w.spell or w.item},w,e)
            local p=touch.hitChance(caster,e,w)
            local stop=expected>0 and M.interruption(input,e,{from=0,rate=p}) or 0
            local score=worth*p+stop
            if score>0 then
                list[#list+1]={resref=w.item,spell=w.spell,kind='strike',mode='creature',target=e.id,worth=score,cost=0,
                    score=score,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},speed=0,interrupt=stop>0 and stop or nil}
            else reject('no-worth') end
        else reject(why or 'unknown') end
    end
    local best
    for _,c in ipairs((orders.keep(input,list,{}))) do
        if not best or c.score>best.score or (c.score==best.score and c.target<best.target) then best=c end
    end
    return best
end

-- Where the spell can be aimed: enemies it can reach for creature spells; for point areas each
-- such enemy's spot and the middle of the enemies around it; the caster for its own area. An aim
-- beyond the spell's range carries the seconds of the walk into range (walk).
local function aims(input,spell,mode)
    local frame=input.frame
    local caster=frame.self
    local out={}
    if mode=='self-area' then
        out[1]={point={x=caster.x,y=caster.y}}
        if spell.area.cone then out={} end
        return out
    end
    local function add(aim,walk)
        if not walk then return end
        if walk>0 then aim.walk=walk end
        out[#out+1]=aim
    end
    for _,e in ipairs(frame.enemies) do
        if mode=='point-area' then
            if targeting.alive(e) and number(e.x) and number(e.y) then
                local p={x=e.x,y=e.y}
                add({point=p,enemy=e},approach(caster,p,spell))
                local sx,sy,n=0,0,0
                for _,o in ipairs(frame.enemies) do
                    if targeting.alive(o) and number(o.x) and number(o.y) and targeting.distance(e,o)<=spell.area.radius then
                        sx,sy,n=sx+o.x,sy+o.y,n+1
                    end
                end
                if n>1 then
                    local m={x=sx/n,y=sy/n}
                    add({point=m},approach(caster,m,spell))
                end
            end
        else
            local ok,_,walk=aimable(caster,e,spell)
            if ok then add({enemy=e,point={x=e.x,y=e.y}},walk) end
        end
    end
    return out
end

local function better(a,b)
    if a.score~=b.score then return a.score>b.score end
    if a.slack~=b.slack then return a.slack>b.slack end
    if a.resref~=b.resref then return a.resref<b.resref end
    local ta,tb=a.target or -1,b.target or -1
    if ta~=tb then return ta<tb end
    local pa,pb=a.point or {x=-1,y=-1},b.point or {x=-1,y=-1}
    if pa.x~=pb.x then return pa.x<pb.x end
    return pa.y<pb.y
end

-- Whether an option is aimed at a creature it counts. An area aimed at an enemy the spell can
-- take no further (one already held, for a hold) only reaches the enemies around it.
local function centred(o)
    if not o.target then return false end
    for _,h in ipairs(o.hits) do if h==o.target then return true end end
    return false
end
-- Of two aims of one spell that hit the same enemies: the one centred on a creature it counts,
-- then the one holding its enemies furthest inside.
local function preferred(a,b)
    local ca,cb=centred(a),centred(b)
    if ca~=cb then return ca end
    return better(a,b)
end

-- Every option the caster has, best first. Aims of one spell that hit the same enemies are one
-- option, so a draw among near-best options weighs each choice once. rejected (a table,
-- optional) counts why the ready attack spells gave none: out-of-reach (no enemy in range or a
-- walk away from it), or evaluate's reason per aim.
function M.options(input,rejected)
    local out,ctx={},{}
    local function reject(why) if rejected then rejected[why]=(rejected[why] or 0)+1 end end
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local spell=row.spell
            local kind,mode=M.attack(spell)
            local w=not kind and input.mind.touch and touch.charge(spell)
            if w and not weaponsOut(input) and type(input.frame.self.charge)~='table' then
                touchOptions(input,row,spell,w,out,reject)
            end
            local arms=not kind and not w and input.mind.weapons and weapons.conjured(spell,input.frame.self)
            if arms and not weaponsOut(input) and not input.frame.self.magicItem then
                armOptions(input,row,spell,arms,out,reject)
            end
            if kind then
                local seen,same={},{}
                local list=aims(input,spell,mode)
                if #list==0 then reject('out-of-reach') end
                for _,aim in ipairs(list) do
                    local option,why=evaluate(input,row,spell,kind,mode,aim,ctx)
                    if option then
                        local key=tostring(option.target)..':'..(option.point and option.point.x..','..option.point.y or '')
                        if not seen[key] then
                            seen[key]=true
                            local ids={}
                            for n,h in ipairs(option.hits) do ids[n]=tostring(h) end
                            table.sort(ids)
                            local set=table.concat(ids,',')
                            local at=same[set]
                            if not at then out[#out+1]=option;same[set]=#out
                            elseif preferred(option,out[at]) then out[at]=option end
                        end
                    else reject(why or 'unknown') end
                end
            end
        end
    end
    table.sort(out,better)
    return out
end

-- Attacks with the weapon in the caster's hand (frame.self.weapon, arms): at each enemy it
-- reaches and can hurt, best first. Worth: a round of its hits, for melee as much of it as counts
-- for a round after the walk to the enemy (weapons.paced; a creature that chases walks to any
-- enemy it sees, weapons.reach), and on a casting enemy what breaking its spell is worth with the
-- hits that come after the walk; cost: for melee, the hit points the caster loses to the weapons
-- around the target that round, times caution. Not while the caster holds a touch charge (the
-- strike decides where that goes), in its own Time Stop or under Improved Alacrity.
function M.weaponOptions(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected[why]=(rejected[why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    local arms=caster.weapon
    if type(arms)~='table' or not number(arms.damage) or type(caster.charge)=='table' or weaponsOut(input) then return out end
    local mind=input.mind
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    for _,e in ipairs(frame.enemies) do
        local ok,why=weapons.reachable(caster,e,mind,arms)
        if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
        if ok then
            local hits,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
            local worth,expected=hitsOn(input,arms,hits,e)
            if worth>0 then
                local cost,walk=0,0
                if not arms.ranged then
                    walk=weapons.walk(caster,e)
                    worth=worth*weapons.paced(walk)
                    if maxHp then cost=mind.caution*weapons.exposure(frame,e)/maxHp end
                end
                local stop=expected>0 and M.interruption(input,e,{from=walk,rate=raw,absorbed=absorbed}) or 0
                worth=worth+stop
                out[#out+1]={resref=arms.item or 'WEAPON',kind='weapon',mode='creature',target=e.id,worth=worth,
                    cost=cost,score=worth-cost,hits={e.id},slack=0,expected={[e.id]=expected},speed=0,
                    melee=not arms.ranged or nil,walk=walk>0 and walk or nil,interrupt=stop>0 and stop or nil}
            else reject(hits<=0 and 'absorbed' or 'no-worth') end
        else reject(why) end
    end
    table.sort(out,better)
    return out
end

-- Jumps into the fight (see the top), best first: for each enemy the weapon in hand could hit in
-- melee a long walk away, the teleport search.jump picks for the walk to a spot landShort short of
-- the enemy on the way, cast at that spot or as far toward it as the teleport reaches. Worth: a
-- round of the weapon's hits on the enemy as weaponOptions counts it, paced by the casting and any
-- walk left after landing; on a casting enemy what breaking its spell is worth with the hits that
-- come after the casting aura, the casting and that walk. Cost: the teleport's level as for a spell,
-- and the hit points lost standing next to the enemy, times caution. Not for a creature that does
-- not chase, cannot walk or holds a touch charge, in its own Time Stop or under Improved Alacrity,
-- or that does not see the tactic (M.tactical). rejected (a table, optional) counts why an enemy
-- got no jump: 'jump-' and the reason.
function M.jumpOptions(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected['jump-'..why]=(rejected['jump-'..why] or 0)+1 end end
    local frame=input.frame
    local caster=frame.self
    local arms=caster.weapon
    local mind=input.mind
    if type(input.teleports)~='table' or #input.teleports==0 or mind.chase~=true then return out end
    if type(arms)~='table' or not number(arms.damage) or arms.ranged or type(caster.charge)=='table' or
        weaponsOut(input) or caster.rooted==true then return out end
    if not M.tactical(input) then reject('unnoticed');return out end
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    local aura=number(caster.aura) and caster.aura>0 and caster.aura or 0
    for _,e in ipairs(frame.enemies) do
        local ok,why=weapons.reachable(caster,e,mind,arms)
        if ok and weapons.immuneTo(e,arms) then ok,why=false,'weapon-immunity' end
        local d=ok and targeting.distance(caster,e) or 0
        if ok and d-M.landShort<search.jumpMin then ok,why=false,'near' end
        if ok then
            local walk=d-M.landShort
            local spot={x=caster.x+(e.x-caster.x)*walk/d,y=caster.y+(e.y-caster.y)*walk/d}
            local o,at=search.jump(input,spot,walk,true)
            local hits,raw,absorbed=weapons.hits(arms.apr,arms.thac0,e)
            local worth,expected=hitsOn(input,arms,hits,e)
            if o and worth>0 then
                local landed={}
                for k,v in pairs(caster) do landed[k]=v end
                landed.x,landed.y=at.x,at.y
                local cast=(number(o.speed) and o.speed or 0)*zones.speedSeconds
                local rest=weapons.walk(landed,e)
                worth=worth*weapons.paced(cast+rest)
                local stop=expected>0 and M.interruption(input,e,{from=aura+cast+rest,rate=raw,absorbed=absorbed}) or 0
                worth=worth+stop
                local level=number(o.level) and o.level or 1
                local cost=mind.economy*slots(input)*M.costPerLevel*level
                if maxHp then cost=cost+mind.caution*weapons.exposure(frame,e)/maxHp end
                out[#out+1]={resref=o.resref,kind='teleport',mode='point',point=at,target=e.id,worth=worth,cost=cost,
                    score=worth-cost,hits={e.id},slack=0,speed=number(o.speed) and o.speed or 0,level=level,
                    innate=o.innate,melee=true,interrupt=stop>0 and stop or nil}
            elseif not o then reject('no-teleport')
            else reject(hits<=0 and 'absorbed' or 'no-worth') end
        else reject(why) end
    end
    table.sort(out,better)
    return out
end

-- The input without its releases (sequencers and triggers): under Improved Alacrity SCS keeps
-- them for later (caster_definitions.ssl), and so does the engine.
function M.unreleased(input)
    local kept,left=false,{}
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and type(row.spell)=='table' and row.spell.release then kept=true else left[#left+1]=row end
    end
    if not kept then return input end
    local view={}
    for k,v in pairs(input) do view[k]=v end
    view.spells=left
    return view
end

-- The input as the caster sees it in its own Time Stop: what it cast in the stop
-- (input.stopCasts: {kind, hits, expected}) lands when time resumes, so the enemies it disabled
-- count as held and the hit points it is expected to have taken come off (hpNow keeps the hit
-- points they have now). The same input outside its own stop.
function M.frozen(input)
    if not openers.ownStop(input) or type(input.stopCasts)~='table' or #input.stopCasts==0 then return input end
    local held,lost={},{}
    for _,cast in ipairs(input.stopCasts) do
        if type(cast)=='table' then
            if cast.kind=='disable' and type(cast.hits)=='table' then
                for _,id in ipairs(cast.hits) do held[id]=true end
            end
            if type(cast.expected)=='table' then
                for id,hp in pairs(cast.expected) do if number(hp) then lost[id]=(lost[id] or 0)+hp end end
            end
        end
    end
    local enemies={}
    for n,e in ipairs(input.frame.enemies) do
        if type(e)=='table' and (held[e.id] or lost[e.id]) then
            local c={}
            for k,v in pairs(e) do c[k]=v end
            if held[e.id] then c.held=math.max(number(c.held) and c.held or 0,1);c.taken=true end
            if lost[e.id] and number(c.hp) then c.hpNow=c.hp;c.hp=c.hp-lost[e.id] end
            enemies[n]=c
        else enemies[n]=e end
    end
    local frame,view={},{}
    for k,v in pairs(input.frame) do frame[k]=v end
    frame.enemies=enemies
    for k,v in pairs(input) do view[k]=v end
    view.frame=frame
    return view
end

-- The enemies of the input's frame by id.
local function placed(input)
    local at={}
    for _,e in ipairs(input.frame.enemies) do if type(e)=='table' and e.id~=nil then at[e.id]=e end end
    return at
end

-- Doing nothing for the given seconds, then deciding again.
function M.wait(seconds)
    return {resref='WAIT',kind='wait',mode='none',worth=0,cost=0,score=0,hits={},slack=0,speed=0,
        seconds=number(seconds) and math.max(0,seconds) or 0}
end

-- The choice without a way out of the zones (M.decide).
local function pick(input)
    local mind=input.mind
    local rejected={}
    local zoned=zones.active(input)
    if mind.touch then
        local strike=M.strike(input,rejected)
        if strike then
            if zoned then zones.adjust(input,strike,placed(input)) end
            return strike,'strike',{strike}
        end
    end
    local aura=input.frame.self.aura
    aura=number(aura) and aura>0 and aura or 0
    local busy=aura>M.auraLead
    if mind.openers then
        local opener=openers.choose(input)
        if opener then
            if busy then return M.wait(aura-M.auraLead),'aura',{opener} end
            return opener,'opener',{opener}
        end
    end
    input=M.frozen(input)
    if input.frame.self.alacrity==true then input=M.unreleased(input) end
    local options=M.options(input,rejected)
    for _,o in ipairs(defence.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(care.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(summons.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(removal.options(input,rejected,function(s) return M.attack(s)~=nil end)) do options[#options+1]=o end
    if mind.weapons then
        for _,o in ipairs(M.jumpOptions(input,rejected)) do options[#options+1]=o end
    end
    -- A weapon attack spends nothing: it needs no minimum worth, and it is taken over a spell
    -- only when it is worth more.
    local swings=mind.weapons and M.weaponOptions(input,rejected) or {}
    if zoned then
        local at=placed(input)
        for _,o in ipairs(options) do zones.adjust(input,o,at) end
        for _,o in ipairs(swings) do zones.adjust(input,o,at) end
        table.sort(swings,better)
    end
    -- An order to always attack an enemy keeps the attacks on it while one reaches it.
    options,swings=orders.keep(input,options,swings)
    table.sort(options,better)
    local swing=swings[1]
    local function all()
        local list={}
        for _,o in ipairs(options) do list[#list+1]=o end
        for _,o in ipairs(swings) do list[#list+1]=o end
        table.sort(list,better)
        return list
    end
    -- Whether an attack is worth making at all: one that hurts the enemy for a creature that always
    -- attacks (what standing next to the enemy costs only chose the target), else one worth more
    -- than that cost.
    local value=swing and (mind.alwaysAttack and swing.worth or swing.score) or 0
    local swinging=swing~=nil and value>0
    -- While the aura runs, casts and drinks wait for it. An attack now holds the best of them back
    -- by the part of a round the aura leaves of the attack's round, and is made when it is worth
    -- more than that part of the best.
    if busy then
        local best=options[1] and number(options[1].score) and math.max(0,options[1].score) or 0
        if swinging and value-best*math.max(0,M.ROUND-aura)/M.ROUND>0 then return swing,'weapon',all() end
        return M.wait(aura-M.auraLead),'aura',all(),rejected
    end
    if #options==0 then
        if swinging then return swing,'weapon',all() end
        return M.wait(M.idle),'no-option',options,rejected
    end
    -- Under Improved Alacrity a slow spell waits while a quick one reaches the minimum worth
    -- (SCS's slow spells and its compromise).
    if input.frame.self.alacrity==true and number(mind.slowSpeed) then
        local quick={}
        for _,o in ipairs(options) do if not (number(o.speed) and o.speed>=mind.slowSpeed) then quick[#quick+1]=o end end
        if quick[1] and quick[1].score>=mind.minValue then options=quick end
    end
    local best=options[1]
    if best.score<mind.minValue then
        if swinging then
            -- A jump into the fight ends next to an enemy as the walk does, sooner: the best one is
            -- taken over the attack when it is worth more.
            for _,o in ipairs(options) do
                if o.kind=='teleport' and o.melee then
                    if o.score>swing.score then return o,'jump',all() end
                    break
                end
            end
            return swing,'weapon',all()
        end
        -- No attack is worth anything: the best that is worth something, rather than nothing.
        if best.score>0 then return best,'weak',options end
        return M.wait(M.idle),'nothing-good',options,rejected
    end
    if swing and swing.score>best.score then return swing,'weapon',all() end
    local rng=input.rng
    if not rng or rng:nextInt(1,1000)<=math.floor(mind.best*1000+0.5) then return best,'best',options end
    local floor=math.max(mind.minValue,best.score-math.abs(best.score)*mind.band)
    local pool={}
    for _,o in ipairs(options) do if o.score>=floor then pool[#pool+1]=o end end
    return pool[rng:nextInt(1,#pool)],'near-best',options
end

-- The attack, defence, heal or cure, summons, removal, opener, strike, weapon attack, jump into the
-- fight, way out of a zone or wait to do now, and why ('aura', 'no-option' or 'nothing-good' for a
-- wait; 'jump' for a jump taken over the attack it brings sooner), or nil and why for bad input; the options come along for the log, and with a wait for want of options the
-- count of reasons the ready spells gave none. Leaving costs no spell, only the seconds of the
-- walk: it comes first when it is worth more than that share of a round of the choice, or when the
-- pain drives a dull creature out (forced). Spell slots cost input.slots of their price,
-- M.slotShare's when it is not given. The creature's target order (input.ordered, false for none;
-- combat-intent/orders.lua) and whether it sees a tactic's chance (input.tactical, M.notices) are
-- worked out once, when not given; an attack on an enemy its order names is marked ordered.
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' or type(input.mind)~='table' then return nil,'bad-input',{} end
    local view={}
    for k,v in pairs(input) do view[k]=v end
    if view.slots==nil then view.slots=M.slotShare(input) end
    if view.ordered==nil then view.ordered=orders.of(view) or false end
    if view.tactical==nil then view.tactical=M.notices(view) end
    input=view
    local d,why,options,rejected=pick(input)
    if d and orders.on(input,d) then d.ordered=true end
    local escape=zones.active(input) and zones.escape(input) or nil
    if escape then
        local score=d and number(d.score) and d.score or 0
        if escape.forced or escape.worth>math.max(0,score)*escape.walk/zones.ROUND then
            local list={escape}
            for _,o in ipairs(type(options)=='table' and options or {}) do list[#list+1]=o end
            return escape,'escape',list
        end
    end
    return d,why,options,rejected
end
return M
