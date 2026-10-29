-- The engine's own summons for one caster (step 3, D3c; Christopher, 2026-10-20: "Mach alles").
-- SCS is the blueprint ([src] its mage and priest summoning blocks): its casters cast most summons
-- at an enemy they target (elementals, monster summonings, the dead, Devas), a few on themselves
-- (Gate, Summon Fiend, Death Knight, Mordenkainen's Sword, the genies), and those that eat magic
-- (Nishruu, Hakeashar) at an enemy caster. Apart from one Deva at a time it counts no summons of
-- its own; the engine stops at a cap of summoned allies in view (the profile's summonCap), as the
-- game limits summoned creatures.
--
-- Inputs are plain values: the frame (enemies with attack data from adapters/eeex/sense.lua,
-- allies with IDS values), the classified ready spells, the profile, the director's plan, and
-- input.creatures: each creature the ready spells name, as M.profile reads its CRE record and
-- weapon (the adapter reads them). Nothing here touches the engine or raises on odd data.
--
-- Worth is on the attack's scale: each summoned creature's fight, the share of an enemy its hits
-- take (as a weapon attack is worth) and the share of a friend its body spares by drawing its part
-- of the enemies' blows, up to its own hit points. It fights over the rest of the fight after the
-- cast, as both sides' strength makes it (combat-intent/threat.lua, M.rest; at most the profile's
-- fightCap), no longer than the summons lasts and only while it lives; so an early summons counts
-- much and a late one little (Christopher, 2026-10-22, agreed). While the caster's side awaits foes
-- out of play (input.calm, combat-intent/choice.lua's readiness; Christopher, 2026-10-29: "Was für
-- eine geile Idee") a summons waits where they went, as the readied frame places them, and fights
-- from when the first is likely back on. Only fighters on the caster's side count:
-- - a creature no one can see or select (its own effects remove its avatar or its selection
--   circle: SCS's markers for its storms and clouds, a kit's helper) or without a weapon is no
--   fighter;
-- - a summons that takes its side from its own file joins the caster only when that side is the
--   caster's (Wish's genie is neutral); one aligned against the caster is hostile.
-- Summons from monster tables (opcodes 127 and 331) name no creature; they count as creatures of
-- twice the spell's level. Cost: the spell's level and its casting time; harm while casting can
-- break it. Not yet: images of the caster (Project Image, Simulacrum), changes of shape, and
-- summons cast at another creature, whose side follows that creature.
local targeting=require('combat-intent.targeting')
local threat=require('combat-intent.threat')
local defence=require('combat-intent.defence')
local weapons=require('combat-intent.weapons')
local arsenal=require('combat-intent.arsenal')
local M={}
M.ROUND=6
-- Opcodes of a creature's own effects that make it no fighter: avatar removal, selection circle
-- removal.
M.HIDDEN={[271]=true,[287]=true}
-- GENDER.IDS SUMMONED: the creatures the cap counts (summoned demons and illusions do not).
M.SUMMONED=6
-- EA.IDS: the good side ends at GOODCUTOFF, the evil side starts at EVILCUTOFF.
M.GOOD_CUTOFF=30
M.EVIL_CUTOFF=200
-- A speed point of casting time is 10 game ticks (as for defences); a spell level costs this,
-- times economy.
M.speedSeconds=10/15
M.costPerLevel=0.03
-- Mean enemy armour class and hit points when no enemy shows them.
M.enemyAc=5
M.enemyHp=60

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- The share of a spell slot's cost that counts now (combat-intent/choice.lua, M.slotShare).
local function slots(input) return number(input.slots) and input.slots or 1 end
local function list(t) return type(t)=='table' and t or {} end
local function average(dice,sides)
    if number(dice) and number(sides) and dice>0 and sides>0 then return dice*(sides+1)/2 end
    return 0
end
local function magic(record)
    return (number(record.enchantment) and record.enchantment>0) or
        (number(record.flags) and math.floor(record.flags/64)%2==1) or false
end

-- The side of an EA value, as adapters/eeex/sense.lua groups them: 'evil', 'good' or nil.
function M.side(ea)
    if not number(ea) then return nil end
    if ea>=M.EVIL_CUTOFF then return 'evil' end
    if ea>=2 and ea<=M.GOOD_CUTOFF then return 'good' end
end

-- STRMOD.2DA's bonuses to hit and to damage for a strength (the game's shipped table; exceptional
-- strength 18/01 to 18/00 by its percentile).
M.strength=arsenal.shippedStrength

-- A creature as a fighter, from its CRE record (adapters/eeex/resources.lua), the record of the
-- weapon in its first weapon slot and, for a launcher, of the ammunition in its first filled
-- quiver slot (nil for none): hit points, armour class, THAC0 with its bonuses, attacks a round,
-- the average damage of a hit with what the weapon's own effects add, whether the weapon is
-- magical, its EA and gender, and whether it fights at all. Strength counts for melee only.
function M.profile(cre,weapon,ammo)
    if type(cre)~='table' or not number(cre.maxHp) then return nil end
    local ability=type(weapon)=='table' and type(weapon.abilities)=='table' and weapon.abilities[1] or nil
    if type(ability)~='table' then ability=nil end
    local fighter=cre.maxHp>1 and ability~=nil
    for _,op in ipairs(list(cre.opcodes)) do if M.HIDDEN[op] then fighter=false end end
    local hit,damage,magical,ranged=0,0,false,false
    if ability then
        damage=average(ability.dice,ability.sides)+(number(ability.damageBonus) and ability.damageBonus or 0)+
            weapons.onHit(ability)
        hit=number(ability.thac0) and ability.thac0 or 0
        magical=magic(weapon)
        ranged=ability.attackType==2 or ability.attackType==4
        if ability.attackType==4 then
            local shot=type(ammo)=='table' and type(ammo.abilities)=='table' and ammo.abilities[1] or nil
            if type(shot)=='table' then
                damage=damage+average(shot.dice,shot.sides)+(number(shot.damageBonus) and shot.damageBonus or 0)+
                    weapons.onHit(shot)
                hit=hit+(number(shot.thac0) and shot.thac0 or 0)
                magical=magical or magic(ammo)
            else fighter=false end
        end
    end
    if not ranged then
        local strHit,strDamage=M.strength(cre.strength,cre.strengthExtra)
        hit=hit+strHit
        if ability then damage=damage+strDamage end
    end
    return {resref=cre.resref,maxHp=cre.maxHp,ac=number(cre.ac) and cre.ac or 10,
        thac0=(number(cre.thac0) and cre.thac0 or 20)-hit,apr=math.max(defence.attacks(cre.apr),0),
        damage=math.max(damage,0),magical=magical,ranged=ranged,fighter=fighter,level=cre.level,
        gender=cre.gender,ea=cre.ea}
end
-- A creature of a monster table, which no file names: twice the spell's level in hit dice.
function M.generic(level)
    local hd=math.max(1,2*(number(level) and level or 1))
    return {maxHp=6*hd,ac=5,thac0=math.max(1,20-hd),apr=1,damage=4.5+hd/2,magical=false,ranged=false,fighter=true,
        level=hd,gender=M.SUMMONED}
end

-- The living enemies' mean armour class and maximum hit points, and how many there are.
local function foes(frame)
    local ac,hp,n=0,0,0
    for _,e in ipairs(list(frame.enemies)) do
        if targeting.alive(e) then
            ac=ac+(number(e.ac) and e.ac or M.enemyAc)
            hp=hp+(number(e.maxHp) and e.maxHp>0 and e.maxHp or M.enemyHp)
            n=n+1
        end
    end
    if n==0 then return M.enemyAc,M.enemyHp,0 end
    return ac/n,hp/n,n
end

-- The worth of one summoned creature c over r rounds: the share of an enemy its hits take while it
-- lives, and the share of a friend its body spares, up to its hit points, by drawing share of the
-- blows of the enemies that can strike (the summons is one more body among the friends). It lives
-- until the blows it draws have taken its hit points.
function M.fight(c,frame,r,share)
    if type(c)~='table' or not c.fighter or not number(r) or r<=0 then return 0 end
    local ac,hp,n=foes(frame)
    if n==0 then return 0 end
    local blows=0
    for _,e in ipairs(list(frame.enemies)) do
        if targeting.alive(e) and not targeting.disabled(e) then
            local a=threat.attack(e)
            blows=blows+a.apr*threat.hitChance(a.thac0,c.ac)*a.damage
        end
    end
    local drawn=blows*(number(share) and share or 0)
    local life=drawn>0 and c.maxHp/drawn or math.huge
    local offense=math.min(r,life)*c.apr*threat.hitChance(c.thac0,ac)*c.damage/hp
    local friends,mean=0,0
    for _,f in ipairs(threat.friends(frame)) do
        friends=friends+1
        mean=mean+(number(f.maxHp) and f.maxHp>0 and f.maxHp or 1)
    end
    mean=friends>0 and mean/friends or 1
    local soak=math.min(c.maxHp,r*drawn)/mean
    return offense+soak
end

-- The summon role of a spell the engine casts as a summons, or nil and why not: none, an image
-- or change of shape alone, a summons against the caster (hostile), or one cast at another
-- creature (aimed).
function M.summon(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    local s=spell.roles.summon
    if type(s)~='table' or type(s.who)~='table' or next(s.who)==nil then return nil,'no-summon' end
    if spell.partial then return nil,'partial' end
    local kinds=list(s.kinds)
    if not kinds.creature and not kinds.monsters then return nil,kinds.transform and 'transform' or 'image' end
    if s.hostile then return nil,'hostile' end
    if not s.who.self then return nil,'aimed' end
    return s
end

-- Where a summons goes: on the caster for a spell on itself; for one at a point or a creature, at
-- the group's focus when it is in range, else at the nearest enemy in range, else at the point in
-- range toward the nearest enemy.
local function aim(input,spell)
    local frame=input.frame
    local caster=frame.self
    if spell.target=='self' then return {self=true} end
    if spell.target~='point' and spell.target~='creature' then return nil end
    -- No foe out of play can be aimed at (input.calm, see the top).
    if spell.target=='creature' and number(input.calm) then return nil,'away' end
    local range=(number(spell.range) and spell.range or 0)*targeting.rangeUnit
    local plan=type(input.plan)=='table' and input.plan or {}
    local focus,nearest,far
    for _,e in ipairs(list(frame.enemies)) do
        if targeting.alive(e) and number(e.x) and number(e.y) then
            local d=targeting.distance(caster,e)
            if d<=range then
                if plan.focus==e.id then focus=e end
                if not nearest or d<targeting.distance(caster,nearest) then nearest=e end
            end
            if not far or d<targeting.distance(caster,far) then far=e end
        end
    end
    local e=focus or nearest
    if e then
        if spell.target=='creature' then return {target=e.id} end
        return {point={x=math.floor(e.x+0.5),y=math.floor(e.y+0.5)}}
    end
    if spell.target=='point' and far and range>0 then
        local t=range/targeting.distance(caster,far)
        return {point={x=math.floor(caster.x+(far.x-caster.x)*t+0.5),y=math.floor(caster.y+(far.y-caster.y)*t+0.5)}}
    end
end

-- Every summons the caster can cast now: {resref, kind='summon', mode, worth, cost, score,
-- hits={}, slack=0, speed, creatures (the resrefs it names), monsters (true when it also brings
-- creatures from monster tables), count (the fighters it brings), rest (the seconds of the fight
-- it reckoned with), and self, target or point}. rejected (optional) counts why ready summoning
-- spells gave none; a spell whose creatures are all helpers (no fighters) is no summons and counts
-- nothing.
function M.options(input,rejected)
    local out={}
    local function reject(why) if rejected then rejected['summon-'..why]=(rejected['summon-'..why] or 0)+1 end end
    local mind=input.mind
    local frame=input.frame
    if type(frame)~='table' or type(frame.self)~='table' or type(mind)~='table' then return out end
    local creatures=type(input.creatures)=='table' and input.creatures or {}
    local rest=threat.rest(frame,number(mind.fightCap) and mind.fightCap or 60)
    local calm=number(input.calm) and math.max(0,input.calm) or 0
    local side=M.side(frame.self.ea)
    local summoned=0
    for _,a in ipairs(list(frame.allies)) do
        if targeting.alive(a) and type(a.ids)=='table' and a.ids.gender==M.SUMMONED then summoned=summoned+1 end
    end
    local cap=number(mind.summonCap) and mind.summonCap or math.huge
    local friends=#threat.friends(frame)
    local pictures
    for _,row in ipairs(list(input.spells)) do
        if type(row)=='table' and number(row.ready) and row.ready>0 and row.usable then
            local spell=row.spell
            local role,why=M.summon(spell)
            if not role then
                if why~='no-summon' and why~='unclassified' then reject(why) end
            else
                local cast=(number(spell.speed) and spell.speed or 0)*M.speedSeconds
                -- A summons of limited duration goes when it ends (IESDP: opcode 67 unsummons its
                -- creature after the effect's duration unless the effect is permanent). It fights
                -- once it is there and the calm is over, until the fight or the summons ends.
                local from,till=math.max(cast,calm),calm+rest
                if number(role.duration) then till=math.min(till,cast+role.duration) end
                local r=math.max(0,till-from)/M.ROUND
                local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
                local fromFile=list(role.fromFile)
                local worth,count,named,listed=0,0,{},0
                local capped,unknown,otherSide=false,false,false
                local function add(c,n,file)
                    if not c.fighter then return end
                    if side==nil or (file and M.side(c.ea)~=side) then otherSide=true;return end
                    if c.gender==M.SUMMONED and summoned>=cap then capped=true;return end
                    for i=1,math.ceil(n) do
                        local part=math.min(1,n-i+1)
                        worth=worth+part*M.fight(c,frame,r,1/(friends+count+1))
                        count=count+part
                    end
                end
                for resref,n in pairs(list(role.creatures)) do
                    if number(n) and n>0 then
                        named[#named+1]=resref
                        listed=listed+n
                        local c=creatures[resref]
                        if type(c)~='table' then unknown=true else add(c,n,fromFile[resref]==true) end
                    end
                end
                if type(role.kinds)=='table' and role.kinds.monsters and number(role.count) and role.count-listed>0 then
                    add(M.generic(level),role.count-listed,false)
                end
                table.sort(named)
                local where,off=aim(input,spell)
                if worth<=0 then
                    if capped then reject('cap')
                    elseif unknown then reject('unknown-creature')
                    elseif otherSide then reject('other-side')
                    elseif count>0 then reject('no-worth') end
                elseif not where then reject(off or 'out-of-reach')
                else
                    pictures=pictures or threat.picture(frame)
                    local through=defence.through(input,pictures[frame.self.id],cast)
                    local cost=(number(mind.economy) and mind.economy or 1)*slots(input)*M.costPerLevel*level+
                        (number(mind.castCost) and mind.castCost or 0)*cast
                    local value=worth*through
                    local option={resref=row.resref,kind='summon',worth=value,cost=cost,score=value-cost,hits={},slack=0,
                        speed=number(spell.speed) and spell.speed or 0,creatures=named,count=count,rest=rest,
                        monsters=type(role.kinds)=='table' and role.kinds.monsters==true or nil}
                    if where.self then option.self=true;option.mode='self'
                    elseif where.target then option.target=where.target;option.mode='creature'
                    else option.point=where.point;option.mode='point' end
                    out[#out+1]=option
                end
            end
        end
    end
    return out
end
return M
