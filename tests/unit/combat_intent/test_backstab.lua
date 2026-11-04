-- Backstabs (F2d, combat-intent/backstab.lua) and the choice around them (combat-intent/choice.lua,
-- defence.lua): where a creature faces and what is behind it, when a first hit can be a backstab
-- and what it is worth, going behind an enemy first, and what a hide is worth for the backstab after
-- it. A thief with THAC0 10 and a short sword (4.5 a hit, one attack a round) hits armour class 5
-- four times in five; its backstab triples the sword's damage. Synthetic records classified by
-- combat-intent/spells.lua; no game data.
local backstab=require('combat-intent.backstab')
local choice=require('combat-intent.choice')
local defence=require('combat-intent.defence')
local mind=require('combat-intent.mind')
local spells=require('combat-intent.spells')
local targeting=require('combat-intent.targeting')
local weapons=require('combat-intent.weapons')
local groups=0
local function near(a,b) return math.abs(a-b)<1e-9 end
local INVISIBLE,IMPROVED=targeting.STATE.invisible,targeting.STATE.improvedInvisible

local SWORD={item='TESTSSWD',damage=4.5,damageType=1,apr=1,thac0=10,ranged=false,flags=0,enchantment=0,backstab=true}
local BOW={item='TESTBOW',damage=4.5,damageType=4,apr=2,thac0=10,ranged=true,range=1600,flags=0,enchantment=0,
    projectile=2,slot=36,abilityNum=0,ammo='TESTARRO'}
-- An enemy at (200, 100), east of the thief at (100, 100), facing west at it unless said.
local function enemy(id,fields)
    local e={id=id,x=200,y=100,hp=60,maxHp=60,state=0,held=0,sanctuary=0,mr=0,action=0,ac=5,skins=0,mirror=0,
        ids={ea=2,general=1,race=1,class=2,specific=0,gender=1,alignment=0x11},protections={},
        saves={spell=20,breath=20,death=20,wand=20,poly=20},resist={},level=10,facing=4,
        attack={apr=0.5,thac0=20,damage=1}}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
-- An enemy whose facing the engine did not give.
local function unfaced(id)
    local e=enemy(id)
    e.facing=nil
    return e
end
local function input(fields,self)
    local i={tick=100,family='fighter',frame={self={id=1,x=100,y=100,hp=40,maxHp=40,state=INVISIBLE,ac=5,mr=0,
        thac0=10,apr=1,guard={},backstab=3,weapon=SWORD},enemies={},allies={}},spells={},plan={},memory={},
        mind=mind.new({ownWeapon=true,chase=true,alwaysAttack=true})}
    for k,v in pairs(self or {}) do i.frame.self[k]=v end
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end

-- 1. Where a creature faces: the way from one spot to another as one of the 16 directions (0
-- south, 4 west, 8 north, 12 east), behind as within two of the target's facing, and the spot
-- behind a creature opposite its facing (the screen's height counting 3/4).
local o={x=100,y=100}
assert(backstab.direction(o,{x=100,y=200})==0 and backstab.direction(o,{x=0,y=100})==4)
assert(backstab.direction(o,{x=100,y=0})==8 and backstab.direction(o,{x=200,y=100})==12)
assert(backstab.direction(o,{x=200,y=200})==14 and backstab.direction(o,{x=0,y=0})==6)
assert(backstab.direction(o,o)==nil and backstab.direction(o,{x=1})==nil)
local target={x=200,y=100,facing=12}
assert(backstab.behind(o,target)==true)
for f,want in pairs({[10]=true,[11]=true,[13]=true,[14]=true,[9]=false,[15]=false,[4]=false,[0]=false}) do
    target.facing=f
    assert(backstab.behind(o,target)==want,f)
end
target.facing=nil
assert(backstab.behind(o,target)==nil and near(backstab.prior(),5/16))
local spot=backstab.spot({x=200,y=100,facing=4})
assert(spot.x==248 and spot.y==100)
spot=backstab.spot({x=200,y=100,facing=0})
assert(spot.x==200 and spot.y==64)
spot=backstab.spot({x=200,y=100,facing=12},20)
assert(spot.x==180 and spot.y==100 and backstab.spot({x=200,y=100})==nil)
-- From the spot behind it, the creature is behind.
target={x=200,y=100,facing=6}
assert(backstab.behind(backstab.spot(target),target)==true)
groups=groups+1

-- 2. Who can backstab whom: an invisible creature (Improved Invisibility alone does not count), a
-- backstab multiplier above 1 and a melee weapon that can backstab; an enemy that is alive, not
-- immune and has no Mirror Image or Stoneskin skin.
assert(backstab.hidden({state=INVISIBLE}) and not backstab.hidden({state=IMPROVED}))
assert(not backstab.hidden({state=INVISIBLE+IMPROVED}) and not backstab.hidden({state=0}))
local thief={backstab=3}
assert(backstab.able(thief,SWORD) and not backstab.able(thief,BOW) and not backstab.able({backstab=1},SWORD))
assert(not backstab.able(thief,{damage=4,backstab=nil}) and not backstab.able({},SWORD))
assert(not backstab.able(thief,{damage=4,backstab=true,ranged=true}))
assert(backstab.open(enemy(11)) and not backstab.open(enemy(11,{backstabImmune=true})))
assert(not backstab.open(enemy(11,{mirror=1})) and not backstab.open(enemy(11,{skins=2})))
assert(not backstab.open(enemy(11,{state=0x800})) and not backstab.open(enemy(11,{hp=0})))
groups=groups+1

-- 3. The chance a first swing is a backstab: it hits (four in five) and the thief stands behind:
-- certain by the enemy's facing away, 5 in 16 when its facing is unknown, none when it faces the
-- thief, unless the thief goes behind first (behind true). A thief not hidden counts as hidden only
-- for a hide it has yet to take.
local caster={x=100,y=100,state=INVISIBLE,backstab=3}
local b=backstab.chance(caster,SWORD,enemy(11,{facing=12}))
assert(near(b.chance,0.8) and b.multiplier==3)
b=backstab.chance(caster,SWORD,unfaced(11))
assert(near(b.chance,0.8*5/16))
local none,why=backstab.chance(caster,SWORD,enemy(11))
assert(none==nil and why=='front' and near(backstab.chance(caster,SWORD,enemy(11),true).chance,0.8))
assert(select(2,backstab.chance({x=100,y=100,state=0,backstab=3},SWORD,enemy(11,{facing=12})))=='seen')
assert(near(backstab.chance({x=100,y=100,state=0,backstab=3},SWORD,enemy(11,{facing=12}),nil,true).chance,0.8))
assert(select(2,backstab.chance(caster,BOW,enemy(11,{facing=12})))=='unable')
assert(select(2,backstab.chance(caster,SWORD,enemy(11,{facing=12,mirror=2})))=='closed')
-- Where the game needs no one behind (BG1's rule), the facing does not matter.
backstab.needsBehind=false
assert(near(backstab.chance(caster,SWORD,enemy(11)).chance,0.8))
backstab.needsBehind=true
groups=groups+1

-- 4. The attack with the sword counts the backstab: from behind, the round's hits take 0.8 x 4.5
-- and the backstab's chance its two more swords' worth (0.8 x 9), 10.8 of 60; the walk of 0.36
-- seconds comes first. Facing it, the round is a plain one. An enemy of 13 hit points dies as likely
-- as the backstab lands (and is not killed without one).
local pace=6/(6+0.36)
local i=input()
i.frame.enemies={enemy(11,{facing=12})}
local list=choice.weaponOptions(i)
assert(#list==1 and near(list[1].worth,10.8/60*pace) and near(list[1].backstab,0.8) and near(list[1].expected[11],10.8))
i.frame.enemies={enemy(11)}
list=choice.weaponOptions(i)
assert(near(list[1].worth,3.6/60*pace) and list[1].backstab==nil)
i.frame.enemies={enemy(11,{facing=12,hp=13})}
list=choice.weaponOptions(i)
local expected=math.min(10.8,13)
assert(near(list[1].worth,(expected/60+0.5*0.8)*pace))
-- Unseen, the same thief strikes plainly; so it does at a barbarian or a mirrored enemy (whose
-- image the first hit takes: the plain hits count past it).
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12})}
assert(choice.weaponOptions(i)[1].backstab==nil)
i=input()
i.frame.enemies={enemy(11,{facing=12,backstabImmune=true})}
assert(choice.weaponOptions(i)[1].backstab==nil)
groups=groups+1

-- 5. Going behind (a tactic): the enemy faces the thief, so the thief walks to the spot behind it
-- (248, 100), 1.48 seconds, and the round's first hit there is a backstab as likely as it lands.
-- Worth more than the plain attack from the front. None when the thief is behind already, does not
-- know the enemy's facing, is seen, cannot walk or does not see the tactic.
i=input()
i.frame.enemies={enemy(11)}
list=choice.flankOptions(i)
local f=list[1]
assert(#list==1 and f.kind=='flank' and f.resref=='FLANK' and f.mode=='point' and f.target==11 and f.melee)
assert(f.point.x==248 and f.point.y==100 and near(f.walk,1.48) and near(f.backstab,0.8) and f.item=='TESTSSWD')
assert(near(f.worth,10.8/60*6/(6+1.48)) and f.worth>choice.weaponOptions(i)[1].worth and f.slot==nil)
local rejected={}
i.frame.enemies={enemy(11,{facing=12}),unfaced(12),enemy(13,{mirror=1}),enemy(14,{backstabImmune=true})}
assert(#choice.flankOptions(i,rejected)==0)
assert(rejected['flank-behind']==1 and rejected['flank-facing-unknown']==1 and rejected['flank-closed']==2)
i=input(nil,{state=0})
i.frame.enemies={enemy(11)}
assert(#choice.flankOptions(i)==0)
i=input(nil,{rooted=true})
i.frame.enemies={enemy(11)}
assert(#choice.flankOptions(i)==0)
i=input({tactical=false})
i.frame.enemies={enemy(11)}
rejected={}
assert(#choice.flankOptions(i,rejected)==0 and rejected['flank-unnoticed']==1)
-- None behind an enemy the adapter found no open way behind lately (input.blocked); behind another
-- one, still.
i=input()
i.frame.enemies={enemy(11),enemy(12)}
i.blocked={flank={[11]=true}}
rejected={}
list=choice.flankOptions(i,rejected)
assert(#list==1 and list[1].target==12 and rejected['flank-blocked']==1)
i.blocked={kite=true,position=true}
assert(#choice.flankOptions(i)==2)
-- A weapon to take up goes along: the switch's second comes first too.
i=input(nil,{weapon=BOW,arsenal={{item='TESTDAGG',damage=4.5,damageType=1,apr=1,thac0=10,ranged=false,flags=0,
    enchantment=0,backstab=true,slot=35,abilityNum=0}}})
i.frame.enemies={enemy(11)}
f=choice.flankOptions(i)[1]
assert(f.item=='TESTDAGG' and f.slot==35 and f.abilityNum==0 and near(f.worth,10.8/60*6/(6+1.48+1)))
groups=groups+1

-- 6. The choice: a clever thief goes behind the enemy facing it, a dull one strikes from the front
-- (it does not see the tactic). A normal one may notice only a backstab that is there: not with a
-- sword that cannot backstab, nor before an enemy whose image would take the first hit.
i=input()
i.frame.enemies={enemy(11)}
local d,whyd=choice.decide(i)
assert(d.kind=='flank' and whyd=='weapon')
i=input(nil,nil)
i.mind=mind.new({ownWeapon=true,chase=true,alwaysAttack=true,tactics=0})
i.frame.enemies={enemy(11)}
d=choice.decide(i)
assert(d.kind=='weapon' and d.backstab==nil)
local function normal(self,e)
    local n=input(nil,self)
    n.mind=mind.new({ownWeapon=true,chase=true,alwaysAttack=true,tactics=0.5})
    n.frame.enemies={e}
    return n
end
assert(choice.notices(normal(nil,enemy(11)))==true)
assert(choice.notices(normal({weapon={item='TESTPLAIN',damage=4.5,damageType=1,apr=1,thac0=10,ranged=false,flags=0,
    enchantment=0}},enemy(11)))==false)
assert(choice.notices(normal(nil,enemy(11,{mirror=1})))==false)
groups=groups+1

-- 7. What a hide is worth for the backstab after it: the thief is seen; hidden, its first hit next
-- round gains two more swords' worth as likely as it lands (0.8 x 9 of 60), less the walk; going
-- behind the enemy that faces it, less that longer walk. A potion of invisibility counts it beside
-- what being unseen protects; Improved Invisibility does not (no backstab under it), nor does a
-- thief that does not see the tactic or is hidden already. A spell of invisibility counts it less
-- the part of a round its casting takes. A potion that only hides for the backstab (nothing threatens
-- the thief) still names the thief as the one it is for.
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12})}
local open=choice.hideOpening(i)
assert(open.target==11 and near(open.worth,7.2/60*pace))
i.frame.enemies={enemy(11)}
open=choice.hideOpening(i)
assert(near(open.worth,7.2/60*6/(6+1.48)))
i=input()
i.frame.enemies={enemy(11,{facing=12})}
assert(choice.hideOpening(i)==nil)
i=input({tactical=false},{state=0})
i.frame.enemies={enemy(11,{facing=12})}
assert(choice.hideOpening(i)==nil)
local function fx(op,fields)
    local e={opcode=op,target=1,power=0,p1=0,p2=0,timing=0,resist=1,duration=120,prob1=100,prob2=0,
        res='',dice=0,sides=0,save=0,saveBonus=0,special=0}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
local function potion(resref,effects)
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,level=1,
        abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=1,minLevel=1,speed=0,projectile=1,
        effects=effects}},casting={}}
    return spells.classify(r,1,function() return nil end,{level=10})
end
local invis=potion('TESTINVI',{fx(20,{p2=0})})
local better=potion('TESTIMPI',{fx(20,{p2=1})})
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12})}
i.items={{resref='TESTINVI',abilities={{effect=invis,uses=1}}},{resref='TESTIMPI',abilities={{effect=better,uses=1}}}}
local plain=defence.options(i)
i.hideOpening=choice.hideOpening(i)
local opts=defence.options(i)
local function find(l,resref) for _,x in ipairs(l) do if x.resref==resref then return x end end end
local hid,was=find(opts,'TESTINVI'),find(plain,'TESTINVI')
assert(hid.hides and near(hid.opening,7.2/60*pace) and hid.hits[1]==1)
assert(near(hid.worth,(was and was.worth or 0)+hid.opening))
local imp,impWas=find(opts,'TESTIMPI'),find(plain,'TESTIMPI')
assert((imp==nil and impWas==nil) or (imp.hides==nil and near(imp.worth,impWas.worth)))
local function memorized(resref,effects,speed)
    local r={kind='SPL',resref=resref,name=0,flags=0,spellType=1,exclusion=0,school=0,secondary=0,level=2,
        abilities={{form=1,flags=0,location=2,target=5,targetCount=0,range=1,minLevel=1,speed=speed,projectile=1,
        effects=effects}},casting={}}
    return spells.classify(r,1,function() return nil end,{level=10})
end
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12})}
i.spells={{resref='TESTINVS',level=2,ready=1,memorized=1,usable=true,list='wizard',
    spell=memorized('TESTINVS',{fx(20,{p2=0})},3)}}
i.hideOpening=choice.hideOpening(i)
local sp=find(defence.options(i),'TESTINVS')
assert(sp.hides and near(sp.opening,i.hideOpening.worth*weapons.paced(3*defence.speedSeconds)))
assert(sp.opening<i.hideOpening.worth)
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12,attack={apr=0,thac0=20,damage=0}})}
i.items={{resref='TESTINVI',abilities={{effect=invis,uses=1}}}}
i.hideOpening=choice.hideOpening(i)
hid=find(defence.options(i),'TESTINVI')
assert(hid.hides and near(hid.worth,hid.opening) and #hid.hits==1 and hid.hits[1]==1)
-- In the choice, a thief whose backstab multiplies by five with a long sword (7.5 a hit) drinks the
-- potion for the backstab (two thirds of the enemy's hit points as likely as it lands) rather than
-- strike plainly now; a potion spends something, so it must reach the minimum worth, which the
-- short sword's backstab does not. A dull thief strikes.
local LONG={item='TESTLSWD',damage=7.5,damageType=3,apr=1,thac0=10,ranged=false,flags=0,enchantment=0,backstab=true}
i=input(nil,{state=0,backstab=5,weapon=LONG})
i.frame.enemies={enemy(11,{facing=12})}
i.items={{resref='TESTINVI',abilities={{effect=invis,uses=1}}}}
d=choice.decide(i)
assert(d.resref=='TESTINVI' and d.hides and d.use and near(d.opening,0.8*30/60*pace))
i.mind=mind.new({ownWeapon=true,chase=true,alwaysAttack=true,tactics=0})
d=choice.decide(i)
assert(d.kind=='weapon')
i=input(nil,{state=0})
i.frame.enemies={enemy(11,{facing=12})}
i.items={{resref='TESTINVI',abilities={{effect=invis,uses=1}}}}
assert(choice.decide(i).kind=='weapon')
groups=groups+1

return groups
