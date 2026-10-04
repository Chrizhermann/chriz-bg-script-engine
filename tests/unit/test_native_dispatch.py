import importlib
from pathlib import Path
import pytest
ROOT=Path(__file__).resolve().parents[2]
@pytest.mark.parametrize('backend',['lua51','luajit21'])
def test_native_dispatch(backend):
    runtime=importlib.import_module('lupa.'+backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path",ROOT.as_posix())
    assert runtime.execute((ROOT/'tests/unit/kernel/test_native_dispatch.lua').read_text())==2
