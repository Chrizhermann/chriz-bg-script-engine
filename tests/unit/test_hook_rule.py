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
    # its state-only middle block. The perceiving item block is not bookkeeping, but making
    # an item is more than a combat round, so it is kept too. The filler, the item-free state
    # block and the spellbook-gated ForceSpellRES are not copied.
    assert copies == [5, 6, 7, 8, 9, 10, 13]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMAG')
    assert (reason, family, count) == ('hooked', 'mage', 7)
    head = source[:spans[anchor][0]]
    assert patched.startswith(head) and patched.endswith(source[spans[anchor][0]:])
    inserted = patched[len(head):len(patched) - len(source) + len(head)]
    guard = hook_rule.guard('mage', 'b-hkmag')
    assert inserted.count('IF\n  ' + guard + '\n') == 8
    assert inserted.endswith(hook_rule.hook_block('mage', 'b-hkmag'))
    # Each copy is its original block with the guard as first trigger.
    for i in copies:
        block = source[spans[i][0]:spans[i][1]]
        assert block.replace('IF\n', 'IF\n  ' + guard + '\n', 1) in inserted


def test_priest_keeps_blade_bookkeeping_and_engine_owns_turn_undead():
    spans, anchor, copies = hook_rule.plan(text('B-HKPRI'))
    assert anchor == 1 and copies == [3, 4]
    assert hook_rule.patch(text('B-HKPRI'), 'B-HKPRI')[1:] == ('hooked', 'priest', 2)


def test_ranged_general_ai_skips_the_retarget_block():
    spans, anchor, copies = hook_rule.plan(text('B-HKRNG'))
    assert anchor == 3 and copies == []
    assert hook_rule.patch(text('B-HKRNG'), 'B-HKRNG')[1:] == ('hooked', 'fighter', 0)


@pytest.mark.parametrize('name,reason', [
    ('B-HKNOA', 'no-anchor'), ('B-HKOLD', 'already-hooked'), ('B-HKCST', 'no-castspell'),
    ('B-HKNON', 'not-scs'), ('B-HKVAN', 'not-scs'),
])
def test_scripts_left_as_they_are(name, reason):
    patched, why, _, count = hook_rule.patch(text(name), name)
    assert patched is None and why == reason and count == 0


def test_windows_line_ends_give_the_same_result():
    source = text('B-HKMAG')
    assert hook_rule.patch(source.replace('\n', '\r\n'), 'B-HKMAG') == hook_rule.patch(source, 'B-HKMAG')


def test_hook_never_ends_with_continue_and_guards_come_first():
    block = hook_rule.hook_block('fighter', 'dw2ms2ge')
    assert 'Continue()' not in block
    assert block.startswith('IF\n  EEex_LuaTrigger("return BGSE_Claim and BGSE_Claim(EEex_LuaTrigger_Object,'
                            "'fighter','dw2ms2ge') or false\")\n")
    assert '"' not in hook_rule.guard('mage', 'dw#mg1')[len('EEex_LuaTrigger("'):-2]


def test_monster_script_keeps_specials_and_everything_beyond_a_combat_round():
    source = text('B-HKMON')
    spans, anchor, copies = hook_rule.plan(source)
    # The setup block stays above; the first round-timer block is the anchor. Copied: the
    # innate power, the summon with its target pick, the escape, the death handler and the
    # allegiance change. The ordinary attacks and the wandering are the engine's.
    assert anchor == 1 and copies == [2, 3, 4, 6, 7, 8]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMON')
    assert (reason, family, count) == ('hooked', 'monster', 6)
    assert hook_rule.guard('monster', 'b-hkmon') in patched


def test_blocks_left_to_the_engine_are_ordinary_combat_rounds():
    for name in ('B-HKMAG', 'B-HKPRI', 'B-HKRNG', 'B-HKMON'):
        source = text(name)
        spans, anchor, copies = hook_rule.plan(source)
        for i in range(anchor, len(spans)):
            if i not in copies:
                assert not hook_rule.is_encounter(source[spans[i][0]:spans[i][1]]), (name, i)


def test_script_names_are_lower_case_and_must_be_safe_in_lua_text():
    source = text('B-HKMAG')
    assert hook_rule.patch(source, 'B-HKMAG') == hook_rule.patch(source, 'b-hkmag')
    for name in ("b'hk", 'b"hk', 'b\\hk'):
        assert hook_rule.patch(source, name)[:2] == (None, 'unsafe-name')
