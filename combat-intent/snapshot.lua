-- Versioned scalar policy view. Copy boundaries, not a sandbox for arbitrary Lua.
local copy=require('kernel.manifest').copy
local M={}
local views=setmetatable({},{__mode='k'})
local booleanFields={alive=true,auraReady=true,idle=true,silenced=true,canAct=true,lineOfSight=true,invisible=true,detected=true}
local fields={position=true,hpFraction=true,castingFailure=true,spellbook=true,protections=true,resistances=true,lastCast=true,relation=true,range=true}
for key in pairs(booleanFields) do fields[key]=true end
function M.assertKey(key)
    assert(type(key)=='string' and #key>0 and #key<=128 and not tonumber(key) and not key:find('%c'),'semantic key required')
    return key
end
function M.assertTick(tick)
    assert(type(tick)=='number' and tick>=0 and tick<9007199254740992 and tick%1==0,'integer tick required')
    return tick
end
function M.assertField(field) assert(fields[field],'undeclared policy field');return field end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
function M.array(t,visit)
    assert(type(t)=='table')
    local count=0;for key in pairs(t) do assert(type(key)=='number' and key%1==0 and key>=1);count=count+1 end
    for i=1,count do assert(t[i]~=nil,'sparse array');visit(t[i],i) end
end
function M.record(t,required,optional)
    assert(type(t)=='table')
    local allowed={};for _,key in ipairs(required) do assert(t[key]~=nil,'missing field: '..key);allowed[key]=true end
    for _,key in ipairs(optional or {}) do allowed[key]=true end
    for key in pairs(t) do assert(allowed[key],'unexpected record field') end
end
function M.value(field,value)
    M.assertField(field)
    if booleanFields[field] then assert(type(value)=='boolean')
    elseif field=='position' then M.record(value,{'x','y'});assert(finite(value.x) and finite(value.y))
    elseif field=='hpFraction' or field=='castingFailure' then assert(finite(value) and value>=0 and value<=1)
    elseif field=='range' then assert(finite(value) and value>=0)
    elseif field=='spellbook' then
        M.array(value,function(resource) assert(text(resource) and #resource<=8 and not resource:find('[^A-Z0-9_#%-]')) end)
    elseif field=='protections' then M.array(value,function(tag) assert(text(tag)) end)
    elseif field=='resistances' then
        assert(type(value)=='table')
        local types={fire=true,cold=true,electricity=true,acid=true,poison=true,magic=true,slashing=true,piercing=true,crushing=true,missile=true}
        for kind,amount in pairs(value) do assert(types[kind] and finite(amount)) end
    elseif field=='lastCast' then assert(text(value) and #value<=8 and not value:find('[^A-Z0-9_#%-]'))
    elseif field=='relation' then assert(({self=true,ally=true,enemy=true,neutral=true,unknown=true})[value]) end
end
function M.new(input)
    -- Every constructor path uses the same fairness admission; callers cannot
    -- accidentally turn a structural record into trusted perceived knowledge.
    local data=require('combat-intent.perception').normalize(input)
    M.record(data,{'schemaVersion','sceneKey','tick','observerKey','eligibleAllies','actors'})
    assert(data.schemaVersion==1);M.assertKey(data.sceneKey);M.assertTick(data.tick);M.assertKey(data.observerKey)
    M.array(data.eligibleAllies,function(key) M.assertKey(key) end)
    local actors={}
    M.array(data.actors,function(actor)
        M.record(actor,{'key','visible','detected','facts'});M.assertKey(actor.key)
        assert(not actors[actor.key] and type(actor.visible)=='boolean' and type(actor.detected)=='boolean')
        assert(type(actor.facts)=='table');actors[actor.key]=actor
        for field,fact in pairs(actor.facts) do
            M.assertField(field)
            if fact.kind=='unknown' or fact.kind=='expired' then
                M.record(fact,{'kind','reason'});assert(text(fact.reason))
            else
                M.record(fact,{'kind','source','value','observedAt','expiresAt','confidence'}, {'origin','basis','evidenceSource'})
                assert(({observed=true,remembered=true,shared=true,inferred=true})[fact.kind])
                M.assertTick(fact.observedAt);M.assertTick(fact.expiresAt)
                assert(fact.expiresAt>fact.observedAt and finite(fact.confidence) and fact.confidence>=0 and fact.confidence<=1)
                assert(text(fact.source));M.value(field,fact.value)
                if fact.origin then M.assertKey(fact.origin) end
                if fact.basis then assert(text(fact.basis)) end
                if fact.evidenceSource then assert(text(fact.evidenceSource)) end
            end
        end
    end)
    local api={}
    function api:get(subject,field)
        M.assertKey(subject);M.assertField(field)
        local actor=actors[subject]
        return copy(actor and actor.facts[field] or {kind='unknown',reason='not-observed'})
    end
    function api:export() return copy(data) end
    function api:reader(declared)
        local allowed={};M.array(declared,function(field) M.assertField(field);assert(not allowed[field]);allowed[field]=true end)
        return function(subject,field) assert(allowed[field],'scorer read undeclared field');return api:get(subject,field) end
    end
    local view=setmetatable({},{__index=api,__newindex=function() error('snapshot is read-only') end,__metatable=false})
    views[view]=true;return view
end
function M.isView(view) return views[view]==true end
return M
