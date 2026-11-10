"""Read a lab profile of the runtime (profLab.lua: prof-funcs.txt and prof-lines.txt, each line "seconds samples
source:line"; prof-incl.txt, when there, the same by function with the time of what it calls) against the bundle
it ran: which module and function each line belongs to, and the shares of time.

    python -I tools/prof_read.py <M_BGSE.lua> <folder-with-prof-files> [top]

Seconds are processor time by a millisecond clock, added up over many samples: read shares, not totals.
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

FACTORY = re.compile(r'^factories\["([^"]+)"\]=function\(require\)')


def modules(bundle):
    """(first line, module name) of each module in the bundle, in order; lines count from 1."""
    return [(i, m.group(1)) for i, line in enumerate(bundle, 1) for m in [FACTORY.match(line)] if m]


def owner(starts, line):
    name, first = '?', 0
    for at, module in starts:
        if at > line:
            break
        name, first = module, at
    return name, first


def read(path):
    rows = []
    for text in Path(path).read_text(encoding='utf-8', errors='replace').splitlines():
        seconds, samples, key = text.split(' ', 2)
        source, _, line = key.rpartition(':')
        rows.append((float(seconds), int(samples), source, int(line) if line.lstrip('-').isdigit() else -1))
    return rows


def main(argv):
    bundle = Path(argv[1]).read_text(encoding='utf-8').splitlines()
    folder = Path(argv[2])
    top = int(argv[3]) if len(argv) > 3 else 40
    starts = modules(bundle)
    funcs, lines = read(folder / 'prof-funcs.txt'), read(folder / 'prof-lines.txt')
    total = sum(r[0] for r in funcs) or 1.0
    ours = lambda source: 'BGSE' in source.upper()  # noqa: E731
    by_module, by_source = defaultdict(float), defaultdict(float)
    for seconds, _, source, line in funcs:
        by_source[source] += seconds
        if ours(source):
            by_module[owner(starts, line)[0]] += seconds
    print(f'samples {sum(r[1] for r in funcs)}, seconds {total:.2f}')
    print('by source:', ', '.join(f'{s} {v / total:.0%}' for s, v in sorted(by_source.items(), key=lambda kv: -kv[1])[:8]))
    print('by module:')
    for module, seconds in sorted(by_module.items(), key=lambda kv: -kv[1])[:20]:
        print(f'  {seconds / total:6.1%} {seconds:7.2f}s {module}')
    print('by function:')
    for seconds, samples, source, line in funcs[:top]:
        where = ''
        if ours(source) and 0 < line <= len(bundle):
            module, first = owner(starts, line)
            where = f'{module}:{line - first} | {bundle[line - 1].strip()[:90]}'
        print(f'  {seconds / total:6.1%} {seconds:7.2f}s {samples:7d} {source}:{line} {where}')
    if (folder / 'prof-incl.txt').exists():
        # The time spent in a function and in what it calls (each function on the stack gets a sample once).
        print('with what it calls, by function:')
        for seconds, samples, source, line in read(folder / 'prof-incl.txt')[:top * 2]:
            where = ''
            if ours(source) and 0 < line <= len(bundle):
                module, first = owner(starts, line)
                where = f'{module}:{line - first} | {bundle[line - 1].strip()[:90]}'
            print(f'  {seconds / total:6.1%} {seconds:7.2f}s {samples:7d} {source}:{line} {where}')
    print('by line:')
    for seconds, samples, source, line in lines[:top]:
        where = ''
        if ours(source) and 0 < line <= len(bundle):
            module, first = owner(starts, line)
            where = f'{module}:{line - first} | {bundle[line - 1].strip()[:100]}'
        print(f'  {seconds / total:6.1%} {seconds:7.2f}s {samples:7d} {source}:{line} {where}')


if __name__ == '__main__':
    main(sys.argv)
