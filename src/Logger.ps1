using namespace System
using namespace System.IO

class Logger {
    [string] $Level
    [bool]   $ToFile
    [string] $FilePath

    hidden [int] MapLevel([string] $level) {
        if ($level -eq 'Error') { return 1 }
        elseif ($level -eq 'Warn') { return 2 }
        elseif ($level -eq 'Info') { return 3 }
        elseif ($level -eq 'Debug') { return 4 }
        else { return 3 }
    }

    Logger([string] $level = 'Info', [bool] $toFile = $false, [string] $filePath = '') {
        $this.Level    = $level
        $this.ToFile   = $toFile
        $this.FilePath = $filePath
        if ($this.ToFile -and [string]::IsNullOrWhiteSpace($this.FilePath)) {
            throw [System.ArgumentException] "FilePath must be provided when LogToFile is true."
        }
        if ($this.ToFile) {
            $dir = [Path]::GetDirectoryName($this.FilePath)
            if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir | Out-Null
            }
        }
    }

    hidden [void] Write([string] $level, [string] $message) {
        $threshold = $this.MapLevel($this.Level)
        $current   = $this.MapLevel($level)
        if ($current -le $threshold) {
            $line = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $level, $message
            if ($this.ToFile) {
                Add-Content -Path $this.FilePath -Value $line
            } else {
                if ($level -eq 'Error') { Write-Error $line }
                elseif ($level -eq 'Warn') { Write-Warning $line }
                else { Write-Host $line }
            }
        }
    }

    [void] Error([string] $message) { $this.Write('Error', $message) }
    [void] Warn ([string] $message) { $this.Write('Warn',  $message) }
    [void] Info ([string] $message) { $this.Write('Info',  $message) }
    [void] Debug([string] $message) { $this.Write('Debug', $message) }
}