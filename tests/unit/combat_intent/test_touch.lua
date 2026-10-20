-- Touch charges (combat-intent/touch.lua) and the choice around them (combat-intent/choice.lua):
-- which spells give one, when the caster can go for an enemy, the chance to hit, what keeps a
-- charge off an enemy, the touch option and the strike. Synthetic records classified by
-- combat-intent/spells.lua; no game data.
local touch=require('combat-intent.touch')
local choice=require('combat-intent.choice')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local groups=0

local function fx(op,fields)
    local e={opcode=op,target=2,power=0,p1=0,p2=0,timing=0,resist=0,duration=0,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function spl(resref,level,effects,ability)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=30,minLevel=1,speed=3,projectile=1,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    return {kind='SPL',resref=resref,name=0,flags=0,spellType=2,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
end
local function hand(resref,effects,fields)
    local a={attackType=1,idRequired=0,location=1,target=1,targetCount=0,range=1,launcher=0,speed=0,
        thac0=4,sides=0,school=0,dice=0,secondary=0,damageBonus=0,damageType=2,charges=1,depletion=1,
        flags=0,projectile=1,isArrow=0,isBolt=0,isBullet=0,effects=effects}
    for k,v in pairs(fields or {}) do a[k]=v end
    return {kind='ITM',resref=resref,name=0,identifiedName=0,flags=0x40,itemType=28,abilities={a},equipping={}}
end
-- Spell Revisions' Harm in miniature: the hand's one hit casts 90 magic damage that leaves at
-- least one hit point; Shocking Grasp: 10 electricity damage and a stun; a conjured blade that
-- lasts as long as it lasts.
local RECORDS={
    ['SPL:TESTHRMD']=spl('TESTHRMD',6,{fx(208,{p1=1,duration=1}),fx(12,{p1=90,p2=64*65536,timing=1})},{range=1,speed=0}),
    ['ITM:TESTHRM']=hand('TESTHRM',{fx(146,{res='TESTHRMD'}),fx(112,{target=1,res='TESTHRM',timing=1})}),
    ['ITM:TESTGRSP']=hand('TESTGRSP',{fx(12,{p1=10,p2=4*65536,timing=1}),fx(45,{duration=6}),fx(112,{target=1,res='TESTGRSP',timing=1})}),
    ['ITM:TESTBLD']=hand('TESTBLD',{fx(12,{dice=1,sides=6,p2=8*65536,timing=1})},{charges=0,depletion=0})}
local function lookup(kind,key) return RECORDS[kind..':'..tostring(key)] end
local function classify(record) return spells.classify(record,1,lookup,{level=12}) end
local harm=classify(spl('TESTHARM',6,{fx(111,{target=1,p1=1,res='TESTHRM',duration=60})},{target=5,range=1,speed=6}))
local grasp=classify(spl('TESTGRAS',1,{fx(111,{target=1,p1=1,res='TESTGRSP',duration=60})},{target=5,range=1,speed=1}))
local blade=classify(spl('TESTBLAD',2,{fx(111,{target=1,p1=1,res='TESTBLD',duration=120})},{target=5,range=1,speed=5}))
local bolt=classify(spl('TESTBOLT',3,{fx(12,{p2=8*65536,dice=6,sides=6})}))

local function enemy(id,fields)
    local e={id=id,x=100+id*10,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,
        skins=0,mirror=0,ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function row(resref,s,level)
    return {resref=resref,level=level,ready=1,memorized=1,usable=true,list='priest',spell=s}
end
local function input(fields)
    local i={tick=100,family='priest',frame={self={id=1,x=100,y=100,hp=60,maxHp=60,state=0,ac=5,mr=0,thac0=10,guard={}},
        enemies={},allies={}},spells={},plan={},memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function near(a,b) return math.abs(a-b)<1e-9 end

-- 1. Which spells give a touch charge: a melee weapon of one hit.
local w=touch.charge(harm)
assert(w and w.item=='TESTHRM' and w.touch and touch.charge(grasp).item=='TESTGRSP' and w.flags==0x40)
assert(touch.charge(blade)==nil and touch.charge(bolt)==nil and touch.charge(nil)==nil)
-- None of them is an attack spell of its own.
assert(choice.attack(harm)==nil and choice.attack(grasp)==nil)
-- The strike's spells come along for spell protections: Harm's hit casts a level-6 spell.
assert(w.strike.delivered[1].resref=='TESTHRMD' and w.strike.delivered[1].level==6)
groups=groups+1

-- 2. The chance to hit: THAC0 10 less the hand's 4 against armour class 5 needs a 1 or better
-- (capped at 95%); against armour class -5, an 11 or better.
local caster={id=1,x=100,y=100,thac0=10}
assert(near(touch.hitChance(caster,{ac=5},w),0.95))
assert(near(touch.hitChance(caster,{ac=-5},w),0.5))
assert(near(touch.hitChance(caster,{ac=-20},w),0.05))
groups=groups+1

-- 3. Reach (touchReach 10 range units of 16) and what keeps the charge off an enemy.
local m=mind.new()
assert(touch.reach(m)==160)
assert(touch.reachable(caster,enemy(11,{x=250}),m))
assert(select(2,touch.reachable(caster,enemy(11,{x=300}),m))=='out-of-reach')
assert(select(2,touch.reachable(caster,enemy(11,{x=150,hp=0}),m))=='dead')
assert(select(2,touch.reachable(caster,enemy(11,{x=150,sanctuary=1}),m))=='sanctuary')
assert(touch.blocked(enemy(11),w)==nil)
assert(touch.blocked(enemy(11,{mirror=3}),w)=='mirror')
assert(touch.blocked(enemy(11,{skins=2}),w)=='stoneskin')
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=1}}}),w)=='weapon-immunity')
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=3,p2=0}}}),w)=='weapon-immunity')
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=2}}}),w)==nil)
-- A hand that is not magical (SR's Chill Touch) passes Protection from Magical Weapons and is
-- kept off by Protection from Normal Weapons; a +4 hand passes an immunity up to +3; a silver
-- hand passes an immunity to weapons that are not silver.
local plain={}
for k,v in pairs(w) do plain[k]=v end
plain.flags=0
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=1}}}),plain)==nil)
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=2}}}),plain)=='weapon-immunity')
plain.enchantment=4
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=3,p2=0}}}),plain)==nil)
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=4,p2=0}}}),plain)=='weapon-immunity')
plain.flags,plain.enchantment=0x140,0
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=4}}}),plain)==nil)
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=3}}}),plain)=='weapon-immunity')
assert(touch.blocked(enemy(11,{protections={{opcode=120,p1=0,p2=99}}}),plain)=='weapon-immunity')
assert(touch.blocked(enemy(11,{protections=false}),w)=='protected')
-- Spell Turning or a globe against the hit's spell keeps the charge off (level 6 here).
assert(touch.blocked(enemy(11,{protections={{opcode=200,p1=0,p2=6}}}),w)=='protected')
assert(touch.blocked(enemy(11,{protections={{opcode=102,p1=6,p2=0}}}),w)=='protected')
assert(touch.blocked(enemy(11,{protections={{opcode=102,p1=4,p2=0}}}),w)==nil)
groups=groups+1

-- 4. Standing next to an enemy whose friend swings a sword costs the hit points that friend
-- would deal a round; next to a lone enemy without a weapon nothing more.
local i=input()
local target=enemy(11,{x=250})
local guard=enemy(12,{x=270,action=3,actee=-1,attack={apr=2,thac0=10,damage=10,magical=true}})
i.frame.enemies={target,guard}
assert(touch.exposure(i.frame,target)>0)
i.frame.enemies={enemy(11,{x=250,attack={apr=0.5,thac0=20,damage=1}})}
local lone=touch.exposure(i.frame,i.frame.enemies[1])
assert(lone>=0 and lone<1)
groups=groups+1

-- 5. The touch option: cast on the caster, aimed at the enemy it will strike. Harm keeps the
-- enemy at one hit point: 59 of its 60 count and no kill.
i=input({spells={row('TESTHARM',harm,6)}})
i.frame.enemies={enemy(11,{x=200,attack={apr=0.5,thac0=20,damage=1}})}
local d,why=choice.decide(i)
assert(why=='best' and d.kind=='touch' and d.self and d.target==11 and d.resref=='TESTHARM' and d.item=='TESTHRM')
local p=touch.hitChance(i.frame.self,i.frame.enemies[1],w)
assert(near(d.hit,p) and near(d.worth,59/60*p) and d.score<d.worth and near(d.expected[11],59*p))
-- The response casts on the caster.
assert(d.mode=='self')
-- An enemy at one hit point gains nothing from Harm; behind Mirror Images it is no target.
i.frame.enemies={enemy(11,{x=200,hp=1})}
d,why=choice.decide(i)
assert(d==nil and why=='no-option')
i.frame.enemies={enemy(11,{x=200,mirror=2})}
d,why,_,rejected=choice.decide(i)
assert(d==nil and rejected.mirror==1)
-- Out of reach, switched off, in the caster's own Time Stop or under Improved Alacrity: none.
i.frame.enemies={enemy(11,{x=400})}
assert(choice.decide(i)==nil)
i.frame.enemies={enemy(11,{x=200})}
i.mind=mind.new({touch=false})
assert(choice.decide(i)==nil)
i.mind=mind.new()
i.timeStop={caster=1,left=10}
assert(choice.decide(i)==nil)
i.timeStop=nil
i.frame.self.alacrity=true
assert(choice.decide(i)==nil)
i.frame.self.alacrity=nil
assert(choice.decide(i).kind=='touch')
-- Standing next to a swordsman costs: the option is worth less after the cost.
i.frame.enemies={enemy(11,{x=200}),enemy(12,{x=215,attack={apr=2,thac0=5,damage=12,magical=true}})}
local cheap=choice.decide(input({spells={row('TESTHARM',harm,6)},frame={self=i.frame.self,
    enemies={enemy(11,{x=200,attack={apr=0.5,thac0=20,damage=1}})},allies={}}}))
local costly=choice.options(i)[1]
assert(costly.kind=='touch' and costly.target==11 and costly.cost>cheap.cost)
groups=groups+1

-- 6. The strike: with a charge in hand, at the enemy in reach where the hit is worth most times
-- its chance, before anything else; no touch spell is cast while the charge waits.
i=input({spells={row('TESTHARM',harm,6),row('TESTBOLT',bolt,3)}})
local charge={}
for k,v in pairs(w) do charge[k]=v end
charge.spell='TESTHARM'
i.frame.self.charge=charge
i.frame.enemies={enemy(11,{x=200,mirror=1}),enemy(12,{x=210}),enemy(13,{x=220,hp=20,maxHp=60})}
d,why=choice.decide(i)
assert(why=='strike' and d.kind=='strike' and d.target==12 and d.resref=='TESTHRM' and d.spell=='TESTHARM')
assert(near(d.worth,59/60*p) and d.score==d.worth)
-- No enemy in reach: the round goes to the other options, and no new touch spell. Why each
-- enemy got no strike is counted.
i.frame.enemies={enemy(12,{x=400})}
d,why=choice.decide(i)
assert(d.kind=='damage' and d.resref=='TESTBOLT')
local counted={}
assert(choice.strike(i,counted)==nil and counted['strike-out-of-reach']==1)
i.frame.enemies={enemy(12,{x=210,mirror=1}),enemy(13,{x=220,protections=false})}
counted={}
assert(choice.strike(i,counted)==nil and counted['strike-mirror']==1 and counted['strike-protected']==1)
i.frame.enemies={enemy(12,{x=400})}
for _,o in ipairs(choice.options(i)) do assert(o.kind~='touch') end
-- Not in the caster's own Time Stop, not under Improved Alacrity.
i.frame.enemies={enemy(12,{x=210})}
i.timeStop={caster=1,left=10}
assert(choice.strike(i)==nil)
i.timeStop=nil
i.frame.self.alacrity=true
assert(choice.strike(i)==nil)
groups=groups+1

-- 7. A hit that also disables is worth its damage and its disable together.
i=input({spells={row('TESTGRAS',grasp,1)}})
i.frame.enemies={enemy(11,{x=200})}
d=choice.decide(i)
local gw=touch.charge(grasp)
local gp=touch.hitChance(i.frame.self,i.frame.enemies[1],gw)
assert(d.kind=='touch' and d.worth>10/60*gp+1e-9)
groups=groups+1

-- 8. The profile: touch is a switch, touchReach an amount.
assert(mind.new().touch==true and mind.new().touchReach==10)
assert(mind.new({touchReach=4}).touchReach==4 and select(2,mind.new({touchReach=-1}))=='touchReach')
assert(select(2,mind.new({touch=1}))=='touch')
groups=groups+1

return groups
