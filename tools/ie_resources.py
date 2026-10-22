"""Read-only Infinity Engine resource reader and SPL/ITM/EFF/PRO parsers.

`Game(root)` finds a resource in the override folder first, then through chitin.key and the
BIFF V1 archives it names. Nothing is ever written. The parsers turn the binary records into
plain dicts; the key names are the contract with the Lua spell classifier and the in-game
EEex reader, which produce the same shapes.

    python tools/ie_resources.py <game_root> list SPL
    python tools/ie_resources.py <game_root> dump SPL SPWI304
    python tools/ie_resources.py <game_root> projectiles
"""
import json
import struct
import sys
from pathlib import Path

TYPES = {'SPL': 0x3EE, 'ITM': 0x3ED, 'BCS': 0x3EF, 'IDS': 0x3F0, 'CRE': 0x3F1, '2DA': 0x3F4,
         'EFF': 0x3F8, 'PRO': 0x3FD}
TYPE_NAMES = {code: ext for ext, code in TYPES.items()}


class FormatError(ValueError):
    """The bytes are not a well-formed record of the expected kind."""


# --- reader ---------------------------------------------------------------------------------

def _resolve(root, relative):
    """Resolve a path with backslashes or odd case under root; None if it does not exist."""
    path = Path(root)
    for part in relative.replace('\\', '/').split('/'):
        if part in ('', '.'):
            continue
        try:
            names = {entry.name.lower(): entry.name for entry in path.iterdir()}
        except OSError:
            return None
        found = names.get(part.lower())
        if found is None:
            return None
        path = path / found
    return path


class Game:
    """Override-first lookup of game resources. Problems are recorded, not raised."""

    def __init__(self, root):
        self.root = Path(root)
        self.problems = []
        self._override = None
        self._key = None
        self._bifs = {}

    def _problem(self, message):
        if message not in self.problems:
            self.problems.append(message)

    def _override_index(self):
        if self._override is None:
            self._override = {}
            folder = _resolve(self.root, 'override')
            if folder is not None and folder.is_dir():
                for entry in folder.iterdir():
                    if entry.is_file():
                        self._override[entry.name.lower()] = entry
        return self._override

    def _key_index(self):
        """Return (bif names, {(type code, RESREF): locator}) from chitin.key."""
        if self._key is not None:
            return self._key
        self._key = ([], {})
        path = _resolve(self.root, 'chitin.key')
        if path is None:
            self._problem('chitin.key not found')
            return self._key
        try:
            data = path.read_bytes()
            if data[:8] != b'KEY V1  ':
                raise FormatError('not a KEY V1 file')
            bif_count, res_count, bif_off, res_off = _unpack('<IIII', data, 0x08)
            names = []
            for i in range(bif_count):
                _, name_off, name_len, _ = _unpack('<IIHH', data, bif_off + 12 * i)
                raw = data[name_off:name_off + name_len]
                if len(raw) != name_len:
                    raise FormatError('BIF name runs past the end of the file')
                names.append(raw.split(b'\0')[0].decode('latin-1'))
            resources = {}
            for i in range(res_count):
                at = res_off + 14 * i
                raw, kind, locator = _unpack('<8sHI', data, at)
                resources.setdefault((kind, _resref(raw)), locator)
        except (OSError, FormatError) as err:
            self._problem(f'chitin.key unusable: {err}')
            return self._key
        self._key = (names, resources)
        return self._key

    def _bif_table(self, bif_index):
        """Return {fileIndex: (offset, size)} and the BIF path, or None if unusable."""
        if bif_index in self._bifs:
            return self._bifs[bif_index]
        self._bifs[bif_index] = None
        names = self._key_index()[0]
        if bif_index >= len(names):
            self._problem(f'chitin.key refers to missing BIF index {bif_index}')
            return None
        label = names[bif_index]
        path = _resolve(self.root, label)
        if path is None or not path.is_file():
            self._problem(f'BIF not found: {label}')
            return None
        try:
            with path.open('rb') as stream:
                head = stream.read(0x14)
                if head[:8] in (b'BIF V1.0', b'BIFCV1.0'):
                    self._problem(f'compressed BIF not supported: {label}')
                    return None
                if head[:8] != b'BIFFV1  ':
                    self._problem(f'not a BIFF V1 archive: {label}')
                    return None
                count, _tilesets, table_off = _unpack('<III', head, 0x08)
                stream.seek(table_off)
                raw = stream.read(16 * count)
            if len(raw) != 16 * count:
                self._problem(f'BIFF file table is truncated: {label}')
                return None
            size_on_disk = path.stat().st_size
            table = {}
            for i in range(count):
                locator, offset, size = struct.unpack_from('<III', raw, 16 * i)
                if offset + size > size_on_disk:
                    self._problem(f'BIFF entry runs past the end of the archive: {label}')
                    continue
                table.setdefault(locator & 0x3FFF, (offset, size))
        except (OSError, FormatError, struct.error) as err:
            self._problem(f'BIFF unreadable ({label}): {err}')
            return None
        self._bifs[bif_index] = (path, table)
        return self._bifs[bif_index]

    def get(self, resref, ext):
        """Return the resource bytes (override first, then BIFF), or None if absent."""
        resref, ext = resref.upper(), ext.upper()
        hit = self._override_index().get(f'{resref}.{ext}'.lower())
        if hit is not None:
            try:
                return hit.read_bytes()
            except OSError as err:
                self._problem(f'override file unreadable ({hit.name}): {err}')
                return None
        kind = TYPES.get(ext)
        locator = self._key_index()[1].get((kind, resref)) if kind is not None else None
        if locator is None:
            return None
        loaded = self._bif_table(locator >> 20)
        if loaded is None:
            return None
        path, table = loaded
        entry = table.get(locator & 0x3FFF)
        if entry is None:
            self._problem(f'{resref}.{ext} is missing from {path.name}')
            return None
        try:
            with path.open('rb') as stream:
                stream.seek(entry[0])
                return stream.read(entry[1])
        except OSError as err:
            self._problem(f'BIFF unreadable ({path.name}): {err}')
            return None

    def names(self, ext):
        """Sorted upper-case resrefs available for an extension (override plus key)."""
        ext = ext.upper()
        found = set()
        suffix = '.' + ext.lower()
        for name in self._override_index():
            if name.endswith(suffix):
                found.add(name[:-len(suffix)].upper())
        kind = TYPES.get(ext)
        if kind is not None:
            found.update(resref for code, resref in self._key_index()[1] if code == kind)
        return sorted(found)

    def text(self, resref, ext):
        """IDS/2DA text (latin-1), or None if absent or encrypted."""
        data = self.get(resref, ext)
        if data is None:
            return None
        if data[:2] == b'\xff\xff':
            self._problem(f'{resref.upper()}.{ext.upper()} is encrypted')
            return None
        return data.decode('latin-1')


def projectiles(game):
    """{projectile field value: PRO resref} from PROJECTL.IDS (field value N is entry N-1)."""
    text = game.text('PROJECTL', 'IDS')
    found = {}
    for line in (text or '').splitlines():
        parts = line.split('//')[0].split()
        if len(parts) < 2:
            continue
        try:
            number = int(parts[0], 0)
        except ValueError:
            continue
        found.setdefault(number + 1, parts[1].upper())
    return found


# --- parsers --------------------------------------------------------------------------------

def _unpack(fmt, data, offset):
    try:
        return struct.unpack_from(fmt, data, offset)
    except struct.error:
        raise FormatError(f'truncated data at 0x{offset:X}') from None


def _resref(raw):
    # bytes.upper() changes ASCII letters only, as the engine and the in-game reader do.
    return raw.split(b'\0')[0].rstrip(b' ').upper().decode('latin-1')


def _check(data, signature, minimum):
    if data[:8] != signature:
        raise FormatError(f'expected signature {signature!r}, found {data[:8]!r}')
    if len(data) < minimum:
        raise FormatError(f'header truncated: {len(data)} bytes, need {minimum}')


_EFFECT = struct.Struct('<HBBiIBBIBB8siiIiI')


def _effect(data, offset):
    (opcode, target, power, p1, p2, timing, resist, duration, prob1, prob2, res, dice, sides,
     save, save_bonus, special) = _EFFECT.unpack_from(data, offset)
    return {'opcode': opcode, 'target': target, 'power': power, 'p1': p1, 'p2': p2,
            'timing': timing, 'resist': resist, 'duration': duration, 'prob1': prob1,
            'prob2': prob2, 'res': _resref(res), 'dice': dice, 'sides': sides, 'save': save,
            'saveBonus': save_bonus, 'special': special}


def _effects(data, table, index, count):
    """The count effect blocks starting at block index of the shared table."""
    start = table + 48 * index
    if count and start + 48 * count > len(data):
        raise FormatError(f'effects {index}..{index + count - 1} run past the end of the data')
    return [_effect(data, start + 48 * i) for i in range(count)]


def _table_end(data, offset, stride, count, what):
    # An empty table reads nothing, wherever its offset points.
    if count and offset + stride * count > len(data):
        raise FormatError(f'{what} table runs past the end of the data')


def parse_spl(data, resref):
    """Parse a SPL V1 spell into {'kind': 'SPL', ...}."""
    _check(data, b'SPL V1  ', 0x72)
    ab_off, ab_count, fx_off, cast_index, cast_count = _unpack('<IHIHH', data, 0x64)
    _table_end(data, ab_off, 40, ab_count, 'ability')
    abilities = []
    for i in range(ab_count):
        at = ab_off + 40 * i
        form, flags, location = _unpack('<BBH', data, at)
        target, target_count, rng, min_level, speed = _unpack('<BBHHH', data, at + 0x0C)
        effect_count, effect_index = _unpack('<HH', data, at + 0x1E)
        (projectile,) = _unpack('<H', data, at + 0x26)
        abilities.append({
            'form': form, 'flags': flags, 'location': location, 'target': target,
            'targetCount': target_count, 'range': rng, 'minLevel': min_level, 'speed': speed,
            'projectile': projectile, 'effects': _effects(data, fx_off, effect_index, effect_count),
        })
    return {
        'kind': 'SPL', 'resref': resref.upper(), 'name': _unpack('<I', data, 0x08)[0],
        'flags': _unpack('<I', data, 0x18)[0], 'spellType': _unpack('<H', data, 0x1C)[0],
        'exclusion': _unpack('<I', data, 0x1E)[0], 'school': data[0x25],
        'secondary': data[0x27], 'level': _unpack('<I', data, 0x34)[0],
        'abilities': abilities, 'casting': _effects(data, fx_off, cast_index, cast_count),
    }


def parse_itm(data, resref):
    """Parse an ITM V1 item into {'kind': 'ITM', ...}."""
    _check(data, b'ITM V1  ', 0x72)
    ab_off, ab_count, fx_off, equip_index, equip_count = _unpack('<IHIHH', data, 0x64)
    _table_end(data, ab_off, 56, ab_count, 'ability')
    abilities = []
    for i in range(ab_count):
        at = ab_off + 56 * i
        attack_type, id_required, location = _unpack('<BBB', data, at)
        target, target_count, rng, launcher = _unpack('<BBHB', data, at + 0x0C)
        (speed,) = _unpack('<B', data, at + 0x12)
        thac0, sides, school, dice, secondary, bonus, damage_type = _unpack(
            '<hBBBBhH', data, at + 0x14)
        effect_count, effect_index, charges, depletion, flags, projectile = _unpack(
            '<HHHHIH', data, at + 0x1E)
        arrow, bolt, bullet = _unpack('<HHH', data, at + 0x32)
        abilities.append({
            'attackType': attack_type, 'idRequired': id_required, 'location': location,
            'target': target, 'targetCount': target_count, 'range': rng, 'launcher': launcher,
            'speed': speed, 'thac0': thac0, 'sides': sides, 'school': school, 'dice': dice,
            'secondary': secondary, 'damageBonus': bonus, 'damageType': damage_type,
            'charges': charges, 'depletion': depletion, 'flags': flags,
            'projectile': projectile, 'isArrow': arrow, 'isBolt': bolt, 'isBullet': bullet,
            'effects': _effects(data, fx_off, effect_index, effect_count),
        })
    return {
        'kind': 'ITM', 'resref': resref.upper(), 'name': _unpack('<I', data, 0x08)[0],
        'identifiedName': _unpack('<I', data, 0x0C)[0], 'flags': _unpack('<I', data, 0x18)[0],
        'itemType': _unpack('<H', data, 0x1C)[0], 'proficiency': data[0x31],
        'stack': _unpack('<H', data, 0x38)[0], 'enchantment': _unpack('<I', data, 0x60)[0],
        'abilities': abilities, 'equipping': _effects(data, fx_off, equip_index, equip_count),
    }


def parse_eff(data, resref):
    """Parse an EFF V2.0 file into {'kind': 'EFF', 'effect': {...}}."""
    _check(data, b'EFF V2.0', 0xD4)
    opcode, target, power, p1, p2, timing = _unpack('<IIIiIH', data, 0x10)
    duration, prob1, prob2, res = _unpack('<IHH8s', data, 0x28)
    dice, sides, save, save_bonus, special, school = _unpack('<iiIiII', data, 0x38)
    effect = {
        'opcode': opcode, 'target': target, 'power': power, 'p1': p1, 'p2': p2,
        'timing': timing, 'resist': _unpack('<I', data, 0x5C)[0], 'duration': duration,
        'prob1': prob1, 'prob2': prob2, 'res': _resref(res), 'dice': dice, 'sides': sides,
        'save': save, 'saveBonus': save_bonus, 'special': special, 'school': school,
        'secondary': _unpack('<I', data, 0xD0)[0],
        'res2': _resref(data[0x70:0x78]), 'res3': _resref(data[0x78:0x80]),
    }
    return {'kind': 'EFF', 'resref': resref.upper(), 'effect': effect}


def parse_pro(data, resref):
    """Parse a PRO V1.0 projectile; area-of-effect keys only for type 3."""
    _check(data, b'PRO V1.0', 0x100)
    kind, speed, flags = _unpack('<HHI', data, 0x08)
    record = {
        'kind': 'PRO', 'resref': resref.upper(), 'type': kind, 'speed': speed, 'flags': flags,
        'width': _unpack('<H', data, 0x2A)[0], 'extFlags': _unpack('<I', data, 0x2C)[0],
        'creatureValue1': _unpack('<H', data, 0x3C)[0],
        'creatureType1': _unpack('<H', data, 0x3E)[0],
        'creatureValue2': _unpack('<H', data, 0x40)[0],
        'creatureType2': _unpack('<H', data, 0x42)[0],
        'defaultSpell': _resref(data[0x44:0x4C]), 'successSpell': _resref(data[0x4C:0x54]),
    }
    if kind == 3:
        if len(data) < 0x24C:
            raise FormatError(f'area projectile truncated: {len(data)} bytes, need {0x24C}')
        record.update({
            'areaFlags': _unpack('<H', data, 0x200)[0], 'rayCount': _unpack('<H', data, 0x202)[0],
            'trigger': _unpack('<H', data, 0x204)[0], 'radius': _unpack('<H', data, 0x206)[0],
            'delay': _unpack('<H', data, 0x210)[0],
            'secondary': _unpack('<H', data, 0x214)[0], 'repeats': data[0x216],
            'explosionProjectile': _unpack('<H', data, 0x21A)[0],
            'coneWidth': _unpack('<H', data, 0x224)[0],
            'extAreaFlags': _unpack('<I', data, 0x240)[0],
            'targetDice': _unpack('<H', data, 0x244)[0],
            'targetSides': _unpack('<H', data, 0x246)[0],
        })
    return record


def parse_cre(data, resref):
    """Parse the parts of a CRE V1.0 creature the engine weighs (a summoned creature's fight):
    hit points, armour class, THAC0, attacks, saves, level, strength, IDS values, its items, the
    40 item slots (item indices, 65535 for empty; SLOTS order: weapons at 9 to 12) and the opcodes
    of its own effects."""
    _check(data, b'CRE V1.0', 0x2D4)
    slots_off, items_off, items_count = _unpack('<III', data, 0x2B8)
    _table_end(data, items_off, 20, items_count, 'item')
    _table_end(data, slots_off, 2, 40, 'slot')
    items = [_resref(data[items_off + 20 * i:items_off + 20 * i + 8]) for i in range(items_count)]
    slots = list(_unpack('<40H', data, slots_off))
    # Its own effects' opcodes (version 1 blocks of 264 bytes, else 48).
    fx_off, fx_count = _unpack('<II', data, 0x2C4)
    wide = data[0x33] == 1
    _table_end(data, fx_off, 264 if wide else 48, fx_count, 'effect')
    opcodes = [_unpack('<I', data, fx_off + 264 * i + 8)[0] if wide else _unpack('<H', data, fx_off + 48 * i)[0]
               for i in range(fx_count)]
    hp, max_hp = _unpack('<hh', data, 0x24)
    return {
        'kind': 'CRE', 'resref': resref.upper(), 'hp': hp, 'maxHp': max_hp,
        'ac': _unpack('<h', data, 0x48)[0], 'thac0': data[0x52], 'apr': data[0x53],
        'saves': {'death': data[0x54], 'wand': data[0x55], 'poly': data[0x56], 'breath': data[0x57],
                  'spell': data[0x58]},
        'level': max(data[0x234], data[0x235], data[0x236]), 'strength': data[0x238],
        'strengthExtra': data[0x239], 'ea': data[0x270], 'general': data[0x271], 'race': data[0x272],
        'class': data[0x273], 'specific': data[0x274], 'gender': data[0x275], 'alignment': data[0x27B],
        'items': items, 'slots': slots, 'opcodes': opcodes,
    }


PARSERS = {'SPL': parse_spl, 'ITM': parse_itm, 'EFF': parse_eff, 'PRO': parse_pro, 'CRE': parse_cre}


# --- command line ---------------------------------------------------------------------------

def main(argv):
    if len(argv) < 3 or argv[2] not in ('list', 'dump', 'projectiles'):
        print(__doc__, file=sys.stderr)
        return 2
    game = Game(argv[1])
    command = argv[2]
    status = 0
    if command == 'list' and len(argv) == 4:
        names = game.names(argv[3])
        print(len(names))
        print('\n'.join(names))
    elif command == 'dump' and len(argv) == 5:
        ext, resref = argv[3].upper(), argv[4]
        data = game.get(resref, ext)
        if ext not in PARSERS:
            print(f'no parser for {ext}', file=sys.stderr)
            status = 2
        elif data is None:
            print(f'{resref.upper()}.{ext} not found', file=sys.stderr)
            status = 1
        else:
            try:
                print(json.dumps(PARSERS[ext](data, resref), indent=1))
            except FormatError as err:
                print(f'{resref.upper()}.{ext}: {err}', file=sys.stderr)
                status = 1
    elif command == 'projectiles' and len(argv) == 3:
        found = projectiles(game)
        print(len(found))
        for number in sorted(found)[:10]:
            print(number, found[number])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    for problem in game.problems:
        print(f'problem: {problem}', file=sys.stderr)
    return status


if __name__ == '__main__':
    sys.exit(main(sys.argv))
