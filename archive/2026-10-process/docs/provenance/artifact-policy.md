# Artifact and behavior provenance policy

**Status:** Accepted for Task 4 host-side governance; not publication approval

**Date:** 2026-09-22

**Owners:** Integration owner; each artifact and behavior also names its responsible owner

## Decision and scope

Every artifact and migrated behavior needs a recorded origin, owner, evidence chain, credit, and
distribution decision before admission. Unknown provenance means hold, not inferred permission.
This policy completes Task 4's governance scope; it does not close LIC-01 through LIC-04 or
TEST-01/TEST-02 and does not approve a release or a repository license.

The current mechanical admission contract covers only reviewed, independently authored JSON
fixtures under `tests/fixtures`. It does not inspect arbitrary source code, archives, installed
games, secrets throughout the repository, or future release output. Ordinary source/documentation
review remains required. No change here grants game access or starts Task 3.

## Artifact classes and locations

Origin and artifact class are separate. An SCS-derived JSON file is still SCS-derived; calling it
synthetic, metadata, or a fingerprint does not erase its source or restrictions.

| Classification | Location and permitted use now | Default distribution decision |
|---|---|---|
| `independently-authored-metadata` | Project-authored schemas, docs, and tooling metadata in their normal repository directories; fixture instances require the exact allowlist | Candidate `redistributable` after review |
| `short-factual-extract` | A minimal cited fact in a research record; no copied narrative, tables, or bulk reconstruction | `conditional`; contextual review required; not currently a fixture input |
| `generated-fingerprint` | Digest and reproducible procedure in the evidence ledger; no embedded original payload | `conditional`; source, privacy, and provenance review required; not currently a fixture input |
| `locally-generated-effective-artifact` | Local evidence outside the repository, only after access is authorized; link with a nonpersonal artifact ID, not a machine path | `local-only`; never commit or package |
| `redistributable-synthetic-fixture` | Independently constructed, reviewed JSON in `tests/fixtures`, exact path and SHA-256 in the allowlist | Candidate `redistributable` after review |
| `upstream-source` | Revision-pinned external reference, not vendored into this repository | `reference-only` while artifact-class reuse is unresolved |
| `forbidden-packaged-content` | No repository or package admission; if legitimately needed for research, keep outside the repository and respect access limits | `forbidden` |

The last class includes game resources, installed binaries, saves, TLK content, credentials,
personal-path logs, full SCS source, generated effective BCS/DLG, and unapproved third-party payloads.
An allowlisted extension is not permission to wrap such payloads in JSON or encode them as strings.
Redaction, decompilation, translation, renaming, and hashing must be described as transformations;
they are not automatic permission or proof of independent authorship.

Future original fake-game builders may generate minimal format-shaped bytes in temporary test
directories under a separately reviewed TEST-02 contract. That is not permission to commit a real
TLK/save/binary, and Task 4's JSON checker does not implement or verify that future E3 contract.
Negative tests here construct tiny original descriptors, headers, and path strings at test time;
they do not import prohibited payloads.

## Evidence and behavior records

Use `archive/2026-10-process/schemas/research-evidence.schema.json` and `archive/2026-10-process/docs/research/evidence-template.md` for material
research claims. Record stable artifact/claim IDs, source revision/path and byte digest, acquisition
date, transformation, owner, applicable evidence layers, observations, counterevidence, residual
uncertainty, and next decision. IDs are not interchangeable with resource names or private paths.

Every migrated behavior family additionally records:

- origin: original, game-derived, SCS-derived, SCS compatibility, or reference-only;
- upstream version/component, exact source artifacts, effective generated artifacts, and their
  evidence IDs; use reference-only placeholders when collection is not yet authorized;
- behavior summary, preserved fairness and encounter rules, intentional changes, omissions, and
  opaque cases; a change is not automatically an improvement;
- dependency/external-control closure, public-state dependencies where applicable, support tier,
  tests, ownership boundary, and legacy fallback;
- responsible owner, specific upstream credit, distribution status, decision reference, reviewer,
  and date. Missing evidence or reuse decisions keep the family held.

Keep original kernel mechanisms separate from family policy and derived data. Future adapters and
their ledgers belong together under a declared family boundary; core modules must not import SCS
adapter policy. Task 4 defines that direction, but dependency linting and enumeration of future
derived material remain LIC-02 work. Generated `dw#*` names alone never establish family identity.

## Admission and change procedure

1. Classify origin before generating or collecting bytes. Prefer original synthetic examples.
2. For upstream/derived work, consult the [register](upstream-register.md). Record the exact source
   and reuse question; do not contact authors or publish anything without authorization.
3. An independent reviewer checks authorship claims, source/derivation, content, privacy, credit,
   and the intended test. The integration owner resolves findings and owns the admission decision.
4. For an admissible original JSON fixture, add its exact relative path and raw-byte SHA-256 to
   [the registry](fixture-allowlist.json), with the required provenance and dated review fields.
   Approved fixtures use LF on every checkout through `.gitattributes`.
5. Run the focused fixture tests, the complete host suite, and `git diff --check`. Any missing,
   changed, unlisted, ambiguous, or held fixture refuses the fixture set.
6. Commit the reviewed fixture, registry, test, and evidence together. A changed digest means review
   the new bytes; never normalize or recalculate hashes automatically to make validation green.

Here `redistributable` plus `approved-for-repository` records admission of this project's original
fixture into the private repository. It is not a public-license grant, release approval, or claim
that a checker can determine copyright. A contributor can falsely label copied prose `original`;
the checker cannot discover that lie. Human source review is indispensable.

Contribution review uses the same objective inputs: missing origin, source, evidence, credit, or
decision is a refusal. For example, an original abstract queue observation with reviewed bytes may
enter; a copied SCS rule table labeled synthetic may not. Naming must follow the G0 `B-` namespace
contract and must not imply affiliation with Tactics/Tactics Remix. External contributor license
terms, final notices, and a public CONTRIBUTING policy remain LIC-04/G8 decisions.

## Publication audit specification (deferred)

Before any external sharing, LIC-03 must add a separate positive publication manifest and scanner
covering the clean source tree, generated output, nested archives, resource/save/TLK signatures,
personal paths, secrets, and provenance. Enumerate exact output paths/digests; reject unclassified
or local-only inputs and output not in that manifest. Test negative samples made independently,
not copied from games. Build twice from clean permitted inputs and compare canonical manifests.

Then prove with pinned real WeiDU in a synthetic fake game that package install, reinstall,
controlled failure, and uninstall respect the manifest and restore required bytes. This requires
both evidence:E2 scanner results and evidence:E3 integration results; neither substitutes for the
other. Archive handling, package creation, game format scanning, and those WeiDU runs have **not**
been implemented or executed by Task 4. G8 and explicit publication authorization remain separate.
