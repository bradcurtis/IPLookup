# SanityCompareFiles.ps1
# Minimal harness to test CIDR vs equivalent range overlap

. "..\src\AllClasses.ps1"

# Use the real Logger class from Logger.ps1
$Logger = [Logger]::new("Info", $false, "")

# Prepare two temp files
$file1 = Join-Path $env:TEMP "cidr.csv"
$file2 = Join-Path $env:TEMP "range.csv"
$csvPath = Join-Path $env:TEMP "OverlapReport.csv"

"192.168.2.0/30" | Set-Content $file1
"192.168.2.0-192.168.2.3" | Set-Content $file2

# Run comparison
Compare-IpFiles -Files @($file1, $file2) -Logger $Logger -CsvPath $csvPath

# Inspect report
$report = Import-Csv $csvPath
Write-Host "`n=== Report ==="
$report | Format-Table -AutoSize