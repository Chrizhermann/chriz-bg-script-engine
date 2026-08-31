from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CHECKER_PATH = REPOSITORY_ROOT / "scripts" / "check-dev-environment.ps1"
# Inert lexical test data only: never resolve or create this path, and never treat it as the
# user's active-game location.
SYNTHETIC_ACTIVE_GAME_ROOT = Path(r"C:\__BGSE_TEST_ONLY__\active-game")
SYNTHETIC_SECRET = "__BGSE_TEST_SECRET_DO_NOT_DISCLOSE__"


def run_checker(
    *,
    disposable_root: Path,
    active_root: Path,
    intended_write_path: Path,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["BGSE_DISPOSABLE_GAME_ROOT"] = str(disposable_root)
    environment["BGSE_ACTIVE_GAME_ROOT"] = str(active_root)
    environment["BGSE_TEST_SECRET"] = SYNTHETIC_SECRET

    return subprocess.run(
        [
            "pwsh",
            "-NoProfile",
            "-File",
            str(CHECKER_PATH),
            "-IntendedWritePath",
            str(intended_write_path),
        ],
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        check=False,
        encoding="utf-8",
        timeout=30,
    )


def parse_result(result: subprocess.CompletedProcess[str]) -> dict[str, object]:
    return json.loads(result.stdout.lstrip("\ufeff"))


def test_refuses_configured_active_game_root_before_any_write(tmp_path: Path) -> None:
    write_probe = tmp_path / "must-not-exist"

    result = run_checker(
        disposable_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        active_root=SYNTHETIC_ACTIVE_GAME_ROOT,
        intended_write_path=write_probe,
    )

    assert result.returncode == 3, result.stderr or result.stdout
    assert parse_result(result)["code"] == "BGSE_E_ACTIVE_GAME_ROOT"
    assert not write_probe.exists()
    normalized_output = (result.stdout + result.stderr).replace("\\\\", "\\").casefold()
    assert "__bgse_test_only__" not in normalized_output
    assert SYNTHETIC_SECRET.casefold() not in normalized_output
