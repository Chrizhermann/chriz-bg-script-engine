-- Which casts the fight director may redirect, and whether another enemy is as fair and legal
-- a target as the one the creature's own script chose. Inputs are plain values: the caster's
-- perception frame (adapters/eeex/sense.lua) and the spell's classification
-- (combat-intent/spells.lua). Nothing here touches the engine or raises on odd data; an
-- answer it cannot give is a reason to leave the cast as it is.
local spells=require('combat-intent.spells')
local ids=require('combat-intent.ids')
local M={}

-- STATE.IDS bits (engine constants).
M.STATE={sleeping=0x1,panic=0x4,stunned=0x8,invisible=0x10,helpless=0x20,reallyDead=0xFC0,
    charmed=0x2000,slowed=0x10000,blind=0x40000,feebleminded=0x100000,improvedInvisible=0x400000,
    confused=0x80000000}
-- STATE_DISABLED as the installed STATE.IDS defines it: sleeping, panic, stunned, helpless,
-- charmed, feebleminded, confused. Holds set the HELD stat instead (see sense.lua).
M.DISABLED=0x8010202D
local UNSEEN=M.STATE.invisible+M.STATE.improvedInvisible
-- Actions that cast: Spell, SpellPoint, ForceSpell, ForceSpellPoint, ReallyForceSpell,
-- SpellNoDec, SpellPointNoDec, ReallyForceSpellPoint.
M.CASTS={[31]=true,[95]=true,[113]=true,[114]=true,[181]=true,[191]=true,[192]=true,[337]=true}
-- Projectiles built into the engine (no PRO file) that hit one creature: Magic Missile's.
M.builtinSingle={}
for n=68,78 do M.builtinSingle[n]=true end
-- Distance as the engine's search map measures it: cells are 16 by 12 world units, so y
-- counts 4/3. SPL range values are taken as cells of 16 (to be confirmed in the lab).
M.rangeUnit=16
-- Roles that tie a cast to its target for reasons the director does not judge (a dispel
-- picks the protected enemy) or that are not attacks at all.
local KEEP_ROLES={'removal','heal','raise','cure','summon'}

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function bits(v) if not number(v) then return 0 end return math.floor(v)%4294967296 end
-- True when value and mask share a bit (plain Lua 5.1 has no bit library).
function M.has(value,mask)
    local a,b=bits(value),bits(mask)
    while a>0 and b>0 do
        local x,y=a%2,b%2
        if x==1 and y==1 then return true end
        a,b=(a-x)/2,(b-y)/2
    end
    return false
end

function M.alive(actor)
    return type(actor)=='table' and not M.has(actor.state,M.STATE.reallyDead) and
        not (number(actor.hp) and actor.hp<=0)
end
function M.disabled(actor)
    return type(actor)=='table' and (M.has(actor.state,M.DISABLED) or (number(actor.held) and actor.held>0))
end
-- Under a charm (STATE_CHARMED). Among a creature's allies such a one is a foe its side charmed:
-- the game puts it on the charmer's side (lab batch J: the party's thief the erinyes charmed stood
-- with the group as EA ENEMY).
function M.charmed(actor) return type(actor)=='table' and M.has(actor.state,M.STATE.charmed) end
function M.casting(actor) return type(actor)=='table' and M.CASTS[actor.action]==true end
function M.health(actor)
    if type(actor)~='table' or not number(actor.hp) or not number(actor.maxHp) or actor.maxHp<=0 then return 1 end
    return math.max(0,math.min(1,actor.hp/actor.maxHp))
end
-- The hit points a creature cannot drop below: its minimum (minHp, opcode 208), 0 without one.
function M.minimum(actor)
    return type(actor)=='table' and number(actor.minHp) and actor.minHp>0 and actor.minHp or 0
end
-- The share of a creature's maximum hit points above its minimum: what attacks can still take
-- from it (its health when it has no minimum).
function M.room(actor)
    if type(actor)~='table' or not number(actor.hp) or not number(actor.maxHp) or actor.maxHp<=0 then return 1 end
    return math.max(0,math.min(1,(actor.hp-M.minimum(actor))/actor.maxHp))
end
function M.distance(a,b)
    if type(a)~='table' or type(b)~='table' or not number(a.x) or not number(a.y) or
        not number(b.x) or not number(b.y) then return math.huge end
    local dx,dy=a.x-b.x,(a.y-b.y)*4/3
    return math.sqrt(dx*dx+dy*dy)
end

-- The chance e makes its saving throw against role: a d20 plus the effect's bonus reaching the
-- best of e's saves the role allows. Unknown saves count as even odds.
function M.saveChance(role,e)
    if type(role)~='table' or type(role.save)~='table' or next(role.save)==nil then return 0 end
    local best
    for name in pairs(role.save) do
        local v=type(e)=='table' and type(e.saves)=='table' and e.saves[name]
        if number(v) and (best==nil or v<best) then best=v end
    end
    if not best then return 0.5 end
    local bonus=number(role.saveBonus) and role.saveBonus or 0
    return clamp((21-(best-bonus))/20,0.05,0.95)
end
-- The share of a role's casts at e that its magic resistance lets through: all of them when no
-- effect of the role is resisted (role.resisted false, combat-intent/spells.lua).
function M.landing(role,e)
    if type(role)=='table' and role.resisted==false then return 1 end
    return 1-clamp(type(e)=='table' and number(e.mr) and e.mr or 0,0,100)/100
end

local function reaches(role) return type(role)=='table' and type(role.who)=='table' and (role.who.target or role.who.area) end
-- The roles that say what kind of attack a spell is: what it does to a creature none of its
-- creature conditions single out, when that is an attack, else all it can do (a hold that takes
-- humanoids only is still a hold). A fire spell with SCS's troll extra stays a damage spell.
function M.kindRoles(spell)
    local common=spells.common(spell)
    if type(common)=='table' and (reaches(common.disable) or reaches(common.damage)) then return common end
    return spell.roles
end
-- What a cast does to the creature it is aimed at, for the group picture: 'disable', 'damage'
-- or nil. Any cast counts here, also one the director would not redirect.
function M.role(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil end
    local roles=M.kindRoles(spell)
    if reaches(roles.disable) then return 'disable' end
    if reaches(roles.damage) then return 'damage' end
end
-- 'disable' or 'damage' when the director may redirect this cast, else nil and why.
function M.kind(spell)
    if type(spell)~='table' or type(spell.roles)~='table' then return nil,'unclassified' end
    if spell.partial then return nil,'partial' end
    if spell.target~='creature' then return nil,'not-creature-target' end
    if spell.friendlyFire then return nil,'friendly-fire' end
    if spell.selfHarm then return nil,'self-harm' end
    if spell.projectileUnknown and not M.builtinSingle[spell.projectile] then return nil,'unknown-projectile' end
    for _,name in ipairs(KEEP_ROLES) do
        if reaches(spell.roles[name]) then return nil,'role-'..name end
    end
    local roles=M.kindRoles(spell)
    if reaches(roles.disable) then return 'disable' end
    if reaches(roles.damage) then return 'damage' end
    return nil,'not-damage-or-disable'
end

-- Whether e meets one of a spell's conditions (combat-intent/spells.lua): an IDS file and entry
-- by e's own values, a SPLPROT row by the marks the adapter read through the engine's own check
-- (e.splprot, keyed by spells.conditionKey), levels by e's level (the highest of its classes', as
-- the game compares it). true, false or nil (cannot judge).
function M.holds(e)
    return function(f)
        if type(f)~='table' then return nil end
        if f.row~=nil then
            local marks=type(e)=='table' and e.splprot or nil
            if type(marks)~='table' then return nil end
            local v=marks[spells.conditionKey(f)]
            if v==true or v==false then return v end
            return nil
        end
        if f.minLevel~=nil or f.maxLevel~=nil then
            local level=type(e)=='table' and e.level
            if not number(level) then return nil end
            return not ((number(f.minLevel) and level<f.minLevel) or (number(f.maxLevel) and level>f.maxLevel))
        end
        return ids.matches(f,e)
    end
end
-- The hit points e keeps at least while a spell hits it, by roles (the spell's roles for e): its
-- minimum, unless the spell takes away every effect that sets it (roles.strips by the effects'
-- sources, e.minHpFrom): SCS's fire, acid and cold spells end troll regeneration, and the
-- minimum with it, before they hit.
function M.floor(e,roles)
    local floor=M.minimum(e)
    if floor<=0 then return 0 end
    local from=e.minHpFrom
    local s=type(roles)=='table' and roles.strips
    local res=reaches(s) and type(s.res)=='table' and s.res
    if type(from)~='table' or next(from)==nil or not res then return floor end
    for source in pairs(from) do
        if not res[source] then return floor end
    end
    return 0
end
-- What the spell does to e, by e's own view of the spell's conditions: its damage (none on a
-- creature its minimum keeps where it is) and its disable chance. nil when a condition cannot be
-- judged for e.
local function effect(spell,e)
    local roles,key=spells.view(spell,M.holds(e))
    if type(roles)~='table' or type(key)~='string' or key:find('?',1,true) then return nil end
    local d,x=roles.damage,roles.disable
    local damage=reaches(d) and number(d.amount) and d.amount or 0
    local floor=M.floor(e,roles)
    if floor>0 and number(e.hp) and e.hp<=floor then damage=0 end
    return {damage=damage,disable=reaches(x) and number(x.chance) and x.chance or 0}
end
-- Amounts that differ by less than this are equal (they come from the same arithmetic).
local EPSILON=1e-9

-- Spell protections that would stop this spell: turning, deflection, traps and globes by
-- power level, school or secondary type; immunity or bounce by opcode or projectile; protection
-- from this very spell. protections holds {opcode, p1, p2, res} rows. Globes (102) and 199 name
-- their power level in parameter 1, 200, 201 and Spell Trap (259) in parameter 2; each compares
-- the power of the effects the spell delivers (spell.power; the spell's level when unknown), and
-- the last four let effects through that pass turnings (spell.unbounced) or come through an
-- explosion (spell.explodes). From the protected creature itself (fromSelf), turnings,
-- deflections, traps, protections by school or secondary type and the bounce of a resource
-- stop nothing, and a globe only a hostile spell (spell.hostile). All by IESDP. Immunity (83)
-- and bounce (197) by projectile name a PROJECTL.IDS entry, one less than the projectile field
-- of the spell's ability (docs/learned.md); the entry of the same number is another projectile:
-- Protection from Missiles' arrows (entry 1) are no immunity to field 1, no projectile, which
-- the sub-spells Spell Revisions' area spells cast at each creature have (lab batch H6: a mage
-- under it counted the party's Ice Storm harmless and began summons that its explosions broke).
local BOUNCES={[199]=1,[200]=2,[201]=2,[259]=2}
local BY_SCHOOL={[202]=true,[204]=true,[223]=true,[227]=true}
local BY_SECONDARY={[203]=true,[205]=true,[226]=true,[228]=true}
local BY_RESOURCE={[206]=true,[207]=true,[318]=true,[324]=true}
local function stops(p,spell,fromSelf)
    local op=p.opcode
    local opcodes=type(spell.opcodes)=='table' and spell.opcodes or {}
    if op==101 or op==198 then return opcodes[p.p2]==true end
    if op==83 or op==197 then return number(spell.projectile) and number(p.p2) and p.p2+1==spell.projectile end
    local power=number(spell.power) and spell.power or spell.level
    if op==102 then return p.p1==power and not (fromSelf and not spell.hostile) end
    if fromSelf and (BOUNCES[op] or BY_SCHOOL[op] or BY_SECONDARY[op] or op==207) then return false end
    if BOUNCES[op] then
        if spell.unbounced or spell.explodes then return false end
        return (BOUNCES[op]==1 and p.p1 or p.p2)==power
    end
    if BY_SCHOOL[op] then return number(spell.school) and spell.school>0 and p.p2==spell.school end
    if BY_SECONDARY[op] then return number(spell.secondary) and spell.secondary>0 and p.p2==spell.secondary end
    if BY_RESOURCE[op] then return type(p.res)=='string' and p.res~='' and p.res==spell.resref end
    return false
end
-- Turnings, deflections and traps that count down (200, 201, 259) hold their levels in parameter
-- 1: each cast they stop takes its power from them, and they stop the last one even with fewer
-- levels left, then end (lab batch H7: Spell Deflection's 9 levels stopped three of an Ice
-- Storm's explosions of power 4, then the fourth hurt).
local COUNTS_DOWN={[200]=true,[201]=true,[259]=true}
-- What one cast of spell takes from protection p: the power of each part p stops, 0 when it
-- stops none, nil when it stops the cast without counting down. A spell another one casts at the
-- target (spell.delivered, combat-intent/spells.lua) meets the target's protections again by its
-- own power, school and secondary type: either stops the whole.
local function taken(p,spell,fromSelf)
    local power,hit=0,false
    local function meet(part)
        if not stops(p,part,fromSelf) then return end
        hit=true
        local v=number(part.power) and part.power or part.level
        power=power+(number(v) and v or 0)
    end
    meet(spell)
    for _,d in ipairs(type(spell.delivered)=='table' and spell.delivered or {}) do
        if type(d)=='table' and d.to~='self' then meet(d) end
    end
    if not hit then return 0 end
    if not COUNTS_DOWN[p.opcode] or not (number(p.p1) and p.p1>0) or power<=0 then return nil end
    return power
end
-- How many casts of spell in a row target's spell protections stop from now (a cloud's
-- explosions): 0 when none does, math.huge when one stops it for as long as it lasts, else as
-- many as the turnings, deflections and traps that count down stop before their levels run out,
-- one after another (each cast meets one of them). Unknown protections stop everything.
-- fromSelf: the target casts the spell itself.
function M.stopped(target,spell,fromSelf)
    if type(target.protections)~='table' then return math.huge end
    local count=0
    for _,p in ipairs(target.protections) do
        if type(p)=='table' then
            local power=taken(p,spell,fromSelf)
            if power==nil then return math.huge end
            if power>0 then count=count+math.ceil(p.p1/power) end
        end
    end
    return count
end
-- Whether target's spell protections stop a cast of spell.
function M.protected(target,spell,fromSelf) return M.stopped(target,spell,fromSelf)>0 end

-- Whether target may take the cast instead of original, the enemy the creature's script chose
-- (both entries of the caster's frame). Nothing here is stricter than "no worse than the
-- original": range up to the farther of the spell's range and the original's distance, magic
-- resistance up to the original's, and by each creature's own view of the spell's conditions,
-- the spell's kind of attack reaches target with no less damage and no lower disable chance
-- than on the original. A cast the original is immune to may so move to a creature it works on;
-- a fire bolt with a troll extra stays on trolls.
function M.legal(caster,target,spell,original)
    if type(target)~='table' or type(original)~='table' or type(caster)~='table' then return false,'missing' end
    if not M.alive(target) then return false,'dead' end
    if number(target.sanctuary) and target.sanctuary>0 then return false,'sanctuary' end
    if M.has(target.state,UNSEEN) and not caster.seeInvisible then return false,'invisible' end
    local away,before=M.distance(caster,target),M.distance(caster,original)
    if away==math.huge or before==math.huge then return false,'no-position' end
    if away>math.max(before,(number(spell.range) and spell.range or 0)*M.rangeUnit) then return false,'out-of-range' end
    if (number(target.mr) and target.mr or 0)>(number(original.mr) and original.mr or 0) then
        return false,'magic-resistance'
    end
    local a,b=effect(spell,target),effect(spell,original)
    if not a or not b then return false,'unknown-filter' end
    local kind=M.role(spell)
    if not kind or a[kind]<=0 or a.damage+EPSILON<b.damage or a.disable+EPSILON<b.disable then
        return false,'filter'
    end
    if M.protected(target,spell) then return false,'protected' end
    return true
end
return M
