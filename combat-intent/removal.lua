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

-- What removal r takes of wards (an enemy's, in list order), cast at caster level level: the
-- chance each ward goes, by index, and whether the invisible state goes.
function M.taken(r,wards,level)
    local chance={}
    local function take(i,p) chance[i]=math.max(chance[i] or 0,p) end
    local kinds=list(r.kinds)
    if kinds.dispel and type(r.dispel)=='table' then
        local at=r.dispel.mode=='fixed' and r.dispel.level or level
        for i,w in ipairs(wards) do
            if type(w)=='table' and w.dispellable then take(i,r.dispel.mode=='always' and 1 or M.dispelChance(at,w.level)) end
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

-- The worth of a removal spell on enemy e once it lands, r rounds before the horizon ends, and the
-- reason when it is none. It can be below zero: then the removal frees e of more than it opens.
function M.on(input,spell,e,r)
    local mind=input.mind
    local killBonus=number(mind.killBonus) and mind.killBonus or 0
    local roles,key=spells.view(spell,targeting.holds(e))
    if type(roles)~='table' or (type(key)=='string' and key:find('?',1,true)) then return 0,'unknown-filter' end
    local role=roles.removal
    if type(role)~='table' or type(role.who)~='table' or not (role.who.target or role.who.area) then return 0,'filter' end
    if targeting.protected(e,spell) then return 0,'protected' end
    local kinds=list(role.kinds)
    local land=targeting.landing(role,e)*(1-targeting.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
    if land<=0 then return 0,'resisted' end
    -- Unsummoned or destroyed: out of the fight for good, as a kill. Unsummoning takes summons only.
    if kinds.destroy or (kinds.summons and summoned(e)) then return land*(targeting.health(e)+killBonus) end
    if r<=0 then return 0,'no-time' end
    local wards=type(e.wards)=='table' and e.wards or {}
    local chance,purge=M.taken(role,wards,input.frame.self.level)
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
    worth=worth*land
    if worth==0 then return 0,'no-worth' end
    return worth,worth<0 and 'frees' or nil
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

-- Every removal the caster can cast now, best aim per spell: {resref, kind='removal', mode, worth,
-- cost, score, hits (the enemies it opens), slack=0, speed, and target, point or self; walk, the
-- seconds of the walk into range, for an aim beyond it}. An area
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
                    local worth,hits,blocked=0,{},false
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
                                    local w,no=M.on(input,spell,e,r)
                                    if w>0 then w=w*orders.favour(input,e) end
                                    worth=worth+w
                                    if w>0 then hits[#hits+1]=e.id else reason=reason or no end
                                end
                            end
                        else reason=reason or 'ally-in-area' end
                    elseif aim.enemy then
                        local w,no=M.on(input,spell,aim.enemy,r)
                        if w>0 then worth=w*orders.favour(input,aim.enemy);hits[1]=aim.enemy.id else reason=reason or no end
                    end
                    -- A walk into range comes first and lowers the worth (combat-intent/choice.lua).
                    if aim.walk then worth=worth*weapons.paced(aim.walk) end
                    if worth>0 and #hits>0 and (not best or worth>best.worth) then best={aim=aim,worth=worth,hits=hits} end
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
