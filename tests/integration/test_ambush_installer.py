"""Integration test for install-time travel ambush relocation in bgse/setup-bgse.tp2."""

import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import pytest

from tools import ambush_rule

ROOT = Path(__file__).resolve().parents[2]

TRIGGER = """IDS V1.0
0x4001 Global(S:Name*,S:Area*,I:Value*)
0x400A True()
0x410E EEex_LuaTrigger(S:Chunk*)
"""

ACTION = """IDS V1.0
0 NoAction()
1 SetGlobal(S:Name*,S:Area*,I:Value*)
37 Dialog(O:Object*)
38 StartDialogNoSet(O:Object*)
46 JumpToPoint(P:Target*)
48 CreateCreature(S:NewObject*,P:Location*,I:Face*Dir)
472 EEex_LuaAction(S:Chunk*)
"""

STATIC_IDS = {
    'OBJECT': 'IDS V1.0\n0 Nothing\n1 Myself\n21 Player1\n',
    'DIFFLEV': 'IDS V1.0\n1 EASIEST\n3 NORMAL\n5 HARDEST\n',
    'DIR': ('IDS V1.0\n0 S\n1 SSW\n2 SW\n3 WSW\n4 W\n5 WNW\n6 NW\n7 NNW\n'
            '8 N\n9 NNE\n10 NE\n11 ENE\n12 E\n13 ESE\n14 SE\n15 SSE\n'),
    'GTIMES': 'IDS V1.0\n6 ONE_ROUND\n',
    'EA': 'IDS V1.0\n0 ANYONE\n2 PC\n128 NEUTRAL\n255 ENEMY\n',
    'ASTYLES': 'IDS V1.0\n0 DEFAULT\n',
    'GENERAL': 'IDS V1.0\n0 ANYONE\n',
    'RACE': 'IDS V1.0\n0 ANYONE\n',
    'CLASS': 'IDS V1.0\n0 ANYONE\n',
    'SPECIFIC': 'IDS V1.0\n0 ANYONE\n',
    'GENDER': 'IDS V1.0\n0 ANYONE\n',
    'ALIGN': 'IDS V1.0\n0 ANYONE\n',
    'SPELL': 'IDS V1.0\n2101 WIZARD_MAGIC_MISSILE\n',
    'STATS': 'IDS V1.0\n18 RESISTMAGIC\n',
    'BOOLEAN': 'IDS V1.0\n0 FALSE\n1 TRUE\n',
    'SCROLL': 'IDS V1.0\n0 INSTANT\n',
    'SPLSTATE': 'IDS V1.0\n12 CONTINGENCY_TRIGGERED\n',
}

TABLES = {
    'THIEFSKL': '2DA V1.0\n0\n  LEVEL_POINTS START_POINTS\nTHIEF 25 40\n',
    'KITLIST': '2DA V1.0\n*\n ROWNAME LOWER MIXED HELP ABILITIES PROFICIENCY UNUSABLE CLASS KITIDS\n0 RESERVE * * * * * * *\n',
    'PDIALOG': '2DA V1.0\n***\n POST_DIALOG_FILE JOIN_DIALOG_FILE\n',
}


def _weidu() -> Path | None:
    candidate = os.environ.get('BGSE_WEIDU')
    if candidate:
        p = Path(candidate)
        if p.is_file():
            return p
    default = ROOT / '.work/task6/effective-pilot-20260927/weidu.exe'
    return default if default.is_file() else None


def _tlk(strings) -> bytes:
    entries, data = bytearray(), bytearray()
    for text in strings:
        raw = text.encode('ascii')
        entries += struct.pack('<H8sIIII', 1 if raw else 0, b'', 0, 0, len(data), len(raw))
        data += raw
    return b'TLK V1  ' + struct.pack('<HII', 0, len(strings), 0x12 + len(entries)) + bytes(entries) + bytes(data)


def _cre(ea: int = 255, scripts=()) -> bytes:
    head = bytearray(0x2D4)
    head[:8] = b'CRE V1.0'
    struct.pack_into('<II', head, 0x08, 0xFFFFFFFF, 0xFFFFFFFF)
    head[0x270] = ea
    for i, scr in enumerate(scripts[:5]):
        head[0x248 + 8 * i:0x250 + 8 * i] = scr.encode('ascii').ljust(8, b'\0')
    levels = [(level, 0) for level in range(7)] + [(level, 1) for level in range(9)] + [(0, 2)]
    info = b''.join(struct.pack('<HHHHII', lv, 0, 0, kind, 0, 0) for lv, kind in levels)
    slots = struct.pack('<40H', *([0xFFFF] * 40))
    at = 0x2D4
    struct.pack_into('<II', head, 0x2A0, at, 0)
    struct.pack_into('<II', head, 0x2A8, at, len(levels))
    struct.pack_into('<II', head, 0x2B0, at + len(info), 0)
    struct.pack_into('<III', head, 0x2B8, at + len(info), at + len(info) + len(slots), 0)
    struct.pack_into('<II', head, 0x2C4, at + len(info) + len(slots), 0)
    return bytes(head) + info + slots


def _are(wed: str) -> bytes:
    head = bytearray(0x11C)
    head[:8] = b'AREAV1.0'
    head[0x08:0x10] = wed.encode('ascii').ljust(8, b'\0')
    return bytes(head)


def _sr_bmp(w: int = 80, h: int = 80, blocked=None) -> bytes:
    blocked = set(blocked or ())
    stride = ((w * 4 + 31) // 32) * 4
    pixels = bytearray(stride * h)
    for cy in range(h):
        ry = h - 1 - cy
        row = ry * stride
        for cx in range(w):
            nib = 0 if (cx, cy) in blocked else 1
            byte_off = row + (cx >> 1)
            if (cx & 1) == 0:
                pixels[byte_off] = (pixels[byte_off] & 0x0F) | (nib << 4)
            else:
                pixels[byte_off] = (pixels[byte_off] & 0xF0) | nib
    data_off = 54 + 64
    header = struct.pack('<2sIHHI', b'BM', data_off + len(pixels), 0, 0, data_off)
    dib = struct.pack('<IIIHHIIIIII', 40, w, h, 1, 4, 0, len(pixels), 0, 0, 16, 16)
    return header + dib + (b'\x00' * 64) + bytes(pixels)


def _invoke(weidu: Path, root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    cmd = [str(weidu), *args, '--language', '0', '--use-lang', 'en_US',
           '--no-exit-pause', '--quick-log', '--noautoupdate']
    return subprocess.run(cmd, cwd=root, text=True, encoding='utf-8', errors='replace',
                          stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=120, check=False)


def _decompile(weidu: Path, root: Path, names) -> dict[str, str]:
    out = root / 'decompiled'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir()
    res = subprocess.run([str(weidu), '--game', str(root), '--noautoupdate', '--no-exit-pause',
                          '--out', str(out), *[str(root / 'override' / f'{n}.bcs') for n in names]],
                         cwd=root, text=True, encoding='utf-8', errors='replace',
                         stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         timeout=120, check=False)
    assert res.returncode == 0, res.stdout
    return {n: (out / f'{n}.baf').read_text(encoding='latin-1').replace('\r', '') for n in names}


def _snapshot(root: Path) -> dict[str, bytes]:
    return {p.relative_to(root).as_posix().casefold(): p.read_bytes()
            for p in (root / 'override').rglob('*') if p.is_file()}


def test_ambush_installer_relocation_agreement_and_uninstall(tmp_path: Path):
    weidu = _weidu()
    if weidu is None:
        pytest.skip('BGSE_WEIDU binary unavailable')

    (tmp_path / 'data').mkdir()
    (tmp_path / 'override').mkdir()
    (tmp_path / 'lang/en_us').mkdir(parents=True)

    resources = [('TRIGGER', TRIGGER), ('ACTION', ACTION)] + sorted(STATIC_IDS.items())
    table_off = 0x14
    payload_off = table_off + len(resources) * 0x10
    payload, entries = bytearray(), bytearray()
    for idx, (_, text) in enumerate(resources):
        raw = text.encode('ascii')
        entries += struct.pack('<IIIHH', idx, payload_off + len(payload), len(raw), 1008, 0)
        payload += raw
    bif = b'BIFFV1  ' + struct.pack('<III', len(resources), 0, table_off) + entries + payload
    (tmp_path / 'data/bgse-test.bif').write_bytes(bif)
    bif_name = b'data\\bgse-test.bif\x00'
    key = b'KEY V1  ' + struct.pack('<IIII', 1, len(resources), 0x18, 0x24)
    key += struct.pack('<IIHH', len(bif), 0x24 + len(resources) * 0x0E, len(bif_name), 0)
    for idx, (name, _) in enumerate(resources):
        key += struct.pack('<8sHI', name.encode('ascii').ljust(8, b'\0'), 1008, idx)
    (tmp_path / 'chitin.key').write_bytes(key + bif_name)

    tlk = _tlk([''])
    (tmp_path / 'dialog.tlk').write_bytes(tlk)
    (tmp_path / 'lang/en_us/dialog.tlk').write_bytes(tlk)
    (tmp_path / 'override/M___EEex.lua').write_text('-- synthetic EEex\n', encoding='ascii')
    for name, text in TABLES.items():
        (tmp_path / f'override/{name}.2DA').write_text(text, encoding='ascii')

    # Areas + search maps with center obstacles + creatures
    blocked = {(cx, cy) for cx in range(35, 45) for cy in range(25, 35)}
    bmp = _sr_bmp(80, 80, blocked=blocked)
    (tmp_path / 'override/BG5600.ARE').write_bytes(_are('BG5600'))
    (tmp_path / 'override/AR0041.ARE').write_bytes(_are('AR0041'))
    (tmp_path / 'override/BG5600SR.BMP').write_bytes(bmp)
    (tmp_path / 'override/AR0041SR.BMP').write_bytes(bmp)

    (tmp_path / 'override/KOBOLD.CRE').write_bytes(_cre(255))
    (tmp_path / 'override/RESUNA.CRE').write_bytes(_cre(255))
    (tmp_path / 'override/TALKER.CRE').write_bytes(_cre(255, ['TALKACT']))
    (tmp_path / 'override/GITH01.CRE').write_bytes(_cre(255))
    (tmp_path / 'override/RENFELD.CRE').write_bytes(_cre(128))
    (tmp_path / 'override/THIEF.CRE').write_bytes(_cre(255))

    src = tmp_path / 'src'
    src.mkdir()
    (src / 'TALKACT.BAF').write_text(
        'IF\n  True()\nTHEN\n  RESPONSE #100\n    StartDialogNoSet(Player1)\nEND\n',
        encoding='ascii',
    )
    (src / 'BG5600.BAF').write_text(
        'IF\n  Global("AMB","GLOBAL",0)\nTHEN\n  RESPONSE #100\n    SetGlobal("AMB","GLOBAL",1)\n'
        + ''.join('    CreateCreature("KOBOLD",[640.480],S)\n' for _ in range(6))
        + 'END\n\n'
        + 'IF\n  Global("CUT","GLOBAL",0)\nTHEN\n  RESPONSE #100\n    CreateCreature("THIEF",[640.480],S)\n'
        + '    JumpToPoint([500.500])\nEND\n',
        encoding='ascii',
    )
    (src / 'AR0041.BAF').write_text(
        'IF\n  Global("DLG","GLOBAL",0)\nTHEN\n  RESPONSE #100\n'
        '    CreateCreature("KOBOLD",[513.528],S)\n'
        '    CreateCreature("TALKER",[513.528],S)\n'
        '    CreateCreature("RESUNA",[513.528],S)\n'
        'END\n\n'
        'IF\n  Global("GTH","GLOBAL",0)\nTHEN\n  RESPONSE #100\n'
        '    CreateCreature("GITH01",[513.528],S)\n'
        '    CreateCreature("GITH01",[513.528],S)\n'
        'END\n\n'
        'IF\n  Global("REN","GLOBAL",0)\nTHEN\n  RESPONSE #100\n'
        '    CreateCreature("RENFELD",[960.860],S)\n'
        'END\n',
        encoding='ascii',
    )
    (src / 'compile.tp2').write_text(
        'BACKUP ~src/bk~\nAUTHOR ~x~\nBEGIN ~compile~\n'
        'COMPILE ~src/TALKACT.BAF~\nCOMPILE ~src/BG5600.BAF~\nCOMPILE ~src/AR0041.BAF~\n',
        encoding='ascii',
    )
    comp = _invoke(weidu, tmp_path, 'src/compile.tp2', '--force-install-list', '0')
    assert comp.returncode == 0, comp.stdout

    # Prepare clean BAFs + BMPs from compiled scripts for ambush_agree cross-check
    agree_in = tmp_path / 'agree_in'
    agree_in.mkdir()
    dec_src = _decompile(weidu, tmp_path, ['BG5600', 'AR0041'])
    for area in ('BG5600', 'AR0041'):
        (agree_in / f'{area}.baf').write_text(dec_src[area], encoding='latin-1')
        (agree_in / f'{area}SR.bmp').write_bytes(bmp)
    talkers_txt = tmp_path / 'talkers.txt'
    talkers_txt.write_text('RENFELD\nRESUNA\nTALKER\n', encoding='utf-8')

    agree_run = subprocess.run(
        [sys.executable, '-I', str(ROOT / 'tools/ambush_agree.py'),
         str(weidu), str(agree_in), str(tmp_path / 'agree_work'), str(talkers_txt)],
        capture_output=True, text=True, check=False,
    )
    assert agree_run.returncode == 0, agree_run.stdout + agree_run.stderr
    assert 'checked: 2, disagreements: 0' in agree_run.stdout

    shutil.copytree(ROOT / 'bgse', tmp_path / 'bgse', ignore=shutil.ignore_patterns('backup'))
    before = _snapshot(tmp_path)

    inst = _invoke(weidu, tmp_path, 'bgse/setup-bgse.tp2', '--force-install-list', '0')
    assert inst.returncode == 0, inst.stdout
    assert 'BGSE ambush: 2 random-encounter scripts updated (3 ambush blocks given sensible positions).' in inst.stdout

    installed = _snapshot(tmp_path)
    dec_post = _decompile(weidu, tmp_path, ['BG5600', 'AR0041'])

    # Installed decompiled spawn positions match tools/ambush_agree.py output identically
    for area in ('BG5600', 'AR0041'):
        agree_baf = (tmp_path / 'agree_work' / 'out' / f'{area}.baf').read_text(encoding='latin-1').replace('\r', '')
        got = [(m.group(2), int(m.group(3)), int(m.group(4))) for m in ambush_rule.CREATE_RE.finditer(dec_post[area])]
        exp = [(m.group(2), int(m.group(3)), int(m.group(4))) for m in ambush_rule.CREATE_RE.finditer(agree_baf)]
        assert got == exp

    # Hostile BG5600 block relocated to Fog-of-War, JumpToPoint left untouched
    bg5600_blocks = list(ambush_rule.BLOCK_RE.finditer(dec_post['BG5600']))
    assert len(bg5600_blocks) == 3  # ON + OFF + untouched CUT
    assert ambush_rule.AMBUSH_ON_LINE.strip() in bg5600_blocks[0].group(0)
    assert ambush_rule.AMBUSH_OFF_LINE.strip() in bg5600_blocks[1].group(0)
    for m in ambush_rule.CREATE_RE.finditer(bg5600_blocks[0].group(0)):
        d = ((int(m.group(3)) - 640) ** 2 + (int(m.group(4)) - 480) ** 2) ** 0.5
        assert 480 <= d <= 700
    assert 'JumpToPoint([500.500])' in bg5600_blocks[2].group(0)
    assert 'BGSE_AmbushOn' not in bg5600_blocks[2].group(0)

    # AR0041: dialogue block relocated, planar block relocated, RENFELD untouched
    ar0041_blocks = list(ambush_rule.BLOCK_RE.finditer(dec_post['AR0041']))
    assert len(ar0041_blocks) == 5  # DLG ON + DLG OFF + GTH ON + GTH OFF + RENFELD
    dlg_spawns = {m.group(2): ((int(m.group(3)) - 513) ** 2 + (int(m.group(4)) - 528) ** 2) ** 0.5
                  for m in ambush_rule.CREATE_RE.finditer(ar0041_blocks[0].group(0))}
    assert 300 <= dlg_spawns['TALKER'] <= 355
    assert 365 <= dlg_spawns['KOBOLD'] <= 485
    assert 365 <= dlg_spawns['RESUNA'] <= 485
    for m in ambush_rule.CREATE_RE.finditer(ar0041_blocks[2].group(0)):
        d = ((int(m.group(3)) - 513) ** 2 + (int(m.group(4)) - 528) ** 2) ** 0.5
        assert 175 <= d <= 275
    assert 'CreateCreature("RENFELD",[960.860]' in ar0041_blocks[4].group(0)
    assert 'BGSE_AmbushOn' not in ar0041_blocks[4].group(0)

    # Reinstall idempotency and uninstall byte-identity
    reinst = _invoke(weidu, tmp_path, 'bgse/setup-bgse.tp2', '--force-uninstall-list', '0', '--force-install-list', '0')
    assert reinst.returncode == 0, reinst.stdout
    assert _snapshot(tmp_path) == installed

    uninst = _invoke(weidu, tmp_path, 'bgse/setup-bgse.tp2', '--force-uninstall-list', '0')
    assert uninst.returncode == 0, uninst.stdout
    assert _snapshot(tmp_path) == before
