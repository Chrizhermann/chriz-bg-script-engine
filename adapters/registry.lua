local manifest=require('kernel.manifest')
local eligibility=require('kernel.eligibility')
local M={}

function M.new()
    local entries,quarantine={},{}
    local epoch,stale
    local api={}
    function api:register(input)
        local m,reason=manifest.validate(input)
        if not m then return false,reason end
        if entries[m.id] then return false,'duplicate-adapter' end
        if epoch and epoch~=m.epoch then return false,'registry-epoch' end
        if stale then return false,'stale-stack' end
        epoch=m.epoch;entries[m.id]=m;return true
    end
    function api:quarantine(id,reason)
        if not entries[id] then return false,'unknown-adapter' end
        assert(type(reason)=='string' and #reason>0,'reason required')
        quarantine[id]=reason;return true
    end
    function api:evaluate(id,environment,identity)
        if not entries[id] then return {eligible=false,reason='unknown-adapter',fallback='legacy',dispatchAuthorized=false} end
        if type(environment)=='table' and rawget(environment,'epoch')~=epoch then stale=true end
        local result=eligibility.evaluate(entries[id],environment,identity)
        if stale or quarantine[id] then
            result.eligible=false;result.reason=stale and 'stale-stack' or quarantine[id]
        end
        return result
    end
    function api:report()
        local ids,lines={},{}
        for id in pairs(entries) do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids) do
            local m=entries[id]
            lines[#lines+1]=table.concat({id,'v'..m.version,m.tier,m.profile,
                table.concat(m.evidence,','),stale and 'stale-stack' or quarantine[id] or 'declared-not-activated'},' | ')
        end
        return table.concat(lines,'\n')
    end
    return api
end

return M
