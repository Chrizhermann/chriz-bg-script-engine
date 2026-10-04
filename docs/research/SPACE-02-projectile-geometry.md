# SPACE-02: bounded point coverage, not general projectile simulation

Date: 2026-10-04. Task28. E1 effective resource/source inspection, E2 geometry
reduction, E4 input coordinates only; no new native AoE delivery proof.

## Question, environment and evidence

Can the pilot reject area choices when current known allies overlap a declared
shape, without assuming every point spell is a circle? The environment is the
current stack pinned in [SPACE-01](SPACE-01-coordinate-and-los.md) and
[COMBAT-01](COMBAT-01-candidate-inputs.md). Effective files were inspected read-only;
their existing COMBAT-01 hashes and corrected projectile mapping were reconfirmed.

| Effective spell | SPL projectile -> PROJECTL ID | PRO | Explosion size | Child projectile |
| --- | --- | --- | --- | --- |
| SPWI224 | 425 -> 424 | DVGLDUST | 110 | 48 |
| SPWI312 | 159 -> 158 | INAREANP | 256 | 0 |

Both PROs are768-byte type3, extended flags0, area flags64, proximity size256,
frequency100 and repetitions1. These are E1 bytes, not complete recipient semantics.
Pins: DVGLDUST `FC60A681D7F36F0DED4D6192EE968964AF85C870CA8AB6E5A898C219CD276994`;
INAREANP `FF8B9B888A1BDF476D33DCDD63078D402D941CB0AAEA306981B10645C509E61A`.

The [IESDP PRO description](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/pro_v1.htm)
describes horizontal radius units, a3/4 vertical scale and area enemy filtering.
That unpinned description is E0 input. Source bytes plus a radius field do not
prove filters, child effects, recipient timing, repeated bursts or safe dispatch.
The radius/filter interpretation remains separate from the verified raw fields.

## Implemented reducer and integration

`geometry.assess(view, descriptor, anchorKey, coverage)` consumes explicit resource,
geometry identity, shape, radius and metric scales. It supports only declared
circles; unknown radius/shape or incomplete/stale coverage cannot attest safety.
Coverage must match the exact frame's actor keys, scene, observer and tick. Every
live actor needs current observed position/relation/life evidence; known dead actors
are omitted. Unknown actors/facts do not become empty space.

Enemies count only inside the true radius. Self, ally and neutral overlap inside
radius plus caller padding produces risk; no enemy-only filter is inferred. Output
is attached to the exact point/resource/geometry/frame expected by existing spell
legality. A safe synthetic example becomes a point proposal; moving an ally into
it excludes that proposal. The reducer never submits an action.

Applied on both Lua backends to the recorded five-actor lab positions as **circle
hypotheses**, radius110 overlaps one friendly mage and radius256 overlaps all
three. Both are rejected under this conservative geometric model. That does not
claim Slow or Glitterdust actually harms those allies: documented enemy filtering
may make this deliberately over-conservative. These reductions are E2 over E4
coordinates, not a live recipient test or an admitted effective geometry.

## Verification, limits and next decision

Missing-module RED preceded implementation. Tests cover ally boundary/padding,
vertical metric, unknown shapes/radii/coverage/relations, stale facts, dead actors,
copied deterministic output and existing candidate legality. Independent source
extraction and lead review checked metric/attestation boundaries. Reproduce with
`scripts/test.ps1 -Suite all -Seed 47`; private `analyze-query.py` verifies the recorded
positions without touching a game. Native source and full receipts are retained
privately under `.work/task28`; no installed artifacts are published.

Task28's scalar risk layer is complete; SPACE-02's authoritative projectile model
is not. The native pilot still supplies no admitted point geometry and cannot
dispatch these spells. Next area-spell admission needs a representative ordinary
cast batch comparing predicted and observed recipients, including an ally boundary,
and resolving relevant child/filter behavior. Cones, lines, rays, clouds, repeated
bursts and recipient movement remain explicitly unsupported, not approximated as
circles. No SCS tactical rule, fairness rule or gameplay weight was changed here.
