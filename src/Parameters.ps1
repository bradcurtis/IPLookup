using namespace System

class LogLevel {
    static [string[]] $Levels = @('Error','Warn','Info','Debug')

    static [bool] Validate([string] $level) {
        return [LogLevel]::Levels -contains $level
    }
}

class Parameters {
    [string] $CsvPath
    [string] $LogLevel
    [bool]   $LogToFile
    [string] $LogFilePath

    Parameters([string] $csvPath, [string] $logLevel = 'Info', [bool] $logToFile = $false, [string] $logFilePath = '') {
        if (-not [LogLevel]::Validate($logLevel)) {
            throw [System.ArgumentException] "Invalid LogLevel '$logLevel'. Allowed: Error, Warn, Info, Debug"
        }
        if ([string]::IsNullOrWhiteSpace($csvPath)) {
            throw [System.ArgumentException] "CsvPath must be provided."
        }
        $this.CsvPath    = $csvPath
        $this.LogLevel   = $logLevel
        $this.LogToFile  = $logToFile
        $this.LogFilePath = $logFilePath
    }
}