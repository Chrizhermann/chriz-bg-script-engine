-- Whether a creature is of the kind a spell's creature filter names (opcodes 175, 177, 185 and
-- 283 carry an IDS file and an entry). Plain values only: the creature's IDS values as
-- adapters/eeex/sense.lua reads them. The engine matches a few entries by rule (EA cutoffs,
-- the *_ALL classes, alignment masks); those rules follow the game's IDS files. An entry this
-- module cannot judge answers nil, and the caller leaves the spell out for that creature.
local M={}
-- IDS file numbers as the opcodes use them.
M.FIELDS={[2]='ea',[3]='general',[4]='race',[5]='class',[6]='specific',[7]='gender',[8]='alignment'}
-- CLASS.IDS: the classes each *_ALL entry stands for (the game's fixed class numbers).
M.CLASS_ALL={
    [202]={1,7,10,13,14,17,19},  -- MAGE_ALL: mages, their multiclasses, sorcerers
    [203]={2,7,8,9,10,16,17},    -- FIGHTER_ALL
    [204]={3,8,14,15,17,18},     -- CLERIC_ALL
    [205]={4,9,10,13,15},        -- THIEF_ALL
    [206]={5},                   -- BARD_ALL
    [207]={6},                   -- PALADIN_ALL
    [208]={11,16},               -- DRUID_ALL
    [209]={12,18},               -- RANGER_ALL
}
-- Classes that cast spells (CLASS.IDS): mage, cleric, bard, paladin, the multiclasses with a
-- caster class, druid, ranger, sorcerer, shaman.
M.CASTERS={}
for _,n in ipairs({1,3,5,6,7,8,10,11,12,13,14,15,16,17,18,19,21}) do M.CASTERS[n]=true end

local function number(v) return type(v)=='number' and v==v and v%1==0 end

-- EA.IDS (EE): 0 anyone; GOODCUTOFF (30) the good side; NOTGOOD (31) everything above it;
-- NOTEVIL (199) everything below EVILCUTOFF (200), which is the evil side.
local function ea(entry,value)
    if entry==0 then return true end
    if entry==30 then return value<=30 end
    if entry==31 then return value>=31 end
    if entry==199 then return value<200 end
    if entry==200 then return value>=200 end
    -- GOODBUTRED, GOODBUTBLUE, EVILBUTGREEN and EVILBUTBLUE name selection colours, and
    -- ANYTHING has no plain range: not judged here.
    if entry==28 or entry==29 or entry==201 or entry==202 or entry==126 then return nil end
    return value==entry
end
-- ALIGN.IDS: a mask entry names only the law axis (0x10, 0x20, 0x30) or only the good axis
-- (0x01, 0x02, 0x03).
local function alignment(entry,value)
    local law,good=math.floor(entry/16),entry%16
    if law==0 and good>0 then return value%16==good end
    if good==0 and law>0 then return math.floor(value/16)==law end
    return value==entry
end
local function class(entry,value)
    local all=M.CLASS_ALL[entry]
    if all then
        for _,n in ipairs(all) do if n==value then return true end end
        return false
    end
    return value==entry
end

-- true, false, or nil when the filter cannot be judged. creature.ids holds the IDS values.
function M.matches(filter,creature)
    if type(filter)~='table' or type(creature)~='table' or type(creature.ids)~='table' then return nil end
    local field=M.FIELDS[filter.ids]
    local entry=filter.entry
    if not field or not number(entry) then return nil end
    if entry==0 then return true end
    local value=creature.ids[field]
    if not number(value) then return nil end
    if field=='ea' then return ea(entry,value) end
    if field=='alignment' then return alignment(entry,value) end
    if field=='class' then return class(entry,value) end
    return value==entry
end

-- Whether the creature casts spells, by its class.
function M.caster(creature)
    return type(creature)=='table' and type(creature.ids)=='table' and M.CASTERS[creature.ids.class]==true
end
return M
