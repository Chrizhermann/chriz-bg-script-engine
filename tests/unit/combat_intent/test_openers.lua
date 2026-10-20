-- The engine's openers (combat-intent/openers.lua) and what the choice does around them
-- (combat-intent/choice.lua, defence.lua): Time Stop and Improved Alacrity as SCS casts them,
-- the caster's own Time Stop, slow spells under Improved Alacrity and the power words' hit
-- point limits. Synthetic spells classified by combat-intent/spells.lua; no game data.
local openers=require('combat-intent.openers')
local choice=require('combat-intent.choice')
local defence=require('combat-intent.defence')
local threat=require('combat-intent.threat')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=1,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local SINGLE={kind='PRO',resref='SINGLE',type=2,speed=20,flags=0,extFlags=0}
local function spell(resref,level,effects,ability)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' and key==2 then return SINGLE end end,{level=10})
end
local FIRE=8*65536
local stop=spell('TESTSTOP',9,{fx(231,{target=1,duration=36})},{target=5,speed=9,projectile=1})
local quick=spell('TESTALAC',9,{fx(188,{target=1,p2=1,duration=12})},{target=5,speed=9,projectile=1})
local bolt=spell('TESTBOLT',3,{fx(12,{p2=FIRE,dice=6,sides=6})})
local blast=spell('TESTBLST',7,{fx(12,{p2=FIRE,dice=10,sides=6})},{speed=9})
local missile=spell('TESTMM',1,{fx(12,{p1=1,p2=64*65536,dice=1,sides=4})},{projectile=69})
local hold=spell('TESTHOLD',2,{fx(175,{p2=3,p1=1,duration=30,save=1})})
local pwk=spell('TESTPWK',9,{fx(209)})
local pfmw=spell('TESTPFMW',6,{fx(120,{p1=6,target=1,duration=12})},{target=5})

local function enemy(id,fields)
    local e={id=id,x=100+id*10,y=100,hp=50,maxHp=50,state=0,held=0,sanctuary=0,mr=0,action=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function fighter(id,x)
    return enemy(id,{x=x,hp=60,maxHp=60,action=3,actee=1,ac=4,attack={apr=2,thac0=10,damage=10,magical=true}})
end
local function row(resref,s,level,fields)
    local r={resref=resref,level=level,ready=1,memorized=1,usable=true,list='mage',spell=s}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function input(fields)
    local i={tick=100,family='mage',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=0,ac=8,mr=0,guard={}},
        enemies={},allies={}},spells={},plan={},memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function kit()
    return {row('TESTSTOP',stop,9),row('TESTALAC',quick,9),row('TESTBOLT',bolt,3),row('TESTHOLD',hold,2)}
end
local function near(a,b) return math.abs(a-b)<1e-9 end
-- Raw records for releases (group 8): the spells a sequencer casts, read through a lookup.
local function record(resref,level,effects,ability,fields)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=1024,spellType=1,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local RAW={['SPL:TESTMMR']=record('TESTMMR',1,{fx(12,{p1=1,p2=64*65536,dice=1,sides=4})}),
    ['SPL:TESTSKIN']=record('TESTSKIN',4,{fx(218,{target=1,p1=8,duration=60})},{target=5,projectile=1}),
    ['SPL:TESTGLOB']=record('TESTGLOB',4,{fx(102,{target=1,p1=3,duration=60})},{target=5,projectile=1})}
local function lookupRaw(kind,key)
    if kind=='PRO' and key==2 then return SINGLE end
    return RAW[kind..':'..tostring(key)]
end
local function innate(resref,parts)
    local effects={}
    for _,res in ipairs(parts) do effects[#effects+1]=fx(146,{p2=1,res=res}) end
    effects[#effects+1]=fx(172,{target=1,res=resref})
    effects[#effects+1]=fx(171,{target=1,timing=4,duration=1440,res=resref})
    return spells.classify(record(resref,1,effects,{range=5,speed=0,projectile=1},{spellType=4,flags=0}),1,lookupRaw,{level=10})
end

-- 1. Which spells open: a time stop held by the caster, and aura cleansing on the caster.
assert(openers.stopsTime(stop) and not openers.stopsTime(bolt) and not openers.stopsTime(quick))
assert(openers.quickens(quick) and not openers.quickens(stop) and not openers.quickens(bolt))
assert(choice.attack(stop)==nil)
groups=groups+1

-- 2. When, as SCS: Time Stop for an enemy that is no summon or illusion, with no stop running
-- and the caster's own Improved Alacrity down; Improved Alacrity when it is down, first in the
-- caster's own stop; nothing in another creature's stop; nothing without spells to follow.
local i=input({spells=kit()})
i.frame.enemies={enemy(11)}
local o,why=openers.choose(i)
assert(o and o.rule=='time-stop' and o.resref=='TESTSTOP' and o.self and o.kind=='opener')
i.frame.enemies={enemy(11,{ids={ea=2,general=1,race=1,class=2,specific=0,gender=6,alignment=0}})}
o=openers.choose(i)
assert(o and o.rule=='alacrity' and o.resref=='TESTALAC')
i.frame.enemies={enemy(11)}
i.frame.self.alacrity=true
o,why=openers.choose(i)
assert(o==nil and why=='waiting')
i.frame.self.alacrity=nil
i.timeStop={caster=99,left=10}
o,why=openers.choose(i)
assert(o==nil and why=='frozen' and openers.ownStop(i)==nil)
i.timeStop={caster=1,left=15}
o=openers.choose(i)
assert(o and o.rule=='alacrity' and openers.ownStop(i)==15)
i.timeStop=nil
i.spells={row('TESTSTOP',stop,9),row('TESTALAC',quick,9),row('TESTBOLT',bolt,3)}
o,why=openers.choose(i)
assert(o==nil and why=='no-followups')
i.spells[3].ready=2
assert(openers.choose(i).rule=='time-stop')
i.frame.enemies={enemy(11,{hp=0})}
o,why=openers.choose(i)
assert(o==nil and why=='no-enemy')
groups=groups+1

-- 3. The choice takes an opener before the ranking; the profile can turn openers off.
i=input({spells=kit()})
i.frame.enemies={enemy(11)}
local d,how,options=choice.decide(i)
assert(d.kind=='opener' and d.rule=='time-stop' and how=='opener' and #options==1)
i.mind=mind.new({openers=false})
d=choice.decide(i)
assert(d.kind=='disable' and d.resref=='TESTHOLD')
assert(mind.new({openers='yes'})==nil and mind.new({slowSpeed=-1})==nil and mind.new().slowSpeed==6)
groups=groups+1

-- 4. In its own Time Stop what the caster cast lands when time resumes: an enemy it held counts
-- as held, so the next hold goes to the other one; an enemy it is expected to have killed is left
-- alone, and one it hurt is worth finishing. Outside its own stop the list counts for nothing.
i=input({spells={row('TESTHOLD',hold,2)},timeStop={caster=1,left=12}})
i.frame.enemies={enemy(11),enemy(12)}
assert(choice.decide(i).target==11)
i.stopCasts={{kind='disable',hits={11}}}
assert(choice.decide(i).target==12)
i=input({spells={row('TESTBOLT',bolt,3)},timeStop={caster=1,left=12}})
i.frame.enemies={enemy(11),enemy(12)}
i.stopCasts={{kind='damage',hits={11},expected={[11]=50}}}
assert(choice.decide(i).target==12)
i.stopCasts={{kind='damage',hits={11},expected={[11]=30}}}
d=choice.decide(i)
assert(d.target==11 and near(d.worth,0.9) and near(d.expected[11],20))
assert(i.frame.enemies[1].hp==50)
i.timeStop={caster=99,left=12}
assert(choice.frozen(i)==i)
groups=groups+1

-- 5. Power Word, Kill works only below 60 hit points; in the caster's own Time Stop it is judged
-- by the hit points the enemy has now, not by what lands when time resumes.
i=input({spells={row('TESTPWK',pwk,9)}})
i.frame.enemies={enemy(11,{hp=80,maxHp=80})}
d,how=choice.decide(i)
assert(d==nil and how=='no-option')
i.frame.enemies={enemy(11,{hp=50,maxHp=80})}
d=choice.decide(i)
assert(d and d.resref=='TESTPWK' and d.target==11 and near(d.worth,0.625+0.5))
i=input({spells={row('TESTPWK',pwk,9)},timeStop={caster=1,left=12},
    stopCasts={{kind='damage',hits={11},expected={[11]=40}}}})
i.frame.enemies={enemy(11,{hp=80,maxHp=80})}
d,how=choice.decide(i)
assert(d==nil and how=='no-option')
groups=groups+1

-- 6. Under Improved Alacrity a slow spell waits while a quick one is good enough, as SCS's slow
-- spells do; a quick spell below the minimum worth leaves the slow one in.
i=input({spells={row('TESTBOLT',bolt,3),row('TESTBLST',blast,7)}})
i.frame.enemies={enemy(11,{hp=60,maxHp=60})}
assert(choice.decide(i).resref=='TESTBLST')
i.frame.self.alacrity=true
d=choice.decide(i)
assert(d.resref=='TESTBOLT' and d.speed==3)
i.spells={row('TESTMM',missile,1),row('TESTBLST',blast,7)}
assert(choice.decide(i).resref=='TESTBLST')
groups=groups+1

-- 8. Releases (D2b): an innate that casts two Magic Missiles at its target reaches as far as they
-- do (30, 480 away), not the 5 written on it, and is an attack that goes off with ForceSpellRES
-- (release). A trigger of protections is a defence on the caster. Under Improved Alacrity
-- neither, as SCS keeps them for after it.
local seq=innate('TESTSEQ',{'TESTMMR','TESTMMR'})
local trig=innate('TESTTRIG',{'TESTSKIN','TESTGLOB'})
assert(seq.release and seq.range==30 and seq.ownRange==5 and choice.attack(seq)=='damage')
assert(trig.release and trig.roles.protection.who.self)
local r8=input({spells={row('TESTSEQ',seq,1,{list='innate'}),row('TESTTRIG',trig,1,{list='innate'})}})
r8.frame.enemies={fighter(11,300)}
r8.frame.enemies[1].hp=6
local attacks=choice.options(r8)
assert(#attacks==1 and attacks[1].resref=='TESTSEQ' and attacks[1].release and attacks[1].target==11)
local guards=defence.options(r8)
assert(#guards==1 and guards[1].resref=='TESTTRIG' and guards[1].release and guards[1].self)
local d8=choice.decide(r8)
assert(d8 and d8.release)
r8.frame.self.alacrity=true
assert(select(2,choice.decide(r8))=='no-option' and #choice.unreleased(r8).spells==0)
groups=groups+1

-- 7. Defences in the caster's own Time Stop: nothing can break a cast that ends within it, the
-- caster is in no acute danger, and a protection counts only for what is left of it when time
-- resumes.
i=input({spells={row('TESTPFMW',pfmw,6)}})
i.frame.enemies={fighter(11,130),fighter(12,135)}
local t=threat.picture(i.frame)
assert(defence.through(i,t[1],5.4)<1 and defence.acute(i,t))
assert(#defence.options(i,{})==1)
i.timeStop={caster=1,left=12}
assert(defence.through(i,t[1],5.4)==1 and defence.through(i,t[1],13)<1 and not defence.acute(i,t))
local rejected={}
assert(#defence.options(i,rejected)==0 and rejected['no-worth']==1)
i.timeStop={caster=1,left=6}
assert(#defence.options(i,{})==1)
groups=groups+1

return groups
