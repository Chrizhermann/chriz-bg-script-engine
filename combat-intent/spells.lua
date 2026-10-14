-- What a spell or item ability does, read from its real effects (design step 2). Records are
-- plain tables with the fields of tools/ie_resources.py (in game: adapters/eeex/resources.lua).
-- lookup(kind, key) returns another record: 'SPL', 'ITM' or 'EFF' by resref, 'PRO' by the
-- ability's projectile number. Spells delivered through other spells or EFF files are followed
-- with depth, cycle and size limits. Nothing here raises: odd or missing data is reported in
-- the result (partial, reasons, unknown opcodes), and the caller skips what it cannot use.
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
    [49]='wisdom',[97]='strength'}
local TOHIT={[54]=true,[167]=true,[278]=true,[284]=true,[288]=true,[305]=true,[306]=true}
local WEAPON_DAMAGE={[73]=true,[285]=true,[286]=true,[289]=true}
local SAVE_MODS={[33]=true,[34]=true,[35]=true,[36]=true,[37]=true,[325]=true,[346]=true}
-- Opcodes that use the dice fields for an amount; elsewhere they are a level range.
local DICE_AMOUNT={[12]=true,[17]=true,[18]=true,[25]=true,[98]=true,[218]=true}
-- Graphics, sounds, text, scripting state and bookkeeping: no role.
local NEUTRAL={}
for _,op in ipairs({7,8,9,23,41,50,51,52,53,56,57,61,63,64,66,71,72,82,94,95,96,99,103,104,105,
    106,107,108,112,114,115,117,122,123,125,138,139,140,141,142,144,147,149,150,152,155,156,164,
    169,170,172,174,180,181,182,183,184,186,187,190,192,194,195,196,215,225,237,239,240,243,
    244,245,251,252,253,254,255,262,263,265,267,268,269,271,275,276,277,279,281,282,287,290,291,
    293,294,295,296,298,300,302,307,308,309,311,312,313,315,319,320,323,327,328,330,336,338,339,
    340,341,342,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,362,363,364,365,367,
    21,59,90,91,92,171,233,266,321}) do NEUTRAL[op]=true end
-- 321 and 266 remove the effects or protections of one named resource: SCS and SR use them
-- to refresh their own helpers, so they are bookkeeping, not dispelling.
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
local function saveNames(bits)
    local names
    for _,pair in ipairs(SAVES) do
        if math.floor(bits/pair[1])%2==1 then names=names or {};names[pair[2]]=true end
    end
    return names
end
local function longer(a,b)
    if a==nil then return b end
    if b==nil then return a end
    if a=='permanent' or b=='permanent' then return 'permanent' end
    if a=='equipped' or b=='equipped' then return 'equipped' end
    return math.max(a,b)
end

-- One effect's contribution to a role: who gets it, how likely, saves, level range, duration.
local function add(c,name,who,e,p)
    local r=c.roles[name]
    if not r then r={who={},kinds={},chance=0,power=0};c.roles[name]=r end
    r.who[who]=true
    r.chance=math.max(r.chance,p)
    r.power=math.max(r.power,e.power)
    local saves=saveNames(e.save)
    if saves then
        r.save=r.save or {}
        for s in pairs(saves) do r.save[s]=true end
        if r.saveBonus==nil or e.saveBonus<r.saveBonus then r.saveBonus=e.saveBonus end
    end
    if not DICE_AMOUNT[e.opcode] then
        if e.dice>0 then r.maxLevel=math.min(r.maxLevel or e.dice,e.dice) end
        if e.sides>0 then r.minLevel=math.max(r.minLevel or e.sides,e.sides) end
    end
    r.duration=longer(r.duration,seconds(e))
    return r
end
local function kind(c,name,label,who,e,p)
    local r=add(c,name,who,e,p);r.kinds[label]=true;return r
end
local function tally(t,key,value) t[key]=(t[key] or 0)+value end
local function set(r,field) r[field]=r[field] or {};return r[field] end

-- A stat change helps or hurts by its sign; percentage modes compare against 100.
local function modifier(c,e,who,p,label,good,bad,amount)
    local mode=e.p2%65536
    local delta=e.p1
    if mode==2 then delta=e.p1-100 end
    if delta==0 then return end
    local r=kind(c,delta>0 and good or bad,label,who,e,p)
    tally(set(r,'amounts'),label,math.abs(amount or delta)*p)
end

-- A bonus or penalty by sign, for opcodes whose parameter 2 is not a modifier type.
local function signed(c,e,who,p,value,label,good,bad)
    if value==0 then return end
    local r=kind(c,value>0 and good or bad,label,who,e,p)
    tally(set(r,'amounts'),label,math.abs(value)*p)
end

local H={}
local function damage(c,e,who,p,amount,label)
    local r=add(c,'damage',who,e,p)
    r.kinds[label]=true
    tally(set(r,'types'),label,amount*p*(c.times or 1))
    r.amount=(r.amount or 0)+amount*p*(c.times or 1)
    if e.save>0 and math.floor(e.special/256)%2==1 then r.saveForHalf=true end
end
H[12]=function(c,e,who,p)
    local mode=e.p2%65536
    local label=DAMAGE[math.floor(e.p2/65536)] or 'other'
    if mode==0 then damage(c,e,who,p,math.max(e.p1,0)+average(e.dice,e.sides),label)
    else
        local r=add(c,'damage',who,e,p);r.kinds[label]=true;r.percent=math.max(r.percent or 0,e.p1)
    end
end
H[25]=function(c,e,who,p)
    local s=seconds(e);local span=number(s) and s or 0
    local mode=e.p2%65536
    local rate=({[0]=1,[1]=e.p1,[2]=e.p1>0 and 1/e.p1 or 0,[3]=e.p1})[mode] or 1
    damage(c,e,who,p,rate*span,'poison')
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
local function hold(c,e,who,p)
    local r=kind(c,'disable','hold',who,e,p)
    if e.p2~=0 then set(r,'filters')[#r.filters+1]={ids=e.p2,entry=e.p1} end
end
H[109]=hold;H[175]=hold;H[185]=hold
H[145]=function(c,e,who,p) kind(c,'disable','nocast',who,e,p) end
local function berserk(c,e,who,p)
    if who=='self' then kind(c,'buff','berserk',who,e,p) else kind(c,'disable','berserk',who,e,p) end
end
H[3]=berserk;H[246]=berserk

local DEBUFFS={[40]='slow',[60]='miscast',[74]='blind',[78]='disease',[80]='deaf',[137]='chant',
    [158]='grease',[235]='knockback'}
for op,label in pairs(DEBUFFS) do H[op]=function(c,e,who,p) kind(c,'debuff',label,who,e,p) end end
H[216]=function(c,e,who,p) local r=kind(c,'debuff','drain',who,e,p);tally(set(r,'amounts'),'drain',math.abs(e.p1)*p) end

for op,label in pairs(STATS) do
    H[op]=function(c,e,who,p)
        local mode=e.p2%65536
        if (op==15 or op==44) and mode==3 then kind(c,'buff',label,who,e,p);return end
        if mode==1 then
            if e.p1>=15 then kind(c,'buff',label,who,e,p) elseif e.p1<=8 then kind(c,'debuff',label,who,e,p) end
            return
        end
        modifier(c,e,who,p,label,'buff','debuff')
    end
end
for op in pairs(TOHIT) do H[op]=function(c,e,who,p) modifier(c,e,who,p,'thac0','buff','debuff') end end
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
H[188]=function(c,e,who,p) kind(c,'buff','castingSpeed',who,e,p) end
H[301]=function(c,e,who,p) modifier(c,e,who,p,'critical','buff','debuff') end
H[344]=function(c,e,who,p) kind(c,'buff','enchantment',who,e,p) end
H[345]=H[344]
H[111]=function(c,e,who,p) kind(c,'buff','weapon',who,e,p) end
H[248]=function(c,e,who,p) kind(c,'buff','onHit',who,e,p) end
H[249]=H[248]
H[303]=function(c,e,who,p) kind(c,'buff','backstab',who,e,p) end
H[42]=function(c,e,who,p) if e.p1>0 then kind(c,'buff','slots',who,e,p) end end
H[62]=H[42]
H[261]=function(c,e,who,p) kind(c,'buff','restore',who,e,p) end
H[193]=function(c,e,who,p) kind(c,'buff','seeInvisible',who,e,p) end
H[16]=function(c,e,who,p)
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
-- Percent more (or less) damage dealt; parameter 2 is the damage type.
H[332]=function(c,e,who,p) signed(c,e,who,p,e.p1,'damagePercent','buff','debuff') end
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
for op in pairs(SAVE_MODS) do H[op]=function(c,e,who,p) modifier(c,e,who,p,'saves','protection','debuff') end end
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
local PROTECTION_KINDS={[20]='invisible',[65]='blur',[69]='nondetection',[100]='creatureType',
    [153]='sanctuary',[163]='freeAction',[208]='minimumHp',[292]='backstab',
    [297]='turnUndead',[299]='chaosShield',[310]='timestop',[322]='evasion',[335]='sevenEyes'}
for op,label in pairs(PROTECTION_KINDS) do H[op]=function(c,e,who,p) kind(c,'protection',label,who,e,p) end end
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
H[201]=function(c,e,who,p) blocks(c,e,who,p,'immune','levels',e.p2,e.p1) end
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
local function strip(field)
    return function(c,e,who,p)
        local r=kind(c,'removal',field,who,e,p)
        local t=set(r,field);t[e.p2]=math.max(t[e.p2] or 0,e.p1)
    end
end
H[220]=strip('schools');H[229]=strip('schools');H[221]=strip('secondaries');H[230]=strip('secondaries')
H[337]=function(c,e,who,p) local r=kind(c,'removal','opcodes',who,e,p);set(r,'opcodes')[e.p2]=true end
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
-- Mode 5 aligns the summons against the receiver, so a summons cast on oneself is hostile.
H[67]=function(c,e,who,p) local r=summon(c,e,who,p);if e.p2==5 and who=='self' then r.hostile=true end end
-- Types 0-2 remove or kill the creature that is replaced.
H[151]=function(c,e,who,p)
    summon(c,e,who,p)
    if e.p2<=2 and who~='self' then kind(c,'removal','replace',who,e,p) end
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

-- Who receives an effect, from its target field and where its delivery lands.
local function receiver(e,where)
    local t=e.target
    if t==1 or t==9 then return 'self' end
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

local function area(projectile)
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
    return a
end

local function valid(e)
    for _,f in ipairs({'opcode','target','power','p1','p2','timing','duration','prob1','prob2',
        'dice','sides','save','saveBonus','special'}) do
        if not number(e[f]) then return false end
    end
    return type(e.res)=='string'
end

local walk
local function deliver(c,state,e,where,depth,p)
    local op=e.opcode
    -- With a non-zero IDS entry, 177 and 283 apply only to creatures of that type (entry 0
    -- matches anyone: bard songs and most SR spells use EA 0).
    if (op==177 or op==283) and e.p1~=0 then
        c.conditional=true
        c.filters=c.filters or {}
        c.filters[#c.filters+1]={ids=e.p2,entry=e.p1}
    end
    if op==177 or op==283 then
        local eff=state.lookup('EFF',e.res)
        if type(eff)~='table' or type(eff.effect)~='table' then return state.miss(c,'EFF',e.res) end
        local inner={}
        for k,v in pairs(eff.effect) do inner[k]=v end
        inner.target=2
        return walk(c,state,{inner},receiver(e,where),depth+1,p,'EFF:'..e.res,c.owner)
    end
    if op==272 then
        local eff=state.lookup('EFF',e.res)
        if type(eff)~='table' or type(eff.effect)~='table' then return state.miss(c,'EFF',e.res) end
        local inner={}
        for k,v in pairs(eff.effect) do inner[k]=v end
        inner.target=2
        local span=seconds(e)
        -- Type 0 once a second, 2 p1 times a second, 3 once every p1 seconds, 4 a number of
        -- times (EFF parameter 3) every p1 rounds.
        local times=number(span) and math.max(span,1) or 1
        local every=math.max(e.p1,1)
        if e.p2==2 then times=times*every elseif e.p2==3 then times=times/every
        elseif e.p2==4 then times=times/(6*every) end
        local saved=c.times;c.times=(saved or 1)*times;c.approximate=true
        walk(c,state,{inner},receiver(e,where),depth+1,p,'EFF:'..e.res,c.owner)
        c.times=saved;return
    end
    -- 146 casts at a creature, 148 at a point, 326 applies a spell's effects directly, 333
    -- casts repeatedly, 366 casts when the target moves.
    -- 333 casts the holder's resref plus B when it names none.
    local res=e.res
    if op==333 and res=='' and c.owner then res=c.owner..'B' end
    local sub=state.lookup('SPL',res)
    if type(sub)~='table' then return state.miss(c,'SPL',res) end
    -- Casting level: 146 and 148 use parameter 1 (0 or instant type 1: the caster's level);
    -- 333 uses parameter 2, else level 1.
    local level=state.level
    if (op==146 or op==148) and e.p2~=1 and e.p1>0 then level=e.p1 end
    if op==333 then level=e.p2>0 and e.p2 or 1 end
    local index=M.abilityForLevel(sub,level)
    local ability=index and sub.abilities[index]
    if type(ability)~='table' then return state.miss(c,'SPL',res) end
    local to=receiver(e,where)
    if op==148 then to='point' end
    local saved=c.times
    if op==333 then c.times=(saved or 1)*math.max(e.p1,1);c.approximate=true end
    if op==326 or op==366 then c.conditional=true end
    local subArea=op~=326 and area(state.lookup('PRO',ability.projectile)) or nil
    if subArea then
        c.area=c.area or subArea
        to='area'
    end
    walk(c,state,ability.effects,to,depth+1,p,'SPL:'..res,res)
    c.times=saved
end
local DELIVERY={[146]=true,[148]=true,[177]=true,[272]=true,[283]=true,[326]=true,[333]=true,[366]=true}

walk=function(c,state,effects,where,depth,p,key,owner)
    if key then
        if state.path[key] then c.approximate=true;c.reasons['cycle:'..key]=true;return end
        if depth>M.limits.depth then c.partial=true;c.reasons['depth:'..key]=true;return end
        state.path[key]=true
    end
    local outer=c.owner
    c.owner=owner
    if type(effects)=='table' then
        for _,e in ipairs(effects) do
            state.count=state.count+1
            if state.count>M.limits.effects then c.partial=true;c.reasons['too-many-effects']=true;break end
            if type(e)~='table' or not valid(e) then c.partial=true;c.reasons['bad-effect']=true
            else
                local who=receiver(e,where)
                local q=p*chance(e)
                if who and q>0 then
                    if DELIVERY[e.opcode] then deliver(c,state,e,where,depth,q)
                    elseif H[e.opcode] then H[e.opcode](c,e,who,q)
                    elseif not NEUTRAL[e.opcode] then tally(c.unknown,e.opcode,1) end
                end
            end
        end
    end
    c.owner=outer
    if key then state.path[key]=nil end
end

local OFFENSIVE={damage=true,disable=true,debuff=true,removal=true}
local HARMS_ALLIES={everyone=true,nonparty=true,casterGroup=true}

-- Classify ability `index` (1-based) of a SPL or ITM record. options.level is the caster level
-- used for spells cast through other spells.
function M.classify(record,index,lookup,options)
    options=options or {}
    local c={roles={},unknown={},reasons={}}
    if type(record)~='table' or type(record.abilities)~='table' then c.partial=true;c.reasons['no-record']=true;return c end
    local ability=record.abilities[index]
    if type(ability)~='table' then c.partial=true;c.reasons['no-ability']=true;return c end
    c.resref=record.resref;c.kind=record.kind;c.ability=index;c.self=record.resref
    c.level=record.level;c.spellType=record.spellType;c.itemType=record.itemType
    c.school=record.school or ability.school;c.secondary=record.secondary or ability.secondary
    c.range=ability.range;c.speed=ability.speed;c.projectile=ability.projectile
    local hostile=record.kind=='ITM' and ability.flags or record.flags
    c.hostile=number(hostile) and math.floor(hostile/1024)%2==1 or false
    local targets={[1]='creature',[2]='item',[3]='dead',[4]='point',[5]='self',[7]='self'}
    c.target=targets[ability.target] or 'none'
    -- lookup may be any callable (a host function arrives as userdata).
    local state={lookup=function(kind,key)
            if lookup==nil then return nil end
            local ok,value=pcall(lookup,kind,key)
            if ok and type(value)=='table' then return value end
        end,path={},count=0,level=options.level or 1}
    function state.miss(cl,kind,res) cl.partial=true;cl.reasons['missing:'..kind..':'..tostring(res)]=true end
    -- Projectiles 0 and 1 are none. Others without a PRO file are built into the engine (in
    -- MISSILE.IDS, not PROJECTL.IDS), so their shape is unknown here.
    local pro=state.lookup('PRO',ability.projectile)
    if pro==nil and number(ability.projectile) and ability.projectile>1 then c.projectileUnknown=true end
    c.area=area(pro)
    local where=c.area and 'area' or (c.target=='self' and 'self') or (c.target=='point' and 'point') or 'target'
    -- The record itself is on the path, so a sub-spell that casts it again is a cycle.
    local key=tostring(record.kind)..':'..tostring(record.resref)
    walk(c,state,ability.effects,where,0,1,key,record.resref)
    if record.kind=='SPL' then walk(c,state,record.casting,'self',0,1,key,record.resref) end
    c.times=nil;c.owner=nil
    local names={}
    for name,r in pairs(c.roles) do
        names[#names+1]=name
        if OFFENSIVE[name] then
            c.offensive=c.offensive or (r.who.target or r.who.area or r.who.point or r.who.party
                or r.who.everyone) and true or nil
            for who in pairs(r.who) do if HARMS_ALLIES[who] then c.friendlyFire=true end end
            if r.who.area and c.area and c.area.filter~='enemies' then c.friendlyFire=true end
            if r.who.self and name~='removal' then c.selfHarm=true end
        else c.beneficial=true end
    end
    table.sort(names);c.kinds=names
    return c
end

return M
