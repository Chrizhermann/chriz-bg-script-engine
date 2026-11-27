"""Check that WeiDU (bgse/lib/ambush.tpa) and tools/ambush_rule.py patch decompiled ambush
scripts alike, byte for byte, without a game:

    python tools/ambush_agree.py <weidu.exe> <folder-with-baf-and-bmp> [work-folder] [talkers.txt]
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import ambush_rule  # noqa: E402

HARNESS = r'''BACKUP ~backup~
AUTHOR ~BGSE ambush agreement~

BEGIN ~bgse_ambush_baf on decompiled scripts~ DESIGNATED 1
INCLUDE ~%argv[0]%~
INCLUDE ~%argv[1]%~
ACTION_FOR_EACH area IN ~BG5600~ ~BG5601~ ~BG5700~ ~BG5701~ ~BG5800~ ~BG5801~
    ~BG5900~ ~BG5901~ ~BG6000~ ~BG6001~ ~BG6100~
    ~AR0041~ ~AR0042~ ~AR0043~ ~AR0044~ ~AR0045~ ~AR0046~ BEGIN
  ACTION_IF FILE_EXISTS ~%argv[2]%/%area%.baf~ BEGIN
    OUTER_SET area_idx = 0
    OUTER_SET idx_i = 0
    ACTION_FOR_EACH a2 IN ~BG5600~ ~BG5601~ ~BG5700~ ~BG5701~ ~BG5800~ ~BG5801~
        ~BG5900~ ~BG5901~ ~BG6000~ ~BG6001~ ~BG6100~
        ~AR0041~ ~AR0042~ ~AR0043~ ~AR0044~ ~AR0045~ ~AR0046~ BEGIN
      ACTION_IF (~%area%~ STRING_EQUAL_CASE ~%a2%~) BEGIN
        OUTER_SET area_idx = idx_i
      END
      OUTER_SET idx_i += 1
    END
    OUTER_SET anchor_x = 640
    OUTER_SET anchor_y = 480
    OUTER_SET anchor_x2 = 640
    OUTER_SET anchor_y2 = 480
    ACTION_IF (INDEX (CASE_INSENSITIVE ~^AR004~ ~%area%~) = 0) BEGIN
      OUTER_SET anchor_x = 513
      OUTER_SET anchor_y = 528
      OUTER_SET anchor_x2 = 600
      OUTER_SET anchor_y2 = 500
    END
    OUTER_TEXT_SPRINT sr_bmp ~~
    ACTION_IF FILE_EXISTS ~%argv[2]%/%area%SR.bmp~ BEGIN
      COPY ~%argv[2]%/%area%SR.bmp~ ~%argv[3]%/%area%SR.bmp~
        READ_ASCII 0 sr_bmp (BUFFER_LENGTH)
      BUT_ONLY
    END
    COPY ~%argv[2]%/%area%.baf~ ~%argv[3]%/%area%.baf~
      READ_ASCII 0 baf (BUFFER_LENGTH)
      LPF bgse_ambush_candidates INT_VAR anchor_x = anchor_x anchor_y = anchor_y
          anchor_x2 = anchor_x2 anchor_y2 = anchor_y2
        STR_VAR bgse_sr_bmp = EVAL ~%sr_bmp%~
        RET bgse_cand_cnt
            bgse_cand_p bgse_cnt_p bgse_cand_dl bgse_cnt_dl bgse_cand_dc bgse_cnt_dc
            bgse_cand_ho0 bgse_cnt_ho0 bgse_cand_ho1 bgse_cnt_ho1
            bgse_cand_ho2 bgse_cnt_ho2 bgse_cand_ho3 bgse_cnt_ho3
            bgse_cand_ho4 bgse_cnt_ho4 bgse_cand_ho5 bgse_cnt_ho5
            bgse_cand_ho6 bgse_cnt_ho6 bgse_cand_ho7 bgse_cnt_ho7
            bgse_cand_hb0 bgse_cnt_hb0 bgse_cand_hb1 bgse_cnt_hb1
            bgse_cand_hb2 bgse_cnt_hb2 bgse_cand_hb3 bgse_cnt_hb3
            bgse_cand_hb4 bgse_cnt_hb4 bgse_cand_hb5 bgse_cnt_hb5
            bgse_cand_hb6 bgse_cnt_hb6 bgse_cand_hb7 bgse_cnt_hb7 END
      LPF bgse_ambush_baf INT_VAR area_idx = area_idx anchor_x = anchor_x anchor_y = anchor_y
          anchor_x2 = anchor_x2 anchor_y2 = anchor_y2 bgse_cand_cnt = bgse_cand_cnt
          bgse_cnt_p = bgse_cnt_p bgse_cnt_dl = bgse_cnt_dl bgse_cnt_dc = bgse_cnt_dc
          bgse_cnt_ho0 = bgse_cnt_ho0 bgse_cnt_ho1 = bgse_cnt_ho1
          bgse_cnt_ho2 = bgse_cnt_ho2 bgse_cnt_ho3 = bgse_cnt_ho3
          bgse_cnt_ho4 = bgse_cnt_ho4 bgse_cnt_ho5 = bgse_cnt_ho5
          bgse_cnt_ho6 = bgse_cnt_ho6 bgse_cnt_ho7 = bgse_cnt_ho7
          bgse_cnt_hb0 = bgse_cnt_hb0 bgse_cnt_hb1 = bgse_cnt_hb1
          bgse_cnt_hb2 = bgse_cnt_hb2 bgse_cnt_hb3 = bgse_cnt_hb3
          bgse_cnt_hb4 = bgse_cnt_hb4 bgse_cnt_hb5 = bgse_cnt_hb5
          bgse_cnt_hb6 = bgse_cnt_hb6 bgse_cnt_hb7 = bgse_cnt_hb7
        STR_VAR bgse_baf = EVAL ~%baf%~ bgse_talkers = ~TALKERS~
          bgse_cand_p = EVAL ~%bgse_cand_p%~ bgse_cand_dl = EVAL ~%bgse_cand_dl%~ bgse_cand_dc = EVAL ~%bgse_cand_dc%~
          bgse_cand_ho0 = EVAL ~%bgse_cand_ho0%~ bgse_cand_ho1 = EVAL ~%bgse_cand_ho1%~
          bgse_cand_ho2 = EVAL ~%bgse_cand_ho2%~ bgse_cand_ho3 = EVAL ~%bgse_cand_ho3%~
          bgse_cand_ho4 = EVAL ~%bgse_cand_ho4%~ bgse_cand_ho5 = EVAL ~%bgse_cand_ho5%~
          bgse_cand_ho6 = EVAL ~%bgse_cand_ho6%~ bgse_cand_ho7 = EVAL ~%bgse_cand_ho7%~
          bgse_cand_hb0 = EVAL ~%bgse_cand_hb0%~ bgse_cand_hb1 = EVAL ~%bgse_cand_hb1%~
          bgse_cand_hb2 = EVAL ~%bgse_cand_hb2%~ bgse_cand_hb3 = EVAL ~%bgse_cand_hb3%~
          bgse_cand_hb4 = EVAL ~%bgse_cand_hb4%~ bgse_cand_hb5 = EVAL ~%bgse_cand_hb5%~
          bgse_cand_hb6 = EVAL ~%bgse_cand_hb6%~ bgse_cand_hb7 = EVAL ~%bgse_cand_hb7%~
        RET bgse_blocks bgse_baf END
      DELETE_BYTES 0 BUFFER_LENGTH
      INSERT_BYTES 0 (STRING_LENGTH ~%bgse_baf%~)
      WRITE_ASCIIE 0 ~%bgse_baf%~
      PATCH_PRINT ~AMBUSH|%area%|%bgse_blocks%|%bgse_cand_cnt%~
  END
END
'''


def main():
    weidu = Path(sys.argv[1]).resolve()
    folder = Path(sys.argv[2]).resolve()
    work = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else Path(tempfile.mkdtemp(prefix='bgse-ambush-agree-'))
    talkers = frozenset()
    if len(sys.argv) > 4:
        talkers = frozenset(line.strip().upper() for line in Path(sys.argv[4]).read_text(encoding='utf-8').splitlines()
                            if line.strip())
    (work / 'out').mkdir(parents=True, exist_ok=True)
    listed = '|' + ''.join(f'{name}|' for name in sorted(talkers))
    (work / 'harness.tp2').write_text(HARNESS.replace('~TALKERS~', f'~{listed}~'), encoding='ascii')
    run = subprocess.run([
        str(weidu), 'harness.tp2', '--nogame', '--force-install-list', '1',
        '--args', str(ROOT / 'bgse/lib/hook.tpa'),
        '--args', str(ROOT / 'bgse/lib/ambush.tpa'),
        '--args', str(folder),
        '--args', 'out',
        '--no-exit-pause', '--quick-log',
    ], cwd=work, capture_output=True, text=True, encoding='latin-1')
    (work / 'weidu.out').write_text(run.stdout + run.stderr, encoding='utf-8')
    if run.returncode != 0:
        print(run.stdout[-1500:])
        print(run.stderr[-1500:])
        raise SystemExit(f'WeiDU exited with {run.returncode}')

    rows = {}
    for line in run.stdout.splitlines():
        if line.startswith('AMBUSH|'):
            _, area, blocks, cands = line.split('|', 3)
            rows[area.upper()] = (int(blocks), int(cands))

    diffs = []
    for area in ambush_rule.TARGET_AREAS:
        baf_path = folder / f'{area}.baf'
        if not baf_path.is_file():
            continue
        bmp_path = folder / f'{area}SR.bmp'
        bmp = bmp_path.read_bytes() if bmp_path.is_file() else None
        text = baf_path.read_text(encoding='latin-1')
        py_text, py_blocks = ambush_rule.patch_ambush_baf(text, area, bmp, talkers)
        w_blocks, w_cands = rows.get(area, (-1, -1))
        w_text = (work / 'out' / f'{area}.baf').read_text(encoding='latin-1').replace('\r', '')
        if py_blocks != w_blocks or py_text != w_text:
            diffs.append((area, py_blocks, w_blocks, w_cands))
            (work / f'{area}.py.baf').write_text(py_text, encoding='latin-1')
        print(f'{area}: blocks={py_blocks}/{w_blocks}, cands={w_cands}, match={py_text == w_text}')

    print(f'checked: {len(rows)}, disagreements: {len(diffs)}')
    raise SystemExit(1 if diffs else 0)


if __name__ == '__main__':
    main()
