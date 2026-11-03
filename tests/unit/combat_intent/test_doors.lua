-- Doors in the engine's own search (combat-intent/doors.lua, combat-intent/search.lua): who has hands
-- for a door, which doors may be opened, the way across a door, where a creature stands to open one
-- and what lies behind it, and the search's door decisions. Plain values only.
local doors=require('combat-intent.doors')
local search=require('combat-intent.search')
local groups=0

local function self(fields)
    local s={id=1,x=1000,y=1000,hp=40,maxHp=40,moraleBreak=5}
    for k,v in pairs(fields or {}) do s[k]=v end
    return s
end
local function input(fields)
    local i={tick=3000,frame={self=self(),enemies={},allies={}},mind={wit='clever',tactics=1},family='fighter',clues={}}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
-- A closed door whose leaf stands across x=cx (or y=cy when flat), with the spots on either side the
-- game gives for opening it.
local function door(id,cx,cy,fields)
    local d={id=id,open=false,box={left=cx-10,top=cy-40,right=cx+10,bottom=cy+40},
        points={{x=cx-20,y=cy},{x=cx+20,y=cy}}}
    for k,v in pairs(fields or {}) do d[k]=v end
    return d
end
local function flat(id,cx,cy,fields)
    local d={id=id,open=false,box={left=cx-40,top=cy-10,right=cx+40,bottom=cy+10},
        points={{x=cx,y=cy-20},{x=cx,y=cy+20}}}
    for k,v in pairs(fields or {}) do d[k]=v end
    return d
end

-- 1. Who has hands for a door (after SCS's non-moron kinds): humanoids, giant humanoids, the undead,
-- demons, dopplegangers and lycanthropes; not dull ones, animals, beholders, dragons, zombies,
-- gibberlings, golems or skeletons. Orders say yes or no whatever the kind.
assert(doors.opener({general='HUMANOID',race='HUMAN',class='FIGHTER',wit='normal'})==true)
assert(doors.opener({general='HUMANOID',race='HUMAN',class='FIGHTER',wit='dull'})==false)
assert(doors.opener({general='GIANTHUMANOID',race='OGRE',wit='normal'})==true)
assert(doors.opener({general='UNDEAD',race='VAMPIRE',wit='clever'})==true)
assert(doors.opener({general='UNDEAD',race='SKELETON',class='SKELETON',wit='normal'})==false)
assert(doors.opener({general='UNDEAD',race='ZOMBIE',wit='normal'})==false)
assert(doors.opener({general='GIANTHUMANOID',race='GOLEM',class='GOLEM_IRON',wit='normal'})==false)
assert(doors.opener({general='HUMANOID',race='GIBBERLING',wit='normal'})==false)
assert(doors.opener({general='MONSTER',race='DEMONIC',wit='clever'})==true)
assert(doors.opener({general='MONSTER',race='LYCANTHROPE',wit='normal'})==true)
assert(doors.opener({general='MONSTER',race='BEHOLDER',wit='clever'})==false)
assert(doors.opener({general='MONSTER',race='DRAGON',class='DRAGON',wit='clever'})==false)
assert(doors.opener({general='ANIMAL',race='WOLF',wit='normal'})==false)
assert(doors.opener({general='ANIMAL',race='WOLF',wit='dull'},{doors=true})==true)
assert(doors.opener({general='HUMANOID',race='HUMAN',wit='clever'},{doors=false})==false)
assert(doors.opener(nil)==false and doors.opener({general='HUMANOID'},{doors='yes'})==true)
local orders=require('combat-intent.orders')
assert(orders.check({doors=true}) and orders.check({doors=false,guard=true}) and select(2,orders.check({doors='yes'}))=='doors')
groups=groups+1

-- 2. Which doors may be opened: closed ones with a box; not open or of unknown state, not one that
-- blocks nothing when closed, not a secret door nobody found, not trapped, not into another area; a
-- locked one only with its key.
assert(doors.usable(door(1,0,0))==true and doors.usable(door(1,0,0,{blocks=true}))==true)
assert(doors.usable(door(1,0,0,{blocks=false}))==false)
local unknown=door(1,0,0);unknown.open=nil
assert(doors.usable(door(1,0,0,{open=true}))==false and doors.usable(unknown)==false)
assert(doors.usable(door(1,0,0,{hidden=true}))==false and doors.usable(door(1,0,0,{trapped=true}))==false)
assert(doors.usable(door(1,0,0,{travel=true}))==false)
assert(doors.usable(door(1,0,0,{locked=true}))==false and doors.usable(door(1,0,0,{locked=true,key=true}))==true)
assert(doors.usable(door(1,0,0,{box=false}))==false)
assert(doors.usable(door(1,0,0,{box={left=5,top=0,right=4,bottom=1}}))==false)
assert(doors.usable(door('x',0,0))==false and doors.usable(nil)==false)
groups=groups+1

-- 3. The way across a door: through its box, beside it, short of it, beside but within the margin,
-- from inside it, straight down and across, and a way of no length.
local box={left=100,top=0,right=120,bottom=100}
assert(doors.crosses({x=0,y=50},{x=200,y=50},box,0)==true)
assert(doors.crosses({x=0,y=150},{x=200,y=150},box,0)==false)
assert(doors.crosses({x=0,y=50},{x=90,y=50},box,0)==false)
assert(doors.crosses({x=0,y=105},{x=200,y=105},box,8)==true and doors.crosses({x=0,y=105},{x=200,y=105},box,0)==false)
assert(doors.crosses({x=110,y=50},{x=300,y=300},box,0)==true)
assert(doors.crosses({x=110,y=-50},{x=110,y=200},box,0)==true and doors.crosses({x=130,y=-50},{x=130,y=200},box,0)==false)
assert(doors.crosses({x=50,y=50},{x=50,y=50},box,0)==false and doors.crosses({x=110,y=50},{x=110,y=50},box,0)==true)
groups=groups+1

-- 4. Where the creature stands to open a door (the nearer spot the game gives, else the middle) and
-- the spot behind it, past the middle on the far side.
local d4=door(4,1150,1000)
local a=doors.access({x=1000,y=1000},d4)
assert(a.x==1130 and a.y==1000)
a=doors.access({x=1300,y=1000},d4)
assert(a.x==1170 and a.y==1000)
a=doors.access({x=1000,y=1000},door(5,1150.4,1000.6,{points={}}))
assert(a.x==1150 and a.y==1001)
local b=doors.beyond({x=1000,y=1000},d4)
assert(b.x==1150+doors.behind and b.y==1000)
assert(doors.beyond({x=1150,y=1000},d4)==nil)
groups=groups+1

-- 5. The door across the way: the nearest crossing door within reach; one failed lately is left
-- for retrySeconds; one out of reach or off the way counts for nothing.
local i5=input({doors={door(7,1250,1000),door(6,1150,1000),door(8,1150,1300)}})
assert(doors.between(i5,{x=1400,y=1000}).id==6)
i5.failed={[6]=3000-15}
assert(doors.between(i5,{x=1400,y=1000}).id==7)
i5.failed={[6]=3000-30*15}
assert(doors.between(i5,{x=1400,y=1000}).id==6)
assert(doors.between(input({doors={door(9,1500,1000)}}),{x=1600,y=1000})==nil)
assert(doors.between(input({doors={door(9,1150,1000)}}),{x=1000,y=1400})==nil)
assert(doors.between(input({doors={door(11,1150,1000),door(10,1150,1000)}}),{x=1400,y=1000}).id==10)
groups=groups+1

-- 6. The door to look behind: the nearest within nearSpot; a tactical creature with the enemy's
-- heading takes the door it was heading for, even a farther one; without a heading, or untactical,
-- the nearest; one right at the spot counts as ahead.
local spot={x=1300,y=1000}
local east,south=door(12,1400,1000),flat(13,1300,1150)
local i6=input({frame={self=self(spot),enemies={},allies={}},doors={east,south}})
assert(doors.near(i6,spot,nil,true).id==12)
assert(doors.near(i6,spot,{vx=0,vy=50},true).id==13 and doors.near(i6,spot,{vx=0,vy=50},false).id==12)
assert(doors.near(i6,spot,{vx=0,vy=0},true).id==12)
assert(doors.near(input({frame={self=self(spot),enemies={},allies={}},doors={door(14,1600,1000)}}),spot,nil,true)==nil)
local i6b=input({frame={self=self(spot),enemies={},allies={}},doors={east,door(15,1300,1000)}})
assert(doors.near(i6b,spot,{vx=0,vy=50},true).id==15)
groups=groups+1

-- 7. The search: a closed door across the way to a clue is opened first, then the walk goes on, also
-- before a teleport; not by a creature without hands for doors, nor through an open door.
local seen={kind='seen',id=21,x=1300,y=1000,tick=2950}
local d=search.decide(input({clues={seen},opener=true,doors={door(6,1150,1000)}}))
assert(d.kind=='door' and d.door==6 and d.point.x==1130 and d.point.y==1000 and d.toward.x==1300 and
    d.clue=='seen' and d.target==21 and d.key=='seen:21:2950' and d.searched==nil and d.behind==nil)
d=search.decide(input({clues={seen},doors={door(6,1150,1000)}}))
assert(d.kind=='search' and d.point.x==1300)
d=search.decide(input({clues={seen},opener=true,doors={door(6,1150,1000,{open=true})}}))
assert(d.kind=='search')
local spin={resref='SPIN147',range=1000,innate=true,level=1,speed=0}
d=search.decide(input({clues={seen},teleports={spin},opener=true,doors={door(6,1150,1000)}}))
assert(d.kind=='door' and d.door==6)
d=search.decide(input({clues={seen},teleports={spin},opener=true,doors={}}))
assert(d.kind=='teleport')
groups=groups+1

-- 8. On a searched spot a closed door nearby is looked behind (the spot counts as searched); a
-- tactical creature takes the door the enemy was heading for. With no spot left it looks behind a
-- door near it while its patience lasts. Not without hands, not rooted, and a guard not beyond its
-- radius.
local here={kind='seen',id=22,x=1300,y=1000,tick=2950,vx=0,vy=10}
local at=self({x=1300,y=1000})
local i8=input({frame={self=at,enemies={},allies={}},clues={here},opener=true,doors={east,south}})
d=search.decide(i8)
assert(d.kind=='door' and d.door==13 and d.searched=='seen:22:2950' and d.key=='seen:22:2950' and d.clue=='seen' and
    d.target==22 and d.behind.x==1300 and d.behind.y==1150+doors.behind and d.toward==nil)
i8.tactical=false
d=search.decide(i8)
assert(d.kind=='door' and d.door==12 and d.behind.x==1400+doors.behind)
d=search.decide(input({frame={self=at,enemies={},allies={}},clues={here},doors={east,south}}))
assert(d.kind=='look' and d.searched=='seen:22:2950')
d=search.decide(input({frame={self=at,enemies={},allies={}},clues={here},searched={['seen:22:2950']=true},
    opener=true,doors={east,south}}))
assert(d.kind=='door' and d.door==13 and d.searched==nil and d.key==nil)
d=search.decide(input({frame={self=at,enemies={},allies={}},clues={here},searched={['seen:22:2950']=true},
    opener=true,doors={}}))
assert(d.kind=='look')
d=search.decide(input({frame={self=self({x=1300,y=1000,rooted=true}),enemies={},allies={}},clues={here},opener=true,
    doors={east}}))
assert(d.kind=='look' and d.rooted==true)
d=search.decide(input({frame={self=self({x=1300,y=1000,rooted=true}),enemies={},allies={}},clues={here},
    searched={['seen:22:2950']=true},opener=true,doors={east,south}}))
assert(d.kind=='look')
d=search.decide(input({frame={self=at,enemies={},allies={}},clues={here},opener=true,doors={east},guard=true,
    post={x=1150,y=1000}}))
assert(d.kind=='look' and d.searched=='seen:22:2950')
d=search.decide(input({frame={self=at,enemies={},allies={}},clues={here},opener=true,doors={east},guard=true,
    post={x=1300,y=900}}))
assert(d.kind=='door' and d.door==12)
groups=groups+1

-- 9. Locked doors (Christopher, 2026-11-03: key, picking, Knock or bashing, "können wir gerne alles so
-- machen"), the cheapest way first: the key, then picking with Open Locks at or above the lock's
-- difficulty, then a ready unlocking spell (only on a lock that can be picked), then bashing. A lock of
-- 100, or of unknown difficulty, is neither picked nor knocked open; bashing needs a fair chance.
local locked=function(fields) local f={locked=true,difficulty=60};for k,v in pairs(fields or {}) do f[k]=v end;return door(1,0,0,f) end
assert(doors.way(door(1,0,0))=='open' and doors.way(locked({key=true}),{picks=100,knock='SPWI207'})=='key')
assert(doors.way(locked(),{picks=60})=='pick' and doors.way(locked(),{picks=59})==nil)
assert(doors.way(locked(),{picks=30,knock='SPWI207',bash=0.5})=='knock' and doors.way(locked(),{knock=''})==nil)
assert(doors.way(locked(),{bash=0.5})=='bash' and doors.way(locked(),{bash=doors.bashMin/2})==nil)
assert(doors.way(locked({difficulty=100}),{picks=100,knock='SPWI207'})==nil and
    doors.way(locked({difficulty=100}),{picks=100,bash=0.3})=='bash')
local unread=locked();unread.difficulty=nil
assert(doors.way(unread,{picks=100,knock='SPWI207'})==nil and doors.way(nil)==nil)
assert(doors.usable(locked(),{picks=80})==true and doors.usable(locked())==false and doors.usable(locked(),{picks=10})==false)
-- In the search: the way goes with the door decision, and Knock names its spell.
local barred=door(6,1150,1000,{locked=true,difficulty=40})
d=search.decide(input({clues={seen},opener=true,doors={barred},unlock={picks=50}}))
assert(d.kind=='door' and d.door==6 and d.way=='pick' and d.spell==nil and d.toward.x==1300)
d=search.decide(input({clues={seen},opener=true,doors={barred},unlock={knock='SPWI207'}}))
assert(d.kind=='door' and d.way=='knock' and d.spell=='SPWI207')
d=search.decide(input({clues={seen},opener=true,doors={barred}}))
assert(d.kind=='search')
d=search.decide(input({clues={seen},opener=true,doors={door(6,1150,1000)}}))
assert(d.kind=='door' and d.way==nil)
-- The unlocking spell the creature has ready: the lowest level, ties by name; none spent or unusable.
local unlocking={roles={unlock={kinds={door=true},who={target=true}}},level=2}
local function book(resref,fields)
    local r={resref=resref,ready=1,usable=true,spell=unlocking}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
assert(search.unlocks({book('SPWI207'),book('XXKNOCK',{level=1})})=='XXKNOCK')
assert(search.unlocks({book('SPWI207',{ready=0}),book('XXKNOCK',{usable=false})})==nil)
assert(search.unlocks({book('B'),book('A')})=='A' and search.unlocks({{resref='X',ready=1,usable=true,spell={roles={}}}})==nil)
groups=groups+1

-- 10. With nothing to go on, in a fight and indoors, the creature looks behind the nearest closed door
-- near it (SCS's door block); not outdoors, not out of a fight, not without hands, not rooted, not a
-- door beyond nearSpot.
local here10=self({x=1300,y=1000})
local function idle(fields)
    local i=input({frame={self=here10,enemies={},allies={}},opener=true,doors={east},fighting=true,indoors=true})
    for k,v in pairs(fields or {}) do i[k]=v end
    return search.decide(i)
end
d=idle()
assert(d.kind=='door' and d.door==12 and d.behind.x==1400+doors.behind and d.clue==nil and d.key==nil)
assert(select(2,idle({indoors=false}))=='no-clue' and select(2,idle({fighting=false}))=='no-clue')
assert(select(2,idle({opener=false}))=='no-clue' and select(2,idle({doors={door(14,1600,1000)}}))=='no-clue')
assert(select(2,idle({frame={self=self({x=1300,y=1000,rooted=true}),enemies={},allies={}}}))=='no-clue')
d=idle({doors={door(12,1400,1000,{locked=true,difficulty=20})},unlock={picks=20}})
assert(d.kind=='door' and d.way=='pick')
groups=groups+1

return groups
