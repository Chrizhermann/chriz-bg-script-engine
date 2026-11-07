-- Runtime eligibility requires a working feature and a unique live identity.  It does not
-- fingerprint game resources: an installed mod or a hand edit still receives the declared action.
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
    for _,cap in ipairs(m.requiredCapabilities) do
        if type(e.capabilities)~='table' or e.capabilities[cap]~=true then return deny('missing-capability') end
    end
    if type(a.key)~='string' or #a.key==0 or type(a.resource)~='string' then return deny('invalid-identity') end
    if a.matches~=1 then return deny('ambiguous-identity') end
    if a.epoch~=e.epoch then return deny('stale-identity') end
    result.eligible,result.reason=true,'runtime-ready'
    return result
end

return M
