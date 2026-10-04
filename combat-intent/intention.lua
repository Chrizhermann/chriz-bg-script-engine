-- A bounded purpose with one currently offered semantic step, not an action queue.
-- The caller must regenerate a legal decision and obtain an ordinary dispatch lease.
local values=require('kernel.manifest')
local identity=require('kernel.identity')
local scalar=require('combat-intent.snapshot')
local attempt=require('kernel.action_attempt')
local M={}
local instances=0 -- transient tokens only; never persist across module/session reload

local function facts(record,booleans)
    assert(type(record)=='table')
    for key,value in pairs(record) do
        scalar.assertKey(key)
        assert(type(value)=='boolean' or not booleans and
            (type(value)=='string' or type(value)=='number'),'scalar fact required')
    end
end
local function frame(input)
    local f=values.copy(input)
    scalar.record(f,{'sceneKey','tick','identity','enabled','combatActive','facts','legalSteps'})
    scalar.assertKey(f.sceneKey);scalar.assertTick(f.tick)
    assert(f.identity==false or identity.validate(f.identity),'semantic identity required')
    assert(type(f.enabled)=='boolean' and type(f.combatActive)=='boolean')
    facts(f.facts);facts(f.legalSteps,true)
    return f
end

function M.new(input)
    local config=values.copy(input)
    scalar.record(config,{'identity','sceneKey','maxSteps','maxLifetimeTicks'})
    assert(identity.validate(config.identity));scalar.assertKey(config.sceneKey)
    scalar.assertTick(config.maxSteps);assert(config.maxSteps>=1 and config.maxSteps<=3)
    scalar.assertTick(config.maxLifetimeTicks);assert(config.maxLifetimeTicks>0)
    instances=instances+1;local instance=instances
    local state={status='idle'}
    local sequence,lastTick,invalid=0,nil,nil
    local stepAttempt
    local api={}
    local function abort(reason)
        state.status='aborted';state.reason=reason;stepAttempt=nil
    end
    local function check(f,planChecks)
        if invalid then return nil,invalid end
        if f.sceneKey~=config.sceneKey then
            invalid='scene-changed';abort(invalid);return nil,invalid
        end
        assert(not lastTick or f.tick>=lastTick,'intention clock regressed')
        lastTick=f.tick
        local reason
        if not values.equal(f.identity,config.identity) then reason='identity-lost'
        elseif not f.enabled then reason='disabled'
        elseif not f.combatActive then reason='combat-ended'
        elseif planChecks and state.status=='active' then
            if f.tick>=state.plan.expiresAt then reason='expired'
            else
                for key,value in pairs(state.plan.assumptions) do
                    if f.facts[key]~=value then reason='assumption-changed';break end
                end
            end
        end
        if reason then if state.status=='active' then abort(reason) end;return nil,reason end
        return f
    end
    function api:begin(input,current)
        local plan=values.copy(input)
        scalar.record(plan,{'purpose','steps','expiresAt','assumptions'})
        scalar.assertKey(plan.purpose);scalar.assertTick(plan.expiresAt);facts(plan.assumptions)
        local count=0
        scalar.array(plan.steps,function(label) scalar.assertKey(label);count=count+1 end)
        assert(count>=1 and count<=config.maxSteps,'intention step bound')
        local f=frame(current)
        assert(plan.expiresAt>f.tick and plan.expiresAt-f.tick<=config.maxLifetimeTicks,'intention lifetime bound')
        local ok,why=check(f,false);if not ok then return nil,why end
        if state.status=='active' then return nil,'intention-active' end
        for key,value in pairs(plan.assumptions) do
            if f.facts[key]~=value then return nil,'assumption-changed' end
        end
        sequence=sequence+1;stepAttempt=nil
        state={status='active',plan=plan,index=1,sequence=sequence,createdAt=f.tick}
        return self:inspect()
    end
    function api:next(current)
        local f,why=check(frame(current),true);if not f then return nil,why end
        if state.status~='active' then return nil,state.reason or state.status end
        if stepAttempt and stepAttempt.state~='proposed' then return nil,'step-in-flight' end
        local label=state.plan.steps[state.index]
        if f.legalSteps[label]~=true then abort('step-no-longer-legal');return nil,state.reason end
        if not stepAttempt then stepAttempt=attempt.new('intention:'..instance..':'..sequence..':'..state.index) end
        return {token=stepAttempt.attemptId,purpose=state.plan.purpose,step=label,index=state.index,
            expiresAt=state.plan.expiresAt,sceneKey=config.sceneKey,identity=values.copy(config.identity),
            tick=f.tick,dispatchAuthorized=false}
    end
    function api:observe(token,input,current)
        local event=values.copy(input)
        scalar.record(event,{'kind'},{'reason','proof'})
        local f,why=check(frame(current),true);if not f then return nil,why end
        if state.status~='active' or not stepAttempt or token~=stepAttempt.attemptId then
            return nil,'stale-step'
        end
        event.attemptId=token
        local result,reason=attempt.reduce(stepAttempt,event)
        if reason~='applied' then return nil,reason end
        stepAttempt=result
        if result.state=='completed' then
            state.index=state.index+1;stepAttempt=nil
            if state.index>#state.plan.steps then state.status='completed' end
        elseif result.state=='failed' or result.state=='interrupted' or result.state=='invalidated' or
            result.state=='timed-out' or result.state=='unknown' then abort(result.state) end
        return self:inspect()
    end
    function api:cancel(reason)
        scalar.assertKey(reason)
        if state.status=='active' then abort(reason) end
        return self:inspect()
    end
    function api:invalidate(reason)
        scalar.assertKey(reason);invalid=reason;abort(reason)
        return self:inspect()
    end
    function api:inspect()
        local out=values.copy(state)
        out.stepAttempt=stepAttempt and values.copy(stepAttempt) or false
        out.dispatchAuthorized=false
        return out
    end
    return api
end
return M
