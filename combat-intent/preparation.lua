-- Shadow-only generic preparation comparison, not a force-cast implementation.
-- Source rules: SCS 35.21, David Wallace (DavidW), SpellPrecast/SpellPrecastLong.
-- See docs/provenance/scs/prebuff-pilot-ledger.md. Helpers remain installed/local.
local snapshot=require('combat-intent.snapshot')
local M={}
function M.validateSpell(spell)
    snapshot.record(spell,{'id','original','helper','window','protectionTag'})
    assert(type(spell.id)=='string' and #spell.id<=64 and spell.id:match('^[a-z][a-z0-9%-]*$'))
    snapshot.value('lastCast',spell.original);snapshot.value('lastCast',spell.helper)
    assert(spell.window=='short' or spell.window=='long');snapshot.assertKey(spell.protectionTag)
end
local booleans={'enabled','seenEnemy','detectedEnemy','nearParty','offscreenPrep','hostile',
    'instantPrep','shortDifficulty','longDifficulty','accountingReady'}
function M.validateContext(context)
    local required={'sceneKey','observerKey','tick'}
    for _,key in ipairs(booleans) do required[#required+1]=key end
    snapshot.record(context,required)
    snapshot.assertKey(context.sceneKey);snapshot.assertKey(context.observerKey);snapshot.assertTick(context.tick)
    for _,key in ipairs(booleans) do assert(type(context[key])=='boolean','known preparation fact required') end
end
function M.check(view,spell,context)
    assert(snapshot.isView(view));M.validateSpell(spell);M.validateContext(context)
    local frame=view:export();local observer,tick=frame.observerKey,frame.tick
    if context.sceneKey~=frame.sceneKey or context.observerKey~=observer or context.tick~=tick then
        return nil,'preparation-observation-stale'
    end
    local function current(field)
        local f=view:get(observer,field)
        if f.kind=='observed' and f.source=='self' and f.observedAt==tick and f.confidence==1 then return f.value end
    end
    if current('alive')~=true then return nil,'caster-not-known-alive' end
    if not context.enabled then return nil,'preparation-disabled' end
    if context.instantPrep then return nil,'preparation-finished' end
    if not context[spell.window..'Difficulty'] then return nil,'preparation-difficulty' end
    local contact=context.offscreenPrep or context.detectedEnemy
    local window=spell.window=='short' and (context.seenEnemy or context.offscreenPrep)
        or spell.window=='long' and (contact or context.nearParty) and (contact or context.hostile)
    if not window then return nil,'preparation-window-closed' end
    if not context.accountingReady then return nil,'preparation-accounting-unknown' end
    local copies=current('spellbook')
    if not copies then return nil,'stale-spell-allocation' end
    local found=false;for _,resource in ipairs(copies) do if resource==spell.original then found=true end end
    if not found then return nil,'spell-unavailable' end
    local protections=current('protections')
    if not protections then return nil,'buff-presence-unknown' end
    for _,tag in ipairs(protections) do if tag==spell.protectionTag then return nil,'buff-already-present' end end
    -- A proposal records accounting, but never performs it or marks instantprep.
    return {kind='shadow-preparation',resource=spell.original,delivery=spell.helper,
        target={kind='actor',key=observer},originalDebit=1,continueLegacy=true,setsInstantPrep=false}
end
return M
