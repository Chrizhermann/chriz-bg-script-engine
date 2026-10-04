-- Deterministic combat shadow set. No scoring, native reads or action submission.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local ownership=require('kernel.ownership')
local legality=require('combat-intent.legality')
local actions=require('combat-intent.actions')
local preparation=require('combat-intent.preparation')
local M={}
function M.generate(view,input)
    assert(snapshot.isView(view),'perception view required')
    local config=copy(input)
    snapshot.record(config,{'ownership','ownershipContext','spells','targets','areaChecks'}, {'prebuffs','preparation'})
    assert(type(config.areaChecks)=='table')
    local seen={}
    snapshot.array(config.spells,function(spell)
        legality.validateSpell(spell);assert(not seen[spell.id],'duplicate spell id');seen[spell.id]=true
    end)
    if config.prebuffs then
        preparation.validateContext(config.preparation)
        local prepIds={}
        snapshot.array(config.prebuffs,function(spell)
            preparation.validateSpell(spell);assert(not prepIds[spell.id],'duplicate prebuff id');prepIds[spell.id]=true
        end)
        table.sort(config.prebuffs,function(a,b) return a.id<b.id end)
    else assert(config.preparation==nil,'preparation requires prebuff set') end
    seen={}
    snapshot.array(config.targets,function(key)
        snapshot.assertKey(key);assert(not seen[key],'duplicate target');seen[key]=true
    end)
    table.sort(config.spells,function(a,b) return a.id<b.id end);table.sort(config.targets)
    local result={dispatchAuthorized=false,eligible={},excluded={}}
    local owner=ownership.decide(config.ownership)
    local frame=view:export();local observed=config.ownershipContext
    snapshot.record(observed,{'sceneKey','observerKey','tick'})
    if observed.sceneKey~=frame.sceneKey or observed.observerKey~=frame.observerKey or observed.tick~=frame.tick then
        owner={combat=false,owner='legacy',reason='ownership-observation-stale'}
    end
    for _,spell in ipairs(config.spells) do
        for _,targetKey in ipairs(config.targets) do
            local id=spell.id..'@'..targetKey
            local admitted,reason
            if owner.combat then admitted,reason=legality.check(view,spell,targetKey,config.areaChecks)
            else reason=owner.reason end
            if admitted then
                result.eligible[#result.eligible+1]={id=id,action=actions.spell(spell.resource,admitted.target),
                    geometryId=spell.geometryId,notes=admitted.notes}
            else result.excluded[#result.excluded+1]={id=id,reason=reason} end
        end
    end
    for _,spell in ipairs(config.prebuffs or {}) do
        local id='prep-'..spell.id..'@'..frame.observerKey
        local action,reason
        if owner.combat then action,reason=preparation.check(view,spell,config.preparation) else reason=owner.reason end
        if action then result.eligible[#result.eligible+1]={id=id,action=action,notes={'generic-preparation-shadow-only'}}
        else result.excluded[#result.excluded+1]={id=id,reason=reason} end
    end
    if owner.combat then result.eligible[#result.eligible+1]={id='wait',action=actions.wait(),notes={}} end
    result.eligible[#result.eligible+1]={id='decline',action=actions.decline(),notes={owner.reason}}
    return result
end
return M
