-- Disposable one-move driver/observer. Explicitly loaded once, never autoloaded or released.
local root = assert(rawget(_G, 'B-'))
assert(root.project == 'chriz-bg-script-engine' and not root.actionProbe, 'probe/root occupied')
local model = assert(loadfile('override/B-XACT00.lua'))()
local trampoline = assert(loadfile('override/B-XOBS00.lua'))()
local probe = {events={}, epoch=0, starts=0}
root.actionProbe = probe
local names = {'EEex_Action_AddSpriteStartedActionListener', 'EEex_GameState_AddDestroyedListener',
    'EEex_Action_QueueResponseStringOnAIBase', 'EEex_Sprite_GetInPortrait', 'EEex_Sprite_GetName',
    'EEex_Sprite_GetNumCharacters', 'EEex_Utility_IterateCPtrList',
    'Infinity_IsMenuOnStack', 'Infinity_GetTransitionInProgress'}
local api = {}
for _, name in ipairs(names) do api[name] = assert(_G[name], name) end
local function available()
    if not EEex_Active then return false end
    for _, name in ipairs(names) do
        if type(api[name]) ~= 'function' or _G[name] ~= api[name] then return false end
    end
    return true
end
local function event(kind, x, y, action, reason)
    if #probe.events == 32 then table.remove(probe.events,1) end
    probe.events[#probe.events+1] = {kind=kind,x=x,y=y,action=action,reason=reason}
end
local function fresh()
    assert(available() and not probe.disabled, 'probe unavailable')
    assert(api.Infinity_IsMenuOnStack('WORLD_ACTIONBAR') and
        not api.Infinity_GetTransitionInProgress(), 'not world-ready')
    assert(api.EEex_Sprite_GetNumCharacters()==1, 'not the single-character fixture')
    local sprite=assert(api.EEex_Sprite_GetInPortrait(0))
    assert(api.EEex_Sprite_GetName(sprite)=='BGSE Lab Test', 'wrong fixture')
    assert(sprite.m_pArea.m_resref:get()=='BG2602', 'wrong test area')
    return sprite
end
local function queue_snapshot(sprite)
    local queued={}
    api.EEex_Utility_IterateCPtrList(assert(sprite.m_queuedActions),function(action)
        queued[#queued+1]={id=action.m_actionID,x=action.m_dest.x,y=action.m_dest.y}
    end)
    return queued
end
trampoline.attach(probe, {
    started=api.EEex_Action_AddSpriteStartedActionListener,
    destroyed=api.EEex_GameState_AddDestroyedListener,
}, {
    started=function(sprite, action)
        if not probe.attempt or api.EEex_Sprite_GetName(sprite)~='BGSE Lab Test' then return end
        local id=action.m_actionID
        if id~=23 then event('other-action-start',nil,nil,id); return end
        local x,y=action.m_dest.x,action.m_dest.y
        event('action-start',x,y,id)
        if x==probe.target.x and y==probe.target.y then
            probe.starts=probe.starts+1
            local why
            probe.attempt,why=model.reduce(probe.attempt,{attemptId='movement-1',kind='started'})
            event('start-reduction',x,y,id,why)
        end
    end,
    destroyed=function()
        probe.epoch=probe.epoch+1
        if probe.attempt then
            probe.attempt=model.reduce(probe.attempt,{attemptId='movement-1',kind='invalidated',reason='session-destroyed'})
        end
    end,
}, available)

function probe.begin(x,y)
    assert(not probe.attempt, 'one attempt only: no retry')
    assert(type(x)=='number' and x==math.floor(x) and type(y)=='number' and y==math.floor(y))
    local sprite=fresh()
    local sx,sy=sprite.m_pos.x,sprite.m_pos.y
    assert(x>=0 and y>=0 and math.abs(x-sx)<=96 and math.abs(y-sy)<=96 and
        (math.abs(x-sx)>8 or math.abs(y-sy)>8), 'target not a distinct nearby point')
    assert(sprite.m_curAction.m_actionID==0, 'fixture is busy; do not clear its queue')
    assert(#queue_snapshot(sprite)==0, 'fixture has queued work')
    probe.attempt=model.new('movement-1')
    probe.target={x=x,y=y}
    probe.before={x=sx,y=sy}
    event('proposed',sx,sy)
    api.EEex_Action_QueueResponseStringOnAIBase(string.format('MoveToPoint([%d.%d])',x,y),sprite)
    local queued=queue_snapshot(sprite)
    if probe.starts~=0 or #queued~=1 or queued[1].id~=23 or queued[1].x~=x or queued[1].y~=y then
        probe.attempt=model.reduce(probe.attempt,{attemptId='movement-1',kind='unknown',reason='unexpected-submission-order-or-queue'})
        event('unknown',sprite.m_pos.x,sprite.m_pos.y)
        return {attempt=probe.attempt,queued=queued,starts=probe.starts}
    end
    probe.attempt=model.reduce(probe.attempt,{attemptId='movement-1',kind='accepted'})
    event('accepted',sprite.m_pos.x,sprite.m_pos.y)
    return {attempt=probe.attempt,before=probe.before,target=probe.target,starts=probe.starts,queued=queued}
end

function probe.sample()
    local sprite=fresh()
    local x,y=sprite.m_pos.x,sprite.m_pos.y
    if probe.attempt and probe.attempt.state=='started' and probe.starts>0 and
        math.abs(x-probe.target.x)<=3 and math.abs(y-probe.target.y)<=3 then
        probe.attempt=model.reduce(probe.attempt,{attemptId='movement-1',kind='completed',proof='independent-postcondition'})
    end
    event('position-sample',x,y,sprite.m_curAction.m_actionID)
    return {attempt=probe.attempt,before=probe.before,target=probe.target,x=x,y=y,
        starts=probe.starts,epoch=probe.epoch,events=probe.events,disabled=probe.disabled}
end

return {ready=not probe.disabled,registrations=probe.registrations}
