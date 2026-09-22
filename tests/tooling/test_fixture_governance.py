from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest

from tools.provenance import fixtures
from tools.provenance.fixtures import FixtureRefused, validate_fixture_set


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = Path("docs/provenance/fixture-allowlist.json")


def write_case(root: Path, payload: bytes = b'{"observed":"accepted"}\n') -> dict:
    path = "tests/fixtures/governance/queue-observation.json"
    target = root / path
    target.parent.mkdir(parents=True)
    target.write_bytes(payload)
    return {
        "schemaVersion": 1,
        "entries": [{
            "id": "artifact:synthetic-queue-observation-v1",
            "path": path,
            "sha256": hashlib.sha256(payload).hexdigest(),
            "classification": "redistributable-synthetic-fixture",
            "origin": "original",
            "owner": "Chriz BG Script Engine",
            "source": "Independently authored abstract queue observation; no upstream payload.",
            "purpose": "Distinguish an acceptance observation from completion evidence.",
            "requiredCredit": "Chriz BG Script Engine contributors",
            "redistributionStatus": "redistributable",
            "evidenceLayers": ["evidence:E2"],
            "review": {
                "decision": "approved-for-repository",
                "reviewer": "integration-owner",
                "date": "2026-09-22",
            },
        }],
    }


def test_accepts_reviewed_original_bytes_and_does_not_modify_them(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    path = tmp_path / registry["entries"][0]["path"]
    before = path.read_bytes()
    assert validate_fixture_set(tmp_path, registry) == [registry["entries"][0]["path"]]
    assert path.read_bytes() == before


@pytest.mark.parametrize("classification", [
    "upstream-source", "locally-generated-effective-artifact", "forbidden-packaged-content",
    "short-factual-extract", "generated-fingerprint", "unclassified",
])
def test_held_classes_cannot_be_promoted_by_a_redistributable_label(
    tmp_path: Path, classification: str,
) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["classification"] = classification
    with pytest.raises(FixtureRefused, match="classification"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("origin", ["scs-derived", "game-derived", "upstream", "unknown"])
def test_synthetic_label_does_not_erase_derived_origin(tmp_path: Path, origin: str) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["origin"] = origin
    with pytest.raises(FixtureRefused, match="origin"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("field", ["owner", "source", "purpose", "requiredCredit", "review"])
def test_missing_provenance_is_refused(tmp_path: Path, field: str) -> None:
    registry = write_case(tmp_path)
    del registry["entries"][0][field]
    with pytest.raises(FixtureRefused, match=field):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("status", ["local-only", "reference-only", "conditional", "unreviewed", "forbidden"])
def test_held_distribution_status_is_refused(tmp_path: Path, status: str) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["redistributionStatus"] = status
    with pytest.raises(FixtureRefused, match="redistributionStatus"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("name", ["generated.bcs", "source.ssl", "Baldur.exe", "dialog.tlk", "BALDUR.SAV", "private.log"])
def test_prohibited_payload_names_are_refused_even_when_declared_original(tmp_path: Path, name: str) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["path"] = "tests/fixtures/" + name
    with pytest.raises(FixtureRefused, match="JSON fixtures only"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("path", [
    "../outside.json", "tests/fixtures/../outside.json", "/outside.json",
    "C:/outside.json", "tests\\fixtures\\outside.json", "tests/fixtures/x.json:stream",
    "tests/fixtures/con.json", "tests/fixtures/x./a.json",
])
def test_paths_cannot_escape_or_alias_the_reviewed_tree(tmp_path: Path, path: str) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["path"] = path
    with pytest.raises(FixtureRefused, match="path"):
        validate_fixture_set(tmp_path, registry)


def test_exact_hash_rejects_one_byte_change_and_line_ending_change(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    path = tmp_path / registry["entries"][0]["path"]
    original = path.read_bytes()
    for changed in (original.replace(b"accepted", b"rejected"), original.replace(b"\n", b"\r\n")):
        path.write_bytes(changed)
        with pytest.raises(FixtureRefused, match="digest"):
            validate_fixture_set(tmp_path, registry)


def test_missing_or_unlisted_file_refuses_the_whole_set(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    target = tmp_path / registry["entries"][0]["path"]
    extra = target.with_name("unreviewed.json")
    extra.write_text("{}", encoding="utf-8")
    with pytest.raises(FixtureRefused, match="unlisted"):
        validate_fixture_set(tmp_path, registry)
    extra.unlink()
    target.unlink()
    with pytest.raises(FixtureRefused, match="missing"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("duplicate", ["id", "path"])
def test_case_insensitive_duplicate_ids_and_paths_are_refused(tmp_path: Path, duplicate: str) -> None:
    registry = write_case(tmp_path)
    other = copy.deepcopy(registry["entries"][0])
    if duplicate == "id":
        other["path"] = "tests/fixtures/other.json"
    else:
        other["id"] = "artifact:other-v1"
        other["path"] = other["path"].upper()
    registry["entries"].append(other)
    with pytest.raises(FixtureRefused, match="duplicate"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("payload", [
    b'TLK V1  synthetic-header-only',
    b'{"x":1,"x":2}', b'{"x":NaN}',
    b'{"x":1e999}', b'{"x":-1e999}',
    pytest.param(b'{"x":' + b'9' * 5000 + b'}', id="integer-digit-limit"),
    b'{"path":"C:\\\\Users\\\\Example\\\\save"}',
    b'{"path":"/home/example/save"}',
    b'{"path":"\\\\\\\\server\\\\share"}',
])
def test_json_suffix_and_matching_hash_do_not_admit_bad_content(tmp_path: Path, payload: bytes) -> None:
    registry = write_case(tmp_path, payload)
    with pytest.raises(FixtureRefused):
        validate_fixture_set(tmp_path, registry)


def test_review_decision_and_evidence_are_not_runtime_proof(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["review"]["decision"] = "pending"
    with pytest.raises(FixtureRefused, match="review"):
        validate_fixture_set(tmp_path, registry)
    registry["entries"][0]["review"]["decision"] = "approved-for-repository"
    registry["entries"][0]["evidenceLayers"] = ["evidence:E4"]
    with pytest.raises(FixtureRefused, match="evidenceLayers"):
        validate_fixture_set(tmp_path, registry)


def test_hardlinked_fixture_is_refused(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    target = tmp_path / registry["entries"][0]["path"]
    (tmp_path / "external-alias.json").hardlink_to(target)
    with pytest.raises(FixtureRefused, match="linked"):
        validate_fixture_set(tmp_path, registry)


@pytest.mark.parametrize("ending", ["\n", "\r\n"])
def test_registry_parsing_is_line_ending_independent(tmp_path: Path, ending: str) -> None:
    registry = write_case(tmp_path)
    target = tmp_path / REGISTRY
    target.parent.mkdir(parents=True)
    target.write_bytes(json.dumps(registry, indent=2).replace("\n", ending).encode("utf-8"))
    assert validate_fixture_set(tmp_path, fixtures.load_registry(tmp_path))


def test_private_path_in_provenance_is_refused(tmp_path: Path) -> None:
    registry = write_case(tmp_path)
    registry["entries"][0]["source"] = "C:/Users/Example/private-source.json"
    with pytest.raises(FixtureRefused, match="personal/absolute path"):
        validate_fixture_set(tmp_path, registry)


def test_numeric_decode_error_is_sanitized_by_cli(tmp_path: Path, monkeypatch, capsys) -> None:
    registry = write_case(tmp_path, b'{"x":' + b'9' * 5000 + b'}')
    monkeypatch.setattr(fixtures, "__file__", str(tmp_path / "tools/provenance/fixtures.py"))
    target = tmp_path / REGISTRY
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(registry), encoding="utf-8")
    assert fixtures.main() == 1
    captured = capsys.readouterr()
    assert "fixture admission refused" in captured.err
    assert str(tmp_path) not in captured.out + captured.err
    assert "Traceback" not in captured.err


def test_repository_fixture_set_and_portable_eol_contract() -> None:
    registry = json.loads((ROOT / REGISTRY).read_text(encoding="utf-8"))
    assert validate_fixture_set(ROOT, registry)
    attributes = subprocess.run(
        ["git", "check-attr", "eol", "--", *[row["path"] for row in registry["entries"]]],
        cwd=ROOT, text=True, capture_output=True, check=True,
    ).stdout.splitlines()
    assert all(line.endswith(": eol: lf") for line in attributes)


def test_cli_reports_only_relative_paths() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "tools.provenance.fixtures"], cwd=ROOT,
        text=True, capture_output=True,
    )
    assert result.returncode == 0, result.stderr
    assert "fixture admission passed" in result.stdout
    assert str(ROOT) not in result.stdout + result.stderr
