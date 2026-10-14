# ASC-01 — Ascension's boss specials: where they cheat

Date: 2026-10-15. Groundwork for a design talk with Chris; nothing in the engine changes.
Stack: the SCS-reference lab (BG2:EE 2.7.3.0, EET 14, EEex 1.2.0 with LuaJIT, Ascension 2.1.0,
SCS 35.21, Spell Revisions 4.21-chriz.5 and the rest of the CEBG collection), WeiDU 24900.
Ascension was made by David Gaider and the original Ascension team (Cuveronious, Quitch, Xyx,
Spork, Vulgar Zildrah, Kensai Ryu) and kept alive by many maintainers; the installed 2.1.0 is
DavidW's rewrite, and the Tougher components are Gaider's. SCS is by David Wallace (DavidW);
Spell Revisions by Demivrgvs and the Gibberlings Three. Vanilla Throne of Bhaal is BioWare's.
No Ascension, SCS or game file, decompiled script or log is in this repository; this note quotes
resource names and short snippets only.

## Question

Chris (2026-10-14): players complain that the Ascension enemies cheat, and that nothing in the
game, neither the log nor the chat, tells them these are not real abilities. The enemies may be
extremely strong; the cheating is the problem. Which special abilities do they really use, how
does each one leave fair play, and who wrote it?

## Method

- For every Ascension enemy, read the five script slots of its CRE in the lab (override first,
  then the BIFFs), decompile those scripts with WeiDU into a scratch folder, and pull out every
  block that acts outside the spellbook: `ForceSpell*`, `ReallyForceSpell*`, `ApplySpell*`,
  `SpellNoDec*`, `CreateCreature*`, `DestroyItem`, `Kill`, `ActionOverride`, `DisplayString*`.
- Read the spells, items and effects with `tools/ie_resources.py` and classify them with
  `combat-intent/spells.lua`, both from branch `claude/wizardly-proskuriakova-c85fd0`
  (a4958c5; notes in SPELLS-01 there).
- Origin: find each script's source in the lab's `ascension/` (Ascension 2.1.0) or
  `stratagems/` (SCS 35.21) folder, check `WeiDU.log` for the component, and check the BIFFs for
  vanilla resources. The ability (spell, item) and the script that fires it often come from
  different mods; the tables name both.
- Ascension's own notes (`ascension/doc/ascension-additional.html`, compiled by DavidW) describe
  most mechanics. I checked them against the installed files and note where they differ.
- No lab game was launched. What only play can show is under "Open questions".

## Short answer

- The cheating sits in five places, not in single spells:
  1. **Melissan can't die while any of the Five live.** Below 20 HP she teleports away and heals
     to full (Draw Power). Half of her 1,000 HP and much of her resistance come from five hidden,
     nameless items; each vanishes when its member of the Five dies. The player sees "Weakened"
     and nothing else.
  2. **The Five die by script at 20 HP**, through the area script's `Kill()`, whoever hit them.
  3. **Boss casting has no spellbook.** Melissan, Illasera, Yaga-Shura, Abazigal, Demogorgon,
     Bodhi and the fiends fire abilities through `ForceSpell*`, `ReallyForceSpell*`, `ApplySpell*`
     or `SpellNoDec*`: unlimited (only timers limit them), mostly uninterruptible, and the
     `ReallyForceSpell*` and `ApplySpell*` ones are instant.
  4. **Custom spells look like spells but ignore magic resistance or saves**: Bone Blades, Blade
     Barrier, Unleash, Symbol of Slow, Lava Bomb, Lightning Aura, two of Illasera's arrows,
     Demogorgon's gazes and Domination, the balor's death blast.
  5. **Silent stat boosts**: fiends at 150 % HP, Tamah at 300 %, permanent haste and faster
     casting from effects stored in the creature, Tamah's full heal off-screen, SCS's rest heal.
- Who wrote it: the story mechanics (1, 2) and the bosses' own special spells (most of 3 and 4)
  are Ascension: Gaider's design, DavidW's 2.x code. Yaga-Shura's invulnerability and Abazigal's
  dragon change are vanilla ToB. SCS adds the casting rhythm and targeting on top:
  difficulty-scaled cooldowns, target choice by hidden stats, prebuffs, contingencies, fiend
  teleports, HP multipliers and hidden heals.
- The fair model already exists: **Balthazar** (Gaider) uses real innate abilities from his
  spellbook (`HaveSpellRES`), recharges them with his own abilities, and names most of them over
  his head. Gromnir and Sarevok are essentially fair too.
- Ascension documents most of this in the notes above, but only outside the game. Inside the game
  the player gets no rule, no log line and no description for most of it.

## The actions, and what they skip

Rules as given by the IESDP and as the scripts use them. Magic resistance and saves come from
each effect's own fields, not from the action (for `ApplySpell*` this is unverified, see open
questions).

| Action | Spell must be memorised | Uses it up | Casting time | Can be interrupted |
|---|---|---|---|---|
| `Spell`, `SpellRES` | yes | yes | yes | yes |
| `SpellNoDec`, `SpellNoDecRES` | no | no | yes | yes |
| `ForceSpell*` (also `…Point…`) | no | no | yes | **no** |
| `ReallyForceSpell*` (also `…Point…`, `…Dead…`) | no | no | **none** | **no** |
| `ApplySpell*` | no | no | none, nothing is cast | no |
| `UseItem` | needs the item | a charge | the item's | yes |

Other script actions that matter here: `CreateCreature*` (a creature appears without a spell),
`DestroyItem` on a nameless item (stats change silently), `Kill` (scripted death),
`ActionOverride` (one script makes another creature act), `SetInterrupt(FALSE)` (nothing
interrupts the block), `DisplayString` (a log line) and `DisplayStringHead` (text over the head).

## Labels used in the tables

- **U** unlimited: no spellbook is used; only a timer or a once-flag limits it.
- **I** can't be interrupted. **Z** zero casting time.
- **R** magic resistance can't stop it (effect resist field 0, 2 or 3), or there is no save.
- **C** custom: not a real game spell; nameless, no description, or a real name over other effects.
- **S** silent: no text, log line or icon tells the player, or the text is misleading.
- **D** scripted life and death: invulnerability, minimum HP, retreat-and-heal, `Kill()`.
- **H** hidden stats: HP, haste, casting speed or resistances from nameless items or effects stored
  in the creature.
- **K** knows too much: target choice reads stats the caster can't perceive, such as magic
  resistance, Spell Trap levels, Stoneskin count or Death Ward. AGENTS.md's "Play fair" rule.

Origin: **Asc** = Ascension 2.1.0; **SCS nnnn** = SCS 35.21 component; **vanilla** = BioWare's
ToB file in the BIFFs. "Asc; SCS 6800 script" means the ability is Ascension's and SCS rebuilt the
script that fires it.

## Melissan (finale, AR6200)

CRE `finmel01`: override script `FINMEL01` (Ascension), default script `FINMEL` (SCS 6590 "Smarter
Throne of Bhaal final villain", rebuilt from Ascension's own `FINMEL` with the same special
spells; Ascension's version already mixes `ForceSpell` and `SpellNoDec`).

| Script | When | Action | What it does | Breaks | Origin |
|---|---|---|---|---|---|
| FINMEL01 | Last of the Five dies, once | `SetInterrupt(FALSE)`, `ApplySpell(Myself,HEAL_NO_VISUAL)`, dialogue | Full heal | U Z S (story beat, heal not shown) | Asc |
| FINMEL01 | HP < 20 while any of the Five live; at most once per 3 minutes | `DisplayStringHead` ("I must take more essence…"), `ForceSpellPointRES("dimdoor",[1286.1122])`, `ForceSpellRES("melspl02")` | Teleport to a fixed spot, then Draw Power: heal 100 %, magic resistance set to 70 % | D U I (she can't die yet; the line hints, no rule is stated) | Asc |
| FINMEL01 | A member of the Five dies | `DestroyItem("finilla")` and the others | Removes the matching hidden item (next table) | S H | Asc |
| AR6200 (area), FINSEND | One of the Five, Gromnir or a hostile Sarevok has < 20 HP | `Kill(<them>)`, `ActionOverride("finmel01",DestroyItem(…))`, `ReallyForceSpellDeadRES("melspl10","finmel01")` | They die on the spot (visual effects only). Feedback: 100 magic damage to Melissan with her magic-damage resistance zeroed for a second, "Weakened" over her head, she collapses for about 6 s | D S (death by script; what she lost isn't shown) | Asc |
| FINMEL01 | All Five dead and HP < 20 | `ReallyForceSpellRES("finrmde")`, cutscene | All demons unsummoned; defeat cutscene | D (scripted end, for the player) | Asc |
| FINMEL | Fight start, once | `CreateCreatureObject("melrat")`, `ApplySpell` heal, `ReallyForceSpellRES` `melspl01` and `melspl03` | Invisible helper creature; full heal; Divine Mantle (immune to weapons below +6, shows "Protected by Absolute Immunity"); Divine Spell Shield (Spell Trap for 30 levels of level 1–9, turns 10 levels of level 1–3, not dispellable) | U Z C | Asc; SCS 6590 script |
| FINMEL | Every 5–20 rounds by difficulty | `ForceSpellRES` `melspl01`, `melspl03` | Renews Mantle and Spell Shield | U I C | Asc |
| FINMEL | Every 5 rounds while slowed, silenced, blinded, cursed or her stats are lowered | `ReallyForceSpellRES("melspl12")` | Divine Cleansing: dispels everything on her (level 50), cures silence, immune to slow and silence for 5 rounds, resets AC, THAC0, attacks and saves; costs 25 max HP and a 2 s pause | U Z C | Asc |
| FINMEL | When drained (`UseRestoration`) and above half HP | `ForceSpellRES("melspl11")` | Divine Restoration: Greater Restoration and Negative Plane Protection; costs 100 HP and 1 STR | U I C | Asc |
| FINMEL | The Five are all dead, once | `ReallyForceSpellRES("gate5")`, plus `gate5a` twice on Hard and 4 times on Insane, `DisplayString` "Contingency—Fired" | 1, 3 or 5 Gates at once | U Z (a contingency nobody saw her prepare) | Asc |
| FINMEL | Every 3–6 rounds by difficulty while few enemies are up | `ForceSpellRES("gate5")` | Gate: 2 cambions, a succubus, and an alu-fiend, a babau and nabassu, a marilith, a glabrezu or a balor | U I | Asc |
| FINMEL | Insane, once | `ForceSpellRES("gate7")`, "Come to your mistress, minions of the Abyss!" | 2 Fallen Solars | U I | Asc |
| FINMEL | Per target, every 10, 5, 3 or 2 rounds (Easy, Normal, Core, Hard and up), 40 % per pass | `ForceSpellRES("melis01")` | Bone Blades: 5d10 slashing + 5d10 piercing (save vs death −4), then the same again without a save; held 3 s, slowed, −2 DEX. The installed numbers are higher than the notes' 10d6 + 10d6. One display-string effect points at strref 3, an unrelated dialogue line in this install | U I R C | Asc |
| FINMEL | An enemy within reach and no Carsomyr nearby | `ForceSpellRES("melis02")` | Blade Barrier: a contingency around her that fires 12d12 slashing (save vs death −2, bypasses Mirror Image) | U I R C | Asc |
| FINMEL | Every 5 rounds | `ForceSpellRES` or `SpellNoDecRES("mels545")` | Symbol of Slow: slow, AC −4, THAC0 −4, half movement for 2 rounds (save vs spell −4) | U, I half the time, R | Asc |
| FINMEL | `malison_timer` | `ForceSpellRES` or `SpellNoDecRES("melspl07")` | Greater Malison: −4 to saves for 90 s; magic resistance applies | U, I half the time | Asc |
| FINMEL | Melee range; every 3 rounds as area, at will as single target (notes) | `ForceSpellRES("melspl08")` with an attack animation | Unleash: 8d12 magic, knockback, 3 s unconscious (save vs death −4); costs her one attack, half movement and 3 STR for 2 rounds | U I R C | Asc |
| FINMEL | Three enemies within reach; once per 3 minutes | `ReallyForceSpellRES("dgwhirl",[PC])` | Nameless circle kick: 1d6, knockback, 2 s unconscious, no save | U Z R C S | Asc |
| FINMEL | A party demon is near | `ForceSpellRES("melspl05")` | Control Demon: 75 % the demon turns, 25 % it takes 10d6 magic; magic resistance doesn't apply | U I R | Asc |
| FINMEL | Summoned enemies near | `ForceSpellRES("melspl06")` | Banish: unsummons | U I | Asc |
| FINMEL | Once on Normal, every 10 rounds on Core, every 5 on Hard and Insane | `ForceSpell(WARRIOR_GREATER_WHIRLWIND)` | Greater Whirlwind | U I | Asc |
| FINMEL | Cooldowns by difficulty | `ForceSpell` or `SpellNoDec` at even odds, plus a chance to skip | Breach, Pierce Shield, Spellstrike, True Seeing, Finger of Death, Power Word Kill, Time Stop, Unholy Word, Freedom (frees imprisoned allies), Banishment; Dragon's Breath, Comet and Storm of Vengeance once each on Hard and up, after four of the Five fell | U, I half the time, K | Asc list; SCS 6590 script |
| FINMEL | When surrounded; every 3 rounds | `ReallyForceSpellPointRES("dw#fitel",[x.y])` | Teleports to one of three fixed points of the arena | U Z | SCS 6590 |

The hidden items (a ring, a helmet, a belt, bracers and boots, none with a name or description),
all on Melissan from the start:

| Item | Removed when | Gives Melissan |
|---|---|---|
| `FINABAZ` | Abazigal dies | +100 max HP, +45 % electricity resistance, immunity to +3 and +4 weapons |
| `FINBALTH` | Balthazar or Gromnir dies, or neither fights for her | +100 max HP, +15 % to all physical resistances, backstab immunity |
| `FINILLA` | Illasera dies | +100 max HP, +45 % magic damage resistance |
| `FINSEND` | Sendai dies | +100 max HP, +25 % magic resistance, immunity to level 3 and 4 spells, +4 save vs spell |
| `FINYAGA` | Yaga-Shura dies | +100 max HP, +45 % fire resistance (normal and magical), +2 save vs death |

The CRE itself has 500 HP and 70 % magic resistance; her amulet (`FINMEL01`, 110 equip effects),
the `ALLFIVE` ring and effects stored in the CRE add the immunity list from the Ascension notes,
permanent haste, faster casting and see-invisible. With all five items she has the notes'
1,000 HP, 95 % fire, electricity, magic damage and magic resistance, and 90 % physical resistance.

## The Five and their helpers

| Creature, script | When | Action | What it does | Breaks | Origin |
|---|---|---|---|---|---|
| Illasera: `FINILLA` (finale), `ILLASERA` (ch. 9) | An enemy within reach; every 4, 5 or 8 rounds by difficulty; at most 5 times | `ForceSpellRES("illainv")` | Ethereal: one round invisible and immune to most attacks, then 2 rounds improved invisibility, immune to divination, 50 % physical resistance, +4 AC; with sound and visual | U I C | Asc (Tougher Illasera, Gaider); SCS 6800 script |
| Illasera | Below 75 % HP, at most twice | `SpellNoDec(Myself,SPPR502)` | Cure Mortal Wounds (SR's name) without a memorised spell; can be interrupted | U | Asc idea; SCS 6800 script |
| Illasera's bows `ILLAS01`–`03` | Every shot | the item's built-in arrows | Disrupting: dispel at level 30, magic resistance −5, 40 % spell failure, kills summons and illusions. Debilitating: 10 HP drain, stun and slow (save vs polymorph −4). Knockback: 2d10 magic, knockback, 2 s unconscious, −1 THAC0. The first and last ignore magic resistance | R C (endless ammunition, unnamed bows) | Asc (Tougher Illasera); Ascension 2.x fixed an EE glitch that applied the arrows twice |
| Illasera, Gromnir, Sarevok | — | `UseItem` potions with "*quaffs a potion*", `Spell` for HLAs | Real items and memorised abilities | fair | SCS, Asc |
| Gromnir: `GROMNIR` (SCS's generic fighter script `dw3ms5be` copied over it), `FINGROM` + `DW3MS5BE` | — | `Spell`, potions | HLAs from his spellbook; his mace Ice Star spreads diseases with saves | fair | SCS 6810; Asc (Tougher Gromnir) |
| Jumjum, the medusa in Gromnir's hall: `JUMJUM` | Every round | `ReallyForceSpellRES("basilisk",…)` | Flesh to Stone gaze on the nearest enemies | U Z | Asc (Tougher Gromnir); SCS script |
| Ramazith: `RAMAZ` | — | `ForceSpellRES("spcl321")` | Enrage | U I | Asc (Tougher Gromnir) |
| Yaga-Shura: `YAGA01` (override, AR5203) | Until Nyalee's ritual (`YagaShuraHeart` > 0) | `DestroyItem("invulner")` | Hidden item: 100 % to all damage, 100 % magic resistance, immune to every spell level, can't drop below 1 HP | D H (the story tells it; the UI doesn't) | vanilla |
| Yaga-Shura: `YAGA01` | Until the area sets `YagaShuraSpawn` | `DestroyItem("sureHP1")` | Hidden item: can't drop below 1 HP, plus immunities | D S | vanilla |
| Yaga-Shura: `YAGAFT` (default) | Every round once `sureHP1` is gone, while cold resistance > 20 % | `ReallyForceSpellRES("yagweak")` | −2 % to every resistance except fire, down to 20 % cold and 70 % for the rest; the notes call it his invulnerability wearing off | Z S (helps the player, but invisible) | Asc (Tougher Yaga-Shura, Gaider); SCS 6820 script |
| Yaga-Shura: `YAGAFT`, `FINYAGA` | Every 5 rounds; finale on Core and up | `ForceSpellRES("yaga01")`, "Fire!" | Lava Bomb: 1d10 crushing + 8d10 fire (save vs breath half), knockback, unconscious (save vs death −10); ignores magic resistance | U I R C | Asc (Tougher Yaga-Shura) |
| Yaga-Shura | Fire Storm once, Sunray every 5 rounds, Aura of Flaming Death every 10 | `ForceSpell` | Real priest spells without a spellbook | U I | Asc; SCS 6820 script |
| Yaga-Shura | — | `Spell(SPCL815)`, potions | Wholeness of Body from his spellbook | fair | SCS |
| Abazigal: `ABAZIGAL` (race script, lair) | Below 50 % HP, once | `ReallyForceSpellRES` `abzaway`, `jwsp02` | Knockback blast, then turns into the blue dragon | Z (story transformation) | vanilla |
| Abazigal's dragon form `DRAGBLUE`: `ABAZDRAG` | Every 2 rounds | `ForceSpell(SPIN597)` | Lightning breath (24d10, save vs breath half) | U I (normal for SCS dragons) | SCS 6540 script |
| `ABAZDRAG` | Every 21 s | `ReallyForceSpell(SPIN531)`, log line "Abazigal Shockwave" | 4d10 electricity (magic resistance applies), then unconsciousness and 90 % spell failure (it doesn't) | U Z, partly R; announced | Asc (Tougher Abazigal); SCS script |
| `ABAZDRAG` | Every 5 rounds | `ReallyForceSpell(SPPR720)`, log line "Tail Slap" | Earthquake, instantly | U Z; announced | Asc |
| `ABAZDRAG` | Fight start | `ReallyForceSpell` Protection from Magical Weapons, Spell Deflection, Dragon Fear, Mordenkainen's Sword, "Contingency" / "Chain Contingency" | Instant buffs and a summon | U Z | SCS |
| `ABAZDRAG` | When a target qualifies | `ReallyForceSpell` Dispel Magic and Greater Malison, `ReallyForceSpellRES("dw#dt2b")` ("Spell Sequencer") | Two or three spells at once | U Z | SCS |
| `ABAZDRAG` | The rest | `Spell` | Spells from the dragon's spellbook | fair | SCS |
| Abazigal (finale): `FINABAZ` + `DW#MG539` | HP < 60 %, every 3 rounds, Hard and up | `ForceSpellRES("abaz02")` | Lightning Aura: 6d6 electricity (save vs spell −2 half) + 3d6 magic (no save, drained to heal him), knockback, unconscious (save vs death −4); ignores magic resistance | U I R C | Asc; SCS 6830 script |
| `DW#MG539` | Every 3 rounds, Hard and up | `SpellRES("abaz01")` | Shockwave (chain lightning) from his spellbook | fair | Asc; SCS |
| `DW#MG539` | Fight start | `ReallyForceSpellRES` triggers and chain contingency, "Contingency" | Tenser's, Stoneskin, Improved Haste; Symbols of Stun, Fear and Chaos | U Z | SCS |
| Tamah: `ABAZDG02` + override `DW#TAMAH` | Below 50 % HP, once | `ReallyForceSpellPointRES("dwtameth",[10.10])`, `ApplySpellRES("dw#silhe")`; back with `ReallyForceSpellRES("dwtameth",Player1)` when Abazigal transforms | Vanishes to a hidden corner of the map, heals to full out of sight, returns later | U Z S D | SCS 6830 |
| Tamah | On a timer | `ForceSpellRES` breath; `ApplySpellRES("dw#drahp")` | Purple breath (16d8, save vs breath; 50 % unconscious); max HP ×3 | U I H | Asc; SCS |
| Abazigal's drakes: `DRAKE01` | On a timer | `ForceSpellRES` breath | Breath weapon | U I | Asc (Tougher Abazigal) |
| Balthazar: `BALTHFT2` (ch. 9), `FINBALTH` (finale) | When he has the power (`HaveSpellRES`, 20 such checks) | `ForceSpellRES`; `ReallyForceSpellRES` for Tiger Strike and Hand of Murder; `ForceSpellPointRES("balth08")` to teleport; most with `DisplayStringHead` naming the power ("Dragon Fist", …) | Real innate abilities from his spellbook, recharged by his own abilities (opcodes 171 and 172) | I, some Z; but limited, visible, and documented on the abilities when he joins | Asc (Gaider) |
| Balthazar | HP < 20 %, once, Hard and up | `ReallyForceSpell(CLERIC_HEAL)`, "Second Wind!" | Full heal | Z; announced | Asc |
| Balthazar | — | stored in the CRE | Permanent haste, 90 % magic damage resistance, see-invisible | H | Asc |
| Sendai: `FINSEND` (general) | HP < 20 | as AR6200 above, from her own script | Scripted death; Melissan loses `FINSEND` | D S | Asc; SCS 6840 script |
| Sendai: `FINSEND` | An ally is imprisoned | `UseItem` scroll of Freedom, "*uses a scroll*" | Real item | fair | SCS 6840 |
| Sendai: `DW#CM6` (default) | Fight start | SCS prebuffs, two summons and a chain contingency via `ReallyForceSpellRES` | See the SCS patterns below | U Z | SCS |
| Sendai: `DW#CM6` | Chasing | `ReallyForceSpell` Dimension Door after `HaveSpell`, then `RemoveSpell` | Instant, but paid from her spellbook | Z | SCS |
| Sendai | — | stored in the CRE | +4 casting speed, 84 % magic resistance (documented as drow) | H | Asc |
| Bodhi: `FINBODHI` (override) | Cooldowns | `ForceSpellRES` Cloud of Bats, Abyssal Darkness, Chill of the Grave, Touch of Death, Sepulchral Sleep; `ApplySpellRES` Deathly Shroud | Improved Bodhi's vampire powers | U I, Z for the shroud | SCS 8085 |
| Irenicus: `FINIREN` + `DW#MG540` | — | SCS mage script | Prebuffs, Prismatic Mantle, chain contingencies (SCS patterns) | U Z for the prebuffs | SCS 6840 |

## Fiends, Fallen Solars and Demogorgon

| Creature, script | When | Action | What it does | Breaks | Origin |
|---|---|---|---|---|---|
| All of Melissan's fiends: override `DEMONDIE` | On death | `ReallyForceSpellDeadRES("demondie")`; balors `"baldead"` | Death effect; the balor's blast does 50 magic damage around it, magic resistance doesn't apply | Z R | Asc |
| `DEMONDIE` | Melissan's `CommandMinions` timer, Normal and up | `ReallyForceSpellRES("melspl5a",Myself)` | The fiend rolls against her control and bows or defies her (text) | Z | Asc |
| `DEMONDIE` | A friendly demon sees no enemy | `ReallyForceSpellRES("dimdoor",Player1)` | Jumps to Player1 | Z | Asc |
| Alu-fiend, succubus, nabassu, glabrezu, marilith, balor (default `FIN…`) | SCS fiend AI | `ReallyForceSpellRES`/`ForceSpellRES("dw#fitel")` teleport and chase (off with `DMWWNoFiendTeleport`); `ForceSpellRES` `gate1`–`gate4` (fiends gate in fiends); `SpellNoDec` Charm Person; `ForceSpell(SPIN996)` Death Gaze; `SpellNoDecRES("dw#batel")` Telekinesis (save vs spell −10, ignores magic resistance); a fire-aura contingency on the balor | Innate monster powers fired without a spellbook | U, I or Z, some R | SCS 6850 (Ascension demons use SCS AI) |
| Every SCS fiend | Spawn | `ApplySpellRES` `dw#fiehp`, `dw#innat` | Max HP ×1.5; immune to silence, spell failure and deafness; innates cast faster (casting speed +10) | H S | SCS 6510 |
| Babau: `FINBABAU` | — | `ApplySpell` Invisibility; `ReallyForceSpell` Demon Fear, Ray of Enfeeblement; `SpellRES("gate6")` | Instant fear and enfeeblement; Gate from the spellbook | Z | Asc |
| Fallen Solars: `FINSOL04` | — | `ForceSpell` teleport | | U I | SCS 6510 (copy of its solar script) |
| Demogorgon: `DEMOGOR2` (Watcher's Keep) | Cooldowns | `SpellNoDec` Implosion, Finger of Death, Breach, Spellstrike, Unholy Word, Dragon's Breath, Time Stop and others | No spellbook, but interruptible | U | Asc list (Tougher Demogorgon, Gaider); SCS 6510 script |
| `DEMOGOR2` | Repeatedly; once for the host | `SpellNoDec` Gate (`SPIN548`), Summon the Abyssal Host (`SPIN549`), with head texts | Summons; Gate also heals him | U | Asc |
| `DEMOGOR2` | On a timer | `ReallyForceSpellRES` `beguile`, `insanity`, "Feel my beguiling gaze!" / "Suffer under my gaze of insanity!" | Instant gazes; Insanity confuses or feebleminds with no save | U Z R; announced | Asc |
| `DEMOGOR2` | A party demon is near | `ReallyForceSpellRES("democHM")` | Domination: no save, magic resistance doesn't apply | U Z R | Asc |
| `DEMOGOR2` | Fight start; spawn | `ReallyForceSpell` Protection from Magical Weapons, Greater Spell Deflection, Aura of Flaming Death; `MELSTONE` Stoneskin; `dw#fiehp`, `dw#innat` | Prebuffs; hidden HP and casting boosts | U Z H | SCS |

Yaga-Shura's army (`FINYAGAR` override plus SCS's generic scripts) and the Black Reavers use no
specials beyond the SCS patterns.

## SCS patterns these fights inherit

These run in all SCS fights, not only in Ascension's; they matter because players meet them here
at their strongest.
- **Prebuffs "(cast previously)"**: at fight start SCS fires long-lasting buffs instantly through
  `ReallyForceSpellRES` copies named "X (cast previously)" and removes the memorised spell
  (`RemoveSpell`). Paid from the spellbook; the name tells the player what it stands for.
- **Contingencies, triggers and sequencers** (`dw#ccNN`, `dw#tgNN`, `dw#sqNN`): two or three
  spells at once through `ReallyForceSpellRES`, announced as "Contingency" or "Chain Contingency".
- **Free detection**: `SpellNoDec` True Seeing or Oracle without a spellbook;
  `ApplySpellRES("dw#mgsee")` gives see-invisible for 6 s, and that spell is named "Armor".
- **Rest heal**: `ApplySpell(Myself,SPIN746)` heals to full and cures poison and disease while no
  enemy is near.
- **Hidden boosts**: `dw#fiehp` (HP ×1.5), `dw#drahp` (HP ×3), `dw#innat` (no silence, spell
  failure or deafness; faster innates).
- **Fiend teleport** `dw#fitel` and **Dimension Door pursuit** (the latter paid from the
  spellbook).
- **Targeting by hidden stats (K)**: SCS cast blocks check the target's magic resistance, Spell
  Trap, Spell Turning, Stoneskins and Death Ward before choosing.

## What is already fair

- Balthazar's model (above): real abilities, limited, recharged in sight, announced.
- Gromnir, Sarevok, Yaga-Shura's Wholeness of Body, Abazigal's human-form Shockwave and most of the
  dragon's spells: from the spellbook (`Spell`, `SpellRES`).
- Potions and scrolls with "*quaffs a potion*" / "*uses a scroll*".
- Announced powers, even where instant: Abazigal Shockwave and Tail Slap (log lines), Balthazar's
  strikes and Second Wind, Demogorgon's gazes, Lava Bomb ("Fire!").
- Yaga-Shura's invulnerability is vanilla and explained by the story; only the slow wear-off
  afterwards is silent.

## Open questions

1. **What does the player see for each action?** Whether `ForceSpell*` and `ReallyForceSpell*`
   print "casts X" over the head and in the log, and whether `ApplySpell*` prints anything, is
   unverified; SCS naming its prebuff copies "(cast previously)" suggests the name does show for
   `ReallyForceSpell`. Needs a lab fight with the log recorded. This decides how much of the
   complaint is "no log line" and how much is "the log line lies".
2. **Does `ApplySpell*` honour magic resistance and saves?** The IESDP doesn't say; it matters for
   Draw Power, Feedback, Tamah's heal and the Five's death.
3. **Bone Blades' strref 3** shows an unrelated dialogue line in this EET install. Check in play;
   if real, it's a strref-remapping bug between Ascension and EET (no upstream contact without
   Chris's OK).
4. **Can the player see Melissan's item-based defences?** Whether EEex or the EE record screen
   shows them on a hostile creature is unchecked.
5. **Coverage.** Only this lab: Ascension 2.1.0 with SCS and Spell Revisions. The no-SR lab has no
   Ascension, so non-SR Ascension wasn't read; without SCS 6590 and 6800–6850 Ascension's own
   scripts would run (same special spells, Ascension's own casting mix). Other EET, Ascension or
   SCS versions are unchecked.
6. **Untraced details**: when the area sets `YagaShuraSpawn`; the `yagweak` portrait icon (it
   names "Protection From Cold", probably a leftover); Melissan's own amulet effects in full.
7. **Player side** (Ascension's pool powers, Balthazar's powers for the party, Imoen's Slayer
   phase) wasn't inventoried.

## Design options for Chris

Keep the strength, remove the cheating, show what happened. None of these is decided; they can be
mixed per boss. Gameplay decisions are Chris's.

1. **Say what happens** (no balance change). Every forced cast, item swap and scripted heal gets a
   log line and floating text that names it ("Melissan draws on the essence stream: healed,
   magic resistance 70 %"; "Illasera's essence fades: Melissan's magic damage resistance falls to
   50 %"). Custom spells get names, descriptions and icons. A short "boss rules" entry at the start
   of the fight (journal or log) states the immortality rule and what each of the Five protects.
   The Ascension notes already have the text. The engine can print through EEex.
2. **Visible boss phases instead of hidden items.** Keep Melissan's immortality and the Five's
   protection, but as a visible state: a portrait icon or aura per living member ("Shielded by
   Illasera"), removed with a message when they fall. The Five die at 0 HP like anyone else, and
   the area script reacts to `Dead()` instead of killing them at 20 HP.
3. **Real abilities with real limits** (Balthazar's model). Give each boss a named innate ability
   list in the spellbook, with uses per fight or a visible recharge, and cast them with normal
   `Spell`/`SpellRES` (casting time, interruption, spell failure). Strength comes from numbers:
   more uses, shorter casting time, higher damage, better difficulty scaling. Our engine picks
   when and at whom, from what the boss could perceive.
4. **Honest effects.** Spells that look like magic let magic resistance work (resist field 1),
   or say plainly in the description that they're divine or physical and why they ignore it. The
   no-save effects get saves, or the description says there is none. HP multipliers move into
   the creature's visible HP; hidden heals become visible heals.
5. **Difficulty-scaled honesty.** Below Insane: options 1–4. On Insane, the old Ascension rules
   stay as an opt-in "legendary" mode, but announced as in option 1.

A cheap first step would be option 1, because it changes no balance and answers the "no
information" complaint directly; options 2–4 are then chosen boss by boss.
