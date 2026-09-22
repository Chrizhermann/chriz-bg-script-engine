[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot = '',
    [string]$DestinationRoot = '',
    [string]$OutputAllowanceBytes = '',
    [string]$SafetyReserveBytes = ''
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
        $measurement = [Bgse.Lab.SourceMeasurement]::Measure(
            $SourceRoot, $DestinationRoot, $OutputAllowanceBytes, $SafetyReserveBytes
        )
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
        'BGSE_E_SOURCE_CHANGED', 'BGSE_E_DESTINATION_CHANGED', 'BGSE_E_CAPACITY', 'BGSE_E_VOLUME'
    )
    if ($exception.GetType().FullName -ceq 'Bgse.Lab.MeasurementRefusal' -and
        $allowedCodes -ccontains $exception.Message) {
        $result.code = $exception.Message
    }
}
[Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 4 -Compress))
exit $exitCode
