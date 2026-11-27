# Sensible Ambushes & Sensible Fog-of-War Respawns

**Status:** Implemented (`feat/sensible-ambushes-and-respawns`)
**Defaults:** Enabled by default whenever BGSE is active (`[BGSE] Enabled=1`, `[BGSE] Ambushes=1`, `[BGSE] Respawns=1`). Not gated behind Challenge Mode.

## Design Philosophy

1. **Part of Overhaul v1 by default:** Players should not face twenty creatures piled directly onto the party formation in random travel encounters or endless off-screen respawn waves popping directly behind them seconds after stepping out of sight.
2. **Logical without disarming danger:** Ambushes stay dangerous — hostile packs simply launch from believable Fog-of-War cover and flanking angles rather than spawning inside the party's hitboxes.
3. **Preserve infested dungeon pressure:** Fog-of-War respawns must never be capped at a fixed wave count. Infested ruins, trolls, and kobold warrens stay threatening while eliminating unnatural instant re-spawns the moment the camera pans away.

---

## 1. Sensible Ambushes (`[BGSE] Ambushes=1`)

### A. Travel "Waylaid" Ambushes (`bgse/lib/ambush.tpa`, `tools/ambush_rule.py`)
Relocates `CreateCreature(...)` spawns at install time on random travel encounter scripts (`BG5600`–`BG6100`, `AR0041`–`AR0046`) on verified walkable cells from `<wed>SR.BMP` (avoiding 4-cell map borders and blocked tiles `{0, 8, 10, 12, 13}`, preferring `3x3` fat-walkable cells):
- **Hostile ambush packs:** Split into 1–3 cohesive flanking squads (1 squad for `<= 2`, 2 squads for `3–7`, 3 squads for `>= 8`) in Fog of War (`480..700 px` from party landing anchors, outside `448 px` visual range), with `>= 56 px` member spacing (`>= 40 px` fallback) facing toward the party.
- **Dialogue & taunt encounters** (`EA < 200`, dialogue-action CRE scripts, `RESUNA`, or `MoveViewObject`/`DisplayStringHead`/`Dialogue`/`StartDialog`): Speaker/leader placed at `300..355 px` (`325 px` target), companions behind/beside the leader at `365..485 px`.
- **Planar teleports (`GITH*`):** De-stacked around the party at `175..275 px` (`>= 56 px` spacing).
- **Safety invariants:** Skips blocks containing `JumpToPoint(`, `MoveBetweenAreas(`, `LeaveAreaLUA`, `CreateCreatureImpassable(`, or already-sensible distant coordinates (`RENFELD` + thugs in `AR0041`). Story-scripted maps (`BD6100`, `OH1000`, `OH6010`, `OH4290`, `AR2601`) are left untouched. Preserves trailing open `OR(n)` trigger semantics.
- **Clean runtime kill switch:** Every relocated block is emitted as dual blocks gated by `EEex_LuaTrigger("return BGSE_AmbushOn and BGSE_AmbushOn() or false")` with the unmodified vanilla block beneath `!EEex_LuaTrigger(...)`.

### B. Fog-of-War Approach (`combat-intent/ambush.lua`, `adapters/eeex/search.lua`)
On travel ambush areas (`BG5600`–`BG6100`, `AR0041`–`AR0046`, `BD0063`), hostile BGSE-driven creatures that have not yet fought (`not s.fought` and `not s.gaveUp`) receive a synthetic `'called'` clue toward the nearest living party member in the same area, latched at initial `s.ambushTick` so squads converge smoothly from Fog of War and obey normal search patience if evaded.

### C. In-Place Rest Interruptions (`adapters/eeex/respawn.lua`, `combat-intent/ambush.lua`)
When `m_gameTime` advances by `>= 4500` ticks (`>= 1` in-game hour) in the same area, newly appeared non-summoned, non-cloned hostiles (`m_lSummonedBy.m_Instance == -1` and `m_nCopyParent == -1`) within melee distance (`< 240 px`) of living party members are moved via `EEex_Area_GetNearestOpenPosition` + `JumpToPoint([x.y])\nFaceObject(NearestEnemyOf(Myself))` onto camp perimeter positions (`280..420 px`, `>= 56 px` apart, preserving approach direction).

---

## 2. Sensible Fog-of-War Respawns (`[BGSE] Respawns=1`)

Implemented in `combat-intent/respawn.lua` and `adapters/eeex/respawn.lua` (driven by `adapters/eeex/arena.lua` ticks without registering duplicate menu listeners):
- **Initial room spawns untouched:** Fresh spawn points (`BGSE_SP_<x>_<y>_<ord> == 0`) remain free to spawn normally until either a party member comes within `448 px` sight or the spawn fires.
- **Primary lever — Minimum party distance:** Once governed (`saved > 0`), spawning is held while any living party member in the area is within `1100 px` (or `max(640, floor(mapDiag * 0.65))` on smaller dungeon floors).
- **Secondary lever — Area-tier cooldowns (NO wave cap):**
  - `infested` (`900` ticks = 1 turn / 10 rounds): designated swarm maps (`BG5201`, `BG3901`, `BG5100`, `BG2100`, `BG0123`, `BG0224`–`0226`, `AR0202`, `AR0404`, `AR0701`, `AR1201`, `AR1202`), boss-gated strongholds while the boss lives (`AR1300`/`AR1302`/`AR1303` with `SPRITE_IS_DEADTORGAL == 0`, `AR1401` with `SPRITE_IS_DEADSHADEL == 0`), and any indoor area with `>= 6` spawn points.
  - `dungeon` (`9000` ticks = 2 in-game hours): remaining indoor areas.
  - `wilderness` (`54000` ticks = 12 in-game hours): outdoor areas (`OUTDOOR` flag `0x1`).
- Persists next allowed tick in native area variables `BGSE_SP_<x>_<y>_<ord>` so governance survives save/load; disabling `[BGSE] Respawns=0` or `[BGSE] Enabled=0` promptly releases held points.

---

## 3. INI Toggles & Future Challenge Mode Scope

- `[BGSE] Ambushes=1` (default ON, `BGSE.setAmbushes(bool, persist)`)
- `[BGSE] Respawns=1` (default ON, `BGSE.setRespawns(bool, persist)`)

Explicitly **out of scope** for Overhaul v1 defaults and deferred to future Challenge Mode / roadmap work:
- Travel ambush exit locks (`ArenaLocks` remains Challenge Mode only).
- Anti-farming limits or finite wave caps on area respawns.
- Wandering area patrols replacing static spawn points.
