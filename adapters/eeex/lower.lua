-- The duties of a creature's lower scripts. Christopher, 2026-11-08: the engine takes over every
-- creature, also one with a script without a hook below the script that decides for it (a summon's
-- BDSUM00, shout, dialogue and plot scripts). The game reaches such a script in a pass only when every
-- script above lets the pass through, and while the engine takes the creature's rounds it never does.
-- So on each claim the gate (kernel/hook.lua) asks walk() which of its blocks would fire now, as the
-- game would: slot by slot below the deciding script, block by block; the first block that holds ends
-- the pass unless every response of it ends with Continue(). A block that holds and does more than an
-- ordinary combat round is owed, by HOOK-02's rule for SCS's own blocks below the anchor: a shout, a
-- plot variable, a dialogue start, turning hostile, a power cast without a spellbook entry (the
-- ForceSpell family; SpellNoDec unless the response removes the spell). The engine's own choice
-- replaces the rest: attacks, moves, spellbook casts, weapon switches, waiting and the creature's own
-- bookkeeping (LOCALS variables, messages). A fight response that also writes a variable outside the
-- creature's own keeps those writes: the world's state follows the story, the fight is the engine's.
-- ApplySpell stays the engine's too: in these scripts it is SCS's free invisibility (DW#GITH1), which
-- the engine replaces with a thief's real skill (F2f).
-- A script with the engine's own hook at its top (kernel/hook.lua, 'auto': the game's own fight
-- scripts of gnolls, xvarts, ankhegs and the like) is walked the same way, the deciding script itself
-- first: its attacks are the engine's, its calls for help, story variables and death notes are
-- duties. Blocks that ask BGSE_Claim are the hook itself and are never evaluated here.
-- run() queues an owed block's response, picked by weight as the game picks, without Continue() and
-- without the response's ordinary fight actions (a gnoll's Help() runs, the Attack() beside it is the
-- engine's); its notes (the creature's own variables, messages, interrupt switches) stay with it.
-- Story targets (Christopher, 2026-11-10: a creature the engine takes over keeps what it was known
-- for): story() tells whether a creature its script attacks by name (xvarts "HulriksCow", gnolls
-- "Drizzt") is alive in its area; the gate then leaves the creature to its script (kernel/hook.lua),
-- pauses and all, as the game had the encounter. A script that attacks no one by name (nearly all)
-- costs a table lookup.
-- Engine objects never leave this module: records are plain, and the cache holds plain plans per
-- script resref (one resref has the same blocks for the whole session).
local M={}
M.levels={0,1,2,4,5,6,7}
M.planLimit=512
M.recentLimit=24
local function set(list)
    local t={}
    for _,name in ipairs(list) do t[name:upper()]=true end
    return t
end
M.CONTINUE=set{'Continue'}
M.UNGATED=set{'ForceSpell','ForceSpellRES','ReallyForceSpell','ReallyForceSpellRES','ForceSpellPoint',
    'ForceSpellPointRES','ReallyForceSpellPoint','ReallyForceSpellPointRES'}
M.NO_DECREMENT=set{'SpellNoDec','SpellNoDecRES'}
M.REMOVES=set{'RemoveSpell','RemoveSpellRES'}
M.VARIABLES=set{'SetGlobal','SetGlobalTimer','SetGlobalTimerRandom','IncrementGlobal'}
-- HOOK-02's ordinary combat round (tools/hook_rule.py, COMBAT without the casts that use no spellbook
-- entry, which are judged above; tests/unit/test_hook.py keeps the two lists equal).
M.COMBAT=set{'Spell','SpellRES','SpellNoDec','SpellNoDecRES','SpellPoint','SpellPointRES',
    'UseItem','Attack','AttackOneRound','AttackReevaluate','AttackNoSound',
    'EquipMostDamagingMelee','EquipRanged','SelectWeaponAbility',
    'MoveToObject','RunAwayFrom','RunAwayFromNoLeaveArea','RunAwayFromNoInterrupt',
    'RunAwayFromNoInterruptNoLeaveArea','RandomWalk','RandomWalkContinuous','FaceObject',
    'Turn','OpenDoor','Wait','SmallWait','NoAction','SetInterrupt','ClearActions',
    'RemoveSpell','ApplySpellRES','ApplySpell',
    'Continue','SetGlobal','SetGlobalTimer','SetGlobalTimerRandom','IncrementGlobal',
    'DisplayString','DisplayStringHead','VerbalConstant','PlaySound'}
-- The part of an ordinary combat round that only keeps notes: it stays with a duty response.
M.NOTES=set{'SetGlobal','SetGlobalTimer','SetGlobalTimerRandom','IncrementGlobal','DisplayString',
    'DisplayStringHead','VerbalConstant','PlaySound','SetInterrupt'}
-- Attacks: at a creature the script calls by name, they follow the story. Casts do not count: a cast
-- at a named friend is a heal, and one without a spellbook entry runs as a duty anyway.
M.AIMED=set{'Attack','AttackOneRound','AttackReevaluate','AttackNoSound'}
-- EEex_LuaTrigger, and the engine's question in a hook block.
M.LUA_TRIGGER=0x410E
M.CLAIM='BGSE_Claim'
local function lower(text) return type(text)=='string' and text:lower() or '' end
function M.new(g,options)
    options=options or {}
    local random=options.random or math.random
    -- ACTION.IDS: action number -> its names (upper case), and the first name, for the log.
    local names,primary,broken
    local plans,planCount={},0
    local stats={walks=0,blocks=0,owed=0,runs=0,actions=0,fights=0,gone=0,errors=0,stories=0,storyLooks=0,
        nameErrors=0}
    local recent={}
    local api={}
    local function iterate(list,fn) g.EEex_Utility_IterateCPtrList(list,fn) end
    local function known()
        if names or broken then return names end
        local ok,err=pcall(function()
            local found,first,count={},{},0
            g.EEex_Resource_IterateUnpackedIDSEntries(g.EEex_Resource_LoadIDS('ACTION'),function(id,line,start)
                local name=type(start)=='string' and start:match('^%s*([%a_][%w_]*)') or
                    type(line)=='string' and line:match('^%s*([%a_][%w_]*)') or nil
                if type(id)=='number' and name then
                    found[id]=found[id] or {}
                    found[id][name:upper()]=true
                    first[id]=first[id] or name
                    count=count+1
                end
            end)
            assert(count>0,'ACTION.IDS has no entries')
            names,primary=found,first
        end)
        -- Without the action names nothing can be told apart, so nothing is owed: the engine fights alone.
        if not ok then broken=tostring(err);stats.errors=stats.errors+1 end
        return names
    end
    local function kind(action)
        local list=names[action.m_actionID]
        if not list then return 'duty' end
        local function any(t)
            for name in pairs(list) do if t[name] then return true end end
            return false
        end
        if any(M.CONTINUE) then return 'continue' end
        if any(M.UNGATED) then return 'special' end
        if any(M.NO_DECREMENT) then return 'nodec' end
        if any(M.REMOVES) then return 'remove' end
        if any(M.VARIABLES) then
            -- A compiled variable name starts with its scope: LOCALS, GLOBAL or an area.
            return lower(action.m_string1.m_pchData:get()):sub(1,6)~='locals' and 'world' or 'note'
        end
        if any(M.NOTES) then return 'note' end
        if any(M.COMBAT) then return 'fight' end
        return 'duty'
    end
    -- The name of the creature an action attacks, lower case, when the script calls it by name (a
    -- compiled object carries the name it was written with; the game's own object kinds, Player1 or
    -- NearestEnemyOf(Myself), carry none); else nil. A name that cannot be read counts as none.
    local function named(action)
        local list=names[action.m_actionID]
        if not list then return nil end
        local aimed=false
        for name in pairs(list) do if M.AIMED[name] then aimed=true;break end end
        if not aimed then return nil end
        local ok,text=pcall(function() return action.m_acteeID.m_name.m_pchData:get() end)
        if not ok then stats.nameErrors=stats.nameErrors+1;return nil end
        text=type(text)=='string' and text:match('^[^%z]*'):lower() or ''
        if text~='' then return text end
    end
    -- A response: 'duty' (it runs without its fight actions), 'world' (only its writes outside LOCALS
    -- run) or 'fight'; removes: it uses up a spellbook entry, so its SpellNoDec is a spellbook cast.
    -- targets (optional) gets the names of the creatures it attacks by name.
    local function judge(response,targets)
        local seen={}
        iterate(response.m_actionList,function(action)
            seen[kind(action)]=true
            local name=targets and named(action)
            if name then targets[name]=true end
        end)
        local sort='fight'
        if seen.duty or seen.special or (seen.nodec and not seen.remove) then sort='duty'
        elseif seen.world then sort='world' end
        return {weight=tonumber(response.m_weight) or 0,kind=sort,continues=seen.continue==true,
            removes=seen.remove==true}
    end
    -- Whether a block is the engine's hook: one of its triggers asks BGSE_Claim.
    local function asksEngine(cr)
        local found=false
        iterate(cr.m_condition.m_triggerList,function(trigger)
            if trigger.m_triggerID==M.LUA_TRIGGER and
                tostring(trigger.m_string1.m_pchData:get()):find(M.CLAIM,1,true) then found=true;return true end
        end)
        return found
    end
    local function plan(name,script)
        if plans[name] then return plans[name] end
        local blocks,targets={},{}
        iterate(script.m_caList,function(cr)
            if asksEngine(cr) then blocks[#blocks+1]={hook=true,responses={}};return end
            local responses,owe,onward={},false,true
            iterate(cr.m_responseSet.m_responseList,function(response)
                local r=judge(response,targets)
                responses[#responses+1]=r
                if r.kind~='fight' then owe=true end
                if not r.continues then onward=false end
            end)
            if #responses==0 then onward=false end
            blocks[#blocks+1]={owe=owe,onward=onward,responses=responses}
        end)
        -- The creatures the script attacks by name, or nil.
        local story
        for target in pairs(targets) do story=story or {};story[#story+1]=target end
        if story then table.sort(story) end
        if planCount>=M.planLimit then plans,planCount={},0 end
        plans[name]={blocks=blocks,story=story};planCount=planCount+1
        return plans[name]
    end
    -- True when the pass ends in this script.
    local function walkScript(object,script,name,level,found)
        local p=plan(name,script)
        local index,stop=0,false
        iterate(script.m_caList,function(cr)
            index=index+1
            local block=p.blocks[index]
            if not block then stop=true;return true end
            if block.hook then return end
            stats.blocks=stats.blocks+1
            if cr.m_condition:Hold(object.m_pendingTriggers,object)~=0 then
                if block.owe then found[#found+1]={key=name..':'..index,script=name,level=level,block=index} end
                if not block.onward then stop=true;return true end
            end
        end)
        return stop
    end
    -- The scripts of the gate's list as the creature carries them now, in the order a pass runs them:
    -- visit(script, name, level) for each, until it answers true or the creature's slots no longer
    -- match the list.
    local function each(object,deciding,scripts,visit)
        deciding=deciding:lower()
        local after,index=false,1
        for _,level in ipairs(M.levels) do
            if index>#scripts then break end
            local name=lower(g.EEex_AIBase_GetScriptLevelResRef(object,level))
            local walks=false
            if not after then
                if name==deciding then
                    after=true
                    walks=scripts[index]==deciding
                end
            elseif name~='' and name~='none' then
                if name~=scripts[index] then break end
                walks=true
            end
            if walks then
                local script=g.EEex_AIBase_GetScriptLevel(object,level)
                if not script or visit(script,name,level) then break end
                index=index+1
            end
        end
    end
    -- The owed blocks of the gate's list (scripts in slot order: the deciding script itself first when
    -- it carries the engine's own hook, then those below it, none of them SCS-hooked), as plain records
    -- {key, script, level, block}.
    function api.walk(object,deciding,scripts)
        stats.walks=stats.walks+1
        local found={}
        if type(deciding)~='string' or type(scripts)~='table' or #scripts==0 or not known() then return found end
        each(object,deciding,scripts,function(script,name,level)
            return walkScript(object,script,name,level,found)
        end)
        stats.owed=stats.owed+#found
        return found
    end
    -- Whether a creature that the scripts of the gate's list attack by name is alive in the creature's
    -- area (see the top), and its name; false and 'absent' when they name someone who is not there.
    -- Scripts that name no one (nearly all) cost no look at the area.
    function api.story(object,deciding,scripts)
        if type(deciding)~='string' or type(scripts)~='table' or #scripts==0 or not known() then return false end
        local wanted
        each(object,deciding,scripts,function(script,name)
            for _,target in ipairs(plan(name,script).story or {}) do
                wanted=wanted or {}
                wanted[target]=true
            end
        end)
        if not wanted then return false end
        stats.storyLooks=stats.storyLooks+1
        local area=object.m_pArea
        if not area then return false,'absent' end
        local found
        for _,list in ipairs({'m_lVertSort','m_lVertSortBack'}) do
            if found then break end
            iterate(area[list],function(id)
                local other=id~=object.m_id and g.EEex_GameObject_Get(id)
                if other and g.EEex_GameObject_IsSprite(other,false) then
                    local ok,name=pcall(function() return lower(other.m_scriptName:get()):match('^[^%z]*') end)
                    if ok and wanted[name] then found=name;return true end
                end
            end)
        end
        if not found then return false,'absent' end
        stats.stories=stats.stories+1
        return true,found
    end
    local function nth(list,n)
        local i,item=0,nil
        iterate(list,function(value)
            i=i+1
            if i==n then item=value;return true end
        end)
        return item
    end
    local function pick(responses)
        local total=0
        for _,r in ipairs(responses) do total=total+math.max(0,r.weight) end
        if total<=0 then return 1 end
        local roll,last=random()*total,1
        for i,r in ipairs(responses) do
            if r.weight>0 then
                last=i
                roll=roll-r.weight
                if roll<0 then return i end
            end
        end
        return last
    end
    -- Queues an owed block's response on the creature: 'queued' and how many actions, 'fight' when the
    -- pick is an ordinary combat round (the engine's choice stands for it), 'gone' when the creature no
    -- longer runs that script.
    function api.run(object,record)
        if type(record)~='table' or not known() then return 'gone',0 end
        local p=plans[record.script]
        local block=p and p.blocks[record.block]
        local script=block and lower(g.EEex_AIBase_GetScriptLevelResRef(object,record.level))==record.script and
            g.EEex_AIBase_GetScriptLevel(object,record.level)
        local cr=script and nth(script.m_caList,record.block)
        if not cr then stats.gone=stats.gone+1;return 'gone',0 end
        local chosen=pick(block.responses)
        local wanted=block.responses[chosen]
        if not wanted or wanted.kind=='fight' then stats.fights=stats.fights+1;return 'fight',0 end
        local response=nth(cr.m_responseSet.m_responseList,chosen)
        if not response then stats.gone=stats.gone+1;return 'gone',0 end
        local queued={}
        iterate(response.m_actionList,function(action)
            local sort=kind(action)
            if sort=='continue' or sort=='fight' or sort=='remove' or (wanted.kind=='world' and sort~='world') or
                (sort=='nodec' and wanted.removes) then return end
            object:virtual_InsertAction(action)
            queued[#queued+1]=primary[action.m_actionID] or tostring(action.m_actionID)
        end)
        stats.runs=stats.runs+1;stats.actions=stats.actions+#queued
        if #recent>=M.recentLimit then table.remove(recent,1) end
        recent[#recent+1]={script=record.script,block=record.block,response=chosen,actions=table.concat(queued,',')}
        return 'queued',#queued
    end
    function api.inspect()
        local copy={}
        for key,value in pairs(stats) do copy[key]=value end
        local runs={}
        for i,row in ipairs(recent) do
            runs[i]={script=row.script,block=row.block,response=row.response,actions=row.actions}
        end
        return {stats=copy,plans=planCount,broken=broken,recent=runs}
    end
    -- A load forgets the plans (a reinstall may have changed a script between sessions).
    function api.reset() plans,planCount,recent={},0,{} end
    return api
end
return M
