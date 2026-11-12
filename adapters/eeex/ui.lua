-- Optional Challenge-Mode Contingency UI filter (Christopher, 2026-11-12).
--
-- When [BGSE] PlayerDefensiveContingencies=1 is set in Baldur.lua, filters offensive spells
-- (damage, disable, debuff, removal via combat-intent/contingency.isOffensive) out of the player's
-- Contingency and Chain Contingency selection list (_G.filterContingencyMageSpells). Sequencers and
-- Spell Triggers (SPWI420, SPWI710, SPWI809 and wild/innate variants) are never filtered.
--
-- Opt-in only: defaults to false. Uses live runtime SPL classification (We Overwrite).
local resources=require('adapters.eeex.resources')
local spells=require('combat-intent.spells')
local contingency=require('combat-intent.contingency')

local M={}
M.cacheLimit=512

-- Resrefs identifying Contingency and Chain Contingency UI screens (never Sequencers/Triggers).
local CONTINGENCY_RESREFS={SPWI617=true,SPWI908=true,SPIN142=true,['DW#WZCND']=true}
local SEQUENCER_RESREFS={SPWI420=true,SPWI710=true,SPWI809=true,SPIN143=true,SPIN144=true,SPIN145=true}

-- True only when the UI is currently populating Contingency or Chain Contingency.
function M.isContingencyScreen(g)
    if type(g)~='table' then return false end
    local resref=rawget(g,'contingencyResRef')
    if type(resref)=='string' and resref~='' then
        local up=resref:upper()
        if SEQUENCER_RESREFS[up] then return false end
        return CONTINGENCY_RESREFS[up]==true
    end
    return rawget(g,'showContingency')==true
end

function M.new(g,options)
    g=g or _G
    options=options or {}
    local reader=options.reader or resources.new(g)
    local enabled=options.playerDefensiveContingencies==true
    local cache,cached={},0
    local counts={hooked=0,filtered=0,kept=0}

    local function classify(resref,level)
        local up=resref:upper()
        local lvl=type(level)=='number' and level>=1 and math.floor(level) or 1
        local key=up..':'..lvl
        if cache[key]==nil then
            if cached>=M.cacheLimit then cache,cached={},0 end
            local record=reader.get('SPL',up)
            local index=record and spells.abilityForLevel(record,lvl)
            cache[key]=index and spells.classify(record,index,reader.lookup,{level=lvl}) or false
            cached=cached+1
        end
        return cache[key] or nil
    end

    local api={}

    function api:setPlayerDefensiveContingencies(value)
        enabled=(value==true)
    end

    function api:invalidate()
        cache,cached={},0
    end

    function api:isOffensive(resref,level)
        if type(resref)~='string' or resref=='' then return false end
        local c=classify(resref,level)
        return c~=nil and contingency.isOffensive(c)==true
    end

    function api:filterSpells(list)
        if not enabled or not M.isContingencyScreen(g) or type(list)~='table' then
            return list
        end
        local out={}
        for _,item in ipairs(list) do
            local level=type(item)=='table' and (item.casterLevel or item.level) or 1
            if type(item)=='table' and api:isOffensive(item.resref,level) then
                counts.filtered=counts.filtered+1
            else
                counts.kept=counts.kept+1
                out[#out+1]=item
            end
        end
        return out
    end

    function api:hookMenu()
        rawset(g,'_bgseUiApi',api)
        local orig=rawget(g,'filterContingencyMageSpells')
        if type(orig)~='function' then return false end
        local wrapper=rawget(g,'_bgseUiWrapper')
        if orig~=wrapper then
            rawset(g,'_bgseOrigFilterContingency',orig)
        end
        local base=rawget(g,'_bgseOrigFilterContingency')
        if type(base)~='function' then return false end
        if not wrapper then
            wrapper=function(...)
                local current=rawget(g,'_bgseUiApi')
                local list=base(...)
                if type(current)=='table' and type(current.filterSpells)=='function' then
                    return current:filterSpells(list)
                end
                return list
            end
            rawset(g,'_bgseUiWrapper',wrapper)
        end
        if orig~=wrapper then
            rawset(g,'filterContingencyMageSpells',wrapper)
            counts.hooked=counts.hooked+1
        end
        return true
    end

    function api:inspect()
        return {
            playerDefensiveContingencies=enabled,
            counts={hooked=counts.hooked,filtered=counts.filtered,kept=counts.kept},
        }
    end

    api:hookMenu()
    local addListener=rawget(g,'EEex_Menu_AddAfterMainFileLoadedListener')
    if type(addListener)=='function' and not rawget(g,'_bgseUiMenuListener') then
        rawset(g,'_bgseUiMenuListener',true)
        pcall(addListener,function()
            local current=rawget(g,'_bgseUiApi')
            if type(current)=='table' and type(current.hookMenu)=='function' then
                pcall(current.hookMenu,current)
            end
        end)
    end

    return api
end

return M
