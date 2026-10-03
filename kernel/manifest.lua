-- Exact, scalar-only development contract. No resource discovery or native calls.
local M = {}

function M.copy(value)
    local active,nodes={},0
    local function visit(v,depth)
        nodes=nodes+1
        assert(nodes<=16384 and depth<=24,'value-limit')
        local t=type(v)
        if t=='string' then assert(#v<=256 and not v:find('\0',1,true));return v end
        if t=='boolean' or t=='nil' then return v end
        if t=='number' then assert(v==v and v>-math.huge and v<math.huge);return v end
        assert(t=='table' and getmetatable(v)==nil and not active[v],'non-scalar-value')
        active[v]=true
        local result={}
        for k,item in next,v do
            assert(type(k)=='string' or (type(k)=='number' and k%1==0),'invalid-key')
            result[visit(k,depth+1)]=visit(item,depth+1)
        end
        active[v]=nil;return result
    end
    return visit(value,0)
end

function M.equal(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not M.equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

local function text(v) return type(v)=='string' and #v>0 end
local function record(t,fields)
    if type(t)~='table' then return false end
    local allowed={};for _,k in ipairs(fields) do allowed[k]=true;if t[k]==nil then return false end end
    for k in pairs(t) do if not allowed[k] then return false end end
    return true
end
local function array(t,check,nonempty)
    if type(t)~='table' then return false end
    local count,seen=0,{}
    for k,v in pairs(t) do
        if type(k)~='number' or k<1 or k%1~=0 or not check(v) or seen[v] then return false end
        seen[v]=true;count=count+1
    end
    if nonempty and count==0 then return false end
    for i=1,count do if t[i]==nil then return false end end
    return true
end
local function resref(v) return text(v) and #v<=8 and not v:find('[^A-Z0-9_#-]') end
local extensions={CRE=true,BCS=true,DLG=true,ARE=true,SPL=true,ITM=true,PRO=true,IDS=true,['2DA']=true}
local function resource(v)
    if not text(v) then return false end
    local stem,ext=v:match('^([^%.]+)%.([^%.]+)$')
    return resref(stem) and extensions[ext]==true
end
local function digest(v) return type(v)=='string' and #v==64 and not v:find('[^a-f0-9]') end
local slotNames={override=true,class=true,race=true,general=true,default=true,area=true}

function M.validate(input)
    local ok,m=pcall(M.copy,input)
    if not ok or type(m)~='table' then return nil,'manifest-shape' end
    if m.schemaVersion~=1 then return nil,'manifest-schema' end
    if not text(m.id) or #m.id>64 or not m.id:match('^B%-/[a-z]+/[a-z0-9][a-z0-9%-]*$')
        or m.id:find('%-%-') or m.id:sub(-1)=='-' then return nil,'manifest-id' end
    local domain=m.id:match('^B%-/([^/]+)/')
    if not ((domain=='combat' and m.domain=='CombatIntent') or
        (domain=='worldflow' and m.domain=='WorldFlow')) then return nil,'manifest-domain' end
    if not text(m.version) then return nil,'manifest-version' end
    if not ({C0=true,C1=true,C2=true,C3=true,C4=true})[m.tier] then return nil,'manifest-tier' end
    if m.hashAlgorithm~='sha256' or m.hashVersion~=1 then return nil,'manifest-hash' end
    if not record(m.fallback,{'kind','resources'}) or m.fallback.kind~='legacy' or
        not array(m.fallback.resources,resource,true) then return nil,'manifest-fallback' end
    if not record(m.provenance,{'source','distribution'}) or not text(m.provenance.source) or
        not text(m.provenance.distribution) then return nil,'manifest-provenance' end
    if not array(m.evidence,text,true) then return nil,'manifest-evidence' end
    if not record(m,{'schemaVersion','id','version','domain','tier','profile','epoch',
        'hashAlgorithm','hashVersion','requiredCapabilities','roots','controlClosure','resources',
        'publicState','fallback','provenance','evidence'}) or not text(m.profile) or not text(m.epoch)
        or not array(m.requiredCapabilities,text,true) or not array(m.roots,resource,true)
        or not array(m.controlClosure,resource,false) or type(m.resources)~='table'
        or type(m.publicState)~='table' then return nil,'manifest-shape' end
    for id,r in pairs(m.resources) do
        if not resource(id) or not record(r,{'sha256','dependencies','slots','opaque'}) or
            not digest(r.sha256) or not array(r.dependencies,resource,false) or
            type(r.slots)~='table' or r.opaque~=false then return nil,'manifest-shape' end
        for slot,stem in pairs(r.slots) do
            if not slotNames[slot] or (stem~='' and not resref(stem)) then return nil,'manifest-shape' end
            if stem~='' and not m.resources[stem..'.BCS'] then return nil,'manifest-closure' end
        end
    end
    local reached={}
    local function walk(id)
        if reached[id] then return true end
        local r=m.resources[id];if not r then return false end
        reached[id]=true
        for _,child in ipairs(r.dependencies) do if not walk(child) then return false end end
        for _,stem in pairs(r.slots) do if stem~='' and not walk(stem..'.BCS') then return false end end
        return true
    end
    for _,ids in ipairs({m.roots,m.controlClosure,m.fallback.resources}) do
        for _,id in ipairs(ids) do if not walk(id) then return nil,'manifest-closure' end end
    end
    for id in pairs(m.resources) do if not reached[id] then return nil,'manifest-closure' end end
    for variable,refs in pairs(m.publicState) do
        if not text(variable) or not variable:match('^[A-Z0-9_]+:[A-Z0-9_%-]+$') or
            not record(refs,{'readers','writers'}) or not array(refs.readers,resource,false) or
            not array(refs.writers,resource,false) then return nil,'manifest-public-state' end
        for _,ids in ipairs({refs.readers,refs.writers}) do
            for _,id in ipairs(ids) do if not reached[id] then return nil,'manifest-closure' end end
        end
    end
    return m
end

return M
