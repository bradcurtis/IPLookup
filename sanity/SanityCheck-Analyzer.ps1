# SanityCheck-Analyzer.ps1
# Verifies New-IpExpression + Get-NormalizedRange + overlap and suggestion logic

. "..\src\AllClasses.ps1"
. "..\src\Analyze-IpExpressionFile.ps1"  # Assuming you saved the analyzer function here

# Logger setup
$logPath = Join-Path $PSScriptRoot "logs\sanity-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Logger = [Logger]::new("Info", $true, $logPath)

# Test expressions
$tests = @(
    "192.168.1.10",
    "192.168.1.11",
    "192.168.1.12",
    "192.168.1.13",
    "192.168.1.14",
    "192.168.1.15",
    "192.168.1.16",
    "192.168.1.17",
    "192.168.1.18",
    "192.168.1.19",
    "192.168.1.20",
    "192.168.1.21",
    "192.168.1.22",
    "192.168.1.20-192.168.1.25",
    "192.168.1.0/28",
    "10.0.0.1",
    "10.0.0.2",
    "10.0.0.3",
    "10.0.0.4",
    "10.0.0.5",
    "invalid-line-here"
)

# Write test file
$testFile = Join-Path $PSScriptRoot "temp-test.csv"
$tests | Set-Content -Path $testFile -Encoding UTF8

# Run analyzer
Analyze-IpExpressionFile -Path $testFile -Logger $Logger

# Clean up
Remove-Item $testFile -Force
Write-Host "`nSanity check complete. Log written to $logPath"
