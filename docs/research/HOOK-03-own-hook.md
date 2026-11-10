# HOOK-03 — The engine's own hook for creatures without an SCS script

Date: 2026-11-10. Follows [HOOK-02](HOOK-02-monster-scripts-and-script-slots.md). Christopher, 2026-11-08: the
engine takes over every creature. Stack: BG2:EE 2.7.3.0, EET, EEex 1.2.0, SCS 35.21 and Chriz BG Magic e200515,
read from the clean labs `BGSE-Lab/eet-nosr-2` and `eet-tour`. SCS is by David Wallace (DavidW). No game file or
generated script is in this repository.

## Question

SCS gives its fight scripts to casters, fighters and many monsters, and the engine asks from a hook inside those.
Creatures SCS leaves alone fight on the game's own scripts and never ask the engine: in BG1 the gnolls of the
Gnoll Stronghold, xvarts, ankhegs, wyverns, basilisks, ettercaps, carrion crawlers, kobolds and wolves (99 of 727
hostile placed creatures), in BG2 and ToB 171 of 1,025, in Siege of Dragonspear 1,116 of 1,140. How does the engine
drive them without losing what their scripts do besides fighting?

## What these scripts are

They are short. `GNOLLDR` has eight blocks: a death count for Drizzt's quest, a variable set when the party
attacks, a call for help (`Help()`) with its attack, a random walk. `ANKHEG`, `WYVERN` and `ETTERCAP` pick one of
two weapons by chance and attack the nearest enemy; `XVARTH` attacks Hulrik's cow first and counts its dead. None
casts from a spellbook, none prepares, none coordinates. What is not a plain attack or walk is story bookkeeping,
or what the monster is known for (see "What the monsters were known for" below).

## The rule

1. **Installer** (`bgse/setup-bgse.tp2`, after the SCS rule): a script gets one hook block at its top when
   a creature carries it (a creature file's five slots, an area actor's six, the five of a creature stored in an
   area), its compiled form holds an attack or a cast (ACTION.IDS numbers of `Attack`, `AttackOneRound`,
   `AttackReevaluate`, `AttackNoSound`, `Spell`, `SpellPoint`, `ForceSpell`, `ForceSpellPoint`, `ReallyForceSpell`,
   `ReallyForceSpellPoint`, `SpellNoDec`, `SpellPointNoDec` and their RES forms) and it does not ask the engine
   yet. `EXTEND_TOP` adds the block to the compiled script; nothing is decompiled. The registry
   (`M_BGSEHK.lua`) lists the script with the family `auto`. `tools/hook_rule.py` (`fight_ids`, `wants_own`,
   `patch_auto`) mirrors it, and the installer test carries a creature, an area actor and a stored creature.
2. **Who decides** (`kernel/hook.lua`): an SCS-hooked script anywhere in the creature's slots decides, as before;
   the own hook above it stands back without an answer, so SCS's guarded blocks keep running. Only a creature
   without any SCS-hooked script is driven from the own hook.
3. **Which creature** (`adapters/eeex/hook.lua`): one on the enemy side (EA 200 and up). Its family comes from
   its class: wizard classes and bards a mage, priest classes a priest, fighters, thieves, rangers, paladins and
   monks a fighter, every other class a monster. A party member the enemy charmed (EA 254) is left to the game:
   whether the engine should play it with its own spells against its party is Christopher's to decide.
   `[BGSE] Others=0` in Baldur.lua switches the own hook off.
4. **What the script still does** (`adapters/eeex/lower.lua`, as for lower scripts in HOOK-02): on each claim the
   engine walks the rest of the script as the game would. A block that holds and does more than an ordinary combat
   round is owed and runs before the engine's own action, without its fight actions: the gnoll's `Help()` runs,
   the `AttackReevaluate` beside it is the engine's. Story variables outside `LOCALS` are written also from
   fight responses. A dead creature is never claimed, so death blocks (`Die()`) run as the game runs them.

## Numbers

In the clean tour lab 4,682 script names are carried by 9,303 creature files and the actors of 1,029 areas; 1,093
carry SCS's marks, 1,103 get the own hook, 2,260 hold no fight action and 226 name no script. The most carried
own-hook scripts are Siege of Dragonspear's (`BDFIGH01` on 420 creature files, `BDFIG00`, `BDMAGE01`), the game's
summon script `BDSUM00` (217), the plain guards' `WTASIGHT` and `SEEENEMY`, and joinable characters' `DPLAYER`.

The fight census (`tools/fight_census.py`, lab `eet-nosr-2`) with the own hook counted: of 3,063 hostile placed
creatures 1,611 are SCS's, 1,419 come through the own hook and 33 carry no fight script at all. BG1: 628 and 99
of 727. BG2 and ToB: 854 and 153 of 1,025. Siege of Dragonspear: 24 and 1,101 of 1,140. Of 6,476 creation lines
in scripts, 4,865 and 1,543.

## Lab check (2026-11-10, tour lab, engine 69f1e94, Insane)

- **Install:** the own-hook pass reached 1,108 scripts. The whole engine install took 378 seconds in the tour lab
  (233 before), still far below the 15-minute goal.
- **Ten one-minute cases** next to the protected PC, each after a fresh load: no engine error, no fault in a walk,
  clean cleanup. The engine chose every round of three gnolls (15 attack rounds; their `Help()` ran 40 times as a
  duty), three xvarts (17), two ankhegs (18; the PC lost 517 hit points), a wyvern (11; 981), three kobolds (27;
  `Help()` 27 times), a lesser basilisk (12), two ettercaps (24; 1,011), two wolves (14), the githyanki mage of
  HOOK-02 again (9; its shouts 4 times) and an enemy Dark Planetar again (8): its SCS-hooked script decides above
  `BDSUM00`, which now carries the own hook.
- SCS's help script `DW#GPSHM` sits above the hooked script of the wyvern, the basilisk and the ettercaps and ran
  as before: its shouts started by the game, before the hook is reached.
- The kobolds started their script's own `Attack` twice before the engine's first claim; the hook's response
  replaced it.
- The scripts' blocks were checked 4,888 times from inside the hook's trigger without a fault. Creatures that are
  not on the enemy side (Candlekeep's people) were declined about 300 times a minute, before any stack is read.
- **Story notes on death** (second launch, same build): two xvarts, two of Drizzt's gnolls and one of Gerde's
  ankhegs fought on the engine for ten seconds and were then killed. `XvartsDead` went from 0 to 2, `DrizztGnolls`
  from 0 to 2, `AnkhKills` and `HelpGerde` from 0 to 1: a dead creature is not claimed, so its script's death
  blocks run as the game runs them.
- **BG1 area tour, first try:** 49 of 60 areas visited with 4,416 claimed rounds and 7,173 performed actions, no
  engine error; 11 areas not reached in 45 seconds. It ended at the game's death screen in the Spider Wood: a
  spider's Web Tangle held the PC, so the tour could not leave, and a Wraith Spider's bites took its Strength to
  nothing (learned.md section 6). The lab's fault, not the build's.
- **BG1 area tour, second try** (the PC immune to ability drain and to what holds it in place): 98 of 99 areas
  visited in 35 minutes, one not reached (`BG2640`), with 1,767 claimed rounds and 3,128 performed actions; no
  engine error, none in 12,052 logged rows, no crash, clean cleanup. Where the engine had no decision, the
  creature had given up its search, saw no enemy or had no picture of the fight yet. The first tour of 2026-11-08
  reached 80 of 99; the holds explain most of the difference.
- Not shown here: a creature's fight against a real party, and how the monsters' choices read to a player.

## What the monsters were known for (2026-11-10)

Christopher, 2026-11-10, after the first lab rows: he likes that the engine takes these creatures over, but they
must not become dumber or simpler than they were, and should still behave as a player expects; their quirks
mostly stay, the engine's author decides each one and asks only where it is truly unclear. The rows of the ten
cases showed three losses, and the old scripts were read again block by block for what they did in play.

**What was lost.** Each monster with two attacks used one only: the choice took the best-scoring weapon attack
every round (`swings[1]`), and the draw that lets a creature stray from its best option covered spells alone.
Xvarts attacked the party on sight instead of Hulrik's cow, and Drizzt's gnolls the party instead of Drizzt: an
attack is the engine's, so the script's named target went with it. An ankheg and a basilisk no longer stepped
back from melee to spit or gaze: stepping away is a tactic, and a dull creature never sees one.

**The rules.**

5. **Body weapons** (`combat-intent/arsenal.lua`, `choice.lua` `M.varied`). A weapon whose item cannot be dropped
   (item flag bit 2 clear, as the game's monster attacks have it: `ANKHEG1` 0x20, `WYVERN1` 0x60; a Long Sword
   0x2c) is part of the creature. It uses them all: when its best attack is made with one of them, it takes that
   one as often as it takes its best option at all (by its wit: clever 8 times in 10, normal 6, dull 4), and
   otherwise draws among the best attack of each body weapon, each as likely as its worth's share. Taking one up
   costs no time. `mind.bodyMix` scales the mix (0: always the best one).
6. **Stepping back to shoot.** A creature whose body shoots (an ankheg's spit, a basilisk's gaze) steps away
   from melee to use it whatever its wit, when the hits it keeps off are worth more than the part of its
   attack the step costs, at most once in 18 seconds (the engine's kiting); `mind.bodyRetreat` switches it off.
   For every other creature the step stays a tactic by wit.
7. **Story targets** (`adapters/eeex/lower.lua` `story`, `kernel/hook.lua`). A script that attacks a creature it
   calls by name (`AttackReevaluate("HulriksCow",30)`, `Attack("Drizzt")`) keeps its creature while a creature
   of that name is alive in its area: the gate declines as `story` before the director or the choice hear of it,
   and the script runs as the game had the encounter, pauses and self-defence included. The gate asks again
   every 45 ticks; once the named creature is dead or gone, the engine takes over. A cast at a named creature is
   no story (a heal for a named friend); a script that names no one costs a table lookup.
8. **Panic.** A creature in panic is not the engine's: the choice declines (`panic`), and the creature runs as
   the game and its script have it. The game's own scripts open with a block for it.

**Monster by monster** (BG1's own scripts, as decompiled from the tour lab):

| Monster | Its own script | With the engine |
|---|---|---|
| Ankheg (`ANKHEG`) | spit or bite by chance (40 to 60 every 12 seconds, the spit whenever it has nothing to do); close to a foe sometimes backs off three seconds and spits | spit and bite mixed by worth and wit; steps back to spit when that pays |
| Wyvern (`WYVERN`) | bite or poison sting by chance, 40 to 60, picked every two rounds | both, the sting more often (poison is worth more) |
| Ettercap (`ETTERCAP`) | claw or poison bite, 60 to 40 | both, the poison bite more often |
| Basilisk (`LBASILSK`; `GBASILSK` the same way with a third attack) | gazes at a foe that is not stone and not known to be immune (it learns that after two rounds), spreads the gaze over the six nearest; close to a foe bites 7 times in 10, else backs off | gazes where the gaze can land (an immune foe is bitten), bites now and then; steps back to gaze when that pays |
| Carrion crawler (`CCRAWLER`) | goes for foes that are not held yet | the same by worth: paralysis is worth nothing on a foe that is out of the fight already |
| Xvart (`XVARTH`) | attacks Hulrik's cow while it lives and a party member is in sight, fights back when attacked, counts its dead | the script's while the cow lives (rule 7); then the engine's |
| Gnoll of Drizzt's (`GNOLLDR`) | attacks Drizzt while it sees him, calls for help, counts its dead | the script's while Drizzt is alive in the area (rule 7); elsewhere the engine's, the call for help a duty |
| Kobold (`KOBOLDFL`) | calls for help, attacks the nearest | the engine's attack, the call for help a duty |
| Wolf (`WOLF`) | attacks the nearest; turns hostile when attacked | the engine's attack |

**Checks.** Unit tests for each rule (455 in the suite) and a mutation check: 24 of 24 changes to the new lines
made a test fail (one of them applied by hand, as the tool did not place an anchor that ended in a line break).

**Lab check** (2026-11-10, tour lab, engine b8f8611, spell mod e200515, Insane; seven cases next to the protected
PC, each after a fresh load; no engine error, no fault in a walk, clean cleanup; the install took 256 seconds):

- Two ankhegs in a minute: 14 spits and 4 bites (before: 18 spits). A wyvern: 13 stings and 1 bite. Two
  ettercaps: 19 poison bites and 4 claw swings. The PC there has a thousand hit points and cannot die, so plain
  damage counts for little and the attack with an effect wins most draws; against a real party the shares are
  closer.
- A lesser basilisk next to the PC (immune to petrification) and Hulrik's cow put on the party's side: its first
  attack was the gaze at the cow, which turned to stone (state 128 at the first read); after that it bit the PC
  twelve times and never gazed at it.
- Three xvarts and Hulrik's cow: while the cow lived (60 hit points, 40 seconds) the xvarts ran their own
  `AttackReevaluate` at it and the gate declined 69 times as `story`, looking for the cow 34 times; the PC lost
  nothing. At the read after the cow's death (it had 2 hit points at second 40, the next read was at 60) the
  engine had all three and they were attacking the PC: 24 attack rounds until the case ended at second 100. By
  the rule the takeover comes within three seconds; the reads were too far apart to show that. The name of an
  action's target reads as written
  (`action.m_acteeID.m_name`, no read error).
- Panic (opcode 24 for ten seconds) on two gnolls with the own hook and on a githyanki with SCS's hook: all three
  ran about for the ten seconds (state 4, the game's walk actions), the engine declined 20 and 9 times as
  `panic` and queued nothing, and they fought again right after.
- Not seen: an ankheg or a basilisk stepping back to shoot. The lab's PC deals too little for the step to pay.

**Left out on purpose.** A wolf's script walks about for a moment every five seconds when its nearest foe is a
druid or a ranger, and a gnoll's every fifteen when its side outnumbers the foe. In play neither showed: the
script's next block (`See(NearestEnemyOf(Myself))`, without a check for a running action) fires in the next pass
and interrupts the walk. The same holds for the gnoll's morale block (one attack, then ten seconds of running
from the attacker): its attack block cuts the run short at once. Reviving them would add running enemies that
the old game never had (Christopher, 2026-10-28: running enemies annoy; rare, and for dull creatures). They can
come back as designed behaviour when the fights are gone through one by one.

## Limits

- A creature whose script names a story target runs wholly on that script while the target lives, also where it
  does not see the target: xvarts that see the party but not the cow wait, as they did.
- A duty waits until the engine's running action ends, a round at most; the game would have run it at once.
- Family by class says nothing about the spellbook: a mage-class creature without spells is driven as a mage and
  falls back to its weapon.
- SCS's pursuit helpers above combat scripts (`DW#C3AS1`, `DW#C3AS2`, `BANDIT`, `DW#C3HST`; BOSS-02) hold no
  attack and get no hook; their walks at unseen party members still run. Their own guard is separate work.
- Siege of Dragonspear's fights now run on the engine too, before Christopher's SoD Remix looks at them.
