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
                       'orders': Counter(), 'pauses': 0}
            continue
        if current is None:
            continue
        if kind == 'act':
            current['orders'][row.get('member', '?')] += 1
        elif kind == 'pause':
            current['pauses'] += 1
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
        if ending is None:
            print(f"Fight {current['number']}: open; foes {foes}; reloads before {current['reloads']}")
            continue
        length = ending.get('length', 0)
        print(f"Fight {current['number']}: {length} ticks ({length / 15:.1f}s); foes {foes}")
        orders = ', '.join(f'{name} {count}' for name, count in sorted(current['orders'].items())) or 'none'
        print(f"  orders: {orders}; pauses: {current['pauses']}; reloads before: {current['reloads']}")
        print(f"  spent: {describe_spent(ending.get('spent'))}")
        dead = ', '.join(ending.get('dead', [])) or 'none'
        foes_dead = ', '.join(ending.get('foesDead', [])) or 'none'
        print(f"  party dead: {dead}; foes dead: {foes_dead}; end: {ending.get('reason', 'unknown')}")


if __name__ == '__main__':
    main()
