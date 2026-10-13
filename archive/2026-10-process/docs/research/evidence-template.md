# Research evidence templates

Use these templates for every material research result and every artifact used to support it. Keep
stable IDs after publication; supersede a record instead of assigning its ID to different bytes or
a different claim. Do not include personal paths, installed-game files, saves, credentials, or
copyrighted content in a committed record.

The machine-readable contract is `archive/2026-10-process/schemas/research-evidence.schema.json`. The focused stdlib
validator covers the keywords required by this project; it is **not a full JSON Schema conformance implementation**.
A future pinned standards-compliant validator may add conformance evidence
without replacing the required project checks.

The project check also enforces semantics not represented by the selected keyword subset: record,
artifact, and claim IDs are unique in their scope; each digest length matches its named algorithm;
artifact evidence layers occur in the enclosing record; and the evidence layer plus game-state
access are possible in the declared environment. Passing the JSON Schema alone is therefore not a
complete project validation.

## Research-result header

```markdown
# <research ID>: <title>

**Outcome:** Proven | Conditional | Rejected | Unknown

**Question:** <one falsifiable question>

**Environment:** <env:host | env:synthetic | env:disposable | env:soak; include game-state access>

**Versions and fingerprints:** <component, version, revision, digest, source>

**Method:** <reproducible steps and exact commands>

**Observations:** <what was actually observed>

**Counterevidence:** <conflicting result, negative search, or explicit “none found” with scope>

**Artifacts:** <artifact IDs from manifests below>

**Applicable evidence:** <every evidence:E0 through evidence:E5 layer actually reached>

**Residual uncertainty:** <what this result does not prove>

**Next decision:** <decision, owner, entry condition, and fail-closed fallback>
```

Research records also include one or more claims. Each claim names the artifact IDs that support it
and states its limitations. Queue acceptance, parser acceptance, source documentation, or a host
simulation must never be described as an engine-runtime postcondition.

## Artifact manifest

Embed manifests in the enclosing research record's `artifacts` array:

```jsonc
{
  "id": "artifact:<stable-slug>",
  "kind": "source-file | installed-resource | decompile | trace | fixture | research-result | transformation",
  "classification": "<PREP-02 classification>",
  "owner": "<author or owning project/component>",
  "component": "<component name>",
  "version": "<exact version or explicit not-applicable reason>",
  "revision": "<commit, build, or immutable identity>",
  "sourcePath": "<revision-pinned URL or repository-relative immutable reference>",
  "acquisitionDate": "YYYY-MM-DD",
  "digest": {
    "algorithm": "git-blob-sha1 | sha256",
    "value": "<hex digest>"
  },
  "transformation": "<none, or exact derivation steps>",
  "requiredCredit": "<credit requirement or project-authored statement>",
  "redistributionStatus": "redistributable | conditional | reference-only | local-only | forbidden | unreviewed",
  "evidenceLayers": ["evidence:E0"]
}
```

PREP-02 recognizes these intake classifications:

- `independently-authored-metadata`
- `short-factual-extract`
- `generated-fingerprint`
- `locally-generated-effective-artifact`
- `redistributable-synthetic-fixture`
- `upstream-source`
- `forbidden-packaged-content`

Classification is not permission. Until the later artifact-policy, upstream-register, and fixture-
allowlist work is complete, ambiguous upstream or derived material remains `reference-only` or
`local-only`; forbidden packaged content remains `forbidden`.

## Focused validation

From the repository root:

```powershell
python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q
```

The check parses the schema and the two PREP-02 sample records, validates the project-required
keyword subset and cross-field semantics, rejects every required-field omission, resolves
unambiguous claim-to-artifact references, and checks the pinned SCS source identity. It does not
prove engine behavior, legal permission, installer behavior, packaging safety, or full JSON Schema
conformance.
