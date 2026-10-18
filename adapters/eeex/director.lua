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
-- advised. Session-local; a load forgets it all.
-- Errors never reach the engine: the cast then goes ahead as the creature's script chose it.
local sense=require('adapters.eeex.sense')
local resources=require('adapters.eeex.resources')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local core=require('combat-intent.director')
local M={}
M.checkTicks=15
M.cacheLimit=512
-- SPELL.IDS numbers name their resref by thousands: 1 priest, 2 wizard, 3 innate, 4 class.
M.prefixes={'SPPR','SPWI','SPIN','SPCL'}

local function text(value) return (value:match('^[^%z]*'):upper()) end
function M.resref(action)
    local name=text(action.m_string1.m_pchData:get())
    if name~='' then return name end
    local number=action.m_specificID
    if type(number)~='number' or number<1000 or number>=5000 or number%1~=0 then return nil end
    return M.prefixes[math.floor(number/1000)]..string.format('%03d',number%1000)
end

function M.new(g,options)
    options=options or {}
    local reader=options.reader or resources.new(g)
    local directors,memberArea,memberFamily,lastCheck={},{},{},{}
    local cache,cached={},0
    local root,sink,choice
    local counts={checkIns=0,starts=0,advised=0,redirected=0,own=0,errors=0,marks=0,markFailures=0}
    local adapter={}
    local function now() return root and root.now and root.now() end
    local function director(area)
        local d=directors[area]
        if not d then
            d=core.new({area=area,families=options.families,sink=function(row) if sink then sink(row) end end})
            directors[area]=d
        end
        return d
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

    local function observe(view,family)
        local tick=now()
        if type(tick)~='number' then return end
        local id=view.id
        if lastCheck[id] and tick>=lastCheck[id] and tick-lastCheck[id]<M.checkTicks then return end
        lastCheck[id]=tick
        local sprite=g.EEex_GameObject_Get(id)
        if not sprite or not g.EEex_GameObject_IsSprite(sprite,false) then return end
        local frame=sense.frame(g,sprite,tick,false)
        if not frame or sense.side(frame.self.ea)~='evil' then memberArea[id]=nil;return end
        local d=director(frame.area)
        if d:checkIn({id=id,family=family},frame) then
            memberArea[id],memberFamily[id]=frame.area,family;counts.checkIns=counts.checkIns+1
        end
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

    -- The group's plan for a member at tick (focus, reservations), or nil outside a group.
    function adapter:plan(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return nil end
        local ok,plan=pcall(d.plan,d,tick)
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
    function adapter:release(id,tick)
        local area=memberArea[id]
        local d=area and directors[area]
        if not d then return 0 end
        local ok,n=pcall(d.release,d,id,tick)
        if ok then return n end
        failed('release',n)
        return 0
    end
    function adapter:setChoice(c) choice=c end
    function adapter:attach(r) root=r end
    function adapter:setSink(fn) assert(fn==nil or type(fn)=='function');sink=fn end
    function adapter:invalidate()
        for _,d in pairs(directors) do d:invalidate('session') end
        directors,memberArea,memberFamily,lastCheck={},{},{},{}
    end
    function adapter:inspect()
        local areas={}
        for area,d in pairs(directors) do areas[area]=d:inspect() end
        local copy={};for k,v in pairs(counts) do copy[k]=v end
        return {counts=copy,areas=areas,problems=reader.problems,lastError=lastError or false,
            markError=markError or false}
    end
    return adapter
end
return M
