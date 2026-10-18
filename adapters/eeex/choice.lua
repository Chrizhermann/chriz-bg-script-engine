-- EEex side of the engine's own choice (step 3, second slice). When a hooked mage's or
-- priest's script asks the gate and SCS's round timer has run out, this reads what the
-- creature perceives (sense.lua, with the details SCS's scripts read), what it has ready
-- (creature.lua, classified by combat-intent/spells.lua) and the director's plan, and asks
-- combat-intent/choice.lua for an attack. A chosen attack becomes the gate's decision: a
-- normal SpellRES or SpellPointRES that first sets SCS's round timer as SCS's own cast blocks
-- do, so SCS's filler runs between casts. Right before the response is queued the target is
-- checked again and named through EEex's EEex_Target object, which reads the caster's own
-- table, so no other creature's choice can change it. A cast that never starts is given up;
-- one that ends with no effect on its target is remembered as a miss. No answer, an error or
-- a switch leaves the round to SCS. Session-local; a load forgets it all.
local sense=require('adapters.eeex.sense')
local creature=require('adapters.eeex.creature')
local resources=require('adapters.eeex.resources')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local rngs=require('kernel.rng')
local M={}
M.families={mage=true,priest=true}
-- Game ticks (15 a second). A queued cast that has not started after pendingTicks is given up;
-- outcomeTicks after a cast ends, its effect on the target is judged.
M.pendingTicks=45
M.outcomeTicks=30
-- A started cast that ends this much before its casting time was interrupted.
M.interruptSlack=3
-- The name under which the caster's EEex_Target table holds the engine's target.
M.targetName='BGSE'
-- SCS's round timer, set the way SCS's own cast blocks set it.
M.timer='castspell'
M.setTimer='SetGlobalTimer("castspell","LOCALS",ONE_ROUND)'
M.cacheLimit=1024
M.logCapacity=128
M.judgeLimit=64
-- Item slots a creature drinks from: the quick items and the backpack (SLOTS.IDS).
M.itemFirst,M.itemLast=15,33
-- Casts of the engine's own: Spell (SpellRES) and SpellPoint (SpellPointRES).
M.CASTS={[31]=true,[95]=true}
M.required={'EEex_GameObject_Get','EEex_GameObject_IsSprite','EEex_Sprite_GetCastTimer',
    'EEex_Sprite_GetLocalInt','EEex_GetUDAux','EEex_Sprite_GetState','EEex_Sprite_GetStat'}
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function text(value) return (value:match('^[^%z]*'):upper()) end
local function valid(resref) return type(resref)=='string' and #resref>0 and #resref<=8 and not resref:find('[^A-Z0-9_#%-]') end
local function whole(v) return type(v)=='number' and v>=0 and v<65536 and v%1==0 end

-- Whether SCS's round timer is still running for sprite at tick. Game timers hold the game
-- time they run out at; without the accessor the timer counts as running, so the engine never
-- takes a round it cannot place.
function M.timerRunning(g,sprite,tick)
    local get=rawget(g,'EEex_Sprite_GetLocalInt')
    if type(get)~='function' then return true end
    local ok,value=pcall(get,sprite,M.timer)
    return ok and type(value)=='number' and value>tick
end

-- The response that casts decision's spell, or nil.
function M.response(decision)
    if type(decision)~='table' or not valid(decision.resref) then return nil end
    if decision.point then
        local p=decision.point
        if not whole(p.x) or not whole(p.y) then return nil end
        return M.setTimer..'\nSpellPointRES("'..decision.resref..'",['..p.x..'.'..p.y..'])'
    end
    if decision.self then return M.setTimer..'\nSpellRES("'..decision.resref..'",Myself)' end
    local t=decision.target
    if type(t)=='number' and t>=0 and t%1==0 then
        return M.setTimer..'\nSpellRES("'..decision.resref..'",EEex_Target("'..M.targetName..'"))'
    end
end

function M.new(g,options)
    options=options or {}
    local reader=options.reader or resources.new(g)
    local director=options.director
    local defaultMind=mind.new()
    local mindFor=options.mindFor or function() return defaultMind end
    local seed=options.seed
    if type(seed)~='number' then
        local clock=rawget(g,'os') and g.os.time or (os and os.time)
        seed=(clock and clock() or 1)%2147483645+1
    end
    local rng=rngs.new(seed)
    local enabled=options.enabled~=false
    local missing
    for _,name in ipairs(M.required) do
        if type(rawget(g,name))~='function' then missing=missing or name end
    end
    local cache,cached,items,itemCount={},0,{},0
    local pending,running,judging,memory={},{},{},{}
    local counts={decisions=0,claims=0,declines=0,performed=0,skipped=0,started=0,lost=0,interrupted=0,
        hits=0,misses=0,errors=0,holds=0}
    local reasons={}
    local log,nextRow,size={},1,0
    local root,sink,lastError
    local api={}

    local function now() return root and root.now and root.now() end
    local function record(row)
        log[nextRow]=row;nextRow=nextRow%M.logCapacity+1;size=math.min(size+1,M.logCapacity)
        if sink then pcall(sink,row) end
    end
    local function failed(where,err)
        counts.errors=counts.errors+1
        lastError=where..': '..tostring(err):sub(1,200)
        record({kind='error',where=where,error=tostring(err):sub(1,200)})
    end
    local function decline(why)
        counts.declines=counts.declines+1
        reasons[why]=(reasons[why] or 0)+1
        return nil
    end
    local function get(id)
        local object=g.EEex_GameObject_Get(id)
        if object and g.EEex_GameObject_IsSprite(object,false) then return object end
    end

    -- A spell at a caster level, classified once.
    local function classify(resref,level)
        local key=resref..':'..level
        if cache[key]==nil then
            if cached>=M.cacheLimit then cache,cached={},0 end
            local record=reader.get('SPL',resref)
            local index=record and spells.abilityForLevel(record,level)
            cache[key]=index and spells.classify(record,index,reader.lookup,{level=level}) or false
            cached=cached+1
        end
        return cache[key] or nil
    end
    -- An item's first three abilities, classified once.
    local function item(resref)
        if items[resref]==nil then
            if itemCount>=M.cacheLimit then items,itemCount={},0 end
            local record=reader.get('ITM',resref)
            local list={}
            if record and type(record.abilities)=='table' then
                for i=1,math.min(3,#record.abilities) do list[i]=spells.classify(record,i,reader.lookup,{level=1}) end
            end
            items[resref]=list;itemCount=itemCount+1
        end
        return items[resref]
    end
    -- What the creature has ready: its spells with their classification, and the items it can
    -- drink or use from its quick slots and backpack.
    local function book(sprite)
        local snapshot,err=creature.read(g,sprite,reader)
        if not snapshot then return nil,err end
        local rows={}
        for _,s in ipairs(snapshot.spells) do
            local level=s.casterLevel or snapshot.level or 1
            if level<1 then level=1 end
            rows[#rows+1]={resref=s.resref,list=s.list,level=s.level,ready=s.ready,memorized=s.memorized,
                usable=s.usable,spell=classify(s.resref,level)}
        end
        local carried={}
        for _,it in ipairs(snapshot.items) do
            if it.slot>=M.itemFirst and it.slot<=M.itemLast then
                local abilities={}
                for i,effect in ipairs(item(it.resref)) do
                    abilities[i]={effect=effect,uses=type(it.uses)=='table' and it.uses[i] or nil}
                end
                carried[#carried+1]={resref=it.resref,abilities=abilities}
            end
        end
        return rows,carried
    end

    -- The effect of finished casts on their targets: a target that lost hit points, became
    -- disabled by a disable, or carries an effect of the spell was hit. An effect a spell lands
    -- through a sub-spell or an EFF file names that as its source (the classifier's sources).
    local function outcome(a)
        if not a.target or a.mode~='creature' then return end
        if a.castTicks and a.ended-a.started<a.castTicks-M.interruptSlack then
            counts.interrupted=counts.interrupted+1;return
        end
        local target=get(a.target)
        if not target then return end
        local hit=a.hp~=nil and target.m_baseStats.m_hitPoints<a.hp
        if not hit and a.kind=='disable' then hit=targeting.disabled(sense.actor(g,target)) end
        if not hit then
            local names=type(a.sources)=='table' and a.sources or {[a.resref]=true}
            for _,list in ipairs({target.m_timedEffectList,target.m_equipedEffectList}) do
                local n=0
                g.EEex_Utility_IterateCPtrList(list,function(effect)
                    n=n+1
                    if n>sense.maxEffects then return true end
                    if names[text(effect.m_sourceRes:get())] then hit=true;return true end
                end)
                if hit then break end
            end
        end
        local key=a.resref..':'..a.target
        local mine=memory[a.caster] or {}
        memory[a.caster]=mine
        if hit then counts.hits=counts.hits+1;mine[key]=nil
        else counts.misses=counts.misses+1;mine[key]=(mine[key] or 0)+1 end
        record({kind='outcome',tick=a.ended,member=a.caster,spell=a.resref,target=a.target,hit=hit,misses=mine[key]})
    end
    local function judge(tick)
        for id,a in pairs(running) do
            local sprite=get(id)
            local action=sprite and sprite.m_curAction
            local ours=action and M.CASTS[action.m_actionID] and text(action.m_string1.m_pchData:get())==a.resref
            if not ours then
                a.ended=tick;running[id]=nil
                if #judging<M.judgeLimit then judging[#judging+1]=a end
            end
        end
        local keep={}
        for _,a in ipairs(judging) do
            if tick<a.ended then
            elseif tick-a.ended>=M.outcomeTicks then outcome(a)
            else keep[#keep+1]=a end
        end
        judging=keep
    end

    local function decide(view,family)
        if not enabled or missing then return decline(missing and 'missing' or 'off') end
        if not M.families[family] then return decline('family') end
        local tick=now()
        if type(tick)~='number' then return decline('no-clock') end
        local id=view.id
        local sprite=get(id)
        if not sprite then return decline('no-sprite') end
        judge(tick)
        local p=pending[id]
        if p then
            if tick>=p.tick and tick-p.tick<=M.pendingTicks then counts.holds=counts.holds+1;return {hold=true} end
            pending[id]=nil;counts.lost=counts.lost+1
            record({kind='lost',tick=tick,member=id,spell=p.resref,target=p.target,queued=p.tick})
        end
        if M.timerRunning(g,sprite,tick) then return decline('timer') end
        if g.EEex_Sprite_GetCastTimer(sprite)~=-1 then return decline('aura') end
        if targeting.CASTS[sprite.m_curAction.m_actionID] then return decline('casting') end
        local frame=sense.frame(g,sprite,tick,true)
        if not frame then return decline('no-frame') end
        if sense.side(frame.self.ea)~='evil' then return decline('side') end
        if #frame.enemies==0 then return decline('no-enemy') end
        local rows,carried=book(sprite)
        if not rows then failed('book',carried);return nil end
        counts.decisions=counts.decisions+1
        local input={tick=tick,family=family,frame=frame,spells=rows,items=carried,
            plan=director and director:plan(id,tick) or {},memory=memory[id] or {},mind=mindFor(sprite,family),rng=rng}
        local d,why,options=choice.decide(input)
        local top={}
        for i=1,math.min(3,#options) do
            local o=options[i]
            top[i]={spell=o.resref,target=o.target,point=o.point,score=o.score,hits=#o.hits}
        end
        if not d then
            if why~='no-option' then record({kind='decline',tick=tick,member=id,family=family,reason=why,top=top}) end
            return decline(why)
        end
        local response=M.response(d)
        if not response then return decline('bad-response') end
        counts.claims=counts.claims+1
        record({kind='choice',tick=tick,member=id,family=family,spell=d.resref,castKind=d.kind,mode=d.mode,
            target=d.target,point=d.point,score=d.score,worth=d.worth,hits=d.hits,how=why,top=top,
            focus=input.plan.focus})
        local spell
        for _,row in ipairs(rows) do if row.resref==d.resref then spell=row.spell end end
        return {own=true,response=response,spell=d.resref,kind=d.kind,mode=d.mode,target=d.target,point=d.point,
            self=d.self,castTicks=spell and type(spell.speed)=='number' and spell.speed*9 or nil,
            sources=spell and spell.sources or nil}
    end
    -- From the gate, each time a hooked script asks: nil (SCS's round), {hold=true} while the
    -- engine's queued cast has not started, or the decision.
    function api:decide(view,family)
        local ok,result=pcall(decide,view,family)
        if ok then return result end
        failed('decide',result)
    end

    -- Right before the gate queues the response: the caster can still cast and the target is
    -- still a living, visible creature without sanctuary; then the caster's EEex_Target table
    -- names it. Decisions of other deciders (lab experiments) pass unchanged.
    local function prepare(object,decision)
        if not decision.own then return true end
        if not enabled or missing then return 'skipped' end
        local tick=now()
        if type(tick)~='number' then return 'skipped' end
        if g.EEex_Sprite_GetCastTimer(object)~=-1 or M.timerRunning(g,object,tick) then return 'skipped' end
        local hp
        if decision.target and not decision.point and not decision.self then
            local target=get(decision.target)
            if not target then return 'skipped' end
            local seen=sense.actor(g,target)
            if not targeting.alive(seen) or (seen.sanctuary or 0)>0 then return 'skipped' end
            if targeting.has(seen.state,UNSEEN) and not (g.EEex_Sprite_GetStat(object,sense.stats.seeInvisible)>0 or
                g.EEex_Sprite_GetStat(object,sense.stats.trueSight)>0) then return 'skipped' end
            local aux=g.EEex_GetUDAux(object)
            local make=rawget(g,'EEex_Utility_GetOrCreateTable')
            local names
            if type(make)=='function' then names=make(aux,'EEex_Target')
            else
                names=aux.EEex_Target
                if type(names)~='table' then names={};aux.EEex_Target=names end
            end
            names[M.targetName]=decision.target
            hp=seen.hp
        end
        pending[object.m_id]={caster=object.m_id,resref=decision.spell,kind=decision.kind,mode=decision.mode,
            target=decision.target,point=decision.point,tick=tick,hp=hp,castTicks=decision.castTicks,
            sources=decision.sources}
        counts.performed=counts.performed+1
        return true
    end
    function api:prepare(object,decision)
        local ok,result=pcall(prepare,object,decision)
        if ok then
            if result=='skipped' then counts.skipped=counts.skipped+1 end
            return result
        end
        failed('prepare',result)
        return false
    end

    -- From the director's started-action listener, for every sprite's every action: the
    -- engine's queued cast starting (returned for the director's picture), or another action
    -- ending a running one.
    local function started(sprite,action,tick)
        local id=sprite.m_id
        local p,r=pending[id],running[id]
        if not p and not r then return nil end
        if r then
            r.ended=tick;running[id]=nil
            if #judging<M.judgeLimit then judging[#judging+1]=r end
        end
        if p and M.CASTS[action.m_actionID] and text(action.m_string1.m_pchData:get())==p.resref then
            pending[id]=nil;p.started=tick;running[id]=p
            counts.started=counts.started+1
            record({kind='start',tick=tick,member=id,spell=p.resref,target=p.target,point=p.point,
                waited=tick-p.tick})
            return {spell=p.resref,role=p.kind,target=p.target}
        end
    end
    function api:started(sprite,action,tick)
        local ok,result=pcall(started,sprite,action,tick)
        if ok then return result end
        failed('started',result)
    end

    function api:setEnabled(value)
        assert(type(value)=='boolean');enabled=value
        if not value then pending={} end
    end
    function api:attach(r) root=r end
    function api:setSink(fn) assert(fn==nil or type(fn)=='function');sink=fn end
    function api:invalidate() pending,running,judging,memory={},{},{},{} end
    function api:inspect()
        local copy=function(t) local c={};for k,v in pairs(t) do c[k]=v end;return c end
        local rows,first={},(nextRow-size-1)%M.logCapacity+1
        for i=0,size-1 do rows[#rows+1]=log[(first+i-1)%M.logCapacity+1] end
        local open,busy,remembered=0,0,0
        for _ in pairs(pending) do open=open+1 end
        for _ in pairs(running) do busy=busy+1 end
        for _,mine in pairs(memory) do for _ in pairs(mine) do remembered=remembered+1 end end
        return {enabled=enabled,missing=missing or false,counts=copy(counts),reasons=copy(reasons),
            pending=open,running=busy,judging=#judging,remembered=remembered,log=rows,lastError=lastError or false}
    end
    return api
end
return M
