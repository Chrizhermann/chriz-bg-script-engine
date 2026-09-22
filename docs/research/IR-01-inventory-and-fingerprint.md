# Task 5 — Synthetic inventory and exact-claim prototype

**Status:** Task 5 complete — independently reviewed synthetic-only prototype

**Date:** 2026-09-22

**Owners:** Integration owner

**Applicable evidence:** evidence:E2 deterministic host model. The proposed future relationship to
effective game resources remains evidence:E0. No E1 decompilation, E3 installer, E4 engine, or E5
corpus result was produced here.

## Question and outcome

Can a compact invented corpus retain script-slot assignments, dependency edges, public-variable
declarations, and uncertainty while producing reproducible exact-byte manifests and refusing stale
or ambiguous claims?

This implements canonical Task 5, not the full IR-01 decompilation/fidelity research spike. The
prototype operates only on caller-supplied in-memory `SyntheticResource` values. It has no file
reader, game-directory option, installer, decompiler, bridge, or runtime action. Both schemas
require `runtimeActivation: false`; an eligible result means only **eligible for synthetic host
analysis**. It cannot grant engine ownership. IR-01, IR-02, TEST-03 and the relevant compatibility
cases remain open for their own evidence requirements.

## Environment, provenance, and artifacts

- Host: Windows x64 / NT `10.0.26200.0`; CPython `3.11.9`, pytest `8.4.2`, PowerShell Core
  `7.6.6`, Git `2.55.0.windows.5`.
- Baseline: `341962f` (Task 4 fixture/provenance governance). The commit containing this memo binds
  the implementation, schemas, tests, and task-state update. Resolve its exact identity with
  `git log -1 --format=%H -- docs/research/IR-01-inventory-and-fingerprint.md`.
- Implementation: `tools/corpus/inventory.py`, `tools/corpus/exact_hash.py`.
- Provisional host-only schemas: `schemas/install-manifest.schema.json`,
  `schemas/resource-claim.schema.json`. These are not the Task 38 SDK or a production activation
  envelope. They must not be consumed as a supported runtime profile.
- Tests contain independently authored inline bytes and create no committed resource payloads.
  They are original project test source/metadata, owned by the project contributors. No SCS/game
  source, generated script, binary, TLK, save, or personal log was obtained or committed.
- No game installation, save tree, disposable lab, or running game was accessed. Task 3 remains
  pending; no publication or upstream contact occurred.

## Provisional input contract

`SyntheticResource(resource_id, payload, source_path='')` carries immutable bytes and a typed ID.
`source_path` is ignored: it is never opened, included in output, or interpolated into diagnostics.
Input names are canonicalized to uppercase ASCII; duplicate case-insensitive typed identities are
an error. This is an inventory of already selected synthetic resources, **not** a KEY/BIFF/override
precedence resolver. Type-aware source identity is separate from G0's cross-extension uniqueness
rule for newly allocated project resource names.

The only understood payload is `BGSE-SYNTHETIC-RESOURCE-V1` followed by LF and a UTF-8 JSON object
with exactly one field, `nodes`, containing an ordered list. Maximum payload size is 1 MiB. This
marker is host-only and is not an engine resource format. The deliberately small node vocabulary is:

| Kind | Exact fields after `kind` | Interpretation in this toy model |
|---|---|---|
| `script-slot` | `slot`, `target` | A declared slot target is a typed BCS identity; explicit `null` means known empty |
| `dependency` | `target` | A declared dependency edge to a typed resource identity |
| `public-variable` | `scope`, `name`, `access` | `GLOBAL` only; `read` or `write`; retain the declared spelling and source position |

Slots are `override`, `class`, `race`, `general`, `default`, or `area`. These labels do not prove
native CRE/ARE layout or dispatch semantics. A missing slot declaration is not a known empty slot;
a malformed or duplicate declaration becomes opaque. Locals/area variables need a stable owner
model and are deliberately opaque here, never incorrectly collapsed into global identity.

Unknown fields, node kinds, scopes, and invalid references are not silently ignored: they leave
opaque position/reason records. Unsupported formats or malformed envelopes get a resource-level
opaque record at position -1. Full payload hashes remain available, but raw opaque content is not
exported. This is a digest/position inventory, not a lossless or round-trippable IR. Future IR work
must preserve unsupported bytes externally without interpreting them or leaking local evidence.

## Hash and claim algorithm

1. SHA-256 every complete raw resource payload, without whitespace, case, line-ending, or semantic
   normalization. Declarations come from those same bytes, never from an unhashed sidecar.
2. Sort resource identities for canonical output. Preserve node order through source positions and
   ordered per-kind lists. Canonical JSON uses sorted keys, compact separators, ASCII escaping, and
   a final LF; it canonicalizes host metadata, not game-script meaning.
3. Compute `inventoryDigest` over the entire canonical manifest before adding that digest field.
   This binds the synthetic `stackId`, all resource hashes, and all parsed/opaque metadata.
4. `make_claim` requires an explicit nonempty root set and a G0-compliant first-party adapter ID
   whose combat/worldflow segment agrees with the domain. It traverses declared dependencies and
   slot edges, plus every declared reader/writer of each referenced GLOBAL (case-insensitive
   variable identity). Cycles terminate without dropping their edges or resources.
5. Missing resources and opaque records inside this declared closure make analysis ineligible.
   An unrelated opaque resource remains inventoried but is not claimed. This is no proof that it
   lacks an undiscovered real-world control edge.
6. `claim_matches` rebuilds from the supplied current bytes and compares the entire canonical claim,
   not a subset of hashes. Extra fields, missing hashes, changed metadata, mismatched domains, and
   stale inventory digests fail. Runtime activation remains false even for an exact match.

Whole-inventory drift invalidates an old claim even when the changed/new resource is outside its
declared local closure. This intentionally accepts harmless over-invalidation. Making a new claim
is an explicit analysis operation, not automatic reactivation or an authorization decision. Real
stack provenance, final install order, capabilities, saved resources, external-control closure,
and complete public-state scans are not represented as proved facts in this prototype.

## Reproduction

From the repository root:

```powershell
python -X utf8 -m pytest tests/tooling/test_inventory.py tests/tooling/test_exact_hash.py tests/tooling/test_inventory_properties.py tests/schemas/test_inventory_schemas.py -q
python -X utf8 -m pytest -q
python -X utf8 -m tools.provenance.fixtures
git diff --check
```

A standalone, file-free example exercises the public host functions:

```powershell
@'
import json
from dataclasses import replace
from tools.corpus.inventory import SyntheticResource, build_inventory, canonical_bytes
from tools.corpus.exact_hash import make_claim, claim_matches

def make_resource(identity, nodes):
    return SyntheticResource(identity, b'BGSE-SYNTHETIC-RESOURCE-V1\n' + json.dumps({'nodes': nodes}).encode('utf-8'))

resources = [
    make_resource('B-XROOT0.CRE', [{'kind': 'script-slot', 'slot': 'override', 'target': 'B-XDEPS0.BCS'}]),
    make_resource('B-XDEPS0.BCS', []),
]
first = build_inventory(resources)
assert canonical_bytes(first) == canonical_bytes(build_inventory(list(reversed(resources))))
claim = make_claim(resources, 'B-/combat/synthetic-probe', 'CombatIntent', ['B-XROOT0.CRE'])
changed = [resources[0], replace(resources[1], payload=resources[1].payload + b' ')]
assert claim_matches(claim, resources) and not claim_matches(claim, changed)
print('inventoryDigest:', first['inventoryDigest'])
print('boundResources:', len(claim['hashes']))
print('runtimeActivation:', claim['runtimeActivation'])
'@ | python -X utf8 -
```

Observed output:

```text
inventoryDigest: 42444bba9be3c8640698a95f8e08cb631415f11e2d77b9ebbcbdd97570743ebe
boundResources: 2
runtimeActivation: False
```

## TDD and independent review

| Phase | Command/result | Meaning |
|---|---|---|
| Tool RED | Focused inventory/hash tests: exit 1, two `ModuleNotFoundError: No module named 'tools.corpus'` collection errors in 0.39s | Tests preceded the implementation |
| Tool GREEN | Same focused tests: `36 passed in 0.09s` | Ordering, paths, declarations, opacity, closure, mutations, and exact matching passed |
| Schema RED | Focused schema tests: `63 failed, 1 passed in 0.90s` | All failures named missing schema files; only the independent helper test passed |
| Initial schema GREEN | `64 passed in 0.09s` | Frozen shape contract implemented |
| Expanded schema/integration GREEN | Combined focused suites: `142 passed in 0.22s` | Actual positive/refused prototype output shapes and trailing-line-terminator grammar cases also passed |

The four-resource tool fixture tests flip one bit at each of **452 byte positions**, one mutation
per run, across the root and its transitive/public-variable dependencies. Every old claim is
invalidated. Ten fixed shuffles produce identical canonical manifest bytes. Whitespace-only drift
is still rejected despite parsing to the same toy declarations. These are deterministic model
tests, not claims of exhaustive engine-state or SHA-256 collision testing.

The lead froze the provisional field contract before assigning non-overlapping schema/test work.
The schema worker recorded RED-before-GREEN and checked both schemas against actual tool output.
The lead read the resulting files, reran the combined tests, and executed the standalone example.
The local schema test helper supports only the declared keyword subset and rejects unsupported
keywords. It is not a standards-conformance validator; graph/digest/eligibility consistency is
tested separately in the implementation, not inferred from schema shape.

A second, independent reviewer found no blocking implementation defect and preserved its checks in
`tests/tooling/test_inventory_properties.py`: 100 fixed graph seeds, each with eight resources and
an independent integer-set fixed-point oracle, plus 91 node-field vectors (90 malformed cases and
one valid null-slot control). They also verify case-mixed GLOBAL identities, shuffled equality,
conservative whitespace-drift refusal, and path redaction. The lead read those tests and ran them
as part of the combined suite; review evidence is not left as an unreproducible conversation claim.
The schema reviewer also independently reproduced the 452 mutation positions and the standalone
example's exact digest, then checked the memo's scope. Its documentation correction (include the
property-test file in the reproduction command) was applied before completion.

Final verification:

- Independent property suite: `191 passed in 0.26s`.
- Lead's complete Task 5 focused command above: `333 passed in 0.44s`, exit 0.
- Lead's full repository suite: `457 passed in 59.20s`, exit 0.
- Fixture admission CLI: passed, still exactly one reviewed static fixture (Task 5 adds no payload
  files to `tests/fixtures`).
- Staged diff whitespace check: passed. Both G0 validators and the LF/CRLF regression passed earlier
  in the same session during Task 4; Task 5 changes neither their scripts nor the G0 charter.

The reviewed exit is bounded synthetic inventory and exact matching. Task 5 is completed in the
canonical task-state file; no engine gate or real corpus evidence is promoted by that update.

## Counterevidence, remaining work, and next decision

- Invented JSON declarations cannot prove decompiler fidelity or complete discovery of BCS/DLG,
  CRE slots, globals, shouts, forced actions, or external controllers. Nothing here closes IR-01,
  IR-02, TEST-03, COMP-I02/I05/I06/I07/I10/I11/I12, or G1–G8.
- This is not an importer/validator for arbitrary stored install manifests. Claims are recomputed
  from current supplied bytes; hashes and a caller-supplied stack label are not signed provenance,
  authentication, or evidence that a real install is finalized.
- The recognized synthetic declaration vocabulary is intentionally narrow. Rich state, dialogue
  order, weighted responses, locals, timers, and opaque-node round-tripping await later IR research.
- Whole-file and whole-inventory hashes can invalidate harmless changes. Do not weaken that rule
  until a separately reviewed loss-aware IR and counterexample suite justifies a specific family.
- No game parsing, WeiDU compilation, installer rollback, runtime ownership, save behavior,
  performance/soak result, or upstream reuse permission was tested.

After Task 5's reviewed completion, Task 6 can begin pinned-source SCS characterization. Its required
effective-generated-BCS cross-check needs a separately scoped lawful evidence source; this prototype
is not a substitute. Task 7's pure EEex capability research is also independent host work. Task 3
still requires explicit user authorization naming the disposable destination, and all engine gates
remain stop points.
