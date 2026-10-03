param(
    [ValidateSet('unit', 'integration', 'schemas', 'all')]
    [string]$Suite = 'all',
    [string]$Filter,
    [int]$Seed
)

$python = Get-Command python -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $python) {
    [Console]::Error.WriteLine('Python is required for host tests.')
    exit 2
}

$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$arguments = @('-X', 'utf8', (Join-Path $repository 'tools/run_lua_tests.py'), '--suite', $Suite)
if ($PSBoundParameters.ContainsKey('Filter')) {
    $arguments += @('--filter', $Filter)
}
if ($PSBoundParameters.ContainsKey('Seed')) {
    $arguments += @('--seed', $Seed.ToString())
}

& $python.Source @arguments
exit $LASTEXITCODE
