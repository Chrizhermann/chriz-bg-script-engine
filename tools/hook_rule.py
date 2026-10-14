"""Reference version of the install-time hook rule (bgse/lib/hook.tpa does the same in WeiDU).

Input is a decompiled SCS script (BAF text as WeiDU writes it). The hook goes immediately
before the anchor, the first block of SCS's per-round action choice. Above the hook go guarded
copies of the SCS blocks that must keep running while the engine drives the creature:
bookkeeping runs, the creature's own special abilities, and every block that does more than
an ordinary combat round (summoning, dialogue, leaving the area, changing allegiance, death
handlers and the like). The original blocks stay where they are, so a declining or
switched-off engine leaves SCS's order untouched. Each hook and copy names its own script, so
the engine can tell which of a creature's scripts asks.

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
    return text[:at] + insert + hook_block(fam, script) + text[at:], 'hooked', fam, len(copies)


def main():
    folder = Path(sys.argv[1])
    rows = []
    for path in sorted(folder.glob('*.baf')):
        text = path.read_text(encoding='latin-1')
        patched, reason, fam, copies = patch(text, path.stem)
        rows.append({'script': path.stem, 'family': fam, 'result': reason, 'copies': copies})
    summary = {}
    for row in rows:
        key = f"{row['family']}/{row['result']}"
        summary[key] = summary.get(key, 0) + 1
    print(json.dumps(summary, indent=1, sort_keys=True))
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(json.dumps(rows, indent=1), encoding='utf-8')


if __name__ == '__main__':
    main()
