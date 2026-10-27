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

return groups
