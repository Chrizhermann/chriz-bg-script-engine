-- The engine's own healing and curing (combat-intent/care.lua, D3a and D3b) on synthetic spells
-- classified by combat-intent/spells.lua and plain frames. No game data.
local care=require('combat-intent.care')
local choice=require('combat-intent.choice')
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
local function area(radius,flags)
    return {kind='PRO',resref='AREA',type=3,speed=20,flags=0,extFlags=0,areaFlags=flags or 0,trigger=30,radius=radius,coneWidth=0}
end
local function spell(resref,level,effects,ability,pro)
    local a={form=1,flags=0,location=2,target=1,targetCount=0,range=1,minLevel=1,speed=3,projectile=2,effects=effects}
    for k,v in pairs(ability or {}) do a[k]=v end
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=2,exclusion=0,school=0,secondary=0,
        level=level,abilities={a},casting={}}
    return spells.classify(r,1,function(kind,key) if kind=='PRO' and key==2 then return pro or SINGLE end end,{level=10})
end
local cure=spell('TESTCURE',4,{fx(17,{p1=30})})
local heal=spell('TESTHEAL',6,{fx(17,{p1=100,p2=2}),fx(77),fx(75),fx(11)},{speed=6})
local mass=spell('TESTMASS',5,{fx(17,{p1=20})},{target=4,range=30},area(150,192))
local wide=spell('TESTWIDE',5,{fx(17,{p1=20})},{target=4,range=30},area(150,0))
local freedom=spell('TESTFREE',3,{fx(162)},{target=4,range=30},area(256,192))
local vocal=spell('TESTVOCL',2,{fx(48,{target=1})},{target=5})
local antidote=spell('TESTPOIS',4,{fx(11)})
local vampire=spell('TESTVAMP',3,{fx(12,{dice=2,sides=6}),fx(17,{p1=6,target=1})})
local party=spell('TESTPRTY',4,{fx(17,{p1=10}),fx(17,{p1=10,target=3})})
local potion=spells.classify({kind='ITM',resref='TESTPOTN',flags=0,abilities={{form=3,flags=0,location=3,target=5,
    range=1,speed=0,projectile=1,effects={fx(17,{p1=25,target=1})}}}},1,function() end,{level=1})

local function enemy(id,fields)
    local e={id=id,x=600,y=100,hp=50,maxHp=50,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function friend(id,fields)
    local f={id=id,x=100,y=100,hp=50,maxHp=50,state=0,held=0,ac=5,level=10,ids={class=3},
        guard={roles={},stoneskins=0,mirror=0,sources={},recast={},conditions={},poison=0}}
    for k,v in pairs(fields or {}) do f[k]=v end
    return f
end
local function row(resref,s,level,fields)
    local r={resref=resref,level=level,ready=1,memorized=1,usable=true,list='priest',spell=s}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end
local function input(fields)
    local i={tick=100,family='priest',frame={self=friend(1,{level=12}),enemies={},allies={}},spells={},plan={},
        memory={},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function near(a,b) return math.abs(a-b)<1e-9 end
local function only(i,kind)
    local out={}
    for _,o in ipairs(care.options(i,i.rejected)) do if kind==nil or o.kind==kind then out[#out+1]=o end end
    return out
end

-- 1. SCS's healing level (minimum_healing_level), the hit points a heal restores, and what each
-- spell is: a heal and cure for friends; no attack, no spell that reaches the party.
local levels={[1]=1,[3]=1,[4]=2,[5]=2,[6]=3,[7]=3,[8]=4,[9]=4,[12]=7,[14]=9,[15]=9,[17]=11,[18]=11,[20]=13,[21]=13,[30]=22}
for level,minimum in pairs(levels) do assert(care.minimumLevel(level)==minimum,level) end
assert(care.minimumLevel(nil)==1)
assert(care.healed(cure.roles.heal,{hp=10,maxHp=100})==30 and care.healed(cure.roles.heal,{hp=90,maxHp=100})==10)
assert(care.healed(heal.roles.heal,{hp=10,maxHp=80})==70 and care.healed({kinds={set=true}},{hp=1,maxHp=10})==0)
assert(care.care(cure).heal and care.care(heal).cure.kinds.feeblemind and care.care(vocal).cure.who.self)
assert(select(2,care.care(vampire))=='offensive' and select(2,care.care(party))=='party')
assert(select(2,care.care(spell('TESTBOLT',3,{fx(12,{dice=6,sides=6})})))=='no-care')
assert(select(2,choice.attack(cure))=='role-heal')
groups=groups+1

-- 2. A heal on a friend no one threatens is worth the hit points it restores; on a friend about
-- to fall also the rounds it keeps it standing and the kill bonus. A friend that falls before the
-- cast lands gains nothing.
local f=friend(2,{hp=20,maxHp=100})
local quiet=care.standing(f,nil,{stoneskin=0,mirror=0,armor=0,hp=0,mr=0,saves=0,schools=0,resist={},covers={},all={},
    personal={},nonmagical=false,magicalUpTo=0,invisible=false,improved=false,blur=false},3,0.5,50)
assert(near(quiet,0.5+0.5+1))
local i=input()
i.frame.allies={friend(2,{x=110,hp=20,maxHp=100})}
i.spells={row('TESTCURE',cure,4)}
local o=only(i)[1]
assert(o.kind=='heal' and o.target==2 and o.mode=='ally' and near(o.worth,0.3) and o.hits[1]==2)
assert(near(o.cost,0.12+0.02*3*care.speedSeconds))
-- A spell slot costs input.slots of its price (combat-intent/choice.lua); the casting time does not.
i.slots=0.5;assert(near(only(i)[1].cost,0.06+0.02*3*care.speedSeconds));i.slots=nil
-- An enemy fighter at the ally (19 hit points a round): it falls either way, but the heal keeps
-- it standing about a round and a half longer.
i.frame.enemies={enemy(11,{x=150,attack={apr=2,thac0=5,damage=10},actee=2})}
local pressed=only(i)[1]
assert(pressed.target==2 and near(pressed.worth,(1/3)*30/19))
-- With 3 hit points left it falls while the spell is cast.
i.frame.allies[1].hp=3;i.rejected={}
assert(#only(i)==0 and i.rejected['care-falls']==1)
-- With minimum hit points (opcode 208) it does not fall, and a heal the fighter takes again
-- within the horizon gains nothing.
i.frame.allies[1].minHp=1;i.rejected={}
assert(#only(i)==0 and i.rejected['care-no-worth']==1)
groups=groups+1

-- 3. Who gets healed: allies above SCS's level for the caster, not one another member is healing
-- (with coordination), within the spell's range and a round's walk; the caster itself always.
i=input({rejected={}})
i.frame.allies={friend(2,{x=110,hp=20,maxHp=100,level=7})}
i.spells={row('TESTCURE',cure,4)}
assert(#only(i)==0 and i.rejected['care-level']==1)
i.frame.allies[1].level=8
assert(only(i)[1].target==2)
i.plan={reserved={[2]=5}};i.rejected={}
assert(#only(i)==0 and i.rejected['care-reserved']==1)
i.mind=mind.new({coordination=0})
assert(only(i)[1].target==2)
i.plan={};i.frame.allies[1].x=100+16+601;i.rejected={}
assert(#only(i)==0)
-- A walk into range comes first and lowers the worth as for an attack (weapons.paced: 5 seconds
-- at 100 world units a second leave 6/11); only the casting time costs.
i.frame.allies[1].x=100+16+500
o=only(i)[1]
assert(o.target==2 and near(o.walk,5) and near(o.worth,0.3*6/11) and near(o.cost,0.12+0.02*3*care.speedSeconds))
-- A caster that cannot walk (webbed or entangled) reaches only allies within range.
i.frame.self.rooted=true
assert(#only(i)==0)
i.frame.allies[1].x=110
o=only(i)[1];assert(o.target==2 and o.walk==nil and near(o.worth,0.3))
i.frame.self.rooted=nil
i.frame.self.hp=10
o=only(i)[1];assert(o.self==true and o.mode=='self' and near(o.worth,30/50))
-- The friend must stand the walk as well as the casting: one an enemy fighter strikes for 19 hit
-- points a round lives through the casting (2 seconds) with 12 but not through 5 seconds of walk
-- and the casting.
i=input({rejected={}})
i.frame.allies={friend(2,{x=110,hp=12,maxHp=100})}
i.frame.enemies={enemy(11,{x=150,attack={apr=2,thac0=5,damage=10},actee=2})}
i.spells={row('TESTCURE',cure,4)}
assert(only(i)[1].target==2)
i.frame.allies[1].x=100+16+500;i.frame.enemies[1].x=100+16+540
assert(#only(i)==0 and i.rejected['care-falls']==1)
groups=groups+1

-- 4. Area heals reach the friends in their area: an allies-only one at the spot where it helps
-- most; one that spares no one counts the enemies it heals against itself.
i=input()
i.frame.allies={friend(2,{x=400,hp=10}),friend(3,{x=450,hp=10}),friend(4,{x=100,y=400,hp=40})}
i.spells={row('TESTMASS',mass,5)}
o=only(i)[1]
assert(o.mode=='point' and #o.hits==2 and near(o.worth,0.8) and (o.point.x==400 or o.point.x==450))
i.spells={row('TESTWIDE',wide,5)}
-- (A held enemy, so that it threatens no one.)
i.frame.enemies={enemy(11,{x=420,hp=20,maxHp=50,held=1})}
o=only(i)[1]
assert(near(o.worth,0.8-0.4))
groups=groups+1

-- 5. Cures (D3b): a held ally is worth freeing for the time its hold has left, as a hold on an
-- enemy is worth; silence matters for casters; poison also for the hit points it would take;
-- a condition whose state shows no more is over; unread effects count by the state alone.
i=input()
local held=friend(2,{x=200,held=1,guard={roles={},conditions={hold=12},poison=0}})
i.frame.allies={held}
i.spells={row('TESTFREE',freedom,3)}
o=only(i)[1]
assert(o.kind=='cure' and o.mode=='point' and o.hits[1]==2 and near(o.worth,1*(12/18)*1))
held.held=0
assert(#only(i)==0)
held.guard=false;held.held=1
assert(near(only(i)[1].worth,12/18))
i.spells={row('TESTVOCL',vocal,2)}
i.frame.self.state=0x1000;i.frame.self.guard.conditions={silence=30}
o=only(i)[1];assert(o.self and near(o.worth,0.7))
i.frame.self.ids={class=2}
assert(near(only(i)[1].worth,0.7*0.2))
i=input()
local sick=friend(2,{x=110,state=0x4000,guard={roles={},conditions={poison=10},poison=20}})
i.frame.allies={sick}
i.spells={row('TESTPOIS',antidote,4)}
assert(near(only(i)[1].worth,20/50))
-- Heal cures too: its cures add to its heal.
i.spells={row('TESTHEAL',heal,6)}
sick.state=0x4000+0x100000;sick.guard.conditions.feeblemind=math.huge;sick.hp=25
o=only(i)[1]
assert(o.kind=='heal' and near(o.worth,25/50+20/50+1*1*(0.5+0.5*25/50)))
-- A cure the ally's spell protections keep out frees nothing (lab batch H: SCS's Minor Globe of
-- Invulnerability kept Remove Paralysis off a held mage); the caster's own globe lets its own
-- beneficial spell through.
local freed=spell('TESTFRE3',3,{fx(162,{power=3})},{target=4,range=30},area(256,192))
i=input({rejected={}})
local globed=friend(2,{x=200,held=1,guard={roles={},conditions={hold=12},poison=0},protections={{opcode=102,p1=3}}})
i.frame.allies={globed}
i.spells={row('TESTFRE3',freed,3)}
assert(#only(i)==0 and i.rejected['care-protected']==1)
globed.protections={{opcode=102,p1=4}}
assert(only(i)[1].hits[1]==2)
i=input()
i.frame.self.hp=10;i.frame.self.protections={{opcode=102,p1=3}}
i.spells={row('TESTMEND',spell('TESTMEND',3,{fx(17,{p1=30,power=3})}),3)}
o=only(i)[1];assert(o.self and near(o.worth,30/50))
groups=groups+1

-- 6. Potions: the caster drinks one while uses are left; it costs as a first-level spell and
-- cannot be interrupted. In decide, a drink or a heal beats a weak attack.
i=input()
i.frame.self.hp=15
i.items={{resref='TESTPOTN',abilities={{effect=potion,uses=1}}}}
o=only(i)[1]
assert(o.use==true and o.self and o.resref=='TESTPOTN' and near(o.worth,25/50) and near(o.cost,0.03))
i.slots=0.25;assert(near(only(i)[1].cost,0.03));i.slots=nil
i.items[1].abilities[1].uses=0
assert(#only(i)==0)
i.items[1].abilities[1].uses=2
i.frame.enemies={enemy(11,{hp=200,maxHp=200,x=300})}
i.spells={row('TESTBOLT',spell('TESTBOLT',3,{fx(12,{dice=6,sides=6})},{range=30}),3,{list='mage'})}
local d=choice.decide(i)
assert(d.kind=='heal' and d.use==true)
groups=groups+1

return groups
