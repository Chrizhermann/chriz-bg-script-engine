-- EEex side of the fight director. Hooked creatures check in when their hook is reached (the
-- gate's observe callback), each at most every checkTicks, with a plain perception frame
-- (sense.lua); one director per area keeps the group's picture. When a member's ordinary Spell
-- action at a creature starts, the director advises. To redirect it, this adapter reads the
-- caster's frame afresh with details, checks the new target once more and changes the starting
-- action's target, as EEex's own SpellToPoint listener changes a starting action: the cast
-- keeps its casting time, spell slot and interruption. A cast aimed at a kind of creature
-- ([PC.0.0.MAGE]) has no target yet when it starts; a decoded copy of its object names the
-- creature it would hit. The spell's own SPLPROT checks are answered by the engine for each
-- enemy (sense.splprot), so a new target meets them as the original does. The engine's own
-- casts (adapters/eeex/choice.lua) are recorded for the picture and the reservations but never
-- advised. An enemy the group lost from sight is looked up by id now and then: one in a maze or a
-- prison is out of the game (sense.removed), and the director keeps it apart from the picture; one
-- dead or no creature any more is gone, and the plan and clues check theirs right before use.
-- Session-local; a load forgets it all.
-- Errors never reach the engine: the cast then goes ahead as the creature's script chose it.
local sense=require('adapters.eeex.sense')
local resources=require('adapters.eeex.resources')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local calls=require('combat-intent.calls')
local core=require('combat-intent.director')
local M={}
M.checkTicks=15
M.cacheLimit=512
-- The spell an action casts (sense.spellOf).
M.resref=sense.spellOf

function M.new(g,options)
    options=options or {}
    local reader=options.reader or resources.new(g)
    local directors,areaCalls,memberArea,memberFamily,memberInfo,lastCheck={},{},{},{},{},{}
    local shoutsOn=options.shouts~=false
    local cache,cached={},0
    local root,sink,choice
    local counts={checkIns=0,starts=0,advised=0,redirected=0,own=0,errors=0,marks=0,markFailures=0,
        removalChecks=0,calls=0,shouts=0}
    local adapter={}
    local function now() return root and root.now and root.now() end
    local function difficulty()
        local ok,level=pcall(function()
            local eg=g.EngineGlobals
            local ch=eg and eg.g_pBaldurChitin
            local game=ch and ch.m_pObjectGame
            local opt=game and game.m_options
            return (opt and opt.m_nDifficultyLevel) or (game and game.m_nDifficultyLevel)
        end)
        if ok and type(level)=='number' and level>=1 and level<=5 then return math.floor(level) end
        return 3
    end
    local function director(area)
        local d=directors[area]
        if not d then
            d=core.new({area=area,families=options.families,groupRadius=options.groupRadius,
                alertTicks=options.alertTicks,sink=function(row) if sink then sink(row) end end})
            directors[area]=d
        end
        return d
    end
    local function callManager(area)
        local cm=areaCalls[area]
        if not cm then
            cm=calls.new(options.callsConfig)
            areaCalls[area]=cm
        end
        return cm
    end
    local function recordInfo(id,sprite,frame)
        local raw=sprite.m_resref and sprite.m_resref.get and sprite.m_resref:get() or nil
        local resref=type(raw)=='string' and #raw>0 and raw:upper() or nil
        local ai=sprite.m_typeAI
        local idsName=type(reader.idsName)=='function' and reader.idsName or nil
        local race=ai and idsName and idsName('RACE',ai.m_Race) or nil
        local general=ai and idsName and idsName('GENERAL',ai.m_General) or nil
        local ord=resref and choice and type(choice.orderFor)=='function' and choice:orderFor(resref) or nil
        local info={id=id,x=frame.self.x,y=frame.self.y,race=race,general=general,resref=resref,orders=ord}
        memberInfo[id]=info
        return info
    end
    local function callHelp(area,d,callerInfo,tick)
        local cm=callManager(area)
        local active=d:members(tick)
        local list={}
        for _,m in ipairs(active) do
            local info=memberInfo[m.id]
            list[#list+1]={
                id=m.id,x=m.x,y=m.y,
                race=info and info.race or nil,
                general=info and info.general or nil,
                resref=info and info.resref or nil,
                orders=info and info.orders or nil,
            }
        end
        local rng=choice and type(choice.rng)=='function' and choice:rng() or nil
        local res=cm:call(callerInfo,list,difficulty(),tick,rng)
        if #res.alerted>0 then
            d:alert(callerInfo.id,res.alerted,tick)
            counts.calls=counts.calls+1
            local shoutKeys={}
            for _,s in ipairs(res.shouts) do
                shoutKeys[#shoutKeys+1]=s.key
                if shoutsOn and type(g.EEex_Sprite_DisplayTextRef)=='function' then
                    local strref=type(g.BGSE_CALL_STRREFS)=='table' and g.BGSE_CALL_STRREFS[s.key] or nil
                    local sp=type(strref)=='number' and g.EEex_GameObject_Get(s.id) or nil
                    if sp and g.EEex_GameObject_IsSprite(sp,false) then
                        local ok=pcall(g.EEex_Sprite_DisplayTextRef,sp,strref,{overHead=true})
                        if ok then counts.shouts=counts.shouts+1 end
                    end
                end
            end
            if sink then
                pcall(sink,{kind='call',area=area,tick=tick,member=callerInfo.id,profile=res.profile,
                    alerted=res.alerted,shouts=#shoutKeys>0 and shoutKeys or nil})
            end
        end
    end
    local lastError,markError
    local function failed(where,err)
        counts.errors=counts.errors+1
        lastError=where..': '..tostring(err):sub(1,200)
        if sink then pcall(sink,{kind='error',where=where,error=tostring(err):sub(1,200)}) end
    end
    -- The classification of resref at the caster's level for it, cached per level.
    local function summary(sprite,resref)
        local ok,level=pcall(g.EEex_Sprite_GetCasterLevelForSpell,sprite,resref,false)
        if not ok or type(level)~='number' or level<1 then level=1 end
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

    -- The enemies the group lost from sight may be out of the game (a maze, a prison: sense.removed).
    -- The director names whom to look up by id and when; a mazed one stays where it vanished.
    local function removals(d,tick)
        for _,target in ipairs(d:removalChecks(tick)) do
            local object=g.EEex_GameObject_Get(target)
            if object and g.EEex_GameObject_IsSprite(object,false) then
                counts.removalChecks=counts.removalChecks+1
                d:removed(target,sense.removed(g,object),{x=object.m_pos.x,y=object.m_pos.y},tick)
            else
                d:removed(target,nil,nil,tick)
            end
        end
    end

    local function observe(view,family)
        local tick=now()
        if type(tick)~='number' then return end
        local id=view.id
        if lastCheck[id] and tick>=lastCheck[id] and tick-lastCheck[id]<M.checkTicks then return end
        lastCheck[id]=tick
        local sprite=g.EEex_GameObject_Get(id)
        if not sprite or not g.EEex_GameObject_IsSprite(sprite,false) then return end
        -- With the choice's memory of what creatures' effects make of them (sense.memory): the check-ins
        -- were the largest single share of the engine's time in a crowd (lab prof-camp-3, 2026-11-10).
        local frame=sense.frame(g,sprite,tick,false,choice and type(choice.readings)=='function' and choice:readings() or nil)
        if not frame or sense.side(frame.self.ea)~='evil' then memberArea[id]=nil;return end
        local d=director(frame.area)
        if d:checkIn({id=id,family=family},frame) then
            memberArea[id],memberFamily[id]=frame.area,family;counts.checkIns=counts.checkIns+1
            local info=recordInfo(id,sprite,frame)
            if #frame.enemies>0 then
                local okCall,errCall=pcall(callHelp,frame.area,d,info,tick)
                if not okCall then failed('call',errCall) end
            end
        end
        local ok,err=pcall(removals,d,tick)
        if not ok then failed('removed',err) end
        d:tick(tick)
    end
    -- From the gate, each time a hooked script asks and passes the gate's own checks.
    function adapter:observe(view,family)
        local ok,err=pcall(observe,view,family)
        if not ok then failed('observe',err) end
    end

    local function started(sprite,action)
        local tick=now()
        -- The engine's own cast starting, or an action ending one (every sprite comes here).
        local own=choice and type(tick)=='number' and choice:started(sprite,action,tick)
        local id=sprite.m_id
        local area=memberArea[id]
        if not area then return end
        local d=directors[area]
        if not d or type(tick)~='number' or not d:isMember(id) then return end
        if own then
            counts.own=counts.own+1
            d:started({id=id,family=memberFamily[id]},{spell=own.spell,role=own.role,target=own.target,
                hits=own.hits,original=own.target,action=action.m_actionID,own=true},tick)
            return
        end
        if action.m_actionID~=31 then d:action(id,tick);return end
        counts.starts=counts.starts+1
        local resref=M.resref(action)
        local original=action.m_acteeID.m_Instance
        local typed=false
        -- A cast at a kind of creature: the engine decodes the object as the cast runs; decode a
        -- copy the same way (EEex evaluates a copy) to learn whom it names.
        if type(original)~='number' or original<0 then
            local ok,named=pcall(g.EEex_Object_EvalAsAIBase,action.m_acteeID,sprite,false)
            if not ok then failed('decode',named)
            elseif named and g.EEex_GameObject_IsSprite(named,false) then
                original,typed=named.m_id,true
            end
        end
        local spell=resref and summary(sprite,resref)
        local member={id=id,family=memberFamily[id]}
        local cast={spell=resref,role=targeting.role(spell),target=original,original=original,action=31,
            typed=typed or nil}
        local allowed=root and root.gate and member.family and root.gate:allows(member.family)
        if allowed and spell and targeting.kind(spell) and original~=id then
            local frame=sense.frame(g,sprite,tick,true)
            -- A member the party charmed stands on the party's side now: what it sees is not the
            -- group's picture, and it is no member until it comes back.
            if frame and sense.side(frame.self.ea)~='evil' then memberArea[id]=nil;frame=nil end
            if frame then
                local read,bad,last=sense.splprot(g,sprite,frame,spells.rows(spell))
                counts.marks=counts.marks+read
                if bad>0 then
                    counts.markFailures=counts.markFailures+bad
                    if not markError then
                        markError=tostring(last):sub(1,200)
                        if sink then pcall(sink,{kind='error',where='splprot',error=markError}) end
                    end
                end
                d:checkIn(member,frame)
                counts.advised=counts.advised+1
                local advice=d:advise(member,frame,spell,original,tick,typed)
                if advice.action=='redirect' then
                    -- The last check: the new target is still a living sprite the caster sees.
                    local target=g.EEex_GameObject_Get(advice.target)
                    local seen=false
                    for _,e in ipairs(frame.enemies) do if e.id==advice.target then seen=true end end
                    if target and seen and g.EEex_GameObject_IsSprite(target,false) then
                        if typed then
                            -- The object takes the new target's AI type, as the engine fills in
                            -- an object it has decoded; its instance then names the target.
                            action.m_acteeID:Set(target:virtual_GetAIType())
                        else
                            action.m_acteeID.m_Instance=advice.target
                        end
                        if action.m_acteeID.m_Instance==advice.target then
                            cast.target=advice.target;cast.redirected=true
                            counts.redirected=counts.redirected+1
                        end
                    end
                end
            end
        end
        d:started(member,cast,tick)
    end
    -- From EEex's started-action listener, for every sprite's every action.
    function adapter:onStarted(sprite,action)
        local ok,err=pcall(started,sprite,action)
        if not ok then failed('started',err) end
    end

    -- Re-checked right before the group's plan or clues are used: an enemy of the picture that died,
    -- or is no creature any more, since a member last saw it is gone, and the director forgets it at
    -- once (members see only the living; lab batch J, run 4: the party's mage, dead for three seconds,
    -- was still the group's focus and in play when a mage charmed the party's last living member).
    -- Returns how many of keys were gone.
    local function settle(d,keys,tick)
        local n=0
        for _,key in ipairs(keys) do
            local object=g.EEex_GameObject_Get(key)
            if not (object and g.EEex_GameObject_IsSprite(object,false)) then d:removed(key,nil,nil,tick);n=n+1 end
        end
        return n
    end
    local function planOf(d,id,tick)
        local plan=d:plan(tick,id)
        local keys={}
        for key in pairs(plan.inPlay) do keys[#keys+1]=key end
        if settle(d,keys,tick)>0 then plan=d:plan(tick,id) end
        return plan
    end
    local function cluesOf(d,id,tick)
        local list=d:clues(id,tick)
        local keys={}
        for _,c in ipairs(list) do keys[#keys+1]=c.id end
        if settle(d,keys,tick)>0 then list=d:clues(id,tick) end
        return list
    end

    -- The group's plan for a member at tick (focus, reservations), or nil outside a group.
    function adapter:plan(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return nil end
        local ok,plan=pcall(planOf,d,id,tick)
        if ok then return plan end
        failed('plan',plan)
    end
    -- The engine's own disable for member id claims its targets in the group as soon as it is
    -- chosen; release gives them back when the decision is dropped before its cast started.
    function adapter:reserve(id,targets,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d or not d:isMember(id) then return 0 end
        local ok,n=pcall(d.reserve,d,{id=id,family=memberFamily[id]},targets,tick)
        if ok then return n end
        failed('reserve',n)
        return 0
    end
    -- The engine's own debuff for member id claims the enemies it weakens for its spell, as reserve
    -- does for a disable (F2b).
    function adapter:curse(id,targets,spell,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d or not d:isMember(id) then return 0 end
        local ok,n=pcall(d.curse,d,{id=id,family=memberFamily[id]},targets,spell,tick)
        if ok then return n end
        failed('curse',n)
        return 0
    end
    function adapter:release(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return 0 end
        local ok,n=pcall(d.release,d,id,tick)
        if ok then return n end
        failed('release',n)
        return 0
    end
    -- For the engine's search (adapters/eeex/search.lua): where the group last saw its enemies, for
    -- member id at tick (combat-intent/director.lua's clues), and the other members of its group;
    -- empty outside a group.
    function adapter:clues(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return {} end
        local ok,list=pcall(cluesOf,d,id,tick)
        if ok then return list end
        failed('clues',list)
        return {}
    end
    -- The enemies out of play in member id's group at tick (combat-intent/director.lua's away: one the
    -- group charmed, one in a maze), for the search to await; empty outside a group.
    function adapter:away(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return {} end
        local ok,list=pcall(d.away,d,tick,id)
        if ok then return list end
        failed('away',list)
        return {}
    end
    function adapter:group(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return {} end
        local ok,list=pcall(d.members,d,tick,id)
        if not ok then failed('group',list);return {} end
        local out={}
        for _,m in ipairs(list) do if m.id~=id then out[#out+1]=m end end
        return out
    end
    function adapter:setShouts(v) shoutsOn=v==true end
    function adapter:setChoice(c) choice=c end
    function adapter:attach(r) root=r end
    function adapter:setSink(fn) assert(fn==nil or type(fn)=='function');sink=fn end
    function adapter:invalidate()
        for _,d in pairs(directors) do d:invalidate('session') end
        for _,cm in pairs(areaCalls) do cm:invalidate() end
        directors,areaCalls,memberArea,memberFamily,memberInfo,lastCheck={},{},{},{},{},{}
    end
    function adapter:inspect()
        local areas={}
        for area,d in pairs(directors) do areas[area]=d:inspect() end
        local copy={};for k,v in pairs(counts) do copy[k]=v end
        return {counts=copy,areas=areas,shouts=shoutsOn,problems=reader.problems,lastError=lastError or false,
            markError=markError or false}
    end
    return adapter
end
return M
