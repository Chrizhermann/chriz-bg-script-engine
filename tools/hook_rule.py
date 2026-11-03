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

SCS's preparation (prep_kind; Christopher, 2026-10-28: the engine takes over how creatures prepare,
first just as SCS does): its prebuffs, which it casts at once while instantprep is still 0 (a helper of
the spell at the creature, then RemoveSpell spends the memorized spell, or a free precast such as its
Stoneskin), its contingencies and sequencers, which fire once (ContingencyFired), its chain
contingencies (ChainContingencyFired, at the creature or the party) and its first-round casts at the
creature itself (openers: they set instantprep to 1). Each such block above the anchor gets a last
condition that holds when BGSE_Prep says no: the engine holds back the openers of a creature it
drives, as it chooses that round itself, and the rest runs as before unless the creature's orders hold
it back. Every response of a prebuff, contingency or chain block that casts tells the engine what the
creature prepared (BGSE_Prepped), before its closing Continue(). Both name the kind, the cast spell and
the spell taken from the spellbook, as written. An opener the engine holds still ends SCS's preparation
(opener_twin): right after it a block with its triggers, BGSE_Prep's answer the other way round, sets
what the opener sets of SCS's state, without its cast, and lets the engine take that round. SCS's own
blocks that end its preparation when no opener fires do not cover every one of its settings.

SCS's vanishing exits (is_exit; Christopher, 2026-10-28: nobody leaves for good): a block whose triggers
check the creature's own hit points below a limit and whose responses do nothing but leave: they destroy
the creature (DestroySelf) or cast a spell at it that removes its target from the game, with only its own
bookkeeping, effects, messages, waits and its dropped inventory besides (SCS's Erinyes and Melissan's
allies vanish so below a quarter or 15 %, its mind flayers below 30 %). Such a block gets a last condition
that holds when BGSE_Stay says no: the engine keeps a creature it drives in the fight unless its orders
let it leave, and for every other creature SCS's block runs as before. A copy above the hook takes the
condition too. Which spells remove their target comes from the game's spell files (vanishing: upper-case
resrefs, SPELL.IDS names and numbers). A block that does more (a cutscene, a story variable: Demogorgon's
death scene) belongs to its encounter and stays as it is.

The game's own vanishing exits (patch_own; Christopher, 2026-11-03: the Pirate Mage, a Hobgoblin Wizard
and a Nymph stay in the fight, Terminsel and Lady Yuth keep their story exits): the same kind of exit in
a script that is not SCS's (no DMWW_ in it) runs above SCS's hooked script when it sits higher in the
creature's stack. One whose triggers check nothing but the creature's own hit points and what it sees,
and whose responses quote nothing but a resource (no variable, no named creature), gets the same condition,
without a family:
BGSE_Stay goes by the script that decides for the creature, the first hooked one below (kernel/hook.lua,
driver), and answers no wherever there is none. Any other trigger may tie the exit to a story (Terminsel's
Death variable, Lady Yuth's theft), so such an exit stays as it is.

Run it on a folder of decompiled scripts to see what an install would do:
    python tools/hook_rule.py <folder-with-baf> [report.json] [teleports.txt] [hides.txt] [innates.txt]
        [gtimes.ids] [vanishing.txt]
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
# SCS's preparation (prep_kind): a trigger that instantprep is still 0 (two spaces: not one of an OR
# group), the variables its contingencies and chain contingencies set when they fire (any case), its
# forced casts, its first-round casts and the spellbook entry a prebuff spends.
PREP_STATE = re.compile(r'^  Global\("instantprep","LOCALS",0\) *$', re.M)
FIRED = re.compile(r'^ {4}SetGlobal\("([A-Za-z]+)","LOCALS",1\) *$', re.M)
FORCED = re.compile(r'^ {4}(ReallyForceSpell(?:RES)?)\((.*)\) *$')
OPENER_CAST = re.compile(r'^ {4}((?:Force)?Spell(?:RES)?)\((.*)\) *$')
SPENT = re.compile(r'^ {4}RemoveSpell(?:RES)?\((.*)\) *$')
PREP_BOOKKEEPING = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal', 'Continue',
                    'DisplayString', 'DisplayStringHead'}
FORCED_CASTS = {'ReallyForceSpell', 'ReallyForceSpellRES', 'RemoveSpell', 'RemoveSpellRES'}
OPENER_CASTS = {'Spell', 'SpellRES', 'ForceSpell', 'ForceSpellRES'}
# What an opener the engine holds still sets (opener_twin): its variables and timers, but not the round
# timer, which the engine's own first action sets.
TWIN_KEEPS = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom'}
ROUND_TIMER_SET = re.compile(r'^ {4}SetGlobalTimer(?:Random)?\("castspell","LOCALS",')
# A spell's name as it goes into Lua text inside a BAF string: what a creature's orders can name.
TOKEN = re.compile(r'[A-Za-z0-9_#-]{1,64}')
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
# SCS's vanishing exits (is_exit): a trigger on the creature's own hit points below a limit (two spaces:
# not one of an OR group; a limit of 0 never holds), the action that destroys the creature, what such a
# block may do besides, and the variable actions among those, which must keep to the creature's own
# (LOCALS) variables.
HURT = re.compile(r'^  (?:HPPercentLT|HPLT)\(Myself,[1-9][0-9]*\) *$', re.M)
GONE = re.compile(r'^ {4}DestroySelf\(\) *$')
EXIT_KEEPS = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal', 'Continue', 'DisplayString',
              'DisplayStringHead', 'CreateVisualEffect', 'CreateVisualEffectObject', 'PlaySound', 'SmallWait', 'Wait',
              'DropInventory'}
VARIABLES = {'SetGlobal', 'SetGlobalTimer', 'SetGlobalTimerRandom', 'IncrementGlobal'}
OWN_VARIABLE = re.compile(r'^ {4}[A-Za-z]+\("[^"]*","LOCALS",')
# The game's own vanishing exits (is_own_exit): what their triggers may check besides the hurt line, the
# creature's own hit points and what it sees (See or Detect, negated or not, of no named creature; two spaces:
# no OR group), and the resource an action may name in quotes (a spell by its file, a visual effect, a sound).
OWN_HP = re.compile(r'^  !?(?:HP|HPGT|HPLT|HPPercent|HPPercentGT|HPPercentLT)\(Myself,[0-9]+\) *$')
SIGHT = re.compile(r'^  !?(?:See|Detect)\([^"]*\) *$')
# SCS's talk on sight (patch_talk): the creature sees a party member it has not talked to yet and starts the talk
# with that party member.
UNTALKED = re.compile(r'^ +NumTimesTalkedTo\(0\) *$', re.M)
SEES_PARTY = re.compile(r'^ +See\(\[PC\]\) *$', re.M)
TALK_START = re.compile(r'^ {4}(?:Dialog|Dialogue|StartDialogNoSet|StartDialogueNoSet)\(\[PC\]\) *$', re.M)
RESOURCE_ARG = re.compile(r'^( {4}(?:ApplySpellRES|ForceSpellRES|ReallyForceSpellRES|SpellNoDecRES|CreateVisualEffect|'
                          r'CreateVisualEffectObject|PlaySound)\()"[^"]*"', re.M)


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


def prep_guard(family, script, kind, cast, spent):
    return ('EEex_LuaTrigger("return BGSE_Prep and BGSE_Prep(EEex_LuaTrigger_Object,'
            f"'{family}','{script}','{kind}','{cast}','{spent}') or false\")")


def stay_guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_Stay and BGSE_Stay(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def talk_guard(family, script):
    return ('EEex_LuaTrigger("return BGSE_TalkHold and BGSE_TalkHold(EEex_LuaTrigger_Object,'
            f"'{family}','{script}') or false\")")


def prep_notice(family, script, kind, cast, spent):
    return ('EEex_LuaAction("if BGSE_Prepped then BGSE_Prepped(EEex_LuaAction_Object,'
            f"'{family}','{script}','{kind}','{cast}','{spent}') end\")")


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
        spell, target = spell_and_target(m.group(1), m.group(2))
        out.append((spell.upper(), target))
    return out


def spell_and_target(action, args):
    """(spell, target) of a cast's arguments, as written: the RES forms name the resource first (in
    quotes), the others the target first (a point for the Point forms: target None) and the spell last."""
    if action.endswith('RES'):
        spell, _, target = args.partition(',')
        spell = spell.strip().strip('"')
    else:
        target, _, spell = args.rpartition(',')
    return spell.strip(), None if 'Point' in action else target.strip()


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


def token(name):
    """A spell's name as it goes into Lua text (TOKEN), '' when it cannot."""
    return name if TOKEN.fullmatch(name) else ''


def prep_kind(block):
    """(kind, cast, spent) for a block of SCS's preparation, else None. Every action is bookkeeping
    (PREP_BOOKKEEPING) or a cast of its kind, with one cast at least. 'opener': casts at the creature
    itself (Spell, SpellRES, ForceSpell or ForceSpellRES) that set instantprep to 1. The others cast at
    once (ReallyForceSpell or ReallyForceSpellRES) and may take the spell from the spellbook
    (RemoveSpell or RemoveSpellRES): 'chain' at the creature or [PC], setting ChainContingencyFired;
    'contingency' at the creature, setting ContingencyFired; 'prebuff' at the creature while instantprep
    is 0. cast is the first cast's spell, spent the first spell taken from the spellbook, as written ('':
    none, or a name unsafe in Lua text)."""
    block = COMMENT.sub('', block)
    trig, resp = split(block)
    names = {n for r in responses(block) for n in r}
    lines = resp.split('\n')
    opener = FIRST_ROUND in resp
    cast, allowed = (OPENER_CAST, OPENER_CASTS) if opener else (FORCED, FORCED_CASTS)
    casts = [spell_and_target(*m.groups()) for m in map(cast.match, lines) if m]
    if not casts or not names <= PREP_BOOKKEEPING | allowed:
        return None
    targets = {t for _, t in casts}
    fired = {m.group(1).lower() for m in FIRED.finditer(resp)}
    if opener:
        kind = 'opener' if targets == {'Myself'} else None
    elif 'chaincontingencyfired' in fired:
        kind = 'chain' if targets <= {'Myself', '[PC]'} else None
    elif 'contingencyfired' in fired:
        kind = 'contingency' if targets == {'Myself'} else None
    else:
        kind = 'prebuff' if targets == {'Myself'} and PREP_STATE.search(trig) else None
    if kind is None:
        return None
    spent = [m.group(1).strip().strip('"') for m in map(SPENT.match, lines) if m]
    return kind, token(casts[0][0]), token(spent[0] if spent else '')


def preparations(text, spans, anchor):
    """Index to (kind, cast, spent) of SCS's preparation blocks above the anchor (prep_kind)."""
    if anchor is None:
        return {}
    out = {}
    for i in range(anchor):
        prep = prep_kind(text[spans[i][0]:spans[i][1]])
        if prep:
            out[i] = prep
    return out


def notify(block, notice):
    """The block with the notice as the last action of each response that casts at once (FORCED),
    before its closing Continue(), which stays last."""
    trig, resp = split(block)
    parts = resp.split('\n  RESPONSE #')
    for k in range(1, len(parts)):
        lines = parts[k].split('\n')
        clean = [COMMENT.sub('', line) for line in lines]
        acts = [j for j, line in enumerate(clean) if ACTION.match(line)]
        if not any(FORCED.match(clean[j]) for j in acts):
            continue
        last = acts[-1]
        lines.insert(last if clean[last].strip() == 'Continue()' else last + 1, '    ' + notice)
        parts[k] = '\n'.join(lines)
    return trig + '\n  RESPONSE #'.join(parts)


def opener_twin(block, question):
    """The block that ends SCS's preparation when the engine holds an opener (block, with question, its
    prep_guard, asked as '!'): the same triggers, the question asked the other way, and in each response
    only what the opener sets of SCS's state: its variables and timers (TWIN_KEEPS; SCS's instantprep and
    redefend), not the round timer (ROUND_TIMER_SET: the engine's first action sets it), nor the cast, a
    counter (a held cast counts nothing) or a message; then Continue(), so the engine takes that round
    in the same pass."""
    trig, resp = split(block.replace('!' + question, question, 1))
    kept = []
    for line in resp.split('\n'):
        action = ACTION.match(line)
        if action is None or (action.group(1) in TWIN_KEEPS and not ROUND_TIMER_SET.match(line)):
            kept.append(line)
    head, mark, rest = '\n'.join(kept).partition('\n  RESPONSE #')
    rest = rest.replace('\n  RESPONSE #', '\n    Continue()\n  RESPONSE #')
    return trig + head + mark + rest[:-len('\nEND\n')] + '\n    Continue()\nEND\n'


def is_exit(block, vanishing):
    """SCS's vanishing exit: its triggers check the creature's own hit points below a limit (HURT: not
    negated, not one of an OR group), and its responses do nothing but leave. At least one destroys the
    creature (DestroySelf) or casts or applies at it, without a spellbook, a spell that removes its target
    (SELF_CAST; vanishing as hides keys spells: SCS's Erinyes and Melissan's allies with Dryad Teleport,
    its mind flayers with dw#mfesc); every other action is the creature's own bookkeeping, an effect, a
    message, a wait or its dropped inventory (EXIT_KEEPS; variables only its own LOCALS ones). A block
    that does more (a cutscene, a story variable: Demogorgon's death scene) belongs to its encounter."""
    trig, resp = split(COMMENT.sub('', block))
    if not HURT.search(trig):
        return False
    leaves = False
    for line in resp.split('\n'):
        action = ACTION.match(line)
        if not action:
            continue
        if GONE.match(line) or cast_at_self(line) in vanishing:
            leaves = True
        elif action.group(1) not in EXIT_KEEPS or (action.group(1) in VARIABLES and not OWN_VARIABLE.match(line)):
            return False
    return leaves


def exits(text, spans, vanishing):
    """Indices of SCS's vanishing exits, above and below the anchor."""
    return [i for i, (a, b) in enumerate(spans) if is_exit(text[a:b], vanishing)]


def is_own_exit(block, vanishing):
    """A vanishing exit (is_exit) in one of the game's own scripts that no story decides: every trigger checks
    the creature's own hit points or what it sees (OWN_HP, SIGHT: no variable, no named creature, no OR group),
    and its responses quote nothing but a resource (RESOURCE_ARG), so they set no variable and name no
    creature. Terminsel's exit (while his Death variable is 0) and Lady Yuth's (once she has stolen) belong to
    their stories."""
    if not is_exit(block, vanishing):
        return False
    trig, resp = split(COMMENT.sub('', block))
    if any(line and line != 'IF' and not (OWN_HP.match(line) or SIGHT.match(line)) for line in trig.split('\n')):
        return False
    return '"' not in RESOURCE_ARG.sub(r'\1', resp)


def own_exits(text, spans, vanishing):
    """Indices of the vanishing exits of one of the game's own scripts that no story decides."""
    return [i for i, (a, b) in enumerate(spans) if is_own_exit(text[a:b], vanishing)]


def patch_own(text, script, vanishing=frozenset()):
    """Return (patched text or None, number of exits) for a script that is not SCS's (no DMWW_ in it) and was
    not patched before (no BGSE_Stay in it): each of its vanishing exits that no story decides (own_exits) gets
    BGSE_Stay's condition with no family, last (it has no OR group). BGSE_Stay goes by the script that decides
    for the creature (kernel/hook.lua, driver)."""
    text = text.replace('\r', '')
    script = script.lower()
    if 'DMWW_' in text or 'BGSE_Stay' in text or any(c in script for c in '\'"\\'):
        return None, 0
    spans = blocks(text)
    leaving = own_exits(text, spans, vanishing)
    for i in reversed(leaving):
        a, b = spans[i]
        text = text[:a] + aside(text[a:b], [f'  !{stay_guard("", script)}']) + text[b:]
    return (text if leaving else None), len(leaving)


def is_talk(block):
    """SCS's talk on sight: NumTimesTalkedTo(0) and See([PC]) among the triggers, and a response that starts the
    talk with that party member (Dialog or StartDialogNoSet at [PC]). Comments do not count."""
    trig, resp = split(COMMENT.sub('', block))
    return bool(UNTALKED.search(trig) and SEES_PARTY.search(trig) and TALK_START.search(resp))


def patch_talk(text, script):
    """Return (patched text or None, number of talk blocks) for SCS's talk-on-sight script: SCS's DMWW_ marker, no
    castspell round timer, and every block a talk on sight (is_talk). SCS gives it to the creatures that speak to the
    party on sight and then fight (dw#shdlg); Christopher, 2026-11-03: such a creature prepares when it sees the party,
    and the talk comes right after. Each block gets BGSE_TalkHold's condition with no family: last, first when its
    triggers end in an OR group that lacks members (aside). A scripted encounter whose script does more (SCS's
    Icharyd and his storm) is designed one by one and stays as it is; so do a script patched before (BGSE_TalkHold in
    it) and one whose name cannot go into Lua text."""
    text = text.replace('\r', '')
    script = script.lower()
    if 'DMWW_' not in text or 'castspell' in text or 'BGSE_TalkHold' in text or any(c in script for c in '\'"\\'):
        return None, 0
    spans = blocks(text)
    talks = [i for i, (a, b) in enumerate(spans) if is_talk(text[a:b])]
    if len(talks) != len(spans):
        return None, 0
    for i in reversed(talks):
        a, b = spans[i]
        text = text[:a] + aside(text[a:b], [f'  !{talk_guard("", script)}']) + text[b:]
    return (text if talks else None), len(talks)


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


def patch(text, script, teleports=frozenset(), hides=None, vanishing=frozenset()):
    """Return (patched text or None, reason, family, number of copies) for the named script;
    teleports names the spells that move their caster (is_jump), hides the spells that make their
    target invisible (free_hide), vanishing those that remove their target (is_exit)."""
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
    leaving = set(exits(text, spans, vanishing))
    insert = ''
    for i in copies:
        block = text[spans[i][0]:spans[i][1]]
        # A copy that gives free invisibility or is a vanishing exit stands aside as its original does.
        extra = ([f'  !{hide_guard(fam, script, hidden[i])}'] if i in hidden else []) + (
            [f'  !{stay_guard(fam, script)}'] if i in leaving else [])
        if extra:
            block = aside(block, extra)
        insert += block.replace('IF\n', f'IF\n  {guard(fam, script)}\n', 1) + '\n'
    at = spans[anchor][0]
    head, tail = text[:at], text[at:]
    cloudy = set(clouds(text, spans, anchor))
    hunting = set(hunts(text, spans)) | set(jumps(text, spans, teleports))
    preps = preparations(text, spans, anchor)
    # From the last one up, so the blocks before keep their offsets.
    for i in reversed(range(len(spans))):
        conditions = ([f'  !{zones_guard(fam, script)}'] if i in cloudy else []) + (
            [f'  !{search_guard(fam, script)}'] if i in hunting else []) + (
            [f'  !{hide_guard(fam, script, hidden[i])}'] if i in hidden else []) + (
            [f'  !{prep_guard(fam, script, *preps[i])}'] if i in preps else []) + (
            [f'  !{stay_guard(fam, script)}'] if i in leaving else [])
        if conditions:
            a, b = spans[i]
            block = aside(text[a:b], conditions)
            # The engine hears of the preparation that ran; it chooses the first round itself, and an
            # opener it holds still ends SCS's preparation.
            if i in preps and preps[i][0] != 'opener':
                block = notify(block, prep_notice(fam, script, *preps[i]))
            elif i in preps:
                block += '\n' + opener_twin(block, prep_guard(fam, script, *preps[i]))
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
    # The spells that remove their target, one a line as vanishing keys them.
    vanishing = frozenset(line.strip().upper() for line in Path(sys.argv[7]).read_text(encoding='utf-8').splitlines()
                          if line.strip()) if len(sys.argv) > 7 else frozenset()
    rows = []
    for path in sorted(folder.glob('*.baf')):
        text = path.read_text(encoding='latin-1')
        patched, reason, fam, copies = patch(text, path.stem, teleports, hides, vanishing)
        text = text.replace('\r', '')
        spans, anchor, _ = plan(text, teleports)
        cloudy = len(clouds(text, spans, anchor)) if patched else 0
        hunting = len(hunts(text, spans)) if patched else 0
        jumping = len(jumps(text, spans, teleports)) if patched else 0
        hidden = len(hiding(text, spans, hides)) if patched else 0
        preps = len(preparations(text, spans, anchor)) if patched else 0
        leaving = len(exits(text, spans, vanishing)) if patched else 0
        rows.append({'script': path.stem, 'family': fam, 'result': reason, 'copies': copies, 'clouds': cloudy,
                     'hunts': hunting, 'jumps': jumping, 'hides': hidden, 'preps': preps, 'exits': leaving,
                     'own_exits': patch_own(text, path.stem, vanishing)[1],
                     'talks': patch_talk(text, path.stem)[1],
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
