# BOSS-01 — Early BG1 encounters, one by one

The boss and encounter fights, designed with Christopher one by one in story order, starting in early
BG1 (Christopher, 2026-11-03: "einfach mit early BG1 und wir gehen alles durch"). SCS stays the
blueprint for each fight ("uns da immer an SCS orientieren"); credit DavidW for SCS's scripts read
here. Facts come from Christopher's current game (`Chriz Easy BG`, read only) unless a line says
otherwise.

## How we work (Christopher, 2026-11-03)

- About five encounters are talked through and written down here, one after the other; then they are
  built and tested together in one lab batch. General improvements found on the way (they help every
  fight) are built right away.
- Small encounters stay simple and close to SCS ("Er soll ja einfach nur eine kleine Challenge sein.
  Ich würde es nicht zu viel verkomplizieren bei solchen Encountern"). What turns out bad in tests is
  improved later.
- Balance is judged at the intended setup: no double damage, no maximised hit points; labs use average
  hit point rolls (or random ones), full hit points only at level 1. For each encounter, ask
  Christopher how strong the party usually is at that point.
- Preparation: instant prebuffing as SCS does it stays, but faster and more reactive ("am liebsten
  noch schneller und reaktiver. Das ist mir sehr wichtig"). Not everything is prebuffed: for each
  encounter, what the caster would definitely have prepared, which may depend on the situation. For a
  caster who could not have known the party was coming, ask Christopher whether he would better be
  caught unprepared and the fight made hard another way.

## Order

Proposed on 2026-11-03 and corrected on 2026-11-04 from the game's scripts: Tarnesh, Silke, Karlat,
Neira, then Greywolf (Prism's quest at the Nashkel Mines) and Mulahey (the mines' boss). Nimbul
comes later: Nashkel's area script creates him only once chapter 3 starts, after the mines (the
Chapter variable counts the chapters shown; arriving in Nashkel starts chapter 2, the mines' lowest
levels chapter 3).

## Lab for BG1 fights

`BGSE-Lab/scs-reference` is an EET lab (a copy of an earlier state of Christopher's game, with Spell
Revisions); `BGSE-Lab/scs-nosr` holds BG2 only. Like Christopher's game, the EET lab carries Tweaks
Anthology's maximum hit points (for creatures in game, at level one and on level up). Christopher
(2026-11-03): no Spell Revisions any more; BG1 fights need a new EET lab without it, installed as the
intended setup: no maximum hit points for creatures, full hit points at level one, rolled or average
ones after. Until it stands, the SR lab can show whether the engine does sensible things, but balance
is not judged there (Sleep, Power Word Sleep, Mirror Image and the like differ under Spell Revisions).
Encounter tests run at Insane without double damage.

## Spells to tune against

Christopher's own spell mod (`chriz-bg-magic`, designed with the spell-mod session; nothing built
yet, decision page https://claude.ai/artifact/DjQs3Dqb5WoxiP7Erkztky) replaces Spell Revisions: vanilla
EE 2.7.3.0 unless his decisions say otherwise (wizard levels 1 to 3 decided as of 2026-11-03, the rest
proposals). For early BG1 tuning that means, among others:
- Sleep, Color Spray, Stinking Cloud: vanilla, and damage wakes the sleeper.
- Power Word Sleep: vanilla (below 20 hit points, no save), damage wakes; elves resist, undead,
  dragons and elementals are immune.
- Horror, Magic Missile, Mage Armor, Hold Person, Charm Person: vanilla; undead immune to fear.
- Mirror Image: vanilla values; area damage ignores the images, targeted attacks pop one.
- Chromatic Orb: SCS's version (no death or petrification, no save bonus).
- Blindness: much shorter (a round per two caster levels, 2 to 5 rounds); to be looked at again with
  the engine, which handles blindness badly in Christopher's view.
- Dispel Magic (everyone in the area) and Remove Magic (enemies only) stay apart as in vanilla; Spell
  Immunity stays vanilla for now and there is no shield against Dispel or Breach yet.

The new no-SR lab (`BGSE-Lab/eet-nosr-2`, CEBG's recommended choice without Spell Revisions and
without maximum hit points; installed 2026-11-03 in about two hours, full hit points only at level
one, EEex v1.3.1) has vanilla spells plus SCS's spell changes; tuning re-checks what the spell mod
changes once it is built. It is set up for quiet runs (Steam off, muted windowed profile, cloud saves
off); the remote console and our component are staged per lab batch, as before. The first attempt
(`eet-nosr`) stopped at BG Rebalance 0.8.9's Flail of the Ages component (302), which does not yet
handle SCS's own Slow and Haste spells without Spell Revisions; the installer session fixes it, and
until then the lab runs without that component (the flail keeps SCS's version).

## 1. Tarnesh (Friendly Arm Inn)

**Who:** `TARNES`, a level-4 mage (SCS makes him a conjurer), 25 hit points, INT 16 (clever by the
engine's wit). Memorised: Mage Armor, Magic Missile (two), Sleep, Horror, Mirror Image, Power Word
Sleep. Carries a Short Sword +1, the ring Topsider's Crutch and a scroll of Magic Missile. Scripts:
SCS's talk-on-sight script (`dw#shdlg`) above SCS's generated mage script (`DW#MG468`).

**What SCS does** (`stratagems/genai/deployment.tph`, `dw#shdlg.ssl`; his compiled script):
1. He talks to the party as soon as he sees it ("Tarnesh no longer hangs back", SCS readme); his
   dialogue ends in the attack.
2. Mage Armor is on at once, from Hard also Mirror Image, as if cast before (an instant cast without
   casting time); otherwise Mirror Image is his first spell.
3. In the fight, in this order: Power Word Sleep at party members under 21 hit points, mages first,
   then thieves, bards, priests, anyone; Horror and Sleep at a foe with another foe close by, or at
   anyone when the party is a single character (Sleep not at elves); Magic Missile first at casters behind
   Mirror Image (each missile takes an image), then at party members under 40 %; he steps away from
   a melee foe close to him while he still has missile spells; without spells he fights with his
   sword.

**The engine** does the talk, the preparation (SCS's prebuffs rebuilt), Sleep and Horror on groups
and Magic Missile to finish foes by worth, and as a clever caster it breaks enemy casts. Found while
comparing: Power Word Sleep counted on any foe and for good; fixed 2026-11-03 (`e94376a`): below 20
hit points (IESDP), five rounds; Christopher's game has Spell Revisions' version, where a creature
with 20 or more saves against it.

**Decided (Christopher, 2026-11-03):**
- Play him much as SCS does; a small encounter.
- A small, light preference for the protagonist (he is hired to kill him): a target order with a
  low bonus, not "always".
- Talk-on-sight creatures prepare when they see the party, and the dialogue comes right after, so
  they cannot be caught unprepared ("Wäre jetzt nur eine Überlegung"; recommended, to be built for
  the creatures SCS gives `dw#shdlg`: Tarnesh, Neira, Nimbul, Takiyah, Teven and others, with SCS's
  difficulty rules for what is precast).
- Magic Missile aimed at Mirror Images: fine, but a detail, later.
- Mages step away from melee foes now and then: wanted; build it by wit, then watch it in the lab.
- Balance: with SCS, a lone level-1 protagonist who walks into the inn nearly always dies, while a
  full party finds him easy. He should be a small challenge, not a wall at the very start. Lab checks:
  a lone level-1 protagonist, two level-1 characters and a full level-1 to 2 party, at average hit
  points without double damage.

## 2. Silke (Beregost)

**Who:** `SILKE`, a level-10 bard, 60 hit points, INT 14 (clever; her mage script makes her think as
a caster). Her book: first level Chromatic Orb twice and Shield (two of five slots empty); second
level Melf's Acid Arrow, Vocalize and Mirror Image; third level Hold Person and Haste; fourth level
Emotion: Hopelessness; and as an innate SCS's Minor Sequencer `DW#MS10` with two Charm Person. She
carries a Quarterstaff, Leather Armor, a Potion of Invulnerability (armor class 0 and +5 to all saves
for five minutes, so the whole fight) and the scrolls Balagarn's Iron Horn and Cleansing Aria
(`C0BW101A`, `C0BW201A`, origin unverified). Scripts: SCS's talk script `DW#SILKE` (the original
talk under SCS's difficulty rules) above the original `SILKE` and SCS's generated mage script
`DW#MG444`.

**The story** (`SILKE.DLG`, `CUTSILK.DLG`, `GARRIC.DLG`): Garrick hires the party in Beregost as
bodyguards for Silke against thugs that Feldepost supposedly sent (300 gold; she raises it to 400 or
cuts it to 200 by her reaction to the party). At the Red Sheaf she calls up three "thugs" (`MERSIL`,
`MERSIL2`, `MERSIL3`: level-1 commoners with 7 hit points) and warns the party not to talk to them,
since one is "a mage whose mystic words can sway even the most wise of men". In the cutscene's
dialogue the party either kills them (she pays; reputation −2) or refuses ("We won't murder those
who are obviously innocent men"). Then she turns on the party: "I'll deal with them myself, after I
deal with you!" (`CUTSILK.DLG` state 4 sets `AttackedSilke` and runs `Enemy()`). The party can also
attack her at any time. Once she is dead, Garrick asks to join; if she lives, she turns up at the
Ducal Palace in chapter 7.

**What SCS does** (her compiled `DW#MG444`): Mirror Image as soon as she sees the party; potions, the
Potion of Invulnerability among them; Shield; the Minor Sequencer's two Charm Person; Emotion:
Hopelessness at groups; Hold Person; Melf's Acid Arrow at casters; Chromatic Orb. Haste is memorized
but never cast.

**The engine:** clever; owns her rounds as for every creature, casts Haste by worth and fires the
Minor Sequencer when it is worth it.

**Decided (Christopher, 2026-11-03):**
- She is a popular, well-liked NPC; she should be dangerous, a fight people remember.
- Strength: roughly that of SCS's Silke. How strong the party is at that point varies a lot.
- Instant preparation: the potion and Mirror Image.
- Haste and the double Charm: yes.
- It should be clear beforehand that she is dangerous, perhaps through a short line, for example
  one Garrick says first; the text is written with Christopher.
- More ideas for a cooler encounter are welcome.

**Decided (Christopher, 2026-11-04):**
- No Minor Spell Deflection. It is a third-level spell (`SPWI318`) and would have taken Hold
  Person's slot or come from a scroll: "ach nein dann ist das egal".
- Her preparation is visible: she drinks the potion and Mirror Image goes up when the "thugs"
  arrive, before the party chooses. She plans the ambush herself, so she is ready, and the player
  sees a real caster first ("jo").
- Garrick's line as drafted, in his admiring voice; it also announces the charms ("jo"): "And when
  she sings, folks forget their own minds. Best stay on her good side!"
- Her spellbook is drawn per run (plan, decision 13): "geile IDee". Her signature stays (the two
  charms, Mirror Image, the potion); one or two slots change from run to run (two first-level slots
  are empty today). Which creatures and how much chance is designed when the first fights are built.

**Lab checks (later):** the engine's Silke against SCS's with the same parties, at average hit points
without double damage; the target is roughly SCS's strength, and she should feel dangerous.

## 3. Karlat (Beregost, Red Sheaf)

Facts from the no-SR lab `eet-nosr-2`.

**Who:** `KARLAT`, a level-5 dwarf fighter with 30 hit points, STR 17, DEX 17, CON 15, INT 11 (normal
wit) and WIS 9, THAC0 15 and one attack a round. He carries a Battle Axe, Chain Mail and a Medium
Shield, which with his dexterity gives armor class about 1. He also carries a bounty notice, the
letter `SCRLKAR`: 350 gold for the head of "the foster child of Gorion". Scripts: the game's own
talk script `INITDLG` above SCS's melee script `DW1MELGE`.

He also gets random potions from SCS's potion component, through the game's random treasure table
(`DW#RND01`, `DW#RND26`). The game draws them when it creates him, so each playthrough differs (not
checked in the lab):
- healing, droppable: a third of the time a Potion of Healing, a sixth two, a sixth a Potion of Extra
  Healing, a third nothing;
- a battle potion, undroppable: half the time nothing, otherwise a Potion of Hill Giant Strength,
  Heroism, Defense or an Oil of Speed.

**The story** (`KARLAT.DLG`): a bounty hunter who sits in the Red Sheaf in Beregost (`BG3357`) from
the start of the game; no quest leads to him. He talks to the first party member he sees ("Not that
it's anything personal, you understand"). All three answers end in his attack; he turns down a
bribe ("I'd never take your panic money over a proven contract").

**What SCS does** (`DW1MELGE`, from Core Rules with SCS's default setting): its potion rules need a
visible enemy, so he drinks only after the talk, when he turns hostile:
- Oil of Speed and Potion of Defense at once;
- Heroism and Hill Giant Strength once a foe is close;
- a Potion of Healing below three quarters of his hit points; he never drinks the Extra Healing.

He first finishes off a party member within reach who is down to a fifth of their hit points and
has no Mirror Image or Stoneskin: mages and thieves before bards, clerics and the rest. Otherwise he
hits the nearest foe. He runs only while panicked (fear or broken morale).

**The engine:** a fighter of normal wit. He drinks his best buff potion as the fight starts and his
healing potions by worth (the Extra Healing too), picks targets by worth (focus or spread) and chases
them.

**For the balance talk:** a level-1 fighter hits armor class 1 only on about 18 or more, one swing
in six or seven; Sleep does not touch him (level 5; Sleep reaches level 4 at most); with Oil of
Speed he swings twice a round. These are the original game's numbers; SCS adds only the script and
the potions.

**Decided (Christopher, 2026-11-04):**
- A light preference for the protagonist, as for Tarnesh, since he carries the bounty notice
  ("hja").
- He prepares on sight: a bounty hunter who finds his mark drinks his battle potion visibly, then
  speaks at once ("solange er versucht sofort mit der Gruppe zu sprechen, ja. Ich fänd das geil").
  In the half of the runs without a battle potion he just speaks.
- Strength: the party is probably not strong yet when it first enters the Red Sheaf, and SCS's
  Karlat is about right ("Ich denke SCS hatte da schon in etwa die richtige Idee").
- Otherwise simple and close to SCS, as for every small encounter.

**Built (2026-11-04):** from Hard, when he sees the party, Karlat drinks his best battle potion (if the
draw gave him one), then speaks. His talk script is the game's `INITDLG`, which many creatures share, so he
gets his own copy (`BGSEKARL`, from `bgse/encounters.tpa`), and only his talk waits. Below Hard he talks at
once and drinks in the fight, as SCS's Karlat does (every encounter's hard parts start at Hard).

**Lab checks (later):** the parties of Tarnesh's checks plus a level 2 to 3 party, at average hit
points without double damage, and several runs, since his potions differ from run to run; at Hard, that
the drink comes before the talk and the talk right after.

## 4. Neira (Nashkel Inn)

Facts from the no-SR lab `eet-nosr-2`.

**Who:** `NEIRA`, a level-5 cleric of Mask ("the Lord of Shadows"), 33 hit points, INT 14 and WIS 14
(clever), DEX 16, THAC0 18, one attack a round. Splint Mail, a Medium Shield and her dexterity give
armor class about 1; she fights with a Club and wears the helmet The Eyes of Truth (infravision).
Her spells:
- first level: Bless, Remove Fear, Armor of Faith;
- second level: Hold Person (holds the target and any of its allies within 4 feet for a turn),
  Silence, 15' Radius (saves at −5) and Spiritual Hammer;
- third level: Unholy Blight (1d4 a caster level to good creatures in a 15-foot radius, half on a
  save, otherwise also −2 to all rolls for 4 rounds).

Her letter `SCRLNEI` is a later bounty notice on the protagonist: last seen near Beregost, "a
formidable foe", "likely to have well-equipped traveling companions". SCS gives her a random healing
potion (`DW#RND02`, undroppable: a third of the time a Potion of Healing, a sixth two, a sixth Extra
Healing, a third nothing). The Randomiser mod (8.1.1, component 1100, which places items by in-game
scripts, so per run) can put one of its items into her pack, as loot only: Bracers of Defense AC 8,
the Excellent Short Bow, Chain Mail +1, Leather Armor +1, Armor of Missile Attraction +2 or the ring
The Victor (`FL24T4.BCS`). Scripts: SCS's talk-on-sight script
`DW#SHDLG` above SCS's priest script `DW#PR141`.

**The story** (`NEIRA.DLG`): a bounty hunter who sits in the Nashkel Inn (`BG4801`) from the start of
the game. She speaks first ("Just fancy my luck seeing you stroll in here, bold as day!"); all four
answers end in her attack, bribes included ("I have made my deals and shall abide by them"). Her
death in Nashkel can start Rasaad's introduction (`RASAAD_.DLG`: "You should not make a habit of
picking fights in the street").

**What SCS does:**
- Talk: from Core Rules (SCS's default setting) she starts the talk at once when she sees the party
  (`StartDialogNoSet`); on lower difficulties she uses the normal `Dialog`.
- Preparation from Hard: Armor of Faith and Spiritual Hammer appear at once "as if cast before", using
  up the memorized spells. Like Karlat's potions they need a visible enemy, so this happens when she
  turns hostile after the talk.
- Fight: alone, she opens four times in five with Hold Person at the first foe she sees; then Hold
  Person by class (fighters, rangers, paladins, fighter/thieves, bards, thieves, then anyone),
  skipping foes with Free Action, undead and the already held. Silence at mages, clerics and druids.
  Unholy Blight at a non-evil foe with another party member within 15 feet (or at a lone hero), or
  centred on herself when party members stand close. Spiritual Hammer for melee. Bless and Remove
  Fear only with allies, so not when she is alone.
- She never drinks the undroppable Potion of Healing she may carry (her priest script only knows the
  droppable one); an Extra Healing she drinks below half her hit points.

**The engine:** a clever caster. Talk-on-sight creatures prepare when they see the party, with SCS's
difficulty rules, and the talk follows at once (decided for Tarnesh, also meant for Neira): from
Hard she starts the talk with Armor of Faith and her hammer already up. In the fight she casts by
worth (Hold Person on the most dangerous fighter, Silence on casters, Unholy Blight where it hits
several, the hammer in melee), breaks enemy casts as a clever caster, and drinks her healing potions
by worth, the undroppable ones too.

**Following earlier decisions:** a light protagonist preference, as for Tarnesh and Karlat (she
carries the bounty notice).

**Decided (Christopher, 2026-11-04):** a bit harder and more interesting than SCS's Neira, who is
"halt schon in SCS immer ein Pushover", but not too heavy; level 5 stays. She should have Aid on
herself for more hit points. In this lab Aid is his version (Chris Revisions): 1d8 + 1 per caster
level temporary hit points (at most 1d8 + 10), lasting a turn per level.

**Decided, second round (Christopher, 2026-11-04):**
- WIS 15 ("gib ihr einfach 15 wis"): at level 5 that gives 5/4/1 slots, all real.
- Her book, as suggested: first level Armor of Faith, Protection From Good, Doom, Command and Bless
  (Remove Fear goes; two of these slots were empty); second level Aid, Hold Person, Silence and
  Spiritual Hammer (she is not strong, so the hammer stays; Draw Upon Holy Might is too weak for
  her); third level Unholy Blight.
- Mask is the god of shadow thieves, deception, lies, thievery and shadows; her opener follows that:
  her buffs on sight (Aid, Armor of Faith, Protection From Good), then a Potion of Invisibility right
  after, then she watches how the party plays and opens from invisibility, for example Doom and then
  Hold Person, or Hold Person at once. After the opener she decides by worth. Nothing rigid.
- The aim, said again: really hard on the high difficulties, normal to beat on the low and middle
  ones, and immersive.

**Notes for building:**
- She needs a Potion of Invisibility in her pack. Invisibility ends with her first spell, so the
  opener's first spell comes as a surprise; until then the party reaches her only with area spells
  or by revealing her, and she chooses her target from what she sees (for example a fighter without
  Free Action for Hold Person).
- Scaled by difficulty, as planned: from Hard the full opener (instant buffs, potion, opening spell
  from invisibility); on Core and below no instant buffs and no potion opener, she casts her buffs in
  the fight like any priest. The engine's wit also sinks on the lower difficulties.
- The opener is a preferred first sequence for this encounter; every step is still checked like any
  decision (legal target, worth, the party's protections).
- Still open: Miscast Magic (a party caster fails 80 % of spells, save at −2) instead of Unholy
  Blight, or as a variant if her spellbook is drawn per run; later ideas: Chant or Prayer, a
  Sanctuary trick (slip away, drink, come back; needs engine work).

**Built (2026-11-04):**
- Her creature, from `bgse/encounters.tpa`: WIS 15, the book above and a Potion of Invisibility (`POTN10`)
  in her pack; everything else of hers stays as other mods left it.
- From Hard she casts her own Aid and Protection From Good at once when she sees the party, spending
  them, before she speaks. Her own spells and not copies, so the party sees her prepare. SCS's own
  preparation adds Armor of Faith and the hammer.
- After the talk, from Hard, her opener: the potion, a watch of 4 seconds from invisibility, then Doom or
  Hold Person, whichever is worth more, then Hold Person. Each step is checked like any decision; a step
  not worth it is passed over.
- Below Hard she has the same book and the potion, but no preparation before the talk and no opener: she
  casts by worth and drinks the potion only when it is worth it, as any creature would.

**Lab checks (later):** as for Karlat, at Core Rules and at Hard and Insane (her preparation starts at
Hard), several runs for her potion. In particular, the order of talk and preparation, the potion right
after the talk, whether 4 seconds of watching feels right, and how often she drinks the potion on Core.

## 5. Greywolf (Prism's quest, Nashkel Mines)

Facts from the no-SR lab `eet-nosr-2`.

**Who:** `GREYWO`, a level-7 fighter with 66 hit points, STR 16, DEX 18, CON 16, INT 13 (normal wit),
WIS 11, THAC0 14. He fights with two swords, an Excellent Long Sword and a Long Sword in the off
hand, and is fully trained for it (three stars each in long sword and two-weapon style). Studded
Leather Armor and his dexterity give armor class about 3. He carries 46 arrows (Piercing +1, Ice,
Fire, plain) but no bow, so they are only loot. XP 1,400. Scripts: his own `GREYWOLF` above SCS's
melee script `DW1MELGE` (Karlat's).

SCS's random potions, all undroppable: healing (`DW#RND04`: half the time Extra Healing, otherwise
one or two Potions of Healing or nothing), protection (`DW#RND12`: Freedom or Invulnerability, three
times in five nothing) and battle (`DW#RND28`: Hill Giant or Stone Giant Strength, Heroism, Power or
Oil of Speed, a third of the time nothing).

**The story** (`PRISM.DLG`, `GREYWO.DLG`, `PRISMCUT.BCS`, `GREYWOLF.BCS`): Prism, a sculptor near the
Nashkel Mines (`BG5400`), stole emeralds for the eyes of his statue. If the party agrees to guard
him or takes his offer, Greywolf arrives in a cutscene ("None cross Greywolf and live!") and asks
who they are:
- standing aside: his bounty is for the gems, so he kills Prism and leaves;
- arguing: he waits a moment, then attacks Prism, and turns on the party if it stays close;
- defending Prism: the fight;
- if the party already took his bounty, he recognizes them and attacks.
Charmed, he lets them live and leaves. Handing Prism to the guards instead makes Prism fight alone.

**What SCS does** (`DW1MELGE`, as for Karlat): potions once he is hostile and sees a foe: Oil of
Speed at once, Heroism and the strength potions with a foe close, a Potion of Healing below three
quarters. He never drinks the Extra Healing or the Invulnerability, which half and a fifth of the
runs give him. Targets: badly hurt casters and thieves within reach first, otherwise the nearest
foe; he runs only while panicked.

**The engine:** a fighter of normal wit. His best buff potion comes first as the fight starts, his
healing and protection potions by worth (the Extra Healing and the Invulnerability too); targets by
worth, chasing foes who step away.

**Earlier idea (Christopher, 2026-10-29):** Greywolf is alone; perhaps give him an archer, priest or
mage companion.

**Decided (Christopher, 2026-11-04):**
- Greywolf himself stays as SCS has him, a swordsman with two blades ("das Konzept von Grey Wolf
  insgesamt mit dem, was SCS macht, auch ganz geil"); no bow for him. His potions: "Im Trank geben
  finde ich nicht schlecht", read as: the engine may drink all of them (to confirm).
- He gets a companion, an archer, which suits a mercenary who does simple jobs like bounty hunting.
- The companion's strength follows the difficulty: very weak on Core and below, clearly stronger
  above Core.

**Suggested for the companion (to tune in the lab):**
- Core and below: a young hired archer, level 2 to 3, short bow and plain arrows, few hit points;
  above Core: a seasoned archer, level 5 to 6, long bow and Greywolf's own special arrows (Ice,
  Fire, Piercing +1), which then explain why he carries arrows without a bow.
- Arrives with him in the cutscene, keeps back, turns hostile when he does and leaves when he
  leaves (standing aside, charmed Greywolf).
- In the fight Greywolf ties up the front while the archer shoots the casters; the engine's archer
  play (bow or sword by worth, stepping back by wit) does the rest.
- Name and look, left to Claude by Christopher (2026-11-04: a male human, a typical Forgotten Realms
  name, one short word or a nickname): **Kestrel**, a falcon's name beside the wolf's. Leather armor
  and a bow, in Greywolf's greys and browns. The name appears nowhere else in the game's text. On the
  low difficulties he is Greywolf's young apprentice, above Core his seasoned partner (a ranger with
  the Archer kit would suit, to tune in the lab).

**Lab checks (later):** a level 2 to 4 party at Core and at Insane, several runs for his potions; the
three choices of the talk.

## Later: Nimbul (Nashkel, chapter 3), facts gathered so far

From the no-SR lab, 2026-11-04; SCS's script for him (`DW#MG293`) is not read yet.
- `NIMBUL`, a level-7/7 mage/thief, 21 hit points, DEX 18, INT 16 (clever).
- Spells: Chromatic Orb twice, Charm Person and Armor; Power Word, Sleep, Invisibility and Mirror
  Image; Dire Charm and Minor Spell Deflection; Confusion; and SCS's Minor Sequencer `DW#MS10` (two
  Charm Person, as Silke).
- Items: Short Sword +1, Throwing Axe, the ring Topsider's Crutch, the boots Senses of the Cat, a
  Find Familiar scroll, three bard-song scrolls and a letter. Random potions: healing (`DW#RND03`,
  half the time Extra Healing), protection (`DW#RND24`: Invulnerability or Defense, half the time
  nothing) and invisibility (`DW#RND37`).
- Nashkel's area script (`BG4800`) creates him outside once chapter 3 starts. His own script
  (`SHOUTDLG`) talks on sight at every difficulty: "I am Death come for thee"; both answers end in
  his attack. Charmed, he tells a fable about a "house of iron" that hired him, a hint at the Iron
  Throne.
