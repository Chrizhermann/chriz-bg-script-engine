-- Native contingencies, chain contingencies, sequencers and spell triggers (Prep Phase 2b;
-- Christopher, 2026-11-12).
--
-- Design agreements:
--   1. Zero today-slot debit: prepared contingencies, chain contingencies, sequencers and spell
--      triggers represent spells loaded the day before and rested over; building or firing them
--      spends no memorized spell slot of today's fight.
--   2. True 0.00s instant evaluation (Fair Play): contingencies and chain contingencies evaluate
--      live without the Infinity Engine's 100-tick opcode-232 lag or BCS pass delay, strictly while
--      the caster is alive (HP > 0, not dead) so a true one-shot kill from above a threshold still
--      beats an unfired threshold contingency.
--   3. Optional Challenge-Mode rule (defensiveContingenciesOnly): when enabled, Contingencies and
--      Chain Contingencies never hold offensive spells (damage, disable, debuff or dispel/removal);
--      only protections, buffs and summons qualify. Sequencers and Spell Triggers remain free to
--      hold offensive spells, except pure dispel-only bundles which are never auto-built.
--   4. Runtime data under We Overwrite: candidate spells are classified from the caster's actual
--      spellbook records at the caster's level, never hardcoded vanilla resref tables.
--
-- Pure policy module: plain values only; no EEex or engine calls.
local spells=require('combat-intent.spells')
local M={}

-- Central tunable parameters for Phase 2b contingencies, chain contingencies and sequencers.
M.CONFIG={
    -- Optional Challenge-Mode rule: forbid damage, disable, debuff and removal spells in
    -- Contingency and Chain Contingency (only protections, buffs and summons allowed).
    defensiveContingenciesOnly=false,

    -- Minimum game difficulty (1..5) for automatic preparation.
    minDifficultyContingency=2,
    minDifficultyChain=3,
    minDifficultyOffensiveChain=4,
    minDifficultySequencer=2,
    minDifficultyHighSequencer=3,

    -- Standard wizard caster-level gates and spell-level caps.
    minor={minLevel=7,maxSpellLevel=2,slots=2,resref='BGSE#MS',callout='msq_fired'},
    contingency={minLevel=12,maxSpellLevel=6,slots=1,callout='ctg_fired'},
    sequencer={minLevel=14,maxSpellLevel=4,slots=3,resref='BGSE#SQ',callout='seq_fired'},
    trigger={minLevel=16,maxSpellLevel=6,slots=3,resref='BGSE#TG',callout='trg_fired'},
    chain={minLevel=18,maxSpellLevel=8,slots=3,callout='cc_fired'},

    -- Emergency trigger thresholds (0.00s check while alive).
    hpEmergencyPct=50,
    closeThreatRange=180,
}

M.CALLOUTS={
    {key='ctg_fired',text='Contingency - Fired'},
    {key='cc_fired',text='Chain Contingency - Fired'},
    {key='msq_fired',text='Minor Sequencer - Fired'},
    {key='seq_fired',text='Spell Sequencer - Fired'},
    {key='trg_fired',text='Spell Trigger - Fired'},
}

local OFFENSIVE_ROLES={'damage','disable','debuff','removal'}
local HARMS_ALLIES={everyone=true,nonparty=true,casterGroup=true}

local function mergeConfig(custom)
    if type(custom)~='table' then return M.CONFIG end
    local out={}
    for k,v in pairs(M.CONFIG) do out[k]=v end
    for k,v in pairs(custom) do out[k]=v end
    return out
end

local function isBlockedByPrep(orders,area,kind)
    if type(orders)~='table' then return false end
    if orders.prep==false then return true end
    if type(area)=='string' and area~='' and type(orders.noPrepIn)=='table' then
        local up=area:upper()
        for _,a in ipairs(orders.noPrepIn) do
            if type(a)=='string' and a:upper()==up then return true end
        end
    end
    if type(orders.prepSkip)=='table' then
        local want=kind:upper()
        for _,s in ipairs(orders.prepSkip) do
            if type(s)=='string' and s:upper()==want then return true end
        end
    end
    return false
end

-- Whether classified spell c has any offensive role (damage, disable, debuff, removal).
function M.isOffensive(c)
    if type(c)~='table' or type(c.roles)~='table' then return false end
    for _,r in ipairs(OFFENSIVE_ROLES) do
        if type(c.roles[r])=='table' then return true end
    end
    return false
end

-- Whether classified spell c is an indiscriminantly ally-harming area explosion.
local function harmsAllies(c)
    if type(c)~='table' then return false end
    if c.friendlyFire or c.selfHarm then return true end
    if type(c.roles)~='table' then return false end
    for _,r in ipairs(OFFENSIVE_ROLES) do
        local role=c.roles[r]
        if type(role)=='table' and type(role.who)=='table' then
            for group in pairs(HARMS_ALLIES) do
                if role.who[group] then return true end
            end
        end
    end
    return false
end

-- Whether classified spell c is unsuitable to put inside an automated package (sequencer/contingency
-- builders themselves, conjured slot-locking weapons, berserk/shapechange, or partial/unclassified).
local function unusableInPackage(c)
    if type(c)~='table' or c.partial or type(c.roles)~='table' then return true end
    if type(c.roles.prepare)=='table' then return true end
    if c.weapons~=nil or c.weapon~=nil or c.touch~=nil then return true end
    local p=c.roles.protection
    local b=c.roles.buff
    local pk=type(p)=='table' and p.kinds or nil
    local bk=type(b)=='table' and b.kinds or nil
    if (pk and (pk.sanctuary or pk.form)) or (bk and (bk.berserk or bk.form)) then return true end
    return false
end

-- Score a candidate spell for self-defensive Contingency / emergency Chain Contingency.
local function defensiveScore(c)
    if unusableInPackage(c) or M.isOffensive(c) then return 0 end
    if c.target~='self' and not (c.target=='point' and c.area~=nil) then return 0 end
    local p=c.roles.protection
    local b=c.roles.buff
    if not p and not b then return 0 end
    local pk=p and p.kinds or {}
    local bk=b and b.kinds or {}
    local s=(tonumber(c.level) or 1)*2
    if pk.weapons then s=s+50 end
    if pk.improvedInvisible then s=s+30 end
    if pk.stoneskin then s=s+28 end
    if pk.turning or pk.trap or pk.deflection or pk.spellShield or pk.screen then s=s+24 end
    if pk.globe then s=s+18 end
    if pk.mirror then s=s+15 end
    if pk.mind or pk.death or pk.elements or pk.magicDamage then s=s+12 end
    if pk.armor or bk.ac or bk.saves then s=s+8 end
    return s
end

-- Score a candidate spell for summon slots inside Chain Contingency.
local function summonScore(c)
    if unusableInPackage(c) or M.isOffensive(c) then return 0 end
    local sum=c.roles.summon
    if type(sum)~='table' then return 0 end
    return 25+(tonumber(c.level) or 1)*5
end

-- Score a party-safe offensive spell for Chain Contingency or offensive Sequencers/Triggers.
local function offensiveScore(c,requirePartySafe)
    if unusableInPackage(c) or not M.isOffensive(c) then return 0 end
    if c.target=='self' and c.area==nil then return 0 end
    if requirePartySafe and harmsAllies(c) then return 0 end
    -- Never auto-build pure dispel/removal contingencies or sequencers (Christopher's dispel rule).
    local rem=c.roles.removal
    local rk=rem and rem.kinds or nil
    if rem and not c.roles.damage and not c.roles.disable and not c.roles.debuff then
        if rk and rk.dispel and not rk.schools and not rk.secondaries and not rk.opcodes then return 0 end
    end
    local s=(tonumber(c.level) or 1)*6
    if c.roles.damage then s=s+20 end
    if c.roles.disable then s=s+18 end
    if c.roles.debuff then s=s+14 end
    if rk and (rk.schools or rk.secondaries or rk.opcodes) then s=s+16 end
    if c.area~=nil and not harmsAllies(c) then s=s+12 end
    return s
end

-- Delivery mode for a sub-spell inside a Contingency / Chain Contingency ('self', 'feet', 'enemy').
function M.deliveryOf(c)
    if type(c)~='table' then return 'self' end
    if M.isOffensive(c) and c.target~='self' then return 'enemy' end
    if c.roles and c.roles.summon and c.target~='self' then return 'feet' end
    if c.target=='point' then return 'feet' end
    return 'self'
end

local function normalizePool(pool)
    local out,seen={},{}
    for _,row in ipairs(type(pool)=='table' and pool or {}) do
        if type(row)=='table' and (row.list==nil or row.list=='mage') and type(row.resref)=='string' and
            row.resref~='' and type(row.spell)=='table' then
            local key=row.resref:upper()
            if not seen[key] then
                seen[key]=true
                local lvl=tonumber(row.spell.level) or tonumber(row.level) or 1
                out[#out+1]={resref=key,level=lvl,spell=row.spell}
            end
        end
    end
    table.sort(out,function(a,b)
        if a.level~=b.level then return a.level>b.level end
        return a.resref<b.resref
    end)
    return out
end

local function resolveSpell(resref,byResref,casterLevel,lookup)
    local key=type(resref)=='string' and resref:upper() or ''
    if key=='' then return nil end
    if byResref[key] then return byResref[key] end
    if type(lookup)=='function' then
        local ok,rec=pcall(lookup,'SPL',key)
        if ok and type(rec)=='table' then
            local c=spells.classify(rec,M.abilityIndex(rec,casterLevel),lookup,{level=casterLevel})
            if type(c)=='table' and not c.partial then
                return {resref=key,level=tonumber(c.level) or tonumber(rec.level) or 1,spell=c}
            end
        end
    end
    return nil
end

function M.abilityIndex(rec,casterLevel)
    return spells.abilityForLevel(rec,casterLevel or 1) or 1
end

-- Synthesize a classified innate release spell record (c.release == true) for a virtual native
-- Minor Sequencer, Spell Sequencer or Spell Trigger so choice.lua, defence.lua and removal.lua
-- weigh and fire it through the standard release path without disk SPL files.
function M.synthesizeRelease(resref,subs,selfOnly,casterLevel,lookup)
    if type(resref)~='string' or type(subs)~='table' or #subs<2 or type(lookup)~='function' then return nil end
    local effects={}
    for _,sub in ipairs(subs) do
        effects[#effects+1]={
            opcode=146,
            target=selfOnly and 1 or 2,
            power=0,
            p1=0,
            p2=1,
            timing=0,
            resist=0,
            duration=0,
            prob1=100,
            prob2=0,
            res=sub:upper(),
            dice=0,
            sides=0,
            save=0,
            saveBonus=0,
            special=0,
        }
    end
    local synthetic={
        kind='SPL',
        resref=resref:upper(),
        name=0,
        flags=selfOnly and 0 or 0x400,
        spellType=4,
        exclusion=0,
        school=0,
        secondary=0,
        level=1,
        casting={},
        abilities={{
            form=1,
            flags=0,
            location=4,
            target=selfOnly and 5 or 1,
            targetCount=0,
            range=selfOnly and 0 or 30,
            minLevel=1,
            speed=0,
            projectile=1,
            effects=effects,
        }},
    }
    local wrapped=function(kind,key)
        if kind=='SPL' and type(key)=='string' and key:upper()==synthetic.resref then return synthetic end
        return lookup(kind,key)
    end
    local c=spells.classify(synthetic,1,wrapped,{level=casterLevel or 1})
    if type(c)~='table' or c.partial then return nil end
    if selfOnly then c.release=true;c.ownRange=0;c.range=0 end
    c.nativeSubs={}
    for i,s in ipairs(subs) do c.nativeSubs[i]=s:upper() end
    return c
end

local function buildContingency(casterLevel,difficulty,entries,byResref,orders,area,lookup,cfg)
    if isBlockedByPrep(orders,area,'contingency') then return nil end
    if type(orders)=='table' and orders.contingency==false then return nil end
    if type(orders)=='table' and orders.contingency~=nil then
        local spec=orders.contingency
        local res=type(spec)=='string' and spec or (type(spec)=='table' and spec.spell)
        local cond=(type(spec)=='table' and spec.condition) or 'emergency'
        local entry=resolveSpell(res,byResref,casterLevel,lookup)
        if entry and (not cfg.defensiveContingenciesOnly or not M.isOffensive(entry.spell)) then
            return {
                kind='contingency',
                condition=cond,
                callout=cfg.contingency.callout,
                spells={{resref=entry.resref,spell=entry.spell,delivery=M.deliveryOf(entry.spell)}},
            }
        end
        return nil
    end
    if casterLevel<cfg.contingency.minLevel or difficulty<cfg.minDifficultyContingency then return nil end
    local cap=math.min(cfg.contingency.maxSpellLevel,math.floor(casterLevel/3))
    local best,bestScore=nil,0
    for _,e in ipairs(entries) do
        if e.level<=cap then
            local sc=defensiveScore(e.spell)
            if sc>bestScore then best,bestScore=e,sc end
        end
    end
    if not best then return nil end
    return {
        kind='contingency',
        condition='emergency',
        callout=cfg.contingency.callout,
        spells={{resref=best.resref,spell=best.spell,delivery=M.deliveryOf(best.spell)}},
    }
end

local function buildChain(casterLevel,difficulty,entries,byResref,orders,area,lookup,cfg,contingencyResref)
    if isBlockedByPrep(orders,area,'chain') then return nil end
    if type(orders)=='table' and orders.chain==false then return nil end
    if type(orders)=='table' and type(orders.chain)=='table' then
        local list=type(orders.chain.spells)=='table' and orders.chain.spells or orders.chain
        local cond=orders.chain.condition or 'seen'
        local out={}
        for _,res in ipairs(list) do
            if #out>=cfg.chain.slots then break end
            local entry=resolveSpell(res,byResref,casterLevel,lookup)
            if entry and (not cfg.defensiveContingenciesOnly or not M.isOffensive(entry.spell)) then
                out[#out+1]={resref=entry.resref,spell=entry.spell,delivery=M.deliveryOf(entry.spell)}
            end
        end
        if #out==0 then return nil end
        return {kind='chain',condition=cond,callout=cfg.chain.callout,spells=out}
    end
    if casterLevel<cfg.chain.minLevel or difficulty<cfg.minDifficultyChain then return nil end
    local cap=cfg.chain.maxSpellLevel
    local bestWard,wardScore=nil,0
    local bestSummon,sumScore=nil,0
    local bestOff,offScore=nil,0
    local allowOff=not cfg.defensiveContingenciesOnly and difficulty>=cfg.minDifficultyOffensiveChain
    for _,e in ipairs(entries) do
        if e.level<=cap and e.resref~=contingencyResref then
            local ws=defensiveScore(e.spell)
            if ws>wardScore then bestWard,wardScore=e,ws end
            local ss=summonScore(e.spell)
            if ss>sumScore then bestSummon,sumScore=e,ss end
            if allowOff then
                local os=offensiveScore(e.spell,true)
                if os>offScore then bestOff,offScore=e,os end
            end
        end
    end
    local picked={}
    local condition='seen'
    if bestWard then
        picked[#picked+1]={resref=bestWard.resref,spell=bestWard.spell,delivery=M.deliveryOf(bestWard.spell)}
    end
    if allowOff and bestOff and offScore>=sumScore then
        while #picked<cfg.chain.slots do
            picked[#picked+1]={resref=bestOff.resref,spell=bestOff.spell,delivery='enemy'}
        end
    elseif bestSummon then
        while #picked<cfg.chain.slots do
            picked[#picked+1]={resref=bestSummon.resref,spell=bestSummon.spell,delivery=M.deliveryOf(bestSummon.spell)}
        end
    else
        -- Pure defensive fallback: fill remaining slots with distinct wards and trigger on emergency!
        condition='hp50'
        local used={[bestWard and bestWard.resref or '']=true,[contingencyResref or '']=true}
        for _,e in ipairs(entries) do
            if #picked>=cfg.chain.slots then break end
            if e.level<=cap and not used[e.resref] and defensiveScore(e.spell)>0 then
                used[e.resref]=true
                picked[#picked+1]={resref=e.resref,spell=e.spell,delivery=M.deliveryOf(e.spell)}
            end
        end
    end
    if #picked==0 then return nil end
    return {kind='chain',condition=condition,callout=cfg.chain.callout,spells=picked}
end

local function hasExistingTier(existingInnates,tier)
    if type(existingInnates)~='table' then return false end
    for res in pairs(existingInnates) do
        local up=type(res)=='string' and res:upper() or ''
        if tier=='minor' and (up:sub(1,5)=='DW#MS' or up=='DW#DT11') then return true end
        if tier=='sequencer' and up:sub(1,5)=='DW#SQ' then return true end
        if tier=='trigger' and (up:sub(1,5)=='DW#TG' or up=='DW#DT0') then return true end
    end
    return false
end

local function buildTierSequencer(tier,spec,casterLevel,difficulty,entries,byResref,orders,existingInnates,lookup,cfg)
    if type(orders)=='table' and orders.sequencers==false then return nil end
    local explicit=type(orders)=='table' and type(orders.sequencers)=='table' and orders.sequencers[tier] or nil
    if explicit==false then return nil end
    if type(explicit)=='table' and #explicit>=2 then
        local subs,selfOnly={},true
        for _,res in ipairs(explicit) do
            if #subs>=spec.slots then break end
            local e=resolveSpell(res,byResref,casterLevel,lookup)
            if e then
                subs[#subs+1]=e.resref
                if e.spell.target~='self' then selfOnly=false end
            end
        end
        if #subs>=2 then
            local rel=M.synthesizeRelease(spec.resref,subs,selfOnly,casterLevel,lookup)
            if rel then return {tier=tier,resref=spec.resref,callout=spec.callout,subs=subs,selfOnly=selfOnly,spell=rel} end
        end
        return nil
    end
    if hasExistingTier(existingInnates,tier) then return nil end
    local minDiff=tier=='minor' and cfg.minDifficultySequencer or cfg.minDifficultyHighSequencer
    if casterLevel<spec.minLevel or difficulty<minDiff then return nil end
    -- Prefer single-target creature offensive spells (cleanest projectile combos like 2x Acid Arrow / Magic Missile / Flame Arrow).
    local bestOff,bestScore=nil,0
    for _,e in ipairs(entries) do
        if e.level<=spec.maxSpellLevel and e.spell.target=='creature' and not harmsAllies(e.spell) then
            local sc=offensiveScore(e.spell,true)
            if sc>bestScore then bestOff,bestScore=e,sc end
        end
    end
    if bestOff then
        local subs={}
        for i=1,spec.slots do subs[i]=bestOff.resref end
        local rel=M.synthesizeRelease(spec.resref,subs,false,casterLevel,lookup)
        if rel then return {tier=tier,resref=spec.resref,callout=spec.callout,subs=subs,selfOnly=false,spell=rel} end
    end
    -- Fallback: distinct self-defensive wards in a defensive sequencer/trigger.
    local wards={}
    for _,e in ipairs(entries) do
        if #wards>=spec.slots then break end
        if e.level<=spec.maxSpellLevel and e.spell.target=='self' and defensiveScore(e.spell)>0 then
            wards[#wards+1]=e.resref
        end
    end
    if #wards>=2 then
        local rel=M.synthesizeRelease(spec.resref,wards,true,casterLevel,lookup)
        if rel then return {tier=tier,resref=spec.resref,callout=spec.callout,subs=wards,selfOnly=true,spell=rel} end
    end
    return nil
end

-- Build a wizard's Phase 2b preparation loadout:
--   input = {level, difficulty, spells, innates, orders, area, lookup, config}
-- Returns {contingency=..., chain=..., sequencers={...}}.
function M.build(input)
    if type(input)~='table' then return {sequencers={}} end
    local cfg=mergeConfig(input.config)
    local level=tonumber(input.level) or 1
    local diff=tonumber(input.difficulty) or 3
    local entries=normalizePool(input.spells)
    local byResref={}
    for _,e in ipairs(entries) do byResref[e.resref]=e end
    local ctg=buildContingency(level,diff,entries,byResref,input.orders,input.area,input.lookup,cfg)
    local ctgRes=ctg and ctg.spells[1] and ctg.spells[1].resref or nil
    local chn=buildChain(level,diff,entries,byResref,input.orders,input.area,input.lookup,cfg,ctgRes)
    local seqs={}
    if not isBlockedByPrep(input.orders,input.area,'contingency') and
        not isBlockedByPrep(input.orders,input.area,'sequencer') then
        for _,pair in ipairs({{'minor',cfg.minor},{'sequencer',cfg.sequencer},{'trigger',cfg.trigger}}) do
            local built=buildTierSequencer(pair[1],pair[2],level,diff,entries,byResref,
                input.orders,input.innates,input.lookup,cfg)
            if built then seqs[#seqs+1]=built end
        end
    end
    return {contingency=ctg,chain=chn,sequencers=seqs}
end

-- Pure 0.00s trigger check for a prepared Contingency or Chain Contingency.
-- state = {alive, enemiesSeen, hpPct, nearestEnemyDist, skins, weaponWard}
function M.shouldTrigger(entry,state,config)
    if type(entry)~='table' or type(state)~='table' then return false end
    -- Guardrail #1: dead / one-shotted casters (HP <= 0) never trigger contingencies!
    if state.alive~=true then return false end
    local seen=tonumber(state.enemiesSeen) or 0
    if seen<=0 then return false end
    local cfg=mergeConfig(config)
    local cond=entry.condition or 'seen'
    local hpPct=tonumber(state.hpPct) or 100
    if cond=='seen' then return true end
    if cond=='hp75' then return hpPct<=75 end
    if cond=='hp50' then return hpPct<=50 end
    if cond=='emergency' then
        if hpPct<=(cfg.hpEmergencyPct or 50) then return true end
        local near=tonumber(state.nearestEnemyDist)
        if near and near<=(cfg.closeThreatRange or 180) and (tonumber(state.skins) or 0)<=0 and not state.weaponWard then
            return true
        end
    end
    return false
end

return M
