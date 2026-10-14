"""The reference hook rule on synthetic SCS-like scripts (no WeiDU needed)."""
from pathlib import Path

import pytest

from tools import hook_rule

FIXTURES = Path(__file__).resolve().parents[1] / 'fixtures/hook'


def text(name):
    return (FIXTURES / f'{name}.baf').read_text(encoding='utf-8')


def test_mage_hook_sits_before_the_action_choice_with_guarded_copies():
    source = text('B-HKMAG')
    spans, anchor, copies = hook_rule.plan(source)
    # Setup, prebuff, first-round cast and cloud escape stay above; the alacrity block is the
    # first block of the per-round choice.
    assert anchor == 4
    # Two target picks and the special that aims at LastSeenBy, then the bookkeeping run with
    # its state-only middle block. The filler, the item-free state block, the perceiving
    # item block and the spellbook-gated ForceSpellRES are not copied.
    assert copies == [5, 6, 7, 8, 9, 10]
    patched, reason, family, count = hook_rule.patch(source)
    assert (reason, family, count) == ('hooked', 'mage', 6)
    head = source[:spans[anchor][0]]
    assert patched.startswith(head) and patched.endswith(source[spans[anchor][0]:])
    inserted = patched[len(head):len(patched) - len(source) + len(head)]
    guard = hook_rule.guard('mage')
    assert inserted.count('IF\n  ' + guard + '\n') == 7
    assert inserted.endswith(hook_rule.hook_block('mage'))
    # Each copy is its original block with the guard as first trigger.
    for i in copies:
        block = source[spans[i][0]:spans[i][1]]
        assert block.replace('IF\n', 'IF\n  ' + guard + '\n', 1) in inserted


def test_priest_keeps_blade_bookkeeping_and_engine_owns_turn_undead():
    spans, anchor, copies = hook_rule.plan(text('B-HKPRI'))
    assert anchor == 1 and copies == [3, 4]
    assert hook_rule.patch(text('B-HKPRI'))[1:] == ('hooked', 'priest', 2)


def test_ranged_general_ai_skips_the_retarget_block():
    spans, anchor, copies = hook_rule.plan(text('B-HKRNG'))
    assert anchor == 3 and copies == []
    assert hook_rule.patch(text('B-HKRNG'))[1:] == ('hooked', 'fighter', 0)


@pytest.mark.parametrize('name,reason', [
    ('B-HKNOA', 'no-anchor'), ('B-HKOLD', 'already-hooked'), ('B-HKCST', 'no-castspell'),
    ('B-HKNON', 'not-scs'), ('B-HKVAN', 'not-scs'),
])
def test_scripts_left_as_they_are(name, reason):
    patched, why, _, count = hook_rule.patch(text(name))
    assert patched is None and why == reason and count == 0


def test_windows_line_ends_give_the_same_result():
    source = text('B-HKMAG')
    assert hook_rule.patch(source.replace('\n', '\r\n')) == hook_rule.patch(source)


def test_hook_never_ends_with_continue_and_guards_come_first():
    block = hook_rule.hook_block('fighter')
    assert 'Continue()' not in block
    assert block.startswith('IF\n  EEex_LuaTrigger("return BGSE_Claim and BGSE_Claim(EEex_LuaTrigger_Object,\'fighter\') or false")\n')
    assert '"' not in hook_rule.guard('mage')[len('EEex_LuaTrigger("'):-2]
