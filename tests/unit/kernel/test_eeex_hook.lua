-- EEex boundary of the BCS handoff, against fake engine globals.
local adapter=require('adapters.eeex.hook')
-- A live sprite whose script levels (SCRLEV.IDS) hold the given resrefs (default: S1 as its
-- default script).
local function creature(id,levels)
    return {m_id=id,alive=true,levels=levels or {[7]='S1'}}
end
local function world(ini)
    local g={ticks=50,queued={},stored={},listeners={},objects={},BGSE_HOOKED={s1='mage'}}
    local time=setmetatable({},{__index=function(_,key) if key=='m_gameTime' then return g.ticks end end})
    g.EngineGlobals={g_pBaldurChitin={m_pObjectGame={m_worldTime=time}}}
    if ini~=false then
        g.Infinity_GetINIValue=function(section,key,default)
            assert(section=='BGSE')
            if ini and ini[key]~=nil then return ini[key] end
            return default
        end
        g.Infinity_SetINIValue=function(section,key,value) g.stored[section..'/'..key]=value end
    end
    g.EEex_GameObject_Get=function(id) return g.objects[id] end
    g.EEex_GameObject_IsSprite=function(object,allowDead) assert(allowDead==false);return object.alive end
    g.EEex_AIBase_GetScriptLevelResRef=function(object,level) return object.levels[level] or '' end
    g.EEex_Action_QueueResponseStringOnAIBase=function(text,object) g.queued[#g.queued+1]=object.m_id..':'..text end
    g.EEex_GameState_AddDestroyedListener=function(fn) g.listeners[#g.listeners+1]=fn end
    return g
end

-- 1. Settings: missing or broken INI access means on; 0 switches the engine or a family off.
local s=adapter.settings(world(false))
assert(s.enabled==true and s.families.mage and s.families.priest and s.families.fighter and s.families.monster)
s=adapter.settings(world({Enabled=0,Mages=0}))
assert(s.enabled==false and s.families.mage==false and s.families.priest==true)
local broken=world();broken.Infinity_GetINIValue=function() error('no ini') end
assert(adapter.settings(broken).enabled==true)
broken.Infinity_GetINIValue=function() return 'yes' end
assert(adapter.settings(broken).families.monster==true)

-- 2. Game time comes from either engine global; without one the gate declines.
local g=world()
assert(adapter.gameTime(g)==50)
local alt=world();alt.EEex_EngineGlobal_CBaldurChitin=alt.EngineGlobals.g_pBaldurChitin;alt.EngineGlobals=nil
assert(adapter.gameTime(alt)==50)
local blind=world();blind.EngineGlobals=nil;blind.objects[3]=creature(3)
adapter.install(blind,{decide=function() return {response='NoAction()'} end})
assert(blind.BGSE_Claim(blind.objects[3],'mage','s1')==false and blind.BGSE.inspect().declines['no-clock']==1)

-- 3. Claim and act through the globals; the response is queued on the live sprite. Repeated
-- claims in one pass (same game tick) get one answer.
g.objects[5]=creature(5)
local asked=0
local root=adapter.install(g,{version='test',backoffTicks=0,decide=function(a,family)
    asked=asked+1
    if a.id==5 and family=='mage' then return {response='Attack(NearestEnemyOf(Myself))'} end
end})
assert(root.version=='test' and g.BGSE==root and #g.listeners==1)
assert(g.BGSE_Claim(g.objects[5],'priest','s1')==false)
assert(g.BGSE_Claim(g.objects[5],'mage','s1')==true and g.BGSE_Claim(g.objects[5],'mage','s1')==true and asked==2)
g.BGSE_Act(g.objects[5])
assert(#g.queued==1 and g.queued[1]=='5:Attack(NearestEnemyOf(Myself))')

-- 4. Bad objects never raise into the script; a vanished sprite is not acted on.
g.ticks=51
assert(g.BGSE_Claim(nil,'mage','s1')==false)
local hostile=setmetatable({},{__index=function() error('freed object') end})
assert(g.BGSE_Claim(hostile,'mage','s1')==false)
g.BGSE_Act(nil);g.BGSE_Act(hostile)
assert(g.BGSE_Claim(g.objects[5],'mage','s1')==true)
g.objects[5].alive=false
g.BGSE_Act({m_id=5})
assert(#g.queued==1 and root.inspect().counts.errors==1)
g.objects[5].alive=true

-- 5. The kill switch and family switches, optionally kept in Baldur.lua.
g.ticks=52
root.setEnabled(false,true)
assert(g.stored['BGSE/Enabled']==0 and g.BGSE_Claim(g.objects[5],'mage','s1')==false)
root.setEnabled(true)
assert(g.stored['BGSE/Enabled']==0)
root.setFamily('mage',false,true)
assert(g.stored['BGSE/Mages']==0 and g.BGSE_Claim(g.objects[5],'mage','s1')==false)
root.setFamily('mage',true,true)
assert(g.stored['BGSE/Mages']==1)
local off=world({Enabled=0})
off.objects[5]=creature(5)
adapter.install(off,{decide=function() return {response='NoAction()'} end})
assert(off.BGSE_Claim(off.objects[5],'mage','s1')==false and off.BGSE.inspect().enabled==false)

-- 6. A load (destroyed event) forgets claims; reinstalling keeps a single listener.
g.ticks=60
assert(g.BGSE_Claim(g.objects[5],'mage','s1')==true)
g.listeners[1]()
g.BGSE_Act(g.objects[5])
assert(#g.queued==1 and root.inspect().pending==0)
local again=adapter.install(g,{decide=function() return {response='Wait(1)'} end})
assert(#g.listeners==1 and g.BGSE==again and again.listening)
assert(g.BGSE_Claim(g.objects[5],'fighter','s1')==true)
g.listeners[1]()
assert(again.inspect().pending==0)

-- 7. Without a decider nothing is ever claimed; an experiment can install one later, and a
-- held round queues nothing.
local plain=world();plain.objects[1]=creature(1)
adapter.install(plain)
assert(plain.BGSE_Claim(plain.objects[1],'mage','s1')==false and plain.BGSE.inspect().declines['no-decider']==1)
plain.BGSE.setDecider(function() return {hold=true} end)
assert(plain.BGSE_Claim(plain.objects[1],'mage','s1')==true)
plain.BGSE_Act(plain.objects[1])
assert(#plain.queued==0 and plain.BGSE.inspect().counts.held==1)
-- options.held hears of a held round with the live sprite.
local heldBy={}
local holding=world();holding.objects[1]=creature(1)
adapter.install(holding,{decide=function() return {hold=true,own=true} end,
    held=function(object,d) heldBy[#heldBy+1]={object=object,own=d.own} end})
assert(holding.BGSE_Claim(holding.objects[1],'mage','s1')==true)
holding.BGSE_Act(holding.objects[1])
assert(#holding.queued==0 and #heldBy==1 and heldBy[1].object==holding.objects[1] and heldBy[1].own==true)

-- 8. Script slots: read with EEex's accessor in the engine's order, case-insensitive; the
-- hooked list arrives with M_BGSEHK.lua, possibly after the runtime; a script below that
-- carries no hook declines; without the accessor the stack is unknown.
local late=world();late.BGSE_HOOKED=nil
local demon=creature(1,{[4]='TANARI',[7]='DW2MS2GE',[5]='NONE'})
local names=adapter.scripts(late,demon)
assert(#names==7 and names[4]=='tanari' and names[5]=='none' and names[7]=='dw2ms2ge' and names[1]=='')
local rest=adapter.below(late,demon,'tanari');assert(#rest==1 and rest[1]=='dw2ms2ge')
assert(#adapter.below(late,demon,'dw2ms2ge')==0 and adapter.below(late,demon,'other')==nil)
late.objects[1]=demon
late.objects[2]=creature(2,{[0]='TANARI',[7]='SHOUTDLG'})
adapter.install(late,{decide=function() return {hold=true} end})
assert(late.BGSE_Claim(demon,'monster','tanari')==false and late.BGSE.inspect().declines['no-registry']==1)
late.BGSE_HOOKED={TANARI='monster',dw2ms2ge='fighter'};late.ticks=51
assert(late.BGSE_Claim(demon,'monster','tanari')==true)
assert(late.BGSE_Claim(demon,'fighter','dw2ms2ge')==false and late.BGSE.inspect().declines['lower-script']==1)
assert(late.BGSE_Claim(late.objects[2],'monster','tanari')==false and late.BGSE.inspect().declines['script-below']==1)
late.objects[1].alive=false;late.ticks=52
assert(late.BGSE_Claim(demon,'monster','tanari')==false and late.BGSE.inspect().declines['no-stack']==1)
local bare=world();bare.EEex_AIBase_GetScriptLevelResRef=nil;bare.objects[1]=creature(1)
assert(adapter.scripts(bare,bare.objects[1])==nil and adapter.below(bare,bare.objects[1],'s1')==nil)
adapter.install(bare,{decide=function() return {hold=true} end})
assert(bare.BGSE_Claim(bare.objects[1],'mage','s1')==false and bare.BGSE.inspect().declines['no-stack']==1)
assert(bare.BGSE.inspect().counts.errors==0)
local list=adapter.stack(late,demon);assert(#list==2 and list[1]=='tanari' and list[2]=='dw2ms2ge')
assert(adapter.stack(bare,bare.objects[1])==nil)

-- 9. SCS blocks that stand aside while the engine drives the creature (BGSE_Zones, BGSE_Search,
-- BGSE_Hide) go by the script that decides for it: a mage script below SCS's general AI follows the
-- general AI's family (here the engine's choice is on for mages only), and the general AI below a
-- mage script follows the mage's. A script the creature does not carry never stands aside. BGSE_Hide
-- passes the kind of free invisibility that asks; BGSE_Prep the kind, cast and spent spell of SCS's
-- preparation, and BGSE_Prepped hands the same on for a creature the engine drives. BGSE_Stay (SCS's
-- vanishing exits) goes the same way.
local stacked=world()
stacked.BGSE_HOOKED={s1='mage',dw1melas='fighter'}
local prepped={}
local fake={attach=function() end,inspect=function() return {} end,searches=function(_,family) return family=='mage' end,
    zones=function(_,family) return family=='mage' end,
    hides=function(_,family,_,kind) return family=='mage' and kind=='plain' end,
    holdsPrep=function(_,family,_,kind,cast,spent) return family=='mage' and kind=='opener' and cast=='SPWI212' and spent=='' end,
    prepped=function(_,family,id,kind,cast,spent) prepped[#prepped+1]={family=family,id=id,kind=kind,cast=cast,spent=spent} end,
    stays=function(_,family,id) return family=='mage' and id==2 end}
local under=creature(1,{[6]='DW1MELAS',[7]='S1'})
local over=creature(2,{[6]='S1',[7]='DW1MELAS'})
stacked.objects[1],stacked.objects[2]=under,over
local stackedRoot=adapter.install(stacked,{decide=function() return {hold=true} end,choice=fake})
assert(stacked.BGSE_Search(under,'mage','s1')==false and stacked.BGSE_Search(under,'fighter','dw1melas')==false)
assert(stacked.BGSE_Zones(under,'mage','s1')==false and stacked.BGSE_Zones(under,'fighter','dw1melas')==false)
assert(stacked.BGSE_Search(over,'fighter','dw1melas')==true and stacked.BGSE_Search(over,'mage','s1')==true)
assert(stacked.BGSE_Zones(over,'fighter','dw1melas')==true and stacked.BGSE_Zones(over,'mage','s1')==true)
assert(stacked.BGSE_Search(over,'priest','s2')==false and stacked.BGSE_Zones(over,'priest','s2')==false)
assert(stacked.BGSE_Hide(over,'fighter','dw1melas','plain')==true and stacked.BGSE_Hide(over,'mage','s1','plain')==true)
assert(stacked.BGSE_Hide(over,'mage','s1','improved')==false and stacked.BGSE_Hide(under,'mage','s1','plain')==false)
assert(stacked.BGSE_Prep(over,'fighter','dw1melas','opener','SPWI212','')==true and stacked.BGSE_Prep(over,'mage','s1','opener','SPWI212','')==true)
assert(stacked.BGSE_Prep(over,'mage','s1','prebuff','SPWI212','')==false and stacked.BGSE_Prep(under,'mage','s1','opener','SPWI212','')==false)
assert(stacked.BGSE_Prep(over,'priest','s2','opener','SPWI212','')==false)
assert(stacked.BGSE_Stay(over,'fighter','dw1melas')==true and stacked.BGSE_Stay(over,'mage','s1')==true)
assert(stacked.BGSE_Stay(under,'mage','s1')==false and stacked.BGSE_Stay(over,'priest','s2')==false)
stacked.BGSE_Prepped(over,'fighter','dw1melas','prebuff','dwsw408','WIZARD_STONE_SKIN')
stacked.BGSE_Prepped(over,'priest','s2','prebuff','dwsw408','WIZARD_STONE_SKIN')
assert(#prepped==1 and prepped[1].family=='mage' and prepped[1].id==2 and prepped[1].kind=='prebuff')
assert(prepped[1].cast=='dwsw408' and prepped[1].spent=='WIZARD_STONE_SKIN')
stackedRoot.setFamily('mage',false)
assert(stacked.BGSE_Search(over,'fighter','dw1melas')==false and stacked.BGSE_Zones(over,'fighter','dw1melas')==false)
assert(stacked.BGSE_Hide(over,'fighter','dw1melas','plain')==false)
assert(stacked.BGSE_Prep(over,'mage','s1','opener','SPWI212','')==false)
assert(stacked.BGSE_Stay(over,'mage','s1')==false)
stacked.BGSE_Prepped(over,'mage','s1','prebuff','dwsw408','')
assert(#prepped==1)
stackedRoot.setFamily('mage',true)
over.alive=false
assert(stacked.BGSE_Search(over,'mage','s1')==false and stacked.BGSE_Hide(over,'mage','s1','plain')==false)
assert(stacked.BGSE_Prep(over,'mage','s1','opener','SPWI212','')==false)
assert(stacked.BGSE_Stay(over,'mage','s1')==false)
assert(stackedRoot.inspect().counts.errors==0)
-- A choice that fails lets SCS's preparation and its vanishing exits run, and its notice never reaches
-- the script.
local failing=world()
failing.BGSE_HOOKED={s1='mage'}
failing.objects[1]=creature(1,{[7]='S1'})
adapter.install(failing,{decide=function() return {hold=true} end,choice={attach=function() end,inspect=function() return {} end,
    holdsPrep=function() error('boom') end,prepped=function() error('boom') end,stays=function() error('boom') end}})
assert(failing.BGSE_Prep(failing.objects[1],'mage','s1','opener','SPWI212','')==false)
assert(failing.BGSE_Stay(failing.objects[1],'mage','s1')==false)
failing.BGSE_Prepped(failing.objects[1],'mage','s1','prebuff','dwsw408','')

-- 10. The game leaves the actions a block queued running while that block stays true. A claim for
-- a new decision, or for a hold with the creature standing still, clears the response set number
-- of the block that queued the engine's own running actions, so the game interrupts them; only
-- while they run as the hook's last response queued them. A hold leaves them alone, and so does
-- anything else in the creature's queue (a story's action behind them), another block's actions,
-- a load and a response that ran outside a script block.
local w=world()
w.EEex_Utility_IterateCPtrList=function(t,fn) for _,x in ipairs(t) do if fn(x) then break end end end
-- The action each line of a response queues: the game reads one action a line (300:
-- SelectWeaponAbility, a number made up for the test).
local parsed={['AttackOneRound(X)']=105,['MoveToPoint([1.2])']=23,['SelectWeaponAbility(1,0)']=300}
w.EEex_Action_QueueResponseStringOnAIBase=function(text,object)
    w.queued[#w.queued+1]=text
    local q=object.m_queuedActions
    for line in (text..'\n'):gmatch('(.-)\n') do q[#q+1]={m_actionID=assert(parsed[line],line)} end
    q.m_nCount=#q
end
local brute=creature(4)
brute.m_curAction,brute.m_queuedActions={m_actionID=0},{m_nCount=0}
brute.m_curScriptNum,brute.m_curResponseSetNum,brute.m_curResponseNum=-1,-1,-1
w.objects[4]=brute
local function push(o,id) local q=o.m_queuedActions;q[#q+1]={m_actionID=id};q.m_nCount=#q end
local function clear(o) o.m_curAction,o.m_queuedActions={m_actionID=0},{m_nCount=0} end
-- The hook block's response: the game records the block (override script, block 1), its
-- EEex_LuaAction (472) runs BGSE_Act, and then the first queued action starts.
local function respond(o)
    o.m_curScriptNum,o.m_curResponseSetNum,o.m_curResponseNum=0,1,1
    o.m_curAction={m_actionID=472}
    w.BGSE_Act(o)
    local q=o.m_queuedActions
    o.m_curAction=table.remove(q,1) or {m_actionID=0};q.m_nCount=#q
end
local answer
local heard={}
local wroot=adapter.install(w,{decide=function() return answer end,
    replaced=function(object,info) heard[#heard+1]={id=object.m_id,kind=info.kind,action=info.action,left=info.left} end})
local function claim() w.ticks=w.ticks+1;return w.BGSE_Claim(brute,'mage','s1') end
-- A pass decides the response, and the hook block's response runs it.
local function run(response)
    clear(brute);answer={response=response}
    assert(claim()==true)
    respond(brute)
end
run('AttackOneRound(X)')
assert(brute.m_curAction.m_actionID==105 and brute.m_curResponseSetNum==1 and w.queued[#w.queued]=='AttackOneRound(X)')
answer={hold=true}
assert(claim()==true and brute.m_curResponseSetNum==1 and wroot.inspect().replaced.count==0)
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and brute.m_curResponseSetNum==-1)
assert(wroot.inspect().replaced.count==1 and #heard==1 and heard[1].id==4 and heard[1].kind=='decision')
assert(heard[1].action==105 and heard[1].left==1)
-- Asked again in the same pass, they give way only once.
brute.m_curResponseSetNum=1
assert(w.BGSE_Claim(brute,'mage','s1')==true and brute.m_curResponseSetNum==1 and #heard==1)
-- The game interrupts them and runs the response: the walk is the engine's own now. A story's
-- action added behind it keeps it, until that is gone; then a wait replaces it.
clear(brute);respond(brute)
assert(brute.m_curAction.m_actionID==23 and w.queued[#w.queued]=='MoveToPoint([1.2])')
push(brute,106)
answer={hold=true,idle=true}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==1)
brute.m_queuedActions={m_nCount=0}
assert(claim()==true and brute.m_curResponseSetNum==-1 and #heard==2 and heard[2].kind=='idle' and heard[2].action==23)
-- Two actions queued: they give way while both are left and once the first is done, not when
-- something else runs in their place.
run('SelectWeaponAbility(1,0)\nAttackOneRound(X)')
assert(brute.m_curAction.m_actionID==300 and brute.m_queuedActions.m_nCount==1)
assert(claim()==true and brute.m_curResponseSetNum==-1 and #heard==3 and heard[3].action==300 and heard[3].left==2)
run('SelectWeaponAbility(1,0)\nAttackOneRound(X)')
brute.m_curAction=table.remove(brute.m_queuedActions,1);brute.m_queuedActions.m_nCount=0
assert(brute.m_curAction.m_actionID==105 and claim()==true and brute.m_curResponseSetNum==-1 and #heard==4)
run('SelectWeaponAbility(1,0)\nAttackOneRound(X)')
brute.m_curAction={m_actionID=23};brute.m_queuedActions={m_nCount=0}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
-- Another block took over: its actions are its own, and the engine's record of its own is gone.
run('AttackOneRound(X)')
brute.m_curResponseSetNum=4
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and brute.m_curResponseSetNum==4)
brute.m_curResponseSetNum=1
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
-- A load forgets which actions were the engine's own, and so does a response that queues nothing:
-- an attack a story's script queues later in the same block's name is not the engine's.
run('AttackOneRound(X)')
w.listeners[1]()
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
run('AttackOneRound(X)')
clear(brute);answer={hold=true}
assert(claim()==true)
respond(brute)
brute.m_curAction={m_actionID=105}
answer={response='MoveToPoint([1.2])'}
assert(brute.m_curResponseSetNum==1 and claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
-- A response that ran outside a script block (no response set), or found the queue taken, queues
-- nothing the engine counts as its own.
clear(brute);brute.m_curScriptNum,brute.m_curResponseSetNum,brute.m_curResponseNum=-1,-1,-1
answer={response='AttackOneRound(X)'}
assert(claim()==true)
w.BGSE_Act(brute)
brute.m_curAction=table.remove(brute.m_queuedActions,1);brute.m_queuedActions.m_nCount=0
answer={response='MoveToPoint([1.2])'}
assert(brute.m_curAction.m_actionID==105 and claim()==true and #heard==4)
brute.m_curScriptNum,brute.m_curResponseSetNum,brute.m_curResponseNum=0,1,1
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
clear(brute);push(brute,106);answer={response='AttackOneRound(X)'}
assert(claim()==true)
respond(brute)
assert(brute.m_curAction.m_actionID==106 and brute.m_queuedActions.m_nCount==1)
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
-- A claim whose kind went missing (a wrapper around the gate that passes on its first answer only,
-- as lab batch J's did) leaves them running: every hold would otherwise stop the engine's own attack.
run('AttackOneRound(X)')
local priorClaim=wroot.gate.claim
wroot.gate.claim=function(self,actor,family) return (priorClaim(self,actor,family)) end
answer={hold=true}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and brute.m_curResponseSetNum==1 and #heard==4)
wroot.gate.claim=priorClaim
-- A sprite that cannot be read is counted, and the claim keeps its answer; a listener that fails
-- changes nothing.
run('AttackOneRound(X)')
brute.m_curAction=setmetatable({},{__index=function() error('freed action') end})
answer={response='MoveToPoint([1.2])'}
assert(claim()==true and wroot.inspect().replaced.errors==1 and wroot.inspect().replaced.count==4)
local failing=world();failing.EEex_Utility_IterateCPtrList=w.EEex_Utility_IterateCPtrList
failing.EEex_Action_QueueResponseStringOnAIBase=w.EEex_Action_QueueResponseStringOnAIBase
local other=creature(4);failing.objects[4]=other
other.m_curAction,other.m_queuedActions={m_actionID=0},{m_nCount=0}
other.m_curScriptNum,other.m_curResponseSetNum,other.m_curResponseNum=0,1,1
local fanswer={response='AttackOneRound(X)'}
local froot=adapter.install(failing,{decide=function() return fanswer end,replaced=function() error('listener broke') end})
assert(failing.BGSE_Claim(other,'mage','s1')==true)
failing.BGSE_Act(other)
other.m_curAction=table.remove(other.m_queuedActions,1);other.m_queuedActions.m_nCount=0
failing.ticks=failing.ticks+1;fanswer={response='MoveToPoint([1.2])'}
assert(failing.BGSE_Claim(other,'mage','s1')==true and other.m_curResponseSetNum==-1)
assert(froot.inspect().replaced.count==1 and froot.inspect().replaced.errors==0)
-- At most ownLimit creatures' records are kept, and one past it starts afresh; a record that gave
-- way no longer counts.
local limit=adapter.ownLimit
adapter.ownLimit=2
local pair=world();pair.EEex_Utility_IterateCPtrList=w.EEex_Utility_IterateCPtrList
pair.EEex_Action_QueueResponseStringOnAIBase=w.EEex_Action_QueueResponseStringOnAIBase
local panswer
local proot=adapter.install(pair,{decide=function() return panswer end})
local crowd={}
for id=1,4 do crowd[id]=creature(id);pair.objects[id]=crowd[id] end
local function attack(...)
    pair.ticks=pair.ticks+1;panswer={response='AttackOneRound(X)'}
    for _,o in ipairs({...}) do
        o.m_curAction,o.m_queuedActions={m_actionID=0},{m_nCount=0}
        o.m_curScriptNum,o.m_curResponseSetNum,o.m_curResponseNum=0,1,1
        assert(pair.BGSE_Claim(o,'mage','s1')==true)
        pair.BGSE_Act(o)
        o.m_curAction=table.remove(o.m_queuedActions,1);o.m_queuedActions.m_nCount=0
    end
    pair.ticks=pair.ticks+1
end
local function walk(o)
    panswer={response='MoveToPoint([1.2])'}
    assert(pair.BGSE_Claim(o,'mage','s1')==true)
    return o.m_curResponseSetNum==-1
end
attack(crowd[1]);assert(walk(crowd[1]))
attack(crowd[2],crowd[3]);assert(walk(crowd[2]) and walk(crowd[3]))
attack(crowd[2],crowd[3],crowd[4])
assert(not walk(crowd[2]) and not walk(crowd[3]) and walk(crowd[4]) and proot.inspect().replaced.count==4)
adapter.ownLimit=limit
assert(wroot.inspect().counts.errors==0)
return 10
