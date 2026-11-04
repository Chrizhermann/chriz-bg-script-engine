"""Draw part of an area's search map as text, read-only, to see the walls behind a stuck walk.

The search map is the area's SR bitmap (4 bits a cell, cells 16 by 12 world units). Each cell
prints as '.' (walkable), '#' (value 0: blocks walking and sight) or 'x' (another value that
blocks walking: 8, 10, 12, 13). Marks put a letter on the cell of a world spot.

    python -I tools/srmap.py <game folder> BG2300 3250 1500 3850 2250 3394,2052=S 3742,1931=E

(lab batch E8 v4: Tarnesh's step into the Friendly Arm Inn's walls, docs/learned.md section 5)
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tools import ie_resources as ie  # noqa: E402

BLOCKED = {8, 10, 12, 13}


def search_map(game, area):
    """(cell(cx, cy) -> value or None, width, height) of the area's SR bitmap, or None."""
    data = ie.Game(game).get(area + 'SR', 'BMP')
    if not data or data[:2] != b'BM':
        return None
    offset = struct.unpack_from('<I', data, 10)[0]
    width, height = struct.unpack_from('<ii', data, 18)
    if struct.unpack_from('<H', data, 28)[0] != 4:
        return None
    row = ((width * 4 + 31) // 32) * 4
    rows = abs(height)

    def cell(cx, cy):
        if not (0 <= cx < width and 0 <= cy < rows):
            return None
        ry = rows - 1 - cy if height > 0 else cy
        byte = data[offset + ry * row + cx // 2]
        return byte >> 4 if cx % 2 == 0 else byte & 15
    return cell, width, rows


def draw(cell, x0, y0, x1, y1, marks):
    lines = []
    for cy in range(y0 // 12, y1 // 12 + 1):
        text = ''
        for cx in range(x0 // 16, x1 // 16 + 1):
            if (cx, cy) in marks:
                text += marks[(cx, cy)]
                continue
            value = cell(cx, cy)
            text += '?' if value is None else '#' if value == 0 else 'x' if value in BLOCKED else '.'
        lines.append(f'{cy * 12:5d} {text}')
    return lines


def main(argv):
    if len(argv) < 6:
        print(__doc__)
        return 2
    game, area = argv[0], argv[1].upper()
    x0, y0, x1, y1 = (int(v) for v in argv[2:6])
    marks = {}
    for mark in argv[6:]:
        spot, letter = mark.split('=')
        x, y = (int(v) for v in spot.split(','))
        marks[(x // 16, y // 12)] = letter[:1]
    found = search_map(game, area)
    if not found:
        print(f'{area}SR.BMP not found or not a 4-bit bitmap')
        return 1
    cell, width, rows = found
    print(f'{area}SR {width}x{rows} cells; x {x0}-{x1}, y {y0}-{y1}; # blocks walking and sight, x walking')
    print('\n'.join(draw(cell, x0, y0, x1, y1, marks)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
