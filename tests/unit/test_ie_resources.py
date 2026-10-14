"""The Infinity Engine resource reader and parsers on synthetic bytes (no game files)."""
import struct

import pytest

from tools import ie_resources as ie

EFFECT_KEYS = {'opcode', 'target', 'power', 'p1', 'p2', 'timing', 'resist', 'duration',
               'prob1', 'prob2', 'res', 'dice', 'sides', 'save', 'saveBonus', 'special'}


def ref(text):
    return text.encode('latin-1').ljust(8, b'\0')


def fx(opcode=0, target=2, power=3, p1=0, p2=0, timing=1, resist=0, duration=0, prob1=100,
       prob2=0, res='', dice=0, sides=0, save=0, save_bonus=0, special=0):
    return struct.pack('<HBBiIBBIBB8siiIiI', opcode, target, power, p1, p2, timing, resist,
                       duration, prob1, prob2, ref(res), dice, sides, save, save_bonus, special)


def spl_ability(form=1, flags=2, location=3, target=4, target_count=5, rng=6, min_level=7,
                speed=8, count=0, index=0, projectile=9):
    block = bytearray(40)
    struct.pack_into('<BBH', block, 0, form, flags, location)
    struct.pack_into('<BBHHH', block, 0x0C, target, target_count, rng, min_level, speed)
    struct.pack_into('<HH', block, 0x1E, count, index)
    struct.pack_into('<H', block, 0x26, projectile)
    return bytes(block)


def build_spl(abilities, effects, casting=(0, 0), level=3, name=77):
    """abilities: list of ability blocks; effects: the shared effect blocks."""
    head = bytearray(0x72)
    head[:8] = b'SPL V1  '
    struct.pack_into('<I', head, 0x08, name)
    struct.pack_into('<I', head, 0x18, 0x400)
    struct.pack_into('<H', head, 0x1C, 1)
    struct.pack_into('<I', head, 0x1E, 0x1234)
    head[0x25] = 5
    head[0x27] = 6
    struct.pack_into('<I', head, 0x34, level)
    ab_off = len(head)
    fx_off = ab_off + 40 * len(abilities)
    struct.pack_into('<IHIHH', head, 0x64, ab_off, len(abilities), fx_off, *casting)
    return bytes(head) + b''.join(abilities) + b''.join(effects)


def itm_ability(attack=1, idreq=2, location=3, target=4, tcount=5, rng=6, launcher=7, speed=8,
                thac0=-2, sides=6, school=1, dice=2, secondary=3, bonus=-1, dtype=4, count=0,
                index=0, charges=9, depletion=1, flags=0x10, projectile=11, arrow=1, bolt=2,
                bullet=3):
    block = bytearray(56)
    struct.pack_into('<BBB', block, 0, attack, idreq, location)
    struct.pack_into('<BBHB', block, 0x0C, target, tcount, rng, launcher)
    block[0x12] = speed
    struct.pack_into('<hBBBBhH', block, 0x14, thac0, sides, school, dice, secondary, bonus, dtype)
    struct.pack_into('<HHHHIH', block, 0x1E, count, index, charges, depletion, flags, projectile)
    struct.pack_into('<HHH', block, 0x32, arrow, bolt, bullet)
    return bytes(block)


def build_itm(abilities, effects, equipping=(0, 0)):
    head = bytearray(0x72)
    head[:8] = b'ITM V1  '
    struct.pack_into('<II', head, 0x08, 10, 11)
    struct.pack_into('<I', head, 0x18, 0x0A)
    struct.pack_into('<H', head, 0x1C, 20)
    head[0x31] = 33
    struct.pack_into('<H', head, 0x38, 5)
    struct.pack_into('<I', head, 0x60, 2)
    ab_off = len(head)
    fx_off = ab_off + 56 * len(abilities)
    struct.pack_into('<IHIHH', head, 0x64, ab_off, len(abilities), fx_off, *equipping)
    return bytes(head) + b''.join(abilities) + b''.join(effects)


def build_eff():
    data = bytearray(272)
    data[:8] = b'EFF V2.0'
    struct.pack_into('<IIIiIH', data, 0x10, 12, 2, 4, -5, 6, 1)
    struct.pack_into('<IHH8s', data, 0x28, 30, 80, 90, ref('spwi112'))
    struct.pack_into('<iiIiII', data, 0x38, 1, 8, 2, -3, 9, 5)
    struct.pack_into('<I', data, 0x5C, 1)
    data[0x70:0x78] = ref('res2')
    data[0x78:0x80] = ref('res3')
    struct.pack_into('<I', data, 0xD0, 42)
    return bytes(data)


def build_pro(kind):
    data = bytearray(0x24C if kind == 3 else 0x100)
    data[:8] = b'PRO V1.0'
    struct.pack_into('<HHI', data, 0x08, kind, 30, 0x20)
    struct.pack_into('<H', data, 0x2A, 4)
    struct.pack_into('<I', data, 0x2C, 0x100)
    struct.pack_into('<HHHH', data, 0x3C, 1, 2, 3, 4)
    data[0x44:0x4C] = ref('dflt')
    data[0x4C:0x54] = ref('ok')
    if kind == 3:
        struct.pack_into('<HHHH', data, 0x200, 0x11, 8, 2, 300)
        struct.pack_into('<H', data, 0x214, 7)
        data[0x216] = 3
        struct.pack_into('<H', data, 0x21A, 12)
        struct.pack_into('<H', data, 0x224, 90)
        struct.pack_into('<I', data, 0x240, 0x55)
        struct.pack_into('<HH', data, 0x244, 2, 6)
    return bytes(data)


# --- parsers ---------------------------------------------------------------------------------

def test_spl_slices_follow_the_casting_slice_and_keep_signed_p1():
    # Shared table: [casting x1][ability 0 x2][ability 1 x1]
    effects = [fx(opcode=1, p1=-7, res='cast'), fx(opcode=2, p1=-1), fx(opcode=3),
               fx(opcode=4, res='ab1')]
    abilities = [spl_ability(count=2, index=1, projectile=14), spl_ability(count=1, index=3)]
    spl = ie.parse_spl(build_spl(abilities, effects, casting=(0, 1)), 'spwi304')
    assert set(spl) == {'kind', 'resref', 'name', 'flags', 'spellType', 'exclusion', 'school',
                        'secondary', 'level', 'abilities', 'casting'}
    assert (spl['kind'], spl['resref'], spl['name'], spl['level']) == ('SPL', 'SPWI304', 77, 3)
    assert (spl['flags'], spl['spellType'], spl['exclusion']) == (0x400, 1, 0x1234)
    assert (spl['school'], spl['secondary']) == (5, 6)
    assert [e['opcode'] for e in spl['casting']] == [1]
    assert spl['casting'][0]['p1'] == -7 and spl['casting'][0]['res'] == 'CAST'
    first, second = spl['abilities']
    assert set(first) == {'form', 'flags', 'location', 'target', 'targetCount', 'range',
                          'minLevel', 'speed', 'projectile', 'effects'}
    assert [e['opcode'] for e in first['effects']] == [2, 3]
    assert first['effects'][0]['p1'] == -1
    assert [e['opcode'] for e in second['effects']] == [4]
    assert (first['form'], first['flags'], first['location'], first['target']) == (1, 2, 3, 4)
    assert (first['targetCount'], first['range'], first['minLevel'], first['speed']) == (5, 6, 7, 8)
    assert first['projectile'] == 14
    assert set(first['effects'][0]) == EFFECT_KEYS


def test_effect_resref_is_cut_at_nul_stripped_and_uppercased():
    raw = fx()[:0x14] + b'sp\0junkX' + fx()[0x1C:]
    spl = ie.parse_spl(build_spl([spl_ability(count=1, index=0)], [raw]), 'a')
    assert spl['abilities'][0]['effects'][0]['res'] == 'SP'
    padded = fx()[:0x14] + b'ab  ' + b'\0\0\0\0' + fx()[0x1C:]
    spl = ie.parse_spl(build_spl([spl_ability(count=1, index=0)], [padded]), 'a')
    assert spl['abilities'][0]['effects'][0]['res'] == 'AB'


def test_spl_without_abilities_or_effects():
    spl = ie.parse_spl(build_spl([], []), 'x')
    assert spl['abilities'] == [] and spl['casting'] == []


def far_tables(data):
    """Point the ability and effect tables of a record without either past its end."""
    data = bytearray(data)
    struct.pack_into('<I', data, 0x64, len(data) + 400)
    struct.pack_into('<I', data, 0x6A, len(data) + 800)
    return bytes(data)


def test_empty_tables_may_point_past_the_end():
    spl = ie.parse_spl(far_tables(build_spl([], [])), 'x')
    assert spl['abilities'] == [] and spl['casting'] == []
    itm = ie.parse_itm(far_tables(build_itm([], [])), 'x')
    assert itm['abilities'] == [] and itm['equipping'] == []


def test_resref_upper_changes_ascii_letters_only():
    raw = fx()[:0x14] + b'sp\xe9x\0\0\0\0' + fx()[0x1C:]
    spl = ie.parse_spl(build_spl([spl_ability(count=1, index=0)], [raw]), 'a')
    assert spl['abilities'][0]['effects'][0]['res'] == 'SP\xe9X'


def test_itm_two_abilities_prove_stride_56():
    effects = [fx(opcode=10), fx(opcode=11), fx(opcode=12, p1=-4)]
    abilities = [itm_ability(count=1, index=0), itm_ability(attack=3, thac0=5, count=2, index=1,
                                                             projectile=21)]
    itm = ie.parse_itm(build_itm(abilities, effects, equipping=(2, 1)), 'potn08')
    assert set(itm) == {'kind', 'resref', 'name', 'identifiedName', 'flags', 'itemType',
                        'proficiency', 'stack', 'enchantment', 'abilities', 'equipping'}
    assert (itm['resref'], itm['name'], itm['identifiedName'], itm['itemType']) == (
        'POTN08', 10, 11, 20)
    assert (itm['flags'], itm['proficiency'], itm['stack'], itm['enchantment']) == (10, 33, 5, 2)
    assert [e['opcode'] for e in itm['equipping']] == [12]
    first, second = itm['abilities']
    assert set(first) == {'attackType', 'idRequired', 'location', 'target', 'targetCount',
                          'range', 'launcher', 'speed', 'thac0', 'sides', 'school', 'dice',
                          'secondary', 'damageBonus', 'damageType', 'charges', 'depletion',
                          'flags', 'projectile', 'isArrow', 'isBolt', 'isBullet', 'effects'}
    assert first['attackType'] == 1 and second['attackType'] == 3
    assert (first['thac0'], first['damageBonus']) == (-2, -1)
    assert (first['charges'], first['depletion'], first['flags'], first['projectile']) == (
        9, 1, 0x10, 11)
    assert (first['isArrow'], first['isBolt'], first['isBullet']) == (1, 2, 3)
    assert second['projectile'] == 21 and second['thac0'] == 5
    assert [e['opcode'] for e in first['effects']] == [10]
    assert [e['opcode'] for e in second['effects']] == [11, 12]


def test_eff_v2():
    eff = ie.parse_eff(build_eff(), 'Ab')
    assert set(eff) == {'kind', 'resref', 'effect'} and eff['resref'] == 'AB'
    effect = eff['effect']
    assert set(effect) == EFFECT_KEYS | {'school', 'secondary', 'res2', 'res3'}
    assert (effect['opcode'], effect['target'], effect['power'], effect['p1'], effect['p2']) == (
        12, 2, 4, -5, 6)
    assert (effect['timing'], effect['resist'], effect['duration']) == (1, 1, 30)
    assert (effect['prob1'], effect['prob2'], effect['res']) == (80, 90, 'SPWI112')
    assert (effect['dice'], effect['sides'], effect['save'], effect['saveBonus']) == (1, 8, 2, -3)
    assert (effect['special'], effect['school'], effect['secondary']) == (9, 5, 42)
    assert (effect['res2'], effect['res3']) == ('RES2', 'RES3')


def test_pro_area_keys_only_for_type_3():
    base = {'kind', 'resref', 'type', 'speed', 'flags', 'width', 'extFlags', 'creatureValue1',
            'creatureType1', 'creatureValue2', 'creatureType2', 'defaultSpell', 'successSpell'}
    area = {'areaFlags', 'rayCount', 'trigger', 'radius', 'secondary', 'repeats',
            'explosionProjectile', 'coneWidth', 'extAreaFlags', 'targetDice', 'targetSides'}
    plain = ie.parse_pro(build_pro(2), 'fireball')
    assert set(plain) == base and plain['resref'] == 'FIREBALL'
    assert (plain['type'], plain['speed'], plain['defaultSpell'], plain['successSpell']) == (
        2, 30, 'DFLT', 'OK')
    big = ie.parse_pro(build_pro(3), 'fireball')
    assert set(big) == base | area
    assert (big['areaFlags'], big['rayCount'], big['trigger'], big['radius']) == (0x11, 8, 2, 300)
    assert (big['secondary'], big['repeats'], big['explosionProjectile']) == (7, 3, 12)
    assert (big['coneWidth'], big['extAreaFlags'], big['targetDice'], big['targetSides']) == (
        90, 0x55, 2, 6)


def test_pro_type_3_needs_the_area_block():
    data = build_pro(3)[:0x200]
    with pytest.raises(ie.FormatError):
        ie.parse_pro(data, 'x')


@pytest.mark.parametrize('parser,data', [
    (ie.parse_spl, build_spl([], [])), (ie.parse_itm, build_itm([], [])),
    (ie.parse_eff, build_eff()), (ie.parse_pro, build_pro(2))])
def test_wrong_signature_and_truncated_header(parser, data):
    with pytest.raises(ie.FormatError):
        parser(b'XXXX' + data[4:], 'x')
    with pytest.raises(ie.FormatError):
        parser(data[:8] + data[8:0x40], 'x')
    with pytest.raises(ie.FormatError):
        parser(b'', 'x')


def test_wrong_version_is_rejected():
    with pytest.raises(ie.FormatError):
        ie.parse_spl(b'SPL V2  ' + build_spl([], [])[8:], 'x')
    with pytest.raises(ie.FormatError):
        ie.parse_eff(b'EFF V1.0' + build_eff()[8:], 'x')


def test_tables_past_the_data_are_rejected():
    with pytest.raises(ie.FormatError):
        ie.parse_spl(build_spl([spl_ability(count=2, index=0)], [fx()]), 'x')
    with pytest.raises(ie.FormatError):
        ie.parse_spl(build_spl([spl_ability(count=1, index=5)], [fx()]), 'x')
    with pytest.raises(ie.FormatError):
        ie.parse_spl(build_spl([], [fx()], casting=(0, 2)), 'x')
    cut = build_spl([spl_ability(), spl_ability()], [])[:-10]
    with pytest.raises(ie.FormatError):
        ie.parse_spl(cut, 'x')
    with pytest.raises(ie.FormatError):
        ie.parse_itm(build_itm([itm_ability(count=1, index=3)], [fx()]), 'x')
    with pytest.raises(ie.FormatError):
        ie.parse_itm(build_itm([itm_ability(), itm_ability()], [])[:-1], 'x')


# --- reader ----------------------------------------------------------------------------------

def build_biff(entries):
    """entries: list of (locator, type, payload) in file-entry order."""
    head_size = 0x14
    table_size = 16 * len(entries)
    body = b''
    table = b''
    offset = head_size + table_size
    for locator, kind, payload in entries:
        table += struct.pack('<IIIHH', locator, offset, len(payload), kind, 0)
        body += payload
        offset += len(payload)
    head = b'BIFFV1  ' + struct.pack('<III', len(entries), 0, head_size)
    return head + table + body


def build_key(bifs, resources):
    """bifs: list of name strings; resources: list of (resref, type, locator)."""
    bif_off = 0x18
    names_off = bif_off + 12 * len(bifs)
    res_off = names_off + sum(len(n) + 1 for n in bifs)
    table = b''
    names = b''
    for name in bifs:
        table += struct.pack('<IIHH', 100, names_off + len(names), len(name) + 1, 1)
        names += name.encode('ascii') + b'\0'
    res = b''.join(struct.pack('<8sHI', ref(r), t, loc) for r, t, loc in resources)
    head = b'KEY V1  ' + struct.pack('<IIII', len(bifs), len(resources), bif_off, res_off)
    return head + table + names + res


@pytest.fixture
def game_root(tmp_path):
    (tmp_path / 'data').mkdir()
    (tmp_path / 'override').mkdir()
    # File entries are deliberately out of order: file index 1 sits first in the table.
    (tmp_path / 'data' / 'x.bif').write_bytes(build_biff([
        (0x00000001, ie.TYPES['SPL'], b'spell-one'),
        (0x00000000, ie.TYPES['ITM'], b'item-zero'),
        (0x00000002, ie.TYPES['SPL'], b'spell-two'),
    ]))
    (tmp_path / 'chitin.key').write_bytes(build_key(['data\\X.BIF'], [
        ('SPWI112', ie.TYPES['SPL'], 1),
        ('SPWI304', ie.TYPES['SPL'], 2),
        ('POTN08', ie.TYPES['ITM'], 0),
    ]))
    return tmp_path


def test_get_reads_biff_entries_by_file_index_not_position(game_root):
    game = ie.Game(game_root)
    assert game.get('SPWI112', 'SPL') == b'spell-one'
    assert game.get('spwi304', 'spl') == b'spell-two'
    assert game.get('POTN08', 'ITM') == b'item-zero'
    assert game.get('NOPE', 'SPL') is None
    assert game.get('POTN08', 'SPL') is None
    assert game.problems == []


def test_override_wins_and_lookup_is_case_insensitive(game_root):
    (game_root / 'override' / 'SpWi112.Spl').write_bytes(b'override')
    (game_root / 'override' / 'NEWSPL.spl').write_bytes(b'new')
    game = ie.Game(game_root)
    assert game.get('SPWI112', 'SPL') == b'override'
    assert game.get('newspl', 'spl') == b'new'
    assert game.get('SPWI304', 'SPL') == b'spell-two'


def test_names_is_the_sorted_union_of_override_and_key(game_root):
    (game_root / 'override' / 'zzspl.spl').write_bytes(b'x')
    (game_root / 'override' / 'SPWI112.SPL').write_bytes(b'x')
    (game_root / 'override' / 'other.itm').write_bytes(b'x')
    game = ie.Game(game_root)
    assert game.names('SPL') == ['SPWI112', 'SPWI304', 'ZZSPL']
    assert game.names('itm') == ['OTHER', 'POTN08']
    assert game.names('PRO') == []


def test_compressed_bif_is_recorded_and_returns_none(tmp_path):
    (tmp_path / 'override').mkdir()
    (tmp_path / 'a.bif').write_bytes(b'BIFCV1.0' + b'\0' * 32)
    (tmp_path / 'b.bif').write_bytes(b'BIF V1.0' + b'\0' * 32)
    (tmp_path / 'chitin.key').write_bytes(build_key(['a.bif', 'b.bif'], [
        ('ONE', ie.TYPES['SPL'], 0), ('TWO', ie.TYPES['SPL'], 1 << 20)]))
    game = ie.Game(tmp_path)
    assert game.get('ONE', 'SPL') is None
    assert game.get('TWO', 'SPL') is None
    assert len(game.problems) == 2 and all('compressed' in p for p in game.problems)
    assert game.names('SPL') == ['ONE', 'TWO']


def test_missing_bif_and_missing_key_are_recorded(tmp_path):
    (tmp_path / 'chitin.key').write_bytes(build_key(['gone.bif'], [('ONE', ie.TYPES['SPL'], 0)]))
    game = ie.Game(tmp_path)
    assert game.get('ONE', 'SPL') is None
    assert any('gone.bif' in p for p in game.problems)
    empty = ie.Game(tmp_path / 'nowhere')
    assert empty.get('ONE', 'SPL') is None and empty.names('SPL') == []
    assert empty.problems


def test_text_reads_latin1_and_refuses_encrypted(game_root):
    (game_root / 'override' / 'plain.ids').write_bytes('IDS V1.0\n1 caf\xe9\n'.encode('latin-1'))
    (game_root / 'override' / 'secret.2da').write_bytes(b'\xff\xff\x01\x02')
    game = ie.Game(game_root)
    assert game.text('PLAIN', 'IDS') == 'IDS V1.0\n1 caf\xe9\n'
    assert game.text('SECRET', '2DA') is None
    assert any('SECRET.2DA' in p for p in game.problems)
    assert game.text('MISSING', 'IDS') is None


def test_projectiles_skips_headers_and_shifts_ids_by_one(game_root):
    (game_root / 'override' / 'projectl.ids').write_bytes(
        b'IDS V1.0\n3\n0 NONE\n0x1 Arrow // comment\n 2   fireball\n\nbad line\n')
    mapping = ie.projectiles(ie.Game(game_root))
    assert mapping == {1: 'NONE', 2: 'ARROW', 3: 'FIREBALL'}


def test_projectiles_without_the_ids_is_empty(game_root):
    assert ie.projectiles(ie.Game(game_root)) == {}
