local manifest = require('kernel.manifest')
local eligibility = require('kernel.eligibility')
local registry = require('adapters.registry')
local fixture = require('tests.unit.kernel.eligibility_fixture')
local function denied(change,reason)
    local m,e,a=fixture();change(m,e,a)
    local result=eligibility.evaluate(m,e,a)
    assert(not result.eligible and result.reason==reason,result.reason)
    assert(result.fallback=='legacy')
end

-- 1. Tiers are declarations, never automatic promotion or permission to dispatch.
for _,tier in ipairs({'C1','C2','C3','C4'}) do
    local m,e,a=fixture();m.tier=tier
    local result=eligibility.evaluate(m,e,a)
    assert(result.eligible and result.tier==tier and not result.dispatchAuthorized)
    assert(result.profile==m.profile and result.adapterId==m.id)
end
denied(function(m) m.tier='C0' end,'pass-through')
denied(function(m) m.schemaVersion=2 end,'manifest-schema')
denied(function(m) m.id='B-KTEST0' end,'manifest-id')
denied(function(m) m.domain='WorldFlow' end,'manifest-domain')
denied(function(m) m.version='' end,'manifest-version')
denied(function(m) m.hashAlgorithm='semantic' end,'manifest-hash')
denied(function(m) m.hashVersion=2 end,'manifest-hash')
denied(function(m) m.fallback=nil end,'manifest-fallback')
denied(function(m) m.provenance=nil end,'manifest-provenance')
denied(function(m) m.evidence={} end,'manifest-evidence')

-- 2. Exact dependency and script-slot/control closure, not the actor name, admits observation.
denied(function(_,e) e.resources['B-XTEST0.BCS']=nil end,'missing-resource')
denied(function(_,e) e.resources['B-XTEST0.BCS'].sha256=string.rep('c',64) end,'hash-mismatch')
denied(function(_,e) e.resources['B-XTEST0.BCS'].opaque=true end,'opaque-resource')
denied(function(_,e) e.resources['B-XTEST1.CRE'].slots.override='OTHERMOD' end,'slot-mismatch')
denied(function(_,e) e.resources['B-XTEST0.BCS'].dependencies={'OTHER.BCS'} end,'dependency-mismatch')
denied(function(m) m.resources['B-XTEST0.BCS']=nil end,'manifest-closure')
denied(function(_,e) e.externalControlComplete=false end,'incomplete-closure')
denied(function(_,e) e.closureComplete=false end,'incomplete-closure')
denied(function(_,e) e.controlClosure={'UNKNOWN.BCS'} end,'control-closure-mismatch')

-- 3. Public state reverse references and capabilities are part of the claim.
denied(function(m,e)
    m.publicState['GLOBAL:QUEST']={readers={'B-XTEST0.BCS'},writers={}}
    e.publicState['GLOBAL:QUEST']={readers={'B-XTEST0.BCS'},writers={'OTHER.BCS'}}
end,'public-state-mismatch')
denied(function(_,e) e.publicStateComplete=false end,'incomplete-closure')
denied(function(_,e) e.publicState['GLOBAL:OTHER']={readers={'OTHER.BCS'},writers={}} end,'public-state-mismatch')
denied(function(_,e) e.capabilities.observe=false end,'missing-capability')
denied(function(_,e) e.profile='older-profile' end,'profile-mismatch')
denied(function(_,e) e.epoch='stack-2' end,'stale-stack')

-- 4. Actor identity must be unique, fresh and explicitly rooted.
denied(function(_,_,a) a.resource='UNKNOWN.CRE' end,'unknown-resource')
denied(function(_,_,a) a.matches=2 end,'ambiguous-identity')
denied(function(_,_,a) a.epoch='old' end,'stale-identity')
denied(function(_,_,a) a.key=nil end,'invalid-identity')

-- 5. Result and normalized manifest are independent copies, not writable kernel state.
local m,e,a,copy=fixture();local original=copy(m)
local normalized=assert(manifest.validate(m));normalized.resources['B-XTEST0.BCS'].sha256='changed'
assert(m.resources['B-XTEST0.BCS'].sha256==original.resources['B-XTEST0.BCS'].sha256)
local result=eligibility.evaluate(m,e,a);result.evidence[1]='changed'
assert(m.evidence[1]=='BCS-01:E4' and e.resources['B-XTEST0.BCS'].sha256==string.rep('b',64))

-- 6. Per-adapter quarantine, duplicate-ID rejection and a sticky all-adapter drift latch.
local r=registry.new();assert(r:register(m));assert(not r:register(m))
local other=copy(m);other.id='B-/combat/other';assert(r:register(other))
assert(r:quarantine(m.id,'adapter-error'))
assert(r:evaluate(m.id,e,a).reason=='adapter-error')
assert(r:evaluate(other.id,e,a).eligible)
e.epoch='stack-2';assert(r:evaluate(other.id,e,a).reason=='stale-stack')
e.epoch='stack-1';assert(r:evaluate(other.id,e,a).reason=='stale-stack')

-- 7. Support report names exact declaration/evidence, and invalid data fails closed.
local report=r:report()
assert(report:find('B-/combat/other',1,true) and report:find('C1',1,true)
    and report:find('current-lab-v1',1,true) and report:find('BCS-01:E4',1,true))
assert(not report:find('compatible',1,true))
denied(function(m) m.resources['B-XTEST0.BCS'].extra=function() end end,'manifest-shape')
local bad={};bad.self=bad
assert(not eligibility.evaluate(bad,{},{}).eligible)
return 7
