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

## Lab for BG1 fights

`BGSE-Lab/scs-reference` is an EET lab (a copy of an earlier state of Christopher's game, with Spell
Revisions); `BGSE-Lab/scs-nosr` holds BG2 only. Like Christopher's game, the EET lab carries Tweaks
Anthology's maximum hit points (for creatures in game, at level one and on level up). For encounter
tests the lab copy alone gets average hit points for creatures and the test party (full at level one),
and Insane without double damage. Spell Revisions stays in the lab until Christopher's own spells
replace it; spell results are re-checked then.

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
