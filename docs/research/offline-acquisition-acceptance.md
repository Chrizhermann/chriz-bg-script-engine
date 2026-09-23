# Task 3: offline acquisition acceptance packet

**Status:** Independently reviewed implementation contract; implementation and real-copy admission
unexecuted.

**Date / owner:** 2026-09-24 / integration lead.

**Question:** What must the operation joining the tested measurement and fresh-creation helpers
prove before acquiring an unchanged offline SCS reference at the already approved destination?

**Environment and identities:** Repository-only inspection at `c6b296e`; authored host mechanics
at `7959996`. Latest unchanged-code regression: 613 synthetic tests passed in 227.66 seconds,
job `fcaffe01-d198-476e-8a3f-a5d7122380d0`. No source/destination access was used for this packet.

## Scope and evidence boundary

This packet refines the existing [approved offline scope](disposable-lab-provisioning.md) and
[runbook](disposable-lab-runbook.md); it does not choose a new installation recipe, runtime profile,
gameplay policy, source, destination or save location. The user permits overnight implementation
within the plan but retains creative/gameplay decisions. Engine launch, installer/native game
execution, source/save mutation and interference with another task remain outside this packet.

The operation must copy ordinary file bytes and directory topology, including empty directories,
without transforming installed content or executing copied programs. It is **not** an NTFS backup:
security descriptors, ownership, alternate streams, extended attributes, timestamp preservation,
compression layout and forensic metadata fidelity are not promised. Existing unsupported-entry
refusals remain intact; unsupported metadata must not be silently advertised as preserved.

Copied `engine.lua` and loader configuration still refer to the original profile. An offline copy
is not launch-isolated. Never create, copy, strip or adopt `.bgse-disposable-lab.json`; its exact
case-insensitive basename is refused at every depth/type, including at actual copying and final
verification. No automatic launch follows success. TEST-05/06 and COMP-X01/X02 still need E4;
this packet contributes no runtime evidence or gate pass. LIC-03 publication restrictions remain.

## Existing proof versus remaining work

| Existing bounded primitive | Repository evidence | Still required at operation level |
|---|---|---|
| Canonical ordinary paths, no-follow native identities, source/destination separation | `SourceMeasurement.cs`; measurement/fault tests | Admit every protected root and every output, not only the game leaf |
| Two complete source observations, file hashes, stream/type/identity checks | `Inventory`, `VerifyObservations`; measurement/fault/marker tests | Bind the actual copy reads to the admitted manifest and compare final source/copy inventories |
| Exclusive native creation, retained directory handles, defensive missing-parent plan | `FreshTree.cs`; `test_fresh_tree.py` and fault tests | Complete write-footprint approval, evidence roots, streaming copy, final publication |
| Same-created-handle write/flush/readback of synthetic bytes | `test_creates_independent_files_and_empty_directories_and_retains_on_dispose` | Source-to-copy length/hash and physical-independence checks for every file |
| Failed creation poisons the instance and leaves partial output | Creation fault tests | Whole-operation cancellation/timeout/failure state and cleanup ledger |
| Measurement `-WhatIf` changes no synthetic tree | `test_measurement_is_read_only_and_not_write_or_runtime_admission` | Equivalent no-write branch in the new acquisition operation |

Process and writable-root admission are explicitly `unexecuted` in measurement results. A matching
measurement is an observation, not a reusable authorization token. Neither helper is a copier.

## Admission inputs and complete write footprint

Before any write, the operation must have all of the following, supplied explicitly rather than
discovered by scanning conventional game locations:

1. The exact approved source and destination, local authorization reference, operation ID and
   pinned authored tool identities. Reject existing destination/partial output rather than adopt it.
2. A private evidence destination outside source/copy/protected game and save roots. It must be
   fresh for this operation, with no overwrite or append to an existing operation's records.
3. The protected-root set: source plus the explicitly known active game/save/configuration roots.
   Offline copying never writes user-profile state and does not claim it has isolated that state.
   Unknown or unreadable protection/admission information is not an empty set or permission.
4. The full planned creation set: every missing intermediate directory, copy root, relative source
   directory/file, evidence root/parent, and each intent/manifest/receipt/temporary output. Existing
   shared ancestors may be read/held, but are not owned recursive-write or cleanup targets.
5. Explicit capacity allowances and reserve, refreshed immediately before first write. Budget the
   independent working copy and future independent baseline, all new ancestors and private
   metadata/output. If outputs span volumes, cost each volume separately. The measurement's
   per-entry margin is a planning allowance, not a proven filesystem upper bound; unknown layout,
   arithmetic overflow or insufficient space refuses. No compression/hard-link savings assumed.
6. Fresh coordination plus a tested, bounded process observation. Candidate game/loader/install/
   editor/helper activity involving either tree must be absent. Enumeration failure, unavailable
   identity or uncertain relevant helper ownership refuses; generic process names alone cannot
   clear or authorize termination. Record coverage and residual blind spots rather than claiming
   an exhaustive open-handle inventory. The provider/classifier contract needs its own RED/GREEN
   packet and independent review; a hand-written empty snapshot is not that implementation.

Validate canonical spelling, containment in the explicit write plan, no reparse/alias/hard links,
and cross-root physical identities for copy and evidence outputs. Reject output equality,
ancestor/descendant overlap or physical alias with any protected root. Reject copy/evidence overlap.
Recheck appeared missing ancestors before exclusive creation. In-memory or caller-mutated plans
must not change the admitted write set. A failure before first write leaves all trees unchanged.

No automatic recursive cleanup is part of admission or acquisition. The narrowly approved runner
timeout may stop only processes it created for the scan, not a game or another task. Any future
copy timeout/cancellation mechanism must similarly preserve partial output and must not infer
authority to terminate unrelated processes or execute copied programs.

## Operation sequence and refusal semantics

1. **Plan without writes.** Admit inputs, roots, coordination/process facts, source inventory and
   capacity. `-WhatIf` runs this admission branch but creates no evidence directory, lock, intent,
   log, copy, marker, baseline or child process. Emit a bounded sanitized result to stdout only;
   caller-side capture, if desired, is separately scoped outside this no-write assertion.
2. **Start once.** Immediately repeat mutation-sensitive checks. Exclusively create the admitted
   private evidence path and persist/read back the operation intent before creating game-copy
   output. Retain validated native identities for successfully claimed ancestors. Do not promise
   that all creations can be journaled: evidence-bootstrap failure, disk exhaustion, abrupt process
   loss or failure validating a newly created handle can precede durable ownership evidence.
   Classify these as **creation/evidence outcome unknown**, not "nothing created". The existing
   `FreshTree.CreatedHandle` can close/reject a handle before its entry reaches the retained list;
   a missing list entry therefore does not prove absence. Preserve the admitted plan outside the
   acquisition output in the task's prior approval record. An appeared path alone never proves
   ownership, safe adoption or deletion authority; later reconciliation is read-only and must
   distinguish validated ownership from an unresolved candidate path.
3. **Capture the private source manifest.** Bind exact source identity and canonical relative
   names, entry kinds, lengths, byte hashes and native identity/stability fields. Use a specified
   deterministic encoding/digest, bounded parser and strict version/type/duplicate handling.
   Keep exact paths and detailed inventories out of Git/public stdout. Hash equality alone is
   not origin, ownership or permission proof. Freeze this wire contract before parallel coding.
4. **Create and copy.** Use the reviewed exclusive-creation primitive, never a generic recursive
   copy/adopt/overwrite fallback. Revalidate actual source name, type, identity, streams, length
   and admitted fingerprint before each destination write. Read through the same validated source
   handle; write through the same exclusively created destination handle. Stream with bounded
   buffers, verify expected byte count, flush, rewind/read back and hash; prove distinct physical
   identities. Recheck source metadata/identity/streams before closing. Refuse unexpected or late
   names/markers rather than skip them. Do not keep one open file handle per corpus file indefinitely.
5. **Verify whole trees.** After copying, compare complete source and copy inventories against the
   admitted source manifest: no missing/extra entries, same topology and file bytes, no shared
   physical file identities, unsupported entries, foreign readiness marker or changed ancestors.
   Repeat coordination/process and root checks. Per-file success alone cannot publish completion.
6. **Finalize evidence, then commit.** Flush/read back the source/copy manifests and the mandatory
   ownership/cleanup ledger before publication. The ledger lists validated owned paths, known
   partials, unresolved candidates, sizes/state and the planned receipt path; it does not invent
   completion before the receipt exists. All mandatory ledger writes stay under held/revalidated
   evidence-output ownership. Then publish a distinct
   private offline receipt binding operation ID, exact roots/root identities, tool identities,
   both manifest digests and verification outcome. `runtimeReady` remains false. The receipt
   lives outside the copy, not in the readiness-marker namespace. Its writer and consumer must
   agree on strict completeness validation: a truncated/partial/malformed receipt, mismatched
   digest or wrong operation/root never counts as success. Define the writer's commit point as
   completion of receipt write, flush and same-handle readback validation, after every mandatory
   prerequisite above passed. Consumers independently validate the complete receipt and all bound
   evidence; they cannot infer the writer's execution phase from file existence. Publication crash
   windows need tests; do not claim atomic or power-loss durability from a successful write alone.
7. **Report and release.** After the commit point, perform no required filesystem writes. Report
   only verified aggregate evidence, release owned handles and stop at the next plan barrier.
   A reporting/handle-release failure after commit is a post-commit error, not a pre-commit copy
   failure: preserve the receipt and known outcome, do not roll back or recopy. A user-facing task
   summary may be refreshed later from verified evidence without being a completion prerequisite.
   The receipt is point-in-time evidence, not lasting copy or
   runtime admission. Future use revalidates it and the corresponding content/identities.

Before publication, any refusal/exception/cancellation stops copying and must not publish a valid
completion receipt. Preserve written output and record the phase/ownership evidence when safely
possible; do not promise a durable failure log when its own storage has failed. During or after
publication, lost acknowledgement means **outcome unknown** until read-only reconciliation of all
bound evidence; a nonzero exit alone cannot distinguish incomplete acquisition from committed
output with reporting failure. Reconciliation requiring source access needs a fresh quiet window.
Known post-commit errors retain the committed-offline result with the reporting error separately.

Never retry under a renamed job, weaken sharing, skip entries, repair source metadata or stop
another task. A partial or unresolved candidate destination is unavailable for adoption and must
be recorded for review when evidence storage is available again. Reconciliation does not authorize
mutation or deletion of an appeared but unowned path. No cleanup is automatic.

## TDD packets and review order

Each packet starts with genuine failing synthetic tests, records the expected failure, implements
only its contract, then runs focused and full host checks plus independent review. Keep native
identity/ownership integration with the lead; Sol 6 workers may own bounded fixture/coverage work
after their input/output schema is frozen. Review worker counterevidence, not only pass counts.

| Packet | Required cases before the next packet |
|---|---|
| A: operation admission / `-WhatIf` | Protected-root/output overlap in both directions; alias and changed ancestor; every missing parent in footprint; evidence-root collision/escape; unknown process data; held writer; insufficient/unknown capacity; unchanged trees and no child process on dry run |
| B: manifest contract | Stable ordering/encoding; case-colliding names; malformed or duplicate fields/entries; unsafe relative names; wrong version/types/root/tool/operation; exact fingerprint mismatch; bounds; no raw paths in public output |
| C: same-handle transfer | Empty/large/Unicode files and empty directories; exact byte/readback hash; independent identities; short read/write/error; appeared marker; swapped/changed source; existing destination entry; stream/link/reparse refusal; source unchanged |
| D: whole-operation publication | Extra/missing/changed final entry; late writer/process conflict; capacity loss; creation succeeds but post-create validation fails; evidence bootstrap fails before intent; failure at each manifest/copy/flush/ledger boundary; cancellation immediately before and after commitment; no receipt before prerequisites; post-commit reporting failure preserves completion; lost-result/unknown-ownership reconciliation; partial retention; second invocation refuses adoption |
| E: operational review | Zero unintended source/protected-root writes; full synthetic regression; bounded memory/handles; exact invocation and tool identities; cleanup ledger; independent acceptance review before one authorized real acquisition |

Fault injection must exercise the real operation branches and distinguish private guard-method
tests from whole-command filesystem/process behavior. Do not delete an assertion because the
first native experiment contradicts the expected call shape; diagnose and record the result.

## Remaining barriers, reproduction and review

The immediate next implementation packet is **A**, not real copying. A successful quiet-window
measurement may inform it, but cannot waive it. The exact source still has no accepted complete
measurement at this checkpoint. Real acquisition waits for all packets, reviewed source evidence,
fresh coordination and exact-root authorization. Runtime profile and non-cloud writable-root
admission, launch/save and two resets remain separate Task 3 requirements afterward.

Reproduce this gap assessment by reading the linked memos and the two C# helpers, then inspecting
the named tests. A Sol 6 worker independently extracted existing coverage without running tests or
accessing game paths; the lead checked consequential call sites and the unchanged suite result.
The `bg-modding` references reinforced installed-byte provenance and game-open/install hazards;
their version-specific claims do not select a new runtime baseline here.

**Evidence:** E1 repository inspection pinned above and pre-existing E2 synthetic results only.
The acceptance sequence itself is a proposed implementation contract, not executed E2/E3/E4 proof.
**Counterevidence / residual uncertainty:** existing per-file/creation tests do not establish an
operational copy; matching serial inventories are not an atomic snapshot or permanent integrity
guarantee; process enumeration has bounded coverage; hostile privileged namespace changes and
power-loss durability are not proved. No fixture or upstream payload is added by this document.

**Review:** Independent Astra review found two blocking draft ambiguities: creation could precede
durable ownership evidence, and a post-publication reporting error contradicted the proposed
no-receipt failure rule. The lead added explicit unknown bootstrap ownership, an observable
commit/reconciliation contract, pre-commit ledger finalization and before/after-commit fault cases.
The reviewer accepted the corrected contract with no remaining blocking findings. The next
implementation still needs frozen wire/provider schemas and actual failure-injection proof;
document review is not real-copy admission or a gate pass. No Claude or game process was used.

**Verification:** Five focused existing synthetic cases passed in 6.26 seconds: the fresh-tree
complete-footprint, same-handle write/readback and partial-preservation cases, plus both forms of
the read-only measurement/no-admission case. The unchanged implementation's full 613-test result
above was verified earlier in this turn; no code/tests changed afterward. Relative Markdown
links, documentation/task JSON privacy checks and `git diff --check` passed. No new production
behavior or RED/GREEN cycle is claimed for this acceptance packet.
