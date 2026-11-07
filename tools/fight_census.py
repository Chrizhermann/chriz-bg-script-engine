"""List the fights an installed game can make and which ones SCS already gives BGSE.

The census reads ARE, CRE, BCS and DLG resources through the shared read-only game reader.  It
does not start the game or change its files.  It gives encounter work a whole-game starting point
instead of making us discover each unhooked group one area at a time.

    python -I tools/fight_census.py <game_root> --out <folder>
"""
import argparse
import csv
import re
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import hook_rule  # noqa: E402
    import ie_resources as ie  # noqa: E402
    import scout  # noqa: E402
else:
    from . import hook_rule, ie_resources as ie, scout


SLOT_NAMES = tuple(scout.SCRIPTS)
# ARE actors store the same five creature levels in a different order, plus dialog and SPECIFIC.
ACTOR_SLOT_OFFSETS = (0x50, 0x60, 0x68, 0x58, 0x70)
CREATE_NAME = re.compile(r'\bCreateCreature[A-Za-z]*\s*\((.*?)\)', re.I | re.S)
QUOTED = re.compile(rb'"([^"]*)"')
TEXT_QUOTED = re.compile(r'"([^"]*)"')
BCS_ACTION = re.compile(rb'AC\n(\d+)OB\n(.*?)(?=AC\n|RE\n)', re.S)


def _resref(raw):
    """A script or resource resref, with the game's empty NONE spelling made empty too."""
    value = scout._resref(raw)
    return '' if value == 'NONE' else value


def _text(raw):
    return raw.split(b'\0')[0].decode('latin-1', 'replace')


def campaign(area):
    """The campaign bucket requested for an area resref."""
    prefix = area[:2].upper()
    return {'BG': 'BG1', 'BD': 'Siege of Dragonspear', 'AR': 'BG2 and ToB',
            'OH': 'EE NPC content'}.get(prefix, prefix or 'other')


def _ids(game, name):
    return scout._ids(game, name)


def _scripts(data, offsets):
    return tuple(_resref(data[offset:offset + 8]) for offset in offsets)


def creature(data, resref, tlk):
    """The CRE details the census needs; a malformed table leaves a visible error, not a missing row."""
    row = {'resref': resref.upper(), 'name': '', 'ea': '', 'allegiance': '', 'hostile': '',
           'class': '', 'class_id': '', 'level': '',
           'race': '', 'race_id': '', 'int': '', 'wis': '', 'hp': '', 'max_hp': '',
           'scripts': ('', '', '', '', ''), 'dialog': '', 'error': ''}
    if not data:
        row['error'] = 'not in this game'
        return row
    if len(data) < 0x2D4 or data[:8] != b'CRE V1.0':
        row['error'] = 'not a CRE V1.0 file'
        return row
    row.update({'name': tlk.text(struct.unpack_from('<I', data, 0x08)[0]), 'ea': data[0x270],
                'class_id': data[0x273], 'race_id': data[0x272],
                'int': data[0x23A], 'wis': data[0x23B],
                'scripts': _scripts(data, range(0x248, 0x270, 8)),
                'dialog': _resref(data[0x2CC:0x2D4])})
    try:
        parsed = ie.parse_cre(data, resref)
        row['level'], row['hp'], row['max_hp'] = parsed['level'], parsed['hp'], parsed['maxHp']
    except ie.FormatError as err:
        # Header metadata remains useful when a file's optional tables are damaged.
        row['level'] = max(data[0x234], data[0x235], data[0x236])
        row['hp'], row['max_hp'] = struct.unpack_from('<hh', data, 0x24)
        row['error'] = str(err)
    return row


def _script_status(data):
    """The installer rule, with hook_rule's family names rather than a second family matcher."""
    if data and b'castspell' in data and b'DMWW_' in data:
        family = hook_rule.family(data.decode('latin-1'))
        return 'scs', family or 'monster'
    return 'other', ''


def _effective_status(scripts, script_statuses):
    statuses = [script_statuses.get(script, ('other', '')) for script in scripts if script]
    hooked = [family for kind, family in statuses if kind == 'scs']
    return ('scs', hooked[0]) if hooked else ('other', '')


def _area_rows(game, tlk, catalogue, script_statuses, classes, races, allegiances, problems):
    """Rows for every placed actor and spawn point, using embedded actor CREs when present."""
    rows = []
    for area in game.names('ARE'):
        data = game.get(area, 'ARE')
        if not data or data[:8] != b'AREAV1.0' or len(data) < 0x68:
            problems.append(f'{area}.ARE is not an ARE V1.0 file')
            continue
        actor_at, actor_count = struct.unpack_from('<IH', data, 0x54)
        if actor_at + actor_count * 0x110 > len(data):
            problems.append(f'{area}.ARE actor table runs past the file')
        else:
            for number in range(actor_count):
                at = actor_at + number * 0x110
                cre_ref = _resref(data[at + 0x80:at + 0x88])
                embedded_at, embedded_size = struct.unpack_from('<II', data, at + 0x88)
                embedded = (embedded_at and embedded_size and embedded_at + embedded_size <= len(data) and
                            data[embedded_at:embedded_at + 8] == b'CRE V1.0')
                if embedded:
                    info = creature(data[embedded_at:embedded_at + embedded_size], cre_ref, tlk)
                else:
                    info = catalogue.get(cre_ref)
                    if info is None:
                        info = creature(game.get(cre_ref, 'CRE'), cre_ref, tlk)
                if not info['class']:
                    # Embedded CREs are not files in the catalogue, but deserve the same readable fields.
                    info = dict(info)
                    info['class'] = classes.get(info['class_id'], str(info['class_id'])) if info['class_id'] != '' else ''
                    info['race'] = races.get(info['race_id'], str(info['race_id'])) if info['race_id'] != '' else ''
                    info['allegiance'] = (allegiances.get(info['ea'], str(info['ea']))
                                          if info['ea'] != '' else '')
                    info['hostile'] = 'yes' if isinstance(info['ea'], int) and info['ea'] >= 200 else 'no'
                actor_scripts = _scripts(data, (at + offset for offset in ACTOR_SLOT_OFFSETS))
                effective = tuple(actor or base for actor, base in zip(actor_scripts, info['scripts']))
                changed = [f'{name}={script}' for name, script in zip(SLOT_NAMES, actor_scripts) if script]
                kind, family = _effective_status(effective, script_statuses)
                rows.append({'area': area, 'campaign': campaign(area), 'kind': 'actor', 'entry': number + 1,
                             'name': _text(data[at:at + 32]), 'cre_resrefs': cre_ref,
                             'embedded_cre': 'yes' if embedded else '', 'max_spawns': '',
                             'actor_script_overrides': '; '.join(changed),
                             'effective_scripts': '; '.join(s for s in effective if s),
                             'dialog': _resref(data[at + 0x48:at + 0x50]) or info['dialog'],
                             'creature_name': info['name'], 'ea': info['ea'], 'allegiance': info['allegiance'],
                             'class': info['class'],
                             'level': info['level'], 'race': info['race'], 'int': info['int'], 'wis': info['wis'],
                             'hp': info['hp'], 'max_hp': info['max_hp'],
                             'hostile': 'yes' if isinstance(info['ea'], int) and info['ea'] >= 200 else 'no',
                             'hook': kind, 'family': family, '_info': info, '_scripts': effective})
        spawn_at, spawn_count = struct.unpack_from('<II', data, 0x60)
        if spawn_at + spawn_count * 0xC8 > len(data):
            problems.append(f'{area}.ARE spawn table runs past the file')
            continue
        for number in range(spawn_count):
            at = spawn_at + number * 0xC8
            table_count = struct.unpack_from('<H', data, at + 0x74)[0]
            if table_count > 10:
                problems.append(f'{area}.ARE spawn {number + 1} has {table_count} creature entries (maximum 10)')
            refs = [_resref(data[at + 0x24 + 8 * i:at + 0x2C + 8 * i])
                    for i in range(min(table_count, 10))]
            refs = [ref for ref in refs if ref]
            rows.append({'area': area, 'campaign': campaign(area), 'kind': 'spawn', 'entry': number + 1,
                         'name': _text(data[at:at + 32]), 'cre_resrefs': '; '.join(refs),
                         'embedded_cre': '', 'max_spawns': struct.unpack_from('<H', data, at + 0xAC)[0],
                         'actor_script_overrides': '', 'effective_scripts': '', 'dialog': '', 'hostile': '',
                         'creature_name': '', 'ea': '', 'allegiance': '', 'class': '', 'level': '', 'race': '',
                         'int': '', 'wis': '',
                         'hp': '', 'max_hp': '', 'hook': '', 'family': '', '_refs': refs})
    return rows


def _create_actions(game):
    """Every CreateCreature-family call whose quoted string resolves to a CRE resource."""
    actions = {number for number, name in _ids(game, 'ACTION').items()
               if name.upper().startswith('CREATECREATURE')}
    created = []
    for name in game.names('BCS'):
        data = game.get(name, 'BCS') or b''
        for match in BCS_ACTION.finditer(data):
            if int(match.group(1)) not in actions:
                continue
            for raw in QUOTED.findall(match.group(2)):
                resref = raw.decode('latin-1').upper()
                if resref and game.get(resref, 'CRE') is not None:
                    created.append((resref, f'BCS:{name}'))
    for name in game.names('DLG'):
        data = game.get(name, 'DLG') or b''
        if data[:8] != b'DLG V1.0' or len(data) < 0x30:
            continue
        table_at, count = struct.unpack_from('<II', data, 0x28)
        if table_at + 8 * count > len(data):
            continue
        for index in range(count):
            action_at, action_size = struct.unpack_from('<II', data, table_at + 8 * index)
            if action_at + action_size > len(data):
                continue
            text = data[action_at:action_at + action_size].decode('latin-1', 'replace')
            for call in CREATE_NAME.finditer(text):
                for quoted in TEXT_QUOTED.findall(call.group(1)):
                    resref = quoted.upper()
                    if resref and game.get(resref, 'CRE') is not None:
                        created.append((resref, f'DLG:{name}'))
    return created


def census(game, tlk):
    """Collect the CSV rows and the occurrence records which the summary counts."""
    problems = []
    catalogue = {resref: creature(game.get(resref, 'CRE'), resref, tlk) for resref in game.names('CRE')}
    script_statuses = {}
    for name in game.names('BCS'):
        script_statuses[name] = _script_status(game.get(name, 'BCS'))
    created = _create_actions(game)
    created_by = defaultdict(list)
    for resref, source in created:
        created_by[resref].append(source)
    classes, races, allegiances = _ids(game, 'CLASS'), _ids(game, 'RACE'), _ids(game, 'EA')
    for row in catalogue.values():
        row['class'] = classes.get(row['class_id'], str(row['class_id'])) if row['class_id'] != '' else ''
        row['race'] = races.get(row['race_id'], str(row['race_id'])) if row['race_id'] != '' else ''
        row['allegiance'] = allegiances.get(row['ea'], str(row['ea'])) if row['ea'] != '' else ''
        row['hostile'] = 'yes' if isinstance(row['ea'], int) and row['ea'] >= 200 else 'no'
        row['hook'], row['family'] = _effective_status(row['scripts'], script_statuses)
        row['script_created_by'] = '; '.join(dict.fromkeys(created_by[row['resref']]))
        row['script_create_count'] = len(created_by[row['resref']])
    areas = _area_rows(game, tlk, catalogue, script_statuses, classes, races, allegiances, problems)
    occurrences = []
    for row in areas:
        if row['kind'] == 'actor':
            occurrences.append(dict(row['_info'], area=row['area'], campaign=row['campaign'], source='placed actor',
                                    hook=row['hook'], family=row['family'], scripts=row['_scripts']))
        else:
            for resref in dict.fromkeys(row['_refs']):
                info = catalogue.get(resref)
                if info:
                    occurrences.append(dict(info, area=row['area'], campaign=row['campaign'], source='spawn creature choice',
                                            scripts=info['scripts']))
    for resref, source in created:
        info = catalogue.get(resref)
        if info:
            occurrences.append(dict(info, area='', campaign='script-created', source='script-created action',
                                    creation_source=source, scripts=info['scripts']))
    return {'areas': areas, 'creatures': catalogue, 'occurrences': occurrences,
            'created': created, 'problems': problems + game.problems}


def _count(rows, field, value):
    return sum(1 for row in rows if row.get(field) == value)


def _summary(data):
    """A small plain-language report; placements are counted, never guessed from runtime conditions."""
    occurrences = [row for row in data['occurrences'] if isinstance(row['ea'], int) and row['ea'] >= 200]
    actors = [row for row in occurrences if row['source'] == 'placed actor']
    spawn_choices = [row for row in occurrences if row['source'] == 'spawn creature choice']
    made = [row for row in occurrences if row['source'] == 'script-created action']
    spawn_entries = []
    for row in data['areas']:
        if row['kind'] != 'spawn':
            continue
        options = [next((item for item in spawn_choices if item['area'] == row['area'] and
                         item['resref'] == ref), None) for ref in dict.fromkeys(row['_refs'])]
        options = [item for item in options if item]
        if options:
            labels = {item['hook'] for item in options}
            spawn_entries.append('mixed' if len(labels) > 1 else next(iter(labels)))
    lines = ['# Fight census', '', 'This is a static read of the installed resources.  A placed actor or a possible '
             'spawn may still be gated by schedule, story or script conditions.', '']
    lines.append(f'Hostile placed actors: {len(actors)} ({_count(actors, "hook", "scs")} SCS, '
                 f'{_count(actors, "hook", "other")} other).')
    lines.append(f'Hostile spawn entries: {len(spawn_entries)} ({spawn_entries.count("scs")} SCS-only, '
                 f'{spawn_entries.count("other")} other-only, {spawn_entries.count("mixed")} mixed); their '
                 f'{len(spawn_choices)} creature choices are {_count(spawn_choices, "hook", "scs")} SCS and '
                 f'{_count(spawn_choices, "hook", "other")} other.')
    lines.append(f'Hostile script-created creatures: {len(made)} ({_count(made, "hook", "scs")} SCS, '
                 f'{_count(made, "hook", "other")} other).')
    lines += ['', '## Hostile placement records by campaign, source and SCS family', '',
              '| Campaign | Source | Hook | Family | Records |', '| --- | --- | --- | --- | ---: |']
    grouped = Counter((row['campaign'], row['source'], row['hook'], row['family'] or '-') for row in occurrences)
    for (where, source, hook, family), count in sorted(grouped.items()):
        lines.append(f'| {where} | {source} | {hook} | {family} | {count} |')

    other = [row for row in occurrences if row['hook'] == 'other']
    scripts = defaultdict(lambda: {'count': 0, 'examples': []})
    for row in other:
        for script in dict.fromkeys(script for script in row['scripts'] if script):
            scripts[script]['count'] += 1
            example = row['resref']
            if example not in scripts[script]['examples'] and len(scripts[script]['examples']) < 3:
                scripts[script]['examples'].append(example)
    lines += ['', '## Scripts on the most other hostile creatures', '',
              '| Script | Creatures | Examples |', '| --- | ---: | --- |']
    for script, item in sorted(scripts.items(), key=lambda pair: (-pair[1]['count'], pair[0]))[:60]:
        lines.append(f'| {script} | {item["count"]} | {", ".join(item["examples"])} |')

    by_area = Counter(row['area'] for row in other if row['area'])
    lines += ['', '## Areas with the most other hostile creatures', '', '| Area | Campaign | Creatures |',
              '| --- | --- | ---: |']
    for area, count in sorted(by_area.items(), key=lambda pair: (-pair[1], pair[0]))[:40]:
        lines.append(f'| {area} | {campaign(area)} | {count} |')

    classes = {'mage': 'MAGE', 'cleric': 'CLERIC', 'druid': 'DRUID'}
    for label, wanted in list(classes.items()) + [('level 10 and above', None)]:
        selected = [row for row in other if (row['class'] == wanted if wanted else row['level'] >= 10)]
        listed = defaultdict(lambda: {'count': 0, 'name': '', 'level': '', 'class': '', 'examples': []})
        for row in selected:
            item = listed[row['resref']]
            item['count'] += 1
            item['name'], item['level'], item['class'] = row['name'], row['level'], row['class']
            place = row.get('area') or row.get('creation_source', '')
            if place and place not in item['examples'] and len(item['examples']) < 3:
                item['examples'].append(place)
        lines += [f'', f'## Other hostile {label}s', '']
        if not listed:
            lines.append('None.')
            continue
        lines += ['| Creature | Name | Class | Level | Records | Examples |', '| --- | --- | --- | ---: | ---: | --- |']
        for resref, item in sorted(listed.items()):
            lines.append(f'| {resref} | {item["name"]} | {item["class"]} | {item["level"]} | '
                         f'{item["count"]} | {", ".join(item["examples"])} |')
    if data['problems']:
        lines += ['', '## Files the reader could not fully use', '']
        lines += [f'- {problem}' for problem in dict.fromkeys(data['problems'])]
    lines += ['', 'The census cannot see creatures made by unquoted, indirect or runtime-generated actions, '
              'by external code, or by a script that changes a creature after it appears.']
    return '\n'.join(lines) + '\n'


def write(data, out):
    """Write the three promised reports, leaving every game resource alone."""
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    area_fields = ['area', 'campaign', 'kind', 'entry', 'name', 'cre_resrefs', 'embedded_cre', 'max_spawns',
                   'actor_script_overrides', 'effective_scripts', 'dialog', 'creature_name', 'ea', 'allegiance', 'class', 'level',
                   'race', 'int', 'wis', 'hp', 'max_hp', 'hostile', 'hook', 'family']
    with (out / 'areas.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=area_fields)
        writer.writeheader()
        for row in data['areas']:
            writer.writerow({field: row[field] for field in area_fields})
    creature_fields = ['resref', 'name', 'ea', 'allegiance', 'hostile', 'class', 'class_id', 'level', 'race', 'race_id', 'int', 'wis',
                       'hp', 'max_hp', *[f'{name}_script' for name in SLOT_NAMES], 'dialog', 'hook', 'family',
                       'script_create_count', 'script_created_by', 'error']
    with (out / 'creatures.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=creature_fields)
        writer.writeheader()
        for resref in sorted(data['creatures']):
            row = dict(data['creatures'][resref])
            row.update({f'{name}_script': script for name, script in zip(SLOT_NAMES, row['scripts'])})
            writer.writerow({field: row.get(field, '') for field in creature_fields})
    (out / 'summary.md').write_text(_summary(data), encoding='utf-8', newline='')


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('game_root', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args(argv[1:])
    try:
        if args.out.resolve().is_relative_to(args.game_root.resolve()):
            parser.error('--out must be outside the game folder')
    except OSError as err:
        parser.error(f'cannot resolve paths: {err}')
    game = ie.Game(args.game_root)
    data = census(game, scout.Tlk(args.game_root))
    write(data, args.out)
    for problem in dict.fromkeys(data['problems']):
        print(f'problem: {problem}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
