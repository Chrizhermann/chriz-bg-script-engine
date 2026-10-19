-- The engine's openers (step 3, third slice, D2a; DEFENCE-01, "D2"): Time Stop and Improved
-- Alacrity, cast when SCS casts them and before the ranking, as SCS's order puts them before its
-- attacks (Christopher, 2026-10-19: Time Stop and combos like SCS first, per enemy later).
-- Inputs are plain values, as for combat-intent/choice.lua; input.timeStop says who holds a
-- running Time Stop ({caster=id, or true when unknown; left=seconds}) and frame.self.alacrity
-- whether the caster's own Improved Alacrity runs. Nothing here touches the engine.
--
-- SCS ([src] mage/ssl/generalblocks/renew.ssl, combatblocks/alacrity.ssl):
-- - Time Stop when the mage sees one of the party ("don't waste timestop on riff-raff") and no
--   Time Stop of its own runs; not during its own Improved Alacrity (a slow spell).
-- - Improved Alacrity when an enemy is seen and it is down; the first core spell in a Time Stop.
local targeting=require('combat-intent.targeting')
local M={}
-- GENDER.IDS: summons and illusions, the riff-raff SCS stops no time for.
M.RIFFRAFF={[6]=true,[7]=true}
-- An opener needs at least this many other ready spells to follow it: a Time Stop or an
-- Improved Alacrity with nothing to cast in it is a slot thrown away.
M.followups=2

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function ready(row)
    return type(row)=='table' and number(row.ready) and row.ready>0 and row.usable and
        type(row.spell)=='table' and type(row.spell.roles)=='table'
end
local function reaches(role,...)
    if type(role)~='table' or type(role.who)~='table' then return false end
    for _,who in ipairs({...}) do if role.who[who] then return true end end
    return false
end

-- Whether a spell stops time around its caster (opcode 231 cast on itself).
function M.stopsTime(spell)
    local d=type(spell)=='table' and type(spell.roles)=='table' and spell.roles.disable
    return type(d)=='table' and type(d.kinds)=='table' and d.kinds.timestop==true and spell.target=='self'
end
-- Whether a spell cleanses the caster's own casting aura (opcode 188), as Improved Alacrity does.
function M.quickens(spell)
    local b=type(spell)=='table' and type(spell.roles)=='table' and spell.roles.buff
    return type(b)=='table' and type(b.kinds)=='table' and b.kinds.alacrity==true and reaches(b,'self')
end
-- The seconds left of the caster's own Time Stop, or nil when it holds none.
function M.ownStop(input)
    local s=type(input)=='table' and input.timeStop
    local self=type(input)=='table' and type(input.frame)=='table' and input.frame.self
    if type(s)~='table' or type(self)~='table' or s.caster~=self.id then return nil end
    return number(s.left) and math.max(s.left,0) or 0
end
-- An enemy worth a Time Stop: a living creature that is neither a summon nor an illusion.
function M.worthy(e)
    return targeting.alive(e) and not (type(e.ids)=='table' and M.RIFFRAFF[e.ids.gender])
end
-- Whether a ready spell can follow an opener: an attack, or a protection or buff for the caster
-- or its allies.
local function followup(spell)
    local r=spell.roles
    return reaches(r.damage,'target','area','point') or reaches(r.disable,'target','area','point') or
        reaches(r.protection,'self','area','target') or reaches(r.buff,'self','area','target')
end

local function option(row,rule)
    return {resref=row.resref,kind='opener',rule=rule,mode='self',self=true,worth=0,cost=0,score=0,
        hits={},slack=0}
end

-- The opener to cast now, or nil and why none.
function M.choose(input)
    if type(input)~='table' or type(input.frame)~='table' or type(input.frame.self)~='table' or
        type(input.frame.enemies)~='table' then return nil,'bad-input' end
    local caster=input.frame.self
    local stop=input.timeStop
    -- In another creature's Time Stop the caster stands frozen: nothing to open.
    if stop~=nil and not M.ownStop(input) then return nil,'frozen' end
    local seen,worthy=false,false
    for _,e in ipairs(input.frame.enemies) do
        if targeting.alive(e) then
            seen=true
            if M.worthy(e) then worthy=true end
        end
    end
    if not seen then return nil,'no-enemy' end
    local stopper,quickener,others=nil,nil,0
    for _,row in ipairs(type(input.spells)=='table' and input.spells or {}) do
        if ready(row) then
            if M.stopsTime(row.spell) then stopper=stopper or row
            elseif M.quickens(row.spell) then quickener=quickener or row
            elseif followup(row.spell) then others=others+row.ready end
        end
    end
    if not stopper and not quickener then return nil,'none' end
    if others<M.followups then return nil,'no-followups' end
    local alacrity=caster.alacrity==true
    -- Time Stop: none runs, an enemy worth it is seen, and the caster's own Improved Alacrity is
    -- down (SCS's slow spells wait for it).
    if stopper and stop==nil and worthy and not alacrity then return option(stopper,'time-stop') end
    -- Improved Alacrity when it is down, also as the first cast in the caster's own Time Stop.
    if quickener and not alacrity then return option(quickener,'alacrity') end
    return nil,'waiting'
end
return M
