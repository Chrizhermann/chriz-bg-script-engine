"""Weapon attacks (combat-intent/weapons.lua) and the choice around them: conjured weapons, reach,
immunities and hits, attacks with the weapon in hand, spells that conjure one, weapon attacks
against spells, the round (a swing or a wait while the casting aura runs), jumps into the fight
with a teleport, the choice among the weapons carried and kiting; the weapons a creature carries
as the game's tables give them (combat-intent/arsenal.lua); backstabs, going behind an enemy and
hiding for a backstab (combat-intent/backstab.lua); on both declared Lua backends."""
import importlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_weapons(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_weapons.lua').read_text(encoding='utf-8')) == 17


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_arsenal(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_arsenal.lua').read_text(encoding='utf-8')) == 8


@pytest.mark.parametrize('backend', ['lua51', 'luajit21'])
def test_backstab(backend):
    runtime = importlib.import_module('lupa.' + backend).LuaRuntime()
    runtime.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    assert runtime.execute((ROOT / 'tests/unit/combat_intent/test_backstab.lua').read_text(encoding='utf-8')) == 7
