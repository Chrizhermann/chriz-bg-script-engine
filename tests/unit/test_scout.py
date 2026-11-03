"""The encounter scout (tools/scout.py) on a synthetic game folder: a creature's identity, scores, spells
and items by name, a random item's odds, its scripts and effects, and where it stands; a missing or broken
creature says so."""
import struct
from pathlib import Path

from tools import ie_resources as ie
from tools import scout


def _tlk(strings) -> bytes:
    entries, data = bytearray(), bytearray()
    for text in strings:
        raw = text.encode('ascii')
        entries += struct.pack('<H8sIIII', 1, b'', 0, 0, len(data), len(raw))
        data += raw
    return b'TLK V1  ' + struct.pack('<HII', 0, len(strings), 0x12 + len(entries)) + bytes(entries) + bytes(data)


def _named(signature: bytes, at: int, name: int) -> bytes:
    data = bytearray(0x72)
    data[:8] = signature
    struct.pack_into('<I', data, at, name)
    return bytes(data)


def _cre() -> bytes:
    """A level-5 cleric, name 1, WIS 14, one priest spell memorized and one known only, a club, a random
    item in the first pack slot and a helmet no slot names, one star in clubs."""
    head = bytearray(0x2D4)
    head[:8] = b'CRE V1.0'
    struct.pack_into('<II', head, 0x08, 1, 1)
    struct.pack_into('<hh', head, 0x24, 33, 33)
    head[0x52], head[0x53] = 18, 1
    head[0x234], head[0x235], head[0x273], head[0x272] = 5, 3, 3, 1
    head[0x238:0x23F] = bytes([12, 0, 14, 14, 16, 10, 13])
    head[0x248:0x250] = b'DW#SHDLG'
    head[0x268:0x270] = b'DW#PR141'
    head[0x280:0x285] = b'NEIRA'
    head[0x2CC:0x2D1] = b'NEIRA'
    known = b'SPPR111\0' + struct.pack('<HH', 0, 0) + b'SPPR108\0' + struct.pack('<HH', 0, 0)
    info = struct.pack('<HHHHII', 0, 5, 5, 0, 0, 1)
    memorized = b'SPPR111\0' + struct.pack('<I', 1)
    words = [0xFFFF] * 38 + [0, 0]
    words[9], words[21] = 0, 1
    slots = struct.pack('<40H', *words)
    items = (b'BLUN01\0\0' + struct.pack('<HHHHI', 0, 0, 0, 0, 0) + b'DW#RND02' + struct.pack('<HHHHI', 0, 0, 0, 0, 8) +
             b'HELM01\0\0' + struct.pack('<HHHHI', 0, 0, 0, 0, 0))
    effect = struct.pack('<HBBii', 233, 1, 0, 1, 115).ljust(48, b'\0')
    at = 0x2D4
    struct.pack_into('<II', head, 0x2A0, at, 2)
    struct.pack_into('<II', head, 0x2A8, at + len(known), 1)
    struct.pack_into('<II', head, 0x2B0, at + len(known) + len(info), 1)
    end = at + len(known) + len(info) + len(memorized)
    struct.pack_into('<III', head, 0x2B8, end, end + len(slots), 3)
    struct.pack_into('<II', head, 0x2C4, end + len(slots) + len(items), 1)
    return bytes(head) + known + info + memorized + slots + items + effect


def _area(cre: str) -> bytes:
    data = bytearray(0x11C + 0x110)
    data[:8] = b'AREAV1.0'
    struct.pack_into('<IH', data, 0x54, 0x11C, 1)
    data[0x94:0x9A] = b'BG4801'
    actor = 0x11C
    data[actor:actor + 5] = b'Neira'
    struct.pack_into('<HH', data, actor + 0x20, 410, 300)
    data[actor + 0x80:actor + 0x80 + len(cre)] = cre.encode('ascii')
    return bytes(data)


def _gam(entries) -> bytes:
    """A starting game (GAME V2.0) whose other-NPC list holds entries of (name, area, x, y, creature copy)."""
    header = bytearray(0xB4)
    header[:8] = b'GAMEV2.0'
    at = len(header)
    copies = at + 0x160 * len(entries)
    struct.pack_into('<II', header, 0x30, at, len(entries))
    structs, blobs = bytearray(), bytearray()
    for name, area, x, y, copy in entries:
        npc = bytearray(0x160)
        struct.pack_into('<II', npc, 0x04, copies + len(blobs), len(copy))
        npc[0x0C:0x0C + len(name)] = name
        npc[0x18:0x18 + len(area)] = area
        struct.pack_into('<HH', npc, 0x20, x, y)
        structs += npc
        blobs += copy
    return bytes(header) + bytes(structs) + bytes(blobs)


def _game(root: Path) -> None:
    (root / 'override').mkdir()
    (root / 'lang/en_us').mkdir(parents=True)
    (root / 'lang/en_us/dialog.tlk').write_bytes(_tlk(['', 'Neira', 'Armor of Faith', 'Remove Fear', 'Club',
                                                       'Potion of Healing']))
    files = {'NEIRA.CRE': _cre(), 'SPPR111.SPL': _named(b'SPL V1  ', 0x08, 2), 'SPPR108.SPL': _named(b'SPL V1  ', 0x08, 3),
             'BLUN01.ITM': _named(b'ITM V1  ', 0x0C, 4), 'DW#PTN08.ITM': _named(b'ITM V1  ', 0x0C, 5),
             'BG4801.ARE': _area('NEIRA'), 'TALK.BCS': b'SC\nCR\nCO\nTR\nOB\n"NEIRA"\n',
             'CLASS.IDS': b'IDS V1.0\n3 CLERIC\n', 'RACE.IDS': b'IDS V1.0\n1 HUMAN\n',
             'STATS.IDS': b'IDS V1.0\n115 PROFICIENCYCLUB\n',
             'RNDTRES.2DA': (b'2DA V1.0\n*\n   1 2 3 4 5 6 7\ndw#rnd02 dw#ptn08 dw#ptn08 DW#BLANK DW#BLANK dw#ptn08*2 '
                             b'dw#ptn52 * *\n')}
    # The starting game lists Neira as an NPC too: by her file name without a copy of her (as a new game's
    # BALDUR.GAM does) and as '*EIRA' with one (as a save's does), and a creature of another death variable
    # under her name.
    other = bytearray(_cre())
    other[0x280:0x285] = b'OTHER'
    files['BALDUR.GAM'] = _gam([(b'NEIRA', b'BG4800', 7, 8, b''), (b'*EIRA', b'BG4801', 400, 290, _cre()),
                                (b'*EIRA', b'BG0100', 5, 6, bytes(other))])
    for name, data in files.items():
        (root / 'override' / name).write_bytes(data)


def test_scout_tells_who_a_creature_is_and_what_it_carries(tmp_path: Path) -> None:
    _game(tmp_path)
    game, tlk = ie.Game(tmp_path), scout.Tlk(tmp_path)
    lines = scout.scout(game, tlk, 'neira', where=True)
    text = '\n'.join(lines)
    assert lines[0] == 'NEIRA "Neira"', text
    assert lines[1].startswith('  CLERIC level 5, HUMAN'), text
    assert 'HP 33/33' in text and 'THAC0 18' in text and 'STR 12 INT 14 WIS 14 DEX 16 CON 10 CHA 13' in text
    assert 'scripts: override DW#SHDLG, default DW#PR141; dialog NEIRA; death variable NEIRA' in text
    assert '    priest 1 (5 slots in the file): Armor of Faith SPPR111' in lines
    assert '  known, not memorized: Remove Fear SPPR108' in lines
    assert '    weapon 1: BLUN01 "Club"' in lines
    assert '    pack 1: DW#RND02 "(not in this game)" (undroppable)' in lines
    assert ('      a random item, drawn when the game creates the creature: 2/6 DW#PTN08 "Potion of Healing"; '
            '2/6 nothing; 1/6 2x DW#PTN08 "Potion of Healing"; 1/6 DW#PTN52 "(not in this game)"') in lines
    assert lines.index('    no slot: HELM01 "(not in this game)"') > lines.index('    pack 1: DW#RND02 "(not in this game)" (undroppable)')
    assert '  its own effects: op233 1/115 (PROFICIENCYCLUB)' in lines
    assert '  stands in BG4801 as "Neira" at (410.300); area script BG4801' in lines
    assert "  listed in BALDUR.GAM's NPC list: in BG4800 at (7.8)" in lines
    assert "  listed in BALDUR.GAM's NPC list: in BG4801 at (400.290)" in lines
    assert not any('BG0100' in line for line in lines), text
    assert '  named in BCS: TALK' in lines


def test_scout_names_a_missing_or_broken_creature(tmp_path: Path) -> None:
    _game(tmp_path)
    (tmp_path / 'override/BROKEN.CRE').write_bytes(b'CRE V9.9')
    game, tlk = ie.Game(tmp_path), scout.Tlk(tmp_path)
    assert scout.scout(game, tlk, 'nobody') == ['NOBODY: not in this game']
    assert scout.scout(game, tlk, 'broken') == ['BROKEN: not a CRE V1.0 file']
    assert scout.places(game, 'NOBODY') == ['stands in no area, no NPC list, and no script or dialog names it']
