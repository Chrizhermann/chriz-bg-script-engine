-- Talk on sight (Christopher, 2026-11-03: a creature that speaks to the party as soon as it sees it
-- prepares when it sees the party, and the talk comes right after, so it cannot be caught
-- unprepared). The installer holds SCS's talk-on-sight blocks while BGSE_TalkHold says so
-- (bgse/lib/hook.tpa, tools/hook_rule.py: patch_talk). On the first ask the engine starts the
-- creature's preparation: it turns on SCS's own switch for preparing out of sight (offscreenprep,
-- so SCS's prebuffs run with SCS's difficulty rules in the scripts below while the talk waits) and
-- queues what the fight's designer adds (combat-intent/encounters.lua). The talk waits at least one
-- script pass, for SCS's preparation to run, then until the creature is idle, at most TIMEOUT ticks.
-- Plain values only; nothing here touches the engine.
local M={}
-- The longest a talk waits for the preparation, in game ticks (15 a second): it never stays stuck.
M.TIMEOUT=90

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end

-- One ask of BGSE_TalkHold for a creature: state is what the last ask left (nil before the first),
-- facts {tick, on (the engine on), busy (the creature has an action running or queued)}. Returns
-- whether the talk waits now, the state to keep and what happened: 'start' (the preparation begins
-- now: the adapter sets offscreenprep and queues the designer's extras), 'wait', 'done', 'timeout'
-- or 'off' (the engine is off: the talk goes on as before, and nothing is kept).
function M.step(state,facts)
    facts=type(facts)=='table' and facts or {}
    if facts.on~=true then return false,state,'off' end
    local tick=number(facts.tick) and facts.tick or 0
    if type(state)~='table' then
        return true,{phase='preparing',since=tick,passes=0},'start'
    end
    if state.phase~='preparing' then return false,state,nil end
    local passes=(number(state.passes) and state.passes or 0)+1
    local since=number(state.since) and state.since or tick
    if tick-since>=M.TIMEOUT or tick<since then
        return false,{phase='done',since=since,passes=passes},'timeout'
    end
    if facts.busy==true then
        return true,{phase='preparing',since=since,passes=passes},'wait'
    end
    return false,{phase='done',since=since,passes=passes},'done'
end
return M
