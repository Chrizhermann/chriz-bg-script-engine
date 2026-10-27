"""Reference version of the install-time hook rule (bgse/lib/hook.tpa does the same in WeiDU).

Input is a decompiled SCS script (BAF text as WeiDU writes it). The hook goes immediately
before the anchor, the first block of SCS's per-round action choice. Above the hook go guarded
copies of the SCS blocks that must keep running while the engine drives the creature:
bookkeeping runs, the creature's own special abilities, and every block that does more than
an ordinary combat round (summoning, dialogue, leaving the area, changing allegiance, death
handlers and the like). The original blocks stay where they are, so a declining or
switched-off engine leaves SCS's order untouched. Each hook and copy names its own script, so
the engine can tell which of a creature's scripts asks.

SCS's cloud blocks above the anchor stand aside while the engine weighs danger zones for the
creature: its escapes (they set SCS's seencloud timer and run from a cloud or walk at the enemy,
genai/ssl/fleecloud.ssl), its mages' run from a Cloudkill before they see the enemy (only
SetInterrupt and a run from the marker it heard, mage/ssl/generalblocks/gohostile.ssl) and its
stand-still while it hears a cloud and sees no enemy (mage/ssl/generalblocks/fleecloud.ssl).
They get a last condition that holds when BGSE_Zones says no; with no enemy in sight it says yes
only when the engine leads the creature out of a zone that hurts it. SCS's own triggers still run
first, as before, and the engine is asked only when SCS would act. Those below the anchor run
only when the engine declines and stay as they are.

SCS's hunt for enemies the creature no longer sees stands aside, above and below the anchor, for
every creature the engine drives, which searches with its own senses and abilities instead: its
chase (the blocks that use its chase variables and walk to the party member it last saw, teleport
there, start or end the chase), its free detection casts (Oracle, Invisibility Purge or Detect
Invisibility on its detect timer) and its walk to the nearest closed door. So does every other
pursuit of a creature it does not perceive: a block whose triggers say it sees or detects no enemy
(or not the one it acts on) and that walks, jumps, casts or attacks at an enemy or party member no
trigger says it sees (a phase spider's or a mind flayer's teleport to a party member, a dragon's
walk to one, the walk to the nearest enemy on an ally's shout), unless the creature must be on the
party's side for it (an ally following the party); and its random walk while an unseen attacker
puzzles it (the whatthe timer). They get a last condition that holds when BGSE_Search says no, and
they are never copied above the hook. The chase's bookkeeping (which party member it last saw,
forgetting the dead) ends with Continue() and stays as it is.

SCS's scripted teleports (Christopher, 2026-10-26: such powers become real abilities): a cast
without a spellbook check (no HaveSpell or the like in its triggers) of a spell that moves the
caster, as SCS's fiends, elementals and Melissan teleport with dw#fitel. The installer gives the
creatures whose scripts do that a real innate Teleport of their own (bgse/setup-bgse.tp2), which
the engine casts like any spell. A scripted teleport at a creature a trigger says the creature
sees is a jump into the fight (SCS's fiends jump to a weak party member): it stands aside like the
hunt and is never copied above the hook, as the engine jumps with the creature's own Teleport.
Scripted teleports elsewhere (to a partner, to the summoner, to a point) stay SCS's. Which spells
move the caster comes from the game's spell files (teleports: their upper-case resrefs and
SPELL.IDS names).

SCS's free invisibility (F2f; Christopher, 2026-10-26: thieves hide with their own Hide in
Shadows): a block whose triggers check no spellbook and whose every action is bookkeeping or a
spellbook-free cast or application at the creature itself, at least one of a spell that makes its
target invisible (SCS's thieves, fiends, mind flayers and sirine turn invisible so when they see no
enemy; its mages fire a contingency's Improved Invisibility). Such a block gets a last condition
that holds when BGSE_Hide says no: the engine hides the creature its own way (a thief's Hide in
Shadows stands in for plain invisibility only), and for every other creature SCS's block runs as
before. A copy above the hook takes the condition too. Which spells make their target invisible,
and whether improved (Improved Invisibility lasts through attacks), comes from the game's spell
files (hides: upper-case resrefs, SPELL.IDS names and numbers, to 'plain' or 'improved'). The thieves
whose scripts do that get hide skills that fit their level (hide_skill; bgse_raise_skills). SCS's
contingencies and sequencers that fire an invisibility (they check the CONTINGENCY_TRIGGERED spell
state) are its preparation, which stays SCS's: no condition.

Every other creature whose scripts make it invisible for free gets real abilities instead (F2f-5;
Christopher, 2026-10-27: such powers become real innate abilities, as often as SCS gives them):
each spell such a block casts or applies at the creature becomes an innate ability of its own (gifts),
an invisibility that is no innate ability the game's own Invisibility or Improved Invisibility. It
comes back after the block's own timer, or after a round when SCS gives it whenever it fits; when SCS
counts its uses, the creature gets that many (frequency). A creature keeps an innate invisibility of
its own of the same kind, and a thief hides by its skill instead of a plain one (creature_gifts).

Run it on a folder of decompiled scripts to see what an install would do:
    python tools/hook_rule.py <folder-with-baf> [report.json] [teleports.txt] [hides.txt]
"""
import json
import re
import sys
from pathlib import Path

CASTSPELL = 'GlobalTimerNotExpired("castspell","LOCALS")'
FIRST_ROUND = 'SetGlobal("instantprep","LOCALS",1)'
FAMILIES = (('DMWW_mage_', 'mage'), ('DMWW_priest_', 'priest'), ('DMWW_genai_', 'fighter'))
# Any other SCS difficulty setting (fiend, dragon, vampire, genie, beholder, ...) marks an SCS
# monster script.
MONSTER = re.compile(r'DMWW_[a-z_]+_difficulty')
MARK = 'BGSE_Claim'
CLOUD = 'SetGlobalTimer("seencloud","LOCALS",'
# A trigger that hears one of SCS's cloud markers shout (initial/detectcloud.tpa: 404 Cloudkill to
# 413 Suffocate); !Heard listens for none.
CLOUD_SHOUT = re.compile(r'^ +Heard\(\[ANYONE\],(40[4-9]|41[0-3])\)', re.M)
# A run from the marker the creature heard, and the interrupt switches around it.
RUN_FROM_MARKER = re.compile(r'^ {4}RunAwayFrom[A-Za-z]*\(LastHeardBy\(Myself\),', re.M)
INTERRUPT = re.compile(r'^ {4}SetInterrupt\(', re.M)
OR_LINE = re.compile(r' +OR\((\d+)\)')
ACTION = re.compile(r'^ {4}([A-Za-z_][A-Za-z0-9_]*)\(', re.M)
RETARGET = {'SetGlobal', 'SetGlobalTimer', 'IncrementGlobal', 'ClearActions'}
BOOKKEEPING = {'SetGlobal', 'SetGlobalTimer', 'IncrementGlobal', 'Continue', 'DisplayString',
               'DisplayStringHead', 'GiveItemCreate', 'DestroyItem', 'CreateItem'}
ITEMS = {'GiveItemCreate', 'DestroyItem', 'CreateItem'}
SELF_APPLY = re.compile(r'^ {4}ApplySpellRES\("[^"]*",Myself\)', re.M)
PERCEPTION = re.compile(
    r'[^A-Za-z0-9_](See|Detect|Heard|Range|AttackedBy|HitBy|LastSeenBy|LastHeardBy|LastAttackerOf'
    r'|LastTargetedBy|NearestEnemyOf|Nearest|SecondNearest|ThirdNearest|InParty|SpellCast'
    r'|SpellCastOnMe|SpellCastPriest|SpellCastInnate)\(|\[(PC|ENEMY|ANYONE|GOODCUTOFF|EVILCUTOFF|NEUTRAL)'
    r'|Player[1-6]')
SPELLBOOK_GATE = re.compile(r'[^A-Za-z0-9_](HaveSpell|HaveSpellRES|HasItem|KnowSpell)\(')
UNGATED_CAST = {'ForceSpell', 'ForceSpellRES', 'ReallyForceSpell', 'ReallyForceSpellRES',
                'ForceSpellPoint', 'ForceSpellPointRES', 'ReallyForceSpellPoint',
                'ReallyForceSpellPointRES'}
# Casts that use up no memorized spell. Without a spellbook check they are scripted abilities
# too (Christopher's answer 10), unless the block also removes the spell: then it uses up a
# spellbook entry after all.
NO_DECREMENT = {'SpellNoDec', 'SpellNoDecRES'}
# Powers a creature applies to itself without a spellbook check are its own abilities too
# (Christopher's answer 11), for example the steps of a vampire's rat form or a genie's fire
# shield.
SELF_POWER = re.compile(r'^ {4}(ApplySpellRES\("[^"]*",Myself\)|ApplySpell\(Myself,)', re.M)
# What an ordinary combat round is made of: casts, items, attacks, weapons, movement around
# enemies, waiting, and the variables, timers and messages that go with them. A block at or
# below the anchor with any other action belongs to SCS's own logic and is copied above the
# hook.
COMBAT = UNGATED_CAST | {
    'Spell', 'SpellRES', 'SpellNoDec', 'SpellNoDecRES', 'SpellPoint', 'SpellPointRES',
    'UseItem', 'Attack', 'AttackOneRound', 'AttackReevaluate', 'AttackNoSound',
    'EquipMostDamagingMelee', 'EquipRanged', 'SelectWeaponAbility',
    'MoveToObject', 'RunAwayFrom', 'RunAwayFromNoLeaveArea', 'RunAwayFromNoInterrupt',
    'RunAwayFromNoInterruptNoLeaveArea', 'RandomWalk', 'RandomWalkContinuous', 'FaceObject',
    'Turn', 'OpenDoor', 'Wait', 'SmallWait', 'NoAction', 'SetInterrupt', 'ClearActions',
    'RemoveSpell', 'ApplySpellRES', 'ApplySpell',
    'Continue', 'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal',
    'DisplayString', 'DisplayStringHead', 'VerbalConstant', 'PlaySound'}
# SCS's hunt in every script it generates: its chase variables, its free detection timer and its
# walk to the nearest door.
CHASE = re.compile(r'"(chasetimer|chasing|chasepc|chasetarget|teleportpursuetimer)","LOCALS"', re.I)
DETECT_TIMER = re.compile(r'^ {4}SetGlobalTimer\("detect","LOCALS",', re.M | re.I)
DOOR_SEARCH = re.compile(r'^ {4}OpenDoor\(NearestDoor\)', re.M)
# What a chase block may do and still be the chase's bookkeeping, when every response ends with
# Continue().
HUNT_BOOKKEEPING = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal', 'Continue',
                    'DisplayString', 'DisplayStringHead'}
# Pursuit of a creature the creature does not perceive (is_pursuit). Comments go first: WeiDU
# writes resource names and texts after some actions.
COMMENT = re.compile(r' *//.*$', re.M)
SENSE = re.compile(r'^ +(!?)(?:See|Detect)\((.*)\) *$', re.M)
# A party member, the nearest enemy, the creature last seen or a class of creatures.
TARGET = re.compile(r'Player[1-6]|NearestEnemyOf\(Myself\)|LastSeenBy\(Myself\)|\[(?:PC|GOODCUTOFF|ENEMY|ANYONE)[^\]]*\]')
# Not seeing or detecting one of these means not perceiving any enemy.
ANY_ENEMY = re.compile(r'NearestEnemyOf\(Myself\)|\[(?:PC|GOODCUTOFF|ENEMY|ANYONE)\]')
PURSUIT = re.compile(
    r'^ {4}(?:MoveToObject|MoveToObjectFollow|MoveToObjectNoInterrupt|JumpToObject|ForceSpell|ForceSpellRES|'
    r'ReallyForceSpell|ReallyForceSpellRES|Spell|SpellRES|SpellNoDec|SpellNoDecRES|UseItem|Attack|AttackOneRound|'
    r'AttackReevaluate|AttackNoSound)\((.*)\) *$', re.M)
ALLY = re.compile(r'^ +Allegiance\(Myself,GOODCUTOFF\)', re.M)
PUZZLED = re.compile(r'^ +GlobalTimerNotExpired\("whatthe","LOCALS"\)', re.M)
WANDER = re.compile(r'^ {4}RandomWalk(?:Continuous)?\(', re.M)
# A spellbook-free cast: the RES forms name the resource first, the others the target (a point
# for the Point forms) first and the spell (a SPELL.IDS name or number) last.
UNGATED = re.compile(r'^ {4}((?:Really)?ForceSpell(?:Point)?(?:RES)?)\((.*)\) *$', re.M)
# A spellbook-free cast or application at the creature itself, and what a block that gives it free
# invisibility may do besides (free_hide).
SELF_CAST = re.compile(r'^ {4}(?:(?:ApplySpellRES|ForceSpellRES|ReallyForceSpellRES|SpellNoDecRES)\("([^"]*)",Myself\)|'
                       r'(?:ApplySpell|ForceSpell|ReallyForceSpell|SpellNoDec)\(Myself,([^,()" ]+)\)) *$')
HIDE_BOOKKEEPING = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal', 'Continue',
                    'DisplayString', 'DisplayStringHead'}
# SCS's contingencies and sequencers fire when the CONTINGENCY_TRIGGERED spell state is not set yet.
CONTINGENCY = re.compile(r'^ +!?CheckSpellState\(Myself,CONTINGENCY_TRIGGERED\) *$', re.M)
# How often SCS gives a free invisibility (frequency): a counter of its uses, a variable it checks for 0
# and then sets, or a timer of its own that it checks for having run out and sets again (not the
# round timer).
COUNTER = re.compile(r'^ +GlobalLT\("([^"]+)","LOCALS",(\d+)\) *$', re.M)
COUNT_UP = re.compile(r'^ {4}IncrementGlobal\("([^"]+)","LOCALS",1\) *$', re.M)
UNSET = re.compile(r'^ +(?:!GlobalGT\("([^"]+)","LOCALS",0\)|Global\("([^"]+)","LOCALS",0\)) *$', re.M)
SET = re.compile(r'^ {4}SetGlobal\("([^"]+)","LOCALS",(\d+)\) *$', re.M)
TIMER_CHECK = re.compile(r'^ +(?:!GlobalTimerNotExpired|GlobalTimerExpired)\("([^"]+)","LOCALS"\) *$', re.M)
TIMER_SET = re.compile(r'^ {4}SetGlobalTimer\("([^"]+)","LOCALS",([A-Za-z0-9_]+)\) *$', re.M)
ROUND_TIMER = 'castspell'
# A gift comes back after a round when SCS gives it whenever it fits; a recharge goes into a gift's
# name as two base-36 digits of seconds (gift_name), so it is at most 1295 seconds.
ROUND = 6
MAX_RECHARGE = 1295
# The game's own invisibility of each kind (Invisibility and Improved Invisibility), for one that is no
# innate ability (gifts).
INVISIBILITY = {'plain': 'SPWI206', 'improved': 'SPWI405'}
BASE36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
SPELL_TAG = re.compile(r'^SP(WI|PR|IN|CL)(\d{3})$')


def guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Claim and BGSE_Claim(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def zones_guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Zones and BGSE_Zones(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def search_guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Search and BGSE_Search(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def hide_guard(family, script, kind):
    return ('EEex_LuaTrigger("return BGSE_Hide and BGSE_Hide(EEex_LuaTrigger_Object,'
            f"'{family}','{script}','{kind}') or false\")")


def hook_block(family, script):
    return (f'IF\n  {guard(family, script)}\nTHEN\n  RESPONSE #100\n'
            '    EEex_LuaAction("if BGSE_Act then BGSE_Act(EEex_LuaAction_Object) end")\nEND\n\n')


def blocks(text):
    """(start, end) of every block: from its IF line up to and including its END line."""
    spans, pos = [], 0
    while True:
        start = text.find('IF\n', pos)
        while start > 0 and text[start - 1] != '\n':
            start = text.find('IF\n', start + 1)
        if start < 0:
            return spans
        end = text.find('\nEND\n', start)
        if end < 0:
            return spans
        spans.append((start, end + 5))
        pos = end + 5


def split(block):
    then = block.find('\nTHEN\n')
    return block[:then], block[then:]


def responses(block):
    """Action names per response."""
    _, resp = split(block)
    return [ACTION.findall(part) for part in resp.split('\n  RESPONSE #')[1:]]


def open_or(trig):
    """Whether a trigger list ends inside its last OR(n) group, with fewer than n lines after it."""
    lines = trig.split('\n')[1:]
    for i in range(len(lines) - 1, -1, -1):
        m = OR_LINE.match(lines[i])
        if m:
            return len(lines) - 1 - i < int(m.group(1))
    return False


def aside(block, conditions):
    """The block with extra trigger lines. They go last; first when the triggers end in an OR group
    that lacks members, which they would otherwise join."""
    trig, resp = split(block)
    lines = '\n'.join(conditions)
    if open_or(trig):
        return 'IF\n' + lines + '\n' + block[len('IF\n'):]
    return trig + '\n' + lines + resp


def stand_aside(block, family, script):
    """A cloud block that runs only when the engine does not weigh zones for the creature."""
    return aside(block, [f'  !{zones_guard(family, script)}'])


def is_cloud(block):
    """SCS's escape from a cloud (it sets the seencloud timer), or a block whose triggers hear a
    marker's shout and that only stands still (every response is NoAction() alone) or only runs
    from the marker it heard (as many runs from LastHeardBy(Myself) as responses, and nothing else
    but SetInterrupt; lab batches H7 and H8: SCS's mages' run from a Cloudkill, which sets no
    timer, kept mages standing in an Incendiary Cloud for 34 to 38 seconds)."""
    trig, resp = split(block)
    if CLOUD in resp:
        return True
    rs = responses(block)
    if not rs or not CLOUD_SHOUT.search(trig):
        return False
    if all(r == ['NoAction'] for r in rs):
        return True
    runs = len(RUN_FROM_MARKER.findall(resp))
    return runs == len(rs) and sum(len(r) for r in rs) == runs + len(INTERRUPT.findall(resp))


def clouds(text, spans, anchor):
    """Indices of the cloud blocks above the anchor."""
    if anchor is None:
        return []
    return [i for i in range(anchor) if is_cloud(text[spans[i][0]:spans[i][1]])]


def is_pursuit(block):
    """A pursuit of a creature the creature does not perceive: its triggers say it sees or detects
    no enemy (the nearest enemy or a class of creatures), or not the one it acts on, and a response
    walks, jumps, casts, uses an item or attacks at an enemy or party member that no trigger says it
    sees or detects; not when the creature must be on the party's side (an ally following the
    party). Or it random-walks while an unseen attacker puzzles it (SCS's whatthe timer) and it
    sees or detects no enemy."""
    trig, resp = split(COMMENT.sub('', block))
    if ALLY.search(trig):
        return False
    seen, unseen = set(), set()
    for m in SENSE.finditer(trig):
        (unseen if m.group(1) else seen).add(m.group(2))
    none_seen = any(ANY_ENEMY.fullmatch(t) for t in unseen)
    if none_seen and PUZZLED.search(trig) and WANDER.search(resp):
        return True
    return any(t not in seen and (none_seen or t in unseen)
               for m in PURSUIT.finditer(resp) for t in TARGET.findall(m.group(1)))


def is_hunt(block):
    """A block of SCS's hunt for enemies the creature cannot see: it walks to the nearest door and
    opens it, casts on its detect timer, uses SCS's chase variables for more than bookkeeping that
    ends with Continue() (it walks or teleports to the party member it last saw, starts the chase or
    ends it), or pursues a creature it does not perceive (is_pursuit: a phase spider's or a mind
    flayer's teleport, a dragon's walk to a party member)."""
    _, resp = split(block)
    rs = responses(block)
    acts = any(n not in HUNT_BOOKKEEPING for r in rs for n in r)
    if DOOR_SEARCH.search(resp) or (acts and DETECT_TIMER.search(resp)):
        return True
    if CHASE.search(block) and (acts or not all(r and r[-1] == 'Continue' for r in rs)):
        return True
    return is_pursuit(block)


def hunts(text, spans):
    """Indices of SCS's hunting blocks, above and below the anchor."""
    return [i for i, (a, b) in enumerate(spans) if is_hunt(text[a:b])]


def ungated_casts(block):
    """(spell, target) for each spellbook-free cast of a block whose triggers check no spellbook:
    the spell in upper case as written (a resref, a SPELL.IDS name or a number), the target None
    for a cast at a point."""
    trig, resp = split(COMMENT.sub('', block))
    if SPELLBOOK_GATE.search(trig):
        return []
    out = []
    for m in UNGATED.finditer(resp):
        action, args = m.group(1), m.group(2)
        if action.endswith('RES'):
            spell, _, target = args.partition(',')
            spell = spell.strip().strip('"')
        else:
            target, _, spell = args.rpartition(',')
        out.append((spell.strip().upper(), None if 'Point' in action else target.strip()))
    return out


def scripted_teleports(block, teleports):
    """The spells of a block's spellbook-free casts that move the caster (teleports)."""
    return [s for s, _ in ungated_casts(block) if s in teleports]


def is_jump(block, teleports):
    """A scripted teleport into the fight: a spellbook-free cast of a spell that moves the caster
    (teleports) at an enemy, a party member or the creature last seen, which a trigger says the
    creature sees or detects (SCS's fiends jump to a weak party member that way); not one to the
    summoner, a partner or a point, nor one the creature must be on the party's side for."""
    trig, _ = split(COMMENT.sub('', block))
    if ALLY.search(trig):
        return False
    seen = {m.group(2) for m in SENSE.finditer(trig) if not m.group(1)}
    return any(s in teleports and t is not None and t in seen and TARGET.fullmatch(t)
               for s, t in ungated_casts(block))


def jumps(text, spans, teleports):
    """Indices of SCS's scripted jumps into the fight that are not part of its hunt."""
    return [i for i, (a, b) in enumerate(spans) if is_jump(text[a:b], teleports) and not is_hunt(text[a:b])]


def teleporter(text, teleports):
    """Whether a script lets its creature teleport by script: a scripted teleport anywhere in it."""
    text = text.replace('\r', '')
    return any(scripted_teleports(text[a:b], teleports) for a, b in blocks(text))


def self_spells(text):
    """The spells of a script's spellbook-free casts and applications at the creature itself, in
    upper case as written (resrefs, SPELL.IDS names and numbers), each once: those whose spell files
    say whether they make their target invisible (hides)."""
    out = []
    for line in COMMENT.sub('', text.replace('\r', '')).split('\n'):
        spell = cast_at_self(line)
        if spell and spell not in out:
            out.append(spell)
    return out


def cast_at_self(line):
    """The spell of a line that casts or applies it at the creature itself without a spellbook
    (SELF_CAST), in upper case as written ('' for an empty RES name), or None."""
    m = SELF_CAST.match(line)
    if not m:
        return None
    return (m.group(1) if m.group(1) is not None else m.group(2)).upper()


def free_hide(block, hides):
    """'improved' or 'plain' for a block that makes the creature invisible for free, else None: its
    triggers check no spellbook, every action is bookkeeping (HIDE_BOOKKEEPING) or a spellbook-free
    cast or application at the creature itself (SELF_CAST: no RemoveSpell, no wait, nothing at anyone
    else), and at least one of those casts a spell that makes its target invisible (hides);
    'improved' when one such spell is Improved Invisibility. Not SCS's contingencies and sequencers
    (CONTINGENCY): they are its preparation."""
    trig, resp = split(COMMENT.sub('', block))
    if SPELLBOOK_GATE.search(trig) or CONTINGENCY.search(trig):
        return None
    kind = None
    for line in resp.split('\n'):
        action = ACTION.match(line)
        if not action or action.group(1) in HIDE_BOOKKEEPING:
            continue
        spell = cast_at_self(line)
        if spell is None:
            return None
        given = hides.get(spell) if spell else None
        if given == 'improved' or (given == 'plain' and kind is None):
            kind = given
    return kind


def hiding(text, spans, hides):
    """Index to kind ('plain' or 'improved') of every block that gives the creature free
    invisibility, above and below the anchor."""
    out = {}
    for i, (a, b) in enumerate(spans):
        kind = free_hide(text[a:b], hides)
        if kind:
            out[i] = kind
    return out


def seconds(value, times):
    """The seconds of a timer's value as WeiDU writes it: a number, or a GTIMES.IDS name (times maps
    names in upper case to seconds); None when unknown."""
    if value.isdigit():
        return int(value)
    return times.get(value.upper())


def frequency(block, times):
    """(charges, recharge) of the free invisibility a block gives: when SCS counts its uses, charges is
    their number (a GlobalLT counter the block raises by one: its limit; a variable it checks for 0 and
    sets: one) and recharge None; else charges is None and recharge the seconds of the block's own timer
    (one it checks for having run out and sets again, not the round timer; times as in seconds), at most
    MAX_RECHARGE, or a round."""
    trig, resp = split(COMMENT.sub('', block))
    raised = {m.group(1).lower() for m in COUNT_UP.finditer(resp)}
    for m in COUNTER.finditer(trig):
        if m.group(1).lower() in raised and int(m.group(2)) > 0:
            return int(m.group(2)), None
    sets = {m.group(1).lower() for m in SET.finditer(resp) if int(m.group(2)) > 0}
    for m in UNSET.finditer(trig):
        if (m.group(1) or m.group(2)).lower() in sets:
            return 1, None
    timers = {}
    for m in TIMER_SET.finditer(resp):
        timers.setdefault(m.group(1).lower(), m.group(2))
    for m in TIMER_CHECK.finditer(trig):
        name = m.group(1).lower()
        if name != ROUND_TIMER and name in timers:
            t = seconds(timers[name], times)
            if t:
                return None, min(t, MAX_RECHARGE)
    return None, ROUND


def gifts(block, hides, innates, times=None):
    """The real abilities that stand in for a block's free invisibility (free_hide), each once, in the
    block's order: (spell, kind, charges, recharge) for every spell it casts or applies at the creature
    (in upper case as written), an invisibility that is no innate ability (innates: the spells whose
    files say innate, as hides keys them) as the game's own of its kind (INVISIBILITY, by resref); kind
    is that of the spell's invisibility (hides) or None; charges and recharge as frequency gives them."""
    if not free_hide(block, hides):
        return []
    charges, recharge = frequency(block, times or {})
    out = []
    for line in COMMENT.sub('', block).split('\n'):
        spell = cast_at_self(line)
        if not spell:
            continue
        kind = hides.get(spell)
        if kind and spell not in innates:
            spell = INVISIBILITY[kind]
        gift = (spell, kind, charges, recharge)
        if gift not in out:
            out.append(gift)
    return out


def script_gifts(text, hides, innates, times=None):
    """A script's gifts (gifts), each once, in the order of its blocks."""
    text = text.replace('\r', '')
    out = []
    for a, b in blocks(text):
        for gift in gifts(text[a:b], hides, innates, times):
            if gift not in out:
                out.append(gift)
    return out


def gift_name(resref, recharge):
    """The name of the innate copy of a spell (its resref) that comes back after recharge seconds (0:
    never): BG, the spell's tag (W, P, N or C and its number for SPWI, SPPR, SPIN and SPCL spells, else
    the first four characters of its resref) and the recharge as two base-36 digits."""
    resref = resref.upper()
    m = SPELL_TAG.match(resref)
    tag = ({'WI': 'W', 'PR': 'P', 'IN': 'N', 'CL': 'C'}[m.group(1)] + m.group(2)) if m else resref[:4]
    r = max(0, min(recharge or 0, MAX_RECHARGE))
    return 'BG' + tag + BASE36[r // 36] + BASE36[r % 36]


def grant_resref(resref, innate, recharge):
    """The resref a creature gets for a gift of a spell (its resref): the spell itself when it is an
    innate ability and SCS counts its uses (no recharge), else its innate copy (gift_name)."""
    if innate and recharge is None:
        return resref.upper()
    return gift_name(resref, recharge)


def creature_gifts(scripts, gifts_of, thief, own, name, party):
    """The gifts a creature gets (each once, in the order of its script slots): those of its scripts
    (gifts_of maps hooked scripts, lower case, to their script_gifts), but no plain invisibility for a
    thief (thief: it has thief levels; it hides by its skill), no invisibility of a kind it has an innate
    ability of its own for (own: those kinds) and nothing for a joinable NPC (party: the script names
    PDIALOG.2DA lists, upper case; name is its own)."""
    if name and name.upper() in party:
        return []
    out = []
    for s in scripts:
        for gift in gifts_of.get((s or '').lower(), []):
            kind = gift[1]
            if (kind == 'plain' and thief) or (kind and kind in own):
                continue
            if gift not in out:
                out.append(gift)
    return out


def grants(scripts, memorized, teleporters, teleports):
    """Whether a creature gets the innate Teleport: one of its scripts (its script slots) is a hooked
    script that teleports by script (teleporters, upper case), and none of its memorized spells moves
    its caster (teleports): a creature with a teleport of its own keeps that one."""
    return (any(s.upper() in teleporters for s in scripts if s) and
            not any(m.upper() in teleports for m in memorized if m))


# The byte of a thief's level among a creature's three class levels (multiclass levels go in the order
# of the class's name) and the THIEFSKL.2DA row of its class, by CLASS.IDS number.
THIEF_LEVEL = {4: (0, 'THIEF'), 9: (1, 'FIGHTER_THIEF'), 10: (2, 'FIGHTER_MAGE_THIEF'), 13: (1, 'MAGE_THIEF'),
               15: (1, 'CLERIC_THIEF')}


def raises_skills(scripts, hiders, name, party):
    """Whether a creature's hide skills go up (bgse_raise_skills): one of its scripts (its script
    slots) is a hooked script that makes its creature invisible for free (hiders, lower case), and it
    is no joinable NPC (party: the script names PDIALOG.2DA lists, upper case; name is its own)."""
    return (any(s.lower() in hiders for s in scripts if s) and
            not (name and name.upper() in party))


def hide_skill(cls, levels, kit, points, kits):
    """The Hide in Shadows and Move Silently a thief SCS makes invisible for free gets at least: half of
    the skill points a player thief of its kit (else its class, else THIEF) has at its thief level, all
    it could put into the two. points maps THIEFSKL.2DA rows to (the first level's points, each later
    level's), kits KIT.IDS values to KITLIST.2DA row names; levels are its three class levels. None
    without thief levels."""
    if cls not in THIEF_LEVEL:
        return None
    at, row = THIEF_LEVEL[cls]
    if kit > 0x4000 and kits.get(kit) in points:
        row = kits[kit]
    if row not in points:
        row = 'THIEF'
    if row not in points:
        return None
    first, each = points[row]
    total = first + each * (max(levels[at], 1) - 1)
    # As WeiDU divides: towards zero.
    return min(255, int(total / 2))


def is_anchor(block):
    trig, resp = split(block)
    if CASTSPELL not in trig or FIRST_ROUND in resp:
        return False
    names = [n for r in responses(block) for n in r]
    # The ranged general AI's retarget block: reset timers and ClearActions, nothing else.
    return not (names and set(names) <= RETARGET and 'ClearActions' in names)


def is_bookkeeping(block):
    trig, resp = split(block)
    rs = responses(block)
    if not rs or not all(r and r[-1] == 'Continue' for r in rs):
        return False
    applies = len(SELF_APPLY.findall(resp))
    names = [n for r in rs for n in r]
    if sum(n not in BOOKKEEPING for n in names) != applies or names.count('ApplySpellRES') != applies:
        return False
    return not PERCEPTION.search(trig)


def carries_items(block):
    _, resp = split(block)
    return bool(SELF_APPLY.search(resp)) or any(n in ITEMS for r in responses(block) for n in r)


def is_special(block):
    trig, resp = split(block)
    if SPELLBOOK_GATE.search(trig):
        return False
    names = [n for r in responses(block) for n in r]
    return any(n in UNGATED_CAST for n in names) or (
        any(n in NO_DECREMENT for n in names) and 'RemoveSpell' not in names) or bool(SELF_POWER.search(resp))


def is_encounter(block):
    """A block that does more than an ordinary combat round, or a death handler."""
    trig, _ = split(block)
    return 'Die()' in trig or any(n not in COMBAT for r in responses(block) for n in r)


def is_target_pick(block):
    """SCS picks a target by evaluating See() for its side effect in a block that never acts."""
    trig, _ = split(block)
    rs = responses(block)
    return 'See(' in trig and bool(rs) and all(r == ['Continue'] for r in rs)


def family(text):
    for key, name in FAMILIES:
        if key in text:
            return name
    return 'monster' if MONSTER.search(text) else None


def plan(text, teleports=frozenset()):
    """Return (block spans, anchor index or None, copied block indices); teleports names the spells
    that move their caster (is_jump)."""
    spans = blocks(text)
    texts = [text[a:b] for a, b in spans]
    anchor = next((i for i, b in enumerate(texts) if is_anchor(b)), None)
    if anchor is None:
        return spans, None, []
    copies = set()
    i = anchor
    while i < len(texts):
        if is_bookkeeping(texts[i]):
            j = i
            while j < len(texts) and is_bookkeeping(texts[j]):
                j += 1
            if any(carries_items(texts[k]) for k in range(i, j)):
                copies.update(range(i, j))
            i = j
        else:
            i += 1
    standing = {i for i in range(len(texts)) if is_hunt(texts[i]) or is_jump(texts[i], teleports)}
    for i in range(anchor, len(texts)):
        if (is_special(texts[i]) or is_encounter(texts[i])) and i not in standing:
            copies.add(i)
            if 'LastSeenBy(Myself)' in texts[i]:
                k = i - 1
                while k >= anchor and is_target_pick(texts[k]):
                    copies.add(k)
                    k -= 1
    # SCS's hunt and its scripted jumps into the fight are never copied: they stand aside for the
    # engine's search and the creature's own Teleport (a fiend's teleport to the party member it
    # last saw is a special, for one).
    return spans, anchor, sorted(copies - standing)


def patch(text, script, teleports=frozenset(), hides=None):
    """Return (patched text or None, reason, family, number of copies) for the named script;
    teleports names the spells that move their caster (is_jump), hides the spells that make their
    target invisible (free_hide)."""
    text = text.replace('\r', '')
    script = script.lower()
    hides = hides or {}
    fam = family(text)
    if fam is None:
        return None, 'not-scs', None, 0
    # The name goes into Lua text inside a BAF string.
    if any(c in script for c in '\'"\\'):
        return None, 'unsafe-name', fam, 0
    if CASTSPELL not in text:
        return None, 'no-castspell', fam, 0
    if MARK in text:
        return None, 'already-hooked', fam, 0
    spans, anchor, copies = plan(text, teleports)
    if anchor is None:
        return None, 'no-anchor', fam, 0
    hidden = hiding(text, spans, hides)
    insert = ''
    for i in copies:
        block = text[spans[i][0]:spans[i][1]]
        # A copy that gives free invisibility stands aside as its original does.
        if i in hidden:
            block = aside(block, [f'  !{hide_guard(fam, script, hidden[i])}'])
        insert += block.replace('IF\n', f'IF\n  {guard(fam, script)}\n', 1) + '\n'
    at = spans[anchor][0]
    head, tail = text[:at], text[at:]
    cloudy = set(clouds(text, spans, anchor))
    hunting = set(hunts(text, spans)) | set(jumps(text, spans, teleports))
    # From the last one up, so the blocks before keep their offsets.
    for i in reversed(range(len(spans))):
        conditions = ([f'  !{zones_guard(fam, script)}'] if i in cloudy else []) + (
            [f'  !{search_guard(fam, script)}'] if i in hunting else []) + (
            [f'  !{hide_guard(fam, script, hidden[i])}'] if i in hidden else [])
        if conditions:
            a, b = spans[i]
            block = aside(text[a:b], conditions)
            if i < anchor:
                head = head[:a] + block + head[b:]
            else:
                tail = tail[:a - at] + block + tail[b - at:]
    return head + insert + hook_block(fam, script) + tail, 'hooked', fam, len(copies)


def read_hides(path):
    """A hides file: one spell a line, its name (as hides keys it) and 'plain' or 'improved'."""
    out = {}
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] in ('plain', 'improved'):
            out[parts[0].upper()] = parts[1]
    return out


def read_times(path):
    """A GTIMES.IDS file: names in upper case to seconds."""
    out = {}
    for line in Path(path).read_text(encoding='latin-1').splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0].isdigit():
            out[parts[1].upper()] = int(parts[0])
    return out


def main():
    folder = Path(sys.argv[1])
    teleports = frozenset()
    if len(sys.argv) > 3:
        teleports = frozenset(line.strip().upper() for line in Path(sys.argv[3]).read_text(encoding='utf-8').splitlines()
                              if line.strip())
    hides = read_hides(sys.argv[4]) if len(sys.argv) > 4 else {}
    # The spells whose files say innate, one a line as hides keys them, and the game's GTIMES.IDS.
    innates = frozenset(line.strip().upper() for line in Path(sys.argv[5]).read_text(encoding='utf-8').splitlines()
                        if line.strip()) if len(sys.argv) > 5 else frozenset()
    times = read_times(sys.argv[6]) if len(sys.argv) > 6 else {}
    rows = []
    for path in sorted(folder.glob('*.baf')):
        text = path.read_text(encoding='latin-1')
        patched, reason, fam, copies = patch(text, path.stem, teleports, hides)
        text = text.replace('\r', '')
        spans, anchor, _ = plan(text, teleports)
        cloudy = len(clouds(text, spans, anchor)) if patched else 0
        hunting = len(hunts(text, spans)) if patched else 0
        jumping = len(jumps(text, spans, teleports)) if patched else 0
        hidden = len(hiding(text, spans, hides)) if patched else 0
        rows.append({'script': path.stem, 'family': fam, 'result': reason, 'copies': copies, 'clouds': cloudy,
                     'hunts': hunting, 'jumps': jumping, 'hides': hidden,
                     'teleporter': bool(patched) and teleporter(text, teleports),
                     'gifts': script_gifts(text, hides, innates, times) if patched else []})
    summary = {}
    for row in rows:
        key = f"{row['family']}/{row['result']}"
        summary[key] = summary.get(key, 0) + 1
    print(json.dumps(summary, indent=1, sort_keys=True))
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(json.dumps(rows, indent=1), encoding='utf-8')


if __name__ == '__main__':
    main()
