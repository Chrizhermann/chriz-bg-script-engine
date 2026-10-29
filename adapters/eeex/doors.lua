-- EEex side of doors in the engine's own search (combat-intent/doors.lua): the area's doors as plain
-- values, read at most once a tick for each area, and whether a door stands open. A door is a
-- CGameDoor among the area's objects (sense.areaLists). Its state is the installed game's own ARE
-- door flags (IESDP: bit 0 open, bit 1 locked, bit 7 secret door, bit 8 found); its closed box
-- (m_rClosedBounding), whether it blocks the way when closed (a closed leaf, m_nClosedPolygon of at
-- least 3 points, that impedes search-map cells, m_nClosedSearch: areas also keep cages, vines, a harp
-- and scripted barriers as doors without one), the two spots the game gives for opening it
-- (m_ptDest1, m_ptDest2), the travel trigger it is linked to (m_triggerName: a door into another
-- area), its key (m_keyType) and its trap (m_trapActivated) come from the same object. A door that
-- cannot be read is left out; a door whose trap or travel link cannot be read counts as trapped or as
-- a way out, so the search leaves it shut (fail soft). Session-local: nothing is kept past the tick.
local sense=require('adapters.eeex.sense')
local creature=require('adapters.eeex.creature')
local M={}
M.OPEN=0x1
M.LOCKED=0x2
M.SECRET=0x80
M.FOUND=0x100
-- Objects looked at per read at most.
M.maxObjects=2048

local function number(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function text(field)
    if field==nil then return nil end
    local ok,v=pcall(function() return field:get() end)
    if not ok or type(v)~='string' then
        ok,v=pcall(function() return field.m_pchData:get() end)
    end
    if not ok or type(v)~='string' then return nil end
    return (v:match('^[^%z]*'):upper())
end
local function corner(p)
    if p==nil then return nil end
    local x,y=p.x,p.y
    if number(x) and number(y) and (x~=0 or y~=0) then return {x=x,y=y} end
    return nil
end

-- Whether object is a door.
local function isDoor(g,object)
    local types=rawget(g,'CGameObjectType')
    return type(types)=='table' and number(types.DOOR) and object.m_objectType==types.DOOR
end
-- One door as plain values (see the top), or nil when it is no door.
local function plain(g,id,object)
    if not isDoor(g,object) then return nil end
    local d=g.EEex_GameObject_CastUserType(object)
    local flags=d.m_dwFlags
    if not number(flags) then error('door flags') end
    local band=g.EEex_BAnd
    local r=d.m_rClosedBounding
    local box={left=r.left,top=r.top,right=r.right,bottom=r.bottom}
    if not (number(box.left) and number(box.top) and number(box.right) and number(box.bottom)) then error('door box') end
    local outline,cells=d.m_nClosedPolygon,d.m_nClosedSearch
    if not (number(outline) and number(cells)) then error('door leaf') end
    local points={}
    local first,second=corner(d.m_ptDest1),corner(d.m_ptDest2)
    if first then points[#points+1]=first end
    if second then points[#points+1]=second end
    local okTrap,trap=pcall(function() return d.m_trapActivated end)
    local travel=text(d.m_triggerName)
    local key=text(d.m_keyType)
    return {id=id,open=band(flags,M.OPEN)~=0,locked=band(flags,M.LOCKED)~=0,blocks=outline>=3 and cells>0,
        hidden=band(flags,M.SECRET)~=0 and band(flags,M.FOUND)==0,
        trapped=not (okTrap and number(trap) and trap==0),travel=travel==nil or travel~='',
        keyType=key~=nil and key~='' and key or nil,box=box,points=points}
end

-- The doors of area as plain values (each read anew, the key not yet looked at), the count of
-- those that could not be read and the last error.
function M.read(g,area)
    local out,failed,last={},0,nil
    if area==nil then return out,0 end
    local seen=0
    for _,listName in ipairs(sense.areaLists) do
        local list=area[listName]
        if list~=nil and seen<M.maxObjects then
            local ids={}
            g.EEex_Utility_IterateCPtrList(list,function(id)
                seen=seen+1
                if seen>M.maxObjects then return true end
                ids[#ids+1]=id
            end)
            for _,id in ipairs(ids) do
                local object=g.EEex_GameObject_Get(id)
                if object~=nil then
                    local ok,d=pcall(plain,g,id,object)
                    if not ok then failed=failed+1;last=tostring(d)
                    elseif d then out[#out+1]=d end
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out,failed,last
end

-- Whether the door with id stands open: true or false, nil when it is gone or cannot be read.
function M.open(g,id)
    local object=g.EEex_GameObject_Get(id)
    if object==nil then return nil end
    local ok,v=pcall(function()
        if not isDoor(g,object) then return nil end
        local flags=g.EEex_GameObject_CastUserType(object).m_dwFlags
        if not number(flags) then return nil end
        return g.EEex_BAnd(flags,M.OPEN)~=0
    end)
    if ok then return v end
    return nil
end

-- The item files sprite carries, as a set (the inventory's slots, creature.slots).
function M.carried(g,sprite)
    local out={}
    local equipment=sprite.m_equipment
    local toPtr=rawget(g,'EEex_UDToPtr')
    for slot=0,creature.slots-1 do
        local item=equipment.m_items:get(slot)
        if item~=nil and (type(toPtr)~='function' or toPtr(item)~=0) then
            local resref=text(item.cResRef)
            if resref and resref~='' then out[resref]=true end
        end
    end
    return out
end
return M
