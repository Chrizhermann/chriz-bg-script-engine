-- Independently authored unit helper, not a distributable game/corpus fixture.
return function()
    local resource = {sha256=string.rep('a',64),dependencies={'B-XTEST0.BCS'},
        slots={override='B-XTEST0',class='',race='',general='',default=''},opaque=false}
    local script = {sha256=string.rep('b',64),dependencies={},slots={},opaque=false}
    local manifest = {schemaVersion=1,id='B-/combat/lab-observer',version='1.0.0',
        domain='CombatIntent',tier='C1',profile='current-lab-v1',epoch='stack-1',
        hashAlgorithm='sha256',hashVersion=1,requiredCapabilities={'observe'},
        roots={'B-XTEST1.CRE'},controlClosure={},resources={
            ['B-XTEST1.CRE']=resource,['B-XTEST0.BCS']=script},publicState={},
        fallback={kind='legacy',resources={'B-XTEST0.BCS'}},
        provenance={source='authored',distribution='original'},evidence={'BCS-01:E4'}}
    local copy = function(value)
        local function visit(v)
            if type(v)~='table' then return v end
            local result={};for k,item in pairs(v) do result[k]=visit(item) end;return result
        end
        return visit(value)
    end
    local env={profile=manifest.profile,epoch=manifest.epoch,capabilities={observe=true},
        resources=copy(manifest.resources),publicState={},controlClosure={},closureComplete=true,
        externalControlComplete=true,publicStateComplete=true}
    return manifest,env,{key='lab/mage-1',resource='B-XTEST1.CRE',matches=1,epoch='stack-1'},copy
end
