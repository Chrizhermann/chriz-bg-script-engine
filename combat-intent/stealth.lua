-- A thief's own hide (F2f; Christopher, 2026-10-27: SCS's free invisibility goes and thieves hide
-- with their real skill, "Der skill sollte natürlich dementsprechend auch hoch sein bei den
-- Dieben/Schurken"). SCS is the blueprint ([src] genai/ssl/initial.ssl, credit DavidW): its thieves
-- turn invisible for free when they are created and whenever no party member is in their sight.
-- Here a thief that sees no enemy hides in shadows with the game's own Hide() action, the game
-- rolling against its skill as it does for a player; the installer takes SCS's free invisibility
-- away from every creature the engine hides this way and gives SCS's thieves hide skills for their
-- level (bgse/lib/hook.tpa, bgse_raise_skills).
--
-- A monster's veil (F2f-5; Christopher, 2026-10-27: SCS's script-only powers become real abilities,
-- as often as SCS gives them). SCS's fiends, Maurezhi, vampiric illithids and the like turn invisible
-- for free from their scripts, most of them whenever they see no enemy; the installer gives each of
-- them that power as an innate ability that comes back as SCS's block would fire again (bgse/lib/
-- hook.tpa, bgse_grant_gifts). Here a creature that cannot hide by its skill and sees no enemy uses
-- an innate invisibility it has ready (M.veils), cast with the game's normal action: a plain one
-- first, whatever its charges (it lasts until the creature acts), an improved one only when it comes
-- back within veilRecharge (a mind flayer's, a vampiric illithid's): one that takes longer stays
-- for the fight, where its short spell counts (the Maurezhi's every 1000 seconds, Illasera's five).
--
-- Who: a creature with thief levels (CLASS.IDS THIEF and its multiclasses, M.THIEVES) and a Hide in
-- Shadows skill above 0 (M.able) hides; any other creature with an innate invisibility ready veils.
-- Neither when invisible already or in the game's stealth mode. Rangers, monks and other creatures
-- with the skill wait for a lab of what the game lets them do.
-- When: with no enemy in sight, by wit (mind.tactics): a clever creature always, a normal one when
-- its stretch out of sight draws it (once, until it sees an enemy again; search.draw), a dull one
-- never. Its orders (combat-intent/orders.lua) can say always (hide=true) or never (hide=false). One
-- try a round at most (gapSeconds), as a player tries again after a failed roll. mind.hide=false
-- (labs) switches both off.
-- Plain values only; nothing here touches the engine.
local targeting=require('combat-intent.targeting')
local search=require('combat-intent.search')
local M={}
M.ticksPerSecond=15
-- CLASS.IDS: THIEF, FIGHTER_THIEF, FIGHTER_MAGE_THIEF, MAGE_THIEF, CLERIC_THIEF.
M.THIEVES={[4]=true,[9]=true,[10]=true,[13]=true,[15]=true}
-- MODAL.IDS STEALTH: the game's stealth mode, which its Hide() action starts.
M.stealthMode=3
M.gapSeconds=6
-- An improved invisibility that comes back within this many seconds may veil a creature out of
-- sight; one that takes longer, or is spent until the creature rests, is kept for the fight.
M.veilRecharge=60
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

-- Whether a creature (self: its class and Hide in Shadows skill, hideSkill) can hide by its skill.
function M.able(self)
    return type(self)=='table' and M.THIEVES[self.class]==true and number(self.hideSkill) and self.hideSkill>0
end

-- The invisibility a classified spell c (combat-intent/spells.lua) gives the creature it is used on,
-- cast at the creature itself (an ability aimed at itself or at a creature): 'improved', 'plain' or
-- nil. The game's spell, Spell Revisions' or another mod's: what its effects do counts.
function M.kind(c)
    if type(c)~='table' or type(c.roles)~='table' or (c.target~='self' and c.target~='creature') then return nil end
    local p=c.roles.protection
    if type(p)~='table' or type(p.kinds)~='table' or not p.kinds.invisible or type(p.who)~='table' or
        not (p.who.self or p.who.target) then return nil end
    return p.kinds.improvedInvisible and 'improved' or 'plain'
end

-- The innate invisibilities a creature has ready (M.pick's options): its innate abilities (rows, as
-- the choice gets them: {resref, list, ready, usable, spell: the classification}; innate when they
-- come from its innate list or their file says so) that make it invisible (M.kind), each with its
-- kind, when it comes back after its use (recharge, seconds; nil: spent until the creature rests)
-- and its casting speed.
function M.veils(rows)
    local out={}
    for _,row in ipairs(type(rows)=='table' and rows or {}) do
        local c=type(row)=='table' and row.spell
        local kind=M.kind(c)
        if kind and type(row.resref)=='string' and number(row.ready) and row.ready>0 and row.usable and
            (row.list=='innate' or c.spellType==4) then
            out[#out+1]={resref=row.resref,kind=kind,recharge=number(c.recharge) and c.recharge or nil,
                speed=number(c.speed) and c.speed or 0}
        end
    end
    return out
end

-- Whether a veil may use an innate invisibility v of M.veils: a plain one always, an improved one
-- that comes back within veilRecharge.
function M.veiling(v)
    if type(v)~='table' then return false end
    return v.kind=='plain' or (v.kind=='improved' and number(v.recharge) and v.recharge<=M.veilRecharge)
end

-- The innate invisibility a veil uses, or nil: plain before improved; one that comes back before one
-- that is spent, the sooner the better; then the faster cast, then the name.
function M.pick(veils)
    local chosen,chosenKey
    for _,v in ipairs(type(veils)=='table' and veils or {}) do
        if M.veiling(v) and type(v.resref)=='string' then
            local k={v.kind=='plain' and 0 or 1,number(v.recharge) and 0 or 1,number(v.recharge) and v.recharge or 0,
                number(v.speed) and v.speed or 0}
            local better=chosen==nil
            if not better then
                for i=1,#k do
                    if k[i]~=chosenKey[i] then better=k[i]<chosenKey[i];break end
                    if i==#k then better=v.resref<chosen.resref end
                end
            end
            if better then chosen,chosenKey=v,k end
        end
    end
    return chosen
end

-- With no enemy in sight: {kind='hide'} for a creature that can hide by its skill, {kind='veil',
-- resref, improved, recharge, speed} for one that has an innate invisibility to veil itself with
-- (M.pick), or nil and why not ('off', 'seen', 'unable', 'hidden', 'hiding', 'ordered', 'wit', 'gap').
-- input: tick; frame (self with class, hideSkill, state and modal, the game's modal state;
-- enemies); veils (M.veils); mind; orders; tactical (its stretch's draw, search.draw); tried (the
-- tick of its last try).
function M.decide(input)
    local m=type(input.mind)=='table' and input.mind or {}
    if m.hide==false then return nil,'off' end
    local frame=input.frame
    if type(frame.enemies)=='table' and #frame.enemies>0 then return nil,'seen' end
    local self=frame.self
    local veil
    if not M.able(self) then
        veil=M.pick(input.veils)
        if not veil then return nil,'unable' end
    end
    if targeting.has(self.state,UNSEEN) then return nil,'hidden' end
    if self.modal==M.stealthMode then return nil,'hiding' end
    local o=type(input.orders)=='table' and input.orders or {}
    if o.hide==false then return nil,'ordered' end
    if o.hide~=true and not search.tactical({mind=m,tactical=input.tactical}) then return nil,'wit' end
    local tried=input.tried
    if number(tried) and number(input.tick) and input.tick>=tried and input.tick-tried<M.gapSeconds*M.ticksPerSecond then
        return nil,'gap'
    end
    if veil then
        return {kind='veil',resref=veil.resref,improved=veil.kind=='improved' or nil,recharge=veil.recharge,
            speed=veil.speed,ordered=o.hide==true or nil}
    end
    return {kind='hide',ordered=o.hide==true or nil}
end
return M
