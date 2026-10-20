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
-- Until the engine removes protections and raises itself, SCS keeps a round the engine would only
-- attack in while the caster has such a spell ready that fits now (M.fits; Christopher,
-- 2026-10-20: "nur wenn jetzt sinnvoll"; profile keepScsSpells).
local targeting=require('combat-intent.targeting')
local defence=require('combat-intent.defence')
local care=require('combat-intent.care')
local summons=require('combat-intent.summons')
local openers=require('combat-intent.openers')
local touch=require('combat-intent.touch')
local weapons=require('combat-intent.weapons')
local ids=require('combat-intent.ids')
local spells=require('combat-intent.spells')
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
-- curing, raising and summoning are other decisions. Of these SCS may still keep a round for
-- removal and raising (M.scsSpell).
local OTHER={'removal','heal','raise','cure','summon'}
local KEPT={'removal','raise'}
local GLOBAL={everyone=true,nonparty=true,casterGroup=true,party=true}
-- What makes such a spell fit now (M.fits). The STATE.IDS bit each cured condition shows in; holds
-- also set the HELD stat, level drain the LEVELDRAIN stat, and a petrified ally lies among the
-- fallen. Curses, deafness, imprisonment, fatigue and the casting pause show in nothing the engine
-- reads, so a cure for those alone does not fit.
M.CURED={sleep=0x1,berserk=0x2,panic=0x4,stun=0x8,hold=0x20,silence=0x1000,poison=0x4000,blind=0x40000,
    disease=0x80000,feeblemind=0x100000,confusion=0x80000000}
-- STATE_STONE_DEATH; frozen and exploding deaths (STATE_FROZEN_DEATH, STATE_EXPLODING_DEATH)
-- leave no body to raise or cure.
M.STONE,M.SHATTERED=0x80,0x140
-- Protective states a dispel or a stripping spell takes away: invisible, nondetection, improved
-- invisibility, blur, mirror image.
M.SHIELDED=0x60600010
-- GENDER.IDS: SUMMONED, ILLUSIONARY, SUMMONED_DEMON.
M.SUMMONED={[6]=true,[7]=true,[9]=true}
-- Removed opcodes that show without an effect entry: Stoneskin's skins, Mirror Image's images,
-- invisibility, blur and nondetection as states.
local SHOWS={[218]='skins',[314]='skins',[119]='mirror',[159]='mirror'}
local SHOWN_STATE={[20]=0x400010,[65]=0x20000000,[69]=0x200000}

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
    local roles=targeting.kindRoles(spell)
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

local function resisted(e,label)
    local r=type(e.resist)=='table' and e.resist[M.RESIST[label] or '']
    if not number(r) then return 1 end
    return math.max(0,1-r/100)
end
local function notResisted(e) return 1-clamp(number(e.mr) and e.mr or 0,0,100)/100 end
-- The chance e makes its saving throw against role: a d20 plus the effect's bonus reaching the
-- best of e's saves the role allows. Unknown saves count as even odds.
-- How long a condition holds on e when e gets a save every bf.every seconds to break free
-- (breakFree, combat-intent/spells.lua: Spell Revisions' Greater Command): the first stretch for
-- sure, each later one while every save so far failed, up to the condition's duration.
function M.brokenFree(duration,bf,e)
    if not number(duration) or duration<=0 then return 0 end
    local every=type(bf)=='table' and number(bf.every) and bf.every>0 and bf.every or duration
    local s=type(bf)=='table' and M.saveChance({save=bf.save,saveBonus=bf.saveBonus},e) or 0
    local held,stay,t,steps=0,1,0,0
    while t<duration and steps<100 do
        local span=math.min(every,duration-t)
        held=held+span*stay
        t=t+span;steps=steps+1
        stay=stay*(1-s)
    end
    return held
end
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

-- The worth of a damage role on e, and the hit points it is expected to take. With spare, e
-- keeps at least one hit point (Harm cannot kill).
local function damageOn(input,row,role,e,spare)
    local hp,maxHp=e.hp,e.maxHp
    if not number(hp) or not number(maxHp) or maxHp<=0 or hp<=0 then return 0,0 end
    if spare then hp=hp-1 end
    if hp<=0 then return 0,0 end
    local amount=0
    for label,v in pairs(type(role.types)=='table' and role.types or {}) do
        if number(v) then amount=amount+v*resisted(e,label) end
    end
    if number(role.percent) then amount=amount+maxHp*role.percent/100 end
    if amount<=0 then return 0,0 end
    local land=notResisted(e)
    local save=M.saveChance(role,e)
    local expected=amount*land*(role.saveForHalf and 1-save/2 or 1-save)
    local worth=math.min(expected,hp)/maxHp
    -- The cast kills when the hit points it deals (halved on a save, if it allows half)
    -- reach those e has left.
    local kill=0
    if amount>=hp and not spare then
        kill=land*((role.saveForHalf and amount/2>=hp) and 1 or 1-save)
    end
    worth=worth+input.mind.killBonus*kill
    local plan=input.plan
    if type(plan)=='table' and plan.focus==e.id then worth=worth*(1+input.mind.focusBonus*input.mind.coordination) end
    local still=remembered(input,row.resref,e,role)
    return worth*still,math.min(expected,hp)*still
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
    -- A power word works by the hit points e has now: in a Time Stop, not counting what lands
    -- when time resumes (hpNow).
    local now=number(e.hpNow) and e.hpNow or e.hp
    if number(role.belowHp) and number(now) and now>=role.belowHp then return 0 end
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
    elseif number(role.duration) and role.duration>0 then
        local span=role.duration
        if type(role.breakFree)=='table' then span=M.brokenFree(span,role.breakFree,e) end
        length=clamp(span/M.fullSeconds,0,1)
    else length=0.5 end
    -- Taking out a nearly dead enemy is worth less than taking out a healthy one; taking one
    -- out for good is worth what killing it is.
    local worth=forGood and factor*(health+input.mind.killBonus) or factor*length*(0.5+0.5*health)
    -- The chance it lands: magic resistance, the saving throw, and the effect's own chance (an
    -- elf keeps out nine charms in ten).
    local chance=notResisted(e)*(1-M.saveChance(role,e))*clamp(number(role.chance) and role.chance or 1,0,1)
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

-- The worth of the spell's kind of attack on e, and for damage the hit points it is expected to
-- take.
local function worthOn(input,row,kind,roles,e)
    if kind=='damage' then return damageOn(input,row,roles.damage,e) end
    return disableOn(input,row,roles.disable,e),0
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
        hits[1]=e.id
    else
        local center=aim.point
        if a.line or a.rectangle then
            -- An enemies-only line or box: counted for the creature aimed at only.
            local e=aim.enemy
            local roles=e and affects(spell,e,kind)
            if not roles then return nil,'shape' end
            worth,expected[e.id]=worthOn(input,row,kind,roles,e)
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
    local cost=input.mind.economy*M.costPerLevel*level
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
                local cost=mind.economy*M.costPerLevel*level+exposure
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
        per=per+each*notResisted(e)*(role.saveForHalf and 1-save/2 or 1-save)
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
    local cost=mind.economy*M.costPerLevel*level
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
                    cost=cost,score=worth-cost,hits={e.id},slack=0,expected={[e.id]=expected},speed=0}
            else reject(hits<=0 and 'absorbed' or 'no-worth') end
        else reject(why) end
    end
    table.sort(out,better)
    return out
end

local function list(t) return type(t)=='table' and t or {} end
-- Whether a role reaches creatures other than its caster.
local function others(role)
    for who in pairs(role.who) do if who~='self' then return true end end
    return false
end
local function ails(f,label)
    if label=='hold' and number(f.held) and f.held>0 then return true end
    if label=='drain' then return number(f.drained) and f.drained>0 end
    local bit=M.CURED[label]
    return bit~=nil and targeting.has(f.state,bit)
end
-- A protection from a spell with time left (sense.lua marks it timed; an item's does not count),
-- Stoneskin skins, Mirror Images or a protective state: what a dispel or a stripping spell takes.
local function shielded(e)
    if (number(e.skins) and e.skins>0) or (number(e.mirror) and e.mirror>0) or targeting.has(e.state,M.SHIELDED) then
        return true
    end
    for _,p in ipairs(list(e.protections)) do if type(p)=='table' and p.timed then return true end end
    return false
end
-- Whether an enemy carries an effect of opcode op that a removal by opcode takes away.
local function carries(e,op)
    local field=SHOWS[op]
    if field then return number(e[field]) and e[field]>0 end
    if SHOWN_STATE[op] then return targeting.has(e.state,SHOWN_STATE[op]) end
    for _,p in ipairs(list(e.protections)) do if type(p)=='table' and p.timed and p.opcode==op then return true end end
    return false
end
local function summoned(e) return type(e.ids)=='table' and M.SUMMONED[e.ids.gender]==true end
-- Whether an enemy has what a removal of each kind takes away. Clouds show in nothing the engine
-- reads: a removal of clouds alone does not fit.
local REMOVED={dispel=shielded,schools=shielded,secondaries=shielded,
    invisibility=function(e) return targeting.has(e.state,UNSEEN) end,
    nondetection=function(e) return targeting.has(e.state,0x200000) end,
    sanctuary=function(e) return number(e.sanctuary) and e.sanctuary>0 end,
    summons=summoned,destroy=summoned,replace=summoned}

-- Whether a role of a spell the engine leaves to SCS fits now (Christopher, 2026-10-20): raising
-- when an ally it sees lies dead with a body, not a summons; curing when the caster or an ally it
-- reaches has a condition the spell cures; removal when an enemy it sees has what the spell takes
-- away. A spell on the caster alone reaches only the caster.
function M.fits(input,name,role)
    if type(role)~='table' or type(role.who)~='table' or next(role.who)==nil then return false end
    local frame=input.frame
    local caster=frame.self
    local wide=others(role)
    local friends={caster}
    if wide then
        for _,a in ipairs(list(frame.allies)) do if targeting.alive(a) then friends[#friends+1]=a end end
    end
    local fallen=wide and list(frame.fallen) or {}
    if name=='raise' then
        for _,f in ipairs(fallen) do
            if type(f)=='table' and not targeting.has(f.state,M.STONE+M.SHATTERED) and not M.SUMMONED[f.gender] then
                return true
            end
        end
        return false
    end
    local kinds=list(role.kinds)
    if name=='cure' then
        for label in pairs(kinds) do
            for _,f in ipairs(friends) do if ails(f,label) then return true end end
            if label=='petrify' then
                for _,f in ipairs(fallen) do
                    if type(f)=='table' and targeting.has(f.state,M.STONE) and not targeting.has(f.state,M.SHATTERED) then
                        return true
                    end
                end
            end
        end
        return false
    end
    if name=='removal' and wide then
        for _,e in ipairs(frame.enemies) do
            if targeting.alive(e) then
                for label in pairs(kinds) do
                    local test=REMOVED[label]
                    if test and test(e) then return true end
                    if label=='opcodes' then
                        for op in pairs(list(role.opcodes)) do if carries(e,op) then return true end end
                    end
                end
            end
        end
    end
    return false
end

-- The kind and resref of a spell the caster has ready that the engine does not cast yet (removal,
-- raise) and that fits now (M.fits), or nil.
function M.scsSpell(input)
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and
            type(row.spell)=='table' and type(row.spell.roles)=='table' then
            for _,name in ipairs(KEPT) do
                if M.fits(input,name,row.spell.roles[name]) then return name,row.resref end
            end
        end
    end
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

-- The attack, defence, heal or cure, summons, opener or strike to do now, or nil and why; the options come along for
-- the log, and with 'no-option' the count of reasons the ready spells gave none. When SCS keeps
-- the round for a spell that fits now, that spell's resref comes last.
function M.decide(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' or type(input.mind)~='table' then return nil,'bad-input',{} end
    local mind=input.mind
    local rejected={}
    if mind.touch then
        local strike=M.strike(input,rejected)
        if strike then return strike,'strike',{strike} end
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
    table.sort(options,better)
    -- A weapon attack spends nothing: it needs no minimum worth, and it is taken over a spell
    -- only when it is worth more. Instead of no cast at all it waits while the caster has a spell
    -- ready that the engine does not cast yet and that fits now: SCS keeps that round ('scs-' and
    -- the kind).
    local swings=mind.weapons and M.weaponOptions(input,rejected) or {}
    local swing=swings[1]
    local function all()
        local list={}
        for _,o in ipairs(options) do list[#list+1]=o end
        for _,o in ipairs(swings) do list[#list+1]=o end
        table.sort(list,better)
        return list
    end
    local function instead()
        if not swing or swing.score<=0 then return nil end
        if mind.keepScsSpells then
            local kind,spell=M.scsSpell(input)
            if kind then return nil,'scs-'..kind,spell end
        end
        return swing
    end
    if #options==0 then
        local s,kept,spell=instead()
        if s then return s,'weapon',all() end
        return nil,kept or 'no-option',kept and all() or options,rejected,spell
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
        local s,kept,spell=instead()
        if s then return s,'weapon',all() end
        return nil,kept or 'nothing-good',kept and all() or options,rejected,spell
    end
    if swing and swing.score>best.score then return swing,'weapon',all() end
    local rng=input.rng
    if not rng or rng:nextInt(1,1000)<=math.floor(mind.best*1000+0.5) then return best,'best',options end
    local floor=math.max(mind.minValue,best.score-math.abs(best.score)*mind.band)
    local pool={}
    for _,o in ipairs(options) do if o.score>=floor then pool[#pool+1]=o end end
    return pool[rng:nextInt(1,#pool)],'near-best',options
end
return M
