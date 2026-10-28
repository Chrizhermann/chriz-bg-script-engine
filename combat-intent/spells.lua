-- What a spell or item ability does, read from its real effects (design step 2). Records are
-- plain tables with the fields of tools/ie_resources.py (in game: adapters/eeex/resources.lua).
-- lookup(kind, key) returns another record: 'SPL', 'ITM' or 'EFF' by resref, 'PRO' by the
-- ability's projectile number. Spells delivered through other spells or EFF files are followed
-- with depth, cycle and size limits. Nothing here raises: odd or missing data is reported in
-- the result (partial, reasons, unknown opcodes), and the caller skips what it cannot use.
--
-- roles is everything the spell can do to anyone. Some effects reach only one kind of
-- creature: what 177 or 283 deliver with an IDS entry, a hold that names a creature type, what
-- 326 applies to creatures that meet a SPLPROT row. Those kinds are the spell's conditions, and
-- M.view gives the roles for one creature by which of them it meets: an extra for trolls counts
-- only on trolls, and a conditional immunity (Spell Revisions spares elves its charms and the
-- undead its fear; most of its spells first make creatures in a given spell state immune) takes
-- out what follows it.
local M={}
-- SCS's troll chains and SR's Greater Command go more than eight deliveries deep.
M.limits={depth=12,effects=2048}

local DAMAGE={[0]='crushing',[1]='acid',[2]='cold',[4]='electricity',[8]='fire',[16]='piercing',
    [32]='poison',[64]='magic',[128]='missile',[256]='slashing',[512]='magicfire',[1024]='magiccold',
    [2048]='stunning'}
local SAVES={{1,'spell'},{2,'breath'},{4,'death'},{8,'wand'},{16,'poly'}}
local RESIST={[27]='acid',[28]='cold',[29]='electricity',[30]='fire',[31]='magic',[84]='magicfire',
    [85]='magiccold',[86]='slashing',[87]='crushing',[88]='piercing',[89]='missile',[173]='poison'}
local STATS={[6]='charisma',[10]='constitution',[15]='dexterity',[19]='intelligence',[44]='strength',
    [49]='wisdom'}
local TOHIT={[54]=true,[167]=true,[278]=true,[284]=true,[288]=true,[305]=true,[306]=true}
local WEAPON_DAMAGE={[73]=true,[285]=true,[286]=true,[289]=true}
local SAVE_MODS={[33]=true,[34]=true,[35]=true,[36]=true,[37]=true,[325]=true,[346]=true}
-- Opcodes that roll their dice fields for an amount (IESDP: 12, 17, 18, 218 with parameter 2 at
-- 1, 331 and 333); they reach creatures of any level.
local DICE_AMOUNT={[12]=true,[17]=true,[18]=true,[331]=true,[333]=true}
local function diced(e) return DICE_AMOUNT[e.opcode]==true or (e.opcode==218 and e.p2==1) end
-- Graphics, sounds, text, scripting state and bookkeeping: no role.
local NEUTRAL={}
for _,op in ipairs({7,8,9,23,41,50,51,52,53,56,57,61,63,64,66,71,72,82,94,95,96,99,103,104,105,
    106,107,108,112,114,115,117,122,123,125,138,139,140,141,142,144,147,149,150,152,155,156,164,
    169,170,172,174,180,181,182,183,184,186,187,190,192,194,195,196,215,225,237,239,240,243,
    244,245,251,252,253,254,255,262,263,265,267,268,269,271,275,276,277,279,281,282,287,290,291,
    293,294,295,296,298,300,302,307,308,309,311,312,313,315,319,320,323,327,328,330,336,338,339,
    340,342,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,362,363,364,365,367,
    21,59,90,91,92,171,233,266}) do NEUTRAL[op]=true end
-- 321 and 266 remove the effects or protections of one named resource: SCS and SR use them
-- to refresh their own helpers, so they are bookkeeping, not dispelling. What 321 takes away
-- is kept all the same (H[321]).
M.neutral=NEUTRAL

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- Readers may return a dword unsigned; some opcodes store a signed amount in it.
local function s32(v) if v>=2^31 then return v-2^32 end return v end
local function chance(e)
    local hi,lo=math.min(e.prob1,100),math.max(e.prob2,0)
    if hi<lo then return 0 end
    return (hi-lo+1)/101
end
local function seconds(e)
    local timing=e.timing%256
    if timing==1 or timing==4 or timing==7 or timing==9 then return 'permanent' end
    if timing==2 or timing==5 or timing==8 then return 'equipped' end
    if timing==10 then return e.duration/15 end
    return e.duration
end
local function average(dice,sides) if dice>0 and sides>0 then return dice*(sides+1)/2 end return 0 end
-- The levels of the creatures an effect reaches, lowest and highest (nil: open), as the game
-- checks them (IESDP; GemRB's CheckLevel): an EFF file keeps them in fields of their own
-- (minLevel, maxLevel) and its dice are only dice; a spell's or an item's effect keeps them in
-- its dice fields (sides the lowest, dice the highest). Effects that roll their dice have none.
local function levels(e)
    if diced(e) then return nil,nil end
    local lo,hi=e.sides,e.dice
    if e.minLevel~=nil or e.maxLevel~=nil then lo,hi=e.minLevel,e.maxLevel end
    return number(lo) and lo>0 and lo or nil,number(hi) and hi>0 and hi or nil
end
local function inLevels(e,level)
    local lo,hi=levels(e)
    return not ((lo and level<lo) or (hi and level>hi))
end
local function saveNames(bits)
    local names
    for _,pair in ipairs(SAVES) do
        if math.floor(bits/pair[1])%2==1 then names=names or {};names[pair[2]]=true end
    end
    return names
end
-- Timings that apply an effect after its duration: delayed limited, permanent, while equipped.
local DELAYED={[3]=true,[4]=true,[5]=true}
-- Effects that come more than this many seconds after the cast (Spell Revisions' Haste casts its
-- fatigue when it ends) are kept apart in c.later: they are not what the spell does now.
M.laterThan=6
local function delay(e) return DELAYED[e.timing%256] and math.max(e.duration,0) or 0 end
local function longer(a,b)
    if a==nil then return b end
    if b==nil then return a end
    if a=='permanent' or b=='permanent' then return 'permanent' end
    if a=='equipped' or b=='equipped' then return 'equipped' end
    return math.max(a,b)
end

-- One effect's contribution to a role: who gets it, how likely, saves, level range, duration.
-- An area role also names the side filters of the areas it came through: 'allies', 'enemies' or
-- 'all' (the delivering area's, else the spell's own).
local function add(c,name,who,e,p)
    local r=c.roles[name]
    if not r then r={who={},kinds={},chance=0,power=0};c.roles[name]=r end
    r.who[who]=true
    if who=='area' then
        r.filters=r.filters or {}
        r.filters[c.filter or (c.area and c.area.filter) or 'all']=true
    end
    r.chance=math.max(r.chance,p)
    r.power=math.max(r.power,e.power)
    -- Magic resistance stops an effect that can be dispelled and does not ignore it (resistance
    -- field bit 0 without bit 1, IESDP); the role is resisted when any of its effects is.
    r.resisted=r.resisted==true or (number(e.resist) and e.resist%4==1) or false
    local saves=saveNames(e.save)
    if saves then
        r.save=r.save or {}
        for s in pairs(saves) do r.save[s]=true end
        if r.saveBonus==nil or e.saveBonus<r.saveBonus then r.saveBonus=e.saveBonus end
    end
    -- What lands on the caster was checked against its level already (walk).
    if who~='self' then
        local lo,hi=levels(e)
        if hi then r.maxLevel=math.min(r.maxLevel or hi,hi) end
        if lo then r.minLevel=math.max(r.minLevel or lo,lo) end
    end
    r.duration=longer(r.duration,seconds(e))
    if e.breakFree then r.breakFree=e.breakFree end
    return r
end
local function kind(c,name,label,who,e,p)
    local r=add(c,name,who,e,p);r.kinds[label]=true
    -- When each condition lands and each cure comes, by label and receiver, for finding a spell
    -- that ends its own condition (ownEnds).
    local marks=c.marks
    if marks and (name=='cure' or name=='disable' or name=='debuff') then
        local at=(c.delay or 0)+delay(e)
        local key=label..':'..who
        if name=='cure' then
            local list=marks.cures[key] or {}
            marks.cures[key]=list;list[#list+1]={at=at,onSave=e.onSave}
        elseif marks.inflicts[key]==nil or at<marks.inflicts[key] then marks.inflicts[key]=at end
    end
    return r
end
local function tally(t,key,value) t[key]=(t[key] or 0)+value end
-- What spell protections by level (opcodes 102, 199, 200, 201, 259) compare: the power of the
-- effects a spell delivers, not its level (IESDP), so removals that deliver power 0 pass them.
-- The highest power of effects that reach others, and whether all of them pass turnings,
-- deflections and traps (resistance field bit 2, EE). nil when none reaches others.
local function strength(effects)
    local power,unbounced
    for _,e in ipairs(type(effects)=='table' and effects or {}) do
        if type(e)=='table' and e.target~=1 and e.target~=9 and number(e.power) then
            power=math.max(power or 0,e.power)
            local passes=number(e.resist) and math.floor(e.resist/4)%2==1 or false
            if unbounced==nil then unbounced=passes else unbounced=unbounced and passes end
        end
    end
    return power,unbounced
end
local function set(r,field) r[field]=r[field] or {};return r[field] end
-- Whether a spell or item ability is hostile (bit 10 of its flags): a globe (opcode 102) keeps a
-- creature's own spell off it only then (IESDP).
local function hostile(flags) return number(flags) and math.floor(flags/1024)%2==1 or false end

-- A stat change helps or hurts by its sign; percentage modes compare against 100. Returns the role
-- and the change, nil when there is none.
local function modifier(c,e,who,p,label,good,bad,amount)
    local mode=e.p2%65536
    local delta=e.p1
    if mode==2 then delta=e.p1-100 end
    if delta==0 then return nil end
    local r=kind(c,delta>0 and good or bad,label,who,e,p)
    tally(set(r,'amounts'),label,math.abs(amount or delta)*p)
    return r,delta
end

-- A bonus or penalty by sign, for opcodes whose parameter 2 is not a modifier type.
local function signed(c,e,who,p,value,label,good,bad)
    if value==0 then return end
    local r=kind(c,value>0 and good or bad,label,who,e,p)
    tally(set(r,'amounts'),label,math.abs(value)*p)
end

local H={}
-- Damage of amount on average, dice of sides among it: the role adds it to its types and keeps the
-- roll itself (rolls: type, dice, sides, the flat rest, the chance it lands and how many times it
-- does), from which harm.spread spreads it over whole hit points.
local function damage(c,e,who,p,amount,label,dice,sides)
    local r=add(c,'damage',who,e,p)
    local times=c.times or 1
    r.kinds[label]=true
    tally(set(r,'types'),label,amount*p*times)
    r.amount=(r.amount or 0)+amount*p*times
    if e.save>0 and math.floor(e.special/256)%2==1 then r.saveForHalf=true end
    local n=number(dice) and dice>0 and number(sides) and sides>0 and dice or 0
    local s=n>0 and sides or 0
    local rolls=set(r,'rolls')
    rolls[#rolls+1]={label=label,dice=n,sides=s,flat=amount-average(n,s),p=p,times=times}
end
H[12]=function(c,e,who,p)
    local mode=e.p2%65536
    local label=DAMAGE[math.floor(e.p2/65536)] or 'other'
    if mode==0 then damage(c,e,who,p,math.max(e.p1,0)+average(e.dice,e.sides),label,e.dice,e.sides)
    else
        local r=add(c,'damage',who,e,p);r.kinds[label]=true;r.percent=math.max(r.percent or 0,e.p1)
    end
end
-- Damage over time counts its first minute: a fight is over sooner (threat.rest caps it there), and
-- a disease that runs for hours would otherwise seem to kill anyone. One without an end counts
-- that minute too.
M.overTime=60
-- How often a poison (25), a disease's damage (78 types 0 to 3) or a repeating EFF (272) strikes
-- in a second, by its type in parameter 2 (IESDP): 0 once a second when parameter 1 is not 0; 1
-- a hit point a second, nothing for 272; 2 parameter 1 every FM seconds; 3 once every parameter
-- 1 × FM seconds; 4 parameter 3 every parameter 1 × FM seconds, from EFF files only (25 and 272).
-- FM, the frequency multiplier, is parameter 4: 0 counts as 1, and spells and items have none.
-- The texts agree: Bolt of Biting (BOLT04, type 2, parameter 1 2) deals "30 points of poison
-- damage in 15 seconds", Poisoned Arrow (AROW14, type 3, parameter 1 3) "1 point of poison
-- damage every 3 seconds". Nil for other types (5 and up crash the game).
function M.perSecond(e)
    local t=e.p2%65536
    local fm=number(e.p4) and e.p4>0 and e.p4 or 1
    if t==0 then return e.p1~=0 and 1 or 0 end
    if t==1 then return e.opcode==272 and 0 or 1 end
    if t==2 then return math.max(e.p1,0)/fm end
    if t==3 then return e.p1>0 and 1/(e.p1*fm) or 0 end
    if t==4 and e.opcode~=78 then
        return e.p1>0 and number(e.p3) and math.max(e.p3,0)/(e.p1*fm) or 0
    end
    return nil
end
local function overTime(e)
    local s=seconds(e)
    if s=='permanent' or s=='equipped' then return M.overTime end
    return number(s) and math.min(s,M.overTime) or 0
end
H[25]=function(c,e,who,p)
    local amount=(M.perSecond(e) or 0)*overTime(e)
    if amount>0 then damage(c,e,who,p,amount,'poison') end
    kind(c,'debuff','poison',who,e,p)
end
H[17]=function(c,e,who,p)
    local mode=e.p2%65536
    if math.floor(e.p2/65536)%2==1 then kind(c,'raise','raise',who,e,p) end
    if mode==2 then
        if e.p1>0 then local r=kind(c,'heal','percent',who,e,p);r.percent=math.max(r.percent or 0,e.p1) end
    elseif mode==1 then
        if e.p1>0 then kind(c,'heal','set',who,e,p) end
    else
        local amount=e.p1+average(e.dice,e.sides)
        if amount>0 then local r=kind(c,'heal','hp',who,e,p);r.amount=(r.amount or 0)+amount*p
        elseif amount<0 then damage(c,e,who,p,-amount,'other') end
    end
end
H[32]=function(c,e,who,p) kind(c,'raise','raise',who,e,p) end
H[304]=H[32]
H[316]=function(c,e,who,p) kind(c,'heal','rest',who,e,p) end
local CURES={[2]='sleep',[4]='berserk',[11]='poison',[26]='curse',[43]='petrify',[46]='stun',
    [48]='silence',[75]='blind',[77]='feeblemind',[79]='disease',[81]='deaf',[161]='panic',
    [162]='hold',[212]='freedom',[224]='drain',[242]='confusion',[270]='pause',[329]='poison'}
for op,label in pairs(CURES) do H[op]=function(c,e,who,p) kind(c,'cure',label,who,e,p) end end

local DISABLES={[24]='panic',[38]='silence',[45]='stun',[76]='feeblemind',[128]='confusion',
    [134]='petrify',[154]='entangle',[157]='web',[165]='pause',[210]='stun',
    [211]='imprison',[213]='maze',[217]='sleep',[241]='charm',[247]='berserk',
    [264]='panic',[13]='death',[55]='death',[209]='death',[238]='death'}
for op,label in pairs(DISABLES) do H[op]=function(c,e,who,p) kind(c,'disable',label,who,e,p) end end
-- A creature with minimum hit points (opcode 208) is immune to death by opcode 13; slaying (55),
-- Power Word, Kill (209) and disintegration (238) still kill it (IESDP): slays.
for _,op in ipairs({55,209,238}) do
    local plain=H[op]
    H[op]=function(c,e,who,p) plain(c,e,who,p);c.roles.disable.slays=true end
end
-- Power Word, Kill (209) and Power Word, Stun (210) work only on a creature with fewer than 60 or
-- 90 hit points left (the engine's own limits): belowHp.
local function below(op,limit)
    local plain=H[op]
    H[op]=function(c,e,who,p)
        plain(c,e,who,p)
        local r=c.roles.disable
        if r then r.belowHp=math.max(r.belowHp or 0,limit) end
    end
end
below(209,60);below(210,90)
-- A short pause of the caster itself (two seconds after Spell Revisions' Shout and Cone of
-- Cold) is a cost of casting, not harm: it is kept as c.pause, in seconds. A longer one stays a
-- disable on the caster.
M.castingPause=6
H[165]=function(c,e,who,p)
    local span=seconds(e)
    if who=='self' and number(span) and span<=M.castingPause then c.pause=math.max(c.pause or 0,span);return end
    kind(c,'disable','pause',who,e,p)
end
H[5]=function(c,e,who,p) kind(c,'disable','charm',who,e,p) end
H[135]=function(c,e,who,p)
    if who=='self' then kind(c,'buff','shapechange',who,e,p) else kind(c,'disable','polymorph',who,e,p) end
end
-- The creature that holds the time stop is immune to it; everyone else stops, allies too.
H[231]=function(c,e,who,p) kind(c,'disable','timestop',who=='self' and 'everyone' or who,e,p) end
H[39]=function(c,e,who,p)
    local r=kind(c,'disable','sleep',who,e,p)
    -- Parameter 2 is 0 when the sleeper wakes on damage (EE).
    if e.p2==0 then r.wakesOnDamage=true else r.staysAsleep=true end
end
-- A hold that names a creature type (IDS file in parameter 2, a non-zero entry in parameter 1)
-- holds only that type: walk makes the type a condition of the hold.
local function hold(c,e,who,p) kind(c,'disable','hold',who,e,p) end
H[109]=hold;H[175]=hold;H[185]=hold
local TYPED={[109]=true,[175]=true,[185]=true}
H[145]=function(c,e,who,p) kind(c,'disable','nocast',who,e,p) end
local function berserk(c,e,who,p)
    if who=='self' then kind(c,'buff','berserk',who,e,p) else kind(c,'disable','berserk',who,e,p) end
end
H[3]=berserk;H[246]=berserk

local DEBUFFS={[40]='slow',[74]='blind',[80]='deaf',[158]='grease',[235]='knockback'}
for op,label in pairs(DEBUFFS) do H[op]=function(c,e,who,p) kind(c,'debuff',label,who,e,p) end end
H[216]=function(c,e,who,p) local r=kind(c,'debuff','drain',who,e,p);tally(set(r,'amounts'),'drain',math.abs(e.p1)*p) end
-- Casting failure (IESDP opcode 60): parameter 1 is the per cent, parameter 2 the spells it hits,
-- 0 and 3 wizard spells, 1 and 4 priest spells, 2 and 5 innate abilities (3 to 5 as dead magic).
-- miscastBy tallies the per cent by kind of spell; it adds up with itself and with deafness.
local MISCAST={[0]='arcane',[1]='divine',[2]='innate',[3]='arcane',[4]='divine',[5]='innate'}
H[60]=function(c,e,who,p)
    if e.p1<=0 then return end
    local r=kind(c,'debuff','miscast',who,e,p)
    local label=MISCAST[e.p2%65536]
    if label then tally(set(r,'miscastBy'),label,math.min(e.p1,100)*p) end
end
-- Negative chant (IESDP opcode 137) lowers luck by the first byte of parameter 1 (below 0 it
-- raises it); chants do not add up.
H[137]=function(c,e,who,p)
    local v=e.p1%256
    if v>=128 then v=v-256 end
    if v<0 then kind(c,'buff','chant',who,e,p);return end
    local r=kind(c,'debuff','chant',who,e,p)
    if v>0 then tally(set(r,'amounts'),'luck',v*p) end
end
-- Disease (IESDP opcode 78) by its type in parameter 2: 0 to 3 deal poison damage as often as
-- M.perSecond says, as opcode 25 does; 4 to 9 lower strength, dexterity, constitution,
-- intelligence, wisdom or charisma by parameter 1 (below 0 they raise it); 10 slows; 11 and 12
-- are Mold Touch, magic damage of 1d6, or of parameter 1 d6 losing a die a round; 13 is
-- Contagion, strength, dexterity and charisma lower by parameter 1 and slowed. Each keeps the
-- disease label, which Cure Disease takes away.
local DISEASE_STATS={[4]={'strength'},[5]={'dexterity'},[6]={'constitution'},[7]={'intelligence'},
    [8]={'wisdom'},[9]={'charisma'},[13]={'strength','dexterity','charisma'}}
H[78]=function(c,e,who,p)
    local t=e.p2%65536
    kind(c,'debuff','disease',who,e,p)
    if t<=3 then
        local amount=(M.perSecond(e) or 0)*overTime(e)
        if amount>0 then damage(c,e,who,p,amount,'poison') end
    elseif t==11 then damage(c,e,who,p,3.5,'magic',1,6)
    elseif t==12 then local n=math.max(0,e.p1)*(math.max(0,e.p1)+1)/2;damage(c,e,who,p,3.5*n,'magic',n,6) end
    if t==10 or t==13 then kind(c,'debuff','slow',who,e,p) end
    for _,label in ipairs(DISEASE_STATS[t] or {}) do
        if e.p1>0 then local r=kind(c,'debuff',label,who,e,p);tally(set(r,'amounts'),label,e.p1*p)
        elseif e.p1<0 then kind(c,'buff',label,who,e,p) end
    end
end

-- Strength (44) counts through the game's strength tables (combat-intent/defence.lua): the points a
-- spell adds or takes (amounts.strength) and the score it sets (strengthSet, a buff's highest and a
-- debuff's lowest: the giant strength potions set 19 to 25). A percentage of it (mode 2) counts by
-- its sign alone, and so does Bull's Strength (mode 3, IESDP: a bonus by class from CLSSPLAB).
for op,label in pairs(STATS) do
    H[op]=function(c,e,who,p)
        local mode=e.p2%65536
        if (op==15 or op==44) and mode==3 then kind(c,'buff',label,who,e,p);return end
        if mode==1 then
            local r,good
            if e.p1>=15 then r,good=kind(c,'buff',label,who,e,p),true elseif e.p1<=8 then r=kind(c,'debuff',label,who,e,p) end
            if r and op==44 then r.strengthSet=r.strengthSet and (good and math.max or math.min)(r.strengthSet,e.p1) or e.p1 end
            return
        end
        if op==44 and mode==2 then
            if e.p1~=100 then kind(c,e.p1>100 and 'buff' or 'debuff',label,who,e,p) end
            return
        end
        modifier(c,e,who,p,label,'buff','debuff')
    end
end
-- Exceptional strength (97), which the game counts only at strength 18 (STRMODEX): the points a spell
-- adds or takes (amounts.strengthExtra) and the highest it sets (strengthExtraSet); a percentage of it
-- by its sign alone.
H[97]=function(c,e,who,p)
    local mode=e.p2%65536
    if mode==1 then
        if e.p1>0 then local r=kind(c,'buff','strengthExtra',who,e,p);r.strengthExtraSet=math.max(r.strengthExtraSet or 0,e.p1) end
        return
    end
    if mode==2 then
        if e.p1~=100 then kind(c,e.p1>100 and 'buff' or 'debuff','strengthExtra',who,e,p) end
        return
    end
    modifier(c,e,who,p,'strengthExtra','buff','debuff')
end
for op in pairs(TOHIT) do H[op]=function(c,e,who,p) modifier(c,e,who,p,'thac0','buff','debuff') end end
-- Opcode 54 changes the base THAC0 by a bonus (type 0: more is better), or the value itself, set
-- (type 1) or scaled (type 2), where less is better (IESDP; the game's Potion of Power scales it
-- to 80 per cent). A value set below the worst THAC0 is a buff and keeps the best one set
-- (thac0Set), one set to the worst or above a debuff; thac0Percent tallies the per cent taken off
-- (buff) or put on (debuff).
M.worstThac0=20
H[54]=function(c,e,who,p)
    local mode=e.p2%65536
    if mode==1 then
        local good=e.p1<M.worstThac0
        local r=kind(c,good and 'buff' or 'debuff','thac0',who,e,p)
        r.thac0Set=good and math.min(r.thac0Set or e.p1,e.p1) or math.max(r.thac0Set or e.p1,e.p1)
    elseif mode==2 then
        if e.p1==100 then return end
        local r=kind(c,e.p1<100 and 'buff' or 'debuff','thac0',who,e,p)
        tally(set(r,'amounts'),'thac0Percent',math.abs(100-e.p1)*p)
    else modifier(c,e,who,p,'thac0','buff','debuff') end
end
for op in pairs(WEAPON_DAMAGE) do H[op]=function(c,e,who,p) modifier(c,e,who,p,'damage','buff','debuff') end end
H[250]=function(c,e,who,p) modifier(c,e,who,p,'damage','buff','debuff') end
H[1]=function(c,e,who,p) modifier(c,e,who,p,'attacks','buff','debuff') end
H[18]=function(c,e,who,p) if e.p1>0 then kind(c,'buff','hp',who,e,p) elseif e.p1<0 then kind(c,'debuff','hp',who,e,p) end end
H[22]=function(c,e,who,p) modifier(c,e,who,p,'luck','buff','debuff') end
H[133]=H[22]
H[98]=function(c,e,who,p) kind(c,'buff','regeneration',who,e,p) end
H[191]=function(c,e,who,p) modifier(c,e,who,p,'castingLevel','buff','debuff') end
H[189]=function(c,e,who,p)
    local mode=e.p2%65536
    if mode==2 or (mode==1 and e.p1<5) then kind(c,'buff','castingSpeed',who,e,p)
    elseif mode==1 then kind(c,'debuff','castingSpeed',who,e,p)
    else signed(c,e,who,p,e.p1,'castingSpeed','buff','debuff') end
end
-- Aura cleansing (Improved Alacrity): the next cast need not wait for the round to end.
H[188]=function(c,e,who,p) kind(c,'buff','castingSpeed',who,e,p);kind(c,'buff','alacrity',who,e,p) end
-- Critical hits on a roll of 20 less parameter 1 (parameter 2 says which hand, not a type).
H[301]=function(c,e,who,p) signed(c,e,who,p,e.p1,'critical','buff','debuff') end
H[344]=function(c,e,who,p) kind(c,'buff','enchantment',who,e,p) end
H[345]=H[344]
-- An empty item reference creates no weapon (IESDP warns that the game can crash on it): a kit
-- mod's Shocking Grasp has one, in the spell that gives its kit the charge in the fist instead.
H[111]=function(c,e,who,p) if e.res~='' then kind(c,'buff','weapon',who,e,p) end end
H[248]=function(c,e,who,p) kind(c,'buff','onHit',who,e,p) end
H[249]=H[248]
-- A spell cast at each creature its holder hits critically (onCrit, F2e).
H[341]=function(c,e,who,p) kind(c,'buff','onCrit',who,e,p) end
H[303]=function(c,e,who,p) kind(c,'buff','backstab',who,e,p) end
H[42]=function(c,e,who,p) if e.p1>0 then kind(c,'buff','slots',who,e,p) end end
H[62]=H[42]
H[261]=function(c,e,who,p) kind(c,'buff','restore',who,e,p) end
H[193]=function(c,e,who,p) kind(c,'buff','seeInvisible',who,e,p) end
-- Haste (IESDP opcode 16): parameter 2 is 0 for a normal haste (an attack more a round), 1 for an
-- improved one (twice the attacks) and 2 for a weak one, which hastens movement alone.
H[16]=function(c,e,who,p)
    if e.p2==2 then kind(c,'buff','movement',who,e,p);return end
    local r=kind(c,'buff','haste',who,e,p)
    if e.p2==1 then r.kinds.improvedHaste=true end
end
H[317]=H[16]
local GROUP_BUFFS={[129]='aid',[130]='bless',[131]='chant',[132]='raise'}
for op,label in pairs(GROUP_BUFFS) do H[op]=function(c,e,who,p) kind(c,'buff',label,who,e,p) end end
local function movement(c,e,who,p)
    local mode=e.p2%65536
    if mode==1 then
        if e.p1==0 then kind(c,'disable','root',who,e,p) end
        return
    end
    modifier(c,e,who,p,'movement','buff','debuff')
end
H[126]=movement;H[176]=movement
-- More fatigue is worse; setting it to 0 rests the target.
H[93]=function(c,e,who,p)
    if e.p2%65536==1 then
        if e.p1==0 then kind(c,'cure','fatigue',who,e,p) else kind(c,'debuff','fatigue',who,e,p) end
        return
    end
    modifier(c,e,who,p,'fatigue','debuff','buff')
end
-- Item in a slot (SLOTS.IDS): weapon slots 34-38 and the fist, armour and shield, ammunition.
H[143]=function(c,e,who,p)
    local slot=e.p1
    local label=(slot==10 or (slot>=34 and slot<=38)) and 'weapon' or (slot==1 or slot==9) and 'armor'
        or (slot>=11 and slot<=14) and 'ammo' or 'item'
    local r=kind(c,'buff',label,who,e,p)
    if e.res~='' then set(r,'items')[e.res]=slot end
end
-- Against one creature type (IDS entry and file); 178 and 179 keep the amount in special.
H[178]=function(c,e,who,p) signed(c,e,who,p,s32(e.special),'thac0VsType','buff','debuff') end
H[179]=function(c,e,who,p) signed(c,e,who,p,s32(e.special),'damageVsType','buff','debuff') end
H[219]=function(c,e,who,p) kind(c,'protection','armorVsType',who,e,p) end
-- Percent more (or less) damage dealt of the damage type in parameter 2 (0 all, 1 to 6 fire,
-- cold, electricity, acid, magic and poison, 7 to 10 slashing, piercing, crushing and missile;
-- IESDP): damagePercentBy tallies the per cent by type, as Kai raises three of them.
H[332]=function(c,e,who,p)
    if e.p1==0 then return end
    local r=kind(c,e.p1>0 and 'buff' or 'debuff','damagePercent',who,e,p)
    tally(set(r,'damagePercentBy'),e.p2,math.abs(e.p1)*p)
end
H[222]=function(c,e,who,p) kind(c,'debuff','teleportField',who,e,p) end
-- Wild magic makes the receiver's own spells surge.
H[280]=function(c,e,who,p) if who~='self' then kind(c,'debuff','wildSurge',who,e,p) end end
-- The receiver turns undead like the modal action, so the undead around it are hit.
H[334]=function(c,e,who,p) kind(c,'disable','turnUndead',who=='self' and 'area' or who,e,p) end
-- Removes the receiver from the game (Banishment's last step).
H[168]=function(c,e,who,p) if who~='self' then kind(c,'removal','destroy',who,e,p) end end
H[214]=function(c,e,who,p) c.choice=true end

-- Protections.
for op,label in pairs(RESIST) do
    H[op]=function(c,e,who,p)
        if e.p2%65536==2 then return end
        if e.p1>0 then local r=kind(c,'protection','resist',who,e,p);tally(set(r,'resist'),label,e.p1*p)
        elseif e.p1<0 then local r=kind(c,'debuff','resist',who,e,p);tally(set(r,'resist'),label,-e.p1*p) end
    end
end
-- Saving throw changes (IESDP: 33 death, 34 wands, 35 polymorph, 36 breath, 37 spells, 325 all
-- five, 346 the spells of one school): saveBy tallies the points by save, which a spell's own saves
-- meet; saves keeps their sum.
local SAVE_BY={[33]={'death'},[34]={'wand'},[35]={'poly'},[36]={'breath'},[37]={'spell'},
    [325]={'death','wand','poly','breath','spell'}}
for op in pairs(SAVE_MODS) do
    H[op]=function(c,e,who,p)
        local r,delta=modifier(c,e,who,p,'saves','protection','debuff')
        if not r then return end
        for _,name in ipairs(SAVE_BY[op] or {}) do tally(set(r,'saveBy'),name,math.abs(delta)*p) end
    end
end
H[166]=function(c,e,who,p) modifier(c,e,who,p,'magicResistance','protection','debuff') end
H[0]=function(c,e,who,p)
    if e.p2==16 then kind(c,'protection','armor',who,e,p);return end
    signed(c,e,who,p,e.p1,'armor','protection','debuff')
end
H[218]=function(c,e,who,p)
    local r=kind(c,'protection','stoneskin',who,e,p)
    local skins=e.p2==1 and average(e.dice,e.sides) or e.p1
    r.stoneskin=math.max(r.stoneskin or 0,skins)
end
H[314]=function(c,e,who,p) local r=kind(c,'protection','stoneskin',who,e,p);r.stoneskin=math.max(r.stoneskin or 0,e.p1) end
H[119]=function(c,e,who,p) kind(c,'protection','mirror',who,e,p) end
H[159]=function(c,e,who,p) local r=kind(c,'protection','mirror',who,e,p);r.mirror=math.max(r.mirror or 0,e.p1) end
local PROTECTION_KINDS={[65]='blur',[69]='nondetection',[100]='creatureType',
    [153]='sanctuary',[163]='freeAction',[208]='minimumHp',[292]='backstab',
    [297]='turnUndead',[299]='chaosShield',[310]='timestop',[322]='evasion',[335]='sevenEyes'}
for op,label in pairs(PROTECTION_KINDS) do H[op]=function(c,e,who,p) kind(c,'protection',label,who,e,p) end end
-- What 321 takes away from its receiver, by the resource that put it there: strips.res, which
-- neither harms nor helps. A creature's minimum hit points end with the effects that set them
-- (combat-intent/targeting.lua's floor): SCS's fire, acid and cold spells take away troll
-- regeneration this way before they hit.
H[321]=function(c,e,who,p)
    if type(e.res)~='string' or e.res=='' then return end
    set(add(c,'strips',who,e,p),'res')[e.res:upper()]=true
end
-- Invisibility; parameter 2 = 1 is Improved Invisibility, which attacks do not break.
H[20]=function(c,e,who,p)
    local r=kind(c,'protection','invisible',who,e,p)
    if e.p2==1 then r.kinds.improvedInvisible=true end
end
local function blocks(c,e,who,p,how,field,key,count)
    local r=kind(c,'protection',how,who,e,p)
    local t=set(set(r,how..'By'),field)
    t[key]=math.max(t[key] or 0,count or 1)
end
H[83]=function(c,e,who,p) blocks(c,e,who,p,'immune','projectiles',e.p2) end
H[120]=function(c,e,who,p)
    local r=kind(c,'protection','weapons',who,e,p)
    set(r,'weapons')[e.p2]=e.p2==0 and e.p1 or true
end
H[101]=function(c,e,who,p) blocks(c,e,who,p,'immune','opcodes',e.p2) end
H[102]=function(c,e,who,p) blocks(c,e,who,p,'immune','levels',e.p1) end
H[197]=function(c,e,who,p) blocks(c,e,who,p,'bounce','projectiles',e.p2) end
H[198]=function(c,e,who,p) blocks(c,e,who,p,'bounce','opcodes',e.p2) end
H[199]=function(c,e,who,p) blocks(c,e,who,p,'bounce','levels',e.p2) end
H[200]=function(c,e,who,p) blocks(c,e,who,p,'bounce','levels',e.p2,e.p1) end
H[201]=function(c,e,who,p) blocks(c,e,who,p,'deflect','levels',e.p2,e.p1) end
H[259]=function(c,e,who,p) blocks(c,e,who,p,'trap','levels',e.p2,e.p1) end
H[202]=function(c,e,who,p) blocks(c,e,who,p,'bounce','schools',e.p2) end
H[203]=function(c,e,who,p) blocks(c,e,who,p,'bounce','secondaries',e.p2) end
H[204]=function(c,e,who,p) blocks(c,e,who,p,'immune','schools',e.p2) end
H[205]=function(c,e,who,p) blocks(c,e,who,p,'immune','secondaries',e.p2) end
H[223]=function(c,e,who,p) blocks(c,e,who,p,'immune','schools',e.p2,e.p1) end
H[226]=function(c,e,who,p) blocks(c,e,who,p,'immune','secondaries',e.p2,e.p1) end
H[227]=function(c,e,who,p) blocks(c,e,who,p,'bounce','schools',e.p2,e.p1) end
H[228]=function(c,e,who,p) blocks(c,e,who,p,'bounce','secondaries',e.p2,e.p1) end
-- Protection from a named resource. Naming the spell itself is SCS's and SR's guard against
-- stacking, not a protection.
local function fromSpell(how)
    return function(c,e,who,p)
        if e.res=='' or e.res==c.self or e.res==c.owner then return end
        blocks(c,e,who,p,how,'spells',e.res)
    end
end
H[206]=fromSpell('immune');H[207]=fromSpell('bounce');H[318]=fromSpell('immune');H[324]=fromSpell('immune')

-- Removal of protections and states.
H[58]=function(c,e,who,p)
    local r=kind(c,'removal','dispel',who,e,p)
    local mode=e.p2%65536
    r.dispel={mode=mode==0 and 'always' or mode==1 and 'caster' or 'fixed',level=e.p1}
end
-- 220 and 221 take every spell of a school or secondary type up to a power level (schools,
-- secondaries: type to level); 229 and 230 only the first such spell and the first such item they
-- find (single.schools, single.secondaries; IESDP).
local function strip(field,one)
    return function(c,e,who,p)
        local r=kind(c,'removal',field,who,e,p)
        local t=one and set(set(r,'single'),field) or set(r,field)
        t[e.p2]=math.max(t[e.p2] or 0,e.p1)
    end
end
H[220]=strip('schools');H[229]=strip('schools',true);H[221]=strip('secondaries');H[230]=strip('secondaries',true)
-- 337 takes the effects of an opcode (parameter 2) whose parameter 2 is parameter 1, any for -1:
-- opcodes holds each opcode's set of such values.
H[337]=function(c,e,who,p)
    local r=kind(c,'removal','opcodes',who,e,p)
    local ops=set(r,'opcodes')
    ops[e.p2]=ops[e.p2] or {};ops[e.p2][e.p1]=true
end
local REMOVES={[47]='invisibility',[68]='summons',[70]='nondetection',[116]='invisibility',
    [136]='invisibility',[160]='sanctuary',[273]='cloud'}
for op,label in pairs(REMOVES) do H[op]=function(c,e,who,p) kind(c,'removal',label,who,e,p) end end

-- Summons and movement.
local function summon(c,e,who,p)
    local r=kind(c,'summon','creature',who,e,p)
    if e.res~='' then tally(set(r,'creatures'),e.res,p) end
    r.count=(r.count or 0)+p
    return r
end
-- Modes 0, 1 and 3 align the summons with the receiver, mode 5 against it (so a summons cast on
-- oneself is hostile), and the other modes take its side from its own file (fromFile; IESDP: Wish's
-- genie is neutral).
H[67]=function(c,e,who,p)
    local r=summon(c,e,who,p)
    if e.p2==5 and who=='self' then r.hostile=true end
    if e.p2~=0 and e.p2~=1 and e.p2~=3 and e.p2~=5 and e.res~='' then set(r,'fromFile')[e.res]=true end
end
-- Types 0-2 remove or kill the creature that is replaced: on the caster itself that is a change of
-- shape (transform), no summons. The new creature's side is its file's.
H[151]=function(c,e,who,p)
    if e.p2<=2 and who=='self' then kind(c,'summon','transform',who,e,p);return end
    local r=summon(c,e,who,p)
    if e.res~='' then set(r,'fromFile')[e.res]=true end
    if e.p2<=2 then kind(c,'removal','replace',who,e,p) end
end
-- Types 5-9 summon from the hostile tables.
H[127]=function(c,e,who,p)
    local r=kind(c,'summon','monsters',who,e,p);r.count=(r.count or 0)+math.max(e.p1,1)*p
    if e.p2>=5 and e.p2<=9 then r.hostile=true end
end
H[331]=function(c,e,who,p) local r=kind(c,'summon','monsters',who,e,p);r.count=(r.count or 0)+math.max(e.p1,1)*p end
H[236]=function(c,e,who,p) kind(c,'summon','image',who,e,p) end
H[124]=function(c,e,who,p) kind(c,'move','teleport',who,e,p) end
H[274]=H[124]
H[232]=function(c,e,who,p) kind(c,'prepare','contingency',who,e,p) end
H[234]=H[232]
for _,op in ipairs({256,257,258,260}) do H[op]=function(c,e,who,p) kind(c,'prepare','sequencer',who,e,p) end end

-- Who receives an effect, from its target field and where its delivery lands. Inside the spell an
-- opcode 326 applies (c.remap, IESDP), "self" is the creature the 326 lands on, and so is "original
-- caster" when that spell has no projectile (0).
local function receiver(c,e,where)
    local t=e.target
    local remap=c.remap
    if t==1 then return remap and remap.self or 'self' end
    if t==9 then return remap and remap.caster or 'self' end
    if t==2 then return where end
    if t==3 then return 'party' end
    if t==4 or t==8 then return 'everyone' end
    if t==5 then return 'nonparty' end
    if t==6 then return 'casterGroup' end
    if t==7 then return 'targetGroup' end
end

function M.abilityForLevel(record,level)
    local abilities=type(record)=='table' and record.abilities
    if type(abilities)~='table' or #abilities==0 then return nil end
    local chosen=1
    for i,ability in ipairs(abilities) do
        if type(ability.minLevel)=='number' and level>=ability.minLevel then chosen=i
        elseif i>1 then break end
    end
    return chosen
end

-- An area projectile's shape and whom it spares. One that explodes again and again (clouds and
-- storms) also gives its explosions (the repetitions, or the caster's casting level where area
-- flag 8 or 9 says so, IESDP; level is the level the spell is classified at), the seconds between
-- them (every delay+1 ticks, lab batch H) and whether its first explosion reaches no one and does
-- not count (flag 14, skip first condition). The first one goes off where it lands (lab, zone
-- probe: Stinking Cloud's repetitions dropped from 10 to 9 on arrival).
local function area(projectile,level)
    if type(projectile)~='table' or projectile.type~=3 then return nil end
    local flags=projectile.areaFlags or 0
    local function bit(v,n) return math.floor(v/2^n)%2==1 end
    local a={radius=projectile.radius or 0,trigger=projectile.trigger or 0}
    a.filter='all'
    if bit(flags,6) then a.filter=bit(flags,7) and 'allies' or 'enemies' end
    if bit(flags,11) then a.cone=projectile.coneWidth or 0 end
    if bit(projectile.flags or 0,4) then a.skipsCenter=true end
    local ext=projectile.extFlags or 0
    if bit(ext,30) then a.conditions=true end
    if bit(ext,31) then a.casterAffected=true end
    if bit(ext,14) then a.line=true end
    if bit(ext,15) then a.rectangle=true end
    if bit(flags,15) then a.maxTargets=average(projectile.targetDice or 0,projectile.targetSides or 0) end
    local explosions=number(projectile.repeats) and projectile.repeats or 1
    if bit(flags,8) or bit(flags,9) then explosions=number(level) and level or 1 end
    if explosions>1 and number(projectile.delay) and projectile.delay>=0 then
        a.explosions=math.floor(explosions)
        a.every=(projectile.delay+1)/15
        if bit(flags,14) then a.skipFirst=true end
    end
    return a
end

local function valid(e)
    for _,f in ipairs({'opcode','target','power','p1','p2','timing','duration','prob1','prob2',
        'dice','sides','save','saveBonus','special'}) do
        if not number(e[f]) then return false end
    end
    return type(e.res)=='string'
end

-- Creature conditions: an IDS file and entry ({ids,entry}), a SPLPROT row and value
-- ({row,value}; flip when the check swaps source and target; caster when the caster is checked,
-- whoever receives what follows: an opcode 326 that lands on the caster), or levels
-- ({minLevel,maxLevel}, nil for an open end). c.conditions lists each once, and c.when holds the
-- positions of those the effects being walked depend on (all must hold).
function M.conditionKey(f)
    if f.row~=nil then
        return 'row:'..tostring(f.row)..':'..tostring(f.value)..(f.flip and ':flip' or '')..(f.caster and ':caster' or '')
    end
    if f.minLevel~=nil or f.maxLevel~=nil then return 'level:'..tostring(f.minLevel or 0)..':'..tostring(f.maxLevel or 0) end
    return 'ids:'..tostring(f.ids)..':'..tostring(f.entry)
end
local function condition(c,f)
    local key=M.conditionKey(f)
    local n=c.conditionAt[key]
    if not n then
        c.conditions[#c.conditions+1]=f
        n=#c.conditions;c.conditionAt[key]=n
    end
    return n
end
local function within(when,n)
    local out={}
    for _,v in ipairs(when or {}) do
        if v==n then return when end
        out[#out+1]=v
    end
    out[#out+1]=n
    return out
end
-- when, and e's own levels: a creature outside them never gets e, nor what e delivers. Spell
-- Revisions' Color Spray weakens creatures of level 1 further and blinds up to the caster's level
-- plus two; Artisan's Kitpack's Deathless Master's Touch casts one of four spells by the target's
-- level.
local function leveled(c,e,when)
    local lo,hi=levels(e)
    if not (lo or hi) then return when end
    c.conditional=true
    return within(when,condition(c,{minLevel=lo,maxLevel=hi}))
end

-- The walk node of a spell on the current path (the spell itself or one it comes through).
local function ancestor(c,res)
    local node=c.node
    while node do
        if c.nodes[node].res==res then return node end
        node=c.nodes[node].parent
    end
end
-- An immunity that keeps creatures of a kind out of what follows. Returns what it cuts (an
-- opcode, or the walk node of the spell it names) with the conditions it needs (when), or nil:
-- - under a creature condition, an immunity to an opcode, or a protection from the spell
--   itself or a spell it comes through (206; 318 and 324 with SPLPROT row 0, anyone);
-- - anywhere, a 318 or 324 that names the spell or a spell it comes through with another
--   SPLPROT row (row in parameter 2, value in parameter 1): the spell's own immunity check.
--   Without a condition, row 0 is SCS's and SR's guard against stacking, not an immunity.
local function exclusion(c,e)
    local op=e.opcode
    -- An immunity within levels is one under a creature condition.
    local when=leveled(c,e,c.when)
    if op==101 then return when and {opcode=e.p2,when=when} or nil end
    if e.res=='' or not (op==206 or op==318 or op==324) then return nil end
    local node=ancestor(c,e.res)
    if not node then return nil end
    if op~=206 and e.p2~=0 then return {node=node,when=within(when,condition(c,{row=e.p2,value=e.p1}))} end
    return when and {node=node,when=when} or nil
end

-- An effect without a saving throw of its own, given the one of the delivery that brings it.
local function inherited(e,from)
    local x={}
    for k,v in pairs(e) do x[k]=v end
    x.save=e.save+from.save%32
    x.saveBonus=from.saveBonus
    return x
end

-- A weapon the spell puts in the caster's hand (opcode 111), by the created item's first
-- ability: how it attacks, how many hits it lasts and what a hit delivers (strike: that ability
-- classified at the caster's level), with the item's flags and enchantment for weapon
-- immunities and the attacks a round the item sets or adds while equipped (opcode 1: SR's Melf's
-- Minute Meteors set 5). It lasts one hit when the hit takes the item away (opcode
-- 112: a touch charge), its charges times the items made when a spent charge makes it vanish,
-- else as long as the item lasts (uses nil).
local ATTACKS={[1]='melee',[2]='ranged',[3]='magical',[4]='launcher'}
local function uses(ability,count)
    for _,x in ipairs(type(ability.effects)=='table' and ability.effects or {}) do
        if type(x)=='table' and x.opcode==112 then return 1 end
    end
    if number(ability.charges) and ability.charges>0 and ability.depletion==1 then
        return math.max(number(count) and count or 1,1)*ability.charges
    end
end
local function weapon(c,state,e,p)
    local item=state.lookup('ITM',e.res)
    local ability=type(item)=='table' and type(item.abilities)=='table' and item.abilities[1]
    if type(ability)~='table' then return state.miss(c,'ITM',e.res) end
    local n=uses(ability,e.p1)
    local aprSet,aprAdd
    for _,x in ipairs(type(item.equipping)=='table' and item.equipping or {}) do
        if type(x)=='table' and x.opcode==1 and number(x.p1) then
            if x.p2==1 then aprSet=x.p1 elseif x.p2==0 then aprAdd=(aprAdd or 0)+x.p1 end
        end
    end
    c.weapons=c.weapons or {}
    c.weapons[#c.weapons+1]={item=type(item.resref)=='string' and item.resref or e.res,
        attack=ATTACKS[ability.attackType] or 'none',range=ability.range,speed=ability.speed,
        toHit=ability.thac0,dice=ability.dice,sides=ability.sides,bonus=ability.damageBonus,
        damageType=ability.damageType,flags=item.flags,enchantment=item.enchantment,aprSet=aprSet,aprAdd=aprAdd,
        itemType=item.itemType,uses=n,touch=(ability.attackType==1 and n==1) or nil,
        seconds=seconds(e),chance=p,strike=M.classify(item,1,state.lookup,{level=state.level,weapons=false})}
end

-- An on-hit effect (opcode 248 for melee hits, 249 for missiles and thrown weapons; F2a): while it
-- lasts, the EFF it names lands on each creature its holder's weapon hits, with the file's own
-- timing and duration; 248 with bit 2 of parameter 2 only on hits with fists (IESDP). c.hits lists
-- them: how the holder must hit, who holds it (who), the chance and seconds, and what one hit
-- delivers (strike: the EFF classified as cast at the creature hit). A hit that takes the spell
-- holding the on-hit effect off its holder again, by opcode 321 (the game matches the spell an
-- effect comes from, not the spells that cast that one), is its only one (once), and so for every
-- on-hit effect of that spell, as they go together (spent): Smite Evil ends with its first hit, and
-- a kit's Poison Weapon poisons with one 248 and ends with another. An active effect read from a
-- creature names that spell as its source (source: kept, for an enemy that carries what the hit
-- brings already). An EFF that cannot be read leaves the spell as it is (its roles are whole) and
-- only the hit unknown: approximate, with the reason.
local function holding(c,e,strike)
    local own,source={},nil
    for _,res in ipairs({c.owner or false,e.source or false}) do
        if type(res)=='string' and res~='' then own[res:upper()]=true;source=res:upper() end
    end
    local ends={}
    local strips=strike.roles.strips
    if type(strips)=='table' and type(strips.who)=='table' and strips.who.self and type(strips.res)=='table' then
        for res in pairs(strips.res) do ends[res]=true end
    end
    return own,ends,source
end
local function onHit(c,state,e,p,who)
    local eff=state.lookup('EFF',e.res)
    if type(eff)~='table' or type(eff.effect)~='table' then
        c.approximate=true;c.reasons['missing:EFF:'..tostring(e.res)]=true
        return
    end
    local inner={}
    for k,v in pairs(eff.effect) do inner[k]=v end
    inner.target=2
    local strike=M.classify({kind='EFF',resref=e.res,abilities={{target=1,range=0,projectile=0,effects={inner}}}},1,
        state.lookup,{level=state.level,weapons=false})
    local own,ends,source=holding(c,e,strike)
    c.hits=c.hits or {}
    c.hits[#c.hits+1]={eff=e.res,melee=e.opcode==248,ranged=e.opcode==249,
        fists=(e.opcode==248 and math.floor(e.p2/4)%2==1) or nil,who=who,chance=p,seconds=seconds(e),once=false,
        strike=strike,source=source,own=own,ends=ends}
end
-- A critical hit effect (opcode 341, F2e; IESDP): while it lasts, the spell it names is cast at each
-- creature its holder hits critically, with either hand (parameter 2 at 0) or with the weapon that
-- holds it alone (1: the item it comes from, as an active effect names it; weapon); from an EFF
-- file only with weapons of one category (parameter 3, ITEMCAT.IDS: 28 for fists and claws;
-- category); with any attack (special 0), melee (1), ranged (2) or magical ones (3, which count
-- nothing here). c.hits lists it as an on-hit effect that critical hits alone bring (critical):
-- what one delivers is the spell at the holder's level, classified as cast at the creature hit
-- without a projectile, so what it puts on its caster lands on the holder, and one that takes its
-- own spell off the holder again comes once (spent), as for onHit. A spell that cannot be read
-- leaves the hit unknown.
local CRIT_ATTACK={[0]={melee=true,ranged=true},[1]={melee=true},[2]={ranged=true}}
local function onCrit(c,state,e,p,who)
    local spell=state.lookup('SPL',e.res)
    local index=type(spell)=='table' and M.abilityForLevel(spell,state.level)
    local ability=index and spell.abilities[index]
    if type(ability)~='table' then
        c.approximate=true;c.reasons['missing:SPL:'..tostring(e.res)]=true
        return
    end
    local strike=M.classify({kind='SPL',resref=type(spell.resref)=='string' and spell.resref or e.res,level=spell.level,
        school=spell.school,secondary=spell.secondary,flags=spell.flags,
        abilities={{target=1,range=0,projectile=0,effects=ability.effects}}},1,state.lookup,{level=state.level,weapons=false})
    local own,ends,source=holding(c,e,strike)
    local attack=CRIT_ATTACK[e.special] or {}
    local weapon
    if e.p2==1 then
        local from=type(e.source)=='string' and e.source~='' and e.source or c.owner
        weapon=type(from)=='string' and from:upper() or ''
    end
    c.hits=c.hits or {}
    c.hits[#c.hits+1]={eff=e.res,critical=true,melee=attack.melee==true,ranged=attack.ranged==true,weapon=weapon,
        category=number(e.p3) and e.p3>0 and e.p3 or nil,who=who,chance=p,seconds=seconds(e),once=false,
        strike=strike,source=source,own=own,ends=ends}
end
local function spent(hits)
    for _,h in ipairs(hits or {}) do
        for _,k in ipairs(hits) do
            for res in pairs(k.ends) do if h.own[res] then h.once=true end end
        end
    end
    for _,h in ipairs(hits or {}) do h.own=nil;h.ends=nil end
end

-- A cure the spell itself brings later to the creatures it gave that condition is no cure: it
-- ends the spell's own condition. ownEnds finds such ends (condition label and receiver, from
-- when the condition lands to the first cure after it); M.classify walks the spell again with
-- them, and ending leaves those cures out. A cure that comes for sure ends the condition then. A
-- cure that comes only on a successful save (onSave) lets the creature break free: Spell
-- Revisions' Greater Command puts its targets to sleep for 60 seconds, and every 6 seconds a save
-- wakes them; the condition keeps its duration and carries the save and how often it comes
-- (breakFree).
local function ownEnds(marks)
    local ends
    for key,from in pairs(marks.inflicts) do
        local first
        for _,x in ipairs(marks.cures[key] or {}) do
            if x.at>from and (first==nil or x.at<first.at) then first=x end
        end
        if first then ends=ends or {};ends[key]={from=from,at=first.at,onSave=first.onSave} end
    end
    return ends
end
-- e as the second walk reads it at second at: nil for a cure that ends the spell's own condition;
-- for that condition (the handler names its labels) a copy that lasts until the end or carries
-- breakFree; else e.
local function ending(ends,e,who,at)
    local cured=CURES[e.opcode]
    if cured then
        local x=ends[cured..':'..who]
        if x and at>x.from then return nil end
        return e
    end
    local h=H[e.opcode]
    if not h then return e end
    local probe={roles={}}
    if not pcall(h,probe,e,who,1) then return e end
    local found
    for _,name in ipairs({'disable','debuff'}) do
        local r=probe.roles[name]
        for label in pairs(r and r.kinds or {}) do
            local x=ends[label..':'..who]
            if x and at<x.at and (found==nil or x.at<found.at) then found=x end
        end
    end
    if found==nil then return e end
    local left=found.at-at
    local y={}
    for k,v in pairs(e) do y[k]=v end
    if found.onSave then
        y.breakFree={every=left,save=saveNames(found.onSave.save),saveBonus=found.onSave.saveBonus}
        return y
    end
    -- Timings with a duration of their own or none: limited, permanent, limited in ticks.
    local timing=e.timing%256
    if not (timing==0 or timing==1 or timing==9 or timing==10) then return e end
    local span=seconds(e)
    if number(span) and span<=left then return e end
    y.timing=e.timing-timing;y.duration=left
    return y
end

local walk
local function send(c,state,e,where,depth,p)
    local op=e.opcode
    if op==177 or op==283 or op==272 then c.sources[e.res]=true end
    if op==177 or op==283 then
        local eff=state.lookup('EFF',e.res)
        if type(eff)~='table' or type(eff.effect)~='table' then return state.miss(c,'EFF',e.res) end
        local inner={}
        for k,v in pairs(eff.effect) do inner[k]=v end
        inner.target=2
        -- The EFF's effect runs with the 177's own timing and duration, not the file's (IESDP:
        -- the 177 copies both into the decoded effect every tick; 283 is its cursed kind). So
        -- Conjure Lesser Water Elemental's summons through DWLESWAT lasts the 177's 114 seconds.
        if number(e.timing) then inner.timing=e.timing end
        if number(e.duration) then inner.duration=e.duration end
        -- With a non-zero IDS entry, 177 and 283 deliver only to creatures of that type (entry
        -- 0 matches anyone: bard songs and most SR spells use EA 0). The type is a condition of
        -- what they deliver, not of the whole spell: SCS's troll extras ride on fire and acid
        -- spells that hurt everyone.
        local when=c.when
        if e.p1~=0 then c.conditional=true;c.when=within(when,condition(c,{ids=e.p2,entry=e.p1})) end
        walk(c,state,{inner},receiver(c,e,where),depth+1,p,'EFF:'..e.res,c.owner)
        c.when=when
        return
    end
    if op==272 then
        local span=seconds(e)
        -- As often as M.perSecond says over the effect's time; one without an end (mostly a
        -- kit's lasting power, renewed every second) counts one second. One that never applies
        -- its file (type 1, or type 0 with parameter 1 at 0) delivers nothing.
        local times=(number(span) and math.max(span,1) or 1)*(M.perSecond(e) or 0)
        if times<=0 then return end
        local eff=state.lookup('EFF',e.res)
        if type(eff)~='table' or type(eff.effect)~='table' then return state.miss(c,'EFF',e.res) end
        local inner={}
        for k,v in pairs(eff.effect) do inner[k]=v end
        inner.target=2
        local saved=c.times;c.times=(saved or 1)*times;c.approximate=true
        walk(c,state,{inner},receiver(c,e,where),depth+1,p,'EFF:'..e.res,c.owner)
        c.times=saved;return
    end
    -- 146 casts at a creature, 148 at a point, 326 applies a spell's effects directly, 333
    -- casts repeatedly, 366 casts when the target moves.
    -- A 326 aimed at "self" or "original caster" still applies its spell to the ability target
    -- (IESDP): the creature the spell holding it is cast at (c.aim), while its SPLPROT row tests the
    -- creature the 326 lands on, the caster (Artisan's Kitpack's Dreadnought stuns the creature its
    -- critical hit strikes when its own strength is high enough). Without a creature to aim at it
    -- lands on the caster, approximate. Inside the spell a 326 applies, "self" is the creature it
    -- lands on (c.remap).
    -- 333 casts the holder's resref plus B when it names none.
    local res=e.res
    -- A resref holds eight characters, so an eight-character holder names itself.
    if op==333 and res=='' and c.owner then res=(c.owner..'B'):sub(1,8) end
    local sub=state.lookup('SPL',res)
    if type(sub)~='table' then return state.miss(c,'SPL',res) end
    c.sources[res]=true
    -- Casting level: 146 and 148 use parameter 1 (0 or instant type 1: the caster's level);
    -- 333 uses parameter 2, else level 1.
    local level=state.level
    if (op==146 or op==148) and e.p2~=1 and e.p1>0 then level=e.p1 end
    if op==333 then level=e.p2>0 and e.p2 or 1 end
    local index=M.abilityForLevel(sub,level)
    local ability=index and sub.abilities[index]
    if type(ability)~='table' then return state.miss(c,'SPL',res) end
    local own=receiver(c,e,where)
    local to=own
    if op==326 and (e.target==1 or e.target==9) then
        if c.aim then to=c.aim else c.approximate=true;c.reasons['326-unaimed:'..res]=true end
    end
    if op==148 then to='point' end
    local castAt=op~=148 and to or nil
    local subArea=op~=326 and area(state.lookup('PRO',ability.projectile),state.level) or nil
    -- What a cast delivers is checked against the receiver's spell protections by its own power,
    -- school, secondary type, hostility and projectile (326 applies effects without a cast). to:
    -- who receives it.
    if op~=326 then
        c.delivered=c.delivered or {}
        local power,unbounced=strength(ability.effects)
        c.delivered[#c.delivered+1]={resref=res,level=sub.level,school=sub.school,secondary=sub.secondary,
            projectile=ability.projectile,opcode=op,power=power,unbounced=unbounced,to=to,
            hostile=hostile(sub.flags),explodes=subArea~=nil}
    end
    local saved=c.times
    if op==333 then c.times=(saved or 1)*math.max(e.p1,1);c.approximate=true end
    if op==326 or op==366 then c.conditional=true end
    local filter=c.filter
    if subArea then
        c.area=c.area or subArea
        to='area'
        c.filter=subArea.filter
    end
    -- 326 applies the spell only when the creature it lands on meets its SPLPROT row (parameter 2,
    -- value in parameter 1; row 0 is anyone). EEex swaps the row's source and target with special
    -- bit 0.
    local when=c.when
    if op==326 and e.p2~=0 then
        c.when=within(when,condition(c,{row=e.p2,value=e.p1,flip=e.special%2==1 or nil,caster=own=='self' or nil}))
    end
    local aim,remap=c.aim,c.remap
    c.aim=castAt
    c.remap=op==326 and {self=to,caster=ability.projectile==0 and to or nil} or nil
    walk(c,state,ability.effects,to,depth+1,p,'SPL:'..res,res)
    c.times=saved;c.when=when;c.filter=filter;c.aim=aim;c.remap=remap
end
-- What a delivery brings shares its saving throw: an effect without one of its own saves as the
-- delivery does (Spell Revisions' Charm Person saves on its 177s, not on the charm).
-- A delivery to others brings what it delivers only to creatures within its own levels.
local function deliver(c,state,e,where,depth,p)
    local inherit,wait,when=c.inherit,c.delay,c.when
    if saveNames(e.save) then c.inherit={save=e.save,saveBonus=e.saveBonus} end
    c.delay=(wait or 0)+delay(e)
    if receiver(c,e,where)~='self' then c.when=leveled(c,e,when) end
    send(c,state,e,where,depth,p)
    c.inherit,c.delay,c.when=inherit,wait,when
end
local DELIVERY={[146]=true,[148]=true,[177]=true,[272]=true,[283]=true,[326]=true,[333]=true,[366]=true}

walk=function(c,state,effects,where,depth,p,key,owner)
    if key then
        if state.path[key] then c.approximate=true;c.reasons['cycle:'..key]=true;return end
        if depth>M.limits.depth then c.partial=true;c.reasons['depth:'..key]=true;return end
        state.path[key]=true
    end
    local outer,parent=c.owner,c.node
    c.owner=owner
    -- Each spell or item walked is a node; a conditional protection from it cuts what follows
    -- inside.
    if key then
        c.nodes[#c.nodes+1]={res=key:match('^SPL:(.+)$') or key:match('^ITM:(.+)$'),parent=parent}
        c.node=#c.nodes
    end
    -- A protection from this very spell with a saving throw of its own, which lands on a failed
    -- save, keeps the rest of the spell from that creature: what follows it there comes only on
    -- a successful save (onSave, by receiver). A cure that follows stays, marked, for ownEnds;
    -- anything else that follows is left out, and the reading is approximate.
    local spell=key and key:match('^SPL:(.+)$')
    local onSave={}
    if type(effects)=='table' then
        for _,e in ipairs(effects) do
            state.count=state.count+1
            if state.count>M.limits.effects then c.partial=true;c.reasons['too-many-effects']=true;break end
            if type(e)~='table' or not valid(e) then c.partial=true;c.reasons['bad-effect']=true
            else
                local who=receiver(c,e,where)
                local q=p*chance(e)
                -- What lands on the caster by a preset target does so only within its levels, by
                -- the caster level; the game does not check a self-targeted effect (GemRB).
                if who=='self' and e.target~=1 and number(state.level) and not inLevels(e,state.level) then q=0 end
                local own=e
                if who and q>0 and c.inherit and not saveNames(e.save) then e=inherited(e,c.inherit) end
                if who and q>0 and onSave[who] then
                    if CURES[e.opcode] then
                        local y={}
                        for k,v in pairs(e) do y[k]=v end
                        y.onSave=onSave[who];e=y
                    else
                        c.approximate=true;c.reasons['on-save:'..spell]=true;e=nil
                    end
                end
                if who and q>0 and e and spell and own.opcode==206 and type(own.res)=='string'
                    and own.res:upper()==spell:upper() and saveNames(own.save) then
                    onSave[who]={save=own.save,saveBonus=own.saveBonus}
                end
                if who and q>0 and e and state.ends and not DELIVERY[e.opcode] then
                    e=ending(state.ends,e,who,(c.delay or 0)+delay(e))
                end
                if who and q>0 and e then
                    local late=not DELIVERY[e.opcode] and (c.delay or 0)+delay(e)>M.laterThan
                    -- What reaches others, for matching a target's opcode immunities.
                    if who~='self' and not late then c.opcodes[e.opcode]=true end
                    local cut=not DELIVERY[e.opcode] and not late and who~='self' and exclusion(c,e)
                    if DELIVERY[e.opcode] then deliver(c,state,e,where,depth,q)
                    elseif late then
                        -- Late effects get roles of their own and no log: views are of now.
                        if H[e.opcode] then
                            local now=c.roles
                            c.later=c.later or {}
                            c.roles=c.later
                            H[e.opcode](c,e,who,q)
                            c.roles=now
                        end
                    elseif cut then
                        cut.cut=true;cut.p=q
                        c.log[#c.log+1]=cut
                    elseif H[e.opcode] then
                        H[e.opcode](c,e,who,q)
                        if e.opcode==111 and e.res~='' and who=='self' and state.weapons then weapon(c,state,e,q) end
                        if (e.opcode==248 or e.opcode==249) and e.res~='' and state.weapons then onHit(c,state,e,q,who) end
                        if e.opcode==341 and e.res~='' and state.weapons then onCrit(c,state,e,q,who) end
                        -- The log replays what reaches others for one creature (M.view).
                        if who~='self' then
                            local when=leveled(c,e,c.when)
                            if TYPED[e.opcode] and e.p2~=0 and e.p1~=0 then
                                when=within(when,condition(c,{ids=e.p2,entry=e.p1}))
                            end
                            c.log[#c.log+1]={e=e,who=who,p=q,times=c.times,owner=c.owner,node=c.node,when=when}
                        end
                    elseif not NEUTRAL[e.opcode] then tally(c.unknown,e.opcode,1) end
                end
            end
        end
    end
    c.owner=outer;c.node=parent
    if key then state.path[key]=nil end
end

local OFFENSIVE={damage=true,disable=true,debuff=true,removal=true}
local HARMS_ALLIES={everyone=true,nonparty=true,casterGroup=true}

-- The range of a release, or nil: an innate that casts two or more spells at its target at once
-- (opcodes 146 and 148) and lands nothing else there, as SCS's sequencers and triggers do
-- (DEFENCE-01). It reaches as far as its shortest spell at the casting level; SCS writes the
-- ability's effect count where its range belongs.
local function releaseRange(c,record,ability,state,where)
    if record.kind~='SPL' or record.spellType~=4 or type(ability.effects)~='table' then return nil end
    local count,shortest=0,nil
    for _,e in ipairs(ability.effects) do
        if type(e)~='table' or not valid(e) then return nil end
        local who=receiver(c,e,where)
        if who and who~='self' then
            if e.opcode~=146 and e.opcode~=148 then return nil end
            local sub=state.lookup('SPL',e.res)
            local level=state.level
            if e.p2~=1 and e.p1>0 then level=e.p1 end
            local index=sub and M.abilityForLevel(sub,level)
            local a=index and sub.abilities[index]
            if type(a)~='table' or not number(a.range) then return nil end
            count=count+1
            shortest=math.min(shortest or a.range,a.range)
        end
    end
    if count>=2 then return shortest end
end

-- When an ability is back after its use, in seconds (0: at once), or nil when it is spent until the
-- caster rests: a 171 that gives the spell itself back to its caster, at once or delayed (timings 3
-- to 5 wait their duration). The game's own come back so (Teleport Without Error at once, Planar
-- Travel after 18 seconds), removing themselves first (172) so that they never pile up, and so do the
-- installer's innate copies of SCS's free powers (bgse/lib/hook.tpa, F2f-5).
local function recharge(c,record,ability,where)
    if record.kind~='SPL' or type(record.resref)~='string' or record.resref=='' then return nil end
    local own=record.resref:upper()
    local back
    for n,list in ipairs({ability.effects,record.casting}) do
        for _,e in ipairs(type(list)=='table' and list or {}) do
            if type(e)=='table' and valid(e) and e.opcode==171 and e.res:upper()==own and
                receiver(c,e,n==1 and where or 'self')=='self' then
                local t=delay(e)
                if back==nil or t<back then back=t end
            end
        end
    end
    return back
end

-- Classify ability `index` (1-based) of a SPL or ITM record. options.level is the caster level
-- used for spells cast through other spells; options.weapons=false leaves created weapons
-- unread (a strike is read without them). c.sources names the record and every spell and EFF
-- file it delivers through: an effect it lands carries one of them as its source. A release
-- (releaseRange) is marked c.release, with its spells' shortest range as c.range and its own as
-- c.ownRange. c.recharge is when the ability is back after its use (recharge). A spell that ends
-- its own condition is walked twice (ownEnds); options.ends is that second walk's.
function M.classify(record,index,lookup,options)
    options=options or {}
    local c={roles={},unknown={},reasons={},opcodes={},sources={},conditions={},conditionAt={},log={},nodes={},
        marks={cures={},inflicts={}}}
    if type(record)~='table' or type(record.abilities)~='table' then c.partial=true;c.reasons['no-record']=true;return c end
    local ability=record.abilities[index]
    if type(ability)~='table' then c.partial=true;c.reasons['no-ability']=true;return c end
    c.resref=record.resref;c.kind=record.kind;c.ability=index;c.self=record.resref
    if type(record.resref)=='string' then c.sources[record.resref]=true end
    c.level=record.level;c.spellType=record.spellType;c.itemType=record.itemType
    c.school=record.school or ability.school;c.secondary=record.secondary or ability.secondary
    c.range=ability.range;c.speed=ability.speed;c.projectile=ability.projectile
    c.power,c.unbounced=strength(ability.effects)
    c.hostile=hostile(record.kind=='ITM' and ability.flags or record.flags)
    local targets={[1]='creature',[2]='item',[3]='dead',[4]='point',[5]='self',[7]='self'}
    c.target=targets[ability.target] or 'none'
    -- lookup may be any callable (a host function arrives as userdata).
    local state={lookup=function(kind,key)
            if lookup==nil then return nil end
            local ok,value=pcall(lookup,kind,key)
            if ok and type(value)=='table' then return value end
        end,path={},count=0,level=options.level or 1,weapons=options.weapons~=false,ends=options.ends}
    function state.miss(cl,kind,res) cl.partial=true;cl.reasons['missing:'..kind..':'..tostring(res)]=true end
    -- Projectiles 0 and 1 are none. Others without a PRO file are built into the engine (in
    -- MISSILE.IDS, not PROJECTL.IDS), so their shape is unknown here.
    local pro=state.lookup('PRO',ability.projectile)
    if pro==nil and number(ability.projectile) and ability.projectile>1 then c.projectileUnknown=true end
    c.area=area(pro,state.level)
    -- The spell's own effects reach creatures through an explosion (an area projectile), which
    -- turnings, deflections and traps let through (IESDP); a sub-spell's area does not count here.
    c.explodes=c.area~=nil
    local where=c.area and 'area' or (c.target=='self' and 'self') or (c.target=='point' and 'point') or 'target'
    -- The creature the ability is cast at, where an opcode 326 aimed at "self" applies its spell.
    c.aim=(c.target=='self' and 'self') or ((c.target=='creature' or c.target=='dead') and 'target') or nil
    -- The record itself is on the path, so a sub-spell that casts it again is a cycle.
    local key=tostring(record.kind)..':'..tostring(record.resref)
    walk(c,state,ability.effects,where,0,1,key,record.resref)
    if record.kind=='SPL' then walk(c,state,record.casting,'self',0,1,key,record.resref) end
    local ends=not options.ends and ownEnds(c.marks)
    if ends then
        local again={}
        for k,v in pairs(options) do again[k]=v end
        again.ends=ends
        return M.classify(record,index,lookup,again)
    end
    local reach=releaseRange(c,record,ability,state,where)
    if reach then c.release=true;c.ownRange=c.range;c.range=reach end
    c.recharge=recharge(c,record,ability,where)
    spent(c.hits)
    c.times=nil;c.owner=nil;c.node=nil;c.when=nil;c.inherit=nil;c.conditionAt=nil;c.delay=nil;c.filter=nil
    c.aim=nil;c.remap=nil
    c.marks=nil
    -- Without conditions every creature gets the same roles, and no view needs the log.
    if #c.conditions==0 then c.conditions=nil;c.log=nil;c.nodes=nil end
    -- What 321 takes away (strips) is no kind of its own.
    local names={}
    for name,r in pairs(c.roles) do
        if name~='strips' then
            names[#names+1]=name
            if OFFENSIVE[name] then
                c.offensive=c.offensive or (r.who.target or r.who.area or r.who.point or r.who.party
                    or r.who.everyone) and true or nil
                for who in pairs(r.who) do if HARMS_ALLIES[who] then c.friendlyFire=true end end
                if r.who.area and c.area and c.area.filter~='enemies' then c.friendlyFire=true end
                if r.who.self and name~='removal' then c.selfHarm=true end
            else c.beneficial=true end
        end
    end
    table.sort(names);c.kinds=names
    return c
end

-- The roles the classified spell c has for one creature it reaches. holds(condition) answers
-- whether the creature meets one of c.conditions: true, false or nil (cannot judge). What a
-- condition brings counts only when it holds; a conditional immunity counts when it holds, and
-- what follows it counts only for the chance it leaves. An unjudged condition brings nothing
-- and cuts nothing. Returns the roles and the creature's key, one mark per condition (1, 0 or
-- ?); roles are kept by key on c. A spell without conditions gives every creature its roles
-- (key ''); a view built from conditions leaves out what the spell does to its caster.
function M.view(c,holds)
    if type(c)~='table' or type(c.roles)~='table' then return nil end
    if type(c.log)~='table' or type(c.conditions)~='table' then return c.roles,'' end
    local marks={}
    for i,f in ipairs(c.conditions) do
        local ok,v=pcall(holds,f)
        marks[i]=(ok and v==true) and '1' or (ok and v==false) and '0' or '?'
    end
    local key=table.concat(marks)
    c.views=c.views or {}
    if c.views[key] then return c.views[key],key end
    local function met(when)
        for _,n in ipairs(when or {}) do if marks[n]~='1' then return false end end
        return true
    end
    local r={roles={},self=c.self}
    local nodes,opcodes={},{}
    for _,x in ipairs(c.log) do
        if x.cut then
            if met(x.when) then
                if x.node then nodes[x.node]=(nodes[x.node] or 1)*(1-math.min(x.p,1)) end
                if x.opcode then opcodes[x.opcode]=(opcodes[x.opcode] or 1)*(1-math.min(x.p,1)) end
            end
        elseif met(x.when) then
            local left=opcodes[x.e.opcode] or 1
            local node=x.node
            while node do
                left=left*(nodes[node] or 1)
                node=c.nodes[node].parent
            end
            if left>0 then
                r.times=x.times;r.owner=x.owner
                H[x.e.opcode](r,x.e,x.who,x.p*left)
            end
        end
    end
    c.views[key]=r.roles
    return r.roles,key
end
local function never() return false end
-- The roles for a creature that meets none of the spell's conditions.
function M.common(c) return (M.view(c,never)) end
-- The SPLPROT rows among the spell's conditions and those of its weapons' and on-hit effects'
-- strikes, added to rows by key: what the adapter asks the engine about each enemy.
function M.rows(c,rows)
    rows=rows or {}
    if type(c)=='table' and type(c.conditions)=='table' then
        for _,f in ipairs(c.conditions) do
            if type(f)=='table' and f.row~=nil then rows[M.conditionKey(f)]=f end
        end
    end
    for _,field in ipairs({'weapons','hits'}) do
        if type(c)=='table' and type(c[field])=='table' then
            for _,w in ipairs(c[field]) do M.rows(w.strike,rows) end
        end
    end
    return rows
end

return M
