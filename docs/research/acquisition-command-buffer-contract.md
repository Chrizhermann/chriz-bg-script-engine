# Task 3, packet A4d: pure counted-command-buffer validation

**Status:** Reviewed pure decoder and corrected test transport verified: all 1,146 host tests
passed, with an independent saved-result/hash audit. The first failed run is retained below.
No native command query is admitted.

**Date / owner:** 2026-09-27 / integration lead.

**Question:** Can a candidate x64 counted-string response be decoded using only owned bytes and
checked numeric offsets, without dereferencing a returned address or claiming native provenance?

## Research inputs and limits

[A4c](acquisition-process-enumeration-contract.md) is verified at `b12871f`: 1,097 host tests passed.
Enumeration and [same-handle identity](acquisition-process-identity-contract.md) do not provide
command-line facts. The unresolved joining/opaque-row rules remain in
[A4a](acquisition-process-screening-contract.md); missing information cannot become clearance.

Microsoft's `NtQueryInformationProcess` reference describes a handle-based query, byte-sized
buffers and an NTSTATUS return, warns that the interface can change, and does not document
command-line class 60. This is not an ordinary Win32 command-line API guarantee.
[Microsoft API reference](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntqueryinformationprocess)

Two revision-pinned upstream source observations support a hypothesis, not execution:

- phnt revision `53fbbdc5b5d2b08761db1c7b26bfa8c820924356`, `ntpsapi.h` line 252, identifies
  class 60 as a `UNICODE_STRING` query. Lines 2272-2277 declare the handle/buffer query.
  Raw-file SHA-256 `3477B3FA901715C5AD139AE154F86D6C36F3415962731D6C0DE0DD3C8417F4D8`.
  [Pinned header](https://github.com/winsiderss/phnt/blob/53fbbdc5b5d2b08761db1c7b26bfa8c820924356/ntpsapi.h#L252)
- System Informer revision `1487bbf6eae315a4e55d02432f682cafb5e28348`,
  `phlib/nativeprocess.c` lines 1910-1971, uses that query on the supplied handle for its
  Windows 8.1+ path. Its comment names query-limited access; its implementation resizes on
  a length mismatch and has an older PEB-reading fallback. **Neither its resize policy nor
  its fallback is adopted here.** Raw-file SHA-256
  `8514F547FAB52387642836088B6338858FFCDEE6032522EFDAE618D9B0474902`.
  [Pinned implementation](https://github.com/winsiderss/systeminformer/blob/1487bbf6eae315a4e55d02432f682cafb5e28348/phlib/nativeprocess.c#L1910)

The local SDK 10.0.26100.0 `um/winternl.h` declares two unsigned 16-bit string sizes and a pointer,
and the generic query signature, but its `PROCESSINFOCLASS` subset omits class 60. Header SHA-256:
`A43424486349C38F697C009512DFE4EB8FCA733D7665AFAB42F50752170B9785`. Local ntdll version is
`10.0.26100.9278`, SHA-256
`A74F7482085EAB125CCC09152AB7E0B5994BCB13E1A7B29880BDBB24179ECB8B`. Hashing that DLL did
not execute this query or establish its response layout. No remote source was installed or copied
into this repository; only bounded source inspection occurred.

`UNICODE_STRING` lengths count bytes; a terminator is not mandatory and, when present, is not
included in the content length. This matters: a C-string read could overrun or silently truncate.
[String structure](https://learn.microsoft.com/en-us/windows/win32/api/ntdef/ns-ntdef-_unicode_string)

## Reviewed pure boundary

`ProcessCommandBuffer.Decode(byte[] buffer, ulong originalBase, uint returnedBytes, int status)`
returns a private string or a fixed refusal. It is a decoder of caller-supplied values, **not** a
native provider, trusted command fact, parser of shell syntax or process-identity attestation.
No P/Invoke, `IntPtr`, unmanaged read, process/file/network access, platform probe or child process.

The format is explicitly x64 little-endian: header size 16; unsigned 16-bit `Length` at offset 0,
unsigned 16-bit `MaximumLength` at offset 2, and unsigned 64-bit buffer address at offset 8.
Padding bytes are not interpreted. Decoding this format on a host does not prove target bitness.

1. Before copying, require a nonnull input of 16..65,552 bytes, a nonzero original base and an
   allocation interval whose exclusive end does not wrap unsigned 64-bit arithmetic. Invalid
   input is `BGSE_E_PROCESS_COMMAND_INPUT`. Keep a defensive snapshot; never retain caller bytes.
2. Accept only status zero. Every nonzero NTSTATUS is `..._STATUS`, with fixed diagnostic
   operation `decode`, kind `ntstatus`, and the numeric status; no payload or inner exception.
   This conservative success policy is not a claim that every nonzero status means OS failure.
3. Require `returnedBytes` between 16 and the supplied buffer length. Zero/short/oversized output
   is `..._DATA`, not a known empty command.
4. Require even lengths and `Length <= MaximumLength`. A null address is valid only when both
   lengths are zero. It yields an empty string only for these supplied successful values; it
   does not establish that a real native call initialized the descriptor.
5. For a nonnull address, subtract the base only after proving it is not below the base. Require
   the offset at/after the 16-byte header and at/before the returned extent. Check that the full
   maximum span fits in the returned extent using subtraction, without adding untrusted values.
   A zero-length/zero-maximum nonnull address may equal the exclusive returned end.
6. Decode exactly `Length` bytes from the validated owned-array offset as strict UTF-16LE.
   Reject malformed surrogate sequences and embedded NUL with `..._DATA`. Do not require or scan
   for a terminator; do not decode unused capacity/tail bytes or normalize case/spacing/quotes.
7. Never dereference the numeric address. Cast an offset to an array index only after its bound
   is proved. Refusals contain no command, address, frame bytes, exception details or inner error.

Validation precedence is input/base/allocation range, then exact signed 32-bit status, then
clone and validate only the owned snapshot and returned extent/descriptor. Do not translate
NTSTATUS to Win32 error or apply `NT_SUCCESS`. Ignore padding, but preserve a content BOM as a
character. Immutable decoded output does not itself prove the defensive clone: clone-before-read
is separately checked statically. No atomic capture under concurrent caller mutation is claimed.
INPUT/DATA use the existing refusal diagnostic `guard` / `guard` with no numeric native error;
only STATUS carries the exact supplied signed status under `decode` / `ntstatus`.

The byte cap accommodates a 16-byte header and the largest unsigned-16-bit counted spans with
small alignment allowance. It is an application limit, not a claim about all Windows versions.
Whether a real response satisfies this exact conservative envelope still needs a reviewed,
own-harness native experiment. No larger-buffer retry or permissive reinterpretation is implied.

## TDD, review and later barriers

First write a failing synthetic fixture before the helper exists. Cover preserved text/spacing,
valid pairs, counted nonterminated strings, known empty descriptors, exact maximum lengths,
invalid input/allocation arithmetic, native status refusals, short/long returned extents,
odd/reversed lengths, pointer-underflow/header/out-of-range, maximum-span overflow, embedded NUL,
unpaired surrogates, ignored padding/tail, input/result isolation and sanitized diagnostics.
Tests construct byte arrays and synthetic base addresses; none queries process command lines.

Independent review must examine branch reachability and unsigned arithmetic. Follow focused and
full host regression plus G0/link/privacy checks before committing. Record worker outcomes and
any correction; do not use a pass count as evidence of a native API contract.

Later native integration must separately validate supported host/binding/layout, returned status
and initialized extent, caller-owned allocation and pointer placement, same-handle identity and
liveness before/after observation, cleanup, error handling and privacy. It must not reopen a PID
to fetch a command, read remote memory/PEB, adjust privileges or execute the returned text.
Even two equal command reads would be observations, not immutable launch history or proof of
actual file use. Opaque processes remain unresolved. No system/service or self exemption is added.

**Evidence:** E0 official documentation, E1 pinned source/SDK/binary inspection and the limited E2
synthetic execution below. No native command-line query, E3/E4/E5 or acquisition proof.
**Counterevidence / uncertainty:** class 60 lacks an official class-specific contract; neither
pointer placement nor all response variants are proved by the inspected callers. Pure parsing
cannot authenticate a fabricated frame or solve complete process coverage.
**Next decision:** freeze this verified pure boundary in a narrow commit, then separately review
the native query contract. Fresh coordination, complete `-WhatIf`, copier B-E and all runtime
gates remain.

Independent schema review accepted this narrow decoder without a blocker and independently
matched the local SDK header. It reinforced that the maximum-span/UTF-16 rules define a strict
application subset, not Windows guarantees. It requested distinct status-precedence, one-past
empty, maximum-versus-content-span and malformed-tail fixtures; these are implementation checks.

## Execution and reproducibility

The first fixture failed before `ProcessCommandBuffer.cs` existed: **1 failed in 1.00 seconds**.
After implementation, the same counted-text fixture passed: **1 passed in 1.61 seconds**. It
checks exact preservation of BOM, quotes, spaces, a surrogate pair and text without a terminator.
Before the GREEN run, the lead made the harness explicitly preserve null versus empty byte arrays
and avoid converting null to base64 before the helper call; these are test-boundary corrections,
not relaxed decoder assertions. No process command line was read.

Independent static code review accepted validation precedence, guarded unsigned arithmetic,
clone-before-descriptor-read, explicit endian handling, strict counted UTF-16, empty descriptors,
refusal privacy and the absence of native/pointer/process operations. Its scope is code inspection,
not execution of the pending fault branches. Both G0 validators and LF/CRLF checks passed unchanged.

Environment: Windows x64 10.0.26200.0, PowerShell 7.6.6, Python 3.11.9, pytest 8.4.2. This execution
environment does not turn the pure wire-format decoder into a native Windows compatibility claim.
Focused command:

```text
python -X utf8 -m pytest -q tests/tooling/test_process_command_buffer.py tests/tooling/test_process_command_buffer_faults.py
```

The full host command is `python -X utf8 -m pytest -q`. Save exact code/test/tool identities and
the result privately; verify completion before the narrow commit. No source retry is reopened.

The Sol 6 worker authored only the synthetic fault file after schema review. The lead read it
fully and ran the first combined suite: **37 passed in 42.47 seconds**, with no harness failure.
Fixtures are independently packed little-endian bytes; the maximum-sized fixture is constructed
inside the harness to avoid oversized Windows environment values. No fixture calls a native API.

Independent fault review found two meaningful coverage gaps: failing pointers/spans exceeded
both allocation capacity and the returned extent, and no valid nonnull high-address fixture
proved full-width arithmetic. The lead added separate inside-allocation/outside-returned cases
for pointer and maximum span, plus a valid near-UInt64-limit pointer. It also added a nonnull
empty string with reserved capacity, explicit informational/negative status cases on valid
frames, exact refusal diagnostics and a synthetic payload privacy canary. The misleading empty
case name was corrected. No production code or safety assertion was weakened; the final run
below supersedes the initial 37-case result after verification.

The strengthened focused run passed **45 tests in 51.38 seconds**, exit 0. Independent
review accepted all corrections with no remaining static blocker. No helper/test bytes changed
between this run and the first full dispatch. Collection found **1,142 tests** (1,097 prior + 45 new) in 0.21 seconds; collection
is not execution. After JSON/link/privacy/whitespace checks and matching all seven saved
helper/test/dependency/tool hashes plus the local research pins, the full suite was dispatched
once in fresh `work/command-buffer-tests-v1` under private Task 3 records, with a 1,800-second
timeout, launcher exit 0 and the completion-wakeup mechanism.

### Full-run failure and transport correction

The saved first result was **exit 1: 1 failed, 1,141 passed in 813.68 seconds**. The primary
Unicode assertion received `?` for the content BOM and `??` for the emoji. Stderr and runner
log were empty; there was no timeout and the single completion notification was accepted.
Independent result audit matched all seven pre-correction code/test/dependency/tool hashes.
This failed result is preserved; it did not authorize a commit or a repeat of the same job.

Diagnosis isolated the output boundary: a fresh hidden harness decoded the synthetic frame,
encoded the returned .NET string as UTF-16LE/base64 before serialization, then emitted that
base64 beside the raw JSON value through a process-private ASCII writer. The internal string
bytes matched the fixture exactly, while the raw JSON value reproduced the question-mark loss.
The completion runner uses a hidden command process and binary log capture; Python's UTF-8
setting does not choose the nested PowerShell writer's encoding. Foreground-only success had
not exercised this transport condition. No native command query was involved.

The new regression always starts the test harness with `CREATE_NO_WINDOW` and separately
sets only that harness's managed writer to code pages 20127 (ASCII), 437, 949 and 65001 (UTF-8).
No shared console code page or parent environment is changed. Before the fix, the five positive
cases produced **4 failed, 1 passed in 7.42 seconds**, including the original failure; two
legacy-code-page cases also exposed Python reader-thread UTF-8 decode warnings.

The harness now uses `ConvertTo-Json -EscapeHandling EscapeNonAscii` for both result branches,
captures raw bytes, removes at most one leading UTF-8 transport preamble, and requires all
remaining bytes to be ASCII before JSON decoding. This is lossless JSON transport, not text
normalization. The content BOM remains inside the value; exact assertions also retain accented
text, Korean, emoji, literal backslash-u text, tabs, line breaks, quotes and spaces. The pure
decoder and its malformed-UTF-16 refusal behavior are unchanged. Independent correction review
found no blocker or weakened assertion.

Reproduce the transport regression with:

```text
python -X utf8 -m pytest -q tests/tooling/test_process_command_buffer.py
```

The combined focused command above now passes **49 tests in 58.47 seconds**, exit 0, with no
warnings. Collection reports **1,146 tests in 0.21 seconds** (1,097 prior + 49); it is not a full
pass. After both G0 validators, LF/CRLF, JSON/link/privacy/whitespace, current fingerprint and
independent evidence checks passed, the corrected full suite was dispatched once in fresh
`work/command-buffer-tests-v2`: launcher exit 0, 1,800-second timeout, its own completion
notification. No helper/test bytes changed after the 49-case run. Preserve v1; no watcher or
polling, and no narrow commit until v2's saved result and identities are independently verified.

### Verified corrected full result

The saved v2 result is **succeeded, exit 0: 1,146 passed in 837.03 seconds** (13:57), with empty
stderr and runner log, no warnings/skips and no timeout. The runner interval was 17:40:04.046204
to 17:54:01.863273 UTC on 26 September, 837.817069 seconds. Eight retained result files total
2,537 bytes; the single completion notification was accepted. The exact command was
`python -X utf8 -m pytest -q` in this worktree with a 1,800-second timeout.

The lead and independent Sol 6 auditor matched all seven current helper/test/dependency/tool
hashes and both local research pins, the command, count (1,097 + 49), exit/status/timing and
single notification. Code/test modification times preceded dispatch. No helper or test bytes
changed after dispatch. This verifies the pure decoder and its hidden-output regression only;
the native command query, operating-system response contract and complete process provider
remain unexecuted. Both the failed v1 evidence and successful v2 evidence are retained privately.

Authored helper SHA-256:
`D26CC8B58F1675B9AFE794BEDEBBB2DDA48FD36BA2DF73C28721DDE6A213E914`.
This packet proves only the tested pure decoder. All native command-buffer layout/ownership,
same-handle provenance, opaque-row accounting, observer/coordination and operational admission
requirements remain open; it neither changes the runtime baseline nor admits any copy or launch.
