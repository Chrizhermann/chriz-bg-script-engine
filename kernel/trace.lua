local values=require('kernel.manifest')
local M={}
function M.new(capacity)
    assert(type(capacity)=='number' and capacity%1==0 and capacity>=1 and capacity<=4096)
    local rows,nextSlot,size={},1,0
    local fields={'kind','actorKey','adapterId','profile','snapshotVersion','owner','reason','tick'}
    local api={}
    function api:record(event)
        local row={}
        for _,field in ipairs(fields) do
            local value=rawget(event,field)
            if value~=nil then
                assert(type(value)=='string' or type(value)=='number','trace scalar required')
                row[field]=values.copy(value)
            end
        end
        rows[nextSlot]=row;nextSlot=nextSlot%capacity+1;size=math.min(size+1,capacity)
    end
    function api:snapshot()
        local result={};local first=(nextSlot-size-1)%capacity+1
        for i=0,size-1 do result[#result+1]=values.copy(rows[(first+i-1)%capacity+1]) end
        return result
    end
    return api
end
return M
