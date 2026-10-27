"""Install the bgse component into a synthetic game with SCS-like scripts.

WeiDU's result must match tools/hook_rule.py block for block; scripts the rule leaves alone
must keep their exact bytes; reinstall and uninstall must be clean.
"""
import os
import shutil
import struct
import subprocess
from collections import Counter
from pathlib import Path

import pytest

from tools import build_runtime, hook_rule
from tools.ie_resources import parse_spl

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / 'tests/fixtures/hook'
HOOKED = {'B-HKMAG': ('mage', 7), 'B-HKPRI': ('priest', 2), 'B-HKRNG': ('fighter', 0),
          'B-HKMON': ('monster', 9), 'B-HKTHF': ('fighter', 3), 'B-HKFEN': ('monster', 0)}
UNTOUCHED = ('B-HKNOA', 'B-HKOLD', 'B-HKCST', 'B-HKNON', 'B-HKVAN')
# The fake game's spells that move their caster: the monster's chase and jump spells, and a
# creature's own innate teleport.
TELEPORTS = frozenset({'B-HKFIT', 'INNATE_FIEND_TELEPORT', 'B-HKBLK'})
# The fake game's spells that make their target invisible, as the scripts name them: the thief's
# b-hksil, SPWI206 by number (SPELL.IDS lacks it) and Improved Invisibility by name; the fiend's
# wizard invisibility b-hkinv and its innate ones b-hkshd (improved, with a recharge of its own) and
# b-hketh. The innate ones as the scripts name them, the resrefs of the spells they name, and the
# game's timer names.
HIDES = {'B-HKSIL': 'plain', '2206': 'plain', 'WIZARD_IMPROVED_INVISIBILITY': 'improved', 'B-HKINV': 'plain',
         'B-HKSHD': 'improved', 'B-HKETH': 'plain'}
INNATES = frozenset({'B-HKSIL', 'B-HKSHD', 'B-HKETH'})
RESREFS = {'2206': 'SPWI206', 'WIZARD_IMPROVED_INVISIBILITY': 'SPWI405', 'WIZARD_BLUR': 'SPWI201'}
GTIMES = {'ONE_ROUND': 6, 'TWO_ROUNDS': 12}
# Creatures: one whose script teleports by script and that has no teleport of its own (the innate
# goes to it), one that has its own, and one whose scripts do not teleport.
CREATURES = {'B-HKFND': (['', 'B-HKMON', '', '', ''], ['B-HKPOW']),
             'B-HKFN2': (['B-HKMON', '', '', '', ''], ['B-HKBLK']),
             'B-HKMGC': (['B-HKMAG', '', '', '', ''], [])}
# Thieves (scripts, class, three class levels, kit, Hide in Shadows, Move Silently, script name): ones
# whose script makes them invisible for free (a thief, an assassin with more Hide in Shadows than its
# level gives, a fighter/thief by its thief level and a shadowdancer), and ones that keep their skills
# (a joinable NPC, a fighter and a thief whose scripts do not do that).
THIEVES = {'B-HKTH1': (['', 'B-HKTHF', '', '', ''], 4, (9, 0, 0), 0x4000, 10, 50, 'HKTH1'),
           'B-HKTH2': (['B-HKTHF', '', '', '', ''], 4, (9, 0, 0), 0x400A, 75, 0, 'HKTH2'),
           'B-HKTH3': (['', '', 'B-HKTHF', '', ''], 9, (10, 7, 0), 0, 5, 5, ''),
           'B-HKTH4': (['', 'B-HKTHF', '', '', ''], 4, (5, 0, 0), 0x4021, 0, 0, 'HKTH4'),
           'B-HKNPC': (['', 'B-HKTHF', '', '', ''], 4, (9, 0, 0), 0, 10, 10, 'B-HKNPC'),
           'B-HKWAR': (['', 'B-HKTHF', '', '', ''], 2, (9, 0, 0), 0, 0, 0, 'HKWAR'),
           'B-HKTHN': (['', 'B-HKMAG', '', '', ''], 4, (9, 0, 0), 0, 0, 0, 'HKTHN')}
# Fiends whose script makes them invisible for free (scripts, memorized innates, class, three class
# levels, script name): one that gets every gift, one with an innate Improved Invisibility of its own, a
# thief and a joinable NPC.
FIENDS = {'B-HKFE1': (['', '', 'B-HKFEN', '', ''], [], 0, (0, 0, 0), 'HKFE1'),
          'B-HKFE2': (['B-HKFEN', '', '', '', ''], ['B-HKSHD'], 0, (0, 0, 0), 'HKFE2'),
          'B-HKFE3': (['', 'B-HKFEN', '', '', ''], [], 4, (7, 0, 0), 'HKFE3'),
          'B-HKFE4': (['', '', 'B-HKFEN', '', ''], [], 0, (0, 0, 0), 'B-HKFE4')}
PARTY = frozenset({'B-HKNPC', 'B-HKFE4'})
# The fake game's thief skill tables, as hook_rule.hide_skill reads them: THIEFSKL.2DA names its
# columns in another order than the game's, KITLIST.2DA's first row lacks its last columns.
POINTS = {'THIEF': (40, 25), 'ASSASIN': (40, 10), 'SHADOWDANCER': (30, 20), 'FIGHTER_THIEF': (40, 25)}
KITS = {0x400A: 'ASSASIN', 0x4021: 'SHADOWDANCER'}
TABLES = {
    'THIEFSKL': ('2DA V1.0\n0\n               LEVEL_POINTS   START_POINTS\nTHIEF          25             40\n'
                 'ASSASIN        10             40\nSHADOWDANCER   20             30\nFIGHTER_THIEF  25             40\n'),
    'KITLIST': ('2DA V1.0\n*\n     ROWNAME       LOWER  MIXED  HELP  ABILITIES  PROFICIENCY  UNUSABLE  CLASS  KITIDS\n'
                '0    RESERVE       *      *      *     *          *            *\n'
                '10   ASSASIN       1      2      3     CLABTH02   *            0         4      0x0000400A\n'
                '33   SHADOWDANCER  1      2      3     CLABTH04   *            0         4      0x00004021\n'),
    'PDIALOG': ('2DA V1.0\n***\n         POST_DIALOG_FILE  JOIN_DIALOG_FILE\nB-HKNPC  B-HKNPCP          B-HKNPCJ\n'
                'B-HKFE4  B-HKFE4P          B-HKFE4J\n'),
}

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
0x4011 Detect(O:Object*)
0x4012 OpenState(O:Object*,I:Open*Boolean)
0x4013 Allegiance(O:Object*,I:Allegiance*EA)
0x4014 GlobalLT(S:Name*,S:Area*,I:Value*)
0x4015 CheckSpellState(O:Object*,I:State*SplState)
0x4089 OR(I:OrCount*)
"""
ACTION = """IDS V1.0
0 NoAction()
1 SetGlobal(S:Name*,S:Area*,I:Value*)
2 SetGlobalTimer(S:Name*,S:Area*,I:Time*GTimes)
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
26 SetInterrupt(I:State*Boolean)
27 OpenDoor(O:Object*)
28 ReallyForceSpell(O:Target*,I:Spell*Spell)
"""
IDS = {
    'OBJECT': ('IDS V1.0\n0 Nothing\n1 Myself\n12 NearestEnemyOf\n18 LastSeenBy\n20 LastHeardBy\n21 Player1\n22 Player2\n'
               '40 NearestDoor\n'),
    'EA': 'IDS V1.0\n0 ANYONE\n2 PC\n30 GOODCUTOFF\n255 ENEMY\n',
    'GENERAL': 'IDS V1.0\n0 ANYONE\n',
    'RACE': 'IDS V1.0\n0 ANYONE\n',
    'CLASS': 'IDS V1.0\n0 ANYONE\n',
    'SPECIFIC': 'IDS V1.0\n0 ANYONE\n',
    'GENDER': 'IDS V1.0\n0 ANYONE\n',
    'ALIGN': 'IDS V1.0\n0 ANYONE\n',
    'SPELL': ('IDS V1.0\n1308 CLERIC_INVISIBILITY_PURGE\n2101 WIZARD_MAGIC_MISSILE\n2102 WIZARD_MIRROR_IMAGE\n'
              '2201 WIZARD_BLUR\n2405 WIZARD_IMPROVED_INVISIBILITY\n2420 WIZARD_ORACLE\n2525 WIZARD_DIMENSION_DOOR\n'
              '3101 DEMILICH_TRAP_SOUL\n3159 INNATE_FIEND_TELEPORT\n'),
    'STATS': 'IDS V1.0\n18 RESISTMAGIC\n200 WIZARD_IMPROVED_ALACRITY\n',
    'BOOLEAN': 'IDS V1.0\n0 FALSE\n1 TRUE\n',
    'SPLSTATE': 'IDS V1.0\n12 CONTINGENCY_TRIGGERED\n',
}


def _weidu() -> Path:
    binary = Path(os.environ.get('BGSE_WEIDU', ROOT / '.work/task6/effective-pilot-20260927/weidu.exe'))
    assert binary.is_file(), f'WeiDU binary missing: {binary} (set BGSE_WEIDU)'
    return binary


def _tlk(strings) -> bytes:
    """A TLK V1 file with these strings, from index 0."""
    entries, data = bytearray(), bytearray()
    for text in strings:
        raw = text.encode('ascii')
        entries += struct.pack('<H8sIIII', 1 if raw else 0, b'', 0, 0, len(data), len(raw))
        data += raw
    return b'TLK V1  ' + struct.pack('<HII', 0, len(strings), 0x12 + len(entries)) + bytes(entries) + bytes(data)


def _tlk_text(data: bytes, index: int) -> str:
    count, start = struct.unpack_from('<II', data, 0x0A)
    assert 0 <= index < count, (index, count)
    offset, length = struct.unpack_from('<II', data, 0x12 + 0x1A * index + 0x12)
    return data[start + offset:start + offset + length].decode('ascii')


def _spl(spell_type: int, name: int = 0xFFFFFFFF, description: int = 0xFFFFFFFF, opcode: int = 124, target: int = 1,
         parameter2: int = 0, speed: int = 1, extra=()) -> bytes:
    """A spell with one ability aimed at a point that moves its caster there (opcode 124 on the
    caster): an innate (type 4) or a wizard spell (type 1) such as SCS's scripted teleport. Another
    opcode, target and parameter 2 make another spell, such as an invisibility (opcode 20); its casting
    speed, and more effects after that one ((opcode, target, parameter 2, timing, duration, resource)
    each)."""
    header = bytearray(0x72)
    header[:8] = b'SPL V1  '
    struct.pack_into('<II', header, 0x08, name, 0xFFFFFFFF)
    struct.pack_into('<H', header, 0x1C, spell_type)
    struct.pack_into('<I', header, 0x34, 1 if spell_type == 4 else 4)
    struct.pack_into('<I', header, 0x50, description)
    struct.pack_into('<IHIHH', header, 0x64, 0x72, 1, 0x9A, 0, 0)
    ability = bytearray(0x28)
    ability[0] = 1
    struct.pack_into('<H', ability, 0x02, 4 if spell_type == 4 else 2)
    ability[0x0C] = 4
    struct.pack_into('<HHH', ability, 0x0E, 200, 1, speed)
    struct.pack_into('<HH', ability, 0x1E, 1 + len(extra), 0)
    struct.pack_into('<H', ability, 0x26, 1)
    effects = [(opcode, target, parameter2, 1, 0, '')] + list(extra)
    return bytes(header + ability) + b''.join(
        struct.pack('<HBBiIBBIBB8siiIiI', op, aim, 0, 0, p2, timing, 0, duration, 100, 0, res.encode('ascii'), 0, 0, 0, 0, 0)
        for op, aim, p2, timing, duration, res in effects)


def _cre(scripts, memorized, cls=0, levels=(0, 0, 0), kit=0, hide=0, silent=0, name='') -> bytes:
    """A creature with these scripts (override, class, race, general and default slot) and these
    innate spells known and memorized, no items or effects, and the memorization levels a real
    creature has (seven priest, nine wizard, one innate); with its class, three class levels, kit (the
    high word, as KIT.IDS numbers it), Hide in Shadows, Move Silently and script name."""
    head = bytearray(0x2D4)
    head[:8] = b'CRE V1.0'
    struct.pack_into('<II', head, 0x08, 0xFFFFFFFF, 0xFFFFFFFF)
    for i, script in enumerate(scripts):
        head[0x248 + 8 * i:0x250 + 8 * i] = script.encode('ascii').ljust(8, b'\0')
    head[0x45], head[0x68], head[0x273] = hide, silent, cls
    head[0x234:0x237] = bytes(levels)
    struct.pack_into('<HH', head, 0x244, 0, kit)
    head[0x280:0x2A0] = name.encode('ascii').ljust(32, b'\0')
    known = b''.join(s.encode('ascii').ljust(8, b'\0') + struct.pack('<HH', 0, 2) for s in memorized)
    levels = [(level, 0) for level in range(7)] + [(level, 1) for level in range(9)] + [(0, 2)]
    info = b''.join(struct.pack('<HHHHII', level, len(memorized) if kind == 2 else 0,
                                len(memorized) if kind == 2 else 0, kind, 0, len(memorized) if kind == 2 else 0)
                    for level, kind in levels)
    spells = b''.join(s.encode('ascii').ljust(8, b'\0') + struct.pack('<I', 1) for s in memorized)
    slots = struct.pack('<40H', *([0xFFFF] * 38 + [0, 0]))
    at = 0x2D4
    struct.pack_into('<II', head, 0x2A0, at, len(memorized))
    struct.pack_into('<II', head, 0x2A8, at + len(known), len(levels))
    struct.pack_into('<II', head, 0x2B0, at + len(known) + len(info), len(memorized))
    end = at + len(known) + len(info) + len(spells)
    struct.pack_into('<III', head, 0x2B8, end, end + len(slots), 0)
    struct.pack_into('<II', head, 0x2C4, end + len(slots), 0)
    return bytes(head) + known + info + spells + slots


def _spells(data: bytes, table: int):
    """(resref, two words) of a creature's known (0x2A0) or memorized (0x2B0) spells."""
    offset, count = struct.unpack_from('<II', data, table)
    return [(data[offset + 12 * i:offset + 12 * i + 8].rstrip(b'\0').decode('ascii').upper(),
             struct.unpack_from('<HH', data, offset + 12 * i + 8)) for i in range(count)]


def _fake_game(root: Path, eeex: bool = True, lua_trigger: bool = True, fiend_teleport: bool = True,
               times=None) -> None:
    (root / 'data').mkdir(parents=True)
    (root / 'override').mkdir()
    (root / 'lang/en_us').mkdir(parents=True)
    trigger = TRIGGER + '0x410E EEex_LuaTrigger(S:Chunk*)\n'
    action = ACTION + '472 EEex_LuaAction(S:Chunk*)\n'
    gtimes = 'IDS V1.0\n' + ''.join(f'{seconds} {name}\n' for name, seconds in (times or GTIMES).items())
    resources = [('TRIGGER', trigger), ('ACTION', action)] + sorted({**IDS, 'GTIMES': gtimes}.items())
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
    tlk = _tlk(['', 'Its description', 'Fiendish Teleport'])
    (root / 'dialog.tlk').write_bytes(tlk)
    (root / 'lang/en_us/dialog.tlk').write_bytes(tlk)
    if eeex:
        (root / 'override/M___EEex.lua').write_text('-- synthetic EEex marker\n', encoding='ascii')
    # The chase's scripted teleport (a wizard spell, as SCS's dw#fitel), a creature's own innate
    # teleport and, in a game that has it, the game's fiend teleport with its own name.
    (root / 'override/B-HKFIT.SPL').write_bytes(_spl(1))
    (root / 'override/B-HKBLK.SPL').write_bytes(_spl(4))
    if fiend_teleport:
        (root / 'override/SPIN159.SPL').write_bytes(_spl(4, name=2, description=1))
    # The thief's free invisibility on itself, the game's Invisibility on its target and Improved
    # Invisibility (parameter 2 is 1, slower than a gift may be), and the game's Blur, which ends an
    # earlier Blur (opcode 321 names itself). The fiend's wizard invisibility on itself, and its innate
    # ones: an Improved Invisibility that recharges by itself (172 and a delayed 171 name it) and a plain
    # one.
    (root / 'override/B-HKSIL.SPL').write_bytes(_spl(4, opcode=20, target=1))
    (root / 'override/SPWI206.SPL').write_bytes(_spl(1, opcode=20, target=2, speed=3))
    (root / 'override/SPWI405.SPL').write_bytes(_spl(1, opcode=20, target=2, parameter2=1, speed=4))
    (root / 'override/SPWI201.SPL').write_bytes(_spl(1, opcode=65, target=2, extra=[(321, 2, 0, 1, 0, 'SPWI201')]))
    (root / 'override/B-HKINV.SPL').write_bytes(_spl(1, opcode=20, target=1))
    (root / 'override/B-HKSHD.SPL').write_bytes(_spl(4, opcode=20, target=1, parameter2=1, extra=[
        (172, 1, 0, 1, 0, 'B-HKSHD'), (171, 1, 0, 4, 30, 'B-HKSHD')]))
    (root / 'override/B-HKETH.SPL').write_bytes(_spl(4, opcode=20, target=1))
    for name, (scripts, memorized) in CREATURES.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, memorized))
    for name, (scripts, cls, levels, kit, hide, silent, script_name) in THIEVES.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, [], cls, levels, kit, hide, silent, script_name))
    for name, (scripts, memorized, cls, levels, script_name) in FIENDS.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, memorized, cls, levels, name=script_name))
    for name, text in TABLES.items():
        (root / f'override/{name}.2DA').write_text(text, encoding='ascii')
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


def _creatures():
    """Every fake creature: (scripts, memorized innates, class, script name)."""
    out = {name: (scripts, memorized, 0, '') for name, (scripts, memorized) in CREATURES.items()}
    out.update({name: (scripts, [], cls, script_name) for name, (scripts, cls, *_, script_name) in THIEVES.items()})
    out.update({name: (scripts, memorized, cls, script_name)
                for name, (scripts, memorized, cls, _, script_name) in FIENDS.items()})
    return out


def _expected_gifts(originals, times=None):
    """What each creature gets for its scripts' free invisibility, as tools/hook_rule.py says: each
    grant's resref and how often (the most of two gifts of one name)."""
    gifts_of = {name.lower(): hook_rule.script_gifts(text, HIDES, INNATES, times or GTIMES)
                for name, text in originals.items()}
    out = {}
    for name, (scripts, memorized, cls, script_name) in _creatures().items():
        own = {HIDES[spell] for spell in memorized if spell in INNATES and spell in HIDES}
        grants = {}
        for spell, _, charges, recharge in hook_rule.creature_gifts(scripts, gifts_of, cls in hook_rule.THIEF_LEVEL,
                                                                    own, script_name, PARTY):
            resref = RESREFS.get(spell, spell)
            grant = hook_rule.grant_resref(resref, resref in INNATES, recharge)
            grants[grant] = max(grants.get(grant, 0), charges or 1)
        out[name] = grants
    return out


def _check_gifts(before, installed, expected) -> None:
    """Each creature knows its grants as innate abilities and has them memorized as often as expected,
    besides the innate teleport and what it had; one that gets nothing else is left as it was."""
    for name, grants in expected.items():
        old, new = before[f'override/{name.casefold()}.cre'], installed[f'override/{name.casefold()}.cre']
        added = Counter(s for s, _ in _spells(new, 0x2B0)) - Counter(s for s, _ in _spells(old, 0x2B0))
        assert added == Counter(grants) + Counter(['BGSETELE'] if name == 'B-HKFND' else []), name
        for grant in grants:
            assert (grant, (0, 2)) in _spells(new, 0x2A0), (name, grant)
        if not added and new[0x45] == old[0x45] and new[0x68] == old[0x68]:
            assert new == old, name


def _gift_spell(installed, name):
    """A gift's spell: its type, level, ability location and speed, and its effects (opcode, timing,
    duration, resource)."""
    spell = parse_spl(installed[f'override/{name.casefold()}.spl'], name)
    [ability] = spell['abilities']
    return ((spell['spellType'], spell['level'], ability['location'], ability['speed']),
            [(e['opcode'], e['timing'], e['duration'], e['res']) for e in ability['effects']])


def test_installer_matches_reference_and_is_reversible(tmp_path: Path) -> None:
    _fake_game(tmp_path)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, HOOKED)

    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    assert ('BGSE hook: 6 SCS scripts hooked, 21 SCS blocks guarded, 5 SCS cloud blocks yield to the engine, '
            "14 SCS hunting blocks yield to the engine's search, 3 left as they are.") in output, output
    assert ("BGSE teleport: 1 SCS jumps into the fight yield to the creatures' own teleports, 1 creatures that "
            'teleport only by script got the innate teleport BGSETELE.') in output, output
    assert ('BGSE hide: 9 SCS blocks of free invisibility yield where the engine hides the creature its own way, '
            '5 thieves got hide skills for their level.') in output, output
    assert ('BGSE gift: 8 creatures SCS makes invisible for free got real innate abilities for it, 7 innate copies '
            'of spells made.') in output, output
    for name, reason in (('B-HKNOA', 'no-anchor'), ('B-HKOLD', 'already-hooked'), ('B-HKCST', 'no-castspell')):
        assert f'left {name} as it is ({reason})'.casefold() in output.casefold(), output
    installed = _snapshot(tmp_path)
    assert installed['override/m_bgse.lua'] == build_runtime.build().encode('utf-8')
    for name in UNTOUCHED:
        assert installed[f'override/{name.casefold()}.bcs'] == before[f'override/{name.casefold()}.bcs'], name
    copies = {'BGW20606', 'BGW20600', 'BGW405RS', 'BGW40500', 'BGW201RS', 'BGB-HK0C', 'BGB-HK0U'}
    assert set(installed) - set(before) == {'override/m_bgse.lua', 'override/m_bgsehk.lua', 'override/bgsetele.spl'} | {
        f'override/{copy.casefold()}.spl' for copy in copies}
    # The registry lists exactly the hooked scripts, in lower case, with their family.
    registry = installed['override/m_bgsehk.lua'].decode('ascii')
    entries = sorted(line.strip() for line in registry.splitlines() if line.strip().startswith("['"))
    assert entries == sorted(f"['{n.lower()}']='{f}'," for n, (f, _) in HOOKED.items()), registry
    assert 'BGSE_HOOKED={' in registry
    # The creature that teleports only by script got the innate teleport, known and memorized;
    # the one with a teleport of its own and the one whose scripts do not teleport did not.
    fiend = installed['override/b-hkfnd.cre']
    assert ('BGSETELE', (0, 2)) in _spells(fiend, 0x2A0)
    assert sorted(s for s, _ in _spells(fiend, 0x2B0)) == ['B-HKPOW', 'BGSETELE']
    assert ('BGSETELE', (1, 0)) in _spells(fiend, 0x2B0)
    info, levels = struct.unpack_from('<II', fiend, 0x2A8)
    innate = [struct.unpack_from('<HHHHII', fiend, info + 16 * i) for i in range(levels)]
    assert [(e[0], e[4], e[5]) for e in innate if e[3] == 2] == [(0, 0, 2)]
    for name in ('B-HKFN2', 'B-HKMGC'):
        assert installed[f'override/{name.casefold()}.cre'] == before[f'override/{name.casefold()}.cre'], name
    _check_teleport(installed['override/bgsetele.spl'], 'Fiendish Teleport', tmp_path)
    # The thieves SCS makes invisible for free got the hide skills of their kit or class and thief
    # level, or kept higher ones; nothing else in their headers changed. The joinable NPC, the fighter
    # and the thief whose scripts do not do that kept theirs.
    thieves = {name: (scripts, cls, levels, kit, hide, silent, script_name)
               for name, (scripts, cls, levels, kit, hide, silent, script_name) in THIEVES.items()}
    thieves.update({name: (scripts, cls, levels, 0, 0, 0, script_name)
                    for name, (scripts, _, cls, levels, script_name) in FIENDS.items()})
    for name, (scripts, cls, levels, kit, hide, silent, script_name) in thieves.items():
        old, new = before[f'override/{name.casefold()}.cre'], installed[f'override/{name.casefold()}.cre']
        skill = hook_rule.hide_skill(cls, levels, kit, POINTS, KITS)
        if hook_rule.raises_skills(scripts, {'b-hkthf', 'b-hkfen'}, script_name, PARTY) and skill is not None:
            assert (new[0x45], new[0x68]) == (max(hide, skill), max(silent, skill)), name
            assert new[:0x45] + new[0x46:0x68] + new[0x69:0x2A0] == old[:0x45] + old[0x46:0x68] + old[0x69:0x2A0], name
        else:
            assert (new[0x45], new[0x68]) == (old[0x45], old[0x68]), name
    assert [installed[f'override/b-hkth{i}.cre'][0x45] for i in range(1, 5)] == [120, 75, 95, 55]
    assert [installed[f'override/b-hkth{i}.cre'][0x68] for i in range(1, 5)] == [120, 60, 95, 55]
    assert installed['override/b-hkfe3.cre'][0x45] == 95
    # Every creature SCS makes invisible for free got real innate abilities for it, as tools/hook_rule.py
    # says: the fiend each of its script's, one with an innate Improved Invisibility of its own only the
    # plain ones and the Blur, the thieves no plain one, the joinable NPC nothing.
    expected = _expected_gifts(originals)
    assert expected['B-HKFE1'] == {'BGW20606': 1, 'BGW405RS': 1, 'BGW201RS': 1, 'BGB-HK0C': 1, 'B-HKETH': 3,
                                   'BGW20600': 1}
    assert expected['B-HKFE2'] == {'BGW20606': 1, 'BGW201RS': 1, 'B-HKETH': 3, 'BGW20600': 1}
    assert expected['B-HKFE3'] == {'BGW405RS': 1, 'BGW201RS': 1, 'BGB-HK0C': 1}
    assert expected['B-HKWAR'] == {'B-HKSIL': 1, 'BGW20600': 1, 'BGB-HK0U': 1, 'BGW40500': 1}
    assert all(expected[f'B-HKTH{i}'] == {'BGW40500': 1} for i in range(1, 5))
    assert not any(expected[name] for name in ('B-HKFE4', 'B-HKNPC', 'B-HKTHN', 'B-HKFND', 'B-HKFN2', 'B-HKMGC'))
    _check_gifts(before, installed, expected)
    # The copies are innate abilities of the first level; the game's Improved Invisibility casts no
    # slower than speed 2, the rest as fast as their spells. Blur's end of an earlier Blur names its
    # copy; b-hkshd's own recharge gives way to its copy's. A copy that comes back is removed when used
    # and back after its recharge.
    for name, speed, kept, recharge in (('BGW20606', 3, [(20, 1, 0, '')], 6), ('BGW20600', 3, [(20, 1, 0, '')], 0),
                                        ('BGW405RS', 2, [(20, 1, 0, '')], 1000), ('BGW40500', 2, [(20, 1, 0, '')], 0),
                                        ('BGW201RS', 1, [(65, 1, 0, ''), (321, 1, 0, 'BGW201RS')], 1000),
                                        ('BGB-HK0C', 1, [(20, 1, 0, '')], 12), ('BGB-HK0U', 1, [(20, 1, 0, '')], 30)):
        assert _gift_spell(installed, name) == ((4, 1, 4, speed), kept + (
            [(172, 1, 0, name), (171, 4, recharge, name)] if recharge else [])), name

    hooked = _decompile(tmp_path, HOOKED)
    for name, (family, copies) in HOOKED.items():
        expected, reason, got_family, got_copies = hook_rule.patch(originals[name], name, TELEPORTS, HIDES)
        assert (reason, got_family, got_copies) == ('hooked', family, copies)
        assert hooked[name] == expected, name
    # SCS's free invisibility stands aside where the engine hides the creature its own way: the
    # thief's three plain ones above the hook and its contingency's Improved Invisibility below it
    # and in its copy, the fiend's three plain and two improved ones, but not its real contingency; no
    # other script has any.
    for name in HOOKED:
        plain = hooked[name].count(hook_rule.hide_guard(HOOKED[name][0], name.lower(), 'plain'))
        improved = hooked[name].count(hook_rule.hide_guard(HOOKED[name][0], name.lower(), 'improved'))
        assert (plain, improved) == {'B-HKTHF': (3, 2), 'B-HKFEN': (3, 2)}.get(name, (0, 0)), name
    # The mage's cloud escape, its run from a Cloudkill's marker and its stand-still take the
    # condition last, the ranged fighter's escape (whose triggers end in an OR group that lacks a
    # member) first and its walk at the party out of a cloud last; the fighter's escape below the
    # hook stays.
    for name, count in (('B-HKMAG', 3), ('B-HKRNG', 2), ('B-HKPRI', 0), ('B-HKMON', 0)):
        assert hooked[name].count(hook_rule.zones_guard(HOOKED[name][0], name.lower())) == count, name
    # SCS's hunt stands aside above and below the hook: the mage's free Oracle, chase and random
    # walk while an unseen attacker puzzles it, the priest's free Invisibility Purge, the fighter's
    # walk at the party it does not see out of a cloud, chase reset and walk to the door (whose
    # triggers end in an OR group that lacks a member), the monster's end of a chase, teleport after
    # the party member it chases and walk and teleport to one it does not detect, and its jump into
    # the fight; not an ally's walk after the party.
    for name, count in (('B-HKMAG', 6), ('B-HKRNG', 3), ('B-HKPRI', 1), ('B-HKMON', 5)):
        assert hooked[name].count(hook_rule.search_guard(HOOKED[name][0], name.lower())) == count, name

    _install(tmp_path, '--force-uninstall-list', '0', '--force-install-list', '0')
    assert _snapshot(tmp_path) == installed

    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


def _check_teleport(data: bytes, name: str, root: Path) -> None:
    """The innate teleport: instant, cast at a point, it moves the caster, lights where it lands,
    glows and sounds, and is gone for 18 seconds, then back; named as given."""
    spell = parse_spl(data, 'BGSETELE')
    assert (spell['spellType'], spell['level'], spell['school'], spell['secondary']) == (4, 1, 8, 13)
    assert struct.unpack_from('<H', data, 0x22)[0] == 9
    [ability] = spell['abilities']
    assert (ability['location'], ability['target'], ability['range'], ability['speed'], ability['projectile']) == (
        4, 4, 200, 0, 1)
    assert [(e['opcode'], e['target'], e['timing'], e['duration'], e['res']) for e in ability['effects']] == [
        (172, 1, 1, 0, 'BGSETELE'), (171, 1, 4, 18, 'BGSETELE'), (124, 1, 1, 0, ''), (141, 1, 4, 1, ''),
        (50, 1, 0, 2, ''), (174, 1, 0, 0, 'EFF_M09')]
    assert _tlk_text((root / 'lang/en_us/dialog.tlk').read_bytes(), spell['name']) == name


def test_without_the_fiend_teleport_the_jump_stays_and_the_innate_gets_an_english_name(tmp_path: Path) -> None:
    # A game without the fiend teleport: the monster's jump casts a spell that moves nobody there, so
    # it stays a special copied above the hook; its chase still teleports by script, so its creature
    # gets the innate teleport, named in English.
    _fake_game(tmp_path, fiend_teleport=False)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, ['B-HKMON'])
    output = _install(tmp_path, '--force-install-list', '0')
    assert ('BGSE hook: 6 SCS scripts hooked, 22 SCS blocks guarded, 5 SCS cloud blocks yield to the engine, '
            "14 SCS hunting blocks yield to the engine's search, 3 left as they are.") in output, output
    assert ("BGSE teleport: 0 SCS jumps into the fight yield to the creatures' own teleports, 1 creatures that "
            'teleport only by script got the innate teleport BGSETELE.') in output, output
    hooked = _decompile(tmp_path, ['B-HKMON'])
    assert hooked['B-HKMON'] == hook_rule.patch(originals['B-HKMON'], 'B-HKMON', TELEPORTS - {'INNATE_FIEND_TELEPORT'})[0]
    installed = _snapshot(tmp_path)
    _check_teleport(installed['override/bgsetele.spl'], 'Teleport Without Error', tmp_path)
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


def test_a_gift_never_takes_a_name_another_mod_or_another_spell_has(tmp_path: Path) -> None:
    # A game where another mod has a spell named as the fiend's round invisibility would be, and where
    # two rounds last 30 seconds: then b-hkshd's copy and the thief script's b-hksil copy would share
    # one name. Nobody gets the round invisibility, the other mod's spell stays as it is, and the name
    # both copies want stands for the spell of the first creature that got it; the other spell's
    # creatures go without that gift.
    _fake_game(tmp_path, times={'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
    foreign = _spl(1, opcode=17, target=1)
    (tmp_path / 'override/BGW20606.SPL').write_bytes(foreign)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, HOOKED)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    assert installed['override/bgw20606.spl'] == foreign
    # b-hkshd is Improved Invisibility (parameter 2 is 1), b-hksil plain.
    _, effects = _gift_spell(installed, 'BGB-HK0U')
    source = 'B-HKSHD' if parse_spl(installed['override/bgb-hk0u.spl'], 'BGB-HK0U')['abilities'][0]['effects'][0][
        'p2'] == 1 else 'B-HKSIL'
    assert effects == [(20, 1, 0, ''), (172, 1, 0, 'BGB-HK0U'), (171, 4, 30, 'BGB-HK0U')]
    expected = _expected_gifts(originals, {'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
    gifts_of = {name.lower(): hook_rule.script_gifts(text, HIDES, INNATES, {'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
                for name, text in originals.items()}
    for name, grants in expected.items():
        grants.pop('BGW20606', None)
        scripts = _creatures()[name][0]
        wants = {spell for s in scripts for spell, _, _, recharge in gifts_of.get(s.lower(), []) if recharge == 30}
        if 'BGB-HK0U' in grants and source not in wants:
            del grants['BGB-HK0U']
    assert expected['B-HKFE1'].get('BGB-HK0U') == (1 if source == 'B-HKSHD' else None)
    assert expected['B-HKWAR'].get('BGB-HK0U') == (1 if source == 'B-HKSIL' else None)
    _check_gifts(before, installed, expected)
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


@pytest.mark.parametrize('missing', ['eeex', 'lua_trigger'])
def test_without_eeex_nothing_is_installed(tmp_path: Path, missing: str) -> None:
    _fake_game(tmp_path, eeex=missing != 'eeex', lua_trigger=missing != 'lua_trigger')
    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SKIPPING' in output, output
    assert _snapshot(tmp_path) == before
