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
    # Setup, prebuff, first-round cast, cloud escape, SCS's stand-still in a cloud and its run
    # from a Cloudkill stay above; the alacrity block is the first block of the per-round choice.
    assert anchor == 6
    # Two target picks and the special that aims at LastSeenBy, then the bookkeeping run with
    # its state-only middle block. The perceiving item block is not bookkeeping, but making
    # an item is more than a combat round, so it is kept too. The filler, the item-free state
    # block and the spellbook-gated ForceSpellRES are not copied.
    assert copies == [7, 8, 9, 10, 11, 12, 15]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMAG')
    assert (reason, family, count) == ('hooked', 'mage', 7)
    # Above the hook only the cloud blocks change (test_cloud_blocks_above_...).
    head = source[:spans[anchor][0]]
    for i in (3, 4, 5):
        cloud = source[spans[i][0]:spans[i][1]]
        head = head.replace(cloud, hook_rule.stand_aside(cloud, 'mage', 'b-hkmag'), 1)
    tail = source[spans[anchor][0]:]
    assert patched.startswith(head) and patched.endswith(tail)
    inserted = patched[len(head):len(patched) - len(tail)]
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
    assert anchor == 4 and copies == []
    assert hook_rule.patch(text('B-HKRNG'), 'B-HKRNG')[1:] == ('hooked', 'fighter', 0)


@pytest.mark.parametrize('name,reason', [
    ('B-HKNOA', 'no-anchor'), ('B-HKOLD', 'already-hooked'), ('B-HKCST', 'no-castspell'),
    ('B-HKNON', 'not-scs'), ('B-HKVAN', 'not-scs'),
])
def test_scripts_left_as_they_are(name, reason):
    patched, why, _, count = hook_rule.patch(text(name), name)
    assert patched is None and why == reason and count == 0


def test_cloud_blocks_above_the_hook_yield_to_the_engine():
    # The mage's escape (SCS's fleecloud blocks), its stand-still while it hears a cloud and sees
    # no enemy and its run from a Cloudkill's marker before it sees the enemy (gohostile) take the
    # condition after their own triggers (lab batches H7 and H8: out of the party's sight, SCS's
    # run from a cloud's marker and its stand-still kept casters in clouds for more than 30
    # seconds).
    source = text('B-HKMAG')
    spans, anchor, _ = hook_rule.plan(source)
    assert hook_rule.clouds(source, spans, anchor) == [3, 4, 5]
    patched = hook_rule.patch(source, 'B-HKMAG')[0]
    zones = hook_rule.zones_guard('mage', 'b-hkmag')
    assert zones == ('EEex_LuaTrigger("return BGSE_Zones and BGSE_Zones(EEex_LuaTrigger_Object,'
                     "'mage','b-hkmag') or false\")")
    escape = ('    !See(NearestEnemyOf(Myself))\n  !' + zones +
              '\nTHEN\n  RESPONSE #100\n    SetGlobalTimer("seencloud","LOCALS",20)\n')
    still = '    Heard([ANYONE],411)\n  !' + zones + '\nTHEN\n  RESPONSE #100\n    NoAction()\nEND\n'
    run = ('  Range(LastHeardBy(Myself),20)\n  !' + zones + '\nTHEN\n  RESPONSE #100\n    SetInterrupt(FALSE)\n'
           '    RunAwayFromNoLeaveArea(LastHeardBy(Myself),45)\n')
    assert patched.count(escape) == 1 and patched.count(still) == 1 and patched.count(run) == 1
    assert patched.count(zones) == 3
    # The ranged fighter's escape ends in an OR group that lacks a member: the condition goes
    # first. Its escape below the hook runs only when the engine declines and stays, and so does
    # its NoAction() that listens for no cloud.
    source = text('B-HKRNG')
    spans, anchor, _ = hook_rule.plan(source)
    assert hook_rule.clouds(source, spans, anchor) == [3]
    patched = hook_rule.patch(source, 'B-HKRNG')[0]
    zones = hook_rule.zones_guard('fighter', 'b-hkrng')
    assert patched.count('IF\n  !' + zones + '\n  !INI("DMWW_genai_difficulty",1)\n  Heard([ANYONE],407)\n') == 1
    assert source[spans[5][0]:spans[5][1]] in patched and patched.count(zones) == 1
    assert patched.startswith(source[spans[0][0]:spans[0][1]])


@pytest.mark.parametrize('triggers,actions,cloud', [
    (['Heard([ANYONE],404)'], ['SetGlobalTimer("seencloud","LOCALS",20)', 'RunAwayFrom(LastHeardBy(Myself),30)'], True),
    (['!See(NearestEnemyOf(Myself))', 'Heard([ANYONE],413)'], ['NoAction()'], True),
    (['!See(NearestEnemyOf(Myself))', 'Heard([ANYONE],403)'], ['NoAction()'], False),
    (['!See(NearestEnemyOf(Myself))', 'Heard([ANYONE],414)'], ['NoAction()'], False),
    (['Heard([ANYONE],410)'], ['NoAction()', 'Continue()'], False),
    (['Global("removedpotions","LOCALS",1)'], ['NoAction()'], False),
    # A run from the marker it heard, with or without the interrupt switches (gohostile).
    (['Heard([ANYONE],404)', '!See([PC])'],
     ['SetInterrupt(FALSE)', 'RunAwayFromNoLeaveArea(LastHeardBy(Myself),45)', 'SetInterrupt(TRUE)'], True),
    (['OR(2)', '  Heard([ANYONE],405)', '  Heard([ANYONE],409)'], ['RunAwayFrom(LastHeardBy(Myself),30)'], True),
    # Not a cloud's marker, a run from someone else, more than a run, or listening for no cloud.
    (['Heard([ANYONE],99)'], ['RunAwayFromNoLeaveArea(LastHeardBy(Myself),180)'], False),
    (['Heard([ANYONE],404)'], ['RunAwayFromNoLeaveArea(NearestEnemyOf(Myself),45)'], False),
    (['Heard([ANYONE],404)'], ['SetInterrupt(FALSE)', 'RunAwayFromNoLeaveArea(LastHeardBy(Myself),45)',
                               'Spell(Myself,WIZARD_MIRROR_IMAGE)'], False),
    (['!Heard([ANYONE],404)'], ['RunAwayFromNoLeaveArea(LastHeardBy(Myself),45)'], False),
    (['!Heard([ANYONE],404)', '!See(NearestEnemyOf(Myself))'], ['NoAction()'], False),
])
def test_cloud_blocks_are_escapes_or_a_stand_still_on_a_marker_shout(triggers, actions, cloud):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    assert hook_rule.is_cloud(f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n') is cloud


@pytest.mark.parametrize('triggers,first', [
    (['Heard([ANYONE],404)'], False),
    (['OR(2)', '  A()', '  B()'], False),
    (['OR(2)', '  A()', '  B()', 'C()'], False),
    (['OR(3)', '  A()', '  B()'], True),
    (['OR(2)', '  A()', '  B()', 'OR(2)', '  C()'], True),
])
def test_cloud_condition_goes_last_unless_an_or_group_lacks_members(triggers, first):
    lines = ''.join(f'  {t}\n' for t in triggers)
    block = f'IF\n{lines}THEN\n  RESPONSE #100\n    SetGlobalTimer("seencloud","LOCALS",20)\nEND\n'
    out = hook_rule.stand_aside(block, 'mage', 'dw#mg1')
    condition = '  !' + hook_rule.zones_guard('mage', 'dw#mg1') + '\n'
    assert out == (f'IF\n{condition}{lines}' if first else f'IF\n{lines}{condition}') + block[block.index('THEN\n'):]


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
    # innate power, the summon with its target pick, the escape, the death handler, the
    # allegiance change, the scripted heal cast with SpellNoDecRES and the two steps of a
    # shape change the creature applies to itself. The ordinary attacks, the wandering, the
    # two spellbook casts (checked with HaveSpell, or used up with RemoveSpell), the
    # self-application checked with HaveSpellRES and the power applied to an enemy are the
    # engine's.
    assert anchor == 1 and copies == [2, 3, 4, 6, 7, 8, 10, 13, 14]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMON')
    assert (reason, family, count) == ('hooked', 'monster', 9)
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


@pytest.mark.parametrize('trigger,actions,special', [
    ('See(NearestEnemyOf(Myself))', ['SpellNoDec(NearestEnemyOf(Myself),WIZARD_MAGIC_MISSILE)'], True),
    ('See(NearestEnemyOf(Myself))', ['SpellNoDecRES("b-hkheal",Myself)'], True),
    ('HaveSpell(WIZARD_MAGIC_MISSILE)', ['SpellNoDec(NearestEnemyOf(Myself),WIZARD_MAGIC_MISSILE)'], False),
    ('HaveSpellRES("b-hkheal")', ['SpellNoDecRES("b-hkheal",Myself)'], False),
    ('See(NearestEnemyOf(Myself))', ['SpellNoDec(NearestEnemyOf(Myself),WIZARD_MAGIC_MISSILE)',
                                     'RemoveSpell(WIZARD_MAGIC_MISSILE)'], False),
    ('See(NearestEnemyOf(Myself))', ['Spell(NearestEnemyOf(Myself),WIZARD_MAGIC_MISSILE)'], False),
    ('See(NearestEnemyOf(Myself))', ['ReallyForceSpellRES("b-hkpow",Myself)', 'RemoveSpell(2124)'], True),
])
def test_scripted_casts_without_a_spellbook_check_are_specials(trigger, actions, special):
    lines = ''.join(f'    {a}\n' for a in actions)
    block = f'IF\n  {trigger}\nTHEN\n  RESPONSE #100\n{lines}END\n'
    assert hook_rule.is_special(block) is special


@pytest.mark.parametrize('trigger,actions,special', [
    ('Global("israt","LOCALS",1)', ['Wait(1)', 'ApplySpellRES("b-hkhid",Myself)', 'SetGlobal("israt","LOCALS",2)'], True),
    ('See(NearestEnemyOf(Myself))', ['ApplySpell(Myself,WIZARD_MIRROR_IMAGE)'], True),
    ('See([PC.0.0.MAGE])', ['ApplySpellRES("b-hknat",Myself)', 'AttackOneRound([PC.0.0.MAGE])'], True),
    # Checked against the spellbook, or applied to someone else: not the creature's own power.
    ('HaveSpellRES("b-hkhid")', ['ApplySpellRES("b-hkhid",Myself)'], False),
    ('See(NearestEnemyOf(Myself))', ['ApplySpellRES("b-hkpow",NearestEnemyOf(Myself))'], False),
    ('See(NearestEnemyOf(Myself))', ['ApplySpell(NearestEnemyOf(Myself),WIZARD_MIRROR_IMAGE)'], False),
])
def test_powers_a_creature_applies_to_itself_are_specials(trigger, actions, special):
    lines = ''.join(f'    {a}\n' for a in actions)
    block = f'IF\n  {trigger}\nTHEN\n  RESPONSE #100\n{lines}END\n'
    assert hook_rule.is_special(block) is special
