"""The optional playtest recorder stays a standalone, observer-only EEex bundle."""
import importlib
from pathlib import Path

import pytest

from tools import build_runtime

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_recorder_logic_and_fake_eeex_flow(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    assert runtime.execute(r'''
        local M=assert(loadfile(...))()
        assert(M.json({k='x',t=4,text='a\nb'}) == '{"k":"x","t":4,"text":"a\\nb"}')
        assert(M.json({}) == '[]')
        local old={{id=31,target={id=2},resource='SPWI112'}}
        assert(M.sameQueue(old,M.cloneQueue(old)))
        assert(not M.sameQueue(old,{{id=31,target={id=3},resource='SPWI112'}}))
        assert(M.spellOf({m_actionID=31,m_specificID=2112},'')=='SPWI112')
        assert(M.spellOf({m_actionID=25,m_specificID=2112},'')=='')
        local spent=M.spent({{id=1,name='Hero',spells={{list='mage',resref='SPWI112',level=1,ready=2}},
            items={{slot=18,resref='POTN52',uses={3,0,0}}}}},
            {{id=1,name='Hero',spells={{list='mage',resref='SPWI112',level=1,ready=1}},
            items={{slot=18,resref='POTN52',uses={1,0,0}}}}})
        assert(#spent==1 and spent[1].spells[1].count==1 and spent[1].items[1].uses[1]==2)

        local function str(v) return {get=function() return v end} end
        local function list(values)
            return {getReference=function(_,_) return values or {} end}
        end
        local area={m_resref=str('AR0001')}
        local function sprite(id,name,ea,x)
            return {m_id=id,name=name,m_resref=str(name..'RES'),m_pos={x=x,y=20},m_pArea=area,
                m_typeAI={m_EnemyAlly=ea,m_Class=1},m_baseStats={m_hitPoints=20,m_generalState=0},
                m_memorizedSpellsMage=list(),m_memorizedSpellsPriest=list(),m_memorizedSpellsInnate=list(),
                m_queuedActions={},m_equipment={m_items={get=function() return nil end}}}
        end
        local hero=sprite(1,'Hero',2,10)
        local foe=sprite(2,'Foe',200,30)
        local corpse=sprite(3,'Corpse',200,40);corpse.m_baseStats.m_generalState=0x400
        local game={m_options={m_nDifficultyLevel=5},m_worldTime={m_gameTime=100}}
        local g={objects={[1]=hero,[2]=foe},listeners={menu={},initialized={},destroyed={},started={},key={},bar={}},
            EngineGlobals={g_pBaldurChitin={m_pObjectGame=game}}}
        g.worldScreen={CheckIfPaused=function() return g.paused end}
        g.EngineGlobals.g_pBaldurChitin.GetActiveEngine=function() return g.worldScreen end
        g.paused=false;g.wall=1;g.lines={};g.os={date=function() return '20261108-010203' end,
            time=function() return g.wall end}
        g.io={open=function(path,mode)
            assert(path=='bgse-playtest/20261108-010203.jsonl' and mode=='a')
            return {write=function(_,text) g.lines[#g.lines+1]=text end,flush=function() end,close=function() end}
        end}
        g.Infinity_GetINIValue=function(section,key,default) assert(section=='BGSE' and key=='Recorder');return default end
        g.Infinity_PushMenu=function(name) assert(name=='BGSE_RECORDER_TICK') end
        g.EEex_Menu_Eval=function(menu) assert(menu:find('BGSE_RECORDER_TICK')) end
        g.EEex_Menu_AddAfterMainFileLoadedListener=function(fn) table.insert(g.listeners.menu,fn) end
        g.EEex_GameState_AddInitializedListener=function(fn) table.insert(g.listeners.initialized,fn) end
        g.EEex_GameState_AddDestroyedListener=function(fn) table.insert(g.listeners.destroyed,fn) end
        g.EEex_Action_AddSpriteStartedActionListener=function(fn) table.insert(g.listeners.started,fn) end
        g.EEex_Key_AddPressedListener=function(fn) table.insert(g.listeners.key,fn) end
        g.EEex_Actionbar_AddListener=function(fn) table.insert(g.listeners.bar,fn) end
        g.EEex_Key_GetName=function(key) return key==77 and 'M' or '' end
        g.EEex_GameState_WouldWorldScreenProcessInput=function() return true end
        g.EEex_GameObject_Get=function(id) return g.objects[id] end
        g.EEex_GameObject_IsSprite=function(object,allowDead) return object~=nil and not object.dead end
        g.EEex_Sprite_GetName=function(object) return object.name end
        g.EEex_Sprite_GetNumCharacters=function() return 1 end
        g.EEex_Sprite_GetInPortrait=function(index) assert(index==0);return hero end
        g.EEex_Sprite_GetStat=function(object,index) return ({[1]=30,[2]=4,[34]=3,[68]=0,[69]=0})[index] or 0 end
        g.EEex_BAnd=function(value,mask) return value==0 and 0 or mask end
        g.EEex_Utility_IterateCPtrList=function(values,fn) for _,value in ipairs(values or {}) do if fn(value) then break end end end
        g.EEex_Sprite_ForAllOfTypeStringInRange=function(subject,what,range,fn,los,nonSprites)
            assert(what=='[ENEMY]' and range==448 and los==1 and nonSprites==0)
            g.scans=(g.scans or 0)+1
            for _,object in pairs(g.objects) do if object~=subject then fn(object) end end
        end
        g.BGSE={director={setSink=function(_,fn) g.dirSink=fn end},choice={
            setSink=function(_,fn) g.choiceSink=fn end,setTrace=function(_,on) g.trace=on end}}

        local root=M.install(g)
        assert(root and #g.listeners.menu==1 and #g.listeners.initialized==1 and #g.listeners.destroyed==1
            and #g.listeners.started==1 and #g.listeners.key==1 and #g.listeners.bar==1)
        g.listeners.menu[1]();g.listeners.initialized[1]();root:tick()
        assert(root.started and g.dirSink and g.choiceSink and g.trace==true)
        g.objects[3]=corpse
        hero.m_baseStats={m_hitPoints=28}
        local foe2={m_id=2,m_resref=str('GNOLL'),dead=false,m_pos={x=45,y=55},
            m_typeAI={m_EnemyAlly=255},m_baseStats={m_hitPoints=24,m_generalState=0}}
        g.objects[2]=foe2
        g.objects[4]=nil
        hero.m_queuedActions={{m_actionID=31,m_acteeID={m_Instance=2},m_string1={m_pchData=str('SPWI112')}}}
        game.m_worldTime.m_gameTime=101;root:tick()
        -- Action carries actor x/y/hp and living target x/y/hp
        g.listeners.started[1](hero,{m_actionID=31,m_acteeID={m_Instance=2},m_dest={x=0,y=0},
            m_string1={m_pchData=str('')},m_specificID=2112})
        g.listeners.started[1](hero,{m_actionID=31,m_acteeID={m_Instance=-1},m_dest={x=80,y=90},
            m_string1={m_pchData=str('')},m_specificID=2112})
        g.listeners.key[1](77);g.listeners.bar[1]({mode='spell'},{id=3})
        g.dirSink({kind='decision',why='test'});g.choiceSink({kind='choice',why='test'})
        g.paused=true;game.m_worldTime.m_gameTime=102;root:tick()
        g.paused=false;game.m_worldTime.m_gameTime=103;root:tick()
        -- Mid-fight reinforcement arrives + hero moves & takes damage at +15 ticks -> {k='foes'} & {k='pos'}!
        local reinf={m_id=4,m_resref=str('KOBOLD7'),name='Kobold Guard',dead=false,m_pArea=area,
            m_pos={x=90,y=95},m_typeAI={m_EnemyAlly=255},m_baseStats={m_hitPoints=15,m_generalState=0}}
        g.objects[4]=reinf
        hero.m_pos={x=40,y=20}
        hero.m_baseStats={m_hitPoints=22}
        game.m_worldTime.m_gameTime=117;root:tick()
        assert(g.scans==2)
        g.objects[2]=nil;g.objects[4]=nil;game.m_worldTime.m_gameTime=210;root:tick()
        assert(g.scans==3)
        g.listeners.destroyed[1]();g.listeners.initialized[1]();game.m_worldTime.m_gameTime=5;root:tick()
        local output=table.concat(g.lines)
        assert(output:find('"k":"session"') and output:find('"difficulty":5') and output:find('"area":"AR0001"')
            and output:find('"k":"queue"') and output:find('"x":10') and output:find('"y":20'))
        assert(not output:find('Corpse'))
        assert(output:find('"k":"act"') and output:find('"hp":28') and output:find('"k":"key"') and output:find('"k":"bar"'))
        assert(output:find('"resource":"SPWI112"') and output:find('"target":{"x":80,"y":90}'))
        assert(output:find('"k":"foes"') and output:find('"KOBOLD7"') and output:find('"k":"pos"'))
        assert(output:find('"foesDead":%["FOERES","KOBOLD7"%]') or output:find('"foesDead":%["KOBOLD7","FOERES"%]'))
        assert(output:find('"tag":"dir"') and output:find('"tag":"ch"') and output:find('"k":"pause"'))
        assert(output:find('"reason":"quiet"') and output:find('"k":"load"') and root:inspect().loads==1)
        return 23
    ''', str(ROOT / 'adapters/eeex/recorder.lua')) == 23


def test_read_playtest_summarizes_joined_movement_hp_and_engine(tmp_path):
    from tools import read_playtest
    rec = tmp_path / 'play.jsonl'
    rec.write_text('\n'.join([
        '{"k":"fight","t":100,"phase":"start","members":[{"name":"Hero","x":0,"y":0,"hp":30,"items":{},"spells":{}}],"foes":[{"id":2,"name":"Gnoll"}]}',
        '{"k":"act","t":105,"member":"Hero","id":3,"x":0,"y":0,"hp":30}',
        '{"k":"foes","t":110,"foes":[{"id":4,"resref":"KOBOLD7","name":"Kobold Guard"}]}',
        '{"k":"pos","t":115,"party":[{"name":"Hero","x":30,"y":40,"hp":22}],"foes":[{"id":2,"hp":10}]}',
        '{"k":"eng","t":116,"tag":"ch","row":{"kind":"choice"}}',
        '{"k":"fight","t":210,"phase":"end","length":110,"dead":[],"spent":{},"foesDead":["GNOLL","KOBOLD7"],"reason":"quiet"}',
    ]), encoding='utf-8')
    fights = list(read_playtest.summarize(read_playtest.read_rows(rec)))
    assert len(fights) == 1
    current, ending = fights[0]
    assert len(current['joined']) == 1 and current['joined'][0]['resref'] == 'KOBOLD7'
    assert current['moved']['Hero'] == 50
    assert current['damage_taken']['Hero'] == 8
    assert current['eng']['ch:choice'] == 1
    assert ending['foesDead'] == ['GNOLL', 'KOBOLD7']


def test_recorder_bundle_is_separate_from_combat_engine():
    source = (ROOT / 'adapters/eeex/recorder.lua').read_text(encoding='utf-8')
    assert build_runtime.RECORDER_TARGET.read_text(encoding='utf-8') == build_runtime.build_recorder()
    assert build_runtime.RECORDER_MODULES == ('adapters.eeex.recorder',)
    assert 'adapters.eeex.recorder' not in build_runtime.MODULES
    for forbidden in ('os.execute', 'm_sName', 'm_nCharacters', 'm_characters', 'm_point'):
        assert forbidden not in source
    for directory in (ROOT / 'kernel', ROOT / 'combat-intent'):
        assert all('recorder' not in path.read_text(encoding='utf-8').lower() for path in directory.rglob('*.lua'))
    for path in (ROOT / 'adapters/eeex').glob('*.lua'):
        if path.name != 'recorder.lua':
            assert "require('adapters.eeex.recorder')" not in path.read_text(encoding='utf-8')
