# Minimal Logger stub
class Logger {
    [void] Info([string] $msg) { Write-Host "INFO: $msg" }
    [void] Warn([string] $msg) { Write-Warning $msg }
}
$Logger = [Logger]::new()

# Load classes
Add-Type -Path "$PSScriptRoot\IpNetworkNative.cs"
. "$PSScriptRoot\IpExpressions.ps1"

# Test cases
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