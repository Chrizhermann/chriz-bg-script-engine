# HOSTILITY-01 — Allied Confusion, Friendly-Fire Tolerance & Ducal Palace Coronation

## Status & Scope (2026-11-22)

Read-only binary and script forensics of vanilla BG:EE (`AR0108.ARE` / `AR0108.BCS`, `BELT`, `LIIA`, `FLAM10`, `SAREVO2`, `GDOPP7*`, `BDSUM00.BCS`, `SPARGONP.PRO`) and EET + SCS 35.21 (`BG0108.BCS`, `BELT`, `LIIA`, `FLAM10`, `SAREVOK_`, `DW#HDP75`, `DVMELEE.BCS`, `stratagems/tactical_bg1/doppelganger.tpa` lines 176–188).

**No SCS patch will be built** (Christopher, 2026-11-22): SCS is being phased out as BGSE replaces scripts natively. This dossier records the verified root cause and design rules for our own encounter/vanilla script rewrite — specifically `#32 BG0108` Ducal Palace (`FIGHTS-01-bg1-fight-list.md`) and general allied/neutral hostility handling across BGSE and our own mods.

---

## Verified Root Cause (Vanilla BG:EE + SCS 35.21)

### 1. Vanilla BG:EE Baseline
- In vanilla BG:EE (`AR0108`), `BELT`, `LIIA`, all six `FLAM10` Flaming Fist guards, and `SAREVO2` (`Sarevok`) start at `EA = 128 (NEUTRAL)`, and the Coronation doppelgangers (`GDOPP7*`) memorize no *Confusion* or *Chaos* spells.
- `BELT.BCS` Block 1, `LIIA.BCS` Block 1, and `SAREVOK.BCS` Block 2 each carry:
  - `AttackedBy([GOODCUTOFF],DEFAULT)` + `!Global("SarevokBehavior","GLOBAL",3)` → `SetGlobal("SarevokBehavior","GLOBAL",3)`
  - A single attack initiation triggers this immediately — even a missed swing with 0 damage.
- Once `SarevokBehavior` reaches `3`, `AR0108.BCS` / `BG0108.BCS` Block 1 sets `liia`, `belt`, and `sarevok` to `Enemy()` and starts `EndGame` (5–15 s), after which `WINSKI` spawns and runs `Kill(Player1)` (hard Game Over).

### 2. Why SCS 35.21 Breaks the Fight
SCS `doppelganger.tpa` (*Improved Doppelgangers*) turns `dw#hdp75` into a Level 9 Conjurer Mage with *Chaos* (plus *Confusion*-family threats) and re-flags `BELT`, `LIIA`, and all six `FLAM10` guards to `EA = 29 (GOODBUTBLUE)` (`<= 30 GOODCUTOFF`), then breaks both intended safeguards in lines 178–188:

1. **Broken Confusion immunity (`doppelganger.tpa:180`):** Patches `BELT` and `LIIA` with `immunity_to_opcode=>~5 241 24 148~`. Opcode `148` is *Cast Spell at Point*, a typo for `128` (*Confusion*), leaving both dukes vulnerable despite `readme-scs.html` promising Confusion immunity. `FLAM10` receives no Confusion immunity at all.
2. **Wrong Hold immunity ring (`doppelganger.tpa:179`):** Equips `RING05` (*Sandthief's Ring*, zero equipped effects) instead of `RING09` (*Edventar's Gift* / Free Action).
3. **Silent-fail forgiveness patch (`doppelganger.tpa:188`):** Runs `swap_text` `AttackedBy(\[PC\],DEFAULT)=>False()` on `belt.bcs` and `liia.bcs`. On BG:EE/EET, Block 1 checks `AttackedBy([GOODCUTOFF],DEFAULT)`, so the regex matches 0 lines and leaves the instant-betrayal trigger fully active on `BELT.BCS`, `LIIA.BCS`, and `SAREVOK_.BCS` Block 2.

### 3. Chain Reaction (Zero Party or Summon Involvement)
- `SPWI401` (*Confusion*) and vanilla `SPWI508` (*Chaos*) use projectile `170` (`SPARGONP.PRO`, `area_flags = 0x0050`, `affect_only_enemies = True`); in the inspected Spell Revisions + SCS install, `DW#HDP75` memorizes SR *Chaos* (`SPWI711`, projectile `509` = `DVSCHAOS.PRO`, `area_flags = 0x0040`, also `affect_only_enemies = True`).
- Because `GOODBUTBLUE (29)` lies inside `[GOODCUTOFF] (<= 30)`, enemy *Confusion*/*Chaos* now hits `BELT`, `LIIA`, and all `FLAM10` guards, and any confused swing by them satisfies `AttackedBy([GOODCUTOFF],DEFAULT)`.
- The moment a confused `FLAM10` swings at `BELT`, `LIIA`, or the still-`NEUTRAL` `SAREVO2` — or confused `BELT` swings at `LIIA` (or vice versa) — `SarevokBehavior` flips to `3` and triggers the `EndGame` Game Over, even if no party member or summon ever touched any NPC.
- Summoned skeletons do not retaliate against confused allies: both vanilla EE (`BDSUM00.BCS`) and Spell Revisions (`DVMELEE.BCS`) target `NearestEnemyOf` (`[EVILCUTOFF]`, `EA >= 200`), and their `AttackedBy` block only executes `Continue()` into `NearestEnemyOf`.

---

## Design Rules for BGSE & Own Mods (Christopher, 2026-11-22)

1. **No SCS patch:** Do not ship a compatibility patch for SCS. Fix this cleanly inside BGSE and our own mods when replacing vanilla/encounter scripts.
2. **Confusion never triggers allied hostility or Game Over:** Attacks committed under `STATE_CONFUSED` — whether confused allied/neutral NPCs swinging at each other, or a confused party member or summon hitting an ally — must never flip allies hostile or advance scripted betrayal / Game-Over globals (such as `SarevokBehavior = 3`).
3. **Friendly-fire tolerance threshold (no 1-hit Game Over):** Replace brittle single-attack / 1-HP triggers (`AttackedBy([GOODCUTOFF],DEFAULT)` or 1-point stray damage) with a forgiveness threshold: one accidental stray AoE/friendly-fire hit (for example, a single stray *Fireball*) should be tolerated, while repeated or deliberate friendly fire (e.g., a second *Fireball* or crossing a clear hit/damage threshold) may legitimately turn allies hostile and trigger Game Over.
4. **Allegiance vs. trigger audit:** Whenever an encounter sets friendly NPCs to `GOODBUTBLUE` or `ALLY` (`EA <= 30`), audit every `AttackedBy([GOODCUTOFF])`, `HitBy([GOODCUTOFF])`, and `Shout` trigger in the area — including temporarily neutral actors like Sarevok during Phase 1 — so allied actors cannot trip party-betrayal flags.
