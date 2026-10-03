# Integrated kernel observer batch

This batch connects the new observer kernel to four authored lab characters. It is not an
active Combat Intent policy or an SCS migration claim. Legacy BCS supplies the ordinary casting
and movement; the kernel must observe only exactly admitted actors and leave all behavior alone.

## Allocation and recipe

| Artifact | Engine name | Use |
|---|---|---|
| Observer-only module bundle | `B-KCORE0.lua` | Authored kernel and read-only boundary; explicitly loaded for this batch |
| Four synthetic casters | `B-XKMAG0.CRE` through `B-XKMAG3.CRE` | Separate semantic identities; private clones of the stripped research donor |
| Legacy phase script | `B-XKLEG0.BCS` | Ordinary self Strength, movement, completion marker |

Stems are unique across extensions. The `X` assets are synthetic-only, not adapters for real
content. Adapter IDs are `B-/combat/lab-observer-0`, `-1`, and `-2`; actor3 remains unregistered.
Each admitted actor has its own exact-resource declaration. One intentionally changed declaration
must decline while the other two keep being observed. No adapter ID is shortened into a resref.

Build the CREs with `build-fixture.tp2`, passing the exact private `B-XMAGE2.CRE` donor as argv0
and a fresh output directory as argv1. Compile the BAF with the already recorded private IDS
copies and WeiDU24900. Generated CRE/BCS, source-game IDS, hashes and command logs stay private.
Bundle authored Lua using `python tools/build_observer_bundle.py <fresh-output>/B-KCORE0.lua`.
Run the combined host check with `pwsh -File scripts/test.ps1 -Suite all`.

The fixture is unarmed by default. In one hidden session, create four fresh casters in the quiet
own baseline, set each own `B-XKCASE` to0–3 and arm `B-XKPHASE=1`. Each script casts SPWI214
normally, moves to its distinct authored point and sets `B-XKDONE=1`. Verify start, expenditure,
later effect, displacement and marker independently; a phase marker alone cannot prove casting.
Then test observer exception/capability loss/disable and lifecycle boundaries without forcing
legacy action completion. Collect full relevant scalar traces for one batch analysis.

Own baseline973 starts in BG2600: use the existing guarded room-entry recipe before scene
creation. Separate queued CreateCreature actions with newlines, not spaces. Wait for all four
distinct actors before loading `session.lua`; its chunk returns a factory, so invoke the chunk
and then the factory with the private config. Full result and honest limits are recorded in
`docs/research/KERNEL-01-integrated-observer.md`.

## Limits

The exact private run receipt records build/tool identities, environment, commands, scene results,
cost and cleanup. Host tests alone do not complete Task16 or pass G2/G3. Snapshot schema v1 is
deliberately read-only; active action dispatch, a production scheduler, save-baked identity and
broader EEex layouts remain unavailable. The bundle does not globally modify `require` or expose
native objects to observer policy. Existing lab/menu/launcher tooling is reused.
