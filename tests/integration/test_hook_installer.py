"""Install the bgse component into a synthetic game with SCS-like scripts.

WeiDU's result must match tools/hook_rule.py block for block; scripts the rule leaves alone
must keep their exact bytes; reinstall and uninstall must be clean.
"""
import os
import shutil
import struct
import subprocess
from pathlib import Path

import pytest

from tools import build_runtime, hook_rule

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / 'tests/fixtures/hook'
HOOKED = {'B-HKMAG': ('mage', 7), 'B-HKPRI': ('priest', 2), 'B-HKRNG': ('fighter', 0),
          'B-HKMON': ('monster', 9)}
UNTOUCHED = ('B-HKNOA', 'B-HKOLD', 'B-HKCST', 'B-HKNON', 'B-HKVAN')

# Authored synthetic identifiers with the signature shapes the fixtures use.
TRIGGER = """IDS V1.0
0x0002 Heard(O:Object*,I:ID*)
0x4001 Global(S:Name*,S:Area*,I:Value*)
0x4002 GlobalGT(S:Name*,S:Area*,I:Value*)
0x4003 GlobalTimerExpired(S:Name*,S:Area*)
0x4004 GlobalTimerNotExpired(S:Name*,S:Area*)
0x4005 See(O:Object*)
0x4006 HaveSpell(I:Spell*Spell)
0x4007 HaveSpellRES(S:Spell*)
0x4008 HasItem(S:ResRef*,O:Object*)
0x4009 False()
0x400A True()
0x400B ActionListEmpty()
0x400C CheckStatGT(O:Object*,I:Value*,I:StatNum*Stats)
0x400D INI(S:Name*,I:Number*)
0x400E HPPercentLT(O:Object*,I:Hit Points*)
0x400F Die()
0x4010 Range(O:Object*,I:Range*)
0x4089 OR(I:OrCount*)
"""
ACTION = """IDS V1.0
0 NoAction()
1 SetGlobal(S:Name*,S:Area*,I:Value*)
2 SetGlobalTimer(S:Name*,S:Area*,I:Time*)
3 IncrementGlobal(S:Name*,S:Area*,I:Value*)
4 Continue()
5 Spell(O:Target*,I:Spell*Spell)
6 ForceSpell(O:Target,I:Spell*Spell)
7 ForceSpellRES(S:RES*,O:Target)
8 ReallyForceSpellRES(S:RES*,O:Target)
9 RemoveSpell(I:Spell*Spell)
10 GiveItemCreate(S:ResRef*,O:Object*,I:Usage1*,I:Usage2*,I:Usage3*)
11 DestroyItem(S:ResRef*)
12 ApplySpellRES(S:RES*,O:Target)
13 Turn()
14 RandomWalkContinuous()
15 RunAwayFromNoLeaveArea(O:Creature*,I:Time*)
16 ClearActions(O:Object*)
17 AttackReevaluate(O:Target*,I:ReevaluationPeriod*)
18 UseItem(S:Object*,O:Target*)
19 CreateCreatureObject(S:ResRef*,O:Object*,I:Usage1*,I:Usage2*,I:Usage3*)
20 DestroySelf()
21 Enemy()
22 SpellNoDec(O:Target*,I:Spell*Spell)
23 SpellNoDecRES(S:RES*,O:Target*)
24 ApplySpell(O:Target,I:Spell*Spell)
25 MoveToObject(O:Object*)
"""
IDS = {
    'OBJECT': 'IDS V1.0\n0 Nothing\n1 Myself\n12 NearestEnemyOf\n18 LastSeenBy\n20 LastHeardBy\n21 Player1\n22 Player2\n',
    'EA': 'IDS V1.0\n0 ANYONE\n2 PC\n255 ENEMY\n',
    'GENERAL': 'IDS V1.0\n0 ANYONE\n',
    'RACE': 'IDS V1.0\n0 ANYONE\n',
    'CLASS': 'IDS V1.0\n0 ANYONE\n',
    'SPECIFIC': 'IDS V1.0\n0 ANYONE\n',
    'GENDER': 'IDS V1.0\n0 ANYONE\n',
    'ALIGN': 'IDS V1.0\n0 ANYONE\n',
    'SPELL': 'IDS V1.0\n2101 WIZARD_MAGIC_MISSILE\n2102 WIZARD_MIRROR_IMAGE\n3101 DEMILICH_TRAP_SOUL\n',
    'STATS': 'IDS V1.0\n18 RESISTMAGIC\n200 WIZARD_IMPROVED_ALACRITY\n',
}


def _weidu() -> Path:
    binary = Path(os.environ.get('BGSE_WEIDU', ROOT / '.work/task6/effective-pilot-20260927/weidu.exe'))
    assert binary.is_file(), f'WeiDU binary missing: {binary} (set BGSE_WEIDU)'
    return binary


def _fake_game(root: Path, eeex: bool = True, lua_trigger: bool = True) -> None:
    (root / 'data').mkdir(parents=True)
    (root / 'override').mkdir()
    (root / 'lang/en_us').mkdir(parents=True)
    trigger = TRIGGER + '0x410E EEex_LuaTrigger(S:Chunk*)\n'
    action = ACTION + '472 EEex_LuaAction(S:Chunk*)\n'
    resources = [('TRIGGER', trigger), ('ACTION', action)] + sorted(IDS.items())
    table_offset = 0x14
    payload_offset = table_offset + len(resources) * 0x10
    payload, entries = bytearray(), bytearray()
    for index, (_, text) in enumerate(resources):
        data = text.encode('ascii')
        entries += struct.pack('<IIIHH', index, payload_offset + len(payload), len(data), 1008, 0)
        payload += data
    bif = b'BIFFV1  ' + struct.pack('<III', len(resources), 0, table_offset) + entries + payload
    (root / 'data/bgse-test.bif').write_bytes(bif)
    bif_name = b'data\\bgse-test.bif\x00'
    bif_offset, res_offset = 0x18, 0x18 + 0x0C
    name_offset = res_offset + len(resources) * 0x0E
    key = b'KEY V1  ' + struct.pack('<IIII', 1, len(resources), bif_offset, res_offset)
    key += struct.pack('<IIHH', len(bif), name_offset, len(bif_name), 0)
    for index, (name, _) in enumerate(resources):
        key += struct.pack('<8sHI', name.encode('ascii').ljust(8, b'\x00'), 1008, index)
    (root / 'chitin.key').write_bytes(key + bif_name)
    tlk = b'TLK V1  ' + struct.pack('<HII', 0, 1, 0x2C) + bytes(0x1A)
    (root / 'dialog.tlk').write_bytes(tlk)
    (root / 'lang/en_us/dialog.tlk').write_bytes(tlk)
    if eeex:
        (root / 'override/M___EEex.lua').write_text('-- synthetic EEex marker\n', encoding='ascii')
    (root / 'fixture').mkdir()
    for path in FIXTURES.glob('*.baf'):
        shutil.copy(path, root / 'fixture' / path.name)
    compile_list = '\n'.join(f'COMPILE ~fixture/{p.name}~' for p in sorted(FIXTURES.glob('*.baf')))
    (root / 'fixture/fixture.tp2').write_text(
        'BACKUP ~fixture/backup~\nAUTHOR ~BGSE test~\nBEGIN ~synthetic SCS-like scripts~\n' + compile_list + '\n',
        encoding='ascii')
    _run(root, 'fixture/fixture.tp2', '--force-install-list', '0')
    if not lua_trigger:
        # A game whose TRIGGER.IDS lacks the EEex symbol (the fixtures were compiled before).
        (root / 'override/TRIGGER.IDS').write_text(TRIGGER, encoding='ascii')
    shutil.copytree(ROOT / 'bgse', root / 'bgse', ignore=shutil.ignore_patterns('backup'))


def _invoke(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    cmd = [str(_weidu()), *args, '--language', '0', '--use-lang', 'en_US',
           '--no-exit-pause', '--quick-log', '--noautoupdate']
    return subprocess.run(cmd, cwd=root, text=True, encoding='utf-8', errors='replace',
                          stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=120, check=False)


def _run(root: Path, *args: str) -> str:
    result = _invoke(root, *args)
    assert result.returncode == 0, result.stdout
    return result.stdout


def _install(root: Path, *selection: str) -> str:
    return _run(root, 'bgse/setup-bgse.tp2', *selection)


def _snapshot(root: Path) -> dict[str, bytes]:
    return {p.relative_to(root).as_posix().casefold(): p.read_bytes()
            for p in (root / 'override').rglob('*') if p.is_file()}


def _decompile(root: Path, names) -> dict[str, str]:
    out = root / 'decompiled'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir()
    result = subprocess.run([str(_weidu()), '--game', str(root), '--noautoupdate', '--no-exit-pause',
                             '--out', str(out), *[str(root / 'override' / f'{n}.bcs') for n in names]],
                            cwd=root, text=True, encoding='utf-8', errors='replace',
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=120, check=False)
    assert result.returncode == 0, result.stdout
    return {p.stem.upper(): p.read_text(encoding='latin-1').replace('\r', '') for p in out.glob('*.baf')}


def test_installer_matches_reference_and_is_reversible(tmp_path: Path) -> None:
    _fake_game(tmp_path)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, HOOKED)

    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    assert ('BGSE hook: 4 SCS scripts hooked, 18 SCS blocks guarded, 3 SCS cloud blocks yield to the engine, '
            '3 left as they are.') in output, output
    for name, reason in (('B-HKNOA', 'no-anchor'), ('B-HKOLD', 'already-hooked'), ('B-HKCST', 'no-castspell')):
        assert f'left {name} as it is ({reason})'.casefold() in output.casefold(), output
    installed = _snapshot(tmp_path)
    assert installed['override/m_bgse.lua'] == build_runtime.build().encode('utf-8')
    for name in UNTOUCHED:
        assert installed[f'override/{name.casefold()}.bcs'] == before[f'override/{name.casefold()}.bcs'], name
    assert set(installed) - set(before) == {'override/m_bgse.lua', 'override/m_bgsehk.lua'}
    # The registry lists exactly the hooked scripts, in lower case, with their family.
    registry = installed['override/m_bgsehk.lua'].decode('ascii')
    entries = sorted(line.strip() for line in registry.splitlines() if line.strip().startswith("['"))
    assert entries == sorted(f"['{n.lower()}']='{f}'," for n, (f, _) in HOOKED.items()), registry
    assert 'BGSE_HOOKED={' in registry

    hooked = _decompile(tmp_path, HOOKED)
    for name, (family, copies) in HOOKED.items():
        expected, reason, got_family, got_copies = hook_rule.patch(originals[name], name)
        assert (reason, got_family, got_copies) == ('hooked', family, copies)
        assert hooked[name] == expected, name
    # The mage's cloud escape and stand-still take the condition last, the ranged fighter's escape
    # (whose triggers end in an OR group that lacks a member) first; the fighter's escape below the
    # hook stays.
    for name, count in (('B-HKMAG', 2), ('B-HKRNG', 1), ('B-HKPRI', 0), ('B-HKMON', 0)):
        assert hooked[name].count(hook_rule.zones_guard(HOOKED[name][0], name.lower())) == count, name

    _install(tmp_path, '--force-uninstall-list', '0', '--force-install-list', '0')
    assert _snapshot(tmp_path) == installed

    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


@pytest.mark.parametrize('missing', ['eeex', 'lua_trigger'])
def test_without_eeex_nothing_is_installed(tmp_path: Path, missing: str) -> None:
    _fake_game(tmp_path, eeex=missing != 'eeex', lua_trigger=missing != 'lua_trigger')
    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SKIPPING' in output, output
    assert _snapshot(tmp_path) == before
