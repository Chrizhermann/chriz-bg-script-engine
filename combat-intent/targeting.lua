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
    charmed=0x2000,feebleminded=0x100000,improvedInvisible=0x400000,confused=0x80000000}
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
function M.casting(actor) return type(actor)=='table' and M.CASTS[actor.action]==true end
function M.health(actor)
    if type(actor)~='table' or not number(actor.hp) or not number(actor.maxHp) or actor.maxHp<=0 then return 1 end
    return math.max(0,math.min(1,actor.hp/actor.maxHp))
end
function M.distance(a,b)
    if type(a)~='table' or type(b)~='table' or not number(a.x) or not number(a.y) or
        not number(b.x) or not number(b.y) then return math.huge end
    local dx,dy=a.x-b.x,(a.y-b.y)*4/3
    return math.sqrt(dx*dx+dy*dy)
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
-- (e.splprot, keyed by spells.conditionKey). true, false or nil (cannot judge).
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
        return ids.matches(f,e)
    end
end
-- What the spell does to e, by e's own view of the spell's conditions: its damage and its
-- disable chance. nil when a condition cannot be judged for e.
local function effect(spell,e)
    local roles,key=spells.view(spell,M.holds(e))
    if type(roles)~='table' or type(key)~='string' or key:find('?',1,true) then return nil end
    local d,x=roles.damage,roles.disable
    return {damage=reaches(d) and number(d.amount) and d.amount or 0,
        disable=reaches(x) and number(x.chance) and x.chance or 0}
end
-- Amounts that differ by less than this are equal (they come from the same arithmetic).
local EPSILON=1e-9

-- Spell protections that would stop this spell: turning, deflection, traps and globes by
-- level, school or secondary type; immunity or bounce by opcode or projectile; protection
-- from this very spell. protections holds {opcode, p1, p2, res} rows.
local BY_LEVEL={[199]=true,[200]=true,[201]=true,[259]=true}
local BY_SCHOOL={[202]=true,[204]=true,[223]=true,[227]=true}
local BY_SECONDARY={[203]=true,[205]=true,[226]=true,[228]=true}
local BY_RESOURCE={[206]=true,[207]=true,[318]=true,[324]=true}
local function stops(p,spell)
    local op=p.opcode
    local opcodes=type(spell.opcodes)=='table' and spell.opcodes or {}
    if op==101 or op==198 then return opcodes[p.p2]==true end
    if op==83 or op==197 then return number(spell.projectile) and (p.p2==spell.projectile or p.p2+1==spell.projectile) end
    if op==102 then return p.p1==spell.level end
    if BY_LEVEL[op] then return p.p2==spell.level end
    if BY_SCHOOL[op] then return number(spell.school) and spell.school>0 and p.p2==spell.school end
    if BY_SECONDARY[op] then return number(spell.secondary) and spell.secondary>0 and p.p2==spell.secondary end
    if BY_RESOURCE[op] then return type(p.res)=='string' and p.res~='' and p.res==spell.resref end
    return false
end
function M.protected(target,spell)
    if type(target.protections)~='table' then return true end
    for _,p in ipairs(target.protections) do
        if type(p)=='table' and stops(p,spell) then return true end
    end
    return false
end

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
