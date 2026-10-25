"""Check that the WeiDU hook (bgse/lib/hook.tpa) and tools/hook_rule.py patch decompiled scripts
alike, byte for byte, without a game: WeiDU runs bgse_hook_baf on every script of a folder with
--nogame, and each result, its counts and its text must match the Python rule's.

    python tools/hook_agree.py <weidu.exe> <folder-with-baf> [work-folder]

The work folder (a new temporary one by default) gets WeiDU's harness, log and patched scripts.
"""
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import hook_rule  # noqa: E402

HARNESS = r'''BACKUP ~backup~
AUTHOR ~BGSE hook agreement~

BEGIN ~bgse_hook_baf on decompiled scripts~ DESIGNATED 1
INCLUDE ~%argv[0]%~
ACTION_BASH_FOR ~%argv[1]%~ ~^.+\.baf$~ BEGIN
  COPY ~%BASH_FOR_FILESPEC%~ ~%argv[2]%/%BASH_FOR_RES%.baf~
    READ_ASCII 0 baf (BUFFER_LENGTH)
    TEXT_SPRINT script ~%BASH_FOR_RES%~
    TO_LOWER script
    LPF bgse_hook_baf STR_VAR bgse_baf = EVAL ~%baf%~ bgse_script = EVAL ~%script%~
      RET bgse_result bgse_family bgse_copies bgse_clouds bgse_hunts bgse_baf END
    DELETE_BYTES 0 BUFFER_LENGTH
    INSERT_BYTES 0 (STRING_LENGTH ~%bgse_baf%~)
    WRITE_ASCIIE 0 ~%bgse_baf%~
    PATCH_PRINT ~AGREE|%BASH_FOR_RES%|%bgse_result%|%bgse_family%|%bgse_copies%|%bgse_clouds%|%bgse_hunts%~
END
'''


def reference(text, stem):
    """The Python rule's (patched or stripped text, result, family, copies, clouds, hunts)."""
    patched, reason, fam, copies = hook_rule.patch(text, stem)
    text = text.replace('\r', '')
    spans, anchor, _ = hook_rule.plan(text)
    clouds = len(hook_rule.clouds(text, spans, anchor)) if patched else 0
    hunts = len(hook_rule.hunts(text, spans)) if patched else 0
    return (patched if patched is not None else text), (reason, fam, copies, clouds, hunts)


def main():
    weidu, folder = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    work = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else Path(tempfile.mkdtemp(prefix='bgse-agree-'))
    (work / 'out').mkdir(parents=True, exist_ok=True)
    (work / 'harness.tp2').write_text(HARNESS, encoding='ascii')
    run = subprocess.run([str(weidu), 'harness.tp2', '--nogame', '--force-install-list', '1',
                          '--args', str(ROOT / 'bgse/lib/hook.tpa'), '--args', str(folder), '--args', 'out',
                          '--no-exit-pause', '--quick-log'], cwd=work, capture_output=True, text=True,
                         encoding='latin-1')
    (work / 'weidu.out').write_text(run.stdout + run.stderr, encoding='utf-8')
    weidu_rows = {}
    for line in run.stdout.splitlines():
        if line.startswith('AGREE|'):
            _, res, result, fam, copies, clouds, hunts = line.split('|')
            weidu_rows[res.lower()] = (result, fam or None, int(copies), int(clouds), int(hunts))
    outcomes, mismatches = Counter(), []
    paths = sorted(folder.glob('*.baf'))
    for path in paths:
        stem = path.stem.lower()
        expected, counts = reference(path.read_text(encoding='latin-1'), stem)
        got = weidu_rows.get(stem)
        if got != counts:
            mismatches.append(f'{path.name}: WeiDU {got}, Python {counts}')
            continue
        text = (work / 'out' / f'{path.stem.upper()}.baf').read_bytes().decode('latin-1')
        if text != expected:
            at = next((i for i, (a, b) in enumerate(zip(text, expected)) if a != b), min(len(text), len(expected)))
            mismatches.append(f'{path.name}: text differs at {at}: WeiDU {text[at - 60:at + 60]!r}, '
                              f'Python {expected[at - 60:at + 60]!r}')
            continue
        outcomes[f'{counts[1]}/{counts[0]}'] += 1
    print(f'{len(paths)} scripts, WeiDU exit {run.returncode}, work folder {work}')
    print('agree:', sum(outcomes.values()), dict(sorted(outcomes.items())))
    for m in mismatches[:40]:
        print('  ' + m)
    if mismatches or run.returncode != 0:
        print(f'{len(mismatches)} mismatches')
        sys.exit(1)


if __name__ == '__main__':
    main()
