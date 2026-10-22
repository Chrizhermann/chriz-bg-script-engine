# CHOICE-01 — The engine's own attack choice: the round, the value model and lab batch E

Date: 2026-10-18. This is step 3 of the plan, second slice, as agreed with Christopher
(answers in the plan, "Step 3, second slice").

SCS is by DavidW. Spell Revisions is by Demivrgvs and the Gibberlings Three. No game file is in
this repository.

## Question

Can the engine take a hooked mage's or priest's round itself, choose a good attack spell and
its target or aim point from what the creature has ready and perceives, cast it through the
ordinary engine actions, and leave every other round to SCS?

## What it does

### When the engine takes the round

Christopher chose B: the engine takes the whole round once SCS's `castspell` round timer has
run out and it has a good attack. The gate asks `adapters/eeex/choice.lua` each time a hooked
script reaches its hook. The engine declines, and SCS's own blocks run in the same script pass,
when:

- the choice is switched off (`[BGSE] Choice` in Baldur.lua, on unless 0) or an EEex function it
  needs is missing;
- the creature is not a mage or priest, or not on the evil side (EA 200 and up);
- SCS's round timer still runs, the creature's casting aura is busy, or it is already casting;
- something urgent comes first in SCS's own order: the caster is silenced, or a priest with
  healing ready is badly hurt (under half its hit points) or sees an ally that is (under three
  quarters);
- no attack is worth enough (the profile's minimum worth, 0.2 of an enemy).

### The cast

A chosen attack becomes the gate's response, in the engine's own action form:

```
SetGlobalTimer("castspell","LOCALS",ONE_ROUND)
SpellRES("<spell>",EEex_Target("BGSE"))      -- at a creature
SpellPointRES("<spell>",[x.y])               -- at a point
SpellRES("<spell>",Myself)                   -- an area around the caster
```

- The timer comes first, as in SCS's own cast blocks, so SCS's filler runs between casts.
- A creature target is named through EEex's `EEex_Target` object. It reads the caster's own
  table (`EEex_GetUDAux(caster).EEex_Target.BGSE`), so no other creature's choice can change it.
- Right before the response is queued, the target is checked again: alive, no sanctuary, seen
  (or the caster sees invisible). A target gone by then skips the act without an error or a
  backoff (`'skipped'`).
- While the queued cast has not started, the creature's next script passes hold for up to 45
  ticks, so SCS's blocks cannot replace it. A cast that has not started by then is given up.
- The cast keeps its casting time, spell slot and interruption: it is the creature's own action.

### The value model

Worth is counted in shares of an enemy taken out of the fight (`combat-intent/choice.lua`).

- **Damage:** the spell's damage by type, times what the enemy's resistance lets through, times
  what its magic resistance lets through, halved or lost on a save. As a share of the enemy's
  maximum hit points, no more than it has left. A likely kill adds the profile's kill bonus
  (0.5) times the kill chance. Damage on the group's focus counts 1.5 times (focus bonus 0.5,
  times the profile's coordination).
- **Disables:** a factor by kind (hold and stun 1, charm 1.2, sleep 0.8, or 0.48 if damage
  wakes the target, confusion 0.8, panic 0.7, and so on), times the duration (18 seconds count
  in full), times 0.5 plus half the enemy's health. Death, petrification and imprisonment count
  the enemy's health plus the kill bonus. Silence, feeblemind and spell-blocking disables are
  worth a fifth against creatures that do not cast. No disable on an enemy already disabled or
  reserved by another member's disable; none outside the spell's level limits.
- **Saves:** a d20 plus the effect's bonus against the enemy's best allowed save; unknown saves
  count as even odds.
- **Areas:** the worth on every enemy inside, no option if an ally (or the caster, for an area
  away from it) stands within the radius plus 32 pixels. Distances count heights 4/3. Point
  areas are tried on each enemy's spot and on the middle of the enemies around it.
- **Cost:** 0.03 of an enemy per spell level, times the profile's economy, so a small spell
  finishes a nearly dead enemy and strong spells wait for strong enemies.
- **Spell slots** (Christopher, 2026-10-21; built 2026-10-22): a slot costs less when the caster
  has more spells left than rounds it can expect to live. The level part of every spell's cost
  (attacks, touch spells, conjured weapons, defences, heals and cures, summons, removals) is
  multiplied by the rounds it lives over the copies it has ready of spells that do something in
  a fight, at most 1. The rounds come from the threat it sees now and what protects it now
  (DEFENCE-01's harm course; plain invisibility, which the next cast ends, counts spread over
  those rounds); the round it is in always counts. Eight spells and about a round to live: an
  eighth of the price. No one threatening it, or no more spells than rounds: the full price.
  Items, casting time and walking are no slots and cost in full. The lab log keeps the share
  with every choice and decline (`slots`). Not counted yet: more casts a round under Improved
  Alacrity or in its own Time Stop, and fights that end before the caster would fall.
- **Pick:** with probability `best` (0.6 by default) the best option, otherwise a uniform draw
  from the options within `band` (0.2) of it.
- **Memory:** a cast that ended with no effect on its target is a miss. A miss with no save and
  no magic resistance to blame means immunity: that spell is not cast at that creature again.
  Otherwise each miss halves the worth, and from three misses the option is dropped. The target
  was hit when it lost hit points, became disabled (for a disable) or carries an effect of the
  spell or of a spell or EFF file the spell delivers through (Spell Revisions' sub-spells, see
  below). A cast that ended before its casting time was interrupted and says nothing.

Every rule is a knob in a per-creature profile (`combat-intent/mind.lua`): coordination, best,
band, economy, memory, knowledge, minimum worth, focus and kill bonuses, and when to defer to
SCS. There is one default profile now; Christopher designs the profiles once the whole framework
stands.

### The director's picture

The engine's own casts enter the director's group picture like SCS's (focus, disable
reservations) but are never advised: the director reads the started action and records it as
`own`. Its plan (focus and reservations) feeds the choice.

## Engine facts the casts rely on

| Fact | Evidence |
|---|---|
| SCS's `castspell` timer holds the game tick it runs out at; `EEex_Sprite_GetLocalInt` reads it; game time counts 15 ticks a second. | Step-1 lab samples: SCS set it 90 ticks ahead each round (castspell − tick fell from 90 to 0). Probe E: the engine's queued response set it 90 ticks ahead too, so `ONE_ROUND` resolves in a queued response. |
| Two actions in one queued response run in order when separated by a line break. | Probe E: `SetGlobalTimer` (action 115), then `Spell`/`SpellPoint`, in the same tick. The space-separated form was never tested; the engine's response uses line breaks. |
| `SpellRES(...,EEex_Target("BGSE"))` starts at the creature stored in the caster's `EEex_Target` table. | Step-3 probes (stored with `setStoredScriptingTarget`, the same table) and probe E: the started action named the stored creature, and the spell was spent. |
| `SpellPointRES("…",[x.y])` starts at exactly that point and spends the spell. | Probe E (Glitterdust at 352.330): action 95 with destination (352,330); ready count 1 → 0. |
| An area's radius (PRO area size) is in pixels; heights count 4/3. | Probe E, Glitterdust at a point and Vitriolic Sphere at a creature, both radius 110: hit at 0, 54/60 and 80 pixels, missed at 144 pixels across and at 96/102 pixels up (128/136 counted 4/3). Unscaled heights would have hit those. |
| Spell range: a range-20 spell was cast from 352 pixels. | Probe E: the caster stood 368 pixels away, walked 16 pixels and cast from 352. So range 20 reaches between 352 and 368 pixels centre to centre; the choice's 16 pixels per unit (320) is cautious, not wrong. One data point; whether the engine adds the creatures' size is open. |
| Spell Revisions' sub-spell effects name the sub-spell as their source. | Probe E: Glitterdust's effects on the dummies carried `SPWI224E` (54, 101, 142, 146, 174, 206, 328), never `SPWI224`. The outcome check therefore accepts every spell and EFF file a spell delivers through (the classifier's `sources`). |

## Lab batch E

One hidden, muted session in the disposable SR lab on Insane, in parallel lab slot 1
(`bg_lab_slots.py`), with the component installed for the session and removed afterwards; the
cleanup found all 5,393 scripts and every changed file restored. Each fight starts from the
same save in the quiet room BG2602: four lab dummies that do not fight back (250 hit points,
one 266) against four SCS casters, either the level-18 group (MAGE18B, MAGE18C, two PRIES18A)
or a mid-level group (MAGE8A, MAGE12A, PRIES10A, PRIES12A). Three modes rotate within each
round: **scs** (gate off), **dir** (the director advises SCS's casts) and **own** (the
engine's own choice). A fight ends when all dummies are dead or after 90 seconds (1,350
ticks). Four rounds gave 24 fights; the first mid own fight is void, because the lab script
removed the engine's decider at its start (found and fixed during the run; the later fights
ran with it).

| Group, mode | Fights | All dead | End (ticks) | Dummy time alive | Damage | Kills | Casts (engine) | Disables at dummies | Doubled |
|---|---|---|---|---|---|---|---|---|---|
| mid, scs | 4 | 0 | 1,350 | 4,673 | 753 | 1.75 | 59.2 (0) | 6.8 | 1.5 |
| mid, dir | 4 | 0 | 1,350 | 4,579 | 745 | 2.00 | 61.5 (0) | 4.2 | 0.2 |
| mid, own | 3 | 0 | 1,350 | 4,775 | 700 | 1.67 | 57.3 (3.7) | 6.0 | 1.7 |
| high, scs | 4 | 3 | 1,084 | 3,694 | 985 | 3.50 | 67.8 (0) | 0 | 0 |
| high, dir | 4 | 3 | 1,035 | 3,259 | 984 | 3.75 | 68.8 (0) | 0 | 0 |
| high, own | 4 | 4 | 1,140 | 3,521 | 1,016 | 4.00 | 75.8 (5.2) | 3.0 | 0.8 |

Means per fight. "Dummy time alive" adds each dummy's ticks until its death (or the end);
"doubled" counts a second disable on the same dummy by another caster within a round.

- **The engine's casts work.** In the seven valid own fights the engine claimed 35 rounds,
  queued 32 casts and all 32 started: no error, no cast lost, none interrupted. Of the seven
  single-target casts it could judge, six landed and one (Minor Lightning Bolt) left its
  target untouched. It cast Hold Person (12 times), Mental Domination (6), Telekinetic Storm
  (5), Symbol: Stun and Confusion (3 each), Minor Lightning Bolt (2) and Emotion:
  Hopelessness (1); the names are Spell Revisions' in this lab.
- **It took few rounds.** 3.7 casts in a mid fight and 5.2 in a high one, out of about 60 to
  75 casts by the group, most of them SCS's buffs and preparations. Batch E2 (below) traced
  why: mostly the casting aura (fixed after E2), then no usable option or none good enough.
- **No difference in the results.** With so few engine rounds the modes are within the spread
  of the fights (dummy time alive 2,895 to 5,130 within one mode).
- **Two engine priests held the same dummy** two ticks apart at a fight's start: the first
  one's Hold Person was chosen but not yet started, and reservations began only at a cast's
  start. Area disables also reserved only their main target, and one at a point none.
- **Three claims of one mage were not acted on** (MAGE18C, high own 1): its hook action stayed
  the current action for 41 ticks without acting. Batch E3 proved the cause: an ally's Time
  Stop (below).
- **Every level-18 fight had Time Stops** (two to four cast starts by the two mages), which
  this batch did not log. While one runs, every creature but its caster is frozen, and its
  script may queue a cast again each round without casting; those starts count as casts in
  this table. The high fights are therefore compared by outcome, not by cast counts.

## Lab batch E2: why the engine left the rounds to SCS

Same room, groups and lab slot, own mode only, four fights per group, after two changes:
disable claims start when the engine chooses and cover every enemy an area hits (commit
959813b), and labs can trace every decline with its reason (commit dfe78e0). Cleanup clean.

| Group | Fights | All dead | End | Dummy time alive | Damage | Kills | Casts (engine) | Disables | On disabled | Doubled |
|---|---|---|---|---|---|---|---|---|---|---|
| mid | 4 | 0 | 1,350 | 4,511 | 850 | 2.25 | 64.0 (2.5) | 5.0 | 0.8 | 0.2 |
| high | 4 | 4 | 1,035 | 3,551 | 1,016 | 4.00 | 70.8 (5.0) | 2.8 | 0.2 | 0 |

- **The engine's casts work.** 30 queued, 30 started, none lost, no error. It judged four
  single-target casts: one hit; Mental Domination missed the same dummy twice at a fight's
  start and Minor Lightning Bolt missed once.
- **Claims work.** No two engine members chose the same dummy. The one doubled disable and
  the disables on disabled dummies were SCS's.
- **Why SCS kept the round.** The trace names the engine's decline right before each SCS
  attack cast. In the mid fights, which have no Time Stop: the casting aura 31 times, no
  usable option 15, nothing good enough 9, urgent healing 1, no enemy seen 1. The high fights
  show the same order.
  - The aura check was wrong. SCS's timer counts 90 ticks from a cast's queueing, the aura
    about 100 from its start, so the aura nearly always outlasts the timer, and SCS's casts
    simply wait for it. Since commit 2262293 the engine takes the round once the timer has run
    out; its queued cast waits for the aura like SCS's, and its hold lasts until 45 ticks after
    the aura was last seen busy.
  - "No usable option" came when every dummy was disabled or claimed; SCS then often cast a
    disable on one of them anyway (mid own 1, t=12: PRIES10A's Hold Person right after
    MAGE8A's Confusion had claimed all four). Since commit b0a1329 the trace names why each
    spell and aim gave no option.
  - "Nothing good enough": single-target spells rarely reach the minimum worth (0.2 of an
    enemy) against 250-hit-point dummies.
- **Three more held hook actions**, now traced: MAGE18C in two high fights until exactly
  t=464, PRIES18A in one from t=679 to 923. Their scripts claimed every 16 ticks while the
  action did not run, and meanwhile only MAGE18B kept casting. E3 confirmed that these were
  MAGE18B's Time Stops.

## Changes found on the way

- **Sub-spell sources.** Before the probe proved it, the outcome check looked only for effects
  of the spell itself; most Spell Revisions spells would have counted as misses. Fixed (commit
  935dd52).
- **Cones.** Spell Revisions' Cone of Cold and Shout pause their caster for two seconds (opcode
  165 on the caster). The classifier counted that as self-harm, so the engine and the director
  left both spells out. A pause of the caster up to one round is now a casting cost
  (`pause`, in seconds); a longer one still counts as harm (commit a43a8c8).
- **Action form.** The response joins the timer and the cast with a line break, the form the
  lab had proven, instead of a space (commit 935dd52).

## Lab batch E3: the aura change in twelve own fights

Same room and groups, own mode, six fights per group, after commits 2262293 (the engine takes
the round once SCS's timer has run out, even while the casting aura runs) and b0a1329 (the
trace names why each spell and aim gave no option). The lab script also traced Time Stops
(`m_nTimeStop` and its caster). Cleanup clean.

| Group | Fights | All dead | End | Dummy time alive | Damage | Kills | Cast starts (outside Time Stops; engine) | Disables | On disabled | Doubled |
|---|---|---|---|---|---|---|---|---|---|---|
| mid | 6 | 0 | 1,350 | 4,865 | 741 | 2.17 | 64.2 (64.2; 3.5) | 5.8 | 1.0 | 0.7 |
| high | 6 | 4 | 1,155 | 3,073 | 956 | 3.50 | 72.3 (67.8; 9.8) | 4.2 | 0.2 | 0.2 |

"Outside Time Stops" leaves out the cast starts of creatures another creature's Time Stop
froze; they cast nothing until time resumed.

- **No aura declines any more.** The engine took about twice as many rounds in the high fights
  as in E2 (9.8 casts, 5.0 before). Its 80 casts: Hold Person 25, Telekinetic Storm 24, Mental
  Domination 9, Confusion 6, Minor Lightning Bolt 5, Emotion: Hopelessness 5, Magic Missile 2,
  Symbol: Stun 2, Unholy Blight 1, Shout 1. Every queued cast started; none had to be held,
  none was lost.
- **Time Stops explain the held hook actions.** Each high fight had one to three Time Stops of
  269 to 270 ticks, and the only hook action that stayed current lay inside one. The engine
  facts are in learned.md.
- **Two faults:**
  - Three Minor Lightning Bolts ended while MAGE18B's Time Stop froze their target and were
    judged misses at t=453, before their damage could land. Each false miss halves the bolt's
    worth on that dummy.
  - An engine Hold Person (an area) was aimed at a held dummy and caught the free one beside it
    (high own 2, t=216). Every aim that hit the same dummies counted as an option of its own,
    so such aims weighed more in the draw.
  - Both are fixed (below).
- **Why SCS still kept rounds.** The mid fights' declines: SCS's timer still running 696,
  no option 234, no enemy seen 88, urgent healing 73, nothing good enough 66. The high fights:
  timer 335, nothing good enough 80, no enemy seen 44, no option 9, urgent 9, already casting
  7. Right before a live SCS attack cast, the engine had found no option 59 times in the mid
  fights, nothing good enough 20 times. Why the mid spells gave no option: the creature filter
  711 times, no worth 552, an ally in the area 372, the caster in the area 11. The filter count
  led to the classifier fault below.
- **The engine pre-empts SCS's openers.** MAGE18B's script opens with Time Stop. The engine
  cast Telekinetic Storm at t=37 and 197, each time SCS's timer ran out, and the Time Stop came
  only at t=293 (active from 388 to 657). That is the agreed rule (the engine takes the round
  when it has a good attack), but it moves SCS's strongest non-attack spells later.
- The outcomes are within the spread of batches E and E2.

## Two fixes and batch E4

- **Outcomes after a Time Stop** (commit 0482ab4). A cast whose target another creature's Time
  Stop freezes when it ends is judged 30 ticks after time resumes, when what reached the target
  has taken effect. A target immune to Time Stop is judged as usual.
- **Equal aims** (commit ff57995). Aims of one spell that hit the same enemies are one option:
  the one centred on a creature the spell counts, then the one that holds its enemies furthest
  inside. The draw among near-best options then weighs each choice once.

Batch E4 ran the six level-18 fights again, own mode. Cleanup clean.

| Group | Fights | All dead | End | Dummy time alive | Damage | Kills | Cast starts (outside Time Stops; engine) | Disables | On disabled | Doubled |
|---|---|---|---|---|---|---|---|---|---|---|
| high | 6 | 4 | 1,148 | 2,893 | 998 | 3.67 | 73.3 (68.8; 10.2) | 3.7 | 0.2 | 0 |

- 61 engine casts, all started, none held or lost, one interrupted: Telekinetic Storm 24, Hold
  Person 13, Mental Domination 8, Unholy Blight 6, Minor Lightning Bolt 5, Poison 3, Symbol:
  Stun 2.
- Eight casts were judged: five hits and three misses, all Mental Domination between t=103 and
  295, none during a Time Stop. One judgement waited for a Time Stop to end.
- The one disable at a disabled dummy was SCS's (Flesh to Stone at a held dummy, high own 4,
  t=503).

## Creature conditions

The filter count in E3 came from a classifier fault, found with a host check of the mid
casters' spells against the lab dummies.

- **The fault.** The classifier made every IDS entry of a 177 or 283 a filter on the whole
  spell, and all filters had to hold at once. In this lab that locked out:
  - every spell that carries one of SCS's troll extras (a 177 for race 129 delivering
    DWTROLFI, DWTROLAC or DWTROLCO, in 191 of the lab's spell files) for every creature but
    trolls: Fireball, Melf's Acid Arrow and more;
  - Spell Revisions' Charm Person, which charms through two 177s, one for each side of EA 200,
    so it needed both sides at once;
  - Dire Charm and the charm sub-spell DVHCHRM, whose 177s for elves and half-elves deliver
    immunities;
  - Horror, whose 177 for the undead delivers a protection from the spell, so it worked only
    on the undead.
- **The fix** (commit 5eccc76). Conditions belong to what they deliver.
  - The classifier logs each contribution with the conditions on its path, and `spells.view`
    replays the log for one creature.
  - A conditional immunity to an opcode, or a protection from the spell or a spell it comes
    through, cuts what follows for creatures that meet it, by its chance: an elf keeps out nine
    of Dire Charm's charms in ten, a half-elf three.
  - A hold's creature type is a condition of the hold.
  - A delivery's saving throw goes to what it brings when that has none. Charm Person's saves
    sit on its 177s, not on the charm (in its last ability −5 against the evil side, −9
    against the rest).
  - The choice judges filters and worth on each creature's own roles, and a disable's worth
    counts the effect's own chance. A spell's kind comes from what it does to a creature none
    of its conditions single out, so the troll extra no longer makes a fire spell a disable.
    The director's redirect needs the same conditions met by the new target as by the
    original.
- **Effect on the labs' spells** (host comparison at caster level 12, mage and priest spells).
  With Spell Revisions, 42 damage and 26 disable spells newly work on a human, and three
  disables (Horror among them) no longer on the undead. Without Spell Revisions, 31 damage and 8
  disable spells newly work.

## Batch E5: E3's fights after the condition fix

Batch E5 ran E3's twelve fights again (six per group, own mode) after commit 5eccc76. Cleanup
clean.

| Group | Fights | All dead | End | Dummy time alive | Damage | Kills | Cast starts (outside Time Stops; engine) | Disables | On disabled | Doubled |
|---|---|---|---|---|---|---|---|---|---|---|
| mid | 6 | 0 | 1,350 | 5,000 | 586 | 1.00 | 60.7 (60.7; 4.8) | 7.5 | 1.8 | 0.8 |
| high | 6 | 4 | 1,210 | 3,056 | 932 | 3.33 | 74.7 (67.2; 11.3) | 3.5 | 0 | 0 |

- **The filter declines are gone.** Why the mid spells gave no option: no worth 250, every
  enemy in reach already disabled 71, an ally in the area 47. In E3: the filter 711, no worth
  552, an ally in the area 372. The engine cast 29 times in the mid fights (E3 21) and 68
  times in the high fights (E3 59).
- **Spells that were locked out now come.** The engine's 97 casts: Telekinetic Storm 23, Hold
  Person 22, Flame Strike 12, Mental Domination 8, Charm Person 7, Confusion 6, Dire Charm 4,
  Melf's Acid Arrow 3, Minor Lightning Bolt 3, Sleep 2, Poison 2, Unholy Blight 1, Emotion:
  Hopelessness 1, Horror 1, Symbol: Stun 1, Shout 1. Flame Strike, Melf's Acid Arrow, Sleep,
  Charm Person, Dire Charm and Horror were locked out before the fix.
- Every queued cast started; none was held or lost, three were interrupted, no errors. 19
  casts were judged: Mental Domination 5 hits and 3 misses, Charm Person 5 and 2, Dire Charm 4
  and 0.
- **No engine disable at a disabled dummy.** The engine's casts at held or panicking dummies
  were all damage spells (Flame Strike, Melf's Acid Arrow, Minor Lightning Bolt, Poison), as
  the rules want. The disables at disabled dummies (1.8 per mid fight) were all SCS's, most of
  them Dire Charm at confused dummies.
- **Charms keep the dummies alive.** The mid fights did less damage than in E3 (586 against
  741) and killed fewer dummies (1.00 against 2.17). The engine's charms explain it: a charmed
  dummy changes sides, and no one attacks it while the charm lasts. Dummies were charmed in 34%
  of the samples, 14% in E3. Against creatures that fight back, a charmed enemy fights for the
  casters; dummies cannot show that. How much a charm is worth against damage is part of the
  value model, which Christopher designs.

## Spells' own immunity checks

- **What they are.** Most Spell Revisions spells begin with an opcode 324 that names the spell
  and a SPLPROT row (row in parameter 2, value in parameter 1): a creature that meets the row
  is immune to the spell. Row 110 tests a spell state: 41 for Charm Person, Dire Charm and
  Mental Domination, 29 for Hold Person, 106 for Horror. SR's Fireball checks row 186 (fire
  resistance 100 to 127) in its sub-spell, which names the parent. Opcode 326 applies a spell
  only to creatures that meet its row. Of the lab's attack spells, 111 of 182 with Spell
  Revisions carry such checks, 43 of 150 without.
- **The classifier** turns them into creature conditions. A 318 or 324 with a row other than 0
  that names the spell, or a spell it comes through, cuts what follows for creatures that meet
  the row. What a 326 applies depends on its row; EEex swaps the two creatures with special
  bit 0. Row 0 without a creature condition stays SCS's and SR's guard against stacking.
- **The engine answers each row.** Rows test stats, spell states, IDS values, two creatures'
  relation and combinations of rows, so the engine's own check evaluates them:
  `CRuleTables::IsProtectedFromSpell(row, stats, mine, value)`, as EEex's Lua bindings expose
  it. The engine's opcode 326 passes the receiving creature as stats and the effect's source
  as mine. The adapter does the same for each enemy the caster sees and each row of the spells
  in question: the caster's ready spells for its own choice, the cast's spell for a redirect.
- **Without an answer** a row stays unknown. The choice still counts the spell (the check's cut
  is not applied); the director does not redirect, because it cannot tell whether the new
  target meets the check as the original does. The first failure is recorded as an error row,
  the rest are counted.
- **Knowledge.** This reads only what the spell itself tests, which a caster's memory of
  failed casts would learn too. Whether every row is plausible knowledge belongs to the later
  knowledge refinement.

## Batches E6 and E7: the checks in game

Each batch first probed the engine's check on two dummies, then ran E5's twelve fights. In the
fights, two dummies got a spell state that Spell Revisions spells check: B3DUMF Free Action
(29, Hold Person) and B3DUMT Chaotic Commands (41, Charm Person, Dire Charm, Mental
Domination). In E6 the states did not take: opcode 328 was applied with special 0. E7 set them
with special 1, as Spell Revisions does. Cleanup was clean both times.

- **The engine's check answers.** Called with each dummy and the probe caster, it answered 0 or
  1 as the creatures' values say: EA, general, race, current hit points and, in E7, the spell
  state. SOURCE held only with the same creature on both sides; ALLIES and ENEMIES were judged
  from the second creature's side.
- **No failures.** The adapters read 3,685 marks in E6 and 3,950 in E7, and no check failed.
- **The checks steer the engine.** In E7 the engine cast Hold Person 18 times, none at the Free
  Action dummy; in E6, without the state, 6 of its 9 went there. It cast charms 28 times, none
  at the Chaotic Commands dummy. SCS still aimed two Hold Persons at the Free Action dummy.
- **A director fault.** The director left both of those holds on the immune dummy. Another
  member's hold had reserved it, and the director found no alternative: its legality wanted the
  new target to meet the spell's conditions exactly as the original did, and a free dummy the
  hold works on met them differently. Fixed: a new target must take no less damage and no lower
  disable chance than the original, by each creature's own view of the conditions. A cast now
  moves away from a creature immune to it, and a fire bolt with a troll extra stays on trolls.

## Limits and next steps

- **One kind per spell.** A spell that damages and disables counts as a disable only. Debuffs
  (slow, blindness) and dispels are no attacks yet; they come with later slices.
- **Area casts teach nothing.** Only single-target casts are judged.
- **Dummies.** All fights so far are against dummies that do not fight back. Single-target
  spells rarely reach the minimum worth (0.2 of an enemy) against their 250 hit points.
- **Answered by Christopher (2026-10-18):** without an attack option the round stays SCS's,
  as now. SCS's opener first and redirects away from immune enemies would be SCS fallbacks;
  they are not built, because the engine's own openers and defences come next and replace
  them (plan, "Step 3, second slice: result"). The minimum worth (0.2 of an enemy) stays for
  now.
- **Knowledge.** Creatures that another creature's Time Stop freezes still decide, with what
  happens meanwhile. A later knowledge refinement may limit that.
