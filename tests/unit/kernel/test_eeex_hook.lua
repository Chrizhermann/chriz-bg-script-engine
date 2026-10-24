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
return 8
