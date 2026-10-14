"""The installed runtime (bgse/lua/M_BGSE.lua) is current and installs the handoff globals."""
import importlib

import pytest

from tools import build_runtime

FAKE_EEEX = '''
ticks, queued, listeners = 40, {}, {}
local time = setmetatable({}, {__index = function(_, key) if key == 'm_gameTime' then return ticks end end})
EngineGlobals = {g_pBaldurChitin = {m_pObjectGame = {m_worldTime = time}}}
local objects = {[9] = {m_id = 9}}
EEex_GameObject_Get = function(id) return objects[id] end
EEex_GameObject_IsSprite = function(object, allowDead) return object ~= nil and allowDead == false end
EEex_Action_QueueResponseStringOnAIBase = function(text, object) queued[#queued + 1] = object.m_id .. ':' .. text end
EEex_GameState_AddDestroyedListener = function(fn) listeners[#listeners + 1] = fn end
creature = objects[9]
'''


def test_committed_runtime_is_current():
    assert build_runtime.TARGET.read_text(encoding='utf-8') == build_runtime.build()


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_runtime_installs_the_handoff(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=''; package.cpath=''")
    runtime.execute(FAKE_EEEX)
    runtime.execute(build_runtime.build())
    assert runtime.execute('''
        assert(BGSE and BGSE.version == '0.1.0-dev' and #listeners == 1)
        assert(package.loaded['kernel.hook'] == nil and package.loaded['adapters.eeex.hook'] == nil)
        -- No decider yet: every script pass falls through to SCS.
        assert(BGSE_Claim(creature, 'mage') == false)
        BGSE.setDecider(function(actor, family)
            if family == 'mage' then return {response = 'NoAction()'} end
        end)
        ticks = 41
        assert(BGSE_Claim(creature, 'priest') == false)
        assert(BGSE_Claim(creature, 'mage') == true and BGSE_Claim(creature, 'mage') == true)
        BGSE_Act(creature)
        assert(#queued == 1 and queued[1] == '9:NoAction()')
        BGSE.setEnabled(false)
        ticks = 42
        assert(BGSE_Claim(creature, 'mage') == false)
        return true
    ''') is True


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_runtime_without_engine_globals_declines(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute(build_runtime.build())
    assert runtime.execute('''
        BGSE.setDecider(function() return {response = 'NoAction()'} end)
        assert(BGSE_Claim({m_id = 3}, 'fighter') == false)
        assert(BGSE.inspect().declines['no-clock'] == 1)
        BGSE_Act({m_id = 3})
        return true
    ''') is True
