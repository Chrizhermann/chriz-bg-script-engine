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
-- The innate one first; none again within its gap (6 seconds, 18 for a memorized spell).
d=search.decide(input({clues={farSeen},teleports={door,blink}}))
assert(d.resref=='SPIN147')
d=search.decide(input({clues={farSeen},teleports={blink},jumped=3000-5*15}))
assert(d.kind=='search')
d=search.decide(input({clues={farSeen},teleports={blink},jumped=3000-6*15}))
assert(d.kind=='teleport')
d=search.decide(input({clues={farSeen},teleports={door},jumped=3000-17*15}))
assert(d.kind=='search')
d=search.decide(input({clues={farSeen},teleports={door,blink},jumped=3000-10*15}))
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

return groups
