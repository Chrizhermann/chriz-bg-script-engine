-- The engine's own choice of an attack spell and its target or aim point for one caster (step
-- 3, second slice; Christopher's answers of 2026-10-18 are in the plan). Inputs are plain
-- values: the caster's perception frame with enemy details (adapters/eeex/sense.lua), its
-- ready and usable spells classified by combat-intent/spells.lua, the fight director's plan,
-- what it remembers about casts that had no effect, and its profile (combat-intent/mind.lua).
-- Nothing here touches the engine. Odd data drops one option, never the whole choice, and no
-- choice means SCS keeps the round.
--
-- Worth is counted in shares of an enemy taken out of the fight: the hit points a cast takes
-- (as a share of the enemy's maximum, no more than it has left), the worth of a kill, or the
-- chance and length of a disable. A spell's level costs a little, so small spells do small
-- jobs. An attack must reach the profile's minimum worth.
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
-- standing next to that enemy costs for melee. It spends nothing, so it needs no minimum worth:
-- when no spell reaches minValue, the engine attacks instead of leaving the round to SCS. A spell
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
-- adds what its removal is worth on each enemy it hits. The engine takes every round it has a
-- cast or a weapon attack for; SCS keeps none for spells of its own (its scripts never raise).
--
-- Danger zones (D3e, combat-intent/zones.lua): clouds and storms around the caster count in every
-- option. Harm from them can break a cast where it stands; a melee attack or a strike counts what
-- walking to its target and standing there does in them. A way out of a zone that hurts the
-- caster comes first when what leaving is worth beats the share of a round the walk takes from
-- the best other choice.
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

-- Whether e can be aimed at directly: alive, no sanctuary, seen, in range.
local function aimable(caster,e,spell)
    if not targeting.alive(e) then return false,'dead' end
    if number(e.sanctuary) and e.sanctuary>0 then return false,'sanctuary' end
    if targeting.has(e.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    local d=targeting.distance(caster,e)
    if d==math.huge then return false,'no-position' end
    if d>range(spell) then return false,'out-of-range' end
    return true
end
-- What the spell does to e, or nil and why it does not work on e: its roles for e's kind of
-- creature (spells.view) must hold the attack, and e's spell protections must not stop it.
local function affects(spell,e,kind)
    local roles,key=spells.view(spell,targeting.holds(e))
    if type(roles)~='table' or not reaches(roles[kind]) then
        return nil,type(key)=='string' and key:find('?',1,true) and 'unknown-filter' or 'filter'
    end
    if targeting.protected(e,spell) then return nil,'protected' end
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

-- The worth of a damage role on e (combat-intent/harm.lua), more on the group's focus, and the hit
-- points it is expected to take. With spare, e keeps at least one hit point (Harm cannot kill).
local function damageOn(input,row,role,e,spare)
    local worth,expected=harm.damage(role,e,input.mind.killBonus,spare)
    if expected<=0 then return 0,0 end
    local plan=input.plan
    if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    local still=remembered(input,row.resref,e,role)
    return worth*still,expected*still
end

-- The worth of a disable role on e (combat-intent/harm.lua): none on an enemy another member has
-- claimed for its disable.
local function disableOn(input,row,role,e)
    if targeting.disabled(e) then return 0 end
    local plan=input.plan
    local reserved=type(plan)=='table' and type(plan.reserved)=='table' and plan.reserved[e.id]
    if reserved and reserved~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    return harm.disable(role,e,input.mind.killBonus)*remembered(input,row.resref,e,role)
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
    if kind=='damage' then return damageOn(input,row,roles.damage,e) end
    return disableOn(input,row,roles.disable,e),0
end

-- What an attack's removal (combat-intent/removal.lua) adds on e, over the rounds left after the
-- cast: below zero when it frees e of more than it opens.
local function stripped(input,spell,e)
    if not reaches(spell.roles.removal) then return 0 end
    local horizon=number(input.mind.horizon) and input.mind.horizon or 18
    local cast=(number(spell.speed) and spell.speed or 0)*removal.speedSeconds
    return (removal.on(input,spell,e,math.max(0,horizon-cast)/removal.ROUND))
end

-- One option: the spell aimed at a creature or a point, its worth, cost and score, or nil
-- and why it is no option.
local function evaluate(input,row,spell,kind,mode,aim)
    local frame=input.frame
    local caster=frame.self
    local a=spell.area
    local worth,hits,slack,expected=0,{},0,{}
    if mode=='creature' then
        local e=aim.enemy
        local roles,why=affects(spell,e,kind)
        if not roles then return nil,why end
        if kind=='disable' and targeting.disabled(e) then return nil,'disabled' end
        worth,expected[e.id]=worthOn(input,row,kind,roles,e)
        worth=worth+stripped(input,spell,e)
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
            hits[1]=e.id
        else
            local inside,near=shape(spell,caster,center,aim.point)
            if a.filter~='enemies' then
                for _,ally in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
                    if targeting.alive(ally) and near(ally) then return nil,'ally-in-area' end
                end
                -- A cone starts at the caster; any other area must keep it out.
                if not a.cone then
                    if mode=='self-area' then
                        if not a.skipsCenter then return nil,'caster-in-area' end
                    elseif near(caster) then return nil,'caster-in-area' end
                end
            end
            -- How far the nearest hit enemy is from the area's edge: an area that holds its
            -- enemies well inside still hits them after a step.
            slack=math.huge
            for _,e in ipairs(frame.enemies) do
                local roles=targeting.alive(e) and inside(e) and affects(spell,e,kind)
                if roles then
                    local w,hp=worthOn(input,row,kind,roles,e)
                    w=w+stripped(input,spell,e)
                    if w>0 then
                        worth=worth+w;hits[#hits+1]=e.id;expected[e.id]=hp
                        slack=math.min(slack,a.radius-targeting.distance(a.cone and caster or center,e))
                    end
                end
            end
            if slack==math.huge then slack=0 end
        end
    end
    if worth<=0 then return nil,'no-worth' end
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=input.mind.economy*slots(input)*M.costPerLevel*level
    local option={resref=row.resref,kind=kind,mode=mode,worth=worth,cost=cost,score=worth-cost,hits=hits,slack=slack,
        speed=number(spell.speed) and spell.speed or 0,release=spell.release or nil}
    if kind=='damage' then option.expected=expected end
    if aim.enemy and (mode=='creature' or mode=='creature-area') then option.target=aim.enemy.id
    elseif mode=='point-area' then option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)}
    elseif mode=='self-area' then option.self=true
    elseif aim.enemy then option.target=aim.enemy.id end
    return option
end

-- What the hit of touch charge w does to e (the strike's roles for e's kind of creature): the
-- worth of its damage and disable together, and the hit points it is expected to take. A strike
-- that keeps e at one hit point or more (a minimum on e) cannot kill.
local function strikeOn(input,row,w,e)
    local roles=spells.view(w.strike,targeting.holds(e))
    if type(roles)~='table' then return 0,0 end
    local floor=roles.protection
    local spare=type(floor)=='table' and type(floor.kinds)=='table' and floor.kinds.minimumHp and
        type(floor.who)=='table' and floor.who.target and true or false
    local worth,expected=0,0
    if reaches(roles.damage) then worth,expected=damageOn(input,row,roles.damage,e,spare) end
    if reaches(roles.disable) then worth=worth+disableOn(input,row,roles.disable,e) end
    return worth,expected
end
-- Whether weapons are out for the caster: its own Time Stop or Improved Alacrity.
local function weaponsOut(input)
    return openers.ownStop(input)~=nil or input.frame.self.alacrity==true
end

-- Touch options of one ready spell: cast on the caster, aimed at each enemy in reach the charge
-- would work on. Worth: the hit's worth times the chance to hit. Cost: the spell's level, and the
-- caster's hit points lost to the weapons around the target while it strikes, times caution.
local function touchOptions(input,row,spell,w,out,reject)
    local frame=input.frame
    local caster=frame.self
    local mind=input.mind
    local maxHp=number(caster.maxHp) and caster.maxHp>0 and caster.maxHp or nil
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    for _,e in ipairs(frame.enemies) do
        local ok,why=touch.reachable(caster,e,mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,row,w,e)
            if worth>0 then
                local p=touch.hitChance(caster,e,w)
                local exposure=maxHp and mind.caution*touch.exposure(frame,e)*touch.exposedRounds/maxHp or 0
                local cost=mind.economy*slots(input)*M.costPerLevel*level+exposure
                out[#out+1]={resref=row.resref,kind='touch',mode='self',self=true,target=e.id,worth=worth*p,
                    cost=cost,score=worth*p-cost,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},
                    speed=number(spell.speed) and spell.speed or 0,item=w.item}
            else reject('no-worth') end
        else reject(why) end
    end
end

-- The worth of hits of weapon arms on e (hits: those expected, over one round or more), and the
-- hit points e is expected to take. A hit deals the weapon's own damage, which neither magic
-- resistance nor a save lessens, and what it casts or applies, which both do; no spell
-- protection stops the weapon, one against what its hit casts stops that part. The hits kill
-- when those expected reach those needed, as likely as the last one lands (two swings that each
-- hit four times in five, needing both: 0.6). The hit's disable counts as likelier the more hits
-- land.
local function hitsOn(input,arms,hits,e)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hits) or hits<=0 or not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    local per=number(arms.damage) and arms.damage>0 and arms.damage*resisted(e,weapons.DAMAGE[arms.damageType] or '') or 0
    local roles=type(arms.strike)=='table' and spells.view(arms.strike,targeting.holds(e)) or nil
    if type(roles)~='table' or targeting.protected(e,arms.strike) then roles=nil end
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
    if per>0 then
        expected=math.min(hits*per,hp)
        worth=expected/maxHp+input.mind.killBonus*clamp(hits-math.ceil(hp/per)+1,0,1)
        local plan=input.plan
        if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    end
    if roles and reaches(roles.disable) then
        worth=worth+disableOn(input,{resref=arms.item or ''},roles.disable,e)*math.min(1,hits)
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
-- enemy in reach where the hit is worth most times its chance to land, or nil. No minimum: the
-- charge is spent already.
-- rejected (a table, optional) counts why each enemy got no strike: 'strike-' and the reason.
function M.strike(input,rejected)
    local function reject(why) if rejected then rejected['strike-'..why]=(rejected['strike-'..why] or 0)+1 end end
    local caster=input.frame.self
    local w=caster.charge
    if type(w)~='table' then return nil end
    if type(w.strike)~='table' then reject('unread');return nil end
    if weaponsOut(input) then reject('weapons-out');return nil end
    local best
    for _,e in ipairs(input.frame.enemies) do
        local ok,why=touch.reachable(caster,e,input.mind)
        if ok then why=touch.blocked(e,w) end
        if ok and not why then
            local worth,expected=strikeOn(input,{resref=w.spell or w.item},w,e)
            local p=touch.hitChance(caster,e,w)
            local score=worth*p
            if score>0 and (not best or score>best.score or (score==best.score and e.id<best.target)) then
                best={resref=w.item,spell=w.spell,kind='strike',mode='creature',target=e.id,worth=score,cost=0,
                    score=score,hits={e.id},slack=0,hit=p,expected={[e.id]=expected*p},speed=0}
            end
            if score<=0 then reject('no-worth') end
        else reject(why or 'unknown') end
    end
    return best
end

-- Where the spell can be aimed: enemies it can reach for creature spells; for point areas each
-- such enemy's spot and the middle of the enemies around it; the caster for its own area.
local function aims(input,spell,mode)
    local frame=input.frame
    local caster=frame.self
    local out={}
    if mode=='self-area' then
        out[1]={point={x=caster.x,y=caster.y}}
        if spell.area.cone then out={} end
        return out
    end
    for _,e in ipairs(frame.enemies) do
        if mode=='point-area' then
            if targeting.alive(e) and number(e.x) and number(e.y) then
                local p={x=e.x,y=e.y}
                if targeting.distance(caster,p)<=range(spell) then out[#out+1]={point=p,enemy=e} end
                local sx,sy,n=0,0,0
                for _,o in ipairs(frame.enemies) do
                    if targeting.alive(o) and number(o.x) and number(o.y) and targeting.distance(e,o)<=spell.area.radius then
                        sx,sy,n=sx+o.x,sy+o.y,n+1
                    end
                end
                if n>1 then
                    local m={x=sx/n,y=sy/n}
                    if targeting.distance(caster,m)<=range(spell) then out[#out+1]={point=m} end
                end
            end
        elseif aimable(caster,e,spell) then
            out[#out+1]={enemy=e,point={x=e.x,y=e.y}}
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
-- optional) counts why the ready attack spells gave none: out-of-reach (no enemy in range), or
-- evaluate's reason per aim.
function M.options(input,rejected)
    local out={}
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
                    local option,why=evaluate(input,row,spell,kind,mode,aim)
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
-- reaches and can hurt, best first. Worth: a round of its hits; cost: for melee, the hit points
-- the caster loses to the weapons around the target that round, times caution. Not while the
-- caster holds a touch charge (the strike decides where that goes), in its own Time Stop or
-- under Improved Alacrity.
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
            local hits=weapons.hits(arms.apr,arms.thac0,e)
            local worth,expected=hitsOn(input,arms,hits,e)
            if worth>0 then
                local cost=0
                if not arms.ranged and maxHp then cost=mind.caution*weapons.exposure(frame,e)/maxHp end
                out[#out+1]={resref=arms.item or 'WEAPON',kind='weapon',mode='creature',target=e.id,worth=worth,
                    cost=cost,score=worth-cost,hits={e.id},slack=0,expected={[e.id]=expected},speed=0,
                    melee=not arms.ranged or nil}
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
    if mind.openers then
        local opener=openers.choose(input)
        if opener then return opener,'opener',{opener} end
    end
    input=M.frozen(input)
    if input.frame.self.alacrity==true then input=M.unreleased(input) end
    local options=M.options(input,rejected)
    for _,o in ipairs(defence.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(care.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(summons.options(input,rejected)) do options[#options+1]=o end
    for _,o in ipairs(removal.options(input,rejected,function(s) return M.attack(s)~=nil end)) do options[#options+1]=o end
    -- A weapon attack spends nothing: it needs no minimum worth, and it is taken over a spell
    -- only when it is worth more.
    local swings=mind.weapons and M.weaponOptions(input,rejected) or {}
    if zoned then
        local at=placed(input)
        for _,o in ipairs(options) do zones.adjust(input,o,at) end
        for _,o in ipairs(swings) do zones.adjust(input,o,at) end
        table.sort(swings,better)
    end
    table.sort(options,better)
    local swing=swings[1]
    local function all()
        local list={}
        for _,o in ipairs(options) do list[#list+1]=o end
        for _,o in ipairs(swings) do list[#list+1]=o end
        table.sort(list,better)
        return list
    end
    local swinging=swing~=nil and swing.score>0
    if #options==0 then
        if swinging then return swing,'weapon',all() end
        return nil,'no-option',options,rejected
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
        if swinging then return swing,'weapon',all() end
        return nil,'nothing-good',options,rejected
    end
    if swing and swing.score>best.score then return swing,'weapon',all() end
    local rng=input.rng
    if not rng or rng:nextInt(1,1000)<=math.floor(mind.best*1000+0.5) then return best,'best',options end
    local floor=math.max(mind.minValue,best.score-math.abs(best.score)*mind.band)
    local pool={}
    for _,o in ipairs(options) do if o.score>=floor then pool[#pool+1]=o end end
    return pool[rng:nextInt(1,#pool)],'near-best',options
end

-- The attack, defence, heal or cure, summons, removal, opener, strike, weapon attack or way out of
-- a zone to do now, or nil and why; the options come along for the log, and without a choice the
-- count of reasons the ready spells gave none. Leaving costs no spell, only the seconds of the
-- walk: it comes first when it is worth more than that share of a round of the choice. Spell
-- slots cost input.slots of their price, M.slotShare's when it is not given.
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' or type(input.mind)~='table' then return nil,'bad-input',{} end
    if input.slots==nil then
        local view={}
        for k,v in pairs(input) do view[k]=v end
        view.slots=M.slotShare(input)
        input=view
    end
    local d,why,options,rejected=pick(input)
    local escape=zones.active(input) and zones.escape(input) or nil
    if escape then
        local score=d and number(d.score) and d.score or 0
        if escape.worth>math.max(0,score)*escape.walk/zones.ROUND then
            local list={escape}
            for _,o in ipairs(type(options)=='table' and options or {}) do list[#list+1]=o end
            return escape,'escape',list
        end
    end
    return d,why,options,rejected
end
return M
