# BOSS-03 — BG1 Cloakwood, Mines & Iron Throne (Read-Only Fact Dossier)

Fact sheets for the next BG1 encounter block — Centeol's Lair, Cloakwood Mines (Hareishan,
Natasha & Ogre Mage, Davaeorn), and the Iron Throne top floor — plus quick checks on Seniyad,
Amarande, and the Seven Suns doppelgangers. **Read-only research dossier: no gameplay changes or
encounter orders were authored here; Christopher decides the gameplay.**

**Evidence:** read directly from the installed lab `BGSE-Lab/eet-tour/game` (EET + SCS +
`chriz-bg-magic` `f5e735d`) via its CRE, ARE, SPL, ITM, BCS and DLG resources. **SCS is DavidW's
work**; descriptions below credit his encounter, preparation and spawn scripts without reproducing
SCS code. Balance baseline remains average/rolled HP (full at level 1), no double damage on Insane,
and no vanilla wands on designed enemies unless Christopher explicitly decides otherwise.

---

## 1. Centeol's Lair (`BG2101`, Cloakwood 2)

**Area script (`BG2101.BCS`):** places `CDIA430` (*Shout* scroll) in `Container1`; no ambush or
reinforcement spawn logic in the area script itself.

| CRE | Spawn | Class & level | HP / AC / THAC0 | Scripts & key gear / abilities |
| --- | --- | --- | --- | --- |
| `CENTEO` | `(576, 426)` | `SPIDER_CENTEOL` lvl 11, NEUTRAL | HP 36, AC 10, THAC0 9, 1 APR, DEX 3, INT 16 | **O** `CIT`, **C** `CENTEOL`, **D** `DW1MELGE`, `CENTEO.DLG`, `ANTIWEB`, quick 1 `WAND06` (*Wand of Frost*); pack `RING23`, `RING18`, `MISC90`, `SW2H06` |
| `ETTERC` ×2 | `(649, 269)`, `(701, 293)` | Ettercap lvl 5 | HP 40, AC 4, THAC0 11, 3 APR | `DW#GPSHM` + `ETTERCAP` |
| `SPIDGI` ×2 | `(858, 426)`, `(856, 474)` | Giant Spider lvl 4 | HP 35, AC 4, THAC0 13, 1 APR | `DW#GPSHM` + `DW#SPIDG`, `SPIN148` (*Web Tangle*) |
| `SPIDSW` ×2 | `(531, 247)`, `(451, 314)` | Sword Spider lvl 5 | HP 45, AC 3, THAC0 12, 4 APR | `DW#GPSHM` + `DW#SPIDS` |

- **Opening & dialogue (`CENTEOL.BCS` / `CENTEO.DLG`):** initiates `CENTEO.DLG` when `See([PC])`,
  `!Allegiance(Myself, ENEMY)`, `!StateCheck(Myself, STATE_CHARMED)`, and `NumTimesTalkedTo(0)`, or
  turns hostile if attacked while neutral. Every non-charmed hostile exit casts
  `ForceSpellPoint([526.384], SPIDER_SUMMON)` and `ForceSpellPoint([635.376], SPIDER_SUMMON)` (`SPWI986`,
  summoning 2× `SPIDGI`) and executes `Enemy()`. `WEIGHT #0` (`STATE_CHARMED`) grants lore and adds
  journal entry `#226909` instead.
- **Open design questions for Christopher:**
  - `CENTEO` carries `WAND06` in quick slot 1 while otherwise immobile/weak physically (HP 36, AC 10,
    DEX 3); under the no-vanilla-wand guideline, should `WAND06` stay as loot or be replaced/removed in
    combat?
  - Should the two `SPWI986` *Spider Summon* spawns remain scripted in `CENTEO.DLG`, or should she
    receive a Hard+ tactical/web opener or Phase Spiders (`SPIDPH`)?

---

## 2. Hareishan, Cloakwood Mines Level 1 (`BG1804`)

**Area script (`BG1804.BCS`):** empty. Floor traps present: `Trap1` (`GTLB`) and `Trap2` (`GTMM`).

| CRE | Spawn | Class & level | HP / AC / THAC0 / Saves | Scripts & gear |
| --- | --- | --- | --- | --- |
| `HAREIS` | `(855, 1251)` | Mage lvl 9, Enchanter (`0x200`), ENEMY | HP 41, THAC0 18, INT 16, DEX 15, saves 13/9/11/13/10 | **O** `DW#GPSHT`, **D** `DW#MG180`; `CLCK14`, `BRAC03`, quick 3 `POTN26`, random `DW#RND06`/`23`/`38`, unslotted `SCRL1I`, `DAGG01` |
| `IRONELIT` ×2 | `(779, 1123)`, `(686, 1233)` | Archer lvl 5 | — | `CDRDLBW` + `6× CDRDBTE` |
| `IRONGUAR` ×5 | Arena guards | Archer lvl 5 | — | `BOW03` + `20× AROW12` (*Arrows of Biting*) |
| `IRONGU` ×8 | Arena guards | Fighter lvl 5 | — | Splint mail melee guards |

- **Hareishan's stored book & SCS script (`DW#MG180.BCS`):**
  - **1:** `SPWI116` ×2, `SPWI106` ×2, `SPWI102`
  - **2:** `SPWI219` ×2, `SPWI212`, `SPWI206`
  - **3:** `SPWI316`, `SPWI312`, `SPWI311`, `SPWI302`
  - **4:** `SPWI411` ×2 (*Emotion: Hopelessness*), `SPWI406` (*Minor Globe of Invulnerability*)
  - **5:** `SPWI508` ×2 (*Chaos*)
  - **Innate:** `DW#MS11` (*Minor Sequencer*: `SPWI212` *Mirror Image* + `SPWI114` *Shield*).
  - **SCS preparation note (`DW#MG180.BCS`):** fires free overnight `dwsw408` (*Stoneskin*, without
    `RemoveSpell`) and checks `HaveSpell(WIZARD_INVISIBILITY)` -> `dw#silin` + `RemoveSpell` as an
    initial prebuff. Note that our new overnight `SPWI408` rest-buff parity now gives Enchanter
    casters with 4th-level slots free 12h `Stoneskin` natively before combat contact without spending a
    memorized slot.
- **Open design questions for Christopher:**
  - `HAREIS` starts `ENEMY` with `DW#GPSHT` and has unslotted `SCRL1I`/`DAGG01`; any Hard+ opener
    preference (e.g. `SPWI508` *Chaos* vs `SPWI411` *Emotion*) or arena alert changes, or let the
    general engine run her 4th/5th-level enchantment kit plus elite archers?

---

## 3. Natasha & the Ogre Mage, Cloakwood Mines Level 3 (`BG1802`)

**Area script (`BG1802.BCS`):** empty. Scattered area guards: `IRONGU`, `IRON3`/`IRON4`/`IRON11`, and
`HOBGBEG9`/`HOBGBEG1`/`HOBGBEG4`.

| CRE | Spawn | Class & level | HP / AC / THAC0 | Scripts & gear |
| --- | --- | --- | --- | --- |
| `NATASH` | `(3092, 861)` | Mage lvl 9, Invoker (`0x800`), ENEMY | HP 41 | **O** `DW#GPSHT`, **D** `DW#MG287`; `CLCK13`, quick 2 `SCRL1O` (*Slow*), `DW#RND06`, `DW#RND24` |
| `OGREMA03` | `(2998, 1907)` (southern room) | Ogre Mage lvl 5, NEUTRAL | HP 39, AC 4, THAC0 14, 2 APR | **O** `DW#SHDLG` (`OGRMA2`), **D** `DW#MG306`; `SW1H44` (*Excellent Katana*), `MAGE01` (*Sandthief's Ring*), `3× RNDTRE09` |

- **Spellbooks:**
  - `NATASH`: **1:** `SPWI112` ×2, `SPWI103`, `SPWI118`, `SPWI114` | **2:** `SPWI204`, `SPWI219` ×2,
    `SPWI212` | **3:** `SPWI312`, `SPWI311`, `SPWI318`, `SPWI302` | **4:** `SPWI430` (*Shout*),
    `SPWI404` (*Ice Storm*), `SPWI406` | **5:** `SPWI503` ×2 (*Cone of Cold*) | **Innate:** `DW#MS11`
    (*Minor Sequencer*). Also receives overnight `SPWI408` parity via wiz lvl 4+ slots.
  - `OGREMA03`: `SPWI116`, `SPWI103`, `SPWI104`, `SPWI114`, `SPWI220`, `SPWI212`, `SPWI311`.
- **Open design questions for Christopher:**
  - `NATASH` fights alone in her chamber unless nearby guards hear the call, and carries quick-slotted
    scroll `SCRL1O` (offensive scroll use is not in general item choice). Should `BG1802` add a
    personal escort/guard on Hard+ or keep her as a clean Invoker duel?
  - `OGREMA03` is a neutral `DW#SHDLG` (`OGRMA2`) talk-on-sight Ogre Mage with `MAGE01` ring in the
    southern chamber; keep default or add pre-talk prep orders?

---

## 4. Davaeorn, Cloakwood Mines Level 4 (`BG1803`)

**Key actors & traps:**

| CRE / Object | Spawn | Class & level | HP / AC / THAC0 / Saves | Scripts & gear |
| --- | --- | --- | --- | --- |
| `DAVAEO` | `(872, 817)` | Mage lvl 11, Invoker (`0x800`), NEUTRAL | HP 45, AC 3, THAC0 17, INT 18, DEX 16, CON 13, saves 4/3/5/7/5 | **O** `DAVAEORN`, **D** `DW#MG103`, `DAVAEO.DLG`; `MAGE05` (*Ring of Free Action*), `MISC83`, `DW#RND06`, `DW#RND24`; unslotted `WAND02`, `POTN02`, `SCRL79`/`78`/`73` |
| `DW#DAVHO` ×2 | `(787, 800)`, `(871, 873)` | Battle Horror lvl 6 | HP 58, AC -2, THAC0 10, 3 APR | `FBLADE`, immune to `SPWI308`/`304`/`215` & 100% fire/elec; march to `[1332.401]`, `Kill(Myself)` if Davaeorn dies |
| `IRON5` | `(1332, 401)` | Guard lvl 5 | — | Entrance hall guard |
| `JELLYMU` | `(976, 1606)` | Mustard Jelly | — | Side room |
| Floor traps ×5 | Hallway / chamber | `BATTLEHO` ×2 (Hard+), `GTST`, `GTGW` ×2 | — | 2 Battle Horrors summoned by traps on Hard+ |

- **Davaeorn's stored book:**
  - **1:** `SPWI118` ×2, `SPWI112` ×3
  - **2:** `SPWI204` ×2, `SPWI227`, `SPWI212` ×2
  - **3:** `SPWI302`, `SPWI308`, `SPWI304` ×2, `SPWI311`
  - **4:** `SPWI406`, `SPWI402` ×3 (*Dimension Door*)
  - **5:** `SPWI524`, `SPWI523` ×2 (*Sunfire*), `SPWI522`
- **Scripts & room mechanics (vital hook/control details):**
  - `BG1803.BCS` spawns up to **5 waves** (`SIX_ROUNDS` timer) of `2× DW#DAFLA` + `2× DW#DAFLU` at
    `[1700.180]` once `Davaeorn_Activate_Horrors != 0`.
  - `DAVAEORN.BCS` sits **above** `DW#MG103` (default) and contains `Detect([PC])` talk + **4 corner
    `Dimension Door` teleport blocks** (`Range(LastSeenBy(Myself), 5)` with `TWO_ROUNDS` timer and
    `Wait(3)`). While `DAVAEORN.BCS` is unhooked in the override slot, those teleport blocks can
    preempt normal round decisions above the engine hook.
  - `DW#MG103.BCS` applies `dw#ms13B` + `WIZARD_WEB` + `WIZARD_STINKING_CLOUD` at `[1072.653]` plus free
    `dwsw408` (*Stoneskin*). Note Davaeorn wears `MAGE05` (*Free Action*) so he moves freely inside his
    own *Web*, and Battle Horrors are immune to *Lightning Bolt*, *Fireball*, and *Web*.
- **Open design questions for Christopher:**
  - **Override script priority:** Should the engine take over `DAVAEORN.BCS`'s four `Range(5)` corner
    teleports (using his 3 memorized `SPWI402` slots cleanly inside the engine's decision loop) and/or
    pre-talk preparation?
  - Keep `DW#MG103`'s choke-point `Web` + `Stinking Cloud` at `[1072.653]` on sight, or turn it into a
    designed `encounters.lua` opener?
  - Keep `DAVAEO`'s unslotted `WAND02` / `POTN02` out of his quick slots per the no-vanilla-wand
    guideline?

---

## 5. Iron Throne Top Floor, Chapter 5 (`BG0615`)

| CRE | Spawn | Class & level | HP | Scripts & key gear |
| --- | --- | --- | ---: | --- |
| `ZHALIM` | `(503, 440)` | Fighter lvl 11, Berserker (`0x4001`), NEUTRAL | 79 | `ZHALIMAR` -> `ZHALIM.DLG`; `HALB03`, `BOW01`, `3× C0BER#00`, `C0FIG01` |
| `GARDUS` | `(383, 574)` | Fighter lvl 10, Berserker | 70 | Frontline Berserker |
| `ALAI` | `(458, 535)` | Fighter/Mage 8/7 | 56 | `DW#MG13`, innate `DW#MS6` (2× *Ray of Enfeeblement*); `RING09`, `WAND07`, unslotted `BRAC02` |
| `AASIM` | `(794, 436)` | Fighter/Cleric 8/7 | 72 | `DW#PR2`; `POTN12`, `WAND11` |
| `DIYAB` | `(705, 493)` | Cleric/Thief 9/9 | 60 | `DW#PR70`; `POTN13`, `POTN39`, `POTN20` |
| `NAAMAN` | `(573, 529)` | Mage lvl 9, Enchanter (`0x200`) | 56 | `DW#MG285`, innate `DW#MS11` |
| `EMITAR3` | Room | Doppelganger host | 31 | Morphed via `ZHALIM.DLG` (`SPWI987`) -> `DOPPLE` (AC 2, THAC0 9, 2 APR) |
| `DW#C51` (Shennara) | `(620, 336)` (SCS `BG0615.BCS`) | Fighter/Thief 8/8 | 55 | `_CULTTHF` + `DW2MP2TH`, invisible (`op20`), `POTN11` |
| `DW#C52` (Kaalos) | `(384, 405)` (SCS `BG0615.BCS`) | Thief lvl 12 | 75 | `DW2MS2TH`, invisible (`op20`), `3× POTN10` |
| `THALDO` | `(961, 611)` | NEUTRAL | — | Non-hostile witness |

- **Opening & dialogue (`ZHALIMAR` / `ZHALIM.DLG`):** flips `ALAI`, `AASIM`, `DIYAB`, `GARDUS` and
  `NAAMAN` to `Enemy()` and casts `DOPPLEGANGER_CHANGE_DEFAULT_LESSER` (`SPWI987`) on `EMITAR3`. SCS
  Ch.5 (`BG0615.BCS`) additionally adds the two invisible backstabbing thieves `DW#C51` and `DW#C52`.
- **Open design questions for Christopher:**
  - `ALAI` (`WAND07`) and `AASIM` (`WAND11`) carry vanilla wands, and `ALAI` has unslotted `BRAC02`:
    follow the no-vanilla-wand rule (replace with potions/slots?) and fix `BRAC02` slotting?
  - Pre-talk prep (`ZHALIMAR` talk-hold + Hard+ openers for `NAAMAN`/`ALAI`/`AASIM`/`DIYAB`): let
    native prebuffs + overnight Stoneskin run natively first, or design specific Hard+ group
    openers?

---

## 6. Quick Check of Simple Rows

| Encounter | Area | Key CRE & details |
| --- | --- | --- |
| **Seniyad** | `BG2200` (Cloakwood 1) | `SENIYA` (Druid lvl 9, `SENIYAD` + `DW#PR218`); dialogue triggered via `ALDETH` confrontation. Standard druid/hostile group under general engine. |
| **Amarande** | `BG1602` (Cloakwood Treehouse) | `AMARAN` (Druid lvl 11, **O** `DW#GPSHT`, **C** `DW#SHDLG`, **D** `DW#PR283`); `DW#AMARA` area/spawn adds 2× lvl 3 `DW#AMARA` druids. Benefits automatically from general engine + Druid lvl 5+ `SPPR506` *Iron Skins* rest-buff parity when holding L5 slots. |
| **Seven Suns** | `BG0603` (BG City) | `DOPPSS` (Doppelganger lvl 1, `DOPPLE.BCS` + `DW2MS2GE`); simple low-level shapechanger encounter suited to general engine handling. |
