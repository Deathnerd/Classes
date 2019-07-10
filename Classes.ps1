using namespace System.Management.Automation
using namespace System.IO
using namespace System.Text
using namespace System
Write-Verbose "Creating Classes"
class PathTransformAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( $inputData -is [string] ) {
            if ( -NOT [string]::IsNullOrWhiteSpace( $inputData ) ) {
                $fullPath = Resolve-Path -Path $inputData -ErrorAction SilentlyContinue
                if ( ( $fullPath.count -gt 0 ) -and ( -Not [string]::IsNullOrWhiteSpace( $fullPath ) )) {
                    return $fullPath.Path
                }
            }
        }
        $fullName = $inputData.Fullname
        if ($fullName.count -gt 0) {
            return $fullName
        }

        throw [FileNotFoundException]::new()
    }
}
function Get-ResolvedPath {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

class FuturePathTransformAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( $inputData -is [string] -and -NOT [string]::IsNullOrWhiteSpace( $inputData )) {
            return Get-ResolvedPath $inputData
        }
        throw [ArgumentException]::new($inputData + " needs to be a non-empty string")
    }
}

class EncodingTransformAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if($inputData -is [Encoding]) {
            return $inputData
        }
        if($inputData -isnot [string]) {
            throw [ArgumentException]::new("Argument is not string or [Encoding]")
        }
        try {
            return [Encoding]::$inputData
        } catch {
            throw [ArgumentException]::new("Could not find encoding type $inputData on [System.Text.Encoding]")
        }
    }
}

class ModuleEntry {
    [String] $Name
    [boolean] $MayNeedInstall
    [scriptblock] $Configuration
    ModuleEntry([String]$Name, [Boolean]$MayNeedInstall) {
        $this.Name = $Name
        $this.MayNeedInstall = $MayneedInstall
        $this.Configuration = [scriptblock]::Create("")
    }

    ModuleEntry([String]$Name, [Boolean]$MayNeedInstall, [scriptblock]$Configuration) {
        $this.Name = $Name
        $this.MayNeedInstall = $MayneedInstall
        $this.Configuration = $Configuration
    }
    [boolean] isInstalled() {
        if($this.Name -in $global:InstalledModules) {
            return $true
        } elseif($null -ne (Get-Module -ListAvailable -Name $this.Name)) {
            #This wasn't in cache so update it
            $global:InstalledModules += $this.Name
            $global:InstalledModules | ConvertTo-Json > "$PSScriptRoot\InstalledModules.json"
            return $true
        }
        return $false
    }
}

class NetworkInterfaceIPInfo {
    [string]$Name
    [string]$Description
    [string[]]$IPAddresses
    NetworkInterfaceIPInfo([string]$Name, [string]$Description, [string[]]$IPAddresses) {
        $this.Name = $Name
        $this.Description = $Description
        $this.IPAddresses = $IPAddresses
    }
}

class DriveMapPair {
    [DirectoryInfo] $UncPath;
    [DriveInfo] $DrivePath;
    [string] $Name

    DriveMapPair([DirectoryInfo]$UncPath, [DriveInfo]$DrivePath) {
        $this.DrivePath = $DrivePath
        $this.UncPath = $UncPath
        $this.Name = $UncPath -split "\\" | Select-Object -Last 1
    }

    [string] ReplaceDrivePath([string]$Path) {
        return $Path.Replace($this.DrivePath, $this.UncPath)
    }

    [string] PrependDrivePath([string]$Path) {
        return Join-Path $this.DrivePath $path
    }

    [string] ReplaceUncPath([string]$Path) {
        return $Path.Replace($this.UncPath, $this.DrivePath);
    }

    [string] PrependUncPath([string]$Path) {
        return Join-Path $this.UncPath $path
    }

    [string] ToString() {
        return "$($this.DrivePath) -> $($this.UncPath)"
    }

    [bool] Matches([string]$Path) {
        return $Path.StartsWith($this.DrivePath) -or $Path.StartsWith($this.UncPath)
    }
}
