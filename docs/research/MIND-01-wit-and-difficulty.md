# MIND-01: Wit and difficulty

How clever each creature fights: what it foresees, how it takes danger and pain, and how the
difficulty shifts that. Direction agreed with Christopher on 2026-10-23 ("Ansich ist die Richtung
aber mega … so machen wir es"), where the wit comes from on 2026-10-24, race groups on
2026-10-25; the zone part is built (below). Profiles live in `combat-intent/mind.lua` ("Gruppen und einzelne Kreaturen müssen
verschiedene Intelligenzen haben", 2026-10-18).

## Agreed (2026-10-23)

- **Two inputs from the creature, plus difficulty.** Intelligence and wisdom (Christopher: "ich
  würde aber noch Weißheit mit dazunehmen"), shifted by the game's difficulty: two points for each
  step above Normal/Core, minus two for each step below (Insane +4, Easiest −4).
- **Overrides.** A creature or group can be given its own wit ("Beispiel: Ein dummer und nicht
  weiser, aber sehr erfahrener, taktischer Krieger. Das können wir nicht so pauschal machen, aber
  wir könnten es mit einbauen"). No blanket rule such as a bonus for level; overrides are designed
  fight by fight.
- **Three steps for zones** (clouds, storms and the like):
  - *Dull:* sees no cloud coming and works nothing out ahead; pain drives it out (after each
    explosion that hurts it, a chance to leave that grows with the share of hit points lost);
    walks into a cloud after its target. Only for really dull creatures ("Das sollte aber nur für
    wirklich sehr dumme Kreaturen gelten. Manche sind auch pfiffig").
  - *Normal:* sees the cloud it stands in and leaves once staying costs more than it gains.
  - *Clever:* as the engine does now: works the explosions out ahead, learns how enemies behave in
    its own clouds, keeps out of clouds on its way.
- **Rage:** a berserk or enraged creature (as the game shows it) stays in a cloud and fights on
  until it falls below about half its hit points.
- **A line under it:** these steps, rage and the difficulty shift; no lists per creature. A fight
  that needs something special gets it in that fight's design.
- **Second step:** the same wit steers coordination and target choice ("ja"): dull creatures hit
  whoever stands before them, clever ones follow the group's focus. The profile has the knobs
  (`coordination`, `best`, `band`).

## What the creature files say (SR lab, 2026-10-23, host census, read only)

Of 8,910 hostile creature files:

- **Monsters carry template values.** 16/9 (INT/WIS) in 132 of 420 giant humanoids (80 ogres, 64
  trolls), 84 of 479 undead (42 ghouls), 84 of 785 monsters, 43 of 818 animals (29 bears, 14
  wolves); 9/9 in 709 of the animals and 71 golems. An INT of 16 does not make an ogre clever.
- **Humanoids mostly carry meant values:** of 6,362, only 44 have 16/9; 2,751 have 9/9, the rest
  spread from 6 to 18 (most 10 to 18). Important casters too can carry 9 in every stat
  (Dracandros, drow mages; plan, 2026-10-18).
- **SCS judges by kind, not by INT** (`sfo/filetype/lib_cre.tpa`, `CRE_check_if_moron`): zombies,
  gibberlings, golems, skeletons, animals and most monsters are unintelligent; humanoids, giant
  humanoids (ogres, trolls, ettins, giants), other undead, demons, dopplegangers, lycanthropes,
  beholders and dragons are not. Its unintelligent creatures get the `mo` genai scripts
  (`IsMoron`): they hit the nearest enemy and skip the smarter retargeting, but flee clouds like
  the others (the same twelve escape blocks per script).

## Where the wit comes from (agreed 2026-10-24)

Christopher: "Reihenfolge Override, Art des Monsters, gewollte Int- und Wisdom-Werte und
Schwierigkeit, das gefällt mir gut." Real INT and WIS for every creature would be better, but the
files often carry templates, so the kind does most of the work: a few categories first, oriented
on SCS, split finer later if worth it ("Wir können die ja immer kleiner machen später").

1. **Override** for the creature or its group, when one is set.
2. **Kind, as SCS judges it,** for the base step: SCS's unintelligent creatures dull, casters
   (mage and priest scripts) clever, everyone else normal.
3. **Meant INT and WIS shift it;** the template pairs 9/9 and 16/9 count as no information. INT
   moves the step (a meant INT of 5 or less is dull, 14 or more clever); WIS sets how seriously
   the creature takes danger and how fast pain drives it out (low: it shrugs a cloud off and stays
   longer; high: it leaves early).
4. **Difficulty** shifts INT as agreed.

Later, if worth the work: each monster's intelligence from the old AD&D books. The second
edition's monster entries give an intelligence class (from non-intelligent through animal, semi,
low, average and so on to godlike, each a range of scores) and a morale class, but no wisdom.
That needs a source we may use; only the classes would be taken, no text.

Examples: a wolf (animal) is dull: it foresees nothing but bolts once the fire bites; an ettin
(7/7) is normal but unwise, so it often stays in an Ice Storm to fight and leaves when it hurts;
a mind flayer (18) is clever.

## Built (2026-10-24)

The zone part: `combat-intent/mind.lua` (`M.wit`, `M.withWit`), `combat-intent/zones.lua`,
`combat-intent/choice.lua` and `adapters/eeex/choice.lua`.

- **The step.** An override for the creature file (labs: `api:setWitOverrides`, by resref with a
  `step` and optionally a `wis`) stands for INT 1, 10 or 15 (dull, normal, clever). Otherwise the
  file's own INT and WIS (STATS.IDS 38 and 39) count when they mean something: an INT above 0 and
  not one of the pairs 9/9 and 16/9. Otherwise the kind stands for its INT, with WIS 10: since
  2026-10-25 by race group (below); before, casters were clever, a few kinds of animals and
  constructs dull and everyone else normal.

  The difficulty (`m_nDifficultyLevel`, 1 to 5) then adds two to INT and WIS for each step above
  Normal and takes two for each step below. An INT of 5 or less makes the creature dull, 14 or
  more clever, anything between normal. Its danger weight is 1 + (WIS − 10) × 0.05, between 0.5
  and 1.5, and multiplies what leaving a zone and walking into one are worth.
- **Clever:** as the engine did before.
- **Normal:** counts a zone's explosions spread evenly over time instead of timing the next one.
  It weighs its own clouds by the cheaper of staying and walking out for each enemy, without what
  the group has seen enemies do.
- **Dull:** no option counts a zone. It casts and walks as if there were none and weighs its own
  clouds by one explosion; SCS's cloud blocks stand aside for it. Each time its hit points have
  dropped since it was last looked at while a zone hurts it where it stands, it draws once whether
  the pain drives it out: 2 × the share of hit points it has lost × its danger weight, at most 1
  (at half its hit points and WIS 10, for sure). Driven out, it walks out whatever else it could
  do and keeps leaving until no zone hurts it there; meanwhile SCS's escape may break a cast of
  its own.
- **Rage:** a creature that is berserk (STATE_BERSERK) or in one of the game's rage states
  (SPLSTATE.IDS BLOOD_RAGE, ANIMAL_RAGE, BARBARIAN_RAGE, BERSERKER_RAGE, MINSC_BERSERK and
  STATE_ENRAGED, which Barbarian Rage, the Berserker's Enrage and Minsc's Berserk all set as well)
  takes no way out while it has more than half its hit points.
- **Log and labs:** a `wit` row each time a creature's profile is made (step, danger weight, INT,
  WIS, where the step came from, difficulty), a `pain` row for each draw, and the step and a forced
  way out in choice rows. `api:setWit(false)` makes every creature clever, as before.
- **Only casters so far.** The engine decides only for mage and priest scripts, so the steps
  change casters only. Ettins, wolves and the like get them once the engine takes fighters' and
  monsters' rounds, at first around zones (to design with Christopher).

What it changes, counted over the SR lab's 8,909 hostile creature files with the CRE class
standing in for the script (read only, 2026-10-24):

| | Normal | Insane |
|---|---|---|
| Arcane casters (1,100) normal | 99 | 8 |
| Divine casters (546) normal / dull | 261 / 4 | 53 / 0 |
| Everyone else (7,263) dull / normal / clever | 1,046 / 5,277 / 940 | 998 / 414 / 5,851 |

Casters that are not clever mostly mean an INT of 9 to 13 (Anomen's files: 10/12); the four dull
ones mean 3 (`KIEL`, `KIEL2`, `D2KIE`, `DOPCLE01`). On Insane the normal kind's INT of 10 reaches
14, so every creature without meant values that is not dull turned clever there, ogres and trolls
(16/9) included. Christopher: "Sowas darf nicht klug sein. Da brauchen wir bessere Rechnungen."
The race groups below settle it.

## Race groups (agreed and built 2026-10-25)

Christopher: "Wir können gerne Rassengruppen erstmal machen. Wenn wir es hinterher komplizierter
brauchen, das können wir uns ja aufschreiben." So the kind is one of four groups, after the
intelligence classes of the old AD&D monster books, coarsened (only the idea of the classes, no
text). Each group stands for an INT where the creature's file means nothing; the dull and the low
group also cap what the difficulty adds (`combat-intent/mind.lua`, `M.GROUPS`):

| Group | INT | Easy / Normal / Insane | Who |
|---|---|---|---|
| dull | 1 | dull / dull / dull | animals, animated weapons, zombies, skeletons, golems, slimes, gibberlings, carrion crawlers, ankhegs, basilisks, mimics, chimeras, shriekers |
| low | 7 | dull / normal / normal | ogres, trolls, giants, ettins, minotaurs, gnolls, bugbears, lizardmen, ghouls, spiders, ettercaps, wyverns, umber hulks, otyughs, elementals, hook horrors, harpies, shambling mounds, yetis |
| average | 10 | normal / normal / clever | humans and the other peoples, orcs, goblins, kobolds, lycanthropes, dopplegangers, shadows, wraiths, spectres, imps, mephits and everyone not listed |
| high | 15 | normal / clever / clever | beholders, mind flayers, vampires, liches, dragons, demons, rakshasas, genies, githyanki, yuan-ti, salamanders, solars and planetars, will-o'-wisps |

- **Casters** (mage and priest scripts) think as the high group, whatever their race.
- **By name:** the class first, then the race, then the general, by the names the installed
  game's IDS files give them, so a race a mod adds counts by its name (the SR lab's `SUCCUBUS`).
  Skeleton warriors (class) are average, not mindless skeletons. Skeletons now count by race too:
  25 skeletons of other classes were normal before.
- **The top bounds only the difficulty.** A step the creature's own file (a meant INT) or an
  override gives stays: Olhydra (an elemental, INT 17) is clever, an ogre whose file means INT 10
  stays normal on Insane, beetles of INT 3 stay dull there. Lower settings lower everyone.
- **Log:** the `wit` row carries the group and the race name.

Counted over the SR lab's hostile creature files, non-casters by CRE class (read only):

| Non-casters | Easy d/n/c | Normal d/n/c | Insane d/n/c |
|---|---|---|---|
| dull (1,126) | 1,056 / 30 / 40 | 1,050 / 36 / 40 | 1,050 / 36 / 40 |
| low (585) | 502 / 70 / 13 | 3 / 565 / 17 | 1 / 567 / 17 |
| average (5,058) | 70 / 4,794 / 194 | 11 / 4,506 / 541 | 3 / 267 / 4,788 |
| high (494) | 8 / 275 / 211 | 8 / 73 / 413 | 0 / 25 / 469 |

The clever ones among the dull and low groups are clever by their files (golems whose files mean
INT 18, an ogre of INT 18, Olhydra). Of the casters (1,646), 1,282 are clever on Normal and
1,585 on Insane.

Written down for later (Christopher: "eventuell hinterher komplizierter/komplexer"): finer groups,
a range of INT per group instead of one value (the AD&D classes are ranges), or each monster's own
intelligence from the books.

## Tactics by wit (built 2026-10-25)

Christopher, on three new behaviours the same day: a thief's Detect Illusion only for "sehr schlaue
oder taktische Schurken … auf keinen Fall alle", giving up a search "sollte wieder schlau gemacht
werden", and walking into position during the casting cooldown "zwischen taktisch klugen Gegnern
und taktisch dummen Gegnern zu unterscheiden … um ein bisschen Varianz ins Spiel zu bringen". So
every tactic that needs some wit reads one knob, `mind.tactics`: how often the creature sees the
chance, 1 for a clever creature, 0.5 for a normal one and 0 for a dull one (`mind.TACTICS`, times
the profile's own `tactics`, so a lab can switch tactics off). A normal creature draws once a
decision, and only when there is a chance to see. The first tactic is interrupting a cast
([FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md), "Orders and interrupting").

## Guard rails (Christopher, 2026-10-23)

- **Decisions must stay understandable.** "Ich will halt auch nicht … dass wir … so ein komplexes
  System haben, dass die Entscheidungen hinterher gar keinen Sinn mehr geben."
- **Scary, not perfect.** On Insane a boss such as Irenicus should frighten players ("fast alleine,
  nur mit ein paar Begleitern, reißt er einen schon komplett auseinander, obwohl er nur ein Magier
  ist"), but not play frame-perfect: no certain wipe by Time Stop and Improved Alacrity with every
  prepared spell.
- **A mage has limited layers.** He must not die too fast either, for instance when his Time Stop
  is interrupted.
- **The engine comes first.** These ideas wait until the whole engine stands ("Erstmal muss
  natürlich die ganze Engine stehen").

First ideas to talk through then (not designed yet):

- Human reaction time: a short delay between noticing something and reacting to it, never in the
  same tick, longer for duller creatures.
- "Almost always the best" (the profile's `best` close to 1, never 1) for strategic minds; a combo
  such as Time Stop with Improved Alacrity as a climax a fight may build to, not a certainty.
- A plan B for a caster whose opener fails: renew layers, step back, use contingencies, rather than
  carry on as if it had worked.
