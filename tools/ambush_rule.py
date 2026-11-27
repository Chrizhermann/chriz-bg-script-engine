"""Reference version of install-time sensible travel-ambush relocation (bgse/lib/ambush.tpa does the same in WeiDU).

Patches random-encounter area scripts (BG5600..BG6100, AR0041..AR0046) so ambush packs spawn
on verified walkable search-map cells at sensible distances instead of inside the party's
formation, while preserving vanilla coordinates behind !BGSE_AmbushOn() for clean fallback.
"""
import re
import struct
from pathlib import Path

TARGET_AREAS = (
    'BG5600', 'BG5601', 'BG5700', 'BG5701', 'BG5800', 'BG5801',
    'BG5900', 'BG5901', 'BG6000', 'BG6001', 'BG6100',
    'AR0041', 'AR0042', 'AR0043', 'AR0044', 'AR0045', 'AR0046',
)
AREA_INDEX = {name: i for i, name in enumerate(TARGET_AREAS)}

AMBUSH_MARK = 'BGSE_AmbushOn'
AMBUSH_ON_LINE = '  EEex_LuaTrigger("return BGSE_AmbushOn and BGSE_AmbushOn() or false")'
AMBUSH_OFF_LINE = '  !EEex_LuaTrigger("return BGSE_AmbushOn and BGSE_AmbushOn() or false")'

BLOCKED_CELLS = frozenset({0, 8, 10, 12, 13})
SKIP_ACTIONS = ('JumpToPoint(', 'MoveBetweenAreas(', 'LeaveAreaLUA', 'CreateCreatureImpassable(')
DIALOGUE_MARKS = ('MoveViewObject(', 'DisplayStringHead(', 'Dialogue(', 'StartDialog')

BLOCK_RE = re.compile(r'^IF\n.*?\nEND\n', re.M | re.S)
OR_LINE = re.compile(r' +OR\((\d+)\)')
CREATE_RE = re.compile(
    r'^( {4}CreateCreature\("([^"]+)",\[(\d+)\.(\d+)\],)([A-Za-z0-9_]+)(\).*)$',
    re.M,
)


def area_anchors(area: str):
    up = area.upper()
    if up.startswith('AR004'):
        return 513, 528, 600, 500
    return 640, 480, 640, 480


def octant_of(dx: int, dy: int) -> int:
    ax = -dx if dx < 0 else dx
    ay = -dy if dy < 0 else dy
    if ay * 1000 <= ax * 414:
        return 0 if dx >= 0 else 4
    if ay * 1000 <= ax * 2414:
        if dx >= 0 and dy >= 0:
            return 1
        if dx < 0 and dy >= 0:
            return 3
        if dx < 0 and dy < 0:
            return 5
        return 7
    return 2 if dy >= 0 else 6


def oct_diff(a: int, b: int) -> int:
    d = (a - b) % 8
    return 8 - d if d > 4 else d


def facing_from_octant(octant: int) -> int:
    return (octant * 2 + 4) % 16


def parse_sr_bmp(data: bytes | None) -> tuple[int, int, bytearray]:
    """Return (width, height, grid) with 0=blocked/border, 1=walkable, 2=3x3 fat-walkable."""
    if not data or len(data) < 54 or data[:2] != b'BM':
        w, h = 80, 80
        grid = bytearray([2] * (w * h))
        for cy in range(h):
            for cx in range(w):
                if cx < 4 or cx >= w - 4 or cy < 4 or cy >= h - 4:
                    grid[cy * w + cx] = 0
        return w, h, grid

    offset = struct.unpack_from('<I', data, 10)[0]
    w, raw_h = struct.unpack_from('<ii', data, 18)
    bpp = struct.unpack_from('<H', data, 28)[0]
    h = -raw_h if raw_h < 0 else raw_h
    if w <= 0 or h <= 0 or bpp != 4:
        return parse_sr_bmp(None)

    stride = ((w * 4 + 31) // 32) * 4
    raw_walk = bytearray(w * h)
    for cy in range(h):
        ry = h - 1 - cy if raw_h > 0 else cy
        row_off = offset + ry * stride
        if row_off + (w + 1) // 2 > len(data):
            continue
        for cx in range(w):
            b = data[row_off + (cx >> 1)]
            nib = (b >> 4) if (cx & 1) == 0 else (b & 15)
            raw_walk[cy * w + cx] = 0 if nib in BLOCKED_CELLS else 1

    grid = bytearray(w * h)
    use_border = w > 8 and h > 8
    for cy in range(h):
        for cx in range(w):
            idx = cy * w + cx
            if raw_walk[idx] == 0:
                continue
            if use_border and (cx < 4 or cx >= w - 4 or cy < 4 or cy >= h - 4):
                continue
            fat = 1
            for dy in (-1, 0, 1):
                ny = cy + dy
                if ny < 0 or ny >= h:
                    fat = 0
                    break
                for dx in (-1, 0, 1):
                    nx = cx + dx
                    if nx < 0 or nx >= w or raw_walk[ny * w + nx] == 0:
                        fat = 0
                        break
                if fat == 0:
                    break
            grid[idx] = 2 if fat else 1
    return w, h, grid


def build_candidates(area: str, bmp_bytes: bytes | None) -> list[tuple[int, int, int, int, int, int]]:
    """Return candidate tuples (x, y, octant, quality, p_sq, m_sq) sorted by (y, x)."""
    w, h, grid = parse_sr_bmp(bmp_bytes)
    ax, ay, ax2, ay2 = area_anchors(area)
    cands = []
    for cy in range(h):
        y = cy * 12 + 6
        dy = y - ay
        dy2 = y - ay2
        for cx in range(w):
            q = grid[cy * w + cx]
            if q == 0:
                continue
            x = cx * 16 + 8
            dx = x - ax
            dx2 = x - ax2
            p_sq = dx * dx + dy * dy
            m_sq2 = dx2 * dx2 + dy2 * dy2
            m_sq = p_sq if p_sq <= m_sq2 else m_sq2
            if m_sq <= 490000 and p_sq >= 30625:
                cands.append((x, y, octant_of(dx, dy), q, p_sq, m_sq))
    return cands


def _open_or(trig: str) -> bool:
    lines = trig.split('\n')[1:]
    for i in range(len(lines) - 1, -1, -1):
        m = OR_LINE.match(lines[i])
        if m:
            return len(lines) - 1 - i < int(m.group(1))
    return False


def aside(block: str, condition: str) -> str:
    then = block.find('\nTHEN\n')
    trig, resp = block[:then], block[then:]
    if _open_or(trig):
        return 'IF\n' + condition + '\n' + block[len('IF\n'):]
    return trig + '\n' + condition + resp


def _spaced(x: int, y: int, placed: list[tuple[int, int]], min_space_sq: int) -> bool:
    for px, py in placed:
        dx = x - px
        dy = y - py
        if dx * dx + dy * dy < min_space_sq:
            return False
    return True


def _pick_ring(cands, placed, ring_lo: int, ring_hi: int, target_sq: int, target_oct: int,
               min_q: int, min_space_sq: int, use_min_sq: bool):
    best = None
    best_score = None
    for c in cands:
        x, y, octant, q, p_sq, m_sq = c
        if q < min_q:
            continue
        d_sq = m_sq if use_min_sq else p_sq
        if d_sq < ring_lo or d_sq > ring_hi:
            continue
        if not _spaced(x, y, placed, min_space_sq):
            continue
        od = oct_diff(octant, target_oct)
        diff = d_sq - target_sq
        if diff < 0:
            diff = -diff
        score = od * 1000000 + diff
        if best is None or score < best_score:
            best = c
            best_score = score
    return best


def _pick_near(cands, placed, ring_lo: int, ring_hi: int, anchor_x: int, anchor_y: int,
               min_q: int, min_space_sq: int, use_min_sq: bool,
               dot_ref: tuple[int, int, int, int] | None = None):
    best = None
    best_dist = None
    for c in cands:
        x, y, octant, q, p_sq, m_sq = c
        if q < min_q:
            continue
        d_sq = m_sq if use_min_sq else p_sq
        if d_sq < ring_lo or d_sq > ring_hi:
            continue
        if dot_ref is not None:
            ax, ay, lx, ly = dot_ref
            if (x - ax) * (lx - ax) + (y - ay) * (ly - ay) <= 0:
                continue
        if not _spaced(x, y, placed, min_space_sq):
            continue
        dx = x - anchor_x
        dy = y - anchor_y
        dist = dx * dx + dy * dy
        if best is None or dist < best_dist:
            best = c
            best_dist = dist
    return best


def _all_pairwise_ok(points: list[tuple[int, int]], min_sq: int) -> bool:
    for i in range(len(points)):
        x1, y1 = points[i]
        for j in range(i + 1, len(points)):
            dx = x1 - points[j][0]
            dy = y1 - points[j][1]
            if dx * dx + dy * dy < min_sq:
                return False
    return True


def relocate_block(
    block: str,
    area: str,
    block_idx: int,
    cands: list[tuple[int, int, int, int, int, int]],
    talkers: frozenset[str] = frozenset(),
) -> str | None:
    """Return relocated+original dual-block replacement, or None if block stays untouched."""
    if AMBUSH_MARK in block:
        return None
    if any(act in block for act in SKIP_ACTIONS):
        return None

    matches = list(CREATE_RE.finditer(block))
    if not matches:
        return None

    ax, ay, ax2, ay2 = area_anchors(area)
    area_idx = AREA_INDEX.get(area.upper(), 0)
    spawns = []
    for m in matches:
        res = m.group(2).upper()
        x = int(m.group(3))
        y = int(m.group(4))
        dx, dy = x - ax, y - ay
        dx2, dy2 = x - ax2, y - ay2
        p_sq = dx * dx + dy * dy
        m_sq2 = dx2 * dx2 + dy2 * dy2
        m_sq = p_sq if p_sq <= m_sq2 else m_sq2
        spawns.append({
            'res': res,
            'x': x,
            'y': y,
            'p_sq': p_sq,
            'm_sq': m_sq,
            'planar': res.startswith('GITH'),
            'talker': res in talkers,
        })

    n = len(spawns)
    planar_cnt = sum(1 for s in spawns if s['planar'])
    if planar_cnt > 0 and planar_cnt * 2 >= n:
        mode = 'planar'
    elif any(s['talker'] for s in spawns) or any(mark in block for mark in DIALOGUE_MARKS):
        mode = 'dialogue'
    else:
        mode = 'hostile'

    pts = [(s['x'], s['y']) for s in spawns]
    if mode == 'planar':
        if all(s['p_sq'] >= 25600 for s in spawns) and _all_pairwise_ok(pts, 2304):
            return None
    elif mode == 'dialogue':
        if all(s['p_sq'] >= 48400 for s in spawns) and _all_pairwise_ok(pts, 1600):
            return None
    else:
        if all(s['m_sq'] >= 216225 for s in spawns) and _all_pairwise_ok(pts, 2304):
            return None

    seed_oct = (block_idx * 3 + area_idx) % 8
    chosen: list[tuple[int, int, int] | None] = [None] * n
    placed: list[tuple[int, int]] = []

    if mode == 'planar':
        for i in range(n):
            toct = (seed_oct + i * 2) % 8
            pick = (
                _pick_ring(cands, placed, 30625, 75625, 50625, toct, 2, 3136, False)
                or _pick_ring(cands, placed, 30625, 75625, 50625, toct, 1, 3136, False)
                or _pick_ring(cands, placed, 30625, 75625, 50625, toct, 1, 1600, False)
            )
            if pick is None:
                return None
            chosen[i] = (pick[0], pick[1], facing_from_octant(pick[2]))
            placed.append((pick[0], pick[1]))
    elif mode == 'dialogue':
        leader_idx = 0
        for i, s in enumerate(spawns):
            if s['talker']:
                leader_idx = i
                break
        lpick = (
            _pick_ring(cands, placed, 90000, 126025, 105625, seed_oct, 2, 3136, False)
            or _pick_ring(cands, placed, 90000, 126025, 105625, seed_oct, 1, 3136, False)
        )
        if lpick is None:
            return None
        lx, ly = lpick[0], lpick[1]
        chosen[leader_idx] = (lx, ly, facing_from_octant(lpick[2]))
        placed.append((lx, ly))
        dot_ref = (ax, ay, lx, ly)
        for i in range(n):
            if i == leader_idx:
                continue
            pick = (
                _pick_near(cands, placed, 133225, 235225, lx, ly, 2, 3136, False, dot_ref)
                or _pick_near(cands, placed, 133225, 235225, lx, ly, 1, 3136, False, dot_ref)
                or _pick_near(cands, placed, 133225, 235225, lx, ly, 1, 3136, False, None)
                or _pick_near(cands, placed, 133225, 235225, lx, ly, 1, 1600, False, None)
            )
            if pick is None:
                return None
            chosen[i] = (pick[0], pick[1], facing_from_octant(pick[2]))
            placed.append((pick[0], pick[1]))
    else:
        flanks = 1 if n <= 2 else (2 if n <= 7 else 3)
        flank_octs = [seed_oct]
        if flanks >= 2:
            flank_octs.append((seed_oct + 3) % 8)
        if flanks >= 3:
            flank_octs.append((seed_oct + 5) % 8)
        anchors = [None] * flanks
        for i in range(n):
            f = i % flanks
            if anchors[f] is None:
                pick = (
                    _pick_ring(cands, placed, 230400, 490000, 291600, flank_octs[f], 2, 3136, True)
                    or _pick_ring(cands, placed, 230400, 490000, 291600, flank_octs[f], 1, 3136, True)
                    or _pick_ring(cands, placed, 230400, 490000, 291600, flank_octs[f], 1, 1600, True)
                )
                if pick is None:
                    return None
                anchors[f] = (pick[0], pick[1])
            else:
                fx, fy = anchors[f]
                pick = (
                    _pick_near(cands, placed, 230400, 490000, fx, fy, 2, 3136, True, None)
                    or _pick_near(cands, placed, 230400, 490000, fx, fy, 1, 3136, True, None)
                    or _pick_near(cands, placed, 230400, 490000, fx, fy, 1, 1600, True, None)
                )
                if pick is None:
                    return None
            chosen[i] = (pick[0], pick[1], facing_from_octant(pick[2]))
            placed.append((pick[0], pick[1]))

    parts = []
    pos = 0
    for i, m in enumerate(matches):
        nx, ny, nface = chosen[i]
        parts.append(block[pos:m.start()])
        parts.append(f'    CreateCreature("{m.group(2)}",[{nx}.{ny}],{nface}{m.group(6)}')
        pos = m.end()
    parts.append(block[pos:])
    relocated = ''.join(parts)
    return aside(relocated, AMBUSH_ON_LINE) + aside(block, AMBUSH_OFF_LINE)


def patch_ambush_baf(
    text: str,
    area: str,
    bmp_bytes: bytes | None = None,
    talkers: frozenset[str] = frozenset(),
) -> tuple[str, int]:
    """Patch a decompiled random-encounter area script. Returns (new_text, changed_blocks)."""
    clean = text.replace('\r', '')
    if area.upper() not in AREA_INDEX or AMBUSH_MARK in clean:
        return clean, 0
    cands = build_candidates(area, bmp_bytes)
    if not cands:
        return clean, 0

    out = []
    pos = 0
    changed = 0
    for block_idx, m in enumerate(BLOCK_RE.finditer(clean)):
        block = m.group(0)
        replacement = relocate_block(block, area, block_idx, cands, talkers)
        out.append(clean[pos:m.start()])
        if replacement is not None:
            out.append(replacement)
            changed += 1
        else:
            out.append(block)
        pos = m.end()
    out.append(clean[pos:])
    return ''.join(out), changed
