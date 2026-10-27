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


def prepared(name, family):
    """Index to the patched block of each of SCS's preparation blocks of a fixture: BGSE_Prep's condition
    and BGSE_Prepped's notice, or for an opener the twin after it."""
    source = text(name)
    spans, anchor, _ = hook_rule.plan(source)
    out = {}
    for i, prep in hook_rule.preparations(source, spans, anchor).items():
        question = hook_rule.prep_guard(family, name.lower(), *prep)
        block = hook_rule.aside(source[spans[i][0]:spans[i][1]], ['  !' + question])
        if prep[0] == 'opener':
            out[i] = block + '\n' + hook_rule.opener_twin(block, question)
        else:
            out[i] = hook_rule.notify(block, hook_rule.prep_notice(family, name.lower(), *prep))
    return out


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
    # Above the hook only SCS's preparation, the cloud blocks and the free Oracle change, below it
    # only SCS's chase and its random walk while an unseen attacker puzzles the mage
    # (test_scs_preparation_..., test_cloud_blocks_above_..., test_hunting_blocks_...).
    expected = guarded(source, spans, [6, 20, 21, 22, 23, 26], '  !' + hook_rule.search_guard('mage', 'b-hkmag'))
    for i in (3, 4, 5):
        cloud = source[spans[i][0]:spans[i][1]]
        expected = expected.replace(cloud, hook_rule.stand_aside(cloud, 'mage', 'b-hkmag'), 1)
    for i, block in prepared('B-HKMAG', 'mage').items():
        expected = expected.replace(source[spans[i][0]:spans[i][1]], block, 1)
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


# The fixtures' spells that make their target invisible (the integration test's fake game has them):
# the thief's b-hksil and 2206 (SPWI206), and Improved Invisibility (SPELL.IDS 2405, SPWI405).
HIDES = {'B-HKSIL': 'plain', '2206': 'plain', 'WIZARD_IMPROVED_INVISIBILITY': 'improved'}


def test_free_invisibility_stands_aside_where_the_engine_hides_the_creature():
    # SCS's thief turns invisible for free when it sees no enemy, when it plans a backstab and on its
    # hide timer while it detects no enemy (above the hook), and fires a contingency's Improved
    # Invisibility below it, which is copied above the hook as a special. Each takes BGSE_Hide's
    # condition with its kind, last, or first where the triggers end in an OR group that lacks a
    # member; the copy takes it too. A free cast that comes with an attack, one checked against the
    # spellbook and one of a spell that hides nobody stay as they are.
    source = text('B-HKTHF')
    spans, anchor, copies = hook_rule.plan(source, TELEPORTS)
    assert (anchor, copies) == (4, [5, 6, 8])
    assert hook_rule.hiding(source, spans, HIDES) == {1: 'plain', 2: 'plain', 3: 'plain', 5: 'improved'}
    patched, reason, family, count = hook_rule.patch(source, 'B-HKTHF', TELEPORTS, HIDES)
    assert (reason, family, count) == ('hooked', 'fighter', 3)
    plain = '  !' + hook_rule.hide_guard('fighter', 'b-hkthf', 'plain')
    improved = '  !' + hook_rule.hide_guard('fighter', 'b-hkthf', 'improved')
    assert patched.count(plain) == 3 and patched.count(improved) == 2
    for i, condition in ((1, plain), (2, plain), (3, plain), (5, improved)):
        block = source[spans[i][0]:spans[i][1]]
        assert hook_rule.aside(block, [condition]) in patched, i
    third = source[spans[3][0]:spans[3][1]]
    assert hook_rule.aside(third, [plain]).startswith('IF\n' + plain + '\n')
    contingency = hook_rule.aside(source[spans[5][0]:spans[5][1]], [improved])
    assert contingency.replace('IF\n', 'IF\n  ' + hook_rule.guard('fighter', 'b-hkthf') + '\n', 1) in patched
    for i in (6, 7, 8):
        block = source[spans[i][0]:spans[i][1]]
        assert patched.count(block) == 1, i
        if i in copies:
            assert block.replace('IF\n', 'IF\n  ' + hook_rule.guard('fighter', 'b-hkthf') + '\n', 1) in patched, i
    # Without the game's spell facts nothing changes, and the other fixtures keep their results.
    assert hook_rule.patch(source, 'B-HKTHF', TELEPORTS)[0].count('BGSE_Hide') == 0
    for name in ('B-HKMAG', 'B-HKPRI', 'B-HKRNG', 'B-HKMON'):
        assert hook_rule.patch(text(name), name, TELEPORTS, HIDES) == hook_rule.patch(text(name), name, TELEPORTS), name


@pytest.mark.parametrize('triggers,actions,kind', [
    # SCS's forms: applied, forced or cast without a spellbook entry, by resref, SPELL.IDS name or
    # number, with bookkeeping and a comment after the action; Improved Invisibility beats plain.
    (['!See(NearestEnemyOf(Myself))'], ['ApplySpellRES("b-hksil",Myself)'], 'plain'),
    (['See(NearestEnemyOf(Myself))'], ['SetGlobal("backstabplan","LOCALS",1)', 'SetGlobalTimerRandom("t","LOCALS",6,12)',
                                       'ApplySpell(Myself,2206)'], 'plain'),
    (['!Detect(Player1)'], ['ForceSpellRES("B-HKSIL",Myself)  // Invisibility', 'Continue()'], 'plain'),
    (['HPPercentLT(Myself,30)'], ['DisplayStringHead(Myself,1234)', 'ReallyForceSpell(Myself,WIZARD_IMPROVED_INVISIBILITY)'],
     'improved'),
    (['True()'], ['SpellNoDecRES("b-hksil",Myself)', 'SpellNoDec(Myself,WIZARD_IMPROVED_INVISIBILITY)'], 'improved'),
    (['True()'], ['ApplySpellRES("b-hksil",Myself)', 'ApplySpellRES("b-hkpow",Myself)'], 'plain'),
    # Not free invisibility: checked against the spellbook, with an attack, a wait or a cast at
    # someone else, a removed spell, a spell that hides nobody, or no invisibility at all.
    (['HaveSpellRES("b-hksil")'], ['ApplySpellRES("b-hksil",Myself)'], None),
    (['True()'], ['ApplySpellRES("b-hksil",Myself)', 'AttackReevaluate(NearestEnemyOf(Myself),15)'], None),
    (['True()'], ['Wait(1)', 'ApplySpellRES("b-hksil",Myself)'], None),
    (['True()'], ['ApplySpellRES("b-hksil",LastSeenBy(Myself))'], None),
    (['True()'], ['ReallyForceSpell(Myself,WIZARD_IMPROVED_INVISIBILITY)', 'RemoveSpell(WIZARD_IMPROVED_INVISIBILITY)'], None),
    (['True()'], ['ApplySpellRES("b-hkpow",Myself)'], None),
    (['True()'], ['ApplySpellRES("",Myself)'], None),
    (['True()'], ['SetGlobal("hidden","LOCALS",1)'], None),
])
def test_free_invisibility_is_a_spellbook_free_cast_at_itself_and_bookkeeping(triggers, actions, kind):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    block = f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n'
    assert hook_rule.free_hide(block, HIDES) == kind


@pytest.mark.parametrize('trigger', ['!CheckSpellState(Myself,CONTINGENCY_TRIGGERED)',
                                     'CheckSpellState(Myself,CONTINGENCY_TRIGGERED)'])
def test_scs_contingencies_are_its_preparation_not_free_invisibility(trigger):
    # SCS's mages fire a contingency's or sequencer's Improved Invisibility or Mislead once they detect
    # an enemy: its preparation, which stays SCS's.
    block = ('IF\n  Global("ContingencyFired","LOCALS",0)\n  ' + trigger + '\n  Detect(NearestEnemyOf(Myself))\n'
             'THEN\n  RESPONSE #100\n    SetGlobal("ContingencyFired","LOCALS",1)\n    DisplayString(Myself,25942)\n'
             '    ReallyForceSpell(Myself,WIZARD_IMPROVED_INVISIBILITY)\nEND\n')
    assert hook_rule.free_hide(block, HIDES) is None
    assert hook_rule.gifts(block, HIDES, set()) == []
    assert hook_rule.free_hide(block.replace(trigger, 'CheckSpellState(Myself,TIME_STOP)'), HIDES) == 'improved'


# GTIMES.IDS as the game names some times.
TIMES = {'ONE_ROUND': 6, 'TWO_ROUNDS': 12, 'FOUR_ROUNDS': 24, 'ONE_MINUTE': 5}


def free(triggers, actions):
    lines = ''.join(f'  {t}\n' for t in triggers)
    response = ''.join(f'    {a}\n' for a in actions)
    return f'IF\n{lines}THEN\n  RESPONSE #100\n{response}END\n'


@pytest.mark.parametrize('triggers,actions,expected', [
    # Whenever it fits (a fiend that sees no enemy): a round.
    (['!See(NearestEnemyOf(Myself))'], ['ApplySpellRES("b-hksil",Myself)'], (None, 6)),
    # Its own timer, by seconds or a GTIMES name, checked either way; not the round timer; a timer it
    # does not set again, or one of unknown length, counts for nothing; at most 1295 seconds.
    (['See(NearestEnemyOf(Myself))', '!GlobalTimerNotExpired("prep","LOCALS")'],
     ['SetGlobalTimer("prep","LOCALS",1000)', 'ApplySpellRES("b-hksil",Myself)', 'Continue()'], (None, 1000)),
    (['GlobalTimerExpired("hidetimer","LOCALS")'], ['SetGlobalTimer("hidetimer","LOCALS",TWO_ROUNDS)',
                                                    'ReallyForceSpellRES("b-hksil",Myself)'], (None, 12)),
    (['!GlobalTimerNotExpired("castspell","LOCALS")'], ['SetGlobalTimer("castspell","LOCALS",ONE_ROUND)',
                                                        'SpellNoDec(Myself,WIZARD_IMPROVED_INVISIBILITY)'], (None, 6)),
    (['!GlobalTimerNotExpired("prep","LOCALS")'], ['ApplySpellRES("b-hksil",Myself)'], (None, 6)),
    (['!GlobalTimerNotExpired("prep","LOCALS")'], ['SetGlobalTimer("prep","LOCALS",ONE_AGE)',
                                                   'ApplySpellRES("b-hksil",Myself)'], (None, 6)),
    (['!GlobalTimerNotExpired("prep","LOCALS")'], ['SetGlobalTimer("prep","LOCALS",7200)',
                                                   'ApplySpellRES("b-hksil",Myself)'], (None, 1295)),
    # Counted uses: a counter it raises by one (over its timer), a variable it checks for 0 and sets
    # (either check); not a counter it does not raise, nor a variable it sets to 0.
    (['GlobalLT("EtherealCount","LOCALS",5)', '!GlobalTimerNotExpired("Ethereal","LOCALS")'],
     ['SetGlobalTimer("Ethereal","LOCALS",FOUR_ROUNDS)', 'IncrementGlobal("EtherealCount","LOCALS",1)',
      'ForceSpellRES("b-hksil",Myself)'], (5, None)),
    (['!GlobalGT("sirinv","LOCALS",0)'], ['SetGlobal("sirinv","LOCALS",1)', 'ApplySpellRES("b-hksil",Myself)'], (1, None)),
    (['Global("hidden","LOCALS",0)'], ['SetGlobal("hidden","LOCALS",1)', 'ApplySpellRES("b-hksil",Myself)'], (1, None)),
    (['GlobalLT("count","LOCALS",5)'], ['ApplySpellRES("b-hksil",Myself)'], (None, 6)),
    (['Global("hidden","LOCALS",0)'], ['SetGlobal("hidden","LOCALS",0)', 'ApplySpellRES("b-hksil",Myself)'], (None, 6)),
])
def test_gifts_come_back_as_often_as_scs_gives_them(triggers, actions, expected):
    assert hook_rule.frequency(free(triggers, actions), TIMES) == expected


def test_each_spell_of_a_free_invisibility_becomes_a_gift_the_game_own_for_a_non_innate_invisibility():
    hides = dict(HIDES, **{'DW#SILIN': 'plain', 'DW#ILLIN': 'improved', 'B-HKETH': 'improved'})
    innates = {'B-HKSIL', 'B-HKETH'}
    # SCS's maurezhi: Improved Invisibility and Blur on sight, once in 1000 seconds; the improved one is
    # the game's own Improved Invisibility, Blur stays itself and has no kind.
    maurezhi = free(['See(NearestEnemyOf(Myself))', '!GlobalTimerNotExpired("prep","LOCALS")'],
                    ['SetGlobalTimer("prep","LOCALS",1000)', 'ApplySpell(Myself,WIZARD_IMPROVED_INVISIBILITY)',
                     'ApplySpell(Myself,WIZARD_BLUR)', 'Continue()'])
    assert hook_rule.gifts(maurezhi, hides, innates, TIMES) == [
        ('SPWI405', 'improved', None, 1000), ('WIZARD_BLUR', None, None, 1000)]
    # SCS's own copies of the game's invisibilities become the game's own; an innate one stays itself,
    # each gift once.
    fiend = free(['!See(NearestEnemyOf(Myself))'], ['ApplySpellRES("dw#silin",Myself)', 'ApplySpellRES("dw#illin",Myself)',
                                                     'ApplySpellRES("b-hketh",Myself)', 'ApplySpellRES("dw#silin",Myself)'])
    assert hook_rule.gifts(fiend, hides, innates, TIMES) == [
        ('SPWI206', 'plain', None, 6), ('SPWI405', 'improved', None, 6), ('B-HKETH', 'improved', None, 6)]
    # A block that gives no free invisibility gives nothing.
    assert hook_rule.gifts(free(['True()'], ['ApplySpell(Myself,WIZARD_BLUR)']), hides, innates, TIMES) == []
    assert hook_rule.gifts(free(['HaveSpellRES("dw#silin")'], ['ApplySpellRES("dw#silin",Myself)']), hides, innates) == []
    # A script's gifts, each once, in block order.
    script = fiend + '\n' + maurezhi + '\n' + fiend
    assert hook_rule.script_gifts(script, hides, innates, TIMES) == [
        ('SPWI206', 'plain', None, 6), ('SPWI405', 'improved', None, 6), ('B-HKETH', 'improved', None, 6),
        ('SPWI405', 'improved', None, 1000), ('WIZARD_BLUR', None, None, 1000)]


@pytest.mark.parametrize('resref,innate,recharge,name', [
    ('SPWI206', False, 6, 'BGW20606'),
    ('spwi405', False, 1000, 'BGW405RS'),
    ('SPWI201', False, 1000, 'BGW201RS'),
    ('SPIN687', True, 6, 'BGN68706'),
    ('SPPR409', False, 36, 'BGP40910'),
    ('SPCL900', True, 1295, 'BGC900ZZ'),
    ('SPWI206', False, None, 'BGW20600'),
    ('DW#SILIN', False, 6, 'BGDW#S06'),
    ('SPWI2061', False, 6, 'BGSPWI06'),
    # An innate ability whose uses SCS counts is given as it is.
    ('ILLAINV', True, None, 'ILLAINV'),
    ('ILLAINV', True, 6, 'BGILLA06'),
])
def test_a_gift_is_the_innate_itself_or_its_innate_copy_named_by_its_spell_and_recharge(resref, innate, recharge, name):
    assert hook_rule.grant_resref(resref, innate, recharge) == name


def test_creatures_get_their_scripts_gifts_but_keep_their_own_and_thieves_hide_by_skill():
    plain = ('SPWI206', 'plain', None, 6)
    improved = ('SPWI405', 'improved', None, 1000)
    blur = ('WIZARD_BLUR', None, None, 1000)
    gifts_of = {'b-hkfen': [plain, improved, blur], 'b-hkoth': [blur, ('SPIN687', 'improved', 3, None)]}
    party = {'B-HKFE4'}
    # Every gift of its scripts, each once, in the order of its slots, whatever their case.
    assert hook_rule.creature_gifts(['', 'B-HKFEN', '', 'b-hkoth', ''], gifts_of, False, set(), 'HKFE1', party) == [
        plain, improved, blur, ('SPIN687', 'improved', 3, None)]
    # An innate invisibility of its own keeps a gift of that kind away, not one of the other kind.
    assert hook_rule.creature_gifts(['B-HKFEN'], gifts_of, False, {'plain'}, '', party) == [improved, blur]
    assert hook_rule.creature_gifts(['B-HKFEN'], gifts_of, False, {'improved'}, '', party) == [plain, blur]
    # A thief hides by its skill instead of a plain invisibility.
    assert hook_rule.creature_gifts(['B-HKFEN'], gifts_of, True, set(), '', party) == [improved, blur]
    # A joinable NPC gets nothing, nor a creature whose scripts give nothing.
    assert hook_rule.creature_gifts(['B-HKFEN'], gifts_of, False, set(), 'b-hkfe4', party) == []
    assert hook_rule.creature_gifts(['B-HKMAG', ''], gifts_of, False, set(), '', party) == []


def test_self_spells_name_casts_at_the_creature_itself_as_written():
    source = ('IF\n  True()\nTHEN\n  RESPONSE #100\n    ApplySpellRES("dw#silin",Myself)  // Invisibility\n'
              '    ReallyForceSpell(Myself,WIZARD_IMPROVED_INVISIBILITY)\n    ForceSpellRES("dw#silin",Myself)\n'
              '    SpellNoDec(Myself,2206)\n    ApplySpellRES("b-hkpow",NearestEnemyOf(Myself))\n'
              '    ReallyForceSpellRES("dw#misld",Myself)\r\nEND\n')
    assert hook_rule.self_spells(source) == ['DW#SILIN', 'WIZARD_IMPROVED_INVISIBILITY', '2206', 'DW#MISLD']


# The fake game's THIEFSKL.2DA and KITLIST.2DA as hide_skill reads them.
POINTS = {'THIEF': (40, 25), 'ASSASIN': (40, 10), 'SHADOWDANCER': (30, 20), 'FIGHTER_THIEF': (40, 25)}
KITS = {0x400A: 'ASSASIN', 0x4021: 'SHADOWDANCER', 0x4001: 'BERSERKER'}


@pytest.mark.parametrize('cls,levels,kit,skill', [
    # A thief, an assassin and a shadowdancer by their own rows; a fighter/thief by its thief level
    # (the second); a mage/thief whose row the table lacks by the thief's; a kit without a row of its
    # own by its class; level 0 as level 1; an odd sum halved towards zero; at most 255.
    (4, (9, 0, 0), 0x4000, 120),
    (4, (9, 0, 0), 0x400A, 60),
    (4, (5, 0, 0), 0x4021, 55),
    (9, (10, 7, 0), 0, 95),
    (13, (12, 3, 0), 0, 45),
    (4, (9, 0, 0), 0x4001, 120),
    (4, (0, 0, 0), 0, 20),
    (4, (2, 0, 0), 0, 32),
    (4, (60, 0, 0), 0, 255),
    # No thief levels: a fighter, a monk.
    (2, (9, 0, 0), 0, None),
    (20, (9, 0, 0), 0, None),
])
def test_thieves_hide_skills_fit_their_level(cls, levels, kit, skill):
    assert hook_rule.hide_skill(cls, levels, kit, POINTS, KITS) == skill
    assert hook_rule.hide_skill(cls, levels, kit, {}, KITS) is None


@pytest.mark.parametrize('scripts,name,raised', [
    (['', 'B-HKTHF', '', '', ''], 'HKTH1', True),
    (['b-hkthf', '', '', '', ''], '', True),
    (['B-HKMAG', '', '', '', ''], 'HKTH1', False),
    (['B-HKTHF', '', '', '', ''], 'B-HKNPC', False),
    (['B-HKTHF', '', '', '', ''], 'b-hknpc', False),
])
def test_only_creatures_scs_makes_invisible_for_free_and_no_joinable_npc_get_skills(scripts, name, raised):
    assert hook_rule.raises_skills(scripts, {'b-hkthf'}, name, {'B-HKNPC'}) is raised

def test_scs_preparation_asks_the_engine_and_reports_what_ran():
    # The mage's prebuff (SCS's Mirror Image helper, then the memorized spell spent) and its first-round
    # Mirror Image ask BGSE_Prep last; the prebuff's response tells BGSE_Prepped what it cast and spent,
    # before its closing Continue(). The opener gets no notice: the engine chooses that round itself, and
    # the twin after it ends SCS's preparation when the engine holds it, without the cast or the round
    # timer, and lets the pass go on to the engine.
    source = text('B-HKMAG')
    spans, anchor, _ = hook_rule.plan(source)
    assert hook_rule.preparations(source, spans, anchor) == {
        1: ('prebuff', 'dwsw212', 'WIZARD_MIRROR_IMAGE'), 2: ('opener', 'WIZARD_MIRROR_IMAGE', '')}
    patched = hook_rule.patch(source, 'B-HKMAG')[0]
    blocks = prepared('B-HKMAG', 'mage')
    guard = hook_rule.prep_guard('mage', 'b-hkmag', 'prebuff', 'dwsw212', 'WIZARD_MIRROR_IMAGE')
    notice = hook_rule.prep_notice('mage', 'b-hkmag', 'prebuff', 'dwsw212', 'WIZARD_MIRROR_IMAGE')
    assert blocks[1] == ('IF\n  See(NearestEnemyOf(Myself))\n  Global("instantprep","LOCALS",0)\n'
                         '  HaveSpell(WIZARD_MIRROR_IMAGE)\n  INI("DMWW_mage_prep_difficulty",0)\n'
                         f'  !{guard}\nTHEN\n  RESPONSE #100\n    ReallyForceSpellRES("dwsw212",Myself)\n'
                         f'    RemoveSpell(WIZARD_MIRROR_IMAGE)\n    {notice}\n    Continue()\nEND\n')
    opener = hook_rule.prep_guard('mage', 'b-hkmag', 'opener', 'WIZARD_MIRROR_IMAGE', '')
    first = ('IF\n  !GlobalTimerNotExpired("castspell","LOCALS")\n  Global("instantprep","LOCALS",0)\n'
             '  See(NearestEnemyOf(Myself))\n')
    assert blocks[2] == (f'{first}  !{opener}\nTHEN\n  RESPONSE #100\n    SetGlobalTimer("castspell","LOCALS",6)\n'
                         '    Spell(Myself,WIZARD_MIRROR_IMAGE)\n    SetGlobal("instantprep","LOCALS",1)\nEND\n\n'
                         f'{first}  {opener}\nTHEN\n  RESPONSE #100\n    SetGlobal("instantprep","LOCALS",1)\n'
                         '    Continue()\nEND\n')
    for block in blocks.values():
        assert block in patched
    assert patched.count('BGSE_Prep(') == 3 and patched.count('BGSE_Prepped(') == 1
    # Fail soft: no engine, or an engine without the function, lets SCS's block run.
    assert guard.startswith('EEex_LuaTrigger("return BGSE_Prep and BGSE_Prep(EEex_LuaTrigger_Object,')
    assert guard.endswith(" or false\")") and notice.startswith('EEex_LuaAction("if BGSE_Prepped then ')
    assert '"' not in guard[len('EEex_LuaTrigger("'):-2] and '"' not in notice[len('EEex_LuaAction("'):-2]
    # The installer's preparation script: two prebuffs (one spends a spell by its file, one casts a name
    # SCS left unfilled), a contingency, a chain at the party and a first-round cast; not the block whose
    # instantprep check is one of an OR group, the cast at an enemy nor the prebuff below the hook.
    source = text('B-HKPRP')
    spans, anchor, copies = hook_rule.plan(source)
    assert (anchor, copies) == (7, [])
    assert hook_rule.preparations(source, spans, anchor) == {
        0: ('prebuff', 'dwsw408', 'dwsw408'), 1: ('prebuff', '', 'WIZARD_MIRROR_IMAGE'),
        4: ('contingency', 'dwsw305', ''), 5: ('chain', 'dw#cc12', ''), 6: ('opener', 'dwsw305', '')}
    patched = hook_rule.patch(source, 'B-HKPRP', TELEPORTS, HIDES)[0]
    assert patched.count('BGSE_Prep(EEex_LuaTrigger_Object') == 6
    assert patched.count('BGSE_Prepped(EEex_LuaAction_Object') == 4
    # The first-round cast's twin: both responses end SCS's preparation, neither sets the round timer.
    assert ('\nTHEN\n  RESPONSE #80\n    SetGlobal("instantprep","LOCALS",1)\n    Continue()\n  RESPONSE #20\n'
            '    SetGlobalTimer("redefend","LOCALS",12)\n    SetGlobal("instantprep","LOCALS",1)\n'
            '    Continue()\nEND\n') in patched
    # The other fixtures have none.
    for name in ('B-HKPRI', 'B-HKRNG', 'B-HKMON', 'B-HKTHF'):
        assert 'BGSE_Prep' not in hook_rule.patch(text(name), name, TELEPORTS, HIDES)[0], name


def prep(triggers, actions, responses=None):
    lines = ''.join(f'  {t}\n' for t in triggers)
    parts = [(100, actions)] + (responses or [])
    body = ''.join(f'  RESPONSE #{w}\n' + ''.join(f'    {a}\n' for a in acts) for w, acts in parts)
    return f'IF\n{lines}THEN\n{body}END\n'


CONTINGENCY_TRIGGERS = ['Global("ContingencyFired","LOCALS",0)', '!CheckSpellState(Myself,CONTINGENCY_TRIGGERED)',
                        'Detect(NearestEnemyOf(Myself))']
CHAIN_TRIGGERS = ['Global("ChainContingencyFired","LOCALS",0)', '!CheckSpellState(Myself,CONTINGENCY_TRIGGERED)',
                  'See([PC])']
FIRST = ['!GlobalTimerNotExpired("castspell","LOCALS")', 'Global("instantprep","LOCALS",0)', 'See(NearestEnemyOf(Myself))']
PREBUFF = ['See(NearestEnemyOf(Myself))', 'Global("instantprep","LOCALS",0)', 'HaveSpell(WIZARD_STONE_SKIN)']


@pytest.mark.parametrize('triggers,actions,expected', [
    # Prebuffs: SCS's helper and the memorized spell spent (by name or resref, a comment after it), a free
    # precast, an out-of-sight summon with its bookkeeping, a second forced cast at the creature.
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)  // No such index', 'RemoveSpell(WIZARD_STONE_SKIN)  // SPWI408.SPL',
               'Continue()'], ('prebuff', 'dwsw408', 'WIZARD_STONE_SKIN')),
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'RemoveSpellRES("SPWI408")', 'Continue()'],
     ('prebuff', 'dwsw408', 'SPWI408')),
    (['Global("instantprep","LOCALS",0)'], ['ReallyForceSpellRES("dwsw408",Myself)', 'Continue()'],
     ('prebuff', 'dwsw408', '')),
    (['Global("instantprep","LOCALS",0)', 'Range(NearestEnemyOf(Myself),30)'],
     ['SetGlobalTimer("initial_summons","LOCALS",6)', 'IncrementGlobal("l9count","LOCALS",1)',
      'ReallyForceSpellRES("DWAPSM1",Myself)', 'Continue()'], ('prebuff', 'DWAPSM1', '')),
    (PREBUFF, ['ReallyForceSpell(Myself,WIZARD_STONE_SKIN)', 'ReallyForceSpellRES("dwsw212",Myself)', 'Continue()'],
     ('prebuff', 'WIZARD_STONE_SKIN', '')),
    # Not a prebuff: instantprep checked in an OR group or for not being 0, not checked at all, a forced
    # cast at an enemy, a wait, an attack or a spell cast the normal way besides.
    (['OR(2)', '  Global("instantprep","LOCALS",0)', '  See(Player1)'], ['ReallyForceSpellRES("dwsw408",Myself)'], None),
    (['!Global("instantprep","LOCALS",0)'], ['ReallyForceSpellRES("dwsw408",Myself)'], None),
    (['See(NearestEnemyOf(Myself))'], ['ReallyForceSpellRES("dwsw408",Myself)', 'Continue()'], None),
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",NearestEnemyOf(Myself))', 'Continue()'], None),
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'Wait(1)'], None),
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'AttackReevaluate(NearestEnemyOf(Myself),15)'], None),
    (PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'Spell(Myself,WIZARD_STONE_SKIN)'], None),
    # Contingencies and sequencers fire once, at the creature (the variable in either case); not at the party.
    (CONTINGENCY_TRIGGERS, ['SetGlobal("ContingencyFired","LOCALS",1)', 'DisplayString(Myself,25942)',
                            'ReallyForceSpell(Myself,WIZARD_IMPROVED_INVISIBILITY)'],
     ('contingency', 'WIZARD_IMPROVED_INVISIBILITY', '')),
    (CONTINGENCY_TRIGGERS, ['SetGlobal("contingencyfired","LOCALS",1)', 'ReallyForceSpellRES("dw#mc1",Myself)',
                            'ReallyForceSpell(Myself,WIZARD_MIRROR_IMAGE)', 'Continue()'], ('contingency', 'dw#mc1', '')),
    (CONTINGENCY_TRIGGERS, ['SetGlobal("ContingencyFired","LOCALS",1)', 'ReallyForceSpellRES("dw#mc1",[PC])'], None),
    # Chain contingencies at the party or the creature; not at the nearest enemy; and not SCS's rest, which
    # sets the variable back to 0.
    (CHAIN_TRIGGERS, ['SetGlobal("ChainContingencyFired","LOCALS",1)', 'ReallyForceSpellRES("dw#cc12",[PC])',
                      'ReallyForceSpell(Myself,WIZARD_STONE_SKIN)', 'Continue()'], ('chain', 'dw#cc12', '')),
    (CHAIN_TRIGGERS, ['SetGlobal("ChainContingencyFired","LOCALS",1)', 'ReallyForceSpellRES("dw#cc12",Myself)'],
     ('chain', 'dw#cc12', '')),
    (CHAIN_TRIGGERS, ['SetGlobal("ChainContingencyFired","LOCALS",1)',
                      'ReallyForceSpellRES("dw#cc12",NearestEnemyOf(Myself))'], None),
    (['Global("instantprep","LOCALS",1)'], ['SetGlobal("ChainContingencyFired","LOCALS",0)',
                                             'SetGlobal("instantprep","LOCALS",0)'], None),
    # Openers: a first-round cast at the creature itself, by name or SCS's helper; not the state alone, not
    # a cast at an enemy or a point, not a forced cast.
    (FIRST, ['SetGlobalTimer("castspell","LOCALS",6)', 'Spell(Myself,WIZARD_MIRROR_IMAGE)',
             'SetGlobal("instantprep","LOCALS",1)'], ('opener', 'WIZARD_MIRROR_IMAGE', '')),
    (FIRST, ['SetGlobalTimer("castspell","LOCALS",6)', 'SetGlobal("redefend","LOCALS",1)',
             'ForceSpellRES("dw#sq1",Myself)', 'SetGlobal("instantprep","LOCALS",1)'], ('opener', 'dw#sq1', '')),
    (FIRST, ['SetGlobal("instantprep","LOCALS",1)', 'SetGlobal("redefend","LOCALS",1)'], None),
    (FIRST, ['Spell(NearestEnemyOf(Myself),WIZARD_HORROR)', 'SetGlobal("instantprep","LOCALS",1)'], None),
    (FIRST, ['SpellPoint([1234.567],WIZARD_HORROR)', 'SetGlobal("instantprep","LOCALS",1)'], None),
    (FIRST, ['ReallyForceSpell(Myself,WIZARD_MIRROR_IMAGE)', 'SetGlobal("instantprep","LOCALS",1)'], None),
    # Names unsafe in Lua text (SCS leaves some unfilled) go as ''.
    (PREBUFF, ['ReallyForceSpellRES("%WIZARD_SPELL_DEFLECTION_PREBUFF%",Myself)', 'RemoveSpell(WIZARD_SPELL_DEFLECTION)',
               'Continue()'], ('prebuff', '', 'WIZARD_SPELL_DEFLECTION')),
    (CHAIN_TRIGGERS, ['SetGlobal("ChainContingencyFired","LOCALS",1)', 'ReallyForceSpellRES("%NULL%",[PC])'],
     ('chain', '', '')),
    (PREBUFF, ["ReallyForceSpellRES(\"it's\",Myself)", 'RemoveSpell(WIZARD_STONE_SKIN)'],
     ('prebuff', '', 'WIZARD_STONE_SKIN')),
])
def test_scs_preparation_kinds(triggers, actions, expected):
    assert hook_rule.prep_kind(prep(triggers, actions)) == expected


def test_notices_go_last_before_a_closing_continue_in_responses_that_cast():
    notice = hook_rule.prep_notice('mage', 'dw#mg1', 'prebuff', 'dwsw408', '')
    # SCS's skip response (#50: Continue() alone) gets none; a response without Continue() gets it last.
    block = prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'Continue()'], [(50, ['Continue()'])])
    assert hook_rule.notify(block, notice) == prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', notice, 'Continue()'],
                                                   [(50, ['Continue()'])])
    block = prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'SetGlobal("x","LOCALS",1)'])
    assert hook_rule.notify(block, notice) == prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)',
                                                             'SetGlobal("x","LOCALS",1)', notice])
    assert hook_rule.prep_kind(prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'Continue()'],
                                    [(50, ['Continue()'])])) == ('prebuff', 'dwsw408', '')


def test_an_opener_the_engine_holds_still_ends_scs_preparation():
    # SCS's first-round cast as it writes them: round timer, cast (with WeiDU's comment), instantprep,
    # redefend and the count of level-9 spells. The twin keeps instantprep and redefend; the round timer
    # (also a random one), the cast and the count go; Continue() closes every response, the question is
    # asked the other way round wherever it stands.
    question = hook_rule.prep_guard('mage', 'dw#mg1', 'opener', 'dw#sq15', '')
    acts = ['SetGlobalTimer("castspell","LOCALS",ONE_ROUND)', 'ForceSpellRES("dw#sq15",Myself)  // dw#sq15',
            'SetGlobal("instantprep","LOCALS",1)', 'SetGlobalTimer("redefend","LOCALS",7)',
            'IncrementGlobal("l9_mage_spells","LOCALS",1)']
    block = hook_rule.aside(prep(FIRST, acts), ['  !' + question])
    assert hook_rule.opener_twin(block, question) == hook_rule.aside(prep(FIRST, [
        'SetGlobal("instantprep","LOCALS",1)', 'SetGlobalTimer("redefend","LOCALS",7)', 'Continue()']), ['  ' + question])
    acts = ['SetGlobalTimerRandom("castspell","LOCALS",6,12)', 'Spell(Myself,WIZARD_MANTLE)',
            'SetGlobal("instantprep","LOCALS",1)']
    block = hook_rule.aside(prep(FIRST + ['OR(2)', '  See([PC])'], acts, [(50, acts)]), ['  !' + question])
    assert block.startswith('IF\n  !' + question + '\n')
    twin = hook_rule.opener_twin(block, question)
    kept = ['SetGlobal("instantprep","LOCALS",1)', 'Continue()']
    assert twin == hook_rule.aside(prep(FIRST + ['OR(2)', '  See([PC])'], kept, [(50, kept)]), ['  ' + question])
    assert twin.startswith('IF\n  ' + question + '\n') and '!' + question not in twin


def test_preparation_below_the_anchor_stays_scs_own():
    # Blocks below the anchor run only when the engine declines the round: they stay as they are.
    source = ('IF\n  Global("x","LOCALS",0)\n  INI("DMWW_mage_prep_difficulty",0)\nTHEN\n  RESPONSE #100\n'
              '    SetGlobal("x","LOCALS",1)\n    Continue()\nEND\n\n'
              'IF\n  !GlobalTimerNotExpired("castspell","LOCALS")\n  See(NearestEnemyOf(Myself))\n'
              'THEN\n  RESPONSE #100\n    SetGlobalTimer("castspell","LOCALS",6)\n    Spell(NearestEnemyOf(Myself),WIZARD_HORROR)\nEND\n\n'
              + prep(PREBUFF, ['ReallyForceSpellRES("dwsw408",Myself)', 'RemoveSpell(WIZARD_STONE_SKIN)', 'Continue()']))
    patched, reason, family, copies = hook_rule.patch(source, 'dw#mg1')
    assert (reason, family, copies) == ('hooked', 'mage', 0)
    assert 'BGSE_Prep' not in patched
    spans, anchor, _ = hook_rule.plan(source)
    assert anchor == 1 and hook_rule.preparations(source, spans, anchor) == {}
