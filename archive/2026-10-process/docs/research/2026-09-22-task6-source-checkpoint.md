# Task 6: reproducible SCS source-mapping checkpoint

**Status:** In progress; pinned-source checkpoint, not Task 6 completion.

**Date / owner:** 2026-09-22 / integration lead.

**Continuation:** The [shared-rule/compiler/helper checkpoint](../../../../docs/research/SCS-shared-rule-expansion.md)
addresses the next bounded source packet. The counts and verification below describe this first
checkpoint and are retained as historical evidence; neither packet completes Task 6.

## Scope and continuation

Tasks 4 and 5 are complete. This checkpoint starts canonical Task 6 with the ordinary standard-mage
generator branch and generic short/long prebuff definitions. SCS is the primary migration knowledge
source, including its wider content/encounter changes; this pilot does not reduce the goal to generic
spellcasting or discard those changes. Nothing here accesses games/saves, provisions a lab, starts
Task 3, admits production policy, or passes G1-G8. Stop at every canonical gate as planned.

The six SCS memo filenames follow Task 6's deliverable list. Their titles do not exactly match the
backlog's SCS-01 through SCS-06 questions; none of those research items is automatically closed.
The [evidence record](scs-source-pilot.evidence.json) contains 18 immutable source-file identities,
not source payloads. Two family ledgers preserve proposed dispositions and open evidence.

## Reusable worker packet and review loop

Christopher's instruction for this workstream: **no Luna**. Astra retains design, research
interpretation, ambiguous exceptions, integration and final judgment. Terra is suitable for bounded
extraction/mechanical work with a clear acceptance test. Do not silently change the lead model or
reasoning effort. This is project execution guidance, not a personal-memory update.

Each packet records: purpose; exact pin and file/range allowlist; expected output; evidence layer;
provenance restrictions; acceptance checks; unresolved questions; edit ownership; forbidden actions.
For research, expected output is artifact identity + source anchor + minimal authored fact +
uncertainty, never an unsupported generalized rule or copied payload.

This run's worker packet was read-only: inspect exactly `mage_shared.tph`,
`standard_mage.ssl` and `caster_definitions.ssl` at the recorded pin; report raw-byte SHA-256,
length, physical lines and structural anchors. No editing, installed-game inspection, upstream
execution, or external contact. Terra returned all three identities and bounded findings; the lead
independently retrieved them and matched the hashes and consequential generator/accounting ranges.
Source include count was independently counted as 47. No worker correction was needed for those
findings. Lead handled the wider source chain and synthesis.

Independent review found one missing input constraint in the lead's synthesis: the enchanter
branch can be overridden later by invisibility detection or undead race selection. The lead
rechecked lines 472-492, added two failing documentation regressions (both failed for the missing
constraints), then froze `kit=enchanter`, `detect_invisible=0`, `race=HUMAN` in the pipeline and mage
ledger. This identifies a template lane only, not a complete generated actor. Future packets must
trace later overrides through the end of the selection function, not stop at the first assignment.

Line-count convention matters: split-on-LF produces a trailing empty element for a terminal newline;
the worker reported physical lines, not that extra element. Raw-byte hashes were identical. Keep
this convention in future packets so an apparent one-line discrepancy is not misreported as drift.

Acceptance loop: record RED for new tooling/contracts, implement only the bounded scope, inspect the
diff against the original question, independently verify consequential facts, record corrections,
rerun focused and full host checks, then make a narrow commit. After one unsuccessful focused worker
correction, the lead takes over. Similar files can reuse an approved packet/schema, but exceptions
and provenance are always rechecked. Do not parallelize schema/ownership decisions before a gate.

Economics for this pilot: one three-file Terra extraction packet, approximately six worker minutes
(self-reported), no retry; separate lead synthesis and independent review. Exact token/cost totals
were not available and are not invented. No claim that broad migration economics are proven: the
second-family trial and Task 30/G6 measurements remain required.

## Verification record

- RED: `python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_scs_source_checkpoint.py -q`
  failed all 16 cases because the record/memos/ledgers did not yet exist. No implementation or
  assertions were weakened to remove those failures.
- GREEN after authored records: 16 passed in 0.07s. Review correction RED: two focused selection
  cases failed as intended; after fixing the two documents, focused suite: 18 passed in 0.06s.
- First full host run: 473 passed in 66.77s (collected before the two review regressions were added).
  Final full-suite result with both regressions: **475 passed in 63.80s**, exit 0.
- Executed the exact PowerShell source-identity recipe in SCS-01: all 18 digests matched,
  328,184 aggregate raw bytes read in memory, no source files persisted. The independent reviewer
  separately matched all 18 hashes and byte counts.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-decisions.ps1`: passed; existing G0 status remains
  Pass with narrowed scope, not a new gate decision.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-namespace.ps1`: grammar/collision vectors passed.
- `pwsh -NoProfile -File archive/2026-10-process/scripts/test-g0-line-endings.ps1`: LF and CRLF checkout checks passed.
- Independent review: accepted with source-only scope after the template-selection correction;
  independently reran all 18 focused tests. No outstanding blocking findings. Reviewer inspected
  private-path leakage and provenance/authority boundaries; no game access or upstream execution.
- Tool identities: Python 3.11.9, pytest 8.4.2, PowerShell 7.6.6. No SSL/WeiDU/Lua parse command
  executed. `git diff --check` passed; final staged diff is reviewed before commit.
- Staged scope audit: 13 documentation/test files only, 27 relative Markdown links resolved;
  `git diff --cached --check` passed. No runtime code or fixture payload added.

The new checks validate the existing research-schema subset, pinned/reference-only source identity,
resolvable claims and document fields. Negative cases reject evidence promotion, game-access
promotion, reuse promotion, changed pin, malformed digest, broken reference and duplicate artifact.
They do not fetch sources, verify factual truth, parse SSL/BCS, simulate policy or establish legal
permission. Source truth still requires pinned inspection and human/agent review.

## Open barriers and next packet

1. Continue the selected source-library/target/protection and generation-helper trace (the next
   bounded packet is now documented in the continuation above). Keep exact
   macro precedence, response expansion and input-sensitive cases explicit; do not infer them from
   names. The general-versus-prep difficulty-variable distinction is a source observation, not a
   bug diagnosis or a behavior-change decision.
2. Compare against provenance-complete **effective** scripts under a reviewed evidence-access
   scope; record actual actor/slot/control closure and all generation inputs. No effective artifact
   was collected in this checkpoint. Provisioning or modifying a lab still requires Christopher's
   separate Task 3 approval naming the destination.
3. Resolve the precise derived-fixture artifact admission, authorship/credit and permitted-use
   decision before creating the planned `scs-pilot.synthetic.json`. Wrapping source-derived rules in
   JSON does not make them independently authored. No maintainer contact or publication authorized.
4. Complete semantic-oracle tests and independent source-to-effective review before marking Task 6
   completed. Its downstream shadow comparison is not yet unblocked by this checkpoint.

Safe source research can continue without a lab. At effective-artifact or fixture admission barriers,
stop the affected work and obtain the missing evidence/decision; do not present this checkpoint as
permission to inspect an active game, install SCS, or choose a new baseline version.
