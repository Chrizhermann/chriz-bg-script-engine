# BOSS-04 — BG1 Chapter 6–7: Candlekeep Return, Catacombs, Caves, Iron Throne Return & Undercellar

Read-only scouting dossier inspected against `C:\Users\chris\Games\Playground\game` (`EET` + `SCS` + `Spell Revisions` + `CEBG`, WeiDU decompilation & `tools/scout.py`). No gameplay, `.CRE`, `.BCS`, or `encounters.lua` changes have been made yet — this document records the verified live state and open design questions for Christopher.

## Overview

| # | Area | Encounter | Actors (CRE) | Hook / Script Status |
|---|---|---|---|---|
| 25 | `BG2626` | Candlekeep Ch.6 Ogre Mage Ambush | `OGREMA`, `OGREMA_A`–`OGREMA_D` | Hooked (`DW#MG303`/`307`/`308`/`309`/`310`); shared `OGREMA`; no arena lock |
| 27 | `BG2619` | Candlekeep Catacombs L2 Disguised Leaders | `GORION3`, `ELMINS4`, `TETHTO3` -> `DOPPGR`, `2× DOPPLE` (+ `4× DOPPLE`) | `op151` Replace Self to global `DOPPGR` / `DOPPLE`; no arena lock |
| 28 | `BG5506` | Escape Caves — Prat's Party | `PRAT`, `SAKUL`, `BOR` (`ROB`), `TAM` | Hooked (`DW#MG392`/`428`, `DW1RANGE`, `DW2RP2GE`); no arena lock |
| 30 | `BG0615` | Ch.7 Iron Throne Return — Cythandria & Golems | `CYTHAN`, `ARGHH`, `UGHH` | Hooked (`DW#MG89`, `GENSHT01`/`GOLSTO01` `HOOK-03` duty); arena lock active |
| 31 | `BG0112` | Ch.7 Undercellar — Slythe & Krystin | `SLYTHE`, `KRYSTI` | Hooked (`DW1MELAS`, `DW#MG225`, `DW#SHDLG` extras); no arena lock |

---

## #25 `BG2626` — Candlekeep Ch.6 Ogre Mage Ambush

### Area & Script Flow
- `BG2626.BCS` runs the Chapter 6 `DMWWOgreAmbush` cutscene: teleports `Player1`–`Player6` around the central yard (~`4777..4936, 3077..3218`) and spawns five level-5 `OGRE_MAGE` ambushers.
- `BG2626.BCS` also spawns Ch.6 Watchers (`WATCH6`) when `Criminal == 1`.
- Travel triggers in `BG2626.ARE`: `Door2605a -> BG2633` (`0x0`), `Door2608a -> BG2608` (`0x804`), and `Door2606a` / `Door2602a` / `Door2616a` / `Door2607a` (`0x800`). Arena lock currently unset.

### Creature Roster & Observed Data
All five are level-5 `OGRE_MAGE` (`STR 18/100`, `INT 16`, `WIS/DEX/CON/CHA 9`, saves `11/11/12/13/12`, `THAC0 14`, `2 APR`). None currently memorizes or carries *Haste*.
- **`OGREMA`** (`4743.2930`, `ENEMY`, HP `41`, script `DW#MG303`, gear `MAGE01`, `CDRDCS1`, `4× RNDTRE09`):
  - **1:** `2× Sleep`, *Burning Hands*, *Shield*; **2:** *Glitterdust*, *Mirror Image*; **3:** *Dire Charm*.
  - **Shared-CRE quirk:** `OGREMA` is reused in `BG2626`, `BG5601`, `BG5701`, and `BG5901` (`encounters.lua` orders on `OGREMA` apply across all four areas unless scoped by `area`).
- **`OGREMA_A`** (`5044.3060`, `ENEMY`, HP `39`, script `DW#MG307`, gear `COMPS01`, `SW1H20`):
  - **1:** *Magic Missile*, *Charm Person*, *Sleep*, *Shield*; **2:** *Glitterdust*, *Mirror Image*; **3:** *Ghost Armor*.
- **`OGREMA_B`** (`4933.2925`, `ENEMY`, HP `39`, script `DW#MG308`, gear `MAGE01`, `COMPS01`):
  - **1:** *Charm Person*, `2× Chromatic Orb`, *Armor*; **2:** *Acid Arrow*, *Mirror Image*; **3:** *Dire Charm*.
- **`OGREMA_C`** (`4602.3194`, `ENEMY`, HP `39`, script `DW#MG309`, gear `COMPS01`):
  - **1:** *Chromatic Orb*, *Magic Missile*, *Sleep*, *Armor*; **2:** *Acid Arrow*, *Mirror Image*; **3:** *Ghost Armor*.
- **`OGREMA_D`** (`4860.3374`, **starts `NEUTRAL`**, HP `39`, Override `SHOUTDLG`, Default `DW#MG310`, Dialogue `OGRELEAD.DLG`, gear `MAGE01`, `SW1H43` *Katana*, `DW#OGSCR`):
  - **1:** `2× Sleep`, *Charm Person*, *Shield*; **2:** *Acid Arrow*, *Mirror Image*; **3:** *Lance of Disruption*.
  - `OGRELEAD.DLG`: "son of Murder offers 10,000 gold" -> `Enemy()`.

### Open Design Questions
1. Should `BG2626` receive arena locks (`Door2605a`, `Door2608a`, etc.) during the Chapter 6 ambush so the party cannot walk straight into an adjacent building mid-ambush?
2. Because `OGREMA_D` handles `OGRELEAD.DLG` while the other four spawn `ENEMY`, do any of them need `prebuff` / `opener` coordination (e.g., Mirror Image/Shield or offensive opening before closing to melee) — and should any changes stay scoped to `BG2626` because `OGREMA` is reused in `BG5601`/`BG5701`/`BG5901`?

---

## #27 `BG2619` — Candlekeep Catacombs L2 Disguised Leaders

### Area & Script Flow
- Initial disguised trio stands near `(1893..1952, 324..390)`, all starting `NEUTRAL`. Four separate placed `DOPPLE`s also occupy the western rooms (`766.1168`, `743.924`, `513.1200`, `845.987`, `DW2MS2GE`, HP `31`, AC `2`, `THAC0 9`, `2 APR`, `S1-12`, `RNDTRE09`).
- `ELMINS4.DLG` states `4`–`7`, `GDCHANGE.BCS`, `LDCHANGE.BCS`, and `BG2619.BCS` (when one dies while `K#DOPPLEGANGER_CHANGE == 0`) transform the trio via **opcode 151 (Replace Self)**:
  - `ELMINS4` casts `DOPPLEGANGER_CHANGE_DEFAULT` (`SPWI988` -> `op151` -> `DOPPGR`).
  - `GORION3` and `TETHTO3` cast `DOPPLEGANGER_CHANGE_DEFAULT_LESSER` (`SPWI987` -> `op151` -> `DOPPLE`).
  - In `ELMINS4.DLG` state `4` (when the player trusts him), they first walk to `[554..635, 1106..1163]` before casting `SPWI988`/`SPWI987` (`false()` states `6`–`7` are unused).
- Travel triggers in `BG2619.ARE`: `Door2615 -> BG2615` (`0x0`), `Door5506 -> BG5506` (`0x4`).

### Creature Roster & `op151` Quirk
- **Pre-transform disguised CREs (replaced immediately on hostility):**
  - `GORION3`: lvl 9 `DOPPLEGANGER_GREATER`, HP `50`, AC `10`, `GDCHANGE` + `DW2MP2GE`, `CLCK18`, `DAGG01`, memorized `4× SPWI308` + `5× SPWI303`.
  - `ELMINS4`: lvl 29 `DOPPLEGANGER_GREATER`, HP `200`, AC `-10`, `THAC0 0`, `ELMINS4` (C) + `GDCHANGE` (R) + `DW2MC2GE`, `0` spells, `STAF01`.
  - `TETHTO3`: lvl 10 `DOPPLEGANGER`, HP `50`, AC `10`, `LDCHANGE` + `DW2MM2GE`, known-not-memorized `SPPR503`.
- **Post-transform combat CREs (`op151` wipes Gorion's spells and Elminster's 200 HP/stats):**
  - `DOPPGR` (shared global CRE!): lvl 9 `DOPPLEGANGER_GREATER`, HP `65`, AC `0`, `THAC0 7`, `4 APR`, saves `2/2/2/2/3`, Override `DOPSPELL` (hooks `auto`), Default `DW2MS2GE`, memorized `SPWI212` (*Mirror Image*) + `SPWI305` (*Haste*).
  - `2× DOPPLE` (shared global CRE!): lvl 4, HP `31`, AC `2`, `THAC0 9`, `2 APR`, no spells.

### Open Design Questions
1. Because `op151` turns the disguised leaders into the global shared resrefs `DOPPGR` and `DOPPLE`, any BGSE `orders` keyed to `DOPPGR`/`DOPPLE` would affect every generic doppelganger in the game (and any orders on `GORION3`/`ELMINS4`/`TETHTO3` vanish on `op151`). Should `BG2619` use area-scoped orders or leave the `op151` doppelgangers under baseline `auto` AI?
2. Should `Door2615` and `Door5506` get arena locks in `BG2619` (noting that the four western `DOPPLE`s remain separate)?

---

## #28 `BG5506` — Escape Caves: Prat's Party

### Area & Script Flow
- All four start `NEUTRAL`. `PRAT.BCS` initiates `PRAT.DLG`, whose hostile exit turns `PRAT`, `SAKUL`, `ROB`, and `TAM` hostile (`PRAT.DLG` also has `WEIGHT #0` `STATE_CHARMED` state `4` interrogation dialogue).
- Travel triggers in `BG5506.ARE`: `Door2619 -> BG2619` (`0x0`), `Door2626 -> BG2626` (`0x4`).

### Creature Roster & Observed Data
- **`PRAT`** (`897.516`): Fighter/Mage `8/8`, HP `74`, `THAC0 13`, `STR 18/63`, `DEX 18`, `CON 18`; **O** `DW#GPSHT`, **C** `PRAT`, **D** `DW#MG392`; innate `DW#MS10`; gear `AX1H05`, `SW1H07`, `MAGE04`, `MAGE06`, `SCRL83`/`86`/`93`/`94`/`96`, `DW#RND04`/`24`/`28`; books:
  - **1:** `SPWI103`, `SPWI116`, `SPWI112`, `SPWI102`
  - **2:** `SPWI205`, `SPWI224`, `SPWI212`
  - **3:** `SPWI314`, `SPWI323`, `SPWI305` (*Haste*)
  - **4:** `SPWI423` (*Spider Spawn*), `SPWI401` (*Confusion*)
- **`SAKUL`** (`963.638`): Mage `7`, HP `43`; **O** `DW#GPSHT`, **D** `DW#MG428`; innate `DW#MS11`; unslotted `SCRL98`/`1C`/`1H`/`1S`/`1T`/`1I`/`1O`/`1R`; books:
  - **1:** `3× SPWI121`, `2× SPWI112`
  - **2:** `SPWI211`, `SPWI206`, `SPWI219`, `SPWI212`
  - **3:** `2× SPWI328`, `SPWI312`
  - **4:** `SPWI431`, `SPWI406`
- **`BOR`** (DV `ROB`, `832.623`): Halfling Fighter `7`, HP `56`; `DW#GPSHT` + `DW1RANGE`; `PLAT01`, `4` pips Dart, `DART03`×20, `DART01`×20, `BLUN02`, `DW#RND04`/`11`/`28`, unslotted `HELM01`.
- **`TAM`** (`1024.611`): Human Fighter `8`, HP `65`; `DW#GPSHT` + `DW2RP2GE`; `PLAT01`, `4` pips Longbow, `BOW01` + `AROW04`×20, `SW1H07`, `DW#RND04`/`12`/`26`, unslotted `HELM01`, `BOW04`, `AROW11`, `AROW02`.

### Open Design Questions
1. Prat & Sakul have `DW#MS10`/`DW#MS11`, *Haste*, *Spider Spawn*, *Confusion*, etc. — what `prebuff` / `opener` / `sequencers` tuning do you want for Prat and Sakul?
2. Should `BG5506` get arena locks (`Door2619` / `Door2626`), considering the spiders / basilisks deeper in the caves?
3. Observation only (mod/CRE scope, not BGSE combat AI): `BOR` and `TAM` have unslotted `HELM01` (and `TAM` has unslotted `BOW04` / `AROW11` / `AROW02`), and `SAKUL` has unslotted scrolls.

---

## #30 `BG0615` — Ch.7 Iron Throne Return: Cythandria & Golems

### Area & Script Flow
- `BG0615.BCS` spawns `CYTHAN` at `[881.774]` in Chapter 7 (`CythanSpawn == 0`).
- `CYTHANDR.BCS` (Override) triggers `CYTHAN.DLG`, whose hostile exits spawn `ARGHH` (`[835.718]`) and `UGHH` (`[795.654]`) and call `Enemy()`.
- `CYTHAN.BCS` (Class) initiates surrender dialogue when `HPPercentLT(Myself,50)`.
- `BG0615` Arena Locks (`Door0614`, `Door0621`) are already active in `combat-intent/encounters.lua` and unlock cleanly both when enemies die and when Cythandria surrenders (`DestroySelf()` + `EscapeArea()` -> `hostiles == 0`).

### Creature Roster & Observed Data
- **`CYTHAN`**: Conjurer (`0x800`) lvl `11`, HP `66`, AC `4`, saves `1/1/1/1/1`, `INT 18`, `DEX 17`; **O** `CYTHANDR`, **C** `CYTHAN`, **D** `DW#MG89`; `CLCK09`, `SCRL3F`, `DW#RND06`/`24`; innate `DW#MS10`; books (zero summon spells):
  - **1:** `3× SPWI112`, `SPWI118`, `SPWI114`
  - **2:** `SPWI204`, `3× SPWI212`, `SPWI219`
  - **3:** `SPWI304`, `SPWI323`, `SPWI312`, `SPWI311`, `SPWI302`
  - **4:** `SPWI431`, `SPWI404`, `SPWI408`, `SPWI406`
  - **5:** `SPWI523`, `SPWI503`, `SPWI513`, `SPWI505`
- **`ARGHH` & `UGHH`**: Stone Golem lvl `14`, HP `60`, AC `5`, `THAC0 7`, `STR 22`; `GENSHT01` + `GOLSTO01` + `WDASIGHT`; `GOLSTONE` + `GOLSTO`; `op120` (non-enchanted / `< +2` weapon immunity) and `op101` immunities; `GOLSTO01` (`Delay(15) -> ReallyForceSpell(Myself, GOLEM_SLOW)`) already runs via `HOOK-03` `duty`.

### Open Design Questions
1. Cythandria is a Conjurer (`0x800`) whose live spellbook currently has zero summon spells: should she stay strictly with her SCS spellbook (`prebuff` / `sequencers` orders overriding `DW#MS10`) or get Conjurer identity touches?
2. Should anything special be coordinated around her `< 50% HP` surrender script (`CYTHAN.BCS`), e.g., ensuring an immediate prebuff doesn't interfere with dialogue or keeping her class surrender intact?

---

## #31 `BG0112` — Ch.7 Undercellar: Slythe & Krystin

### Area & Script Flow
- `BG0112.BCS` spawns `SLYTHE` (`[1278.969]`) and `KRYSTI` (`[1349.973]`) in Chapter 7. Neutral brothel NPCs share the area.
- Four travel triggers in `BG0112.ARE`: `DOOR0225`, `Door0114`, `Door0226`, `Door0224`. Arena lock currently unset (`arena.lua` waits only on living `EVILCUTOFF` sprites, so neutral brothel NPCs do not keep doors locked).

### Creature Roster & Observed Data
- **`SLYTHE`**: Fighter/Thief `9/8`, kit `0x400a` (Artisan's Kitpack Assassin), HP `71`, `THAC0 8`, `STR 18/20`, `DEX 18`, `CON 16`; **O** `DW#GPSHT`, **C** `DW#SHDLG`, **D** `DW1MELAS`; innates `2× C0AS#P1`, `C0A_A01`, `C0ASIN1`; gear `LEAT04`, `SHLD08A`, `MAGE04`, `MAGE06`, `SW1H10` (*Shadow's Blade +3*), `CLCK06`, `POTN36`, `XBOW04`, `MISC78` (*Invitation*), `POTN34`, `DW#RND06`/`16`/`30`/`42` (`2`–`4× DW#PTN10`). Note `DW#SHDLG` already invokes `BGSE_TalkHold` / `BGSE_TalkExtras`.
- **`KRYSTI`**: Mage `13`, HP `54`, saves `6/6/6/10/7`, `DEX 18`, `CON 16`; **O** `DW#GPSHT`, **D** `DW#MG225`; innate `DW#MS0`; gear `MAGE01`, `SLNG02` + `BULL03`/`02`, `SCRL1D`/`1M`/`1N`/`1P`/`1Q`, `DW#RND06`/`23`; books:
  - **1:** `3× SPWI112`, `2× SPWI121`, `SPWI114`
  - **2:** `2× SPWI211`, `SPWI205`, `2× SPWI212`, `SPWI219`
  - **3:** `3× SPWI328`, `SPWI312`, `SPWI311`, `SPWI302`
  - **4:** `SPWI431`, `SPWI402`, `SPWI406`, `SPWI419`, `SPWI408`
  - **5:** `2× SPWI521`, `SPWI506`, `SPWI505`, `SPWI513`
  - **6:** `2× SPWI622`, `SPWI611` (*PfMW*)

### Open Design Questions
1. Should `BG0112` get arena locks on all four exits (`DOOR0225`, `Door0114`, `Door0226`, `Door0224`)?
2. What `prebuff` / opener choreography do you want for Slythe (`DW#PTN10` invisibility, `POTN34`, Assassin innates `C0AS#P1`/`C0A_A01`/`C0ASIN1`) and Krystin (`prebuff`, `DW#MS0` replacement via `orders.sequencers`, `SPWI611` *PfMW* contingency)?

---

## Credits & Attribution
- Encounter scripts, spellbooks, and tactics documented here originate from **Sword Coast Stratagems (SCS)** by **DavidW**, **Spell Revisions** by **Demivrgvs** and **Gibberlings Three**, **Artisan's Kitpack** (Slythe's Assassin kit/innates), and the **CEBG** collection.
