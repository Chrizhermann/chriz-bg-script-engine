-- The engine's own search for enemies a creature cannot see (combat-intent/search.lua): patience by
-- wit, the tactics draw, which clue comes first, the walk (leading a moving enemy, spreading out,
-- casters behind fighters), detection, giving up and going back, guarding a post. Plain values only.
local search=require('combat-intent.search')
local groups=0

local function near(a,b) return math.abs(a-b)<1e-9 end
local function self(fields)
    local s={id=1,x=1000,y=1000,hp=40,maxHp=40,moraleBreak=5}
    for k,v in pairs(fields or {}) do s[k]=v end
    return s
end
local function input(fields)
    local i={tick=3000,frame={self=self(),enemies={},allies={}},mind={wit='clever',tactics=1},family='mage',clues={}}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function rng(value) return {nextInt=function(_,a,b) assert(a==1 and b==1000);return value end} end

-- 1. Patience: the wit's seconds, scaled for labs, halved when wounded and again when cowardly.
assert(search.patience(input())==30)
assert(search.patience(input({mind={wit='normal'}}))==18 and search.patience(input({mind={wit='dull'}}))==8)
assert(search.patience(input({mind={wit='clever',searchPatience=2}}))==60)
assert(search.patience(input({frame={self=self({hp=19})}}))==15)
assert(search.patience(input({frame={self=self({hp=19,moraleBreak=7})}}))==7.5)
assert(search.patience(input({mind={wit='odd'}}))==18)
groups=groups+1

-- 2. The tactics draw, once a search: clever always, dull never, normal by the draw.
assert(search.draw({tactics=1},rng(1000))==true and search.draw({tactics=0},rng(1))==false)
assert(search.draw({tactics=0.5},rng(400))==true and search.draw({tactics=0.5},rng(600))==false)
assert(search.draw({tactics=0.5})==true and search.draw({tactics=0.4})==false and search.draw(nil)==true)
assert(search.tactical(input({tactical=false}))==false and search.tactical(input({mind={tactics=0}}))==false)
assert(search.tactical(input())==true)
groups=groups+1

-- 3. Which clue: an enemy another member sees now, then a hit from an unseen attacker, then one that
-- vanished, then the last sighting; the newest, then the nearest. Forgotten, future and broken
-- clues count for nothing; without a clue there is nothing to do, and one that searched goes back.
local seen={kind='seen',id=11,x=1300,y=1000,tick=2950}
local hit={kind='hit',id=12,x=700,y=1000,tick=2900}
local sighted={kind='sighted',id=13,x=1600,y=1000,tick=2990}
local d=search.decide(input({clues={seen,hit,sighted}}))
assert(d.kind=='search' and d.clue=='sighted' and d.target==13 and d.point.x==1600)
d=search.decide(input({clues={seen,hit}}))
assert(d.clue=='hit' and d.target==12 and d.point.x==700 and d.key=='hit:12:2900')
d=search.decide(input({clues={seen,{kind='seen',id=14,x=900,y=1000,tick=2950}}}))
assert(d.target==14)
d=search.decide(input({clues={seen,{kind='seen',id=14,x=900,y=1000,tick=2940}}}))
assert(d.target==11)
local old={kind='seen',id=15,x=1200,y=1000,tick=3000-30*15-1}
local d2,why=search.decide(input({clues={old,{kind='seen',id=16,x=1,y=1,tick=3001},{kind='nope',x=1,y=1,tick=2999},
    {kind='seen',x='a',y=1,tick=2999}}}))
assert(d2==nil and why=='no-clue')
d=search.decide(input({since=2900,post={x=500,y=500}}))
assert(d.kind=='return' and d.point.x==500 and d.gaveUp==true)
d,why=search.decide(input({since=2900,post={x=1010,y=1000}}))
assert(d==nil and why=='given-up')
assert(select(2,search.decide({}))=='bad-input' and select(2,search.decide(input({frame={self={}}})))=='bad-input')
groups=groups+1

-- 4. The walk: a dull creature goes to the very spot; a clever one leads a moving enemy along its
-- heading, by the seconds since (two at most) and 150 units at most. On the spot it is searched,
-- the next clue comes, and with none left the creature looks around.
local moving={kind='seen',id=11,x=1300,y=1000,tick=2985,vx=40,vy=0}
d=search.decide(input({clues={moving},mind={wit='dull',tactics=0}}))
assert(d.point.x==1300 and d.point.y==1000)
d=search.decide(input({clues={moving}}))
assert(d.point.x==1340 and d.point.y==1000)
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=2900,vx=200,vy=0}}}))
assert(d.point.x==1450)
d=search.decide(input({frame={self=self({x=1310})},clues={{kind='seen',id=11,x=1300,y=1000,tick=2950}}}))
assert(d.kind=='look' and d.searched=='seen:11:2950')
d=search.decide(input({clues={seen,hit},searched={['hit:12:2900']=true}}))
assert(d.kind=='search' and d.target==11)
d=search.decide(input({clues={seen},searched={['seen:11:2950']=true}}))
assert(d.kind=='look' and d.key==nil)
groups=groups+1

-- 5. Together: a tactical caster stays 120 units short of a spot a fighter searches too; members
-- searching the same spot spread around it, the first to the side; a dull one walks straight in.
local fighter={id=2,family='fighter',point={x=1300,y=1000}}
d=search.decide(input({clues={seen},group={fighter}}))
assert(d.point.x==1180 and d.point.y==1000)
d=search.decide(input({frame={self=self({x=1250})},clues={seen},group={fighter}}))
assert(d.kind=='look' and d.searched)
d=search.decide(input({clues={seen},group={{id=3,family='mage',point={x=1300,y=1000}}}}))
assert(d.point.x==1300 and d.point.y==1080)
d=search.decide(input({clues={seen},group={{id=3,family='mage',point={x=1300,y=1000}},{id=4,family='mage',point={x=1300,y=1010}}}}))
assert(d.point.x==1300 and d.point.y==920)
d=search.decide(input({clues={seen},group={fighter},family='fighter'}))
assert(d.point.x==1300 and d.point.y==1080)
d=search.decide(input({clues={seen},group={fighter},mind={wit='dull',tactics=0}}))
assert(d.point.x==1300 and d.point.y==1000)
groups=groups+1

-- 6. Detection, when a clue says the enemy is likely invisible on a spot the creature sees: a hit
-- tells anyone, a vanished enemy (or one another member sees there) a tactical creature. The
-- cheapest detection that reaches the spot; at equal levels the buff that lets it see.
local purge={resref='TESTPURG',kind='purge',center='self',radius=450,level=3,speed=3}
local see={resref='TESTSEE',kind='see',level=3,speed=2}
local dust={resref='TESTDUST',kind='purge',center='point',radius=110,range=320,level=2,speed=2}
local seer={resref='TESTTRUE',kind='see',level=6,speed=6}
local vanished={kind='vanished',id=11,x=1200,y=1000,tick=2990,near=true}
d=search.decide(input({clues={vanished},detects={purge,seer}}))
assert(d.kind=='detect' and d.resref=='TESTPURG' and d.self==true and d.level==3 and d.key=='vanished:11:2990')
d=search.decide(input({clues={vanished},detects={purge,see}}))
assert(d.resref=='TESTSEE' and d.self==true)
d=search.decide(input({clues={vanished},detects={purge,see,dust}}))
assert(d.resref=='TESTDUST' and d.point.x==1200 and d.point.y==1000)
d=search.decide(input({clues={{kind='vanished',id=11,x=1400,y=1000,tick=2990,near=true}},detects={dust}}))
assert(d.resref=='TESTDUST' and d.point.x==1320)
d=search.decide(input({clues={{kind='vanished',id=11,x=1440,y=1000,tick=2990,near=true}},detects={dust}}))
assert(d.kind=='search')
d=search.decide(input({clues={vanished},detects={purge},mind={wit='dull',tactics=0}}))
assert(d.kind=='search')
d=search.decide(input({clues={{kind='hit',id=12,x=1200,y=1000,tick=2990,near=true}},detects={purge},mind={wit='dull',tactics=0}}))
assert(d.kind=='detect' and d.resref=='TESTPURG')
d=search.decide(input({clues={{kind='hit',id=12,x=1200,y=1000,tick=2990}},detects={purge}}))
assert(d.kind=='search')
d=search.decide(input({clues={{kind='sighted',id=13,x=1200,y=1000,tick=2995,near=true}},detects={purge}}))
assert(d.kind=='detect')
d=search.decide(input({clues={seen},detects={purge}}))
assert(d.kind=='search')
d=search.decide(input({frame={self=self({seeInvisible=true})},clues={vanished},detects={purge}}))
assert(d.kind=='search')
d=search.decide(input({clues={vanished},detects={purge},detected=2950}))
assert(d.kind=='search')
d=search.decide(input({clues={vanished},detects={purge},detected=2900}))
assert(d.kind=='detect')
-- A rogue's Detect Illusion: a tactical one with the skill, the spot near enough.
d=search.decide(input({clues={vanished},illusion=45,family='fighter'}))
assert(d.kind=='modal' and d.target==11)
d=search.decide(input({clues={vanished},illusion=20,family='fighter'}))
assert(d.kind=='search')
d=search.decide(input({clues={{kind='vanished',id=11,x=1300,y=1000,tick=2990,near=true}},illusion=45,family='fighter'}))
assert(d.kind=='search')
assert(select(1,search.detection(input({detects={{kind='purge',center='point',range=10}}}),vanished))==nil)
groups=groups+1

-- 7. Patience: from the newest clue; when it runs out the creature gives up and goes back to its
-- post, and there it leaves the round to its own life; nothing new since it gave up keeps it
-- there; a newer clue starts a search again.
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-19*15}},post={x=600,y=1000},mind={wit='normal',tactics=0.5}}))
assert(d.kind=='return' and d.point.x==600 and d.gaveUp==true)
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-9*15}},post={x=600,y=1000},mind={wit='dull',tactics=0}}))
assert(d.kind=='return' and d.gaveUp==true)
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-9*15}},post={x=600,y=1000},mind={wit='normal',tactics=0.5}}))
assert(d.kind=='search')
d,why=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-20*15}},post={x=1000,y=1020},
    mind={wit='dull',tactics=0}}))
assert(d==nil and why=='given-up')
-- A clever one searching: its clue forgotten after its 30 seconds, it goes back; a patient one
-- (the lab's scale) keeps the clue as long as its patience.
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-31*15}},post={x=600,y=1000},since=2400}))
assert(d.kind=='return' and d.gaveUp==true)
d=search.decide(input({clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-45*15}},post={x=600,y=1000},
    mind={wit='clever',tactics=1,searchPatience=2}}))
assert(d.kind=='search')
d=search.decide(input({clues={seen},post={x=600,y=1000},gaveUp=2960}))
assert(d.kind=='return' and d.gaveUp==nil)
d=search.decide(input({clues={seen},post={x=600,y=1000},gaveUp=2940}))
assert(d.kind=='search')
d,why=search.decide(input({clues={seen},gaveUp=2960}))
assert(d==nil and why=='given-up')
groups=groups+1

-- 8. A creature that guards searches only near its post; detection it still casts from where it
-- stands. A rooted one looks around where it is.
local far={kind='seen',id=11,x=1300,y=1000,tick=2950}
d=search.decide(input({clues={far},guard=true,post={x=1000,y=1000}}))
assert(d.kind=='look' and d.guard==true)
d=search.decide(input({frame={self=self({x=1100})},clues={far},guard=true,post={x=900,y=1000}}))
assert(d.kind=='return' and d.point.x==900)
d=search.decide(input({clues={{kind='seen',id=11,x=1150,y=1000,tick=2950}},guard=true,post={x=1000,y=1000}}))
assert(d.kind=='search')
d=search.decide(input({clues={{kind='vanished',id=11,x=1300,y=1000,tick=2990,near=true}},guard=true,post={x=1000,y=1000},
    detects={purge}}))
assert(d.kind=='detect')
d=search.decide(input({frame={self=self({rooted=true})},clues={far}}))
assert(d.kind=='look' and d.rooted==true)
d,why=search.decide(input({frame={self=self({rooted=true})},clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-20*15}},
    post={x=500,y=500},mind={wit='dull',tactics=0}}))
assert(d==nil and why=='given-up')
assert(near(search.patience(input({mind={wit='clever',searchPatience=0.5}})),15))
groups=groups+1

-- 9. The group's picture as clues: still seen by another member, vanished on a spot the creature
-- sees, else seen. A boss stands clearly above at least two others. Detections come from what the
-- spells and items do: a buff of sight on the caster, an area that takes invisibility around the
-- caster or at a point; a spell's level ranks it, an item comes after every spell; nothing that is
-- not ready, not usable, used up or aimed at a creature.
assert(search.kindOf(10,false,true)=='sighted' and search.kindOf(10,true,false)=='vanished')
assert(search.kindOf(20,true,true)=='vanished' and search.kindOf(20,false,true)=='seen' and search.kindOf(40,true,true)=='seen')
assert(search.boss(12,{8,10}) and not search.boss(12,{8}) and not search.boss(12,{8,11}) and not search.boss(nil,{1,2}))
local purgeRole={who={area=true},kinds={invisibility=true}}
local trueSeeing={target='self',speed=6,area={radius=450},roles={removal=purgeRole,buff={who={self=true},kinds={seeInvisible=true}}}}
local purgeOnly={target='self',speed=3,area={radius=2000},roles={removal=purgeRole}}
local glitter={target='point',range=20,speed=2,area={radius=110},roles={removal=purgeRole}}
local aimed={target='creature',range=20,speed=1,area={radius=75},roles={removal=purgeRole}}
local bolt={target='creature',speed=1,roles={damage={who={target=true},kinds={}}}}
local opts=search.options({
    {resref='SPWI609',level=6,ready=1,usable=true,spell=trueSeeing},
    {resref='SPPR309',level=3,ready=2,usable=true,spell=purgeOnly},
    {resref='SPWI224',level=2,ready=1,usable=true,spell=glitter},
    {resref='SPPR116',level=1,ready=1,usable=true,spell=aimed},
    {resref='SPWI112',level=1,ready=1,usable=true,spell=bolt},
    {resref='SPWI203',level=2,ready=0,usable=true,spell=trueSeeing},
    {resref='SPWI515',level=5,ready=1,usable=false,spell=purgeOnly}},
    {{resref='TESTEYES',abilities={{effect=trueSeeing,uses=1}}},{resref='TESTWAND',abilities={{effect=glitter,uses=3}}},
        {resref='TESTGONE',abilities={{effect=trueSeeing,uses=0}}},{resref='TESTNONE',abilities={}}})
local byRes={}
for _,o in ipairs(opts) do byRes[o.resref]=o end
assert(#opts==4 and byRes.SPWI609.kind=='see' and byRes.SPWI609.level==6 and byRes.SPWI609.speed==6)
assert(byRes.SPPR309.kind=='purge' and byRes.SPPR309.center=='self' and byRes.SPPR309.radius==2000)
assert(byRes.SPWI224.center=='point' and byRes.SPWI224.range==320 and byRes.SPWI224.radius==110 and byRes.SPWI224.level==2)
assert(byRes.TESTEYES.kind=='see' and byRes.TESTEYES.item==true and byRes.TESTEYES.level==search.itemLevel)
-- With them, an enemy vanished 300 away: Glitterdust at its spot, the cheapest that reaches; a
-- potion of sight only once no spell is left.
d=search.decide(input({clues={{kind='vanished',id=11,x=1300,y=1000,tick=2990,near=true}},detects=opts}))
assert(d.kind=='detect' and d.resref=='SPWI224' and d.point.x==1300 and d.item==nil)
d=search.decide(input({clues={{kind='vanished',id=11,x=1300,y=1000,tick=2990,near=true}},detects={byRes.TESTEYES}}))
assert(d.kind=='detect' and d.resref=='TESTEYES' and d.item==true and d.self==true)
groups=groups+1

-- 10. The jump: what moves the caster to a point counts (a phase spider's teleport, astral travel,
-- Dimension Door), nothing aimed at a creature, moving others, not ready or not usable. A long walk
-- goes by an innate teleport for anyone, a longer one by a memorized spell for a tactical creature
-- only; not again within the gap; the innate first; as far toward the spot as the range reaches.
local blinkSpell={target='point',range=200,speed=0,roles={move={who={self=true},kinds={teleport=true}}}}
local doorSpell={target='point',range=1000,speed=1,level=4,roles={move={who={self=true},kinds={teleport=true}},
    buff={who={self=true},kinds={}}}}
local shortBlink={target='point',range=20,speed=0,roles={move={who={self=true},kinds={teleport=true}}}}
local pushSpell={target='creature',range=20,speed=1,roles={move={who={target=true},kinds={teleport=true}}}}
local fieldSpell={target='point',range=20,speed=2,area={radius=200},roles={move={who={area=true},kinds={teleport=true}}}}
local jumps=search.teleports({
    {resref='SPIN147',list='innate',level=1,ready=1,usable=true,spell=blinkSpell},
    {resref='SPWI402',list='mage',level=4,ready=2,usable=true,spell=doorSpell},
    {resref='TESTPUSH',list='mage',level=3,ready=1,usable=true,spell=pushSpell},
    {resref='TESTFLD',list='mage',level=5,ready=1,usable=true,spell=fieldSpell},
    {resref='SPIN186',list='innate',level=1,ready=0,usable=true,spell=blinkSpell},
    {resref='TESTMUTE',list='mage',level=4,ready=1,usable=false,spell=doorSpell},
    {resref='TESTBOLT',list='mage',level=1,ready=1,usable=true,spell=bolt}})
local jumpBy={}
for _,o in ipairs(jumps) do jumpBy[o.resref]=o end
assert(#jumps==2 and jumpBy.SPIN147.innate==true and jumpBy.SPIN147.range==3200 and jumpBy.SPIN147.speed==0)
assert(jumpBy.SPWI402.innate==nil and jumpBy.SPWI402.level==4 and jumpBy.SPWI402.range==16000 and jumpBy.SPWI402.speed==1)
local blink,door=jumpBy.SPIN147,jumpBy.SPWI402
local farSeen={kind='seen',id=11,x=1700,y=1000,tick=2950}
-- An innate teleport for a walk of 200 or more, by a dull creature too; the walk below that.
d=search.decide(input({clues={farSeen},teleports={blink},mind={wit='dull',tactics=0}}))
assert(d.kind=='teleport' and d.resref=='SPIN147' and d.innate==true and d.point.x==1700 and d.point.y==1000 and
    d.clue=='seen' and d.target==11 and d.key=='seen:11:2950')
d=search.decide(input({clues={{kind='seen',id=11,x=1150,y=1000,tick=2950}},teleports={blink}}))
assert(d.kind=='search')
-- A memorized spell: 600 or more, and only for a tactical creature.
d=search.decide(input({clues={farSeen},teleports={door}}))
assert(d.kind=='teleport' and d.resref=='SPWI402' and d.innate==nil and d.level==4 and d.speed==1)
d=search.decide(input({clues={{kind='seen',id=11,x=1500,y=1000,tick=2950}},teleports={door}}))
assert(d.kind=='search')
d=search.decide(input({clues={farSeen},teleports={door},mind={wit='normal',tactics=0.5},tactical=false}))
assert(d.kind=='search')
-- The innate one first; none again within its gap (18 seconds, for a memorized spell too).
d=search.decide(input({clues={farSeen},teleports={door,blink}}))
assert(d.resref=='SPIN147')
d=search.decide(input({clues={farSeen},teleports={blink},jumped=3000-17*15}))
assert(d.kind=='search')
d=search.decide(input({clues={farSeen},teleports={blink},jumped=3000-18*15}))
assert(d.kind=='teleport')
d=search.decide(input({clues={farSeen},teleports={door,blink},jumped=3000-17*15}))
assert(d.kind=='search')
d=search.decide(input({clues={farSeen},teleports={door,blink},jumped=3000-18*15}))
assert(d.resref=='SPIN147')
-- Beyond its range: as far toward the spot as it reaches.
local short=search.teleports({{resref='TESTSHRT',list='innate',level=1,ready=1,usable=true,spell=shortBlink}})[1]
d=search.decide(input({clues={farSeen},teleports={short}}))
assert(d.kind=='teleport' and d.point.x==1320 and d.point.y==1000 and d.toward.x==1700 and d.toward.y==1000)
-- Its spot led and spread like a walk's; a guard, a rooted creature and a searched spot do not jump.
d=search.decide(input({clues={{kind='seen',id=11,x=1700,y=1000,tick=2985,vx=40,vy=0}},teleports={blink}}))
assert(d.kind=='teleport' and d.point.x==1740)
d=search.decide(input({clues={farSeen},teleports={blink},guard=true,post={x=1000,y=1000}}))
assert(d.kind=='look' and d.guard==true)
d=search.decide(input({frame={self=self({rooted=true})},clues={farSeen},teleports={blink}}))
assert(d.kind=='look' and d.rooted==true)
d=search.decide(input({frame={self=self({x=1690})},clues={farSeen},teleports={blink}}))
assert(d.kind=='look' and d.searched=='seen:11:2950')
-- Detection still comes first where a clue says the enemy is likely invisible in sight.
d=search.decide(input({clues={{kind='hit',id=12,x=1700,y=1000,tick=2990,near=true}},detects={purge},teleports={blink}}))
assert(d.kind=='search' or d.kind=='teleport')
d=search.decide(input({clues={{kind='hit',id=12,x=1300,y=1000,tick=2990,near=true}},detects={purge},teleports={blink}}))
assert(d.kind=='detect')
assert(select(1,search.jump(input({teleports={{resref='X',range=0,innate=true}}}),{x=2000,y=1000},1000,true))==nil)
groups=groups+1

-- 11. Foes out of play (Christopher, 2026-10-29): one the group charmed, one in a maze. Never a clue;
-- awaited by wit once nothing else is left to search: a clever creature guards the nearest one's spot
-- (240 for a caster, 96 for a fighter, on its own side, turned away from the spots other members make
-- for) and looks out once there; a normal one waits at its post, a dull one stands where it is; a
-- designer's orders can say which; a rooted one looks out where it is; one that guards its post guards
-- only a foe near it. Giving up a search hands over to the wait, never to the creature's own life.
local mazed={id=21,kind='maze',x=1300,y=1000,since=2900,lastTick=2995}
d=search.decide(input({away={mazed}}))
assert(d.kind=='guard' and d.point.x==1060 and d.point.y==1000 and d.await==21 and d.target==21 and d.away=='maze' and
    d.how=='guard' and d.gaveUp==nil)
d=search.decide(input({away={mazed},family='fighter'}))
assert(d.kind=='guard' and d.point.x==1204 and d.point.y==1000)
-- Another member makes for that place: the next one on the ring, one way, then the other.
d=search.decide(input({away={mazed},group={{id=2,family='mage',point={x=1060,y=1000}}}}))
assert(d.kind=='guard' and d.point.x==1130 and d.point.y==873)
d=search.decide(input({away={mazed},group={{id=2,family='mage',point={x=1060,y=1000}},{id=3,family='mage',point={x=1130,y=873}}}}))
assert(d.point.x==1130 and d.point.y==1127)
local ring={}
for i=0,7 do
    local t=math.ceil(i/2)*(i%2==1 and 1 or -1)*search.guardTurn
    ring[#ring+1]={id=10+i,family='mage',point={x=1300-math.cos(t)*240,y=1000-math.sin(t)*180}}
end
d=search.decide(input({away={mazed},group=ring}))
assert(d.point.x==1060 and d.point.y==1000)
-- At its place it looks out there, keeping the place.
d=search.decide(input({frame={self=self({x=1060})},away={mazed}}))
assert(d.kind=='look' and d.point.x==1060 and d.await==21 and d.how=='guard')
-- The nearer foe first: a charmed one standing by.
d=search.decide(input({away={mazed,{id=22,kind='charm',x=900,y=1000,since=2990,lastTick=3000}}}))
assert(d.kind=='guard' and d.await==22 and d.away=='charm' and d.point.x==1140 and d.point.y==1000)
-- A normal one waits at its post, a dull one stands; without a post the normal one stands as well.
d=search.decide(input({away={mazed},post={x=600,y=1000},mind={wit='normal',tactics=0.5}}))
assert(d.kind=='return' and d.point.x==600 and d.how=='post' and d.await==21)
d=search.decide(input({frame={self=self({x=620})},away={mazed},post={x=600,y=1000},mind={wit='normal',tactics=0.5}}))
assert(d.kind=='look' and d.how=='post' and d.point==nil)
d=search.decide(input({away={mazed},mind={wit='normal',tactics=0.5}}))
assert(d.kind=='look' and d.how=='post')
d=search.decide(input({away={mazed},post={x=600,y=1000},mind={wit='dull',tactics=0}}))
assert(d.kind=='look' and d.how=='stand' and d.await==21)
-- Orders over wit; an unknown order leaves it to wit.
d=search.decide(input({away={mazed},await='stand'}))
assert(d.kind=='look' and d.how=='stand')
d=search.decide(input({away={mazed},await='guard',mind={wit='dull',tactics=0}}))
assert(d.kind=='guard' and d.how=='guard')
d=search.decide(input({away={mazed},await='nope'}))
assert(d.how=='guard')
-- Rooted: looks out where it is. A creature that guards its post guards a foe near it only.
d=search.decide(input({frame={self=self({rooted=true})},away={mazed}}))
assert(d.kind=='look' and d.how=='guard' and d.point==nil)
d=search.decide(input({away={mazed},guard=true,post={x=1000,y=1000}}))
assert(d.kind=='look' and d.how=='post')
d=search.decide(input({away={{id=21,kind='maze',x=1200,y=1000}},guard=true,post={x=1000,y=1000},family='fighter'}))
assert(d.kind=='guard' and d.point.x==1104)
-- A clue of the foe out of play is none; another foe's clue is still searched; giving up or running
-- out of patience hands over to the wait (gaveUp marked once).
d=search.decide(input({away={mazed},clues={{kind='seen',id=21,x=1300,y=1000,tick=2990}}}))
assert(d.kind=='guard' and d.gaveUp==nil)
d=search.decide(input({away={mazed},clues={{kind='seen',id=21,x=1300,y=1000,tick=2990}},since=2900}))
assert(d.kind=='guard' and d.gaveUp==true)
d=search.decide(input({away={mazed},clues={seen}}))
assert(d.kind=='search' and d.target==11)
d=search.decide(input({away={mazed},clues={{kind='seen',id=11,x=1300,y=1000,tick=3000-31*15}},since=2400}))
assert(d.kind=='guard' and d.gaveUp==true)
d=search.decide(input({away={mazed},clues={seen},gaveUp=2960,post={x=600,y=1000}}))
assert(d.kind=='guard' and d.gaveUp==nil)
-- Only charmed and mazed foes count, with a place and an id.
d,why=search.decide(input({away={{id=23,kind='prison',x=1,y=1},{id=24,kind='maze',x='a',y=1},{kind='maze',x=1,y=1}}}))
assert(d==nil and why=='no-clue')
groups=groups+1

-- 12. What readiness takes from here (combat-intent/choice.lua): the nearest foe out of play and how
-- the creature awaits it, and how long a maze is still likely to last (IESDP opcode 213: dice of
-- rounds by the foe's intelligence; the group knows the spell, not what its dice rolled).
local charmed={id=32,kind='charm',x=900,y=1000}
assert(search.nearestAway(input({away={mazed,charmed}})).id==32 and search.nearestAway(input({away={}}))==nil)
assert(search.how(input(),mazed)=='guard' and search.how(input({mind={wit='dull',tactics=0}}),mazed)=='stand')
assert(search.how(input({await='post'}),mazed)=='post' and search.how(input({mind={}}),mazed)=='post')
assert(search.how(input({guard=true,post={x=1000,y=1000}}),mazed)=='post')
assert(search.how(input({guard=true,post={x=1200,y=1000}}),mazed)=='guard')
-- 4d4 rounds (intelligence 9 to 11): ten on average, a minute; after 96 seconds none are left. One
-- die: 2.5 rounds; six seconds in, 12 seconds more on average (12, 18 or 24 in all).
assert(near(search.mazeLeft(4,4,0),60) and search.mazeLeft(4,4,96)==0 and search.mazeLeft(4,4,200)==0)
assert(near(search.mazeLeft(1,4,0),15) and near(search.mazeLeft(1,4,6),12))
-- A maze that has lasted a while is likely nearer its end, never over before its last possible
-- round: 90 seconds into 4d4 only the longest is left, six seconds more.
assert(search.mazeLeft(4,4,30)<search.mazeLeft(4,4,0) and near(search.mazeLeft(4,4,90),6))
-- A die of one side is certain (the SR lab's INTMOD gives intelligence 0 to 2 7200d1 rounds, twelve
-- hours); beyond mazeOutcomes, the mean. Dice that make no duration give none.
assert(search.mazeLeft(7200,1,100)==43100 and near(search.mazeLeft(30,4,0),30*2.5*6))
assert(search.mazeLeft(3,1,0)==18 and search.mazeLeft(3,1,12)==6 and search.mazeLeft(3,1,20)==0)
assert(search.mazeLeft(0,4,0)==nil and search.mazeLeft(4,0,0)==nil and search.mazeLeft('a',4,0)==nil)
assert(search.mazeLeft(2.5,4,0)==nil and near(search.mazeLeft(4,4,nil),60))
groups=groups+1

-- 13. Set pieces (Christopher, 2026-11-10: SCS's ambushes are taken over as they are for now). A
-- creature its script calls to a party member it does not perceive ('called', where that member
-- stands, new with every call) walks there, a dull one too. What the group perceived comes first.
-- A call never runs out: the newest clue is the call. A guard leaves its post for it; with a newer
-- call than its giving up it searches again. The walk is the engine's own: two members spread
-- around the spot.
do
    local called={kind='called',id=21,x=2200,y=1400,tick=3000}
    local dull={wit='dull',tactics=0}
    d=search.decide(input({clues={called},mind=dull}))
    assert(d.kind=='search' and d.clue=='called' and d.target==21 and d.point.x==2200 and d.point.y==1400)
    assert(d.key=='called:21:3000')
    d=search.decide(input({clues={called,seen},mind=dull}))
    assert(d.clue=='seen' and d.target==11)
    d=search.decide(input({clues={called,seen},mind=dull,searched={['seen:11:2950']=true}}))
    assert(d.clue=='called')
    -- The old sighting is long forgotten and the dull one's patience over: the call still stands.
    d=search.decide(input({clues={called,{kind='seen',id=11,x=1300,y=1000,tick=3000-60*15}},mind=dull,since=1000,
        post={x=600,y=1000}}))
    assert(d.kind=='search' and d.clue=='called')
    d=search.decide(input({clues={called},guard=true,post={x=1000,y=1000}}))
    assert(d.kind=='search' and d.clue=='called' and d.point.x==2200)
    d=search.decide(input({clues={called},gaveUp=2990,post={x=600,y=1000}}))
    assert(d.kind=='search' and d.clue=='called')
    d=search.decide(input({clues={called},gaveUp=3000,post={x=600,y=1000}}))
    assert(d.kind=='return')
    -- Next to the party member and still not seeing it: the spot is looked at, and the next call is new.
    d=search.decide(input({clues={{kind='called',id=21,x=1020,y=1000,tick=3000}}}))
    assert(d.kind=='look' and d.searched=='called:21:3000')
    -- A second member that searches the same spot: the creature keeps off to the side.
    d=search.decide(input({clues={called},group={{id=2,family='fighter',point={x=2200,y=1400}}},family='fighter'}))
    assert(d.kind=='search' and (d.point.x~=2200 or d.point.y~=1400))
    assert(search.PRIORITY.called==0 and search.PRIORITY.seen>search.PRIORITY.called)
end
groups=groups+1

return groups
