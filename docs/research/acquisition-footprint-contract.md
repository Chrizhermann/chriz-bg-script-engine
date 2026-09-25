# Task 3, packet A1: read-only output footprint

**Status:** A1 verified: independently reviewed, 721 full-suite host tests passed. This is not
operation admission, a copier, a manifest format, or complete packet A.

**Date / owner:** 2026-09-26 / integration lead.

**Question:** Can we hold and recheck the path boundaries for every proposed copy/evidence
creation, before implementing the process/capacity/authorization portions of admission?

## Frozen interface

`scripts/lib/AcquisitionFootprint.cs` uses the existing no-follow native path routines
from `SourceMeasurement.cs`. It does not change the measurement or creation helpers.

- `PlannedEntry(string relative, bool isDirectory)` is an immutable scalar input.
- `AcquisitionFootprint(sourceRoot, copyRoot, evidenceRoot, string[] protectedRoots,
  PlannedEntry[] copyEntries, PlannedEntry[] evidenceEntries)` is a sealed disposable
  read-only path observation. The three roots are explicit local ordinary NTFS paths.
- `Creations` returns a defensive array of immutable `FootprintEntry` records with `Path`,
  `Tree` (`copy` or `evidence`), `Relative`, `IsDirectory`, and `IsRootChain` properties.
  Root-chain records include every missing intermediate directory and the output root;
  their `Relative` is null. Other records use the supplied canonical relative name.
- `Revalidate()` repeats root/ancestor checks without creating anything. A failed recheck
  poisons the instance; further rechecks refuse. `Dispose()` closes retained handles only,
  is idempotent, and prevents further observation through that instance.

These are private in-memory records, not public stdout or a wire format. Constructors and
rechecks return no authorization token, `safe` status, creation API or runtime readiness.
The future operation must consume the exact frozen footprint; passing this library cannot
authorize a generic copy, omitted outputs or mutation through `FreshTree` alone.
`Revalidate()` applies only before the first write. Once evidence bootstrap or copying starts,
planned paths legitimately appear; reusing this observation would refuse. A later operation
must explicitly transfer/track validated creation ownership, not treat this object as an
ongoing write-admission lease.

## Input and path rules

1. Null collections/entries, an empty protected set or more than 64 protected roots refuse.
   Source must occur explicitly exactly once in the protected set. Case-insensitive duplicate
   roots refuse; legitimate nested protected roots are allowed. Every protected root must
   currently exist as an ordinary directory. Missing/unreadable/reparse protection data is
   not silently dropped, followed or interpreted as empty. This deliberately does not yet
   admit the previously observed cloud/reparse Documents location.
2. Copy/evidence paths must each be fresh and must not equal, contain, or be contained by any
   protected root or each other (case-insensitive component comparisons, not string-prefix
   comparisons). Check every missing root-chain path too, not only the final output roots.
   Shared **existing** ancestors are allowed. Shared **missing** ancestors
   refuse, rather than having two independent creators claim the same new directory.
3. Hold no-follow validated chains for all roots. Reuse native fixed-NTFS, canonical-path,
   reparse, type and physical-identity checks. Compare each protected root's identity with
   each output's existing ancestor identities. Shared existing ancestors above a protected
   root are not themselves protected roots. No recursive protected/source traversal occurs.
4. Each relative name is nonempty, uses `/`, and has no absolute/traversal/backslash/empty,
   reserved-device, ADS, trailing-dot/space or other illegal component. No normalization or
   case folding rewrites names. Reject case-insensitive collisions across files/directories;
   require explicit directory parents with exactly matching spelling, irrespective of input
   order. Output roots are implicit; `.` is not a supplied entry. Empty directory entries
   remain in the plan. Root-only empty trees are representable, not operationally admitted.
5. Reject the exact case-insensitive `.bgse-disposable-lab.json` component throughout each
   proposed output path, including root/missing-parent and nested relative components. Do
   not create, strip or adopt that readiness namespace. The source inventory's marker guard
   remains separate; this helper does not inventory source entries.
6. Bound each component to 255 UTF-16 code units, full paths below 32,767 code units, each
   supplied entry array to 1,000,000 records, and total relative-name input across both trees
   to 64,000,000 UTF-16 code units. Reject invalid UTF-16. These are implementation refusal
   bounds, not a claim about maximum supported NTFS corpus size or a memory benchmark.
7. Snapshot inputs before native access; records have no mutable fields/arrays. Sort output
   by tree (`copy`, then `evidence`), with all root-chain entries shallowest to deepest,
   followed by non-root entries using `StringComparer.Ordinal` on the relative name.
   Include only missing parents, never claim ownership of shared existing ancestors.
8. Revalidate the same protected chains and missing-output chains, not just final leaves;
   changed identity, appeared missing ancestor/root or new alias/reparse refuses. A refusal
   releases temporary handles; the caller must dispose the original observation. Failure
   during construction releases all retained handles. Errors expose codes, never raw paths.

## TDD and evidence plan

Start with a missing-helper RED test, then cover synthetic ordinary trees, all protected
roots and overlap directions, evidence collisions/escapes, complete missing-parent output,
Unicode/empty directories, parent/case/type collisions, marker paths, immutable arrays,
input bounds, short-name/reparse aliases, appeared missing ancestors, held identity and
handle release on failure/disposal. Snapshots before/after establish no content/topology
writes in the fixtures; they are not proof of unchanged access times or OS bookkeeping.

The lead owns implementation/native integration. A Sol 6 worker may add independent tests
after the interface is frozen; the lead reproduces and resolves any counterexample.
Independent review, focused regressions and the full host suite precede acceptance.

**Still open:** complete operation identity/authorization binding, trusted process and
coordination providers, per-volume capacity and refresh, source-derived complete inventory,
fixed evidence-file layout, operational `-WhatIf` including no child process, exclusive
creation using this exact plan, manifest/transfer/publication packets B-E. No copied game,
profile choice, writable-root admission, launch/save/reset proof or G0-G8 advancement.

**Sources / grade:** existing helpers at `66a2282`, reviewed
[offline acquisition acceptance contract](offline-acquisition-acceptance.md), and
[verified measurement checkpoint](private-measurement-diagnostics.md#verified-successful-measurement-after-radar-closure)
at `e306943`; E1 static context. The following executed host results are E2 only.

## Executed host evidence and review

Environment: Windows x64 local NTFS synthetic temporary directories, PowerShell 7.6.6,
Python 3.11.9. No installed game, save or runtime path was read or written for A1.
The earlier complete source measurement remains a separate E1 observation, not an input
manifest or A1 operational invocation.

TDD began with the primary success/complete-footprint test before the helper existed.
An initial test-script typo was corrected first; it is not counted as product RED evidence.
The corrected harness then failed because `AcquisitionFootprint.cs` did not exist (one
failure in 1.04 seconds). After implementation that test passed in 1.65 seconds. The
initial 58 primary cases passed in 68.04 seconds. Eleven added bound/immutability cases
passed in 15.56 seconds; two appeared-root/poisoned-getter cases passed in 3.04 seconds.

The independently authored Sol 6 fault file initially had 11 passes and two harness
failures in 16.29 seconds. Its deliberate directory create/delete interleave changed the
fixture root's modification time. The actual changed-ancestor and poisoned-state checks
passed. The worker corrected only that root timestamp comparison, retaining all child
topology/metadata/byte comparisons and exact refusal-code assertions. The lead reviewed
the correction. The worker's corrected 13 cases passed in 15.64 seconds, with no skips.
No production guard was weakened and this was not a native implementation failure.

The combined-name-budget and physical-ID intersection cases invoke the **real private
guard methods** with bounded synthetic values; they are not whole-command high-memory or
physical-alias experiments. Actual junction and available 8.3 alias cases exercise native
path observation separately. No exhaustive open-handle or child-process telemetry claim is
made. This library has no process-launch/write API; the future operation's complete
`-WhatIf` proof still belongs to packet A, not to these fixture snapshots.

The independent lead-model reviewer requested explicit pre-first-write revalidation,
root-chain protected checks and deterministic ordering before freezing the interface.
All three were incorporated. The subsequent static implementation review found no blocking
findings and requested the additional null/UTF-16/bounds/getter fault coverage recorded
above. The reviewer ran no tests and inspected no game/process state.

A second independent review found five coverage ambiguities, not product defects: an
allowed physical-ID comparison could be masked by the later expected refusal; the path
length fixture also broke component rules; null/duplicate inputs masked count limits;
another output masked protected-parent containment; and two fault snapshots omitted too
much root metadata. The lead isolated those branches and narrowed exclusions to only
the reproduced root `mtime_ns` difference. **27 corrected cases passed in 33.82 seconds**
(57 deselected). The reviewer inspected and accepted all corrections before full dispatch.

Reproduce the focused suite with Python 3.11:

```text
python -X utf8 -m pytest -q tests/tooling/test_acquisition_footprint.py tests/tooling/test_acquisition_footprint_faults.py
```

Both G0 validators and their LF/CRLF regression passed unchanged. This does not reevaluate
or advance any gate. Full-suite job `c35c18ef-4ee0-47f6-9fbf-c7d7ce0c26bc` completed
**successfully, exit 0: 721 passed in 345.96 seconds**, empty stderr, no warnings or timeout.
It ran once via the completion runner, `python -X utf8 -m pytest -q`, timeout 1,800 seconds,
in the ignored `work/acquisition-footprint-tests-v1` result directory under the Task 3
private work area. Status times were 21:31:35.559669 to 21:37:22.265018 UTC on 25 September
(26 September locally), 346.705349 seconds wall time. Its single completion notification
was accepted. Eight private files totaling 2,113 bytes are retained, not polled or rerun.
The authored helper SHA-256 at dispatch is
`DD616912E4C6201ED038738C336E7EE7194842FF7F4CE3B7DD052D7ACAA2BB15`;
both test hashes and executable/runner identities are retained in the private checkpoint.
The lead rechecked all seven saved code/test/dependency/tool hashes after completion.
An independent Sol 6 saved-result audit matched the exact command, outcome, 637 previous
plus 84 new tests (71 primary, 13 fault), and all three new code/test hashes. No discrepancy
was found. JSON parsing, relative documentation links, added-content privacy checks and
`git diff --check` passed. Next: the remaining process/coordination, capacity and complete
operation-admission checks in packet A; do not jump to source copying or packet B.
New test evidence is E2 only; no E3/E4/E5, copy, runtime readiness or Task 3 completion.
