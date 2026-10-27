-- EEex side of a thief's own hide and a monster's veil (combat-intent/stealth.lua), for the choice
-- adapter (adapters/eeex/choice.lua). It reads what the rule needs of the creature (its class, its
-- Hide in Shadows skill and the game's modal state), keeps for each creature whether its stretch out
-- of sight draws the hide or veil and when it last tried, and holds a hide: while the creature runs
-- the game's Hide() action (graceTicks until it starts) or stays in the game's stealth mode, until it
-- is hidden and hideTicks at most, never once an enemy shows or the creature is hurt. Then the try is
-- judged: a 'hidden' row tells whether the creature came out invisible (STATE_INVISIBLE, which the
-- game's hiding in shadows sets as players know it; a lab is to measure it) and what the game's own
-- hiding fields read, where the engine offers them. A veil is a cast of the creature's innate
-- invisibility at itself, which the choice adapter queues, holds and judges as its other casts: a
-- 'veil' row when it is queued and a 'veiled' row with whether the creature is invisible after it.
-- Which kinds of innate invisibility a creature has (owns) also counts those coming back after their
-- use. Session-local; a load forgets it all.
local sense=require('adapters.eeex.sense')
local stealth=require('combat-intent.stealth')
local search=require('combat-intent.search')
local targeting=require('combat-intent.targeting')
local M={}
-- Hide() (ACTION.IDS); STATS.IDS HIDEINSHADOWS.
M.HIDE=18
M.skillStat=135
-- A try is held graceTicks until its action starts, and hideTicks at most.
M.graceTicks=8
M.hideTicks=45
M.cacheLimit=1024
-- Give Innate Ability (opcode 171), and the live m_durationType of a delayed effect while its delay
-- runs: 6 for a delayed limited one, 7 for a delayed permanent one (ie-duration, BG2:EE 2.7.3.0). An
-- innate ability that comes back after its use waits so in its user's timed effects.
M.GIVE=171
M.PENDING={[6]=true,[7]=true}
local INVISIBLE=targeting.STATE.invisible
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

-- A field of the sprite, or nil when the engine does not offer it.
local function field(sprite,name)
    local ok,v=pcall(function() return sprite[name] end)
    if ok and (type(v)=='number' or type(v)=='boolean') then return v end
    return nil
end
local function text(value) return (value:match('^[^%z]*'):upper()) end

-- options: record (the log), rng, classify(resref) (a spell's classification, combat-intent/
-- spells.lua, or nil).
function M.new(g,options)
    options=options or {}
    local record=type(options.record)=='function' and options.record or function() end
    local classify=type(options.classify)=='function' and options.classify or function() return nil end
    local rng=options.rng
    local states,stateCount={},0
    local counts={hides=0,hidden=0,unhidden=0,draws=0,veils=0,veiled=0,unveiled=0}
    local hider={}
    local function state(id)
        local s=states[id]
        if not s then
            if stateCount>=M.cacheLimit then states,stateCount={},0 end
            s={}
            states[id]=s;stateCount=stateCount+1
        end
        return s
    end
    -- What the rule reads of the creature, added to self (a plain copy): its class (CLASS.IDS), its
    -- Hide in Shadows skill and the game's modal state (nil when the engine does not offer it).
    local function read(sprite,self)
        self.class=sprite.m_typeAI.m_Class
        local skill=g.EEex_Sprite_GetStat(sprite,M.skillStat)
        self.hideSkill=type(skill)=='number' and skill or 0
        local mode=field(sprite,'m_nModalState')
        self.modal=type(mode)=='number' and mode or nil
        return self
    end
    -- Whether the creature can hide by its own skill (stealth.able).
    function hider:able(sprite) return stealth.able(read(sprite,{})) end
    -- The kinds of innate invisibility the creature has (stealth.kind), ready or used, and those coming
    -- back to it after their use (a delayed 171 in its timed effects, M.PENDING): {plain, improved,
    -- veil: one of them may veil it (stealth.veiling)}. Asked once a tick per creature at most.
    function hider:owns(sprite,tick)
        local s=state(sprite.m_id)
        if s.owned and s.ownedAt==tick then return s.owned end
        local out={}
        local function note(resref)
            if resref=='' then return end
            local c=classify(resref)
            local kind=stealth.kind(c)
            if not kind then return end
            out[kind]=true
            if stealth.veiling({kind=kind,recharge=c.recharge}) then out.veil=true end
        end
        g.EEex_Utility_IterateCPtrList(sprite.m_memorizedSpellsInnate:getReference(0),function(spell)
            note(text(spell.m_spellId:get()))
        end)
        local seen=0
        g.EEex_Utility_IterateCPtrList(sprite.m_timedEffectList,function(e)
            seen=seen+1
            if seen>sense.maxEffects then return true end
            if e.m_effectId==M.GIVE and M.PENDING[e.m_durationType] then note(text(e.m_res:get())) end
        end)
        s.owned,s.ownedAt=out,tick
        return out
    end
    -- An enemy in sight: the stretch out of sight is over, and the next draws afresh.
    function hider:fight(id)
        local s=states[id]
        if s then s.tactical=nil end
    end
    -- With no enemy in sight: the rule's decision (stealth.decide), or nil and why. m: the creature's
    -- profile; orders: its designer's orders; rows: its ready spells and innate abilities, classified
    -- (for its veils). A creature that could hide or veil itself draws once a stretch whether it
    -- thinks of it (search.draw, by its wit).
    function hider:decide(sprite,frame,tick,m,orders,rows)
        local self=read(sprite,frame.self)
        local s=state(self.id)
        local able=stealth.able(self)
        local veils=not able and stealth.veils(rows) or nil
        if s.tactical==nil and (able or stealth.pick(veils)~=nil) and type(m)=='table' and m.hide~=false then
            s.tactical=search.draw(m,rng);counts.draws=counts.draws+1
        end
        local d,why=stealth.decide({tick=tick,frame=frame,veils=veils,mind=m,orders=orders,tactical=s.tactical,
            tried=s.tried})
        if d then
            d.skill=d.kind=='hide' and self.hideSkill or nil
            d.tactical,d.wit=s.tactical,type(m)=='table' and m.wit or nil
        end
        return d,why
    end
    -- The try queued at tick (Hide()): held from here, with a 'hide' row.
    function hider:start(sprite,decision,tick)
        local id=sprite.m_id
        local s=state(id)
        s.tried=tick
        s.act={tick=tick,hp=sprite.m_baseStats.m_hitPoints}
        counts.hides=counts.hides+1
        record({kind='hide',tick=tick,member=id,skill=decision.skill,wit=decision.wit,tactical=decision.tactical,
            ordered=decision.ordered,greyed=field(sprite,'m_nStealthGreyOut')})
    end
    -- A veil queued at tick (its cast, which the choice adapter holds): a 'veil' row, and the try
    -- counts for the round.
    function hider:veil(sprite,decision,tick)
        state(sprite.m_id).tried=tick
        counts.veils=counts.veils+1
        record({kind='veil',tick=tick,member=sprite.m_id,spell=decision.spell,improved=decision.improved,
            recharge=decision.recharge,wit=decision.wit,tactical=decision.tactical,ordered=decision.ordered})
    end
    -- A veil's cast once it is over (the choice adapter's judgement): a 'veiled' row with whether its
    -- caster is invisible now.
    function hider:judge(sprite,cast)
        local hidden=targeting.has(g.EEex_Sprite_GetState(sprite),UNSEEN)
        if hidden then counts.veiled=counts.veiled+1 else counts.unveiled=counts.unveiled+1 end
        record({kind='veiled',tick=cast.ended,member=cast.caster,spell=cast.resref,hidden=hidden})
    end
    -- Whether the try goes on (see the top); once it is over it is judged.
    function hider:holding(sprite,id,tick)
        local s=states[id]
        local a=s and s.act
        if not a then return false end
        local took=tick-a.tick
        local hidden=targeting.has(g.EEex_Sprite_GetState(sprite),INVISIBLE)
        local mode=field(sprite,'m_nModalState')
        local why
        if took<0 or took>=M.hideTicks then why='limit'
        elseif hidden then why='hidden'
        elseif took>=M.graceTicks and sprite.m_curAction.m_actionID~=M.HIDE and mode~=stealth.stealthMode then why='ended'
        elseif sprite.m_baseStats.m_hitPoints<a.hp then why='hurt'
        elseif sense.seesEnemy(g,sprite) then why='seen' end
        if not why then return true end
        s.act=nil
        if hidden then counts.hidden=counts.hidden+1 else counts.unhidden=counts.unhidden+1 end
        record({kind='hidden',tick=tick,member=id,hidden=hidden,why=why,took=math.max(took,0),modal=mode,
            hiding=field(sprite,'m_bHiding'),counter=field(sprite,'m_modalCounter'),greyed=field(sprite,'m_nStealthGreyOut')})
        return false
    end
    function hider:stop(id)
        local s=states[id]
        if s then s.act=nil end
    end
    function hider:invalidate() states,stateCount={},0 end
    function hider:inspect()
        local c={}
        for k,v in pairs(counts) do c[k]=v end
        local trying=0
        for _,s in pairs(states) do if s.act then trying=trying+1 end end
        return {counts=c,trying=trying}
    end
    return hider
end
return M
