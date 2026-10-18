-- Which casts the director may redirect and when another enemy is as legal a target as the
-- original, on synthetic spells classified by combat-intent/spells.lua. No game data.
local targeting=require('combat-intent.targeting')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spell(resref,effects,ability,record,pro)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=3,abilities={a},casting={}}
    for k,v in pairs(record or {}) do r[k]=v end
    local projectiles={[2]=pro or {kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' then return projectiles[key] end end,{level=10})
end
local bolt=spell('TESTBOLT',{fx(12,{p2=4*65536,dice=6,sides=6})},nil,{school=8,secondary=10})
local hold=spell('TESTHOLD',{fx(175,{p2=3,p1=2,duration=30})},nil,{school=5})
local missile=spell('TESTMM',{fx(12,{p1=1,p2=64*65536,dice=1,sides=4})},{projectile=69})
local strange=spell('TESTODD',{fx(12,{p1=5})},{projectile=66})
local ball=spell('TESTBALL',{fx(12,{dice=6,sides=6})},{target=4},nil,
    {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=256,coneWidth=0})
local screen=spell('TESTSCRN',{fx(12,{dice=6,sides=6})},nil,nil,
    {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=64,trigger=30,radius=256,coneWidth=0})
local blast=spell('TESTBLST',{fx(12,{dice=6,sides=6})},nil,nil,
    {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=256,coneWidth=0})
local breach=spell('TESTBRCH',{fx(12,{p1=2}),fx(221,{p2=1,p1=9})})

-- 1. State bits, health and distance; a signed state value still shows confusion.
assert(targeting.has(0x8010202D,0x80000000) and targeting.has(-2147483648,targeting.STATE.confused))
assert(not targeting.has(0x10,0x20) and not targeting.has(nil,1))
assert(targeting.disabled({state=0x20}) and targeting.disabled({state=0,held=1}) and not targeting.disabled({state=0x10}))
assert(not targeting.alive({state=0x800}) and not targeting.alive({state=0,hp=0}) and targeting.alive({state=0,hp=3}))
assert(targeting.casting({action=31}) and targeting.casting({action=191}) and not targeting.casting({action=3}))
assert(targeting.health({hp=5,maxHp=20})==0.25 and targeting.health({hp=5})==1)
assert(targeting.distance({x=0,y=0},{x=30,y=30})==50 and targeting.distance({x=0},{x=1,y=1})==math.huge)
groups=groups+1

-- 2. Redirectable casts: creature-targeted damage or disable, no friendly fire, a known or
-- single-target built-in projectile, not tied to its target by another role.
assert(targeting.kind(bolt)=='damage' and targeting.kind(hold)=='disable' and targeting.kind(missile)=='damage')
assert(targeting.kind(screen)=='damage')
local function why(s) return select(2,targeting.kind(s)) end
assert(why(strange)=='unknown-projectile' and why(ball)=='not-creature-target' and why(blast)=='friendly-fire')
assert(why(breach)=='role-removal' and why(nil)=='unclassified')
local part=spell('TESTPART',{fx(146,{res='GONE'}),fx(12,{p1=1})});assert(part.partial and why(part)=='partial')
assert(targeting.role(ball)=='damage' and targeting.role(hold)=='disable' and targeting.role(breach)=='damage')
groups=groups+1

-- 3. A legal replacement: alive, no sanctuary, seen, in reach, no more magic resistance than
-- the original, the same filtered IDS values, and no protection that stops this spell.
local caster={id=1,x=0,y=0}
local original={id=2,x=100,y=0,state=0,hp=10,maxHp=10,mr=0,ids={general=1,race=1},protections={}}
local function enemy(fields)
    local e={id=3,x=200,y=0,state=0,hp=10,maxHp=10,mr=0,ids={general=1,race=2},protections={}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function legal(e,s,c,o) local ok,r=targeting.legal(c or caster,e,s or bolt,o or original);return ok and 'ok' or r end
assert(legal(enemy())=='ok' and legal(enemy({state=0x800}))=='dead' and legal(enemy({sanctuary=1}))=='sanctuary')
assert(legal(enemy({state=0x10}))=='invisible' and legal(enemy({state=0x400000}),bolt,{x=0,y=0,seeInvisible=true})=='ok')
-- Reach: the spell's 30 cells (480 units), or farther when the original already was.
assert(legal(enemy({x=480}))=='ok' and legal(enemy({x=481}))=='out-of-range')
assert(legal(enemy({x=0,y=361}))=='out-of-range' and legal(enemy({x=600}),bolt,caster,enemy({id=2,x=600}))=='ok')
local lost=enemy();lost.x=nil
assert(legal(lost)=='no-position')
assert(legal(enemy({mr=10}))=='magic-resistance' and legal(enemy({mr=10}),bolt,caster,enemy({id=2,x=100,mr=50}))=='ok')
-- The hold filters on GENERAL (IDS 3): the same value passes, another fails.
assert(legal(enemy({ids={general=1}}),hold)=='ok' and legal(enemy({ids={general=4}}),hold)=='filter')
groups=groups+1

-- 4. Protections by opcode, projectile, level, school, secondary type and resource.
local function shielded(p) return legal(enemy({protections={p}}),hold) end
assert(shielded({opcode=101,p2=175})=='protected' and shielded({opcode=101,p2=12})=='ok')
assert(shielded({opcode=102,p1=3})=='protected' and shielded({opcode=102,p1=4})=='ok')
assert(shielded({opcode=200,p1=10,p2=3})=='protected' and shielded({opcode=259,p1=8,p2=2})=='ok')
assert(shielded({opcode=204,p2=5})=='protected' and shielded({opcode=204,p2=8})=='ok')
assert(shielded({opcode=206,res='TESTHOLD'})=='protected' and shielded({opcode=206,res='OTHER'})=='ok')
assert(shielded({opcode=83,p2=1})=='protected' and shielded({opcode=197,p2=2})=='protected')
assert(legal(enemy({protections={{opcode=205,p2=10}}}),bolt)=='protected')
assert(legal(enemy({protections={{opcode=205,p2=10}}}),hold)=='ok')
-- Unknown protections: not a replacement.
local unread=enemy();unread.protections=nil
assert(legal(unread)=='protected')
groups=groups+1

return groups
