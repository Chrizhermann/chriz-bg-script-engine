-- Synthetic durable facts only: no real quest phase or engine policy is selected.
local state = assert(loadfile(...))()
local limits = {maxDepth=8,maxNodes=64,maxBytes=4096,maxStringBytes=128}
local text = {kind='string',maxBytes=64}
local natural = {kind='number',integer=true,min=0,max=1000000}
local flag = {kind='number',integer=true,min=0,max=1}
local v1 = {kind='record',fields={flowId=text,phase=text}}
local v2 = {kind='record',fields={flowId=text,phase=text,epoch=natural}}
local v3 = {kind='record',fields={flowId=text,phase=text,epoch=natural,
    committed=flag,actorKeys={kind='array',maxItems=4,items=text}}}
local contract = {schemaId='research:durable-fixture',version=3,limits=limits,
    shapes={[1]=v1,[2]=v2,[3]=v3},migrations={
        [1]=function(p) p.epoch=0;return p end,
        [2]=function(p) p.committed=0;p.actorKeys={};return p end,
    }}
local function envelope(version,payload)
    return {schemaId=contract.schemaId,schemaVersion=version,payload=payload}
end
local function facts()
    return {flowId='test:flow',phase='fixture-ready',epoch=2,committed=1,actorKeys={'test:actor'}}
end
local function refused(value,shape,why,custom)
    local copy,reason=state.copy(value,shape,custom or limits)
    assert(copy==nil and reason==why,tostring(reason))
end

-- 1. Export is a deep scalar/table copy, never a reference to live state.
local live=facts()
local exported=assert(state.export(live,contract))
assert(exported.schemaVersion==3 and exported.payload~=live)
assert(exported.payload.actorKeys~=live.actorKeys and exported.payload.committed==1)
exported.payload.actorKeys[1]='test:other';assert(live.actorKeys[1]=='test:actor')
assert(state.load(nil,contract).status=='absent')

-- 2. Two sequential migrations work on a copy and validate each output.
local old=envelope(1,{flowId='test:flow',phase='fixture-ready'})
local upgraded=state.load(old,contract)
assert(upgraded.status=='ready' and upgraded.migrated==2 and upgraded.value.schemaVersion==3)
assert(upgraded.value.payload.epoch==0 and upgraded.value.payload.committed==0)
assert(old.schemaVersion==1 and old.payload.epoch==nil)

-- 3. Future/unknown schemas and corrupt fields quarantine only this record.
assert(state.load(envelope(4,{}),contract).reason=='future-schema')
local unknown=envelope(3,facts());unknown.schemaId='unknown'
assert(state.load(unknown,contract).reason=='schema-id')
local corrupt=facts();corrupt.epoch=-1
local bad=state.load(envelope(3,corrupt),contract)
assert(bad.status=='quarantined' and bad.reason=='number-range' and bad.value==nil)
assert(state.load(envelope(3,facts()),contract).status=='ready')

-- 4. No runtime handles/booleans/callbacks/threads or undeclared numeric IDs.
for _,value in ipairs({true,function() end,coroutine.create(function() end),io.stdout}) do
    local p=facts();p.actorKeys={value};refused(p,v3,'type')
end
local id=facts();id.objectId=123;refused(id,v3,'unknown-field')
id=facts();id.actorKeys={123};refused(id,v3,'type')
id=facts();id.committed=true;refused(id,v3,'type')

-- 5. Cycles and metatables fail without running caller code; finite numbers only.
local cyclicShape={kind='record',fields={}};cyclicShape.fields.child=cyclicShape
local cyclic={};cyclic.child=cyclic;refused(cyclic,cyclicShape,'cycle')
local calls=0
local decorated=setmetatable(facts(),{__index=function() calls=calls+1;error('must not run') end})
refused(decorated,v3,'metatable');assert(calls==0)
for _,n in ipairs({0/0,math.huge,-math.huge}) do refused(n,natural,'non-finite') end
-- Pinned EEex wire uses integer writers and NUL-terminated strings. Keep the
-- current direct numeric profile unsigned32; other values need explicit encoding.
for _,n in ipairs({0.5,-1,4294967296}) do refused(n,{kind='number'},'wire-number') end
assert(state.copy(4294967295,{kind='number'},limits)==4294967295)
refused('before\0after',text,'string-nul')

-- 6. Explicit budgets bound nesting, nodes, bytes, strings and array length/holes.
refused(facts(),v3,'node-limit',{maxDepth=8,maxNodes=2,maxBytes=4096,maxStringBytes=128})
refused(facts(),v3,'depth-limit',{maxDepth=1,maxNodes=64,maxBytes=4096,maxStringBytes=128})
refused(facts(),v3,'byte-limit',{maxDepth=8,maxNodes=64,maxBytes=2,maxStringBytes=128})
refused(string.rep('x',65),text,'string-limit')
refused({'a','b','c','d','e'},v3.fields.actorKeys,'array-limit')
refused({[2]='gap'},v3.fields.actorKeys,'array-shape')

-- 7. Failed/missing/invalid migrations never leak raw exception text or mutate input.
local original=contract.migrations[1]
contract.migrations[1]=function(p) p.phase='mutated';error('C:/private/path: secret') end
local failed=state.load(old,contract)
assert(failed.status=='quarantined' and failed.reason=='migration-failed' and failed.error==nil)
assert(old.payload.phase=='fixture-ready')
contract.migrations[1]=nil;assert(state.load(old,contract).reason=='migration-missing')
contract.migrations[1]=function(p) p.epoch='not-number';return p end
assert(state.load(old,contract).reason=='type')
contract.migrations[1]=original

-- 8. Envelope rejects unexpected/unsafe fields and version shapes, no silent stripping.
local extra=envelope(3,facts());extra.objectId=123
assert(state.load(extra,contract).reason=='envelope-shape')
assert(state.load(envelope(1.5,{}),contract).reason=='schema-version')
assert(state.load({schemaId=contract.schemaId,schemaVersion=3},contract).status=='quarantined')
assert(not pcall(state.copy,{},v1,{maxDepth=0,maxNodes=1,maxBytes=1,maxStringBytes=1}))

-- Trusted contract metadata is still serialized: reject invalid wire identifiers
-- and versions before an exporter can return an otherwise valid payload.
local admitted={}
for _,metadata in ipairs({
    {name='nul-id',id='research\0hidden',version=3},
    {name='oversized-id',id=string.rep('x',limits.maxStringBytes+1),version=3},
    {name='wide-version',id=contract.schemaId,version=4294967296},
}) do
    local badContract={schemaId=metadata.id,version=metadata.version,limits=limits,
        shapes={[metadata.version]=v3},migrations={}}
    if pcall(state.export,facts(),badContract) then admitted[#admitted+1]=metadata.name..'-export' end
    if pcall(state.load,nil,badContract) then admitted[#admitted+1]=metadata.name..'-load' end
end
assert(#admitted==0,'invalid contract metadata admitted: '..table.concat(admitted,','))
return 8
