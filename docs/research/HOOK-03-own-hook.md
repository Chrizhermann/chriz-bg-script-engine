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
casts from a spellbook, none prepares, none coordinates. What is not a plain attack or walk is story bookkeeping.

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
  nothing (learned.md section 6). The lab's fault, not the build's; the tour runs again with a sturdier PC.
- Not shown here: a creature's fight against a real party, and how the monsters' choices read to a player.

## Limits

- The engine attacks what it perceives. A hostile creature whose script waited for a story condition before it
  attacked no longer waits (xvarts went for the cow first). Designed exceptions go into encounter orders.
- A duty waits until the engine's running action ends, a round at most; the game would have run it at once.
- Family by class says nothing about the spellbook: a mage-class creature without spells is driven as a mage and
  falls back to its weapon.
- SCS's pursuit helpers above combat scripts (`DW#C3AS1`, `DW#C3AS2`, `BANDIT`, `DW#C3HST`; BOSS-02) hold no
  attack and get no hook; their walks at unseen party members still run. Their own guard is separate work.
- Siege of Dragonspear's fights now run on the engine too, before Christopher's SoD Remix looks at them.
