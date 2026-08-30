local Prebuff = {}

function Prebuff.queue(caster, delivery_resref, accounting_spell_id)
    local response = string.format(
        'ReallyForceSpellRES("%s",Myself)\nRemoveSpell(%d)',
        delivery_resref,
        accounting_spell_id
    )
    EEex_Action_QueueResponseStringOnAIBase(response, caster)
end

return Prebuff
