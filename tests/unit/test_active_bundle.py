"""Task25's private active bundle is isolated and remains off at load."""
import importlib

import pytest


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_active_bundle_is_closed_and_default_off(backend):
    from tools.build_active_bundle import ACTIVE_MODULES, build
    from tools.build_combat_bundle import SHADOW_MODULES

    assert ACTIVE_MODULES == SHADOW_MODULES + (
        'kernel.lease', 'kernel.action_attempt', 'kernel.action_dispatch',
        'combat-intent.dispatch', 'adapters.eeex.action_dispatch',
    )
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=''; package.cpath=''")
    runtime.globals().bundle = runtime.execute(build())
    assert runtime.execute('''
        assert(bundle.new and bundle.eeex and bundle.listeners and bundle.manifest)
        assert(bundle.controller and bundle.inputs and bundle.snapshot)
        assert(bundle.candidates and bundle.decision)
        assert(bundle.activeDispatch and bundle.nativeDispatch)
        assert(bundle.dispatch==nil)
        assert(package.loaded['kernel.action_dispatch']==nil)
        assert(package.loaded['adapters.eeex.action_dispatch']==nil)
        local reads,submits=0,0
        local manager=bundle.activeDispatch.new({
            clock={now=function() return 0 end}, leaseTicks=3, attemptTicks=20,
            maxProposalAgeTicks=2,
            read=function() reads=reads+1; error('default-off read') end,
            submit=function() submits=submits+1; error('default-off submit') end,
        })
        assert(manager:inspect().enabled==false)
        local id={adapterId='B-/combat/lab-mage',key='mage/one',resource='B-XPMAG0.CRE'}
        local result,reason=manager:dispatch(id,{})
        assert(result==nil and reason=='runtime-disabled')
        assert(reads==0 and submits==0)
        return true
    ''')
