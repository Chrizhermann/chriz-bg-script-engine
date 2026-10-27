"""Check that the WeiDU hook (bgse/lib/hook.tpa) and tools/hook_rule.py patch decompiled scripts
alike, byte for byte, without a game: WeiDU runs bgse_hook_baf on every script of a folder with
--nogame, and each result, its counts, its gifts and its text must match the Python rule's.

    python tools/hook_agree.py <weidu.exe> <folder-with-baf> [work-folder] [teleports.txt] [hides.txt]
        [innates.txt] [gtimes.ids]

The work folder (a new temporary one by default) gets WeiDU's harness, log and patched scripts.
teleports.txt names the spells that move their caster, one a line (resrefs, SPELL.IDS names and
numbers, as a game's spell files say; none by default), hides.txt those that make their target
invisible ('NAME plain' or 'NAME improved' a line; none by default), innates.txt those whose files say
innate (one a line; none by default), gtimes.ids the game's timer names (none by default): both sides
get the same lists.
"""
import re
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
    LPF bgse_hook_baf STR_VAR bgse_baf = EVAL ~%baf%~ bgse_script = EVAL ~%script%~ bgse_teleports = ~TELEPORTS~
        bgse_invisible = ~INVISIBLE~ bgse_improved = ~IMPROVED~ bgse_innate = ~INNATE~ bgse_times = ~TIMES~
      RET bgse_result bgse_family bgse_copies bgse_clouds bgse_hunts bgse_jumps bgse_hides bgse_preps bgse_teleporter bgse_hider
          bgse_gifts bgse_baf END
    DELETE_BYTES 0 BUFFER_LENGTH
    INSERT_BYTES 0 (STRING_LENGTH ~%bgse_baf%~)
    WRITE_ASCIIE 0 ~%bgse_baf%~
    PATCH_PRINT ~AGREE|%BASH_FOR_RES%|%bgse_result%|%bgse_family%|%bgse_copies%|%bgse_clouds%|%bgse_hunts%|%bgse_jumps%|%bgse_teleporter%|%bgse_hides%|%bgse_hider%|%bgse_preps%|%bgse_gifts%~
END
'''


def gift_list(gifts):
    """Gifts (hook_rule.script_gifts) as bgse_hook_baf lists them, without the form of each spell:
    |SPELL:KIND:CHARGES:RECHARGE| entries, - for none."""
    return '|' + ''.join(f'{spell}:{kind or "-"}:{charges or "-"}:{recharge or "-"}|'
                         for spell, kind, charges, recharge in gifts)


def reference(text, stem, teleports=frozenset(), hides=None, innates=frozenset(), times=None):
    """The Python rule's (patched or stripped text, result, family, copies, clouds, hunts, jumps,
    teleporter, hides, hider, preps, gifts)."""
    hides = hides or {}
    patched, reason, fam, copies = hook_rule.patch(text, stem, teleports, hides)
    text = text.replace('\r', '')
    spans, anchor, _ = hook_rule.plan(text, teleports)
    clouds = len(hook_rule.clouds(text, spans, anchor)) if patched else 0
    hunts = len(hook_rule.hunts(text, spans)) if patched else 0
    jumps = len(hook_rule.jumps(text, spans, teleports)) if patched else 0
    teleporter = int(bool(patched) and hook_rule.teleporter(text, teleports))
    hidden = len(hook_rule.hiding(text, spans, hides)) if patched else 0
    preps = len(hook_rule.preparations(text, spans, anchor)) if patched else 0
    gifts = gift_list(hook_rule.script_gifts(text, hides, innates, times) if patched else [])
    return (patched if patched is not None else text), (reason, fam, copies, clouds, hunts, jumps, teleporter, hidden,
                                                        int(hidden > 0), preps, gifts)


def main():
    weidu, folder = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    work = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else Path(tempfile.mkdtemp(prefix='bgse-agree-'))
    teleports = frozenset()
    if len(sys.argv) > 4:
        teleports = frozenset(line.strip().upper() for line in Path(sys.argv[4]).read_text(encoding='utf-8').splitlines()
                              if line.strip())
    hides = hook_rule.read_hides(sys.argv[5]) if len(sys.argv) > 5 else {}
    innates = frozenset(line.strip().upper() for line in Path(sys.argv[6]).read_text(encoding='utf-8').splitlines()
                        if line.strip()) if len(sys.argv) > 6 else frozenset()
    times = hook_rule.read_times(sys.argv[7]) if len(sys.argv) > 7 else {}
    (work / 'out').mkdir(parents=True, exist_ok=True)
    listed = '|' + ''.join(f'{name}|' for name in sorted(teleports))
    invisible = '|' + ''.join(f'{name}|' for name in sorted(hides))
    improved = '|' + ''.join(f'{name}|' for name, kind in sorted(hides.items()) if kind == 'improved')
    innate = '|' + ''.join(f'{name}|' for name in sorted(innates))
    timers = '|' + ''.join(f'{name}={seconds}|' for name, seconds in times.items())
    (work / 'harness.tp2').write_text(HARNESS.replace('~TELEPORTS~', f'~{listed}~').replace('~INVISIBLE~', f'~{invisible}~')
                                      .replace('~IMPROVED~', f'~{improved}~').replace('~INNATE~', f'~{innate}~')
                                      .replace('~TIMES~', f'~{timers}~'), encoding='ascii')
    run = subprocess.run([str(weidu), 'harness.tp2', '--nogame', '--force-install-list', '1',
                          '--args', str(ROOT / 'bgse/lib/hook.tpa'), '--args', str(folder), '--args', 'out',
                          '--no-exit-pause', '--quick-log'], cwd=work, capture_output=True, text=True,
                         encoding='latin-1')
    (work / 'weidu.out').write_text(run.stdout + run.stderr, encoding='utf-8')
    weidu_rows = {}
    for line in run.stdout.splitlines():
        if line.startswith('AGREE|'):
            _, res, result, fam, copies, clouds, hunts, jumps, teleporter, hidden, hider, preps, gifts = line.split('|', 12)
            # Python's gifts do not say how each spell is written (resref or SPELL.IDS name).
            weidu_rows[res.lower()] = (result, fam or None, int(copies), int(clouds), int(hunts), int(jumps),
                                       int(teleporter), int(hidden), int(hider), int(preps),
                                       re.sub(r'\|[RI]:', '|', gifts))
    outcomes, mismatches = Counter(), []
    paths = sorted(folder.glob('*.baf'))
    for path in paths:
        stem = path.stem.lower()
        expected, counts = reference(path.read_text(encoding='latin-1'), stem, teleports, hides, innates, times)
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
    jumps = sum(row[5] for row in weidu_rows.values())
    teleporters = sum(row[6] for row in weidu_rows.values())
    hidden = sum(row[7] for row in weidu_rows.values())
    hiders = sum(row[8] for row in weidu_rows.values())
    preps = sum(row[9] for row in weidu_rows.values())
    gifts = Counter(gift for row in weidu_rows.values() for gift in row[10].strip('|').split('|') if gift)
    print(f'jumps {jumps}, teleporting scripts {teleporters}, free invisibility blocks {hidden} in {hiders} scripts, '
          f'preparation blocks {preps}')
    print('gifts:', dict(sorted(gifts.items())))
    for m in mismatches[:40]:
        print('  ' + m)
    if mismatches or run.returncode != 0:
        print(f'{len(mismatches)} mismatches')
        sys.exit(1)


if __name__ == '__main__':
    main()
