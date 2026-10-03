-- Observer snapshot v1 contains only reviewed scalar fields, never engine userdata/IDs.
local M={}
local fields={version=true,tick=true,area=true,x=true,y=true,actionId=true,queuedActions=true,alive=true}
function M.snapshot(value)
    assert(type(value)=='table' and getmetatable(value)==nil,'invalid-snapshot')
    for key in pairs(value) do assert(fields[key],'unknown-snapshot-field') end
    assert(value.version==1 and type(value.area)=='string' and value.area:match('^[A-Z0-9_#%-]+%.ARE$')
        and type(value.alive)=='boolean','invalid-snapshot')
    local copy={version=1,area=value.area,alive=value.alive}
    for _,key in ipairs({'tick','x','y','actionId','queuedActions'}) do
        local n=rawget(value,key)
        assert(type(n)=='number' and n==n and n>=0 and n<math.huge and n%1==0,'invalid-snapshot-number')
        copy[key]=n
    end
    return copy
end
return M
