# HOOK-01 — Where the engine's hook sits in SCS scripts

Date: 2026-10-14. Step 1 of [the plan](../plans/2026-10-14-combat-intent-on-scs.md).
Stack: the SCS-reference lab (BG2:EE 2.7.3.0, EET 14, EEex 1.2.0 with LuaJIT, SCS 35.21,
Spell Revisions 4.21-chriz.5 and the rest of the CEBG collection), WeiDU 24900.
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
- **SCS removes fighters' potions on lower settings.** At the lab's difficulty the ranged
  fighter's script destroyed its 15 potions on the first pass (`removedpotions`, above the
  hook, so it ran while the engine held too). The first milestone's "fighters with potions"
  needs a setting where SCS keeps them.
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
  arguments. Not diagnosed.

## Limits

- One stack, with Spell Revisions. The rule matches SCS's generated structure, not spell
  content, but no install without SR has been checked yet.
- Specials ran in the lab only for the golem. Drake breath, elemental and hag powers and the
  target picks before specials are covered by the rule and the fixture tests, not by a fight.
- The engine only held or ran one test response; real engine decisions start in step 3.
- The PC was protected and alone; party fights come with the first-milestone scenario.
