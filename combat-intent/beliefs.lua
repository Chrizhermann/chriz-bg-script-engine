-- Ephemeral, observer-owned memory of admitted scalar facts. No engine or save access.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local M={}
local known={observed=true,remembered=true,shared=true,inferred=true}

local function countEntries(entries)
    local count=0
    for _,fields in pairs(entries) do
        for _ in pairs(fields) do count=count+1 end
    end
    return count
end

local function cloneEntries(entries)
    local cloned={}
    for subject,fields in pairs(entries) do
        local selected={}
        for field,fact in pairs(fields) do selected[field]=fact end
        cloned[subject]=selected
    end
    return cloned
end

function M.new(config)
    assert(type(config)=='table' and getmetatable(config)==nil,'invalid-beliefs-config')
    snapshot.assertKey(config.observerKey)
    local observerKey=config.observerKey
    local limit=config.maxEntries
    assert(type(limit)=='number' and limit==limit and limit>=1 and
        limit<math.huge and limit%1==0,'invalid-beliefs-capacity')

    local entries,size={},0
    local sceneKey
    local api={}

    function api:observe(view)
        if not snapshot.isView(view) then return false,'invalid-view' end
        local data=view:export()
        if data.observerKey~=observerKey then return false,'observer-mismatch' end
        -- A fresh area/session/stack scene cannot inherit old target memory.
        if sceneKey~=nil and sceneKey~=data.sceneKey then entries,size={},0 end
        sceneKey=data.sceneKey

        -- Stage the whole update. Existing facts are immutable within this table;
        -- fresh evidence is copied before replacement, so failure cannot leak writes.
        local staged=cloneEntries(entries)
        local actors={}
        for _,actor in ipairs(data.actors) do actors[#actors+1]=actor end
        table.sort(actors,function(a,b) return a.key<b.key end)
        for _,actor in ipairs(actors) do
            local fields={}
            for field in pairs(actor.facts) do fields[#fields+1]=field end
            table.sort(fields)
            for _,field in ipairs(fields) do
                local fact=actor.facts[field]
                if known[fact.kind] and fact.expiresAt>data.tick then
                    local selected=staged[actor.key]
                    local previous=selected and selected[field]
                    if not previous or fact.observedAt>=previous.observedAt then
                        if not selected then selected={};staged[actor.key]=selected end
                        selected[field]=copy(fact)
                    end
                end
            end
        end

        local nextSize=countEntries(staged)
        if nextSize>limit then
            for subject,fields in pairs(staged) do
                for field,fact in pairs(fields) do
                    if fact.expiresAt<=data.tick then fields[field]=nil end
                end
                if next(fields)==nil then staged[subject]=nil end
            end
            nextSize=countEntries(staged)
        end
        if nextSize>limit then return false,'capacity' end
        entries,size=staged,nextSize
        return true
    end

    function api:read(subjectKey,field,tick)
        snapshot.assertKey(subjectKey)
        snapshot.assertField(field)
        snapshot.assertTick(tick)
        local selected=entries[subjectKey]
        local fact=selected and selected[field]
        if not fact then return {kind='unknown',reason='absent-belief'} end
        if tick<fact.observedAt then return {kind='unknown',reason='future-belief'} end
        if tick>=fact.expiresAt then return {kind='expired',reason='belief-expired'} end
        local result=copy(fact)
        if result.kind=='observed' or result.kind=='remembered' then result.kind='remembered' end
        result.age=tick-result.observedAt
        return result
    end

    function api:invalidate()
        entries,size={},0
        sceneKey=nil
    end

    function api:size() return size end
    return api
end

return M
