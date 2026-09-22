# Upstream register and reuse holds

**Status:** Reference register; unresolved derived classes remain shipping-blocked

**Date:** 2026-09-22

**Owners:** Integration owner for intake; upstream authors retain their respective rights

## Source identities

These are the existing PREP-01/PREP-02 research identities, not newly selected lab versions. A label
does not establish that an installed copy has these bytes. No source payload is vendored here.

| Source / credit | Pinned research identity | Current use and decision |
|---|---|---|
| Sword Coast Stratagems — David Wallace (DavidW), with component contributors credited individually | `v35.21`, `5dc240e9ff85d3909b6436e54b56297d3b61e33b`; [copyright section](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/doc/readme-stratagems.html#L1988-L1995) | Primary tactical/encounter corpus; reference-only pending class-specific LIC-01 decisions |
| Spell Revisions — Demivrgvs and contributors at Gibberlings Three | `v4.19`, `e97435afeb14ff5c83cfa41e14c23940c9a0cf8e`; [README](https://github.com/Gibberlings3/SpellRevisions/blob/e97435afeb14ff5c83cfa41e14c23940c9a0cf8e/README.md) | Reference-only for optional effective-spell semantics; no reuse determination here |
| EEex — Bubb and contributors | `v0.11.0-alpha`, `89e524640766aa61d6963070299eaaac86f883d8`; [README](https://github.com/Bubb13/EEex/blob/89e524640766aa61d6963070299eaaac86f883d8/README.md) | Candidate capability profile reference; no engine execution or redistribution permission inferred |
| EET — EET authors and contributors at Gibberlings Three | `v14.0`, `ad20ca29ae797e773fffb10c25537c1b1a674716`; [readme](https://github.com/Gibberlings3/EET/blob/ad20ca29ae797e773fffb10c25537c1b1a674716/EET/readme-EET.html) | Candidate campaign/profile reference; no game payload admission |
| WeiDU — WeiDU authors and contributors | `v251.00`, `5d94cb73661d74a6fd5126ede39c4c7b3748e188`; [commit](https://github.com/WeiDUorg/weidu/commit/5d94cb73661d74a6fd5126ede39c4c7b3748e188) | Candidate future verification tool, not executed here; no binary packaged |

Other tools/mods, including the eventual lab's DLCMerger and Bubb's Spell Menu, require their own
exact artifact intake when the lab profile is frozen. Prior read-only planning references are in
`docs/research/disposable-lab-runbook.md`; accepting a lab convenience is not permission to vendor it.
The old stack's WeiDU 246 provenance and deferred EEex v1 profile remain distinct in PREP-01.

## SCS statement and evidence boundary

PREP-02 recorded the entire pinned SCS readme's identity, not a redistributed copy:

- 345,027 bytes;
- SHA-256 `1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA`;
- pinned revision above; retrieved read-only on 2026-08-31 and rechecked in memory on 2026-09-22.

The copyright section identifies David Wallace and describes code reuse with full credit while
asking that SCS or a modified SCS not be mirrored. That is **evidence:E1 source text**, not blanket
permission for every asset in the repository. The project's conservative hold below is an E0
policy interpretation, not legal advice. Use PREP-02's exact retrieval/hash recipe to reproduce.

| SCS-related artifact class | Current disposition | Evidence/decision still required before any reuse admission |
|---|---|---|
| Upstream-authored source code | Study via pinned reference; no copied code committed by this checkpoint | Specific files, authors, applicable statements, transformation, attribution and permitted-use decision |
| Effective/generated BCS or DLG | Local-only after authorized collection; never a committed fixture here | Generator/input/stack provenance plus separate generated-artifact conclusion; no assumption that a source statement covers game-derived output |
| Rule/data tables | Reference-only | Row/content origin, bundled contributions, derivative scope, exact allowed use |
| Documentation/prose | Link and paraphrase minimal relevant facts only; no full text or copied narrative | Context-specific extract/reuse decision; code permission is not assumed to cover prose |
| Bundled third-party assets | Reference-only; unknown owner means hold | Component-level owner and independent terms, not the umbrella SCS statement |
| Reimplemented tactical/encounter behavior | Document intended preservation/changes in a family ledger; derived implementation remains held | Distinguish original mechanisms from derived policy, trace source rules, review transformations and permitted-use conclusion |
| Small factual observation or digest | Conditional metadata, never an encoded payload | Exact evidence chain, privacy/content review, and recorded admission decision |

No SCS-derived fixture is approved in the current fixture registry. No upstream maintainer was
contacted, no permission/reservation was requested, and no repository/package was published.

## Credit and update procedure

Credit SCS (DavidW) and Spell Revisions (Demivrgvs/G3) visibly where they inform an adapter. Add every
relevant component author rather than treating a project name as complete attribution. A family
ledger must distinguish preserved rules, intentional changes, deferred/omitted behavior, tests,
upstream version/component, effective artifacts, and the distribution decision.

Adding a revision or a new source requires an immutable link/digest and a fresh artifact-class
review; approval never floats to the latest release. Unknown terms keep the material reference-only
while independent mechanisms and original synthetic tests can proceed. LIC-01 remains open for
artifact-specific permitted-use conclusions and bundled-content tracing; this register does not
claim that task is complete.
