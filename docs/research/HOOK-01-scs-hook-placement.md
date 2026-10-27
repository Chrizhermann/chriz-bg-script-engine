# HOOK-01 — Where the engine's hook sits in SCS scripts

Date: 2026-10-14. Step 1 of [the plan](../plans/2026-10-14-combat-intent-on-scs.md).
Stack: the SCS-reference lab (BG2:EE 2.7.3.0, EET 14, EEex 1.2.0 with LuaJIT, SCS 35.21,
Spell Revisions 4.21-chriz.5 and the rest of the CEBG collection), WeiDU 24900. A second,
install-only lab without Spell Revisions (plain BG2:EE 2.7.3.0, EEex 1.2.0, SCS 35.21) is
under "Without Spell Revisions".
SCS is by David Wallace (DavidW); Spell Revisions by Demivrgvs and the Gibberlings Three.
No SCS file or generated script is in this repository; the fixtures are synthetic.

## Question

Where must the engine's hook block go in SCS-generated mage, priest and general-AI scripts,
so that SCS's setup, bookkeeping, prebuffs and specials keep working, both when the engine
declines and when it takes the round?

## How SCS scripts are laid out

What the rule relies on, read from the 1,196 decompiled SCS scripts of the lab game:
- Blocks run top-down; the first firing block without `Continue()` ends the pass. Triggers
  short-circuit, which SCS's `See(X)` + `False()` target picks rely on.
- The preamble: setup (caster label, invisibility animation), rest and alert state,
  non-hostile guards, prebuffs (`ReallyForceSpellRES`, `RemoveSpell`, `Continue()`),
  contingency and chain contingency, first-round preparation (it sets `instantprep` to 1),
  cloud escape (`!GlobalTimerExpired("castspell","LOCALS")`), chasing.
- The per-round choice starts at the `castspell` stage: filler while the round timer runs
  (`GlobalTimerNotExpired("castspell","LOCALS")`), casts once it has run out
  (`!GlobalTimerNotExpired(...)`). Most cast blocks rely on the timer, not on
  `ActionListEmpty()`.
- Below that start, some scripts still carry bookkeeping (Melf's Minute Meteors, Energy
  Blades and Star Blades: item swaps and charge refreshes, all ending in `Continue()`) and
  abilities cast without a spellbook check (a `ForceSpell` family action with no `HaveSpell`,
  `HaveSpellRES`, `HasItem` or `KnowSpell` trigger), sometimes behind target picks.
- Mage, priest and general-AI scripts carry `DMWW_mage_`, `DMWW_priest_` and `DMWW_genai_`
  difficulty settings. 100 mage scripts carry Energy Blade bookkeeping: 40 above the
  per-round choice, 60 below it.

## The rule

`bgse/lib/hook.tpa` does this at install time; `tools/hook_rule.py` is the same rule in
Python, and `tests/integration/test_hook_installer.py` checks they agree.
1. A script is SCS's when it contains `castspell` and a `DMWW_` marker. The marker gives the
   family (mage, priest or fighter for the general AI). Nothing depends on script names or
   hashes.
2. The anchor is the first block whose triggers contain
   `GlobalTimerNotExpired("castspell","LOCALS")`, except first-round preparation (its
   response sets `instantprep` to 1) and the ranged general AI's retarget block (only
   variable and timer writes plus `ClearActions`).
3. The hook block goes directly before the anchor, with no `Continue()`. Its trigger asks
   `BGSE_Claim(object, family)`; its response calls `BGSE_Act(object)`.
4. Copied above the hook, in their original order, each with the same claim as its first
   trigger:
   - bookkeeping runs at or below the anchor: longest runs of blocks that perceive nothing,
     end every response in `Continue()` and only write variables, move items or self-apply a
     spell; a run is copied when it moves an item or self-applies a spell;
   - specials at or below the anchor: `ForceSpell` family casts with no spellbook or item
     check; when one aims at `LastSeenBy(Myself)`, the target picks right before it too.
5. The originals stay where they are. A script that is already hooked, has no round timer or
   has no anchor is left as it is, and the installer says so.
6. SCS's cloud blocks above the anchor get a last condition, `!EEex_LuaTrigger(...BGSE_Zones...)`:
   its escapes (the response sets the `seencloud` timer), and the blocks whose triggers hear a
   marker's shout (`Heard([ANYONE],404)` to `413`; `!Heard` hears none) and that only stand still
   (every response is `NoAction()` alone: the stand-still while it hears a cloud) or only run
   from the marker they heard (as many `RunAwayFrom…(LastHeardBy(Myself),…)` as responses and
   nothing else but `SetInterrupt`: the mages' run from a Cloudkill before they see the enemy,
   `mage/ssl/generalblocks/gohostile.ssl`). They run when the engine does not weigh danger zones
   for the creature now (SUPPORT-01, D3e); with no enemy in sight it weighs them only when it
   leads the creature out of a zone that hurts it. SCS's own triggers run first, as before, and
   the engine is asked only when SCS would act (EEex compiles each `EEex_LuaTrigger` anew). When
   the triggers end in an OR group that lacks members, the condition goes first instead, so it
   never joins that group. Cloud blocks below the anchor run only when the engine declines and
   stay as they are. Until 2026-10-22 the condition was
   `OR(2) !See(NearestEnemyOf(Myself)) !...BGSE_Zones...` and the stand-still had none, so with no
   enemy in sight SCS kept these rounds; until 2026-10-23 the run from a Cloudkill had none. In lab
   batches H7 and H8 that run kept mages out of the party's sight standing in an Incendiary Cloud
   for 34 to 38 seconds (SUPPORT-01). In the SR lab's 1,148 hooked scripts 11,496 blocks get the
   condition, all of it last: 9,957 escapes, 952 stand-stills and 587 runs from a marker (585 in
   mage scripts, 2 in monster scripts; host run of the rule, nothing installed).
7. SCS's hunt for enemies the creature no longer sees gets a last condition,
   `!EEex_LuaTrigger(...BGSE_Search...)`, above and below the anchor, and is never copied above
   the hook (2026-10-25, [FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md), "Searching"). Its
   blocks: those that use its chase variables (`chasetimer`, `chasing`, `chasePC`, `chasetarget`,
   `teleportpursuetimer`) and act, or end a response without `Continue()` (the chase's start, its
   walks with `MoveToObject` to the party member it noted, its give-up, a mage's Dimension Door and
   a fiend's teleport to that party member, the chase's end with `ClearActions`); its free
   detection casts on the `detect` timer; and its walk to the nearest closed door
   (`OpenDoor(NearestDoor)`). The chase's bookkeeping (which party member it noted, forgetting the
   dead, every response only setting variables or showing text and ending in `Continue()`) stays
   unguarded, so the record is there again when the engine is off.

   Since 2026-10-26 every other pursuit of a creature it does not perceive is part of the hunt
   too (`is_pursuit`): the triggers say it sees or detects no enemy (`!See` or `!Detect` of
   `NearestEnemyOf(Myself)` or of a whole class, `[PC]`, `[GOODCUTOFF]`, `[ENEMY]` or `[ANYONE]`)
   or not the one it acts on, and a response walks, jumps, casts, uses an item or attacks at a
   party member, the nearest enemy, the creature last seen or a class that no `See` or `Detect`
   trigger names. Not when a trigger says it must be on the party's side
   (`Allegiance(Myself,GOODCUTOFF)`: the Ascension followers' walk after the party). Its random
   walk while an unseen attacker puzzles it (`GlobalTimerNotExpired("whatthe","LOCALS")`, no enemy
   seen, `RandomWalk` or `RandomWalkContinuous`) is part of it as well: the engine's search answers
   such a hit with the attacker's spot as a clue. Comments go first (WeiDU writes some after an
   action). A not-seen class with qualifiers (`[PC.0.0.MAGE_ALL]`) does not mean no enemy.

   `BGSE_Search` is true for every creature the engine drives (its choice on for the family,
   the creature on the engine's side, not neutral or charmed): it searches itself, and SCS's
   give-up no longer ends `inafight` for it. That also keeps the behaviour the same whether or not
   the game counts a timer that was never set as run out (`GlobalTimerExpired`). In the SR lab's
   1,148 hooked scripts 16,294 blocks get the condition (2,663 above the anchor, 13,631 below).
   SCS's chase, detection and doors make 14,191 of them (1,632 above, 12,559 below): 6,906 chase
   walks, 1,159 chase starts, 4,051 give-ups, 806 ends of a chase, 706 free detection casts (all
   above), 205 door walks, 258 fiend teleports (42 scripts), 96 Dimension Door pursuits (8 scripts)
   and 4 other chase blocks. The chase's walks, start and give-up and the door walk sit below the
   anchor, except in 15 vampire and spider scripts (`C6VAMPIR`, `LASSAL`, `PPJOYE`, `PPVAMP`,
   `PPVAMPIR`, …); the free detection casts and nearly every end of a chase sit above it. The other
   pursuits make 2,103: 1,232 cloud escapes that walk at the party they do not see
   (`MoveToObject([PC])`, 87 scripts; the 688 above the anchor are cloud blocks too), 661 random
   walks on `whatthe` (657 scripts), 155 walks to the nearest enemy on an ally's shout 111 (only
   SCS's easiest settings), 36 walks to a party member not detected (16 dragons, Yaga-Shura,
   Illasera, two sahuagin scripts' `helptarget`, the Solar, Hama, a sirine), 9 mind flayer astral
   travels and 9 phase spider teleports to a party member (3 scripts each) and Melissan's teleport
   (`finmel`). Copies fell from 3,173 to 2,915 when the fiend teleports, copied as specials before,
   joined the hunt, and to 2,914 with Melissan's. When the triggers end in an OR group that lacks
   members, the condition goes first, as in rule 6; a block that is both gets both conditions, the
   cloud's first.
8. SCS's scripted teleports (2026-10-26, Christopher: a creature should teleport with a real
   ability whose name shows in the log, not jump silently). A scripted teleport is a `ForceSpell`
   family cast (`ReallyForceSpell` too, and the `Point` and `RES` forms) whose triggers check no
   spellbook or item (`HaveSpell`, `HaveSpellRES`, `HasItem`, `KnowSpell`), of a spell that moves
   its caster: an ability effect with opcode 124 or 274 aimed at the caster (target 1). The
   installer reads that from the game's spell files (`bgse_moves_caster`, SPELL.IDS names
   included); `tools/hook_rule.py` takes the list of such spells as a file.
   - A jump into the fight is a scripted teleport at a creature that a `See` or `Detect` trigger
     names (a party member, the nearest enemy, the creature last seen, or a class), unless a
     trigger says the creature must be on the party's side or the block is part of the hunt. It
     gets `!BGSE_Search` like the hunt and is never copied above the hook: the engine jumps with
     the creature's own teleport instead ([FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md)).
   - A hooked script with any scripted teleport teleports its creature by script. A creature
     whose script slots name such a script, and none of whose memorized spells moves its caster,
     gets the innate `BGSETELE` (known and memorized). A creature with a teleport of its own keeps
     it: most fiends have the game's Teleport Without Error (`SPIN159`), mind flayers Planar
     Travel (`SPIN186`).
   - `BGSETELE` takes the name and description of `SPIN159` when the game has it, else the
     English name Teleport Without Error. It is instant (speed 0) and otherwise built like
     `SPIN159` (range 200, casting glow, school), removes itself when used and comes back after 18
     seconds (opcodes 172 and 171), lights and glows where the creature lands, and sounds like
     Planar Travel (`EFF_M09`).

   In the SR lab's 1,148 hooked scripts there are 51 jumps in 50 scripts, all of them SCS's fiend
   jump (`fiend/ssl/jump.ssl`: `ForceSpell(LastSeenBy(Myself),…)` with `DW#FITEL`, SCS's copy of
   Teleport Without Error that no creature memorizes, below the anchor). Until now they ran as copied specials. Copies fall
   from 2,914 to 2,506, since the jumps' target picks are no longer copied either, and 16,345
   blocks get the search condition. 65 hooked scripts teleport by script. 123 creatures use them:
   110 have a teleport of their own (94 `SPIN159`, 15 mind flayers `SPIN186`, and the dryad
   `DRYADHA` six Dimension Doors), and 13 get
   `BGSETELE`: Melissan in the final fight (`FINMEL01`), the undead mind flayers (`MINDVA01`,
   `MINDVAM`, `UDVAMP`), four elementals (`UDELDA`, `UDELDE`, `UDELDF`, `ELEMIMIX`) and five
   demons (`DEMOGOR2`, `OHB5BHAL`, `DW#BFSUM`, `SUDEMON2`, `GORCHR`). Host run of the rule on the
   lab's files, nothing installed.

9. SCS's free invisibility (2026-10-27, Christopher: thieves hide with their own skill;
   [FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md), "F2f"). A block gives free invisibility when
   its triggers check no spellbook or item (`HaveSpell`, `HaveSpellRES`, `HasItem`, `KnowSpell`),
   each of its actions is bookkeeping (`SetGlobal`, `SetGlobalTimer`, `SetGlobalTimerRandom`,
   `IncrementGlobal`, `Continue`, `DisplayString`, `DisplayStringHead`) or a cast at the creature
   itself (`ApplySpell`, `ForceSpell`, `ReallyForceSpell`, `SpellNoDec` and their `RES` forms, at
   `Myself`), and one of those spells makes its target invisible: an ability effect with opcode 20
   at target 1 or 2, improved invisibility with parameter 2 at 1 (improved wins when a block gives
   both). The installer reads that from the game's spell files (`bgse_hides_target`, SPELL.IDS names
   included); `tools/hook_rule.py` takes the list of such spells as a file. Not SCS's contingencies
   and sequencers that fire an invisibility: their triggers check the `CONTINGENCY_TRIGGERED` spell
   state, and they are SCS's preparation, which stays SCS's (2026-10-28). Each such block, above
   or below the anchor and in its copy above the hook, gets the condition
   `!EEex_LuaTrigger(...BGSE_Hide(...,'plain')...)` or `'improved'`: last, or first when its
   triggers end in an OR group that lacks members (rule 6), and after the cloud's and the hunt's
   conditions. It stands aside while the engine hides the creature its own way (`api:hides`, for a
   creature the engine drives): a plain one when the creature can hide by its skill (a thief with a
   Hide in Shadows skill) or has an innate invisibility it may veil itself with (a plain one, or an
   improved one that comes back within a minute: a gift of rule 10 or its own, such as the mind
   flayers' Psionic Superior Invisibility); an improved one when it has an improved innate
   invisibility. One it used counts while it comes back (FIGHT-01, "F2f-5"). A creature with thief levels whose script slots name
   a script with such a block, and that no PDIALOG row names (no joinable NPC), gets thief skills for
   its level (FIGHT-01, "F2f").

   In the SR lab's 1,148 hooked scripts 124 blocks in 36 scripts give free invisibility (69 plain,
   55 improved; 22 general AI and 14 monster scripts): 114 above the anchor, 10 below it, all of
   those copied, so 134 conditions in all. Before contingencies were left out (2026-10-27) there
   were 158 blocks in 70 scripts: the 34 left out are all mage contingencies. The lab's 12 spells
   that make their target invisible: plain `DW#SILIN` (SCS's thieves and fiends), `DW#VMHID`,
   `DW#VMMIS` (vampires) and `WIZARD_INVISIBILITY`; improved `DW#ILLIN` (mind flayers), `DW#MISLD`,
   `DWSW405`, `DWSW505`, `BALTH10`, `ILLAINV`, `SHADOW_DRAGON_SHADOWS` and
   `WIZARD_IMPROVED_INVISIBILITY`. Without Spell Revisions (823 hooked scripts, 10 such spells: no
   `BALTH10` and `ILLAINV`) 63 blocks in 29 scripts (56 plain, 7 improved), 59 above the anchor and
   4 copied; 36 contingencies left out.
10. Real abilities for SCS's free invisibility (2026-10-27, Christopher: such powers become real
    innate abilities, as often as SCS gives them; FIGHT-01, "F2f-5"). Each spell a rule-9 block casts
    or applies at the creature becomes an innate ability of its own, a gift. An invisibility that is
    no innate ability becomes the game's own spell of its kind: Invisibility (`SPWI206`) or Improved
    Invisibility (`SPWI405`); anything else stays itself (Maurezhi's Blur). How often comes from the
    block (`frequency`, `bgse_frequency`):
    - a counter it raises by one (`GlobalLT` and `IncrementGlobal` by 1): that many charges
      (Illasera's 5 Ethereal);
    - a variable it checks for 0 (`Global(…,0)` or `!GlobalGT(…,0)`) and sets above 0: one charge
      (the sirine's);
    - else its own timer, checked as run out (`!GlobalTimerNotExpired` or `GlobalTimerExpired`, not the
      round timer `castspell`) and set again: back after that many seconds, a number or a name of
      the game's GTIMES.IDS, at most 1295 (Maurezhi's 1000);
    - else back after a round, 6 seconds (SCS gives it whenever it fits: the fiends').

    A creature whose script slots name scripts with gifts gets each once (`creature_gifts`,
    `bgse_grant_gifts`), but no plain invisibility when it has thief levels (it hides by its skill),
    no invisibility of a kind it has a memorized innate ability of its own for (mind flayers keep
    Psionic Superior Invisibility, Erinyes their Invisibility), and nothing as a joinable NPC. A gift
    is the spell itself when it is an innate ability with charges, else its innate copy, named
    `BG`, the spell's tag (`W`, `P`, `N` or `C` and the number of an `SPWI`, `SPPR`, `SPIN` or `SPCL`
    spell, else the first four characters of its resref) and the recharge in seconds as two base-36
    digits (`00` for none): `BGW20606` is Invisibility back after a round, `BGW405RS` Improved
    Invisibility back after 1000 seconds. The creature knows it and has it memorized as an innate
    ability, once or as many times as it has charges. A copy (`bgse_create_gift`) is the spell made an
    innate ability of the first level on the innate bar, `SPWI405` cast at speed 2 at most
    (2026-10-27), its references to itself renamed to the copy; with a recharge it removes itself when
    used and comes back after it (172, and 171 delayed), and a removal and return of its own give way
    to those. A gift is left out when the game lacks its spell, when another mod's file already has
    its copy's name, or when another spell's copy took that name first.

    In the SR lab 33 creatures get gifts (host run of the rule on the lab's files): 16 get
    Invisibility back after a round (`BGW20606`: Pit Fiends, Bone Fiends, Maurezhi, Ka'rashur, two
    fighters and a drow under SCS's assassin and stalker scripts, Tellan), the three Maurezhi also
    Improved Invisibility and Blur back after 1000 seconds, three vampiric illithids Improved
    Invisibility back after a round (`BGW40506`), two shadow dragons their Create Shadows back after a
    round (`BGN68706`), Illasera her Ethereal 5 times, eight sirines Invisibility once (`BGW20600`),
    the brown dragon and Draconis Invisibility (`BGW20600`) and Non-Detection (`BGW31000`) 6 times
    each.
11. SCS's preparation (2026-10-28, Christopher: the engine rebuilds how SCS prepares, first just as
    SCS does; [FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md), "Prebuffs, phase 1"). A block above
    the anchor is SCS's preparation when each of its actions is bookkeeping (`SetGlobal`,
    `SetGlobalTimer`, `SetGlobalTimerRandom`, `IncrementGlobal`, `Continue`, `DisplayString`,
    `DisplayStringHead`) or a cast of its kind, with one cast at least (`prep_kind`,
    `bgse_prep_block`):
    - first-round cast (opener): `Spell`, `SpellRES`, `ForceSpell` or `ForceSpellRES` at the creature
      itself, in a block that sets `instantprep` to 1;
    - chain contingency: casts at once (`ReallyForceSpell`, `ReallyForceSpellRES`) at the creature or
      `[PC]`, setting `ChainContingencyFired` to 1;
    - contingency: casts at once at the creature, setting `ContingencyFired` to 1 (either name in any
      case);
    - prebuff: casts at once at the creature while a trigger of its own (not one of an OR group) says
      `instantprep` is still 0.

    The three that cast at once may also take the spell from the spellbook (`RemoveSpell`,
    `RemoveSpellRES`). Each such block gets the condition
    `!EEex_LuaTrigger(...BGSE_Prep(...,'kind','cast','spent')...)`, last, after the other rules'
    conditions. cast is the first cast's spell, spent the first spell taken from the spellbook, both
    as written, or '' when there is none or the name is unsafe in Lua text (only letters, digits,
    `_`, `#` and `-`, at most 64 characters; SCS left some names unfilled, such as
    `%WIZARD_SPELL_DEFLECTION_PREBUFF%`). Each response of a prebuff, contingency or chain that casts
    tells the engine what ran with `EEex_LuaAction(...BGSE_Prepped(...)...)`, its last action before a
    closing `Continue()`, which stays last so the next block still runs in the same pass. The engine
    holds a block back (the condition fails) only for a creature it drives: its openers, since it
    chooses the first round itself, and what the creature's orders hold back (`prep = false`,
    `prepSkip`); everything else runs as SCS has it (`combat-intent/prep.lua`, `api:holdsPrep`).
    Preparation below the anchor would stay SCS's, as it runs only when the engine declines; neither
    lab has any.

    An opener the engine holds still ends SCS's preparation (`opener_twin`, `bgse_opener_twin`):
    right after it comes its twin, with the same triggers and the question asked the other way round,
    so it fires exactly when the engine holds the opener. Of each response it keeps only what the
    opener sets of SCS's state, its variables and timers (`instantprep` 1 and SCS's `redefend`
    timer), not the round timer `castspell` (the engine's own action sets it), the cast or SCS's count
    of level-9 spells, and it ends with `Continue()`, so the engine takes that round in the same pass.
    Without the twin SCS's preparation could stay open: SCS's own blocks that set `instantprep` when no
    opener fires leave out some of its settings (in 564 of the SR lab's 859 scripts with prebuffs or
    openers some combination of settings and slider sets it nowhere, for example SCS's mage setting fixed at
    BASIC, 1, with its preparation setting following the slider, 0, from the slider's third step up;
    410 of 601 without Spell Revisions), and SCS's free prebuffs have no check of their own against
    firing again, so a free Stoneskin would come back on every script pass.

    In the SR lab 860 of the 1,148 hooked scripts have 6,173 such blocks: 5,100 prebuffs (3,718 mage,
    1,382 priest), 239 contingencies and 245 chains (all mage) and 589 openers (588 mage, 1 monster),
    with 5,584 notices and 589 twins. 45 casts name a spell SCS left unfilled (42 prebuffs, 3 chains).
    4,408 prebuffs spend the memorized spell they check for; the other 692 take none (mostly free
    Stoneskin, `DWSW408`, 467, on SCS's harder preparation settings, also high-level abilities) and
    have no check of their own against firing again. All 589 openers have one response: the round
    timer, the cast (461 `Spell`, 128 `ForceSpellRES`), `instantprep` 1 and the `redefend` timer, 34
    also a count of level-9 spells; `redefend` is read only below the anchor. All 204 blocks that check the
    `CONTINGENCY_TRIGGERED` state are contingencies by this rule. Without Spell Revisions 602 of the
    823 hooked scripts have 5,054 (4,073 prebuffs, 226 contingencies, 229 chains, 526 openers; 4,528
    notices, 526 twins). SCS's area prebuffs, Haste (`DWSW305`) and Improved Haste (`DWSW613`), keep their area
    projectile (158, `INAREAPA`), so they already reach allies nearby; a lab check is planned.

`BGSE_Zones`, `BGSE_Search`, `BGSE_Hide` and `BGSE_Prep` go by the script that decides for the creature: the
first hooked script in its stack, since a lower script runs only after every higher one let the
pass through and a higher hooked script asks on the way. So in a creature with two hooked scripts (SCS's general
AI above a mage script, or a monster script above the general AI) the lower script's cloud and
hunting blocks stand aside exactly when the higher one's do (`kernel/hook.lua`, `driver`; since
2026-10-25, before which each script went by its own family).

`tools/hook_agree.py` checks that WeiDU and `tools/hook_rule.py` agree without a game: WeiDU runs
`bgse_hook_baf` on a folder of decompiled scripts with `--nogame`, and every result, count and text
must match. On the SR lab's 1,241 decompiled scripts (1,148 hooked) all agree byte for byte
(2026-10-25, 2 to 3 minutes; again on 2026-10-26 with the pursuit rule, 3.5 minutes, and with
the teleport rule, given the lab's 48 names of spells that move their caster as a fourth argument:
51 jumps, 65 scripts that teleport by script; on 2026-10-27 with the free invisibility rule, given
the lab's 12 names of spells that make their target invisible, with their kind, as a fifth: 158
blocks in 70 scripts; and on the no-SR lab's 878 decompiled scripts, 99 blocks in 65 scripts). On
2026-10-28 with the gifts, given the names of those spells whose files say innate as a sixth and the
game's GTIMES.IDS as a seventh argument, both labs agree again, gifts included (5.5 minutes for the
SR lab: 124 blocks in 36 scripts; no-SR lab 63 blocks in 29 scripts). With the preparation rule
(rule 11, 2026-10-28) both labs agree again: 6,173 preparation blocks in the SR lab, 5,054 without
Spell Revisions.

The claim is cached per creature and game tick, so the copies and the hook ask once per
script pass and get the same answer. When the engine declines or is switched off, every
copy's first trigger fails and SCS's script runs in its original order; a switched-off engine
also lets every cloud escape and SCS's whole hunt run.

## Install results in the lab game

- 1,028 scripts hooked: 585 mage, 307 priest, 136 general AI. 799 copied blocks (mage 426,
  priest 265, general AI 108). Two scripts without a round timer left alone (`sahamb02`,
  `sahamb05`). 166 SCS monster-only scripts are not part of step 1.
- Most scripts get no copies (mage 511, priest 240, general AI 121). Typical counts: 6 for a
  mage whose Melf or Energy Blade bookkeeping sits below the anchor, 4 for a priest with Star
  and Energy Blade bookkeeping, 1–4 for golems and drakes, up to 21 for the hag in `yagaft`.
- WeiDU's output matches the Python rule block for block on all 1,028; every other script
  keeps its bytes. The install takes about 4 minutes. Decompiling and recompiling all SCS
  scripts takes about 2 of those and on its own changes no byte.
- Install, reinstall and uninstall are exact in the fixture test. In the lab, the uninstall
  gave back all 1,028 scripts byte for byte.

## Without Spell Revisions (install only)

Second lab, same day: a new copy of unmodded BG2:EE 2.7.3.0 (the same executable as the first
lab) with EEex 1.2.0 (core and main components) and SCS 35.21 from the same release, with the
SCS components of the CEBG game that apply to BG2:EE on its own. No EET, Spell Revisions,
Ascension or other mod; SCS skipped its four Ascension-only components (Illasera, Gromnir,
Yaga-Shura, Abazigal). Scripts decompiled from PowerShell with WeiDU pointing at the lab. No
game launch.
- 838 scripts carry `castspell` (SR lab: 1,196). 718 hooked: 416 mage, 192 priest, 110
  general AI, with 764 copied blocks (mage 415: 351 bookkeeping, 50 specials, 14 target picks;
  priest 245: 244 bookkeeping, 1 special; general AI 104 specials). Most scripts get none (mage
  344, priest 130, general AI 98). The same two scripts left alone (`sahamb02`, `sahamb05`, no
  round timer). 118 monster-only scripts not hooked (SR lab: 166).
- WeiDU's output matches the Python rule block for block on all 718 scripts (248,281 blocks),
  with the same families and copy counts; only `M_BGSE.lua` is added. The install took
  2.5 minutes, the uninstall 4 seconds, and afterwards all 8,488 files in `override` and the
  game folder were byte-identical to before; `WeiDU.log` was put back from its copy.

Compared with the SR lab:
- SCS numbers its generated mage and priest scripts per install, so `dw#mg…` and `dw#pr…`
  names don't match between the two games; they were compared by structure. The 115 hooked
  scripts with fixed names in both games have the same anchor block and the same copies, apart
  from string numbers. One differs in content: `elemimix` copies the same blocks, but SCS writes
  vanilla Spell Immunity checks into them without SR and Shield of the Archons checks with SR.
- Bookkeeping copies use the same SCS helper items and variables in both games (Melf's Minute
  Meteors, Energy Blades, Star Blades): 64 mage and 61 priest scripts here, 65 and 66 there.
- Everything else below the hook that differs between the games is a cast behind a spellbook
  check (sequencers and triggers behind `HaveSpellRES`, no-decrement casts behind
  `HaveSpell`); neither game copies those, by design.
- New here: SCS's stone golem script (`golsto01`, 3 copies: Slow on the three nearest
  enemies, like the other golems' powers; in the SR game another mod's stone golem script
  replaces SCS's) and two general-AI scripts without copies (`dw3mc2ba`, `dw3mm2as`).
- **Melissan.** Without Ascension, SCS's Throne of Bhaal villain component scripts the
  original Melissan (`meliss01`–`03`). Her scripts carry SCS's general-AI settings, so they are
  hooked (8, 9 and 23 copies under the step-1 rule; for the current rule see the re-check
  below). With Ascension (the SR lab) her script is `finmel`, which has
  no family marker and stays with the monster-only scripts. Her own powers come first and
  check the round timer, so the anchor is the first of them and the hook sits above them all.
  Copied (`ForceSpellRES` and `ReallyForceSpellRES`): Taint of the Slayer, Blade Barrier,
  Bone Blades, a whirlwind attack and SCS's fiend teleport. Not copied, so they stop while the
  engine holds her: killing an undead (`ActionOverride` … `Kill`), summoning minions
  (`CreateCreatureObjectEffect`) and her spell list: 105 blocks across the three scripts that
  cast with `SpellNoDec` or `SpellNoDecRES` and no spellbook check (26 spells, among them her
  heal, Time Stop, Power Word Kill, Dragon's Breath and the Symbols). These are not memorized
  spells, so the engine would not offer them either.
- The same kind of gap in the SR lab: one self-heal (`SpellNoDec`, Cure Critical Wounds, no
  spellbook check) below the hook in Ascension's Illasera (`illasera`). A census of both games
  found no other hooked script with such a block left below the hook (summons,
  `ActionOverride`, `SpellNoDec` without a spellbook check, shape changes, cutscenes, global
  plot variables).

So the rule does not depend on Spell Revisions. It does depend on what counts as a special:
`ForceSpell`-family casts without a spellbook check are copied; `SpellNoDec` casts without one,
summons and `ActionOverride` commands are not. That only matters for scripted bosses (Melissan
without Ascension, one Illasera block with it). Copying those too, or leaving such bosses to
the monster-script pass, is Christopher's call.
Since then, the monster hook copies summons and other blocks beyond a combat round
([HOOK-02](HOOK-02-monster-scripts-and-script-slots.md)), and Christopher agreed to copy the
`SpellNoDec` casts as well (answer 10): a `SpellNoDec` or `SpellNoDecRES` cast without a
spellbook check now counts as a special, unless the block also removes the spell.

Re-checked in the same lab with that rule (`a4958c5`), install only:
- 823 scripts hooked: 416 mage, 192 priest, 110 general AI and 105 monster. Left alone:
  `sahamb02`, `sahamb05` and SCS's vampire minion script `dw#vmmin` (no round timer). 12
  scripts with `castspell` carry no SCS difficulty setting.
- Copies: 2,178 with the monster hook alone, 2,672 with answer 10 (mage 415 and priest 245
  as before, general AI 110 → 335, monster 1,408 → 1,677). The 494 new copies are 200
  `SpellNoDec` casts without a spellbook check and 294 target picks, in 31 scripts: Melissan's
  three (105 casts, 120 picks) and 28 monster scripts (95 casts, 174 picks: fiends such as
  Demogorgon, balors, glabrezus, succubi, alu-fiends and mariliths, the brown and shadow
  dragons, Tahazzar and others). Run on the SR lab's 1,196 scripts, the same counting gives
  that lab's 1,148 hooked scripts and 2,666 → 3,003 copies.
- WeiDU hooked the same 823 scripts with the same families and copy counts and left the same
  three alone. Its output decompiles to exactly the Python rule's text on all 823 (274,478
  blocks), and `M_BGSEHK.lua` lists exactly these scripts with their families. Only
  `M_BGSE.lua` and `M_BGSEHK.lua` were added; no other file changed. The install took about
  3 minutes, the uninstall 2 seconds. Afterwards all 8,488 files were byte-identical to
  before, after `WeiDU.log` was put back from its copy (the uninstall had added its
  `// Recently Uninstalled` line).
- **Melissan:** `meliss01`–`03` now carry 70, 81 and 120 copies (step-1 rule: 8, 9 and 23;
  monster hook alone: 10, 11 and 25). All 105 `SpellNoDec` blocks are copied, with the target
  picks before them. Killing an undead (`ActionOverride` … `Kill`) and summoning minions
  (`CreateCreatureObjectEffect`) stay copied, as blocks beyond a combat round. Below the hook
  only her ordinary round is left: melee, moving to a target, `AttackReevaluate`, `NoAction`
  and variable resets.
- **Still below the hook:** powers a creature applies to itself with `ApplySpell` or
  `ApplySpellRES` and no spellbook check are not specials. 167 such blocks in 23 monster
  scripts here, 170 in 26 in the SR lab. In SCS's 12 vampire scripts (both labs) the rat-form
  cast (`dw#vmrat`, a copied special) sets `israt`; the steps after it are self-applies below
  the hook: turning invisible, and turning back into the natural form (`dw#vmnrt`) when the
  rat form runs out or a target is in reach. So a vampire that took rat form while the engine
  holds it stays a rat until the engine declines. The others are single buffs: fire shields in
  four genie scripts, stoneskin and protection from magic energy in four dragon scripts,
  stoneskin or invisibility in two fiend scripts (Tahazzar, Karash), the brown dragon's
  `runrun`, and with SR also Ascension's Abazigal and balor (stoneskin) and succubus (spell
  deflection). Christopher agreed to copy them (answer 11, below).

Since answer 11 (2026-10-15), a block whose response applies a spell to the creature itself
(`ApplySpellRES("…",Myself)` or `ApplySpell(Myself,…)`) and whose triggers check no spellbook
or item is a special too. On the decompiled scripts the rule adds exactly the blocks above:
167 in 23 monster scripts without SR (2,672 → 2,839 copies) and 170 in 26 with SR (3,003 →
3,173). Mage, priest and general-AI scripts get none: their self-applies sit above the
anchor, in bookkeeping runs or in casts checked against the spellbook. In the vampire
scripts the copies are the rat's whole cycle: turning invisible, turning back when the rat
form runs out, and the ambush that turns back and attacks a mage, thief or bard in reach.
Below the anchor, every block that applies a spell without a spellbook check is now copied
in both labs. A block that only applied a spell to another creature would stay the
engine's, but there is none. WeiDU, installing on copies of the SR lab's 1,196 SCS scripts,
hooked the same 1,148 with the same 3,173 copies; its output decompiles to exactly the
Python rule's text on all of them, and every other script kept its bytes.

## Lab fights

Quiet room BG2602, one baseline save, one PC kept alive (minimum 1 HP plus protection from
death effects). Six installed SCS creatures spawned around it: MAGE18B (`dw#mg256`, no
copies), MAGE18C (`dw#mg257`, 5 copies: blade bookkeeping), PRIES18A (`dw#pr183`, 4 copies:
blade bookkeeping), RETHUG01 (`dw2ms2ge`, melee), REFIGH01 (`dw2rp2ge`, ranged) and CLGOL01
(clay golem, general script `golcly01`, 1 copy: golem haste). The seven scripts these
creatures use matched the Python rule exactly in the installed lab. Each case ran 900 game ticks (60 s) from a fresh load;
the bookkeeping cases ran 600. Three cases shared one launch through the quiet runner, the
two bookkeeping attempts had one launch each, and a first launch stopped before any case
because the queued load fired before the start menu was up. Lab-only wrappers counted claims and hook actions per creature, an action-started
listener logged spells, attacks and item moves, and every creature was sampled each second.

| Case | Result |
|---|---|
| Engine present, declining (no decider) | SCS as usual: Stoneskin and Mind Blank prebuffs, MAGE18B's first-round sequencer, casts most rounds, golem haste every three rounds, fighters attacking.  Hooks asked 30–108 times per creature, all declined; 335 gate decisions, 149 same-pass repeats, 0 errors. |
| Engine holds every round | Prebuffs and the first-round sequencer above the hook still ran. Round casts and attacks stopped. The golem's copied haste still fired three times. A one-off test response on the priest ran (`BGSETEST` = 1). 640 claims: 636 held, 1 acted, 0 errors. |
| Switches | Held until tick 300; switching the fighter family off gave the two fighters and the golem back to SCS at once (29 attack actions after, none before); the global switch at tick 600 gave back the mages and the priest (casts resumed). 52 family-off and 88 disabled declines, 0 errors. |
| Bookkeeping | MAGE18C got the Energy Blades item directly (effect 122, no action queue). It was casting Time Stop from tick 99 to 460, so nothing reacted before the engine took over at tick 300. With the engine holding, the guarded copy above the hook ran twice (ticks 467 and 483): it destroyed the blade item, created SCS's helper item and set `eneblade` to 10 and the `melfinit` timer, the original block's actions. The original sits below the hook and is not reached while the engine holds. During the cast the script was still evaluated (54 claims) but only 9 hook responses ran, all after it. |
| Baldur.lua switch | `BGSE.setEnabled(false, true)` wrote `[BGSE] Enabled` 0, read back as the number 0; turning it on read back 1. |

**Timing.** With the hook declining, SCS's casters started their next cast 5–9 ticks
(0.3–0.6 s) after their round timer ran out whenever they had something to cast; longer gaps
were SCS's own waits, such as MAGE18C's 24-second Time Stop. A declined hook is a false
condition in the same script pass, so it cannot delay SCS by a tick. One check costs about
2.4 µs on host LuaJIT, including compiling the trigger text as EEex does on every call. No
run without the hook was timed, so the 5–9 ticks have no baseline yet.

The runtime registered its load listener at startup: EEex is initialised before the game
autoloads `M_` files.

## Found on the way

- **SCS mage invisibility animation.** The mage script's block that applies `dw#hdani` while
  the caster is invisible has no "already applied" check; the priest script has one. A mage
  held by the engine stayed invisible and re-applied it on every pass: 56 times in a minute,
  and its effect list grew from 123 to 467 entries. Not caused by the hook; the engine must
  not keep an invisible mage waiting.
- **A queued action is not a quick action.** An item creation queued on MAGE18C waited
  behind its 24-second Time Stop cast and was dropped when the next script response replaced
  the queue. Lab setup now applies such changes directly (effects, local variables).
- **Claims during a running cast.** A claimed hook does not cut into a cast SCS already
  started; its response runs when the cast ends, as ACT-04 found for legacy blocks. The gate's
  pending decision is refreshed by every claim, so the response that finally runs uses the
  latest one (no stale decisions in these runs).
- **INI values.** `Infinity_GetINIValue` returns numbers. `Infinity_SetINIValue` is read back
  at once, and the value was in the profile's `Baldur.lua` (as a string) after the game was
  stopped by force, so it is not written only at a clean exit.
- **SCS removes fighters' potions on lower settings.** The lab ran at difficulty 2 of 5
  (SCS's IMPROVED). There the ranged fighter's script destroyed its 15 potions on the first
  pass (`removedpotions`, done at BASIC and IMPROVED; above the hook, so it ran while the
  engine held too). Its Stoneskin and Mind Blank prebuffs need at least IMPROVED. Later lab
  fights run on Insane.
- **Lab start.** On the hidden desktop the startup movie runs about two minutes. The console
  answers meanwhile, but the queued load must wait until `START` is on the menu stack.
- **`WeiDU.log` after the uninstall.** WeiDU writes the whole log again on every install and
  uninstall. With `--quick-log` (used here) it dropped every component name, and the uninstall
  added a `// Recently Uninstalled` line, so the log failed its pre-install hash check although
  its entries were unchanged. No copy had been taken; the log was rebuilt from its entries and
  the source game's component names and matches the old hash again. Next time, copy the log
  before installing.
- **Other mods write at game start.** Every launch rewrote BuffBot's 51 `BFBT*.SPL` files
  (same bytes as before) and its three small `BFBOTBG*.MOS` files. They are not ours and stay.
- **Decompiling.** WeiDU `--game … --out` decompiles failed under Git Bash ("None of the
  dialog paths were a match against en_us") and worked from PowerShell with the same
  arguments. Not diagnosed. In the second lab, PowerShell decompiled all 838 scripts in about
  a minute, in chunks of 60.
- **Line ends.** This PC's system git config sets `core.autocrlf=true`, so a fresh checkout
  wrote `bgse/lua/M_BGSE.lua` with CRLF and the installer test's byte comparison with the
  build failed. `.gitattributes` now keeps that file LF; the second lab installed the
  committed bytes.

## Limits

- Two installs: the SR lab and plain BG2:EE with SCS but without SR, EET or Ascension
  (install only, no fight). Other SCS versions, other spell or overhaul mods and EET without
  SR are unchecked.
- Self-applied powers without a spellbook check are copied since answer 11 (see "Without
  Spell Revisions"), checked on the host (the rule over both labs' scripts, the installer on
  the SR lab's scripts and on synthetic ones) and in one lab fight: a mature vampire the
  engine held ran SCS's rat cycle three times in 60 seconds (step-2 batch, HOOK-02).
- Specials ran in the lab only for the golem. Drake breath, elemental and hag powers and the
  target picks before specials are covered by the rule and the fixture tests, not by a fight.
- The engine only held or ran one test response; real engine decisions start in step 3.
- The PC was protected and alone; party fights come with the first-milestone scenario.
