"""Mutation check: each mutation (a file, a text in it, what replaces it) must make the given tests
fail. The tests must pass unmutated first: on a red baseline every mutation looks caught (E7,
2026-11-04: the choice tests already failed, and the check reported all mutations killed). Rebuilds
the runtime around each run and restores every file.

    python -I tools/mutation_check.py <spec.json> <test filter>

spec.json: [["combat-intent/choice.lua", "the text as it is", "the mutated text"], ...]
Exit code: 0 all killed, 1 survivors, 2 a red baseline or an anchor not found exactly once.
"""
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def tests_pass(selection):
    subprocess.run([sys.executable, '-I', 'tools/build_runtime.py'], cwd=REPO, capture_output=True)
    result = subprocess.run(['powershell', '-NoProfile', '-File', 'scripts/test.ps1', '-Suite', 'all', '-Filter',
                             selection], cwd=REPO, capture_output=True, text=True)
    return result.returncode == 0, (result.stdout + result.stderr)[-3000:]


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    spec = json.loads(Path(argv[1]).read_text(encoding='utf-8'))
    selection = argv[2]
    ok, out = tests_pass(selection)
    if not ok:
        print('the tests fail without any mutation; fix them first:\n' + out)
        return 2
    for path, old, _ in spec:
        count = (REPO / path).read_text(encoding='utf-8').count(old)
        if count != 1:
            print(f'{path}: the text to mutate is there {count} times, not once: {old[:70]!r}')
            return 2
    survivors = []
    for path, old, new in spec:
        target = REPO / path
        text = target.read_bytes().decode('utf-8')
        target.write_bytes(text.replace(old, new, 1).encode('utf-8'))
        try:
            ok, _ = tests_pass(selection)
        finally:
            target.write_bytes(text.encode('utf-8'))
        print('SURVIVED' if ok else 'killed  ', path, '|', old[:70].replace('\n', ' '), flush=True)
        if ok:
            survivors.append([path, old, new])
    tests_pass(selection)  # the runtime built again from the restored files
    print('survivors:', len(survivors))
    return 1 if survivors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
