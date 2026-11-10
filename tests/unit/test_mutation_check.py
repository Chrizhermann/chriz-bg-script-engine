"""The mutation check's own replacement: a mutation must change the file it names, whatever its line ends."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('mutation_check', ROOT / 'tools' / 'mutation_check.py')
mutation_check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mutation_check)


def test_a_mutation_over_a_line_break_fits_both_line_ends():
    # 2026-11-10: an anchor over two lines was counted once in a file with Windows line ends, replaced nowhere, and
    # the unchanged file's green tests were reported as a survivor.
    old, new = '    if not ready:\n        return None\n    go()', '    go()'
    unix = 'def f():\n    if not ready:\n        return None\n    go()\n'
    windows = unix.replace('\n', '\r\n')
    assert mutation_check.mutate(unix, old, new) == 'def f():\n    go()\n'
    assert mutation_check.mutate(windows, old, new) == 'def f():\r\n    go()\r\n'
    # What replaces it keeps the file's line ends too, and only the first place changes.
    assert mutation_check.mutate(windows, 'go()', 'a()\nb()') == windows.replace('go()', 'a()\r\nb()')
    assert mutation_check.mutate('x=1\nx=1\n', 'x=1', 'x=2') == 'x=2\nx=1\n'


def test_a_mutation_that_changes_nothing_is_none():
    assert mutation_check.mutate('a\nb\n', 'c', 'd') is None
    assert mutation_check.mutate('a\nb\n', 'a', 'a') is None
