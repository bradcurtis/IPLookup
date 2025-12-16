class ProjectConfig {
    # Simple project configuration loader that reads key=value pairs
    # (ignoring comments and blank lines) and exposes common settings
    [string] $Environment
    [string] $InputFolder
    [string] $OutputFolder
    [string] $LogFolder
    [string] $LogLevel
    [bool]   $EnableUpload
    [string] $SharePointSite
    [string] $TargetLibrary
    [Logger] $Logger

    ProjectConfig([string] $configPath, [Logger] $Logger) {
        $this.Logger = $Logger
        $this.Logger.Info("Loading config from $configPath")

        if (-not (Test-Path $configPath)) {
            throw "Config file not found: $configPath"
        }

        $dict = @{}
        Get-Content $configPath | ForEach-Object {
            if ($_ -match '^\s*#') { return } # skip comments
            if ($_ -match '^\s*$') { return } # skip blank lines
            $parts = $_ -split '=', 2
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                $dict[$key] = $val
            }
        }

        $this.Environment     = $dict["Environment"]
        $this.InputFolder     = [IO.Path]::GetFullPath((Join-Path (Split-Path $configPath) $dict["InputFolder"]))
        $this.OutputFolder    = [IO.Path]::GetFullPath((Join-Path (Split-Path $configPath) $dict["OutputFolder"]))
        $this.LogFolder       = [IO.Path]::GetFullPath((Join-Path (Split-Path $configPath) $dict["LogFolder"]))
        $this.LogLevel        = $dict["LogLevel"]
        $this.EnableUpload    = [bool]::Parse($dict["EnableUpload"])
        $this.SharePointSite  = $dict["SharePointSite"]
        $this.TargetLibrary   = $dict["TargetLibrary"]

        $this.Logger.Info("Config loaded for environment: $($this.Environment)")
    }
}
