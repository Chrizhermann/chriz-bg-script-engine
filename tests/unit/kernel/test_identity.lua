-- Scalar semantic identities only; no session-local engine handles.
local identity = assert(loadfile(...))()
local function specimen()
    return {adapterId='B-/combat/mage-pilot',key='actor:mage-1',resource='B-XMAGE1.CRE'}
end

-- 1. Validation copies the exact declared fields and never aliases input.
local source=specimen()
local validated,reason=identity.validate(source)
assert(validated and reason==nil and validated~=source)
assert(validated.adapterId==source.adapterId and validated.key==source.key and
    validated.resource==source.resource)
source.key='actor:changed'
assert(validated.key=='actor:mage-1')
local worldflow=identity.validate({adapterId='B-/worldflow/quest-1',
    key='quest:chapter-1',resource='B-XDIAL0.DLG'})
assert(worldflow and worldflow.resource=='B-XDIAL0.DLG')

-- 2. The identity shape refuses numeric/session forms and unknown fields.
assert(select(2,identity.validate(nil))=='invalid-identity')
for _,bad in ipairs({42,'actor:mage-1',io.stdout,{},
    {adapterId='B-/combat/mage-pilot',key=123,resource='B-XMAGE1.CRE'},
    {adapterId='B-/combat/mage-pilot',key='123',resource='B-XMAGE1.CRE'},
    {adapterId='B-/combat/mage-pilot',key='0x2A',resource='B-XMAGE1.CRE'},
    {adapterId='B-/combat/mage-pilot',key=' 42 ',resource='B-XMAGE1.CRE'},
    {adapterId='B-/combat/mage-pilot',key='',resource='B-XMAGE1.CRE'},
    {adapterId='B-/combat/mage-pilot',key='actor:mage-1',resource='B-XMAGE1.CRE',objectId=42},
    {adapterId='B-/combat/mage-pilot',key='actor:mage-1',resource='B-XMAGE1.CRE',handle={}},
}) do
    local value,why=identity.validate(bad)
    assert(value==nil and why=='invalid-identity')
end

-- 3. Adapter and resource spelling is canonical and typed.
for _,badId in ipairs({'B-/other/mage','B-/combat/','B-/combat/Bad','combat/mage',
    'B-/combat/mage/extra'}) do
    local value=specimen();value.adapterId=badId
    assert(select(2,identity.validate(value))=='invalid-identity')
end
for _,badResource in ipairs({'b-xmage1.CRE','B-XMAGE1.cre','B-XMAGE12.CRE',
    'B-XMAGE1.SPL','B-XMAGE1','B-XMAGE1.CRE/extra'}) do
    local value=specimen();value.resource=badResource
    assert(select(2,identity.validate(value))=='invalid-identity')
end

-- 4. Each resolution checks current candidates; exact duplicates decline.
local target=specimen()
local candidates={
    {key='actor:other',resource='B-XMAGE1.CRE',epoch='stack-1',area='AR0001.ARE'},
    {key=target.key,resource='B-XMAGE1.CRE',epoch='stack-1',area='AR0001.ARE'},
    {key=target.key,resource='B-XOTHER.CRE',epoch='stack-1',area='AR0001.ARE'},
}
local resolved=assert(identity.resolve(target,candidates))
assert(resolved~=candidates[2] and resolved.key==target.key and resolved.matches==1)
assert(resolved.epoch=='stack-1' and resolved.area=='AR0001.ARE' and resolved.objectId==nil)
resolved.epoch='changed'
assert(candidates[2].epoch=='stack-1')
assert(select(2,identity.resolve(target,{}))=='absent-identity')
candidates[4]={key=target.key,resource=target.resource,epoch='stack-2',area='AR0002.ARE'}
assert(select(2,identity.resolve(target,candidates))=='ambiguous-identity')

-- 5. Candidate arrays and rows must be dense, scalar, and exact.
for _,bad in ipairs({42, {[2]=candidates[2]},
    {{key=target.key,resource=target.resource,epoch='stack-1',area='AR0001.ARE',objectId=42}},
    {{key=target.key,resource=target.resource,epoch='stack-1',area='AR0001.ARE',handle={}}},
    {{key=target.key,resource=target.resource,epoch=42,area='AR0001.ARE'}},
    {{key=target.key,resource=target.resource,epoch='stack-1',area='not-area'}},
}) do
    assert(select(2,identity.resolve(target,bad))=='invalid-candidates')
end
assert(select(2,identity.resolve({key='bad'},{}))=='invalid-identity')
return 5
