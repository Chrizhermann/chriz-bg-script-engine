[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$IntendedWritePath = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$NativePathSource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Bgse.Host
{
    public static class NativePath
    {
        public const uint OpenExisting = 3;
        public const uint FileShareRead = 0x00000001;
        public const uint FileShareWrite = 0x00000002;
        public const uint FileShareDelete = 0x00000004;
        public const uint FileFlagOpenReparsePoint = 0x00200000;
        public const uint FileFlagBackupSemantics = 0x02000000;
        public const uint FileAttributeDirectory = 0x00000010;
        public const uint FileAttributeReparsePoint = 0x00000400;
        public const uint FileNameNormalized = 0x00000000;
        public const uint VolumeNameGuid = 0x00000001;
        public const int FileAttributeTagInfo = 9;
        public const int FileIdInfo = 18;

        [StructLayout(LayoutKind.Sequential)]
        public struct FileAttributeTagInformation
        {
            public uint FileAttributes;
            public uint ReparseTag;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FileId128
        {
            public ulong Part0;
            public ulong Part1;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FileIdInformation
        {
            public ulong VolumeSerialNumber;
            public FileId128 FileId;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FileTime
        {
            public uint LowDateTime;
            public uint HighDateTime;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct ByHandleFileInformation
        {
            public uint FileAttributes;
            public FileTime CreationTime;
            public FileTime LastAccessTime;
            public FileTime LastWriteTime;
            public uint VolumeSerialNumber;
            public uint FileSizeHigh;
            public uint FileSizeLow;
            public uint NumberOfLinks;
            public uint FileIndexHigh;
            public uint FileIndexLow;
        }

        [DllImport(
            "kernel32.dll",
            CharSet = CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true)]
        public static extern SafeFileHandle CreateFileW(
            string fileName,
            uint desiredAccess,
            uint shareMode,
            IntPtr securityAttributes,
            uint creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile);

        [DllImport(
            "kernel32.dll",
            CharSet = CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true)]
        public static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle file,
            StringBuilder path,
            uint pathLength,
            uint flags);

        [DllImport(
            "kernel32.dll",
            EntryPoint = "GetFileInformationByHandleEx",
            ExactSpelling = true,
            SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetAttributeTagInfo(
            SafeFileHandle file,
            int informationClass,
            out FileAttributeTagInformation information,
            uint bufferSize);

        [DllImport(
            "kernel32.dll",
            EntryPoint = "GetFileInformationByHandleEx",
            ExactSpelling = true,
            SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetFileIdInfo(
            SafeFileHandle file,
            int informationClass,
            out FileIdInformation information,
            uint bufferSize);

        [DllImport(
            "kernel32.dll",
            ExactSpelling = true,
            SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetFileInformationByHandle(
            SafeFileHandle file,
            out ByHandleFileInformation information);
    }
}
'@

function Write-CheckerResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter()]
        [System.Collections.IDictionary]$Checks,

        [Parameter()]
        [System.Collections.IDictionary]$Capabilities
    )

    $result = [ordered]@{
        schemaVersion = 1
        status = $Status
        code = $Code
        capabilities = if ($null -eq $Capabilities) {
            [ordered]@{ discovery = 'unexecuted' }
        }
        else {
            $Capabilities
        }
    }
    if ($null -ne $Checks) {
        $result.checks = $Checks
    }

    $json = $result | ConvertTo-Json -Compress -Depth 4
    [Console]::Out.WriteLine($json)

    exit $ExitCode
}

function Get-LexicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath -ceq $root) {
        return $fullPath
    }
    return $fullPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-SupportedLocalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path -notmatch '^[A-Za-z]:[\\/]') {
        return $false
    }
    if ($Path.Substring(2).Contains(':')) {
        return $false
    }

    $pathRoot = [System.IO.Path]::GetPathRoot($Path)
    $components = $Path.Substring($pathRoot.Length).Split(
        [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    foreach ($component in $components) {
        if ($component.EndsWith('.') -or $component.EndsWith(' ')) {
            return $false
        }
        if ($component -match '[\x00-\x1F<>"|?*]') {
            return $false
        }
        $deviceBaseName = $component.Split('.')[0]
        if ($deviceBaseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$') {
            return $false
        }
    }
    return $true
}

function Get-BgseApplicationCapability {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Name
    )

    foreach ($candidate in $Name) {
        $command = Get-Command `
            -Name $candidate `
            -CommandType Application `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $command) {
            return [ordered]@{
                status = 'discoverable'
                execution = 'unexecuted'
            }
        }
    }
    return [ordered]@{
        status = 'unavailable'
        execution = 'unexecuted'
    }
}

function Get-BgseCapabilities {
    $vcRuntime = Get-ItemProperty `
        -LiteralPath 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' `
        -ErrorAction SilentlyContinue

    return [ordered]@{
        discovery = 'completed'
        platform = [ordered]@{
            status = 'available'
            execution = 'verified'
            operatingSystem = 'windows'
            osArchitecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            processArchitecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        }
        powerShell = [ordered]@{
            status = 'available'
            execution = 'verified'
            edition = $PSVersionTable.PSEdition
            version = $PSVersionTable.PSVersion.ToString()
        }
        python = Get-BgseApplicationCapability -Name @('python.exe', 'python')
        pytest = Get-BgseApplicationCapability -Name @('pytest.exe', 'pytest')
        lua = Get-BgseApplicationCapability -Name @('lua.exe', 'lua')
        luaJit = Get-BgseApplicationCapability -Name @('luajit.exe', 'luajit')
        weidu = Get-BgseApplicationCapability -Name @('weidu.exe', 'weidu')
        java = Get-BgseApplicationCapability -Name @('java.exe', 'java')
        nearInfinity = Get-BgseApplicationCapability `
            -Name @('NearInfinity.exe', 'NearInfinity')
        vcRuntimeX64 = if ($null -ne $vcRuntime -and $vcRuntime.Installed -eq 1) {
            [ordered]@{
                status = 'metadata-present'
                execution = 'unexecuted'
                version = [string]$vcRuntime.Version
            }
        }
        else {
            [ordered]@{
                status = 'unavailable'
                execution = 'unexecuted'
            }
        }
        lupa = [ordered]@{
            status = 'unassessed'
            execution = 'unexecuted'
        }
        diskRequirement = [ordered]@{
            status = 'unassessed'
            execution = 'unexecuted'
        }
    }
}

function Test-BgseMarkerDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawJson
    )

    $document = $null
    try {
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.AllowTrailingCommas = $false
        $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
        $document = [System.Text.Json.JsonDocument]::Parse($RawJson, $options)
        $root = $document.RootElement
        if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            return $false
        }

        $seenNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $properties = [System.Collections.Generic.Dictionary[
            string,
            System.Text.Json.JsonElement
        ]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $root.EnumerateObject()) {
            if (-not $seenNames.Add($property.Name)) {
                return $false
            }
            $properties.Add($property.Name, $property.Value)
        }

        foreach ($requiredName in @('schemaVersion', 'markerType', 'createdByTask', 'labId')) {
            if (-not $properties.ContainsKey($requiredName)) {
                return $false
            }
        }

        $schemaVersion = $properties['schemaVersion']
        $createdByTask = $properties['createdByTask']
        $markerType = $properties['markerType']
        $labId = $properties['labId']
        if (
            $schemaVersion.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $schemaVersion.GetInt32() -ne 1 -or
            $createdByTask.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $createdByTask.GetInt32() -ne 3 -or
            $markerType.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            $markerType.GetString() -cne 'chriz-bg-script-engine-disposable-lab' -or
            $labId.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or
            -not [System.Text.RegularExpressions.Regex]::IsMatch(
                $labId.GetString(),
                '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
        ) {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Test-PathContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Parent,

        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    if ($Parent.Equals($Candidate, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $prefix = if ($Parent.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $Parent
    }
    else {
        $Parent + [System.IO.Path]::DirectorySeparatorChar
    }
    return $Candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Initialize-BgseNativePath {
    if ($null -eq ('Bgse.Host.NativePath' -as [type])) {
        Add-Type -TypeDefinition $NativePathSource -Language CSharp
    }

    $attributeSize = [Runtime.InteropServices.Marshal]::SizeOf(
        [type][Bgse.Host.NativePath+FileAttributeTagInformation]
    )
    $identitySize = [Runtime.InteropServices.Marshal]::SizeOf(
        [type][Bgse.Host.NativePath+FileIdInformation]
    )
    $linkInformationSize = [Runtime.InteropServices.Marshal]::SizeOf(
        [type][Bgse.Host.NativePath+ByHandleFileInformation]
    )
    if ($attributeSize -ne 8 -or $identitySize -ne 24 -or $linkInformationSize -ne 52) {
        throw 'Unexpected native path information layout.'
    }
}

function Test-PathHasTraversalSegment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $pathRoot = [System.IO.Path]::GetPathRoot($Path)
    $components = $Path.Substring($pathRoot.Length).Split(
        [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    return @($components | Where-Object { $_ -ceq '.' -or $_ -ceq '..' }).Count -gt 0
}

function Get-BgseHandleRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$NoFollow
    )

    $flags = [Bgse.Host.NativePath]::FileFlagBackupSemantics
    if ($NoFollow) {
        $flags = $flags -bor [Bgse.Host.NativePath]::FileFlagOpenReparsePoint
    }
    $shareMode = (
        [Bgse.Host.NativePath]::FileShareRead -bor
        [Bgse.Host.NativePath]::FileShareWrite -bor
        [Bgse.Host.NativePath]::FileShareDelete
    )
    $handle = [Bgse.Host.NativePath]::CreateFileW(
        "\\?\$Path",
        0,
        $shareMode,
        [IntPtr]::Zero,
        [Bgse.Host.NativePath]::OpenExisting,
        $flags,
        [IntPtr]::Zero
    )
    if ($handle.IsInvalid) {
        $handle.Dispose()
        throw 'Unable to open a metadata-only path handle.'
    }

    try {
        $attributeInfo = [Bgse.Host.NativePath+FileAttributeTagInformation]::new()
        if (-not [Bgse.Host.NativePath]::GetAttributeTagInfo(
            $handle,
            [Bgse.Host.NativePath]::FileAttributeTagInfo,
            [ref]$attributeInfo,
            8
        )) {
            throw 'Unable to query path attributes.'
        }

        $identityInfo = [Bgse.Host.NativePath+FileIdInformation]::new()
        if (-not [Bgse.Host.NativePath]::GetFileIdInfo(
            $handle,
            [Bgse.Host.NativePath]::FileIdInfo,
            [ref]$identityInfo,
            24
        )) {
            throw 'Unable to query path identity.'
        }

        $fileInfo = [Bgse.Host.NativePath+ByHandleFileInformation]::new()
        if (-not [Bgse.Host.NativePath]::GetFileInformationByHandle(
            $handle,
            [ref]$fileInfo
        )) {
            throw 'Unable to query hard-link metadata.'
        }

        $pathBuffer = [Text.StringBuilder]::new(32768)
        $pathLength = [Bgse.Host.NativePath]::GetFinalPathNameByHandleW(
            $handle,
            $pathBuffer,
            $pathBuffer.Capacity,
            (
                [Bgse.Host.NativePath]::FileNameNormalized -bor
                [Bgse.Host.NativePath]::VolumeNameGuid
            )
        )
        if ($pathLength -eq 0 -or $pathLength -ge $pathBuffer.Capacity) {
            throw 'Unable to query the final path.'
        }

        return [pscustomobject]@{
            Attributes = [uint32]$attributeInfo.FileAttributes
            FinalPath = $pathBuffer.ToString().TrimEnd('\')
            VolumeSerialNumber = [uint64]$identityInfo.VolumeSerialNumber
            FileIdPart0 = [uint64]$identityInfo.FileId.Part0
            FileIdPart1 = [uint64]$identityInfo.FileId.Part1
            LinkCount = [uint32]$fileInfo.NumberOfLinks
        }
    }
    finally {
        $handle.Dispose()
    }
}

function Test-BgseSameIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Left,

        [Parameter(Mandatory = $true)]
        [object]$Right
    )

    return (
        $Left.VolumeSerialNumber -eq $Right.VolumeSerialNumber -and
        $Left.FileIdPart0 -eq $Right.FileIdPart0 -and
        $Left.FileIdPart1 -eq $Right.FileIdPart1
    )
}

function Get-BgseVerifiedPathRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $noFollowRecord = Get-BgseHandleRecord -Path $Path -NoFollow
    if ($noFollowRecord.Attributes -band [Bgse.Host.NativePath]::FileAttributeReparsePoint) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_REPARSE_POINT' -ExitCode 3
    }

    $followRecord = Get-BgseHandleRecord -Path $Path
    if (-not (Test-BgseSameIdentity -Left $noFollowRecord -Right $followRecord)) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_PATH_CHANGED' -ExitCode 3
    }
    return $followRecord
}

function Get-BgseVerifiedAncestorChain {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $pathRoot = [System.IO.Path]::GetPathRoot($Path)
    $currentPath = $pathRoot
    $components = $Path.Substring($pathRoot.Length).Split(
        [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ),
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
    $records = [Collections.Generic.List[object]]::new()

    foreach ($component in @('') + $components) {
        if ($component.Length -gt 0) {
            $currentPath = Join-Path -Path $currentPath -ChildPath $component
        }
        try {
            $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            break
        }
        $records.Add([pscustomobject]@{
            InputPath = $currentPath
            IsContainer = [bool]$item.PSIsContainer
            Record = Get-BgseVerifiedPathRecord -Path $currentPath
        })
    }

    return $records.ToArray()
}

function Test-BgseIdentityInChain {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Identity,

        [Parameter(Mandatory = $true)]
        [object[]]$Chain
    )

    foreach ($entry in $Chain) {
        if (Test-BgseSameIdentity -Left $Identity -Right $entry.Record) {
            return $true
        }
    }
    return $false
}

try {
    if (
        $PSVersionTable.PSEdition -cne 'Core' -or
        $PSVersionTable.PSVersion -lt [version]'7.4' -or
        $PSVersionTable.PSVersion -ge [version]'8.0' -or
        [Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
        [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [Runtime.InteropServices.Architecture]::X64 -or
        [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -ne [Runtime.InteropServices.Architecture]::X64
    ) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_UNSUPPORTED_HOST' -ExitCode 2
    }

    if (
        [string]::IsNullOrWhiteSpace($env:BGSE_DISPOSABLE_GAME_ROOT) -or
        [string]::IsNullOrWhiteSpace($env:BGSE_ACTIVE_GAME_ROOT)
    ) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_REQUIRED_ENV' -ExitCode 2
    }

    if (
        $IntendedWritePath.Count -eq 0 -or
        @($IntendedWritePath | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
    ) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_INTENDED_WRITE_REQUIRED' -ExitCode 2
    }

    if (
        -not [System.IO.Path]::IsPathFullyQualified($env:BGSE_DISPOSABLE_GAME_ROOT) -or
        -not [System.IO.Path]::IsPathFullyQualified($env:BGSE_ACTIVE_GAME_ROOT)
    ) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_PATH_NOT_ABSOLUTE' -ExitCode 2
    }

    if (
        -not (Test-SupportedLocalPath -Path $env:BGSE_DISPOSABLE_GAME_ROOT) -or
        -not (Test-SupportedLocalPath -Path $env:BGSE_ACTIVE_GAME_ROOT)
    ) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_UNSUPPORTED_PATH' -ExitCode 2
    }

    $disposableRoot = Get-LexicalPath -Path $env:BGSE_DISPOSABLE_GAME_ROOT
    $activeRoot = Get-LexicalPath -Path $env:BGSE_ACTIVE_GAME_ROOT

    if (
        (Test-PathContains -Parent $activeRoot -Candidate $disposableRoot) -or
        (Test-PathContains -Parent $disposableRoot -Candidate $activeRoot)
    ) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_ACTIVE_GAME_ROOT' -ExitCode 3
    }

    foreach ($rootPath in @($disposableRoot, $activeRoot)) {
        $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($rootPath))
        if (-not $drive.IsReady -or $drive.DriveType -ne [System.IO.DriveType]::Fixed) {
            Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_UNSUPPORTED_VOLUME' -ExitCode 2
        }
    }

    Initialize-BgseNativePath
    $disposableChain = @(Get-BgseVerifiedAncestorChain -Path $disposableRoot)
    $activeChain = @(Get-BgseVerifiedAncestorChain -Path $activeRoot)

    $disposableExists = (
        $disposableChain.Count -gt 0 -and
        $disposableChain[-1].IsContainer -and
        $disposableChain[-1].InputPath.Equals(
            $disposableRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    )
    $activeExists = (
        $activeChain.Count -gt 0 -and
        $activeChain[-1].IsContainer -and
        $activeChain[-1].InputPath.Equals(
            $activeRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    )
    if (-not $disposableExists -or -not $activeExists) {
        Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_ROOT_NOT_FOUND' -ExitCode 2
    }

    $disposableRecord = $disposableChain[-1].Record
    $activeRecord = $activeChain[-1].Record
    if (
        (Test-BgseSameIdentity -Left $disposableRecord -Right $activeRecord) -or
        (Test-PathContains -Parent $activeRecord.FinalPath -Candidate $disposableRecord.FinalPath) -or
        (Test-PathContains -Parent $disposableRecord.FinalPath -Candidate $activeRecord.FinalPath) -or
        (Test-BgseIdentityInChain -Identity $activeRecord -Chain $disposableChain) -or
        (Test-BgseIdentityInChain -Identity $disposableRecord -Chain $activeChain)
    ) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_ACTIVE_GAME_ROOT' -ExitCode 3
    }

    $markerPath = Join-Path -Path $disposableRoot -ChildPath '.bgse-disposable-lab.json'
    $markerChain = @(Get-BgseVerifiedAncestorChain -Path $markerPath)
    $markerExists = (
        $markerChain.Count -gt 0 -and
        -not $markerChain[-1].IsContainer -and
        $markerChain[-1].InputPath.Equals(
            $markerPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    )
    if (-not $markerExists) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_MARKER_REQUIRED' -ExitCode 3
    }

    $markerItem = Get-Item -LiteralPath $markerPath -Force -ErrorAction Stop
    if ($markerItem.Length -gt 4096) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_MARKER_INVALID' -ExitCode 3
    }
    if ($markerItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_REPARSE_POINT' -ExitCode 3
    }

    if ($markerChain[-1].Record.LinkCount -gt 1) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_HARD_LINK' -ExitCode 3
    }
    $markerPhysicallyContained = Test-PathContains `
        -Parent $disposableRecord.FinalPath `
        -Candidate $markerChain[-1].Record.FinalPath
    if (
        -not (Test-BgseIdentityInChain -Identity $disposableRecord -Chain $markerChain) -or
        -not $markerPhysicallyContained
    ) {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_MARKER_INVALID' -ExitCode 3
    }

    try {
        $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $markerJson = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($markerPath))
        if ($markerJson.Length -gt 0 -and $markerJson[0] -eq [char]0xFEFF) {
            $markerJson = $markerJson.Substring(1)
        }
        if (-not (Test-BgseMarkerDocument -RawJson $markerJson)) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_MARKER_INVALID' -ExitCode 3
        }
    }
    catch {
        Write-CheckerResult -Status 'refused' -Code 'BGSE_E_MARKER_INVALID' -ExitCode 3
    }

    foreach ($intendedPath in $IntendedWritePath) {
        if (-not [System.IO.Path]::IsPathFullyQualified($intendedPath)) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_WRITE_ESCAPE' -ExitCode 3
        }
        if (Test-PathHasTraversalSegment -Path $intendedPath) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_WRITE_ESCAPE' -ExitCode 3
        }
        if (-not (Test-SupportedLocalPath -Path $intendedPath)) {
            Write-CheckerResult -Status 'invalid' -Code 'BGSE_E_UNSUPPORTED_PATH' -ExitCode 2
        }

        $lexicalIntendedPath = Get-LexicalPath -Path $intendedPath
        if (-not (Test-PathContains -Parent $disposableRoot -Candidate $lexicalIntendedPath)) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_WRITE_ESCAPE' -ExitCode 3
        }
        $intendedChain = @(Get-BgseVerifiedAncestorChain -Path $lexicalIntendedPath)
        $deepestIntendedAncestor = $intendedChain[-1]
        $intendedTargetExists = $deepestIntendedAncestor.InputPath.Equals(
            $lexicalIntendedPath,
            [StringComparison]::OrdinalIgnoreCase
        )
        if ($intendedTargetExists -and $deepestIntendedAncestor.IsContainer) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_DIRECTORY_SCOPE' -ExitCode 3
        }
        if ($intendedTargetExists -and $deepestIntendedAncestor.Record.LinkCount -gt 1) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_HARD_LINK' -ExitCode 3
        }
        $intendedAncestorPhysicallyContained = Test-PathContains `
            -Parent $disposableRecord.FinalPath `
            -Candidate $deepestIntendedAncestor.Record.FinalPath
        if (
            -not (Test-BgseIdentityInChain -Identity $disposableRecord -Chain $intendedChain) -or
            -not $intendedAncestorPhysicallyContained
        ) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_WRITE_ESCAPE' -ExitCode 3
        }
        if (
            -not $deepestIntendedAncestor.IsContainer -and
            -not $deepestIntendedAncestor.InputPath.Equals(
                $lexicalIntendedPath,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            Write-CheckerResult -Status 'refused' -Code 'BGSE_E_WRITE_ESCAPE' -ExitCode 3
        }
    }

    $capabilities = Get-BgseCapabilities
    Write-CheckerResult -Status 'safe' -Code 'BGSE_OK' -ExitCode 0 -Capabilities $capabilities -Checks ([ordered]@{
        configuration = 'verified'
        lexicalIsolation = 'verified'
        reparseIsolation = 'verified'
        physicalIsolation = 'verified'
        localFixedVolumes = 'verified'
        marker = 'verified'
        intendedWrites = 'verified'
    })
}
catch {
    Write-CheckerResult -Status 'error' -Code 'BGSE_E_CHECKER_FAILURE' -ExitCode 4
}
