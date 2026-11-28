"""Print compact per-fight summaries from a BGSE playtest JSONL recording."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def describe_spent(spent):
    pieces = []
    for member in spent or []:
        uses = []
        for spell in member.get('spells', []):
            uses.append(f"{spell.get('resref', '?')} x{spell.get('count', 0)}")
        for item in member.get('items', []):
            counts = '/'.join(str(value) for value in item.get('uses', []) if value)
            uses.append(f"{item.get('resref', '?')} x{counts or '1'}")
        if uses:
            pieces.append(f"{member.get('name', '?')}: " + ', '.join(uses))
    return '; '.join(pieces) or 'none'


def read_rows(path: Path):
    for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f'{path}:{number}: invalid JSON: {exc.msg}') from exc
        if not isinstance(row, dict):
            raise SystemExit(f'{path}:{number}: row is not an object')
        yield row


def summarize(rows):
    reloads = 0
    current = None
    fight_number = 0
    for row in rows:
        kind = row.get('k')
        if kind == 'load':
            reloads += 1
        if kind == 'fight' and row.get('phase') == 'start':
            fight_number += 1
            current = {'number': fight_number, 'start': row, 'reloads': reloads,
                       'orders': Counter(), 'pauses': 0, 'joined': [], 'eng': Counter(),
                       'moved': Counter(), 'last_pos': {}, 'last_hp': {}, 'damage_taken': Counter(),
                       'pos_frames': 0}
            for member in row.get('members', []):
                name = member.get('name')
                if name and 'x' in member and 'y' in member:
                    current['last_pos'][name] = (member['x'], member['y'])
                if name and 'hp' in member:
                    current['last_hp'][name] = member['hp']
            continue
        if current is None:
            continue
        if kind == 'act':
            current['orders'][row.get('member', '?')] += 1
        elif kind == 'pause':
            current['pauses'] += 1
        elif kind == 'foes':
            current['joined'].extend(row.get('foes', []))
        elif kind == 'eng':
            tag = row.get('tag', '?')
            sub = row.get('row', {}).get('kind') if isinstance(row.get('row'), dict) else None
            key = f'{tag}:{sub}' if sub else tag
            current['eng'][key] += 1
        elif kind == 'pos':
            current['pos_frames'] += 1
            for member in row.get('party', []):
                name = member.get('name')
                if not name:
                    continue
                if 'x' in member and 'y' in member:
                    px, py = member['x'], member['y']
                    prev = current['last_pos'].get(name)
                    if prev is not None:
                        dx, dy = px - prev[0], py - prev[1]
                        current['moved'][name] += int(round((dx * dx + dy * dy) ** 0.5))
                    current['last_pos'][name] = (px, py)
                if 'hp' in member:
                    hp = member['hp']
                    prev_hp = current['last_hp'].get(name)
                    if prev_hp is not None and hp < prev_hp:
                        current['damage_taken'][name] += prev_hp - hp
                    current['last_hp'][name] = hp
        elif kind == 'fight' and row.get('phase') == 'end':
            yield current, row
            current = None
    if current is not None:
        yield current, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recording', type=Path)
    args = parser.parse_args()
    for current, ending in summarize(read_rows(args.recording)):
        start = current['start']
        foes = ', '.join(foe.get('name') or foe.get('resref', '?') for foe in start.get('foes', [])) or 'none recorded'
        joined = current['joined']
        joined_text = ''
        if joined:
            joined_names = ', '.join(foe.get('name') or foe.get('resref', '?') for foe in joined)
            joined_text = f' (+{len(joined)} joined: {joined_names})'
        if ending is None:
            print(f"Fight {current['number']}: open; foes {foes}{joined_text}; reloads before {current['reloads']}")
            continue
        length = ending.get('length', 0)
        print(f"Fight {current['number']}: {length} ticks ({length / 15:.1f}s); foes {foes}{joined_text}")
        orders = ', '.join(f'{name} {count}' for name, count in sorted(current['orders'].items())) or 'none'
        print(f"  orders: {orders}; pauses: {current['pauses']}; reloads before: {current['reloads']}")
        print(f"  spent: {describe_spent(ending.get('spent'))}")
        if current['pos_frames'] > 0:
            moved = ', '.join(f"{name} {dist}px" for name, dist in sorted(current['moved'].items()) if dist > 0) or 'none'
            dmg = ', '.join(f"{name} -{hp}" for name, hp in sorted(current['damage_taken'].items()) if hp > 0) or 'none'
            print(f"  move: {moved}; damage taken: {dmg} ({current['pos_frames']} pos frames)")
        if current['eng']:
            eng = ', '.join(f'{k} {v}' for k, v in sorted(current['eng'].items()))
            print(f"  engine: {eng}")
        dead = ', '.join(ending.get('dead', [])) or 'none'
        foes_dead = ', '.join(ending.get('foesDead', [])) or 'none'
        print(f"  party dead: {dead}; foes dead: {foes_dead}; end: {ending.get('reason', 'unknown')}")


if __name__ == '__main__':
    main()
