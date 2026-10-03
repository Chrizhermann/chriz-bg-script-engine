"""Shape checks for the exported Task20 view, not raw perception evidence."""

import copy
import importlib
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, ValidationError


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas/combat-snapshot.schema.json"


def json_shape(value, lua_type):
    """Turn a real Lupa-exported Lua table into JSON-compatible containers."""
    if lua_type(value) != "table":
        return value
    items = list(value.items())
    if items and all(type(key) is int for key, _ in items):
        assert {key for key, _ in items} == set(range(1, len(items) + 1))
        return [json_shape(value[index], lua_type) for index in range(1, len(items) + 1)]
    return {key: json_shape(item, lua_type) for key, item in items}


def exported_view(backend):
    module = importlib.import_module(f"lupa.{backend}")
    runtime = module.LuaRuntime()
    runtime.execute("package.path = ... .. '/?.lua;' .. package.path", ROOT.as_posix())
    result = runtime.execute("""
        local perception=require('combat-intent.perception')
        local function fact(source,value,extra)
            local result={source=source,value=value,observedAt=10,expiresAt=20,confidence=1}
            for key,item in pairs(extra or {}) do result[key]=item end
            return result
        end
        return perception.build({schemaVersion=1,tick=10,observerKey='mage/one',
            eligibleAllies={'ally/one'},actors={
                {key='mage/one',visible=true,detected=true,facts={
                    spellbook=fact('self',{'SPWI112'}),auraReady=fact('self',true)}},
                {key='enemy/one',visible=true,detected=true,facts={
                    position=fact('sight',{x=10,y=20}),alive=fact('sight',true),
                    protections=fact('witnessed',{'mirror-image'},{basis='visible-cast/123'}),
                    resistances=fact('engine-private',{fire=100}),
                    lastCast=fact('shared','SPWI214',{origin='ally/one',
                        basis='observed-cast/3',evidenceSource='witnessed'})}}
            }}):export()
    """)
    return json.loads(json.dumps(json_shape(result, module.lua_type)))


@pytest.mark.parametrize("backend", ["lua51", "luajit21"])
def test_genuine_export_and_malformed_shapes(backend):
    assert SCHEMA_PATH.is_file(), "normalized combat snapshot schema is absent"
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert "Lua" in schema["$comment"] and "shape" in schema["$comment"]
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    exported = exported_view(backend)
    validator.validate(exported)
    assert exported["actors"][1]["facts"]["resistances"] == {
        "kind": "unknown", "reason": "forbidden-engine-knowledge",
    }
    variants = [
        (("objectId",), 42),
        (("tick",), 1.5),
        (("observerKey",), "12345"),
        (("actors", 1, "objectId"), 42),
        (("actors", 1, "facts", "objectId"), 42),
        (("actors", 1, "facts", "resistances", "value"), {"fire": 100}),
        (("actors", 1, "facts", "position", "value", "objectId"), 42),
        (("actors", 1, "facts", "alive", "value"), 1),
        (("actors", 1, "facts", "lastCast", "origin"), 7),
    ]
    for path, value in variants:
        malformed = copy.deepcopy(exported)
        target = malformed
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
        with pytest.raises(ValidationError):
            validator.validate(malformed)
    malformed = copy.deepcopy(exported)
    del malformed["actors"][1]["facts"]["position"]["expiresAt"]
    with pytest.raises(ValidationError):
        validator.validate(malformed)
