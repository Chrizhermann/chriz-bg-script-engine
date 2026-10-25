# ACT-05 — Casts whose target leaves sight

Status: lab probe on 2026-10-26, 26 phases in one launch, none failed. Result: the game already
does what Christopher wished for, for both sides; no EEex change is needed. On the side it
measured a speed point of casting time as 10 ticks; the engine, which assumed 9, now uses 10.

## Question

Reported in September: casts aimed at a character, such as Davaeorn's suspected Fireball,
usually don't go off once that character runs around a corner. Christopher's wish (2026-10-25,
plan "Christopher's ideas"): only invisibility or leaving the room or area may break a cast; a
target that only walks farther away or around a corner should not, for Magic Missile as for Hold
Person. One rule for both sides; where the game is stricter, the engine changes it through EEex
for both sides alike. He believed the whole group's sight counts for either side.

So: what does the game do when a cast's target leaves the caster's sight, for an enemy casting
at the party and for a party mage casting at an enemy, with and without another member of the
caster's side still seeing the target?

## Setup

- **Stack:** the SR lab (BG2:EE 2.7.3.0, EET 14.0, EEex 1.2.0, SCS 35.21, Spell Revisions
  4.21-chriz.5). Nothing of ours was installed: QA files, the remote console and four probe
  creatures were staged, and removed afterwards with every changed file checked by hash. One
  quiet hidden launch in a parallel lab slot.
- **Spells** (Spell Revisions' files, credit Demivrgvs and Gibberlings Three): Magic Missile
  (`SPWI112`, range 30, speed 1, five missiles from this caster) and Vitriolic Sphere (`SPWI426`,
  range 20, speed 4, cast at a creature). By the cautious 16 pixels a range unit that is 480 and
  320 pixels.
- **Creatures:** the caster is a copy of `MAGE18C`, the targets copies of `REFIGH01` with 250 hit
  points and magic resistance 0 (opcode 166, mode 1); scripts and dialogue cleared. **e** phases:
  a hostile caster casts at the protagonist. **p** phases: a neutral caster joins the party with
  `JoinParty()` (party place 1) and casts at a hostile fighter. Each cast is an ordinary
  `SpellRES` at `EEex_Target("BGSE")`.
- **Casting time:** Magic Missile casters were slowed with opcode 189 (−5, so speed 6: 61 ticks)
  to leave time for the change; the "fast" phases repeat the main cases unslowed (11 ticks).
- **Rooms:** BD0072 (open) for distance; the quiet BG2602 for the wall, where the target goes
  behind a light-blocking block of the search map (value 0; cells 16–20 by 22–25, about x 256–335
  and y 264–311).
- **The change:** two ticks after the copy is spent (casting has begun), the target jumps
  (`JumpToPoint`) or walks (`MoveToPoint`) to its new place, or turns invisible (opcode 20). In
  the "approach" phases the caster starts out of range and the change comes once it has walked 30
  pixels.
- **Read every tick:** the caster's action, ready copies and cast counter; positions and hit
  points; the game's own `See()` from the caster's and an onlooker's view (through
  `EEex_Trigger_ParseConditionalString` and `EEex_Trigger_EvalScriptFileConditionalAsAIBase`); an
  area search with line of sight (448 pixels); every projectile in the area with its source and
  target.

## Results

### Casting has begun (copy spent)

Ticks are counted from the spend. Release is the first missile at the target, flight the time
from release to the hit. Both directions gave the same numbers, give or take a tick.

| Phase | Target after the change | Caster's sight | Release | Flight | Outcome |
|---|---|---|---|---|---|
| control | stays, 208 px | sees | 61 | 4 | hit |
| far | jumps to 468 px: beyond sight (448), within range (480) | lost (`See()` and search) | 61 | 10–11 | hit |
| farout | jumps to 708 px: beyond sight and range | lost | 61 | 16–17 | hit |
| farseen | as far, and a member of the caster's side sees it | caster lost, onlooker sees | 61 | 10 | hit, as far |
| outrange (Vitriolic Sphere) | jumps to 408 px: in sight, beyond range (320) | sees | 41 | 38–39 | hit |
| wall | jumps behind the block, 216 px | lost | 60 | 5 | hit |
| wallwalk | walks behind the block | lost on the way | 60 | 5 | hit |
| invis | turns invisible where it stands | lost (`See()`); the search still finds it | — | — | action ends the next tick, copy lost, no missile |
| controlfast, farfast, wallfast | as control, far and wall, unslowed | as above | 11 | 4, 10–11, 5 | hit |

- The caster never moved while casting, not even when the target left its range: the spell left
  from where it stood and flew the whole way.
- In the invisible case the cast counter ran on to about 99 and then read −1, as after a finished
  cast. The copy stayed spent and nothing was refunded.

### Still walking into range (nothing spent yet)

Vitriolic Sphere, caster 420 pixels from the target.

- **The target jumps 600 pixels farther, out of sight** (about 980 pixels away): the caster kept
  walking toward the target's true position, unseen for 72 (e) and 82 (p) ticks, saw it again,
  began casting 352 pixels from it and hit (copy spent at tick 117 and 132, release 41 ticks
  later, hit 33 ticks after that).
- **The target turns invisible:** the action ended the next tick and no copy was spent. The
  caster still finished its walk to where the target stood, 24 pixels from it, and stood there
  idle.

### Both directions

All 13 cases gave the same result for the enemy caster and for the party mage. Whether another
member of the caster's side saw the target made no difference: a cast that has begun needs no
sight at all, so neither side needs the group's sight for it.

The party mage got the game's party scripts on joining (`BDDEFAI`, `DPLAYER2`); they started no
action during the phases. The action log shows only `JoinParty` (19) and the cast (31) on it.

### Timing

- The copy is spent when casting begins, and the cast counter (`EEex_Sprite_GetCastTimer`) counts
  0, 1, 2… from there, on past the release to about 99, then reads −1.
- The casting action ended 10 ticks a speed point after the spend (10, 40 and 60 at speeds 1, 4
  and 6), and the missiles appeared the tick after. The casting glow is a projectile from the
  caster to itself, one tick after the spend.
- Magic Missile is five projectiles from the caster to the target, then a spell-hit projectile at
  the target. They flew 4 ticks over 208 pixels, 11 over 468 and 17 over 708.
- EEex's started-action listener fired when a cast that had to walk into range began its walk
  (tick 23), long before its casting (tick 117 and 132). The caster walked 8 pixels a tick.

## What it means

- **The game's rule already matches the wish.** Walking away, around a corner or out of range
  does not break a cast that has begun; invisibility does. Leaving the area was not part of this
  probe (ACT-03: after the player left and came back, a caster was idle with its copy spent).
- **No EEex change.** Nothing here is stricter than the wish, for either side.
- **The engine's own casts** behave like the game's: `prepare()` checks the target right before
  queueing (alive, not invisible unless the caster sees invisible creatures, no Sanctuary), and
  the hold of a running cast has no sight check. Only a long walk into range differs: if the hold
  runs out before the caster can cast, the engine decides again on what the creature perceives
  (its search walks to where the target was last seen, FIGHT-01 "Searching"), which is fairer
  than the game's walk to a position the caster cannot know.
- **Area spells.** The engine casts area spells that can go to a spot at a point
  (`SpellPointRES`, the point fixed when it decides). Spells that must be cast at a creature, such
  as Vitriolic Sphere, and area casts at a creature by SCS or by a player clicking an enemy follow
  the creature to wherever it stands at release. The plan's earlier premise that such a spell
  "breaks off if it leaves sight" is wrong: only invisibility breaks it.
- **Casting time.** The engine took a speed point as 9 ticks (a tenth of a 6-second round). It now
  uses the measured 10 (`speedTicks` in `adapters/eeex/choice.lua`, `speedSeconds` in the
  decision modules), so its holds, its round marker, its judgement of broken casts and the
  window in which an enemy's cast can be broken no longer end early.
- **The September report** (Davaeorn's Fireball not going off around a corner) is not explained
  by sight. Likely causes: invisibility, damage during casting (ACT-03, SUPPORT-01: damage broke
  every cast it hit), an `ActionOverride` that replaced the cast (ACT-04) or an area change.

## Limits

- One stack, one caster file, two spells, two rooms. Hold Person and other spells with a saving
  throw, priest spells, innate abilities and an area projectile thrown at a creature (Fireball)
  were not run; Vitriolic Sphere stood in for spells cast at a creature with an area burst.
- Every hit came after the target had stopped. Missiles chasing a target that is still moving
  were not tested.
- Invisibility only by opcode 20. Improved Invisibility, Shadow Door, Mislead, Sanctuary and a
  caster that sees invisible creatures were not tested.
- No player click was simulated: the party mage's cast was queued with `SpellRES` like a
  script's.
- Death of the target and area changes are in ACT-03, not here.

## Reproduction

Private, git-ignored tooling in `.work/stepS-lab/`: `stageS.py` (stage and fixtures),
`labS.lua` (the phases, run through the remote console), `driveS.py` (host driver),
`labrunS.py` (slot, launch, cleanup), `cleanupS.py` and `analyze_s.py` (`--brief` for one line a
phase, `<phase> --detail` for the timeline around the change). The traces (`phase-*.jsonl`) and
the fixtures derive from game files and stay private.
