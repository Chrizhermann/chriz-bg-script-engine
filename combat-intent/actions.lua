-- Shadow proposals deliberately do not match kernel.lease's dispatch-request types.
local snapshot=require('combat-intent.snapshot')
local copy=require('kernel.manifest').copy
local M={}
function M.spell(resource,target)
    snapshot.value('lastCast',resource)
    assert(type(target)=='table')
    if target.kind=='actor' then
        snapshot.record(target,{'kind','key'});snapshot.assertKey(target.key)
    elseif target.kind=='point' then
        snapshot.record(target,{'kind','x','y','anchorKey'})
        snapshot.value('position',{x=target.x,y=target.y});snapshot.assertKey(target.anchorKey)
    else error('unsupported shadow target') end
    return {kind='shadow-spell',resource=resource,target=copy(target)}
end
function M.wait() return {kind='shadow-wait'} end
function M.decline() return {kind='legacy-decline'} end
return M
