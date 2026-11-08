-- Duties of a creature's lower scripts (adapters/eeex/lower.lua) and their way through the hook
-- (adapters/eeex/hook.lua), against fake engine objects: compiled blocks as CPtrLists, conditions
-- that hold or not, ACTION.IDS from a list.
local lower=require('adapters.eeex.lower')
local adapter=require('adapters.eeex.hook')
local ACTIONS={{0,'NoAction'},{1,'Attack'},{3,'AttackOneRound'},{30,'SetGlobal'},{36,'Continue'},
    {106,'Shout'},{107,'Enemy'},{113,'ForceSpell'},{120,'MoveToObject'},{137,'StartDialogNoSet'},
    {181,'SpellNoDec'},{182,'RemoveSpell'},{200,'ApplySpellRES'},{210,'DisplayStringHead'},{211,'Kill'}}
local function list(items)
    local head,last
    for _,item in ipairs(items) do
        local node={data=item}
        if last then last.pNext=node else head=node end
        last=node
    end
    return {m_pNodeHead=head,m_nCount=#items}
end
local function text(value) return {m_pchData={get=function() return value end}} end
-- action(id, variable name with its scope)
local function action(id,variable) return {m_actionID=id,m_string1=text(variable or '')} end
local function response(weight,actions) return {m_weight=weight,m_actionList=list(actions)} end
-- A block: whether it holds (a value or a function), then its responses.
local function block(holds,responses)
    return {m_condition={Hold=function(_,pending,object)
        assert(pending=='pending' and object~=nil)
        local value=holds;if type(holds)=='function' then value=holds() end
        return value and 1 or 0
    end},m_responseSet={m_responseList=list(responses)}}
end
local function script(name,blocks) return {cResRef={get=function() return name end},m_caList=list(blocks)} end
local function world(entries)
    local g={queued={},objects={},listeners={},ticks=10,BGSE_HOOKED={s1='mage',deciding='monster'}}
    local time=setmetatable({},{__index=function(_,key) if key=='m_gameTime' then return g.ticks end end})
    g.EngineGlobals={g_pBaldurChitin={m_pObjectGame={m_worldTime=time}}}
    g.EEex_Utility_IterateCPtrList=function(l,fn)
        local node=l.m_pNodeHead
        while node do
            if fn(node.data) then break end
            node=node.pNext
        end
    end
    g.EEex_Resource_LoadIDS=function(name) assert(name=='ACTION');return 'ids' end
    g.EEex_Resource_IterateUnpackedIDSEntries=function(ids,fn)
        assert(ids=='ids')
        for _,entry in ipairs(entries or ACTIONS) do fn(entry[1],entry[2]..'(O:Object*)',entry[2]) end
    end
    g.EEex_AIBase_GetScriptLevel=function(object,level) return object.scripts[level] end
    g.EEex_AIBase_GetScriptLevelResRef=function(object,level)
        local s=object.scripts[level]
        return s and s.cResRef:get() or ''
    end
    g.EEex_GameObject_Get=function(id) return g.objects[id] end
    g.EEex_GameObject_IsSprite=function(object) return object.alive end
    g.EEex_GameState_AddDestroyedListener=function(fn) g.listeners[#g.listeners+1]=fn end
    -- The engine's own response: one action (id 3) behind whatever the creature has queued.
    g.EEex_Action_QueueResponseStringOnAIBase=function(text,object)
        g.queued[#g.queued+1]=object.m_id..':'..text
        object:virtual_InsertAction(action(3))
    end
    return g
end
local function creature(id,scripts)
    local c={m_id=id,alive=true,scripts=scripts,m_pendingTriggers='pending',inserted={},
        m_queuedActions={m_nCount=0},m_curAction={m_actionID=0},m_curScriptNum=2,m_curResponseSetNum=0,
        m_curResponseNum=0}
    function c:virtual_InsertAction(a)
        self.inserted[#self.inserted+1]=a.m_actionID
        local q=self.m_queuedActions
        local node={data={m_actionID=a.m_actionID}}
        if q.m_pNodeHead then
            local last=q.m_pNodeHead
            while last.pNext do last=last.pNext end
            last.pNext=node
        else q.m_pNodeHead=node end
        q.m_nCount=q.m_nCount+1
    end
    return c
end

-- 1. The walk follows the game's pass: blocks in order, the first that holds ends the pass unless all
-- its responses continue. A block that only fights is never owed; one that does more is.
local g=world()
local walker=lower.new(g)
local summon=script('BDSUM00',{
    block(false,{response(100,{action(0)})}),
    block(true,{response(100,{action(30,'LOCALSBD_RangedA'),action(36)})}),
    block(true,{response(100,{action(3)})}),
    block(true,{response(100,{action(106)})})})
local deva=creature(1,{[4]=script('DEVAGOOD',{}),[7]=summon})
local found=walker.walk(deva,'devagood',{'bdsum00'})
assert(#found==0 and walker.inspect().stats.blocks==3 and walker.inspect().plans==1)
-- A shout that continues is owed and the pass goes on; a fight that writes a world variable is owed
-- too and ends the pass; what follows is never reached.
local reached=false
local shout=script('GPSHOUT',{
    block(true,{response(100,{action(106),action(36)})}),
    block(true,{response(100,{action(30,'GLOBALAttackedGith'),action(1)})}),
    block(function() reached=true;return true end,{response(100,{action(106)})})})
local gith=creature(2,{[0]=script('DECIDING',{}),[5]=shout})
found=walker.walk(gith,'DECIDING',{'gpshout'})
assert(#found==2 and found[1].key=='gpshout:1' and found[2].key=='gpshout:2' and not reached)
assert(found[1].script=='gpshout' and found[1].level==5 and found[2].block==2)
-- A block with a power cast without a spellbook entry among its responses is owed; SpellNoDec counts
-- unless the response removes the spell; ApplySpell, messages and local variables are the engine's.
local powers=script('DEMGAJ',{
    block(true,{response(70,{action(1)}),response(30,{action(113)})})})
local nodec=script('NODEC',{block(true,{response(100,{action(181),action(36)})}),
    block(true,{response(100,{action(181),action(182),action(36)})}),
    block(true,{response(100,{action(200),action(210),action(30,'LOCALSx'),action(36)})}),
    block(true,{response(100,{action(0)})})})
local demon=creature(3,{[0]=script('S1',{}),[4]=powers})
found=walker.walk(demon,'s1',{'demgaj'})
assert(#found==1 and found[1].key=='demgaj:1')
local caster=creature(4,{[0]=script('S1',{}),[6]=nodec})
found=walker.walk(caster,'s1',{'nodec'})
assert(#found==1 and found[1].key=='nodec:1')
-- Several lower scripts: walked in slot order, the next one only while the pass goes on; a slot that
-- does not hold the expected script ends the walk; the deciding script must be in the stack.
local talk=script('SHOUTDLG',{block(true,{response(100,{action(137)})})})
local both=creature(5,{[2]=script('S1',{}),[4]=script('GOING',{block(true,{response(100,{action(106),action(36)})})}),[7]=talk})
found=walker.walk(both,'s1',{'going','shoutdlg'})
assert(#found==2 and found[1].key=='going:1' and found[2].key=='shoutdlg:1' and found[2].level==7)
found=walker.walk(both,'s1',{'other','shoutdlg'})
assert(#found==0)
assert(#walker.walk(both,'absent',{'going'})==0 and #walker.walk(both,nil,{'going'})==0)
assert(#walker.walk(both,'s1',{})==0)

-- 2. run() queues the owed block's response, picked by weight, without Continue(); a world-only pick
-- keeps only its writes outside LOCALS; a fight pick is the engine's; a changed stack is gone.
local rolls={0.9}
walker=lower.new(g,{random=function() return table.remove(rolls,1) or 0 end})
found=walker.walk(gith,'deciding',{'gpshout'})
local result,count=walker.run(gith,found[1])
assert(result=='queued' and count==1 and #gith.inserted==1 and gith.inserted[1]==106)
result,count=walker.run(gith,found[2])
assert(result=='queued' and count==1 and gith.inserted[2]==30)
found=walker.walk(demon,'s1',{'demgaj'})
rolls={0.5};result=walker.run(demon,found[1]);assert(result=='fight' and #demon.inserted==0)
rolls={0.8};result,count=walker.run(demon,found[1]);assert(result=='queued' and count==1 and demon.inserted[1]==113)
local s=walker.inspect()
assert(s.stats.runs==3 and s.stats.fights==1 and s.stats.actions==3)
assert(s.recent[1].actions=='Shout' and s.recent[2].actions=='SetGlobal' and s.recent[3].actions=='ForceSpell')
demon.scripts[4]=script('OTHER',{})
assert(walker.run(demon,found[1])=='gone' and walker.run(demon,{key='x',script='demgaj',level=4,block=9})=='gone')
assert(walker.run(demon,nil)=='gone' and walker.inspect().stats.gone==2)
walker.reset();assert(walker.inspect().plans==0 and #walker.inspect().recent==0)

-- 3. Without ACTION.IDS nothing is owed, once counted.
local blind=world({})
local lost=lower.new(blind)
assert(#lost.walk(gith,'deciding',{'gpshout'})==0 and #lost.walk(gith,'deciding',{'gpshout'})==0)
assert(lost.inspect().stats.errors==1 and lost.inspect().broken~=nil and lost.run(gith,{script='gpshout'})=='gone')

-- 4. Through the hook: a creature whose deciding script has an unhooked shout script below stays on
-- the engine. The claim owes the shout; the response queues it before the engine's own action, and
-- only the engine's action counts as its own: a new decision lets it give way once the shout is done,
-- never while the shout still runs.
g=world()
local driven=creature(7,{[4]=script('DECIDING',{}),[7]=script('GENSHT01',{
    block(true,{response(100,{action(106),action(36)})}),
    block(true,{response(100,{action(3)})})})})
g.objects[7]=driven
local replaced={}
local root=adapter.install(g,{decide=function() return {response='AttackOneRound(NearestEnemyOf(Myself))'} end,
    replaced=function(object,info) replaced[#replaced+1]=info.kind end})
assert(g.BGSE_Claim(driven,'monster','deciding')==true)
s=root.inspect();assert(s.counts.owed==1 and s.owing==1 and s.declines['script-below']==nil)
g.BGSE_Act(driven)
assert(#driven.inserted==2 and driven.inserted[1]==106 and driven.inserted[2]==3)
assert(#g.queued==1 and g.queued[1]=='7:AttackOneRound(NearestEnemyOf(Myself))')
s=root.inspect();assert(s.counts.dutiesHanded==1 and s.lower.stats.runs==1 and s.owing==0)
-- Next pass, a new decision while the shout still waits in the queue: the engine's action stays.
g.ticks=11
assert(g.BGSE_Claim(driven,'monster','deciding')==true and #replaced==0 and driven.m_curResponseSetNum==0)
-- The shout is done and only the engine's action runs: a new decision lets it give way.
driven.m_queuedActions={m_nCount=0};driven.m_curAction={m_actionID=3}
g.ticks=12
assert(g.BGSE_Claim(driven,'monster','deciding')==true and #replaced==1 and driven.m_curResponseSetNum==-1)
-- A load forgets the plans.
g.listeners[1]();assert(root.inspect().lower.plans==0)
-- options.lower=false: no walk, the creature still fights on the engine.
local plain=world();plain.objects[7]=creature(7,driven.scripts)
local quiet=adapter.install(plain,{lower=false,decide=function() return {hold=true} end})
assert(plain.BGSE_Claim(plain.objects[7],'monster','deciding')==true and quiet.inspect().lower==nil)
assert(quiet.inspect().counts.owed==0)
-- A walker that has not planned a script yet has nothing to run for it.
assert(lower.new(g).run(gith,{key='gpshout:1',script='gpshout',level=5,block=1})=='gone')
return 4
