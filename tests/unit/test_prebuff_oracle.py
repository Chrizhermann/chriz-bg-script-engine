"""Exercise the admitted, source-derived generic prep examples as host policy checks."""

import importlib
import json
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]
ORACLE = ROOT / "tests/fixtures/manifests/scs-pilot.synthetic.json"
SPELLS = (
    ("mirror-short-prep", "SPWI212", "DWSW212", "short", "buff/mirror"),
    ("shield-long-prep", "SPWI114", "DWSW114", "long", "buff/shield"),
)


def _lua(runtime, value):
    if isinstance(value, dict):
        table = runtime.table()
        for key, item in value.items():
            table[key] = _lua(runtime, item)
        return table
    if isinstance(value, list):
        table = runtime.table()
        for index, item in enumerate(value, 1):
            table[index] = _lua(runtime, item)
        return table
    return value


def _fact(value):
    return {"source": "self", "value": value, "observedAt": 10, "expiresAt": 11, "confidence": 1}


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_reviewed_generic_preparation_cases(backend):
    fixture = json.loads(ORACLE.read_text(encoding="utf-8"))
    cases = fixture["syntheticCases"]
    assert [case["id"] for case in cases] == [
        "sight-only-short",
        "detection-only-long",
        "configuration-split-short",
        "configuration-split-long",
        "ordered-generic-prep",
        "prep-state-transition",
    ]
    # The sixth case describes separate source-only first-round/rest state writers.
    # Generic preparation.check does not execute that lifecycle.
    assert "expectedSequence" in cases[5] and "expectedSelectedPrep" not in cases[5]

    runtime = importlib.import_module(f"lupa.{backend}").LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    perception = runtime.eval("require('combat-intent.perception')")
    preparation = runtime.eval("require('combat-intent.preparation')")

    for case in cases[:5]:
        inputs = case["inputs"]
        ready = [
            resource
            for ready_flag, resource in (("mirrorReady", "SPWI212"), ("shieldReady", "SPWI114"))
            if inputs[ready_flag]
        ]
        frame = {
            "schemaVersion": 1,
            "sceneKey": "oracle/synthetic",
            "tick": 10,
            "observerKey": "mage/one",
            "eligibleAllies": [],
            "actors": [{
                "key": "mage/one",
                "visible": True,
                "detected": True,
                "facts": {
                    "alive": _fact(inputs["alive"]),
                    "spellbook": _fact(ready),
                    "protections": _fact([]),
                },
            }],
        }
        # Only the selected emitted E1 INI clauses are represented here. These
        # booleans are known outcomes for 2/5 and 2/3, not runtime setting detection.
        assert inputs["magePrepDifficulty"] in (2, 5)
        assert inputs["mageDifficulty"] in (2, 3)
        context = {
            "sceneKey": frame["sceneKey"],
            "observerKey": frame["observerKey"],
            "tick": frame["tick"],
            "enabled": True,
            "seenEnemy": inputs["seeNearestEnemy"],
            "detectedEnemy": inputs["detectNearestEnemy"],
            "nearParty": inputs["anyPlayerWithin20"],
            "offscreenPrep": bool(inputs["offscreenprep"]),
            "hostile": inputs["casterEnemy"],
            "instantPrep": bool(inputs["instantprep"]),
            "shortDifficulty": inputs["magePrepDifficulty"] == 5,
            "longDifficulty": inputs["mageDifficulty"] == 3,
            "accountingReady": True,
        }
        view = perception.build(_lua(runtime, frame))
        actual = []
        for observation_id, original, helper, window, protection in SPELLS:
            spell = {
                "id": observation_id,
                "original": original,
                "helper": helper,
                "window": window,
                "protectionTag": protection,
            }
            result = preparation.check(view, _lua(runtime, spell), _lua(runtime, context))
            action = result[0] if isinstance(result, tuple) else result
            if action is None:
                continue
            actual.append(observation_id)
            assert action["kind"] == "shadow-preparation"
            assert action["resource"] == original
            assert action["delivery"] == helper
            assert action["originalDebit"] == 1
            assert action["continueLegacy"] is True
            assert action["setsInstantPrep"] is False
            assert action["target"]["kind"] == "actor"
            assert action["target"]["key"] == frame["observerKey"]
        assert actual == case["expectedSelectedPrep"], case["id"]
