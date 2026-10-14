-- EEex boundary of the BCS handoff, against fake engine globals.
local adapter=require('adapters.eeex.hook')
local function world(ini)
    local g={ticks=50,queued={},stored={},listeners={},objects={}}
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
local blind=world();blind.EngineGlobals=nil;blind.objects[3]={m_id=3,alive=true}
adapter.install(blind,{decide=function() return {response='NoAction()'} end})
assert(blind.BGSE_Claim(blind.objects[3],'mage')==false and blind.BGSE.inspect().declines['no-clock']==1)

-- 3. Claim and act through the globals; the response is queued on the live sprite. Repeated
-- claims in one pass (same game tick) get one answer.
g.objects[5]={m_id=5,alive=true}
local asked=0
local root=adapter.install(g,{version='test',backoffTicks=0,decide=function(a,family)
    asked=asked+1
    if a.id==5 and family=='mage' then return {response='Attack(NearestEnemyOf(Myself))'} end
end})
assert(root.version=='test' and g.BGSE==root and #g.listeners==1)
assert(g.BGSE_Claim(g.objects[5],'priest')==false)
assert(g.BGSE_Claim(g.objects[5],'mage')==true and g.BGSE_Claim(g.objects[5],'mage')==true and asked==2)
g.BGSE_Act(g.objects[5])
assert(#g.queued==1 and g.queued[1]=='5:Attack(NearestEnemyOf(Myself))')

-- 4. Bad objects never raise into the script; a vanished sprite is not acted on.
g.ticks=51
assert(g.BGSE_Claim(nil,'mage')==false)
local hostile=setmetatable({},{__index=function() error('freed object') end})
assert(g.BGSE_Claim(hostile,'mage')==false)
g.BGSE_Act(nil);g.BGSE_Act(hostile)
assert(g.BGSE_Claim(g.objects[5],'mage')==true)
g.objects[5].alive=false
g.BGSE_Act({m_id=5})
assert(#g.queued==1 and root.inspect().counts.errors==1)
g.objects[5].alive=true

-- 5. The kill switch and family switches, optionally kept in Baldur.lua.
g.ticks=52
root.setEnabled(false,true)
assert(g.stored['BGSE/Enabled']==0 and g.BGSE_Claim(g.objects[5],'mage')==false)
root.setEnabled(true)
assert(g.stored['BGSE/Enabled']==0)
root.setFamily('mage',false,true)
assert(g.stored['BGSE/Mages']==0 and g.BGSE_Claim(g.objects[5],'mage')==false)
root.setFamily('mage',true,true)
assert(g.stored['BGSE/Mages']==1)
local off=world({Enabled=0})
off.objects[5]={m_id=5,alive=true}
adapter.install(off,{decide=function() return {response='NoAction()'} end})
assert(off.BGSE_Claim(off.objects[5],'mage')==false and off.BGSE.inspect().enabled==false)

-- 6. A load (destroyed event) forgets claims; reinstalling keeps a single listener.
g.ticks=60
assert(g.BGSE_Claim(g.objects[5],'mage')==true)
g.listeners[1]()
g.BGSE_Act(g.objects[5])
assert(#g.queued==1 and root.inspect().pending==0)
local again=adapter.install(g,{decide=function() return {response='Wait(1)'} end})
assert(#g.listeners==1 and g.BGSE==again and again.listening)
assert(g.BGSE_Claim(g.objects[5],'fighter')==true)
g.listeners[1]()
assert(again.inspect().pending==0)

-- 7. Without a decider nothing is ever claimed; an experiment can install one later, and a
-- held round queues nothing.
local plain=world();plain.objects[1]={m_id=1,alive=true}
adapter.install(plain)
assert(plain.BGSE_Claim(plain.objects[1],'mage')==false and plain.BGSE.inspect().declines['no-decider']==1)
plain.BGSE.setDecider(function() return {hold=true} end)
assert(plain.BGSE_Claim(plain.objects[1],'mage')==true)
plain.BGSE_Act(plain.objects[1])
assert(#plain.queued==0 and plain.BGSE.inspect().counts.held==1)
return 7
