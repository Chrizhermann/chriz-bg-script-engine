-- Scalar semantic identities are re-resolved against each supplied snapshot.
local M = {}
local extensions = {CRE=true, ARE=true, BCS=true, DLG=true}

local function plainRecord(value, fields)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    for _, field in ipairs(fields) do
        if rawget(value, field) == nil then return false end
    end
    local allowed = {}
    for _, field in ipairs(fields) do allowed[field] = true end
    for key in next, value do
        if not allowed[key] then return false end
    end
    return true
end

local function semanticText(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum and
        value:find('%S') ~= nil and value:find('%c') == nil
end

local function semanticKey(value)
    return semanticText(value, 128) and tonumber(value) == nil
end

local function adapterId(value)
    if not semanticText(value, 64) then return false end
    local domain, name = value:match('^B%-/([a-z]+)/([a-z0-9%-]+)$')
    return (domain == 'combat' or domain == 'worldflow') and
        name ~= nil and name:match('^[a-z0-9]') ~= nil and
        name:sub(-1) ~= '-' and not name:find('%-%-')
end

local function resource(value, requiredExtension)
    if type(value) ~= 'string' then return false end
    local stem, extension = value:match('^([^%.]+)%.([^%.]+)$')
    return stem ~= nil and #stem >= 1 and #stem <= 8 and
        stem:find('[^A-Z0-9_#%-]') == nil and
        extensions[extension] == true and
        (requiredExtension == nil or extension == requiredExtension)
end

function M.validate(value)
    if not plainRecord(value, {'adapterId','key','resource'}) or
        not adapterId(rawget(value,'adapterId')) or
        not semanticKey(rawget(value,'key')) or
        not resource(rawget(value,'resource')) then
        return nil, 'invalid-identity'
    end
    return {
        adapterId=rawget(value,'adapterId'),
        key=rawget(value,'key'),
        resource=rawget(value,'resource'),
    }
end

local function validCandidates(candidates)
    if type(candidates) ~= 'table' or getmetatable(candidates) ~= nil then return nil end
    local count = 0
    for key in next, candidates do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return nil end
        count = count + 1
    end
    for index = 1, count do
        local row = rawget(candidates, index)
        if not plainRecord(row, {'key','resource','epoch','area'}) or
            not semanticKey(rawget(row,'key')) or
            not resource(rawget(row,'resource')) or
            not semanticText(rawget(row,'epoch'), 128) or
            not resource(rawget(row,'area'), 'ARE') then
            return nil
        end
    end
    return count
end

function M.resolve(value, candidates)
    local requested, reason = M.validate(value)
    if not requested then return nil, reason end
    local count = validCandidates(candidates)
    if not count then return nil, 'invalid-candidates' end

    local found
    for index = 1, count do
        local row = rawget(candidates, index)
        if rawget(row,'key') == requested.key and
            rawget(row,'resource') == requested.resource then
            if found then return nil, 'ambiguous-identity' end
            found = row
        end
    end
    if not found then return nil, 'absent-identity' end
    return {key=rawget(found,'key'), resource=rawget(found,'resource'),
        epoch=rawget(found,'epoch'), area=rawget(found,'area'), matches=1}
end

return M
