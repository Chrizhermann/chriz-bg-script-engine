-- Pure current-fact checks. Trusted native mapping/metadata attestation is later work.
local snapshot=require('combat-intent.snapshot')
local equal=require('kernel.manifest').equal
local M={}
local fields={'alive','canAct','idle','auraReady','silenced','castingFailure','spellbook',
    'relation','range','lineOfSight','position','protections'}
local function current(read,key,field,tick)
    local f=read(key,field)
    if f.kind=='observed' and f.observedAt==tick and f.expiresAt>tick and f.confidence==1 then return f.value end
end
function M.validateSpell(spell)
    snapshot.record(spell,{'id','resource','target','range','geometry','geometryId','maxCastingFailure','immunityTags'})
    assert(type(spell.id)=='string' and #spell.id<=64 and spell.id:match('^[a-z][a-z0-9%-]*$'))
    snapshot.value('lastCast',spell.resource)
    assert(spell.target=='actor' or spell.target=='point')
    snapshot.value('range',spell.range)
    assert(spell.geometry=='exact' or spell.geometry=='unknown');snapshot.assertKey(spell.geometryId)
    snapshot.value('castingFailure',spell.maxCastingFailure)
    snapshot.value('protections',spell.immunityTags)
end
function M.check(view,spell,targetKey,areaChecks)
    assert(snapshot.isView(view));M.validateSpell(spell);snapshot.assertKey(targetKey)
    local frame=view:export();local read=view:reader(fields)
    local observer,tick=frame.observerKey,frame.tick
    if targetKey==observer then return nil,'offensive-self-target' end
    for _,rule in ipairs({{'alive',true,'caster-dead'},{'canAct',true,'caster-disabled'},
        {'idle',true,'action-occupied'},{'auraReady',true,'aura-not-ready'},{'silenced',false,'caster-silenced'}}) do
        local value=current(read,observer,rule[1],tick)
        if value==nil then return nil,'stale-caster-'..rule[1] end
        if value~=rule[2] then return nil,rule[3] end
    end
    local failure=current(read,observer,'castingFailure',tick)
    if failure==nil then return nil,'stale-casting-failure' end
    if failure>spell.maxCastingFailure then return nil,'casting-failure-too-high' end
    local available=current(read,observer,'spellbook',tick)
    if not available then return nil,'stale-spell-allocation' end
    local hasCopy=false;for _,resource in ipairs(available) do if resource==spell.resource then hasCopy=true end end
    if not hasCopy then return nil,'spell-unavailable' end
    for _,rule in ipairs({{'alive',true,'target-dead'},{'relation','enemy','target-not-enemy'},
        {'lineOfSight',true,'no-line-of-sight'}}) do
        local value=current(read,targetKey,rule[1],tick)
        if value==nil then return nil,'stale-target-'..rule[1] end
        if value~=rule[2] then return nil,rule[3] end
    end
    local range=current(read,targetKey,'range',tick)
    if range==nil then return nil,'stale-target-range' end
    if range>spell.range then return nil,'out-of-range' end
    if spell.geometry~='exact' then return nil,'geometry-unknown' end
    local target={kind='actor',key=targetKey}
    if spell.target=='point' then
        local point=current(read,targetKey,'position',tick)
        if not point then return nil,'stale-target-position' end
        local geometry=type(areaChecks)=='table' and areaChecks[spell.geometryId]
        local area=geometry and geometry[targetKey]
        if type(area)~='table' or area.complete~=true then return nil,'area-coverage-unknown' end
        if area.tick~=tick then return nil,'area-coverage-stale' end
        if area.resource~=spell.resource or area.observerKey~=observer or area.sceneKey~=frame.sceneKey or
            area.anchorCovered~=true or not equal(area.point,point) or not equal(area.actors,frame.actors) then
            return nil,'area-coverage-mismatch'
        end
        if area.safe==false then return nil,'ally-risk' end
        if area.safe~=true then return nil,'area-safety-unknown' end
        target={kind='point',x=point.x,y=point.y,anchorKey=targetKey}
    end
    local protections=read(targetKey,'protections');local notes={}
    if protections.kind=='observed' and protections.observedAt==tick and protections.confidence==1 then
        -- Single-target immunity is a candidate exclusion. An immune point anchor
        -- does not establish that all other area recipients are immune.
        if spell.target=='actor' then
            for _,known in ipairs(protections.value) do
                for _,blocked in ipairs(spell.immunityTags) do
                    if known==blocked then return nil,'known-protection' end
                end
            end
        end
    else notes[1]='protection-knowledge-unknown' end
    return {target=target,notes=notes}
end
return M
