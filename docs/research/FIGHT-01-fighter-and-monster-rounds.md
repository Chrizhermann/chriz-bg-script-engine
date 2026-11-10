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
potions. A thief's free invisibility stands aside for its own hide since F2f (below).

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

- Every creature may attack any enemy it sees in melee, a webbed or entangled one no further than a
  weapon reaches (`threat.reach`, 64). Until E8 v5 a caster went no further than `touchReach` (10
  range units, SCS's reach for touch spells); then Tarnesh, his attack spells spent, stood eighty
  seconds beside the hero he had put to sleep 195 away, twice, until the two-minute limit. SCS's
  mages walk there (the mage script `DW#MG468`, decompiled read only, credit DavidW): between casts
  (its `castspell` timer) `EquipRanged` and `AttackReevaluate` at the party, first at those not
  asleep, stunned or held, then at anyone, and once their attack spells and wands are spent
  `AttackReevaluate(NearestEnemyOf(Myself),30)` at any distance. A caster weighs what standing
  next to the enemy costs (`mind.alwaysAttack` is the fighters'), so it walks to a sleeper but not
  into an awake fighter's swings for a staff's few points. Touch strikes keep `touchReach`;
  `mind.chase` (fighters and monsters) lets a touch strike go any distance and a teleport into
  melee. A spell that conjures a melee weapon counts the walk as its share of the rounds the weapon
  fights (`combat-intent/choice.lua`, `armOptions`). Test group 8 in `test_weapons.lua`, 10
  mutations.
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
- **A target that runs off ends the attack** (E8 v1, 2026-11-04: Tarnesh chased the hero he had
  panicked with Horror for two rounds with his staff, while his Magic Missile was ready; the game's
  attack follows its target for as long as the engine holds it). Once the walk the choice expected is
  over (twice the straight walk, as paths bend, and two seconds), a melee target that stands further
  off than when the attack began and than a weapon's reach, by half that reach, makes the engine
  decide again (`adapters/eeex/choice.lua`, `M.outrun`); the attack is recorded as any other. A
  target that only steps aside, or a big creature whose body keeps its foe further than 64, keeps it.
- **A target the creature cannot get to ends the attack too** (E8 v3, 2026-11-04: Karlat, boxed in by
  four of the party, swung at Imoen behind them for a hundred seconds without a step, until the
  two-minute limit, with 3 of his 35 hit points left). An attacker that stands still for three
  seconds (45 ticks, no step of 8 or more) while its target stands beyond a swing's reach for the two
  of them is stuck (`M.stuck`, `M.swingReach`): a weapon's reach, 64 for two of a human's size with a
  weapon of range 1, 16 more or less for each point of the weapon's own range from 1 (`swing`, the
  ITM ability's range: a Halberd, Quarterstaff or Two-handed Sword 2, a Dagger 0), 16 more for each
  cell of personal space either has beyond a human's 3 (`M.pairReach`), so a big monster swinging
  from its own edge is never taken for stuck, and 12 more, as swings go a little further
  (`M.reachSlack`); without the sizes nothing is. The engine then leaves that target out of
  the creature's melee choices for two rounds, or until it stands within that reach again
  (`frame.self.unreachable`, `weapons.reachable`); missiles, spells and a teleport still go there.
  The attack row says `stuck` and the reach. Until E8 v6 the margin was half a reach (96 for two
  humans); then Neira, boxed in by Khalid and Jaheira, aimed at the hero 79 away for seventy seconds
  without a swing. Across the encounter lab's batches v3 to v9, between two creatures of a human's
  size, both standing, weapons of range 1 dealt damage up to 75 apart (in about half the samples at
  72 to 75) and not from 76 to 99 (in one more, at 85, the target lost hit points while Kestrel was
  shooting at it); hence 76. Weapons of range 2 dealt damage up to 89 (Kivan's Halberd, Tarnesh's
  Quarterstaff at 87), hence 92, and until E8 v9, with one reach for all, the check ended staff
  swings that landed (Tarnesh's at 80 and Silke's at 82 in v8). Alora's Dagger stopped to swing no
  further than 39 in 18 stops, where swords in the same fights stopped up to 70: 60 for range 0.

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
- **Openers** (2026-11-04, for Neira; Christopher: "das muss alles nicht komplett starr sein"):
  `opener` gives a creature a first sequence for its fight, from the difficulty `openerFrom` up: steps
  in order, each a spell or item, a list of them (the best by worth counts) or `{watch=seconds}`. At each
  decision the first step left with a choice worth more than it costs comes before the ranking, and the
  steps before it are passed over; a watch is a wait of its seconds and counts only while the creature
  is invisible. A step is behind the creature once its cast or drink starts, so a cast cut short before
  it starts is tried again. The opener ends after its last step or 30 seconds after the creature's first
  decision with an enemy in sight (`orders.openerSeconds`), and a load starts it anew. The choice row
  logs `openerStep` and `how` `opener-step` or `opener-watch`; an `opener` row says when a step was taken.
- **Companions** (2026-11-04, for Greywolf's archer Kestrel; Christopher: very weak on Core and below,
  clearly stronger above): `companion={weak=…, strong=…, strongFrom=4}` names two creature files the
  installer made (BOSS-01). When the creature's cutscene asks (`BGSE_Companion`, a line the installer puts
  into it), the engine creates the strong one at the creature's place from the difficulty `strongFrom` up,
  otherwise the weak one; once a creature, and only a file this game has. Without the engine, or with it
  switched off, nobody comes and the fight is as the game has it. A `companion` row says which came.
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
- **Called to the party (2026-11-10).** A set piece is the one case where a creature goes for a
  party member nobody perceived: SCS's assassins and the Bandit Camp's alarm walk their creatures at
  the party from a helper script (Christopher, 2026-11-10: taken over as they are for now). That
  walk asks the engine first ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 14), and for a creature
  the engine drives the member's place becomes a clue of the weakest kind (`called`), fresh while
  the script keeps calling. It does not run out and takes a guard from its post; the walk aims anew
  once the member has moved more than 240 away. Anything the creature or its group perceived goes
  first. SCS's calls for help work the same way (a group member's shout sends those who see no
  enemy to the party).
- **Casters search too (2026-11-10).** SCS's mages and priests did nothing until they saw an enemy
  themselves: a gate above the hook ended their pass (HOOK-01, rule 15), so the engine was never
  asked, and only fighters went for a clue. The gate now asks the engine first. A caster walks to
  its group's clues and to the member its script calls it to, as a fighter does. Open for the
  fights' design: the group is everyone of the enemy's side on the map whom the engine drives, and
  a clue has no reach, while SCS's shouts are heard only within earshot (how far was not measured).
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
- **Doors** (built 2026-10-29; Christopher: doors go into the first release, "muss rein";
  `combat-intent/doors.lua`, `adapters/eeex/doors.lua`). SCS's blueprint (`genai/ssl/chase.ssl`,
  credit DavidW): in a fight, indoors, with no enemy within 30, a creature that is no moron walks to
  the nearest closed door within 15 and opens it (`OpenDoor(NearestDoor)`); only SCS's general AI
  does it, not its mage or priest scripts.
  - *Who* has hands for a door, after SCS's non-moron kinds (`CRE_check_if_moron`,
    `sfo/filetype/lib_cre.tpa`) by the installed game's IDS names: humanoids, giant humanoids, the
    undead, demons, dopplegangers and lycanthropes; never zombies, gibberlings, golems or skeletons,
    nor beholders and dragons (no hands), nor anyone dull. Orders say yes or no whatever the kind
    (`doors=true` or `doors=false`).
  - *When*, only while searching: the straight way to the spot it searches crosses a closed door
    within its sight (448): it opens the door on its way and walks on. On a searched spot, or with no
    spot left, it looks behind a closed door within 240 of it (SCS's range of 15): a tactical creature
    takes the door the enemy was heading for, any other the nearest, and walks on 96 past the door's
    middle. A guard only near its post (240), a rooted creature never.
  - *Which doors*: closed ones with a leaf that blocks the way: a closed outline of at least three
    points that impedes search-map cells (`m_nClosedPolygon`, `m_nClosedSearch`). Areas also keep
    cages, vines, a harp, a tree, temple links and scripted barriers as doors without one (139 of the
    SR lab's 1,485 door entries; learned.md); those stay shut. Never a door with an armed trap (or
    one whose trap cannot be read), a secret door nobody has found, or a door into another area (one
    linked to a travel trigger, or whose link cannot be read); a locked door only when the creature
    carries its key, the game's own rule for `OpenDoor`. A door it could not open (it stood again, or its time ran out, with the door
    shut; also when a block of SCS's cut its try short once it was under way) is left for 30 seconds.
    A try ended by a hit, an enemy in sight or a danger zone, or cut short right at the start, leaves
    the door to try again. A door whose spot, or the spot behind it, lies in a danger zone waits; a
    spot beyond a door in a danger zone counts as searched.
  - *How*: one response, `MoveToPoint` to the nearer of the two spots the game gives for opening the
    door (`m_ptDest1`, `m_ptDest2`), `OpenDoor` at `EEex_Target` naming the door, and to look behind
    it `MoveToPoint` past it, one action a line (the game reads one action from each line of a
    queued response); held while the creature walks or opens, at most twice the walk's seconds
    plus 3 seconds. Then the door is judged by its own open flag (the ARE door flags).
  - *Log*: `door` rows (door, from, to, behind or toward, clue, target, tactical) and `door-end` rows
    (open, why: done, time, hurt, enemy, cut, zone); counts `doors`, `doorsOpened`, `doorsShut` and
    `doorFailures` (doors or kinds that could not be read; the first error as an `error` row).
  - *The door probe* (lab step D, 2026-11-02, the SR lab, `DOOR01` of `AR1204`, two scriptless probe
    creatures, nothing installed):
    - The reader finds doors in the area's main list (`m_lVertSort`, object type 33) and read
      `DOOR01` whole: closed, a four-point outline over 19 search-map cells, its two spots for
      opening, 20 hit points, no key and no lock difficulty. The game's own `NearestDoor` from the
      player names the same door.
    - `OpenDoor` at `EEex_Target` opens it: a fighter 204 pixels away had it open within a tick,
      without walking there.
    - The engine's door response held its three actions on one line, and the game reads one
      action a line: only the walk to the door ran, and the door stayed shut. Fixed the same day
      (one action a line, `chain` in `adapters/eeex/choice.lua`). The same flaw cost every weapon
      switch its attack (`SelectWeaponAbility` before `AttackOneRound`, or before the walk behind an
      enemy): in lab batch J, run 4, the archer's switch to its bow at 1.7 seconds only switched,
      and the attack came a second later from its next decision.
    - A walk to a spot behind the closed door (`MoveToPoint`) goes up to the door and stops there,
      trying again and again.
    - A door the player locked (`Lock`): the thief's `PickLock` had it unlocked within a tick (lock
      difficulty 0); the fighter's `BashDoor` within two ticks (its flags read open and broken, a
      tick later broken).
    - With the fix, a second probe the same day: the fighter walked to the door, opened it 7 ticks
      after it set off, and walked on through to the spot behind it (about 2 seconds in all); the
      same with the door named in the response. At the locked door (no key) its `OpenDoor` did
      nothing, and the walk on stopped at the door; the fighter stood still 41 ticks after it set
      off, which the engine takes as a door it could not open.
    - Still to see in game: the door response in a real search.
    Christopher, 2026-11-03: a locked door may also be opened by picking the lock (thieves), bashing
    it (strong fighters) or Knock (mages), not only with the key, and creatures look behind doors
    without any trace, as SCS does ("Können wir gerne alles so machen").
  - *Locked doors* (built 2026-11-03, `doors.way`): the cheapest way the creature has, its key first,
    then picking the lock when its Open Locks (STATS.IDS 26) reach the door's lock difficulty
    (`m_lockDifficulty`, 0 to 100; IESDP: picking "depends on points in the Open Locks skill"), then a
    ready spell that unlocks (opcode 125, Knock: it "only works on locks that can normally be picked",
    IESDP), then bashing. A lock of 100, or one whose difficulty cannot be read, is neither picked nor
    knocked open. The response puts the lock first: the walk, `PickLock`, `SpellRES` of the spell or
    `BashDoor` at `EEex_Target`, then `OpenDoor` and the walk on, one action a line; it is held while
    the creature picks, casts or bashes, 3 seconds longer than an open door. Bashing waits for the lock
    probe's numbers (IESDP gives no rule for it), so no creature bashes yet.
  - *Behind a door without a trace* (built 2026-11-03): with nothing to go on, a creature that saw an
    enemy or was hit within the last minute, in an area that is no outdoor one (its ARE header's area
    type), looks behind the nearest closed door it may open within 15 of where it stands, as SCS's
    door block does (`genai/ssl/chase.ssl`: in a fight, not outdoors, no enemy within 30, a closed door
    within 15). Where the area type cannot be read it does not.
  - *The lock probe* (`.work/stepD-lab`, phases `locks`, the SR lab, nothing installed) waits for a
    quiet PC: picking at difficulty 60 with Open Locks 30 and 100, and at 100; bashing at 60 by Strength
    9 and 18/00, and at 100, each watched for a minute; Knock cast at the door at 60 and at 100; and how
    the bindings name the area type.
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
- **A spot without a way there counts as searched** (E8 v4, 2026-11-04): Tarnesh, out of everyone's
  sight in a dead-end corridor whose mouth Kivan and Yeslick blocked, walked to the same clue every few
  ticks for twenty seconds, each `MoveToPoint` over at once. Now a search walk that ends by itself (it
  stopped walking, or its time ran out) no nearer its spot than `progress` (32) finds no way there:
  the spot counts as searched (a `blocked` row with move `search`), and the search goes on with the
  next clue, a look or giving up. One ended by an enemy in sight or a hit is no such sign.
- **Log.** Rows `hunt` (a search begins: clues, tactics, patience, guard, wit), `clue` (a hit),
  `search` and `return` (walks), `blocked` (a walk with no way), `teleport` and `landed`, `detect`,
  `reveal`, `door` and `door-end`, `gave-up` (why: patience, no clue, stuck) and `stuck`; `inspect()`
  has the search's counts.

Not built yet: buffing at the post after giving up, barks, and an ordered target's
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

In the third run (2026-10-28, build `0e15f77`; the second stopped at its first console command) the
watching PC was no longer exactly neutral (EA 129), so the balor's first blocks left it alone, and
each fiend fought a dummy of the party's side 400 away. With only its teleport left the glabrezu jumped at once (Teleport Without Error, worth 0.40),
and so did the balor (BGSETELE, worth 0.59): each stood 48 from the dummy 1.4 seconds into the fight
and hit it within two seconds more. With all its powers the glabrezu chose its Confusion first
(worth 0.61 against 0.36 for the jump), now the engine's own choice, then walked the 400 under the
casting pause (6 seconds left, the walk 3.4) and attacked. The direct casts again named every
teleport in the log, SCS's own forced one with its target, and BGSETELE came back 18.7 seconds
after its use and refused a cast in between.

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
- **Casters step away too** (E7, 2026-11-04; Christopher, 2026-11-03: mages step away from melee foes
  now and then, by wit; SCS's mages run from a foe within 8 for four seconds while their casting pause
  runs and they still have spells, [src] mage/ssl/meleeblocks/standard_mage.ssl, credit DavidW). A
  creature whose best choice is a cast that damage can break (a spell or ability with a casting time;
  not a potion or other item, a weapon, a strike or a release) kites as an archer does, without a
  missile weapon. The step is also worth that cast's score times how much less likely a melee hit
  breaks it once the step is over than where it stands: the chance one hit or more lands while it casts
  (Mirror Images and Stoneskin take hits first), the casting starting when the casting aura frees. A
  melee enemy that attacks the creature follows it a second late (`react`) at its own speed; the others
  stay where they are. While the casting aura runs a step gives up only the part of the best cast past
  the aura (the cast waits for the aura anyway) and the part of a round of a weapon attack, so casters
  step away in their casting pause as SCS's do. Not again within 18 seconds; clever always, normal when
  they notice, dull never. In the tests a mage of 200 hit points beside a fighter that attacks it (1.9
  hits a round) would lose its two-second bolt 47 times in 100 where it stands and 30 after the step (the
  fighter is back 0.86 seconds into the casting); against a slow bolt (six seconds) amid two fighters
  that attack someone else, 98 times in 100 and never after the step, so it steps away although the hits
  it keeps off are few. A `kite` row of a caster names the cast (`cast`) and the chances (`breaks`, here
  and after). To see in the lab: whether casters step away too often or too seldom (SCS's mages: every
  pause, from 8 away; ours from 6, at most every 18 seconds), and whether the party's fighters follow as
  the model says.
- **In game** (`adapters/eeex/choice.lua`): a weapon not in hand is `SelectWeaponAbility(slot,
  ability)` before `AttackOneRound`, held as any weapon attack; the `swing` row names the slot and
  `switches` counts them. An `arms` row logs the weapon in hand whenever it changes, with the
  tables' parts of its bonuses (`model`) beside the game's THAC0BONUSRIGHT and DAMAGEBONUSRIGHT
  (`game`). A step away is `MoveToPoint` to the first open spot of the step and its exits, held
  while the creature walks, like a way out of a zone, with a `kite` row and, once it is over, a
  `kited` row (where it ended, how close the nearest enemy it sees stands); `kites` and `kited`
  count them.
- **Blocked steps** (E8 v4, 2026-11-04). Tarnesh, cornered in the narrow lane by the Friendly Arm
  Inn (`BG2300`), stepped away north, into the inn's walls: the nearest open spot of the search map
  for that point lay 419 units east, in a dead-end corridor, and the walk there took him round the
  block for ten seconds and out of everyone's sight. Kivan and Yeslick, walking after him, ended up
  across a one-cell wall from him, and the fight timed out after two minutes. The nearest open spot
  can lie anywhere around an obstacle and says nothing of the way there (`learned.md`, section 5). Now
  a step away, a walk behind an enemy and a walk into position, whose worth was weighed for their own
  spot, take an open spot only within a weapon's reach of it (`snapSlack`, 64), else the next exit; with
  none, the move is blocked (a `blocked` row, why `snap`) and the engine decides again at once without
  it (the creature casts or shoots where it stands). A walk that after a second of walking has come
  nearer its spot by less than half a straight walk at its pace goes round something (`M.detour`) and
  ends there; one that ends by itself more than a weapon's reach from its spot, less than half the way
  nearer, falls short (`M.short`). Both block the move too (why `detour` or `short`, named in the
  `kited`, `positioned` or `flanked` row). The choice leaves a blocked move out for a round
  (`input.blocked`: kite, position, a flank by enemy). A walk into position cut by the casting aura, as
  planned, is no failure.

Tests: `arsenal` (5 groups, probe F's numbers), weapons groups 12 and 13, the choice adapter's group
35, 37 mutations checked. Casters (E7): weapons group 16, the choice adapter's group 16 (a mage behind
Stoneskin steps away in its casting pause), 21 mutations checked. Blocked steps: weapons group 13,
choice group 24, backstab group 5, the choice adapter's groups 35, 36 (a flank's walk counts from its
first step) and 40 (a walk into position cut by the aura), 25 mutations checked with the search fix
below.

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
- **SCS's free hide stayed SCS's** until F2f (below), which replaces it for thieves with their own
  skill (Christopher's answer 11 had been: powers a creature gives itself are its own abilities;
  above the hook stays SCS's, as listed at the top). It happens only while the thief sees
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
Harbinger of Pain +4. Since the classifier reads opcode 326 as IESDP describes it (SPELLS-01,
2026-10-27), the Dreadnought's critical hit stuns and hurts the creature it strikes when the
Dreadnought's own strength is high enough.

Tests: spells group 38, weapons group 14, defence group 13, `arsenal` group 6, the choice adapter's
group 37 (a brawler's critical hit spell from its own effects, at its level, with fists only); 57
mutations checked.

To see in a lab: that "self" in a critical hit spell is the attacker (Corinth's Bow's Luck on its
wielder); how often critical hits come with critical hit points; and whether a helmet keeps a
critical hit spell off as it keeps a critical hit's double damage off.

### F2f: thieves hide with their own skill (2026-10-27)

Christopher, 2026-10-27: SCS's free invisibility goes, thieves hide with the game's real Hide in
Shadows roll, and "der skill sollte natürlich dementsprechend auch hoch sein bei den
Dieben/Schurken". Monsters' free invisibility (fiends, mind flayers, the sirine) becomes real
innate abilities later (F2f-5), each as often as SCS gives it.

- **SCS's free invisibility** (read in the decompiled scripts; credit DavidW): its thieves cast
  `ApplySpellRES("dw#silin",Myself)` once when they are created (`OnCreation()`, whether they see the
  party or not; in its sight they also plan a backstab) and whenever they detect no enemy and no
  party member (`!Detect`: range and line of sight) and are not invisible already, blind or
  disabled. Fiends, mind flayers, djinn and the sirine have blocks
  of their own (`DEMPIT`, `ERINYES`, `SIRSPELL`, …); mages' contingencies give Improved Invisibility.
- **The installer** ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 9) has every block that gives
  free invisibility ask `BGSE_Hide` and stand aside while the engine hides the creature its own
  way, and raises SCS's thieves' skills: a creature with thief levels (CLASS.IDS 4, 9, 10, 13, 15)
  whose script slots name a script with such a block, and that no PDIALOG row names (no joinable
  NPC), gets Hide in Shadows and Move Silently of at least half of all the thief skill points a
  player of its class or kit has at its thief level, all a player could put into the two:
  (START_POINTS + LEVEL_POINTS × (level − 1)) / 2 by THIEFSKL.2DA, at most 255, never lowered.
  Christopher, 2026-10-27, on a quarter: "das ist glaube ich alles etwas low"; "gerne eher höher als
  niedriger", as high as a rogue could legally have it. Columns go by name; a kit's row by its
  KITLIST name. The game adds race and dexterity to these points (the hide probe below). In the
  Spell Revisions lab 239 creatures are raised, 6 have that much already, and 83 that carry such a
  script have no thief levels (fiends, mind flayers and others, which keep SCS's own); 17 reach 200
  in both before those bonuses. For example: level-9 thieves 120 each, assassins of level 20
  (`GORDECK5` and others) from 0 to 115, `ALATOS` (level 19) from 0 to 245, `CHALCY02` (level 25)
  from 140 and 100 to 255 each, a fighter/thief of thief level 1 (`CALAHA`) to 20. The difficulty
  leaves the skills alone and acts through wit (more clever thieves on Insane). Even so a thief is
  invisible less often than SCS made it: only out of sight, never when dull, and its roll can fail.
- **The engine's hide** (`combat-intent/stealth.lua`, `adapters/eeex/stealth.lua`): with no enemy in
  sight, once no zone hurts it and no friend in sight needs a heal or cure worth casting, a thief
  hides before it searches: `Hide()`, the game's own action, whose roll the game makes against the
  creature's skill as it does for a player. Who: thief levels and a Hide in Shadows skill above 0,
  not invisible already and not in the game's stealth mode. When, by wit: a clever thief always, a
  normal one when its stretch out of sight draws it (once, until it sees an enemy again), a dull one
  never; orders by creature file say always (`hide=true`) or never (`hide=false`), and labs switch it
  off with `mind.hide=false`. One try a round: six seconds after a try the next. A try is held while
  the creature runs `Hide()` (8 ticks until it starts) or stays in the stealth mode, until it is
  invisible and 45 ticks at most, and ends at once when an enemy shows or the creature is hurt. A
  `hide` row logs a try (skill, wit, draw, orders), a `hidden` row its end: whether the creature came
  out invisible, why it ended (`hidden`, `ended`, `limit`, `hurt`, `seen`), how long it took and what
  the game's own fields read (`m_nModalState`, `m_bHiding`, `m_modalCounter`, `m_nStealthGreyOut`,
  where EEex offers them). The hidden thief then searches, goes behind its enemy and stabs (F2d).
- **Who stands aside** (`api:hides`): SCS's plain free invisibility, for every creature the engine
  drives (as for its search) that can hide by its skill, whatever its wit: a dull thief no longer
  turns invisible at all. Since F2f-5 (below) also for every creature with an innate invisibility
  of its own. A creature off the engine's side, the engine switched off or an error: SCS's block
  runs.
- **One mode at a time:** a rogue hiding in shadows keeps its hide rather than switch to the Find
  Traps mode for its Detect Illusion.
- **Fixed on the way:** a rogue's Find Traps for its Detect Illusion never ran. The decision named
  the invisible enemy it was for as its target, and the check right before acting skipped it as
  unseen; the enemy is now only its aim.

Tests: `stealth` (4 groups), the choice adapter's group 38 (hide, hold, judge, the round's wait, the
stealth mode's limit, hurt, dull and ordered thieves, `BGSE_Hide`, the kept hide over Find Traps),
the hook adapter's group 9, `test_hook_rule.py` (the free invisibility rule and the skill formula)
and the installer test (fixture `B-HKTHF` and seven thief creatures: kits, a multiclass, THIEFSKL's
columns swapped, a joinable NPC, a fighter, a creature without such a script); 12 mutations checked.

The hide probe (2026-10-27, Spell Revisions lab, BD0072): six scriptless copies of the
level-10 thief `RETHIE01`, each with its own Hide in Shadows and Move Silently in the creature file,
12 tries each, every try a new creature 736 away from the PC and out of each other's sight.

- `Hide()` works for a creature outside the party. A success sets the stealth mode
  (`m_nModalState` 3) and STATE_INVISIBLE (0x10) within a tick, and the action ends after 3 ticks;
  a failed try ends with the mode at 0. In sight of an enemy it never hides (0 of 8 at 265/260).
- A failed try greys the creature's stealth out for a round: `m_nStealthGreyOut` reads 90 right
  after it and falls by one a tick (all 25 failed tries, 8 of them in the PC's sight, followed for
  33 ticks), 6 seconds at 15 ticks a second; a success leaves it at 0. The engine's own rule waits
  as long (one try a round).
- The creature file holds the points; the game adds race and dexterity to the derived stats
  `STEALTH` (27) and `HIDEINSHADOWS` (135): `RETHIE01`'s copies read 15 and 10 with 0 in the file.
- Both skills count, Move Silently more. In the game's numbers (Move Silently / Hide in Shadows):
  15/10 hid 3 of 12, 65/60 8 of 12, 15/110 8 of 12, 115/10 12 of 12, 115/110 and 265/260 12 of 12.
  Players report an average of the two with a malus in bright light and a bonus in shadow (Beamdog
  forum); a plain average would give 15/110 and 115/10 the same chance, which these counts make
  unlikely (12 of 12 at 62.5 per cent: 0.4 per cent). Light was not varied; whether bright light
  halves the skills (Christopher: 200 in both to hide in light without fail) is still to measure.
- A hidden thief walked up to the PC unseen (14 samples, the PC never saw it) and hit it; whether
  that hit was a backstab stays open (3 hit points from behind, 11 from the front, at 12).

The second hide probe (lab batch K, 2026-10-29, the same lab and area; scriptless copies standing
in spots of known light, by the luminance of BD0072's light map: dark 35, mid 124, lit 188, bright
239; 8 to 20 tries each), cleaned up after:

- **Light** lowers the chance a lot. At 65/60 (Move Silently / Hide in Shadows, the game's
  numbers): dark 14 of 16, mid 9 of 16, lit 5 of 12, bright 5 of 16.
- **Skill** wins in bright light: 65/60 hid 5 of 16, 115/110 9 of 12, 215/210 12 of 12, as
  Christopher said (200 in both to hide in light without fail).
- **Armour** showed nothing at 115/110 in the dark: leather 8 of 8, chain mail and plate 12 of 12
  each, and the game's skills read 115/110 in all three, so these creatures lose nothing for armour,
  at least at that skill and light.
- **The grey-out does not stop a scripted try.** Each of 6 failed tries was followed at once by a
  second `Hide()`, 86 ticks of grey-out still to run, and all 6 hid. The engine keeps its one try a
  round: a player's button stays greyed out that long (play fair).
- **Classes** in the dark at 65/60: thief 14 of 16, ranger 7 of 12, monk 8 of 12, shadowdancer 10
  of 12.
- **In sight:** a thief of 215/210 never hid in the PC's sight (0 of 4); a shadowdancer of the same
  skill hid every time (8 of 8: Hide in Plain Sight).

For the engine: its thieves hide only out of sight, which fits. Not used yet: a shadowdancer could
hide in sight, and a clever thief could step into shadow first (for Christopher to decide).

### A new decision replaces the engine's own running action (2026-10-28)

In the lab of mixed fights (lab batch I, fight `f1-own-2`) a glabrezu chose to teleport and never
did. When a member of the lab's party died (blown apart), its four attackers, the glabrezu among
them, kept attacking the body for 17 to 90 seconds. Meanwhile the engine decided again and again,
and none of it happened.

- **Why.** The game leaves the actions a script block queued running while that same block stays
  true, and runs its response again only once the creature has nothing left to do; any other block
  that fires interrupts them. The hook is one block, so its new decisions waited for the engine's
  own attack to end. The engine also held a weapon attack on a dead target for up to two rounds.
- **The probe** (lab step W, 2026-10-27, Spell Revisions lab, BD0072, 11 phases, cleaned up after):
  the game records the block that queued a creature's actions (`m_curScriptNum`,
  `m_curResponseSetNum`, `m_curResponseNum`: 0, 1, 1 for an override script's first block, -1 each
  when the creature is idle). A second decision of the same block waited 80 ticks for the running
  attack to end. With the response set number cleared in the claim, the game replaced the running
  walk or attack within a tick; a second block that fired did the same, and so did clearing the
  actions with NoAction as the current one, which skips the game's own interrupt rules. 10 dummies
  killed under such an attack (4 normal deaths, 6 blown apart) ended it 1–2 ticks later, so what
  kept lab batch I's attacks going is still unknown; the fix does not depend on it. AttackOneRound counts its walk toward its
  round: an attack on a dummy 590 pixels away walked for 80 ticks and ended 13 ticks after
  arriving, the dummy unhurt.
- **What the engine does now.** A claim names its kind: a decision, a hold (the running action goes
  on) or an idle hold (a wait or a look around: the creature stands still). For a decision or an
  idle hold the hook adapter (`adapters/eeex/hook.lua`) clears the response set number while the
  actions the hook's last response queued still run as queued, and the game interrupts them by its
  own rules in the same pass. Never for a plain hold, nor for a claim whose kind went missing (lab
  batch J's first run wrapped the gate and passed on its first answer only: every hold then stopped
  the engine's own attack, and its fighters stood idle most of each round), and never when anything
  else sits in the creature's queue (a story's action behind the engine's), when another block's
  actions run, after a load, or when the response ran outside a script block. The choice ends a weapon or touch
  attack's hold as soon as its target dies; a charge still in hand goes to the next choice.
- **Log.** A `replace` row (the action that gave way, the actions left of it, the claim's kind),
  `replaced` in the choice's counts, and the hook's own count with its errors (`inspect().replaced`).
- **Fixed on the way:** a creature that decided to leave a danger zone while its search walk ran
  waited for the walk to end; it leaves at once now. A wait decided while an old attack still ran
  let the attack go on; the creature waits now.

Tests: the gate's group 19, the hook adapter's group 10 (decision, hold, idle, two actions, a story's
action behind them, another block, a load, a response outside a block, errors, at most 1,024
creatures' records), the choice adapter's groups 3 and 33 (waits and looks are idle holds) and its
dead-target case; 12 mutations checked.
Still to see in game: the fix inside whole fights.

### F2f-5: monsters' free invisibility becomes real abilities (2026-10-28)

Christopher, 2026-10-27: SCS's script-only powers become real, named innate abilities the player can
see, as often as SCS gives them, with a cooldown that recharges by itself or charges; gameplay
numbers are his. Agreed per creature: the fiends' invisibility out of sight comes back after a round;
mind flayers turn invisible out of sight only; Pit Fiends and Bone Fiends get no escape and cast
their real Improved Invisibility in fights; the Maurezhi gets Improved Invisibility and Blur about
once per 1,000 seconds, the sirine one charge per rest, the shadow dragons a real recharge and
Illasera five charges. Mages keep their contingency invisibility and Mislead (SCS's preparation).
The Erinyes' withdrawal moves to a later step ("disengage").

- **SCS's blocks** (decompiled scripts of the Spell Revisions lab, credit DavidW): fiends (`DEMPIT`,
  `DW#BONEF`, `ERINYES`, `KARASH`, `TELPIT1`, `DEMMAU01`, `OBSDEM04`) cast `DW#SILIN` whenever they
  see no enemy and are not invisible; mind flayers (`FLAYER01`, `FLAYER02`, `FLAYUN`) `DW#ILLIN`, SCS's
  copy of the game's Psionic Superior Invisibility, the same way; the Maurezhi Improved Invisibility
  and Blur when it sees an enemy, every 1,000 seconds; shadow dragons their Create Shadows whenever
  they are not invisible; Illasera Ethereal in sight of a PC, five times; the sirine Invisibility once;
  the brown dragon (`DRAGBROW`) Invisibility and Non-Detection near its enemy, six times. SCS's Pit
  Fiend block for Improved Invisibility checks `SPWI405`, which Pit Fiends lack: it never fires.
- **The installer** ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 10) gives each such creature
  those spells as innate abilities (gifts), as often as the block fires: Invisibility back after a
  round for fiends (`BGW20606`), Improved Invisibility and Blur back after 1,000 seconds for the
  Maurezhi, Improved Invisibility back after a round for vampiric illithids, Create Shadows back
  after a round for shadow dragons, Ethereal five times for Illasera, Invisibility once for the
  sirines. Not a thief (it hides by its skill), not a kind of invisibility the creature has an innate
  ability of its own for, nothing for a joinable NPC. In the Spell Revisions lab 33 creatures.
- **The game's own innates** these creatures carry (host run of the classifier on both labs' files):
  Pit Fiends' and the Bone Fiend's Improved Invisibility (`SPIN137` with Spell Revisions, `SPIN129`
  without) and the Erinyes' Invisibility (`SPIN167`, `SPIN147`) remove and give themselves back at
  once (opcodes 172 and 171), so they never run out; the mind flayers' Psionic Superior
  Invisibility (`SPIN544`) comes back after 12 seconds.
- **When an ability comes back** (`combat-intent/spells.lua`, `recharge`): a 171 that gives the
  spell itself back to its caster, at once (0) or delayed by its duration; nil when it is spent until
  the creature rests.
- **The engine's veil** (`combat-intent/stealth.lua`, `adapters/eeex/stealth.lua`): a creature that
  cannot hide by its skill and sees no enemy, once no zone hurts it and no friend in sight needs a
  heal or cure, casts an innate invisibility it has ready at itself (`SpellRES(…,Myself)`), with the
  game's normal casting time, like the engine's other casts. Which: what its effects do counts (an
  opcode 20 on the creature it is cast at, aimed at itself or a creature), plain before improved,
  plain whatever its charges (it lasts until the creature acts), improved only when it comes back
  within 60 seconds (`veilRecharge`): a vampiric illithid's after a round and a mind flayer's after
  12 seconds veil, the Maurezhi's after 1,000 seconds and Illasera's five charges stay for the
  fight, where the choice weighs them as defences. One that comes back before one that is spent,
  the sooner the better, then the faster cast. Wit, orders and one try a round as for the hide.
  Right before it is queued: a creature that turned invisible meanwhile needs none. A `veil` row
  logs it (spell, kind, recharge, wit, draw, orders), a `veiled` row two seconds after the cast
  whether the creature is invisible.
- **Who stands aside** (`api:hides`, for a creature the engine drives, whatever its wit): SCS's plain
  free invisibility when it can hide by its skill or has an innate invisibility it may veil itself
  with; SCS's improved one when it has an improved innate invisibility. One it used counts while it
  comes back: its 171 waits in the creature's timed effects with the live timing 7 (6 for a delayed
  limited one) until its delay is over. Without that, SCS's Maurezhi block, whose timer never ran,
  would give a free Improved Invisibility right after the creature's real one. Asked once a tick per
  creature at most.

In the two labs the engine sees the gifts as meant (host run of `combat-intent/stealth.lua` on the
copies as the installer makes them): `BGW20606` plain, back after 6 seconds, veils; `BGW405RS`
improved, back after 1,000 seconds, no veil; `BGW40506` and Create Shadows' `BGN68706` improved,
back after 6 seconds, veil; `BGW20600` plain with charges, veils; `ILLAINV` improved with charges, no
veil; Blur and Non-Detection no invisibility.

Tests: `spells` group 40 (recharge), `stealth` groups 5 to 7 (kind, the creature's veils, the pick,
the decision), the choice adapter's group 39 (the veil cast, held and judged, the recharge counting
for `BGSE_Hide`, no second cast while invisible, the 1,000-second Improved Invisibility kept for the
fight, a vampiric illithid's veil, a lost cast and the round after it, a thief, dull and ordered
fiends, the check before it is queued, `BGSE_Hide` for each kind) and the installer test of HOOK-01
rule 10; 24 mutations checked.
Still to see in game: the copies' recharge (172 and the delayed 171 after a real cast), the
delayed 171 in the timed effects after a cast as after `EEex_GameObject_ApplyEffect`, and fiends
veiling themselves in whole fights.

### Positioning in the casting pause (2026-10-28)

Christopher, 2026-10-25: casters use the casting pause to walk into position, by wit (clever
always, normal sometimes, dull never). With it one walk rule for heals and attacks.

- **When** (`combat-intent/choice.lua`, `M.position`): while the casting aura of the last cast runs
  and the cast the creature will make once it frees needs a walk into range (R3 above), the
  creature walks toward the spot it will cast from meanwhile: straight toward its aim, for the
  seconds until the aura frees less half a second (`auraLead`), never past that spot. Only for the
  cast it will make: one worth the minimum and more than its best attack, or worth something when
  no attack is worth making. A mage whose weapon would kill an enemy next to it walks nowhere for a
  bolt at an enemy far away; it swings.
- **Never into melee:** of the whole way, three quarters, half or a quarter, the longest that ends
  where no enemy's melee weapon reaches (`weapons.meleeAt`); none shorter than 16 (a tenth of a
  second's walk).
- **Worth:** what the cast gains as its walk shrinks (6 / (6 + walk left) against 6 / (6 + walk), on
  the cast's worth before its walk lowered it), and what standing there is worth in danger zones.
  A bolt of range 480 at an enemy 600 away needs a walk of 1.2 seconds; with 4 seconds of aura left
  the mage walks all of it meanwhile, worth the sixth of the bolt the walk would have cost, and casts
  without a walk once the aura frees. With 1 second left it walks half a second of it.
- **Against an attack meanwhile:** the walk when it is worth more than the attack (the attack's
  worth less the part of the best cast it holds back, as before), else the attack, else the wait.
- **Wit:** a tactic (`M.tactical`). A normal creature draws once a decision whether it notices, and
  only when there is something to notice: the aura runs, it can walk, and an enemy or ally it sees
  stands beyond the range of one of its ready spells cast at a creature or a point.
- **The adapter** walks it there (`MoveToPoint` to the nearest open spot by the point) and holds the
  walk until the aura is about to free; then the next decision, mostly the cast, replaces the walk
  ("A new decision replaces the engine's own running action" above). A walk over sooner ends the
  hold too. Log: the choice row (`castKind` `position`, the cast it walks for, toward whom, the
  aura), a `position` row (from, to, cast, toward) and a `positioned` row (where it ended, how long
  it took, how near the nearest enemy stands). A wait in the casting pause names why no walk came of
  it (`positioning`: `unnoticed`, `melee`, `short`, `no-aim`, `no-worth`). Counts: `positions`,
  `positioned`.
- **One walk rule for heals and cures** (`combat-intent/care.lua`): a walk to a friend comes first and
  lowers the worth as for an attack (6 / (6 + seconds), at the caster's pace, `weapons.speed`), and a
  friend that falls during the walk and the casting gains nothing. Until now the walk cost as
  casting time did, a much smaller cost. A caster that cannot walk reaches no friend beyond its
  range. So a priest walks toward the friend it will heal in the casting pause, too.

Tests: the choice's group 24 (the whole walk and half of it, the cast at the aura's end, the melee
guard, wit and draws, nothing to notice, the cast it will make against a swing, short, aimless,
rooted, a heal), the care's group 3 (the paced walk, a rooted caster, a friend that falls during
the walk), `weapons` (the pace), and the choice adapter's group 40 (the walk, its hold until the
aura's end, the cast after it, a walk over sooner, a dull mage's wait row) and group 30 (a cast
broken off after its walk: the pause now walks); 23 mutations checked.
Still to see in game: walks in the casting pause in whole fights, where the game's path ends, and
the cast replacing the walk at once.

### Prebuffs, phase 1 (2026-10-28)

Christopher, 2026-10-28: "Erste Phase könnte ja sein, dass wir genau die Prebuffs übernehmen, wie SCS
sie macht (außer eben, dass AOE spells wirklich als AOE spells gecastet werden) und dann später bauen
wir Dinge um". Contingencies and sequencers come along.

- **SCS's blueprint** (decompiled scripts of both labs, credit DavidW): while `instantprep` is still 0
  and the creature sees an enemy (or SCS prepares it out of sight), a mage or priest script casts its
  prebuffs at once: SCS's helper copy of a memorized protection at itself
  (`ReallyForceSpellRES("dwsw212",Myself)` for Mirror Image), then the memorized spell is spent
  (`RemoveSpell`). On SCS's harder preparation settings some come free (Stoneskin, `DWSW408`) or from
  a high-level ability. Contingencies and sequencers fire once (`ContingencyFired`), chain
  contingencies at the party (`ChainContingencyFired`). Then a first-round cast at itself with the
  normal casting time (Moment of Prescience, Protection from Magic Weapons, Mantle, …) sets
  `instantprep` to 1; without one a plain block sets it, on most settings. Free prebuffs have no check of their own:
  they fire once because `instantprep` turns 1 in the same pass.
- **Phase 1** ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 11): all of it runs as SCS has it, but
  each block asks the engine first (`BGSE_Prep`) and tells it what ran (`BGSE_Prepped`). The
  first-round cast alone is the engine's: since the engine owns the whole round (2026-10-25), it holds
  that cast for a creature it drives and chooses the first round itself. A twin block after the cast
  still ends SCS's preparation as the cast would have (`instantprep` 1 and SCS's `redefend` timer, no
  cast). Without it SCS's preparation could stay open: SCS's own end of it leaves out some of its
  settings, and then a free Stoneskin would come back on every script pass.
- **Orders** (`combat-intent/orders.lua`, `combat-intent/prep.lua`): `prep = false` holds back all of
  a creature's preparation; `prepSkip` holds back what it names, a kind (`prebuff`, `contingency`,
  `chain`, `opener`) or a spell as SCS's blocks write it, the cast (`DWSW408`) or the spell spent
  (`WIZARD_STONE_SKIN`), in any case. Names SCS left unfilled reach the engine as ''.
- **Area buffs:** SCS's prebuffed Haste (`DWSW305`) keeps Haste's area projectile, which reaches the
  caster's allies, in both labs; Improved Haste (`DWSW613`) does with Spell Revisions, where it is an
  area spell (without it is single-target). So they already reach allies nearby. What "AoE as AoE"
  should add beyond that is for Christopher to decide (phase 2).
- **Log:** a `prep` row with `held` true once per creature, kind and spell the engine holds back, and
  one with `held` false for each block that ran, with kind, cast and spell spent. Counts: `prepHolds`,
  `preps`.

Tests: `prep` (3 groups), the choice adapter's group 41 (openers held, the rest run, the side and
switch, orders), the hook adapter's group 9 (the driver, a failing choice runs SCS's block), the hook
rule's tests (every kind, notices before a closing `Continue()`, the twin, below the anchor) and the
installer test with its preparation script `B-HKPRP` (its first-round cast has two responses); both
labs agree byte for byte, twins included; 16 mutations checked.
Still to see in game: the `prep` rows, the engine's first round right after a held first-round
cast, the prebuffed Haste reaching allies, and SCS's long conditions in compiled scripts.

### Disengage: SCS's blueprint (2026-10-28, nothing built)

Step 5 of the order agreed on 2026-10-27; the gameplay design is Christopher's. Read in SCS 35.21's
source (credit DavidW) and the SR lab's spell files:

- **Out of melee:** the Erinyes, an archer, jumps with its Teleport Without Error (`SPIN159`, a real
  innate that moves its caster to the target) next to an enemy farther than 15 when one stands within
  8, at most every 12 seconds (`fiend/ssl/erinyes.ssl`); invisible, it runs from an enemy within 15.
  Other fiends, mind flayers and phase spiders teleport only toward enemies, as the engine's fight
  jumps do. No mage script escapes melee: SCS's Dimension Doors chase enemies, and Mislead is a
  prebuff.
- **Badly hurt:** below a quarter of its hit points and in sight of an enemy, the Erinyes casts
  `DRYAD_TELEPORT` (`SPWI995`) at itself by script (`ForceSpell`): a glow, and opcode 68 removes it
  from the game 2 seconds later. The party gets neither experience nor loot, and nothing brings it
  back. Ascension's allies of Melissan (`ascension/ssl/fin*.ssl`) leave the same way below 15 %, once,
  and only while their nearest enemy has more than a fifth of its hit points left; there Balors and
  succubi destroy themselves (`DestroySelf`). No difficulty setting gates any of it.
- **Rest:** a creature with SCS's `lib/ssl/common_rest.ssl` (fiends, mind flayers, dragons, the
  Shade Lord and others) that has detected no enemy for 2,400 game seconds (8 game hours, 40
  minutes of play) heals to full by script (`SPIN746`, poison and disease too) and rests.
- **Summons** go back to their summoner when no enemy is in sight and the summoner is farther than
  30: fiends by a free Teleport (`ReallyForceSpell`), others on foot.
- **Morale:** SCS sets none; it reads panic only to choose targets (beholders, Melissan). Fear and
  panic come from the game's own morale and from spells.
- **Story exits** at low hit points (Bodhi's and Abazigal's dialogues, a dragon turning neutral)
  belong to their encounters, not to this step.

Christopher's answers (2026-10-28):

- **Badly hurt:** nobody leaves for good, or almost nobody (later we may look for the rare creature
  where it makes sense); he finds the vanishing Erinyes and Melissan's allies dumb. Being gone long
  is bad too; a short retreat is fine.
- **Escaping melee with own spells:** not every caster, only chosen encounters or creatures. A
  Dimension Door or the like would be cool, but buys little when the attacker is much faster than
  the mage. Mislead is too buggy for more uses: it stays in the mages' preparation, where SCS puts
  it up before a fight, and gets no new ones (no escape); fixing Mislead itself may come later.
- **Morale:** dull creatures may run, for example when their leader falls, but thin and rare, as
  running enemies annoy.

Settled by his rules: real, visible abilities only (no free teleports), and every tactic by wit.

Christopher, 2026-10-29, on whether a badly hurt clever creature should step out of melee, heal
and come back: mostly not. A potion is "quasi nur ein paar Millisekunden", so a creature with a
healing potion drinks it in the fight and need not run; no big focus on enemies going far away.
Rare cases he would like, case by case: a clever foe that flees a bit more cleverly, priests that
keep their fighters alive (strong fighters, or priests of a helpful kind). Too many fleeing
enemies are no fun, and the AI need not always be as clever as the player or cleverer.

So: no general retreat to heal; a hurt creature heals where it stands (its potion, its own spell,
a priest's heal, as the engine does already). SCS's vanishing exits end under "nobody leaves for
good": the Erinyes, Melissan's allies, and the mind flayer's escape (`DW#MFESC`, cast by SCS's
script above the hook; lab batch J, runs 3 and 4, below). Retreats and escapes only for creatures
or encounters chosen with Christopher.

Built 2026-10-30 ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 12): SCS's vanishing exits wait
while the engine drives the creature. Badly hurt, the Erinyes, Melissan's alu-fiend, Balor and
succubus and the mind flayers fight on; they heal where they stand as far as they can, as everyone
else does. A fight's designer lets a chosen creature leave as SCS has it with `leave = true` in its
orders. Story exits stay theirs: Demogorgon's death scene, the silver dragon's exit in its lair,
Abazigal's. Not seen in game yet; the next lab batch with Erinyes or mind flayers shows it.

Built 2026-11-03 (Christopher: "jo"): the same kind of exit in the game's own scripts above SCS's
waits too, when only the creature's hit points and what it sees decide it. The Pirate Mage (`PPMAG01`,
Dryad Teleport below 20 hit points), the Hobgoblin Wizard in the Unseeing Eye's lair (`GPFLEE01`, below
15 hit points with an enemy in sight) and the Nymph (`HGNYMPH`, below a quarter) fight on while the
engine drives them. Terminsel (his own `Death` variable) and Lady Yuth (once she has stolen from the
party) keep their story exits. The install takes a few seconds longer: it looks through the game's own
scripts for such exits ([HOOK-01](HOOK-01-scs-hook-placement.md), rule 12).

### Lab batch J: whole fights with a mirror party (2026-10-28)

The big lab round of step 3 (Spell Revisions lab, cleaned up after). Two groups fought the lab's
party of seven, which plays like a simple human player (everyone drinks the buff potions it carries
at the start, the mage and priest cast their spells by their real areas): j1, the party's mirror (a
fighter with potions, a kensai, an archer, a thief, an assassin, a mage and a priest), and j2, a
glabrezu, a greater werewolf, that fighter, a bone fiend, an erinyes and a mind flayer. Each fought
under the engine (`own`) and under SCS alone (`scs`).

- **Result:** under SCS the groups won all 7 fights (j1 in 47 to 72 seconds without a loss). Under
  the engine j1 lost 3 of 4 and ran out of time once with both sides nearly dead; j2 was ahead in all
  3 (57 to 68 per cent of its hit points left, the party at 4 to 13) but did not finish them in 240
  seconds.
- **Why j2 did not finish (run 2).** In all three fights the party's last members were not beaten but
  taken out of the fight: by the mind flayer's Maze (`SPIN774`, 9 of 11 casts hit; a creature of the
  party's intelligence, 9 to 11, stays 4d4 rounds in the maze, here about 65 to 95 seconds) and by
  the erinyes' Charm (`SPIN558`, 120 seconds; the charmed thief stood among the group as its ally).
  The group then hunted the missing enemy as if it were hiding: the mazed one as vanished, walking and
  teleporting to its spot (the mind flayer and the bone fiend in j2-own-2), the charmed one as last
  seen (39 search rows and a teleport on the thief in j2-own-1 while he was charmed, in sight). After
  its patience (30 seconds for the clever)
  it gave up, and SCS's own blocks went on below the hook: they attacked the lab's watcher, the
  player character the lab makes unkillable and neutral, as SCS's groups do in the SCS fights from
  the start. The mazed or charmed party member came back only near the time limit. A lab defect
  beside it: the party bot went on ordering the charmed thief to attack (196 orders, which the game
  overrode).
- **What SCS does with a charmed party member** ([src] genai/ssl/move.ssl and shoot.ssl, ssl/
  library.slb, credit DavidW): its target blocks take only creatures not on its own side
  (`!Allegiance(target,ENEMY)`) and not disabled, so a party member it charmed (EA ENEMY) is
  skipped; only its last blocks, when no good target is near, attack any party member (Player1 to
  6), charmed or confused, and then anything hostile. The lab's watcher is Player1, hence SCS's
  attacks on it.
- **The rules text and the game.** Charm Person and Dire Charm break when the caster harms the
  charmed creature, and Dispel Magic ends them (the game's descriptions with Spell Revisions, as in
  AD&D 2e); Domination allows no release. The game (opcode 5, types 0 to 3; Domination is type
  1003) ends a charm only when the good side (GOODCUTOFF) attacks the charmed creature: the party
  frees a friend it hits, but a group that hits a party member it charmed keeps it charmed, so SCS's
  last blocks work.
- **Christopher's answer (2026-10-29):** play by the rules text. A creature never attacks a foe its
  side charmed, nobody hunts it, and it is an enemy again once the charm ends; no change to the
  game's charm rule. A mazed foe is not searched: clever creatures guard its spot at a distance,
  heal and re-buff and strike when it comes back, normal ones wait at their post and heal, dull ones
  forget it. The engine owns those waiting rounds, so SCS's last blocks do not run. Built since
  (below, "Foes out of play").
- **Standing idle after an interruption.** A block of SCS's above the hook that fires (a call for
  help, `Shout(151)`, or one of its timers, with `Continue()`) interrupts the engine's running attack,
  as the game interrupts any block's actions. The hook's hold then queued nothing, so the creature
  stood until its next decision. Of 2,361 holds in the 7 fights, the hook's response ran 448 times:
  75 times it had just cut the engine's action short (mostly an attack; 51 times with SCS's blocks
  firing in the same pass), 373 times the action was already over; each time the creature stood a
  median 32 ticks (two seconds). The hook block also cut the engine's own attack by itself, 19
  times, each time an attack queued in a pass in which a call for help had fired (never one queued
  in a pass without: 1,876 holds); why is open.
- **Potions at the start.** SCS's fighters drink their buff potions at once (Oil of Speed, giant
  strength, at tick 15); the engine's fighter drank its Oil of Speed after 14 seconds, the kensai
  never. The party drank its own at the start, so the engine's fighters met hasted, stronger enemies.
  Fixed since (below, "Buffs over the rest of the fight").
- **What the engine does now.** The game runs a block's response only once that block's actions are
  over or another block interrupted them, so a plain hold whose response runs finds the action it held
  gone. The gate then lets the choice answer with a new decision (kernel/hook.lua, `renewed`), and the
  choice ends its record of the cut action (its outcome judged as when it ends: a queued cast that
  never started is lost) with a `cut` row and decides again at once, in the same response
  (adapters/eeex/choice.lua). Waits, looks around and a thief's stealth mode are idle holds, whose
  response runs while the creature stands still on purpose; they cut nothing. Under SCS's own scripts
  the same calls for help interrupt SCS's attacks, and SCS's attack blocks below queue them again in
  the same pass.
- **Log:** a `cut` row (what ended: `queued`, `cast`, `attack`, `strike`, `move`, `search`, `hide`),
  a `lost` row with `cut` for a queued cast, the choice's `cut` count and the gate's `renewed` count.

Tests: the gate's group 20 (a decision answered for a plain hold is performed once; an idle hold, a
hold and answers that are no decision change nothing; a renewed decision that no longer fits is
skipped), the choice adapter's group 42 (an attack cut by a block above the hook, one ended early, a
queued cast cut before it started, a wait's response), the search's look and the thief's stealth mode
as idle holds (groups 33 and 38); 9 mutations checked.
Seen in game: batch J, run 3 (below), 122 new decisions after 127 cuts.

### Buffs over the rest of the fight (lab batch J's potions, 2026-10-28)

Why the engine's fighters drank late (batch J's log, j1 at 5 seconds): the fighter's Oil of Speed
counted three rounds, the horizon protections use, though it lasts 300 seconds. Worth 0.17, it stayed
below the minimum (0.2) at which a fighter leaves its weapon for something else, so the fighter
walked up and swung (0.07). Its Potion of Fire Giant Strength counted nothing: a strength a potion
sets (opcode 44, type 1) was no gain at all.

What the engine does now (`combat-intent/defence.lua`, `spells.lua`, `arsenal.lua`):

- **Over the rest of the fight.** What a buff adds to attacks counts for the time the fight probably
  still lasts (`threat.rest`: until the faster side would have killed the other, at most the
  profile's `fightCap`, 60 seconds), cut by the buff's duration, as summons count since 2026-10-22
  ("an early summons counts much and a late one little"). At the start of a long fight both potions
  count ten rounds; with the enemy nearly dead, two. Protections keep the 18-second horizon: they
  count the harm they save while it comes.
- **Strength by the game's tables.** The classifier records what a spell sets (`strengthSet`: a
  buff's highest, a debuff's lowest), adds or takes; the worth goes through STRMOD and, at 18,
  STRMODEX, the installed ones when the adapter reads them, else the game's shipped values. Only a
  weapon that takes strength's bonuses gains (`strengthHit`, `strengthDamage`), and a creature
  stronger already loses by a lower set. A percentage and Bull's Strength (type 3, a bonus by class
  from CLSSPLAB) count by their sign only. Exceptional strength (opcode 97) is a stat of its own.
- **Haste once.** A haste the creature has already adds nothing; an improved one over a normal one
  adds what doubling the attacks before it brings; a weak haste (opcode 16, type 2) only hastens the
  legs.
- **What a potion takes** from its drinker (its own debuff role) counts against it, strength too.
- Unchanged: a buff for attacks counts only with an enemy within a round's walk, so a fighter drinks
  as the enemy comes, not at first sight across the area.

Example (the defence tests' group 14): a fighter of 18/50 with a sword of 10 a hit swings twice a
round at 0.75 against an enemy of 300 hit points. Oil of Speed adds a swing, 7.5 a round: over ten
rounds a quarter of the enemy. The Potion of Fire Giant Strength (22: 4 to hit and 10 damage instead
of 1 and 3) hits at 0.9 for 17, 15.6 more a round. With the enemy at 30 both count two rounds, and
the swing wins.

Not valued yet: Bull's Strength's real bonus; dispelling an enemy's giant strength (the removal
compares the potion's set with the strength the enemy has now, which the potion already raised).

Tests: the defence tests' group 14, the classifier's strength and haste group, the arsenal's group 7,
the choice adapter's group 43 (a fighter's strength and its sword's flags from the game's stats to
the choice, `UseItem` before the first swing, the installed table against another); 24 mutations
checked.
Seen in game: batch J, run 3 (below): the giant strength potion at the start of every fight; Oil of
Speed still late.

### Foes out of play: charmed and mazed (Christopher's answer, 2026-10-29)

What the engine does now (`combat-intent/director.lua`, `search.lua`, `threat.lua`, `orders.lua`;
`adapters/eeex/sense.lua`, `director.lua`, `search.lua`, `choice.lua`):

- **A charmed foe.** One the group charmed stands among its allies (EA ENEMY, in the charmed state):
  an ally the group has seen as an enemy, or a party member. The director takes it out of the
  picture (no clue, no focus); its side never attacks it, as it is no enemy, and the area spells that
  spare allies spare it, since harming it would break the charm by the rules text. It is no friend
  either: nobody heals, cures or buffs it, and it counts for nothing in the fight's balance. Once the
  charm ends it is an enemy again.
- **A mazed foe.** An enemy no member has seen for a second is looked up by id. Maze (opcode 213)
  stays in its effect list until the delayed opcode 212 it applies ends it, and its object stays
  where it vanished, out of every area search (IESDP; lab batch J). The director holds it there until
  the maze ends; out again but still unseen, it is a fresh sighting where it vanished, which the
  search follows. Imprisonment (opcode 211) lasts until the party frees it, which no waiting brings
  about: the picture forgets the foe at once (Christopher, 2026-10-29: "Ja"; something cleverer
  later, in peace).
- **Awaiting by wit.** A foe out of play is no clue. When nothing else is left to search, the search
  awaits the nearest one instead of giving the round back to SCS. A clever creature walks to a place
  by the foe's spot, 96 away (fighters and monsters: a step from striking) or 240 (casters), on the
  side it comes from and turned around the spot so that the group's guards stand apart, and looks out
  there. A normal one walks back to its post and waits; a dull one stands where it is. A boss that
  guards its post guards only a foe near it. A designer's orders can set it per creature (`await`:
  `guard`, `post` or `stand`). Healing goes on as without an enemy in sight, for real friends only.
- **No hand-over.** While a foe is out of play the engine owns the creature's rounds, also after it
  gave up a search and when its way back to its post is stuck, so SCS's last blocks (which attack the
  party, a charmed member too) never run. A record lapses when the director has neither seen nor
  checked the foe for 30 seconds, any after 5 minutes.
- **Log:** the director's `away` row (`charm`, `maze` or `prison`), `back`, `away-end` (why `unseen`,
  `await` or `gone`) and the focus row's why `away`; the search's `await` row (target, how, wit) once
  for each new way of awaiting and its `guard` walks; counts `awaits`, `guardWalks` and the director
  adapter's `removalChecks`.

Example: the mind flayer mazes the party's thief. A clever fighter of the group walks to a place 96
from the spot where the thief vanished and waits there, the mind flayer itself 240 off; a normal one
goes back to where its fight began, a dull one stands. When the thief comes out about a minute later,
the clever fighter strikes at once.

Built since: re-buffing while awaiting (below, "Readiness") and the reverse case, a member of the
group the party charmed (below, "Freeing a member the party charmed").

Tests: the search's group 11, the director's group 12, the director adapter's group 10, the choice
adapter's group 32 (guard walks, `await` rows, a place in a danger zone, the dull, an order to the
post, a stuck way back, two guards apart; whole claims with a mazed and a charmed foe), the orders
check and the defence tests' group 1 (a charmed ally is no friend); 33 mutations checked.
Seen in game: batch J, run 3 (below).

### Lab batch J, run 3 (2026-10-29)

The same 14 fights with the build of bdae67e (a cut hold decides anew, buffs over the rest of the
fight, foes out of play), in the Spell Revisions lab, cleaned up after.

- **Result.** j1: the engine's group won 3 of 4 (186, 131 and 193 seconds; in run 2 none); the
  fourth ran out of time with only the party's mage left (4 per cent of the party's hit points) and
  the group at 77 per cent. SCS won 3 of 4 too, faster (55, 60 and 138 seconds) and with more left
  (86, 78 and 93 per cent of its hit points against the engine's 59, 21 and 34); its fourth ran out
  of time as well, the party's thief alive. j2: SCS won all 3 (86 to 126 seconds); the engine won 1
  (57 seconds) and ran out of time twice, again ahead (58 and 67 per cent left, the party at 4 and
  8).
- **What works.** A hold whose response ran decided anew 122 times (127 cuts). The group's fighter
  drank its Potion of Fire Giant Strength at the start of every fight (0.4 seconds). No one attacked
  or hunted a foe the group had charmed, and the group awaited the charmed and mazed ones (56 `await`
  rows) instead of letting SCS's last blocks run.
- **Why j2 ran out of time again.** The group's casters charmed or mazed the party's last members
  anew each time it ended. In j2-own-1 the mind flayer mazed the assassin at 1, 56 and 86 seconds,
  and the erinyes charmed the archer at 57 seconds and, once he was the last of the party, again at
  178, so he stood charmed until the time ran out; in j2-own-3 the erinyes charmed the mage, the last
  one, at 79 and 201 seconds. Our side never harms a foe it charmed and no one reaches a mazed one, so
  a charm or a maze on the last foe in play only postpones the fight.
- **Why the priest stood.** The group's priest chose a heal at its own invisible thief or assassin
  over and over (Heal 22 times in j1-own-1, Cure Moderate Wounds 115 times over two minutes in
  j1-own-4). The choice adapter skips a cast at a creature its caster cannot see, as the game would
  not let it happen, so nothing happened and the priest stood.
- **Why j1-own-4 ran out of time.** From 121 seconds the party's last member, its mage, stood with
  five Stoneskin skins. The group's fighters counted all of a round's hits (two or three) as taken by
  the skins, found no attack worth anything and waited two minutes (`nothing-good`) while the mage
  cast area spells at them. Fixed since (below, "Hits that skins take").
- **Oil of Speed** still came late: the group's fighter drank it in j2 after 9 to 11 seconds, in j1
  not at all; a round of swings counted more (in j1-own-2 0.53 against 0.37).

What the engine does now:

- **No charm or maze on the last foe in play** (`combat-intent/harm.lua`, `choice.lua`,
  `director.lua`). The director's plan names the enemies in play (`inPlay`: living, in its picture,
  not out of play). When no other enemy is in play or in the caster's sight, a charm or a maze on a
  foe is worth nothing (`harm.UNTOUCHED`); a hold, a petrification or a kill keeps its worth.
  Example: the erinyes with Charm and the party's archer left alone: no charm; with the party's mage
  still fighting, the charm on the archer counts as before.
- **Heals and buffs only at allies the caster sees** (`targeting.seen`, `care.lua`,
  `defence.lua`): at itself, at allies in sight, at invisible ones only with See Invisibility or
  True Seeing; also for spells aimed at a spot by an ally.

Tests: the harm tests' group 8, the choice tests' groups 15 and 23 (a charm and a debuff's opening
on the last foe), the director's group 12, the targeting tests' group 1, the care tests' groups 3
and 4 and the defence tests' groups 6 and 7; 17 mutations checked.
Still open then: a member of the group that the party charmed and the group charmed back was awaited
as a charmed foe; it had turned to the party's side (below, "Freeing a member the party charmed").
Oil of Speed: fixed since (below, "Buff potions before the attack").

### Hits that skins take (lab batch J, run 3, 2026-10-29)

Why the group waited in j1-own-4: the worth of a round of weapon hits took off every hit that
Mirror Images and Stoneskin skins take first (`weapons.hits`), so two or three hits a round against
five skins counted nothing, and so did every round after it. But each hit an image or a skin takes
removes it: it brings the kill a hit closer.

What the engine does now (`combat-intent/choice.lua`, `hitsOn`): the hits past the images and
skins deal damage, bring an on-hit disable or debuff, break a spell and kill this round, as before.
The round counts at least the progress it makes toward the kill: what its hits would deal with
nothing in the way, times the share of real hits among all the hits the kill takes (to the enemy's
minimum, if it has one). A conjured weapon's rounds and a jump into the fight count the same way;
over a conjured weapon's rounds the images and skins take their hits once, no longer once a round.

Example (the weapons tests' group 15): a fighter hits 2.4 times a round with a sword of 9; the
party's mage has 12 of 40 hit points left and five skins. The kill takes two hits and the five, so
the round counts 2/7 of the 12 hit points it could take: 0.09, enough to attack (before: nothing,
and the fighter waited). Beside another enemy as hurt with nothing in the way, the fighter strikes
that one first, as its round kills. With one image and 9 hit points left, 1.4 hits get through
and kill: the round counts the kill.

Tests: the weapons tests' groups 3, 5, 10 and 15; 12 mutations checked.
Still to see in game: batch J again.

### How long the fight lasts (lab batch J, run 3, 2026-10-29)

Buffs and summons count over the rest of the fight (`threat.rest`), and so do a lasting area's
explosions. In run 3 the estimate came out a tenth or less of what the fights lasted: 13.1 seconds at
the start of every j1 fight (they lasted 131 to 193), 6.7 in j2 (57 to 126), and 2 to 4 seconds a
minute in, in fights that went on for two more. So every buff and summons counted far too little,
most at the start, where it counts most.

Why: each side's harm a round stayed whole until the other side was dead, so a group lost no harm as
its members fell, and Stoneskin skins and Mirror Images took nothing.

What the engine does now (`combat-intent/threat.lua`, `M.rest`): round by round each side's harm
falls on the other side's creatures one by one, the one that deals the most harm for its hit points
first (each side strikes down what hurts it most), and a creature that has fallen deals no more
harm. Skins and images take a weapon hit each first, a hit of the other side's mean damage; spells
pass them. At most `fightCap` (60 seconds), as before. A fight of one against one comes out as
before.

Example (the summons tests' group 8): a mage (14.4 a round) and a fighter (8) against two fighters
(8 each). The enemies strike down the mage first; the first enemy falls in the third round, the mage
in the fourth, and with the fighter's 8 left the second enemy falls in the eighth round: 46.8
seconds, where the old count said 32.1. An enemy with three skins and two images lasts 24.6 seconds
instead of 16.1. Six against six, as in batch J's j1 (a fighter, a kensai, a mage, a priest, a thief
and an archer on each side): 52 to 59 seconds at the start instead of 20.5.

Still rough: healing, potions, disables, walking and casting time and invisibility do not count, so
the estimate still errs short; the choice record keeps it (`rest`) for the lab to compare.

Tests: the summons tests' group 8; 11 mutations checked.
Still to see in game: batch J again (summons, buffs and lasting areas at the start).

### Buff potions before the attack (Christopher, 2026-10-29)

Christopher, 2026-10-29: "Ich finde, dass der erste Trank, falls wir einen Stärkungstrank (oil of
speed, irgendwelche stärke potions, was auch immer) vergeben, sollte direkt am Anfang des Kampfes
getrunken werden"; healing potions and further potions are more complex. A potion takes no round
now: the drinker still attacks and moves, and it is almost instant. Whether potions should take one
to three seconds or longer, so that healing spells matter more, is a balance question for later.

Why the Oil came late or never (batch J, run 3; j1-own-2, the group's fighter):

- At the start both potions counted the rest of the fight as 13 seconds (`threat.rest`), though the
  fight lasted 131: the Potion of Fire Giant Strength still won (0.40, drunk at 0.4 seconds), Oil of
  Speed counted 0.09. Fixed (above, "How long the fight lasts").
- After that every choice set the Oil against a round of swings, as if the drink took the round: the
  swing at the focus won each time (0.53 against 0.37 at 19.6 seconds), and below the minimum worth
  (0.2) a fighter does not leave its weapon for anything. But the drink takes a moment: its attack
  followed 0.6 and 1 second after the potion started.

What the engine does now (`combat-intent/choice.lua`, `defence.lua`): where the creature would
attack, the best drink that adds to attacks (a defence option of an item that `boosts`: Oil of Speed,
giant strength, a potion of heroism's THAC0) comes first when it is worth more than the part of the
attack its moment takes (`M.drinkSeconds`, one second: a seventh of a round of swings), and needs no
minimum worth, since the creature does not leave its weapon for it. The attack follows. A drink waits
for the casting aura as before, a pause after a defence (`mind.redefend`) too, and a cast worth more
than the attack still comes first. Healing and protection potions are weighed against the attack as
before (Christopher: more complex; with the time a drink takes, later). The choice record's `how` is
`drink`.

Example (the defence tests' group 15, batch J's case): a fighter with Oil of Speed beside an enemy
at half of its 40 hit points, whose round of swings is worth 0.63 (a kill as likely as not); the Oil
is worth 0.22. It drinks, then swings. With giant strength and Oil of Speed at the start it drinks
the giant strength (the larger), swings while the pause after it runs, and drinks the Oil then.

Tests: the defence tests' groups 14 and 15; 10 mutations checked.
Still to see in game: batch J again.

### Freeing a member the party charmed (Christopher, 2026-10-29)

Christopher, 2026-10-29 ("klingt gut"): clever creatures free a member of their group whom the party
charmed, with Dispel Magic when they have it; otherwise the group fights it as any enemy.

What the game does with a charm (opcode 5; IESDP, and batch J, run 3, read from each creature's EA
in the logs):

- **While it holds** the creature fights for its charmer's side: the party's charms set the group's
  assassin, kensai and archer to EA CONTROLLED (5); the group's charms set the party's members to
  ENEMY (255) or CHARMED_PC (254).
- **After it** a charm of the hostile types sets the creature against its charmer: the party's
  members the group had charmed came back as GOODCUTOFF (30), not as PC (2). By IESDP one the party
  charms with a hostile type goes to the evil side after (EVILCUTOFF), and one of the neutral types
  keeps its allegiance as it was; either way a dispel that takes the charm off a member of the group
  brings it back to the group. Not seen in the lab yet: the three the party charmed died charmed (EA
  NEUTRAL, 128, at their death).
- **A charm by a caster of the evil side** turns its creature to the good side for after the charm.
  In j1-own-4 and j2-own-3 the party's mage began a Dire Charm at the group's kensai, and at its
  fighter-thief, 17 and 30 ticks before the group charmed the mage; the charm landed after, with its
  caster on the group's side. Both stood with the group while charmed and with the party once it
  ended (EA 30). The erinyes then charmed the fighter-thief back, and the group awaited it as a
  charmed foe; that was right then, since it had become one of the party's. A real party can get
  there too: a cast goes on when its caster is charmed in the middle of it.

What the engine does now (`combat-intent/removal.lua`, `harm.lua`, `targeting.lua`, `choice.lua`;
`adapters/eeex/director.lua`):

- **Freeing.** A creature among the enemies in the charmed state is one the other side charmed. A
  removal that takes every charm on it (Dispel Magic, as likely as its level against the charm's)
  frees it, worth what the same charm on an enemy is (1.2 for the full 18 seconds, less for less
  time left or fewer hit points), as likely as every charm goes and as the dispel lands (magic
  resistance). Its other effects count neither way then (they go with a creature that comes back),
  and as on any enemy as far as it stays charmed. A charm no dispel can take (an innate one) frees
  nothing. Seeing it is a tactic: a clever creature always, a normal one when it notices, a dull one
  never; one that does not see it weighs the dispel on it as on any enemy.
- **It fights.** A charmed creature is no disabled one any more (`targeting.disabled`): the one the
  party charmed counts with its weapon and spells against the group it now fights (threat, the rest
  of the fight, danger zones), and holds and debuffs count on it as on any enemy. Before, the group
  counted it out of the fight. A foe the group charmed stays out of play as before
  (`threat.friends`).
- **No charm over a charm.** A charm on a creature charmed already counts nothing: the group's charm
  on its own member would turn that member to the party's side for good once it ends.
- **A member the party charmed** stands on the party's side: what it sees no longer enters the
  group's picture, and its casts at the group are not advised.

Example: the party's mage charms the group's kensai. The group's clever mage, with Dispel Magic at
level 15 against the party's charm of level 10 (74%), dispels it at once when that is worth more
than its other spells: the kensai is back for the rest of the fight. A dull ogre beside it attacks
the kensai as any enemy.

For the lab: run 3's bot left charmed members alone, as fixed after run 2. Its 13 orders that seemed
to reach a charmed member (the assassin, the thief, the archer and the mage) came in the second each
charm ended: the sample a second before showed the charm, the next one without it (EA 2 or 30), and
in two of them the group charmed the member again a second later. Nothing to change for run 4.

Tests: the removal tests' group 8, the harm tests' group 9, the targeting tests' group 1, the
director adapter's group 5; 15 mutations checked.
Still to see in game: batch J again.

### Readiness: re-buffing while a foe is out of play (Christopher, 2026-10-29)

Christopher, 2026-10-29: clever creatures guard a mazed foe's spot from a distance, heal and re-buff,
and strike when it returns (above, "Foes out of play"). Until now a buff counted only with an enemy
in sight, so with the foe away nothing was worth casting.

What the engine does now (`combat-intent/choice.lua`, `defence.lua`, `search.lua`;
`adapters/eeex/search.lua`, `sense.lua`, `choice.lua`):

- **Who.** Only a creature that guards: a clever one, or one whose orders say `await = guard` (a
  boss that guards its post only for a foe near it). A normal creature at its post and a dull one
  cast nothing while they wait. Healing goes on for all, as before.
- **Against whom.** The foes out of play stand in for enemies in sight, as the group last saw them:
  where they went, with their weapons, protections and spells. A foe the group charmed counts without
  its charm, as it comes back an enemy.
- **When they are back.** A charm: what is left of the charm the group cast. A maze by intelligence
  (opcode 213 type 0, every Maze in the SR lab): how much of the maze is likely left, by the foe's
  intelligence and the installed game's INTMOD.2DA (4d4 rounds at intelligence 10 in the SR lab, a
  minute on average), counted from when the group saw the foe go; a maze that has lasted a while is
  likely nearer its end. The engine never reads what the game's dice rolled: the group cannot know
  that. When the return cannot be told (a maze of a set duration, type 1), the foe may be back any
  moment. A foe under a charm without an end is never back: nothing is readied for it.
- **Like its own Time Stop.** Until the first foe is likely back (the calm) nothing can hit the
  creature: a buff counts only for what is left of it after the calm, a protection likewise, a cast
  that ends within the calm cannot be broken, and nothing is acute danger. An area spell weakens
  none of the foes meanwhile, as they are not there.
- **Only what is worth it.** Such a defence must reach the minimum worth (`mind.minValue`); a weak
  one does not beat waiting here, while a weak heal still does, as before. Anything else goes to the
  guard walk as before.
- **Log:** the `choice` row's `ready` and `calm` (seconds), count `readies`; the search's count
  `readyFailures` and an `error` row (where `ready`) for a foe out of play that could not be read.

Example: the group's mind flayer mazes the party's fighter (intelligence 10). The group's clever
mage, guarding the spot 240 off, expects the fighter back in about a minute. It casts Stoneskin,
which still holds when the fighter is back; a short protection that would be over by then counts
nothing yet, and only once the fighter is due. With its skins up it just guards. A normal mage goes
back to its post and waits; a dull ogre stands where it is.

Tests: the search tests' group 12 (the nearest foe away, how it is awaited, the maze's time left),
the defence tests' groups 16 (the calm) and 17 (readiness, a weak heal, a foe never back), the
choice adapter's group 44 (a mazed and a charmed foe, skins up, a normal and a dull mage, a maze of a
set duration, the search's reading by time and intelligence); 35 mutations checked.
Still to see in game: batch J again.

#### Summons and clouds on the spot (Christopher, 2026-10-29)

On the idea that clever creatures could also lay a summons or a cloud where the mazed foe reappears,
Christopher, 2026-10-29: "Was für eine geile Idee". The guard now also weighs (`combat-intent/
choice.lua`, `summons.lua`; `adapters/eeex/choice.lua`):

- **A summons** waits where the foes went (the summons' usual spot, now where the group last saw
  the foe) and counts only from when the first foe is likely back until the fight or the summons
  ends. One that is gone by then is worth nothing. A summons cast at a creature has no foe in play
  to be cast at.
- **A lasting cloud or storm on a mazed foe's spot.** The foe comes back where it went, so the
  explosions count from its likely return: staying, those after it; walking out, those before it is
  out, and the seconds the walk costs it. A cloud that is over before the foe is back is worth
  nothing. As the group has learned how often a foe stays in a cloud, so it counts here.
- **Not on a charmed foe.** It walks about meanwhile and is in no cloud, and an area that would hit
  it where it stands is refused, as harming it breaks the charm by the rules text, unless the area
  does nothing to it. A cloud on enemies only passes it, as it stands with the caster's side.
- **Nothing else counts before the foes are back:** no bolt, no single explosion, no cloud for a
  profile that counts one explosion (dull creatures), nothing aimed at a creature out of play, no
  line (it counts only the creature it is aimed at), no touch spell and no conjured weapon.
- The engine answers the cloud's SPLPROT checks for the foe out of play as for an enemy in sight. A
  cloud cast at a point is judged by no target, so the foe's absence teaches the caster nothing.
- **Log:** the `choice` row with `ready` and `calm` as for a defence; a cloud's row also lists the
  explosions it counts on the foe (`lasting`: staying and walking out).

Example: the group's mind flayer mazes the party's fighter, likely back in 9 seconds. The clever
mage lays a fire storm of ten explosions on the spot where the fighter vanished; it counts the seven
that come after the fighter is back if the fighter stays, and the one it takes walking out if not.
A summoner calls its creatures, which wait by the spot. Against a charmed party member the mage
lays nothing: the storm would hurt it where it stands.

Limitation: the return is what the maze likely has left on average; the dice may bring the foe back
a round earlier or later than counted. Timing the cast so that the cloud lands just before the
return is a later refinement.

Not built: a trap on the spot. Whether it fits is Christopher's call.

Tests: the choice tests' group 25 (the storm by the foe's return, the fight's rest, a charmed foe in
or beside the area, globes, an enemies-only storm, what does not count, the choice and its minimum
worth), the summons tests' group 9 (the calm, durations, a summons at a creature, the choice), the
touch and weapons tests' readiness checks, the choice adapter's group 45 (the storm at the spot, its
SPLPROT check on the foe out of play, a charmed foe); 29 mutations checked.
Still to see in game: a lab with a mazed party member and a clever caster.

### Lab batch J, run 4 (2026-10-29)

The same 14 fights with the build of 1f29652 (run 3's fixes: no charm or maze on the last foe in
play, heals only at allies in sight, hits that skins take, the fight's rest, buff potions first,
freeing members the party charmed, readiness), in the Spell Revisions lab, cleaned up after.

- **Result.** j1: the engine's group won 3 of 4 (120, 59 and 123 seconds) with 83, 85 and 79 per
  cent of its hit points left (run 3: 59, 21 and 34); the fourth it lost (below). SCS won all 4
  (38, 234, 65 and 53 seconds; 74, 5, 74 and 78 per cent left: in the long one six of its seven
  fell). j2: the engine won all 3 (109, 82 and 75 seconds; 52, 75 and 74 per cent) and no time ran
  out (run 3: twice); SCS won all 3 as well (44, 124 and 136 seconds; 67, 41 and 45 per cent). The
  bot made no errors.
- **What run 3's fixes did.** No priest healed an ally it could not see; no fighter waited at a
  foe behind skins (`nothing-good`); the group's fighter drank its Potion of Fire Giant Strength at
  0.3 to 0.5 seconds in every fight and its Oil of Speed at 8 to 9, after the pause that follows a
  first defence (`mind.redefend`, 7 seconds), as designed. While awaiting a charmed foe the
  group's kensai renewed its kit ability (C0KN#04, from the lab's kit mods) twice. The group
  awaited foes out of play (6, 7, 6 and 1 `await` rows in j1); in j2-own-1 and 2 mazes ended and
  the foes came back.
- **Why j1-own-4 was lost.** The party's kensai used Kai at 4 seconds and the party's priest healed
  him; the group's kensai fell at 15 seconds, and five of the group were dead by 36. Its mage,
  alone from 73 seconds, killed the party's archer, fighter and mage and fell to the party's kensai
  at 187. A mirror fight can go either way: in j1-scs-2 SCS's group lost six of seven.
- **Where the fighters struck.** In the first 36 seconds of each j1 fight a quarter to a third of
  the fighters' blows went at the group's focus, in the won fights as in the lost one; the others
  mostly took the foe at hand. Whether a group should strike one foe together is a point for the
  design round on group tactics.
- **The charm on the last foe still came, twice.** j1-own-2: at 54 seconds the group's mage cast
  Dire Charm at the party's priest, its last living member; the priest stood charmed from 57 and
  died at 59. j1-own-3: at 55 seconds the same at the party's fighter, who stood charmed from 59 to
  119; the fight ended at 123. The party's mage (dead at 51 seconds) and archer (dead within the
  second before the cast) still counted as in play. Fixed (below, "Gone at once").
- **The fight's rest at the start** came out at 13 seconds in j1 again: the group's fighter saw
  its whole group but 2 of the party's 7. Fixed (below, "The fight the group knows").
- **Why SCS's mirror wins came faster** (38 to 65 seconds, one of 234; the engine's 59 to 123; in
  the fiend fights the engine was faster in 2 of 3). In all three won mirror fights the group's mage
  charmed the party's last member just as the one before fell (j1-own-1 at 53 seconds, the same
  second), and in j1-own-1 and j1-own-3 the group then awaited the charm for a minute; without that
  those wins would have taken 55 to 60 seconds. Beyond that SCS's mage cast what ours left: Dispel
  Magic (`SPWI302`) in every mirror fight (ours once; at 5 seconds in j1-own-2 it rated it 0.06,
  and the logs explain why (2026-11-02): Spell Revisions' Dispel Magic takes effects from enemies
  only (its projectile's area keeps to enemies), and its best spot then was the party's kensai
  alone, with a strength potion and at most Bless; the party's mage with its Stoneskin stood 750
  pixels from the group's mage, beyond the spell's reach of 480, and none of the group pressed it, so its protections
  opened little; whether a group should break an enemy caster's protections and press it together
  is a point for the design round on group tactics), Teleport Field (`SPWI421`) in every one (the engine weighs it
  as no attack: SUPPORT-01), and water elementals (`SPWI526`, Spell Revisions) in three (ours in one;
  in j1-own-2 they were its best option at 12.5, 13.5 and 30.6 seconds, lost to a near-best draw
  once and to the casting pause twice, and they counted over the 13-second fight). The default mind
  takes a near-best option 4 times in 10 (`best` 0.6, `band` 0.2): 3 of the mage's 5 casts in
  j1-own-2. Since 2026-10-29 that goes by wit: a clever creature strays 2 times in 10, a normal one
  4, a dull one 6 (MIND-01, "The best option by wit").
- **The mind flayer's escape.** In j2-own-3, at 36 per cent of its hit points (47 seconds), SCS's
  script cast the flayer's escape (`DW#MFESC`, a SpellNoDec cast above the hook); it vanished about
  2 seconds later. Run 3 shows the same at 51 seconds. It goes with the other vanishing exits
  (above, "Disengage"): nobody leaves for good.

### The fight the group knows (lab batch J, run 4, 2026-10-29)

The estimate of the fight's rest (`threat.rest`) counted only what the deciding creature saw. At
the start of j1 the group's fighter saw all of its group and 2 of the party's 7, reckoned the fight
over in 13 seconds, and the fights lasted 59 to 187. So buffs, potions, summons and lasting clouds
counted for a fraction of the fight at its start, where they count most. A minute in, with the
fight in sight, the estimate fitted what the creature saw.

What the engine does now (`adapters/eeex/choice.lua`; `combat-intent/choice.lua`, `defence.lua`,
`summons.lua`): the fight is the one the group knows: the creature's frame, the other members of
its group and the enemies of the group's picture that the creature does not see itself, each read
at most a second ago (`M.knownTicks`). One that cannot be read is left out (count `fightFailures`,
an `error` row where `fight`). Without a group the frame counts, as before. Readiness keeps its own
count: the fight from the foes' return is theirs against the caster's side. The choice record's
`fight` gives the count (the creature's side, the enemies).

Example: at the start of j1 the group's fighter sees 2 of the party's 7 and the other members see
the rest; its potions now count over the fight against all 7, not over the 13 seconds two foes
would last. It works the other way too: a summoner that sees one armed foe while the group sees
three counts a shorter fight (the choice adapter's group 46).

Correction: in run 4's first look the Oil of Speed at 8 seconds was put down to this estimate. It
came from the pause after the first potion, as designed.

Tests: the defence tests' group 14, the summons tests' group 8, the choice tests' group 25, the
choice adapter's group 46; 15 mutations checked.
Still to see in game: batch J again (buffs and summons at the start).

### Gone at once (lab batch J, run 4, 2026-10-29)

Members see only the living, so a dead enemy stayed in the group's picture as last seen, alive: in
play for up to 30 seconds (`forgetTicks`) and the focus while the sighting was fresh. The adapter's
check of enemies no one had seen for a second found it dead, but the director acted only on a maze
or a prison. In j1-own-2 the party's mage, dead for three seconds, was still the group's focus and
in play, so the mage's Dire Charm on the party's last member kept its worth.

What the engine does now (`combat-intent/director.lua`, `adapters/eeex/director.lua`):

- **Gone at once.** A creature the check finds dead, or no creature any more, leaves the picture at
  once: no foe in play, no clue for the search, no focus; a charm or maze kept for it ends. Log: a
  `gone` row (count `gone`) and a `focus` row with `why = gone`.
- **Checked right before use.** The plan and the search's clues check their enemies just before a
  member uses them, so one that died a moment ago does not count either (in j1-own-3 the party's
  archer died within the second before the charm).
- **Charmed foes too.** A foe the group charmed that no member has seen for a second is checked as
  well: dead, its charm ends; before, clever guards could await it for 30 seconds.

Example: the party's archer falls. A moment later the group's mage weighs Dire Charm on the party's
fighter, the last one standing: no other foe is in play, so the charm is worth nothing, and the mage
casts what harms him.

Tests: the director's groups 12 and 13, the director adapter's group 11; 17 mutations checked.
Seen in game: lab batch J, run 5, below (4 to 7 `gone` rows in each of the engine's fights).

### Lab batch J, run 5 (2026-11-02)

The same 14 fights as run 4 (`.work/stepJ-lab`, SR lab on Insane, BD0072) on snapshot `c79e24d`:
the dead leave the group's picture at once, the fight as the group knows it, the best option by wit,
SCS's vanishing exits wait while the engine drives the creature, doors in the search, and responses
one action a line. The lab's party archer now takes up its bow and shoots in one response too
(`EquipRanged` had stood on the attack's line). 25 minutes, no guard tripped, the lab clean after.

| Fights | Group won | Seconds | Group's hit points left | Group deaths |
|---|---|---|---|---|
| j1 (mirror), engine | 3 of 4 | 51, 108, 52 (lost at 115) | 0.54, 0.21, 0.67 (lost: 0) | 2, 5, 1 (lost: 7) |
| j1 (mirror), SCS alone | 4 of 4 | 61, 72, 102, 75 | 0.81, 0.75, 0.78, 0.81 | none |
| j2 (fiends), engine | 3 of 3 | 82, 100, 81 | 0.75, 0.74, 0.66 | 1 in all |
| j2 (fiends), SCS alone | 3 of 3 | 124, 70, 155 | 0.45, 0.62, 0.40 | 5 in all |

- **Against the fiends the engine was the better group:** faster in two of three fights, with more
  left and four fewer deaths than SCS's.
- **In the mirror fights SCS's group was far better** this time: no death in four fights, against the
  engine's one lost fight and wins with a fifth to two thirds left. With four fights a side the
  spread is wide (run 4 had it the other way round), but the first seconds show a real difference:
  SCS's fighter and kensai drank Oil of Speed in the first half second and were hasted from the first
  second; SCS's kensai used Ki Focus (`SPCL144`, which Artisan's Kitpack's Kensai Overhaul makes of Kai in this lab) three or four times a fight; all of
  SCS's group went for the party's kensai, dead after 7 or 8 seconds. The engine's fighter drank Fire
  Giant Strength first and Oil of Speed eight seconds later; its kensai never drank Oil of Speed in
  the first sixteen seconds and used Ki Strike (`C0KN#04`) instead of Ki Focus, twice. The party's
  kensai fell at 15 seconds or survived.
- **The fighter's order holds:** at strength 17 Fire Giant Strength (22) roughly doubles what a hit
  of his does, haste adds a third more attacks, so the engine's 0.395 against 0.094 was its model's
  honest answer. **The kensai's was a fault:** Ki Strike rated 1.0 to 3.5, Ki Focus 0.17 (below,
  "Ki Strike").
- **SCS's vanishing exits waited:** the mind flayer at 38 seconds (j2-own-2) and the erinyes at 34
  (j2-own-3) would have left; both fought on (`stay` rows).
- **Weapon switches attack now:** the archer's switch to its bow and its first arrow came in one
  response (1.7 and 1.8 seconds).
- **The fight's rest at the start:** the first two decisions, a third of a second in, still reckoned
  13 to 16 seconds; from the third on 17 to 42; the fights lasted 51 to 155. Better than run 4's
  constant 13, still short.

### Ki Strike: a buff that ends with its hit (2026-11-02)

Ki Strike (`C0KN#04`, from Artisan's Kitpack's Kensai Overhaul in this lab; the kensai's "next attack within one round deals maximum damage", with
a doubled critical modifier and fatigue after) holds three things the engine read wrong:

- Opcode 250 with 20 is luck for base weapon damage (IESDP: as luck, on the weapon's own damage dice
  alone): every die rolls 20 higher, at most its sides, so every die at its top. The classifier read
  it as 20 more damage a hit.
- Its critical bonus (opcode 301) is set to last (timing 9), so the whole buff counted as lasting:
  20 more damage on every swing for the rest of the fight.
- Its blow casts `C0KN#04A`, which takes every effect of Ki Strike off again (opcode 321) and
  fatigues the kensai: one strengthened hit.

What the engine does now:

- **Luck for base weapon damage** (`damageLuck`, `combat-intent/spells.lua`) moves the weapon's own
  dice (`threat.luckGain`): each die rolls that much higher, at most its sides, or lower, at least 1.
  A creature's attack data carries its weapon's dice and its ammunition's (`rolls`,
  `combat-intent/arsenal.lua`); without them luck counts nothing. Bad luck on an enemy counts as the
  damage it loses (`harm.weaken`).
- **A buff that ends with its hit** (`untilHit`): when a spell's own on-hit effect takes the spell
  off its holder (the "spent" on-hit effects that already counted once, F2a), all its effects go
  with it, so its buff counts for that one hit, as likely as one of the creature's swings over the
  fight lands (`defence.offense`), whatever its effects' durations.

Example: the kensai's katana (1d10) rolls 5.5 on average; Ki Strike's blow rolls 10 and doubles a
hit on 18 or more instead of 20, once. Worth what that one blow adds, no longer more than the rest
of the fight's swings, so Ki Focus's twelve seconds of hits that do not miss, with a fifth more
damage, can win (the next lab run shows whether they do).

Tests: the classifier's on-hit group (Ki Strike, bad luck, Smite Evil's buff until its hit), the
arsenal's dice, `luckGain`, a Ki Strike worth one hit against the same edge lasting a minute, bad
luck in `harm.weaken`; 7 mutations caught. Seen in game: run 6, below.

### Lab batch J, run 6 (2026-11-02)

The same fights on snapshot `8b7cdcd` (run 5's build with Ki Strike fixed); 29 minutes, no guard
tripped, the lab clean after.

| Fights | Group won | Seconds | Group's hit points left | Group deaths |
|---|---|---|---|---|
| j1 (mirror), engine | 2 of 4, one more ahead when time ran out | 98, 61, 240 (lost at 111) | 0.21, 0.85, 0.09 (lost: 0) | 5, 0, 6 (lost: 7) |
| j1 (mirror), SCS alone | 3 of 4, the fourth far ahead when time ran out | 59, 61, 55, 240 | 0.82, 0.82, 0.75, 0.77 | one in all |
| j2 (fiends), engine | 3 of 3 | 99, 86, 64 | 0.57, 0.60, 0.86 | 3 in all |
| j2 (fiends), SCS alone | 3 of 3 | 117, 78, 125 | 0.47, 0.39, 0.47 | 6 in all |

- **Ki Strike no longer wins:** the kensai drank Oil of Speed half a second in, in every fight, as
  SCS's did. **Ki Focus still never came:** worth 0.17 at the start and 0.11 a second later, it lost
  to the swing (0.27, 0.19) as a whole action, though it is an ability without casting time
  (below, "Instant abilities").
- **The fiend fights again went the engine's way:** more left than SCS's group and half its deaths.
- **The mirror fights again went SCS's way.** In SCS's four fights its group killed the party's
  kensai within 6 or 7 seconds every time, then its fighter. In the engine's, its own kensai fell
  first or second (16 to 19 seconds) in three fights of four, and the party's kensai lived longer.
  SCS's melee all strike the same foe; the engine's spread over the foes at hand. Whether a group
  should strike one foe together is a point for the design round on group tactics (as after run 4).

### Instant abilities take a moment (2026-11-02)

Christopher, 2026-10-25: potions, abilities and the like are often instant and need not take the
whole round. Buff potions already came before the swing, taking a moment
(`choice.drinkSeconds`). Now an ability without casting time (speed 0) that the creature uses on
itself to strengthen its attacks counts the same way: where it would attack, it comes first when it
is worth more than the part of the attack its moment takes (`combat-intent/choice.lua`). A spell
with a casting time still takes its casting.

Example: the kensai at the start of a mirror fight: Ki Focus (twelve seconds of hits that do not
miss, a fifth more damage, 0.17) against its swing (0.27): the moment costs a seventh of the swing,
so Ki Focus first, then Oil of Speed, then the swing.

Tests: defence group 15 (the same haste without casting time cast before the swing, with a casting
time not); the mutation that drops it is caught. Seen in game: run 7, below.

### Lab batch J, run 7 (2026-11-02)

The same fights on snapshot `d804e97` (run 6's build with instant abilities taking a moment); 22
minutes, no guard tripped, the lab clean after.

| Fights | Group won | Seconds | Group's hit points left | Group deaths |
|---|---|---|---|---|
| j1 (mirror), engine | 4 of 4 | 72, 56, 48, 61 | 0.72, 0.85, 0.74, 0.67 | 3 in all |
| j1 (mirror), SCS alone | 4 of 4 | 57, 51, 66, 52 | 0.84, 0.81, 0.56, 0.90 | 1 in all |
| j2 (fiends), engine | 3 of 3 | 86, 75, 105 | 0.77, 0.68, 0.74 | 1 in all |
| j2 (fiends), SCS alone | 3 of 3 | 65, 180, 82 | 0.76, 0.38, 0.65 | 4 in all |

- **The kensai uses Ki Focus now:** half a second in, before its first swing, and again every 8 to
  10 seconds while it fights; Oil of Speed follows at 9 seconds, when the casting aura of the Ki
  Focus has run out (drinks wait for it, "Buffs over the rest of the fight").
- **The mirror fights are even with SCS's:** four wins of four in both modes, about as fast (59
  seconds on average against 57) and with about as much left (three quarters against four fifths);
  the party's kensai fell at 11 to 13 seconds (SCS's group: 6 or 7).
- **The fiend fights stay the engine's:** more left (0.73 on average against 0.60), faster (89
  seconds against 109) and one death against four.
- Runs 5 to 7 together: the engine's group lost two mirror fights of twelve (one more ran out of
  time, slightly ahead), SCS's none; against the fiends both won all nine, the engine's with more
  left and fewer deaths in each run.

### Teleport Field: a spell for positions (Christopher, 2026-11-03)

Christopher: "Solche Spells müssen natürlich auch bewertet werden. Du musst überlegen, dass das ein
taktischer Spell ist. Auch AI muss sich positionieren, genau wie Spieler." The field teleports again and
again. Until now the engine gave Teleport Field no worth, so it never cast it.

- **What the spell does (the labs' data):** vanilla `SPWI421` casts the area projectile `PFIELD`
  (projectile 238, `PROJECTL` 237) at a point within 40 feet: a radius of 256, enemies of the caster only
  (area flag bit 6), ten explosions 100 ticks (a round) apart. Each explosion applies opcode 222 with
  parameter 1 = 256 to every enemy in the field. IESDP: the target is teleported in a random direction,
  up to that range, measured as a projectile's radius (16 = 1 foot). Spell Revisions' version casts the
  same projectile with the opcode in a sub-spell (a save vs. spell at -4 by its text).
- **The worth (built 2026-11-03):** a foe that fights a friend in melee (the caster or an ally its
  action aims at, with no ranged weapon) walks back the part of each jump that takes it beyond its
  weapon's reach and loses that walk from its fight. With the jump's length even over the range, which
  IESDP leaves open, that is (256-64)^2/(2*256) = 72 world units, 0.72 seconds at a fighter's walk, worth
  a hold that long (`harm.displaced`, `harm.teleport`). It comes back for each explosion while the friend
  it fights stands in the field, and gets one otherwise (`choice.lua`, `lastingOn`). The caster and its
  allies may stand in the field, since it spares them, so the best spot is the melee around the
  engine's own fighters and casters. Over ten explosions that is up to 7.2 seconds of a foe's fight,
  as a hold of 7 seconds.
- **Not counted yet:** whether a jump breaks a cast under way or the foe's attack (then it would also
  be worth something against casters and archers), and whether the jump's length is even over the
  range or over the field's area. The Teleport Field probe (`.work/stepP-lab`, the SR lab, nothing
  installed: the PC casts the vanilla spell at a fighter attacking an ally, a caster casting at it, an
  enemy and an ally standing still) measures each jump and what happens to attacks and casts. It waits
  for a quiet PC (the CPU was busy on 2026-11-03). The engine's own creatures in an enemy's field do not
  weigh it yet either.

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
  taking it up: they are no active effects until it does. Helmets are not read: half of all
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
- Backstabs (F2d): in sight of an enemy only potions, scrolls and spells of invisibility hide a
  creature for a backstab; its own Hide in Shadows works out of sight (F2f), and no fight choice
  weighs walking out of sight to hide. The spot behind an enemy is where it stands now, not where a
  walking enemy will be. A backstab counts the weapon's average damage, not its dice.
- Hiding (F2f): only thieves hide by their skill (rangers, monks and shadowdancers wait for the hide
  probe). A veil (F2f-5) uses innate abilities only, not a mage's memorized Invisibility (that is
  for the prebuffs), and leaves out invisibilities that reach an area. A creature without an innate
  invisibility, or whose last one is gone for good, keeps SCS's free one (a creature file the
  installer did not see, a spell another mod took away).
- Barbarian Rage's armour class penalty does not count against what it protects; per-cent maximum
  hit points (opcode 18, mode 2) give no hit points; helmets are not read.
- Movement speed is not read (haste, slow, boots of speed), only the default: every walk counts
  100 a second (`weapons.speed`), also the walk into position in the casting pause.
- Defences at allies do not walk into range yet (heals and cures do, by the one walk rule).
- Positioning: the walk goes straight toward the aim, not around walls or other creatures (the
  game finds the path); the spot is chosen for the next cast alone, not for the casts after it, and
  an enemy that walks meanwhile is aimed at where it stands now.
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
