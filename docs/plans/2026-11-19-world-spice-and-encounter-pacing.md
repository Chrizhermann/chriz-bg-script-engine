# World Spice & Non-Boss Encounter Pacing

Recorded from Christopher's direction on **2026-11-19** to guide long-term encounter, stat, and world design beyond the main SCS boss blocks (`BOSS-01`–`BOSS-04`+).

## Core Principles

1. **Relaxed baseline areas are intentional — not every map needs to be a gauntlet.**
   - Under the target ruleset (**Insane without double damage**, **rolled hit points** with full HP only at level 1), early wilderness maps and ordinary trash encounters naturally feel calmer than classic SCS + Insane + Double Damage (where a single wolf at level 1–3 could kill a character in one or two hits).
   - That calmer baseline is **good and intended**: the player should still have breathing room and exploration pace across the world.

2. **Never turn ordinary areas into Tactics Remix / Improved Anvil bloat.**
   - Do **not** stamp generic packs with artificial caster/priest/elite templates everywhere (e.g., six groups of gnolls where every pack suddenly has a fully prebuffed mage, a buff-spamming cleric, elites, and potion-chugging grunts).
   - Every enemy upgrade must stay grounded in the area's lore, ecology, and believable creature identity.

3. **Targeted "World Spice" instead of blanket difficulty inflation.**
   - Keep standard pockets approachable, while sprinkling memorable, well-placed tactical surprises, interesting terrain/positions, occasional smarter sub-leaders, or distinct small set pieces across the world so a playthrough stays tense and never turns sleepy.
   - Respect early progression goals — **Gnoll Stronghold (Dynaheir)** is the canonical example: players often go there early to recruit a companion, so the stronghold must stay very beatable early on while still feeling like a real, lively gnoll fortress rather than flat filler (or an overtuned caster-spam wall).

4. **Two-track rollout (long-term, iterative).**
   - **Track A (current main path — confirmed):** Continue replacing and upgrading SCS's designed encounters block by block (`FIGHTS-01` / `BOSS-*` sheets).
   - **Track B (gradual world pass, alongside playtesting):** Over time, review general areas, creature stats, and non-boss encounters across the world and introduce targeted spice step by step based on live playtest feedback (never all at once, always verified in real play).

## Open Design Areas to Revisit Gradually
- Wilderness & dungeon pacing passes (starting with BG1 landmarks such as the Gnoll Stronghold `BG5100`, road ambushes, and mid-chapter wilderness pockets).
- Global creature-stat & role baselines (where general enemies feel too soft without Double Damage vs. where early level 1–3 lethality should stay fair).
- Local call-for-help tuning (`combat-intent/calls.lua`): keep wilderness pulls strictly local (never map-wide chains), while tuning earshot radii and Hard/Insane 1-hop relays as playtest logs come in.
