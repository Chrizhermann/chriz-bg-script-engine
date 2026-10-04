-- SCS-derived two-branch shadow model; SCS35.21 by David Wallace (DavidW).
-- No native calls or timer writes. See docs/provenance/scs/priest-turn-ledger.md.
local manifest=require('kernel.manifest')
local eligibility=require('kernel.eligibility')
local ownership=require('kernel.ownership')
local snapshot=require('combat-intent.snapshot')
local M={}
local revision='5dc240e9ff85d3909b6436e54b56297d3b61e33b'
local function truth(value) assert(type(value)=='boolean' or value=='unknown','predicate must be known or unknown') end
local function context(c)
    snapshot.record(c,{'sceneKey','observerKey','tick'})
    snapshot.assertKey(c.sceneKey);snapshot.assertKey(c.observerKey);snapshot.assertTick(c.tick)
end
function M.evaluate(raw)
    local input=manifest.copy(raw)
    snapshot.record(input,{'sourceRevision','nonDruid','manifest','environment','identity',
        'ownership','context','observation'})
    local result={schemaVersion=1,input=input,branch='decline',reason='unreviewed-source',
        proposal=false,dispatchAuthorized=false}
    local function deny(reason) result.reason=reason;return result end
    if input.sourceRevision~=revision then return result end
    -- This is source-generation/fixture eligibility, not a native IsDruid trigger.
    truth(input.nonDruid)
    if input.nonDruid~=true then return deny('generation-not-admitted') end
    local admitted=eligibility.evaluate(input.manifest,input.environment,input.identity)
    if not admitted.eligible then return deny(admitted.reason) end
    -- This checkpoint admits only this authored host fixture, never arbitrary
    -- eligible actors or an installed priest inferred from a caller's flags.
    if input.manifest.id~='B-/combat/priest-turn-shadow' or
        not manifest.equal(input.manifest.roots,{'B-XPRST0.CRE'}) or
        input.identity.resource~='B-XPRST0.CRE' then return deny('unreviewed-family') end
    local owner=ownership.decide(input.ownership)
    if not owner.combat then return deny(owner.reason) end
    context(input.context)
    if input.context.observerKey~=input.identity.key then return deny('observer-identity-mismatch') end
    local o=input.observation
    snapshot.record(o,{'sceneKey','observerKey','tick','target','castTimerActive','initTimerActive','turningTimerActive'})
    snapshot.assertKey(o.sceneKey);snapshot.assertKey(o.observerKey);snapshot.assertTick(o.tick)
    if o.sceneKey~=input.context.sceneKey or o.observerKey~=input.context.observerKey or
        o.tick~=input.context.tick then return deny('stale-observation') end
    for _,key in ipairs({'castTimerActive','initTimerActive','turningTimerActive'}) do
        truth(o[key]);if o[key]=='unknown' then return deny('timer-unknown') end
    end
    if o.target==false then return deny('no-observed-target') end
    -- One target report binds See's selected actor and its LastSeenBy state check.
    snapshot.record(o.target,{'key','seeGoodcutoffUndead','disabled'})
    snapshot.assertKey(o.target.key);truth(o.target.seeGoodcutoffUndead);truth(o.target.disabled)
    if o.target.key==o.observerKey then return deny('invalid-selected-target') end
    if o.target.seeGoodcutoffUndead~=true then return deny('undead-sight-unproved') end
    if o.target.disabled~=false then return deny('target-disabled-or-unknown') end
    if o.castTimerActive then return deny('cast-timer-active') end
    if not o.initTimerActive then
        result.branch='initialize';result.reason='initial-window'
        result.proposal={kind='shadow-turn-initialize',writes={
            {name='turninitialise',scope='LOCALS',argument=30},
            {name='turning',scope='LOCALS',argument=4}},
            continueLegacy=true,requiresFreshObservation=true}
    elseif o.turningTimerActive then
        result.branch='turn';result.reason='active-window'
        -- targetKey is evidence context, not a Turn() target argument.
        result.proposal={kind='shadow-turn',targetKey=o.target.key}
    else return deny('turn-window-inactive') end
    return result
end
function M.replay(record)
    local saved=manifest.copy(record)
    snapshot.record(saved,{'schemaVersion','input','branch','reason','proposal','dispatchAuthorized'})
    local regenerated=M.evaluate(saved.input)
    if not manifest.equal(saved,regenerated) then return nil,'trace-disagreement' end
    return regenerated
end
return M
