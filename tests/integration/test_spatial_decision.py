"""Spatial proposals use the ordinary choice/trace path, never native movement."""
import importlib
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[2]

@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_spatial_decision(backend):
    lua = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    lua.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    lua.execute(r'''
local perception=require('combat-intent.perception')
local spatial=require('combat-intent.spatial')
local candidates=require('combat-intent.candidates')
local decision=require('combat-intent.decision')
local trace=require('combat-intent.trace')
local dispatch=require('combat-intent.dispatch')
local copy=require('kernel.manifest').copy
local equal=require('kernel.manifest').equal
local function fact(source,v) return {source=source,value=v,observedAt=10,expiresAt=20,confidence=1} end
local frame={schemaVersion=1,sceneKey='scene/test',observerKey='mage/one',tick=10,eligibleAllies={},actors={
 {key='mage/one',visible=true,detected=true,facts={alive=fact('self',true),relation=fact('self','self'),position=fact('self',{x=100,y=100})}},
 {key='enemy/one',visible=true,detected=true,facts={alive=fact('sight',true),relation=fact('sight','enemy'),position=fact('sight',{x=110,y=100})}}}}
local view=perception.build(frame)
local cfg={scaleX=1,scaleY=4/3,maxDistance=32,personalSpace=2,margin=1,pathProofId='synthetic/path',
 weights={retreatGain=1,travelDistance=-.1},offsets={{id='left',x=-16,y=0},{id='right',x=16,y=0}}}
local reports={}
for _,s in ipairs(spatial.sample(view,cfg)) do reports[s.id]={sceneKey=frame.sceneKey,observerKey=frame.observerKey,
 tick=10,from={x=100,y=100},point=s.point,actors=view:export().actors,pathProofId=cfg.pathProofId,
 reachable=true,open=true,lineOfSight=true,clearance=3} end
local config={ownership={player=false,hardMode=false,world=false,encounter=false,forced=false,dialogue=false,
 cutscene=false,staging=false,imageOwner=false,alive=true,active=true,hostile=true,actionIdle=true,auraReady=true,
 capable=true,eligible=true},ownershipContext={sceneKey=frame.sceneKey,observerKey=frame.observerKey,tick=10},
 spells={},targets={},areaChecks={},spatial={config=cfg,reports=reports}}
local generated=candidates.generate(view,config)
local terms={wait={retreatGain=0,travelDistance=0},decline={retreatGain=0,travelDistance=0}}
for _,row in ipairs(generated.eligible) do if row.action.kind=='shadow-position' then terms[row.id]=copy(row.features) end end
local request={frame=frame,candidates=config,terms=terms,seed=7,profile={id='synthetic/spatial',weights=cfg.weights,
 nearBestBand=0,reactionTicks=0,commitmentTicks=0,maxMemoryAge=0,minConfidence=1}}
local result=decision.evaluate(request)
assert(result.choice.id=='position/left' and result.choice.score==14.4)
assert(equal(trace.replay(trace.record(result)),result))
local action,why=dispatch.revalidate(result,result,0)
assert(not action and why=='unsupported-action','spatial proposal became dispatchable')
local tampered=copy(request);tampered.terms['position/left'].retreatGain=999
assert(not pcall(decision.evaluate,tampered),'forged spatial score input accepted')
config.ownership.encounter=true
local denied=candidates.generate(view,config)
assert(#denied.eligible==1 and denied.eligible[1].id=='decline' and #denied.excluded==2)
assert(denied.excluded[1].reason=='higher-world-owner')
config.ownership.encounter=false;config.spatial.config.pathProofId=false
denied=candidates.generate(view,config)
assert(#denied.eligible==2 and #denied.excluded==2 and denied.excluded[1].reason=='path-capability-unadmitted')
''')
