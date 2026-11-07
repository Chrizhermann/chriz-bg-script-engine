"""The fight census on tiny ARE, CRE, BCS and DLG bytes (no installed game)."""
import csv
import struct

from tools import fight_census
from tools import ie_resources as ie
from tools import scout


def ref(value):
    return value.encode('ascii').ljust(8, b'\0')


def cre(ea, cls, level, script, name=0):
    data = bytearray(0x324)
    data[:8] = b'CRE V1.0'
    struct.pack_into('<Ihh', data, 0x08, name, 21, 25)
    data[0x234], data[0x23A], data[0x23B] = level, 17, 12
    data[0x270:0x274] = bytes((ea, 0, 1, cls))
    data[0x268:0x270] = ref(script)
    struct.pack_into('<III', data, 0x2B8, 0x2D4, 0x324, 0)
    struct.pack_into('<II', data, 0x2C4, 0x324, 0)
    return bytes(data)


def area(embedded):
    actor_at, spawn_at = 0x100, 0x320
    data = bytearray(spawn_at + 0xC8 + len(embedded))
    data[:8] = b'AREAV1.0'
    struct.pack_into('<IH', data, 0x54, actor_at, 2)
    struct.pack_into('<II', data, 0x60, spawn_at, 1)
    first = actor_at
    data[first:first + 32] = b'Mage in the street'.ljust(32, b'\0')
    data[first + 0x70:first + 0x78] = ref('OTHER')  # Actor default replaces the CRE default.
    data[first + 0x80:first + 0x88] = ref('MAGE')
    second = actor_at + 0x110
    data[second:second + 32] = b'Embedded guard'.ljust(32, b'\0')
    data[second + 0x80:second + 0x88] = ref('EMBED')
    embedded_at = spawn_at + 0xC8
    struct.pack_into('<II', data, second + 0x88, embedded_at, len(embedded))
    data[embedded_at:embedded_at + len(embedded)] = embedded
    spawn = spawn_at
    data[spawn:spawn + 32] = b'road ambush'.ljust(32, b'\0')
    data[spawn + 0x24:spawn + 0x2C] = ref('MAGE')
    data[spawn + 0x2C:spawn + 0x34] = ref('TOWN')
    struct.pack_into('<H', data, spawn + 0x74, 2)
    struct.pack_into('<H', data, spawn + 0xAC, 3)
    return bytes(data)


def dialog():
    body = b'CreateCreature("MAGE",[1.2],S)\r\n'
    data = bytearray(0x3C + len(body))
    data[:8] = b'DLG V1.0'
    struct.pack_into('<II', data, 0x28, 0x34, 1)
    struct.pack_into('<II', data, 0x34, 0x3C, len(body))
    data[0x3C:] = body
    return bytes(data)


def game(root):
    override = root / 'override'
    override.mkdir(parents=True)
    files = {
        'MAGE.CRE': cre(255, 1, 12, 'SCSSCR'),
        'TOWN.CRE': cre(128, 2, 2, 'OTHER'),
        'BGTEST.ARE': area(cre(200, 2, 4, 'SCSSCR')),
        'SCSSCR.BCS': b'SC\ncastspell DMWW_mage_difficulty\nSC\n',
        'OTHER.BCS': b'SC\nNoAction()\nSC\n',
        'MAKE.BCS': b'SC\nAC\n7OB\n0 0 0 0 0"MAGE" "" AC\nRE\nSC\n',
        'MAKEDLG.DLG': dialog(),
        'ACTION.IDS': b'IDS V1.0\n7 CreateCreature(S:NewObject*,P:Location*,I:Face*DIR)\n',
        'CLASS.IDS': b'IDS V1.0\n1 MAGE\n2 FIGHTER\n',
        'RACE.IDS': b'IDS V1.0\n1 HUMAN\n',
    }
    for name, data in files.items():
        (override / name).write_bytes(data)


def test_census_uses_actor_and_embedded_creatures_and_finds_script_creations(tmp_path):
    root = tmp_path / 'game'
    game(root)
    data = fight_census.census(ie.Game(root), scout.Tlk(root))
    actors = [row for row in data['areas'] if row['kind'] == 'actor']
    assert actors[0]['cre_resrefs'] == 'MAGE'
    assert actors[0]['actor_script_overrides'] == 'default=OTHER'
    assert actors[0]['hook'] == 'other'
    assert actors[1]['embedded_cre'] == 'yes' and actors[1]['hook'] == 'scs'
    spawn = next(row for row in data['areas'] if row['kind'] == 'spawn')
    assert (spawn['cre_resrefs'], spawn['max_spawns']) == ('MAGE; TOWN', 3)
    mage = data['creatures']['MAGE']
    assert (mage['class'], mage['level'], mage['int'], mage['wis']) == ('MAGE', 12, 17, 12)
    assert mage['script_create_count'] == 2
    assert mage['script_created_by'] == 'BCS:MAKE; DLG:MAKEDLG'


def test_census_writes_the_three_reports(tmp_path):
    root, out = tmp_path / 'game', tmp_path / 'out'
    game(root)
    data = fight_census.census(ie.Game(root), scout.Tlk(root))
    fight_census.write(data, out)
    with (out / 'areas.csv').open(newline='', encoding='utf-8') as stream:
        rows = list(csv.DictReader(stream))
    assert [row['kind'] for row in rows] == ['actor', 'actor', 'spawn']
    with (out / 'creatures.csv').open(newline='', encoding='utf-8') as stream:
        mage = next(row for row in csv.DictReader(stream) if row['resref'] == 'MAGE')
    assert mage['default_script'] == 'SCSSCR' and mage['script_create_count'] == '2'
    summary = (out / 'summary.md').read_text(encoding='utf-8')
    assert 'Hostile placed actors: 2 (1 SCS, 1 other).' in summary
    assert 'Hostile script-created creatures: 2 (2 SCS, 0 other).' in summary
