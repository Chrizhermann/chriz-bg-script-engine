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

The claim is cached per creature and game tick, so the copies and the hook ask once per
script pass and get the same answer. When the engine declines or is switched off, every
copy's first trigger fails and SCS's script runs in its original order.

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
