-- A thief's own hide (F2f, combat-intent/stealth.lua): who can hide by its skill, and when a thief
-- that sees no enemy hides: not when invisible or hiding already, by its wit or its orders, one try a
-- round. Plain values; no game data.
local stealth=require('combat-intent.stealth')
local mind=require('combat-intent.mind')
local groups=0

local function thief(fields)
    local s={id=1,x=100,y=100,hp=40,maxHp=40,state=0,class=4,hideSkill=60,modal=0}
    for k,v in pairs(fields or {}) do s[k]=v end
    return s
end
local function input(fields,self)
    local i={tick=1000,frame={self=thief(self),enemies={},allies={}},mind=mind.new()}
    for k,v in pairs(fields or {}) do i[k]=v end
    return i
end
local function why(i) return select(2,stealth.decide(i)) end

-- 1. Who can hide: a creature with thief levels (single or multiclass) and a Hide in Shadows skill
-- above 0. A fighter, a ranger (its skill waits for a lab) and a thief without the skill cannot.
for _,class in ipairs({4,9,10,13,15}) do assert(stealth.able(thief({class=class}))==true,class) end
assert(stealth.able(thief({class=2}))==false and stealth.able(thief({class=12}))==false)
assert(stealth.able(thief({hideSkill=0}))==false and stealth.able(thief({hideSkill='x'}))==false)
assert(stealth.able(nil)==false and stealth.able({})==false)
groups=groups+1

-- 2. A clever thief that sees no enemy hides; one that sees an enemy does not (the game's hiding
-- needs it unseen), nor one already invisible (a potion, a spell, an earlier hide) or in the game's
-- stealth mode, where its try runs. From the Find Traps mode it hides (the game switches modes).
local d=stealth.decide(input())
assert(d and d.kind=='hide' and d.ordered==nil)
assert(why(input({frame={self=thief(),enemies={{id=11}},allies={}}}))=='seen')
assert(why(input(nil,{class=2}))=='unable' and why(input(nil,{hideSkill=0}))=='unable')
assert(why(input(nil,{state=0x10}))=='hidden' and why(input(nil,{state=0x400000}))=='hidden')
assert(why(input(nil,{modal=3}))=='hiding')
assert(stealth.decide(input(nil,{modal=2})).kind=='hide' and stealth.decide(input(nil,{modal=nil})).kind=='hide')
assert(why(input({mind=mind.new({hide=false})}))=='off' and mind.new({hide='yes'})==nil)
groups=groups+1

-- 3. Wit: a dull thief never thinks of hiding, a normal one when its stretch out of sight drew it
-- (half or more without a draw); orders say always or never, whatever the wit.
local dull,normal={wit='dull',tactics=0},{wit='normal',tactics=0.5}
assert(why(input({mind=dull}))=='wit')
assert(why(input({mind=normal,tactical=false}))=='wit')
assert(stealth.decide(input({mind=normal,tactical=true})).kind=='hide')
assert(stealth.decide(input({mind=normal})).kind=='hide')
d=stealth.decide(input({mind=dull,orders={hide=true}}))
assert(d and d.kind=='hide' and d.ordered==true)
assert(why(input({orders={hide=false}}))=='ordered' and why(input({mind=dull,orders={hide=false}}))=='ordered')
groups=groups+1

-- 4. One try a round: within 90 ticks of the last try it waits; after them, or when the clock went
-- back (a load), it tries again.
assert(why(input({tried=950}))=='gap' and why(input({tried=911}))=='gap')
assert(stealth.decide(input({tried=910})).kind=='hide' and stealth.decide(input({tried=1200})).kind=='hide')
groups=groups+1

-- A monster's veil (F2f-5). Classified spells as combat-intent/spells.lua gives them: an
-- invisibility on the creature it is cast at, plain or improved, and when it comes back.
local function invisibility(fields)
    local c={target='self',spellType=4,speed=2,roles={protection={kinds={invisible=true},who={self=true}}}}
    for k,v in pairs(fields or {}) do c[k]=v end
    return c
end
local function row(resref,c,fields)
    local r={resref=resref,list='innate',ready=1,usable=true,spell=c}
    for k,v in pairs(fields or {}) do r[k]=v end
    return r
end

-- 5. What a veil can use: an invisibility on the creature it is used on, cast at itself or at a
-- creature, plain or improved; not one that reaches an area or others only, nor one aimed at a point.
assert(stealth.kind(invisibility())=='plain')
local improved=invisibility();improved.roles.protection.kinds.improvedInvisible=true
assert(stealth.kind(improved)=='improved')
assert(stealth.kind(invisibility({target='creature',roles={protection={kinds={invisible=true},who={target=true}}}}))=='plain')
assert(stealth.kind(invisibility({roles={protection={kinds={invisible=true},who={area=true}}}}))==nil)
assert(stealth.kind(invisibility({target='point'}))==nil)
assert(stealth.kind(invisibility({roles={protection={kinds={blur=true},who={self=true}}}}))==nil)
assert(stealth.kind(nil)==nil and stealth.kind({})==nil)
-- Ready innate ones only (from the innate list or innate by their file), with kind, recharge and
-- speed; one used up, not on the engine's buttons, a wizard's spell or no invisibility is left out.
local fiend=invisibility({recharge=6})
local list=stealth.veils({row('BGW20606',fiend),row('USED',fiend,{ready=0}),row('OFF',fiend,{usable=false}),
    row('SPWI206',invisibility({spellType=1}),{list='mage'}),row('FILE',invisibility({spellType=4}),{list='mage'}),
    row('BLUR',{target='self',roles={protection={kinds={blur=true},who={self=true}}}}),{resref='NONE'}})
assert(#list==2 and list[1].resref=='BGW20606' and list[1].kind=='plain' and list[1].recharge==6 and list[1].speed==2)
assert(list[2].resref=='FILE' and list[2].recharge==nil)
groups=groups+1

-- 6. Which one: plain before improved, one that comes back before one that is spent, the sooner the
-- better, then the faster cast, then the name. An improved one only when it is back within
-- veilRecharge (60 seconds): a vampiric illithid's after a round, not the Maurezhi's after 1000
-- seconds nor Illasera's five charges.
local function v(resref,kind,recharge,speed) return {resref=resref,kind=kind,recharge=recharge,speed=speed or 0} end
assert(stealth.pick({v('ONCE','plain',nil),v('ROUND','plain',6)}).resref=='ROUND')
assert(stealth.pick({v('II','improved',6),v('ONCE','plain',nil)}).resref=='ONCE')
assert(stealth.pick({v('LONG','plain',60),v('SHORT','plain',12)}).resref=='SHORT')
assert(stealth.pick({v('SLOW','plain',6,3),v('FAST','plain',6,1)}).resref=='FAST')
assert(stealth.pick({v('BBB','plain',6),v('AAA','plain',6)}).resref=='AAA')
assert(stealth.pick({v('II','improved',6)}).resref=='II' and stealth.pick({v('II','improved',60)}).resref=='II')
assert(stealth.pick({v('MAUREZHI','improved',1000)})==nil and stealth.pick({v('ILLASERA','improved',nil)})==nil)
assert(stealth.pick({})==nil and stealth.pick(nil)==nil and stealth.pick({{kind='plain'}})==nil)
assert(stealth.veiling(v('X','plain',nil)) and not stealth.veiling(v('X','improved',61)) and not stealth.veiling(nil))
groups=groups+1

-- 7. A creature that cannot hide by its skill and sees no enemy veils itself: the decision names the
-- spell, its kind and recharge. Without an innate invisibility it is unable; a thief hides even
-- with one. Seen, invisible already, dull, ordered not to or within a round of its last try: none.
local monster={class=2,hideSkill=0}
local veils={v('BGW20606','plain',6,2),v('BGW40506','improved',6,2)}
d=stealth.decide(input({veils=veils},monster))
assert(d and d.kind=='veil' and d.resref=='BGW20606' and d.improved==nil and d.recharge==6 and d.speed==2 and d.ordered==nil)
d=stealth.decide(input({veils={veils[2]}},monster))
assert(d.kind=='veil' and d.resref=='BGW40506' and d.improved==true)
assert(why(input({veils={v('MAUREZHI','improved',1000)}},monster))=='unable' and why(input(nil,monster))=='unable')
assert(stealth.decide(input({veils=veils})).kind=='hide')
assert(why(input({veils=veils,frame={self=thief(monster),enemies={{id=11}},allies={}}}))=='seen')
assert(why(input({veils=veils},{class=2,hideSkill=0,state=0x10}))=='hidden')
assert(why(input({veils=veils,mind=dull},monster))=='wit' and why(input({veils=veils,orders={hide=false}},monster))=='ordered')
d=stealth.decide(input({veils=veils,mind=dull,orders={hide=true}},monster))
assert(d.kind=='veil' and d.ordered==true)
assert(why(input({veils=veils,tried=950},monster))=='gap' and why(input({veils=veils,mind=mind.new({hide=false})},monster))=='off')
groups=groups+1

return groups
