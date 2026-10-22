-- Which casts the director may redirect and when another enemy is as legal a target as the
-- original, on synthetic spells classified by combat-intent/spells.lua. No game data.
local targeting=require('combat-intent.targeting')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spell(resref,effects,ability,record,pro,more)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=3,abilities={a},casting={}}
    for k,v in pairs(record or {}) do r[k]=v end
    local projectiles={[2]=pro or {kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}}
    return spells.classify(r,1,function(kind,key)
        if kind=='PRO' then return projectiles[key] or (more and more['PRO:'..tostring(key)]) end
        return more and more[kind..':'..tostring(key)]
    end,{level=10})
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
-- A fire bolt that also kills trolls (an SCS-style extra for one race).
local trollBolt=spell('TESTTRBL',{fx(12,{p2=8*65536,dice=6,sides=6}),fx(177,{p1=129,p2=4,res='TESTTRDE'})},nil,nil,nil,
    {['EFF:TESTTRDE']={kind='EFF',resref='TESTTRDE',effect=fx(13,{})}})

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
-- What a spell does to a creature none of its conditions single out decides its kind: the
-- troll extra does not make the bolt a disable.
assert(trollBolt.roles.disable.kinds.death and targeting.kind(trollBolt)=='damage' and targeting.role(trollBolt)=='damage')
groups=groups+1

-- 3. A legal replacement: alive, no sanctuary, seen, in reach, no more magic resistance than
-- the original, no less of what the spell does by its creature conditions, and no protection
-- that stops this spell.
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
-- A hold of animals (GENERAL 2) takes only animals: aimed at an animal it may move to another
-- animal, not to a humanoid; aimed at a humanoid, where it does nothing, it may move to an
-- animal, not to an undead, where it would do nothing either. An unknown type is no
-- replacement.
local animal={id=2,x=100,y=0,state=0,hp=10,maxHp=10,mr=0,ids={general=2,race=1},protections={}}
assert(legal(enemy({ids={general=2}}),hold,caster,animal)=='ok' and legal(enemy({ids={general=1}}),hold,caster,animal)=='filter')
assert(legal(enemy({ids={general=2}}),hold)=='ok' and legal(enemy({ids={general=4}}),hold)=='filter')
assert(legal(enemy({ids={}}),hold)=='unknown-filter')
-- The troll extra: an elf takes the bolt as the human original does, a troll takes more; aimed
-- at a troll, the bolt does not leave trolls.
local troll={id=2,x=100,y=0,state=0,hp=10,maxHp=10,mr=0,ids={general=1,race=129},protections={}}
assert(legal(enemy(),trollBolt)=='ok' and legal(enemy({ids={general=1,race=129}}),trollBolt)=='ok')
assert(legal(enemy(),trollBolt,caster,troll)=='filter' and legal(enemy({ids={general=1,race=129}}),trollBolt,caster,troll)=='ok')
-- A spell's own immunity check, by the engine's marks: a free original's hold does not move to
-- an immune creature, an immune original's moves to a free one; without marks it does not
-- move.
local srHold=spell('TESTSRHL',{fx(324,{res='TESTSRHL',p2=110,p1=29,duration=1}),fx(175,{p2=3,p1=1,duration=30})})
local freeAction=spells.conditionKey({row=110,value=29})
local function marked(v,fields) local e=enemy(fields);e.splprot={[freeAction]=v};return e end
local held=marked(false,{id=2,x=100})
assert(legal(marked(false),srHold,caster,held)=='ok' and legal(marked(true),srHold,caster,held)=='filter')
assert(legal(marked(false),srHold,caster,marked(true,{id=2,x=100}))=='ok')
assert(legal(enemy(),srHold,caster,held)=='unknown-filter')
groups=groups+1

-- 4. Protections by opcode, projectile, level, school, secondary type and resource, against a
-- hold of any creature. Levels are the power of what the spell delivers (IESDP): globes and 199
-- name it in parameter 1, turnings, deflections and traps in parameter 2. Power 0 passes them all;
-- effects that pass turnings (resistance bit 2) pass all but globes.
local anyHold=spell('TESTHOLD',{fx(175,{duration=30,power=3})},nil,{school=5})
local function shielded(p) return legal(enemy({protections={p}}),anyHold) end
assert(shielded({opcode=101,p2=175})=='protected' and shielded({opcode=101,p2=12})=='ok')
assert(shielded({opcode=102,p1=3})=='protected' and shielded({opcode=102,p1=4})=='ok')
assert(shielded({opcode=200,p1=10,p2=3})=='protected' and shielded({opcode=259,p1=8,p2=2})=='ok')
assert(shielded({opcode=199,p1=3})=='protected' and shielded({opcode=199,p1=0,p2=3})=='ok')
assert(anyHold.power==3 and anyHold.unbounced==false)
local quiet=spell('TESTQHLD',{fx(175,{duration=30,power=0})})
assert(quiet.power==0 and not targeting.protected(enemy({protections={{opcode=200,p1=10,p2=3},{opcode=102,p1=3}}}),quiet))
local passing=spell('TESTPHLD',{fx(175,{duration=30,power=3,resist=5})})
assert(passing.unbounced==true and not targeting.protected(enemy({protections={{opcode=201,p1=10,p2=3}}}),passing))
assert(targeting.protected(enemy({protections={{opcode=102,p1=3}}}),passing))
-- A spell another casts at the target meets its protections again by its own power: Secret Word's
-- sub-spells (power 0) pass a turning, a sub-spell of power 4 behind a cast of power 0 (Chromatic
-- Orb's kind) does not; one the spell casts on its caster does not count.
local subs={['SPL:TESTSUB0']={kind='SPL',resref='TESTSUB0',name=0,flags=0,spellType=1,exclusion=0,school=0,
    secondary=1,level=4,casting={},abilities={{form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,
    speed=1,projectile=1,effects={fx(230,{p1=9,p2=1,power=0})}}}},
    ['SPL:TESTSUB4']={kind='SPL',resref='TESTSUB4',name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=10,
    level=4,casting={},abilities={{form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=1,
    projectile=1,effects={fx(12,{p1=10,power=4})}}}}}
local turnedAt4={protections={{opcode=200,p1=10,p2=4}}}
local secret=spell('TESTWORD',{fx(146,{p2=1,res='TESTSUB0',power=0})},nil,{level=4},nil,subs)
local orb=spell('TESTORB',{fx(146,{p2=1,res='TESTSUB4',power=0})},nil,{level=4},nil,subs)
local selfish=spell('TESTSELF',{fx(12,{p1=10,power=0}),fx(146,{target=1,p2=1,res='TESTSUB4',power=0})},nil,{level=4},nil,subs)
assert(not targeting.protected(enemy(turnedAt4),secret) and targeting.protected(enemy(turnedAt4),orb))
assert(not targeting.protected(enemy(turnedAt4),selfish))
assert(shielded({opcode=204,p2=5})=='protected' and shielded({opcode=204,p2=8})=='ok')
assert(shielded({opcode=206,res='TESTHOLD'})=='protected' and shielded({opcode=206,res='OTHER'})=='ok')
-- An explosion (an area projectile) delivers past turnings, deflections and traps, not past
-- globes or protections by school (IESDP); so does a sub-spell through its own explosion.
local burst=spell('TESTBRST',{fx(175,{duration=30,power=3})},nil,{school=5},
    {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=256,coneWidth=0})
assert(burst.explodes==true and anyHold.explodes==false)
for _,p in ipairs({{opcode=199,p1=3},{opcode=200,p1=10,p2=3},{opcode=201,p1=10,p2=3},{opcode=259,p1=8,p2=3}}) do
    assert(not targeting.protected(enemy({protections={p}}),burst) and targeting.protected(enemy({protections={p}}),anyHold))
end
assert(targeting.protected(enemy({protections={{opcode=102,p1=3}}}),burst))
assert(targeting.protected(enemy({protections={{opcode=204,p2=5}}}),burst))
subs['PRO:7']={kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=0,trigger=30,radius=128,coneWidth=0}
subs['SPL:TESTSUB7']={kind='SPL',resref='TESTSUB7',name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=10,
    level=4,casting={},abilities={{form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=1,
    projectile=7,effects={fx(12,{p1=10,power=4})}}}}
local storm=spell('TESTSTRM',{fx(146,{p2=1,res='TESTSUB7',power=0})},nil,{level=4},nil,subs)
assert(storm.delivered[1].explodes==true and storm.delivered[1].hostile==true and orb.delivered[1].explodes==false)
assert(not targeting.protected(enemy(turnedAt4),storm) and targeting.protected(enemy({protections={{opcode=102,p1=4}}}),storm))
-- From the creature itself a beneficial spell passes its own globe, turnings and protections by
-- school, a hostile one meets its own globe; protection from the spell or its opcode stops it
-- from anyone (IESDP).
local kind=spell('TESTKIND',{fx(17,{p1=10,power=3})},nil,{flags=0,school=5})
assert(kind.hostile==false and anyHold.hostile==true)
local own={protections={{opcode=102,p1=3},{opcode=200,p1=10,p2=3},{opcode=204,p2=5}}}
assert(not targeting.protected(own,kind,true) and targeting.protected(own,kind))
assert(targeting.protected({protections={{opcode=102,p1=3}}},anyHold,true))
assert(not targeting.protected({protections={{opcode=200,p1=10,p2=3},{opcode=204,p2=5},{opcode=207,res='TESTHOLD'}}},anyHold,true))
assert(targeting.protected({protections={{opcode=207,res='TESTHOLD'}}},anyHold))
assert(targeting.protected({protections={{opcode=206,res='TESTKIND'}}},kind,true))
assert(targeting.protected({protections={{opcode=101,p2=17}}},kind,true))
-- Projectile immunities (83) and bounces (197) name a PROJECTL.IDS entry, one less than the
-- spell's projectile field; the entry of the same number is the neighbouring projectile. The
-- sub-spell a storm's explosions cast at each creature has none (field 1): the arrows of
-- Protection from Missiles (entries 1 and 3) do not stop it, an immunity to the storm's own
-- projectile does (lab batch H6).
assert(shielded({opcode=83,p2=1})=='protected' and shielded({opcode=197,p2=1})=='protected')
assert(shielded({opcode=83,p2=2})=='ok' and shielded({opcode=197,p2=2})=='ok')
local ice=spell('TESTICE',{fx(146,{p2=1,res='TESTSUB4',power=4})},{target=4,projectile=7},{level=4},nil,subs)
assert(ice.explodes==true and ice.delivered[1].projectile==1)
assert(not targeting.protected(enemy({protections={{opcode=83,p2=1},{opcode=83,p2=3}}}),ice))
assert(targeting.protected(enemy({protections={{opcode=83,p2=6}}}),ice))
assert(not targeting.protected(enemy({protections={{opcode=83,p2=7}}}),ice))
assert(legal(enemy({protections={{opcode=205,p2=10}}}),bolt)=='protected')
assert(legal(enemy({protections={{opcode=205,p2=10}}}),anyHold)=='ok')
-- Unknown protections: not a replacement.
local unread=enemy();unread.protections=nil
assert(legal(unread)=='protected')
groups=groups+1

-- 5. How many casts in a row protections stop (a storm's explosions, each casting its sub-spell of
-- power 4 at the creature): turnings, deflections and traps that count down stop as many as their
-- levels last, the last one even with fewer levels left (lab batch H7: Minor Spell Deflection's 6
-- levels stopped two, Spell Deflection's 9 and Greater Spell Deflection's 12 three); several of
-- them one after another; anything else for as long as it lasts; unknown protections everything.
local function stops(protections,s) return targeting.stopped(enemy({protections=protections}),s or ice) end
assert(stops({})==0 and stops({{opcode=201,p1=9,p2=5}})==0)
assert(stops({{opcode=201,p1=6,p2=4}})==2 and stops({{opcode=201,p1=9,p2=4}})==3 and stops({{opcode=201,p1=12,p2=4}})==3)
assert(stops({{opcode=201,p1=4,p2=4}})==1 and stops({{opcode=201,p1=1,p2=4}})==1)
assert(stops({{opcode=200,p1=10,p2=4},{opcode=201,p1=9,p2=4}})==6 and stops({{opcode=259,p1=8,p2=4}})==2)
-- A deflection names each power it covers in a row of its own: only the row of this power counts.
local deflection={}
for power=1,7 do deflection[#deflection+1]={opcode=201,p1=9,p2=power} end
assert(stops(deflection)==3)
assert(stops({{opcode=201,p1=9,p2=4},{opcode=102,p1=4}})==math.huge and stops({{opcode=102,p1=4}})==math.huge)
assert(stops({{opcode=83,p2=6}})==math.huge and stops({{opcode=199,p1=4}})==math.huge)
-- Levels that cannot be read count as lasting.
assert(stops({{opcode=201,p2=4}})==math.huge and stops({{opcode=201,p1=0,p2=4}})==math.huge)
assert(targeting.stopped(unread,ice)==math.huge)
-- A turning stops a cast at the creature (power 3) as often as its levels last.
assert(targeting.stopped(enemy({protections={{opcode=200,p1=10,p2=3}}}),anyHold)==4)
-- Whether a protection stops a cast at all is whether it stops at least one.
for _,set in ipairs({{},{{opcode=201,p1=9,p2=5}},{{opcode=201,p1=1,p2=4}},{{opcode=102,p1=4}}}) do
    assert(targeting.protected(enemy({protections=set}),ice)==(stops(set)>0))
end
groups=groups+1

return groups
