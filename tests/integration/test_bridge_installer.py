"""Task11: one real WeiDU install/reinstall/uninstall in a synthetic game."""

import os
import re
import shutil
import struct
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "experiments/bridge"
ALLOW = {"b-xbrsc0.bcs", "b-xbrhi0.bcs", "b-xbrdl0.dlg", "b-xbrdg0.lua"}
SOURCE = {"B-XBRSC0.baf", "B-XBRHI0.baf", "B-XBRDL0.d", "B-XBRDG0.lua"}


def _weidu() -> Path:
    binary = Path(os.environ.get("BGSE_WEIDU", ROOT / ".work/task6/effective-pilot-20260927/weidu.exe"))
    assert binary.is_file(), f"WeiDU 24900 binary missing: {binary}"
    return binary


def _fake_game(root: Path, missing_symbol: str | None = None) -> None:
    (root / "data").mkdir(parents=True)
    (root / "override").mkdir()
    (root / "lang/en_us").mkdir(parents=True)
    # Only authored synthetic identifiers. These are the precise compiler inputs.
    trigger_ids = b"IDS V1.0\n0x400F Global(S:Name*,S:Area*,I:Value*)\n0x4023 True()\n"
    action_ids = b"IDS V1.0\n0 NoAction()\n30 SetGlobal(S:Name*,S:Area*,I:Value*)\n36 Continue()\n"
    if missing_symbol != "trigger":
        trigger_ids += b"0x410E EEex_LuaTrigger(S:LuaCode*)\n"
    if missing_symbol != "action":
        action_ids += b"472 EEex_LuaAction(S:LuaCode*)\n"
    resources = [
        ("OH6000", 1010, b"ARE V1.0"),
        ("TRIGGER", 1008, trigger_ids),
        ("ACTION", 1008, action_ids),
        ("OBJECT", 1008, b"IDS V1.0\n1 Myself\n"),
    ]
    table_offset = 0x14
    payload_offset = table_offset + len(resources) * 0x10
    payload = bytearray()
    entries = bytearray()
    for index, (_, kind, data) in enumerate(resources):
        entries += struct.pack("<IIIHH", index, payload_offset + len(payload), len(data), kind, 0)
        payload += data
    bif = b"BIFFV1  " + struct.pack("<III", len(resources), 0, table_offset) + entries + payload
    (root / "data/bgse-test.bif").write_bytes(bif)
    bif_name = b"data\\bgse-test.bif\x00"
    bif_offset = 0x18
    res_offset = bif_offset + 0x0C
    name_offset = res_offset + len(resources) * 0x0E
    key = b"KEY V1  " + struct.pack("<IIII", 1, len(resources), bif_offset, res_offset)
    key += struct.pack("<IIHH", len(bif), name_offset, len(bif_name), 0)
    for index, (name, kind, _) in enumerate(resources):
        key += struct.pack("<8sHI", name.encode("ascii").ljust(8, b"\x00"), kind, index)
    (root / "chitin.key").write_bytes(key + bif_name)
    # One empty TLK entry; WeiDU appends the D source's authored SAY/REPLY text.
    tlk = b"TLK V1  " + struct.pack("<HII", 0, 1, 0x2C) + bytes(0x1A)
    (root / "dialog.tlk").write_bytes(tlk)
    (root / "lang/en_us/dialog.tlk").write_bytes(tlk)


def _snapshot(root: Path) -> dict[str, bytes]:
    return {p.relative_to(root).as_posix().casefold(): p.read_bytes()
            for folder in ("override", "data", "lang")
            for p in (root / folder).rglob("*") if p.is_file()} | {
                "chitin.key": (root / "chitin.key").read_bytes(),
                "dialog.tlk": (root / "dialog.tlk").read_bytes(),
            }


def _invoke(root: Path, *selection: str) -> subprocess.CompletedProcess[str]:
    cmd = [str(_weidu()), "experiments/bridge/setup-bgse-bridge.tp2",
           *selection, "--language", "0", "--use-lang", "en_US",
           "--no-exit-pause", "--quick-log"]
    return subprocess.run(cmd, cwd=root, text=True, encoding="utf-8",
                          errors="replace", stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          timeout=45, check=False)


def _run(root: Path, *selection: str) -> str:
    result = _invoke(root, *selection)
    assert result.returncode == 0, result.stdout
    return result.stdout


def test_bridge_installer_is_reversible(tmp_path: Path) -> None:
    assert (PACKAGE / "setup-bgse-bridge.tp2").is_file(), "Task11 installer is absent"
    assert all((PACKAGE / name).is_file() for name in SOURCE), "Task11 authored sources are absent"
    _fake_game(tmp_path)
    shutil.copytree(PACKAGE, tmp_path / "experiments/bridge")
    before = _snapshot(tmp_path)
    install = _run(tmp_path, "--force-install-list", "0")
    assert "Successfully installed" in install or "SUCCESSFULLY INSTALLED" in install, install
    installed = _snapshot(tmp_path)
    published = {p.name.casefold() for p in (tmp_path / "override").iterdir()}
    assert published == ALLOW
    bcs = installed["override/b-xbrsc0.bcs"]
    higher_bcs = installed["override/b-xbrhi0.bcs"]
    dlg = installed["override/b-xbrdl0.dlg"]
    assert bcs.startswith(b"SC\n")
    assert b"16399 " in bcs and b"16654 " in bcs
    assert b"EEex_LuaTrigger_Object.m_id" in bcs
    assert b"472OB" in bcs and b"EEex_LuaAction_Object.m_id" in bcs
    # Runtime regression: Continue schedules the legacy block before the accepted
    # block's SetGlobal executes. Only the higher-priority handoff may Continue.
    assert b"36OB" not in bcs
    for expression in re.findall(r'EEex_Lua(?:Trigger|Action)\("([^"\n]+)"\)',
                                 (PACKAGE / "B-XBRSC0.baf").read_text(encoding="utf-8")):
        assert b'"' + expression.encode("ascii") + b'"' in bcs
    assert higher_bcs.startswith(b"SC\n") and b"0OB" in higher_bcs and b"36OB" in higher_bcs
    assert dlg.startswith(b"DLG V1.0")
    assert struct.unpack_from("<I", dlg, 0x10)[0] == 2
    assert installed["override/b-xbrdg0.lua"] == (PACKAGE / "B-XBRDG0.lua").read_bytes()
    assert installed["chitin.key"] == before["chitin.key"]
    assert installed["data/bgse-test.bif"] == before["data/bgse-test.bif"]
    assert installed["dialog.tlk"] == before["dialog.tlk"]
    assert installed["lang/en_us/dialog.tlk"] != before["lang/en_us/dialog.tlk"]
    for line in (b"BGSE laboratory: the ordinary dialogue entry was reached.",
                 b"Accept the laboratory check.", b"Decline the laboratory check."):
        assert line in installed["lang/en_us/dialog.tlk"]
    _run(tmp_path, "--force-uninstall-list", "0", "--force-install-list", "0")
    assert _snapshot(tmp_path) == installed
    _run(tmp_path, "--force-uninstall-list", "0")
    uninstalled = _snapshot(tmp_path)
    assert all(not name.startswith("override/") for name in uninstalled)
    assert uninstalled["chitin.key"] == before["chitin.key"]
    assert uninstalled["data/bgse-test.bif"] == before["data/bgse-test.bif"]
    assert uninstalled["dialog.tlk"] == before["dialog.tlk"]
    # WeiDU keeps allocated dialogue strrefs after uninstall.
    assert uninstalled["lang/en_us/dialog.tlk"] == installed["lang/en_us/dialog.tlk"]


@pytest.mark.parametrize("missing_symbol", ["trigger", "action"])
def test_missing_eeex_symbol_prevents_publication(tmp_path: Path, missing_symbol: str) -> None:
    _fake_game(tmp_path, missing_symbol=missing_symbol)
    shutil.copytree(PACKAGE, tmp_path / "experiments/bridge")
    before = _snapshot(tmp_path)
    output = _run(tmp_path, "--force-install-list", "0")
    assert "SKIPPING" in output, output
    assert _snapshot(tmp_path) == before


@pytest.mark.parametrize("collision", sorted(ALLOW))
def test_bridge_publication_collision_fails_before_game_mutation(tmp_path: Path,
                                                                 collision: str) -> None:
    _fake_game(tmp_path)
    shutil.copytree(PACKAGE, tmp_path / "experiments/bridge")
    original = b"BGSE unrelated owner\x00\xff"
    (tmp_path / "override" / collision.upper()).write_bytes(original)
    before = _snapshot(tmp_path)

    result = _invoke(tmp_path, "--force-install-list", "0")

    assert result.returncode != 0, result.stdout
    assert "BGSE bridge publication collision" in result.stdout, result.stdout
    assert collision.upper() in result.stdout, result.stdout
    assert "NOT INSTALLED DUE TO ERRORS" in result.stdout, result.stdout
    assert _snapshot(tmp_path) == before


def test_unknown_override_bytes_survive_install_reinstall_uninstall(tmp_path: Path) -> None:
    _fake_game(tmp_path)
    shutil.copytree(PACKAGE, tmp_path / "experiments/bridge")
    unknown = {
        "ZUNK0001.BCS": b"unknown script\x00\xff",
        "ZUNK0002.DLG": b"unknown dialogue\x01\xfe",
        "ZUNK0003.CRE": b"unknown creature\x02\xfd",
    }
    for name, payload in unknown.items():
        (tmp_path / "override" / name).write_bytes(payload)
    before = _snapshot(tmp_path)

    _run(tmp_path, "--force-install-list", "0")
    installed = _snapshot(tmp_path)
    assert set(installed) - set(before) == {f"override/{name}" for name in ALLOW}
    for path, payload in before.items():
        if path != "lang/en_us/dialog.tlk":
            assert installed[path] == payload, path
    assert installed["lang/en_us/dialog.tlk"] != before["lang/en_us/dialog.tlk"]

    _run(tmp_path, "--force-uninstall-list", "0", "--force-install-list", "0")
    assert _snapshot(tmp_path) == installed

    _run(tmp_path, "--force-uninstall-list", "0")
    uninstalled = _snapshot(tmp_path)
    assert set(uninstalled) == set(before)
    for path, payload in before.items():
        if path != "lang/en_us/dialog.tlk":
            assert uninstalled[path] == payload, path
    # WeiDU retains allocated strings, but no unknown resource byte may change.
    assert uninstalled["lang/en_us/dialog.tlk"] == installed["lang/en_us/dialog.tlk"]
