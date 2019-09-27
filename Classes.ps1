using namespace System.Management.Automation
using namespace System.IO
using namespace System.Text
using namespace System
Write-Verbose "Creating Classes"

class JenkinsBrowserLog {
    [ValidateNotNullOrEmpty()]
    [regex]$ParsePattern = "^(?<datetime>(?<day_name>[SMTWF][a-z]{2})\s(?<month_name>[JFMASOND][a-z]{2}))\s(?<day>\d+)\s(?<time>(?<hour>\d+):(?<minute>\d+):(?<second>\d+)\s(?<timezone>[A-Z]{3})\s(?<year>\d{4}))\s(?<severity>[A-Z]+)\s(?<message>.*)$"
    [ValidateNotNullOrEmpty()]
    [uri]$Link
    hidden [string]$_content
    JenkinsBrowserLog([uri]$Link) {
        $this.Link = $Link
        $this | Add-Member -MemberType ScriptProperty -Name Content -Value {
            if (!$this._content) {
                $this._content = Invoke-WebRequest $Link | Select-Object Content
            }
            return $this._content
        }
    }
}

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

class FuturePathTransformAttribute : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( $inputData -is [string] -and -NOT [string]::IsNullOrWhiteSpace( $inputData )) {
            return ([scriptblock] {
                    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputData)
                })
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

class DriveMapPair {
    [IO.DirectoryInfo] $UncPath;
    [DriveInfo] $DrivePath;
    [string] $Name

    DriveMapPair([IO.DirectoryInfo]$UncPath, [DriveInfo]$DrivePath) {
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
