"""What keeps a creature that perceives nobody from reaching the hook: the blocks above the hook's anchor in a
decompiled SCS script that end a pass (a response without Continue()) and need no enemy in sight, with the kinds
tools/hook_rule.py gives each. Read this before a lab whenever a block above the hook is made to stand aside: the
pass then goes on to the next of these (2026-11-10: SCS's caster gate, HOOK-01 rule 15).

    python -I tools/above_hook.py <script.baf> [<script.baf> ...]
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hook_rule  # noqa: E402

KINDS = (('cloud', hook_rule.is_cloud), ('hunt', hook_rule.is_hunt), ('pursuit', hook_rule.is_pursuit),
         ('idle', hook_rule.is_idle), ('prep', hook_rule.prep_kind), ('book', hook_rule.is_bookkeeping),
         ('special', hook_rule.is_special), ('walk', hook_rule.party_walk))
SEES = re.compile(r'^\s+(?:See|Detect)\(', re.M)


def main(paths):
    for path in paths:
        text = Path(path).read_text(encoding='latin-1').replace('\r', '')
        spans = hook_rule.blocks(text)
        anchor = next((i for i, (a, b) in enumerate(spans) if hook_rule.is_anchor(text[a:b])), None)
        print(f'== {Path(path).stem}: {len(spans)} blocks, anchor {anchor}')
        if anchor is None:
            continue
        shown = 0
        for i, (a, b) in enumerate(spans[:anchor]):
            block = text[a:b]
            trig, _ = hook_rule.split(block)
            if all('Continue' in r for r in hook_rule.responses(block)) or SEES.search(trig):
                continue
            shown += 1
            print(f'-- block {i} {[k for k, f in KINDS if f(block)]}')
            print(block if len(block) < 900 else block[:900] + '\n   ...')
        print(f'   {shown} such blocks above the anchor')


if __name__ == '__main__':
    main(sys.argv[1:])
