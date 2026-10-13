# Reviewed fixture allowlist

**Status:** Task 4 host-only admission contract

**Date:** 2026-09-22

**Owners:** Integration owner

## Exact admission

The machine-readable registry is [`fixture-allowlist.json`](fixture-allowlist.json). Every file
under `tests/fixtures` must appear exactly once with its reviewed raw-byte SHA-256. Admission is
limited to original JSON objects of at most 262,144 bytes, classified as independently authored
metadata or redistributable synthetic fixtures. No glob is an approval rule.

Run from the repository root:

```powershell
python -X utf8 -m tools.provenance.fixtures
python -X utf8 -m pytest archive/2026-10-process/tests/tooling/test_fixture_governance.py -q
```

The checker reads only the repository registry and fixture tree. It neither copies, normalizes,
repairs, publishes, nor installs files. Use a quiescent trusted checkout: it is not a sandbox against
hostile simultaneous filesystem mutation. Review fields record a decision; they are not a signed
approval or an automatic authorship check.

## Positive fixture

| Field | Reviewed value |
|---|---|
| ID | `artifact:synthetic-queue-observation-v1` |
| Path | `archive/2026-10-process/tests/fixtures/governance/queue-observation.json` |
| SHA-256 | `62446ff95f8ffa6d33d1815668247f76a5532731a116cbba467e4d35d3140f94` |
| Origin/owner | Original abstract example, Chriz BG Script Engine contributors |
| Purpose | Express that an acceptance observation alone cannot establish completion |
| Distribution/review | `redistributable`, `approved-for-repository`; integration owner, 2026-09-22 |
| Evidence | E2 admission mechanics only; the expected outcome is a policy input, not a tested action observer |

This fixture was written from scratch for this task, contains no upstream payload or game data, and
records no actual queued action. It has no dependency on SCS, EEex, or a game installation.

## Negative cases and portability

The tests create original negative inputs in temporary directories and require refusal for:

- held artifact classes, non-original/unknown origin, missing provenance, non-approved review,
  held distribution status, or a claimed E4 admission result;
- full-source/generated-script, executable, TLK, save, and log filename descriptors (no actual
  third-party payload is needed); malformed JSON renamed to `.json` is also refused;
- missing/unlisted files, duplicate case-insensitive paths/IDs, or any byte change after review;
- escaping/noncanonical paths, Windows device names, alternate-stream syntax, and hard links;
- duplicate JSON keys, non-finite numbers including exponent overflow, overlong integers, or
  common personal-path forms in JSON values/keys or provenance metadata.

Only UTF-8 JSON objects are admitted. Integers are limited to 4,096 digits independently of the
interpreter's own limit. Unexpected numeric parsing errors yield a sanitized refusal, not a
traceback containing checkout paths. Common Windows drive/UNC and `/home/` or `/users/` path forms
are checked; this is not comprehensive secret detection, semantic privacy analysis, or detection of
copied prose/base64 data. Review remains necessary even with a passing digest and JSON parser.

Registry syntax accepts LF and CRLF. Fixture **bytes** are never normalized: changing LF to CRLF
invalidates the reviewed digest. `.gitattributes` pins `tests/fixtures/**/*.json` to LF on Windows
and Unix checkouts. Symlinks/reparse points and nonregular files are rejected by the checker;
platform-specific coverage and any unexecuted branch are recorded in the task memo.

Full SCS source, generated effective BCS/DLG, installed binaries, TLK, saves, personal-path logs, and
unclassified upstream material are not approved entries. Wrapping them in JSON does not make them
original. The [artifact policy](artifact-policy.md) governs review and the still-deferred publication
scanner/E3 packaging work. This allowlist approves neither a game experiment nor external sharing.
