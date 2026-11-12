-- The fight director of one hostile group (for now: the hooked creatures of one area).
-- Members check in with what they perceive (frames from adapters/eeex/sense.lua); the director
-- keeps the shared picture (where the enemies are, how wounded, who is disabled), picks a focus
-- target and keeps one disabler per target with short reservations, and one caster of each
-- debuff per target (F2b: two priests do not cast Doom at one enemy together; SCS keeps its
-- priests' Greater Malison apart with a timer for the whole area, [src] priest/ssl/combatblocks/
-- curse_malison.ssl). It never acts. When a
-- member's own cast starts, it advises keeping the target or taking another one, and the
-- adapter re-checks before it changes anything. Plain values only; nothing survives a load.
local targeting=require('combat-intent.targeting')
local values=require('kernel.manifest')
local M={}
-- Game ticks, 15 a second. A member that has not checked in for memberTicks has left; what a
-- member saw is current for enemyTicks, a round, since members check in only when their script
-- reaches its hook and that pauses while they cast (gaps of 48 to 128 ticks in the lab, 16
-- otherwise); a disable reservation lasts reserveTicks at most and graceTicks after its cast
-- ended, so the disable can show before another one is allowed. The engine's own disables
-- reserve their targets as soon as they are chosen, before the cast is queued: such a claim
-- lasts claimTicks at most, until the cast starts. An enemy's heading comes from two sightings at
-- least headingMin ticks apart; one seen again after more than headingTicks starts without one. An
-- enemy is forgotten forgetTicks after it was last seen. It advises the casts of the members of
-- families, all four since F1e.
-- An enemy out of play is not missing (lab batch J: the party's last members were mazed or charmed,
-- and the group hunted them as hidden; Christopher, 2026-10-29): one the group charmed stands with
-- it (an ally in the charmed state that it has seen as an enemy, foeLimit kept, or that belongs to
-- the party), one in a maze is gone until the maze ends where it vanished (the adapter checks the
-- enemies no member has seen for removalTicks and tells, removed). Each is kept apart from the
-- picture, for the search to await: no clue, no focus, until it shows as an enemy again; a mazed one
-- that comes back is a fresh sighting where it vanished. One not seen or checked for awayTicks is
-- forgotten, and any after awaitTicks. An imprisoned enemy is out of the game until the party frees
-- it, which no waiting brings about: the picture forgets it at once. It forgets one that is gone just
-- as fast, dead or no creature any more (the adapter checks): members see only the living, and the
-- last sighting kept a dead enemy in play and as the focus (lab batch J, run 4: a mage charmed the
-- party's last living member while the party's mage, dead for three seconds, still counted).
M.defaults={memberTicks=150,enemyTicks=90,reserveTicks=225,graceTicks=30,claimTicks=60,forgetTicks=450,
    headingMin=5,headingTicks=45,logCapacity=256,families={mage=true,priest=true,fighter=true,monster=true},
    awayTicks=450,awaitTicks=4500,removalTicks=15,foeLimit=1024,groupRadius=560,combatRadius=1200,alertTicks=900}
M.ticksPerSecond=15

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function id(v) return number(v) and v>=0 and v%1==0 end

function M.new(config)
    config=config or {}
    local o={}
    for k,v in pairs(M.defaults) do if config[k]==nil then o[k]=v else o[k]=config[k] end end
    local area=type(config.area)=='string' and config.area or ''
    local sink=type(config.sink)=='function' and config.sink or nil
    local members,enemies,reservations,attempts,curses={},{},{},{},{}
    local foes,foeCount,away={},0,{}
    local focus,groupFocus,lastTick=nil,{},nil
    local log,nextRow,size={},1,0
    local counts={checkIns=0,advice=0,redirects=0,keeps=0,focusChanges=0,focusLost=0,attempts=0,ended=0,
        released=0,sinkErrors=0,away=0,back=0,awayEnded=0,gone=0,alerts=0}
    local api={}

    local function record(row)
        row.area=area
        local ok,copy=pcall(values.copy,row)
        if not ok then return end
        log[nextRow]=copy;nextRow=nextRow%o.logCapacity+1;size=math.min(size+1,o.logCapacity)
        if sink and not pcall(sink,values.copy(copy)) then counts.sinkErrors=counts.sinkErrors+1 end
    end
    local function fresh(e,tick) return e~=nil and tick-e.lastTick<=o.enemyTicks and targeting.alive(e) end
    -- Whether attacks can take anything from e: no minimum keeps it where it is.
    local function open(e) return targeting.minimum(e)<=0 or targeting.room(e)>0 end
    local function holder(target,tick)
        local r=reservations[target]
        if r and r.untilTick>tick and members[r.owner] then return r.owner end
    end
    -- Reserve target for member for ticks, unless another member holds it; a claim never
    -- shortens the member's own cast reservation.
    local function take(member,target,tick,ticks,claim)
        if not id(target) or target==member then return false end
        local owner=holder(target,tick)
        if owner~=nil and owner~=member then return false end
        if claim and owner==member and not reservations[target].claim then return true end
        reservations[target]={owner=member,from=tick,untilTick=tick+ticks,claim=claim}
        return true
    end
    -- Who casts debuff spell at target at tick, as reservations do for disables.
    local function cursing(target,spell,tick)
        local r=curses[target] and curses[target][spell]
        if r and r.untilTick>tick and members[r.owner] then return r.owner end
    end
    -- Claim debuff spell at target for member for ticks, as take does.
    local function curse(member,target,spell,tick,ticks,claim)
        if not id(target) or target==member or type(spell)~='string' then return false end
        local owner=cursing(target,spell,tick)
        if owner~=nil and owner~=member then return false end
        local held=curses[target] or {}
        if claim and owner==member and not held[spell].claim then return true end
        held[spell]={owner=member,from=tick,untilTick=tick+ticks,claim=claim}
        curses[target]=held
        return true
    end
    -- Drop member's claims.
    local function drop(member)
        local n=0
        for target,r in pairs(reservations) do
            if r.owner==member and r.claim then reservations[target]=nil;n=n+1 end
        end
        for _,held in pairs(curses) do
            for spell,r in pairs(held) do
                if r.owner==member and r.claim then held[spell]=nil;n=n+1 end
            end
        end
        return n
    end
    local function finish(member,tick,why)
        local a=attempts[member]
        if not a or a.ended then return end
        a.ended=tick;counts.ended=counts.ended+1
        for _,target in ipairs(a.reserved) do
            local r=reservations[target]
            if r and r.owner==member then r.untilTick=math.min(r.untilTick,tick+o.graceTicks) end
        end
        for _,target in ipairs(a.cursed or {}) do
            local r=curses[target] and curses[target][a.spell]
            if r and r.owner==member then r.untilTick=math.min(r.untilTick,tick+o.graceTicks) end
        end
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
    -- The enemy's heading (vx, vy: world units a second) from where it was seen last (px, py at
    -- ptick) and where it is seen now.
    local function heading(seen,e,tick)
        if not (number(e.x) and number(e.y)) then return end
        if seen.ptick==nil or tick<seen.ptick or tick-seen.ptick>o.headingTicks then
            seen.px,seen.py,seen.ptick,seen.vx,seen.vy=e.x,e.y,tick,nil,nil
        elseif tick-seen.ptick>=o.headingMin then
            local seconds=(tick-seen.ptick)/M.ticksPerSecond
            seen.vx,seen.vy=(e.x-seen.px)/seconds,(e.y-seen.py)/seconds
            seen.px,seen.py,seen.ptick=e.x,e.y,tick
        end
    end
    -- Whether two members belong to the same local fight at tick: within groupRadius of one
    -- another, or linked by an active call-for-help root (api:alert). Nil member means whole area.
    local function linked(a,b,tick)
        if a==nil or b==nil or a==b then return true end
        local ma,mb=members[a],members[b]
        if not ma or not mb then return true end
        if not (number(ma.x) and number(ma.y) and number(mb.x) and number(mb.y)) then return true end
        local dist=targeting.distance(ma,mb)
        if dist<=o.groupRadius then return true end
        if dist<=o.combatRadius and ma.engagedAt and tick-ma.engagedAt<=o.enemyTicks and
            mb.engagedAt and tick-mb.engagedAt<=o.enemyTicks then
            return true
        end
        if ma.alertRoot~=nil and ma.alertRoot==mb.alertRoot and
            ma.alertedUntil and ma.alertedUntil>=tick and mb.alertedUntil and mb.alertedUntil>=tick then
            return true
        end
        return false
    end
    local function seenByLinked(map,member,tick,recentOnly)
        if member==nil then
            if not recentOnly then return true end
            if type(map)~='table' then return false end
            for s,at in pairs(map) do if members[s] and tick-at<=o.enemyTicks then return true end end
            return false
        end
        if type(map)~='table' or next(map)==nil then return not recentOnly end
        for s,at in pairs(map) do
            if (not recentOnly or (members[s] and tick-at<=o.enemyTicks)) and linked(member,s,tick) then return true end
        end
        return false
    end
    local function copySeen(map,extraMember,tick)
        local out={}
        if type(map)=='table' then for k,v in pairs(map) do out[k]=v end end
        if extraMember~=nil then out[extraMember]=tick end
        return out
    end
    -- An enemy out of play (kind 'charm' or 'maze') at at: kept apart from the picture, with what
    -- the picture knew of it, for when it comes back.
    local function hold(target,kind,at,tick,byMember)
        local a=away[target]
        local e=enemies[target]
        if not a or a.kind~=kind then
            a={kind=kind,since=tick,hp=e and e.hp,maxHp=e and e.maxHp,state=e and e.state,
                seenBy=copySeen(e and (next(e.seenBy)~=nil and e.seenBy or e.origin) or nil,byMember,tick)}
            away[target]=a;counts.away=counts.away+1
            record({kind='away',tick=tick,target=target,away=kind,x=at.x,y=at.y})
        elseif byMember~=nil then
            a.seenBy=a.seenBy or {};a.seenBy[byMember]=tick
        end
        a.x,a.y,a.lastTick=at.x,at.y,tick
        enemies[target]=nil
    end
    local function gone(target,tick,why)
        local a=away[target]
        if not a then return end
        away[target]=nil
        if why=='back' then counts.back=counts.back+1 else counts.awayEnded=counts.awayEnded+1 end
        record({kind=why=='back' and 'back' or 'away-end',tick=tick,target=target,away=a.kind,ticks=tick-a.since,
            why=why~='back' and why or nil})
    end

    function api:isMember(member) return members[member]~=nil end
    -- Link callerId and recipientIds into one alerted fight group for alertTicks.
    function api:alert(callerId,recipientIds,tick)
        if not id(callerId) or type(recipientIds)~='table' or not number(tick) then return 0 end
        clock(tick)
        local mc=members[callerId]
        if not mc then return 0 end
        local root=(mc.alertedUntil and mc.alertedUntil>=tick and mc.alertRoot) or callerId
        mc.alertRoot=root;mc.alertedUntil=tick+o.alertTicks
        local n=0
        for _,rid in ipairs(recipientIds) do
            if id(rid) and rid~=callerId and members[rid] then
                members[rid].alertRoot=root;members[rid].alertedUntil=tick+o.alertTicks
                n=n+1
            end
        end
        if n>0 then counts.alerts=counts.alerts+1 end
        return n
    end
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
                m.engagedAt=tick
                local seen=enemies[e.id] or {seenBy={}}
                heading(seen,e,tick)
                seen.lastTick=tick;seen.x,seen.y,seen.hp,seen.maxHp=e.x,e.y,e.hp,e.maxHp
                seen.state,seen.held,seen.minHp,seen.statue=e.state,e.held,e.minHp,e.statue==true or nil
                seen.seenBy[member.id]=tick;seen.origin=nil
                enemies[e.id]=seen
                if not foes[e.id] then
                    if foeCount>=o.foeLimit then foes,foeCount={},0 end
                    foes[e.id]=true;foeCount=foeCount+1
                end
                gone(e.id,tick,'back')
            end
        end
        -- A foe the group charmed stands with it: an ally in the charmed state that it has seen as
        -- an enemy or that belongs to the party (player).
        for _,a in ipairs(type(frame.allies)=='table' and frame.allies or {}) do
            if id(a.id) and (foes[a.id] or number(a.player)) and targeting.charmed(a) and targeting.alive(a) and
                number(a.x) and number(a.y) then
                hold(a.id,'charm',a,tick,member.id)
            end
        end
        -- A member no longer busy with its cast has finished it.
        local a=attempts[member.id]
        if a and not a.ended and frame.self.action~=a.action then finish(member.id,tick,'action-changed') end
        return true
    end

    local function focusSlot(member,tick)
        if member==nil then return 0 end
        local slot=member
        for k,m in pairs(members) do
            if tick>=m.lastTick and tick-m.lastTick<=o.memberTicks and k<slot and linked(member,k,tick) then slot=k end
        end
        return slot
    end

    -- The focus target: kept while it lives, someone in the local group sees it and attacks can take
    -- something from it; otherwise the enemy seen by the most linked members, then the most wounded
    -- (by what it has above its minimum hit points), then the nearest to the members who see it.
    function api:focus(tick,member)
        local slot=focusSlot(member,tick)
        local cur=slot==0 and focus or groupFocus[slot]
        if cur and fresh(enemies[cur],tick) and open(enemies[cur]) and not enemies[cur].statue and
            seenByLinked(enemies[cur].seenBy,member,tick,true) then
            return cur
        end
        local best,bestKey
        for key,e in pairs(enemies) do
            if fresh(e,tick) and open(e) then
                local seen,far=0,0
                for s,at in pairs(e.seenBy) do
                    local m=members[s]
                    if m and tick-at<=o.enemyTicks and linked(member,s,tick) then
                        seen=seen+1;far=far+targeting.distance(m,e)
                    end
                end
                if seen>0 then
                    local k={e.statue and 0 or 1,seen,-targeting.room(e),-far/seen,-key}
                    local better=bestKey==nil
                    for i=1,#k do
                        if better or k[i]~=bestKey[i] then better=better or k[i]>bestKey[i];break end
                    end
                    if better then best,bestKey=key,k end
                end
            end
        end
        if best~=cur then
            counts.focusChanges=counts.focusChanges+1
            record({kind='focus',tick=tick,target=best,previous=cur,seenBy=bestKey and bestKey[2],
                health=bestKey and -bestKey[3]})
            if slot==0 then focus=best else groupFocus[slot]=best;focus=best end
        end
        return slot==0 and focus or groupFocus[slot]
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
        local target=api:focus(tick,member.id)
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
        if (not first.statue or chosen.statue) and targeting.health(first)<targeting.health(chosen) then
            return {action='keep',kind=kind,reason='original-more-wounded'}
        end
        local ok,blocked=targeting.legal(caster,chosen,spell,first)
        if not ok then return {action='keep',kind=kind,reason='focus-'..blocked} end
        return {action='redirect',kind=kind,target=target,reason='focus'}
    end
    -- A member's own cast at original is starting: keep it, or take another target. typed: the
    -- script aimed it at a kind of creature ([PC.0.0.MAGE]) that named original; any other
    -- legal target will do as well (Christopher, 2026-10-18), so it only marks the log.
    function api:advise(member,frame,spell,original,tick,typed)
        clock(tick);counts.advice=counts.advice+1
        local ok,result=pcall(advise,member,frame,spell,original,tick)
        local err
        if not ok then err=tostring(result):sub(1,200);result={action='keep',reason='error'} end
        if result.action=='redirect' then counts.redirects=counts.redirects+1 else counts.keeps=counts.keeps+1 end
        record({kind=result.action,tick=tick,member=member.id,family=member.family,
            spell=type(spell)=='table' and spell.resref or nil,castKind=result.kind,from=original,
            to=result.target,reason=result.reason,focus=focus,typed=typed or nil,error=err})
        return result
    end

    -- The group's plan as its members use it at tick: the focus target, who holds which disable
    -- reservation, who casts which debuff at which enemy (cursed[target][spell]), and the foes in
    -- play (inPlay[id]: every living enemy of the local group's picture; those out of play are not
    -- in it). When member is omitted, returns the whole area's plan.
    function api:plan(tick,member)
        clock(tick)
        local reserved,cursed,inPlay={},{},{}
        for target,r in pairs(reservations) do
            if r.untilTick>tick and members[r.owner] and linked(member,r.owner,tick) then reserved[target]=r.owner end
        end
        for target,held in pairs(curses) do
            for spell in pairs(held) do
                local owner=cursing(target,spell,tick)
                if owner and linked(member,owner,tick) then cursed[target]=cursed[target] or {};cursed[target][spell]=owner end
            end
        end
        for key,e in pairs(enemies) do
            if targeting.alive(e) and (seenByLinked(e.seenBy,member,tick,false) or
                (next(e.seenBy)==nil and seenByLinked(e.origin,member,tick,false))) then
                inPlay[key]=true
            end
        end
        return {focus=api:focus(tick,member),reserved=reserved,cursed=cursed,inPlay=inPlay}
    end

    -- A member's cast has started at target (after any redirect). Any cast counts for the
    -- picture and replaces the member's claims. A disable reserves its target, or every enemy
    -- its area hits (cast.hits, known for the engine's own casts), except those another member
    -- holds; the engine's own heal or cure (D3a, D3b) reserves the allies it helps the same way,
    -- and its own debuff (F2b) the enemies it weakens, for that spell only.
    -- own: the engine chose the cast itself.
    function api:started(member,cast,tick)
        clock(tick)
        finish(member.id,tick,'replaced')
        drop(member.id)
        local role=cast.role
        local reserved,cursed={},{}
        local list=type(cast.hits)=='table' and #cast.hits>0 and cast.hits or {cast.target}
        if role=='disable' or role=='heal' or role=='cure' then
            for _,target in ipairs(list) do
                if take(member.id,target,tick,o.reserveTicks,nil) then reserved[#reserved+1]=target end
            end
        elseif role=='debuff' then
            for _,target in ipairs(list) do
                if curse(member.id,target,cast.spell,tick,o.reserveTicks,nil) then cursed[#cursed+1]=target end
            end
        end
        attempts[member.id]={spell=cast.spell,role=role,target=cast.target,action=cast.action or 31,
            startedAt=tick,reserved=reserved,cursed=cursed}
        counts.attempts=counts.attempts+1
        record({kind='start',tick=tick,member=member.id,family=member.family,spell=cast.spell,
            role=role,target=cast.target,original=cast.original,redirected=cast.redirected or nil,
            typed=cast.typed or nil,own=cast.own or nil})
    end
    -- Where the local group last saw each living enemy it remembers, for a member that sees none (the
    -- engine's search, combat-intent/search.lua): {id, x, y, tick (when it was last seen), vx, vy
    -- (its heading then, when known), by (whether another linked member saw it then)}, by id.
    function api:clues(member,tick)
        clock(tick)
        local out={}
        for key,e in pairs(enemies) do
            if targeting.alive(e) and e.lastTick<=tick and number(e.x) and number(e.y) and
                (seenByLinked(e.seenBy,member,tick,false) or
                 (next(e.seenBy)==nil and seenByLinked(e.origin,member,tick,false))) then
                local by=false
                for m,at in pairs(e.seenBy) do if m~=member and at==e.lastTick and linked(member,m,tick) then by=true end end
                out[#out+1]={id=key,x=e.x,y=e.y,tick=e.lastTick,vx=e.vx,vy=e.vy,by=by}
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        return out
    end
    -- The enemies to check now for being out of the game, by id: each living one the picture keeps
    -- that no member has seen for removalTicks, each in a maze, and each the group charmed that no
    -- member has seen for removalTicks (it may be dead), at most once in removalTicks.
    function api:removalChecks(tick)
        clock(tick)
        local out={}
        for key,e in pairs(enemies) do
            if targeting.alive(e) and tick-e.lastTick>=o.removalTicks and
                not (e.checked and tick>=e.checked and tick-e.checked<o.removalTicks) then
                e.checked=tick;out[#out+1]=key
            end
        end
        for key,a in pairs(away) do
            if (a.kind=='maze' or tick-a.lastTick>=o.removalTicks) and
                not (a.checked and tick>=a.checked and tick-a.checked<o.removalTicks) then
                a.checked=tick;out[#out+1]=key
            end
        end
        table.sort(out)
        return out
    end
    local function dropFocusTarget(target,tick,why)
        local lost=focus==target
        for s,f in pairs(groupFocus) do
            if f==target then groupFocus[s]=nil;lost=true end
        end
        if lost then
            counts.focusLost=counts.focusLost+1
            record({kind='focus',tick=tick,previous=target,why=why})
            if focus==target then focus=nil end
        end
    end
    -- What the check of target found at tick: kind 'maze', in a maze at at, where it stands and will
    -- come back; 'prison', imprisoned: forgotten; nil, in the game, and a mazed one that is out again
    -- (at) is seen where it vanished. Neither kind nor at: the creature is gone (dead, or no creature
    -- any more): the picture forgets it at once, focus too, and a charm or maze kept for it ends.
    function api:removed(target,kind,at,tick)
        if not id(target) or not number(tick) then return end
        clock(tick)
        local a=away[target]
        local spot=type(at)=='table' and number(at.x) and number(at.y)
        if kind=='maze' and spot then
            hold(target,'maze',at,tick)
            away[target].checked=tick
        elseif kind=='prison' then
            if enemies[target] or a then
                away[target],enemies[target]=nil,nil;counts.away=counts.away+1
                record({kind='away',tick=tick,target=target,away='prison',x=spot and at.x or nil,y=spot and at.y or nil})
            end
        elseif kind==nil and at==nil then
            if a then gone(target,tick,'gone') end
            if enemies[target] then
                enemies[target]=nil;counts.gone=counts.gone+1
                record({kind='gone',tick=tick,target=target})
            end
            dropFocusTarget(target,tick,'gone')
        elseif a and a.kind=='maze' then
            local origin=a.seenBy
            gone(target,tick,at and 'back' or 'gone')
            if spot then
                enemies[target]={seenBy={},origin=origin,lastTick=tick,x=at.x,y=at.y,hp=a.hp,maxHp=a.maxHp,state=a.state}
            end
        end
    end
    -- The enemies out of play at tick: {id, kind ('charm' or 'maze'), x, y, since, lastTick}, by id.
    function api:away(tick,member)
        clock(tick)
        local out={}
        for key,a in pairs(away) do
            if member==nil or seenByLinked(a.seenBy,member,tick,false) then
                out[#out+1]={id=key,kind=a.kind,x=a.x,y=a.y,since=a.since,lastTick=a.lastTick}
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        return out
    end
    -- The group's members at tick, by id: {id, family, x, y} (where each last checked in).
    function api:members(tick,member)
        local out={}
        for key,m in pairs(members) do
            if tick>=m.lastTick and tick-m.lastTick<=o.memberTicks and linked(member,key,tick) then
                out[#out+1]={id=key,family=m.family,x=m.x,y=m.y}
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        return out
    end
    -- A member started some other action: its cast, if any, is over.
    function api:action(member,tick) clock(tick);finish(member,tick,'next-action') end
    -- The engine's own disable for member, just chosen and not yet queued, claims its targets
    -- (an area's every hit enemy) so that other members deciding meanwhile leave them alone. It
    -- replaces the member's earlier claims. Returns how many it holds.
    function api:reserve(member,targets,tick)
        if type(member)~='table' or not id(member.id) or type(targets)~='table' or not number(tick) then return 0 end
        clock(tick)
        drop(member.id)
        local held={}
        for _,target in ipairs(targets) do
            if take(member.id,target,tick,o.claimTicks,true) then held[#held+1]=target end
        end
        if #held>0 then record({kind='reserve',tick=tick,member=member.id,family=member.family,targets=held}) end
        return #held
    end
    -- The engine's own debuff spell for member, just chosen and not yet queued, claims the enemies
    -- it weakens for that spell, as reserve does for a disable. Returns how many it holds.
    function api:curse(member,targets,spell,tick)
        if type(member)~='table' or not id(member.id) or type(targets)~='table' or type(spell)~='string' or
            not number(tick) then return 0 end
        clock(tick)
        drop(member.id)
        local held={}
        for _,target in ipairs(targets) do
            if curse(member.id,target,spell,tick,o.claimTicks,true) then held[#held+1]=target end
        end
        if #held>0 then record({kind='curse',tick=tick,member=member.id,family=member.family,spell=spell,targets=held}) end
        return #held
    end
    -- The member's decision was given up before its cast started: its claims go. member: the
    -- member or its id.
    function api:release(member,tick)
        local key=type(member)=='table' and member.id or member
        if not id(key) then return 0 end
        if number(tick) then clock(tick) end
        local n=drop(key)
        if n>0 then record({kind='release',tick=tick,member=key,count=n}) end
        return n
    end

    function api:tick(tick)
        clock(tick)
        for key,m in pairs(members) do
            if tick-m.lastTick>o.memberTicks then
                finish(key,tick,'member-left');members[key]=nil;attempts[key]=nil
            end
        end
        for key,e in pairs(enemies) do if tick-e.lastTick>o.forgetTicks then enemies[key]=nil end end
        for key,a in pairs(away) do
            if tick-a.since>o.awaitTicks then gone(key,tick,'await')
            elseif tick-a.lastTick>o.awayTicks then gone(key,tick,'unseen') end
        end
        for key,r in pairs(reservations) do
            if r.untilTick<=tick or not members[r.owner] then reservations[key]=nil;counts.released=counts.released+1 end
        end
        for key,held in pairs(curses) do
            for spell,r in pairs(held) do
                if r.untilTick<=tick or not members[r.owner] then held[spell]=nil;counts.released=counts.released+1 end
            end
            if next(held)==nil then curses[key]=nil end
        end
        for slot,f in pairs(groupFocus) do
            if not fresh(enemies[f],tick) then
                if f~=focus then
                    local e=enemies[f]
                    counts.focusLost=counts.focusLost+1
                    record({kind='focus',tick=tick,previous=f,
                        why=e and not targeting.alive(e) and 'dead' or away[f] and 'away' or 'unseen'})
                end
                groupFocus[slot]=nil
            end
        end
        if focus and not fresh(enemies[focus],tick) then
            local e=enemies[focus]
            counts.focusLost=counts.focusLost+1
            record({kind='focus',tick=tick,previous=focus,
                why=e and not targeting.alive(e) and 'dead' or away[focus] and 'away' or 'unseen'})
            focus=nil
        end
    end
    function api:invalidate(reason)
        members,enemies,reservations,attempts,curses,focus,groupFocus,lastTick={},{},{},{},{},nil,{},nil
        foes,foeCount,away={},0,{}
        record({kind='invalidated',reason=reason})
    end
    function api:inspect()
        local held={}
        for target,r in pairs(reservations) do
            held[#held+1]={target=target,owner=r.owner,untilTick=r.untilTick,claim=r.claim}
        end
        table.sort(held,function(a,b) return a.target<b.target end)
        local cursed={}
        for target,list in pairs(curses) do
            for spell,r in pairs(list) do
                cursed[#cursed+1]={target=target,spell=spell,owner=r.owner,untilTick=r.untilTick,claim=r.claim}
            end
        end
        table.sort(cursed,function(a,b) if a.target~=b.target then return a.target<b.target end return a.spell<b.spell end)
        local count=function(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
        -- The group's picture of each enemy: when it was last seen, by how many members within
        -- enemyTicks of that, and whether it was disabled then.
        local known={}
        for key,e in pairs(enemies) do
            local seenBy=0
            for member,at in pairs(e.seenBy) do if members[member] and e.lastTick-at<=o.enemyTicks then seenBy=seenBy+1 end end
            known[#known+1]={id=key,lastTick=e.lastTick,seenBy=seenBy,disabled=targeting.disabled(e)}
        end
        table.sort(known,function(a,b) return a.id<b.id end)
        local rows,first={},(nextRow-size-1)%o.logCapacity+1
        for i=0,size-1 do rows[#rows+1]=values.copy(log[(first+i-1)%o.logCapacity+1]) end
        local out={}
        for key,a in pairs(away) do out[#out+1]={id=key,kind=a.kind,since=a.since,lastTick=a.lastTick} end
        table.sort(out,function(a,b) return a.id<b.id end)
        return {area=area,members=count(members),enemies=count(enemies),focus=focus,reservations=held,
            curses=cursed,known=known,away=out,foes=foeCount,counts=values.copy(counts),log=rows}
    end
    return api
end
return M
