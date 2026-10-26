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
- **The jump** (2026-10-26). A long walk goes by a teleport the creature has: any spell or innate
  ability cast at a point that moves the caster there (opcode 124 or 274 on the caster: a phase
  spider's teleport, a mind flayer's astral travel, Dimension Door, Ascension's Dimension Door),
  cast like the engine's other spells (`SpellPointRES` at the open spot nearest the walk's point,
  held while it runs). SCS teleports its phase spiders and mind flayers to the party member they do
  not see and its mages after the one they chase; here the spot is the clue's. An innate power goes
  for a walk of 200 or more, by anyone (it is how such a creature moves); a memorized spell, which
  spends its slot, for 600 or more and only by a creature that sees its tactics this search. No
  teleport within 18 seconds of the creature's last, a search jump or a jump into the fight (SCS's
  pause between its mages' Dimension Door pursuits; the game's Teleport Without Error, which most
  fiends carry, gives itself back at once); the innate first, then the lowest level; beyond its range
  as far toward the spot as it reaches, and the creature walks when that would land it in a danger
  zone short of the spot. The log judges each by where the creature stands after it
  (`landed` rows with the distance off its spot, `landed` and `unlanded` counts).
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
  An ally's walk after the party stays. So the engine alone searches, also when it has no clue, for
  every creature on the engine's side (fighters and monsters too since F1e); a neutral or charmed
  creature keeps SCS's own hunt.
- **Log.** Rows `hunt` (a search begins: clues, tactics, patience, guard, wit), `clue` (a hit),
  `search` and `return` (walks), `teleport` and `landed`, `detect`, `reveal`, `gave-up` (why:
  patience, no clue, stuck) and `stuck`; `inspect()` has the search's counts.

Not built yet: opening doors, buffing at the post after giving up, barks, and an ordered target's
clues coming first. SCS's scripted teleports (the fiends' and Melissan's `dw#fitel`, cast with
`ForceSpellRES` or `ReallyForceSpellRES` without a memorized copy) are no ability the engine sees.
Since 2026-10-26 the installer gives each creature of a hooked script that teleports that way and
has no teleport of its own a real innate one, BGSETELE ([HOOK-01](HOOK-01-scs-hook-placement.md),
rule 8); most fiends already carry the game's Teleport Without Error (SPIN159). So a fiend the
engine drives searches and jumps with a teleport the player sees cast. In the SR lab (2026-10-26,
`.work/stepT-lab`) the message log named both when cast at a point ("Balor: Teleport Without
Error"), and SCS's own `ForceSpellRES` of `dw#fitel` too, with its target ("Glabrezu: Teleport
Without Error : …"). BGSETELE moved its caster 0.4 seconds after the order and came back 18.7
seconds after its use; Teleport Without Error moved it after about a second (its casting time)
and was ready again at once, though the next cast waited for the usual pause after a spell. To
see in a lab: searches in real fights, whether spell damage sets `m_lHitter` as weapon hits do,
what Detect Illusion reveals, and whether a teleport at a spot the caster does not see goes off
or first walks until it does.

### Jumps into the fight (2026-10-26)

Christopher on SCS's fiends, which he saw stand somewhere else at once without a word in the log:
"Wenn die so einen Instant-Teleport hätten, der halt
irgendwie auf Cooldown geht" (no round lost, but seen: a glow and the name in the log). SCS is the
blueprint (`fiend/ssl/jump.ssl`, credit DavidW): its fiends jump next to a party member that is
weak, a mage or easy to hit. The engine (`combat-intent/choice.lua`'s `jumpOptions`) weighs the jump
against the walk instead:

- **Who.** A creature that walks to the enemies it sees for its melee weapon (`mind.chase`: the
  fighter and monster profiles), with a teleport among its ready spells and innate abilities (as
  the search finds them). Not with a ranged weapon or a touch charge, nor while rooted, in its own
  Time Stop or under Improved Alacrity.
- **Wit.** A tactic: a clever creature always, a normal one when it notices (drawn once a decision,
  also when only a jump is there to notice), a dull one never.
- **Where.** A spot 48 short of the enemy on the way there, when the walk to it is 200 or more for
  an innate teleport and 600 or more for a memorized spell; beyond the teleport's range as far
  toward it as it reaches, at the nearest open spot where the creature fits. The search's rules
  pick the teleport and its 18-second pause, shared with the search.
- **Worth.** The round of the weapon's hits on that enemy as for a swing, paced by the casting and
  any walk left after landing, and on a casting enemy what breaking its spell is worth. It costs
  the teleport's level as a spell's would and what standing next to the enemy costs, times caution.
  A danger zone counts as for a step out of it: leaving a cloud by the jump is worth what the cloud
  would still have hurt, landing in one costs it (`zones.leap`), and an order to attack someone
  makes the jump to that enemy count as ordered.
- **Choice.** A jump ends next to the enemy as the walk does, so a creature that always attacks
  takes the jump over the walk whenever it is worth more (`why='jump'`), also when it is worth less
  than a spell must be. A very weak weapon walks, as the teleport costs more than the few hits the
  jump wins: in the tests a knife of 6 jumps 600 to its enemy, a mace of 4.5 walks.
- **Log.** A `leap` row (from, to, the teleport, the target, innate or not), `jumps` in the counts,
  and a `landed` row once it ends, as for a search teleport. `jumps` counts decisions, as the other
  counts do; the `leap` row marks a jump begun.

Asleep in the game until F1e switched fighters and monsters on (below): mages and priests do not
chase.

In the lab's first run (2026-10-26, monsters switched on for the lab) no jump went off. The
glabrezu's first decision was the jump (Teleport Without Error, worth 0.19 against 0.13 for the
walk), but SCS's Confusion power went first: a guarded copy above the hook, which fires in a round
the engine has (Christopher's answer 10). Under the casting pause after it the next decision
walked the 350 to the enemy (3.4 seconds) rather than wait 5.9 seconds and jump. The
Suldanessellar balor (`SUDEMON2`) never asked the engine: the first two blocks of its SCS script
attack neutral creatures (the city's elves) while it senses the party, and the lab's watching PC
was neutral.

### F1e: fighters and monsters switched on (2026-10-26)

The engine takes the rounds of all four families now: the choice (`adapters/eeex/choice.lua`,
`M.families`) and the director's advice on a member's own casts (`combat-intent/director.lua`)
cover fighters and monsters as well as mages and priests. Until F2:

- Archers shot with the weapon in hand at the enemies within its range, from where they stood: no
  kiting, no switch to a melee weapon. F2c (below) gives them both.
- Thieves fought as fighters do. SCS's backstab plan still sets up above the hook; F2d (below)
  gives the engine its own hiding and backstabs.
- SCS's guarded specials above the hook (a glabrezu's Confusion, for one) still go first in the
  round they fire in (Christopher's answer 10).

Labs switch families with `api:setFamilies`: `{mage=true,priest=true}` gives fighters and monsters
back to their scripts, for a comparison with SCS. A lab of mixed fights follows.

### F2a: on-hit enhancers (2026-10-26)

Spells and items that make the next hits do more (opcode 248 for melee hits, 249 for missiles and
thrown weapons) count by what one hit brings (`combat-intent/spells.lua`, `c.hits`): the EFF each
hit lands, read as if cast at the creature hit, with its saving throw and the enemy's own spell
protections (their SPLPROT rows are asked for each enemy, as for a weapon's own effects). An
effect for fists only (opcode 248, parameter 2 bit 2) counts when the creature fights with its
fists (slot 10 selected, `sense.attack`).

- **A buff** (`defence.offense`): for each enemy the creature sees, the hits that land while the
  buff runs (attacks a round, chance to hit, rounds, less Mirror Images and Stoneskin skins) times
  what one hit deals, and the best disable once; the mean over the enemies.
- **A swing** (`choice.hitsOn`): on-hit effects already on the creature (its active effects,
  `sense.guard`) add to each attack: their damage per hit, counted for the kill, and the best
  disable.
- **Once:** a hit that takes its own spell off again (opcode 321 on the spell that holds the
  on-hit effect) is that spell's only one, and so for all on-hit effects of the spell: Smite Evil
  counts for the next hit alone, and Artisan's Kitpack's Poison Weapon (`C0AS#P1`), which poisons
  with one 248 and ends
  with another, too.

The Spell Revisions lab at level 12 reads: Artisan's Kitpack's Smite Evil (`C0PAL02`) 21 magic
damage on the next hit;
the assassin's Poison Weapon (`SPCL423`) 22 poison on every hit for 30 seconds, save vs death;
Power Attack (`SPCL906`) a stun, save vs death; Smite (`SPCL909`) a stun and a knockback without a
save; Deathblow (`SPCL902`) a slay up to level 10, Greater Deathblow up to 12 (the hit's EFF keeps
its levels, SPELLS-01). An on-hit EFF that cannot be read leaves the spell approximate, with its
reason, and the rest of it whole.

### F2b: debuffs (2026-10-26)

Spells and abilities that weaken enemies are attacks now (`combat-intent/harm.lua`,
`combat-intent/choice.lua`). SCS's blueprint (credit: DavidW; read in its source): its priests
cast Doom at an enemy not doomed yet, each priest at most every 18 seconds
(`priest/ssl/combatblocks/doom.ssl`), and Greater Malison at enemies not malisoned yet, once a
minute in the whole area (`curse_malison.ssl`); its mages slow the strongest enemies not slowed yet
whose save can still fail (`mage/ssl/combatblocks/slow.ssl`), throw Glitterdust at enemies whose
save can fail and that are not dusted yet (`glitterdust.ssl`), and fire sequencers that pair
Dispel Magic with Greater Malison (`attacks_on_pc_defences.ssl`).

- **Worth** (`harm.weaken`, `harm.debuff`): the share of an enemy's fight a debuff takes while it
  holds, on the scale where a hold that takes all of a healthy enemy's fight for three rounds is
  worth 1. An enemy's fight is its weapon's harm in a round (attacks, the chance to hit the mean
  armour class of the caster's side, the damage of a hit) and its spells (by casting class and
  level, as `threat.lua` counts them). That share counts for the part of three rounds the debuff
  holds, by the enemy's health as a disable does, and as likely as it lands (magic resistance,
  save, its own chance). What takes a share (IESDP):
  - Slow halves all a creature does: it acts every second tick, so it makes half its attacks and
    casts in twice the time.
  - Blindness costs 4 to hit (on EE); a second blindness adds nothing.
  - To-hit penalties, luck and a negative chant (Doom, an enemy's Chant) count on the attack roll
    point for point; fatigue above 6 costs a point of luck each (FATIGMOD.2DA, for a rested
    creature).
  - Fewer attacks, less damage, less damage in per cent for the weapon's kind (opcode 332) and a
    THAC0 set or scaled (opcode 54).
  - Casting failure by kind of spell (wizard, priest, innate), and deafness's 50 % on wizard and
    priest spells: Miscast Magic on a mage takes most of its fight, little of a fighter's.
  - A lower casting level weakens the creature's spells by the levels it takes; drained levels
    weaken its weapon and its spells by theirs.

  Slow on a fighter who would deal 6.65 a round (one attack at THAC0 12 for 7, against armour class
  10) takes half its fight for the full time: worth 0.5, as much as holding it for half the time. A
  creature already slowed or blind gets nothing more from another slow or blindness.
- **As attacks** (`choice.attack`): a spell that only weakens is an attack of its own kind
  (`debuff`). A debuff beside damage counts in full (Holy Smite blinds), beside a disable only as
  likely as the disable fails: a creature held has no fight to weaken. An enemy that only the
  debuff of a spell reaches counts for the debuff (Holy Word's weaker tiers for those too strong
  for its stronger ones, SPELLS-01). A removal with a debuff makes an attack too: Spell Revisions'
  Slow takes haste, Glitterdust and Faerie Fire take invisibility.
- **Openings,** a tactic by wit (Christopher, 2026-10-26: every new tactic varies by wit): a debuff
  that lowers saving throws, magic resistance, resistances or armour class (Greater Malison, Lower
  Resistance, Faerie Fire, blindness's 4 points of armour class) also counts what it opens. That is
  the most one of the caster's other ready attack spells gains on the weakened enemy (Greater
  Malison before Hold Person makes the hold land more often), and what its friends' weapons gain on
  it over the rounds the debuff holds (those next to the enemy, and archers when it is the group's
  focus), no more than the enemy has left, as likely as the debuff lands. A clever creature always
  counts it, a normal one when it notices (a ready attack spell whose debuff opens defences
  counts toward noticing), a dull one never. Plain debuffs every creature casts.
- **No double curses.** An enemy that carries the spell's effects already gets it no second time:
  one of its active effects comes from the spell or from what the spell delivers (`harm.carries`),
  or, in the caster's own Time Stop, the spell is among the casts that land when time resumes. In
  the group, one member casts each debuff spell at an enemy (the director's curses,
  `combat-intent/director.lua`). The choice claims the enemies it weakens for its spell, and the
  cast's start holds them while it runs and 2 seconds after (`graceTicks`), as a disable holds its
  targets. So two priests with Doom curse two enemies, or one priest casts Doom and the other
  Greater Malison on the same enemy. A creature that does not coordinate (coordination below 0.5)
  pays the claims no heed.
- **Prayer, Recitation and Chant** count for both sides: what they give the caster's side, weighted
  by caution, and what they take from each enemy in their area that does not carry them yet
  (DEFENCE-01).
- **Danger zones** weigh the conditions of a cloud the same way on the creature in it
  (`zones.debuff` is `harm.debuff`): Stinking Cloud's spell failure takes most of a mage's fight
  and little of a fighter's (SUPPORT-01).
- **In game** (`adapters/eeex/choice.lua`): when a ready spell weakens enemies, the adapter reads
  each enemy's active effects (`sense.wards`, as for removals). A debuff at a creature is judged as
  an attack: a hit when the target carries an effect of the spell afterwards, a miss otherwise,
  remembered as other misses are. The choice adapter counts `debuffs`; the director logs `curse`
  rows and shows its `curses` in `inspect`.

Tests: `harm` (5 groups), the choice's group 23, defence group 6, director group 11 and the choice
adapter's group 34.

### F2c: archers, weapon choice and kiting (2026-10-26)

SCS's blueprint (credit: DavidW; read in its source): its ranged fighters (`genai/ssl/dw#range.ssl`)
shoot while no enemy stands close (`shoot.ssl`: enemies below 40 % of their hit points first, then
casters, then anyone), and leave alone enemies their missiles cannot hurt (`ArrowSafe` in
`ssl/library.slb`: Protection from Normal Missiles, a Physical Mirror, the shield `shld24`, each
noticed after three or six seconds; `MissileSafe`: missile resistance of 100, or of 75 and more
unless its `targetcompromise` timer runs). The engine counts missile resistance in each shot's
damage instead. With an enemy within 6 a ranged fighter runs from the
nearest for four seconds, once in eighteen (`retreat.ssl`); if one is still close, it takes up its
most damaging melee weapon and fights (`dw#wtacor.ssl`, `EquipMostDamagingMelee`).

- **The weapon in hand, read right** (`combat-intent/arsenal.lua`, `sense.arsenal`; lab probe F,
  [learned.md](../learned.md)): THAC0BONUSRIGHT holds the bonus to hit of strength (of dexterity for
  missiles), of the proficiency and of the item itself, a launcher's and its ammunition's together;
  DAMAGEBONUSRIGHT only the proficiency's bonus to damage. Strength's and the item's bonuses to
  damage come on top, strength's by the ability's flags. While a launcher is in hand the game's
  selected slot is the quiver's, and the launcher is the first weapon slot that shoots the
  ammunition. Before, the engine took the arrows for the weapon (a bow's own bonuses and range were
  lost), counted an item's bonus to hit twice and strength's bonus to damage not at all. Probe F's
  fighter (level 8, strength 18, dexterity 16) reads THAC0 10, 8.5 a hit and two attacks with its
  short sword +1, THAC0 7, 9.5 a hit and three attacks with its longbow +1 and arrows +1, as the game
  showed.
- **Other weapons.** Each weapon ability of each item in the weapon slots (35 to 38), as it would
  strike if taken up, worked out from the game's tables, read once through EEex: WSPECIAL for the
  proficiency, the class's ZERO_SKILL_THAC0 (CLSWPBON) without a star, STRMOD and STRMODEX, DEXMOD's
  missile column, WSPATCK for the attacks a warrior's proficiency and level bring (for classes whose
  CLSWPBON row gets them). Its attacks a round are those in hand, less what the weapon in hand adds
  or sets (opcode 1 while equipped, its WSPATCK share), plus what the other brings, so haste stays.
  A launcher shoots the first ammunition in the quiver it fits; ammunition alone strikes nothing. A
  thrown axe is two weapons, swung and thrown. A magic weapon in hand stays there (the game keeps
  it), and without the tables only the weapon in hand counts (an `error` row once).
- **Choice** (`choice.weaponOptions`): every weapon at every enemy it can reach. One not in hand
  costs the second it takes to take it up (`weapons.switchSeconds`, a guess until a lab measures
  it), as a walk of that length lowers a round's worth: in the tests a sword next to the enemy must
  be worth 7/6 of the bow in hand to be taken up, so the creature does not change weapons back and
  forth. A missile weapon walks into its range first, as the game's attack actions do, and the walk
  lowers the worth; not for a creature that cannot walk. Worth decides, not SCS's range rule: next
  to an enemy an archer keeps shooting while the bow is worth more and takes up the sword when that
  is. No missile option at an enemy that keeps its missiles off (`weapons.missileBlocked`):
  Protection from Normal Missiles against a hit that is not magical, a Physical Mirror, and an
  immunity or bounce of the missile's projectile (opcodes 83 and 197, by the PROJECTL.IDS entry one
  below the projectile's number; EE Fixpack adds darts', throwing daggers' and throwing axes'
  entries to Protection from Normal Missiles this way. The game's own spell names EE's plain
  arrows and bolts (`1arow01`, `1bolt01`), not the magical ones; Spell Revisions' Protection from
  Missiles names only the older entries of arrows, axes, bolts and bullets, none that EE's arrows
  fly as, beside the spell state SCS looks for; [learned.md](../learned.md)).
- **Kiting** (`choice.kite`), a tactic by wit: with a melee enemy within 6 (96) that can fight, and a
  missile weapon it can shoot an enemy with, the creature weighs a step of four seconds away
  (`kiteSeconds`, SCS's 60 ticks): straight away from the melee enemies close to it, or in one of
  eight directions, where the fewest melee weapons reach it, then furthest from its nearest enemy,
  with the next four spots as exits. Worth: the hit points a round the melee weapons take from it
  where it stands less where the step ends (`weapons.meleeAt`), as a share of its own, times
  caution, for the step's two thirds of a round, and what the walk is worth in danger zones
  (`zones.delta`). The step is taken when that beats two thirds of a round of its best attack or
  cast. Not again within 18 seconds (`kiteGap`, SCS's `runonce` timer); not webbed, invisible, with a
  touch charge, in its own Time Stop or under Improved Alacrity. A clever creature always, a normal
  one when it notices (a melee enemy close by counts toward noticing), a dull one never. In the
  tests an ogre that would take 57 of the archer's 60 hit points a round makes it step away (worth
  0.63 against the bow's 0.06 for those seconds); a weak enemy does not.
- **In game** (`adapters/eeex/choice.lua`): a weapon not in hand is `SelectWeaponAbility(slot,
  ability)` before `AttackOneRound`, held as any weapon attack; the `swing` row names the slot and
  `switches` counts them. An `arms` row logs the weapon in hand whenever it changes, with the
  tables' parts of its bonuses (`model`) beside the game's THAC0BONUSRIGHT and DAMAGEBONUSRIGHT
  (`game`). A step away is `MoveToPoint` to the first open spot of the step and its exits, held
  while the creature walks, like a way out of a zone, with a `kite` row and, once it is over, a
  `kited` row (where it ended, how close the nearest enemy it sees stands); `kites` and `kited`
  count them.

Tests: `arsenal` (5 groups, probe F's numbers), weapons groups 12 and 13, the choice adapter's group
35, 37 mutations checked.

To see in a lab: how long `SelectWeaponAbility` takes and that it takes up a launcher with its
ammunition, and whether a queued one can hang (one queued on the protagonist did once, on
2026-10-17, and was not seen again after a fresh load; bg-modding knowledge base, `gotchas.md`):
the hold of a weapon attack ends after two rounds at most either way; the `arms` rows' model
against the game on real creatures (whether missile and melee bonuses to hit, stats 72 and 166,
are part of THAC0BONUSRIGHT); whether Spell Revisions' Protection from Missiles keeps EE's
arrows off at all, as its projectile entries miss them (the engine skips plain missiles at a
creature in its spell state, as SCS's archers do, and shoots magical ones); whether enemies
follow a kite, and whether kiting plays well or annoys.

### F2d: thieves, hiding and backstabs (2026-10-26)

SCS's blueprint (credit: DavidW; read in its source): a thief that sees no enemy turns invisible
for free (`genai/ssl/initial.ssl`: `ApplySpellRES("dw#silin",Myself)`, SCS's own Invisibility,
when it is not invisible, blind or disabled and detects no enemy and no party member; also once
when it is created, in sight of the party or not), above the hook. In a fight it drinks
invisibility or reads its scroll when it sees an enemy and is not invisible
(`genai/ssl/backstab.ssl`, potions `dw#ptn10` and `potn10`, scroll `scrl90`), then stabs the weakest
close enemy that has no Mirror Images and no Stoneskin (`dw#wtacor.ssl`, `BackstabSafe` in
`ssl/library.slb`), going a little way for a good one while no enemy sees through invisibility (its
`backstabplan`).

- **The game's rule** (`combat-intent/backstab.lua`, as GemRB reads BG2: `GetBackstabDamage`,
  `IsBehind`; [learned.md](../learned.md)): the attacker is invisible (Improved Invisibility alone
  does not count), its weapon can backstab, the target is not immune (`IMMUNITY_TO_BACKSTAB`, stat
  175, or a barbarian), and the attacker stands behind it: the target faces within two of the 16
  directions of the way from the attacker to it. The hit's damage is multiplied by the attacker's
  `BACKSTABDAMAGEMULTIPLIER` (stat 56); attacking ends invisibility, so only the first hit can be one.
- **Which weapon can backstab** (`combat-intent/arsenal.lua`): a melee weapon whose "unusable by
  thieves" bit (item usability `0x400000`) is clear, whoever wields it. Mods move that bit, so the
  engine reads it from the item: Tweaks Anthology's "Thieves Can Backstab With More Weapons" clears it
  on daggers, staves, swords and clubs, and in Christopher's game nearly every melee weapon has it
  clear (its class limits sit in opcode 319). Both resource readers take the usability field now.
- **What the engine reads** (`sense.actor`): every creature's backstab multiplier, its immunity
  (stat 175 or the barbarian kit, `m_mageSpecUpperWord` and `m_mageSpecialization` as EEex builds the
  kit) and the direction it faces (`m_nDirection`, 0 to 15; anything else counts as unknown).
- **Worth** (`choice.hitsOn`): every attack with a weapon that can backstab counts the backstab as
  likely as its first swing lands from behind: by the target's facing, 5 in 16 when that is unknown,
  certain once the creature stands behind it. A backstab adds the weapon's damage times the
  multiplier less one, and the kill counts both ways (with and without it).
- **Going behind** (`choice.flankOptions`), a tactic by wit: a hidden creature next to an enemy that
  faces it may first walk to the spot 48 behind it (`backstab.spot`, opposite the way the enemy
  faces) and stab from there; worth the round with the backstab, lowered by the walk (and a weapon
  switch) as a walk lowers any attack, plus what breaking a spell is worth, less what standing next
  to the enemy costs. Danger zones at the spot count as for kiting (`zones.delta`). A clever creature
  always, a normal one when it notices (a backstab within reach counts toward noticing), a dull one
  never.
- **Hiding first** (`choice.hideOpening`, `defence.lua`), a tactic by wit: a potion, scroll or spell
  that makes the creature invisible (plain invisibility, on itself) counts what the backstab after
  it gains over the same round without one, less the part of a round the walk to the enemy takes
  (to the spot behind it when the enemy faces the creature). A potion counts no casting time. A
  defence must reach the minimum worth to beat a free swing, so a thief with a short sword swings,
  one with a long sword and a multiplier of 5 drinks first (in the tests).
- **SCS's free hide stays SCS's** (Christopher's answer 11: powers a creature gives itself are its own
  abilities; above the hook stays SCS's, as listed at the top). It happens only while the thief sees
  no enemy, so nobody would see a named ability being used either. The engine takes the hidden
  thief from there: it searches, goes behind and stabs. The same holds for SCS's other free
  invisibilities: fiends out of sight (`DEMPIT`, `ERINYES`, `KARASH`, `TELPIT1`, `DEMMAU01`, …), mind
  flayers' Improved Invisibility (`dw#illin`, above the illithid difficulty's normal setting) and the
  vampires' forms. SCS's helper scripts that walk a thief, hiding, to a party member an ally called
  for help against (`dw#gphlp`, `drdsht01`) are not hooked and run as before.
- **In game** (`adapters/eeex/choice.lua`): a walk behind an enemy is `MoveToPoint` to the nearest
  open spot by the spot behind it, the weapon taken up first when the choice switches
  (`SelectWeaponAbility`), held while the creature walks or takes up its weapon, with a `flank` row
  and, once it is over, a `flanked` row (whether it stands behind its enemy and is still hidden, how
  far from it); `flanks` and `flanked` count them. Then the engine decides again, mostly the swing.
  Choice, `swing` and `attack` rows carry the chance that the first hit is a backstab (`backstab`),
  so a lab can hold the hit points lost against it; a choice row for a hide carries what the
  backstab after it adds (`opening`).

Tests: `backstab` (7 groups), `arsenal` group 6, `zones` group 13, the director's sense test, the
choice adapter's group 36 (also a walk behind that takes up another weapon first, and the potion
first with its opening).

To see in a lab: whether EE needs the attacker behind its target at all and how wide behind is;
which way `m_nDirection` counts; whether Improved Invisibility alone allows a backstab; whether a
barbarian has stat 175 set; whether a backstab leaves its target immune for a while; that a
fighter-thief stabs with a two-handed sword whose thieves' bit a mod cleared; and whether a
hidden thief reaches the spot behind a moving enemy in time.

### F2e: critical hit effects and on-hit debuffs (2026-10-27)

Weapons and kit powers that cast a spell on a critical hit (opcode 341) count now, and so do hits
that weaken (F2b's debuffs, brought by opcodes 248 and 249 or by a critical hit), beside on-hit
damage and disables.

- **The game's rule** (IESDP, opcode 341): while the effect lasts, the spell it names is cast at each
  creature its holder hits critically, with either hand (parameter 2 at 0) or with the weapon that
  holds it alone (1); from an EFF file only with weapons of one category (parameter 3, ITEMCAT.IDS:
  28 for fists and claws); with any attack (special 0), melee ones (1), ranged ones (2) or magical
  ones (3, which count nothing here).
- **Who gets what** ([learned.md](../learned.md)): inside such a spell "self" (effect target 1) and
  "original caster" (9) are the attacker, the preset target (2) the creature hit. IESDP does not
  say; the in-game texts of the lab's holders do. Beamdog's Corinth's Bow +2 gives its wielder Luck
  by a cast at self (`BDBOW02`), the Sword of Troll Decapitation +1 gives its wearer strength
  through target 9 (`BDSW2H02`), Artisan's Kitpack's Kensai heals itself with target 1 (Second
  Wind, `C0KN#09A`), and the Sirene NPC's Harbinger of Pain +4 deals its 1d10 to target and wielder
  with one effect each (targets 2 and 1, `C0SBLUN`). The classifier (`spells.lua`, `onCrit`) reads
  the spell at the holder's level as if cast at the creature hit without its projectile, so what it
  puts on its caster lands on the holder.
- **How often** (`weapons.critical`): of the hits that land, a share of (1 + critical hit points)/20
  over the chance to hit are critical hits, at least 1 in 20 and at most all of them (a natural 20
  always hits). Critical hit points come from the creature's own effects (opcode 301), less what its
  debuffs take. Half of them get past a helmet (`defence.critOpen`, as for a weapon's own critical
  hits; helmets are not read yet).
- **A swing** (`choice.hitsOn`): what the critical hit spell deals counts as expected damage, but not
  toward a kill, which no one plans on a critical hit; its disable and its debuff count as likely as
  a critical hit lands. One of a single weapon counts only with that item, one of a category only
  with a weapon of it (`arsenal.lua` reads every weapon's category from its item).
- **A buff** (`defence.offense`): the same over the rounds the buff runs, also when the buff raises
  the critical hit points itself: Critical Strike's sure critical hits make every hit that lands one.
- **Once:** a critical hit spell that takes the spell holding it off its holder again (opcode 321)
  comes once, as an on-hit effect does (F2a).
- **On-hit debuffs:** a hit's debuff counts by `harm.debuff` (F2b), against the armour class of the
  caster's side, as likely as a hit that brings it lands, the strongest one beside the strongest
  disable; more on an enemy the creature's orders name. Nothing on an enemy that carries it already:
  an effect of the spell or item that holds it, or of what it lands (`harm.carries`). A weapon's own
  effects weaken alike.
- **In game** (`sense.guard`, `adapters/eeex/choice.lua`): the creature's active effects are
  classified at its own level, so a kit power's critical hit or on-hit spell counts at the holder's
  level (until now, at level 1).

The Spell Revisions lab at level 12 reads all 30 of its holders without a gap: Siege of Dragonspear's
weapons (Martyr's Morning Star +2 takes 15 % of the target's hit points, the Bracers of the Shuttered
Lid blind, the Astral Crossbow +2 knocks unconscious, Spell Breaker +2 dispels), Artisan's Kitpack's
Kensai, Swashbuckler, Trickster, Siegemaster and Dreadnought, and the Sirene NPC's Brimstone +3 and
Harbinger of Pain +4.

Tests: spells group 38, weapons group 14, defence group 13, `arsenal` group 6, the choice adapter's
group 37 (a brawler's critical hit spell from its own effects, at its level, with fists only); 57
mutations checked.

To see in a lab: that "self" in a critical hit spell is the attacker (Corinth's Bow's Luck on its
wielder); how often critical hits come with critical hit points; and whether a helmet keeps a
critical hit spell off as it keeps a critical hit's double damage off.

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

- Critical hits (F2e): critical hit effects of magical attacks (special 3) count nothing, nor what
  a critical hit spell does to the holder itself (Corinth's Bow's Luck, Second Wind's heal). The
  critical hit and on-hit effects of a weapon not in hand count nothing when the creature weighs
  taking it up: they are no active effects until it does. Critical hit spells that put their
  effects through opcode 326 aimed at "self" (Artisan's Kitpack's Dreadnought) count for the holder
  until the classifier reads 326 as IESDP describes it (next). Helmets are not read: half of all
  critical hits count as kept off.
- Debuffs (F2b): lower strength, dexterity and constitution count nothing (the engine reads
  neither the stats nor their tables), and neither do lower maximum hit points, movement, casting
  speed, critical hit chances, bonuses against kinds of creature, Grease, knockback, wild surges or
  fields that block teleports. Fatigue counts FATIGMOD.2DA's free points for a rested creature
  without reading the table. A debuff beside damage counts in full even when the damage kills.
  Openings count neither the debuffs of defences (Prayer) nor allies' spells. Buffs count a point
  of luck half a point to hit (`defence.lua`), debuffs a full point; and defences sum saving throw
  changes, so a spell that raises each of the five saves with an effect of its own counts five
  times what one effect raising all five (opcode 325) counts. Cures still count blindness,
  deafness and disease on a friend at fixed values (`care.lua`), not by the share of its fight
  they take.
- Weapons (F2c): the off hand and two-weapon fighting count nothing, nor the shield's armour class
  lost when a two-handed weapon or a bow is taken up. A launcher always shoots the first ammunition
  that fits, never a better one. WSPATCK goes by the highest class level, and CLSWPBON by the
  class's row, not a kit's. Without the game's tables strength's bonus to damage is unknown for the
  weapon in hand. A thrown weapon counts strength's bonus to hit beside dexterity's when its flag
  says so (not measured). The walk into a missile's range does not count danger zones on the way.
  Conjured weapons still take the caster's THAC0 with the bonus to hit of the weapon it held.
- Backstabs (F2d): only potions, scrolls and spells of invisibility hide a creature for a backstab;
  the thieves' own Hide in Shadows counts nothing. The spot behind an enemy is where it stands now,
  not where a walking enemy will be. A backstab counts the weapon's average damage, not its dice.
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
