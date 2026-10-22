-- What threatens a caster and its allies right now, from what the caster perceives (step 3,
-- third slice, D1; DEFENCE-01). Inputs are plain values: the caster's perception frame
-- (adapters/eeex/sense.lua), whose creatures may carry their armour class, attack data and
-- current target. Nothing here touches the engine or raises on odd data; what is unknown counts
-- with the defaults below.
--
-- Harm is counted per round, in hit points, by the way it comes:
-- - weapons: from enemies that can strike the friend (melee within a round's walk, or ranged),
--   with the hits and attacks behind it, which Stoneskin and Mirror Image absorb one by one;
-- - spells: from enemy casters that see the friend, split into spells aimed at one creature and
--   areas, and their chance to disable it.
-- Who an enemy attacks: the friend its current action is aimed at, else the nearest friend it can
-- reach. A caster's spells go to the friend it casts at, else spread over the friends it sees.
-- An invisible friend is safe from weapons and aimed spells of enemies that do not see invisible
-- creatures (lab: party fighters never attacked an invisible SCS mage). This is knowledge SCS's
-- scripts have too (Christopher, 2026-10-18: as much as SCS).
local targeting=require('combat-intent.targeting')
local M={}
M.ROUND=6
-- How far a creature walks in a round, in world units (y counted 4/3): the lab's fighters covered
-- about 100 a second. How far a melee weapon reaches.
M.stride=600
M.reach=64
-- Attack data for an enemy whose weapon or stats were not read: one attack a round, the THAC0 of
-- a mid-level fighter, the average hit of a long sword with a small bonus.
M.unknownAttack={apr=1,thac0=12,damage=7,ranged=false,magical=true}
-- Hit points a round an enemy caster deals per caster level, the share of it aimed at one
-- creature (the rest comes as areas), and the chance a round it disables the friend it casts at.
-- Rough on purpose: they weigh spell protections against weapon protections; the lab tunes them.
M.spellPerLevel=1.2
M.personal=0.6
M.disablePerRound=0.15
-- How much of a class's casting counts: full casters, bards, the half-casting warriors.
M.CASTING={[1]=1,[3]=1,[11]=1,[19]=1,[21]=1,[5]=0.6,[6]=0.2,[12]=0.2,
    [7]=0.8,[8]=0.8,[10]=0.8,[13]=0.8,[14]=0.8,[15]=0.8,[16]=0.6,[17]=0.8,[18]=0.6}
-- Divine casters reach spell level 7, arcane ones 9.
local DIVINE={[3]=true,[8]=true,[11]=true,[14]=true,[15]=true,[16]=true,[17]=true,[18]=true,[21]=true}
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end

-- The chance a d20 attack roll with thac0 hits armour class ac.
function M.hitChance(thac0,ac)
    if not number(thac0) then thac0=M.unknownAttack.thac0 end
    if not number(ac) then ac=10 end
    return clamp((21-(thac0-ac))/20,0.05,0.95)
end

-- An enemy's attack data with the defaults filled in.
function M.attack(e)
    local a=type(e)=='table' and type(e.attack)=='table' and e.attack or {}
    local u=M.unknownAttack
    local apr=number(a.apr) and a.apr>0 and a.apr or u.apr
    return {apr=apr,thac0=number(a.thac0) and a.thac0 or u.thac0,
        damage=number(a.damage) and a.damage>=0 and a.damage or u.damage,
        ranged=a.ranged==true,magical=a.magical~=false,range=number(a.range) and a.range or nil}
end

-- How much of a creature's class casts, 0 for none.
function M.casting(e)
    local class=type(e)=='table' and type(e.ids)=='table' and e.ids.class
    return M.CASTING[class] or 0
end
-- The highest spell level a caster of its class and level casts.
function M.spellLevel(e)
    local level=type(e)=='table' and number(e.level) and e.level or 1
    local class=type(e)=='table' and type(e.ids)=='table' and e.ids.class
    local top=DIVINE[class] and 7 or 9
    return clamp(math.ceil(level/2),1,top)
end

-- The caster and its living allies.
function M.friends(frame)
    local out={}
    if type(frame)~='table' then return out end
    if targeting.alive(frame.self) then out[#out+1]=frame.self end
    for _,a in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
        if targeting.alive(a) then out[#out+1]=a end
    end
    return out
end

-- Whether e can aim at f: f is not hidden from it.
local function sees(e,f) return e.seeInvisible==true or not targeting.has(f.state,UNSEEN) end

local function entry(t,id)
    local r=t[id]
    if not r then
        r={weapon={hp=0,hits=0,attacks=0,magicalAttacks=0,seeing=0},
            spell={hp=0,personal=0,area=0,disable=0,casters=0,level=0,seeing=0},attackers={},casters={}}
        t[id]=r
    end
    return r
end

-- The threat to each friend (the caster and its living allies), by id. Each entry has weapon
-- {hp, hits, attacks, magicalAttacks, seeing} and spell {hp, personal, area, disable, casters,
-- level, seeing} per round, and the ids of the enemies behind them. seeing: the weapon hit
-- points and the aimed spell harm (personal) that come from enemies that see invisible
-- creatures, which invisibility does not keep away (combat-intent/defence.lua).
function M.picture(frame)
    local out={}
    local friends=M.friends(frame)
    if #friends==0 or type(frame.enemies)~='table' then return out end
    local byId={}
    for _,f in ipairs(friends) do byId[f.id]=f;entry(out,f.id) end
    for _,e in ipairs(frame.enemies) do
        if targeting.alive(e) and not targeting.disabled(e) then
            local a=M.attack(e)
            -- Weapons: the friend it is aimed at, else the nearest one it can reach this round. A
            -- creature whose attack is false has none (a caster with nothing in hand, as
            -- combat-intent/removal.lua pictures its own side).
            local reach=a.ranged and (a.range or math.huge) or M.reach+M.stride
            local target=e.attack~=false and byId[e.actee] or nil
            if target and (targeting.distance(e,target)>reach or not sees(e,target)) then target=nil end
            if not target and e.attack~=false then
                local best=math.huge
                for _,f in ipairs(friends) do
                    local d=targeting.distance(e,f)
                    if d<=reach and d<best and sees(e,f) then target,best=f,d end
                end
            end
            if target then
                local r=entry(out,target.id)
                local hit=M.hitChance(a.thac0,target.ac)
                r.weapon.hp=r.weapon.hp+a.apr*hit*a.damage
                r.weapon.hits=r.weapon.hits+a.apr*hit
                r.weapon.attacks=r.weapon.attacks+a.apr
                if a.magical then r.weapon.magicalAttacks=r.weapon.magicalAttacks+a.apr end
                if e.seeInvisible==true then r.weapon.seeing=r.weapon.seeing+a.apr*hit*a.damage end
                r.attackers[#r.attackers+1]=e.id
            end
            -- Spells: the friend it casts at, else spread over the friends it sees. Areas reach
            -- hidden friends too.
            local weight=M.casting(e)
            if weight>0 then
                local level=number(e.level) and e.level or 1
                local aimed=targeting.casting(e) and byId[e.actee]
                local near={}
                if aimed then near[1]=aimed
                else
                    for _,f in ipairs(friends) do
                        if targeting.distance(e,f)<=448 then near[#near+1]=f end
                    end
                end
                for _,f in ipairs(near) do
                    local harm=weight*M.spellPerLevel*level/#near
                    local r=entry(out,f.id)
                    local open=sees(e,f)
                    local personal=open and harm*M.personal or 0
                    r.spell.personal=r.spell.personal+personal
                    if e.seeInvisible==true then r.spell.seeing=r.spell.seeing+personal end
                    r.spell.area=r.spell.area+harm*(1-M.personal)
                    r.spell.hp=r.spell.personal+r.spell.area
                    if open then r.spell.disable=math.min(0.95,r.spell.disable+weight*M.disablePerRound/#near) end
                    r.spell.casters=r.spell.casters+weight/#near
                    r.spell.level=math.max(r.spell.level,M.spellLevel(e))
                    r.casters[#r.casters+1]=e.id
                end
            end
        end
    end
    return out
end

-- The caster's weapon in hand (frame.self.weapon, adapters/eeex/sense.lua) as attack data, or
-- false without one: the caster strikes with it or not at all.
function M.wielded(caster)
    local w=type(caster)=='table' and caster.weapon
    if type(w)~='table' or not number(w.damage) then return false end
    local flags=number(w.flags) and w.flags or 0
    return {apr=number(w.apr) and w.apr or caster.apr,thac0=number(w.thac0) and w.thac0 or caster.thac0,
        damage=w.damage,ranged=w.ranged==true,range=w.range,
        magical=(number(w.enchantment) and w.enchantment>0) or math.floor(flags/64)%2==1}
end

-- How many seconds the fight is expected to last from now, from both sides' strength: each side's
-- harm a round (the weapons of its living creatures that are not disabled, against the other
-- side's mean armour class, and its casters' spells at spellPerLevel a caster level) against the
-- other side's hit points left. The side that needs fewer rounds ends it; neither side's harm
-- falls as its creatures die, so this errs short. At most cap seconds; 0 when a side has no one
-- left.
function M.rest(frame,cap)
    cap=number(cap) and cap>=0 and cap or math.huge
    if type(frame)~='table' then return 0 end
    local friends=M.friends(frame)
    local enemies={}
    for _,e in ipairs(type(frame.enemies)=='table' and frame.enemies or {}) do
        if targeting.alive(e) then enemies[#enemies+1]=e end
    end
    if #friends==0 or #enemies==0 then return 0 end
    local function body(side)
        local hp,ac=0,0
        for _,c in ipairs(side) do
            hp=hp+(number(c.hp) and c.hp>0 and c.hp or number(c.maxHp) and c.maxHp>0 and c.maxHp or 1)
            ac=ac+(number(c.ac) and c.ac or 10)
        end
        return hp,ac/#side
    end
    local function harm(side,ac)
        local total=0
        for _,c in ipairs(side) do
            if not targeting.disabled(c) then
                local held=c.attack
                if c==frame.self then held=M.wielded(c) end
                if held~=false then
                    local a=M.attack({attack=held})
                    total=total+a.apr*M.hitChance(a.thac0,ac)*a.damage
                end
                total=total+M.casting(c)*M.spellPerLevel*(number(c.level) and c.level or 1)
            end
        end
        return total
    end
    local ourHp,ourAc=body(friends)
    local theirHp,theirAc=body(enemies)
    local ours,theirs=harm(friends,theirAc),harm(enemies,ourAc)
    local win=ours>0 and M.ROUND*theirHp/ours or math.huge
    local lose=theirs>0 and M.ROUND*ourHp/theirs or math.huge
    return math.min(win,lose,cap)
end
return M
