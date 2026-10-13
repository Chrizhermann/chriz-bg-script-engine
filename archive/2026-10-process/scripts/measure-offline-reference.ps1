[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot = '',
    [string]$DestinationRoot = '',
    [string]$OutputAllowanceBytes = '',
    [string]$SafetyReserveBytes = '',
    # Explicit local-only diagnostic mode: stdout may contain a personal path.
    # Capture privately outside the source/destination and never publish that log.
    [switch]$IncludePrivateFailurePath
)

# Deliberately read-only, with or without -WhatIf. No ShouldProcess output or
# mutation branch: this is a measurement, not a provisioning authorization.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$result = [ordered]@{
    schemaVersion = 1
    status = 'refused'
    code = 'BGSE_E_MEASUREMENT'
    writesAuthorized = $false
    runtimeReady = $false
    processCheck = 'unexecuted'
    writableRootAdmission = 'unexecuted'
}
$exitCode = 3
$privateObservation = $null
try {
    if (
        $PSVersionTable.PSEdition -cne 'Core' -or
        $PSVersionTable.PSVersion -lt [version]'7.4' -or
        $PSVersionTable.PSVersion -ge [version]'8.0' -or
        [Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64 -or
        [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -ne [Runtime.InteropServices.Architecture]::X64
    ) {
        $result.code = 'BGSE_E_UNSUPPORTED_HOST'
    }
    else {
        if ($null -eq ('Bgse.Lab.SourceMeasurement' -as [type])) {
            Add-Type -Path (Join-Path $PSScriptRoot 'lib/SourceMeasurement.cs')
        }
        if ($IncludePrivateFailurePath) {
            $privateObservation = [Bgse.Lab.PrivateMeasurementDiagnostic]::new()
            $measurement = [Bgse.Lab.SourceMeasurement]::MeasureWithPrivateDiagnostics(
                $SourceRoot, $DestinationRoot, $OutputAllowanceBytes, $SafetyReserveBytes, $privateObservation
            )
        }
        else {
            $measurement = [Bgse.Lab.SourceMeasurement]::Measure(
                $SourceRoot, $DestinationRoot, $OutputAllowanceBytes, $SafetyReserveBytes
            )
        }
        $result.status = 'observed-read-only'
        $result.code = 'BGSE_MEASUREMENT_ONLY'
        foreach ($property in $measurement.PSObject.Properties) {
            $result[$property.Name] = $property.Value
        }
        $exitCode = 0
    }
}
catch {
    $exception = $_.Exception
    while ($null -ne $exception.InnerException) {
        $exception = $exception.InnerException
    }
    # Never emit an exception message/path. Only these authored refusal codes
    # cross the public boundary; compiler/system errors use the generic code.
    $allowedCodes = @(
        'BGSE_E_PATH_SYNTAX', 'BGSE_E_OVERLAP', 'BGSE_E_DESTINATION_EXISTS',
        'BGSE_E_PATH_ACCESS', 'BGSE_E_REPARSE_POINT', 'BGSE_E_ALIAS',
        'BGSE_E_HARDLINK', 'BGSE_E_STREAMS', 'BGSE_E_ENTRY_TYPE',
        'BGSE_E_SOURCE_CHANGED', 'BGSE_E_SOURCE_MARKER', 'BGSE_E_DESTINATION_CHANGED', 'BGSE_E_CAPACITY', 'BGSE_E_VOLUME'
    )
    if ($exception.GetType().FullName -ceq 'Bgse.Lab.MeasurementRefusal' -and
        $allowedCodes -ccontains $exception.Message) {
        $result.code = $exception.Message
        # Schema 1 additive, optional diagnostics. Reject the entire diagnostic
        # if malformed; never alter the original refusal or expose raw details.
        try {
            $diagnostic = $exception.Diagnostic
            $phases = @('inputs', 'source-ancestors', 'destination-ancestors', 'inventory',
                'inventory-comparison', 'destination-recheck', 'final-identities', 'capacity')
            $operations = @('guard', 'open-metadata', 'open-content', 'query-info', 'query-id',
                'query-final-path', 'enumerate', 'hash-read', 'measurement')
            $kinds = @('guard', 'native-error', 'buffer-limit', 'managed-io', 'unexpected')
            # Read each potentially malformed property once. String coercion is
            # not validation: an object may stringify to a permitted enum while
            # carrying private properties that JSON would otherwise serialize.
            $phaseValue = $diagnostic.phase
            $passValue = $diagnostic.pass
            $operationValue = $diagnostic.operation
            $kindValue = $diagnostic.failureKind
            $errorValue = $diagnostic.nativeError
            $validText = $phaseValue -is [string] -and $operationValue -is [string] -and $kindValue -is [string]
            $validPass = if ($validText -and $phaseValue -ceq 'inventory') {
                $passValue -is [int] -and $passValue -in @(1, 2)
            } else { $null -eq $passValue }
            $validNative = if ($validText -and $kindValue -ceq 'native-error') {
                $errorValue -is [int] -and $errorValue -ge 0
            } else { $null -eq $errorValue }
            if ($validText -and $phases -ccontains $phaseValue -and
                $operations -ccontains $operationValue -and
                $kinds -ccontains $kindValue -and $validPass -and $validNative) {
                $result.diagnostic = [ordered]@{
                    # Publish canonical enum constants, not caller-owned objects.
                    phase = $phases[[Array]::IndexOf($phases, $phaseValue)]
                    pass = if ($null -eq $passValue) { $null } elseif ($passValue -eq 1) { 1 } else { 2 }
                    operation = $operations[[Array]::IndexOf($operations, $operationValue)]
                    failureKind = $kinds[[Array]::IndexOf($kinds, $kindValue)]
                    nativeError = if ($null -eq $errorValue) { $null } else { [int]($errorValue + 0) }
                }
                if ($IncludePrivateFailurePath -and $null -ne $privateObservation -and
                    $result.code -ceq 'BGSE_E_PATH_ACCESS' -and $phaseValue -ceq 'inventory' -and
                    $passValue -in @(1, 2) -and $operationValue -ceq 'open-content' -and
                    $kindValue -ceq 'native-error' -and $errorValue -eq 32) {
                    $attemptedPath = $privateObservation.AttemptedPath
                    if ($attemptedPath -is [string] -and -not [string]::IsNullOrEmpty($attemptedPath)) {
                        $result.privateDiagnostic = [ordered]@{
                            classification = 'private-local-only'
                            attemptedPath = $attemptedPath
                            pathIdentity = 'unverified-at-failed-open'
                            holderAttribution = 'unexecuted'
                        }
                    }
                }
            }
        }
        catch { } # A diagnostic is optional; the refusal is not.
    }
}
# Hidden Windows jobs may inherit a legacy console writer. JSON Unicode escapes
# preserve exact private names without changing any console/app encoding state.
[Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 4 -Compress -EscapeHandling EscapeNonAscii))
exit $exitCode
