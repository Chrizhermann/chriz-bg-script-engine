# Chriz BG Script Engine (Combat Intent)

An **EEex/Lua** combat and encounter engine that makes enemy groups in **Baldur's Gate II:
Enhanced Edition** and **EET (`2.7.3.0`)** fight together intelligently on top of **Sword Coast
Stratagems (SCS)**—while every creature keeps the spellbook, items, stats, and personality SCS
gave it. Planned as an optional, experimental component of
**[Chriz Easy BG](https://bg.chrizfader.org/collection)**.

---

## Part 1 — Overview: What Combat Intent Does

Install-time AI scripts evaluate each creature's round in isolation. **Combat Intent** adds a
live group-level decision layer on top of SCS without throwing away what already works:

- **Group Tactics & Live Reaction:** A fight director shares enemy sightings across allies,
  coordinates target focus, reserves targets and disables so casters do not waste duplicate
  spells, and adapts as protections, wounds, or positions change.
- **AoE Safety & Fair Play:** Checks spell geometry and line of sight to keep area spells off
  allies. Enemies act strictly on what they can perceive, using normal casting times,
  interruptions, spell slots, and item charges—never cheating effects or hidden instant casts.
- **Full Battlefield Decisions:** Handles fighter potion timing, archer weapon switching and
  kiting, caster step-away, thief *Hide in Shadows* flanking, clue-based searching, non-travel
  doors (`OpenDoor`, `PickLock`, `BashDoor`), and awareness of **Chriz BG Magic** rules (strength
  floors, restoration, simulacra, and petrified/imprisoned protagonist states).
- **Encounter Flow & Safe Travel:** Supports difficulty-scaled openers, talk-on-sight
  preparation, and lower-script duty forwarding while leaving scripted area transitions and travel
  triggers with the game's scripts. Always fails soft back to SCS if declined or toggled off.

### Naming

The combat AI module is **Combat Intent**. The project deliberately avoids the name **Tactics**
to prevent confusion with existing Infinity Engine mods.

---

## Part 2 — Development Status, Architecture & License

### Current Status (Nov 2026 — Active Lab Development, Pre-Release)

No public release has shipped yet. Current verified work on `main` runs in disposable EET
`2.7.3.0` + EEex + SCS + Chriz BG Magic labs and the **Playground**:

- **Kernel & BCS→Lua Bridge (`bgse/setup-bgse.tp2`, `kernel/`, `adapters/eeex/`):**
  - Component `0` hooks SCS combat scripts (mage, priest, general-AI, monster, ambushes, calls for
    help, talk-on-sight, idle gates), adds the engine's `own` hook on non-SCS fight scripts, and
    forwards lower-script duties (`adapters/eeex/lower.lua`) for enemy celestials and shouting
    creatures.
  - Component `10` (`bgse-recorder`) provides an independent playtest recorder (`M_BGSERC.lua`).
- **Combat Intent & Spell Integration (`combat-intent/`):**
  - Group director, shared perception and observer-bound beliefs, reservation leases, spatial and
    projectile geometry, spell/defence/removal scoring, and Chriz BG Magic spell/state
    integration (`5dc6324`) pass host suites and ran across 98 of 99 BG1 enemy areas in lab
    tours without engine errors.
- **Encounter Work & Preparation Gating:**
  - The first five BG1 encounters (`BOSS-01`: Tarnesh, Karlat, Neira, Silke, Greywolf & Kestrel)
    are implemented in `combat-intent/encounters.lua` and `bgse/encounters.tpa`.
  - The next BG1 encounter block (Bandit Camp, Cloakwood Mine / Drasus / Davaeorn, Iron Throne,
    and travelling assassins) is cataloged in `FIGHTS-01` and `BOSS-02` for design review.
  - `combat-intent/prep.lua` (`prep` / `prepSkip` orders) gates SCS prebuffs, contingencies,
    chain contingencies, and first-round openers, alongside reduced scoring on enemy dispel
    sequencers.

### Start Here

- [Working Agreements (`AGENTS.md`)](AGENTS.md)
- [What We Learned (`docs/learned.md`)](docs/learned.md)
- [Building an Encounter (`docs/ENCOUNTERS.md`)](docs/ENCOUNTERS.md)
- [Playground Guide (`docs/PLAYGROUND.md`)](docs/PLAYGROUND.md)
- Plans: [Combat Intent on SCS](docs/plans/2026-10-14-combat-intent-on-scs.md) ·
  [Playground & Parallel Work](docs/plans/2026-11-08-playground-and-parallel-work.md) ·
  [2026-08 Architecture](docs/plans/2026-08-27-script-engine-architecture-design.md)
- Research & Fight Sheets: [`docs/research/`](docs/research/) (`BOSS-01`, `BOSS-02`, `FIGHTS-01`,
  `HOOK-01`–`03`, `SPELLS-01`, `SUPPORT-01`)

### Verification

```powershell
powershell -NoProfile -File scripts/test.ps1 -Suite all
```

Runs Python, Lua 5.1, and LuaJIT unit, integration, and schema suites via `lupa`. Set
`BGSE_WEIDU` to a WeiDU executable for bridge-installer and hook-installer tests.

### Credits

- **Sword Coast Stratagems** by David Wallace (**DavidW**) and **Spell Revisions** by
  **Demivrgvs** and the **Gibberlings Three** team—tactical and spell knowledge base; no upstream
  mod files are copied or redistributed.
- **EEex** by **Bubb**—native runtime bridge powering the engine's hooks and Lua inspection.
- Collection interoperability notes reference *Artisan's Kitpack* and *Sirene NPC* (Artemius I),
  *Bardic Wonders* (The Artisan), *Tweaks Anthology* (CamDawg / Gibberlings Three), and *EE
  Fixpack* (Gibberlings Three), without copying any of their files.

### License

Licensed under the **[MIT License](LICENSE)** (`Copyright (c) 2026 Christopher Hermann`).
