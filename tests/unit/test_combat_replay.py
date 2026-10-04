"""Saved scalar decision records replay without a game or executable trace code."""
from __future__ import annotations

import importlib
import json
from pathlib import Path

import pytest

from tools.replay.diff import classify_selection
from tools.replay.replay import ReplayFailure, main, replay_jsonl


ROOT = Path(__file__).resolve().parents[2]


def _fact(source: str, value: object) -> dict:
    return {"source": source, "value": value, "observedAt": 10, "expiresAt": 20,
            "confidence": 1}


def _input() -> dict:
    frame = {"schemaVersion": 1, "sceneKey": "synthetic/scene", "tick": 10,
             "observerKey": "mage/one", "eligibleAllies": [], "actors": [
                 {"key": "mage/one", "visible": True, "detected": True, "facts": {
                     "spellbook": _fact("self", ["SPWI112"]), "auraReady": _fact("self", True),
                     "alive": _fact("self", True), "idle": _fact("self", True),
                     "canAct": _fact("self", True), "silenced": _fact("self", False),
                     "castingFailure": _fact("self", 0)}},
                 {"key": "enemy/one", "visible": True, "detected": True, "facts": {
                     "alive": _fact("sight", True), "position": _fact("sight", {"x": 100, "y": 200}),
                     "range": _fact("sight", 10), "relation": _fact("sight", "enemy"),
                     "lineOfSight": _fact("sight", True)}}]}
    ownership = {"player": False, "hardMode": False, "world": False, "encounter": False,
                 "forced": False, "dialogue": False, "cutscene": False, "staging": False,
                 "imageOwner": False, "alive": True, "active": True, "hostile": True,
                 "actionIdle": True, "auraReady": True, "capable": True, "eligible": True}
    candidates = {"ownership": ownership,
                  "ownershipContext": {"sceneKey": frame["sceneKey"],
                                       "observerKey": frame["observerKey"], "tick": frame["tick"]},
                  "spells": [{"id": "missile", "resource": "SPWI112", "target": "actor",
                              "range": 30, "geometry": "exact", "geometryId": "synthetic/missile",
                              "maxCastingFailure": 0.5, "immunityTags": []}],
                  "targets": ["enemy/one"], "areaChecks": {}}
    profile = {"id": "synthetic/decision", "weights": {"control": 1, "resourceCost": -1,
              "urgency": 0.5}, "nearBestBand": 0, "reactionTicks": 0,
               "commitmentTicks": 0, "maxMemoryAge": 0, "minConfidence": 0}
    return {"frame": frame, "candidates": candidates, "profile": profile,
            "terms": {"missile@enemy/one": {"control": 2, "urgency": 1},
                      "wait": {"resourceCost": 0}, "decline": {"resourceCost": 1}}, "seed": 7}


def _to_lua(runtime, value):
    if isinstance(value, dict):
        table = runtime.table()
        for key, item in value.items():
            table[key] = _to_lua(runtime, item)
        return table
    if isinstance(value, list):
        table = runtime.table()
        for index, item in enumerate(value, 1):
            table[index] = _to_lua(runtime, item)
        return table
    return value


def _from_lua(value, lua_type):
    if lua_type(value) != "table":
        return value
    keys = list(value.keys())
    if all(type(key) is int for key in keys) and set(keys) == set(range(1, len(keys) + 1)):
        return [_from_lua(value[index], lua_type) for index in range(1, len(keys) + 1)]
    return {key: _from_lua(item, lua_type) for key, item in value.items()}


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_saved_decision_roundtrip_and_tamper(tmp_path: Path, backend: str, capsys) -> None:
    lua_module = importlib.import_module(f"lupa.{backend}")
    runtime = lua_module.LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    evaluate = runtime.eval("require('combat-intent.decision').evaluate")
    saved = _from_lua(evaluate(_to_lua(runtime, _input())), lua_module.lua_type)
    path = tmp_path / "decisions.jsonl"
    path.write_text(json.dumps(saved, separators=(",", ":")) + "\n", encoding="utf-8")

    summary = replay_jsonl(path, backend)
    assert summary.row_count == 1
    assert summary.selected_ids == ("missile@enemy/one",)
    assert main([str(path), "--backend", backend]) == 0
    output = capsys.readouterr().out
    assert "replay passed: 1 row(s)" in output and "row 1: missile@enemy/one" in output
    assert classify_selection(summary.selected_ids[0], "missile@enemy/one") == "agree"
    assert classify_selection(summary.selected_ids[0], "wait") == "unresolved"
    assert classify_selection(summary.selected_ids[0], "wait", "intentional-divergence") == "intentional-divergence"
    assert classify_selection(summary.selected_ids[0], "wait", "suspected-upstream-bug") == "suspected-upstream-bug"

    saved["scores"][0]["score"] += 1
    path.write_text(json.dumps(saved) + "\n", encoding="utf-8")
    with pytest.raises(ReplayFailure) as failed:
        replay_jsonl(path, backend)
    assert (failed.value.row_index, failed.value.reason) == (1, "trace-disagreement")

    path.write_text(json.dumps(saved) + "\n{malformed\n", encoding="utf-8")
    with pytest.raises(ReplayFailure) as malformed:
        replay_jsonl(path, backend)
    assert (malformed.value.row_index, malformed.value.reason) == (2, "malformed")
