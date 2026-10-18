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
local targeting=require('combat-intent.targeting')
local ids=require('combat-intent.ids')
local M={}
M.rangeUnit=targeting.rangeUnit
-- Allies keep this much room beyond an area's edge; positions are up to a check-in old.
M.allyMargin=32
-- Worth of one spell level, times the profile's economy.
M.costPerLevel=0.03
-- A disable lasting this long counts in full (three rounds).
M.fullSeconds=18
-- STATE_SILENCED, in the active state.
M.SILENCED=0x1000
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible
-- What each kind of disable is worth on an enemy in full health, for the full time. Death,
-- petrification and imprisonment take the enemy out for good.
M.DISABLE={hold=1,stun=1,sleep=0.8,charm=1.2,confusion=0.8,panic=0.7,berserk=0.4,feeblemind=1,
    silence=0.7,nocast=0.7,entangle=0.5,web=0.6,root=0.3,polymorph=1,pause=0.8,maze=1.2,
    turnUndead=1,petrify=1,imprison=1,death=1}
M.FOR_GOOD={petrify=true,imprison=true,death=true}
-- Disables that matter only against casters.
M.CASTERS_ONLY={feeblemind=true,silence=true,nocast=true}
-- Damage types to the resistance an enemy's details carry (sense.lua reads SCS's stats).
M.RESIST={fire='fire',cold='cold',electricity='electricity',acid='acid',magic='magic',
    magicfire='magicfire',magiccold='magiccold',slashing='slashing',crushing='crushing',
    piercing='piercing',missile='missile',poison='poison'}
-- Roles that make a spell something other than an attack: protection removal, healing,
-- curing, raising and summoning are other decisions (later slices).
local OTHER={'removal','heal','raise','cure','summon'}
local GLOBAL={everyone=true,nonparty=true,casterGroup=true,party=true}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
local function benefits(role)
    return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area or role.who.point or role.who.party)
end

-- 'damage' or 'disable' and how the spell is aimed, or nil and why the engine leaves it out.
function M.attack(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    for _,name in ipairs(OTHER) do
        if benefits(spell.roles[name]) then return nil,'role-'..name end
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
    local kind=reaches(spell.roles.disable) and 'disable' or reaches(spell.roles.damage) and 'damage' or nil
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
-- Whether the spell can work on e at all: its creature filters and e's spell protections.
local function affects(spell,e)
    for _,f in ipairs(targeting.filters(spell)) do
        local m=ids.matches(f,e)
        if m~=true then return false,m==false and 'filter' or 'unknown-filter' end
    end
    if targeting.protected(e,spell) then return false,'protected' end
    return true
end

local function resisted(e,label)
    local r=type(e.resist)=='table' and e.resist[M.RESIST[label] or '']
    if not number(r) then return 1 end
    return math.max(0,1-r/100)
end
local function notResisted(e) return 1-clamp(number(e.mr) and e.mr or 0,0,100)/100 end
-- The chance e makes its saving throw against role: a d20 plus the effect's bonus reaching the
-- best of e's saves the role allows. Unknown saves count as even odds.
function M.saveChance(role,e)
    if type(role.save)~='table' or next(role.save)==nil then return 0 end
    local best
    for name in pairs(role.save) do
        local v=type(e.saves)=='table' and e.saves[name]
        if number(v) and (best==nil or v<best) then best=v end
    end
    if not best then return 0.5 end
    local bonus=number(role.saveBonus) and role.saveBonus or 0
    return clamp((21-(best-bonus))/20,0.05,0.95)
end
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

local function damageOn(input,row,role,e)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0 end
    local amount=0
    for label,v in pairs(type(role.types)=='table' and role.types or {}) do
        if number(v) then amount=amount+v*resisted(e,label) end
    end
    if number(role.percent) then amount=amount+maxHp*role.percent/100 end
    if amount<=0 then return 0 end
    local land=notResisted(e)
    local save=M.saveChance(role,e)
    local expected=amount*land*(role.saveForHalf and 1-save/2 or 1-save)
    local worth=math.min(expected,hp)/maxHp
    -- The cast kills when the hit points it deals (halved on a save, if it allows half)
    -- reach those e has left.
    local kill=0
    if amount>=hp then
        kill=land*((role.saveForHalf and amount/2>=hp) and 1 or 1-save)
    end
    worth=worth+input.mind.killBonus*kill
    local plan=input.plan
    if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    return worth*remembered(input,row.resref,e,role)
end

local function disableOn(input,row,role,e)
    if targeting.disabled(e) then return 0 end
    local plan=input.plan
    local reserved=type(plan)=='table' and type(plan.reserved)=='table' and plan.reserved[e.id]
    if reserved and reserved~=input.frame.self.id and input.mind.coordination>=0.5 then return 0 end
    local level=e.level
    if number(level) and ((number(role.maxLevel) and level>role.maxLevel) or (number(role.minLevel) and level<role.minLevel)) then
        return 0
    end
    local factor,forGood=0,false
    for label in pairs(type(role.kinds)=='table' and role.kinds or {}) do
        local f=M.DISABLE[label] or 0
        if M.CASTERS_ONLY[label] and not ids.caster(e) then f=f*0.2 end
        if label=='turnUndead' and not (type(e.ids)=='table' and e.ids.general==4) then f=0 end
        if label=='sleep' and role.wakesOnDamage then f=f*0.6 end
        if f>factor then factor,forGood=f,M.FOR_GOOD[label]==true end
    end
    if factor<=0 then return 0 end
    local health=targeting.health(e)
    local length
    if forGood then length=1
    elseif role.duration=='permanent' then length=1
    elseif number(role.duration) and role.duration>0 then length=clamp(role.duration/M.fullSeconds,0,1)
    else length=0.5 end
    -- Taking out a nearly dead enemy is worth less than taking out a healthy one; taking one
    -- out for good is worth what killing it is.
    local worth=forGood and factor*(health+input.mind.killBonus) or factor*length*(0.5+0.5*health)
    local chance=notResisted(e)*(1-M.saveChance(role,e))
    return worth*chance*remembered(input,row.resref,e,role)
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

local function worthOn(input,row,kind,spell,e)
    if kind=='damage' then return damageOn(input,row,spell.roles.damage,e) end
    return disableOn(input,row,spell.roles.disable,e)
end

-- One option: the spell aimed at a creature or a point, its worth, cost and score, or nil
-- and why it is no option.
local function evaluate(input,row,spell,kind,mode,aim)
    local frame=input.frame
    local caster=frame.self
    local a=spell.area
    local worth,hits,slack=0,{},0
    if mode=='creature' then
        local e=aim.enemy
        local ok,why=affects(spell,e)
        if not ok then return nil,why end
        if kind=='disable' and targeting.disabled(e) then return nil,'disabled' end
        worth=worthOn(input,row,kind,spell,e)
        hits[1]=e.id
    else
        local center=aim.point
        if a.line or a.rectangle then
            -- An enemies-only line or box: counted for the creature aimed at only.
            local e=aim.enemy
            if not e or not affects(spell,e) then return nil,'shape' end
            worth=worthOn(input,row,kind,spell,e)
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
                if targeting.alive(e) and inside(e) and affects(spell,e) then
                    local w=worthOn(input,row,kind,spell,e)
                    if w>0 then
                        worth=worth+w;hits[#hits+1]=e.id
                        slack=math.min(slack,a.radius-targeting.distance(a.cone and caster or center,e))
                    end
                end
            end
            if slack==math.huge then slack=0 end
        end
    end
    if worth<=0 then return nil,'no-worth' end
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    local cost=input.mind.economy*M.costPerLevel*level
    local option={resref=row.resref,kind=kind,mode=mode,worth=worth,cost=cost,score=worth-cost,hits=hits,slack=slack}
    if aim.enemy and (mode=='creature' or mode=='creature-area') then option.target=aim.enemy.id
    elseif mode=='point-area' then option.point={x=math.floor(aim.point.x+0.5),y=math.floor(aim.point.y+0.5)}
    elseif mode=='self-area' then option.self=true
    elseif aim.enemy then option.target=aim.enemy.id end
    return option
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

-- Every option the caster has, best first.
function M.options(input)
    local out={}
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local spell=row.spell
            local kind,mode=M.attack(spell)
            if kind then
                local seen={}
                for _,aim in ipairs(aims(input,spell,mode)) do
                    local option=evaluate(input,row,spell,kind,mode,aim)
                    if option then
                        local key=tostring(option.target)..':'..(option.point and option.point.x..','..option.point.y or '')
                        if not seen[key] then seen[key]=true;out[#out+1]=option end
                    end
                end
            end
        end
    end
    table.sort(out,better)
    return out
end

-- Healing the caster has ready: for itself, and for others.
function M.heals(input)
    local own,others=false,false
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        local h=type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and
            type(row.spell)=='table' and type(row.spell.roles)=='table' and row.spell.roles.heal
        if type(h)=='table' and type(h.who)=='table' then
            if h.who.self or h.who.target then own=true end
            if h.who.target or h.who.area or h.who.party then others=true end
        end
    end
    for _,item in ipairs(type(input.items)=='table' and input.items or {}) do
        for _,a in ipairs(type(item)=='table' and type(item.abilities)=='table' and item.abilities or {}) do
            local h=type(a)=='table' and type(a.effect)=='table' and type(a.effect.roles)=='table' and a.effect.roles.heal
            if type(h)=='table' and type(h.who)=='table' and (h.who.self or h.who.target) and
                (not number(a.uses) or a.uses>0) then own=true end
        end
    end
    return {self=own,others=others}
end

-- Something SCS's own order puts before attacks, which the engine leaves to SCS for now.
function M.urgent(input)
    local defer=type(input.mind.defer)=='table' and input.mind.defer or {}
    local caster=input.frame.self
    if defer.silenced and targeting.has(caster.state,M.SILENCED) then return 'silenced' end
    if input.family=='priest' then
        local heals=M.heals(input)
        if heals.self and number(defer.selfHealth) and targeting.health(caster)<defer.selfHealth then return 'self-hurt' end
        if heals.others and number(defer.allyHealth) then
            for _,ally in ipairs(type(input.frame.allies)=='table' and input.frame.allies or {}) do
                if targeting.alive(ally) and targeting.health(ally)<defer.allyHealth then return 'ally-hurt' end
            end
        end
    end
end

-- The attack to cast now, or nil and why; the options come along for the log.
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' or type(input.mind)~='table' then return nil,'bad-input',{} end
    local why=M.urgent(input)
    if why then return nil,'urgent-'..why,{} end
    local options=M.options(input)
    if #options==0 then return nil,'no-option',options end
    local mind=input.mind
    local best=options[1]
    if best.score<mind.minValue then return nil,'nothing-good',options end
    local rng=input.rng
    if not rng or rng:nextInt(1,1000)<=math.floor(mind.best*1000+0.5) then return best,'best',options end
    local floor=math.max(mind.minValue,best.score-math.abs(best.score)*mind.band)
    local pool={}
    for _,o in ipairs(options) do if o.score>=floor then pool[#pool+1]=o end end
    return pool[rng:nextInt(1,#pool)],'near-best',options
end
return M
