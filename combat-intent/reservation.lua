-- Ephemeral, advisory group claims. Never authorizes native dispatch or spell expenditure.
local snapshot=require('combat-intent.snapshot')
local identity=require('kernel.identity')
local values=require('kernel.manifest')
local M={}
local nextBoardId=0

local function scalar(value) return values.copy(value) end
local function integer(value)
    return type(value)=='number' and value==value and value>=1 and
        value<9007199254740992 and value%1==0
end
local function same(a,b) return values.equal(a,b) end

local function context(raw)
    local current=scalar(raw)
    snapshot.record(current,{'sceneKey','groupKey','tick','combatActive','members','targets','spaces'})
    snapshot.assertKey(current.sceneKey);snapshot.assertKey(current.groupKey);snapshot.assertTick(current.tick)
    assert(type(current.combatActive)=='boolean','combatActive must be boolean')
    local members,targets,spaces={},{},{}
    snapshot.array(current.members,function(row)
        local id=assert(identity.validate(row))
        assert(not members[id.key],'duplicate member key');members[id.key]=id
    end)
    snapshot.array(current.targets,function(key)
        snapshot.assertKey(key);assert(not targets[key],'duplicate target');targets[key]=true
    end)
    snapshot.array(current.spaces,function(key)
        snapshot.assertKey(key);assert(not spaces[key],'duplicate space');spaces[key]=true
    end)
    return current,members,targets,spaces
end

local function request(raw,current,maxLifetime)
    local item=scalar(raw)
    assert(type(item)=='table','reservation request required')
    if item.kind=='target' then
        snapshot.record(item,{'kind','targetKey','expiresAt'})
        snapshot.assertKey(item.targetKey)
    elseif item.kind=='effect' then
        snapshot.record(item,{'kind','targetKey','effectKey','expiresAt'})
        snapshot.assertKey(item.targetKey);snapshot.assertKey(item.effectKey)
    elseif item.kind=='space' then
        snapshot.record(item,{'kind','spaceKey','expiresAt'})
        snapshot.assertKey(item.spaceKey)
    else error('undeclared reservation kind') end
    snapshot.assertTick(item.expiresAt)
    assert(item.expiresAt>current.tick and item.expiresAt-current.tick<=maxLifetime,
        'reservation lifetime out of bounds')
    return item
end

local function conflicts(a,b)
    return a.kind==b.kind and (a.kind=='space' and a.spaceKey==b.spaceKey or
        a.kind=='target' and a.targetKey==b.targetKey or
        a.kind=='effect' and a.targetKey==b.targetKey and a.effectKey==b.effectKey)
end

function M.new(raw)
    local config=scalar(raw)
    snapshot.record(config,{'sceneKey','groupKey','maxEntries','maxLifetimeTicks'})
    snapshot.assertKey(config.sceneKey);snapshot.assertKey(config.groupKey)
    assert(integer(config.maxEntries) and config.maxEntries<=256,'invalid reservation capacity')
    assert(integer(config.maxLifetimeTicks),'invalid reservation lifetime')
    nextBoardId=nextBoardId+1
    assert(nextBoardId<9007199254740992,'reservation board sequence exhausted')
    local boardId=nextBoardId
    local claims,lastTick,sequence,invalidated={},nil,0,false
    local api={}
    local function advance(current,members,targets,spaces)
        if invalidated then return nil,'board-invalidated' end
        if current.sceneKey~=config.sceneKey or current.groupKey~=config.groupKey or
            not current.combatActive then
            claims={};invalidated=true
            return nil,'board-invalidated'
        end
        if lastTick and current.tick<lastTick then return nil,'regressed-clock' end
        lastTick=current.tick
        for i=#claims,1,-1 do
            local row=claims[i]
            if row.expiresAt<=current.tick or not same(members[row.owner.key],row.owner) or
                (row.kind=='space' and not spaces[row.spaceKey]) or
                (row.kind~='space' and not targets[row.targetKey]) then
                table.remove(claims,i)
            end
        end
        return true
    end
    function api:reserve(rawOwner,rawRequest,rawCurrent)
        local owner=assert(identity.validate(rawOwner))
        local current,members,targets,spaces=context(rawCurrent)
        local item=request(rawRequest,current,config.maxLifetimeTicks)
        local ok,why=advance(current,members,targets,spaces)
        if not ok then return nil,why end
        if not same(members[owner.key],owner) then return nil,'owner-not-member' end
        if item.kind=='space' and not spaces[item.spaceKey] or
            item.kind~='space' and not targets[item.targetKey] then
            return nil,'subject-absent'
        end
        for _,row in ipairs(claims) do
            if conflicts(row,item) then
                if same(row.owner,owner) then return scalar(row) end
                return nil,'reserved-by-peer'
            end
        end
        if #claims>=config.maxEntries then return nil,'capacity' end
        sequence=sequence+1;assert(sequence<9007199254740992,'reservation sequence exhausted')
        local row=scalar(item);row.owner=owner;row.token='reservation:'..boardId..':'..sequence
        claims[#claims+1]=row
        return scalar(row)
    end
    function api:view(rawOwner,rawCurrent)
        local owner=assert(identity.validate(rawOwner))
        local current,members,targets,spaces=context(rawCurrent)
        local ok,why=advance(current,members,targets,spaces)
        if not ok then return nil,why end
        if not same(members[owner.key],owner) then return nil,'owner-not-member' end
        return scalar({sceneKey=current.sceneKey,groupKey=current.groupKey,tick=current.tick,
            combatActive=current.combatActive,members=current.members,targets=current.targets,
            spaces=current.spaces,claims=claims,dispatchAuthorized=false})
    end
    function api:release(rawOwner,token)
        local owner=assert(identity.validate(rawOwner))
        assert(type(token)=='string' and #token>0,'reservation token required')
        if invalidated then return false,'board-invalidated' end
        for i,row in ipairs(claims) do
            if row.token==token then
                if not same(row.owner,owner) then return false,'wrong-owner' end
                table.remove(claims,i);return true
            end
        end
        return false,'unknown-token'
    end
    function api:invalidate(reason)
        snapshot.assertKey(reason)
        claims={};invalidated=true
        return true
    end
    return api
end
return M
