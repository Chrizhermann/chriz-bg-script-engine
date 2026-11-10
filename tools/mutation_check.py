"""Mutation check: each mutation (a file, a text in it, what replaces it) must make the given tests
fail. The tests must pass unmutated first: on a red baseline every mutation looks caught (E7,
2026-11-04: the choice tests already failed, and the check reported all mutations killed). Rebuilds
the runtime around each run and restores every file.

    python -I tools/mutation_check.py <spec.json> <test filter>

spec.json: [["combat-intent/choice.lua", "the text as it is", "the mutated text"], ...]
A text may span lines, written with \\n; it also fits a file checked out with Windows line ends.
Exit code: 0 all killed, 1 survivors, 2 a red baseline, an anchor not found exactly once or a mutation
that changes nothing.
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


def mutate(raw, old, new):
    """The file's text as it lies on disk (raw, line ends as they are) with old replaced by new once, or None when
    that changes nothing. A text that spans lines is written with \\n; in a file with Windows line ends it stands
    with \\r\\n, and the mutation keeps the file's line ends. (Until 2026-11-10 the anchor was counted in text read
    with translated line ends and replaced in the raw text: a mutation over a line break in such a file changed
    nothing and was reported as a survivor.)"""
    crlf = '\r\n' in raw
    if crlf:
        old, new = (t.replace('\r\n', '\n').replace('\n', '\r\n') for t in (old, new))
    mutated = raw.replace(old, new, 1)
    return None if mutated == raw else mutated


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
    for path, old, new in spec:
        if mutate((REPO / path).read_bytes().decode('utf-8'), old, new) is None:
            print(f'{path}: the mutation changes nothing: {old[:70]!r}')
            return 2
    survivors = []
    for path, old, new in spec:
        target = REPO / path
        text = target.read_bytes().decode('utf-8')
        target.write_bytes(mutate(text, old, new).encode('utf-8'))
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
