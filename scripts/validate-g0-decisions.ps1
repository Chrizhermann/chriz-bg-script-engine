[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$repositoryPath = [System.IO.Path]::GetFullPath($RepositoryRoot)
$decisionRoot = Join-Path $repositoryPath 'docs/decisions'

$adrNames = @(
    '0001-legacy-ownership-by-default.md'
    '0002-separate-combat-intent-and-worldflow.md'
    '0003-weidu-remains-installer-of-record.md'
    '0004-evidence-and-environment-gates.md'
    '0005-scs-provenance-and-reuse.md'
    '0006-runtime-and-host-language-boundaries.md'
    'template.md'
)

$adrSections = @(
    'Decision'
    'Context'
    'Alternatives'
    'Consequences'
    'Compatibility'
    'Evidence'
    'Revisit when'
    'Review date'
)

$gateSections = @(
    'Decision'
    'Entry criteria'
    'Criterion findings'
    'Compatibility'
    'Evidence'
    'Safety boundary'
    'Open blockers'
    'Downstream authorization'
    'Revisit when'
    'Review date'
)

$errors = [System.Collections.Generic.List[string]]::new()
$allowedGateStatuses = @(
    'Pending'
    'Pass'
    'Pass with narrowed scope'
    'Fail'
)

$expectedAdrStatuses = [ordered]@{
    '0001-legacy-ownership-by-default.md' = 'Accepted'
    '0002-separate-combat-intent-and-worldflow.md' = 'Accepted'
    '0003-weidu-remains-installer-of-record.md' = 'Accepted'
    '0004-evidence-and-environment-gates.md' = 'Accepted'
    '0005-scs-provenance-and-reuse.md' = 'Accepted'
    '0006-runtime-and-host-language-boundaries.md' = 'Accepted'
    'template.md' = 'Proposed'
}

function Test-SingleMetadataField {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$ExpectedValue,

        [Parameter()]
        [string[]]$AllowedValues
    )

    $escapedName = [regex]::Escape($Name)
    $matches = [regex]::Matches(
        $Content,
        "(?m)^\*\*${escapedName}:\*\*[ \t]*(?<value>[^\r\n]*?)[ \t]*\r?$"
    )

    if ($matches.Count -ne 1) {
        $errors.Add("Expected exactly one nonempty '$Name' field: $Path")
        return $null
    }

    $value = $matches[0].Groups['value'].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        $errors.Add("Empty '$Name' field: $Path")
        return $null
    }

    if (-not [string]::IsNullOrEmpty($ExpectedValue) -and $value -cne $ExpectedValue) {
        $errors.Add("Expected '$Name' to be '$ExpectedValue', found '$value': $Path")
    }

    if ($null -ne $AllowedValues -and $AllowedValues.Count -gt 0 -and $value -cnotin $AllowedValues) {
        $errors.Add("Unsupported '$Name' value '$value': $Path")
    }

    return $value
}

function Test-DecisionRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Sections,

        [Parameter()]
        [string]$ExpectedStatus,

        [Parameter()]
        [string[]]$AllowedStatuses,

        [Parameter()]
        [switch]$Template,

        [Parameter()]
        [switch]$RequireSafetyFields
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add("Missing file: $Path")
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $status = Test-SingleMetadataField -Content $content -Path $Path -Name 'Status' `
        -ExpectedValue $ExpectedStatus -AllowedValues $AllowedStatuses
    $date = Test-SingleMetadataField -Content $content -Path $Path -Name 'Date'
    $null = Test-SingleMetadataField -Content $content -Path $Path -Name 'Owners'

    if ($Template) {
        if ($date -cne 'YYYY-MM-DD') {
            $errors.Add("Template date must be 'YYYY-MM-DD': $Path")
        }
    }
    elseif ($null -ne $date) {
        $parsedDate = [datetime]::MinValue
        $validDate = [datetime]::TryParseExact(
            $date,
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$parsedDate
        )
        if (-not $validDate) {
            $errors.Add("Decision date must be a valid YYYY-MM-DD date: $Path")
        }
    }

    if (-not $Template -and $content -match '(?im)\b(?:TODO|TBD)\b|\{\{[^}\r\n]+\}\}') {
        $errors.Add("Unresolved placeholder text in decision record: $Path")
    }

    if ($RequireSafetyFields) {
        foreach ($field in @('Unknown-content rule', 'Active-game boundary')) {
            $escapedField = [regex]::Escape($field)
            $fieldMatches = [regex]::Matches(
                $content,
                "(?m)^\*\*${escapedField}:\*\*\s+\S.*$"
            )
            if ($fieldMatches.Count -ne 1) {
                $errors.Add("Expected exactly one nonempty '$field' field: $Path")
            }
        }
    }

    foreach ($section in $Sections) {
        $escaped = [regex]::Escape($section)
        $pattern = "(?ms)^## $escaped\s*\r?\n(?<body>.*?)(?=^## |\z)"
        $matches = [regex]::Matches($content, $pattern)
        if ($matches.Count -ne 1) {
            $errors.Add("Expected exactly one section '$section': $Path")
            continue
        }

        if ([string]::IsNullOrWhiteSpace($matches[0].Groups['body'].Value)) {
            $errors.Add("Empty section '$section': $Path")
        }
    }

    return $status
}

foreach ($adrName in $adrNames) {
    $isTemplate = $adrName -ceq 'template.md'
    $null = Test-DecisionRecord -Path (Join-Path $decisionRoot $adrName) -Sections $adrSections `
        -ExpectedStatus $expectedAdrStatuses[$adrName] -Template:$isTemplate -RequireSafetyFields
}

$gatePath = Join-Path $decisionRoot 'gates/G0-charter.md'
$gateStatus = Test-DecisionRecord -Path $gatePath -Sections $gateSections `
    -AllowedStatuses $allowedGateStatuses

$gateContent = if (Test-Path -LiteralPath $gatePath -PathType Leaf) {
    Get-Content -LiteralPath $gatePath -Raw
}
else {
    ''
}

foreach ($criterion in @(
    'Initial platform'
    'Unique engine namespace'
    'Support tiers'
    'Kill switches'
    'Non-goals'
    'SCS attribution/provenance'
    'Domain separation'
    'Compatibility and safety'
    'Evidence and task map'
)) {
    $escapedCriterion = [regex]::Escape($criterion)
    if ($gateContent -notmatch "(?m)^\| $escapedCriterion \|") {
        $errors.Add("Missing G0 criterion row '$criterion': $gatePath")
    }
}

function Test-RequiredText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $path = Join-Path $repositoryPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing contract file: $path")
        return
    }

    $content = Get-Content -LiteralPath $path -Raw
    if ($content -notmatch $Pattern) {
        $errors.Add("Missing contract '$Description': $path")
    }
}

function Test-ForbiddenText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $path = Join-Path $repositoryPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing contract file: $path")
        return
    }

    $content = Get-Content -LiteralPath $path -Raw
    if ($content -match $Pattern) {
        $errors.Add("Forbidden contract wording '$Description': $path")
    }
}

function Test-ReviewedArtifactAtHead {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$BarrierDescription
    )

    $artifactPath = Join-Path $repositoryPath $RelativePath
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        $errors.Add("Unsatisfied $BarrierDescription; artifact is absent: $artifactPath")
        return
    }

    & git -C $repositoryPath cat-file -e "HEAD`:$RelativePath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        $errors.Add("Unsatisfied $BarrierDescription; artifact is not committed at HEAD: $artifactPath")
    }
}

function Test-ExactSequence {
    param(
        [Parameter()]
        [object[]]$Actual,

        [Parameter()]
        [object[]]$Expected
    )

    $actualItems = @($Actual)
    $expectedItems = @($Expected)
    if ($actualItems.Count -ne $expectedItems.Count) {
        return $false
    }

    for ($index = 0; $index -lt $expectedItems.Count; $index++) {
        if ($actualItems[$index] -cne $expectedItems[$index]) {
            return $false
        }
    }

    return $true
}

$planPath = 'docs/plans/2026-08-27-research-and-vertical-slices.md'
$backlogPath = 'docs/research/research-backlog.md'
$architecturePath = 'docs/plans/2026-08-27-script-engine-architecture-design.md'

Test-RequiredText -RelativePath $planPath `
    -Pattern '(?s)### Task 2:.*?PREP-01-support-baseline\.md.*?PREP-02-evidence-and-provenance-index\.md.*?### Task 3:' `
    -Description 'Task 2 PREP-01 to PREP-02 artifact barrier'
Test-RequiredText -RelativePath $planPath `
    -Pattern '(?s)### Task 4:.*?PREP-01-support-baseline\.md.*?PREP-02-evidence-and-provenance-index\.md.*?### Task 5:' `
    -Description 'Task 4 PREP-01 to PREP-02 artifact barrier'
Test-RequiredText -RelativePath $planPath `
    -Pattern 'interpreter selected by\s+`docs/research/host-runtime-toolchain-decision\.md`' `
    -Description 'Task 13 host interpreter decision artifact'
Test-RequiredText -RelativePath $backlogPath `
    -Pattern '`docs/research/PREP-01-support-baseline\.md`' `
    -Description 'canonical PREP-01 artifact path'
Test-RequiredText -RelativePath 'docs/decisions/0005-scs-provenance-and-reuse.md' `
    -Pattern 'must first be revision-pinned as E1 static evidence' `
    -Description 'future Task 4 E1 pinning requirement'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern '(?m)^### Reproduction commands\s*$' `
    -Description 'namespace scan reproduction commands'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern '(?m)^### Namespace derivation contract\s*$' `
    -Description 'selected namespace derivation contract'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('^B-[KCWX][A-Z0-9]{5}$')) `
    -Description 'exact engine-resource grammar'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('^B-[KCWX][GLA]-[A-Z0-9]+(?:-[A-Z0-9]+)*$')) `
    -Description 'exact private-variable grammar'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('M_B-K.lua')) `
    -Description 'exact EE bootstrap filename'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('_G["B-"]')) `
    -Description 'quoted Lua root key'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('^B-/(kernel\|combat\|worldflow)/[a-z0-9]+(?:-[a-z0-9]+)*$')) `
    -Description 'exact first-party adapter-ID grammar'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('^(kernel\|combat\|worldflow\|synthetic)\.[a-z0-9]+(?:[.-][a-z0-9]+)*$')) `
    -Description 'exact allocation-ledger logical-artifact grammar'
Test-RequiredText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('Every `B-` value is a quoted string')) `
    -Description 'BAF D and WeiDU B- quoting rule'
Test-ForbiddenText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern '\bE3/E4\b' `
    -Description 'conflated E3 synthetic integration and E4 runtime evidence'
Test-ForbiddenText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern '\bE4/G1-G3\b' `
    -Description 'conflated E4 evidence layer and G1-G3 gates'
Test-ForbiddenText -RelativePath 'docs/decisions/gates/G0-charter.md' `
    -Pattern ([regex]::Escape('non-substitutable gates')) `
    -Description 'evidence layers mislabeled as authorization gates'
foreach ($adrName in $adrNames) {
    Test-ForbiddenText -RelativePath (Join-Path 'docs/decisions' $adrName) `
        -Pattern '\bE3/E4\b' `
        -Description 'ambiguous E3/E4 shorthand in Task 1 decision records'
}
Test-ForbiddenText -RelativePath 'docs/research/research-backlog.md' `
    -Pattern '\bE3/E4\b' `
    -Description 'ambiguous E3/E4 shorthand in the research backlog'
Test-ForbiddenText -RelativePath $planPath `
    -Pattern ([regex]::Escape('{engine-prefix}')) `
    -Description 'obsolete mechanical engine-prefix filename interpolation'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/eeex-observer/M_B-K.lua')) `
    -Description 'fixed observer bootstrap path'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/eeex-observer/{allocated-observer-stem}.lua')) `
    -Description 'explicitly allocated observer resource placeholder'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/bridge/{allocated-bridge-script-stem}.baf')) `
    -Description 'explicitly allocated bridge-script resource placeholder'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/bridge/{allocated-dialogue-stem}.d')) `
    -Description 'explicitly allocated dialogue resource placeholder'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/bridge/{allocated-bridge-lua-stem}.lua')) `
    -Description 'explicitly allocated bridge-Lua resource placeholder'
Test-RequiredText -RelativePath $planPath `
    -Pattern ([regex]::Escape('experiments/bridge/setup-bgse-bridge.tp2')) `
    -Description 'host-only bridge installer slug'

Test-ForbiddenText -RelativePath $planPath -Pattern 'strongest current proof' `
    -Description 'scalar strongest-proof label'
Test-ForbiddenText -RelativePath $planPath -Pattern '\ban evidence grade\b' `
    -Description 'singular fixture evidence grade'
Test-ForbiddenText -RelativePath $backlogPath -Pattern "upgrade a spike's evidence grade|upgraded by later E4/E5" `
    -Description 'scalar evidence upgrades'
Test-ForbiddenText -RelativePath $architecturePath -Pattern 'cannot graduate on E0 alone|with evidence level,' `
    -Description 'scalar evidence graduation or level'
Test-ForbiddenText -RelativePath $planPath -Pattern '\bbgse_(?:obs|bridge|dialogue)\b' `
    -Description 'unapproved engine-facing BGSE placeholder'

$taskStatePath = Join-Path $repositoryPath 'docs/plans/2026-08-27-research-and-vertical-slices.md.tasks.json'
if (-not (Test-Path -LiteralPath $taskStatePath -PathType Leaf)) {
    $errors.Add("Missing task state: $taskStatePath")
}
else {
    try {
        $taskState = Get-Content -LiteralPath $taskStatePath -Raw | ConvertFrom-Json
        $task1 = @($taskState.tasks | Where-Object { $_.id -eq 1 })
        $task2 = @($taskState.tasks | Where-Object { $_.id -eq 2 })
        $task3 = @($taskState.tasks | Where-Object { $_.id -eq 3 })
        $task4 = @($taskState.tasks | Where-Object { $_.id -eq 4 })
        $prep01 = 'docs/research/PREP-01-support-baseline.md'
        $prep02 = 'docs/research/PREP-02-evidence-and-provenance-index.md'

        if ($taskState.tasks.Count -ne 41) {
            $errors.Add("Expected 41 plan tasks: $taskStatePath")
        }
        foreach ($task in @($task1[0], $task2[0], $task3[0], $task4[0])) {
            if ($task.status -cnotin @('pending', 'in_progress', 'completed')) {
                $errors.Add("Unsupported task status '$($task.status)' for Task $($task.id): $taskStatePath")
            }
        }
        if ($task1.Count -ne 1) {
            $errors.Add("Expected exactly one Task 1 state: $taskStatePath")
        }
        if ($task2.Count -ne 1 -or
            -not (Test-ExactSequence -Actual @($task2[0].blockedBy) -Expected @(1)) -or
            -not (Test-ExactSequence `
                -Actual @($task2[0].completionBlockedByArtifacts) -Expected @($prep02))) {
            $errors.Add("Task 2 must be blocked by Task 1 and completion-blocked by PREP-02: $taskStatePath")
        }
        if ($task3.Count -ne 1 -or
            -not (Test-ExactSequence -Actual @($task3[0].blockedBy) -Expected @(2)) -or
            $task3[0].requiresUserAuthorization -ne $true) {
            $errors.Add("Task 3 must require separate user authorization: $taskStatePath")
        }
        if ($task4.Count -ne 1 -or
            -not (Test-ExactSequence -Actual @($task4[0].blockedBy) -Expected @(1)) -or
            -not (Test-ExactSequence `
                -Actual @($task4[0].startBlockedByArtifacts) -Expected @($prep01))) {
            $errors.Add("Task 4 must be blocked by Task 1 plus the PREP-01 artifact, not Task 2 completion: $taskStatePath")
        }
        if ($null -eq $taskState.artifactBarrierSemantics.startBlockedByArtifacts -or
            $null -eq $taskState.artifactBarrierSemantics.completionBlockedByArtifacts) {
            $errors.Add("Task state must define normative artifact-barrier semantics: $taskStatePath")
        }
        if ($gateStatus -ceq 'Pending' -and
            ($task1[0].status -cne 'in_progress' -or
             $task2[0].status -cne 'pending' -or
             $task3[0].status -cne 'pending' -or
             $task4[0].status -cne 'pending')) {
            $errors.Add("Pending G0 requires Task 1 in_progress and Tasks 2-4 pending: $taskStatePath")
        }
        if ($gateStatus -cin @('Pass', 'Pass with narrowed scope') -and
            $task1[0].status -cne 'completed') {
            $errors.Add("Passing G0 requires Task 1 completed: $taskStatePath")
        }
        if ($task1[0].status -ceq 'completed' -and
            $gateStatus -cnotin @('Pass', 'Pass with narrowed scope', 'Fail')) {
            $errors.Add("Completed Task 1 requires a terminal G0 decision: $taskStatePath")
        }
        if ($task4[0].status -cne 'pending') {
            Test-ReviewedArtifactAtHead -RelativePath $prep01 `
                -BarrierDescription 'Task 4 PREP-01 start barrier'
        }
        if ($task4[0].status -ceq 'completed') {
            Test-ReviewedArtifactAtHead -RelativePath $prep02 `
                -BarrierDescription 'Task 4 PREP-02 completion requirement'
        }
        if ($task2[0].status -ceq 'completed') {
            Test-ReviewedArtifactAtHead -RelativePath $prep01 `
                -BarrierDescription 'Task 2 PREP-01 completion prerequisite'
            Test-ReviewedArtifactAtHead -RelativePath $prep02 `
                -BarrierDescription 'Task 2 PREP-02 completion barrier'
        }
    }
    catch {
        $errors.Add("Task state is invalid or missing artifact-barrier fields: $taskStatePath ($($_.Exception.Message))")
    }
}

$namespaceValidatorPath = Join-Path $repositoryPath 'scripts/validate-g0-namespace.ps1'
if (-not (Test-Path -LiteralPath $namespaceValidatorPath -PathType Leaf)) {
    $errors.Add("Missing G0 namespace validator: $namespaceValidatorPath")
}
else {
    $namespaceOutput = & $namespaceValidatorPath 2>&1
    $namespaceSucceeded = $?
    if (-not $namespaceSucceeded) {
        $errors.Add("G0 namespace validation failed: $($namespaceOutput -join ' | ')")
    }
}

if ($errors.Count -gt 0) {
    Write-Output "Task 1 decision-record validation failed with $($errors.Count) error(s):"
    foreach ($validationError in $errors) {
        Write-Output "  - $validationError"
    }
    exit 1
}

Write-Output "Task 1 decision-record structure validation passed. G0 gate status: $gateStatus (evaluated separately)."
