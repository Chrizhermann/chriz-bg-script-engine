-- Talk on sight (Christopher, 2026-11-03: a creature that speaks to the party as soon as it sees it
-- prepares when it sees the party, and the talk comes right after, so it cannot be caught
-- unprepared). The installer holds SCS's talk-on-sight blocks while BGSE_TalkHold says so and puts a
-- block of the engine's before them, which fires when BGSE_TalkExtras says so (bgse/lib/hook.tpa,
-- tools/hook_rule.py: patch_talk).
--
-- On the first ask the engine starts the creature's preparation: it turns on SCS's own switch for
-- preparing out of sight (offscreenprep), so SCS's prebuffs run in the scripts below the talk with
-- SCS's difficulty rules while the talk waits that script pass. On the next ask the switch goes back
-- to what it was, so SCS's free precasts do not fire again on every pass. Then, when the fight's
-- designer adds something for the creature (combat-intent/encounters.lua: a potion, instant copies
-- of spells it has memorized), the engine's own block fires once and queues it: a block of its own,
-- so that no later block of SCS's replaces those actions. The talk waits while the creature is busy,
-- at most TIMEOUT ticks. Plain values only; nothing here touches the engine.
local M={}
-- The longest a talk waits for the preparation, in game ticks (15 a second): it never stays stuck.
M.TIMEOUT=120

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

local function copy(state,changes)
    local s={}
    for k,v in pairs(state) do s[k]=v end
    for k,v in pairs(changes) do s[k]=v end
    return s
end

-- One ask of BGSE_TalkHold for a creature: state is what the last ask left (nil before the first),
-- facts {tick, on (the engine on), busy (an action running or queued), extras (the designer adds
-- something for it now)}. Returns whether the talk waits now, the state to keep, what happened
-- ('start': the adapter turns on offscreenprep; 'wait', 'done', 'timeout'; 'off': the engine is off,
-- the talk goes on as before and nothing is kept) and whether the switch goes back now (the first ask
-- after the start).
function M.step(state,facts)
    facts=type(facts)=='table' and facts or {}
    if facts.on~=true then return false,state,'off',false end
    local tick=number(facts.tick) and facts.tick or 0
    if type(state)~='table' then
        return true,{phase='preparing',since=tick,passes=0},'start',false
    end
    if state.phase~='preparing' and state.phase~='extras' then return false,state,nil,false end
    local passes=(number(state.passes) and state.passes or 0)+1
    local since=number(state.since) and state.since or tick
    local restore=state.phase=='preparing' and passes==1
    if tick-since>=M.TIMEOUT or tick<since then
        return false,copy(state,{phase='done',since=since,passes=passes}),'timeout',restore
    end
    if state.phase=='preparing' then
        if facts.busy==true then
            return true,copy(state,{since=since,passes=passes}),'wait',restore
        end
        if facts.extras==true then
            return true,copy(state,{phase='extras',since=since,passes=passes}),'wait',restore
        end
        return false,copy(state,{phase='done',since=since,passes=passes}),'done',restore
    end
    -- The designer's extras: the talk waits until the engine's block queued them and they ran.
    if state.queued~=true or facts.busy==true then
        return true,copy(state,{since=since,passes=passes}),'wait',false
    end
    return false,copy(state,{phase='done',since=since,passes=passes}),'done',false
end

-- One ask of BGSE_TalkExtras (the engine's block before the talk): whether that block fires now and
-- queues the designer's extras, once, after SCS's preparation had its pass; the state to keep, and
-- 'queue' when it fires.
function M.extras(state,facts)
    facts=type(facts)=='table' and facts or {}
    if facts.on~=true or type(state)~='table' or state.phase~='extras' or state.queued==true then
        return false,state,nil
    end
    return true,copy(state,{queued=true}),'queue'
end
return M
