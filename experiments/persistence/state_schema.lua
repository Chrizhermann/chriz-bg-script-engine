-- Research-only durable boundary: explicit field schemas, no native calls or storage.
-- Schemas/migrations are trusted code. They must declare semantic identities as strings;
-- a generic number validator cannot distinguish an epoch from a disguised object ID.
local M = {}

local function integer(n)
    return type(n)=='number' and n==n and n>-math.huge and n<math.huge and n%1==0
end
local function fail(reason) error({reason=reason},0) end

function M.copy(value,shape,limits)
    assert(type(limits)=='table','explicit persistence limits required')
    for _,key in ipairs({'maxDepth','maxNodes','maxBytes','maxStringBytes'}) do
        assert(integer(limits[key]) and limits[key]>0,'invalid persistence limit')
    end
    assert(limits.maxDepth<=64,'persistence depth is too large')
    local active,nodes,bytes={},0,0
    local function charge(text)
        if #text>limits.maxStringBytes then fail('string-limit') end
        bytes=bytes+#text
        if bytes>limits.maxBytes then fail('byte-limit') end
    end
    local function visit(input,schema,depth)
        if depth>limits.maxDepth then fail('depth-limit') end
        nodes=nodes+1
        if nodes>limits.maxNodes then fail('node-limit') end
        assert(type(schema)=='table','invalid trusted schema')
        local kind=schema.kind
        if kind=='number' then
            if type(input)~='number' then fail('type') end
            if input~=input or input==math.huge or input==-math.huge then fail('non-finite') end
            if schema.integer and input%1~=0 then fail('number-range') end
            if (schema.min and input<schema.min) or (schema.max and input>schema.max) then fail('number-range') end
            bytes=bytes+8
            if bytes>limits.maxBytes then fail('byte-limit') end
            return input
        elseif kind=='string' then
            if type(input)~='string' then fail('type') end
            charge(input)
            if (schema.maxBytes and #input>schema.maxBytes) or
                (schema.minBytes and #input<schema.minBytes) then fail('string-limit') end
            return input
        end
        assert(kind=='record' or kind=='array','unsupported trusted schema')
        if type(input)~='table' then fail('type') end
        if getmetatable(input)~=nil then fail('metatable') end
        if active[input] then fail('cycle') end
        active[input]=true
        local output={}
        if kind=='record' then
            assert(type(schema.fields)=='table','record fields required')
            for key,item in next,input do
                if type(key)~='string' or not schema.fields[key] then fail('unknown-field') end
                charge(key)
                output[key]=visit(item,schema.fields[key],depth+1)
            end
            for key,field in next,schema.fields do
                if rawget(input,key)==nil and not field.optional then fail('missing-field') end
            end
        else
            assert(integer(schema.maxItems) and schema.maxItems>=0,'array bound required')
            local count,highest=0,0
            for key in next,input do
                if not integer(key) or key<1 then fail('array-shape') end
                count=count+1;highest=math.max(highest,key)
                if count>schema.maxItems or highest>schema.maxItems then fail('array-limit') end
            end
            if highest~=count then fail('array-shape') end
            for i=1,count do output[i]=visit(rawget(input,i),schema.items,depth+1) end
        end
        active[input]=nil
        return output
    end
    local ok,result=pcall(visit,value,shape,1)
    if ok then return result end
    if type(result)=='table' and type(result.reason)=='string' then return nil,result.reason end
    return nil,'validation-failed'
end

local function checkContract(contract)
    assert(type(contract)=='table' and type(contract.schemaId)=='string' and #contract.schemaId>0
        and integer(contract.version) and contract.version>0 and type(contract.shapes)=='table'
        and type(contract.migrations)=='table','invalid persistence contract')
end

function M.export(payload,contract)
    checkContract(contract)
    local copied,reason=M.copy(payload,assert(contract.shapes[contract.version]),contract.limits)
    if not copied then return nil,reason end
    return {schemaId=contract.schemaId,schemaVersion=contract.version,payload=copied}
end

function M.load(envelope,contract)
    checkContract(contract)
    if envelope==nil then return {status='absent'} end
    local function quarantine(reason) return {status='quarantined',reason=reason} end
    if type(envelope)~='table' or getmetatable(envelope)~=nil then return quarantine('envelope-shape') end
    for key in next,envelope do
        if key~='schemaId' and key~='schemaVersion' and key~='payload' then
            return quarantine('envelope-shape')
        end
    end
    if envelope.schemaId~=contract.schemaId then return quarantine('schema-id') end
    local version=envelope.schemaVersion
    if not integer(version) or version<1 then return quarantine('schema-version') end
    if version>contract.version then return quarantine('future-schema') end
    local shape=contract.shapes[version]
    if not shape then return quarantine('unsupported-schema') end
    local payload,reason=M.copy(envelope.payload,shape,contract.limits)
    if not payload then return quarantine(reason) end
    local migrated=0
    while version<contract.version do
        local migration=contract.migrations[version]
        if type(migration)~='function' then return quarantine('migration-missing') end
        if not contract.shapes[version+1] then return quarantine('unsupported-schema') end
        -- Only the independent validated copy reaches trusted migration code.
        local ok,changed=pcall(migration,payload)
        if not ok then return quarantine('migration-failed') end
        payload,reason=M.copy(changed,contract.shapes[version+1],contract.limits)
        if not payload then return quarantine(reason) end
        version=version+1;migrated=migrated+1
    end
    return {status='ready',migrated=migrated,
        value={schemaId=contract.schemaId,schemaVersion=version,payload=payload}}
end

return M
