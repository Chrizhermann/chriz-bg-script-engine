-- In-game twin of tools/ie_resources.py: the same SPL, ITM, EFF and PRO records, read from the
-- engine's resource table through EEex (Fetch, then Demand, as EEex_Resource_Demand does; CRes
-- has no Release, so each resource is demanded once and cached). A raw read past a resource's
-- end would crash the game instead of raising, so every read is checked against the size the
-- engine loaded first. A missing resource is nil; a malformed one is nil plus a problem.
-- Nothing here raises, and the cache holds plain records only (treat them as read-only).
local M={}
M.maxProblems=50

local function upper(text) return (text:gsub('[a-z]',function(c) return string.char(c:byte()-32) end)) end
local function clean(text) return upper((text:match('^[^%z]*'):gsub(' +$',''))) end

-- InfinityLoader exposes all of these; the wider ones are composed from bytes if one is absent.
local function natives(g)
    local u8=rawget(g,'EEex_ReadU8')
    if type(u8)~='function' then return nil end
    local function native(name) local f=rawget(g,name);if type(f)=='function' then return f end end
    local r={u8=u8}
    r.u16=native('EEex_ReadU16') or function(a) return u8(a)+u8(a+1)*256 end
    r.u32=native('EEex_ReadU32') or function(a) return r.u16(a)+r.u16(a+2)*65536 end
    r.i16=native('EEex_Read16') or function(a) local v=r.u16(a);return v>=32768 and v-65536 or v end
    r.i32=native('EEex_Read32') or function(a) local v=r.u32(a);return v>=2147483648 and v-4294967296 or v end
    -- Reads at most n bytes and stops at the first NUL, like the native one.
    r.str=native('EEex_ReadLString') or function(a,n)
        local t={}
        for i=0,n-1 do local b=u8(a+i);if b==0 then break end;t[#t+1]=string.char(b) end
        return table.concat(t)
    end
    return r
end

local function fail(message) error({format=message},0) end

local function view(read,base,size)
    local function at(offset,width)
        if offset<0 or offset+width>size then fail(string.format('truncated data at 0x%X',offset)) end
        return base+offset
    end
    return {size=size,
        u8=function(o) return read.u8(at(o,1)) end,
        u16=function(o) return read.u16(at(o,2)) end,
        u32=function(o) return read.u32(at(o,4)) end,
        i16=function(o) return read.i16(at(o,2)) end,
        i32=function(o) return read.i32(at(o,4)) end,
        resref=function(o) return clean(read.str(at(o,8),8)) end,
        text=function(o,n) return read.str(at(o,n),n) end}
end

local function check(v,signature,minimum)
    if v.size<8 or v.text(0,8)~=signature then fail('expected signature '..signature) end
    if v.size<minimum then fail(string.format('header truncated: %d bytes, need %d',v.size,minimum)) end
end
local function tableEnd(v,offset,stride,count,what)
    -- An empty table reads nothing, wherever its offset points.
    if count>0 and offset+stride*count>v.size then fail(what..' table runs past the end of the data') end
end

local function effect(v,o)
    return {opcode=v.u16(o),target=v.u8(o+2),power=v.u8(o+3),p1=v.i32(o+4),p2=v.u32(o+8),
        timing=v.u8(o+12),resist=v.u8(o+13),duration=v.u32(o+14),prob1=v.u8(o+18),prob2=v.u8(o+19),
        res=v.resref(o+20),dice=v.i32(o+28),sides=v.i32(o+32),save=v.u32(o+36),saveBonus=v.i32(o+40),
        special=v.u32(o+44)}
end
-- The count effect blocks starting at block index of the shared table.
local function effects(v,offset,index,count)
    local start=offset+48*index
    if count>0 and start+48*count>v.size then fail('effects run past the end of the data') end
    local list={}
    for i=0,count-1 do list[i+1]=effect(v,start+48*i) end
    return list
end

local function spl(v,resref)
    check(v,'SPL V1  ',0x72)
    local abOff,abCount,fxOff=v.u32(0x64),v.u16(0x68),v.u32(0x6A)
    tableEnd(v,abOff,40,abCount,'ability')
    local abilities={}
    for i=0,abCount-1 do
        local at=abOff+40*i
        abilities[i+1]={form=v.u8(at),flags=v.u8(at+1),location=v.u16(at+2),target=v.u8(at+0x0C),
            targetCount=v.u8(at+0x0D),range=v.u16(at+0x0E),minLevel=v.u16(at+0x10),
            speed=v.u16(at+0x12),projectile=v.u16(at+0x26),
            effects=effects(v,fxOff,v.u16(at+0x20),v.u16(at+0x1E))}
    end
    return {kind='SPL',resref=resref,name=v.u32(0x08),flags=v.u32(0x18),spellType=v.u16(0x1C),
        exclusion=v.u32(0x1E),school=v.u8(0x25),secondary=v.u8(0x27),level=v.u32(0x34),
        abilities=abilities,casting=effects(v,fxOff,v.u16(0x6E),v.u16(0x70))}
end

local function itm(v,resref)
    check(v,'ITM V1  ',0x72)
    local abOff,abCount,fxOff=v.u32(0x64),v.u16(0x68),v.u32(0x6A)
    tableEnd(v,abOff,56,abCount,'ability')
    local abilities={}
    for i=0,abCount-1 do
        local at=abOff+56*i
        abilities[i+1]={attackType=v.u8(at),idRequired=v.u8(at+1),location=v.u8(at+2),
            target=v.u8(at+0x0C),targetCount=v.u8(at+0x0D),range=v.u16(at+0x0E),
            launcher=v.u8(at+0x10),speed=v.u8(at+0x12),thac0=v.i16(at+0x14),sides=v.u8(at+0x16),
            school=v.u8(at+0x17),dice=v.u8(at+0x18),secondary=v.u8(at+0x19),
            damageBonus=v.i16(at+0x1A),damageType=v.u16(at+0x1C),charges=v.u16(at+0x22),
            depletion=v.u16(at+0x24),flags=v.u32(at+0x26),projectile=v.u16(at+0x2A),
            isArrow=v.u16(at+0x32),isBolt=v.u16(at+0x34),isBullet=v.u16(at+0x36),
            effects=effects(v,fxOff,v.u16(at+0x20),v.u16(at+0x1E))}
    end
    return {kind='ITM',resref=resref,name=v.u32(0x08),identifiedName=v.u32(0x0C),
        flags=v.u32(0x18),itemType=v.u16(0x1C),proficiency=v.u8(0x31),stack=v.u16(0x38),
        enchantment=v.u32(0x60),abilities=abilities,equipping=effects(v,fxOff,v.u16(0x6E),v.u16(0x70))}
end

local function eff(v,resref)
    check(v,'EFF V2.0',0xD4)
    return {kind='EFF',resref=resref,effect={opcode=v.u32(0x10),target=v.u32(0x14),
        power=v.u32(0x18),p1=v.i32(0x1C),p2=v.u32(0x20),timing=v.u16(0x24),resist=v.u32(0x5C),
        duration=v.u32(0x28),prob1=v.u16(0x2C),prob2=v.u16(0x2E),res=v.resref(0x30),
        dice=v.i32(0x38),sides=v.i32(0x3C),save=v.u32(0x40),saveBonus=v.i32(0x44),
        special=v.u32(0x48),school=v.u32(0x4C),secondary=v.u32(0xD0),res2=v.resref(0x70),
        res3=v.resref(0x78)}}
end

-- Area-of-effect keys only for type 3.
local function pro(v,resref)
    check(v,'PRO V1.0',0x100)
    local kind=v.u16(0x08)
    local r={kind='PRO',resref=resref,type=kind,speed=v.u16(0x0A),flags=v.u32(0x0C),
        width=v.u16(0x2A),extFlags=v.u32(0x2C),creatureValue1=v.u16(0x3C),
        creatureType1=v.u16(0x3E),creatureValue2=v.u16(0x40),creatureType2=v.u16(0x42),
        defaultSpell=v.resref(0x44),successSpell=v.resref(0x4C)}
    if kind==3 then
        if v.size<0x24C then fail('area projectile truncated') end
        r.areaFlags=v.u16(0x200);r.rayCount=v.u16(0x202);r.trigger=v.u16(0x204)
        r.radius=v.u16(0x206);r.secondary=v.u16(0x214);r.repeats=v.u8(0x216)
        r.explosionProjectile=v.u16(0x21A);r.coneWidth=v.u16(0x224)
        r.extAreaFlags=v.u32(0x240);r.targetDice=v.u16(0x244);r.targetSides=v.u16(0x246)
    end
    return r
end

local PARSERS={SPL=spl,ITM=itm,EFF=eff,PRO=pro}

-- reader.get(kind, resref), reader.projectile(field value) and reader.lookup(kind, key), the
-- callable spells.classify takes (PRO by projectile field value, the rest by resref).
function M.new(g)
    local read=natives(g)
    local reader={problems={}}
    local cache,projectiles,seen={},nil,{}
    local function problem(text)
        if seen[text] or #reader.problems>=M.maxProblems then return end
        seen[text]=true;reader.problems[#reader.problems+1]=text
    end
    local function load(kind,resref)
        local fetch,toPtr=rawget(g,'EEex_Resource_Fetch'),rawget(g,'EEex_UDToPtr')
        if not read or type(fetch)~='function' or type(toPtr)~='function' then
            problem('EEex resource access unavailable');return nil
        end
        local res=fetch(resref,kind)
        if res==nil then return nil end
        local data=res:Demand()
        local base,size=data~=nil and toPtr(data),res.nSize
        if type(base)~='number' or base<=0 or type(size)~='number' or size<0 then
            problem(resref..'.'..kind..' could not be loaded');return nil
        end
        return PARSERS[kind](view(read,base,size),resref)
    end
    function reader.get(kind,resref)
        if PARSERS[kind]==nil or type(resref)~='string' then return nil end
        resref=upper(resref)
        if #resref==0 or #resref>8 then return nil end
        local key=kind..':'..resref
        if cache[key]~=nil then return cache[key] or nil end
        local ok,value=pcall(load,kind,resref)
        if not ok then
            problem(resref..'.'..kind..': '..(type(value)=='table' and value.format or tostring(value)))
            value=nil
        end
        cache[key]=value or false
        return value
    end
    -- Field value N is PROJECTL.IDS entry N-1; the first entry for a number wins.
    function reader.projectile(number)
        if type(number)~='number' then return nil end
        if projectiles==nil then
            projectiles={}
            local ok,err=pcall(function()
                local ids=g.EEex_Resource_LoadIDS('PROJECTL')
                g.EEex_Resource_IterateUnpackedIDSEntries(ids,function(id,line,start)
                    local name=type(start)=='string' and start:match('^%s*(%S+)') or
                        type(line)=='string' and line:match('^%s*(%S+)')
                    if type(id)=='number' and name and #name<=8 and not name:find('^//')
                        and projectiles[id+1]==nil then projectiles[id+1]=upper(name) end
                end)
            end)
            if not ok then problem('PROJECTL.IDS unreadable: '..tostring(err)) end
        end
        local resref=projectiles[number]
        return resref and reader.get('PRO',resref) or nil
    end
    function reader.lookup(kind,key)
        if kind=='PRO' and type(key)=='number' then return reader.projectile(key) end
        return reader.get(kind,key)
    end
    function reader.reset() cache,projectiles,seen={},nil,{};reader.problems={} end
    return reader
end
return M
