-- Host-only Task10 diagnostic contract. No EEex registration or game policy.
local M = {}
local Methods = {}
Methods.__index = Methods

local limits = {
    traceCapacity = 4096,
    errorAdapterCapacity = 256,
    errorsPerAdapter = 65535,
    maxTextBytes = 256,
}
local maxCount = 2147483647
local fields = {'kind','adapterId','attemptId','outcome','reason'}

local function bounded_integer(value, limit)
    return type(value)=='number' and value==value and value>=1 and
        value<=limit and value%1==0
end

local function identifier(value, maxBytes)
    return type(value)=='string' and #value>0 and #value<=maxBytes and
        not value:find('[^A-Za-z0-9_.:-]')
end

local function safe_text(value, maxBytes)
    if identifier(value,maxBytes) then return value end
    return '[redacted]'
end

local function finite_number(value)
    return type(value)=='number' and value==value and
        value<math.huge and value>-math.huge
end

local function increment(value)
    if value<maxCount then return value+1 end
    return value
end

function M.new(config)
    assert(type(config)=='table','diagnostic config required')
    for name,limit in pairs(limits) do
        assert(bounded_integer(rawget(config,name),limit),'invalid '..name)
    end
    return setmetatable({
        traceCapacity=config.traceCapacity,
        errorAdapterCapacity=config.errorAdapterCapacity,
        errorsPerAdapter=config.errorsPerAdapter,
        maxTextBytes=config.maxTextBytes,
        trace={}, nextSlot=1, traceSize=0,
        errors={}, adapterCount=0, suppressedErrors=0, capacityRejected=0,
    },Methods)
end

function Methods:record(event)
    if type(event)~='table' or type(rawget(event,'kind'))~='string' or
        rawget(event,'kind')=='' then
        return false,'invalid-event'
    end
    local row={}
    for _,name in ipairs(fields) do
        local value=rawget(event,name)
        if value~=nil then row[name]=safe_text(value,self.maxTextBytes) end
    end
    local tick=rawget(event,'tick')
    if finite_number(tick) then row.tick=tick end
    self.trace[self.nextSlot]=row
    self.nextSlot=self.nextSlot%self.traceCapacity+1
    if self.traceSize<self.traceCapacity then self.traceSize=self.traceSize+1 end
    return true
end

function Methods:error(adapterId,code)
    if not identifier(adapterId,self.maxTextBytes) then
        return false,'invalid-adapter'
    end
    local count=self.errors[adapterId]
    if count==nil then
        if self.adapterCount>=self.errorAdapterCapacity then
            self.capacityRejected=increment(self.capacityRejected)
            return false,'adapter-capacity'
        end
        count=0
        self.adapterCount=self.adapterCount+1
    end
    if count>=self.errorsPerAdapter then
        self.suppressedErrors=increment(self.suppressedErrors)
        return false,'error-limit'
    end
    self.errors[adapterId]=count+1
    self:record({kind='error',adapterId=adapterId,
        reason=safe_text(code,self.maxTextBytes)})
    return true
end

function Methods:snapshot()
    local result={trace={},errors={},suppressedErrors=self.suppressedErrors,
        capacityRejected=self.capacityRejected}
    local start=(self.nextSlot-self.traceSize-1)%self.traceCapacity+1
    for offset=0,self.traceSize-1 do
        local source=self.trace[(start+offset-1)%self.traceCapacity+1]
        local row={}
        for key,value in pairs(source) do row[key]=value end
        result.trace[#result.trace+1]=row
    end
    for id,count in pairs(self.errors) do result.errors[id]=count end
    return result
end

return M
