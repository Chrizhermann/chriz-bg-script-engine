# MIND-01: Wit and difficulty

How clever each creature fights: what it foresees, how it takes danger and pain, and how the
difficulty shifts that. Direction agreed with Christopher on 2026-10-23 ("Ansich ist die Richtung
aber mega … so machen wir es"); the details below marked *proposed* wait for his OK. Profiles
live in `combat-intent/mind.lua` ("Gruppen und einzelne Kreaturen müssen verschiedene
Intelligenzen haben", 2026-10-18).

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
