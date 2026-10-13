# Host/runtime toolchain decision

**Research ID:** PREP-01-T2-HOST-TOOLCHAIN

**Status:** Conditional

**Date:** 2026-08-31

**Owners:** Integration owner

**Evidence:** E1 host/binary inventory plus E2 synthetic path-safety tests

## Question

Which host runtimes, version floors, encodings, discovery rules, and command boundaries are safe and
reproducible for the initial Windows research profile without turning a host tool into an in-game
dependency or treating an unavailable tool as a passing check?

## Decision

The initial host profile is Windows x64 with PowerShell Core, CPython 3.11, and pytest 8.4. Lua
policy remains Lua 5.1-compatible; Lupa is an optional host-only E2 runner. WeiDU v251.00 remains
the required future compiler/installer identity, but it is currently unavailable and therefore no
WeiDU parse, compile, install, or restoration result is claimed. Near Infinity is not selected as a
required batch tool at this checkpoint.

| Boundary | Selected floor/profile | Verified here | Failure behavior |
|---|---|---|---|
| Environment guard | Windows x64 OS and x64 PowerShell Core process, `>=7.4,<8` | PowerShell `7.6.5`, .NET `10.0.11`, OS build `10.0.26200.0`; OS/process both x64 | Refuse before path access on Windows PowerShell 5.1, non-Windows, non-x64 OS/process, Core `<7.4`, or Core `>=8` |
| Python host tooling | CPython `>=3.11,<3.12` | CPython `3.11.9`; host suites executed with `-X utf8` | Outside the selected range blocks the dependent host check; no other interpreter is guessed |
| Test runner | pytest `>=8.4,<9` | pytest `8.4.2`; focused and full host suites executed | A missing/out-of-range runner is reported and blocks the dependent check |
| Optional Lua E2 runner | Lupa `>=2.8,<3`, use the named `lua51` or `luajit21` backend explicitly | Lupa `2.8`; Lua 5.1; LuaJIT `2.1.1774896198` | Lua-dependent E2 check is unexecuted |
| Embedded runtime | EEex-selected LuaJIT capability profile | Not executed | No runtime-support claim; the dependent adapter stays inactive |
| Installer/compiler | WeiDU `v251.00`, commit `5d94cb73661d74a6fd5126ede39c4c7b3748e188` | Executable unavailable | E3 and compiler evidence remain blocked; Python/PowerShell never substitute |
| Decompiler/browser | No required Near Infinity profile yet | Command/JAR unavailable | NI-dependent work is unexecuted; no recursive host search is authorized |
| Java for a future NI profile | No selected floor beyond upstream's numeric Java 8 input | Java `1.8.0_491-b10`, x86 Client VM | Current 32-bit Java is not accepted as proof of NI availability or corpus suitability |
| EEex native prerequisite metadata | Microsoft VC++ x64 runtime present | Registry reports `v14.51.36231.00`, installed | Metadata only; it does not prove EEex loader success |

The PowerShell 7.4 floor is a selected compatibility boundary, not a claim that every 7.4-7.6
patch was tested. The only executed profile is 7.6.5. Expanding the accepted profile requires the
same checker suite on the added version.

## Host observation

The bounded inventory used application-command lookup, exact registry keys, runtime self-reporting,
and temporary-directory tests. It did not crawl disks, inspect a game path, launch a game, install a
tool, or create a disposable game.

| Observation | Result |
|---|---|
| Standalone `lua`, `luajit`, `weidu`, `NearInfinity`, `NearInfinity.exe` | Not directly discoverable on `PATH`; this is not proof of machine-wide absence |
| `python`, `pytest`, `java` | Directly discoverable; executable locations are intentionally not recorded |
| `javap`, `jar` | Not directly discoverable on `PATH` |
| PowerShell Core text defaults | .NET/default output UTF-8; console input IBM850; culture `en-DE`, UI culture `en-GB` |
| CPython without UTF-8 mode | preferred/stdout encoding Windows-1252; UTF-8 mode disabled |
| CPython with `-X utf8` | filesystem/default/preferred encoding UTF-8; UTF-8 mode enabled |
| Windows PowerShell 5.1 | `5.1.26100.9168`; default Windows-1252; `$OutputEncoding` US-ASCII; rejected by the checker |
| Workspace volume snapshot | fixed NTFS; 1,999,364,943,872 total bytes and 124,443,230,208 free bytes at observation time |

The capacity snapshot is volatile, and the workspace volume is not an approved lab destination. No
fixed disposable-lab byte floor is supportable before Task 3 is authorized to measure the named
source and destination. The later preflight must require:

```text
free destination bytes >= full independent working copy
                        + independent reset baseline
                        + worst-case WeiDU backup/output/evidence allowance
                        + explicit safety reserve
```

Hard links, junctions, shared user directories, and optimistic filesystem compression do not reduce
that requirement because they weaken isolation or make capacity non-deterministic.

## Encoding and invocation contract

- Repository JSON, JSONL, Markdown, Python, PowerShell, Lua, BAF, D, and WeiDU-authored text is
  UTF-8. Generated text uses explicit UTF-8 and deterministic LF where the consumer permits it.
- Invoke tests as `python -X utf8 -m pytest ...`; never rely on the console code page or locale.
- The environment checker performs bounded application-command lookup but does not execute the
  candidate. A match is only `discoverable` with execution `unexecuted`; it is not `available` or
  verified. Record version/identity in a separately scoped reproduction step before relying on it.
  Never hardcode a personal absolute executable path or silently accept a WindowsApps alias.
- A missing command is `unavailable`; an intentionally skipped command is `unexecuted`; VC++
  registry presence is `metadata-present`. None of those statuses means `passing`.
- External command stdout/stderr is never copied into the environment checker's JSON. The checker
  reports sanitized status only.
- WeiDU positional decompiles, once authorized and available, run from a dedicated scratch working
  directory because they can write output there. No such command was executed at this checkpoint.

`pyproject.toml` records the CPython and pytest bounds. PowerShell is intentionally separate because
it is the Windows safety boundary, not a Python package dependency.

## Windows path decision

Lexical normalization is not physical canonicalization. The executed host inventory reproduced
junction targets and 8.3 aliases that ordinary `Resolve-Path`/`Path.GetFullPath()` did not safely
discharge as an identity proof. The checker therefore:

1. requires both `BGSE_ACTIVE_GAME_ROOT` and `BGSE_DISPOSABLE_GAME_ROOT`; no active path is embedded,
   inferred, or searched for, and a missing value fails closed;
2. accepts only ordinary local drive-absolute input;
3. rejects active/disposable lexical overlap before filesystem access;
4. walks every existing component with a no-follow metadata handle;
5. rejects any reparse point;
6. compares no-follow/follow identity, volume-qualified final paths, volume serial, and the complete
   128-bit file ID;
7. rejects a hard-linked marker or existing file target by native link count, and rejects an existing
   directory as an unaudited recursive write scope;
8. decodes the exact-root marker with a throwing UTF-8 decoder and parses strict JSON: one object,
   exact case-sensitive required names, unique names case-insensitively, JSON-number task/schema
   fields, exact string contracts, and a UUID-v4 lab ID;
9. validates every intended target; and
10. emits exactly one path-free JSON object with stable status/exit-code semantics.

The implementation follows Microsoft's documented
[`CreateFileW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew),
[`GetFinalPathNameByHandleW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew),
[`FILE_ID_INFO`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info),
[`GetFileInformationByHandle`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfileinformationbyhandle),
[`BY_HANDLE_FILE_INFORMATION.nNumberOfLinks`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-by_handle_file_information),
[hard-link](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions), and
[reparse-point](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-operations)
contracts. The live Microsoft pages are E0 documentation input; the synthetic NTFS regressions are
the E2 behavior evidence for this host. This is a read-only preflight, not a TOCTOU guarantee; Task 3
must repeat the guard immediately before each authorized mutation.

## Reproduction

Run from the repository root. These commands print versions/statuses but not executable locations:

```powershell
$PSVersionTable.PSVersion.ToString()
[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
[Environment]::OSVersion.Version.ToString()

$names = 'python','pytest','lua','luajit','weidu','NearInfinity','NearInfinity.exe','java','javap','jar'
foreach ($name in $names) {
    $found = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Name = $name
        Status = if ($found) { 'discoverable' } else { 'unavailable' }
        Execution = 'unexecuted'
    }
}

python -X utf8 -c "import locale,platform,sys; print(platform.python_version(), locale.getpreferredencoding(False), sys.flags.utf8_mode)"
python -X utf8 -m pytest --version
python -X utf8 -c "from importlib.metadata import version; from lupa import lua51,luajit21; print(version('lupa'), lua51.LuaRuntime().eval('_VERSION'), luajit21.LuaRuntime().eval('jit.version'))"

$vc = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
[pscustomobject]@{ Installed = $vc.Installed; Version = $vc.Version }

python -X utf8 -m pytest archive/2026-10-process/tests/tooling/test_environment_contract.py -q
```

The initial intentional RED is preserved in commit `cbb42a0`: the focused test exited 1 because the
checker file was absent and PowerShell returned 64 instead of the required refusal exit 3. Later
RED/GREEN cycles added input, marker, path-form, physical-identity, reparse, capability, and
multi-target cases before their implementations. Security review then reproduced an NTFS hard-link
escape, invalid UTF-8 acceptance, a metadata-error ambiguity, and capability/JSON overclaims;
focused failing regressions preceded link-count/directory-scope refusal, strict marker decoding and
parsing, item-not-found-only ancestor termination, the PowerShell `<8` ceiling, and
discoverability-only reporting.

## Counterevidence and rejected alternatives

- `Resolve-Path` and `Path.GetFullPath()` alone are rejected as alias proof.
- Windows PowerShell 5.1 is rejected because the selected checker/runtime and encoding contract is
  PowerShell Core 7; its observed encoding differs materially.
- A `java` command plus an upstream numeric minimum does not prove Near Infinity is installed or
  usable. Near Infinity's pinned source candidate is commit
  [`50021b834e0360c6400a6a818626b50edabdd868`](https://github.com/NearInfinityBrowser/NearInfinity/tree/50021b834e0360c6400a6a818626b50edabdd868),
  which declares `v2.4-20260616` and Java 8, but no local NI command was executed.
- GitHub's historical Near Infinity `releases/latest` result is not used as a current tool pin.
- Standalone Lua and Lupa are not evidence about EEex's embedded LuaJIT build.
- VC++ runtime registry metadata is not loader or engine evidence.

## Artifacts and evidence grade

- `scripts/check-dev-environment.ps1`: read-only Windows preflight.
- `archive/2026-10-process/tests/tooling/test_environment_contract.py`: synthetic temporary-directory E2 guard matrix.
- `pyproject.toml`: selected Python/pytest bounds.
- `docs/research/disposable-lab-runbook.md`: later authorized operating procedure.
- `archive/2026-10-process/docs/research/PREP-01-support-baseline.md`: dependency/revision baseline.

The host inventory is E1 for the exact observed binaries/metadata. The temporary path, output, and
complete fixture-tree snapshots are E2 for checker policy and Win32 call behavior on this host. They
prove no mutation of those checked synthetic fixture trees during the test invocations, not a global
claim that the operating system performed no writes. No E3 synthetic-game, E4 engine, or E5 corpus
evidence was produced.

## Residual uncertainty and next decision

- PowerShell 7.4/7.5 and other Windows builds have not run the checker matrix.
- The installed Lupa backends have not yet run project Lua policy tests.
- WeiDU v251.00 and Near Infinity are unavailable, so compiler/decompiler workflows remain blocked.
- The capacity floor, source size, destination filesystem, user-directory isolation, launch shape,
  and reset design require separate Task 3 authorization naming a destination.
- A read-only preflight cannot eliminate a change between check and later write.

**Outcome: Conditional.** The selected host boundary and checker mechanics are reproducible at E1+E2
on the observed host. Runtime, compiler, installer, lab provisioning, and game-support claims remain
unexecuted.
