-- Danger zones (D3e; Christopher, 2026-10-20: "Natürlich. Wir können uns da gerne an SCS
-- orientieren, aber ich bin auch offen für eine bessere Implementierung von selbst."). SCS's
-- creatures flee clouds and storms ([src] initial/detectcloud.tpa, genai/ssl/fleecloud.ssl, credit
-- DavidW): SCS gives each cloud spell an invisible marker creature that shouts its kind every few
-- seconds; a creature that hears one close by and can be hurt by it (its resistances, magic
-- resistance, Minor Globe, undead or demon for some) runs away from the marker, unless it is
-- resistant enough and sees an enemy; a melee creature that sees an enemy walks towards it
-- instead, and one that sees no enemy stands still.
--
-- The engine reads the zones themselves (adapters/eeex/sense.lua): every area projectile that
-- explodes again and again (clouds, storms, webs, Spike Growth), with its centre, radius, the
-- seconds left and between explosions, who it spares and what one explosion does, classified by
-- combat-intent/spells.lua. So it knows every zone, not only those SCS marks, and judges each by
-- the creature in it, as the engine's own attacks judge an enemy (combat-intent/harm.lua): the
-- damage that gets through its resistances, magic resistance and saves, the disables it does not
-- shrug off (Cloudkill's death only up to its levels), conditions such as Stinking Cloud's spell
-- failure, and the spell protections that keep it out (turnings, deflections and traps that count
-- down only for as many explosions as their levels last).
--
-- What leaving is worth: the explosions the creature would sit through in the next round if it
-- stayed, counted from when it would be out, at most one per round where a zone makes those it
-- hits immune to itself for a while (Spell Revisions' clouds). Leaving costs no spell, only the
-- seconds of the walk, so it is taken when it is worth more than that part of a round of the best
-- other option (combat-intent/choice.lua). The way out is the shortest walk to a point beyond
-- every zone that would hurt it. While it stays, harm from a zone can break its casts: each
-- explosion during the casting time whose damage lands; a melee attack counts what walking to its
-- target and standing there does, so a creature fights its way out of a cloud towards an enemy
-- outside and thinks twice before walking into one.
--
-- Inputs are plain values: the caster's frame (its own saves, resistances, level, IDS values,
-- protections and SPLPROT marks; rooted when it cannot walk; aura, the seconds until the casting
-- aura of its last cast frees) and input.zones (side: who cast the zone, 'friend', 'enemy' or
-- 'unknown'; filter: 'all', 'enemies' or 'allies' of its caster).
-- Nothing here touches the engine or raises on odd data; a zone that cannot be read is left out.
local targeting=require('combat-intent.targeting')
local harm=require('combat-intent.harm')
local spells=require('combat-intent.spells')
local ids=require('combat-intent.ids')
local openers=require('combat-intent.openers')
local M={}
M.ROUND=6
-- World units a creature walks a second (the lab's fighters: about 100; care.walkSpeed).
M.walkSpeed=100
-- An exit lies this far beyond a zone's edge, and the directions tried around the creature.
M.margin=24
M.directions=16
-- Exits further away than a round's walk are not tried.
M.maxWalk=600
-- A speed point of casting time is a tenth of a round.
M.speedSeconds=0.6
-- What conditions that hinder without taking a creature out are worth for the full time
-- (harm.fullSeconds), as care.CONDITION counts blindness, deafness and disease; Stinking Cloud's
-- spell failure counts as a silence. Those for casters count a fifth on others.
M.DEBUFF={miscast=0.7,blind=0.3,deaf=0.2,disease=0.1}
M.CASTERS_ONLY={miscast=true,deaf=true}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
local function list(t) return type(t)=='table' and t or {} end

-- Whether z can be weighed: a centre, a radius and explosions to come.
function M.valid(z)
    return type(z)=='table' and number(z.x) and number(z.y) and number(z.radius) and z.radius>0 and
        number(z.left) and z.left>0 and type(z.spell)=='table'
end
-- Zones count unless the caster's own Time Stop freezes them.
function M.active(input)
    return type(input)=='table' and type(input.zones)=='table' and #input.zones>0 and
        type(input.frame)=='table' and type(input.frame.self)=='table' and openers.ownStop(input)==nil
end
function M.inside(z,p,margin) return targeting.distance(z,p)<=z.radius+(margin or 0) end
-- Whether z's explosions reach the caster's side, or with theirs its enemies' side: a zone for
-- its caster's enemies spares that caster's side, one for its caster's allies spares the other.
function M.reachesSide(z,theirs)
    local side=z.side
    if theirs then side=side=='friend' and 'enemy' or side=='enemy' and 'friend' or side end
    if z.filter=='enemies' then return side~='friend' end
    if z.filter=='allies' then return side~='enemy' end
    return true
end

-- What a debuff role's conditions take from f for as long as they hold, times the chance they
-- land.
function M.debuff(role,f)
    local factor=0
    for label in pairs(type(role.kinds)=='table' and role.kinds or {}) do
        local v=M.DEBUFF[label] or 0
        if M.CASTERS_ONLY[label] and not ids.caster(f) then v=v*0.2 end
        if v>factor then factor=v end
    end
    if factor<=0 then return 0 end
    local length=0.5
    if role.duration=='permanent' then length=1
    elseif number(role.duration) and role.duration>0 then length=clamp(role.duration/harm.fullSeconds,0,1) end
    local chance=targeting.landing(role,f)*(1-targeting.saveChance(role,f))
    return factor*length*(0.5+0.5*targeting.health(f))*chance
end

-- How many of z's next explosions f's spell protections stop (targeting.stopped): math.huge
-- while one keeps z out for as long as it lasts, a few while turnings, deflections and traps
-- count down (each explosion that reaches f takes its power from them), 0 without any.
local function stopped(f,z)
    if type(f.protections)~='table' then return 0 end
    return targeting.stopped(f,z.spell)
end
-- What one explosion of z does to friend f inside it once it gets through, on the attack's
-- scale: its damage, its disable and its conditions, by f's own view of the spell's conditions
-- (undead and the like); nothing when z spares f's side or a spell protection keeps z out. Also
-- how many of z's next explosions f's protections stop first (stopped), and the hit points z
-- leaves f at least (targeting.floor: its minimum, unless z takes it away). With theirs, f is
-- one of the caster's enemies.
function M.hit(input,z,f,theirs)
    if not M.reachesSide(z,theirs) then return 0,0,0 end
    local roles=spells.view(z.spell,targeting.holds(f))
    if type(roles)~='table' then return 0,0,0 end
    local floor=targeting.floor(f,roles)
    local first=stopped(f,z)
    if first==math.huge then return 0,first,floor end
    local killBonus=type(input.mind)=='table' and input.mind.killBonus or 0
    local worth=0
    if reaches(roles.damage) then worth=worth+(harm.damage(roles.damage,f,killBonus,floor)) end
    if reaches(roles.disable) then worth=worth+harm.disable(roles.disable,f,killBonus,floor) end
    if reaches(roles.debuff) then worth=worth+M.debuff(roles.debuff,f) end
    return worth,first,floor
end

-- The chance one explosion of z that gets through breaks a cast of f's: its damage lands (halved
-- still breaks it); and how many of z's next explosions f's protections stop first.
local function breaks(z,f)
    if not M.reachesSide(z) then return 0,0 end
    local roles=spells.view(z.spell,targeting.holds(f))
    local d=type(roles)=='table' and roles.damage
    if not reaches(d) then return 0,0 end
    local first=stopped(f,z)
    if first==math.huge then return 0,first end
    local any=false
    for label,v in pairs(type(d.types)=='table' and d.types or {}) do
        if number(v) and v>0 and harm.resisted(f,label)>0 then any=true end
    end
    if not any and not (number(d.percent) and d.percent>0) then return 0,first end
    local land=targeting.landing(d,f)
    return d.saveForHalf and land or land*(1-targeting.saveChance(d,f)),first
end

-- Seconds between the explosions of z that can hit one creature: those of z, or longer when z
-- makes the creatures it hits immune to it for a while.
function M.period(z)
    local every=number(z.every) and z.every>0 and z.every or M.ROUND
    local p=type(z.spell.roles)=='table' and z.spell.roles.protection
    if reaches(p) and type(p.kinds)=='table' and p.kinds.immune and number(p.duration) and p.duration>every then
        return p.duration
    end
    return every
end
-- The explosions of z that hit a creature inside it during (a,b] seconds from now: counted from
-- the next one when it is known, else spread evenly; none after z ends.
function M.count(z,a,b)
    b=math.min(b,z.left)
    if b<=a then return 0 end
    local period=M.period(z)
    if number(z.next) and z.next>=0 and period==(number(z.every) and z.every or period) then
        local first=math.max(0,math.floor((a-z.next)/period)+1)
        local last=math.floor((b-z.next)/period)
        return math.max(0,last-first+1)
    end
    return (b-a)/period
end

-- Positions with y counted 4/3, as the engine's search map measures distance.
local function flat(p) return p.x,p.y*4/3 end
-- The parts of a walk from p to q (speed units a second, then standing at q until time t) that
-- lie inside z, as {from, to} seconds.
local function spans(z,p,q,speed,t)
    local px,py=flat(p)
    local qx,qy=flat(q)
    local cx,cy=flat(z)
    local r=z.radius
    local out={}
    local dx,dy=qx-px,qy-py
    local length=math.sqrt(dx*dx+dy*dy)
    local arrive=length/speed
    if length>1e-6 then
        local ux,uy=dx/length,dy/length
        local fx,fy=px-cx,py-cy
        local b=fx*ux+fy*uy
        local disc=b*b-(fx*fx+fy*fy-r*r)
        if disc>=0 then
            local s=math.sqrt(disc)
            local s0,s1=math.max(0,-b-s),math.min(length,-b+s)
            if s1>s0 then out[#out+1]={s0/speed,math.min(s1/speed,t)} end
        end
    end
    local ex,ey=qx-cx,qy-cy
    if ex*ex+ey*ey<=r*r and t>arrive then
        local last=out[#out]
        if last and last[2]>=arrive-1e-9 then last[2]=t else out[#out+1]={arrive,t} end
    end
    return out
end

-- What f would lose to the zones that hurt it: hurts lists {zone, hit, stopped} (one explosion's
-- harm, and how many explosions its protections stop first, in the order they reach it). staying
-- puts f at p until time t; walking takes it from p to q and leaves it there.
local function loss(hurts,f,p,q,speed,t)
    local total=0
    for _,h in ipairs(hurts) do
        local free=h.stopped or 0
        for _,s in ipairs(spans(h.zone,p,q,speed,t)) do
            local n=M.count(h.zone,s[1],s[2])
            local kept=math.min(n,free)
            free=free-kept
            total=total+h.hit*(n-kept)
        end
    end
    return total
end
-- The zones that would hurt f where it stands or on its way, with one explosion's harm each, the
-- explosions its protections stop first and the hit points each leaves it at least.
local function hurting(input,f)
    local out={}
    for _,z in ipairs(list(input.zones)) do
        if M.valid(z) then
            local h,first,floor=M.hit(input,z,f)
            if h>0 then out[#out+1]={zone=z,hit=h,stopped=first,floor=floor} end
        end
    end
    return out
end
local function speedOf(f) return number(f.speed) and f.speed>0 and f.speed or M.walkSpeed end
-- The most f can lose to the zones that hurt it (hurts): all it is worth and the kill bonus, or
-- while its minimum holds against all of them, what it has above the lowest they leave it.
local function cap(input,f,hurts)
    local killBonus=type(input.mind)=='table' and number(input.mind.killBonus) and input.mind.killBonus or 0
    local floor
    for _,h in ipairs(hurts) do
        local v=number(h.floor) and h.floor or 0
        if floor==nil or v<floor then floor=v end
    end
    if not floor or floor<=0 or not number(f.hp) or not number(f.maxHp) or f.maxHp<=0 then
        return targeting.health(f)+killBonus
    end
    return math.max(0,math.min(1,(f.hp-floor)/f.maxHp))
end

-- What walking to q is worth to the caster against standing where it is, in the zones: what it
-- would lose standing for a round and the walk, less what it loses on the way and at q. Above
-- zero when q leads out of harm, below when it leads in. 0 without zones.
function M.delta(input,q)
    if not M.active(input) or type(q)~='table' or not number(q.x) or not number(q.y) then return 0 end
    local f=input.frame.self
    if not number(f.x) or not number(f.y) then return 0 end
    local hurts=hurting(input,f)
    if #hurts==0 then return 0 end
    local speed=speedOf(f)
    local t=M.ROUND+targeting.distance(f,q)/speed
    local most=cap(input,f,hurts)
    local stay=math.min(loss(hurts,f,f,f,speed,t),most)
    local go=math.min(loss(hurts,f,f,q,speed,t),most)
    return stay-go
end

-- The chance the caster finishes a cast of the given seconds where it stands: each explosion of
-- a zone around it whose damage lands breaks the cast. The casting starts when the casting aura
-- of the creature's last cast frees (f.aura seconds from now) and runs for the casting time. An
-- explosion whose time is known breaks it with its chance; where explosions are spread evenly, a
-- part of one breaks it with that part of the chance (lab batch H5: an Ice Storm's next explosion
-- fell inside a summons' casting time three times, and each time its damage broke the cast).
-- Explosions the creature's protections stop break nothing; those before the casting starts use
-- them up first.
local function sits(z,f,from,cast,first)
    local free=math.max(0,(first or 0)-M.count(z,0,from))
    return math.max(0,M.count(z,from,from+cast)-free)
end
function M.through(input,cast)
    if not M.active(input) or not number(cast) or cast<=0 then return 1 end
    local f=input.frame.self
    local from=number(f.aura) and f.aura>0 and f.aura or 0
    local chance=1
    for _,z in ipairs(input.zones) do
        if M.valid(z) and M.inside(z,f) then
            local p,first=breaks(z,f)
            p=clamp(p,0,1)
            if p>0 then
                local n=sits(z,f,from,cast,first)
                local k=math.floor(n)
                chance=chance*(1-p)^k*(1-p*(n-k))
            end
        end
    end
    return chance
end

-- For the lab log: each zone around the caster with the seconds to its next explosion and until
-- it ends, when the casting would begin (aura), the explosions during a cast of the given seconds
-- that get through and the chance one breaks it, and while turnings, deflections or traps count
-- down, how many explosions they stop first.
function M.explain(input,cast)
    local out={}
    if not M.active(input) or not number(cast) or cast<=0 then return out end
    local f=input.frame.self
    local from=number(f.aura) and f.aura>0 and f.aura or 0
    for _,z in ipairs(input.zones) do
        if M.valid(z) and M.inside(z,f) then
            local p,first=breaks(z,f)
            out[#out+1]={id=z.id,next=z.next,left=z.left,from=from,count=sits(z,f,from,cast,first),
                breaks=clamp(p,0,1),stopped=first>0 and first<math.huge and first or nil}
        end
    end
    return out
end

-- Whether f cannot walk: held, disabled, webbed or entangled.
function M.rooted(f) return f.rooted==true or targeting.disabled(f) end
local rooted=M.rooted

-- Whether a zone hurts the caster where it stands.
function M.harmed(input)
    if not M.active(input) then return false end
    local f=input.frame.self
    if not number(f.x) or not number(f.y) then return false end
    for _,h in ipairs(hurting(input,f)) do
        if M.inside(h.zone,f) then return true end
    end
    return false
end

-- The caster's way out of the zones that hurt it, as an option {kind='escape', mode='point',
-- point, worth (what leaving is worth, M.delta), walk (seconds), exits (other points, best first),
-- zones (the zones it leaves, {x, y, radius})}, or nil and why: no zone hurts it where it stands,
-- it cannot walk, or no way out is worth anything.
function M.escape(input)
    if not M.active(input) then return nil,'no-zone' end
    local f=input.frame.self
    if not number(f.x) or not number(f.y) then return nil,'no-position' end
    if not M.harmed(input) then return nil,'unharmed' end
    local hurts=hurting(input,f)
    if rooted(f) then return nil,'rooted' end
    local speed=speedOf(f)
    local most=cap(input,f,hurts)
    local px,py=flat(f)
    local found={}
    for i=0,M.directions-1 do
        local a=2*math.pi*i/M.directions
        local ux,uy=math.cos(a),math.sin(a)
        -- Out along the ray past every zone that hurts, edge by edge.
        local s,moved,steps=0,true,0
        while moved and steps<8 do
            moved,steps=false,steps+1
            for _,h in ipairs(hurts) do
                local cx,cy=flat(h.zone)
                local fx,fy=px+s*ux-cx,py+s*uy-cy
                local r=h.zone.radius+M.margin
                if fx*fx+fy*fy<r*r then
                    local b=fx*ux+fy*uy
                    local disc=b*b-(fx*fx+fy*fy-r*r)
                    s=s+(-b+math.sqrt(math.max(0,disc)))+1
                    moved=true
                end
            end
        end
        local q={x=math.floor(px+s*ux+0.5),y=math.floor((py+s*uy)*3/4+0.5)}
        -- Areas start at 0: a point before their edge is no way out.
        if not moved and s<=M.maxWalk and q.x>=0 and q.y>=0 then
            local t=M.ROUND+s/speed
            local worth=math.min(loss(hurts,f,f,f,speed,t),most)-math.min(loss(hurts,f,f,q,speed,t),most)
            found[#found+1]={point=q,worth=worth,walk=s/speed}
        end
    end
    if #found==0 then return nil,'no-way-out' end
    table.sort(found,function(a,b)
        if a.worth~=b.worth then return a.worth>b.worth end
        if a.walk~=b.walk then return a.walk<b.walk end
        if a.point.x~=b.point.x then return a.point.x<b.point.x end
        return a.point.y<b.point.y
    end)
    local best=found[1]
    if best.worth<=0 then return nil,'no-worth' end
    local exits,left={},{}
    for i=2,math.min(#found,5) do if found[i].worth>0 then exits[#exits+1]=found[i].point end end
    for _,h in ipairs(hurts) do left[#left+1]={x=h.zone.x,y=h.zone.y,radius=h.zone.radius} end
    return {resref='ESCAPE',kind='escape',mode='point',point=best.point,worth=best.worth,cost=0,score=best.worth,
        hits={},slack=0,speed=0,walk=best.walk,exits=exits,zones=left}
end

-- An option with the zones counted: a melee attack or a strike gains what walking to its target
-- is worth (M.delta: out of harm, or into it); a cast where the caster stands loses what the zones
-- around it may break (the chance it finishes kept as finish, for the log). Changes the option's
-- worth and score in place.
function M.adjust(input,o,enemyAt)
    if not M.active(input) or type(o)~='table' or not number(o.worth) then return o end
    if o.kind=='escape' then return o end
    if o.kind=='strike' or (o.kind=='weapon' and o.melee) then
        local e=enemyAt and enemyAt[o.target]
        if e then o.worth=o.worth+M.delta(input,e) end
    elseif not o.use and o.kind~='weapon' then
        local cast=(number(o.speed) and o.speed or 0)*M.speedSeconds
        if cast>0 then o.finish=M.through(input,cast);o.worth=o.worth*o.finish end
    end
    o.score=o.worth-(number(o.cost) and o.cost or 0)
    return o
end
return M
