# Priest Turn shadow: host checkpoint

2026-10-04 — Task29 in progress, G6 not yet reviewed. **E1+E2, no E4 priest result.**

Question: can the existing eligibility, ownership and replay machinery represent a
second SCS family with different behavior, without building another testing framework?
The selected family has two timer-driven Turn Undead branches, not another spell ranker.

## What works

The authored scalar reducer preserves the selected branch order, coupled target
predicates, timer arguments and later active-window choice. It reuses the existing
manifest/ownership/snapshot contracts and records a replayable no-dispatch proposal.
An initialization proposal requires a fresh observation; it does not write timers or
execute SCS's same-pass Continue. This shadow boundary is not a gameplay redesign.

Five grouped scenarios run on each Lua backend: initialization/replay; subsequent
window/cooldown; false or unknown predicates; resource/family/control/ownership/stale
observation rejection; and invalid data/tampered replay. Tests contain no game assets.
Independent review found missing family scoping; its failing test was reproduced,
then exact manifest ID and authored priest-root checks were added. The register's
obsolete mage-only wording was corrected at the same checkpoint.

Reproduction from the repository root:

```powershell
./scripts/test.ps1 -Suite unit -Filter priest_turn -Seed 47
./scripts/test.ps1 -Suite all -Seed 47
```

Focused result: 2 passed, including both backends and all five groups. Combined
result: 216 passed across 38 files. Python3.11.9, Lupa2.8, Lua5.1 and
LuaJIT2.1.1774896198. This is host evidence, not a priest executing Turn in the engine.

## Source and remaining engine batch

The [family ledger](../provenance/scs/priest-turn-ledger.md) pins SCS35.21/component6040,
source/effective hashes, the exact offline byte-identical roundtrip and its limitations.
The decompile emitted179 missing-ID diagnostics; these remain recorded, not dismissed
as a clean whole-script translation. Its installed neutral priest is not enrolled:
an earlier NoAction block and unresolved encounter control prevent that conclusion.

Next: build one authored private priest/undead scene and observe a useful continuous
legacy batch spanning initialization, active window, cooldown and target-state changes.
Compare the existing shadow decisions against observed legacy timer/Turn behavior.
Do not evaluate a stateful See trigger as an allegedly mutation-free reader: its
selected-target state needs a reviewed observation method. Native trigger evaluation
has not been attempted. No native Turn dispatch is authorized by this checkpoint.

Bounded reader research (E1): installed `EEex_Object.lua` resolves LastSeenBy through
native Decode/GetShare, not a source-proven passive getter. `getLocalInt` can read
raw timer values without evaluating See, and world time is exposed, but exact
GlobalTimerNotExpired equivalence remains unproved. Independent extraction and lead
source inspection agree. Exact wrapper hashes/lines and the proposed observation
boundary are retained in `.work/task29/turn-source-v1/reader-evidence.md`; no native
call was made. Reuse these findings rather than repeat the source investigation.

Runtime agreement/divergence, fixture-build effort and runtime cost remain unmeasured.
Task29 completes after that batch and review; Task30/G6 must use those actual results,
not extrapolate broad migration cost from these host examples. No new design choice
has been identified at this checkpoint.
