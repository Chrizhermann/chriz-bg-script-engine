-- Scalar arbitration only. Unknown facts decline rather than imply permission.
local M={}
local fields={'player','hardMode','world','encounter','forced','dialogue','cutscene',
    'staging','imageOwner','alive','active','hostile','actionIdle','auraReady','capable','eligible'}
function M.decide(snapshot)
    local function answer(owner,reason) return {owner=owner,reason=reason,combat=owner=='combat'} end
    if type(snapshot)~='table' or getmetatable(snapshot)~=nil then return answer('legacy','invalid-snapshot') end
    if rawget(snapshot,'player')==true or rawget(snapshot,'hardMode')==true then
        return answer('player','higher-player-mode')
    end
    for _,field in ipairs(fields) do
        if type(rawget(snapshot,field))~='boolean' then return answer('legacy','unknown-'..field) end
    end
    if snapshot.world or snapshot.encounter or snapshot.dialogue or snapshot.cutscene or snapshot.staging then
        return answer('world','higher-world-owner')
    end
    if snapshot.forced then return answer('forced','higher-forced-behavior') end
    if snapshot.imageOwner then return answer('legacy','image-owner-lock') end
    for _,field in ipairs({'eligible','capable','alive','active','hostile','actionIdle','auraReady'}) do
        if not snapshot[field] then return answer('legacy','blocked-'..field) end
    end
    return answer('combat','ready')
end
return M
