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
- Instant preparation when the fight starts: the potion and Mirror Image; on higher difficulty also
  Minor Spell Deflection.
- Haste and the double Charm: yes.
- It should be clear beforehand that she is dangerous, perhaps through a short line, for example
  one Garrick says first; the text is written with Christopher.
- More ideas for a cooler encounter are welcome.

**Open (suggestions to Christopher, 2026-11-03):**
- Minor Spell Deflection is a third-level spell (`SPWI318`); her two third-level slots hold Haste and
  Hold Person. Suggested: from Hard it takes Hold Person's slot (a real slot, so fair). Or a scroll
  she reads while preparing.
- Visible preparation as a warning: she drinks the potion and casts Mirror Image when the "thugs"
  arrive. She plans an ambush herself, so she is ready, and the player sees a real caster before
  choosing.
- Garrick's line, a draft in his admiring voice: "And when she sings, folks forget their own minds.
  Best stay on her good side!" It also announces the charms.
- A spellbook drawn per run (plan, decision 13): her signature stays (the two charms, Mirror Image,
  the potion), one or two slots change from run to run; two first-level slots are empty today.

**Lab checks (later):** the engine's Silke against SCS's with the same parties, at average hit points
without double damage; the target is roughly SCS's strength, and she should feel dangerous.
