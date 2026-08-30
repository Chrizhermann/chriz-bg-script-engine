from pathlib import Path

from lupa import lua51


REPO_ROOT = Path(__file__).resolve().parents[4]
MODULE_PATH = REPO_ROOT / "adapters" / "scs" / "prebuff.lua"


def test_queues_native_prebuff_cast_and_one_spell_debit_as_one_response():
    assert MODULE_PATH.is_file(), f"missing Lua module: {MODULE_PATH}"

    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        queued = {}
        caster = {}

        function EEex_Action_QueueResponseStringOnAIBase(response, sprite)
            table.insert(queued, { response = response, sprite = sprite })
        end
        """
    )
    prebuff = lua.execute(MODULE_PATH.read_text(encoding="utf-8"))

    prebuff["queue"](lua.globals().caster, "dwsw305", 2305)

    response, call_count, same_caster = lua.eval(
        "function() "
        "return queued[1].response, #queued, queued[1].sprite == caster "
        "end"
    )()
    assert response == (
        'ReallyForceSpellRES("dwsw305",Myself)\n'
        "RemoveSpell(2305)"
    )
    assert call_count == 1
    assert same_caster is True
