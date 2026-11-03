"""Scout creatures for encounter building, read-only: who each one is, its scores, its spells and items
by name, its scripts and dialog, SCS's random items and, with --where, where it stands. One command
instead of looking each thing up again (Christopher, 2026-11-04: building encounters gets faster each
time). See docs/ENCOUNTERS.md.

    python -I tools/scout.py <game_root> NEIRA [KARLAT ...] [--where]

--where also lists the areas whose actors use the creature, where the starting game's NPC list puts it
(BG1's joinable NPCs, such as Garrick, stand only there) and the scripts and dialogs that name it; it
reads every area, script and dialog, so it takes a while.
"""
import struct
import sys
from pathlib import Path

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import ie_resources as ie  # noqa: E402
else:
    from . import ie_resources as ie

# The 38 item slots of a CRE V1.0 file, in the order of its slot table (IESDP).
SLOTS = (['helmet', 'armor', 'shield', 'gloves', 'left ring', 'right ring', 'amulet', 'belt', 'boots'] +
         [f'weapon {i}' for i in range(1, 5)] + [f'quiver {i}' for i in range(1, 5)] + ['cloak'] +
         [f'quick item {i}' for i in range(1, 4)] + [f'pack {i}' for i in range(1, 17)] + ['magic weapon'])
KINDS = {0: 'priest', 1: 'wizard', 2: 'innate'}
SCRIPTS = ['override', 'class', 'race', 'general', 'default']
# CLASS.IDS values of multiclass creatures, which use more than the first level field.
MULTI = {7, 8, 9, 10, 13, 14, 15, 16, 17, 18}


class Tlk:
    """The game's dialog.tlk (English first), for names; empty when there is none."""

    def __init__(self, root):
        path = ie._resolve(root, 'lang/en_us/dialog.tlk') or ie._resolve(root, 'dialog.tlk')
        self.data = path.read_bytes() if path is not None and path.is_file() else b''
        self.count, self.start = struct.unpack_from('<II', self.data, 0x0A) if len(self.data) >= 0x12 else (0, 0)

    def text(self, ref):
        if not 0 <= ref < self.count:
            return ''
        _, _, _, _, offset, length = struct.unpack_from('<H8sIIII', self.data, 0x12 + 26 * ref)
        return self.data[self.start + offset:self.start + offset + length].decode('latin-1', 'replace')


def _resref(raw):
    return raw.split(b'\0')[0].decode('latin-1').upper()


def _ids(game, name):
    """An IDS file as {number: symbol}."""
    out = {}
    for line in (game.text(name, 'IDS') or '').splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            try:
                out.setdefault(int(parts[0], 0), parts[1])
            except ValueError:
                pass
    return out


def spell_name(game, tlk, resref):
    data = game.get(resref, 'SPL')
    if not data or len(data) < 0x0C or data[:4] != b'SPL ':
        return '(not in this game)'
    return tlk.text(struct.unpack_from('<I', data, 0x08)[0]) or '(no name)'


def item_name(game, tlk, resref):
    data = game.get(resref, 'ITM')
    if not data or len(data) < 0x10 or data[:4] != b'ITM ':
        return '(not in this game)'
    named, general = struct.unpack_from('<I', data, 0x0C)[0], struct.unpack_from('<I', data, 0x08)[0]
    return tlk.text(named) or tlk.text(general) or '(no name)'


def random_rows(game):
    """The game's random treasure table (RNDTRES.2DA): {row name in capitals: [entries]}, '*' left out."""
    rows = {}
    for line in (game.text('RNDTRES', '2DA') or '').splitlines()[3:]:
        parts = line.split()
        if len(parts) >= 2:
            rows[parts[0].upper()] = [p for p in parts[1:] if p != '*']
    return rows


def _draw(game, tlk, entries):
    """What a random item may become, with its odds: SCS's placeholders swap for one entry of their row."""
    out = []
    for entry in dict.fromkeys(entries):
        share = entries.count(entry)
        resref, _, times = entry.partition('*')
        label = 'nothing' if resref.upper() == 'DW#BLANK' else f'{resref.upper()} "{item_name(game, tlk, resref)}"'
        out.append(f'{share}/{len(entries)} {times + "x " if times else ""}{label}')
    return out


def scout(game, tlk, resref, where=False):
    """The lines that describe creature resref."""
    resref = resref.upper()
    data = game.get(resref, 'CRE')
    if not data:
        return [f'{resref}: not in this game']
    if len(data) < 0x2D4 or data[:8] != b'CRE V1.0':
        return [f'{resref}: not a CRE V1.0 file']
    cls, race, align, ea = _ids(game, 'CLASS'), _ids(game, 'RACE'), _ids(game, 'ALIGNMEN'), _ids(game, 'EA')
    out = [f'{resref} "{tlk.text(struct.unpack_from("<I", data, 0x08)[0])}"']
    kit = struct.unpack_from('<H', data, 0x246)[0]
    levels = (f'levels {data[0x234]}/{data[0x235]}/{data[0x236]}' if data[0x273] in MULTI
              else f'level {data[0x234]}')
    out.append(f'  {cls.get(data[0x273], data[0x273])} {levels}'
               f'{f" kit {kit:#x}" if kit else ""}, {race.get(data[0x272], data[0x272])}, '
               f'{align.get(data[0x27B], data[0x27B])}, {ea.get(data[0x270], data[0x270])}')
    hp, max_hp = struct.unpack_from('<hh', data, 0x24)
    out.append(f'  HP {hp}/{max_hp}, AC {struct.unpack_from("<h", data, 0x48)[0]} in the file (its armour counts in '
               f'the game), THAC0 {data[0x52]}, '
               f'attacks {data[0x53]}, saves death {data[0x54]} wand {data[0x55]} poly {data[0x56]} '
               f'breath {data[0x57]} spell {data[0x58]}')
    strength = f'{data[0x238]}/{data[0x239]:02d}' if data[0x239] else f'{data[0x238]}'
    out.append(f'  STR {strength} INT {data[0x23A]} WIS {data[0x23B]} DEX {data[0x23C]} CON {data[0x23D]} '
               f'CHA {data[0x23E]}')
    scripts = [f'{label} {_resref(data[o:o + 8])}' for label, o in zip(SCRIPTS, range(0x248, 0x270, 8))
               if _resref(data[o:o + 8]) not in ('', 'NONE')]
    out.append(f'  scripts: {", ".join(scripts) or "none"}; dialog {_resref(data[0x2CC:0x2D4]) or "none"}; '
               f'death variable {_resref(data[0x280:0x2A0]) or "none"}')
    known_at, known_count, info_at, info_count, mem_at, mem_count = struct.unpack_from('<IIIIII', data, 0x2A0)
    memorized = set()
    lines = []
    for i in range(info_count):
        o = info_at + 16 * i
        if o + 16 > len(data):
            break
        level, slots, _, kind, first, many = struct.unpack_from('<HHHHII', data, o)
        names = []
        for j in range(first, first + many):
            if mem_at + 12 * j + 12 <= len(data):
                spell = _resref(data[mem_at + 12 * j:mem_at + 12 * j + 8])
                memorized.add(spell)
                names.append(f'{spell_name(game, tlk, spell)} {spell}')
        if names:
            lines.append(f'    {KINDS.get(kind, kind)} {level + 1} ({slots} slots in the file): {", ".join(names)}')
    out.append('  memorized:' if lines else '  memorized: none')
    out += lines
    spare = sorted({_resref(data[known_at + 12 * i:known_at + 12 * i + 8]) for i in range(known_count)
                    if known_at + 12 * i + 12 <= len(data)} - memorized)
    if spare:
        out.append(f'  known, not memorized: {", ".join(f"{spell_name(game, tlk, s)} {s}" for s in spare)}')
    slot_at, item_at, item_count = struct.unpack_from('<III', data, 0x2B8)
    words = struct.unpack_from('<40H', data, slot_at) if slot_at + 80 <= len(data) else (0xFFFF,) * 40
    rows = random_rows(game)
    lines = []
    # Each item by its slot, then those no slot names (carried, but out of view in the inventory).
    placed = [(SLOTS[slot], word) for slot, word in enumerate(words[:38]) if word < item_count]
    taken = {word for _, word in placed}
    placed += [('no slot', word) for word in range(item_count) if word not in taken]
    for label, word in placed:
        if item_at + 20 * word + 20 > len(data):
            continue
        o = item_at + 20 * word
        item = _resref(data[o:o + 8])
        charges = struct.unpack_from('<HHH', data, o + 10)
        flags = struct.unpack_from('<I', data, o + 16)[0]
        notes = [f'charges {"/".join(map(str, charges))}'] if any(charges) else []
        if flags & 8:
            notes.append('undroppable')
        lines.append(f'    {label}: {item} "{item_name(game, tlk, item)}"{" (" + ", ".join(notes) + ")" if notes else ""}')
        if item in rows:
            lines.append(f'      a random item, drawn when the game creates the creature: {"; ".join(_draw(game, tlk, rows[item]))}')
    out.append('  items:' if lines else '  items: none')
    out += lines
    fx_at, fx_count = struct.unpack_from('<II', data, 0x2C4)
    wide = data[0x33] == 1
    stats = _ids(game, 'STATS')
    effects = []
    for i in range(fx_count):
        o = fx_at + (264 if wide else 48) * i
        if wide and o + 0x30 <= len(data):
            opcode, p1, p2 = struct.unpack_from('<I', data, o + 8)[0], *struct.unpack_from('<ii', data, o + 0x14)
            res = _resref(data[o + 0x28:o + 0x30])
        elif not wide and o + 0x1C <= len(data):
            opcode, p1, p2 = struct.unpack_from('<H', data, o)[0], *struct.unpack_from('<ii', data, o + 4)
            res = _resref(data[o + 0x14:o + 0x1C])
        else:
            break
        # A weapon proficiency (opcode 233) is named: parameter 1 its stars, parameter 2 the proficiency.
        named = f' ({stats[p2]})' if opcode == 233 and p2 in stats else ''
        effects.append(f'op{opcode} {p1}/{p2}{named}{" " + res if res else ""}')
    out.append(f'  its own effects: {", ".join(effects) or "none"}')
    if where:
        out += [f'  {line}' for line in places(game, resref)]
    return out


def listed(game, resref):
    """Where the starting game's NPC list (BALDUR.GAM, GAME V2.0: party and other NPCs, 0x160 bytes each) puts
    creature resref: BG1's joinable NPCs stand where it says, not in any area file or script (Garrick in
    Beregost, encounter lab 2026-11-04). An entry names its creature file; once a save holds its own copy of
    the creature, as '*' and the name from its second letter on, and that copy has to carry the same death
    variable when the file has one."""
    data = game.get('BALDUR', 'GAM')
    if not data or data[:8] != b'GAMEV2.0' or len(data) < 0x38:
        return []
    cre = game.get(resref, 'CRE') or b''
    dv = _resref(cre[0x280:0x2A0]) if cre[:8] == b'CRE V1.0' and len(cre) >= 0x2A0 else ''
    out = []
    for offset, count in (struct.unpack_from('<II', data, 0x20), struct.unpack_from('<II', data, 0x30)):
        for i in range(count):
            a = offset + 0x160 * i
            if a + 0x160 > len(data):
                break
            if _resref(data[a + 0x0C:a + 0x14]) not in (resref, '*' + resref[1:]):
                continue
            at, size = struct.unpack_from('<II', data, a + 0x04)
            copy = data[at:at + size]
            if dv and len(copy) >= 0x2A0 and _resref(copy[0x280:0x2A0]) != dv:
                continue
            x, y = struct.unpack_from('<HH', data, a + 0x20)
            out.append(f'listed in BALDUR.GAM\'s NPC list: in {_resref(data[a + 0x18:a + 0x20])} at ({x}.{y})')
    return out


def places(game, resref):
    """Where creature resref stands: area actors that use it, the starting game's NPC list, and scripts and
    dialogs that name it."""
    out = []
    for area in game.names('ARE'):
        data = game.get(area, 'ARE')
        if not data or data[:8] != b'AREAV1.0' or len(data) < 0x9C:
            continue
        at, count = struct.unpack_from('<IH', data, 0x54)
        for i in range(count):
            a = at + 0x110 * i
            if a + 0x110 > len(data):
                break
            if _resref(data[a + 0x80:a + 0x88]) == resref:
                x, y = struct.unpack_from('<HH', data, a + 0x20)
                name = data[a:a + 32].split(b'\0')[0].decode('latin-1')
                out.append(f'stands in {area} as "{name}" at ({x}.{y}); area script {_resref(data[0x94:0x9C]) or "none"}')
    out += listed(game, resref)
    needle = f'"{resref}"'.encode('ascii')
    for ext in ('BCS', 'DLG'):
        named = [name for name in game.names(ext) if needle in (game.get(name, ext) or b'').upper()]
        if named:
            out.append(f'named in {ext}: {", ".join(named)}')
    return out or ['stands in no area, no NPC list, and no script or dialog names it']


def main(argv):
    args = [a for a in argv[1:] if not a.startswith('--')]
    if len(args) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    game = ie.Game(args[0])
    tlk = Tlk(args[0])
    for resref in args[1:]:
        print('\n'.join(scout(game, tlk, resref, '--where' in argv)))
    for problem in game.problems:
        print(f'problem: {problem}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
