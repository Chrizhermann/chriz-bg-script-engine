-- Authored SCS-derived examples, not copied BAF. SCS35.21 by David Wallace/DavidW.
-- See docs/provenance/scs/priest-turn-ledger.md for exact source and admission.
local shadow=require('adapters.scs.priest_turn_shadow')
local fixture=require('tests.unit.kernel.eligibility_fixture')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local function input()
    local m,e,id=fixture();m.id='B-/combat/priest-turn-shadow';m.evidence={'SCS-PRIEST-TURN:E2'}
    -- Exact authored priest fixture, not an admitted installed SCS actor.
    m.resources['B-XPRST0.CRE']=m.resources['B-XTEST1.CRE'];m.resources['B-XTEST1.CRE']=nil
    e.resources['B-XPRST0.CRE']=e.resources['B-XTEST1.CRE'];e.resources['B-XTEST1.CRE']=nil
    m.roots={'B-XPRST0.CRE'};id.resource='B-XPRST0.CRE';id.key='synthetic/priest-1'
    return {sourceRevision='5dc240e9ff85d3909b6436e54b56297d3b61e33b',nonDruid=true,
        manifest=m,environment=e,identity=id,context={sceneKey='synthetic/priest',observerKey=id.key,tick=10},
        ownership={player=false,hardMode=false,world=false,encounter=false,forced=false,dialogue=false,
            cutscene=false,staging=false,imageOwner=false,alive=true,active=true,hostile=true,
            actionIdle=true,auraReady=true,capable=true,eligible=true},
        observation={sceneKey='synthetic/priest',observerKey=id.key,tick=10,
            target={key='target/undead',seeGoodcutoffUndead=true,disabled=false},
            castTimerActive=false,initTimerActive=false,turningTimerActive=false}}
end
local raw=input();local original=copy(raw);local initial=shadow.evaluate(raw)
assert(initial.branch=='initialize' and not initial.dispatchAuthorized)
assert(initial.proposal.kind=='shadow-turn-initialize' and #initial.proposal.writes==2)
assert(initial.proposal.writes[1].name=='turninitialise' and initial.proposal.writes[1].argument==30)
assert(initial.proposal.writes[2].name=='turning' and initial.proposal.writes[2].argument==4)
assert(initial.proposal.continueLegacy and initial.proposal.requiresFreshObservation)
assert(equal(raw,original) and equal(shadow.replay(initial),initial))
initial.proposal.writes[1].argument=0
assert(not shadow.replay(initial),'tampered rule outcome replayed')
local groups=1

raw=input();raw.observation.initTimerActive=true;raw.observation.turningTimerActive=true
local turning=shadow.evaluate(raw)
assert(turning.branch=='turn' and turning.proposal.kind=='shadow-turn' and turning.proposal.targetKey=='target/undead')
assert(equal(shadow.replay(turning),turning))
raw.observation.turningTimerActive=false
assert(shadow.evaluate(raw).reason=='turn-window-inactive')
raw.observation.initTimerActive=false
assert(shadow.evaluate(raw).branch=='initialize','source first-branch order changed')
groups=groups+1

for _,change in ipairs({function(x) x.observation.target=false end,
 function(x) x.observation.target.disabled=true end,
 function(x) x.observation.target.seeGoodcutoffUndead=false end,
 function(x) x.observation.castTimerActive=true end,
 function(x) x.nonDruid=false end,
 function(x) x.observation.target.disabled='unknown' end,
 function(x) x.observation.turningTimerActive='unknown' end}) do
 raw=input();change(raw);assert(shadow.evaluate(raw).proposal==false)
end
groups=groups+1

local function denied(change,reason)
 local x=input();change(x);local result=shadow.evaluate(x)
 assert(result.branch=='decline' and result.reason==reason and result.proposal==false,result.reason)
end
denied(function(x) x.sourceRevision='newer-unreviewed' end,'unreviewed-source')
denied(function(x) x.manifest.id='B-/combat/unrelated-family' end,'unreviewed-family')
denied(function(x)
    x.manifest.resources['B-XTEST1.CRE']=x.manifest.resources['B-XPRST0.CRE']
    x.manifest.resources['B-XPRST0.CRE']=nil
    x.environment.resources['B-XTEST1.CRE']=x.environment.resources['B-XPRST0.CRE']
    x.environment.resources['B-XPRST0.CRE']=nil
    x.manifest.roots={'B-XTEST1.CRE'};x.identity.resource='B-XTEST1.CRE'
end,'unreviewed-family')
denied(function(x) x.environment.resources['B-XTEST0.BCS'].sha256=string.rep('c',64) end,'hash-mismatch')
denied(function(x) x.environment.externalControlComplete=false end,'incomplete-closure')
denied(function(x) x.environment.controlClosure={'UNKNOWN.BCS'} end,'control-closure-mismatch')
denied(function(x) x.ownership.encounter=true end,'higher-world-owner')
denied(function(x) x.ownership.hostile=false end,'blocked-hostile')
denied(function(x) x.observation.tick=9 end,'stale-observation')
denied(function(x) x.observation.observerKey='another/priest' end,'stale-observation')
denied(function(x) x.context.observerKey='another/priest';x.observation.observerKey='another/priest' end,'observer-identity-mismatch')
groups=groups+1

raw=input();raw.observation.target.key=raw.identity.key
assert(shadow.evaluate(raw).reason=='invalid-selected-target')
raw=input();raw.observation.castTimerActive=1
assert(not pcall(shadow.evaluate,raw),'numeric truthy timer accepted')
raw=input();raw.observation.target.extra='second-unbound-target'
assert(not pcall(shadow.evaluate,raw),'unbound target fact accepted')
local result=shadow.evaluate(input());result.input.observation.target.disabled=true
assert(not shadow.replay(result),'changed predicate frame replayed')
groups=groups+1
return groups
