# FIGHT-01: Fighter and monster rounds

The engine takes the rounds of fighters and monsters as it takes the casters' (Christopher,
2026-10-25: "Ich mein das ist ja 1000% der Plan sowieso … Ich denke aber mal, das ist weniger
Arbeit als Magier und so"). SCS's fight logic stays the blueprint: every creature keeps its SCS
identity (items, potions, kit abilities, innate powers), and worth on the attack's scale decides,
as for casters ([CHOICE-01](CHOICE-01-engine-own-attack-choice.md),
[DEFENCE-01](DEFENCE-01-openers-and-defences.md)). Credit for the blueprint: SCS by DavidW.

## SCS's blueprint

The hook sits before a script's first block that tests SCS's round timer
([HOOK-01](HOOK-01-scs-hook-placement.md)). In SCS's melee general AI (read in `DW1MELAS`, one of
the compiled `genai` scripts; decompiled read only) that is the first potion block.

**Above the hook** (stays SCS's): battle cries and turning hostile, thief detection, the backstab
plan's setup, resting, noting the first party member it sees (the `chasetarget` and `chasePC`
records) and ending a chase once it sees an enemy, walking to the party when it hears a cloud's
shout and sees no one (archers run from the shout instead), and on lower settings destroying its
potions.

**Below the hook** (the engine's once it takes the round), in SCS's order:

- 54 potion blocks (`UseItem`): protection, buffs and healing;
- kit abilities (an assassin's poison, `Spell(Myself,ASSASSIN_POISON)`);
- the hunt for enemies it does not see: the walk to a closed door nearby, the chase's start, its
  give-up and `MoveToObject` to the party member it noted (it stands aside for the engine's search
  now, "Searching" below);
- the backstab: `Attack` while invisible, within range 4 or with the backstab plan;
- melee: `EquipMostDamagingMelee` and `AttackOneRound` within range 4, by the target's class
  (mage, mage-thief, thief, bard, cleric, anyone) and health (below 20 %, below 50 %, any);
- the chase: with `ActionListEmpty`, `MoveToObject` to a helpless or immobile enemy within 10, then
  by class and health at any distance;
- at last `AttackOneRound` at any player or the nearest enemy.

The ranged general AI (`DW1RANAS`) has the same potions, kit abilities and melee within range 4,
then kiting (`RunAwayFromNoLeaveArea` with `SetInterrupt(FALSE)`) and 34 blocks of `EquipRanged`
with `AttackReevaluate(target,30)`. SCS's monster scripts carry about 100 melee and movement blocks
each plus innate powers ([HOOK-02](HOOK-02-monster-scripts-and-script-slots.md)).

## Staging (agreed 2026-10-25)

- **F1:** melee fighters and monsters. Targets by worth, walking to them, potions and kit abilities
  through the buff valuation, monsters' innate spells.
- **F2, straight after:** archers (weapon switching and kiting), thieves (the invisibility and
  backstab plan), debuffs such as Aura of Despair, and on-hit enhancers (below).

Christopher: "Hauptsache, wir stoppen nicht wieder random davor und sagen, ah, lohnt sich jetzt
nicht … Also ich würde es schon ordentlich trennen." No release pressure; testing F1 and F2 in the
same lab is fine too.

## Built

### F1a: self-only heals and removals ride along (2026-10-25)

A heal or removal that reaches the user alone no longer makes a spell something other than a
defence (`combat-intent/defence.lua`, `M.defence`): Barbarian Rage and Potion of Haste and Potion of
Free Action take earlier copies or slowing effects off the user, Enrage heals it a little. One that
reaches others keeps the spell out (care and removal decide those).

### F1b: the own weapon counts for own buffs (2026-10-25)

A creature whose profile fights with its weapon (`mind.ownWeapon`: fighters and monsters through
`mind.FAMILIES`) counts a buff on itself by what it adds to its own swings: more attacks (haste,
opcode 1), to-hit (opcodes 278 and 54, THAC0 set or scaled), damage (opcode 73), damage of the
weapon's kind in per cent (opcode 332 by type) and critical hits (opcode 301), less what the spell
puts on the user (Whirlwind Attack's −4 to hit and damage). A swing deals its damage on a hit; a
critical roll (20 less the bonus, at least 1 in 20) always hits and doubles where no helmet stops
it (`defence.critOpen`, 0.5 while helmets are not read). A caster that casts does not count its
weapon.

The classifier read opcode 54 in its set and per-cent modes the wrong way round: Potion of Power
(THAC0 to 80 %) and Potion of Heroism (90 %) were penalties. Now they count as the better THAC0 they
give (`combat-intent/spells.lua`).

### F1c: protection and buff potions (2026-10-25)

The creature's carried items join its defences (`defence.options`), as healing potions joined care:
the first ability of each item that defends, while uses are left, drunk on the user itself. A drink
is not interrupted, costs as a first-level spell plus its own time (the ability's speed), and is
worth what the same spell cast on the user is worth, own weapon included. The adapter answers with
`UseItem` as for healing potions, and any drink of an item one of whose abilities defends, the
engine's or the script's, starts the pause before the next defence (SCS's redefend timer).

### F1d: walking to the enemy (2026-10-25)

- `mind.chase` (fighters and monsters): such a creature may attack any enemy it sees in melee. A
  caster goes no further than `touchReach` (10 range units), a webbed or entangled creature no
  further than a weapon reaches (`threat.reach`, 64).
- The walk comes first and lowers the worth (`weapons.walk`, `weapons.paced`): the seconds to come
  within a weapon's reach of the enemy, at the creature's own speed when known, else a fighter's
  100 a second; a round of hits after a walk of w seconds counts 6 / (6 + w) of its worth (half a
  round's walk leaves two thirds, a round's walk half). So near enemies come first unless a far one
  is clearly worth more: one the next hits kill, or the group's focus.
- Clouds on the way count by the creature's wit, as they did for melee options
  ([SUPPORT-01](SUPPORT-01-healing-curing-summons-removal-zones.md), D3e): a clever fighter gives up a
  wounded enemy behind a fire cloud, a dull one walks through.
- The response stays `AttackOneRound` at `EEex_Target`, which walks to its target first as the
  game's attack actions do; the engine decides again after the round. The choice row logs the walk
  (`walk`, seconds). A long walk is still to be seen in a lab.

### The engine owns the round (2026-10-25)

Built after the two engine-wide rules below (commit 11704bc; `combat-intent/choice.lua`,
`adapters/eeex/choice.lua`, `kernel/hook.lua`):

- **No round goes to SCS's blocks below the hook,** also not between two of the engine's own
  actions. The engine takes every round of a creature it drives and decides again as soon as an
  action is over, so a drink or another quick action does not take the round.
- **While the casting aura runs** (about 100 ticks from a cast's start), casts, drinks and openers
  wait for it; one chosen half a second or less before the aura frees is queued and starts when it
  frees. Meanwhile the creature attacks with its weapon when that is worth more than the part of
  the best cast it holds back, else it waits. Under Improved Alacrity the aura holds nothing back.
- **Waits:** with nothing worth doing, or while the aura runs, the creature waits: held, and decided
  again when the wait is over or 15 ticks after it began, whichever comes first; a new action ends
  it. While it waits the engine still leads it out of a cloud that hurts it. The log gets one `wait`
  row per new reason (`aura`, `no-option`, `nothing-good`). Fighters and monsters always attack when
  nothing else is worth more (`mind.alwaysAttack`; Agreed, point 4).
- **SCS's round timer** (`castspell`) is no part of the engine's responses any more. It stays the
  round's marker for SCS's own blocks above the hook (specials and other copies): when the hook's
  response runs, a decision's or a hold's, and the timer has run out, the engine sets it for a round
  (90 ticks), so those blocks get one pass a round, as in SCS's own order. A cast or drink of the
  engine's stretches it to cover its casting (a speed point is 10 ticks, measured in ACT-05; 9
  until 2026-10-26; plus 15) and any walk into range.
- **Left to the creature's script:** a cast the engine did not queue (a copy's special), which only
  that block may keep going, and the engine's own cast once it is held past its time (decline
  `casting`); no enemy in sight (`no-enemy`); the engine switched off, missing an EEex function or
  failing (fail-soft).

### Casts walk into range (R3, 2026-10-25)

With no round left to SCS, an enemy beyond a spell's range is no reason to wait (commit 1e33acc):

- `SpellRES` and `SpellPointRES` walk into range before they cast (batch G3 saw `SpellRES` do it),
  so the choice and the protection removal aim beyond the range too. The walk at the creature's
  pace (`weapons.approach`, 100 a second by default) comes first and lowers the worth as a walk to a
  melee enemy does (6 / (6 + seconds)); an area must keep the caster out where the walk ends, and a
  lasting cloud counts the walk into its casting delay.
- No walk for a cone (it starts where the caster stands), a release (`ForceSpellRES` casts where the
  caster stands, batch G3) or a caster that cannot walk (webbed or entangled): an enemy beyond their
  reach is out of reach, as before.
- The adapter holds a queued or started cast for the walk as well, twice the straight walk as paths
  bend, and the round's marker covers it. A cast's casting is counted from when its casting aura
  starts again, not from the action's start, so a cast broken off after a walk, or one that ended on
  the way, counts as interrupted and is never remembered as a miss on its target.
- Creatures see 448 around them (`sense.sightRange`), so a spell of range 28 or more (448 at 16 a
  range unit) reaches every enemy a creature sees, apart from some above or below it, as heights
  count 4/3 in range. Walks come mostly with shorter-range spells.

### Orders and interrupting (2026-10-25)

Built for Agreed point 1 (`combat-intent/orders.lua`, `combat-intent/choice.lua`,
`combat-intent/mind.lua`, `adapters/eeex/sense.lua`, `adapters/eeex/choice.lua`):

- **Orders.** A designer gives a creature orders by its creature file, through `options.orders`
  or `api:setOrders({MYBOSS={target='protagonist',always=true}})`. The target names the
  protagonist (`protagonist`, the game's Player1), a party place (`player1` to `player6`, by
  joining, as the game counts them) or a creature file, or a list of them, of which the first that
  names an enemy in sight counts. Preferred, what an attack does to that enemy counts its bonus
  more (1 by default: twice). With `always=true` every attack (spells, removals, touch charges,
  strikes, weapon attacks) stays on it while one of them reaches it; defences, heals, cures,
  summons and ways out of a zone stay free, and with the enemy out of sight or reach everything is
  open again. The choice row logs `ordered`. Other decisions get their orders as they are built.
- **Interrupting.** Damage that lands while an enemy casts breaks its spell, and the spell slot
  stays spent (ACT-03, batch H5). Each enemy in a cast that damage can break (Spell, SpellPoint
  and their NoDec forms; forced casts cannot be broken) carries its spell, read at the enemy's
  caster level, and the count of its casting aura. The casting runs from the aura's restart for
  its casting time (10 ticks, two thirds of a second, a speed point: ACT-05; 0.6 seconds until
  2026-10-26); a count past the casting time is the last cast's
  aura, which the cast waits for. Breaking the spell adds 0.1 of an enemy for each spell level
  (`mind.interrupt`), times the chance the attack's damage lands while the casting runs: a
  weapon's hits after the walk, less those Mirror Images and Stoneskin take first; a spell's damage
  after the creature's own casting aura, the walk and the casting, as likely as magic resistance
  and a save that keeps all of it off let it through; a touch charge's strike. Example: a fighter
  with two swings that hit 0.8 each, beside a mage one second into a three-second Cone of Cold,
  breaks it in 41 % of such rounds, and the fifth-level spell adds 0.2 to the attack. The creature
  may know the spell: SCS's scripts can learn it from the game's SpellCast triggers. The choice row
  logs `interrupt`.
- **Wit.** How often a creature sees the chance is `mind.tactics`: a clever creature always, a
  normal one in half its decisions (drawn once a decision, and only when an enemy casts), a dull
  one never. Every new tactic reads the same knob ([MIND-01](MIND-01-wit-and-difficulty.md)).

### Searching (2026-10-25)

Christopher on SCS's hunt: "Das können wir doch auch einbauen? Vielleicht sogar geiler als SCS?",
and "ok." to the proposal the same day. SCS is the blueprint (`genai/ssl/chase.ssl`,
`mage/ssl/generalblocks/chase.ssl` and `findhidden.ssl`, credit DavidW): its creatures note the
first party member they see; with no enemy in sight while their fight goes on, they walk for 8 to
15 seconds to where that party member really is (`MoveToObject` follows it, seen or not), mages
with Dimension Door teleport there, fighters open a closed door nearby, and mages and priests of
higher levels cast a free Oracle, Detect Invisibility or Invisibility Purge (`SpellNoDec`) when a
hidden party member is near (`Detect` without `See`, which only the game knows); then they give up.
The engine searches with what the creature and its group perceived instead
(`combat-intent/search.lua`, `adapters/eeex/search.lua`, `combat-intent/director.lua`'s clues,
`adapters/eeex/choice.lua`):

- **When.** With no enemy in sight the engine first leads the creature out of a zone that hurts it,
  then heals or cures a friend in sight that has lost hit points, is held or has a condition a cure
  takes away (worth decides, as in a fight), and otherwise searches.
- **Clues.** Where the group last saw each living enemy and which way it was going (the director
  works out a heading from two sightings at least 5 ticks apart); an enemy another member sees now
  (`sighted`); a hit from an attacker the creature does not see: its hit points dropped and the game
  names an enemy as the last to hit it (`m_lHitter`), and the clue is where that enemy stands
  (`hit`); an enemy lost from sight within two seconds on a spot the creature still sees, and for a
  walking enemy the spot it would have reached by now (`vanished`: likely invisible). The best clue
  is the strongest kind (sighted, hit, vanished, last seen), then the newest, then the nearest.
  Clues are kept 30 seconds, or longer while the creature's patience lasts.
- **The walk.** `MoveToPoint` to the open spot nearest the clue, held while the creature walks it
  (at most twice the straight walk plus 2 seconds) and ended at once when an enemy shows or the
  creature is hurt. A spot inside a danger zone counts as searched. On a searched spot the creature
  looks around for a second and takes the next clue.
- **Detection.** Only when a clue says the enemy is likely invisible near the creature: a hit from a
  spot it sees with no one there tells anyone; an enemy that vanished on such a spot, or that
  another member sees there, tells a creature that sees its tactics this search. The creature uses
  what it has, judged by what it does (so with or without Spell Revisions): a buff that lets it see
  the invisible (True Seeing, Detect Invisibility), an area that takes invisibility away around it
  (Invisibility Purge) or at a point it can reach (Glitterdust), and items that do the same, the
  lowest spell level first and at equal levels the lasting buff; not while it sees the invisible
  already, nor within 6 seconds of its last detection. A rogue with Detect Illusion of 30 or more
  switches to its Find Traps mode within 224 of the spot, and only when it sees its tactics ("auf
  keinen Fall alle"). The log judges each detection by whether the caster sees an enemy afterwards
  (`reveal` rows, `revealed` and `unrevealed` counts).
- **Patience** by wit: 30 seconds for a clever creature, 18 for a normal one, 8 for a dull one (SCS:
  8 to 15), counted from the newest clue, so a search goes on while clues keep coming. Halved for a
  creature below half its hit points and again for a coward (morale break 7 or more);
  `mind.searchPatience` stretches or shortens it for labs and fight designs.
- **Giving up** is not forgetting. The creature walks back to its post (where its fight began),
  where heals and cures go on as above, and its own script goes on; it stops trying when two walks
  back in a row bring it no nearer. A new clue (a hit, a member seeing the enemy again) starts the
  search again, and the next enemy in sight starts a full fight.
- **Guarding.** A group's boss (at least two other members, each at least two levels below it)
  guards its post: it searches only clues within 240 of it and otherwise goes back or looks
  around. Orders override it either way (`guard=true` or `guard=false`, `combat-intent/orders.lua`).
- **Tactics by wit** (`mind.tactics`, drawn once a search: clever always, normal in half its
  searches, dull never): leading a moving enemy along its last heading (up to 2 seconds, 150 at
  most), spreading out from members that search the same spot (80 apart), casters staying 120
  short of a spot a fighter of their group searches too, seeing that a vanished enemy turned
  invisible, and a rogue's Detect Illusion.
- **SCS's hunt stands aside** for every creature the engine drives ([HOOK-01](HOOK-01-scs-hook-placement.md),
  rule 7): its chase, its free detection casts and its walk to a door get a last condition,
  `BGSE_Search`, and are never copied above the hook (a fiend's teleport to the party member it
  noted was copied as a special before). Since 2026-10-26 so does every other pursuit of an enemy
  the creature does not perceive: a phase spider's or a mind flayer's teleport to a party member,
  Melissan's teleport, a dragon's walk to a party member it does not detect, the walk to the
  nearest enemy on an ally's shout, the walk at the party it does not see out of a cloud, and the
  random walk when an unseen attacker hits it (the hit is a clue for the engine's search instead).
  An ally's walk after the party stays. So the engine alone searches, also when it has no clue. For
  now that means mages and priests on the engine's side; fighters and monsters follow with F1e, and
  a neutral or charmed creature keeps SCS's own hunt.
- **Log.** Rows `hunt` (a search begins: clues, tactics, patience, guard, wit), `clue` (a hit),
  `search` and `return` (walks), `detect`, `reveal`, `gave-up` (why: patience, no clue, stuck) and
  `stuck`; `inspect()` has the search's counts.

Not built yet: opening doors, teleporting toward a clue (SCS's Dimension Door pursuit and fiend
teleport), buffing at the post after giving up, barks, and an ordered target's clues coming first.
To see in a lab: searches in real fights, whether spell damage sets `m_lHitter` as weapon hits do,
and what Detect Illusion reveals.

## Agreed (Christopher, 2026-10-25)

1. **Target choice by worth, with overrides.** Not SCS's fixed list ("Ich würde es nicht eins zu
   eins so eine statische Liste machen … Das ist ein bisschen zu simpel"): worth decides, with a
   bonus for interrupting an enemy that is casting. And for target choice "und bei solchen
   ähnlichen Entscheidungen, die KI treffen muss, immer auch einen Override", for example "wenn ein
   bestimmter Gegner immer auf den Main-Charakter gehen soll". Built: "Orders and interrupting".
2. **Staging** as above.
3. **Wit by race group** ([MIND-01](MIND-01-wit-and-difficulty.md), built): ogres and trolls stay
   normal on Insane. More detail later if needed.
4. **Fighters and monsters always attack** when nothing else is worth more; what standing next to
   an enemy costs (`weapons.exposure`) only chooses between targets ("dein Vorschlag an sich passt
   mir"). Casters keep the weighing.

Two rules for the whole engine came with it:

- **No more SCS takeovers.** "Ich will, wie gesagt, nichts mehr mit SCS übernimmt … Wir haben
  keinen Release-Druck, wir müssen SCS nichts überlassen. Das machen wir wirklich, wenn dann nur
  zum Testen … diese SCS-Übernahmen und diese Schwellen und all so ein Kram, das brauchen wir alles
  nicht … lieber direkt bei uns in der eigenen Engine nachbauen … Mit geilerer KI." So the engine
  owns the whole round: no decline that hands a round to SCS's blocks below the hook (until then,
  SCS's round timer ran between two engine actions and SCS's melee filler took over), no worth
  thresholds below which SCS acts. SCS's logic stays the blueprint, rebuilt in the engine. Built:
  "The engine owns the round" above.
- **Instant actions do not take the round.** "Tränke nehmen, Fähigkeiten benutzen … können auch
  teilweise nicht eine ganze Runde dauern, sondern instant sein. Und müssen dann nicht die ganze
  Runde übernehmen. Das gilt auch für viele Dinge … Bei Magiern … Auch bei Bogenschützen." The
  engine decides again right after such an action.

And the tone: not too clever, but immersive and sensible; "ein paar Gegner, die einfach ein paar
blöde Entscheidungen machen … vollkommen in Ordnung", and in the end a challenge on high
difficulty.

Known gaps, for later:

- On-hit enhancers (opcodes 248 and 249: Power Attack, Smite, an assassin's poison, Stunning Blow)
  are not valued yet (F2): one hit's worth of the effect they add.
- Barbarian Rage's armour class penalty does not count against what it protects; per-cent maximum
  hit points (opcode 18, mode 2) give no hit points; helmets are not read.
- Movement speed is not read (haste, slow, boots of speed), only the default.
- Heals and cures at allies weigh a walk to the ally by its seconds (`castCost`), attacks by
  `weapons.paced`; one rule for both is open. Defences, heals and cures at allies do not walk into
  range yet.
- To see in a lab: whether `SpellPointRES` walks as `SpellRES` does, and long walks with
  `AttackOneRound`. EEex's started-action listener fires when the walk into range begins, not when
  the casting does ([ACT-05](ACT-05-casts-out-of-sight.md)), so the engine's hold of a queued cast
  over the walk is needed.
- Interrupting: only damage counts; whether a hold, sleep, stun or silence breaks a cast is open
  (the lab saw one cast end under an imposed silence, ACT-02). A spell is worth breaking by its
  level alone, not by what it would do to whom. Changed casting speeds (opcode 189, Improved
  Alacrity on the enemy) are not read. A lab has to show interrupts in fights.
- An ordered target out of sight is searched for like any other enemy; its clues do not come first
  yet ("Searching").
