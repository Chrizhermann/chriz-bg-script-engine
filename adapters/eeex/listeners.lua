-- Promoted void-listener trampoline from the measured Task8 probe.
-- No return-valued hook or loaded/destroyed userdata inspection is admitted here.
local M={}
local function disable(state,reason)
    if not state.disabled then state.disabled=reason;state.failures=(state.failures or 0)+1 end
end
function M.dispatch(state,key,...)
    if state.disabled then return end
    local ok,available=pcall(state.available)
    if not ok or not available then disable(state,'capability-lost');return end
    local handler=state.handlers[key];if not handler then return end
    if not pcall(handler,...) then disable(state,'callback:'..key) end
end
function M.attach(state,register,handlers,available)
    if state.disabled then return state end
    state.handlers,state.available=handlers,available
    state.registrations=state.registrations or {}
    state.generation=(state.generation or 0)+1
    local keys={};for key in pairs(register) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do
        if not state.registrations[key] then
            state.registrations[key]=1 -- before a possibly synchronous registration callback
            local callback=function(...) return M.dispatch(state,key,...) end
            if not pcall(register[key],callback) then disable(state,'registration:'..key);break end
        end
    end
    return state
end
return M
