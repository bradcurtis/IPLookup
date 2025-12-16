using namespace System
using namespace System.IO

# Lightweight logger used by scripts and services in this project.
# Supports console output and optional file output with simple rotation.
class Logger {
    [string] $Level
    [bool]   $ToFile
    [string] $FilePath
    [int64]  $MaxSizeBytes = 10MB

    # Map textual level to numeric threshold for comparisons
    hidden [int] MapLevel([string] $level) {
        switch ($level) {
            'Error' { return 1 }
            'Warn'  { return 2 }
            'Info'  { return 3 }
            'Debug' { return 4 }
            default { return 3 }
        }
        return 3
    }

    # Constructor: configure level and optional file logging
    Logger([string] $level = 'Info', [bool] $toFile = $false, [string] $filePath = '') {
        $this.Level    = $level
        $this.ToFile   = $toFile
        $this.FilePath = $filePath

        if ($this.ToFile -and [string]::IsNullOrWhiteSpace($this.FilePath)) {
            throw [System.ArgumentException] "FilePath must be provided when LogToFile is true."
        }

        if ($this.ToFile) {
            # Ensure directory exists for the log file
            $dir = [Path]::GetDirectoryName($this.FilePath)
            if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir | Out-Null
            }
        }
    }

    # Rotate the log file if it exceeds MaxSizeBytes. Keeps implementation
    # simple by renaming the current file with a timestamp suffix.
    hidden [void] RotateLogIfNeeded() {
        if (-not (Test-Path $this.FilePath)) { return }

        $fileInfo = [FileInfo]::new($this.FilePath)
        if ($fileInfo.Length -ge $this.MaxSizeBytes) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $newPath = $this.FilePath -replace '\.log$', "-$timestamp.log"
            Rename-Item -Path $this.FilePath -NewName (Split-Path $newPath -Leaf)
        }
    }

    # Core write method: evaluates threshold and writes to file or host
    hidden [void] Write([string] $level, [string] $message) {
        $threshold = $this.MapLevel($this.Level)
        $current   = $this.MapLevel($level)
        if ($current -le $threshold) {
            $line = "[{0:yyyy-MM-dd HH:mm:ss}] [{1}] {2}" -f (Get-Date), $level, $message

            if ($this.ToFile) {
                $this.RotateLogIfNeeded()
                Add-Content -Path $this.FilePath -Value $line
            } else {
                # Map levels to appropriate host output functions
                switch ($level) {
                    'Error' { Write-Error   $line }
                    'Warn'  { Write-Warning $line }
                    'Info'  { Write-Output  $line }
                    'Debug' { Write-Verbose $line }
                }
            }
        }
    }

    # Convenience wrappers for common log levels
    [void] Error([string] $message) { $this.Write('Error', $message) }
    [void] Warn ([string] $message) { $this.Write('Warn',  $message) }
    [void] Info ([string] $message) { $this.Write('Info',  $message) }
    [void] Debug([string] $message) { $this.Write('Debug', $message) }

    # Helpers used by callers to decide whether expensive operations should run
    [bool] ShouldLogInfo() {
        return $this.MapLevel($this.Level) -ge $this.MapLevel("Info")
    }

    [bool] ShouldLog([string] $level) {
        return $this.MapLevel($this.Level) -ge $this.MapLevel($level)
    }
}
