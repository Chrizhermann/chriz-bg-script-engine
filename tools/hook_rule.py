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

Run it on a folder of decompiled scripts to see what an install would do:
    python tools/hook_rule.py <folder-with-baf> [report.json]
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


def guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Claim and BGSE_Claim(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def zones_guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Zones and BGSE_Zones(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


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


def stand_aside(block, family, script):
    """A cloud block that runs only when the engine does not weigh zones for the creature. The
    condition goes last; first when the triggers end in an OR group that lacks members, which it
    would otherwise join."""
    trig, resp = split(block)
    condition = f'  !{zones_guard(family, script)}'
    if open_or(trig):
        return 'IF\n' + condition + '\n' + block[len('IF\n'):]
    return trig + '\n' + condition + resp


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


def plan(text):
    """Return (anchor index, copied block indices) or None when the script has no anchor."""
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
    for i in range(anchor, len(texts)):
        if is_special(texts[i]) or is_encounter(texts[i]):
            copies.add(i)
            if 'LastSeenBy(Myself)' in texts[i]:
                k = i - 1
                while k >= anchor and is_target_pick(texts[k]):
                    copies.add(k)
                    k -= 1
    return spans, anchor, sorted(copies)


def patch(text, script):
    """Return (patched text or None, reason, family, number of copies) for the named script."""
    text = text.replace('\r', '')
    script = script.lower()
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
    spans, anchor, copies = plan(text)
    if anchor is None:
        return None, 'no-anchor', fam, 0
    insert = ''.join(text[spans[i][0]:spans[i][1]].replace('IF\n', f'IF\n  {guard(fam, script)}\n', 1) + '\n'
                     for i in copies)
    at = spans[anchor][0]
    head = text[:at]
    # From the last one up, so the blocks before keep their offsets.
    for i in reversed(clouds(text, spans, anchor)):
        a, b = spans[i]
        head = head[:a] + stand_aside(text[a:b], fam, script) + head[b:]
    return head + insert + hook_block(fam, script) + text[at:], 'hooked', fam, len(copies)


def main():
    folder = Path(sys.argv[1])
    rows = []
    for path in sorted(folder.glob('*.baf')):
        text = path.read_text(encoding='latin-1')
        patched, reason, fam, copies = patch(text, path.stem)
        spans, anchor, _ = plan(text.replace('\r', ''))
        aside = len(clouds(text.replace('\r', ''), spans, anchor)) if patched else 0
        rows.append({'script': path.stem, 'family': fam, 'result': reason, 'copies': copies, 'clouds': aside})
    summary = {}
    for row in rows:
        key = f"{row['family']}/{row['result']}"
        summary[key] = summary.get(key, 0) + 1
    print(json.dumps(summary, indent=1, sort_keys=True))
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(json.dumps(rows, indent=1), encoding='utf-8')


if __name__ == '__main__':
    main()
