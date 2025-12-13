# SanityCheck.ps1
# Quick verification of New-IpExpression + Get-NormalizedRange

. ".\src\AllClasses.ps1"

# Create a logger stub
# Set up logger for debug
#$logger = [Logger]::new("Info", $false, "")

#logger for batch runs
$logPath = Join-Path $PSScriptRoot "logs\batch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new("Info", $true, $logPath)

# Test expressions
$tests = @(
    "192.168.1.10",
    "192.168.1.20-192.168.1.25",
    "192.168.2.0/30",
    "10.0.0.0/29",
    "8.8.8.8",
    "invalid-line-here"
)

foreach ($raw in $tests) {
    Write-Host "`n=== Testing '$raw' ==="
    try {
        $expr = New-IpExpression $raw $Logger
        Write-Host "Result type: $($expr.GetType().Name)"
        $range = Get-NormalizedRange $expr $Logger
        if ($range) {
            Write-Host "Normalized range: Start=$($range.Start), End=$($range.End)"
        } else {
            Write-Warning "Normalization failed."
        }
    } catch {
        Write-Warning "Expression '$raw' failed: $_"
    }
}