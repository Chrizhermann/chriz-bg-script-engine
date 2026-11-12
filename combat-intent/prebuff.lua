-- Native prebuff selection (Prep Phase 2a; Christopher, 2026-11-12: hostile casters prepare
-- through our own code with zero delay, wearing hours-long buffs before combat even begins and
-- firing combat-start prebuffs instantly on contact, while keeping every threshold and cap easy
-- to tune). Phase 2b (contingencies, spell sequencers and triggers) follows next.
--
-- Runtime data classifies every memorized spell (We Overwrite: no hardcoded spell list gates a
-- modded spell out). A spell qualifies when its classified roles protect or buff the caster or
-- its allies without harming friends, summoning, raising, conjuring a slot-locking weapon or
-- turning into an uncontrollable form. Plain invisibility stays with combat-intent/stealth.lua,
-- Sanctuary stays tactical in live rounds, and ultra-short emergency immunities (< minShortSeconds,
-- such as four-round weapon immunities) stay in the spellbook for live combat.
-- Plain values only; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local M={}

M.CONFIG={
    -- Spells whose protection/buff lasts at least longSeconds (30 minutes = 1800s: Stoneskin,
    -- Iron Skins, Armor, Mage Armor, Mind Blank) are 'long' all-day buffs that hostile casters
    -- already keep up out of sight before combat starts.
    longSeconds=1800,
    -- Spells lasting at least minShortSeconds (6 rounds = 36s: Bless, Defensive Harmony, Chant,
    -- Prayer, DUHM, Mirror Image, Blur, Shield, Haste, Minor Globe, Spirit Armor, Free Action,
    -- Chaotic Commands, Improved Invisibility) and below longSeconds are 'short' fight-start
    -- prebuffs. Shorter emergency spells (PfMW 24s, Mantle 24s, Improved Alacrity 12s) stay for
    -- live rounds.
    minShortSeconds=36,
    -- Maximum native prebuffs cast per creature by game difficulty (1..5: Easy..Insane).
    maxLongByDifficulty={1,2,4,6,8},
    maxShortByDifficulty={0,1,3,5,7},
    -- Default difficulty when the game option is unavailable.
    defaultDifficulty=3,
    -- Minimum caster level for out-of-sight 'long' prebuffs and fight-start 'short' prebuffs.
    minLongLevel=1,
    minShortLevel=1,
    -- Spellbook lists eligible for automatic prebuffs (innates stay tactical combat abilities).
    lists={mage=true,priest=true},
}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
local function named(s,name) return type(name)=='string' and name~='' and s==name:upper() end

local function merged(custom)
    if type(custom)~='table' then return M.CONFIG end
    local out={}
    for k,v in pairs(M.CONFIG) do out[k]=custom[k]~=nil and custom[k] or v end
    return out
end

local function forFriends(role)
    if type(role)~='table' or type(role.who)~='table' then return false end
    if role.who.self or role.who.target or role.who.party then return true end
    if role.who.area then
        local f=role.filters
        return type(f)~='table' or f.allies==true or f.all==true
    end
    return false
end

local function ownOnly(who)
    if type(who)~='table' then return false end
    for k,v in pairs(who) do if v and k~='self' then return false end end
    return who.self==true
end

local function harmsFriends(spell)
    for _,name in ipairs({'damage','disable'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' then
            if r.who.self or r.who.party or r.who.everyone or r.who.casterGroup then return true end
            if r.who.area and type(r.filters)=='table' and (r.filters.allies or r.filters.all) then return true end
        end
    end
    return false
end

-- Effective timed span of the spell's protection/buff roles. Cure or child-delivery helpers often
-- carry permanent timing alongside a timed buff (Improved Invisibility 138s, Free Action 180s), so
-- any positive timed effect sets the real span; a pure permanent protection without timed effects
-- (such as an until-struck Stoneskin) counts as all-day.
local function spanOf(p,b,cfg)
    local timed=0
    local permanent=false
    for _,r in ipairs({p or false,b or false}) do
        if type(r)=='table' then
            if number(r.timed) and r.timed>timed then timed=r.timed end
            if r.duration=='permanent' then permanent=true end
        end
    end
    if timed>0 then return timed end
    if permanent then return cfg.longSeconds end
    return 0
end

local function priorityOf(spell,p,b,level,span)
    local pk=type(p)=='table' and type(p.kinds)=='table' and p.kinds or {}
    local bk=type(b)=='table' and type(b.kinds)=='table' and b.kinds or {}
    local tier=120
    if pk.stoneskin then tier=400
    elseif (p and (p.immuneBy or p.bounceBy or p.deflectBy or p.trapBy)) or pk.magicResistance or pk.freeAction or
        pk.chaosShield or pk.sevenEyes then
        tier=300
    elseif pk.mirror or pk.improvedInvisible or pk.weapons or pk.blur or pk.resist or pk.saves then
        tier=220
    elseif bk.haste or bk.improvedHaste or bk.bless or bk.chant or bk.aid or bk.raise or bk.luck or pk.armor or
        bk.strength or bk.thac0 or bk.damage or bk.hp or bk.regeneration or type(spell.hits)=='table' then
        tier=160
    end
    return tier+(number(level) and level or 1)*10+math.min(span,3600)/3600
end

-- Classify one spellbook row for native prebuffing: returns {phase='long'|'short', point=bool,
-- priority=number, span=number, protection=..., buff=...} or nil and the rejection reason.
function M.classify(row,custom)
    local cfg=merged(custom)
    if type(row)~='table' or type(row.resref)~='string' or row.resref=='' then return nil,'bad-row' end
    if not (type(cfg.lists)=='table' and cfg.lists[row.list]) then return nil,'list' end
    local spell=row.spell
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    if spell.choice then return nil,'choice' end
    local target=spell.target
    local point=target=='point' and type(spell.area)=='table'
    if target~='self' and target~='creature' and not point then return nil,'target' end
    local p=forFriends(spell.roles.protection) and spell.roles.protection or nil
    local b=forFriends(spell.roles.buff) and spell.roles.buff or nil
    if not p and not b then return nil,'no-defence' end
    if harmsFriends(spell) then return nil,'harms-friends' end
    for _,name in ipairs({'damage','disable'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' and (r.who.target or r.who.point) then return nil,'attack' end
    end
    for _,name in ipairs({'summon','raise','prepare','move','unlock'}) do
        local r=spell.roles[name]
        if type(r)=='table' and type(r.who)=='table' and next(r.who) then return nil,'role-'..name end
    end
    local heal=spell.roles.heal
    if type(heal)=='table' and type(heal.who)=='table' and next(heal.who) and not ownOnly(heal.who) then
        return nil,'role-heal'
    end
    local pk=p and type(p.kinds)=='table' and p.kinds or {}
    local bk=b and type(b.kinds)=='table' and b.kinds or {}
    if pk.sanctuary then return nil,'sanctuary' end
    if pk.invisible and not pk.improvedInvisible then return nil,'plain-invisibility' end
    if bk.shapechange or bk.berserk or bk.alacrity or bk.weapon or type(spell.weapons)=='table' then
        return nil,'tactical-form'
    end
    local span=spanOf(p,b,cfg)
    if span<cfg.minShortSeconds then return nil,'too-short' end
    local phase=span>=cfg.longSeconds and 'long' or 'short'
    local level=number(row.level) and row.level or number(spell.level) and spell.level or 1
    return {
        resref=row.resref,
        list=row.list,
        level=level,
        phase=phase,
        point=point,
        span=span,
        priority=priorityOf(spell,p,b,level,span),
        protection=p,
        buff=b,
    }
end

local function skippedByOrders(orders,area,resref)
    if type(orders)~='table' then return false end
    if orders.prep==false then return true end
    if type(area)=='string' and area~='' then
        local where=area:upper()
        for _,a in ipairs(type(orders.noPrepIn)=='table' and orders.noPrepIn or {}) do
            if named(where,a) then return true end
        end
    end
    for _,s in ipairs(type(orders.prepSkip)=='table' and orders.prepSkip or {}) do
        if type(s)=='string' then
            local up=s:upper()
            if up=='PREBUFF' or named(up,resref) then return true end
        end
    end
    return false
end

local function reservedByOrders(orders,resref,diff)
    if type(orders)~='table' then return 0 end
    local need=0
    if type(orders.opener)=='table' and (not number(orders.openerFrom) or diff>=orders.openerFrom) then
        for _,step in ipairs(orders.opener) do
            if type(step)=='string' and named(resref,step) then need=1;break end
            if type(step)=='table' then
                local hit=false
                for _,entry in ipairs(step) do
                    if type(entry)=='string' and named(resref,entry) then hit=true;break end
                end
                if hit then need=1;break end
            end
        end
    end
    local extraCount=0
    for _,pair in ipairs({{orders.talkPrep,orders.talkFrom},{orders.prebuff,orders.prebuffFrom}}) do
        local list,from=pair[1],pair[2]
        if type(list)=='table' and (not number(from) or diff>=from) then
            local c=0
            for _,e in ipairs(list) do
                if type(e)=='table' and type(e.spend)=='string' and named(resref,e.spend) then c=c+1 end
            end
            if c>extraCount then extraCount=c end
        end
    end
    return need+extraCount
end

local function alreadyActive(caster,resref,info)
    if type(caster)~='table' then return false end
    local guard=type(caster.guard)=='table' and caster.guard or {}
    if (type(guard.recast)=='table' and guard.recast[resref]) or
        (type(guard.sources)=='table' and guard.sources[resref]) then
        return true
    end
    local pk=info.protection and info.protection.kinds or {}
    local bk=info.buff and info.buff.kinds or {}
    local skins=tonumber(caster.skins) or tonumber(caster.stoneskins) or tonumber(guard.stoneskins) or 0
    local mirror=tonumber(caster.mirror) or tonumber(guard.mirror) or 0
    if pk.stoneskin and skins>0 then return true end
    if pk.mirror and mirror>0 then return true end
    local had=type(guard.kinds)=='table' and guard.kinds or {}
    if pk.improvedInvisible and (had.improvedInvisible or targeting.has(caster.state,targeting.STATE.improvedInvisible)) then return true end
    if bk.improvedHaste and had.improvedHaste then return true end
    if bk.haste and not bk.improvedHaste and (had.haste or had.improvedHaste or targeting.has(caster.state,targeting.STATE.hasted)) then return true end
    return false
end

-- Select the native prebuffs to fire now.
-- input = {frame, caster, spells, difficulty, phase ('long', 'short' or 'both'), orders, area, level, config}
-- Returns an ordered list of {resref, list, level, phase, point, span}.
function M.select(input)
    if type(input)~='table' then return {} end
    local cfg=merged(input.config)
    local caster=(type(input.frame)=='table' and input.frame.self) or input.caster or nil
    local casterLevel=number(input.level) and input.level or (caster and number(caster.level) and caster.level) or nil
    local diff=clamp(math.floor((number(input.difficulty) and input.difficulty or cfg.defaultDifficulty)+0.5),1,5)
    local phase=input.phase or 'both'
    local wantLong=(phase=='long' or phase=='both') and (casterLevel==nil or casterLevel>=cfg.minLongLevel)
    local wantShort=(phase=='short' or phase=='both') and (casterLevel==nil or casterLevel>=cfg.minShortLevel)
    if not wantLong and not wantShort then return {} end

    local maxLong=wantLong and (cfg.maxLongByDifficulty[diff] or 0) or 0
    local maxShort=wantShort and (cfg.maxShortByDifficulty[diff] or 0) or 0
    if maxLong<=0 and maxShort<=0 then return {} end

    local seen={}
    local longPool,shortPool={},{}
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if type(row)=='table' and number(row.ready) and row.ready>reservedByOrders(input.orders,row.resref,diff) and
            row.usable~=false and not seen[row.resref] then
            if not skippedByOrders(input.orders,input.area,row.resref) then
                local info=M.classify(row,cfg)
                if info and not alreadyActive(caster,row.resref,info) then
                    seen[row.resref]=true
                    if info.phase=='long' and maxLong>0 then longPool[#longPool+1]=info
                    elseif info.phase=='short' and maxShort>0 then shortPool[#shortPool+1]=info end
                end
            end
        end
    end

    local function byPriority(a,b)
        if a.priority~=b.priority then return a.priority>b.priority end
        return a.resref<b.resref
    end
    table.sort(longPool,byPriority)
    table.sort(shortPool,byPriority)

    local out={}
    for i=1,math.min(#longPool,maxLong) do out[#out+1]=longPool[i] end
    for i=1,math.min(#shortPool,maxShort) do out[#out+1]=shortPool[i] end
    return out
end

return M
