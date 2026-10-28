-- EEex side of the engine's own search for enemies a creature cannot see (combat-intent/search.lua),
-- for the choice adapter (adapters/eeex/choice.lua). With no enemy in sight it gathers the
-- creature's clues: where its group last saw each enemy and which way it went (the director's
-- picture), as the creature reads it (still seen by another member; vanished on a spot it sees, the
-- spot where the enemy would be now included; or seen before), and a hit from an attacker it does
-- not see (its hit points dropped and the game names an enemy as the last to hit it: where that
-- enemy stands). What it can detect with comes from its ready spells and items, and a rogue's
-- Detect Illusion skill (STATS.IDS DETECTILLUSIONS); what it can teleport with from its ready spells
-- and innate abilities. Each creature keeps where its fight began (its post, where it goes back when
-- it gives up), whether its search draws its tactics, the spots it has searched, when it gave up,
-- when it last detected and when it last teleported; its group's boss, or one whose orders say so,
-- guards its post. A walk is held while the creature walks it, a look and the rogue's detection mode
-- briefly; each ends early when an enemy shows or the creature is hurt. Session-local; a load
-- forgets it all.
local sense=require('adapters.eeex.sense')
local search=require('combat-intent.search')
local targeting=require('combat-intent.targeting')
local M={}
M.ticksPerSecond=15
-- MoveToPoint (ACTION.IDS). A walk is held while the creature walks it, or walkGrace ticks until it
-- starts, and twice its seconds at walkSpeed (world units a second, combat-intent/zones.lua's) and
-- walkMargin ticks at most.
M.MOVE=23
M.walkGrace=8
M.walkMargin=30
M.walkSpeed=100
-- Ticks a look and the rogue's detection mode are held.
M.lookTicks=15
M.modalTicks=8
-- A member's walk counts for the group's spreading out this long after it began.
M.aimTicks=150
-- An enemy farther than twice the sight range cannot just have hit the creature: an old name.
M.hitRange=896
-- STATS.IDS DETECTILLUSIONS; the modal state of the Find Traps mode (MODAL.IDS DETECTTRAPS), in which
-- a rogue's Detect Illusion works; and of the stealth mode (MODAL.IDS STEALTH): a rogue hiding in
-- shadows keeps its hide (combat-intent/stealth.lua), as the game has one mode at a time.
M.illusionStat=136
M.detectMode=2
M.stealthMode=3
-- A walk back that ends no nearer than progress to the post than the last is stuck; after
-- stuckLimit of them the creature stays where it is.
M.progress=32
M.stuckLimit=2
M.cacheLimit=1024

function M.new(g,options)
    options=options or {}
    local director=options.director
    local record=type(options.record)=='function' and options.record or function() end
    local rng=options.rng
    local states,stateCount={},0
    local counts={hunts=0,walks=0,looks=0,returns=0,gaveUp=0,detects=0,modals=0,teleports=0,hitClues=0,guards=0,
        stuck=0,guardFailures=0}
    local seeker={}
    local function state(id)
        local s=states[id]
        if not s then
            if stateCount>=M.cacheLimit then states,stateCount={},0 end
            s={searched={},clues={},hits={},stuck=0}
            states[id]=s;stateCount=stateCount+1
        end
        return s
    end
    -- Whether the creature guards its post: its orders say so (guard), else whether it is its
    -- group's boss (search.boss, by the levels of the members the director knows).
    local function guards(sprite,id,tick,orders)
        if type(orders)=='table' and type(orders.guard)=='boolean' then return orders.guard end
        if not director then return false end
        local ok,boss=pcall(function()
            local others={}
            for _,m in ipairs(director:group(id,tick)) do
                local object=g.EEex_GameObject_Get(m.id)
                if object and g.EEex_GameObject_IsSprite(object,false) then others[#others+1]=sense.identity(g,object,{}).level end
            end
            return search.boss(sense.identity(g,sprite,{}).level,others)
        end)
        if ok then return boss==true end
        counts.guardFailures=counts.guardFailures+1
        return false
    end
    local function giveUp(s,id,tick,why)
        if s.gaveUp then return end
        s.gaveUp=tick;counts.gaveUp=counts.gaveUp+1
        record({kind='gave-up',tick=tick,member=id,since=s.since,why=why})
    end

    -- An enemy in sight: the fight goes on. Where it began is the creature's post; a search is over,
    -- and the next starts afresh.
    function seeker:fight(sprite,frame,tick,orders)
        local id=frame.self.id
        local s=state(id)
        s.hp=frame.self.hp
        if not s.post then
            s.post={x=frame.self.x,y=frame.self.y}
            s.guard=guards(sprite,id,tick,orders)
            if s.guard then counts.guards=counts.guards+1 end
        end
        s.since,s.gaveUp,s.tactical,s.act,s.aim,s.back,s.stuck=nil,nil,nil,nil,nil,nil,0
        s.searched,s.clues,s.hits={},{},{}
    end

    -- A hit from an enemy the creature does not see (it sees none): its hit points dropped since it
    -- was last looked at, and the game names that enemy as the last to hit it. The clue is where the
    -- enemy stands, near when the creature sees the spot.
    local function hit(s,sprite,frame,tick,lost)
        local ok,hitter=pcall(function() return sprite.m_lHitter.m_Instance end)
        if not ok or type(hitter)~='number' or hitter<=0 then return end
        local object=g.EEex_GameObject_Get(hitter)
        if not object or not g.EEex_GameObject_IsSprite(object,false) then return end
        local side=sense.side(object.m_typeAI.m_EnemyAlly)
        if side==nil or side==sense.side(frame.self.ea) then return end
        local at={x=object.m_pos.x,y=object.m_pos.y}
        if targeting.distance(frame.self,at)>M.hitRange then return end
        local near=sense.sees(g,sprite,at.x,at.y)
        s.hits[hitter]={kind='hit',id=hitter,x=at.x,y=at.y,tick=tick,near=near}
        counts.hitClues=counts.hitClues+1
        record({kind='clue',tick=tick,member=frame.self.id,clue='hit',target=hitter,near=near,lost=lost})
    end
    -- Whether the creature with id lives: a dead enemy is no clue, its body lies where a search
    -- would find it (the group's picture keeps the last it saw of each enemy, also of one that died
    -- out of sight).
    local function living(id)
        local object=g.EEex_GameObject_Get(id)
        return object~=nil and g.EEex_GameObject_IsSprite(object,false)
    end
    -- The creature's clues now: the group's picture as it reads it, each enemy's kept while its
    -- patience lasts (horizon, in ticks), and its own hits. An enemy lost from sight lately counts as
    -- vanished where the creature sees its spot and, for one that was walking, the spot it would
    -- have reached by now.
    local function clues(s,sprite,frame,tick,horizon)
        if director then
            for _,c in ipairs(director:clues(frame.self.id,tick)) do
                local had=s.clues[c.id]
                if not had or c.tick>=had.tick then s.clues[c.id]=c end
            end
        end
        local out={}
        for key,c in pairs(s.clues) do
            local age=tick-c.tick
            if age<0 or age>horizon or not living(c.id) then s.clues[key]=nil
            else
                local near=false
                if age<=search.vanishTicks then
                    near=sense.sees(g,sprite,c.x,c.y)
                    if near and type(c.vx)=='number' and type(c.vy)=='number' then
                        local t=math.min(age/M.ticksPerSecond,search.leadSeconds)
                        local ahead={x=c.x+c.vx*t,y=c.y+c.vy*t}
                        if targeting.distance(c,ahead)>=search.arrive then near=sense.sees(g,sprite,ahead.x,ahead.y) end
                    end
                end
                out[#out+1]={kind=search.kindOf(age,near,c.by),id=c.id,x=c.x,y=c.y,tick=c.tick,vx=c.vx,vy=c.vy,near=near}
            end
        end
        for key,c in pairs(s.hits) do
            if tick<c.tick or tick-c.tick>horizon or not living(c.id) then s.hits[key]=nil else out[#out+1]=c end
        end
        table.sort(out,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end return a.id<b.id end)
        return out
    end
    -- The group's other searchers in the area and the spots they make for.
    local function group(id,area,tick)
        local out={}
        for other,s in pairs(states) do
            if other~=id and s.aim and s.area==area and tick>=s.aimTick and tick-s.aimTick<=M.aimTicks then
                out[#out+1]={id=other,family=s.family,point=s.aim}
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        return out
    end
    -- A rogue's Detect Illusion skill, unless its detection mode is on already or it hides in shadows.
    local function illusion(sprite)
        local ok,mode=pcall(function() return sprite.m_nModalState end)
        if ok and (mode==M.detectMode or mode==M.stealthMode) then return nil end
        local skill=g.EEex_Sprite_GetStat(sprite,M.illusionStat)
        return type(skill)=='number' and skill>0 and skill or nil
    end

    -- With no enemy in sight: what the creature does now (combat-intent/search.lua's decision; a look
    -- is held from here), or nil and why its own life goes on ('no-clue', 'given-up'). m: its profile;
    -- rows and carried: what it has ready (adapters/eeex/choice.lua's book); zoneAt(p): whether a spot
    -- lies in a danger zone, where no search walks or jumps; orders: its designer's orders.
    function seeker:decide(sprite,frame,tick,family,m,rows,carried,zoneAt,orders)
        local self=frame.self
        local id=self.id
        local s=state(id)
        s.family,s.area=family,frame.area
        if type(s.hp)=='number' and type(self.hp)=='number' and self.hp<s.hp then hit(s,sprite,frame,tick,s.hp-self.hp) end
        s.hp=self.hp
        local patience=search.patience({mind=m,frame=frame})
        local list=clues(s,sprite,frame,tick,math.max(search.memorySeconds,patience)*M.ticksPerSecond)
        local newest
        for _,c in ipairs(list) do if not newest or c.tick>newest then newest=c.tick end end
        -- Something new since the creature gave up (a hit, a member seeing the enemy again): it
        -- searches again.
        if newest and s.gaveUp and newest>s.gaveUp then s.gaveUp,s.since=nil,nil end
        if newest and not s.since and not s.gaveUp then
            s.since=tick;s.tactical=search.draw(m,rng)
            counts.hunts=counts.hunts+1
            record({kind='hunt',tick=tick,member=id,family=family,clues=#list,tactical=s.tactical,patience=patience,
                guard=s.guard or nil,wit=m.wit})
        end
        local d,why=search.decide({tick=tick,frame=frame,mind=m,family=family,clues=list,post=s.post,since=s.since,
            searched=s.searched,gaveUp=s.gaveUp,detected=s.detected,jumped=s.jumped,group=group(id,frame.area,tick),
            guard=s.guard,detects=search.options(rows,carried),teleports=search.teleports(rows),illusion=illusion(sprite),
            tactical=s.tactical})
        if not d then
            if why=='given-up' then
                giveUp(s,id,tick,newest and 'patience' or 'no-clue')
                -- At its post, or kept where it is: the search is over, and the next fight sets the post
                -- anew.
                s.post,s.aim,s.act,s.back=nil,nil,nil,nil
            end
            return nil,why
        end
        if d.gaveUp then giveUp(s,id,tick,newest and 'patience' or 'no-clue') end
        if (d.kind=='search' or d.kind=='teleport') and type(zoneAt)=='function' then
            if zoneAt(d.toward or d.point) then
                d={kind='look',key=d.key,searched=d.key,zone=true}
            elseif d.kind=='teleport' and zoneAt(d.point) then
                -- A jump that would land in a danger zone short of its spot: the creature walks there.
                d={kind='search',point=d.toward,clue=d.clue,target=d.target,key=d.key}
            end
        end
        if d.searched then s.searched[d.searched]=true end
        if d.kind=='return' then
            -- A creature that cannot come nearer its post stays where it is.
            local away=targeting.distance(self,s.post)
            if s.back and away>s.back-M.progress then s.stuck=s.stuck+1 end
            s.back=away
            if s.stuck>=M.stuckLimit then
                counts.stuck=counts.stuck+1
                record({kind='stuck',tick=tick,member=id,post=s.post,at={x=self.x,y=self.y}})
                giveUp(s,id,tick,'stuck')
                s.post,s.aim,s.act,s.back=nil,nil,nil,nil
                return nil,'given-up'
            end
        else
            s.back,s.stuck=nil,0
        end
        if d.kind=='look' then
            s.act={kind='look',tick=tick,limit=M.lookTicks};counts.looks=counts.looks+1
        elseif d.kind=='detect' or d.kind=='modal' then
            s.detected=tick
            if d.kind=='detect' then counts.detects=counts.detects+1 else counts.modals=counts.modals+1 end
            record({kind='detect',tick=tick,member=id,spell=d.resref,clue=d.clue,target=d.target,self=d.self,point=d.point,
                item=d.item,modal=d.kind=='modal' or nil,tactical=s.tactical})
        end
        return d
    end
    -- The walk prepared for a search or a way back (decision: its kind, clue, target, gaveUp and
    -- guard), to point, an open spot: held while the creature walks it.
    function seeker:walk(sprite,decision,point,tick)
        local id=sprite.m_id
        local s=state(id)
        local from={x=sprite.m_pos.x,y=sprite.m_pos.y}
        local seconds=targeting.distance(from,point)/M.walkSpeed
        s.act={kind='walk',tick=tick,limit=math.ceil(seconds*M.ticksPerSecond*2)+M.walkMargin}
        if decision.kind=='search' then
            s.aim,s.aimTick=point,tick
            counts.walks=counts.walks+1
        else
            s.aim=nil
            counts.returns=counts.returns+1
        end
        record({kind=decision.kind,tick=tick,member=id,from=from,to=point,clue=decision.clue,target=decision.target,
            gaveUp=decision.gaveUp,guard=decision.guard})
    end
    -- The teleport prepared for a search (decision: its spell, clue and target), to point, an open
    -- spot: cast like the engine's other casts, which hold it; the members spread out from its spot.
    function seeker:jump(sprite,decision,point,tick)
        local id=sprite.m_id
        local s=state(id)
        s.jumped=tick
        s.aim,s.aimTick=point,tick
        counts.teleports=counts.teleports+1
        record({kind='teleport',tick=tick,member=id,from={x=sprite.m_pos.x,y=sprite.m_pos.y},to=point,spell=decision.spell,
            clue=decision.clue,target=decision.aim,innate=decision.innate,tactical=s.tactical})
    end
    -- When the creature last teleported, for a search or into the fight (adapters/eeex/choice.lua):
    -- one gap counts for both (combat-intent/search.lua, M.jump); nil when it has not.
    function seeker:jumped(id)
        local s=states[id]
        return s and s.jumped
    end
    -- A teleport into the fight, prepared at tick: its gap counts for the search's teleports too.
    function seeker:leapt(id,tick) state(id).jumped=tick end
    -- The rogue's detection mode, started: held briefly before the search goes on.
    function seeker:mode(sprite,tick)
        state(sprite.m_id).act={kind='modal',tick=tick,limit=M.modalTicks}
    end
    -- Whether the creature's walk, look or detection mode goes on ('walk', 'look' or 'modal'; false
    -- once it is over): not past its time, a walk not once the creature has stopped walking, and none
    -- once an enemy shows or the creature was hurt.
    function seeker:holding(sprite,id,tick)
        local s=states[id]
        local a=s and s.act
        if not a then return false end
        local over=tick<a.tick or tick-a.tick>=a.limit
        if not over and a.kind=='walk' and sprite.m_curAction.m_actionID~=M.MOVE and tick-a.tick>=M.walkGrace then over=true end
        if not over and type(s.hp)=='number' and sprite.m_baseStats.m_hitPoints<s.hp then over=true end
        if not over and sense.seesEnemy(g,sprite) then over=true end
        if over then s.act=nil;return false end
        return a.kind
    end
    function seeker:stop(id)
        local s=states[id]
        if s then s.act=nil end
    end
    function seeker:invalidate() states,stateCount={},0 end
    function seeker:inspect()
        local c={}
        for k,v in pairs(counts) do c[k]=v end
        local searching,posts=0,0
        for _,s in pairs(states) do
            if s.since and not s.gaveUp then searching=searching+1 end
            if s.post then posts=posts+1 end
        end
        return {counts=c,searching=searching,posts=posts}
    end
    return seeker
end
return M
