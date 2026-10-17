# DIRECTOR-01 — The fight director's first slice: a shared focus, one disabler per target

Date: 2026-10-18. This is step 3 of the plan, first slice, as agreed with Christopher.

- First the technical base: the group picture from what members perceive, the decision
  framework, safe execution and abort, and logs.
- Then one small visible behaviour, shown in the lab: a shared focus target and no double
  disables for mages and priests.

SCS is by DavidW. Spell Revisions is by Demivrgvs and the Gibberlings Three. No game file is in
this repository.

## Question

Can the engine coordinate an SCS group's casters so that they work on one target and don't put
two disables on the same enemy? Every creature must keep its SCS spellbook, items and
personality, and the engine must stay within normal casting rules and fair play.

## What it is: an advisor on SCS's own casts

SCS keeps choosing every spell. The gate still has no decider, so each hooked script pass
declines and SCS's block runs as before. The director only looks at the target of a cast that
SCS has already chosen.

### Check-ins

Each time a hooked creature's script asks the gate, the gate's new `observe` callback hands the
creature to the director, at most every 15 ticks per creature.

The creature's frame (`adapters/eeex/sense.lua`) holds what it perceives right now: itself, and
the living creatures it sees.

- **Standing creatures** are found with EEex's area search: sight range 448 and line of sight,
  the same way the `NumCreature()` trigger counts them.
- **Lying creatures.** That search walks only the area's front render list. Creatures lying
  down (asleep or unconscious) are in the back list, together with the dead. A living creature
  in the back list counts as seen when the same search, run from where it lies with the
  observer's terrain table, finds the observer.
- **Invisible creatures** are left out unless the observer sees invisible.
- **A blind creature** sees no one.
- **Sides** follow EA: evil (200 and up) against good (2 to 30). Only the evil side checks in
  for now.

### The director's picture

There is one director per area (`combat-intent/director.lua`). It keeps the group picture from
the frames:

- the members;
- the enemies they saw, with position, health, whether disabled, and what each is doing;
- a focus target;
- disable reservations.

It holds plain values only, and a load forgets it all.

What a member saw stays current for a round (90 ticks). Members check in only when their script
reaches its hook, and that pauses while they cast. In the lab the gaps were 48 to 128 ticks;
otherwise check-ins came every 16 ticks.

### Focus

- The focus stays while it is alive and seen within that round.
- Otherwise it goes to the enemy seen by the most members. Ties go to the most wounded, then
  the nearest on average, then the lowest id.
- When the focus lapses (unseen, or dead), the director logs that with the reason.

### Advice at the start of a member's cast

The director advises when a member's ordinary `Spell` action (ID 31) at a creature starts. The
hook is EEex's started-action listener. It runs right after the engine sets the action, the
same place where EEex's own SpellToPoint listener changes a starting cast.

- **Damage** (a single-target damage spell): redirect to the focus, unless any of these holds:
  - the cast is already on the focus;
  - the caster does not see the focus;
  - the original target is casting (interrupting it is worth more);
  - the original target is more wounded than the focus;
  - the focus is not a legal target for this spell.
- **Disable:** keep the cast on a free target. If the target is already disabled, or another
  member is disabling it, redirect to the focus, or else to the nearest free legal enemy. If
  there is none, keep the cast.
- **Reservations:** a started disable reserves its target for up to 15 seconds, and for two
  more seconds after its cast ends, so the effect can show before another disable is allowed.

### Casts at a kind of creature

SCS often casts at a kind of creature, for example `SpellRES("…",[PC.0.0.MAGE])`. Such a cast
has no target instance when it starts (`m_Instance` is -1). The engine decodes the object only
as the cast runs.

- The adapter decodes a copy of the object the same way (`EEex_Object_EvalAsAIBase`) to learn
  whom it names. From then on the cast counts like one at that creature: for the picture, for
  reservations and for advice.
- Another target must be of the same kind. It must have the named creature's value in every
  IDS field the object names (`targeting.sameKind`). This is stricter than the engine's own
  matching (MAGE_ALL accepts any mage), never looser.
- To redirect such a cast, the adapter sets the object to the new target's AI type
  (`m_acteeID:Set(target:virtual_GetAIType())`), as the engine fills in an object it has
  decoded.

### Legal targets

Legal means no worse than the original target (`combat-intent/targeting.lua`):

- alive;
- not under sanctuary;
- not invisible to the caster;
- within the farther of the spell's range and the original's distance;
- magic resistance no higher than the original's;
- the same values in every creature IDS file the spell filters on;
- no spell protection on the target that would stop this spell: immunity or bounce by opcode
  or projectile, globes and turning by level, school or secondary type, or protection from
  this very spell.

Anything the director cannot judge counts as protected.

### Which casts

Only casts at a creature that are:

- not partial;
- without friendly fire or self harm;
- with a known projectile;
- with no dispel, breach, heal, cure, raise or summon role on the target. Those casts pick their
  target for reasons the director does not judge.

### Execution

Before changing anything, the adapter:

1. reads the caster's frame afresh, with the enemies' IDS values and protections;
2. checks the new target once more: a living sprite the caster sees;
3. sets the starting action's target;
4. reads it back.

The cast keeps its casting time, spell slot and interruption: it is the creature's own action.

### Fail soft

- The kill switch and the family switches (mage, priest) stop all advice.
- Any error inside the director leaves the cast as SCS chose it. Errors are counted, and the
  last one is kept with its place (`observe`, `started`, `decode`) for `BGSE.inspect()`.
- A load invalidates everything.

### Logs

Each director keeps its last 256 rows: focus changes and losses, advice with its reason, and
cast starts and ends. Rows for casts at a kind of creature are marked `typed`. The director can
hand every row to a sink; the lab writes them to its trace. `inspect()` also lists the group's
picture of each enemy: when it was last seen, by how many members, and whether it was disabled.

## Host tests

All of these run on Lua 5.1 and LuaJIT:

- `tests/unit/combat_intent/test_targeting.lua` (5 groups);
- `test_director.lua` (8 groups);
- `tests/unit/kernel/test_eeex_director.lua` (7 groups, against fake EEex globals: frames with
  lying creatures, check-ins, redirects, switches, errors, loads, and casts at a kind of
  creature);
- the gate's observe callback in `test_hook.lua`;
- the installed runtime bundle in `tests/unit/test_runtime_bundle.py`.

## Lab batch (2026-10-18)

### Setup

- **Lab:** the SR lab (BG2:EE 2.7.3.0, EET, EEex 1.2.0, SCS 35.21, SR), on Insane with SCS's
  settings at their highest, in the quiet room BG2602.
- **Runs:** three hidden launches through the quiet runner. Each launch was followed by a full
  restore: all 5,393 scripts and the 40,774 override files unchanged, and the profile
  unchanged.
- **Targets:** four dummies on the party's side: fighter, thief, mage and cleric, about 250 hit
  points each.
- **Groups:** SCS's level-18 group (MAGE18B, MAGE18C, two PRIES18A) and a mid-level group
  (MAGE8A, MAGE12A, PRIES10A, PRIES12A), with the PC neutral and unkillable.
- **Fights** last 1,350 ticks (about 90 seconds). Director-off and director-on fights alternate.

### Redirect probes: all four pass

| Probe | Redirect | Target B HP | Target A HP | Memorized copy |
|---|---|---|---|---|
| Magic Missile at one creature | instance A→B | 266→248 | 250→250 | spent |
| Acid Arrow at one creature | instance A→B | 266→253 | 250→250 | spent |
| Magic Missile at `[PC.0.0.MAGE]` | -1 → B by `Set` | 266→249 | 250→250 | spent |
| Acid Arrow at `[PC.0.0.MAGE]` | -1 → B by `Set` | 266→257 | 250→250 | spent |

For the cast at a kind of creature, the decoded copy named the mage dummy A before the change
and B after it.

### Fights: the director worked without errors but rarely acted

**Level-18 group, 5 + 5 fights**

- No redirects and no errors.
- These casters prebuff with forced casts, cast self-buffs, and fight with area spells cast at
  creatures, which the director leaves alone. Of their Spell actions, 189 were on themselves,
  77 at dummies (mostly area spells), 30 at a kind of creature and 1 at the PC.
- Fights ended on average at tick 1,287 with the director off and 1,140 with it on. These
  samples read the front list only, so the end means "all down", not "all dead". With no
  redirect at all, the difference is SCS's own randomness.

**Mid-level group, 6 + 6 fights**

Casts at dummies over the 12 fights, area spells aimed at a creature included:

| | Director off | Director on |
|---|---|---|
| Disables aimed at one creature | 35 (9 at an already disabled target) | 35 (12) |
| Disables aimed at a kind of creature | 20 (2 at a disabled one) | 24 (6) |
| Damage aimed at one creature | 13 | 14 |
| Damage aimed at a kind of creature | 24 | 21 |

- **One redirect.** MAGE12A's Dire Charm went from a panicked fighter dummy to the free thief
  dummy, which was then charmed and attacked its side.
- **Why it kept the rest:**
  - Every cast at a kind of creature was "original unseen": not yet decoded at that point.
  - 11 of the 12 disables at an already disabled target were Dire Charm at a confused or
    panicked target, with no free alternative in sight.
  - The remaining keeps were area spells, and casts at targets the caster could not see.

### Diagnosis (launch C): what the search saw

- **Lying creatures.** Sleeping dummies lie in the area's back list with the dead. In one fight
  two dummies were asleep at full health from tick 45. The members' searches found none of the
  56 sleeping samples and none of the dead. Held and other helpless creatures stay in the front
  list and were found.

  This also explains launch B, where dummies left the front-list samples at full health at tick
  45 and came back later elsewhere: they slept, woke and moved.
- **Line of sight.** Healthy dummies were missed 21 to 29% of the time:
  - almost never below about 190 pixels, more often with distance, and always beyond 448;
  - concentrated on particular pairs, for example PRIES10A and the mage dummy 65 to 73 times
    per fight.

  That is line of sight in this room, which is fair play.
- **Check-ins.** 238 check-ins in a fight came from four members, exactly the director's count.
  They came every 16 ticks, with gaps of 48 to 128 ticks while casting. The focus lapsed in
  those gaps and was then picked afresh: up to three changes per fight, none logged as a loss
  at the time.

### Changed after the diagnosis (commit f9d6990)

- lying creatures are perceived;
- casts at a kind of creature are decoded, reserved, advised, and redirected only within their
  kind;
- the focus lasts a round, and a lost focus is logged.

Launch D checks this in game.

### Launch D: the fixes work in game

The mid-level group again, 5 + 5 fights, with every sample also recording the director's
picture. The lab was restored afterwards, as before.

- **Sleepers:** dummies were asleep in 164 samples. Each one was in the director's picture,
  seen within the round, and marked disabled. Before the fix: 0 of 56.
- **Casts at a kind of creature:** 41 were decoded, and 20 of them got advice. Of those, 2
  went to the focus, and 2 stayed because the focus was of another kind. "Original unseen" no
  longer came up at all; before, it was the reason for every such cast.
- **Focus:** one or two picks per fight. The first focus held for 475 to 1,081 ticks, and each
  loss was logged ("unseen"). Before, there were up to three silent changes per fight.
- **Errors:** none.
- **Redirects:** 5 in 5 fights (before: 1 in 11):
  - 4 damage casts went to the focus: two of them at a kind of creature, and two away from a
    sleeping dummy;
  - 1 disable went from a disabled target to a free one.
- **Disables at an already disabled target:**

  | | Director off | Director on |
  |---|---|---|
  | Wasted disables | 11 of 42 | 7 of 51 |
  | Doubled within a round, per fight | 0.8 | 0.6 |

  Every remaining waste had no free alternative in sight: Dire Charm or Charm Person on a
  confused or panicked target. That case belongs to the engine's own spell choice
  (Christopher's answer below).
- **Fight outcome:** no measurable change. Damage was the same (717 against 720 per fight). On
  average 2.6 dummies died with the director off and 2.0 with it on, and the one fight in
  which all four died had the director on. With 5 redirected casts out of 186 starts, that is
  SCS's randomness. The director changes too few casts to show in the result.

So the first slice does what was agreed: the group keeps a shared picture and a focus, and
coordinated casts go where they help. The bigger lever is the engine's own choices.

## Open for Christopher

1. Dire Charm (or another stronger disable) on a target that is already confused or panicked:
   waste, or an upgrade because the target then fights for the caster? (asked 2026-10-18)
   **Answer: waste**, though "sehr bescheuerte/unweise Magier könnten sowas eventuell machen".
   The director already treats such a target as disabled. With no free alternative the cast
   still goes ahead, since cancelling it would cost the creature its round under SCS's running
   round timer. The engine's own spell choice (the next step) will not pick it. Unwise
   casters belong to the personality layer.
2. Casts at a kind of creature now go only to another creature of the same kind. Should the
   director be allowed to pick any creature?
3. With no alternative, the director keeps SCS's cast. Should it instead cancel the cast, so
   that SCS chooses something else?
4. Most of SCS's damage comes from area spells. Should they be aimed at the focus, or at the
   biggest cluster without allies?
5. Next big step: the engine's own spell and target choice, with the director's plan in the
   scoring.
