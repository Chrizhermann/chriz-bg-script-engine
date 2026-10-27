-- A thief's own hide (F2f; Christopher, 2026-10-27: SCS's free invisibility goes and thieves hide
-- with their real skill, "Der skill sollte natürlich dementsprechend auch hoch sein bei den
-- Dieben/Schurken"). SCS is the blueprint ([src] genai/ssl/initial.ssl, credit DavidW): its thieves
-- turn invisible for free when they are created and whenever no party member is in their sight.
-- Here a thief that sees no enemy hides in shadows with the game's own Hide() action, the game
-- rolling against its skill as it does for a player; the installer takes SCS's free invisibility
-- away from every creature the engine hides this way and gives SCS's thieves hide skills for their
-- level (bgse/lib/hook.tpa, bgse_raise_skills).
--
-- Who: a creature with thief levels (CLASS.IDS THIEF and its multiclasses, M.THIEVES) and a Hide in
-- Shadows skill above 0 (M.able), not invisible already and not in the game's stealth mode. Rangers,
-- monks and other creatures with the skill wait for a lab of what the game lets them do.
-- When: with no enemy in sight, by wit (mind.tactics): a clever creature always, a normal one when
-- its stretch out of sight draws it (once, until it sees an enemy again; search.draw), a dull one
-- never. Its orders (combat-intent/orders.lua) can say always (hide=true) or never (hide=false). One
-- try a round at most (gapSeconds), as a player tries again after a failed roll. mind.hide=false
-- (labs) switches it off.
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
local UNSEEN=targeting.STATE.invisible+targeting.STATE.improvedInvisible

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

-- Whether a creature (self: its class and Hide in Shadows skill, hideSkill) can hide by its skill.
function M.able(self)
    return type(self)=='table' and M.THIEVES[self.class]==true and number(self.hideSkill) and self.hideSkill>0
end

-- With no enemy in sight: {kind='hide'}, or nil and why not ('off', 'seen', 'unable', 'hidden', 'hiding',
-- 'ordered', 'wit', 'gap'). input: tick; frame (self with class, hideSkill, state and modal, the game's
-- modal state; enemies); mind; orders; tactical (its stretch's draw, search.draw); tried (the tick of
-- its last try).
function M.decide(input)
    local m=type(input.mind)=='table' and input.mind or {}
    if m.hide==false then return nil,'off' end
    local frame=input.frame
    if type(frame.enemies)=='table' and #frame.enemies>0 then return nil,'seen' end
    local self=frame.self
    if not M.able(self) then return nil,'unable' end
    if targeting.has(self.state,UNSEEN) then return nil,'hidden' end
    if self.modal==M.stealthMode then return nil,'hiding' end
    local o=type(input.orders)=='table' and input.orders or {}
    if o.hide==false then return nil,'ordered' end
    if o.hide~=true and not search.tactical({mind=m,tactical=input.tactical}) then return nil,'wit' end
    local tried=input.tried
    if number(tried) and number(input.tick) and input.tick>=tried and input.tick-tried<M.gapSeconds*M.ticksPerSecond then
        return nil,'gap'
    end
    return {kind='hide',ordered=o.hide==true or nil}
end
return M
