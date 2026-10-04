-- Conservative scalar point-coverage reduction. Descriptor units are caller-attested,
-- not inferred from SPL/PRO or authorized for native dispatch by this module.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local M={}
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function current(view,key,field,tick)
    local fact=view:get(key,field)
    if fact.kind=='observed' and fact.observedAt==tick and fact.expiresAt>tick and
        fact.confidence==1 then return fact.value end
end
local function descriptor(raw)
    local d=copy(raw)
    snapshot.record(d,{'geometryId','resource','shape','radius','scaleX','scaleY'})
    snapshot.assertKey(d.geometryId);snapshot.value('lastCast',d.resource)
    assert(d.shape=='circle' or d.shape=='unknown','invalid geometry shape')
    assert(finite(d.scaleX) and d.scaleX>0 and finite(d.scaleY) and d.scaleY>0,
        'invalid metric scales')
    assert(d.radius==false or finite(d.radius) and d.radius>0,'invalid circle radius')
    return d
end
local function coverageReport(raw)
    if raw==nil then return nil end
    local report=copy(raw)
    snapshot.record(report,{'sceneKey','observerKey','tick','complete','actorKeys','padding'})
    snapshot.assertKey(report.sceneKey);snapshot.assertKey(report.observerKey);snapshot.assertTick(report.tick)
    assert(type(report.complete)=='boolean' and finite(report.padding) and report.padding>=0,
        'invalid coverage bounds')
    local seen={}
    snapshot.array(report.actorKeys,function(key)
        snapshot.assertKey(key);assert(not seen[key],'duplicate covered actor');seen[key]=true
    end)
    return report
end
function M.assess(view,spellGeometry,anchorKey,coverage)
    assert(snapshot.isView(view),'genuine policy view required')
    snapshot.assertKey(anchorKey)
    local d=descriptor(spellGeometry)
    local report=coverageReport(coverage)
    local frame=view:export()
    local result={complete=false,safe=false,reason='geometry-unknown',sceneKey=frame.sceneKey,
        observerKey=frame.observerKey,tick=frame.tick,resource=d.resource,geometryId=d.geometryId,
        point=false,actors=frame.actors,anchorCovered=false,affectedKeys={},riskKeys={},
        dispatchAuthorized=false}
    if d.shape~='circle' or d.radius==false then return result end
    result.reason='coverage-unknown'
    if not report or not report.complete then return result end
    if report.tick~=frame.tick then result.reason='coverage-stale';return result end
    local keys={}
    for i,actor in ipairs(frame.actors) do keys[i]=actor.key end
    if report.sceneKey~=frame.sceneKey or report.observerKey~=frame.observerKey or
        not equal(report.actorKeys,keys) then
        result.reason='coverage-mismatch';return result
    end
    local radiusRisk=d.radius+report.padding
    if not finite(radiusRisk) then result.reason='metric-overflow';return result end
    local anchorAlive=current(view,anchorKey,'alive',frame.tick)
    local anchorRelation=current(view,anchorKey,'relation',frame.tick)
    local point=current(view,anchorKey,'position',frame.tick)
    if anchorAlive~=true or anchorRelation~='enemy' or not point then
        result.reason='anchor-not-current-enemy';return result
    end
    result.point=copy(point)
    local actualSquared,riskSquared=d.radius*d.radius,radiusRisk*radiusRisk
    if not finite(actualSquared) or not finite(riskSquared) then
        result.reason='metric-overflow';return result
    end
    local affected,risk,anchorCovered={},{},false
    for _,actor in ipairs(frame.actors) do
        local alive=current(view,actor.key,'alive',frame.tick)
        if alive==nil then result.reason='actor-knowledge-unknown';return result end
        if alive then
            local relation=current(view,actor.key,'relation',frame.tick)
            local position=current(view,actor.key,'position',frame.tick)
            if not relation or relation=='unknown' or not position then
                result.reason='actor-knowledge-unknown';return result
            end
            local x=(position.x-point.x)*d.scaleX
            local y=(position.y-point.y)*d.scaleY
            local distance=x*x+y*y
            if not finite(distance) then result.reason='metric-overflow';return result end
            if actor.key==anchorKey then anchorCovered=distance<=actualSquared end
            if relation=='enemy' then
                if distance<=actualSquared then affected[#affected+1]=actor.key end
            elseif distance<=riskSquared then
                risk[#risk+1]=actor.key
            end
        end
    end
    if not anchorCovered then result.reason='anchor-outside-radius';return result end
    table.sort(affected);table.sort(risk)
    result.anchorCovered=true;result.affectedKeys=affected;result.riskKeys=risk
    result.complete=true;result.safe=#risk==0
    result.reason=result.safe and 'clear' or 'ally-risk'
    return result
end
return M
