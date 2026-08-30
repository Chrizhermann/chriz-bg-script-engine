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

function Test-DecisionRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Sections
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add("Missing file: $Path")
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch '(?m)^\*\*Status:\*\*\s+\S') {
        $errors.Add("Missing or empty status: $Path")
    }

    foreach ($section in $Sections) {
        $escaped = [regex]::Escape($section)
        $pattern = "(?ms)^## $escaped\s*\r?\n(?<body>.*?)(?=^## |\z)"
        $match = [regex]::Match($content, $pattern)
        if (-not $match.Success) {
            $errors.Add("Missing section '$section': $Path")
            continue
        }

        if ([string]::IsNullOrWhiteSpace($match.Groups['body'].Value)) {
            $errors.Add("Empty section '$section': $Path")
        }
    }
}

foreach ($adrName in $adrNames) {
    Test-DecisionRecord -Path (Join-Path $decisionRoot $adrName) -Sections $adrSections
}

$gatePath = Join-Path $decisionRoot 'gates/G0-charter.md'
Test-DecisionRecord -Path $gatePath -Sections $gateSections

if ($errors.Count -gt 0) {
    Write-Output "G0 decision validation failed with $($errors.Count) error(s):"
    foreach ($validationError in $errors) {
        Write-Output "  - $validationError"
    }
    exit 1
}

Write-Output 'G0 decision validation passed: all required records and sections are present.'
