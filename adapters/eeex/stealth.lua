-- EEex side of a thief's own hide (combat-intent/stealth.lua), for the choice adapter
-- (adapters/eeex/choice.lua). It reads what the rule needs of the creature (its class, its Hide in
-- Shadows skill and the game's modal state), keeps for each creature whether its stretch out of
-- sight draws the hide and when it last tried, and holds a try: while the creature runs the game's
-- Hide() action (graceTicks until it starts) or stays in the game's stealth mode, until it is hidden
-- and hideTicks at most, never once an enemy shows or the creature is hurt. Then the try is judged:
-- a 'hidden' row tells whether the creature came out invisible (STATE_INVISIBLE, which the game's
-- hiding in shadows sets as players know it; a lab is to measure it) and what the game's own hiding
-- fields read, where the engine offers them. Session-local; a load forgets it all.
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
local INVISIBLE=targeting.STATE.invisible

-- A field of the sprite, or nil when the engine does not offer it.
local function field(sprite,name)
    local ok,v=pcall(function() return sprite[name] end)
    if ok and (type(v)=='number' or type(v)=='boolean') then return v end
    return nil
end

function M.new(g,options)
    options=options or {}
    local record=type(options.record)=='function' and options.record or function() end
    local rng=options.rng
    local states,stateCount={},0
    local counts={hides=0,hidden=0,unhidden=0,draws=0}
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
    -- An enemy in sight: the stretch out of sight is over, and the next draws afresh.
    function hider:fight(id)
        local s=states[id]
        if s then s.tactical=nil end
    end
    -- With no enemy in sight: the rule's decision (stealth.decide), or nil and why. m: the creature's
    -- profile; orders: its designer's orders. A creature that could hide draws once a stretch whether
    -- it thinks of it (search.draw, by its wit).
    function hider:decide(sprite,frame,tick,m,orders)
        local self=read(sprite,frame.self)
        local s=state(self.id)
        if s.tactical==nil and stealth.able(self) and type(m)=='table' and m.hide~=false then
            s.tactical=search.draw(m,rng);counts.draws=counts.draws+1
        end
        local d,why=stealth.decide({tick=tick,frame=frame,mind=m,orders=orders,tactical=s.tactical,tried=s.tried})
        if d then d.skill,d.tactical,d.wit=self.hideSkill,s.tactical,type(m)=='table' and m.wit or nil end
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
