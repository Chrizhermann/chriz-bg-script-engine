-- The engine's own healing and curing for one caster (step 3, D3a and D3b; Christopher,
-- 2026-10-20: "Mach alles"). SCS's priests are the blueprint ([src] priest/ssl/generalblocks/
-- renew.ssl): they heal themselves and allies who are hurt, and cure what keeps an ally out of the
-- fight, before they attack; they heal and cure only allies above a level that rises with their
-- own (priest_shared.tph, minimum_healing_level). SCS's mages and priests drink healing potions.
--
-- Inputs are plain values, as for combat-intent/defence.lua: the caster's frame, whose friends
-- (the caster and its allies) carry their level and guard (what protects them, and the conditions
-- on them with the seconds left: adapters/eeex/sense.lua), the classified ready spells and the
-- carried items, the profile and the director's plan. Nothing here touches the engine or raises
-- on odd data.
--
-- Worth is on the attack's scale (shares of a creature), as for protections: what a friend is
-- worth at the horizon's end with the cast less what it is worth without, counting the share of
-- its hit points it has left then, the kill bonus as likely as it lives, and the rounds it is in
-- the fight (alive and not disabled), each worth a round of disable (defence.disableRound). A heal
-- on a friend no one threatens is worth the hit points it restores, as damage on an enemy is; on
-- a friend about to fall also the rounds it keeps it standing and the kill bonus. A friend that
-- falls before the cast lands gains nothing. A cure is worth what the condition would still keep
-- the friend out of, as the same disable on an enemy is worth (combat-intent/choice.lua), and the
-- hit points poison would still take.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local defence=require('combat-intent.defence')
local ids=require('combat-intent.ids')
local M={}
M.ROUND=6
-- What freeing a friend of each condition is worth for the full time (fullSeconds), as the same
-- disable on an enemy is worth (choice.DISABLE); blindness, deafness and disease hinder without
-- taking the friend out. Conditions that matter only for casters count a fifth on others.
M.CONDITION={sleep=0.8,hold=1,stun=1,panic=0.7,confusion=0.8,berserk=0.4,feeblemind=1,silence=0.7,
    pause=0.8,blind=0.3,deaf=0.2,disease=0.1}
M.CASTERS_ONLY={feeblemind=true,silence=true,deaf=true}
M.fullSeconds=18
-- Seconds a condition counts for when the friend's effects could not be read.
M.unknownSeconds=12
-- The STATE.IDS bit each condition shows in (holds set the HELD stat); a condition whose effect
-- is on a friend but whose state does not show any more is over. Deafness and the casting pause
-- show in no state.
M.STATE={sleep=0x1,berserk=0x2,panic=0x4,stun=0x8,silence=0x1000,poison=0x4000,blind=0x40000,
    disease=0x80000,feeblemind=0x100000,confusion=0x80000000}
-- How far beyond a spell's range the caster walks to an ally it heals or cures (a touch spell
-- reaches one range unit): a round's walk, at about 100 world units a second.
M.walk=600
M.walkSpeed=100
-- A speed point of casting time is 10 game ticks (as for defences).
M.speedSeconds=10/15
-- Worth of one spell level, times the profile's economy; a potion costs as a first-level spell.
M.costPerLevel=0.03
M.itemLevel=1

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- The share of a spell slot's cost that counts now (combat-intent/choice.lua, M.slotShare).
local function slots(input) return number(input.slots) and input.slots or 1 end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function list(t) return type(t)=='table' and t or {} end

-- The level an ally must exceed for SCS's priests of this level to heal or cure it
-- (priest_shared.tph, minimum_healing_level; renew.ssl: CheckStatGT on the ally's level).
function M.minimumLevel(level)
    if not number(level) or level<=3 then return 1 end
    if level<=5 then return 2 end
    if level<=7 then return 3 end
    if level<=8 then return 4 end
    if level<=14 then return level-5 end
    if level<=17 then return level-6 end
    if level<=20 then return level-7 end
    return level-8
end

-- Hit points a heal role restores on friend f now: its amount, or its share of f's maximum, up
-- to what f is missing. A heal that sets hit points or rests is not counted.
function M.healed(role,f)
    if type(role)~='table' or not number(f.hp) or not number(f.maxHp) or f.maxHp<=0 then return 0 end
    local missing=math.max(0,f.maxHp-f.hp)
    local amount=0
    if number(role.amount) then amount=amount+role.amount end
    if number(role.percent) then amount=amount+f.maxHp*role.percent/100 end
    return math.min(amount,missing)
end

local NONE={weapon={hp=0,hits=0,attacks=0,magicalAttacks=0},spell={hp=0,personal=0,area=0,disable=0,casters=0,level=0}}
-- What friend f is worth at the end of r rounds under threat t with shield s, if it had hp hit
-- points now: the share of its hit points left then, the kill bonus as likely as it lives (for
-- sure while its minimum holds), and the rounds it is in the fight (alive and not disabled by
-- enemy spells), each worth a round of disable. Harm runs as defence.course has it.
function M.standing(f,t,s,r,killBonus,hp)
    local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or 1
    if hp<=0 then return 0 end
    local g={}
    for k,v in pairs(f) do g[k]=v end
    g.hp=hp
    local harm,death,b=defence.course(s,g,t or NONE,r)
    local dies=targeting.minimum(f)>0 and 0 or clamp((harm-0.5*hp)/(0.5*hp),0,1)
    local alive=math.min(death,r)
    local disabled=(t or NONE).spell.disable*(1-b.disable)*alive
    return math.max(0,hp-harm)/maxHp+killBonus*(1-dies)+defence.disableRound*(alive-disabled)
end

-- Whether friend f has condition label now, and its seconds left: the effect on f (its guard's
-- conditions) while its state still shows it; a hold shows in the HELD stat. A friend whose
-- effects could not be read counts by its state alone, for unknownSeconds.
function M.condition(f,label)
    local shown
    if label=='hold' then shown=number(f.held) and f.held>0
    elseif M.STATE[label] then shown=targeting.has(f.state,M.STATE[label]) end
    local guard=type(f.guard)=='table' and f.guard or nil
    local left=guard and type(guard.conditions)=='table' and guard.conditions[label]
    if not guard then
        if shown then return true,M.unknownSeconds end
        return false,0
    end
    -- (A condition without an end lasts math.huge seconds.)
    if not (type(left)=='number' and left>0) then return false,0 end
    if shown==false then return false,0 end
    return true,left
end

-- The worth of a cure role on friend f: each condition it takes away that f has, as that
-- disable would be worth on an enemy for the time it has left, and the share of f's hit points
-- poison would still take.
function M.cured(role,f)
    if type(role)~='table' or type(role.kinds)~='table' then return 0,{} end
    local worth,freed=0,{}
    local health=targeting.health(f)
    for label in pairs(role.kinds) do
        local has,left=M.condition(f,label)
        if has then
            local factor=M.CONDITION[label] or 0
            if M.CASTERS_ONLY[label] and not ids.caster(f) then factor=factor*0.2 end
            if factor>0 then
                worth=worth+factor*clamp(left/M.fullSeconds,0,1)*(0.5+0.5*health)
                freed[#freed+1]=label
            end
            if label=='poison' then
                local guard=type(f.guard)=='table' and f.guard or {}
                local hp=number(guard.poison) and guard.poison or 0
                local maxHp=number(f.maxHp) and f.maxHp>0 and f.maxHp or nil
                if hp>0 and maxHp then
                    worth=worth+math.min(hp,math.max(0,f.hp or 0))/maxHp
                    freed[#freed+1]=label
                end
            end
        end
    end
    return worth,freed
end

-- The heal and cure roles of a spell or item ability that reach friends, or nil and why it is no
-- care: an attack, a spell that also harms or removes, one that reaches the party (for the
-- engine's creatures that is the enemy), or one without such roles.
function M.care(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    local h,c=spell.roles.heal,spell.roles.cure
    local function reaches(role)
        return type(role)=='table' and type(role.who)=='table' and (role.who.self or role.who.target or role.who.area)
    end
    if not reaches(h) and not reaches(c) then return nil,'no-care' end
    if spell.partial then return nil,'partial' end
    if spell.offensive or spell.selfHarm then return nil,'offensive' end
    for _,r in ipairs({h,c}) do
        if type(r)=='table' and type(r.who)=='table' and (r.who.party or r.who.everyone or r.who.nonparty) then
            return nil,'party'
        end
    end
    return {heal=reaches(h) and h or nil,cure=reaches(c) and c or nil}
end

-- Where a care spell can be cast: on the caster, and at each ally within its range and a round's
-- walk beyond it for a spell cast at a creature; at the caster's spot or an ally's for an area at
-- a point; around the caster for its own area. walk: world units the caster goes beyond range.
local function aims(input,spell)
    local frame=input.frame
    local caster=frame.self
    local out={}
    local range=(number(spell.range) and spell.range or 0)*targeting.rangeUnit
    if spell.target=='self' then
        out[1]={self=true,friend=caster,point=spell.area and {x=caster.x,y=caster.y} or nil,walk=0}
    elseif spell.target=='point' and spell.area then
        out[1]={point={x=caster.x,y=caster.y},walk=0}
        for _,f in ipairs(threat.friends(frame)) do
            local d=targeting.distance(caster,f)
            if f~=caster and d<=range+M.walk then out[#out+1]={point={x=f.x,y=f.y},walk=math.max(0,d-range)} end
        end
    elseif spell.target=='creature' then
        out[1]={self=true,friend=caster,walk=0}
        for _,f in ipairs(threat.friends(frame)) do
            local d=targeting.distance(caster,f)
            if f~=caster and d<=range+M.walk then out[#out+1]={friend=f,walk=math.max(0,d-range)} end
        end
    end
    return out
end
-- Who a role reaches, aimed as the cast is: the caster for its own part, the creature aimed at,
-- the friends in its area (the enemies too, when the area spares no one).
local function receivers(input,spell,role,aim)
    local frame=input.frame
    local friends,foes,seen={},{},{}
    local function add(f) if f and not seen[f] then seen[f]=true;friends[#friends+1]=f end end
    if role.who.self then add(frame.self) end
    if role.who.target and aim.friend then add(aim.friend) end
    if role.who.area then
        local filters=type(role.filters)=='table' and role.filters or {all=true}
        local area=spell.area
        local center=aim.point or (aim.friend and {x=aim.friend.x,y=aim.friend.y})
        if area and number(area.radius) and center and (filters.allies or filters.all) then
            for _,f in ipairs(threat.friends(frame)) do
                if targeting.distance(center,f)<=area.radius then add(f) end
            end
            if filters.all then
                for _,e in ipairs(list(frame.enemies)) do
                    if targeting.alive(e) and targeting.distance(center,e)<=area.radius then foes[#foes+1]=e end
                end
            end
        end
    end
    return friends,foes
end

-- Every heal and cure option the caster has: {resref, kind='heal' or 'cure', mode, worth, cost,
-- score, hits (the friends it helps), slack=0, speed, and self, target or point as it is aimed;
-- use=true for an item it drinks}. rejected (optional) counts why ready care spells gave none.
-- An ally at or below SCS's healing level for the caster's level, or one another member of the
-- group is already healing or curing (the director's plan, with coordination), is left out.
function M.options(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected['care-'..why]=(rejected['care-'..why] or 0)+1 end end
    local mind=input.mind
    local frame=input.frame
    if type(frame)~='table' or type(frame.self)~='table' or type(mind)~='table' then return out end
    local caster=frame.self
    local pictures=threat.picture(frame)
    local horizon=number(mind.horizon) and mind.horizon or 18
    local rounds=horizon/M.ROUND
    local killBonus=number(mind.killBonus) and mind.killBonus or 0
    local minimum=M.minimumLevel(caster.level)
    local plan=type(input.plan)=='table' and input.plan or {}
    local reserved=type(plan.reserved)=='table' and plan.reserved or {}
    local coordinated=(number(mind.coordination) and mind.coordination or 0)>=0.5
    local shields={}
    local function shieldOf(f) shields[f.id]=shields[f.id] or defence.held(f);return shields[f.id] end
    -- The worth on friend f of the heal and the cure of spell that reach it, once a cast of the
    -- given seconds lands. A spell f's protections keep out does nothing for it (lab batch H: SCS's
    -- Minor Globe of Invulnerability kept a Remove Paralysis off a held mage); the caster's own
    -- protections let its own help through (targeting.protected).
    local function on(f,heal,cure,cast,spell)
        if f~=caster then
            if number(f.level) and f.level<=minimum then return 0,'level' end
            local owner=reserved[f.id]
            if coordinated and owner~=nil and owner~=caster.id then return 0,'reserved' end
        end
        if type(f.protections)=='table' and targeting.protected(f,spell,f==caster) then return 0,'protected' end
        local t=pictures[f.id]
        local s=shieldOf(f)
        local worth=0
        if heal then
            local healed=M.healed(heal,f)
            if healed>0 then
                -- Harm while the cast runs: a friend that falls meanwhile gains nothing.
                local lead=cast/M.ROUND
                local hp=f.hp
                if t and lead>0 then
                    local harm,death=defence.course(s,f,t,lead)
                    if death<=lead then return 0,'falls' end
                    hp=math.max(1,f.hp-harm)
                end
                worth=worth+M.standing(f,t,s,rounds,killBonus,hp+healed)-M.standing(f,t,s,rounds,killBonus,hp)
            end
        end
        if cure then worth=worth+(M.cured(cure,f)) end
        return worth,worth<=0 and 'no-worth' or nil
    end
    local function consider(resref,spell,gives,level,item)
        local cast=(number(spell.speed) and spell.speed or 0)*M.speedSeconds
        local best,why
        local candidates=item and {{self=true,friend=caster,walk=0}} or aims(input,spell)
        for _,aim in ipairs(candidates) do
            -- Who each role reaches; healing an enemy in an area that spares no one counts
            -- against the cast.
            local reach,order,worth,hits={},{},0,{}
            for name,role in pairs(gives) do
                local friends,foes=receivers(input,spell,role,aim)
                for _,f in ipairs(friends) do
                    if not reach[f] then reach[f]={};order[#order+1]=f end
                    reach[f][name]=role
                end
                if name=='heal' then
                    for _,e in ipairs(foes) do
                        local maxHp=number(e.maxHp) and e.maxHp>0 and e.maxHp or nil
                        if maxHp then worth=worth-M.healed(role,e)/maxHp end
                    end
                end
            end
            table.sort(order,function(a,b) return (a.id or 0)<(b.id or 0) end)
            for _,f in ipairs(order) do
                local w,no=on(f,reach[f].heal,reach[f].cure,cast,spell)
                -- The most telling reason a friend gains nothing: anything but plain no worth.
                if w>0 then worth=worth+w;hits[#hits+1]=f.id
                elseif no and (why==nil or why=='no-worth') then why=no end
            end
            if worth>0 and (not best or worth>best.worth) then best={aim=aim,worth=worth,hits=hits} end
        end
        if not best then reject(why or 'no-worth');return end
        -- Casting time: harm while casting can interrupt a spell (not an item); long casts and the
        -- walk to an ally cost.
        local through=item and 1 or defence.through(input,pictures[caster.id],cast)
        local walk=best.aim.walk/M.walkSpeed
        local cost=(number(mind.economy) and mind.economy or 1)*M.costPerLevel*(item and M.itemLevel or slots(input)*level)+
            (number(mind.castCost) and mind.castCost or 0)*(cast+walk)
        local worth=best.worth*through
        local option={resref=resref,kind=gives.heal and 'heal' or 'cure',worth=worth,cost=cost,score=worth-cost,
            hits=best.hits,slack=0,speed=number(spell.speed) and spell.speed or 0,use=item or nil}
        local aim=best.aim
        if aim.self then option.self=true;option.mode='self'
        elseif aim.friend then option.target=aim.friend.id;option.mode='ally'
        else option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)};option.mode='point' end
        out[#out+1]=option
    end
    for _,row in ipairs(list(input.spells)) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local gives,why=M.care(row.spell)
            if gives then
                local level=number(row.level) and row.level or number(row.spell.level) and row.spell.level or 1
                consider(row.resref,row.spell,gives,level,false)
            elseif why~='no-care' and why~='unclassified' then reject(why) end
        end
    end
    -- Items the caster carries: their abilities on itself, while uses are left.
    for _,it in ipairs(list(input.items)) do
        if type(it)=='table' and type(it.resref)=='string' then
            for _,a in ipairs(list(it.abilities)) do
                local effect=type(a)=='table' and a.effect
                local gives=effect and M.care(effect)
                if gives and (not number(a.uses) or a.uses>0) and effect.target~='point' then
                    consider(it.resref,effect,gives,M.itemLevel,true)
                    break
                end
            end
        end
    end
    return out
end
return M
