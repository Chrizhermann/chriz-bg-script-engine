# PREP-02 evidence and provenance index

**Status:** Conditional

**Date:** 2026-08-31

**Owners:** Integration owner

**Applicable evidence:** evidence:E1 pinned SCS source identity plus evidence:E2 deterministic
ledger/schema mechanics. The embedded architectural statements remain evidence:E0 inputs.

## Question and outcome

Can a reviewer trace one Combat Intent rule and one WorldFlow compatibility contract from a design
statement through exact evidence to a fail-closed conclusion without personal memory or the active
game?

**Outcome:** Conditional — evidence:E1 + evidence:E2 mechanics only.

The two repository-only trace chains below are complete and mechanically validated. The pinned SCS
reuse statement is recorded as E1 static evidence. No game installation, save, installed resource,
or engine process was consulted. This checkpoint proves neither engine behavior nor a legal,
packaging, publication, or redistribution conclusion. E3 through E5 remain unexecuted.

## Ledger conventions

- Research IDs use `research:<stable-slug>`; artifact IDs use `artifact:<stable-slug>`; claim IDs use
  `claim:<stable-slug>`. An ID is never reassigned to different bytes or a different semantic claim.
- Repository artifacts use a commit plus Git blob hash. Remote artifacts use a revision-pinned URL
  plus a byte digest. A mutable label or unpinned URL is insufficient.
- Every claim resolves only to artifact IDs in its record and names its limitation. Missing or
  ambiguous evidence leaves the result `Unknown` or `Conditional`; it never becomes a runtime fact.
- Every material record includes environment, versions/fingerprints, method, observations,
  counterevidence, artifacts, applicable evidence layers, residual uncertainty, and next decision.
- The stdlib checker validates the project-required keyword subset. It is **not a full JSON Schema conformance implementation**.
- The PREP-02 index contains exactly two uniquely identified records. Record IDs are unique across
  the index; artifact and claim IDs are unique within their record, so every claim reference has
  exactly one local target.
- Cross-field checks bind `sha256` to 64 hex characters and `git-blob-sha1` to 40, require artifact
  layers to occur in their enclosing record, and reject evidence or game-state access that the
  declared environment cannot produce. A standards validator alone is not a complete project check.

## PREP-02 intake classifications

These are provenance intake classes, not final permission decisions:

| Classification | Meaning at this checkpoint | Default distribution state before later governance |
|---|---|---|
| `independently-authored-metadata` | Project-authored schema, index, rule description, or test metadata | Candidate `redistributable`; ordinary repository review still applies |
| `short-factual-extract` | Minimal fact recorded from a pinned source without packaging that source | `conditional`; cite and review context |
| `generated-fingerprint` | Digest or deterministic identity derived without copying payload content | `conditional`; retain source/procedure |
| `locally-generated-effective-artifact` | Locally generated installed/decompiled/effective material | `local-only`; never package by default |
| `redistributable-synthetic-fixture` | Independently constructed synthetic bytes with documented origin | Candidate `redistributable`; later fixture allowlist must approve it |
| `upstream-source` | Third-party source or documentation inspected in place | `reference-only` until an artifact-class decision exists |
| `forbidden-packaged-content` | Game resources, saves, TLK, installed binaries, personal-path logs, or held third-party payloads | `forbidden` |

At the 2026-08-31 checkpoint, the artifact policy, upstream register, and fixture allowlist remained
Task 4 steps 7–9. That checkpoint did not create or pre-approve them. The dated follow-up below
records the later governance work without changing the two historical evidence traces.

## Trace 1 — Combat Intent queue acceptance is not completion

```json
{
  "schemaVersion": 1,
  "id": "research:prep02-combat-queue-acceptance",
  "recordType": "research-result",
  "title": "Combat Intent queue acceptance remains a nonterminal observation",
  "outcome": "Conditional",
  "question": "Can the queue-acceptance rule be traced to exact repository evidence while preserving its runtime-proof boundary?",
  "environment": {
    "kind": "env:host",
    "description": "Windows NT 10.0.26200.0 host; CPython 3.11.9 and pytest 8.4.2 used for deterministic stdlib schema validation.",
    "gameStateAccess": "none"
  },
  "versions": [
    {
      "component": "Chriz BG Script Engine architecture",
      "version": "2026-08-27",
      "revision": "7e74e1e08e7ed6dac620268937197b93e8acd97d",
      "fingerprint": "git-blob-sha1:93ea6a1b981047dfdd8d9bcd8713b04b95de9545",
      "source": "git:7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md"
    },
    {
      "component": "Sword Coast Stratagems",
      "version": "v35.21",
      "revision": "5dc240e9ff85d3909b6436e54b56297d3b61e33b",
      "fingerprint": "sha256:1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA",
      "source": "https://raw.githubusercontent.com/Gibberlings3/SwordCoastStratagems/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/doc/readme-stratagems.html"
    }
  ],
  "method": {
    "summary": "Inspect the revision-pinned architecture statement and SCS copyright section, record immutable identities, then validate this record and its claim references with the stdlib-only project subset checker.",
    "commands": [
      "git show 7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md",
      "python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q"
    ],
    "constraints": [
      "No active or disposable game access.",
      "No engine-runtime inference from source or schema acceptance.",
      "No redistribution permission inferred from the SCS statement."
    ]
  },
  "observations": [
    "Architecture section 3 says a queued action being accepted does not prove that it started, completed, or persisted.",
    "Architecture sections 8.2 and 13 require a separate in-flight observation state and action-family-specific outcome/postcondition evidence.",
    "The SCS v35.21 Copyright Information section identifies David Wallace and describes requested credit and anti-mirroring conditions for code reuse."
  ],
  "counterevidence": [
    "No disposable-engine action lifecycle was observed, so the repository statement is not E4 runtime proof.",
    "No artifact-class legal review was performed, so the SCS statement does not settle redistribution permission."
  ],
  "artifacts": [
    {
      "id": "artifact:architecture-queue-contract",
      "kind": "source-file",
      "classification": "independently-authored-metadata",
      "owner": "Chriz BG Script Engine integration owner",
      "component": "Chriz BG Script Engine architecture",
      "version": "2026-08-27",
      "revision": "7e74e1e08e7ed6dac620268937197b93e8acd97d",
      "sourcePath": "git:7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md",
      "acquisitionDate": "2026-08-31",
      "digest": {
        "algorithm": "git-blob-sha1",
        "value": "93ea6a1b981047dfdd8d9bcd8713b04b95de9545"
      },
      "transformation": "None; exact committed source inspected.",
      "requiredCredit": "Project-authored design; preserve repository attribution.",
      "redistributionStatus": "redistributable",
      "evidenceLayers": [
        "evidence:E0"
      ]
    },
    {
      "id": "artifact:scs-v35.21-reuse-statement",
      "kind": "source-file",
      "classification": "upstream-source",
      "owner": "David Wallace (DavidW)",
      "component": "Sword Coast Stratagems",
      "version": "v35.21",
      "revision": "5dc240e9ff85d3909b6436e54b56297d3b61e33b",
      "sourcePath": "https://raw.githubusercontent.com/Gibberlings3/SwordCoastStratagems/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/doc/readme-stratagems.html",
      "acquisitionDate": "2026-08-31",
      "digest": {
        "algorithm": "sha256",
        "value": "1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA"
      },
      "transformation": "None; read-only inspection of the Copyright Information section.",
      "requiredCredit": "Give full credit to David Wallace (DavidW) for borrowed or reused SCS code.",
      "redistributionStatus": "reference-only",
      "evidenceLayers": [
        "evidence:E1"
      ]
    }
  ],
  "evidenceLayers": [
    "evidence:E0",
    "evidence:E1",
    "evidence:E2"
  ],
  "claims": [
    {
      "id": "claim:combat-accepted-not-complete",
      "statement": "A queue-accepted Combat Intent action is not completion; completion requires an independent observer or declared postcondition, otherwise the outcome remains unknown and control yields.",
      "evidenceRefs": [
        "artifact:architecture-queue-contract"
      ],
      "limitations": [
        "This is an E0 architecture contract with E2 trace validation, not observed engine behavior."
      ]
    },
    {
      "id": "claim:scs-reuse-statement-pinned",
      "statement": "The pinned SCS v35.21 copyright section says code may be borrowed or reused with full credit and asks that SCS or a modified SCS not be mirrored.",
      "evidenceRefs": [
        "artifact:scs-v35.21-reuse-statement"
      ],
      "limitations": [
        "This is E1 source evidence; interpretation is E0 policy, is not legal advice, and does not authorize redistribution."
      ]
    }
  ],
  "residualUncertainty": [
    "Action-family-specific completion signals remain unproved until ACT-01 and ACT-02 produce E4 evidence.",
    "SCS artifact classes and bundled third-party provenance remain unresolved until LIC-01."
  ],
  "nextDecision": {
    "decision": "Require each supported action family to name an independent terminal observer before it can report success.",
    "owner": "ACT-01 and ACT-02 integration owner",
    "condition": "Revision-pinned E1 capability research plus authorized E4 action-lifecycle evidence.",
    "fallback": "outcome-unknown-and-yield"
  }
}
```

Trace result: the architecture source establishes the policy input; the record resolves its claim to
that exact blob; the only safe non-runtime conclusion is that `accepted` remains nonterminal. If an
independent postcondition is absent, the bounded result is outcome-unknown and yield. The SCS
artifact in the same record separately demonstrates an upstream E1 manifest and is not evidence of
engine action behavior.

## Trace 2 — WorldFlow unknown public state or writer drift yields

```json
{
  "schemaVersion": 1,
  "id": "research:prep02-worldflow-public-state-drift",
  "recordType": "research-result",
  "title": "WorldFlow yields on unknown public state or writer drift",
  "outcome": "Conditional",
  "question": "Can the WorldFlow public-state compatibility rule be traced to exact repository evidence without claiming an unexecuted stack scan?",
  "environment": {
    "kind": "env:host",
    "description": "Windows NT 10.0.26200.0 host; CPython 3.11.9 and pytest 8.4.2 used for deterministic stdlib schema validation.",
    "gameStateAccess": "none"
  },
  "versions": [
    {
      "component": "Chriz BG Script Engine architecture",
      "version": "2026-08-27",
      "revision": "7e74e1e08e7ed6dac620268937197b93e8acd97d",
      "fingerprint": "git-blob-sha1:93ea6a1b981047dfdd8d9bcd8713b04b95de9545",
      "source": "git:7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md"
    },
    {
      "component": "Chriz BG Script Engine research backlog",
      "version": "2026-08-27",
      "revision": "82caec04325018a32b593a42880c300eee64aec9",
      "fingerprint": "git-blob-sha1:2f4785ebe0955d8d036585207088ed158437b0d1",
      "source": "git:82caec04325018a32b593a42880c300eee64aec9:archive/2026-10-process/docs/research/research-backlog.md"
    }
  ],
  "method": {
    "summary": "Inspect the revision-pinned public-variable and external-control rules, record their exact blobs, and validate the claim-to-artifact chain using only repository inputs.",
    "commands": [
      "git show 7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md",
      "git show 82caec04325018a32b593a42880c300eee64aec9:archive/2026-10-process/docs/research/research-backlog.md",
      "python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q"
    ],
    "constraints": [
      "No active or disposable game access.",
      "No effective-stack reader/writer scan was executed.",
      "Unknown syntax and ownership remain opaque rather than guessed."
    ]
  },
  "observations": [
    "Architecture section 11.6 says new global writers can invalidate WorldFlow ownership without changing the claimed DLG or BCS.",
    "Architecture section 11.7 requires all known public-variable readers and writers to be indexed and requires reconciliation or yield on unknown values or writers.",
    "Backlog BCS-03 makes an unknown area or encounter controller, shout or global writer, forced action, or script owner a stale-adapter condition."
  ],
  "counterevidence": [
    "No typed-IR completeness proof exists for a real effective stack, so safe reactivation after drift is not established.",
    "No E3 installer or E4 WorldFlow runtime result was produced by this host-only trace."
  ],
  "artifacts": [
    {
      "id": "artifact:architecture-worldflow-public-state-contract",
      "kind": "source-file",
      "classification": "independently-authored-metadata",
      "owner": "Chriz BG Script Engine integration owner",
      "component": "Chriz BG Script Engine architecture",
      "version": "2026-08-27",
      "revision": "7e74e1e08e7ed6dac620268937197b93e8acd97d",
      "sourcePath": "git:7e74e1e08e7ed6dac620268937197b93e8acd97d:docs/plans/2026-08-27-script-engine-architecture-design.md",
      "acquisitionDate": "2026-08-31",
      "digest": {
        "algorithm": "git-blob-sha1",
        "value": "93ea6a1b981047dfdd8d9bcd8713b04b95de9545"
      },
      "transformation": "None; exact committed source inspected.",
      "requiredCredit": "Project-authored design; preserve repository attribution.",
      "redistributionStatus": "redistributable",
      "evidenceLayers": [
        "evidence:E0"
      ]
    },
    {
      "id": "artifact:backlog-external-control-closure",
      "kind": "source-file",
      "classification": "independently-authored-metadata",
      "owner": "Chriz BG Script Engine integration owner",
      "component": "Chriz BG Script Engine research backlog",
      "version": "2026-08-27",
      "revision": "82caec04325018a32b593a42880c300eee64aec9",
      "sourcePath": "git:82caec04325018a32b593a42880c300eee64aec9:archive/2026-10-process/docs/research/research-backlog.md",
      "acquisitionDate": "2026-08-31",
      "digest": {
        "algorithm": "git-blob-sha1",
        "value": "2f4785ebe0955d8d036585207088ed158437b0d1"
      },
      "transformation": "None; exact committed source inspected.",
      "requiredCredit": "Project-authored backlog; preserve repository attribution.",
      "redistributionStatus": "redistributable",
      "evidenceLayers": [
        "evidence:E0"
      ]
    }
  ],
  "evidenceLayers": [
    "evidence:E0",
    "evidence:E2"
  ],
  "claims": [
    {
      "id": "claim:worldflow-unknown-writer-yields",
      "statement": "An unknown public-state value or writer, or later writer drift outside the declared WorldFlow compatibility closure, requires reconciliation or legacy yield and must never be silently normalized.",
      "evidenceRefs": [
        "artifact:architecture-worldflow-public-state-contract",
        "artifact:backlog-external-control-closure"
      ],
      "limitations": [
        "This is an E0 compatibility contract with E2 trace validation, not proof that a future scanner finds every writer."
      ]
    }
  ],
  "residualUncertainty": [
    "The complete public-variable reverse-reference closure for a pilot flow remains unproved.",
    "Harmless drift cannot reactivate a claim until later IR and counterexample evidence establishes a conservative slice."
  ],
  "nextDecision": {
    "decision": "Keep WorldFlow claims stale after unknown writer drift until a refreshed dependency and public-state scan proves the declared closure.",
    "owner": "BCS-03 and WorldFlow compatibility integration owner",
    "condition": "Typed-IR reader/writer inventory plus required E2, E3, and E4 validation for the selected pilot.",
    "fallback": "legacy-yield"
  }
}
```

Trace result: two exact repository blobs converge on the same compatibility boundary. Because the
real stack has not been scanned, this record does not claim that all readers or writers are known.
An unknown public value or writer, including later writer drift, therefore leaves the adapter stale
and returns ownership to legacy BCS/DLG.

## Pinned SCS v35.21 reuse statement

The upstream evidence is SCS `v35.21`, commit
`5dc240e9ff85d3909b6436e54b56297d3b61e33b`, file
[`stratagems/doc/readme-stratagems.html`](https://github.com/Gibberlings3/SwordCoastStratagems/blob/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/doc/readme-stratagems.html#L1988-L1995).
The file identifies David Wallace as copyright holder. Its reuse statement says, in substance, that
code may be borrowed or reused when DavidW receives full credit and that the mod or a modified
version should not be mirrored.

The exact 345,027-byte file was acquired read-only from the revision-pinned raw URL and hashed in
memory on 2026-08-31:

```powershell
$uri = 'https://raw.githubusercontent.com/Gibberlings3/SwordCoastStratagems/5dc240e9ff85d3909b6436e54b56297d3b61e33b/stratagems/doc/readme-stratagems.html'
$client = [Net.WebClient]::new()
try {
    $bytes = $client.DownloadData($uri)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    $bytes.Length
}
finally {
    $client.Dispose()
}
```

Observed output:

```text
1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA
345027
```

The source text and identity are E1. This project's conservative interpretation is E0 policy: all
candidate SCS-derived material remains `reference-only` and shipping-blocked until LIC-01 reaches an
artifact-class conclusion. That interpretation is not legal advice and does not authorize copying,
adaptation, packaging, publication, or redistribution.

## Validation and residual uncertainty

Run from the repository root:

```powershell
python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q
git diff --check
```

TDD evidence captured on 2026-08-31:

| Phase | Command/result | What it established |
|---|---|---|
| Required RED | `python -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q` exited 1: `4 failed in 0.25s` | Every failure named the absent `archive/2026-10-process/schemas/research-evidence.schema.json`; no schema or checkpoint document existed yet |
| First implementation check | Same command exited 1: `1 failed, 3 passed in 0.18s` | The substantive records validated, but the required non-conformance disclaimer was split across a Markdown line break; the prose was made mechanically discoverable |
| Regex portability RED | Same command exited 1: `1 failed, 4 passed in 0.19s` | A focused review proved that schema regexes depended on the local full-match helper instead of standard search-based JSON Schema pattern semantics |
| GREEN | Same command exited 0: `5 passed in 0.03s` | Required fields, records, references, fail-closed conclusions, SCS pin, validator scope, and anchored patterns passed |
| Semantic-review RED | `python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q` exited 1: `1 failed, 5 passed in 0.21s` | Adversarial review showed the required cross-field validator was absent; duplicate IDs, mismatched digest algorithms, and impossible environment/layer combinations needed explicit rejection |
| Reviewed GREEN | Same command exited 0: `6 passed in 0.03s` | Exactly two records, scoped ID uniqueness, digest binding, artifact-layer inclusion, environment consistency, and unambiguous references passed |

The focused test parses both records, applies the explicitly documented project subset and semantic
cross-field checks, rejects omission of each required PREP-02 field, checks local claim-reference
integrity, preserves both fail-closed outcomes, and pins the SCS version/revision/digest. Full JSON
Schema conformance remains unexecuted because no standards-compliant validator is selected at this
checkpoint.

PREP-02 released Task 2's PREP-03 work after independent review. It did not finish Task 4 at that
checkpoint. Publication scanning, E3 installer proof, E4 runtime proof, E5 soak, and unresolved reuse
conclusions remain later work even after the host-only follow-up below.

## 2026-09-22 follow-up — Task 4 fixture governance

The [artifact policy](../provenance/artifact-policy.md), [upstream register](../provenance/upstream-register.md),
and [fixture allowlist](../provenance/fixture-allowlist.md) now define the remaining classifications,
owners, locations, review procedure, and default holds. One original abstract JSON fixture and
temporary negative cases exercise the exact-byte E2 admission contract. The evidence and review
trail is in [the Task 4 memo](2026-09-22-task4-fixture-governance.md).

The pinned SCS readme was re-fetched read-only in memory with the same size and SHA-256. Its
copyright section is at lines 1988–1995; the former link targeted unrelated encounter text and was
corrected. Neither the pin nor the new fixture checker approves SCS-derived payloads or establishes
runtime behavior. The historical trace records, their limitations, and their exact blobs remain
unchanged. Task completion is recorded only after review in the canonical task-state JSON.
