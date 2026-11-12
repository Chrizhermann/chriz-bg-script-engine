"""Install the bgse component into a synthetic game with SCS-like scripts.

WeiDU's result must match tools/hook_rule.py block for block; scripts the rule leaves alone
must keep their exact bytes; reinstall and uninstall must be clean.
"""
import os
import re
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
          'B-HKMON': ('monster', 9), 'B-HKTHF': ('fighter', 3), 'B-HKFEN': ('monster', 0), 'B-HKPRP': ('mage', 0),
          'B-HKEXT': ('monster', 6), 'B-HKGAT': ('priest', 0)}
UNTOUCHED = ('B-HKNOA', 'B-HKOLD', 'B-HKCST', 'B-HKNON', 'B-HKVAN', 'B-HKTLX', 'B-HKPLT')
# Scripts that are not SCS's and that a creature carries: a fight script in a creature file's slot (with a talk
# script that does not fight, B-HKPLT), one only an area's actor names and one only a creature stored in the area
# names. They get the engine's own hook. The fight scripts nobody carries (B-HKNON and others above) do not.
OWN = ('B-HKGEN', 'B-HKACT', 'B-HKEMB')
OWN_CREATURE = ('B-HKGNL', ['B-HKPLT', '', 'B-HKGEN', '', ''])
OWN_AREA = ('B-HKARE', ['', '', 'B-HKACT', '', '', ''], ['', 'B-HKEMB', '', '', ''])
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
# The fake game's spell that takes its target out of the game (opcode 68 at its caster), as the exit
# script casts it at itself: b-hkgon, as SCS's Dryad Teleport and dw#mfesc. Its b-hkheal only heals.
VANISH = frozenset({'B-HKGON'})
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
0x4016 HPLT(O:Object*,I:Hit Points*)
0x4017 NumTimesTalkedTo(I:Num*)
0x4018 NumTimesTalkedToGT(I:Num*)
0x4019 AttackedBy(O:Object*,I:Style*AStyles)
0x401A Exists(O:Object*)
0x401B DifficultyGT(I:Amount*Difflev)
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
29 RemoveSpellRES(S:Spell*)
30 DisplayStringHead(O:Object*,I:StrRef*)
31 SetGlobalTimerRandom(S:Name*,S:Area*,I:Min*,I:Max*)
32 DropInventory()
33 CreateVisualEffectObject(S:DialogFile*,O:Target*)
34 SmallWait(I:Time*)
35 StartCutSceneMode()
36 EndCutSceneMode()
37 Dialog(O:Object*)
38 StartDialogNoSet(O:Object*)
39 CutSceneId(O:Object*)
40 MoveViewPoint(P:Target*,I:ScrollSpeed*Scroll)
41 Wait(I:Time*)
42 StartDialogue(S:DialogFile*,O:Target*)
43 MoveToPoint(P:Point*)
44 ClearAllActions()
45 StartCutSceneEx(S:Cutscene*,I:CheckTriggers*Boolean)
46 JumpToPoint(P:Target*)
47 EscapeArea()
48 CreateCreature(S:NewObject*,P:Location*,I:Face*Dir)
49 FaceObject(O:Object*)
50 StartDialogNoSetInterrupt(O:Object*)
"""
IDS = {
    'OBJECT': ('IDS V1.0\n0 Nothing\n1 Myself\n12 NearestEnemyOf\n18 LastSeenBy\n20 LastHeardBy\n21 Player1\n22 Player2\n'
               '40 NearestDoor\n'),
    'DIFFLEV': 'IDS V1.0\n1 EASIEST\n2 EASY\n3 NORMAL\n4 HARD\n5 HARDEST\n',
    'DIR': 'IDS V1.0\n0 S\n5 NW\n',
    'GTIMES': 'IDS V1.0\n6 ONE_ROUND\n',
    'EA': 'IDS V1.0\n0 ANYONE\n2 PC\n30 GOODCUTOFF\n128 NEUTRAL\n255 ENEMY\n',
    'ASTYLES': 'IDS V1.0\n0 DEFAULT\n',
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
    'SCROLL': 'IDS V1.0\n0 INSTANT\n',
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


def _are(actor_scripts, stored_scripts) -> bytes:
    """An area with one actor: its six script slots (override, general, class, race, default, specific) and
    a creature stored in the area with its own five."""
    head, actor = bytearray(0x11C), bytearray(0x110)
    head[:8] = b'AREAV1.0'
    for i, script in enumerate(actor_scripts):
        actor[0x50 + 8 * i:0x58 + 8 * i] = script.encode('ascii').ljust(8, b'\0')
    stored = _cre(stored_scripts, [])
    struct.pack_into('<IH', head, 0x54, len(head), 1)
    struct.pack_into('<II', actor, 0x88, len(head) + len(actor), len(stored))
    return bytes(head) + bytes(actor) + stored


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
    # The exit script's vanishing spell (Unsummon at the caster) and its heal on itself.
    (root / 'override/B-HKGON.SPL').write_bytes(_spl(1, opcode=68, target=2))
    (root / 'override/B-HKHEAL.SPL').write_bytes(_spl(1, opcode=17, target=1))
    for name, (scripts, memorized) in CREATURES.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, memorized))
    for name, (scripts, cls, levels, kit, hide, silent, script_name) in THIEVES.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, [], cls, levels, kit, hide, silent, script_name))
    for name, (scripts, memorized, cls, levels, script_name) in FIENDS.items():
        (root / f'override/{name}.CRE').write_bytes(_cre(scripts, memorized, cls, levels, name=script_name))
    (root / f'override/{OWN_CREATURE[0]}.CRE').write_bytes(_cre(OWN_CREATURE[1], []))
    (root / f'override/{OWN_AREA[0]}.ARE').write_bytes(_are(OWN_AREA[1], OWN_AREA[2]))
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


def test_recorder_installs_without_the_engine_component(tmp_path: Path) -> None:
    _fake_game(tmp_path, lua_trigger=False)
    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '10')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    assert installed['override/m_bgserc.lua'] == build_runtime.build_recorder().encode('utf-8')
    assert 'override/m_bgse.lua' not in installed
    assert (tmp_path / 'bgse-playtest').is_dir()
    _install(tmp_path, '--force-uninstall-list', '10')
    assert _snapshot(tmp_path) == before

    # A normal engine install and recorder install can also coexist; component 10 itself only
    # requires EEex, so this checks it does not accidentally depend on component 0's artefacts.
    second = tmp_path / 'with-engine'
    _fake_game(second)
    output = _install(second, '--force-install-list', '0', '--force-install-list', '10')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(second)
    assert 'override/m_bgse.lua' in installed and 'override/m_bgserc.lua' in installed
    assert (second / 'bgse-playtest').is_dir()


def test_installer_matches_reference_and_is_reversible(tmp_path: Path) -> None:
    _fake_game(tmp_path)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, HOOKED)
    own = _decompile(tmp_path, ['B-HKOWN'])['B-HKOWN']
    talk = _decompile(tmp_path, ['B-HKTLK'])['B-HKTLK']
    helper = _decompile(tmp_path, ['B-HKHLP'])['B-HKHLP']
    carried = _decompile(tmp_path, OWN)

    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    assert "BGSE own: 3 fight scripts that are not SCS's ask the engine first." in output, output
    assert ('BGSE hunt: 5 walks at party members a creature does not perceive, in scripts the SCS rule did not hook, '
            "yield to the engine's search.") in output, output
    assert ('BGSE hook: 9 SCS scripts hooked, 27 SCS blocks guarded, 5 SCS cloud blocks yield to the engine, '
            "14 SCS hunting blocks yield to the engine's search, 3 left as they are.") in output, output
    assert ("BGSE teleport: 1 SCS jumps into the fight yield to the creatures' own teleports, 1 creatures that "
            'teleport only by script got the innate teleport BGSETELE.') in output, output
    assert ('BGSE hide: 9 SCS blocks of free invisibility yield where the engine hides the creature its own way, '
            '5 thieves got hide skills for their level.') in output, output
    assert ('BGSE gift: 8 creatures SCS makes invisible for free got real innate abilities for it, 7 innate copies '
            'of spells made.') in output, output
    assert ('BGSE prep: 7 SCS preparation blocks (prebuffs, contingencies, chains, first-round casts) ask the engine '
            'and tell it what ran.') in output, output
    assert 'BGSE stay: 5 SCS vanishing exits yield while the engine keeps the creature in the fight.' in output, output
    assert ("BGSE stay: 2 vanishing exits in the game's own scripts yield while the engine keeps the creature in the "
            'fight.') in output, output
    assert 'BGSE talk: 4 SCS talk-on-sight blocks wait while the engine prepares the creature.' in output, output
    assert ('BGSE idle: 2 SCS idle gates (no enemy perceived, not in a fight: do nothing) ask the engine first.'
            ) in output, output
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
    assert entries == sorted([f"['{n.lower()}']='{f}'," for n, (f, _) in HOOKED.items()] +
                             [f"['{n.lower()}']='auto'," for n in OWN]), registry
    assert 'BGSE_HOOKED={' in registry
    assert 'BGSE_CALL_STRREFS={' in registry
    import importlib
    lua = importlib.import_module('lupa.lua51').LuaRuntime()
    lua.execute("package.path=... .. '/?.lua;' .. package.path", ROOT.as_posix())
    lua.execute(registry)
    all_lines = lua.execute("return require('combat-intent.calls').allLines()")
    call_strrefs = lua.globals().BGSE_CALL_STRREFS
    for idx in range(1, len(all_lines) + 1):
        entry = all_lines[idx]
        assert isinstance(call_strrefs[entry['key']], int) and call_strrefs[entry['key']] >= 0, entry['key']
    # The engine's own hook: the fight scripts creatures carry that are not SCS's have it at their top and are
    # otherwise as they were, as tools/hook_rule.py says of their compiled form; the talk script beside one, the
    # fight scripts nobody carries and the SCS-hooked ones (which ask already) are not touched (UNTOUCHED, HOOKED
    # below). The creature file and the area that name them stay as they are.
    ids = hook_rule.fight_ids(ACTION + '472 EEex_LuaAction(S:Chunk*)\n')
    assert ids == {5, 6, 7, 8, 17, 22, 23, 28}
    with_hook = _decompile(tmp_path, OWN)
    for name in OWN:
        assert hook_rule.wants_own(before[f'override/{name.casefold()}.bcs'], ids), name
        assert not hook_rule.wants_own(installed[f'override/{name.casefold()}.bcs'], ids), name
        assert with_hook[name] == hook_rule.patch_auto(carried[name], name), name
    assert not hook_rule.fights(before['override/b-hkplt.bcs'], ids)
    assert hook_rule.wants_own(before['override/b-hknon.bcs'], ids)
    assert not any(hook_rule.wants_own(installed[f'override/{name.casefold()}.bcs'], ids) for name in HOOKED)
    for name in (f'{OWN_CREATURE[0]}.cre', f'{OWN_AREA[0]}.are'):
        assert installed[f'override/{name.casefold()}'] == before[f'override/{name.casefold()}'], name
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
        expected, reason, got_family, got_copies = hook_rule.patch(originals[name], name, TELEPORTS, HIDES, VANISH)
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
    # SCS's idle gates hold only when the engine has no decision: the caster's gate and the monster's take the
    # hook's own question last. The gate of a creature that is no enemy, a block that notes something out of a
    # fight and a gate below the hook stay as they are, and no other script has one.
    for name in HOOKED:
        asks = hooked[name].count('  !' + hook_rule.guard(HOOKED[name][0], name.lower()))
        assert asks == {'B-HKGAT': 2}.get(name, 0), name
    # SCS's vanishing exits wait while the engine keeps the creature in the fight, in place and in their
    # copies: the exit script's escapes above the hook (a flayer's and one whose triggers end in an OR
    # group that lacks a member) and below it (an Erinyes' and a Balor's gate away), and the monster's
    # gate away; not a story death in a cutscene, an escape that sets a global variable, a death in an OR
    # group nor a heal on itself.
    for name in HOOKED:
        stays = hooked[name].count(hook_rule.stay_guard(HOOKED[name][0], name.lower()))
        assert stays == {'B-HKEXT': 6, 'B-HKMON': 2}.get(name, 0), name
    # The game's own script: its two exits that no story decides (a hurt teleport away, and a hurt
    # vanish with an enemy in sight, a message and an effect) wait the same way, with no family; its
    # story exits (a variable of its own), the exit that sets a variable and its heal stay as they are.
    expected_own, count = hook_rule.patch_own(own, 'B-HKOWN', VANISH)
    assert count == 2 and expected_own.count(hook_rule.stay_guard('', 'b-hkown')) == 2
    assert _decompile(tmp_path, ['B-HKOWN'])['B-HKOWN'] == expected_own
    # SCS's talk-on-sight script: its four talk blocks wait while the engine prepares the creature, with no family
    # (the one whose triggers end in an OR group that lacks a member takes the condition first). The script that
    # does more besides its talk on sight stays as it is (UNTOUCHED).
    expected_talk, talks = hook_rule.patch_talk(talk, 'B-HKTLK')
    assert talks == 4 and expected_talk.count(hook_rule.talk_guard('', 'b-hktlk')) == 4
    assert 'IF\n  !' + hook_rule.talk_guard('', 'b-hktlk') + '\n  NumTimesTalkedTo(0)\n' in expected_talk
    assert _decompile(tmp_path, ['B-HKTLK'])['B-HKTLK'] == expected_talk
    # The helper above a combat script (as SCS's helpers for its ambushes): its three walks at party members the
    # creature does not perceive ask the engine first, with no family and naming the member; the walk to the
    # nearest one, whose triggers end in a full OR group, takes the condition last as well. Its two walks to the
    # creature whose call for help it heard, with no enemy in sight, ask the same way, naming the caller as the
    # script does. Its walk to a party member it sees, an ally's walk, its bookkeeping, a call that turns the
    # creature hostile first and a walk to the caller with an enemy in sight stay as they are. The SCS-hooked
    # scripts' own walks at the party keep BGSE_Search's condition and get none of this.
    expected_helper, walks = hook_rule.patch_hunt(helper, 'B-HKHLP')
    assert walks == 5 and [expected_helper.count(hook_rule.hunt_guard('b-hkhlp', t)) for t in (
        'Player1', 'Player2', '[PC]', 'LastHeardBy(Myself)')] == [1, 1, 1, 2]
    assert ('    Global("B-HKALERT","GLOBAL",2)\n  !' + hook_rule.hunt_guard('b-hkhlp', '[PC]') + '\nTHEN\n'
            ) in expected_helper
    assert _decompile(tmp_path, ['B-HKHLP'])['B-HKHLP'] == expected_helper
    assert not any('BGSE_Hunt' in text for text in hooked.values())
    # SCS's preparation above the hook asks the engine first and tells it what ran, once in each response
    # that casts: the mage's prebuff and first-round cast, and the preparation script's two prebuffs (one
    # spends a spell by its file, one casts a name SCS left unfilled), contingency, chain at the party and
    # first-round cast. Not a block whose instantprep check is one of an OR group, a cast at an enemy, nor
    # the prebuff below the hook; no other script has any. Each first-round cast is followed by its twin,
    # which asks the other way round and ends SCS's preparation without the cast: each response keeps
    # what it sets of SCS's state but the round timer, then continues.
    preps = {name: hook_rule.preparations(originals[name], *hook_rule.plan(originals[name], TELEPORTS)[:2])
             for name in HOOKED}
    assert preps['B-HKPRP'] == {0: ('prebuff', 'dwsw408', 'dwsw408'), 1: ('prebuff', '', 'WIZARD_MIRROR_IMAGE'),
                                4: ('contingency', 'dwsw305', ''), 5: ('chain', 'dw#cc12', ''),
                                6: ('opener', 'dwsw305', '')}
    assert preps['B-HKMAG'] == {1: ('prebuff', 'dwsw212', 'WIZARD_MIRROR_IMAGE'), 2: ('opener', 'WIZARD_MIRROR_IMAGE', '')}
    for name in HOOKED:
        asks = hooked[name].count('BGSE_Prep(EEex_LuaTrigger_Object')
        tells = hooked[name].count('BGSE_Prepped(EEex_LuaAction_Object')
        twins = hooked[name].count('\n  EEex_LuaTrigger("return BGSE_Prep and')
        assert (asks, tells, twins) == {'B-HKPRP': (6, 4, 1), 'B-HKMAG': (3, 1, 1)}.get(name, (0, 0, 0)), name
    assert ('\nTHEN\n  RESPONSE #80\n    SetGlobal("instantprep","LOCALS",1)\n    Continue()\n  RESPONSE #20\n'
            '    SetGlobalTimer("redefend","LOCALS",TWO_ROUNDS)\n    SetGlobal("instantprep","LOCALS",1)\n'
            '    Continue()\nEND\n') in hooked['B-HKPRP']

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


def test_without_the_fiend_teleport_the_jump_stays_and_the_innate_overwrites_a_taken_name(tmp_path: Path) -> None:
    # A game without the fiend teleport: the monster's jump casts a spell that moves nobody there, so
    # it stays a special copied above the hook; its chase still teleports by script, so its creature
    # gets the innate teleport, named in English.
    _fake_game(tmp_path, fiend_teleport=False)
    (tmp_path / 'override/BGSETELE.SPL').write_bytes(_spl(1, opcode=17, target=1))
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, ['B-HKMON'])
    output = _install(tmp_path, '--force-install-list', '0')
    assert ('BGSE hook: 9 SCS scripts hooked, 28 SCS blocks guarded, 5 SCS cloud blocks yield to the engine, '
            "14 SCS hunting blocks yield to the engine's search, 3 left as they are.") in output, output
    assert ("BGSE teleport: 0 SCS jumps into the fight yield to the creatures' own teleports, 1 creatures that "
            'teleport only by script got the innate teleport BGSETELE.') in output, output
    hooked = _decompile(tmp_path, ['B-HKMON'])
    assert hooked['B-HKMON'] == hook_rule.patch(originals['B-HKMON'], 'B-HKMON', TELEPORTS - {'INNATE_FIEND_TELEPORT'})[0]
    installed = _snapshot(tmp_path)
    _check_teleport(installed['override/bgsetele.spl'], 'Teleport Without Error', tmp_path)
    assert 'another mod has BGSETELE' not in output
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


def test_a_gift_overwrites_a_taken_name_but_two_ours_do_not_share_one(tmp_path: Path) -> None:
    # A game where another mod has a spell named as the fiend's round invisibility would be, and where
    # two rounds last 30 seconds: BGSE owns and overwrites the first name. b-hkshd's copy and the thief
    # script's b-hksil copy still share a generated name, so the first source owns it and creatures of
    # the other source go without that gift.
    _fake_game(tmp_path, times={'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
    foreign = _spl(1, opcode=17, target=1)
    (tmp_path / 'override/BGW20606.SPL').write_bytes(foreign)
    before = _snapshot(tmp_path)
    originals = _decompile(tmp_path, HOOKED)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    assert installed['override/bgw20606.spl'] != foreign
    assert _gift_spell(installed, 'BGW20606') == ((4, 1, 4, 3), [(20, 1, 0, ''), (172, 1, 0, 'BGW20606'),
                                                                  (171, 4, 6, 'BGW20606')])
    # b-hkshd is Improved Invisibility (parameter 2 is 1), b-hksil plain.
    _, effects = _gift_spell(installed, 'BGB-HK0U')
    source = 'B-HKSHD' if parse_spl(installed['override/bgb-hk0u.spl'], 'BGB-HK0U')['abilities'][0]['effects'][0][
        'p2'] == 1 else 'B-HKSIL'
    assert effects == [(20, 1, 0, ''), (172, 1, 0, 'BGB-HK0U'), (171, 4, 30, 'BGB-HK0U')]
    expected = _expected_gifts(originals, {'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
    gifts_of = {name.lower(): hook_rule.script_gifts(text, HIDES, INNATES, {'ONE_ROUND': 6, 'TWO_ROUNDS': 30})
                for name, text in originals.items()}
    for name, grants in expected.items():
        scripts = _creatures()[name][0]
        wants = {spell for s in scripts for spell, _, _, recharge in gifts_of.get(s.lower(), []) if recharge == 30}
        if 'BGB-HK0U' in grants and source not in wants:
            del grants['BGB-HK0U']
    assert expected['B-HKFE1'].get('BGB-HK0U') == (1 if source == 'B-HKSHD' else None)
    assert expected['B-HKWAR'].get('BGB-HK0U') == (1 if source == 'B-HKSIL' else None)
    assert 'another mod has' not in output
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


# Neira as the no-SR lab has her (BOSS-01): priest spells by spell level, an innate ability and a wizard
# spell another mod might give her, and her items with their slot words (2 shield, 9 weapon 1, 18 quick
# item 1, 21 the first pack slot).
NEIRA_BOOK = {(0, 1): ['SPPR111', 'SPPR108', 'SPPR101'], (0, 2): ['SPPR211', 'SPPR208', 'SPPR213'],
              (0, 3): ['SPPR314'], (1, 1): ['SPWI112'], (2, 1): ['SPIN101']}
NEIRA_ITEMS = [('SHLD03A', 2), ('BLUN01', 9), ('SCRLNEI', 18), ('DW#RND02', 21)]
# The book bgse/encounters.tpa gives her (Christopher, 2026-11-04).
DESIGNED = {(0, 1): ['SPPR111', 'SPPR117', 'SPPR113', 'SPPR102', 'SPPR101'],
            (0, 2): ['SPPR201', 'SPPR208', 'SPPR211', 'SPPR213'], (0, 3): ['SPPR314']}
PRIEST_LEVELS = {'SPPR101': 1, 'SPPR102': 1, 'SPPR108': 1, 'SPPR111': 1, 'SPPR113': 1, 'SPPR117': 1, 'SPPR201': 2,
                 'SPPR208': 2, 'SPPR211': 2, 'SPPR213': 2, 'SPPR314': 3}


def _book_cre(book, wis=14, items=(), name='') -> bytes:
    """A level-5 cleric with these memorized spells by (type, spell level) (type 0 priest, 1 wizard, 2
    innate), each known once, WIS wis, these items (resref, slot word), script name name and the memorization
    rows a real creature has, five slots in each of its first three priest levels; no effects."""
    head = bytearray(0x2D4)
    head[:8] = b'CRE V1.0'
    struct.pack_into('<II', head, 0x08, 0xFFFFFFFF, 0xFFFFFFFF)
    head[0x238:0x23F] = bytes([12, 0, 14, wis, 16, 10, 13])
    head[0x234], head[0x273] = 5, 3
    head[0x248:0x250] = b'DW#SHDLG'
    head[0x280:0x2A0] = name.encode('ascii').ljust(32, b'\0')
    rows = [(level, 0) for level in range(7)] + [(level, 1) for level in range(9)] + [(0, 2)]
    known, info, memorized, index = b'', b'', b'', 0
    for level, kind in rows:
        spells = book.get((kind, level + 1), [])
        for spell in dict.fromkeys(spells):
            known += spell.encode('ascii').ljust(8, b'\0') + struct.pack('<HH', level, kind)
        memorized += b''.join(s.encode('ascii').ljust(8, b'\0') + struct.pack('<I', 1) for s in spells)
        slots = 5 if kind == 0 and level < 3 else len(spells)
        info += struct.pack('<HHHHII', level, slots, slots, kind, index, len(spells))
        index += len(spells)
    words = [0xFFFF] * 38 + [0, 0]
    records = b''
    for i, entry in enumerate(items):
        item, slot = entry[0], entry[1]
        charges = entry[2] if len(entry) > 2 else 0
        records += item.encode('ascii').ljust(8, b'\0') + struct.pack('<HHHHI', 0, charges, 0, 0, 0)
        if slot is not None:
            words[slot] = i
    slots = struct.pack('<40H', *words)
    at = 0x2D4
    struct.pack_into('<II', head, 0x2A0, at, len(known) // 12)
    struct.pack_into('<II', head, 0x2A8, at + len(known), len(rows))
    struct.pack_into('<II', head, 0x2B0, at + len(known) + len(info), len(memorized) // 12)
    end = at + len(known) + len(info) + len(memorized)
    struct.pack_into('<III', head, 0x2B8, end, end + len(slots), len(items))
    struct.pack_into('<II', head, 0x2C4, end + len(slots) + len(records), 0)
    return bytes(head) + known + info + memorized + slots + records


def _book_of(data: bytes):
    """A creature's memorized spells by (type, spell level), and its known spells (resref, level, type)."""
    info, rows = struct.unpack_from('<II', data, 0x2A8)
    at, _ = struct.unpack_from('<II', data, 0x2B0)
    book = {}
    for i in range(rows):
        level, _, _, kind, first, many = struct.unpack_from('<HHHHII', data, info + 16 * i)
        if many:
            book[(kind, level + 1)] = [data[at + 12 * j:at + 12 * j + 8].rstrip(b'\0').decode('ascii').upper()
                                       for j in range(first, first + many)]
    known_at, known_count = struct.unpack_from('<II', data, 0x2A0)
    known = [(data[known_at + 12 * i:known_at + 12 * i + 8].rstrip(b'\0').decode('ascii').upper(),
              *struct.unpack_from('<HH', data, known_at + 12 * i + 8)) for i in range(known_count)]
    return book, known


def _items_of(data: bytes):
    """A creature's items by slot word."""
    slot_at, item_at, count = struct.unpack_from('<III', data, 0x2B8)
    words = struct.unpack_from('<40H', data, slot_at)
    items = [data[item_at + 20 * i:item_at + 20 * i + 8].rstrip(b'\0').decode('ascii').upper() for i in range(count)]
    return {slot: items[word] for slot, word in enumerate(words[:38]) if word < count}


@pytest.mark.parametrize('variant', ['plain', 'strong', 'mismatched', 'full', 'absent'])
def test_a_designed_creature_gets_its_scores_book_and_items(tmp_path: Path, variant: str) -> None:
    # Neira's entry (bgse/encounters.tpa): WIS is exactly 15, her priest levels 1 to 3 are the book's,
    # and she gets one Potion of Invisibility. 'strong' has higher WIS and the potion already; it is
    # lowered and not duplicated. 'mismatched' gives Doom another file level, which does not move it out
    # of the entry's priest level 1. 'full' replaces the last pack item. 'absent' has no Neira.
    _fake_game(tmp_path)
    levels = dict(PRIEST_LEVELS)
    if variant == 'mismatched':
        levels['SPPR113'] = 2
    for spell, level in levels.items():
        data = bytearray(_spl(2))
        struct.pack_into('<I', data, 0x34, level)
        (tmp_path / f'override/{spell}.SPL').write_bytes(bytes(data))
    (tmp_path / 'override/POTN10.ITM').write_bytes(b'ITM V1  ' + bytes(0x72 - 8))
    items = list(NEIRA_ITEMS)
    if variant == 'strong':
        items.append(('POTN10', 23))
    if variant == 'full':
        items += [(f'MISC{slot:02d}', slot) for slot in range(22, 37)]
    if variant != 'absent':
        (tmp_path / 'override/NEIRA.CRE').write_bytes(_book_cre(NEIRA_BOOK, 17 if variant == 'strong' else 14, items))
    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    if variant == 'absent':
        assert 'BGSE encounter: neira.cre is not in this game, left out' in output, output
        assert 'BGSE encounter: 0 designed creatures changed, 0 lines added to dialogues, 0 new creatures made.' in output, output
        assert 'override/neira.cre' not in installed
    else:
        assert 'BGSE encounter: 1 designed creatures changed, 0 lines added to dialogues, 0 new creatures made.' in output, output
        new = installed['override/neira.cre']
        assert new[0x23B] == 15
        assert new[0x238:0x23B] == before['override/neira.cre'][0x238:0x23B]
        assert new[0x23C:0x23F] == before['override/neira.cre'][0x23C:0x23F]
        book, known = _book_of(new)
        wanted = {key: list(spells) for key, spells in DESIGNED.items()}
        # Each level holds its spells as often as named; WeiDU may put them in any order.
        assert {key: Counter(spells) for key, spells in book.items()} == {
            key: Counter(spells) for key, spells in {**wanted, (1, 1): ['SPWI112'], (2, 1): ['SPIN101']}.items()}, book
        expected_known = Counter((spell, level - 1, kind) for (kind, level), spells in book.items()
                                 for spell in dict.fromkeys(spells))
        assert Counter(known) == expected_known, known
        have = _items_of(new)
        for item, slot in items:
            assert have[slot] == ('POTN10' if variant == 'full' and slot == 36 else item), (slot, have)
        added = {slot: item for slot, item in have.items() if slot not in dict((s, i) for i, s in items)}
        if variant in ('plain', 'mismatched'):
            assert added == {22: 'POTN10'}, added
        else:
            assert added == {}, added
        assert 'file says another kind or level' not in output, output
        assert 'pack is full' not in output, output
    for name in before:
        if name != 'override/neira.cre' and not name.endswith('.bcs') and name in installed:
            assert installed[name] == before[name] or not name.endswith(('.spl', '.itm')), name
    _install(tmp_path, '--force-uninstall-list', '0', '--force-install-list', '0')
    assert _snapshot(tmp_path) == installed
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


@pytest.mark.parametrize('variant', ['plain', 'elsewhere', 'full', 'taken'])
def test_a_designed_creature_gets_its_own_talk_script(tmp_path: Path, variant: str) -> None:
    # Karlat's entry (bgse/encounters.tpa): his own copy of the game's INITDLG, BGSEKARL, whose talk waits while the
    # engine prepares him as tools/hook_rule.py patches it (own=True); his slot names the copy, and INITDLG and every
    # other creature that uses it stay as they were. 'elsewhere' puts the copy in Karlat's first empty script slot;
    # 'full' replaces Karlat's override script when none is empty; 'taken' overwrites a BGSEKARL another mod left.
    _fake_game(tmp_path)
    compiled = next(p for p in (tmp_path / 'override').iterdir() if p.name.lower() == 'b-hkidl.bcs').read_bytes()
    (tmp_path / 'override/INITDLG.BCS').write_bytes(compiled)
    if variant == 'taken':
        (tmp_path / 'override/BGSEKARL.BCS').write_bytes(compiled)
    scripts = (['DW#OTHER', '', '', '', 'DW1MELGE'] if variant == 'elsewhere' else
               ['DW#OTHER', 'DW#CLASS', 'DW#RACE', 'DW#GENERAL', 'DW1MELGE'] if variant == 'full' else
               ['INITDLG', '', '', '', 'DW1MELGE'])
    (tmp_path / 'override/KARLAT.CRE').write_bytes(_cre(scripts, []))
    (tmp_path / 'override/B-HKTALK.CRE').write_bytes(_cre(['INITDLG', '', '', '', ''], []))
    before = _snapshot(tmp_path)
    source = _decompile(tmp_path, ['INITDLG'])['INITDLG']
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    assert installed['override/initdlg.bcs'] == before['override/initdlg.bcs']
    assert installed['override/b-hktalk.cre'] == before['override/b-hktalk.cre']
    karlat, old = installed['override/karlat.cre'], before['override/karlat.cre']
    assert 'BGSE encounter: 1 designed creatures changed, 0 lines added to dialogues, 0 new creatures made.' in output, output
    changed = 0x250 if variant == 'elsewhere' else 0x248
    assert karlat[changed:changed + 8] == b'BGSEKARL'
    assert karlat[:changed] + karlat[changed + 8:] == old[:changed] + old[changed + 8:]
    assert _decompile(tmp_path, ['BGSEKARL'])['BGSEKARL'] == hook_rule.patch_talk(source, 'BGSEKARL', own=True)[0]
    assert 'has no script INITDLG' not in output and 'another mod has BGSEKARL' not in output
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


# Silke's cutscene as the game has it (SILKECUT: she watches her "thugs" walk up, then starts the talk), and
# Garrick's offer, whose last state starts his cutscene to the Red Sheaf.
SILKECUT = """IF
  True()
THEN
  RESPONSE #100
    CutSceneId("Silke")
    MoveViewPoint([3522.2108],INSTANT)
    Wait(6)
    StartDialogue("cutsilk",Player1)
    EndCutSceneMode()
END

IF
  True()
THEN
  RESPONSE #100
    CutSceneId("Merchant1")
    MoveToPoint([3522.2108])
END
"""
GARRIC = """BEGIN ~GARRIC~
IF ~Global("CDNoRepeat","LOCALS",0)~ THEN BEGIN 0
  SAY ~Hail, adventurers.~
  IF ~~ THEN REPLY ~Tell us more.~ GOTO 1
END
IF ~~ THEN BEGIN 1
  SAY ~I'm Garrick, and I work for Silke Rosena.~
  IF ~~ THEN REPLY ~Show us to your mistress.~ GOTO 2
END
IF ~~ THEN BEGIN 2
  SAY ~Now just meet me outside of the Red Sheaf Inn.~
  IF ~~ THEN DO ~ClearAllActions() StartCutSceneMode() StartCutSceneEx("Garrcut",FALSE)~ EXIT
END
"""


def _decompile_dlg(root: Path, name: str) -> str:
    out = root / 'decompiled-dlg'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir()
    result = subprocess.run([str(_weidu()), '--game', str(root), '--noautoupdate', '--no-exit-pause', '--out', str(out),
                             str(root / 'override' / f'{name}.dlg')],
                            cwd=root, text=True, encoding='utf-8', errors='replace', stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120, check=False)
    assert result.returncode == 0, result.stdout
    return next(out.glob('*.d')).read_text(encoding='latin-1').replace('\r', '')


@pytest.mark.parametrize('variant', ['plain', 'lacking', 'two'])
def test_silke_prepares_in_her_cutscene_and_garrick_warns_of_her_songs(tmp_path: Path, variant: str) -> None:
    # Silke's entry (bgse/encounters.tpa): in SILKECUT, before her wait, she drinks her Potion of Invulnerability
    # and casts one of her Mirror Images at herself, the slot spent; Garrick's line follows the state that starts
    # his cutscene and takes its transition over. 'lacking' has neither the potion nor Mirror Image, but is given
    # the potion and casts the spell anyway; its Garrick starts no cutscene. 'two' has two matching dialogue
    # states, and the first gets the line. Uninstall restores the files; the TLK keeps the game's strings as they
    # were (WeiDU leaves a string it added in the TLK, unused).
    _fake_game(tmp_path)
    (tmp_path / 'fixture/b-hkcut.baf').write_text(SILKECUT, encoding='ascii')
    garric = GARRIC if variant != 'lacking' else GARRIC.replace(' StartCutSceneEx("Garrcut",FALSE)', '')
    if variant == 'two':
        garric += ('IF ~~ THEN BEGIN 3\n  SAY ~A second way to start the cutscene.~\n'
                   '  IF ~~ THEN DO ~StartCutSceneEx("Garrcut",FALSE)~ EXIT\nEND\n')
    (tmp_path / 'fixture/garric.d').write_text(garric, encoding='ascii')
    (tmp_path / 'fixture/extra.tp2').write_text(
        'BACKUP ~fixture/backup-extra~\nAUTHOR ~BGSE test~\nBEGIN ~Silke and Garrick~\n'
        'COMPILE ~fixture/b-hkcut.baf~\nCOMPILE ~fixture/garric.d~\n', encoding='ascii')
    _run(tmp_path, 'fixture/extra.tp2', '--force-install-list', '0')
    compiled = next(p for p in (tmp_path / 'override').iterdir() if p.name.lower() == 'b-hkcut.bcs').read_bytes()
    (tmp_path / 'override/SILKECUT.BCS').write_bytes(compiled)
    (tmp_path / 'override/POTN11.ITM').write_bytes(b'ITM V1  ' + bytes(0x72 - 8))
    (tmp_path / 'override/SPWI212.SPL').write_bytes(_spl(1))
    book = {(1, 1): ['SPWI112'], (1, 2): ['SPWI211', 'SPWI212', 'SPWI212'] if variant != 'lacking' else ['SPWI211']}
    items = [('POTN11', 18)] if variant != 'lacking' else []
    (tmp_path / 'override/SILKE.CRE').write_bytes(_book_cre(book, 12, items, 'SILKE'))
    tlk = tmp_path / 'lang/en_us/dialog.tlk'
    before, before_tlk = _snapshot(tmp_path), tlk.read_bytes()
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    if variant == 'lacking':
        assert _items_of(installed['override/silke.cre'])[21] == 'POTN11'
    else:
        assert installed['override/silke.cre'] == before['override/silke.cre']
    # WeiDU's comments after names it shows (// POTN11) do not count.
    cut = re.sub(r' *//[^\n]*', '', _decompile(tmp_path, ['SILKECUT'])['SILKECUT'])
    prep = '    UseItem("POTN11",Myself)\n    ForceSpellRES("SPWI212",Myself)\n    RemoveSpellRES("SPWI212")\n'
    assert '    MoveViewPoint([3522.2108],INSTANT)\n' + prep + '    Wait(6)\n' in cut, cut
    assert cut.count('UseItem(') == 1 and 'CutSceneId("Merchant1")\n    MoveToPoint([3522.2108])\nEND' in cut, cut
    dialogue = _decompile_dlg(tmp_path, 'GARRIC')
    line = 'And when she sings, folks forget their own minds. Best stay on her good side!'
    if variant != 'lacking':
        assert ('BGSE encounter: 1 designed creatures changed, 1 lines added to dialogues, 0 new creatures made.') in output, output
        state2 = dialogue[dialogue.index('BEGIN 2'):]
        new_state = 4 if variant == 'two' else 3
        assert f'IF ~~ THEN GOTO {new_state}\nEND' in state2, dialogue
        state = dialogue[dialogue.index(f'BEGIN {new_state}'):]
        assert line in state and 'StartCutSceneEx("Garrcut",FALSE)' in state and 'EXIT' in state, dialogue
        assert dialogue.count('StartCutSceneEx(') == (2 if variant == 'two' else 1), dialogue
        assert 'has 2 states that do' not in output, output
    else:
        assert 'BGSE encounter: 1 designed creatures changed, 0 lines added to dialogues, 0 new creatures made.' in output, output
        assert 'silke.cre neither carries SPWI212 nor has it memorized' not in output, output
        assert 'garric.dlg has 0 states that do StartCutSceneEx("Garrcut"' in output, output
        assert installed['override/garric.dlg'] == before['override/garric.dlg'] and line not in dialogue
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before
    count = struct.unpack_from('<I', before_tlk, 0x0A)[0]
    assert [_tlk_text(tlk.read_bytes(), i) for i in range(count)] == [_tlk_text(before_tlk, i) for i in range(count)]


# Greywolf's cutscene as the game has it (PRISMCUT: he jumps in, walks up and starts the talk).
PRISMCUT = """IF
  True()
THEN
  RESPONSE #100
    CutSceneId("Greywolf")
    Wait(5)
    JumpToPoint([1267.2579])
    MoveToPoint([785.2742])
    Wait(1)
    StartDialogNoSet(Player1)
END

IF
  True()
THEN
  RESPONSE #100
    CutSceneId("Prism")
    Wait(1)
END
"""
KESTRELS = {'bgsekes1': (3, 17, 18, 16, {1: 'LEAT01', 9: 'BOW05', 10: 'SW1H07', 13: 'AROW01'}, {13: 40},
                         {(105, 2), (91, 1)}),
            'bgsekes2': (6, 44, 15, 18, {1: 'LEAT04', 9: 'BOW01', 10: 'SW1H07', 13: 'AROW10', 14: 'AROW09', 15: 'AROW08',
                                         16: 'AROW01'}, {13: 10, 14: 10, 15: 10, 16: 20}, {(104, 4), (91, 2)})}
# A warriors' saving throw table in the game's layout, its rows out of order and each value its own (tens: the
# save, ones: the level), so that a wrong row or column shows; 'short' ends at level 4.
SAVEWAR = ('2DA    V1.0\n0\n       1  2  3  4  5  6\n' + ''.join(
    f'{row:<7}' + ' '.join(str(10 * tens + level) for level in range(1, 7)) + '\n'
    for row, tens in (('SPELL', 5), ('DEATH', 1), ('BREATH', 4), ('WANDS', 2), ('POLY', 3))))
CHASSIS_SAVES = bytes([2, 3, 4, 5, 6])


def _proficiencies(data: bytes):
    """A creature's own weapon proficiencies (opcode 233 effects, version 1): {(proficiency, stars)}."""
    at, count = struct.unpack_from('<II', data, 0x2C4)
    assert data[0x33] == 0
    found = set()
    for i in range(count):
        opcode, _, _, stars, prof = struct.unpack_from('<HBBiI', data, at + 48 * i)
        if opcode == 233:
            found.add((prof, stars))
    return found


@pytest.mark.parametrize('variant', ['plain', 'short', 'bare', 'taken'])
def test_greywolf_brings_kestrel(tmp_path: Path, variant: str) -> None:
    # Greywolf's entry (bgse/encounters.tpa): two Kestrels made from the game's archers HUNTER and BAERIN, set as the
    # entry says (level, hit points, THAC0, dexterity, a warrior's saving throws at his level, neutral, his own
    # script over SCS's ranged one, no dialog, his death variable, only his own items and weapon proficiencies),
    # his script compiled, and in PRISMCUT, as Greywolf arrives, the line that has the engine bring the Kestrel the
    # difficulty calls for. 'short': the game's table of warriors' saving throws ends below level 6, so the seasoned
    # Kestrel keeps his chassis's, with a warning. 'taken' overwrites an existing BGSEKES1. 'bare': a game without
    # those archers makes neither, compiles nothing and leaves the cutscene as it is.
    _fake_game(tmp_path)
    (tmp_path / 'fixture/b-hkpcut.baf').write_text(PRISMCUT, encoding='ascii')
    (tmp_path / 'fixture/extra.tp2').write_text(
        'BACKUP ~fixture/backup-extra~\nAUTHOR ~BGSE test~\nBEGIN ~Greywolf~\nCOMPILE ~fixture/b-hkpcut.baf~\n',
        encoding='ascii')
    _run(tmp_path, 'fixture/extra.tp2', '--force-install-list', '0')
    compiled = next(p for p in (tmp_path / 'override').iterdir() if p.name.lower() == 'b-hkpcut.bcs').read_bytes()
    (tmp_path / 'override/PRISMCUT.BCS').write_bytes(compiled)
    (tmp_path / 'override/DW1RANGE.BCS').write_bytes(compiled)
    for item in ('LEAT01', 'BOW05', 'SW1H07', 'AROW01', 'LEAT04', 'BOW01', 'AROW10', 'AROW09', 'AROW08'):
        (tmp_path / f'override/{item}.ITM').write_bytes(b'ITM V1  ' + bytes(0x72 - 8))
    if variant != 'bare':
        # The chassis trained in other weapons (two stars in the long sword) than the entry gives Kestrel, with
        # saving throws of their own.
        for chassis in ('HUNTER', 'BAERIN'):
            data = bytearray(_cre(['DW#GPSHT', '', '', '', 'DW1RANGE'], [], 2, (5, 0, 0)))
            data[0x54:0x59] = CHASSIS_SAVES
            struct.pack_into('<II', data, 0x2C4, len(data), 1)
            data += struct.pack('<HBBiIBBI', 233, 1, 0, 2, 90, 9, 0, 0).ljust(48, b'\0')
            (tmp_path / f'override/{chassis}.CRE').write_bytes(bytes(data))
        table = SAVEWAR if variant in ('plain', 'taken') else re.sub(r' (?:\d5|\d6|5|6)(?= |\n|$)', '', SAVEWAR)
        (tmp_path / 'override/SAVEWAR.2DA').write_text(table, encoding='ascii')
    if variant == 'taken':
        (tmp_path / 'override/BGSEKES1.CRE').write_bytes(_cre(['DW#OTHER', '', '', '', ''], []))
    tlk = tmp_path / 'lang/en_us/dialog.tlk'
    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    cut = re.sub(r' *//[^\n]*', '', _decompile(tmp_path, ['PRISMCUT'])['PRISMCUT'])
    line = 'EEex_LuaAction("if BGSE_Companion then BGSE_Companion(EEex_LuaAction_Object) end")'
    if variant == 'bare':
        assert 'this game lacks hunter.cre, so bgsekes1.cre is not made' in output, output
        assert 'BGSE encounter: 0 designed creatures changed, 0 lines added to dialogues, 0 new creatures made.' in output
        assert not any(name.startswith(('override/bgsekes', 'override/bgsekest')) for name in installed)
        assert installed['override/prismcut.bcs'] == before['override/prismcut.bcs'] and line not in cut
    else:
        assert 'BGSE encounter: 1 designed creatures changed, 0 lines added to dialogues, 2 new creatures made.' in output
        assert ('    JumpToPoint([1267.2579])\n    ' + line + '\n    MoveToPoint([785.2742])\n') in cut, cut
        assert cut.count('EEex_LuaAction(') == 1, cut
        kept = 'BGSE encounter: bgsekes2.cre keeps the saving throws of baerin.cre: this game has no table for its class at level 6'
        assert (kept in output) == (variant == 'short'), output
        assert 'bgsekes1.cre keeps the saving throws' not in output, output
        assert 'another mod has bgsekes1.cre' not in output, output
        for name, (level, hp, thac0, dex, items, charges, profs) in KESTRELS.items():
            assert _proficiencies(installed[f'override/{name}.cre']) == profs, name
            data = installed[f'override/{name}.cre']
            saves = CHASSIS_SAVES if variant == 'short' and level == 6 else bytes(10 * t + level for t in range(1, 6))
            assert data[0x54:0x59] == saves, (name, list(data[0x54:0x59]))
            assert (data[0x234], struct.unpack_from('<hh', data, 0x24), data[0x52], data[0x23C]) == (level, (hp, hp), thac0, dex)
            assert (data[0x270], data[0x27B]) == (128, 0x22)
            scripts = [data[o:o + 8].rstrip(b'\0') for o in range(0x248, 0x270, 8)]
            assert scripts == [b'BGSEKEST', b'', b'', b'', b'DW1RANGE'], scripts
            assert data[0x280:0x2A0].rstrip(b'\0') == b'Kestrel' and data[0x2CC:0x2D4].rstrip(b'\0') == b''
            assert _tlk_text(tlk.read_bytes(), struct.unpack_from('<I', data, 0x08)[0]) == 'Kestrel'
            assert _items_of(data) == items, (name, _items_of(data))
            slot_at, item_at, _ = struct.unpack_from('<III', data, 0x2B8)
            words = struct.unpack_from('<40H', data, slot_at)
            for slot, count in charges.items():
                assert struct.unpack_from('<H', data, item_at + 20 * words[slot] + 10)[0] == count, (name, slot)
        script = _decompile(tmp_path, ['BGSEKEST'])['BGSEKEST']
        assert 'Allegiance("Greywolf",ENEMY)' in script and 'EscapeArea()' in script and 'MoveToObject("Greywolf")' in script
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


MULAHEY_AREA = """IF
  Global("DMWWMulaheyFlunky","MYAREA",1)
  Global("DW#Mulahey_Override","GLOBAL",0)
  DifficultyGT(3)
THEN
  RESPONSE #100
    SetGlobal("DMWWMulaheyFlunky","MYAREA",0)
    CreateCreature("dw#mulkc",[217.591],5)
END
"""
LAMALHA_BAF = """IF
  See([PC])
  NumTimesTalkedTo(0)
THEN
  RESPONSE #100
    SmallWait(2)
    FaceObject([PC])
    StartDialogue("lamalh",[PC])
END
"""
DRASUS_BAF = """IF
  See([PC])
  NumTimesTalkedTo(0)
THEN
  RESPONSE #100
    StartDialogNoSetInterrupt(LastSeenBy)
END
"""


@pytest.mark.parametrize('variant', ['plain', 'edited'])
def test_boss02_encounters_overwrite_slots_unslotted_items_talks_and_mulahey_waves(tmp_path: Path, variant: str) -> None:
    _fake_game(tmp_path)
    (tmp_path / 'fixture/bg5405.baf').write_text(MULAHEY_AREA, encoding='ascii')
    (tmp_path / 'fixture/lamalha.baf').write_text(LAMALHA_BAF, encoding='ascii')
    (tmp_path / 'fixture/drasus.baf').write_text(DRASUS_BAF, encoding='ascii')
    (tmp_path / 'fixture/extra.tp2').write_text(
        'BACKUP ~fixture/backup-extra~\nAUTHOR ~BGSE test~\nBEGIN ~BOSS-02~\n'
        'COMPILE ~fixture/bg5405.baf~\nCOMPILE ~fixture/lamalha.baf~\nCOMPILE ~fixture/drasus.baf~\n',
        encoding='ascii')
    _run(tmp_path, 'fixture/extra.tp2', '--force-install-list', '0')
    for res in ('SPPR312', 'SPPR308', 'SPPR316', 'SPPR314'):
        s = bytearray(_spl(2))
        struct.pack_into('<I', s, 0x34, 3)
        (tmp_path / f'override/{res}.SPL').write_bytes(bytes(s))
    for res in ('SPWI118', 'SPWI104', 'SPWI116', 'SPWI102', 'SPWI114'):
        s = bytearray(_spl(1))
        struct.pack_into('<I', s, 0x34, 1)
        (tmp_path / f'override/{res}.SPL').write_bytes(bytes(s))
    for item in ('AROW08', 'AROW09', 'AROW04', 'AROW01', 'AROW10', 'POTN09', 'POTN08', 'POTN14'):
        (tmp_path / f'override/{item}.ITM').write_bytes(b'ITM V1  ' + bytes(0x72 - 8))

    mulahe_book = {(0, 3): ['SPPR312', 'SPPR312', 'SPPR308', 'SPPR316'] if variant == 'plain' else ['SPPR314']}
    (tmp_path / 'override/MULAHE.CRE').write_bytes(_book_cre(mulahe_book, 11 if variant == 'plain' else 22))
    (tmp_path / 'override/DW#MULKC.CRE').write_bytes(_cre(['', '', '', '', ''], []))
    (tmp_path / 'override/LAMALH.CRE').write_bytes(_cre(['', 'LAMALHA', '', '', ''], []))
    (tmp_path / 'override/DRASUS.CRE').write_bytes(_cre(['', 'DRASUS', '', '', ''], []))
    telka_items = ([('AROW08', 13, 20), ('AROW09', None, 20), ('AROW04', None, 20)] if variant == 'plain' else
                   [('AROW01', 13, 40), ('AROW01', 14, 12), ('AROW10', 15, 5)])
    (tmp_path / 'override/TELKA.CRE').write_bytes(_book_cre({}, 7, telka_items))
    maneir = bytearray(_cre(['', '', '', '', ''], []))
    maneir[0x238] = 12 if variant == 'plain' else 18
    (tmp_path / 'override/MANEIR.CRE').write_bytes(bytes(maneir))
    # Drakar's only POTN09 is unslotted (slot None); carries must ignore unslotted records and place a real one.
    (tmp_path / 'override/DRAKAR.CRE').write_bytes(_book_cre({}, 11, [('POTN08', 18, 2), ('POTN09', None, 1)]))
    venkt_items = ([('POTN08', 18, 1), ('POTN08', 19, 1), ('POTN08', None, 1)] if variant == 'plain' else
                   [('POTN08', 18, 1), ('POTN08', 19, 1), ('POTN09', 20, 3)])
    venkt_book = {(1, 1): ['SPWI118', 'SPWI104', 'SPWI116', 'SPWI116', 'SPWI114'] if variant == 'plain' else ['SPWI114']}
    (tmp_path / 'override/VENKT.CRE').write_bytes(_book_cre(venkt_book, 9, venkt_items))
    (tmp_path / 'override/GENTHO.CRE').write_bytes(_book_cre({}, 13, []))

    before = _snapshot(tmp_path)
    lam_src = _decompile(tmp_path, ['LAMALHA'])['LAMALHA']
    dra_src = _decompile(tmp_path, ['DRASUS'])['DRASUS']
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)

    mulahe = installed['override/mulahe.cre']
    assert mulahe[0x23B] == 17
    assert Counter(_book_of(mulahe)[0][(0, 3)]) == Counter(['SPPR312', 'SPPR308', 'SPPR316'])
    area_baf = _decompile(tmp_path, ['BG5405'])['BG5405']
    assert 'BGSEMulaheyWave' in area_baf and '[360.380]' in area_baf and 'BGSE.gate:on()' in area_baf

    assert installed['override/lamalh.cre'][0x250:0x258] == b'BGSELAMA'
    assert installed['override/drasus.cre'][0x250:0x258] == b'BGSEDRAS'
    assert _decompile(tmp_path, ['BGSELAMA'])['BGSELAMA'] == hook_rule.patch_talk(lam_src, 'BGSELAMA', own=True)[0]
    assert _decompile(tmp_path, ['BGSEDRAS'])['BGSEDRAS'] == hook_rule.patch_talk(dra_src, 'BGSEDRAS', own=True)[0]

    telka = installed['override/telka.cre']
    assert {s: _items_of(telka)[s] for s in (13, 14, 15)} == {13: 'AROW08', 14: 'AROW09', 15: 'AROW04'}
    slot_at, item_at, _ = struct.unpack_from('<III', telka, 0x2B8)
    words = struct.unpack_from('<40H', telka, slot_at)
    assert [struct.unpack_from('<H', telka, item_at + 20 * words[s] + 10)[0] for s in (13, 14, 15)] == [20, 20, 20]

    assert installed['override/maneir.cre'][0x238] == 15
    assert _items_of(installed['override/drakar.cre'])[21] == 'POTN09'

    venkt = installed['override/venkt.cre']
    assert Counter(_book_of(venkt)[0][(1, 1)]) == Counter(['SPWI118', 'SPWI104', 'SPWI116', 'SPWI116', 'SPWI102'])
    assert _items_of(venkt)[20] == 'POTN08'
    vslot, vitem, _ = struct.unpack_from('<III', venkt, 0x2B8)
    vwords = struct.unpack_from('<40H', venkt, vslot)
    assert struct.unpack_from('<H', venkt, vitem + 20 * vwords[20] + 10)[0] == 1
    assert _items_of(installed['override/gentho.cre'])[21] == 'POTN14'

    _install(tmp_path, '--force-uninstall-list', '0', '--force-install-list', '0')
    assert _snapshot(tmp_path) == installed
    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before


@pytest.mark.parametrize('variant', ['typo', 'edited', 'fallback'])
def test_ppdjinn2_overwrite_assigns_hooked_djinni_script_and_restores_cleanly(tmp_path: Path, variant: str) -> None:
    _fake_game(tmp_path)
    bcs_name = 'DJINNI01' if variant == 'fallback' else 'PPDJINN2'
    (tmp_path / f'fixture/{bcs_name.lower()}.baf').write_text(
        'IF\n  See(NearestEnemyOf(Myself))\nTHEN\n  RESPONSE #100\n    AttackReevaluate(NearestEnemyOf(Myself),30)\nEND\n',
        encoding='ascii')
    (tmp_path / 'fixture/djinni.tp2').write_text(
        f'BACKUP ~fixture/backup-djinni~\nAUTHOR ~BGSE test~\nBEGIN ~djinni~\nCOMPILE ~fixture/{bcs_name.lower()}.baf~\n',
        encoding='ascii')
    _run(tmp_path, 'fixture/djinni.tp2', '--force-install-list', '0')
    old_default = '"djinni0' if variant == 'typo' else ('CUSTOMDJ' if variant == 'edited' else '')
    (tmp_path / 'override/PPDJINN2.CRE').write_bytes(_cre(['', '', '', '', old_default], []))

    before = _snapshot(tmp_path)
    output = _install(tmp_path, '--force-install-list', '0')
    assert 'SUCCESSFULLY INSTALLED' in output, output
    installed = _snapshot(tmp_path)
    assert installed['override/ppdjinn2.cre'][0x268:0x270] == bcs_name.encode('ascii').ljust(8, b'\x00')
    registry = installed['override/m_bgsehk.lua'].decode('ascii')
    assert f"['{bcs_name.lower()}']='auto'," in registry

    _install(tmp_path, '--force-uninstall-list', '0')
    assert _snapshot(tmp_path) == before
