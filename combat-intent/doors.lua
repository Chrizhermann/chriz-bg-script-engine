-- Doors in the engine's own search (Christopher, 2026-10-29: doors go into the first release, "muss
-- rein"; whoever stands behind a closed door must not be safe from our creatures). SCS is the
-- blueprint ([src] genai/ssl/chase.ssl, credit DavidW): in a fight, indoors, with no enemy in sight,
-- a creature that is no moron (sfo/filetype/lib_cre.tpa, CRE_check_if_moron) walks to the nearest
-- closed door within a range of 15 and opens it; locked doors stay shut (OpenDoor needs the key).
--
-- Here combat-intent/search.lua asks, while the creature searches for enemies it cannot see. A
-- creature that can open doors (M.opener) opens a door it may open (M.usable) when
-- - the straight way to the spot it searches crosses the door (M.between): the party went through and
--   shut it, say. It opens it on its way and walks on;
-- - it has searched a spot, or has no spot left to search, and a closed door is near (M.near): it
--   looks behind the door. A tactical creature takes the door the enemy was heading for.
-- A door it failed to open (a door the game keeps shut, a lock it misjudged) is left for retrySeconds.
-- Never: a door with an armed trap (the trap would spring on the creature), a secret door nobody has
-- found, a door into another area, a "door" that blocks nothing when closed (areas keep cages, vines,
-- a harp and scripted barriers as doors without a leaf); a locked door only with a way through its lock
-- (M.way: its key, picking it, Knock or bashing it).
-- In a fight, indoors, with nothing to go on, a creature looks behind the nearest closed door near it
-- (combat-intent/search.lua; SCS's door block above, Christopher, 2026-11-03).
-- Inputs are plain values; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local M={}
M.ticksPerSecond=15
-- Who has hands for a door, after SCS's non-moron kinds (CRE_check_if_moron, credit DavidW), by the
-- installed game's IDS names: humanoids, giant humanoids and the undead, demons, dopplegangers and
-- lycanthropes; not zombies, gibberlings, golems or skeletons. Beholders and dragons, clever as SCS
-- counts them, have no hands for a door. Dull creatures never open one (combat-intent/mind.lua).
M.GENERAL={HUMANOID=true,GIANTHUMANOID=true,UNDEAD=true}
M.RACES={DEMONIC=true,DOPPLEGANGER=true,LYCANTHROPE=true}
M.NOT_RACES={ZOMBIE=true,GIBBERLING=true,BEHOLDER=true,DRAGON=true}
M.NOT_CLASSES={GOLEM_IRON=true,GOLEM_FLESH=true,GOLEM_STONE=true,GOLEM_CLAY=true,GOLEM_ICE=true,SKELETON=true}
-- A door counts within reach of the creature (its sight) and, to look behind, within nearSpot of
-- where it stands (SCS: a range of 15).
M.reach=448
M.nearSpot=15*targeting.rangeUnit
-- The way to a spot crosses a door's closed box widened by margin world units.
M.margin=8
-- A tactical creature takes a door within headingAngle of the enemy's last heading.
M.headingAngle=math.pi/3
-- After opening a door to look behind it, the creature walks behind world units past its middle.
M.behind=96
-- A door the creature failed to open is left this long.
M.retrySeconds=30

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function list(t) return type(t)=='table' and t or {} end
local function point(p) return type(p)=='table' and number(p.x) and number(p.y) end
local function whole(p) return {x=math.max(0,math.floor(p.x+0.5)),y=math.max(0,math.floor(p.y+0.5))} end

-- Whether a creature can open doors: its orders say so (doors=true or false), else its kind has hands
-- for one and its wit is not dull. c: {general, race, class (IDS names), wit}.
function M.opener(c,orders)
    if type(orders)=='table' and type(orders.doors)=='boolean' then return orders.doors end
    if type(c)~='table' or c.wit=='dull' then return false end
    if M.NOT_RACES[c.race] or M.NOT_CLASSES[c.class] then return false end
    return M.GENERAL[c.general]==true or M.RACES[c.race]==true
end

-- The door's closed box {left, top, right, bottom}, or nil.
function M.box(door)
    local b=type(door)=='table' and door.box
    if type(b)~='table' or not (number(b.left) and number(b.top) and number(b.right) and number(b.bottom)) or
        b.left>b.right or b.top>b.bottom then return nil end
    return b
end
-- The middle of the door's closed box.
function M.middle(door)
    local b=M.box(door)
    return {x=(b.left+b.right)/2,y=(b.top+b.bottom)/2}
end

-- Ways through a locked door (Christopher, 2026-11-03: key, picking the lock, bashing it or Knock,
-- "können wir gerne alles so machen"), the cheapest first: its key (OpenDoor opens a locked door for a
-- creature that carries it, IESDP), picking the lock (success "depends on points in the Open Locks
-- skill", IESDP: Open Locks at or above the door's lock difficulty), a ready spell that unlocks (opcode
-- 125, Knock: it "only works on locks that can normally be picked", IESDP), bashing it (a chance each
-- try, unlock.bash). A lock of difficulty unpickable can be neither picked nor knocked open, nor can one
-- whose difficulty could not be read.
M.unpickable=100
-- Bashing is tried when a try succeeds at least this often.
M.bashMin=0.05
-- How the creature gets through door: 'open' when it is not locked, else 'key', 'pick', 'knock' or
-- 'bash', the first it has; nil when it has none. unlock: what the creature has for locks (picks, its
-- Open Locks; knock, the resref of a ready spell that unlocks; bash, its chance a try).
function M.way(door,unlock)
    if type(door)~='table' then return nil end
    if door.locked~=true then return 'open' end
    if door.key==true then return 'key' end
    local u=type(unlock)=='table' and unlock or {}
    local hard=number(door.difficulty) and door.difficulty or M.unpickable
    if hard<M.unpickable then
        if number(u.picks) and u.picks>=hard then return 'pick' end
        if type(u.knock)=='string' and u.knock~='' then return 'knock' end
    end
    if number(u.bash) and u.bash>=M.bashMin then return 'bash' end
    return nil
end

-- Whether door is one the creature may open: closed, with a box, a leaf that blocks the way when
-- closed (blocks), not a secret door nobody has found (hidden), without an armed trap, not into
-- another area (travel), and not locked unless the creature has a way through the lock (M.way).
function M.usable(door,unlock)
    return type(door)=='table' and number(door.id) and door.open==false and M.box(door)~=nil and door.blocks~=false and
        door.hidden~=true and door.trapped~=true and door.travel~=true and M.way(door,unlock)~=nil
end

-- Whether the straight way from a to b crosses box, widened by margin (Liang and Barsky's clipping).
function M.crosses(a,b,box,margin)
    local m=number(margin) and margin or 0
    local dx,dy=b.x-a.x,b.y-a.y
    local t0,t1=0,1
    for _,pq in ipairs({{-dx,a.x-(box.left-m)},{dx,box.right+m-a.x},{-dy,a.y-(box.top-m)},{dy,box.bottom+m-a.y}}) do
        local p,q=pq[1],pq[2]
        if p==0 then
            if q<0 then return false end
        else
            local r=q/p
            if p<0 then
                if r>t1 then return false elseif r>t0 then t0=r end
            else
                if r<t0 then return false elseif r<t1 then t1=r end
            end
        end
    end
    return t0<=t1
end

-- Where the creature stands to open door: the nearer of the spots the game gives for it (points),
-- else the middle of its box.
function M.access(self,door)
    local best,bd
    for _,p in ipairs(list(door.points)) do
        if point(p) then
            local d=targeting.distance(self,p)
            if not best or d<bd then best,bd=p,d end
        end
    end
    return whole(best or M.middle(door))
end
-- A spot behind door as the creature at from sees it: behind world units past its middle, on the far
-- side; nil when it stands in the middle.
function M.beyond(from,door)
    local c=M.middle(door)
    local dx,dy=c.x-from.x,c.y-from.y
    local len=math.sqrt(dx*dx+dy*dy)
    if len<1 then return nil end
    return whole({x=c.x+dx/len*M.behind,y=c.y+dy/len*M.behind})
end

-- The doors the creature may try now: usable with what it has for locks (input.unlock), within reach,
-- and not failed within retrySeconds (input.failed: door id to the tick it failed).
local function candidates(input)
    local self=input.frame.self
    local failed=type(input.failed)=='table' and input.failed or {}
    local out={}
    for _,d in ipairs(list(input.doors)) do
        if M.usable(d,input.unlock) and targeting.distance(self,M.middle(d))<=M.reach and
            not (number(failed[d.id]) and input.tick>=failed[d.id] and
                input.tick-failed[d.id]<M.retrySeconds*M.ticksPerSecond) then
            out[#out+1]=d
        end
    end
    return out
end

-- The door the straight way from the creature to p crosses, the nearest first (ties by id), or nil.
function M.between(input,p)
    local self=input.frame.self
    local best,bd
    for _,d in ipairs(candidates(input)) do
        if M.crosses(self,p,M.box(d),M.margin) then
            local dist=targeting.distance(self,M.middle(d))
            if not best or dist<bd or (dist==bd and d.id<best.id) then best,bd=d,dist end
        end
    end
    return best
end

-- Whether the way from spot to c lies within headingAngle of heading (vx, vy); a door right at the
-- spot does.
local function ahead(spot,c,heading)
    local hx,hy=heading.vx,heading.vy
    local h=math.sqrt(hx*hx+hy*hy)
    if h<=0 then return false end
    local dx,dy=c.x-spot.x,c.y-spot.y
    local d=math.sqrt(dx*dx+dy*dy)
    if d<1 then return true end
    return (hx*dx+hy*dy)/(h*d)>=math.cos(M.headingAngle)
end
-- The door to look behind from spot (where the creature stands): the nearest door within nearSpot of
-- it, or for a tactical creature with the enemy's last heading (heading: vx, vy) the nearest within
-- headingAngle of that heading, when there is one. Ties by id; nil when none is near.
function M.near(input,spot,heading,tactical)
    local best,bd,aimed,ad
    local led=tactical and type(heading)=='table' and number(heading.vx) and number(heading.vy)
    for _,d in ipairs(candidates(input)) do
        local c=M.middle(d)
        local dist=targeting.distance(spot,c)
        if dist<=M.nearSpot then
            if not best or dist<bd or (dist==bd and d.id<best.id) then best,bd=d,dist end
            if led and ahead(spot,c,heading) and (not aimed or dist<ad or (dist==ad and d.id<aimed.id)) then
                aimed,ad=d,dist
            end
        end
    end
    return aimed or best
end
return M
