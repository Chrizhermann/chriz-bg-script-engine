# Connected mage/prebuff shadow — disposable-engine results

**Question / result:** Does the new chooser make reproducible, lawful decisions from changing
engine observations without issuing actions? Yes within this explicitly authored two-observer
pilot. This does not yet make our AI cast. G4's scoped technical review is recorded separately.

**Environment:** Approved BG2:EE2.7.3/EEex1.2.0 LuaJIT/EET14/SCS35.21/SR4.21-chriz.5/Bubb
Spell Menu5.2 lab. Same exact tool/profile pins as G3; no upgrade, active-game mutation or new
installation. WeiDU24900 created private CRE fixtures offline; current194 host checks pass.

## Method and observations

One hidden non-input-desktop session loaded only own baseline973. Three hostile test mages and
one passive opposing target in quiet BG2602; only the first two mages were enrolled. Test-vector
weights prioritize the two prep proposals over Missile, not a player-facing balance preset.
The snapshot exposes current own readiness/allocation/buffs and observed target position/LOS/
allegiance, not target-private books/resistances/effects. No queued spell is called completion.

The first baseline failed before any harness cast: an absent dialogue menu returned nil, so
the ownership reducer correctly declined `unknown-dialogue`. Its18 decisions and failure remain
private. A focused host reproduction established the cause; coercing the known menu predicate
to boolean fixed it. The closed harness was replaced through the existing one-registration
listener trampoline without relaunching. Controllers were cleared at the load boundary.

| Completed sequence | Decisions / event rows | Observed behavior |
|---|---:|---|
| Corrected v2 |156 /509| Shield on mage0, Mirror on mage1; Missile/Glitterdust/Slow research casts; three legacy Strength casts and moves. New choices followed changed prep availability. Target37→29HP. |
| Expanded v3 |200 /747| Both preparations on both observers, then12 live Missile selections, followed by the same offensive/legacy sequence. Target37→27HP. Sole party actor idle at all101 sampled passes. |

Expanded v3's first two Missile choices occur at tick34151 after both observers' Shield+Mirror
effects are recorded and before the same-tick offensive harness requests. The other selected
IDs comprise19 Mirror choices,1 Shield,9 wait and159 decline; occupied/aura phases dominate
the declines. These are repeated observations, not200 spells. All356 completed-sequence decision
records replay identically on both Lua backends. The failed baseline also replays its18 declines.

Ten ordinary action31 starts in v3: four prep, three offensive and three legacy Strength casts.
Ready-copy depletion, source-SPWI114 opcode328/parameter126, source-SPWI212 opcode159 and legacy
source-SPWI214 opcode44 were independently checked. Legacy movement reaches each authored target
within24pixels with phase4/done1. Slow/Glitterdust copies were spent, but target control effects
were not observed in the selected final sample: landing/save/resistance remains unknown. Their
point geometry is not promoted from the harness to policy eligibility. All new-AI proposals
remained shadow types, with dispatchAuthorized=false.

Each synchronous observer call left sampled actor state unchanged; independent code review found
no shadow write/queue operation. Named973 reload completed, cleared enrollment/controller state,
and each native listener retained one registration. Both adapter circuits recorded zero errors.
No actor userdata or runtime IDs appear in decision traces; the native mapper resolves transiently.

## Comparison and bounded acceptance

The five reviewed generic prep examples now exercise actual preparation.check on both host Lua
backends and match selected SCS E1 gate expectations. The sixth oracle case describes separate
first-round/rest writers; it is not falsely tested as part of generic prep. SCS credit remains
DavidW; Spell Revisions credit Demivrgvs/G3. No upstream bytes are published.

The authored current-buff and ownership/aura exclusions are conservative pilot differences.
They remain unresolved for production SCS policy and do not alter legacy behavior in this run.
The test-vector ordering of Mirror before Shield agrees with the selected source block order;
ordinary offensive scoring is not advertised as MAGE6B behavior or an SCS stochastic match.
Neither whole-actor SCS closure nor helper force/debit execution is admitted.

Combined observer cost in v2: median8.555ms/p9517.994ms/max22.757ms. V3:
median8.549ms/p9518.115ms/max19.893ms. Two observers every five world ticks, at most1000 decisions/
16MiB, declared p95<20ms/max<150ms development ceiling. This is not a production scale claim.

## Reproduction / artifacts / cleanup

Authored recipes: `experiments/combat-pilot/build-fixture.tp2`, `shadow-session.lua`,
`python -m tools.build_combat_bundle <new-output>` and `python -m tools.replay.replay
<private-decisions.jsonl> --backend lua51|luajit21`. Use the private fixed13-target lab recipe,
fresh pong/cloud0, own save973 and exact recorded inputs; never point it at the active game.
Private `.work/task24/fixture-build-v2` records the offline commands and byte checks;
`.work/task24/shadow-runtime-v1` holds configuration, exact source/tool identities, started/closed
results, full JSONL, staging ledger, original backups and cleanup receipts. Its prelaunch record
also preserves two corrected startup-query mistakes and the nil-dialogue failure.

| Private fixture | SHA256 |
|---|---|
| B-XPMAG0.CRE |`536AC592EC7A0D5B14D59BB11A7044AAF888F68578E05FA80E50E69C26383B13`|
| B-XPMAG1.CRE |`F36A16D75F503EAC32EDC1C9BBE2F935E0A80ED55A2487A2EF8007F5F5583197`|
| B-XPMAG2.CRE |`8C326ED041196AD74060A60D57D41485DD55CA6C7D2C8C2194EF8606229D9B5B`|
| B-XPTRG0.CRE |`45E6B0013ECB214DBB3E311AED5E3A84C74B70955830C3F4E65F03A61B863D0A`|

Mages have EA255, targetEA4, all37HP; v2 differs from superseded v1 only at EA@0x270. Exact selected
spell pins remain in COMBAT-01, the installed-prebuff comparison and ACT-02; no transitive
resource closure is inferred. C1 declarations cover this authored observation scene only.

Own process tree stopped; three originals restored, ten additions and owned IPC removed;
reservation token released. No new save, full copy or material disk cost. Preserve these small
evidence files. E1+E2+bounded E4 supports the narrowed G4; G5 active execution remains next.
