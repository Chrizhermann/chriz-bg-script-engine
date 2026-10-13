[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$errors = [System.Collections.Generic.List[string]]::new()

$resourcePattern = '\AB-[KCWX][A-Z0-9]{5}\z'
$variablePattern = '\AB-[KCWX][GLA]-[A-Z0-9]+(?:-[A-Z0-9]+)*\z'
$adapterPattern = '\AB-/(?:kernel|combat|worldflow)/[a-z0-9]+(?:-[a-z0-9]+)*\z'
$logicalArtifactIdPattern = '\A(?:kernel|combat|worldflow|synthetic)\.[a-z0-9]+(?:[.-][a-z0-9]+)*\z'
$hostEnvironmentPattern = '\ABGSE_[A-Z][A-Z0-9_]*\z'

function Test-Ascii {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    foreach ($character in $Value.ToCharArray()) {
        if ([int]$character -gt 0x7F) {
            return $false
        }
    }

    return $true
}

function Test-CanonicalResourceStem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return (Test-Ascii $Value) -and
        [regex]::IsMatch($Value, $resourcePattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Test-ReleaseResourceStem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return (Test-CanonicalResourceStem $Value) -and $Value[2] -cne 'X'
}

function Test-CanonicalPrivateVariable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('GLOBAL', 'LOCALS', 'AREA')]
        [string]$Scope
    )

    if (-not (Test-Ascii $Value) -or $Value.Length -gt 32 -or
        -not [regex]::IsMatch(
            $Value,
            $variablePattern,
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        return $false
    }

    $expectedScopeMarker = switch ($Scope) {
        'GLOBAL' { 'G' }
        'LOCALS' { 'L' }
        'AREA' { 'A' }
    }

    return $Value[3] -ceq $expectedScopeMarker
}

function Test-ReleasePrivateVariable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('GLOBAL', 'LOCALS', 'AREA')]
        [string]$Scope
    )

    return (Test-CanonicalPrivateVariable $Value $Scope) -and $Value[2] -cne 'X'
}

function Test-CanonicalAdapterId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return (Test-Ascii $Value) -and $Value.Length -le 64 -and
        [regex]::IsMatch($Value, $adapterPattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Test-CanonicalLogicalArtifactId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return (Test-Ascii $Value) -and $Value.Length -le 64 -and
        [regex]::IsMatch(
            $Value,
            $logicalArtifactIdPattern,
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
}

function Test-AllocationSet {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Allocations
    )

    $allocationErrors = [System.Collections.Generic.List[string]]::new()
    $logicalIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $resourceStems = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($allocation in $Allocations) {
        $logicalId = [string]$allocation.logicalId
        $resourceStem = [string]$allocation.resourceStem

        if (-not (Test-CanonicalLogicalArtifactId $logicalId)) {
            $allocationErrors.Add("Invalid logical allocation ID: $logicalId")
        }
        elseif (-not $logicalIds.Add($logicalId)) {
            $allocationErrors.Add("Duplicate logical allocation ID: $logicalId")
        }
        if (-not (Test-CanonicalResourceStem $resourceStem)) {
            $allocationErrors.Add("Invalid allocated resource stem: $resourceStem")
        }
        else {
            $logicalDomain = $logicalId.Split('.')[0]
            $expectedResourceMarker = switch ($logicalDomain) {
                'kernel' { 'K' }
                'combat' { 'C' }
                'worldflow' { 'W' }
                'synthetic' { 'X' }
                default { $null }
            }
            if ($null -ne $expectedResourceMarker -and $resourceStem[2] -cne $expectedResourceMarker) {
                $allocationErrors.Add("Logical/resource domain mismatch: $logicalId -> $resourceStem")
            }
            if (-not $resourceStems.Add($resourceStem)) {
                $allocationErrors.Add("Case-insensitive resource-stem collision: $resourceStem")
            }
        }
    }

    return @($allocationErrors)
}

function Add-ExpectedResult {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Actual,

        [Parameter(Mandatory = $true)]
        [bool]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($Actual -ne $Expected) {
        $errors.Add("Unexpected namespace validation result for $Description")
    }
}

foreach ($resourceStem in @(
    'B-KCORE0'
    'B-CMAGE0'
    'B-WMINI0'
    'B-XPROB0'
)) {
    Add-ExpectedResult -Actual (Test-CanonicalResourceStem $resourceStem) -Expected $true `
        -Description "valid resource '$resourceStem'"
}

foreach ($resourceStem in @(
    'B-KCORE'
    'B-KCORE00'
    'b-KCORE0'
    'B-ACORE0'
    'B-KCOR_0'
    'B-KCOR-0'
    'B-KCORÉ0'
    'BGSECORE'
)) {
    Add-ExpectedResult -Actual (Test-CanonicalResourceStem $resourceStem) -Expected $false `
        -Description "invalid resource '$resourceStem'"
}

$maxVariableToken = 'A' * 27
$overlongVariableToken = 'A' * 28
foreach ($variableCase in @(
    @{ name = 'B-KG-ENABLED'; scope = 'GLOBAL' }
    @{ name = 'B-CL-LEASE'; scope = 'LOCALS' }
    @{ name = 'B-WA-MINI-PHASE'; scope = 'AREA' }
    @{ name = "B-XG-$maxVariableToken"; scope = 'GLOBAL' }
)) {
    Add-ExpectedResult `
        -Actual (Test-CanonicalPrivateVariable $variableCase.name $variableCase.scope) `
        -Expected $true -Description "valid $($variableCase.scope) variable '$($variableCase.name)'"
}

foreach ($variableCase in @(
    @{ name = "B-XG-$overlongVariableToken"; scope = 'GLOBAL' }
    @{ name = 'B-KG-ENABLED'; scope = 'LOCALS' }
    @{ name = 'B-KL-LEASE'; scope = 'GLOBAL' }
    @{ name = 'B-KG-DOUBLE--HYPHEN'; scope = 'GLOBAL' }
    @{ name = 'B-KG-TRAILING-'; scope = 'GLOBAL' }
    @{ name = 'B-KG_HAS-UNDERSCORE'; scope = 'GLOBAL' }
    @{ name = 'b-KG-LOWERCASE'; scope = 'GLOBAL' }
    @{ name = 'BGSE_GLOBAL'; scope = 'GLOBAL' }
)) {
    Add-ExpectedResult `
        -Actual (Test-CanonicalPrivateVariable $variableCase.name $variableCase.scope) `
        -Expected $false -Description "invalid $($variableCase.scope) variable '$($variableCase.name)'"
}

$maxAdapterSlug = 'a' * 54
$overlongAdapterSlug = 'a' * 55
foreach ($adapterId in @(
    'B-/kernel/core'
    'B-/combat/scs-mage-pilot'
    'B-/worldflow/mini-quest'
    "B-/combat/$maxAdapterSlug"
)) {
    Add-ExpectedResult -Actual (Test-CanonicalAdapterId $adapterId) -Expected $true `
        -Description "valid adapter ID '$adapterId'"
}

foreach ($adapterId in @(
    "B-/combat/$overlongAdapterSlug"
    'b-/combat/scs-mage-pilot'
    'B-/Combat/scs-mage-pilot'
    'B-/combat/SCs-mage-pilot'
    'B-/combat/scs--mage'
    'B-/combat/scs_mage'
    'B-/combat/scs/mage'
    'B-/experiment/probe'
    'bgse.combat.mage'
)) {
    Add-ExpectedResult -Actual (Test-CanonicalAdapterId $adapterId) -Expected $false `
        -Description "invalid adapter ID '$adapterId'"
}

Add-ExpectedResult -Actual ('M_B-K.lua' -ceq 'M_B-K.lua') -Expected $true `
    -Description 'canonical bootstrap filename'
foreach ($bootstrapName in @('m_b-k.lua', 'M_B-K0.lua', 'M_BGSE.lua', 'B-KBOOT0.lua')) {
    Add-ExpectedResult -Actual ($bootstrapName -ceq 'M_B-K.lua') -Expected $false `
        -Description "invalid bootstrap filename '$bootstrapName'"
}

$occupiedBootstrapNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
[void]$occupiedBootstrapNames.Add('M_B-K.lua')
Add-ExpectedResult -Actual ($occupiedBootstrapNames.Add('m_b-k.lua')) -Expected $false `
    -Description 'case-insensitive occupied bootstrap collision'

Add-ExpectedResult -Actual ('_G["B-"]' -ceq '_G["B-"]') -Expected $true `
    -Description 'canonical Lua root expression'
foreach ($luaRoot in @('B-', 'B_', '_G.B-', '_G["BGSE"]')) {
    Add-ExpectedResult -Actual ($luaRoot -ceq '_G["B-"]') -Expected $false `
        -Description "invalid Lua root expression '$luaRoot'"
}

foreach ($hostEnvironmentName in @('BGSE_DISPOSABLE_GAME_ROOT', 'BGSE_TEST_SEED')) {
    Add-ExpectedResult `
        -Actual ([regex]::IsMatch($hostEnvironmentName, $hostEnvironmentPattern)) `
        -Expected $true -Description "valid host environment name '$hostEnvironmentName'"
}
foreach ($hostEnvironmentName in @('B-_GAME_ROOT', 'bgse_GAME_ROOT', 'BGSE_')) {
    Add-ExpectedResult `
        -Actual ([regex]::IsMatch($hostEnvironmentName, $hostEnvironmentPattern)) `
        -Expected $false -Description "invalid host environment name '$hostEnvironmentName'"
}

Add-ExpectedResult -Actual ('chriz-bg-script-engine' -ceq 'chriz-bg-script-engine') -Expected $true `
    -Description 'canonical repository and package slug'
foreach ($repositorySlug in @('chriz_bg_script_engine', 'chriz-bg-scriptengine', 'Chriz-bg-script-engine')) {
    Add-ExpectedResult -Actual ($repositorySlug -ceq 'chriz-bg-script-engine') -Expected $false `
        -Description "invalid repository and package slug '$repositorySlug'"
}

Add-ExpectedResult -Actual ('bgse' -ceq 'bgse') -Expected $true `
    -Description 'canonical short host slug'
foreach ($shortHostSlug in @('BGSE', 'bg-se', 'b_gse')) {
    Add-ExpectedResult -Actual ($shortHostSlug -ceq 'bgse') -Expected $false `
        -Description "invalid short host slug '$shortHostSlug'"
}

$maxLogicalArtifactToken = 'a' * 57
$overlongLogicalArtifactToken = 'a' * 58
foreach ($logicalArtifactId in @(
    'kernel.core'
    'combat.mage-pilot'
    'worldflow.mini-dialogue'
    'synthetic.probe'
    "kernel.$maxLogicalArtifactToken"
)) {
    Add-ExpectedResult -Actual (Test-CanonicalLogicalArtifactId $logicalArtifactId) -Expected $true `
        -Description "valid logical-artifact ID '$logicalArtifactId'"
}
foreach ($logicalArtifactId in @(
    "kernel.$overlongLogicalArtifactToken"
    'Kernel.core'
    'kernel.core '
    'kernel.coré'
    'kernel..core'
    'kernel/core'
    'experiment.probe'
)) {
    Add-ExpectedResult -Actual (Test-CanonicalLogicalArtifactId $logicalArtifactId) -Expected $false `
        -Description "invalid logical-artifact ID '$logicalArtifactId'"
}

$validAllocations = @(
    @{ logicalId = 'kernel.core'; resourceStem = 'B-KCORE0'; extension = 'lua' }
    @{ logicalId = 'combat.mage-pilot'; resourceStem = 'B-CMAGE0'; extension = 'lua' }
    @{ logicalId = 'worldflow.mini-dialogue'; resourceStem = 'B-WMINI0'; extension = 'dlg' }
)
Add-ExpectedResult -Actual (@(Test-AllocationSet $validAllocations).Count -eq 0) -Expected $true `
    -Description 'valid reversible allocation set'

$crossExtensionCollision = @(
    @{ logicalId = 'kernel.core'; resourceStem = 'B-KCORE0'; extension = 'lua' }
    @{ logicalId = 'kernel.bridge'; resourceStem = 'B-KCORE0'; extension = 'bcs' }
)
$crossExtensionErrors = @(Test-AllocationSet $crossExtensionCollision)
Add-ExpectedResult `
    -Actual ($crossExtensionErrors -ccontains 'Case-insensitive resource-stem collision: B-KCORE0') `
    -Expected $true `
    -Description 'case-insensitive cross-extension allocation collision'

$duplicateLogicalId = @(
    @{ logicalId = 'kernel.core'; resourceStem = 'B-KCORE0'; extension = 'lua' }
    @{ logicalId = 'kernel.core'; resourceStem = 'B-KCORE1'; extension = 'bcs' }
)
Add-ExpectedResult -Actual (@(Test-AllocationSet $duplicateLogicalId).Count -gt 0) -Expected $true `
    -Description 'duplicate logical allocation ID'

$domainMismatch = @(
    @{ logicalId = 'combat.mage-pilot'; resourceStem = 'B-WMINI0'; extension = 'lua' }
)
$domainMismatchErrors = @(Test-AllocationSet $domainMismatch)
Add-ExpectedResult `
    -Actual ($domainMismatchErrors -ccontains 'Logical/resource domain mismatch: combat.mage-pilot -> B-WMINI0') `
    -Expected $true `
    -Description 'logical-artifact and resource-domain mismatch'

Add-ExpectedResult -Actual (Test-ReleaseResourceStem 'B-XPROB0') -Expected $false `
    -Description 'synthetic-only X resource rejected from release'
Add-ExpectedResult -Actual (Test-ReleaseResourceStem 'B-KCORE0') -Expected $true `
    -Description 'non-X resource accepted by release grammar'
Add-ExpectedResult -Actual (Test-ReleasePrivateVariable 'B-XG-PROBE' 'GLOBAL') -Expected $false `
    -Description 'synthetic-only X variable rejected from release'
Add-ExpectedResult -Actual (Test-ReleasePrivateVariable 'B-KG-ENABLED' 'GLOBAL') -Expected $true `
    -Description 'non-X variable accepted by release grammar'

if ($errors.Count -gt 0) {
    Write-Output "G0 namespace validation failed with $($errors.Count) error(s):"
    foreach ($validationError in $errors) {
        Write-Output "  - $validationError"
    }
    exit 1
}

Write-Output 'G0 namespace grammar and collision vectors passed.'
exit 0
