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
$powerShellPath = (Get-Process -Id $PID).Path
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempPrefix = $tempBase.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$tempRoot = Join-Path $tempBase "bgse-g0-line-endings-$([guid]::NewGuid().ToString('N'))"
$tempRoot = [System.IO.Path]::GetFullPath($tempRoot)

if (-not $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe test fixture path outside the OS temp directory: $tempRoot"
}

function Copy-TestRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    [void][System.IO.Directory]::CreateDirectory($Destination)
    foreach ($directoryName in @('docs', 'scripts')) {
        Copy-Item -LiteralPath (Join-Path $repositoryPath $directoryName) `
            -Destination $Destination -Recurse
    }
}

function Set-CheckoutLineEndings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateSet('LF', 'CRLF')]
        [string]$Style
    )

    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $textFiles = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
        $_.Extension -cin @('.json', '.md', '.ps1')
    }

    foreach ($textFile in $textFiles) {
        $content = [System.IO.File]::ReadAllText($textFile.FullName)
        $lfContent = $content.Replace("`r`n", "`n").Replace("`r", "`n")
        $renderedContent = if ($Style -ceq 'CRLF') {
            $lfContent.Replace("`n", "`r`n")
        }
        else {
            $lfContent
        }
        [System.IO.File]::WriteAllText($textFile.FullName, $renderedContent, $utf8WithoutBom)
    }
}

function Assert-ProbeLineEndings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [ValidateSet('LF', 'CRLF')]
        [string]$Style
    )

    $probePath = Join-Path $Root 'docs/decisions/gates/G0-charter.md'
    $bytes = [System.IO.File]::ReadAllBytes($probePath)
    $lfCount = 0
    $crlfCount = 0
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 10) {
            $lfCount++
            if ($index -gt 0 -and $bytes[$index - 1] -eq 13) {
                $crlfCount++
            }
        }
    }

    if ($lfCount -eq 0) {
        throw "Line-ending probe contains no line feeds: $probePath"
    }
    if ($Style -ceq 'LF' -and $crlfCount -ne 0) {
        throw "LF fixture unexpectedly contains $crlfCount CRLF sequences: $probePath"
    }
    if ($Style -ceq 'CRLF' -and $crlfCount -ne $lfCount) {
        throw "CRLF fixture has LF=$lfCount but CRLF=${crlfCount}: $probePath"
    }
}

function Assert-GitHead {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $insideWorkTree = & git -C $Root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $insideWorkTree -cne 'true') {
        throw "Line-ending fixture is not a Git worktree: $Root"
    }

    & git -C $Root rev-parse --verify --quiet HEAD 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Line-ending fixture has no committed HEAD: $Root"
    }
}

function Initialize-TestRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    & git -C $Root init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to initialize line-ending fixture repository: $Root"
    }

    & git -C $Root -c core.autocrlf=false add --all
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stage line-ending fixture repository: $Root"
    }

    $disabledHooksPath = Join-Path $Root '.git/disabled-hooks'
    [void][System.IO.Directory]::CreateDirectory($disabledHooksPath)
    & git -C $Root `
        -c 'user.name=G0 Line Ending Test' `
        -c 'user.email=g0-line-endings@example.invalid' `
        -c commit.gpgsign=false `
        -c "core.hooksPath=$disabledHooksPath" `
        commit --quiet -m 'test: create line-ending fixture HEAD'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to commit line-ending fixture repository: $Root"
    }
}

function Invoke-LineEndingCase {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('LF', 'CRLF')]
        [string]$Style
    )

    $caseRoot = Join-Path $tempRoot $Style.ToLowerInvariant()
    Copy-TestRepository -Destination $caseRoot
    Set-CheckoutLineEndings -Root $caseRoot -Style $Style
    Initialize-TestRepository -Root $caseRoot
    Assert-GitHead -Root $caseRoot
    Assert-ProbeLineEndings -Root $caseRoot -Style $Style

    $validatorPath = Join-Path $caseRoot 'scripts/validate-g0-decisions.ps1'
    $validatorOutput = @(
        & $powerShellPath -NoProfile -File $validatorPath -RepositoryRoot $caseRoot 2>&1
    )
    $validatorExitCode = $LASTEXITCODE
    if ($validatorExitCode -ne 0) {
        $renderedOutput = $validatorOutput -join [Environment]::NewLine
        throw "G0 decision validator failed for $Style checkout (exit $validatorExitCode):`n$renderedOutput"
    }
    if (($validatorOutput -join "`n") -notmatch
        'Task 1 decision-record structure validation passed') {
        throw "G0 decision validator did not report success for $Style checkout"
    }

    Write-Output "G0 decision validator passed for $Style checkout."
}

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    Invoke-LineEndingCase -Style 'LF'
    Invoke-LineEndingCase -Style 'CRLF'
}
finally {
    if ([System.IO.Directory]::Exists($tempRoot)) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        if (-not $resolvedTempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing unsafe test fixture cleanup outside the OS temp directory: $resolvedTempRoot"
        }
        foreach ($fixtureItem in Get-ChildItem -LiteralPath $resolvedTempRoot -Recurse -Force) {
            if (($fixtureItem.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                $writableAttributes = $fixtureItem.Attributes -band `
                    (-bnot [System.IO.FileAttributes]::ReadOnly)
                [System.IO.File]::SetAttributes($fixtureItem.FullName, $writableAttributes)
            }
        }
        [System.IO.Directory]::Delete($resolvedTempRoot, $true)
    }
}
