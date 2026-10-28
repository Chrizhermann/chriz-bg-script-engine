-- The weapons a creature carries (F2c; Christopher, 2026-10-26: archers next, SCS as the
-- blueprint): the one in its hand as the game reports it, and the others in its weapon slots as
-- they would strike if it took them up, for the engine's choice of weapon (combat-intent/
-- choice.lua). SCS's archers shoot while no enemy stands close and take up their most damaging
-- melee weapon when one does ([src] genai/ssl/shoot.ssl, dw#wtacor.ssl, lib/ssl/
-- shared_definitions.ssl; credit DavidW).
--
-- The weapon in hand (lab probe F, docs/learned.md): THAC0BONUSRIGHT holds the bonus to hit of
-- strength (of dexterity for missiles), of the proficiency and of the item itself (a launcher's
-- and its ammunition's together); DAMAGEBONUSRIGHT holds the proficiency's bonus to damage alone.
-- The bonus to damage of strength and of the item come on top. While a launcher is in hand the
-- game's selected slot is the quiver slot of its ammunition, and the launcher is the first weapon
-- slot that shoots it.
--
-- A weapon not in hand is worked out from the same parts, by the game's own tables: WSPECIAL for
-- the proficiency, the class's ZERO_SKILL_THAC0 (CLSWPBON) without one, STRMOD and STRMODEX,
-- DEXMOD's missile column, and WSPATCK for the attacks a warrior's proficiency brings (for a class
-- whose CLSWPBON row gets them). Its attacks a round are those in hand less what the weapon in
-- hand adds or sets (opcode 1 while equipped, its WSPATCK bonus) plus what the other one does, so
-- that haste and the like stay. Plain values only; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local M={}
-- SLOTS.IDS: the fist, the quiver, the magic weapon slot and the weapon slots.
M.FIST=10
M.QUIVER={11,12,13}
M.MAGIC=34
M.WEAPONS={35,36,37,38}
-- Ammunition's launcher field (bow, crossbow, sling) as the item category of the weapon that
-- shoots it (IESDP, ITM).
M.LAUNCHER={[1]=15,[2]=27,[3]=18}
-- Item ability flags (IESDP, ITM): strength's bonus to hit and damage (bit 0), and the two halves
-- EE splits it into (bit 2 damage, bit 3 to hit). The item flag of a magical weapon.
M.STRENGTH_HIT=0x9
M.STRENGTH_DAMAGE=0x5
M.MAGICAL=0x40
-- Item ability attack types: melee, ranged (thrown or ammunition), launcher.
M.MELEE,M.RANGED,M.LAUNCHES=1,2,4
-- The item's usability bit "unusable by thieves" (IESDP, ITM). A backstab lands only with a melee
-- weapon whose bit is clear, whoever wields it (GemRB's reading of the game, [src]
-- core/Inventory.cpp; Use Any Item does not change it). GemRB also reads ability flag bit 24 and
-- ToBEx bit 25 as backstab switches; IESDP lists neither for EE, so neither counts here. Mods
-- move this bit: Tweaks Anthology's "Thieves Can Backstab With More Weapons" clears it on daggers,
-- staves, swords and clubs, and in Christopher's game nearly every melee weapon has it clear (their
-- class limits sit in opcode 319), so the item read decides, never a list of weapon kinds.
M.THIEF=0x400000
-- Attacks a round of a weapon taken up: at least a half, at most what haste allows.
M.minApr,M.maxApr=0.5,10

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function value(v) return number(v) and v or 0 end
local function average(dice,sides)
    if not number(dice) or not number(sides) or dice<=0 or sides<=0 then return 0 end
    return dice*(sides+1)/2
end
local function abilities(record) return type(record)=='table' and type(record.abilities)=='table' and record.abilities or {} end
local function recordAt(items,slot)
    local it=type(items)=='table' and items[slot]
    return type(it)=='table' and type(it.record)=='table' and it.record or nil,type(it)=='table' and it.resref or nil
end

-- Attacks a round as opcode 1, stat 8 and creature files keep them: 6 to 10 are half attacks (6 a
-- half, 7 one and a half, up to 10), and the negative ones mirror them. nil for no number.
function M.decode(v)
    if not number(v) then return nil end
    if v>5 and v<=10 then return v-5.5 end
    if v<-5 and v>=-10 then return v+5.5 end
    return v
end
-- A WSPATCK cell as attacks: whole ones when positive; when negative, its size less a half (-1 is
-- a half, -2 one and a half; IESDP, docs/learned.md).
local function warriorAttacks(v)
    if not number(v) then return 0 end
    if v<0 then return -v-0.5 end
    return v
end
-- The row of a table kept by number for n, or the highest one below it (stars past a table's end).
local function rowAt(rows,n)
    if type(rows)~='table' or not number(n) then return nil end
    local best,at
    for k,row in pairs(rows) do
        if number(k) and k<=n and (at==nil or k>at) then best,at=row,k end
    end
    return best
end

-- Whether an item ability strikes as a weapon: a weapon ability (location 1) that hits in melee,
-- is thrown or shot, or shoots.
local function striking(a)
    return type(a)=='table' and a.location==1 and (a.attackType==M.MELEE or a.attackType==M.RANGED or a.attackType==M.LAUNCHES)
end
-- Whether launcher (an item record) shoots ammunition whose ability is a.
local function shoots(launcher,a)
    if type(launcher)~='table' or type(a)~='table' or not number(a.launcher) then return false end
    local category=M.LAUNCHER[a.launcher]
    return category~=nil and category==launcher.itemType
end
-- Whether ability a is ammunition, shot by a launcher.
local function ammunition(a) return type(a)=='table' and a.attackType==M.RANGED and number(a.launcher) and M.LAUNCHER[a.launcher]~=nil end

-- The first weapon slot holding a launcher that shoots ammunition of ability a: its slot, its
-- record, its resref and the number of its launcher ability (from 0, as SelectWeaponAbility
-- counts), or nil.
function M.launcherFor(items,a)
    for _,slot in ipairs(M.WEAPONS) do
        local record,resref=recordAt(items,slot)
        if record and shoots(record,a) then
            for i,b in ipairs(abilities(record)) do
                if striking(b) and b.attackType==M.LAUNCHES then return slot,record,resref,i-1 end
            end
        end
    end
end
-- The first quiver slot holding ammunition the launcher shoots: its slot, record and resref, or nil.
function M.ammoFor(items,launcher)
    for _,slot in ipairs(M.QUIVER) do
        local record,resref=recordAt(items,slot)
        if record and shoots(launcher,abilities(record)[1]) then return slot,record,resref end
    end
end

-- What strikes when the creature attacks with the item in slot and its ability number n (from 0;
-- the first ability when the item has no such one), or nil when nothing can: {slot, number (what
-- SelectWeaponAbility takes up), item, record, use (the weapon's ability), ammo, ammoRecord, shot
-- (the ammunition's ability), ranged, launcher, quiver}. A launcher shoots the first ammunition in
-- the quiver it fits, ammunition is shot by the first launcher for it, and either alone strikes
-- nothing.
function M.striker(items,slot,n)
    local record,resref=recordAt(items,slot)
    if not record then return nil end
    local list=abilities(record)
    local index=(number(n) and n>=0 and n or 0)+1
    if type(list[index])~='table' then index=1 end
    local a=list[index]
    if type(a)~='table' then return nil end
    if ammunition(a) then
        local at,launcher,name,i=M.launcherFor(items,a)
        if not at then return nil end
        return {slot=at,number=i,item=name,record=launcher,use=abilities(launcher)[i+1],ammo=resref,ammoRecord=record,
            shot=a,ranged=true,launcher=true,quiver=slot}
    end
    if a.attackType==M.LAUNCHES then
        local q,ammo,name=M.ammoFor(items,record)
        if not q then return nil end
        return {slot=slot,number=index-1,item=resref,record=record,use=a,ammo=name,ammoRecord=ammo,shot=abilities(ammo)[1],
            ranged=true,launcher=true,quiver=q}
    end
    return {slot=slot,number=index-1,item=resref,record=record,use=a,ranged=a.attackType==M.RANGED}
end

-- Strength's bonus to hit and to damage (STRMOD, with STRMODEX on top for 18 and exceptional
-- strength); none without the table.
function M.strength(tables,str,extra)
    local mod=type(tables)=='table' and type(tables.strmod)=='table' and tables.strmod[str]
    if type(mod)~='table' then return 0,0 end
    local hit,damage=value(mod.hit),value(mod.damage)
    local ex=str==18 and number(extra) and extra>0 and type(tables.strmodex)=='table' and tables.strmodex[extra]
    if type(ex)=='table' then hit,damage=hit+value(ex.hit),damage+value(ex.damage) end
    return hit,damage
end
-- STRMOD.2DA's bonuses as the game ships them, strengths 1 to 25 (none for those left out), and
-- exceptional strength 18/01 to 18/00 by its percentile (STRMODEX.2DA on top of 18's).
local SHIPPED_HIT={[1]=-5,[2]=-3,[3]=-3,[4]=-2,[5]=-2,[6]=-1,[7]=-1,[17]=1,[18]=1,[19]=3,[20]=3,[21]=4,[22]=4,
    [23]=5,[24]=6,[25]=7}
local SHIPPED_DAMAGE={[1]=-4,[2]=-2,[3]=-1,[4]=-1,[5]=-1,[16]=1,[17]=1,[18]=2,[19]=7,[20]=8,[21]=9,[22]=10,
    [23]=11,[24]=12,[25]=14}
-- Strength's bonus to hit and to damage by the game's shipped tables, for when the installed ones
-- cannot be read and for summoned creatures (combat-intent/summons.lua). A strength above 25 counts
-- as 25 (the game caps it there); none for one below 1.
function M.shippedStrength(str,extra)
    str=number(str) and math.min(math.floor(str),25) or 0
    extra=number(extra) and extra or 0
    if str==18 and extra>0 then
        local hit=(extra>=100 and 3) or (extra>=51 and 2) or 1
        local damage=(extra>=100 and 6) or (extra>=91 and 5) or (extra>=76 and 4) or 3
        return hit,damage
    end
    return SHIPPED_HIT[str] or 0,SHIPPED_DAMAGE[str] or 0
end
-- Strength's bonus to hit and to damage by the installed tables, else by the shipped ones.
function M.might(tables,str,extra)
    if type(tables)=='table' and type(tables.strmod)=='table' then return M.strength(tables,str,extra) end
    return M.shippedStrength(str,extra)
end
-- The proficiency's bonus to hit and to damage with the stars c has in it (WSPECIAL); with none,
-- the class's penalty to hit (ZERO_SKILL_THAC0). An item of no proficiency, or stars not known,
-- get neither.
function M.skill(tables,c,proficiency)
    if not number(proficiency) or proficiency<=0 then return 0,0 end
    local pips=type(c.pips)=='table' and c.pips[proficiency]
    if not number(pips) then return 0,0 end
    if pips<=0 then return -value(c.penalty),0 end
    local row=rowAt(type(tables)=='table' and tables.wspecial,pips)
    if type(row)~='table' then return 0,0 end
    return value(row.hit),value(row.damage)
end
-- What opcode 1 while equipped does with an item's attacks a round: the base it sets (mode 1), what
-- it adds (mode 0) and the last word it sets (mode 3, the first one).
local function equipped(record)
    local set,add,final=nil,0,nil
    for _,e in ipairs(type(record)=='table' and type(record.equipping)=='table' and record.equipping or {}) do
        if type(e)=='table' and e.opcode==1 and number(e.p1) then
            if e.p2==1 then set=M.decode(e.p1)
            elseif e.p2==0 then add=add+M.decode(e.p1)
            elseif e.p2==3 and final==nil then final=M.decode(e.p1) end
        end
    end
    return set,add,final
end
-- The attacks a round the weapon record brings c: the base it sets or the creature's own, what it
-- adds and the warrior table's bonus for its proficiency (by stars and the creature's level); and
-- the last word it sets, if any.
local function share(tables,c,record)
    local set,add,final=equipped(record)
    local base=M.decode(c.baseApr)
    if not number(base) or base<=0 then base=1 end
    local bonus=0
    local rows=type(tables)=='table' and tables.wspatck
    local proficiency=type(record)=='table' and record.proficiency
    if c.profApr and type(rows)=='table' and number(proficiency) and proficiency>0 then
        local pips=type(c.pips)=='table' and c.pips[proficiency]
        local row=rowAt(rows,number(pips) and math.max(pips,0) or 0)
        if type(row)=='table' then
            local level=math.max(1,math.floor(value(c.level)))
            while level>1 and row[level]==nil do level=level-1 end
            bonus=warriorAttacks(row[level])
        end
    end
    return (set or base)+add+bonus,final
end

-- Whether one of striker s's abilities (a launcher's or its ammunition's) has a flag of mask.
local function takes(s,mask)
    return targeting.has(value(s.use and s.use.flags),mask) or (s.shot~=nil and targeting.has(value(s.shot.flags),mask))
end
-- The damage of one hit of striker s's items: the weapon's dice and bonus, and its ammunition's.
local function own(s)
    local d=average(s.use.dice,s.use.sides)+value(s.use.damageBonus)
    if s.shot then d=d+average(s.shot.dice,s.shot.sides)+value(s.shot.damageBonus) end
    return d
end
-- Strength's bonus to damage that striker s takes (see M.STRENGTH_DAMAGE).
local function strengthDamage(tables,c,s)
    if not takes(s,M.STRENGTH_DAMAGE) then return 0 end
    local _,damage=M.strength(tables,c.str,c.strExtra)
    return damage
end
-- The bonus to hit THAC0BONUSRIGHT holds for striker s (see the top) and the bonus to damage
-- DAMAGEBONUSRIGHT holds, as the tables give them.
function M.bonus(tables,c,s)
    local hit=value(s.use.thac0)+(s.shot and value(s.shot.thac0) or 0)
    if takes(s,M.STRENGTH_HIT) then hit=hit+(M.strength(tables,c.str,c.strExtra)) end
    if s.ranged and type(tables)=='table' and type(tables.dexmod)=='table' then hit=hit+value(tables.dexmod[c.dex]) end
    local skillHit,skillDamage=M.skill(tables,c,s.record.proficiency)
    return hit+skillHit,skillDamage
end
-- Whether the tables a weapon not in hand needs are there.
function M.complete(tables)
    return type(tables)=='table' and type(tables.wspecial)=='table' and type(tables.strmod)=='table' and
        type(tables.dexmod)=='table'
end

-- Striker s as an attack (combat-intent/threat.lua's and weapons.lua's attack data): its THAC0 and
-- damage from thac0 and the given bonus to hit and to damage of the weapon's own parts, with the
-- creature's hit and damage bonuses for all weapons and for melee or missiles alone, whether it
-- shoots and how far (a launcher's own range, else the ammunition's), the item, its ability (1 for
-- the first) and the ammunition, the damage type and the hitting item's flags and enchantment
-- (plain ammunition from a magical launcher hits as magical), the projectile a missile flies as,
-- slot and abilityNum for SelectWeaponAbility, whether it can backstab (M.THIEF) and the item's
-- category (ITEMCAT.IDS, for critical hit effects of one category); also the creature's strength
-- and exceptional strength and which of strength's bonuses the weapon takes (strengthHit,
-- strengthDamage), for buffs that change its strength (combat-intent/defence.lua).
local function attack(c,s,hit,damage)
    local stats=c.stats
    local melee=not s.ranged
    local out={item=s.item,ability=s.number+1,slot=s.slot,abilityNum=s.number,ammo=s.ammo,ranged=s.ranged,
        launcher=s.launcher,fist=s.slot==M.FIST or nil,itemType=number(s.record.itemType) and s.record.itemType or nil,
        str=number(c.str) and c.str or nil,strExtra=number(c.strExtra) and c.strExtra or nil,
        strengthHit=takes(s,M.STRENGTH_HIT) or nil,strengthDamage=takes(s,M.STRENGTH_DAMAGE) or nil}
    if melee and number(s.record.usability) and not targeting.has(s.record.usability,M.THIEF) then out.backstab=true end
    out.thac0=value(stats.thac0)-hit-value(stats.hitBonus)-value(melee and stats.meleeHit or stats.missileHit)
    out.damage=math.max(0,damage+value(stats.damageBonus)+value(melee and stats.meleeDamage or stats.missileDamage))
    local hitting=s.ammoRecord or s.record
    local a=s.shot or s.use
    out.damageType=a.damageType
    out.flags,out.enchantment=value(hitting.flags),value(hitting.enchantment)
    if s.ammoRecord then out.enchantment=math.max(out.enchantment,value(s.record.enchantment)) end
    local magic=out.enchantment>0 or targeting.has(value(s.record.flags),M.MAGICAL) or targeting.has(out.flags,M.MAGICAL)
    if magic and not targeting.has(out.flags,M.MAGICAL) and out.enchantment<=0 then out.flags=out.flags+M.MAGICAL end
    out.magical=magic
    if s.ranged then
        local range=value(s.use.range)
        if range<=0 and s.shot then range=value(s.shot.range) end
        if range>0 then out.range=range*targeting.rangeUnit end
        out.projectile=a.projectile
    end
    return out
end

-- The weapon in c's hand (c.selected, c.ability, as the game reports them) as an attack, with its
-- attacks a round decoded (nil when the game gives none) and the parts the tables give for the two
-- right-hand bonuses (model: {hit, damage}), so that a lab can hold them against the game's. Without
-- a weapon that strikes (a launcher without ammunition, ammunition without its launcher, nothing
-- readable) only the attacks and THAC0 are known.
--
-- c (plain values the adapter reads): stats {thac0, apr, hitBonus, meleeHit, missileHit,
-- damageBonus, meleeDamage, missileDamage, thac0Right, damageRight}, str, strExtra, dex, level,
-- pips (stars by proficiency stat), penalty (ZERO_SKILL_THAC0), profApr (whether WSPATCK applies),
-- baseApr (the creature file's attacks), items ({resref, record} by slot), selected, ability.
function M.hand(tables,c)
    local stats=type(c.stats)=='table' and c.stats or {}
    local apr=M.decode(stats.apr)
    local s=M.striker(c.items,c.selected,c.ability)
    if not s or type(s.use)~='table' then
        return {apr=number(apr) and apr>0 and apr or nil,thac0=value(stats.thac0)-value(stats.thac0Right)-value(stats.hitBonus)}
    end
    local out=attack(c,s,value(stats.thac0Right),own(s)+strengthDamage(tables,c,s)+value(stats.damageRight))
    out.apr=number(apr) and apr>0 and apr or nil
    if M.complete(tables) and type(c.pips)=='table' then
        local hit,damage=M.bonus(tables,c,s)
        out.model={hit=hit,damage=damage}
    end
    return out
end

-- The other weapons c could take up, best first by nothing (the choice weighs them): each striking
-- ability of each item in the weapon slots, but the one in hand, as M.hand's attack with the
-- attacks a round worked out (see the top). None while a magic weapon is in hand (the game keeps
-- it there) or without the tables.
function M.others(tables,c)
    local out={}
    if not M.complete(tables) or c.selected==M.MAGIC then return out end
    local stats=type(c.stats)=='table' and c.stats or {}
    local inHand=M.striker(c.items,c.selected,c.ability)
    -- What the creature has without the weapon in hand: its attacks a round less what that weapon
    -- brings, unless the weapon in hand sets the last word.
    local selectedRecord=inHand and inHand.record or recordAt(c.items,c.selected)
    local apr=M.decode(stats.apr)
    local part,final=share(tables,c,selectedRecord)
    local rest=number(apr) and apr>0 and not final and apr-part or 0
    for _,slot in ipairs(M.WEAPONS) do
        local record=recordAt(c.items,slot)
        for i,a in ipairs(abilities(record)) do
            if striking(a) and not (inHand and inHand.slot==slot and inHand.number==i-1) then
                local s=M.striker(c.items,slot,i-1)
                if s and s.slot==slot then
                    local hit,damage=M.bonus(tables,c,s)
                    local w=attack(c,s,hit,own(s)+strengthDamage(tables,c,s)+damage)
                    local mine,last=share(tables,c,s.record)
                    w.apr=math.max(M.minApr,math.min(M.maxApr,last or rest+mine))
                    out[#out+1]=w
                end
            end
        end
    end
    return out
end
return M
