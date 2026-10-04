"""The lab shadow bundle has no native dispatcher or global require hook."""
import importlib
import pytest

@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_combat_bundle(backend):
    from tools.build_combat_bundle import build
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=''; package.cpath=''")
    module = runtime.execute(build())
    assert module.controller.new is not None and module.inputs.sample is not None
    assert module.dispatch is None
    assert runtime.eval("package.loaded['combat-intent.controller']") is None
