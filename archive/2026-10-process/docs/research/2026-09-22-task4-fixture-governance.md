# Task 4 — Fixture and provenance governance

**Status:** Task 4 complete — independently reviewed host-only governance

**Date:** 2026-09-22

**Owners:** Integration owner

**Applicable evidence:** evidence:E1 pinned upstream-source identity; evidence:E2 deterministic
fixture admission. Policy choices remain evidence:E0. No E3/E4/E5 result is claimed.

## Question and scope

Can future fixtures and migrated behaviors have an explicit place, owner, evidence chain, and
distribution decision, while admitting one original fixture and rejecting held material without
accessing a game?

Task 4 steps 1–6 were already recorded in PREP-02. This follow-up covers steps 7–9: the seven
artifact classes, upstream register and default holds, exact fixture allowlist, positive/negative
host validation, and independent review. It does not implement runtime policy or change any gate.

## Environment and identities

- `env:host`; Windows x64, Windows NT `10.0.26200.0`.
- CPython `3.11.9`, pytest `8.4.2`, PowerShell Core `7.6.6`, Git `2.55.0.windows.5`.
- Baseline repository commit: `9ce0ef08146b4df57f861f2a2c2f1829dc819c3f`.
- The commit containing this memo binds the checker, tests, policy, and allowlist together; retrieve
  it with `git log -1 --format=%H -- archive/2026-10-process/docs/research/2026-09-22-task4-fixture-governance.md`.
- The original fixture's raw-byte SHA-256 is
  `62446ff95f8ffa6d33d1815668247f76a5532731a116cbba467e4d35d3140f94`.
- SCS `v35.21`, commit `5dc240e9ff85d3909b6436e54b56297d3b61e33b`: readme re-fetched
  read-only in memory, 345,027 bytes, SHA-256
  `1CDD2C11526E27D37CDB62938CCFD7EF8B03932AB03C0AC30ECFDA4145C2F5AA`.
  PREP-02 contains the exact pinned URL and retrieval/hash command. No source payload was saved.

Only repository files, temporary original host fixtures, ordinary host tool metadata, and the pinned
public source were used. No installed game, save, disposable lab, or game process was accessed.
No author/registry contact, permission request, repository publication, or package creation occurred.

## Method and reproduction

From the repository root, run:

```powershell
python -X utf8 -m pytest archive/2026-10-process/tests/tooling/test_fixture_governance.py -q
python -X utf8 -m pytest archive/2026-10-process/tests/schemas/test_research_evidence_schema.py -q
python -X utf8 -m tools.provenance.fixtures
python -X utf8 -m pytest -q
pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-decisions.ps1
pwsh -NoProfile -File archive/2026-10-process/scripts/validate-g0-namespace.ps1
pwsh -NoProfile -File archive/2026-10-process/scripts/test-g0-line-endings.ps1
git diff --check
```

The fixture CLI must report one reviewed repository-relative path and exit zero. The tests build
small original negative cases in temporary directories; they do not obtain upstream content. Exact
digests bind reviewed bytes. Registry parsing accepts both LF and CRLF, but fixture payload bytes
must remain LF as specified by `.gitattributes`. Changed payload line endings fail the digest check.

## TDD observations and review corrections

| Phase | Observed result | Interpretation |
|---|---|---|
| Initial RED | Focused fixture tests: exit 1, collection error `ModuleNotFoundError: No module named 'tools'` | Required admission implementation did not exist |
| Incremental check | `2 failed, 47 passed in 0.74s` | Policy unit cases passed; checked-in registry and CLI integration intentionally still absent |
| Initial GREEN | `49 passed in 0.43s` | One exact original fixture admitted; original negative cases refused |
| Independent-review RED | `5 failed, 50 passed in 0.76s` | Exponent overflow admitted infinity; oversized integer parsing bypassed sanitized errors; two LF/CRLF cases needed a shared registry loader |
| Corrected GREEN | `56 passed in 0.50s` | Finite numbers, bounded integers, sanitized CLI refusal, private-path metadata, and LF/CRLF registry loading verified |

An independent read-only reviewer found the two numeric parser defects by direct reproduction.
The lead added failing tests, then rejected non-finite float results, bounded integer digits, and
caught decoder failures without leaking exception paths. A shared registry loader made the
portability tests exercise the real CLI parsing route. The reviewer did not author the implementation.

The lead separately rechecked the SCS readme digest and found that PREP-02's old GitHub line link
pointed to encounter text, not copyright. The link now points to lines 1988–1995; the historical
source identity and trace records were unchanged. ADR 0005 now distinguishes the completed E1 pin
from the still-unresolved SCS-derived reuse decisions.

## Validation and acceptance

The final host suite passed: `124 passed in 61.25s`, exit 0. The focused PREP-02 schema suite also
passed separately: `6 passed in 0.02s`. The fixture CLI admitted exactly the one reviewed relative
path, and `git check-attr` confirmed `eol: lf`. `git diff --check` passed. Both G0 validators passed;
the separate checkout regression passed for LF and CRLF. This is not a new engine gate result.

The independent reviewer re-read the implementation, original fixture, provenance documents,
PREP-02/ADR updates, and Task 4 exit criteria; independently ran fixture plus schema tests
(`62 passed in 0.54s`), CLI admission, diff checking, and the LF attribute check; and approved the
bounded scope with no remaining blockers. The lead verified the original requirements and recorded
Task 4 as completed. This review pattern is reusable: independent adversarial reproduction,
lead-owned RED-before-fix, independent rerun, then exact evidence and task-state update.

## Counterevidence and residual uncertainty

- A truthful origin declaration and human content review are assumptions. Hashes prove byte
  identity, not authorship, license validity, privacy completeness, or absence of encoded payloads.
- The checker covers `tests/fixtures`, not arbitrary repository files, archive members, generated
  packages, dependency direction, or external contributions. The policy explicitly retains those
  LIC-02/03/04 obligations. No complete legal conclusion or public license is selected.
- Link rejection is implemented and hard-link refusal is host-tested; symlink/reparse refusal is
  not separately exercised by this run. The checker assumes a trusted quiescent checkout and
  does not lock out concurrent hostile filesystem changes.
- Only the named Windows host profile ran. LF/CRLF tests are not Linux/macOS execution evidence.
- The queue observation's expected outcome is an architectural input. Admission does not test an
  actual action observer or prove EEex/WeiDU parsing, bootstrap order, engine safety, or saving.
- SCS generated artifacts, rule tables, prose, and bundled assets still need class-specific reuse
  decisions. The positive fixture contains none of them. TEST-01's Lua scenario/replay harness and
  TEST-02's real WeiDU fake-game integration remain separate, unexecuted work.

## Next decision

After the reviewed completion of Task 4, Task 5 may start its compact synthetic-only inventory and
exact-hash prototype. It must not read a real install or activate ownership. Task 3 stays pending
until the user explicitly authorizes a named disposable destination; no engine-dependent task or
G1–G8 pass can be inferred from this host checkpoint. Gates remain explicit stop points.
