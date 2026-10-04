-- Bounded scalar position sampling. Callers supply reviewed path attestations and
-- explicit score weights; an open square alone is never a reachable destination.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local M={}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function current(view,key,field,tick)
    local fact=view:get(key,field)
    if fact.kind=='observed' and fact.observedAt==tick and fact.expiresAt>tick and fact.confidence==1 then
        return fact.value
    end
end
local function validate(input)
    local c=copy(input)
    snapshot.record(c,{'scaleX','scaleY','maxDistance','personalSpace','margin','pathProofId','weights','offsets'})
    for _,key in ipairs({'scaleX','scaleY','maxDistance','personalSpace'}) do
        assert(finite(c[key]) and c[key]>0,'invalid spatial metric')
    end
    assert(finite(c.margin) and c.margin>=0)
    if c.pathProofId~=false then snapshot.assertKey(c.pathProofId) end
    snapshot.record(c.weights,{'retreatGain','travelDistance'})
    for _,n in pairs(c.weights) do assert(finite(n) and math.abs(n)<=1000000,'invalid spatial weight') end
    local ids={}
    snapshot.array(c.offsets,function(row)
        snapshot.record(row,{'id','x','y'});snapshot.assertKey(row.id)
        assert(not ids[row.id],'duplicate sample id');ids[row.id]=true
        snapshot.value('position',{x=row.x,y=row.y})
    end)
    assert(#c.offsets>0 and #c.offsets<=8,'one to eight spatial samples required')
    return c
end
local function distance(a,b,c)
    local x,y=(a.x-b.x)*c.scaleX,(a.y-b.y)*c.scaleY
    local n=math.sqrt(x*x+y*y)
    assert(finite(n),'spatial metric overflow');return n
end
local function samples(view,c)
    local f=view:export();local from=current(view,f.observerKey,'position',f.tick)
    if not from then return {},f,nil end
    local result={}
    for _,offset in ipairs(c.offsets) do
        local point={x=from.x+offset.x,y=from.y+offset.y};snapshot.value('position',point)
        result[#result+1]={id=offset.id,point=point}
    end
    return result,f,from
end
function M.sample(view,input)
    assert(snapshot.isView(view),'genuine policy view required')
    local result=samples(view,validate(input));return result
end
local function query(raw)
    if not raw then return nil end
    local q=copy(raw)
    snapshot.record(q,{'sceneKey','observerKey','tick','from','point','actors','pathProofId',
        'reachable','open','lineOfSight','clearance'})
    snapshot.assertKey(q.sceneKey);snapshot.assertKey(q.observerKey);snapshot.assertTick(q.tick)
    snapshot.value('position',q.from);snapshot.value('position',q.point)
    if q.pathProofId~=false then snapshot.assertKey(q.pathProofId) end
    for _,key in ipairs({'reachable','open','lineOfSight'}) do
        assert(type(q[key])=='boolean' or q[key]=='unknown','invalid query truth')
    end
    assert(q.clearance==false or finite(q.clearance) and q.clearance>=0,'invalid clearance')
    return q
end
local function threatPoints(view,f)
    local points={}
    for _,actor in ipairs(f.actors) do
        local alive=current(view,actor.key,'alive',f.tick)
        if alive==nil then return nil end
        if alive then
            local relation=current(view,actor.key,'relation',f.tick)
            if not relation or relation=='unknown' then return nil end
            if relation=='enemy' then
                local p=current(view,actor.key,'position',f.tick)
                if not p then return nil end
                points[#points+1]=p
            end
        end
    end
    return points
end
local function nearest(point,threats,c)
    if #threats==0 then return 0 end
    local n=math.huge
    for _,p in ipairs(threats) do n=math.min(n,distance(point,p,c)) end
    return n
end
function M.evaluate(view,input,rawReports)
    assert(snapshot.isView(view),'genuine policy view required')
    local c=validate(input);local candidates,f,from=samples(view,c)
    local reports={};assert(type(rawReports)=='table')
    for id,raw in pairs(rawReports) do snapshot.assertKey(id);reports[id]=query(raw) end
    local result={sceneKey=f.sceneKey,observerKey=f.observerKey,tick=f.tick,
        dispatchAuthorized=false,eligible={},excluded={}}
    if not from then result.reason='observer-position-unknown';return result end
    local threats=threatPoints(view,f)
    for _,row in ipairs(candidates) do
        local q=reports[row.id];local travel=distance(from,row.point,c);local reason
        if travel>c.maxDistance then reason='outside-sample-radius'
        elseif not threats then reason='threat-knowledge-unknown'
        elseif not c.pathProofId then reason='path-capability-unadmitted'
        elseif not q then reason='query-unknown'
        elseif q.pathProofId~=c.pathProofId then reason='path-capability-unadmitted'
        elseif q.sceneKey~=f.sceneKey or q.observerKey~=f.observerKey or q.tick~=f.tick or
            not equal(q.from,from) or not equal(q.point,row.point) or not equal(q.actors,f.actors) then
            reason='query-stale-or-mismatched'
        elseif q.open~=true then reason=q.open==false and 'occupied' or 'occupancy-unknown'
        elseif q.reachable~=true then reason=q.reachable==false and 'unreachable' or 'reachability-unknown'
        elseif q.lineOfSight~=true then reason=q.lineOfSight==false and 'line-of-sight-blocked' or 'line-of-sight-unknown'
        elseif q.clearance==false then reason='clearance-unknown'
        elseif q.clearance<c.personalSpace+c.margin then reason='insufficient-clearance' end
        if reason then result.excluded[#result.excluded+1]={id=row.id,reason=reason}
        else
            local gain=nearest(row.point,threats,c)-nearest(from,threats,c)
            local score=gain*c.weights.retreatGain+travel*c.weights.travelDistance
            assert(finite(score),'spatial score overflow')
            result.eligible[#result.eligible+1]={id=row.id,action={kind='shadow-position',point=copy(row.point)},
                retreatGain=gain,travelDistance=travel,score=score,pathProofId=c.pathProofId}
        end
    end
    table.sort(result.eligible,function(a,b) return a.score>b.score or a.score==b.score and a.id<b.id end)
    table.sort(result.excluded,function(a,b) return a.id<b.id end)
    return result
end
return M
