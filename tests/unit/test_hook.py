"""Host contract of the BCS handoff gate on both declared Lua backends."""
import importlib
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_hook_gate(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_hook.lua').read_text(encoding='utf-8')) == 23


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_lower_scripts(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_eeex_lower.lua').read_text(encoding='utf-8')) == 6


def test_lower_scripts_follow_the_hook_rule():
    """adapters/eeex/lower.lua judges lower scripts by HOOK-02's rule: its ordinary combat round is
    tools/hook_rule.py's COMBAT without the casts that use no spellbook entry, which it lists apart."""
    from tools import hook_rule
    text = (ROOT / 'adapters/eeex/lower.lua').read_text(encoding='utf-8')

    def names(label):
        body = re.search(r'^M\.' + label + r'=set\{(.*?)\}', text, re.M | re.S).group(1)
        return set(re.findall(r"'([A-Za-z]+)'", body))

    assert names('UNGATED') == hook_rule.UNGATED_CAST
    assert names('NO_DECREMENT') == hook_rule.NO_DECREMENT
    assert names('COMBAT') == hook_rule.COMBAT - hook_rule.UNGATED_CAST
    assert names('VARIABLES') == {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal'}
    assert names('VARIABLES') <= hook_rule.COMBAT
    assert names('VARIABLES') < names('NOTES') <= hook_rule.COMBAT


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_eeex_hook_boundary(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/kernel/test_eeex_hook.lua').read_text(encoding='utf-8')) == 10
