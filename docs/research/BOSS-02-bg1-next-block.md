# BOSS-02 — The next BG1 encounters

Fact sheets for Christopher's next design round, 2026-11-08: rows 9, 12, 13, 14–15 and 19 of
[FIGHTS-01](FIGHTS-01-bg1-fight-list.md). The questions are options; no new encounter design is decided.
Follow [BOSS-01's way of working](BOSS-01-bg1-early-encounters.md#how-we-work-christopher-2026-11-03):
small fights stay simple and close to SCS, new prepared openers start at Hard, Core and below play
normally, and creatures use abilities they could have. Christopher decides the gameplay.

**Evidence:** the installed no-SR lab `BGSE-Lab/eet-nosr-2/game`, read only with `tools/scout.py`;
its CRE, ARE, SPL, ITM and random-treasure records; scripts and dialogues decompiled from copies
outside the game; and its `stratagems` source. **SCS is DavidW's work**; the descriptions below credit
his encounter and combat logic. No SCS code is reproduced. No game was launched or installation run.
These are file facts and expectations from the current engine, without acceptance or balance results
for these fights. NPC-mod interjections and Item Randomiser's later item placement were not fully traced.

## Reading the sheets

- HP, INT and WIS are the stored CRE values; temporary effects and potions can change them in play.
  Script slots are **O** override, **C** class, **R** race, **G** general, **D** default; omitted slots
  are empty. Counts such as `×2` are memorized copies or item quantities.
- The engine's wit uses meaningful INT/WIS. Template pairs 9/9 and 16/9 use its species/class defaults.
  Hard adds 2, Insane 4, subject to species limits; INT 14 reaches clever. Skeletons stay dull, gnolls
  stay at most normal. WIS changes how seriously a creature takes danger. See
  [MIND-01](MIND-01-wit-and-difficulty.md).
- SCS difficulty descriptions below assume its default component sliders. Its installed long-duration
  preparation can already run below Hard; Christopher's Hard rule applies to new designed openers.
- **Orders** means existing encounter-order support; **installer work** means a new creature, area,
  script or dialogue edit; **engine work** means behavior the general engine does not yet provide.

**The general engine today** ([FIGHT-01](FIGHT-01-fighter-and-monster-rounds.md),
[`encounters.lua`](../../combat-intent/encounters.lua), [`choice.lua`](../../combat-intent/choice.lua)):

- These groups have no bespoke orders. Their hooked combat scripts use their actual books and items,
  coordinate focus and avoid duplicating disables, weigh buffs, summons and dispels, and recheck before
  normal casts and attacks. SCS preparation remains; ordinary first-round spell choice belongs to the engine.
- Fighters drink a worthwhile attack buff before swinging; healing and protection compete by worth.
  A better caster spell can still come first. Undroppable usable potions count too. Offensive consumables
  are a gap: items currently enter healing/curing and defence choices, without a general attack-item
  choice. Do not count attack scrolls, Oil of Fiery Burning or Potion of Fire Breath as extra attacks.
- Archers switch between equipped weapon abilities and can kite; casters can step away to protect a cast.
  Kiting is a four-second step, at most once in eighteen seconds, weighed by danger and wit. The engine
  uses a launcher's first matching quiver ammunition; it does not select the best arrows or equip an
  unslotted spare stack. It does not value an off-hand weapon's contribution.
- Thieves use real Hide in Shadows out of enemy sight, then can flank and backstab. The installer raises
  their hiding skills within their thief-level allowance and suppresses SCS's free invisibility. They
  cannot hide in plain sight or deliberately break sight to hide yet.
- Searches follow perceived clues. Humanoids can open ordinary doors and use a key, sufficient lock
  skill or Knock; bashing is pending. Travel between areas and scripted entry restrictions remain with
  the game's scripts. No general formation or bodyguard behavior holds a front line for a caster.

**A hook gap that affected these expectations is closed (2026-11-10).** `DW#C3AS1`, `DW#C3AS2`,
`BANDIT` and `DW#C3HST` walk their creatures to party members out of sight, from above the creatures'
combat scripts; the installer did not hook those helpers, so SCS steered the walk and the pass never
reached the engine while nobody was visible. Since the engine after 06efb6a each such walk asks the
engine first: for a creature the engine drives it stands aside and the engine's search goes for that
party member itself; on sight the fight is the engine's
([HOOK-01](HOOK-01-scs-hook-placement.md), rule 14). A neutral creature (Molkar, Lamalha before their
talk) keeps its walk up to the party. The special talk scripts of Mulahey, Lamalha, Molkar and Drasus
still receive no pre-talk wrapper; new group preparation before their conversations needs a dedicated
hook.

**SCS random potions**, decoded from this lab's `RNDTRES.2DA`. The sheet's `R02`, for example, means
`DW#RND02`; the game draws it when creating the creature. U means undroppable, D droppable.
`DW#HASPT`, displayed as “Mirror”, is SCS's marker for an existing potion, with no combat power.

| Draw | Contents and odds |
| --- | --- |
| R02 U | Healing 1/3; Healing ×2 1/6; Extra Healing 1/6; nothing 1/3 |
| R04 U | Healing 1/6; Healing ×2 1/6; Extra Healing 1/2; nothing 1/6 |
| R05 D | Extra Healing, Healing ×2, Extra Healing ×2: 1/3 each |
| R11 D / R12 U | Freedom 1/5; Invulnerability 1/5; nothing 3/5 |
| R24 U | Invulnerability 1/4; Defense 1/4; nothing 1/2 |
| R25 D / R26 U | Hill Giant Strength, Heroism, Oil of Speed, Defense: 1/8 each; nothing 1/2 |
| R27 D / R28 U | Hill Giant Strength, Stone Giant Strength, Heroism, Power: 1/9 each; Oil of Speed 2/9; nothing 1/3 |
| R38 U | Invisibility 1/2; Invisibility ×2 1/4; nothing 1/4 |

SCS's general fighter scripts use their potion blocks from Core: early speed/defence, strength and
heroism when a foe closes, Healing below 75% HP. The inspected general scripts omit Extra Healing
and Invulnerability; the priests do use undroppable Extra Healing, but omit undroppable Healing.
The mage scripts here use ordinary healing potions, leaving some undroppable supplies unused.
The engine can use these healing/protection items by their effects. Lower SCS settings can also
remove ordinary potions from creatures without its existing-potion marker.

**Party ceilings:** [ENCOUNTERS, “How strong the party may be”](../ENCOUNTERS.md#how-strong-the-party-may-be)
describes optional XP banking, component 652. Caps are per character, with multiclass XP split:

| Chapter | XP cap | Fighter | Ranger/Paladin | Cleric | Druid | Thief/Bard | Mage/Sorcerer |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1–2 | 16,000 | 5 | 4 | 5 | 5 | 5 | 4 |
| 3 | 20,000 | 5 | 5 | 5 | 6 | 6 | 5 |
| 4 | 32,000 | 6 | 5 | 6 | 6 | 6 | 5 |

The likely levels below are route estimates for a full party, to confirm with Christopher;
ENCOUNTERS supplies ceilings, without measured typical levels. Balance remains average/rolled HP,
full at level one, without double damage.

## 1. Mulahey and his reinforcements

**Who:** Mulahey starts in his chamber, `BG5405`, with four tough kobold guards.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `MULAHE` | Half-orc cleric 7 | 43 | 13/11 | O `DW#MUDEP`, C `MULAHEY`, D `DW#PR288` |
| `KOBOLD7` ×4, placed guards | Kobold 4 | 25 | 9/9 | O `HELPMUL`, C `DW#GPSHT`, D `DW2MP2GE` |
| `KOBOLD`, lower-setting reinforcement | Kobold 1 | 4 | 9/9 | O `DW#GPSHT`, D `DW2MM2GE` |
| `DW#MULKA`, kobold archer | Kobold 1 | 4 | 9/9 | O `HELPMUL`, C `DW#GPSHT`, D `DW2RM2GE` |
| `DW#MULKC`, kobold commando | Kobold 1 | 7 | 9/9 | O `HELPMUL`, C `DW#GPSHT`, D `DW2RM2GE` |
| `SKELET`, lower-setting reinforcement | Skeleton 1 | 8 | 9/9 | O `DW#GPSHM`, D `DW2MC2MO` |
| `DW#MULSK`, skeleton | Skeleton 1 | 8 | 9/9 | O `HELPMUL`, C `DW#GPSHM`, D `DW2MC2MO` |
| `DW#MULSA`, skeleton archer | Skeleton 1 | 8 | 9/9 | O `HELPMUL`, C `DW#GPSHM`, D `DW2RM2MO` |

Mulahey's stored book: **1:** Armor of Faith, Remove Fear, Bless; **2:** Hold Person ×2,
Silence, 15' Radius; **3:** Strength of One ×2, Remove Paralysis, Prayer; **4:** Mental Domination.
No innates. Chain Mail, Large Shield, Morning Star, his Holy Symbol, letters `SCRL2W` and `SCRL2V`,
and R02. **Possible data fault:** his four stored third-level spells exceed the two slots in this
lab's level-7 priest table; WIS 11 grants no bonus. ENCOUNTERS records that spells beyond real slots
are unavailable. The usable set needs a runtime check before designing a Prayer opener.

The helpers have no memorized spells, innates or SCS potion draws. The four guards use swords;
ordinary reinforcement kobolds get a random sword. Archers have bows and plain arrows; commandos
have twenty Fire Arrows in their quiver, with additional arrow loot. Melee skeletons have their
natural attack and `RING99`; skeleton archers have Composite Longbows, twenty arrows and a random
two-handed melee weapon. These random weapon placeholders are Tweaks treasure rows, separate from SCS potions.

**The story** (`MULAHE.DLG`, `MULAHEY.BCS`, `DW#MUDEP.BCS`, `CD5405CH.BCS`, `BG5405.BCS`):
he mistakes the party for Tazok's agents. Agreeing lets the party approach his chest; denying it
starts the fight and calls help. Opening the chest after the bluff causes another conversation,
hostility and the same call for help. Below half HP he offers surrender once. Refusing keeps the
fight going; accepting makes Mulahey neutral, while the summoned helpers remain hostile. Opening
the chest after accepting can provoke him again and create another set of helpers. These are
dialogue/chest calls, with no timed endless wave.

Mulahey and the guards are area actors; his dialogue creates the reinforcements. `HELPMUL` brings
helpers back toward him when they cannot detect a party member and he still lives. No cross-area
pursuit was found in those scripts; what survives leaving and re-entering was not tested. His
letters lead onward. In this lab chapter 3 starts after obtaining `SCRL2V` and leaving combat in
`BG5405`, so the usual Mulahey fight is still chapter 2; BOSS-01's older chapter-on-entry wording
does not describe this installed script. A charm dialogue reveals the mine-poisoning plot;
Sirene's added interjection path was not fully followed.

**What SCS does** (`tactical_bg1/c2end.tpa`, the above scripts and `DW#PR288`):

- It makes Mulahey level 7 and the four placed kobolds level 4. Each help call creates ten:
  Core and below get six ordinary kobolds and four skeletons; Hard/Insane get four kobold archers,
  two commandos, two melee skeletons and two skeleton archers.
- Armor of Faith is instant preparation from Hard under normal creation conditions. Its
  `created_out_of_sight` branch postpones that preparation to Insane at default settings.
- Hold Person favors vulnerable warriors; Silence targets casters; Mental Domination targets
  susceptible warriors. Bless, Prayer and Strength of One support a nearby group; Remove Fear and
  Remove Paralysis rescue allies. This is conditional spell selection, with no assured full-book
  sequence. He has no Dispel Magic or Remove Magic.

**The engine:** Mulahey is normal on Core, clever from Hard. It can coordinate holds with the
helpers' attacks, value group buffs when the allies are present, and use his healing draw. Kobolds
are normal on Core/Hard and clever on Insane through the species default; skeletons stay dull and
do not kite or open doors. Archers can choose missiles or melee and kite by wit. With enough
lower-level allies nearby, the default search rule is expected to keep Mulahey near his starting
post; this is an inference from the boss rule, without a chamber test. Surrender, chest triggers
and helper creation remain the story scripts' work. A staged arrival or preparation before his
special dialogue needs installer work; a Prayer order first needs a usable slot.

**Party strength:** chapter 2, cap 16,000: up to Fighter 5/Cleric 5/Mage 4; likely levels 2–4 on a
fairly direct full-party route, unmeasured. Level-1 reinforcements and the level-7 priest present
very different control targets.

**Own spell mod:** `components.md` makes Silence enemy-only and Bless faster, so Mulahey can silence
the party amid his helpers and spend less time on a group buff; compare with those versions when installed.

**Questions for Christopher:**

1. Usual party here: levels 2–3, 3–4, or near the chapter cap?
2. Hard opener: normal choices, Hold Person, or Prayer for the guards (orders; Prayer needs the slot issue resolved)?
3. Reinforcements: keep SCS's one call, or split the same ten into two signalled arrivals (new installer work)?
4. Surrender: keep the chest trick, or give a clearer warning before renewed hostility (new dialogue work)?

## 2. Lamalha, Zeela, Telka and Maneira

**Who:** the priest-and-thief travelling party.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `LAMALH` | Human cleric 5 | 33 | 14/14 | C `LAMALHA`, R `DW#C3AS2`, D `DW#PR132` |
| `ZEELA` | Human cleric 6 | 31 | 14/14 | O `DW#C3AS2`, D `DW#PR278` |
| `TELKA` | Human fighter 5/thief 4 | 28 | 12/7 | O `DW#C3AS2`, D `DW1RANTH` |
| `MANEIR` | Human fighter 5/thief 4 | 31 | 12/7 | O `DW#C3AS2`, D `DW1RANTH` |

- **Lamalha:** **1:** Armor of Faith, Remove Fear, Bless; **2:** Silence, 15' Radius, Hold Person,
  Spiritual Hammer; **3:** Exaltation. Plate Mail, Medium Shield, Helmet, Mace, Potions of Power
  and Stone Form, R02. Her extra Flail and Bracers of Defense AC 7 have no inventory slot.
- **Zeela:** **1:** Armor of Faith, Remove Fear, Bless; **2:** Hold Person ×3; **3:** Animate Dead,
  Prayer. Splint Mail, Medium Shield, Flail, R02. Harrower +1 sits in the belt slot; spare Plate
  Mail, Flail and bracers are unslotted. Her equipped weapon is the Flail.
- **Telka:** Studded Leather Armor +1, Longbow, Short Sword, twenty Fire Arrows in the quiver.
  Twenty each of Ice, ordinary and Acid Arrows +1, plus a Shortbow, are unslotted.
- **Maneira:** Protector of the Second +2, twenty Darts of Wounding, Short Sword, Potion of Magic
  Blocking and Oil of Fiery Burning. No SCS random draw on either thief.

No one has innates; Telka and Maneira have no memorized spells.

**The story** (`BALDUR.BCS`, travel-area scripts, `LAMALHA.BCS`, `LAMALH.DLG`,
`DW#C3AS2.BCS`; SCS `tactical_bg1` assassin deployment): “first” and “second” are the list's order;
SCS can send either party first. After chapter 2 and Player1 exceeding 10,000 XP, its timer and
Tranzig/bandit-hostility progress enable an ambush. A 50/50 choice selects the first group; the
other can follow later, with a minimum-delay timer and further time/chapter conditions.

The travel maps `BG5600`, `BG5601`, `BG5700`, `BG5701`, `BG5800`, `BG5801`, `BG5900`, `BG5901`,
`BG6001` and `BG6100` contain the one-shot creation blocks for all four members. Lamalha starts
neutral and talks on sight; all three answers lead to the attack. She names Cyric and the Iron
Throne. The companions already start hostile, so file inspection alone does not guarantee that
the speech precedes their actions. There is no surrender or negotiated passage. Their pursuit
helper follows offscreen party members; escaping across a travel transition and revisiting this
encounter were not tested. The later group is separate from reinforcements to this fight.

**What SCS does** (`DW#PR132`, `DW#PR278`, `DW1RANTH`): from Hard, Lamalha prepares Armor of Faith
and Spiritual Hammer; Zeela prepares Armor of Faith. Zeela also has an above-Story offscreen Animate
Dead block when the party is near, but the higher pursuit helper may preempt it; actual summon
timing is unconfirmed. Holds press the warriors, Silence the casters, Bless/Prayer strengthen the
group, and Exaltation clears disabling conditions. Neither priest has a dispel.

SCS's thieves get free invisibility on creation and when nobody is detected, then use ranged
pressure or backstab opportunities. Their ranged script kites and switches to melee at close
range. The inspected priest script has no use for Lamalha's Power/Stone Form potions, and Maneira's
script has no Oil of Fiery Burning attack. The ordinary SCS fighter potion rules start at Core.

**The engine:** both priests are clever already on Core; the thieves are normal on Core and clever
from Hard, with low WIS making danger less discouraging. Expected behavior is separate holds,
group buffs or a summon when worthwhile, and missiles at a useful shared focus. There is no
preassigned division between the priests. Lamalha's defence potions and Maneira's Magic Blocking
can be used by worth. The thieves' free initial vanish becomes real hiding out of sight; a short
sword backstab remains possible, without a guaranteed opening backstab. Telka's unslotted special
arrows are outside the weapon selector, and offensive Oil use is missing. The higher pursuit
helper limits the search/hiding expectations until its hook gap is fixed. Pre-talk group
preparation needs a new hook.

**Party strength:** normally chapter 3, cap 20,000: Fighter/Cleric/Mage 5, Thief 6; likely levels
3–5. A delayed ambush can happen in chapter 4, whose cap is 32,000, and the order of the two parties varies.

**Own spell mod:** enemy-only Silence lets Lamalha use it near Zeela safely; faster Bless changes
the cost of both priests' group preparation.

**Questions for Christopher:**

1. Strength: stay close to SCS, or add a little pressure through coordinated Hard openers?
2. Arrival: caught walking, or visible priest preparation before the threat (new group/talk hook)?
3. Hard priest roles: normal choices, or Zeela summons while Lamalha opens with Silence (orders)?
4. Thieves: missiles with opportunistic hiding, or deliberate retreats to hide (new engine work)?
5. Hunting (also for sheets 3 and 4): both assassin parties and the camp's bandits walk to the party unseen, as SCS has it, from a script the engine leaves alone. They were sent after the party, so keep that, or let them go only by what they perceive (new installer work)?
   **Answered, Christopher 2026-11-10:** taken over as it is for now. The groups come straight at the
   party and surround it, as with SCS; the engine does the walk (rule 14 of HOOK-01). Each ambush gets
   cooler later, in its own design round.

## 3. Molkar, Drakar, Halacan and Morvin

**Who:** the more physical travelling party.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `MOLKAR` | Human fighter 6 | 55 | 10/11 | C `MOLKAR`, R `DW#C3AS1`, D `DW1MELGE` |
| `DRAKAR` | Human fighter 5/cleric 5 | 39 | 10/11 | O `DW#C3AS1`, D `DW#PR72` |
| `HALACA` | Gnome fighter 4/mage 4 | 26 | 15/9 | O `DW#C3AS1`, D `DW#MG177` |
| `MORVIN` | Dwarf fighter 5 | 56 | 11/9 | O `DW#C3AS1`, D `DW1MELGE` |

- **Molkar:** Mail of the Dead +2, Helmet, Excellent Long Sword with an ordinary Long Sword in
  his off hand, Potion of Heroism, R02 and the existing-potion marker. No spells.
- **Drakar:** **1:** Armor of Faith, Remove Fear, Bless; **2:** Hold Person, Spiritual Hammer,
  Draw Upon Holy Might; **3:** Exaltation. Chain Mail, Medium Shield, Helmet, Excellent Morning
  Star, Potion of Absorption, R02 and the marker. The spare Plate Mail and Heroism potion are unslotted.
- **Halacan:** **1:** Chromatic Orb, Burning Hands, Shield; **2:** Melf's Acid Arrow, Mirror Image.
  Battle Axe, War Hammer, Helmet; scrolls of Color Spray, Sleep and Detect Illusion. No random
  potion. The CRE's third level byte is 5, but his two active classes are 4/4.
- **Morvin:** Splint Mail, Helmet, Battle Axe, R02 and R26; an unslotted spare Chain Mail. No spells.

No innates on any of the four.

**The story** (`MOLKAR.BCS`, `MOLKAR.DLG`, `DW#C3AS1.BCS`): the same global/travel creation system
as sheet 2 creates this party, possibly first. Molkar talks on sight. All three replies end in
combat, and he refuses to name his employer. He starts neutral, his companions hostile; speech
timing has the same caveat as Lamalha's. There is no surrender or extra scripted reinforcement.
The higher helper walks to offscreen party members; escape/re-entry across areas remains untested.

**What SCS does:** Drakar prepares Armor of Faith, Spiritual Hammer and Draw Upon Holy Might from
Hard. Halacan gets Shield from Core, Mirror Image from Hard; below Hard he can spend his first
ordinary cast on Mirror Image. His few attacks are Acid Arrow against casters, Chromatic Orb,
and Burning Hands when its close-range conditions fit. Drakar follows holds, support and cures
with melee. Molkar and Morvin use the general Core-and-up potion and melee rules: buff when the
fight closes, exploit hurt nearby targets, then attack. No fixed four-person opening combination,
no memorized dispel. A Detect Illusion scroll in Halacan's pack is no memorized detection spell.

**The engine:** Halacan is clever on Core; the other three remain normal through Hard and become
clever on Insane. It should coordinate a spell disable with melee pressure, weigh Drakar's support,
let the fighters drink useful buffs and heal with either Healing or Extra Healing, and let Halacan
kite when protecting a cast is worth it. These are general-policy inferences. Molkar's second
sword still works in the game, but the engine does not count its off-hand contribution when
comparing attacks and buffs. Halacan's attack scrolls need general offensive-item support before
they can enter his choices. The pursuit-helper and special-dialogue hook gaps apply here too.

**Party strength:** usually chapter 3, cap 20,000 and likely levels 3–5; chapter 4 and cap 32,000
are possible if this is the later ambush. Party composition matters against three sturdy melee
characters and a mage with only 26 HP.

**Own spell mod:** Mirror Image refreshes without stacking and area damage bypasses its images,
which matters for Halacan's survival; Bless is faster. Sleep waking on damage matters if his
scroll is eventually made usable by the engine.

**Questions for Christopher:**

1. Strength: keep this a small SCS-like fight, or emphasize the fighters' shared focus from Hard?
2. Drakar's Hard opener: Hold Person, Draw Upon Holy Might, or normal choices (orders)?
3. Hired targets: a light protagonist preference, or ordinary target choice (orders)?
4. Halacan's attack scrolls: leave as loot, or let him cast them (new engine work)?

## 4. The Bandit Camp and Tazok's tent

**Who, exterior `BG1900`:** twenty-five main combatants are placed: Taurgosz, Ardenor,
ten bandits, five hobgoblins, four Black Talon Elites and four hobgoblin elites. `CREDUS`, `BANDCR`
and the hobgoblin `GLART` are additional actors. They have no spells or innates.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `TAUGOS`, Taurgosz Tenhammer | Human fighter 8 | 56 | 11/12 | O `DW#TAUG`, C `BANDIT`, R `DW#PRSHT`, D `DW1MELGE` |
| `ARDENO`, Ardenor Crush | Hobgoblin 7 | 48 | 14/12 | O `BANDIT`, C `DW#PRSHT`, D `DW2MS2GE` |
| `BANDITC` ×10 | Human fighter 3 | 23 | 12/12 | O `DW#PRSHT`, R `BANDIT`, D `DW1RANGE` |
| `HOBGOBC` ×5 | Hobgoblin 4 | 25 | 9/9 | O `DW#PRSHT`, C `HOBGOBC`, D `DW1MELGE` |
| `DW#C3CBT` ×4 | Human fighter 5 | 31 | 12/12 | O `BANDIT`, C `DW#PRSHT`, R `DW#GPSHT`, D `DW1RANGE` |
| `DW#C3CHE` ×4 | Hobgoblin fighter 3 | 16 | 9/9 | O `HOBGOBC`, C `DW#PRSHT`, R `DW#GPSHT`, D `DW1RANGE` |
| `CREDUS` | Human fighter 1 | 18 | 12/12 | O `BANDIT`, C `DW#PRSHT`, R `DW#CREDU`, D `DW1RANGE` |
| `BANDCR` | Human fighter 1 | 8 | 12/12 | O `DW#PRSHT`, D `DW1RANGE` |
| `GLART` | Hobgoblin 1 | 8 | 9/9 | O `DW#PRSHT`, C `HOBGOBC`, D `DW1MELGE` |

- **Taurgosz:** Full Plate, Medium Shield +1, Excellent War Hammer, Potions of Fortitude and Fire
  Breath, R04/R11/R27. **Ardenor:** Studded Leather, Helmet, Bastard Sword (`COMPS01`); no potion draw.
- **Bandits:** Leather, Long Sword, Shortbow and twenty arrows; Credus has a Composite Longbow.
  **Hobgoblins/GLART:** Leather, Helmet, Bastard Sword. No SCS potion draws on these ranks.
- **Black Talon Elites:** Splint Mail, random Longbow/Composite Longbow and one-handed blade, six
  special arrows drawn from fire/ice/acid/biting/piercing, ten Arrows +1 and twenty ordinary arrows.
  Extra Arrows of Biting are unslotted. **Hobgoblin elites:** random Leather/Studded Leather, bow
  and blade, twenty Arrows of Biting and eighteen ordinary arrows. The `CDRD...` random equipment
  rows come from Tweaks and resolve through `RNDTRES.2DA`; these elites have no SCS potion draw.

**Who, tent `BG1901`:** Raemon, Britik, Hakt and Venkt, plus three Black Talon Elites and two
hobgoblin elites: nine fighters in total. Ender Sai is the prisoner, outside the enemy roster.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `RAEMON` | Human fighter 5 | 35 | 12/12 | O `DW#C3HST`, C `DW#PRSHT`, R `SHOUTDLG`, D `DW1RANGE` |
| `BRITIK` | Gnoll fighter 5 | 38 | 9/9 | O `DW#C3HST`, R `DW#GPSHT`, D `DW2MS2GE` |
| `HAKT` | Hobgoblin 5 | 30 | 9/9 | O `DW#C3HST`, C `DW#PRSHT`, R `DW#GPSHT`, D `DW1RANGE` |
| `VENKT` | Human conjurer 6 | 31 | 18/9 | O `DW#C3HST`, D `DW#MG511` |
| `DW#C3BT1`, `DW#C3BT2`, `DW#C3BT3` | Human fighter 5 | 31 | 12/12 | O `DW#PRSHT`, C `DW#C3HST`, R `DW#GPSHT`, D `DW1RANGE` |
| `DW#C3HB1`, `DW#C3HB2` | Hobgoblin fighter 3 | 16 | 9/9 | O `DW#PRSHT`, C `DW#C3HST`, R `DW#GPSHT`, D `DW1RANGE` |

- **Raemon:** Leather, Long Sword, Composite Longbow, ten Ice Arrows and twenty ordinary arrows,
  R02/R25. **Britik:** Halberd, Potion of Stone Giant Strength; base AC 2, with no worn armour.
  **Hakt:** Dead Shot +2, Leather, Bastard Sword, twenty Biting and twenty ordinary arrows.
  The five extra elites carry the equipment of their exterior counterparts. Only Raemon has SCS
  potion draws among these eight; none has memorized spells or innates.
- **Venkt:** **1:** Chromatic Orb, Charm Person, Sleep ×2, Shield; **2:** Melf's Acid Arrow,
  Power Word: Sleep, Mirror Image; **3:** Monster Summoning I, Remove Magic, Protection From
  Normal Missiles. No innate sequencer. Mage Robe of Fire Resistance, Quarterstaff, ten Darts,
  two slotted Healing potions and another unslotted, scrolls of Color Spray, Blindness, Friends
  and Spell Thrust, and the existing-potion marker. No SCS random potion draw.

**Tazok's optional recruitment scene:** the cutscenes create `TAZOK_`, ogre fighter 9, HP 98,
INT/WIS 11/12, C `TAZOK`, D `DW2MS2GE`; Plate Mail, Legacy of the Masters, Two-handed Sword,
Potion of Strength, Oil of Speed and the minimum-HP item `MIHP1`, with no spells or innates. He is the
recruitment tester and leaves on patrol; the usual tent fight has the roster above.

**The story** (`TEVEN`, `RAIKEN`, `TAZOK_`, `RAEMON`, `TAUGOS`, `ENDER` dialogues;
`BANCUT01/02`, `BG1900/1901`, `BANDIT`, `DW#TAUG`, `DW#C3HST` scripts):

1. The party can arrive as enemies or infiltrate through Teven/Raiken. Their recruitment
   cutscenes bring it to camp and create Tazok. He can accept the recruit's answer or test the
   party in combat; below half HP he ends that test, then leaves. Added companion interjections
   were not fully traced, so this describes the base recruitment branches read here.
2. An outdoor bandit detecting the party or its summon during hostility raises the camp alarm.
   After two rounds, if the party has not entered the tent, `BG1900` creates its nine defenders
   outside. `BG1901` removes the original interior copies when entered. This is one mobilization.
3. Entering the tent first records the other route and prevents that outdoor creation. Raemon's
   two reply paths make all nine hostile. The exterior and tent travel triggers require the party.
4. After Venkt dies, if the party's joined-bandits state still holds, Taurgosz can confront it
   at the exit and create seven more: three `BANDITC`, two `HOBGOBC`, one `DW#C3CHE` and one
   `DW#C3CBT`. Both final replies lead to combat.
5. Ender Sai explains the Iron Throne/Cloakwood connection and leaves. Obtaining `SCRL2Z`, then
   leaving combat, advances chapter 3 to 4 and reveals the Cloakwood route. After that chapter
   change, SCS closes the outside-to-tent travel trigger until Ardenor and Taurgosz are dead;
   the party is told to fight or flee. The letters can advance the plot before every bandit dies.

Fleeing inside the same area can provoke the helper scripts' offscreen pursuit. Tent travel is
story-controlled; the engine's ordinary door logic cannot open that travel restriction. Leaving
the camp and returning, and every companion-specific infiltration branch, remain unconfirmed in play.

**What SCS does** (`tactical_bg1/c3end.tpa`, `ssl/sealtent.ssl`, `tazoktent.ssl`, `dw#taug.ssl`,
`bandit.ssl`; installed scripts): it strengthens and equips the camp, brings the tent fighters
out after the alarm, and creates the infiltration exit confrontation. Those roster/route changes
in the installed scripts have no Hard-only condition. Difficulty still changes combat and potion use.

Venkt has Shield and Protection From Normal Missiles from Core, Mirror Image from Hard; below
Hard Mirror Image can take his first normal cast. He can summon, dispel party buffs with Remove
Magic, use Sleep against low-level foes and Power Word: Sleep against low HP, then Acid Arrow,
Chromatic Orb and Charm Person by their conditions. There is no guaranteed “summon then dispel”
sequence. The archers use special ammunition, wounded/caster targeting, kiting and melee when
pressed. Taurgosz and Britik use their melee/potion scripts. Taurgosz's Fire Breath is not used
by the inspected general script.

**The engine:** Venkt and Ardenor are clever on Core. The human archers become clever on Hard,
Taurgosz on Insane; ordinary hobgoblins reach clever on Insane, Britik stays normal. It should
coordinate missile focus, avoid duplicate disabling casts, value Venkt's Remove Magic
against real removable buffs and summon early when the fight looks long. Venkt has only 31 HP;
kiting and his missile protection matter, without a bodyguard formation to keep melee off him.
Taurgosz/Britik can use their buff potions and healing; the engine has no general Fire Breath
attack-item choice. Ammunition selection, higher helper pursuits and physical choke points need
attention in the later lab. The existing alarm and cutscene transitions remain as installed;
there are no new encounter phases in the engine by default.

**Party strength:** the normal approach and tent are chapter 3, cap 20,000: Fighter/Cleric/Mage 5,
Thief 6; roughly levels 3–5 for a full party, unmeasured. The exit confrontation can follow the
chapter change to 4, when banking allows 32,000; whether levels rise before it depends on when
the player levels up. Do not use that later ceiling for the first approach.

**Own spell mod:** Sleep and Power Word: Sleep wake on damage, so missile focus and sleep targets
must be judged together; area damage bypassing Mirror Image makes Venkt more exposed.

**Questions for Christopher:**

1. Outdoor alarm: keep SCS's single mobilization, or stagger the same defenders with visible warning (new area-script work)?
2. Infiltration exit: keep Taurgosz's fight, or allow a convincing escape dialogue (new dialogue work)?
3. Venkt's Hard opener: summon, control, or normal choices (orders)?
4. Tent fighters: free target choice, or a front line protecting Venkt (new engine work)?

## 5. Drasus, Genthore, Kysus and Rezdan

**Who:** four placed actors at the Cloakwood Mine entrance, `BG1800`.

| CRE | Class and level | HP | INT/WIS | Scripts |
| --- | --- | ---: | --- | --- |
| `DRASUS` | Human berserker 10 | 63 | 14/13 | O `DW#GPSHT`, C `DRASUS`, D `DW1MELBE` |
| `GENTHO` | Human fighter 9 | 69 | 14/13 | O `DW#GPSHT`, D `DW1RANGE` |
| `KYSUS` | Human conjurer 11 | 68 | 18/16 | O `DW#GPSHT`, D `DW#MG550` |
| `REZDAN` | Human mage 9, enchanter kit | 56 | 18/15 | O `DW#GPSHT`, D `DW#MG551` |

- **Drasus:** innates Enrage ×3 (`C0BER#00`) and Power Attack (`C0FIG01`); no priest/wizard book.
  Chain Mail, Medium Shield, Morning Star +1, Frost Giant Strength ×2, Magic Shielding, his bounty
  letter, R04/R11 and SCS's existing-potion marker. This CRE has no Boots of Speed equipped;
  Item Randomiser's later distribution was not traced, so permanent speed is unconfirmed here.
- **Genthore:** no spells or innates. Fallorain's Plate +1, Large Shield, two stacks of five
  Throwing Axes, Battle Axe, R04/R12/R28. His default script is ranged: expect throws as well as melee.
- **Kysus:** **1:** Magic Missile ×2, Sleep, Chromatic Orb, Shield; **2:** Mirror Image ×3,
  Invisibility, Vocalize; **3:** Icelance, Minor Spell Deflection, Slow, Protection From Normal
  Missiles, Remove Magic; **4:** Monster Summoning II, Confusion, Stoneskin, Minor Globe of
  Invulnerability; **5:** Conjure Lesser Earth Elemental, Conjure Lesser Air Elemental, Monster
  Summoning III, Shadow Door. Innate Minor Sequencer `DW#MS0` contains Melf's Acid Arrow ×2.
  Traveler's Robe, Dagger, twenty slotted Throwing Daggers, Fireshield (Red) scroll, R05/R24/R38;
  another ten Throwing Daggers are unslotted.
- **Rezdan:** **1:** Blindness, Sleep ×2, Charm Person, Armor; **2:** Glitterdust, Ray of
  Enfeeblement, Mirror Image, Vocalize; **3:** Dire Charm ×3, Remove Magic; **4:** Monster
  Summoning II, Dimension Door, Stoneskin; **5:** Chaos ×2. Innate Minor Sequencer `DW#MS9`
  contains Mirror Image and Invisibility. Mage Robe of Cold Resistance, Quarterstaff, twenty
  Darts, R04/R24.

**The story** (`BG1800.ARE`, `DRASUS.BCS`, `DRASUS.DLG`): the group is already placed near the
mine approach. Drasus talks on sight; all three ordinary replies make the four hostile. There is
no surrender or scripted extra wave in the inspected encounter scripts; extra creatures come
from the mages' summons. Winning clears the approach; chapter 4 continues into the mine.
An added Sirene interjection was not fully traced. Genthore's CRE names dialogue `GENTHO`, and
Kysus's names `KYSUS`, but neither DLG exists in this lab; Drasus's main conversation exists.
These are dangling data references, without evidence that the main fight fails.

No encounter-specific cross-area chase was found. The general SCS/engine pursuit still matters
if the party retreats inside the area; flight through the mine entrance and return were not tested.

**What SCS does** (`tactical_bg1/drasus.tpa`, `DW1MELBE`, `DW1RANGE`, `DW#MG550/551`):

- The encounter component raises each member by two levels and adds Drasus's Magic Shielding and
  Frost Giant Strength; this installed upgrade is not conditional on Hard.
- Above Story, the mages have the free long-duration Stoneskin preparation and Rezdan Armor.
  Kysus gets Shield, Protection From Normal Missiles and Minor Spell Deflection from Core.
  Hard adds short preparation including Mirror Image, Kysus's Shadow Door and Minor Globe;
  the alternate `created_out_of_sight` branch shifts short preparation to Insane at default settings.
- Kysus can strip buffs, use the double Acid Arrow sequencer, control groups with Confusion/Slow,
  and summon monsters or lesser elementals; the summoning blocks have weighted passes, without
  one fixed chain. Rezdan emphasizes Chaos, Dire Charm, Glitterdust, Blindness and Ray of
  Enfeeblement, plus his own summons and Remove Magic. Vocalize answers silence. His defensive
  sequencer restores Mirror Image/Invisibility when his protection or HP conditions call for it.
- Drasus closes with a strength potion and his berserker melee script; Genthore uses the ranged
  fighter rules. Some supplies go unused: the general fighters omit Extra Healing/Invulnerability,
  and these mage scripts omit Rezdan's undroppable healing and Kysus's undroppable Invisibility.
  Whether SCS's rage call matches the kit mod's renamed Enrage was not established.

**The engine:** all four are clever already on Core. Expected strengths are coordinated dispels
and control, summons valued over the group's fight, potion use, Drasus's real kit abilities and
Genthore's choice between thrown and swung axes. Its target selection still permits attacking
through Stoneskin to remove skins. It can use Rezdan's Dimension Door to a perceived search clue,
spending the slot, rather than acquiring the party's unseen position. Those are general-policy
expectations; the terrain, sequencers and kit abilities need the eventual encounter lab.

Specific gaps: strength-reducing debuffs have no value in `harm.weaken`, so Ray of Enfeeblement
can be neglected; the effect is classified but its lost weapon damage is not scored. Movement
estimates use the default speed, so any eventual speed boots or Oil of Speed do not fully change
the movement model. There is no automatic “Drasus protects Rezdan” role or group preparation
before `DRASUS`'s talk. Offensive scroll support and cross-area pursuit remain outside the
current general behavior.

**Party strength:** chapter 4, cap 32,000: Fighter/Cleric 6, Ranger/Paladin 5, Thief 6, Mage 5;
likely levels 4–6 across a full party, unmeasured. Both enemy mages have fifth-level spells while
a single-class party mage at the cap has third-level spells, which makes preparation and control decisive.

**Own spell mod** (`chriz-bg-magic-batches/specs/docs/components.md`, read only):

- Confusion and Chaos last four rounds at these caster levels; Rezdan's Blindness lasts four
  rounds. Sleep wakes on damage. These change how long the group can exploit a disabled target.
- Mirror Image refreshes without stacking and area damage bypasses it. Minor Spell Deflection
  covers spell levels 1–4, with four spell levels absorbed, so Kysus's protection is narrower.
- The wizard lesser elementals regain a three-round control contest and a 15% hostile outcome.
  That affects Kysus's summon timing and risk; the engine's valuation of that contest is unconfirmed.
  Do not tune his elemental opener from this lab's current summon timing alone.

**Questions for Christopher:**

1. Strength: SCS's current step up, or more Hard pressure through coordinated opening spells?
2. Hard opening: Kysus summons and Rezdan controls, or both choose freely (orders)?
3. Genthore: keep throwing and melee, or make him a front-line guard (new combat-role work)?
4. Preparation: SCS's current timing, or visible group preparation before Drasus speaks (new group/talk hook)?

## Sources and checks to carry into the design batch

The CRE names and script slots above identify the installed resources for another scout pass.
Story evidence is the decompiled dialogues/scripts named in each sheet, plus the areas' actor
tables; sequencer payloads were read from their SPL effects. SCS preparation and attacks were read
from the actual generated combat scripts, supported by `stratagems/tactical_bg1`, `genai`, `mage`,
`priest` and `potion` sources. Random draws come from the installed `RNDTRES.2DA`.

Engine expectations come from FIGHT-01 and MIND-01, checked against
[`mind.lua`](../../combat-intent/mind.lua), [`arsenal.lua`](../../combat-intent/arsenal.lua),
[`harm.lua`](../../combat-intent/harm.lua), [`abilities.lua`](../../combat-intent/abilities.lua),
[`care.lua`](../../combat-intent/care.lua), [`defence.lua`](../../combat-intent/defence.lua),
[`search.lua`](../../combat-intent/search.lua), [`orders.lua`](../../combat-intent/orders.lua),
[`hook_rule.py`](../../tools/hook_rule.py) and the script-selection loop in
[`setup-bgse.tp2`](../../bgse/setup-bgse.tp2).

Before claiming these encounters work with the engine, check the helper pursuit/talk coverage,
Mulahey's usable third-level slots, the unslotted/mis-slotted inventory entries, offensive item
support, Molkar's off-hand valuation, Rezdan's strength drain and the elemental contest. The later
lab should cover each dialogue route, surrender, alarm, flight/re-entry and chapter transition,
with SCS and engine comparisons at Christopher's chosen party strength. No such live result is
claimed here, and no engine or data fix was made as part of these fact sheets.
