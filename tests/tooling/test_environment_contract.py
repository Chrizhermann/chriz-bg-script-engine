from __future__ import annotations

import ctypes
import json
import os
import shutil
import stat
import subprocess
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path

import pytest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CHECKER_PATH = REPOSITORY_ROOT / "scripts" / "check-dev-environment.ps1"
POWERSHELL_PATH = shutil.which("pwsh")
assert POWERSHELL_PATH is not None
WINDOWS_POWERSHELL_PATH = shutil.which("powershell.exe")
# Inert lexical test data only: never resolve or create this path, and never treat it as the
# user's active-game location.
SYNTHETIC_ACTIVE_GAME_ROOT = Path(r"C:\__BGSE_TEST_ONLY__\active-game")
SYNTHETIC_SECRET = "__BGSE_TEST_SECRET_DO_NOT_DISCLOSE__"
MARKER_NAME = ".bgse-disposable-lab.json"
VALID_MARKER = {
    "schemaVersion": 1,
    "markerType": "chriz-bg-script-engine-disposable-lab",
    "createdByTask": 3,
    "labId": "00000000-0000-4000-8000-000000000001",
}


def run_checker(
    *,
    disposable_root: Path | str | None,
    active_root: Path | str | None,
    intended_write_path: Path | str | Sequence[Path | str] | None,
    environment_overrides: Mapping[str, str] | None = None,
    powershell_path: str = POWERSHELL_PATH,
    reported_powershell_version: str | None = None,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    if disposable_root is None:
        environment.pop("BGSE_DISPOSABLE_GAME_ROOT", None)
    else:
        environment["BGSE_DISPOSABLE_GAME_ROOT"] = str(disposable_root)
    if active_root is None:
        environment.pop("BGSE_ACTIVE_GAME_ROOT", None)
    else:
        environment["BGSE_ACTIVE_GAME_ROOT"] = str(active_root)
    environment["BGSE_TEST_SECRET"] = SYNTHETIC_SECRET
    if environment_overrides is not None:
        environment.update(environment_overrides)

    command = [
        powershell_path,
        "-NoProfile",
    ]
    if intended_write_path is not None:
        if isinstance(intended_write_path, (str, Path)):
            intended_paths = [intended_write_path]
        else:
            intended_paths = list(intended_write_path)
        if len(intended_paths) > 1 or reported_powershell_version is not None:
            environment["BGSE_TEST_CHECKER_PATH"] = str(CHECKER_PATH)
            environment["BGSE_TEST_INTENDED_PATHS_JSON"] = json.dumps(
                [str(path) for path in intended_paths]
            )
            if reported_powershell_version is not None:
                environment["BGSE_TEST_POWERSHELL_VERSION"] = reported_powershell_version
            command.extend(
                [
                    "-Command",
                    (
                        "if ($env:BGSE_TEST_POWERSHELL_VERSION) { "
                        "$PSVersionTable.PSVersion = "
                        "[version]$env:BGSE_TEST_POWERSHELL_VERSION }; "
                        "$paths = $env:BGSE_TEST_INTENDED_PATHS_JSON | ConvertFrom-Json; "
                        "& $env:BGSE_TEST_CHECKER_PATH -IntendedWritePath $paths; "
                        "exit $LASTEXITCODE"
                    ),
                ]
            )
        else:
            command.extend(
                [
                    "-File",
                    str(CHECKER_PATH),
                    "-IntendedWritePath",
                    str(intended_paths[0]),
                ]
            )
    else:
        command.extend(["-File", str(CHECKER_PATH)])

    return subprocess.run(
        command,
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )


def parse_result(result: subprocess.CompletedProcess[str]) -> dict[str, object]:
    assert result.stderr == ""
    output_lines = result.stdout.lstrip("\ufeff").splitlines()
    assert len(output_lines) == 1
    payload = json.loads(output_lines[0])
    assert isinstance(payload, dict)
    if payload.get("status") != "safe":
        assert payload.get("capabilities") == {"discovery": "unexecuted"}
    return payload


def assert_sanitized(
    result: subprocess.CompletedProcess[str],
    *hidden_values: object,
) -> None:
    normalized_output = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    assert "__bgse_test_only__" not in normalized_output
    assert SYNTHETIC_SECRET.casefold() not in normalized_output
    for value in hidden_values:
        normalized_value = str(value).replace("\\\\", "\\").casefold()
        assert normalized_value not in normalized_output


def write_valid_marker(root: Path) -> None:
    (root / MARKER_NAME).write_text(
        json.dumps(VALID_MARKER, sort_keys=True),
        encoding="utf-8",
        newline="\n",
    )


def snapshot_tree(root: Path) -> dict[str, object]:
    """Snapshot fixture entries without following reparse points.

    The guard's no-mutation contract covers entry creation/removal, empty directories,
    entry kinds, link metadata, and regular-file bytes—not only existing file contents.
    """

    snapshot: dict[str, object] = {}

    def visit(path: Path, relative_path: str) -> None:
        metadata = os.lstat(path)
        file_attributes = getattr(metadata, "st_file_attributes", 0)
        reparse_tag = getattr(metadata, "st_reparse_tag", 0)
        is_reparse_point = bool(
            file_attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
        )
        entry_type = (
            "reparse"
            if is_reparse_point
            else "directory"
            if stat.S_ISDIR(metadata.st_mode)
            else "file"
            if stat.S_ISREG(metadata.st_mode)
            else "other"
        )
        record: dict[str, object] = {
            "type": entry_type,
            "mode": metadata.st_mode,
            "size": metadata.st_size,
            "mtime_ns": metadata.st_mtime_ns,
            "device": metadata.st_dev,
            "inode": metadata.st_ino,
            "links": metadata.st_nlink,
            "file_attributes": file_attributes,
            "reparse_tag": reparse_tag,
        }
        if entry_type == "file":
            record["bytes"] = path.read_bytes()
        snapshot[relative_path] = record

        if entry_type == "directory":
            with os.scandir(path) as entries:
                children = sorted(entries, key=lambda entry: entry.name.casefold())
            for child in children:
                child_relative = (
                    child.name
                    if relative_path == "."
                    else f"{relative_path}/{child.name}"
                )
                visit(Path(child.path), child_relative)

    visit(root, ".")
    return snapshot


def create_junction(link: Path, target: Path) -> None:
    result = subprocess.run(
        ["cmd.exe", "/d", "/c", "mklink", "/J", str(link), str(target)],
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def get_short_path(path: Path) -> Path:
    get_short_path_name = ctypes.windll.kernel32.GetShortPathNameW
    get_short_path_name.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint32]
    get_short_path_name.restype = ctypes.c_uint32
    buffer = ctypes.create_unicode_buffer(32768)
    length = get_short_path_name(str(path), buffer, len(buffer))
    if length == 0 or length >= len(buffer):
        pytest.skip("No usable 8.3 alias is available for this synthetic fixture")
    short_path = Path(buffer.value)
    if str(short_path).casefold() == str(path).casefold():
        pytest.skip("The synthetic fixture has no distinct 8.3 alias")
    return short_path


def get_unused_drive_root() -> Path:
    logical_drive_mask = ctypes.windll.kernel32.GetLogicalDrives()
    for letter_index in range(25, 1, -1):
        if not logical_drive_mask & (1 << letter_index):
            return Path(f"{chr(ord('A') + letter_index)}:\\")
    pytest.skip("No unused local drive letter is available for the volume-refusal fixture")


def test_refuses_configured_active_game_root_before_any_write(tmp_path: Path) -> None:
    write_probe = tmp_path / "must-not-exist"

    result = run_checker(
        disposable_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=write_probe,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    payload = parse_result(result)
    assert payload["code"] == "BGSE_E_ACTIVE_GAME_ROOT"
    assert payload["capabilities"] == {"discovery": "unexecuted"}
    assert not write_probe.exists()
    assert_sanitized(result)


@pytest.mark.parametrize("missing_name", ["active", "disposable"])
def test_rejects_missing_required_root_without_disclosure(missing_name: str) -> None:
    result = run_checker(
        disposable_root=None if missing_name == "disposable" else SYNTHETIC_ACTIVE_GAME_ROOT,
        active_root=None if missing_name == "active" else SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=SYNTHETIC_ACTIVE_GAME_ROOT / "write-probe",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REQUIRED_ENV"
    assert_sanitized(result)


@pytest.mark.parametrize("relative_name", ["active", "disposable"])
def test_rejects_relative_root_without_resolving_it(relative_name: str) -> None:
    result = run_checker(
        disposable_root=(
            "relative-disposable"
            if relative_name == "disposable"
            else r"C:\__BGSE_TEST_ONLY__\disposable-game"
        ),
        active_root=(
            "relative-active" if relative_name == "active" else SYNTHETIC_ACTIVE_GAME_ROOT
        ),
        intended_write_path=r"C:\__BGSE_TEST_ONLY__\disposable-game\write-probe",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_PATH_NOT_ABSOLUTE"
    assert_sanitized(result)


def test_rejects_missing_intended_write_path() -> None:
    result = run_checker(
        disposable_root=r"C:\__BGSE_TEST_ONLY__\disposable-game",
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=None,
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_INTENDED_WRITE_REQUIRED"
    assert_sanitized(result)


@pytest.mark.parametrize(
    ("disposable_root", "active_root"),
    [
        (
            r"C:\__BGSE_TEST_ONLY__\ACTIVE-GAME",
            r"c:\__bgse_test_only__\active-game",
        ),
        (
            r"C:\__BGSE_TEST_ONLY__\active-game\disposable",
            r"C:\__BGSE_TEST_ONLY__\active-game",
        ),
        (
            r"C:\__BGSE_TEST_ONLY__\disposable-game",
            r"C:\__BGSE_TEST_ONLY__\disposable-game\active",
        ),
    ],
    ids=["case-variant", "disposable-inside-active", "active-inside-disposable"],
)
def test_refuses_case_insensitive_root_overlap_before_filesystem_access(
    disposable_root: str,
    active_root: str,
) -> None:
    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=Path(disposable_root) / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_ACTIVE_GAME_ROOT"
    assert_sanitized(result)


def test_accepts_safe_marked_synthetic_root_without_mutation(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "generated" / "artifact.json",
    )

    assert result.returncode == 0, result.stderr or result.stdout
    payload = parse_result(result)
    assert payload["code"] == "BGSE_OK"
    assert payload["checks"] == {
        "configuration": "verified",
        "lexicalIsolation": "verified",
        "reparseIsolation": "verified",
        "physicalIsolation": "verified",
        "localFixedVolumes": "verified",
        "marker": "verified",
        "intendedWrites": "verified",
    }
    assert payload["capabilities"]["discovery"] == "completed"
    assert payload["capabilities"]["powerShell"]["status"] == "available"
    assert payload["capabilities"]["powerShell"]["execution"] == "verified"
    assert payload["capabilities"]["powerShell"]["version"]
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root)


@pytest.mark.parametrize("missing_name", ["active", "disposable"])
def test_rejects_nonexistent_root_without_creating_it(
    tmp_path: Path,
    missing_name: str,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    if missing_name != "active":
        active_root.mkdir()
    if missing_name != "disposable":
        disposable_root.mkdir()
        write_valid_marker(disposable_root)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_ROOT_NOT_FOUND"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root)


@pytest.mark.parametrize("marker_location", ["missing", "parent", "child"])
def test_requires_marker_at_exact_disposable_root(
    tmp_path: Path,
    marker_location: str,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    if marker_location == "parent":
        write_valid_marker(tmp_path)
    elif marker_location == "child":
        child = disposable_root / "child"
        child.mkdir()
        write_valid_marker(child)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_MARKER_REQUIRED"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root)


@pytest.mark.parametrize(
    "invalid_marker",
    [
        "malformed",
        "invalid-utf8",
        "non-object-root",
        "wrong-contract",
        "string-numeric-fields",
        "missing-lab-id",
        "case-mismatched-key",
        "duplicate-required-key",
        "invalid-lab-id",
        "oversized",
    ],
)
def test_rejects_invalid_marker_without_disclosure(
    tmp_path: Path,
    invalid_marker: str,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    marker_path = disposable_root / MARKER_NAME
    if invalid_marker == "malformed":
        marker_path.write_text("{not-json", encoding="utf-8")
    elif invalid_marker == "invalid-utf8":
        marker_path.write_bytes(
            json.dumps(VALID_MARKER, separators=(",", ":"))[:-1].encode("utf-8")
            + b',"extra":"\xff"}'
        )
    elif invalid_marker == "non-object-root":
        marker_path.write_text(json.dumps([VALID_MARKER]), encoding="utf-8")
    elif invalid_marker == "wrong-contract":
        marker_path.write_text(
            json.dumps({**VALID_MARKER, "createdByTask": 2}),
            encoding="utf-8",
        )
    elif invalid_marker == "string-numeric-fields":
        marker_path.write_text(
            json.dumps({**VALID_MARKER, "schemaVersion": "1", "createdByTask": "3"}),
            encoding="utf-8",
        )
    elif invalid_marker == "missing-lab-id":
        marker_path.write_text(
            json.dumps({key: value for key, value in VALID_MARKER.items() if key != "labId"}),
            encoding="utf-8",
        )
    elif invalid_marker == "case-mismatched-key":
        marker_path.write_text(
            json.dumps(
                {
                    **{
                        key: value
                        for key, value in VALID_MARKER.items()
                        if key != "schemaVersion"
                    },
                    "SchemaVersion": 1,
                }
            ),
            encoding="utf-8",
        )
    elif invalid_marker == "duplicate-required-key":
        marker_path.write_text(
            (
                '{"schemaVersion":1,"schemaVersion":1,'
                '"markerType":"chriz-bg-script-engine-disposable-lab",'
                '"createdByTask":3,'
                '"labId":"00000000-0000-4000-8000-000000000001"}'
            ),
            encoding="utf-8",
        )
    elif invalid_marker == "invalid-lab-id":
        marker_path.write_text(
            json.dumps({**VALID_MARKER, "labId": "not-a-uuid"}),
            encoding="utf-8",
        )
    else:
        marker_path.write_bytes(b" " * 4097)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_MARKER_INVALID"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root)


def test_refuses_reparse_marker_without_following_it(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    external_marker = active_root / "external-marker.json"
    external_marker.write_text(
        json.dumps(VALID_MARKER, sort_keys=True),
        encoding="utf-8",
        newline="\n",
    )
    os.symlink(external_marker, disposable_root / MARKER_NAME)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REPARSE_POINT"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, external_marker)


def test_refuses_broken_reparse_marker_instead_of_treating_it_as_missing(
    tmp_path: Path,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    missing_external_marker = active_root / "missing-marker.json"
    os.symlink(missing_external_marker, disposable_root / MARKER_NAME)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REPARSE_POINT"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, missing_external_marker)


@pytest.mark.parametrize(
    "write_path_factory",
    [
        lambda _root, _tmp: Path("relative-write"),
        lambda _root, tmp: tmp / "outside" / "artifact.json",
        lambda root, _tmp: Path(f"{root}\\child\\..\\..\\escape.json"),
        lambda root, _tmp: Path(f"{root}-other\\artifact.json"),
    ],
    ids=["relative", "outside", "traversal", "prefix-sibling"],
)
def test_refuses_lexical_write_escape_without_mutation(
    tmp_path: Path,
    write_path_factory: Callable[[Path, Path], Path],
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    before = snapshot_tree(tmp_path)
    intended_write_path = write_path_factory(disposable_root, tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_WRITE_ESCAPE"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_refuses_traversal_even_when_normalized_target_stays_inside(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    intended_write_path = Path(f"{disposable_root}\\child\\..\\safe.json")
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_WRITE_ESCAPE"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_rejects_alternate_data_stream_write_target(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    intended_write_path = Path(f"{disposable_root}\\artifact.json:stream")
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_UNSUPPORTED_PATH"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_rejects_device_path_form_before_marker_access(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    device_disposable_root = rf"\\?\{disposable_root}"
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=device_disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "artifact.json",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_UNSUPPORTED_PATH"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, device_disposable_root)


@pytest.mark.parametrize(
    "unsupported_root",
    [
        r"\\server\share\synthetic-root",
        r"C:\synthetic-root\trailing-dot.",
        r"C:\synthetic-root\NUL",
    ],
    ids=["unc", "trailing-dot", "reserved-name"],
)
def test_rejects_unsupported_root_form_before_filesystem_access(
    unsupported_root: str,
) -> None:
    result = run_checker(
        disposable_root=unsupported_root,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=r"C:\__BGSE_TEST_ONLY__\write-probe",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_UNSUPPORTED_PATH"
    assert_sanitized(result, unsupported_root)


def test_rejects_unready_local_volume_before_path_access() -> None:
    disposable_root = get_unused_drive_root() / "__BGSE_TEST_ONLY__" / "disposable"

    result = run_checker(
        disposable_root=disposable_root,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=disposable_root / "artifact.json",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_UNSUPPORTED_VOLUME"
    assert_sanitized(result, disposable_root)


@pytest.mark.parametrize(
    "invalid_name",
    ["NUL", "con.txt", "trailing-dot.", "trailing-space ", "wild*card"],
)
def test_rejects_unsupported_future_write_component(
    tmp_path: Path,
    invalid_name: str,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    intended_write_path = disposable_root / invalid_name
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 2, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_UNSUPPORTED_PATH"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_refuses_entire_invocation_when_one_of_multiple_targets_escapes(
    tmp_path: Path,
) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    inside = disposable_root / "inside.json"
    outside = tmp_path / "outside.json"
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=[inside, outside],
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_WRITE_ESCAPE"
    assert snapshot_tree(tmp_path) == before
    assert not inside.exists()
    assert not outside.exists()
    assert_sanitized(result, active_root, disposable_root, inside, outside)


def test_classifies_missing_optional_tools_as_unavailable(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "artifact.json",
        environment_overrides={"PATH": ""},
    )

    assert result.returncode == 0, result.stderr or result.stdout
    capabilities = parse_result(result)["capabilities"]
    assert capabilities["discovery"] == "completed"
    for tool in ["python", "pytest", "lua", "luaJit", "weidu", "java", "nearInfinity"]:
        assert capabilities[tool] == {
            "status": "unavailable",
            "execution": "unexecuted",
        }
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root)


def test_discovered_application_is_not_claimed_executable(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    fake_bin = tmp_path / "fake-bin"
    active_root.mkdir()
    disposable_root.mkdir()
    fake_bin.mkdir()
    write_valid_marker(disposable_root)
    (fake_bin / "python.exe").write_text(
        "plain text fixture; the checker must not execute it",
        encoding="utf-8",
    )
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "artifact.json",
        environment_overrides={"PATH": str(fake_bin)},
    )

    assert result.returncode == 0, result.stderr or result.stdout
    capabilities = parse_result(result)["capabilities"]
    assert capabilities["python"] == {
        "status": "discoverable",
        "execution": "unexecuted",
    }
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, fake_bin)


def test_emits_exactly_one_sanitized_json_object(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "artifact.json",
    )

    assert result.stderr == ""
    assert len(result.stdout.splitlines()) == 1
    assert isinstance(parse_result(result), dict)
    assert_sanitized(result, active_root, disposable_root)


def test_ancestor_walk_only_treats_item_not_found_as_missing() -> None:
    checker_source = CHECKER_PATH.read_text(encoding="utf-8")
    ancestor_walk = checker_source.split(
        "function Get-BgseVerifiedAncestorChain", maxsplit=1
    )[1].split("function Test-BgseIdentityInChain", maxsplit=1)[0]

    assert "-ErrorAction Stop" in ancestor_walk
    assert "catch [System.Management.Automation.ItemNotFoundException]" in ancestor_walk
    assert "-ErrorAction SilentlyContinue" not in ancestor_walk


def test_checker_enforces_the_declared_x64_host_boundary() -> None:
    checker_source = CHECKER_PATH.read_text(encoding="utf-8")

    for architecture_property in ["OSArchitecture", "ProcessArchitecture"]:
        assert (
            "[Runtime.InteropServices.RuntimeInformation]::"
            f"{architecture_property} -ne "
            "[Runtime.InteropServices.Architecture]::X64"
        ) in checker_source


def test_rejects_windows_powershell_5_before_path_access() -> None:
    if WINDOWS_POWERSHELL_PATH is None:
        pytest.skip("Windows PowerShell is unavailable")

    result = run_checker(
        disposable_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=SYNTHETIC_ACTIVE_GAME_ROOT / "write-probe",
        powershell_path=WINDOWS_POWERSHELL_PATH,
    )

    assert result.returncode == 2, result.stderr or result.stdout
    payload = parse_result(result)
    assert payload["code"] == "BGSE_E_UNSUPPORTED_HOST"
    assert payload["capabilities"] == {"discovery": "unexecuted"}
    assert_sanitized(result)


def test_rejects_powershell_8_profile_before_path_access() -> None:
    result = run_checker(
        disposable_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=SYNTHETIC_ACTIVE_GAME_ROOT / "write-probe",
        reported_powershell_version="8.0.0",
    )

    assert result.returncode == 2, result.stderr or result.stdout
    payload = parse_result(result)
    assert payload["code"] == "BGSE_E_UNSUPPORTED_HOST"
    assert payload["capabilities"] == {"discovery": "unexecuted"}
    assert_sanitized(result)


def test_accepts_multiple_contained_targets(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    targets = [
        disposable_root / "one.json",
        disposable_root / "nested" / "two.json",
    ]
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=targets,
    )

    assert result.returncode == 0, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_OK"
    assert snapshot_tree(tmp_path) == before
    assert all(not target.exists() for target in targets)
    assert_sanitized(result, active_root, disposable_root, *targets)


def test_accepts_unicode_and_long_synthetic_paths(tmp_path: Path) -> None:
    deep_root = tmp_path
    while len(str(deep_root)) < 280:
        deep_root /= "long-segment-0123456789"
    active_root = deep_root / "synthetic-active-한글"
    disposable_root = deep_root / "synthetic-disposable-한글"
    active_root.mkdir(parents=True)
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    intended_write_path = disposable_root / "nested-출력" / "artifact.json"
    before = snapshot_tree(deep_root)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 0, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_OK"
    assert snapshot_tree(deep_root) == before
    assert not intended_write_path.exists()
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_refuses_child_below_existing_file(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    existing_file = disposable_root / "already-a-file"
    existing_file.write_bytes(b"unchanged")
    intended_write_path = existing_file / "child.json"
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_WRITE_ESCAPE"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_refuses_existing_hard_link_to_active_file(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    active_file = active_root / "active-owned.dat"
    active_file.write_bytes(b"must remain active-owned")
    intended_write_path = disposable_root / "lab-name.dat"
    os.link(active_file, intended_write_path)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_HARD_LINK"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_write_path)


def test_refuses_hard_linked_marker(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    external_marker = active_root / "external-marker.json"
    external_marker.write_text(
        json.dumps(VALID_MARKER, sort_keys=True),
        encoding="utf-8",
        newline="\n",
    )
    os.link(external_marker, disposable_root / MARKER_NAME)
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=disposable_root / "write-probe",
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_HARD_LINK"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, external_marker)


def test_refuses_existing_directory_as_unbounded_write_scope(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    active_root.mkdir()
    disposable_root.mkdir()
    write_valid_marker(disposable_root)
    active_file = active_root / "active-owned.dat"
    active_file.write_bytes(b"must remain active-owned")
    intended_directory = disposable_root / "existing-scope"
    intended_directory.mkdir()
    os.link(active_file, intended_directory / "hidden-hard-link.dat")
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=disposable_root,
        active_root=active_root,
        intended_write_path=intended_directory,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_DIRECTORY_SCOPE"
    assert snapshot_tree(tmp_path) == before
    assert_sanitized(result, active_root, disposable_root, intended_directory)


@pytest.mark.parametrize("aliased_name", ["active", "disposable"])
def test_refuses_reparse_root_without_mutation(
    tmp_path: Path,
    aliased_name: str,
) -> None:
    real_active_root = tmp_path / "real-active"
    real_disposable_root = tmp_path / "real-disposable"
    real_active_root.mkdir()
    real_disposable_root.mkdir()
    write_valid_marker(real_disposable_root)
    alias = tmp_path / f"{aliased_name}-junction"
    target = real_active_root if aliased_name == "active" else real_disposable_root
    create_junction(alias, target)
    active_root = alias if aliased_name == "active" else real_active_root
    disposable_root = alias if aliased_name == "disposable" else real_disposable_root
    intended_write_path = disposable_root / "write-probe"
    before = snapshot_tree(tmp_path)

    try:
        result = run_checker(
            disposable_root=disposable_root,
            active_root=active_root,
            intended_write_path=intended_write_path,
        )
        after = snapshot_tree(tmp_path)
        intended_target_exists = intended_write_path.exists()
    finally:
        os.rmdir(alias)

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REPARSE_POINT"
    assert after == before
    assert not intended_target_exists
    assert_sanitized(result, active_root, disposable_root, target)


def test_refuses_reparse_ancestor_of_disposable_root(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    real_container = tmp_path / "real-container"
    real_disposable_root = real_container / "synthetic-disposable"
    active_root.mkdir()
    real_disposable_root.mkdir(parents=True)
    write_valid_marker(real_disposable_root)
    container_alias = tmp_path / "container-junction"
    create_junction(container_alias, real_container)
    disposable_root = container_alias / real_disposable_root.name
    intended_write_path = disposable_root / "write-probe"
    before = snapshot_tree(tmp_path)

    try:
        result = run_checker(
            disposable_root=disposable_root,
            active_root=active_root,
            intended_write_path=intended_write_path,
        )
        after = snapshot_tree(tmp_path)
        intended_target_exists = intended_write_path.exists()
    finally:
        os.rmdir(container_alias)

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REPARSE_POINT"
    assert after == before
    assert not intended_target_exists
    assert_sanitized(result, active_root, disposable_root, real_container)


def test_refuses_reparse_ancestor_of_intended_write(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active"
    disposable_root = tmp_path / "synthetic-disposable"
    outside_root = tmp_path / "outside"
    active_root.mkdir()
    disposable_root.mkdir()
    outside_root.mkdir()
    write_valid_marker(disposable_root)
    output_alias = disposable_root / "output-junction"
    create_junction(output_alias, outside_root)
    intended_write_path = output_alias / "write-probe"
    before = snapshot_tree(tmp_path)

    try:
        result = run_checker(
            disposable_root=disposable_root,
            active_root=active_root,
            intended_write_path=intended_write_path,
        )
        after = snapshot_tree(tmp_path)
        intended_target_exists = (outside_root / "write-probe").exists()
    finally:
        os.rmdir(output_alias)

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_REPARSE_POINT"
    assert after == before
    assert not intended_target_exists
    assert_sanitized(result, active_root, disposable_root, outside_root)


def test_refuses_short_name_alias_of_active_root(tmp_path: Path) -> None:
    active_root = tmp_path / "synthetic-active-root-with-long-name"
    active_root.mkdir()
    write_valid_marker(active_root)
    short_alias = get_short_path(active_root)
    intended_write_path = short_alias / "write-probe"
    before = snapshot_tree(tmp_path)

    result = run_checker(
        disposable_root=short_alias,
        active_root=active_root,
        intended_write_path=intended_write_path,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_ACTIVE_GAME_ROOT"
    assert snapshot_tree(tmp_path) == before
    assert not intended_write_path.exists()
    assert_sanitized(result, active_root, short_alias)
