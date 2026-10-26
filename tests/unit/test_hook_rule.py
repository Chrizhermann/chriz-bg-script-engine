"""The reference hook rule on synthetic SCS-like scripts (no WeiDU needed)."""
from pathlib import Path

import pytest

from tools import hook_rule

FIXTURES = Path(__file__).resolve().parents[1] / 'fixtures/hook'
# The fixtures' spells that move their caster (the integration test's fake game has them): the
# chase's b-hkfit and the jump's fiend teleport (SPELL.IDS 3159, SPIN159).
TELEPORTS = frozenset({'B-HKFIT', 'INNATE_FIEND_TELEPORT'})


def text(name):
    return (FIXTURES / f'{name}.baf').read_text(encoding='utf-8')


def guarded(source, spans, indices, condition):
    """The source with the condition added to the blocks at these indices."""
    for i in sorted(indices, reverse=True):
        a, b = spans[i]
        source = source[:a] + hook_rule.aside(source[a:b], [condition]) + source[b:]
    return source


def test_mage_hook_sits_before_the_action_choice_with_guarded_copies():
    source = text('B-HKMAG')
    spans, anchor, copies = hook_rule.plan(source)
    # Setup, prebuff, first-round cast, cloud escape, SCS's stand-still in a cloud, its run from a
    # Cloudkill, its free Oracle and its note of the party member it saw stay above; the alacrity
    # block is the first block of the per-round choice.
    assert anchor == 8
    # Two target picks and the special that aims at LastSeenBy, then the bookkeeping run with
    # its state-only middle block. The perceiving item block is not bookkeeping, but making
    # an item is more than a combat round, so it is kept too. The filler, the item-free state
    # block, the spellbook-gated ForceSpellRES and SCS's chase are not copied.
    assert copies == [9, 10, 11, 12, 13, 14, 17]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMAG')
    assert (reason, family, count) == ('hooked', 'mage', 7)
    # Above the hook only the cloud blocks and the free Oracle change, below it only SCS's chase
    # and its random walk while an unseen attacker puzzles the mage (test_cloud_blocks_above_...,
    # test_hunting_blocks_...).
    expected = guarded(source, spans, [6, 20, 21, 22, 23, 26], '  !' + hook_rule.search_guard('mage', 'b-hkmag'))
    for i in (3, 4, 5):
        cloud = source[spans[i][0]:spans[i][1]]
        expected = expected.replace(cloud, hook_rule.stand_aside(cloud, 'mage', 'b-hkmag'), 1)
    at = expected.index(source[spans[anchor][0]:spans[anchor][1]])
    head, tail = expected[:at], expected[at:]
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
    assert anchor == 2 and copies == [4, 5]
    assert hook_rule.patch(text('B-HKPRI'), 'B-HKPRI')[1:] == ('hooked', 'priest', 2)


def test_ranged_general_ai_skips_the_retarget_block():
    spans, anchor, copies = hook_rule.plan(text('B-HKRNG'))
    assert anchor == 6 and copies == []
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
    # first. Its walk at the party it does not see out of a cloud is SCS's hunt as well: both
    # conditions go last, the zones' first. Its escape below the hook runs only when the engine
    # declines and stays, and so does its NoAction() that listens for no cloud.
    source = text('B-HKRNG')
    spans, anchor, _ = hook_rule.plan(source)
    assert hook_rule.clouds(source, spans, anchor) == [3, 4]
    patched = hook_rule.patch(source, 'B-HKRNG')[0]
    zones = hook_rule.zones_guard('fighter', 'b-hkrng')
    search = hook_rule.search_guard('fighter', 'b-hkrng')
    assert patched.count('IF\n  !' + zones + '\n  !INI("DMWW_genai_difficulty",1)\n  Heard([ANYONE],407)\n') == 1
    assert patched.count('  !See([PC])\n  !' + zones + '\n  !' + search + '\nTHEN\n') == 1
    assert source[spans[7][0]:spans[7][1]] in patched and patched.count(zones) == 2
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


@pytest.mark.parametrize('name,family,hunts', [
    ('B-HKMAG', 'mage', [6, 20, 21, 22, 23, 26]), ('B-HKPRI', 'priest', [1]), ('B-HKRNG', 'fighter', [4, 5, 9]),
    ('B-HKMON', 'monster', [1, 18, 19, 20]),
])
def test_hunting_blocks_yield_to_the_engines_search(name, family, hunts):
    # SCS's hunt stands aside above and below the hook for every creature the engine drives: the
    # mage's free Oracle and the priest's free Invisibility Purge on their detect timer, the chase's
    # start, walk to the party member last seen, end and Dimension Door after it, the mage's random
    # walk while an unseen attacker puzzles it, the fighter's walk at the party it does not see out
    # of a cloud, its reset of its chase that clears its actions and its walk to the nearest door,
    # the monster's end of a chase above the hook, its teleport to the party member it chases, its
    # walk to a party member it does not detect and its teleport to one. (The monster's jump into
    # the fight stands aside as well: test_scripted_jumps_...)
    source = text(name)
    spans, anchor, copies = hook_rule.plan(source)
    assert hook_rule.hunts(source, spans) == hunts
    assert not set(hunts) & set(copies)
    patched = hook_rule.patch(source, name)[0]
    search = hook_rule.search_guard(family, name.lower())
    assert patched.count(search) == len(hunts)
    # A cloud block above the hook that hunts as well takes the zones' condition first.
    clouds = hook_rule.clouds(source, spans, anchor)
    for i in hunts:
        conditions = (['  !' + hook_rule.zones_guard(family, name.lower())] if i in clouds else []) + ['  !' + search]
        assert hook_rule.aside(source[spans[i][0]:spans[i][1]], conditions) in patched, i
    if name == 'B-HKMAG':
        # The note of the party member it saw and the chase's reset that ends with Continue()
        # are bookkeeping and stay as they are.
        for i in (7, 24):
            assert source[spans[i][0]:spans[i][1]] in patched and not hook_rule.is_hunt(source[spans[i][0]:spans[i][1]])
    if name == 'B-HKRNG':
        # The walk to the door ends in an OR group that lacks a member: the condition goes first.
        assert ('IF\n  !' + search + '\n  Global("inafight","LOCALS",1)\n') in patched
    if name == 'B-HKMON':
        # A ReallyForceSpellRES without a spellbook check is a special, but the teleport after the
        # chased party member and the one to a party member it does not detect are SCS's hunt:
        # never copied above the hook. An ally's walk after the party is no hunt.
        claim = hook_rule.guard(family, name.lower())
        for i in (18, 20):
            teleport = source[spans[i][0]:spans[i][1]]
            assert hook_rule.is_special(teleport)
            assert teleport.replace('IF\n', f'IF\n  {claim}\n', 1) not in patched
        assert source[spans[21][0]:spans[21][1]] in patched


def test_search_condition_names_the_script_and_fails_soft():
    assert hook_rule.search_guard('mage', 'b-hkmag') == (
        'EEex_LuaTrigger("return BGSE_Search and BGSE_Search(EEex_LuaTrigger_Object,'
        "'mage','b-hkmag') or false\")")


@pytest.mark.parametrize('triggers,actions,hunt', [
    # The chase: its start, its walk to the party member last seen, its end, a fiend's teleport
    # there, a Dimension Door after it, and its reset that clears the creature's actions.
    (['ActionListEmpty()', 'Global("chasing","LOCALS",0)', '!Global("chasePC","LOCALS",0)'],
     ['SetGlobalTimer("chasetimer","LOCALS",8)', 'SetGlobal("chasing","LOCALS",1)'], True),
    (['!Detect(Player2)', 'GlobalTimerNotExpired("chasetimer","LOCALS")', 'Global("chasePC","LOCALS",2)'],
     ['MoveToObject(Player2)'], True),
    (['GlobalTimerExpired("chasetimer","LOCALS")', '!Global("chasePC","LOCALS",0)'],
     ['SetGlobal("inafight","LOCALS",0)', 'SetGlobal("chasePC","LOCALS",0)'], True),
    (['GlobalTimerNotExpired("chasetimer","LOCALS")', 'Global("chasePC","LOCALS",3)'],
     ['ReallyForceSpellRES("dw#fitel",Player3)'], True),
    (['!GlobalTimerNotExpired("teleportpursuetimer","LOCALS")', 'HaveSpell(WIZARD_DIMENSION_DOOR)'],
     ['ReallyForceSpell(Player1,WIZARD_DIMENSION_DOOR)', 'SetGlobalTimer("teleportpursuetimer","LOCALS",18)'], True),
    (['See(NearestEnemyOf(Myself))', '!Global("chasing","LOCALS",0)'],
     ['SetGlobal("chasing","LOCALS",0)', 'ClearActions(Myself)'], True),
    (['GlobalTimerNotExpired("ChaseTimer","LOCALS")', 'Global("ChasePC","LOCALS",1)'], ['MoveToObject(Player1)'], True),
    # The walk to the nearest door, and a free detection cast on the detect timer.
    (['Range(NearestDoor,15)', 'OpenState(NearestDoor,FALSE)'], ['MoveToObject(NearestDoor)', 'OpenDoor(NearestDoor)'], True),
    (['Detect([PC])', '!See([PC])', '!GlobalTimerNotExpired("detect","LOCALS")'],
     ['SetGlobalTimer("detect","LOCALS",1000)', 'SpellNoDec(Myself,WIZARD_ORACLE)'], True),
    # The chase's bookkeeping: the note of the party member seen, forgetting the dead, the reset
    # that continues, and the detect timer alone.
    (['!GlobalTimerNotExpired("chasetarget","LOCALS")', 'See(Player1)'],
     ['SetGlobalTimer("chasetarget","LOCALS",3600)', 'SetGlobal("chasePC","LOCALS",1)', 'Continue()'], False),
    (['Global("chasePC","LOCALS",1)', 'StateCheck(Player1,STATE_REALLY_DEAD)'],
     ['SetGlobal("chasePC","LOCALS",0)', 'Continue()'], False),
    (['!Global("chasing","LOCALS",0)', 'See(NearestEnemyOf(Myself))'], ['SetGlobal("chasing","LOCALS",0)', 'Continue()'], False),
    (['!GlobalTimerNotExpired("detect","LOCALS")'], ['SetGlobalTimer("detect","LOCALS",30)', 'Continue()'], False),
    # A scripted door.
    (['Global("deadJoye","AR1513",2)'], ['OpenDoor("Door08")', 'MoveToObject([PC])'], False),
])
def test_hunting_blocks_are_scs_chase_free_detection_and_door_search(triggers, actions, hunt):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    assert hook_rule.is_hunt(f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n') is hunt


@pytest.mark.parametrize('triggers,actions,hunt', [
    # A mind flayer's astral travel to a party member while it detects none, a phase spider's
    # teleport while it sees no enemy, a dragon's walk to a party member it does not detect,
    # Melissan's teleport, Illasera's walk, the walk to the nearest enemy on an ally's shout and
    # the walk at the party out of a cloud while it sees no party member.
    (['!Detect([PC])', 'OR(2)', '  HitBy([GOODCUTOFF],CRUSHING)', '  See(NearestEnemyOf(Myself))',
      'InMyArea(Player1)'], ['SetGlobalTimer("castspell","LOCALS",ONE_ROUND)', 'ForceSpell(Player1,PSIONIC_ASTRAL_TRAVEL)'], True),
    (['GlobalTimerNotExpired("DMWWphase","GLOBAL")', '!See(NearestEnemyOf(Myself))', 'InMyArea(Player2)'],
     ['ForceSpell(Player2,INNATE_PHASE_SPIDER_TELEPORT)'], True),
    (['!Detect(NearestEnemyOf(Myself))', '!Detect(Player3)', 'Global("inafight","LOCALS",1)'], ['MoveToObject(Player3)'], True),
    (['!GlobalTimerNotExpired("castspell","LOCALS")', '!Detect(NearestEnemyOf(Myself))', 'Allegiance(Myself,ENEMY)'],
     ['ReallyForceSpellRES("dw#fitel",Player4)  // Teleport'], True),
    (['!See(NearestEnemyOf(Myself))'], ['MoveToObject(Player5)'], True),
    (['Heard([ANYONE],111)', '!See(NearestEnemyOf(Myself))'], ['MoveToObject(NearestEnemyOf(Myself))'], True),
    (['Heard([ANYONE],404)', 'Range(LastHeardBy(Myself),20)', '!See([PC])'],
     ['SetGlobalTimer("seencloud","LOCALS",FOUR_MINUTES)', 'MoveToObject([PC])'], True),
    # A walk to the one party member it does not detect, while it sees others.
    (['See(NearestEnemyOf(Myself))', 'Global("helptarget","LOCALS",6)', '!Detect(Player6)'], ['MoveToObject(Player6)'], True),
    # Its random walk while an unseen attacker puzzles it.
    (['!See(NearestEnemyOf(Myself))', 'GlobalTimerNotExpired("whatthe","LOCALS")'], ['RandomWalkContinuous()'], True),
    (['GlobalTimerNotExpired("castspell","LOCALS")', '!See(NearestEnemyOf(Myself))', '!Heard([ANYONE],404)',
      'GlobalTimerNotExpired("whatthe","LOCALS")'], ['RandomWalk()'], True),
    # Not a pursuit: it sees the one it acts on; it must be on the party's side (an ally that
    # follows the party); it sees no mage but may see others; the one it does not see is not the
    # one it acts on; no trigger says it misses anyone; the random walk while nothing puzzles it
    # or while it sees an enemy; the whatthe timer without a walk.
    (['!See(NearestEnemyOf(Myself))', 'See(Player1)'], ['MoveToObject(Player1)'], False),
    (['Allegiance(Myself,GOODCUTOFF)', '!See([ENEMY])', 'CombatCounter(0)', '!Range(Player1,20)'], ['MoveToObject(Player1)'], False),
    (['See([PC])', '!See([PC.0.0.MAGE_ALL])'], ['Attack(LastSeenBy(Myself))'], False),
    (['!Detect(Player2)'], ['MoveToObject(Player1)'], False),
    (['Global("ai","LOCALS",1)'], ['MoveToObject(Player1)'], False),
    (['!See(NearestEnemyOf(Myself))', 'Global("inafight","LOCALS",0)'], ['RandomWalkContinuous()'], False),
    (['See(NearestEnemyOf(Myself))', 'GlobalTimerNotExpired("whatthe","LOCALS")'], ['RandomWalkContinuous()'], False),
    (['!See(NearestEnemyOf(Myself))', 'GlobalTimerNotExpired("whatthe","LOCALS")'], ['NoAction()'], False),
    # Casting at itself or walking to a point is no pursuit of someone else.
    (['!See(NearestEnemyOf(Myself))'], ['Spell(Myself,WIZARD_STONE_SKIN)'], False),
    (['!See(NearestEnemyOf(Myself))'], ['MoveToPoint([1200.800])'], False),
])
def test_pursuit_of_a_creature_it_does_not_perceive_is_part_of_the_hunt(triggers, actions, hunt):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    block = f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n'
    assert hook_rule.is_pursuit(block) is hunt
    assert hook_rule.is_hunt(block) is hunt


def test_aside_keeps_the_order_of_several_conditions():
    block = 'IF\n  OR(3)\n    A()\n    B()\nTHEN\n  RESPONSE #100\n    NoAction()\nEND\n'
    assert hook_rule.aside(block, ['  !C()', '  !D()']) == 'IF\n  !C()\n  !D()\n' + block[len('IF\n'):]
    block = 'IF\n  A()\nTHEN\n  RESPONSE #100\n    NoAction()\nEND\n'
    assert hook_rule.aside(block, ['  !C()', '  !D()']) == 'IF\n  A()\n  !C()\n  !D()\nTHEN\n  RESPONSE #100\n    NoAction()\nEND\n'


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
    spans, anchor, copies = hook_rule.plan(source, TELEPORTS)
    # The setup block and SCS's end of a chase stay above; the first round-timer block is the
    # anchor. Copied: the innate power, the summon with its target pick, the escape, the death
    # handler, the allegiance change, the scripted heal cast with SpellNoDecRES and the two steps
    # of a shape change the creature applies to itself. The ordinary attacks, the wandering, the
    # two spellbook casts (checked with HaveSpell, or used up with RemoveSpell), the
    # self-application checked with HaveSpellRES, the power applied to an enemy, the fiend's
    # teleport to the party member it chases, its walk and teleport to one it does not detect (SCS's
    # hunt), an ally's walk after the party and the fiend's jump into the fight are the engine's.
    assert anchor == 2 and copies == [3, 4, 5, 7, 8, 9, 11, 14, 15]
    patched, reason, family, count = hook_rule.patch(source, 'B-HKMON', TELEPORTS)
    assert (reason, family, count) == ('hooked', 'monster', 9)
    assert hook_rule.guard('monster', 'b-hkmon') in patched


def test_scripted_jumps_into_the_fight_stand_aside_for_the_creatures_own_teleport():
    # The fiend's jump to the weak party member it sees (SCS's fiend/ssl/jump.ssl) is a cast without
    # a spellbook check: copied above the hook while nothing says its spell moves the caster (a game
    # without the fiend teleport), and with the game's spells known it stands aside like the hunt,
    # as the engine jumps with the creature's own teleport.
    source = text('B-HKMON')
    spans, anchor, copies = hook_rule.plan(source, {'B-HKFIT'})
    assert 22 in copies and hook_rule.jumps(source, spans, {'B-HKFIT'}) == []
    assert hook_rule.jumps(source, spans, TELEPORTS) == [22]
    patched = hook_rule.patch(source, 'B-HKMON', TELEPORTS)[0]
    search = hook_rule.search_guard('monster', 'b-hkmon')
    jump = source[spans[22][0]:spans[22][1]]
    assert hook_rule.aside(jump, ['  !' + search]) in patched
    assert jump.replace('IF\n', 'IF\n  ' + hook_rule.guard('monster', 'b-hkmon') + '\n', 1) not in patched
    assert patched.count(search) == 5
    # The script teleports by script (the chase, and the jump): its creatures get the innate
    # Teleport unless they have one of their own.
    assert hook_rule.teleporter(source, {'B-HKFIT'}) and not hook_rule.teleporter(source, frozenset())
    assert not hook_rule.teleporter(text('B-HKMAG'), TELEPORTS | {'WIZARD_DIMENSION_DOOR'})


@pytest.mark.parametrize('triggers,actions,jump', [
    # SCS's fiend jump at the creature it last saw; at a party member or the nearest enemy it sees or
    # detects; the IDS form, by name and by number; a comment after the action.
    (['See(LastSeenBy(Myself))', '!Range(LastSeenBy(Myself),15)'], ['ForceSpellRES("b-hkfit",LastSeenBy(Myself))'], True),
    (['See(Player3)'], ['ReallyForceSpellRES("B-HKFIT",Player3)'], True),
    (['Detect(NearestEnemyOf(Myself))'], ['ReallyForceSpell(NearestEnemyOf(Myself),INNATE_FIEND_TELEPORT)'], True),
    (['See(Player1)'], ['ForceSpell(Player1,3159)'], True),
    (['See(LastSeenBy(Myself))'], ['ForceSpellRES("b-hkfit",LastSeenBy(Myself))  // Teleport'], True),
    # Not a jump into the fight: to the summoner, to a point, to someone no trigger says it sees, a
    # spell checked against the spellbook, one that moves nobody, or for a creature that must be on
    # the party's side.
    (['See(LastSummonerOf(Myself))'], ['ReallyForceSpell(LastSummonerOf(Myself),INNATE_FIEND_TELEPORT)'], False),
    (['See(NearestEnemyOf(Myself))'], ['ReallyForceSpellPointRES("b-hkfit",[928.788])'], False),
    (['See(NearestEnemyOf(Myself))'], ['ForceSpellRES("b-hkfit",Player2)'], False),
    (['!See(Player2)'], ['ForceSpellRES("b-hkfit",Player2)'], False),
    (['HaveSpellRES("b-hkfit")', 'See(Player1)'], ['ForceSpellRES("b-hkfit",Player1)'], False),
    (['See(Player1)'], ['ForceSpellRES("b-hkpow",Player1)'], False),
    (['Allegiance(Myself,GOODCUTOFF)', 'See(Player1)'], ['ForceSpellRES("b-hkfit",Player1)'], False),
])
def test_jumps_are_scripted_teleports_at_a_creature_the_creature_sees(triggers, actions, jump):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    block = f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n'
    assert hook_rule.is_jump(block, TELEPORTS | {'INNATE_FIEND_TELEPORT', '3159'}) is jump


def test_scripted_casts_name_their_spell_and_target_as_written():
    block = ('IF\n  See(Player1)\nTHEN\n  RESPONSE #100\n    ForceSpellRES("dw#fitel",LastSeenBy(Myself))  // Teleport\n'
             '    ReallyForceSpell(Player2,INNATE_FIEND_TELEPORT)\n    ForceSpellPoint([10.20],3159)\n'
             '    ReallyForceSpellPointRES("dimdoor",[30.40])\n    Spell(Player1,WIZARD_DIMENSION_DOOR)\n'
             '    SpellNoDecRES("b-hkheal",Myself)\nEND\n')
    assert hook_rule.ungated_casts(block) == [('DW#FITEL', 'LastSeenBy(Myself)'), ('INNATE_FIEND_TELEPORT', 'Player2'),
                                              ('3159', None), ('DIMDOOR', None)]
    assert hook_rule.ungated_casts(block.replace('See(Player1)', 'HaveSpell(WIZARD_DIMENSION_DOOR)')) == []
    assert hook_rule.scripted_teleports(block, {'DIMDOOR', '3159'}) == ['3159', 'DIMDOOR']


@pytest.mark.parametrize('scripts,memorized,granted', [
    # A creature with a teleporting script and no teleport of its own; one whose own innate moves
    # it (a fiend's Teleport Without Error); one whose scripts do not teleport; any case.
    (['', 'b-hkmon', '', '', ''], ['SPWI112'], True),
    (['B-HKMON', '', '', '', ''], ['SPWI112', 'B-HKBLK'], False),
    (['B-HKMAG', 'B-HKPRI', '', '', ''], [], False),
    (['', '', '', 'B-HKMON', ''], ['b-hkblk'], False),
])
def test_creatures_that_teleport_only_by_script_get_the_innate_teleport(scripts, memorized, granted):
    assert hook_rule.grants(scripts, memorized, {'B-HKMON'}, TELEPORTS | {'B-HKBLK'}) is granted


def test_blocks_left_to_the_engine_are_ordinary_combat_rounds():
    for name in ('B-HKMAG', 'B-HKPRI', 'B-HKRNG', 'B-HKMON'):
        source = text(name)
        spans, anchor, copies = hook_rule.plan(source, TELEPORTS)
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
