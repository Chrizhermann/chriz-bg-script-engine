-- Fair evidence admission. No engine calls or balance/difficulty parameters.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local M={}
local selfOnly={spellbook=true,auraReady=true,idle=true,silenced=true,castingFailure=true,canAct=true}
local publicSources={sight=true,witnessed=true,inference=true}
local function unknown(reason,kind) return {kind=kind or 'unknown',reason=reason} end
local function proofText(value) return type(value)=='string' and #value>0 and #value<=128 and not value:find('%c') end
local function admit(field,evidence,actor,frame,allies)
    snapshot.assertField(field)
    snapshot.record(evidence,{'source','value','observedAt','expiresAt','confidence'}, {'origin','basis','evidenceSource'})
    snapshot.assertTick(evidence.observedAt);snapshot.assertTick(evidence.expiresAt)
    assert(evidence.expiresAt>evidence.observedAt,'invalid evidence lifetime')
    assert(type(evidence.confidence)=='number' and evidence.confidence>=0 and evidence.confidence<=1)
    snapshot.value(field,evidence.value)
    if evidence.source=='engine-private' then return unknown('forbidden-engine-knowledge') end
    if evidence.observedAt>frame.tick then return unknown('future-observation') end
    if evidence.expiresAt<=frame.tick then return unknown('evidence-expired','expired') end
    if selfOnly[field] and (actor.key~=frame.observerKey or evidence.source~='self') then return unknown('self-only-information') end
    local source=evidence.source
    local kind
    if source=='self' then
        if actor.key~=frame.observerKey then return unknown('not-self') end
        kind='observed'
    elseif source=='shared' then
        if not allies[evidence.origin] or evidence.origin==frame.observerKey then return unknown('ineligible-source-ally') end
        if not publicSources[evidence.evidenceSource] or not proofText(evidence.basis) then return unknown('missing-shared-provenance') end
        source=evidence.evidenceSource;kind='shared'
    elseif publicSources[source] then
        if not actor.visible or not actor.detected then return unknown('not-sensed') end
        kind=source=='inference' and 'inferred' or 'observed'
    else return unknown('unknown-perception-source') end
    -- Exact hidden resistance values cannot be learned merely by seeing an actor.
    if field=='resistances' and source~='self' and source~='inference' then return unknown('requires-public-inference') end
    if (field=='protections' or field=='lastCast') and source~='self' and source~='witnessed' and source~='inference' then return unknown('requires-public-witness') end
    if (source=='witnessed' or source=='inference') and not proofText(evidence.basis) then return unknown('missing-public-basis') end
    if kind=='observed' and evidence.observedAt<frame.tick then kind='remembered' end
    local result=copy(evidence);result.kind=kind;return result
end
function M.normalize(input)
    local frame=copy(input)
    snapshot.record(frame,{'schemaVersion','sceneKey','tick','observerKey','eligibleAllies','actors'})
    assert(frame.schemaVersion==1);snapshot.assertKey(frame.sceneKey);snapshot.assertTick(frame.tick);snapshot.assertKey(frame.observerKey)
    local allies={}
    snapshot.array(frame.eligibleAllies,function(key) snapshot.assertKey(key);assert(not allies[key]);allies[key]=true end)
    snapshot.array(frame.actors,function(actor)
        snapshot.record(actor,{'key','visible','detected','facts'})
        snapshot.assertKey(actor.key);assert(type(actor.visible)=='boolean' and type(actor.detected)=='boolean')
        assert(type(actor.facts)=='table')
        for field,evidence in pairs(actor.facts) do actor.facts[field]=admit(field,evidence,actor,frame,allies) end
    end)
    return frame
end
function M.build(input) return snapshot.new(input) end
return M
