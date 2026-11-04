"""tools/srmap.py: an area's search map drawn as text from its SR bitmap (4 bits a cell)."""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools import srmap  # noqa: E402


def bitmap(rows):
    """A 4-bit BMP of the given cell values, top row first (stored bottom-up, rows padded to 4 bytes)."""
    width, height = len(rows[0]), len(rows)
    stride = ((width * 4 + 31) // 32) * 4
    pixels = b''
    for values in reversed(rows):
        packed = bytearray()
        for i in range(0, width, 2):
            high = values[i]
            low = values[i + 1] if i + 1 < width else 0
            packed.append(high << 4 | low)
        pixels += bytes(packed) + b'\0' * (stride - len(packed))
    palette = b'\0' * 64
    offset = 14 + 40 + len(palette)
    header = b'BM' + struct.pack('<IHHI', offset + len(pixels), 0, 0, offset)
    info = struct.pack('<IiiHHIIiiII', 40, width, height, 1, 4, 0, len(pixels), 0, 0, 16, 0)
    return header + info + palette + pixels


def test_draws_walls_blocked_cells_and_marks(tmp_path):
    (tmp_path / 'override').mkdir()
    (tmp_path / 'override' / 'TESTSR.BMP').write_bytes(bitmap([[0, 5, 8, 1], [1, 1, 1, 10]]))
    cell, width, rows = srmap.search_map(tmp_path, 'TEST')
    assert (width, rows) == (4, 2)
    assert [cell(x, 0) for x in range(4)] == [0, 5, 8, 1] and cell(4, 0) is None
    assert srmap.draw(cell, 0, 0, 63, 23, {(1, 1): 'M'}) == ['    0 #.x.', '   12 .M.x']


def test_no_bitmap_and_a_short_call(tmp_path, capsys):
    (tmp_path / 'override').mkdir()
    assert srmap.search_map(tmp_path, 'NONE') is None
    assert srmap.main([str(tmp_path), 'NONE', '0', '0', '10', '10']) == 1
    assert srmap.main([]) == 2
    assert 'search map' in capsys.readouterr().out
