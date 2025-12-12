using namespace System
using namespace System.IO

class Logger {
    [string] $Level
    [bool]   $ToFile
    [string] $FilePath

   hidden [int] MapLevel([string] $level) {
    switch ($level) {
        'Error' { return 1 }
        'Warn'  { return 2 }
        'Info'  { return 3 }
        'Debug' { return 4 }
        default { return 3 }
    }
    return 3  # <-- ensures all paths return
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
                switch ($level) {
                    'Error' { Write-Error   $line }
                    'Warn'  { Write-Warning $line }
                    'Info'  { Write-Output  $line }   # <-- changed from Write-Host
                    'Debug' { Write-Verbose $line }   # <-- visible with -Verbose
                    
                }
            }
        }
    }

    [void] Error([string] $message) { $this.Write('Error', $message) }
    [void] Warn ([string] $message) { $this.Write('Warn',  $message) }
    [void] Info ([string] $message) { $this.Write('Info',  $message) }
    [void] Debug([string] $message) { $this.Write('Debug', $message) }

    [bool] ShouldLogInfo() {
    return $this.MapLevel($this.Level) -ge $this.MapLevel("Info")
}
[bool] ShouldLog([string] $level) {
    return $this.MapLevel($this.Level) -ge $this.MapLevel($level)
}

}