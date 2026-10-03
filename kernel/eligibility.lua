-- Static eligibility is necessary, never sufficient, for a runtime action claim.
local manifest=require('kernel.manifest')
local M={}

function M.evaluate(input,environment,identity)
    local m,reason=manifest.validate(input)
    local result={eligible=false,reason=reason,fallback='legacy',dispatchAuthorized=false}
    if not m then return result end
    result.adapterId,result.version,result.tier=m.id,m.version,m.tier
    result.profile,result.evidence=m.profile,manifest.copy(m.evidence)
    local function deny(code) result.reason=code;return result end
    local ok,e,a=pcall(function() return manifest.copy(environment),manifest.copy(identity) end)
    if not ok or type(e)~='table' or type(a)~='table' then return deny('invalid-observation') end
    if m.tier=='C0' then return deny('pass-through') end
    if e.profile~=m.profile then return deny('profile-mismatch') end
    if e.epoch~=m.epoch then return deny('stale-stack') end
    if e.closureComplete~=true or e.externalControlComplete~=true or e.publicStateComplete~=true then
        return deny('incomplete-closure')
    end
    if not manifest.equal(e.controlClosure,m.controlClosure) then return deny('control-closure-mismatch') end
    for _,cap in ipairs(m.requiredCapabilities) do
        if type(e.capabilities)~='table' or e.capabilities[cap]~=true then return deny('missing-capability') end
    end
    for id,expected in pairs(m.resources) do
        local actual=type(e.resources)=='table' and e.resources[id]
        if type(actual)~='table' then return deny('missing-resource') end
        if actual.opaque~=false then return deny('opaque-resource') end
        if actual.sha256~=expected.sha256 then return deny('hash-mismatch') end
        if not manifest.equal(actual.slots,expected.slots) then return deny('slot-mismatch') end
        if not manifest.equal(actual.dependencies,expected.dependencies) then return deny('dependency-mismatch') end
    end
    -- These observations describe the claimed closure, not every variable in the game.
    if not manifest.equal(m.publicState,e.publicState) then return deny('public-state-mismatch') end
    if type(a.key)~='string' or #a.key==0 or type(a.resource)~='string' then return deny('invalid-identity') end
    if a.matches~=1 then return deny('ambiguous-identity') end
    if a.epoch~=e.epoch then return deny('stale-identity') end
    local rooted=false;for _,id in ipairs(m.roots) do if a.resource==id then rooted=true end end
    if not rooted then return deny('unknown-resource') end
    result.eligible,result.reason=true,'exact-match'
    return result
end

return M
