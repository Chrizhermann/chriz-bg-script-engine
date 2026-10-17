-- The fight director of one hostile group (for now: the hooked creatures of one area).
-- Members check in with what they perceive (frames from adapters/eeex/sense.lua); the director
-- keeps the shared picture (where the enemies are, how wounded, who is disabled), picks a focus
-- target and keeps one disabler per target with short reservations. It never acts. When a
-- member's own cast starts, it advises keeping the target or taking another one, and the
-- adapter re-checks before it changes anything. Plain values only; nothing survives a load.
local targeting=require('combat-intent.targeting')
local values=require('kernel.manifest')
local M={}
-- Game ticks, 15 a second. A member that has not checked in for memberTicks has left; what a
-- member saw is current for enemyTicks; a disable reservation lasts reserveTicks at most and
-- graceTicks after its cast ended, so the disable can show before another one is allowed.
M.defaults={memberTicks=150,enemyTicks=45,reserveTicks=225,graceTicks=30,forgetTicks=450,
    logCapacity=256,families={mage=true,priest=true}}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function id(v) return number(v) and v>=0 and v%1==0 end

function M.new(config)
    config=config or {}
    local o={}
    for k,v in pairs(M.defaults) do if config[k]==nil then o[k]=v else o[k]=config[k] end end
    local area=type(config.area)=='string' and config.area or ''
    local sink=type(config.sink)=='function' and config.sink or nil
    local members,enemies,reservations,attempts={},{},{},{}
    local focus,lastTick=nil,nil
    local log,nextRow,size={},1,0
    local counts={checkIns=0,advice=0,redirects=0,keeps=0,focusChanges=0,attempts=0,ended=0,
        released=0,sinkErrors=0}
    local api={}

    local function record(row)
        row.area=area
        local ok,copy=pcall(values.copy,row)
        if not ok then return end
        log[nextRow]=copy;nextRow=nextRow%o.logCapacity+1;size=math.min(size+1,o.logCapacity)
        if sink and not pcall(sink,values.copy(copy)) then counts.sinkErrors=counts.sinkErrors+1 end
    end
    local function fresh(e,tick) return e~=nil and tick-e.lastTick<=o.enemyTicks and targeting.alive(e) end
    local function holder(target,tick)
        local r=reservations[target]
        if r and r.untilTick>tick and members[r.owner] then return r.owner end
    end
    local function finish(member,tick,why)
        local a=attempts[member]
        if not a or a.ended then return end
        a.ended=tick;counts.ended=counts.ended+1
        local r=reservations[a.target]
        if r and r.owner==member then r.untilTick=math.min(r.untilTick,tick+o.graceTicks) end
        local e=enemies[a.target]
        record({kind='end',tick=tick,member=member,spell=a.spell,role=a.role,target=a.target,
            why=why,ticks=tick-a.startedAt,targetDisabled=e and targeting.disabled(e) or nil,
            targetHealth=e and targeting.health(e) or nil})
    end
    -- After a load or a jump back in time nothing here is valid any more.
    local function clock(tick)
        if lastTick and tick<lastTick then api:invalidate('clock') end
        lastTick=tick
    end

    function api:isMember(member) return members[member]~=nil end
    -- member = {id, family}; frame = the member's plain perception frame.
    function api:checkIn(member,frame)
        if type(member)~='table' or not id(member.id) or type(frame)~='table' or not number(frame.tick) or
            type(frame.self)~='table' then return false end
        local tick=frame.tick;clock(tick)
        local m=members[member.id] or {}
        m.family=member.family;m.lastTick=tick;m.x=frame.self.x;m.y=frame.self.y
        members[member.id]=m;counts.checkIns=counts.checkIns+1
        for _,e in ipairs(type(frame.enemies)=='table' and frame.enemies or {}) do
            if id(e.id) then
                local seen=enemies[e.id] or {seenBy={}}
                seen.lastTick=tick;seen.x,seen.y,seen.hp,seen.maxHp=e.x,e.y,e.hp,e.maxHp
                seen.state,seen.held=e.state,e.held
                seen.seenBy[member.id]=tick
                enemies[e.id]=seen
            end
        end
        -- A member no longer busy with its cast has finished it.
        local a=attempts[member.id]
        if a and not a.ended and frame.self.action~=a.action then finish(member.id,tick,'action-changed') end
        return true
    end

    -- The focus target: kept while it lives and someone sees it; otherwise the enemy seen by
    -- the most members, then the most wounded, then the nearest to the members who see it.
    function api:focus(tick)
        if focus and fresh(enemies[focus],tick) then return focus end
        local best,bestKey
        for key,e in pairs(enemies) do
            if fresh(e,tick) then
                local seen,far=0,0
                for member,at in pairs(e.seenBy) do
                    local m=members[member]
                    if m and tick-at<=o.enemyTicks then seen=seen+1;far=far+targeting.distance(m,e) end
                end
                if seen>0 then
                    local k={seen,-targeting.health(e),-far/seen,-key}
                    local better=bestKey==nil
                    for i=1,#k do
                        if better or k[i]~=bestKey[i] then better=better or k[i]>bestKey[i];break end
                    end
                    if better then best,bestKey=key,k end
                end
            end
        end
        if best~=focus then
            counts.focusChanges=counts.focusChanges+1
            record({kind='focus',tick=tick,target=best,previous=focus,seenBy=bestKey and bestKey[1],
                health=bestKey and -bestKey[2]})
            focus=best
        end
        return focus
    end

    local function advise(member,frame,spell,original,tick)
        local family=members[member.id] and members[member.id].family or member.family
        if not o.families[family] then return {action='keep',reason='family'} end
        local kind,why=targeting.kind(spell)
        if not kind then return {action='keep',reason=why} end
        local byId={}
        for _,e in ipairs(type(frame.enemies)=='table' and frame.enemies or {}) do if id(e.id) then byId[e.id]=e end end
        local first=byId[original]
        if not first then return {action='keep',kind=kind,reason='original-unseen'} end
        local caster=frame.self
        local target=api:focus(tick)
        if kind=='disable' then
            local busy=targeting.disabled(first) and 'disabled' or
                (holder(original,tick) and holder(original,tick)~=member.id and 'reserved') or nil
            if not busy then return {action='keep',kind=kind,reason='free'} end
            local best,bestDistance
            for key,e in pairs(byId) do
                if key~=original and not targeting.disabled(e) and
                    (holder(key,tick)==nil or holder(key,tick)==member.id) and targeting.legal(caster,e,spell,first) then
                    local d=key==target and -1 or targeting.distance(caster,e)
                    if best==nil or d<bestDistance or (d==bestDistance and key<best) then best,bestDistance=key,d end
                end
            end
            if best==nil then return {action='keep',kind=kind,reason=busy..'-no-alternative'} end
            return {action='redirect',kind=kind,target=best,reason=busy}
        end
        if target==nil then return {action='keep',kind=kind,reason='no-focus'} end
        if target==original then return {action='keep',kind=kind,reason='on-focus'} end
        local chosen=byId[target]
        if not chosen then return {action='keep',kind=kind,reason='focus-unseen'} end
        if targeting.casting(first) then return {action='keep',kind=kind,reason='original-casting'} end
        if targeting.health(first)<targeting.health(chosen) then
            return {action='keep',kind=kind,reason='original-more-wounded'}
        end
        local ok,blocked=targeting.legal(caster,chosen,spell,first)
        if not ok then return {action='keep',kind=kind,reason='focus-'..blocked} end
        return {action='redirect',kind=kind,target=target,reason='focus'}
    end
    -- A member's own cast at original is starting: keep it, or take another target.
    function api:advise(member,frame,spell,original,tick)
        clock(tick);counts.advice=counts.advice+1
        local ok,result=pcall(advise,member,frame,spell,original,tick)
        local err
        if not ok then err=tostring(result):sub(1,200);result={action='keep',reason='error'} end
        if result.action=='redirect' then counts.redirects=counts.redirects+1 else counts.keeps=counts.keeps+1 end
        record({kind=result.action,tick=tick,member=member.id,family=member.family,
            spell=type(spell)=='table' and spell.resref or nil,castKind=result.kind,from=original,
            to=result.target,reason=result.reason,focus=focus,error=err})
        return result
    end

    -- A member's cast has started at target (after any redirect). Any cast counts for the
    -- picture; a disable reserves its target.
    function api:started(member,cast,tick)
        clock(tick)
        finish(member.id,tick,'replaced')
        local role=cast.role
        attempts[member.id]={spell=cast.spell,role=role,target=cast.target,action=cast.action or 31,
            startedAt=tick}
        counts.attempts=counts.attempts+1
        if role=='disable' and id(cast.target) and cast.target~=member.id then
            reservations[cast.target]={owner=member.id,from=tick,untilTick=tick+o.reserveTicks}
        end
        record({kind='start',tick=tick,member=member.id,family=member.family,spell=cast.spell,
            role=role,target=cast.target,original=cast.original,redirected=cast.redirected or nil})
    end
    -- A member started some other action: its cast, if any, is over.
    function api:action(member,tick) clock(tick);finish(member,tick,'next-action') end

    function api:tick(tick)
        clock(tick)
        for key,m in pairs(members) do
            if tick-m.lastTick>o.memberTicks then
                finish(key,tick,'member-left');members[key]=nil;attempts[key]=nil
            end
        end
        for key,e in pairs(enemies) do if tick-e.lastTick>o.forgetTicks then enemies[key]=nil end end
        for key,r in pairs(reservations) do
            if r.untilTick<=tick or not members[r.owner] then reservations[key]=nil;counts.released=counts.released+1 end
        end
        if focus and not fresh(enemies[focus],tick) then focus=nil end
    end
    function api:invalidate(reason)
        members,enemies,reservations,attempts,focus,lastTick={},{},{},{},nil,nil
        record({kind='invalidated',reason=reason})
    end
    function api:inspect()
        local held={}
        for target,r in pairs(reservations) do held[#held+1]={target=target,owner=r.owner,untilTick=r.untilTick} end
        table.sort(held,function(a,b) return a.target<b.target end)
        local count=function(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
        local rows,first={},(nextRow-size-1)%o.logCapacity+1
        for i=0,size-1 do rows[#rows+1]=values.copy(log[(first+i-1)%o.logCapacity+1]) end
        return {area=area,members=count(members),enemies=count(enemies),focus=focus,reservations=held,
            counts=values.copy(counts),log=rows}
    end
    return api
end
return M
