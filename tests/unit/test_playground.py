"""The Playground tool (tools/playground.py) without a game: which components a WeiDU.log holds, the profile it
writes, and the order it takes the engine and the spell mod out and puts them back in."""
from pathlib import Path

from tools import playground

LOG = """// Log of Currently Installed WeiDU Mods
~STRATAGEMS/SETUP-STRATAGEMS.TP2~ #0 #1000 // something
~SETUP-CHRIZ-BG-MAGIC.TP2~ #0 #0 // Chriz BG Magic: v0.1.0-dev
~BGSE/SETUP-BGSE.TP2~ #0 #0 // Chriz BG Script Engine
~bgse/setup-bgse.tp2~ #0 #10 // recorder
"""


def test_components_reads_a_mods_numbers_in_log_order():
    assert playground.components(LOG, playground.ENGINE_TP2) == [0, 10]
    assert playground.components(LOG, playground.MAGIC_TP2) == [0]
    assert playground.components('// nothing\n', playground.ENGINE_TP2) == []


def test_profile_sets_each_value_once_and_keeps_other_lines():
    before = ("SetPrivateProfileString('Game Options','Footsteps','1')\n"
              "SetPrivateProfileString('Game Options','Difficulty Level','2')\n"
              "SetPrivateProfileString('Game Options','Difficulty Level','3')\n")
    lines = playground.profile_lines(before)
    assert lines[0] == "SetPrivateProfileString('Game Options','Footsteps','1')"
    assert lines.count("SetPrivateProfileString('Game Options','Difficulty Level','5')") == 1
    assert not any("'Difficulty Level','2'" in line or "'Difficulty Level','3'" in line for line in lines)
    assert "SetPrivateProfileString('Game Options','Suppress Extra Difficulty Damage','1')" in lines
    assert "SetPrivateProfileString('Program Options','Cloud Saves Enabled','0')" in lines


def test_taking_out_goes_last_first_and_removes_the_files(tmp_path: Path, monkeypatch):
    game = tmp_path / 'game'
    (game / 'bgse').mkdir(parents=True)
    (game / 'chriz-bg-magic').mkdir()
    (game / playground.MAGIC_TP2).write_text('x', encoding='ascii')
    (game / 'WeiDU.log').write_text(LOG, encoding='ascii')
    calls = []

    def weidu(config, root, label, *arguments):
        assert (game / arguments[0]).exists() or arguments[0] == playground.ENGINE_TP2
        calls.append((label, arguments))

    monkeypatch.setattr(playground, 'weidu', weidu)
    playground.take_out({}, tmp_path)
    assert calls == [('engine-out', (playground.ENGINE_TP2, '--force-uninstall-list', '10', '0')),
                     ('magic-out', (playground.MAGIC_TP2, '--force-uninstall-list', '0'))]
    assert not (game / 'bgse').exists() and not (game / 'chriz-bg-magic').exists()
    assert not (game / playground.MAGIC_TP2).exists()


def test_a_game_without_them_takes_nothing_out(tmp_path: Path, monkeypatch):
    game = tmp_path / 'game'
    game.mkdir()
    (game / 'WeiDU.log').write_text('// nothing\n', encoding='ascii')
    monkeypatch.setattr(playground, 'weidu', lambda *a: (_ for _ in ()).throw(AssertionError('no WeiDU run')))
    playground.take_out({}, tmp_path)


def test_putting_in_goes_spell_mod_first_and_takes_the_recorder_when_there(tmp_path: Path, monkeypatch):
    game = tmp_path / 'game'
    game.mkdir()
    order = []

    def unpack(repo, ref, names, where):
        order.append(('unpack', ref))
        if 'bgse' in names:
            (where / 'bgse').mkdir()
            (where / 'bgse' / 'setup-bgse.tp2').write_text('BEGIN ~a~ DESIGNATED 0\nBEGIN ~b~ DESIGNATED 10\n', encoding='ascii')
        return ref

    monkeypatch.setattr(playground, 'unpack', unpack)
    monkeypatch.setattr(playground, 'weidu', lambda config, root, label, *a: order.append((label, a)))
    done = playground.put_in({'magic_repo': 'm', 'engine_repo': 'e'}, tmp_path, 'E1', 'M1')
    assert order == [('unpack', 'M1'), ('magic-in', (playground.MAGIC_TP2, '--force-install-list', '0')),
                     ('unpack', 'E1'), ('engine-in', (playground.ENGINE_TP2, '--force-install-list', '0', '10'))]
    assert done['magic'] == 'M1' and done['engine'] == 'E1'
