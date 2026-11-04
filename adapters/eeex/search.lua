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
-- guards its post. The foes its group holds out of play (the director's away: one it charmed, one in
-- a maze) are no clues; the search awaits them (combat-intent/search.lua, M.await) and reads them for
-- a guard's readiness (seeker:returning). A walk is held
-- while the creature walks it, a look and the rogue's detection mode briefly; each ends early when an
-- enemy shows or the creature is hurt. A search walk that ends by itself no nearer its spot finds no
-- way there: the spot counts as searched (a 'blocked' row).
--
-- Doors (combat-intent/doors.lua, adapters/eeex/doors.lua): a creature with hands for a door (its IDS
-- names and wit, or its orders) gets the area's doors, a locked one counted as openable only when it
-- carries the key. Opening one walks to the spot the game gives for it, opens it and, to look behind
-- it, walks on there; held while it walks or opens. Then the door is judged: open, or shut when the
-- creature stopped or its time ran out without opening it (the game keeps some doors shut, and a
-- creature can stay stuck on a failed OpenDoor until the next decision replaces it). A shut door is
-- left for doors.retrySeconds. Session-local; a load forgets it all.
local sense=require('adapters.eeex.sense')
local search=require('combat-intent.search')
local targeting=require('combat-intent.targeting')
local doorRules=require('combat-intent.doors')
local doorReader=require('adapters.eeex.doors')
local M={}
M.ticksPerSecond=15
-- MoveToPoint and OpenDoor (ACTION.IDS). A walk is held while the creature walks it, or walkGrace
-- ticks until it starts, and twice its seconds at walkSpeed (world units a second,
-- combat-intent/zones.lua's) and walkMargin ticks at most; opening a door openTicks more.
M.MOVE=23
M.OPEN=143
M.walkGrace=8
M.walkMargin=30
M.walkSpeed=100
M.openTicks=15
-- The actions that get a creature through a locked door (ACTION.IDS: PickLock, BashDoor, Spell for an
-- unlocking spell), held as opening is, and unlockTicks more for the lock.
M.UNLOCKING={[145]=true,[148]=true,[31]=true}
M.unlockTicks=45
-- STATS.IDS LOCKPICKING: the creature's Open Locks (combat-intent/doors.lua, doors.way).
M.lockStat=26
-- A creature that saw an enemy or was hit within fightSeconds is still in the fight: with nothing to
-- go on, indoors, it looks behind a closed door near it (SCS's in-a-fight flag; combat-intent/search.lua).
M.fightSeconds=60
-- The ARE header's area type bit of an outdoor area (IESDP: 0x48, bit 0).
M.OUTDOOR=0x1
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
-- stuckLimit of them the creature stays where it is. A search walk that ends no nearer than progress
-- to its spot finds no way there (lab batch E8 v4: Tarnesh's walk out of a dead-end corridor whose
-- mouth two of the party blocked failed at once, again and again for 20 seconds): that spot counts
-- as searched.
M.progress=32
M.stuckLimit=2
M.cacheLimit=1024

function M.new(g,options)
    options=options or {}
    local director=options.director
    local record=type(options.record)=='function' and options.record or function() end
    local rng=options.rng
    local reader=options.reader
    local states,stateCount={},0
    local counts={hunts=0,walks=0,looks=0,returns=0,gaveUp=0,detects=0,modals=0,teleports=0,hitClues=0,guards=0,
        stuck=0,guardFailures=0,awaits=0,guardWalks=0,readyFailures=0,doors=0,doorsOpened=0,doorsShut=0,
        doorFailures=0,unlocks=0,blocked=0}
    local seeker={}
    local doorError
    -- The area's doors, read once a tick for each area.
    local doorCache
    local function state(id)
        local s=states[id]
        if not s then
            if stateCount>=M.cacheLimit then states,stateCount={},0 end
            s={searched={},clues={},hits={},stuck=0,doors={}}
            states[id]=s;stateCount=stateCount+1
        end
        return s
    end
    local function doorFailed(where,err)
        counts.doorFailures=counts.doorFailures+1
        if not doorError then
            doorError=tostring(err):sub(1,200)
            record({kind='error',where=where,error=doorError})
        end
    end
    -- Whether the creature can open doors: its orders say so, else its kind and wit (doors.opener);
    -- without a reader for its kind, no.
    local function opens(sprite,m,orders)
        if type(orders)=='table' and type(orders.doors)=='boolean' then return orders.doors end
        if not reader then return false end
        local ok,can=pcall(function()
            local t=sprite.m_typeAI
            return doorRules.opener({general=reader.idsName('GENERAL',t.m_General),race=reader.idsName('RACE',t.m_Race),
                class=reader.idsName('CLASS',t.m_Class),wit=m.wit})
        end)
        if ok then return can==true end
        doorFailed('door-opener',can)
        return false
    end
    -- The doors of the creature's area as it may use them: a locked one with key set when the
    -- creature carries its key.
    local function doorsOf(sprite,frame,tick)
        if not (doorCache and doorCache.area==frame.area and doorCache.tick==tick) then
            local list,failed,last=doorReader.read(g,sprite.m_pArea)
            if failed>0 then doorFailed('door-read',last) end
            doorCache={area=frame.area,tick=tick,doors=list}
        end
        local out,carried={},nil
        for _,d in ipairs(doorCache.doors) do
            local c={}
            for k,v in pairs(d) do c[k]=v end
            if d.locked and d.keyType then
                carried=carried or doorReader.carried(g,sprite)
                c.key=carried[d.keyType]==true
            end
            out[#out+1]=c
        end
        return out
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
        s.fought=tick
        if not s.post then
            s.post={x=frame.self.x,y=frame.self.y}
            s.guard=guards(sprite,id,tick,orders)
            if s.guard then counts.guards=counts.guards+1 end
        end
        s.since,s.gaveUp,s.tactical,s.act,s.aim,s.back,s.stuck,s.awaiting=nil,nil,nil,nil,nil,nil,0,nil
        s.searched,s.clues,s.hits={},{},{}
    end

    -- The foes out of play a creature that sees no enemy readies itself for (combat-intent/choice.lua's
    -- readiness), or nil: it guards the nearest of them (search.how: by its profile m, its orders and
    -- its post). Each is read as an enemy in sight is (sense.foe), where it went out of play, doing
    -- nothing yet, a charmed one without its charm, with back, the seconds until it is likely back:
    -- what is left of the charm its side cast, or of a maze by intelligence (INTMOD.2DA's dice,
    -- search.mazeLeft, from when the group saw it go); nil for a maze of a set duration. One that
    -- cannot be read is left out (counts.readyFailures).
    function seeker:returning(frame,tick,m,orders)
        local id=frame.self.id
        local away=director and director.away and director:away(id,tick) or {}
        if #away==0 then return nil end
        local s=states[id] or {}
        local foe=search.nearestAway({frame=frame,away=away})
        if not foe or search.how({mind=m,await=type(orders)=='table' and orders.await or nil,post=s.post,guard=s.guard},foe)~='guard' then
            return nil
        end
        local tables=sense.tables(g)
        local out={}
        for _,a in ipairs(away) do
            local object=g.EEex_GameObject_Get(a.id)
            if object and g.EEex_GameObject_IsSprite(object,false) then
                local ok,e=pcall(function()
                    local e=sense.foe(g,object,reader)
                    local held=sense.outOfPlay(g,object,tick)
                    e.x,e.y,e.away,e.action,e.actee=a.x,a.y,a.kind,0,-1
                    if a.kind=='charm' then
                        if targeting.charmed(e) then e.state=e.state-targeting.STATE.charmed end
                        e.back=held.charm
                    elseif held.maze==0 then
                        local dice=type(tables)=='table' and type(tables.maze)=='table' and tables.maze[e.int]
                        if dice and type(a.since)=='number' then
                            e.back=search.mazeLeft(dice.num,dice.size,(tick-a.since)/M.ticksPerSecond)
                        end
                    end
                    return e
                end)
                if ok then out[#out+1]=e
                else
                    counts.readyFailures=counts.readyFailures+1
                    record({kind='error',where='ready',member=id,target=a.id,error=tostring(e):sub(1,200)})
                end
            end
        end
        if #out==0 then return nil end
        return out
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
    -- patience lasts (horizon, in ticks), and its own hits; none of a foe out of play (away, by id). An
    -- enemy lost from sight lately counts as vanished where the creature sees its spot and, for one
    -- that was walking, the spot it would have reached by now.
    local function clues(s,sprite,frame,tick,horizon,away)
        if director then
            for _,c in ipairs(director:clues(frame.self.id,tick)) do
                local had=s.clues[c.id]
                if not had or c.tick>=had.tick then s.clues[c.id]=c end
            end
        end
        local out={}
        for key,c in pairs(s.clues) do
            local age=tick-c.tick
            if age<0 or age>horizon or away[c.id] or not living(c.id) then s.clues[key]=nil
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
            if tick<c.tick or tick-c.tick>horizon or away[c.id] or not living(c.id) then s.hits[key]=nil else out[#out+1]=c end
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
    -- What the creature has for locks (combat-intent/doors.lua, doors.way): its Open Locks and the
    -- unlocking spell it has ready (search.unlocks). Bashing waits for the lock probe's numbers.
    local function locks(sprite,rows)
        local ok,picks=pcall(g.EEex_Sprite_GetStat,sprite,M.lockStat)
        return {picks=ok and type(picks)=='number' and picks or nil,knock=search.unlocks(rows)}
    end
    -- Whether the creature's area is no outdoor one (its ARE header's area type); nil when it cannot be
    -- read, so no door is looked behind without a clue.
    local function indoors(sprite)
        local ok,kind=pcall(function() return sprite.m_pArea.m_header.m_areaType end)
        if not ok or type(kind)~='number' then
            ok,kind=pcall(function() return sprite.m_pArea.m_header.reference.m_areaType end)
        end
        if not ok or type(kind)~='number' then return nil end
        return g.EEex_BAnd(kind,M.OUTDOOR)==0
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
        if type(s.hp)=='number' and type(self.hp)=='number' and self.hp<s.hp then
            s.fought=tick
            hit(s,sprite,frame,tick,s.hp-self.hp)
        end
        s.hp=self.hp
        local patience=search.patience({mind=m,frame=frame})
        local away,out=director and director.away and director:away(id,tick) or {},{}
        for _,a in ipairs(away) do out[a.id]=true end
        local list=clues(s,sprite,frame,tick,math.max(search.memorySeconds,patience)*M.ticksPerSecond,out)
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
        local opener=opens(sprite,m,orders)
        local doorList,unlock,inside
        if opener then
            local ok,v=pcall(doorsOf,sprite,frame,tick)
            if ok then doorList=v else doorFailed('door-read',v) end
            unlock=locks(sprite,rows)
            inside=indoors(sprite)
        end
        local fighting=type(s.fought)=='number' and tick>=s.fought and tick-s.fought<=M.fightSeconds*M.ticksPerSecond
        local d,why=search.decide({tick=tick,frame=frame,mind=m,family=family,clues=list,post=s.post,since=s.since,
            searched=s.searched,gaveUp=s.gaveUp,detected=s.detected,jumped=s.jumped,group=group(id,frame.area,tick),
            guard=s.guard,detects=search.options(rows,carried),teleports=search.teleports(rows),illusion=illusion(sprite),
            tactical=s.tactical,away=away,await=type(orders)=='table' and orders.await or nil,opener=opener,
            doors=doorList,failed=s.doors,unlock=unlock,fighting=fighting,indoors=inside})
        if not d then
            if why=='given-up' then
                giveUp(s,id,tick,newest and 'patience' or 'no-clue')
                -- At its post, or kept where it is: the search is over, and the next fight sets the post
                -- anew.
                s.post,s.aim,s.act,s.back=nil,nil,nil,nil
            end
            s.awaiting=nil
            return nil,why
        end
        if d.gaveUp then giveUp(s,id,tick,newest and 'patience' or 'no-clue') end
        if (d.kind=='search' or d.kind=='teleport' or d.kind=='guard') and type(zoneAt)=='function' then
            if zoneAt(d.toward or d.point) then
                -- A guard's place in a danger zone: it looks out where it is.
                if d.kind=='guard' then d.kind,d.point,d.zone='look',nil,true
                else d={kind='look',key=d.key,searched=d.key,zone=true} end
            elseif d.kind=='teleport' and zoneAt(d.point) then
                -- A jump that would land in a danger zone short of its spot: the creature walks there.
                d={kind='search',point=d.toward,clue=d.clue,target=d.target,key=d.key}
            end
        elseif d.kind=='door' and type(zoneAt)=='function' then
            if d.toward and zoneAt(d.toward) then
                -- A spot in a danger zone counts as searched, door or not.
                d={kind='look',key=d.key,searched=d.key,zone=true}
            elseif zoneAt(d.point) or (d.behind and zoneAt(d.behind)) then
                -- A door it would open or look behind from inside a danger zone: left for now.
                s.doors[d.door]=tick
                d={kind='look',key=d.key,searched=d.searched,zone=true}
            end
        end
        if d.searched then s.searched[d.searched]=true end
        if d.kind=='return' then
            -- A creature that cannot come nearer its post stays where it is; one that awaits a foe
            -- out of play looks out there.
            local left=targeting.distance(self,s.post)
            if s.back and left>s.back-M.progress then s.stuck=s.stuck+1 end
            s.back=left
            if s.stuck>=M.stuckLimit then
                counts.stuck=counts.stuck+1
                record({kind='stuck',tick=tick,member=id,post=s.post,at={x=self.x,y=self.y}})
                giveUp(s,id,tick,'stuck')
                s.post,s.aim,s.act,s.back=nil,nil,nil,nil
                if not d.await then s.awaiting=nil;return nil,'given-up' end
                d.kind,d.point='look',nil
            end
        else
            s.back,s.stuck=nil,0
        end
        -- Each new way of awaiting a foe out of play is logged once.
        if d.await then
            local key=d.await..':'..d.how
            if s.awaiting~=key then
                counts.awaits=counts.awaits+1
                record({kind='await',tick=tick,member=id,family=family,target=d.await,away=d.away,how=d.how,wit=m.wit,
                    point=d.point})
            end
            s.awaiting=key
            -- A guard at its place keeps it as the spot it makes for, which the group's other guards
            -- leave free.
            if d.kind=='look' and d.point then s.aim,s.aimTick=d.point,tick end
        else
            s.awaiting=nil
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
    -- The walk prepared for a search, a guard's walk to its place by a foe out of play or a way back
    -- (decision: its kind, clue, target, gaveUp, guard and, for a search, the key of its spot), to
    -- point, an open spot: held while the creature walks it.
    function seeker:walk(sprite,decision,point,tick)
        local id=sprite.m_id
        local s=state(id)
        local from={x=sprite.m_pos.x,y=sprite.m_pos.y}
        local seconds=targeting.distance(from,point)/M.walkSpeed
        s.act={kind='walk',tick=tick,limit=math.ceil(seconds*M.ticksPerSecond*2)+M.walkMargin,
            key=decision.kind=='search' and decision.key or nil,from=from,point=point,target=decision.target}
        if decision.kind=='search' then
            s.aim,s.aimTick=point,tick
            counts.walks=counts.walks+1
        elseif decision.kind=='guard' then
            s.aim,s.aimTick=point,tick
            counts.guardWalks=counts.guardWalks+1
        else
            s.aim=nil
            counts.returns=counts.returns+1
        end
        record({kind=decision.kind,tick=tick,member=id,from=from,to=point,clue=decision.clue,target=decision.target,
            gaveUp=decision.gaveUp,guard=decision.guard})
    end
    -- A door prepared for a search (decision: its door, clue, target and toward): the walk to point,
    -- an open spot where the door is opened, the door opened, and to look behind it the walk on to
    -- behind (an open spot, or nil). Held while the creature walks or opens, at most twice the walks'
    -- seconds and the margins.
    function seeker:door(sprite,decision,point,behind,tick)
        local id=sprite.m_id
        local s=state(id)
        local from={x=sprite.m_pos.x,y=sprite.m_pos.y}
        local walk=targeting.distance(from,point)+(behind and targeting.distance(point,behind) or 0)
        s.act={kind='door',door=decision.door,way=decision.way,tick=tick,
            limit=math.ceil(walk/M.walkSpeed*M.ticksPerSecond*2)+M.walkMargin+M.openTicks+(decision.way and M.unlockTicks or 0)}
        s.aim,s.aimTick=behind or point,tick
        counts.doors=counts.doors+1
        if decision.way then counts.unlocks=counts.unlocks+1 end
        record({kind='door',tick=tick,member=id,door=decision.door,from=from,to=point,behind=behind,
            toward=decision.toward,clue=decision.clue,target=decision.target,tactical=s.tactical,way=decision.way,
            spell=decision.spell})
    end
    -- A door's try, over (why: 'time', 'done' once the creature neither walks nor opens, 'hurt',
    -- 'enemy', or seeker:stop's): open, or shut and left for doors.retrySeconds when the creature
    -- stopped or its time ran out; a 'door-end' row either way.
    local function judged(s,id,a,tick,why)
        local open=doorReader.open(g,a.door)
        if open==true then counts.doorsOpened=counts.doorsOpened+1
        elseif why=='time' or why=='done' then
            counts.doorsShut=counts.doorsShut+1
            s.doors[a.door]=tick
        end
        record({kind='door-end',tick=tick,member=id,door=a.door,open=open,why=why,way=a.way})
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
    -- A search walk over by itself (why: 'time' or 'done'): one that came no nearer than progress to its
    -- spot finds no way there, so the spot counts as searched, with a 'blocked' row.
    local function walked(s,id,a,sprite,tick,why)
        if not a.key or (why~='time' and why~='done') then return end
        local at={x=sprite.m_pos.x,y=sprite.m_pos.y}
        if targeting.distance(a.from,a.point)-targeting.distance(at,a.point)>=M.progress then return end
        s.searched[a.key]=true
        counts.blocked=counts.blocked+1
        record({kind='blocked',tick=tick,member=id,move='search',target=a.target,to=a.point,at=at,why=why})
    end
    -- Whether the creature's walk, look, detection mode or door goes on ('walk', 'look', 'modal' or
    -- 'door'; false once it is over): not past its time, a walk not once the creature has stopped
    -- walking, a door not once it neither walks nor opens, and none once an enemy shows or the
    -- creature was hurt. A door is judged when its try is over, a search walk when it is over by
    -- itself (walked).
    function seeker:holding(sprite,id,tick)
        local s=states[id]
        local a=s and s.act
        if not a then return false end
        local why
        if tick<a.tick or tick-a.tick>=a.limit then why='time' end
        if not why and (a.kind=='walk' or a.kind=='door') and tick-a.tick>=M.walkGrace then
            local action=sprite.m_curAction.m_actionID
            if action~=M.MOVE and (a.kind=='walk' or (action~=M.OPEN and not M.UNLOCKING[action])) then why='done' end
        end
        if not why and type(s.hp)=='number' and sprite.m_baseStats.m_hitPoints<s.hp then why='hurt' end
        if not why and sense.seesEnemy(g,sprite) then why='enemy' end
        if why then
            s.act=nil
            if a.kind=='door' then judged(s,id,a,tick,why) end
            if a.kind=='walk' then walked(s,id,a,sprite,tick,why) end
            return false
        end
        return a.kind
    end
    -- The creature's walk, look, detection mode or door, ended from outside at tick (why: 'zone' when
    -- it walks out of a danger zone, 'cut' when a block of SCS's cut it short); a door is judged.
    function seeker:stop(id,tick,why)
        local s=states[id]
        local a=s and s.act
        if not a then return end
        s.act=nil
        if a.kind=='door' and type(tick)=='number' then judged(s,id,a,tick,why or 'stop') end
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
