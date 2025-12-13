# Ensure log directory exists
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Create timestamped log file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "TestResults-$timestamp.txt"

# Create temporary script file to run Pester
$tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
Set-Content -Path $tempScript -Value @"
`$env:NO_COLOR = 'true'
Import-Module Pester
. '$PSScriptRoot\src\AllClasses.ps1'
`$config = [PesterConfiguration]::Default
`$config.Run.Path = 'tests'
`$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration `$config
"@ -Encoding UTF8

# Run the temporary script in a new PowerShell process and capture output
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell.exe"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
$process.Start() | Out-Null

# Read output
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

# Clean up temp script
Remove-Item $tempScript -Force

# Strip ANSI escape sequences using literal ESC character
function Remove-Ansi {
    param ([string]$text)
    $esc = [char]27
    $pattern = [string]::Concat($esc, '

\[[0-9;]*[ -/]*[@-~]')
    return [regex]::Replace($text, $pattern, '')
}

# Strip ANSI first
$stdoutClean = Remove-Ansi -text $stdout
$stderrClean = Remove-Ansi -text $stderr

# Trim final 8 lines from stderr (assumes expected error is always last)
$stderrLines = $stderrClean -split "`r?`n"
if ($stderrLines.Count -ge 8) {
    $stderrFiltered = ($stderrLines[0..($stderrLines.Count - 9)] -join "`n")
} else {
    $stderrFiltered = $stderrClean
}

# Combine cleaned and filtered output
$cleanOutput = $stdoutClean + "`n" + $stderrFiltered

# Debug check
if ($cleanOutput -match '

\[EXPECTED\]

') {
    Write-Host "⚠️ Expected error block still present in final output"
} else {
    Write-Host "✅ Expected error block successfully removed"
}

# Confirm log file path is valid
if ([string]::IsNullOrWhiteSpace($logFile)) {
    throw "Log file path is not set. Cannot write output."
}

# Write clean output to file using UTF-8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllBytes($logFile, $utf8NoBom.GetBytes($cleanOutput))
