# Run-ConnectorComparisons.ps1
# Compares IP range exports across servers for each connector group

# Load all classes and utilities
if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
}

# Set up logger for debug
#$logger = [Logger]::new("Info", $false, "")

#logger for batch runs
$logPath = Join-Path $PSScriptRoot "logs\batch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new("Warn", $true, $logPath)

# Define input and output folders
$inputFolder  = Join-Path $PSScriptRoot 'exports'
$outputFolder = Join-Path $PSScriptRoot 'reports'

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Clean quotes in-place for all input files
$files = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File
foreach ($file in $files) {
    Write-Host "Cleaning quotes in : $($file.Name)"
    $cleanedLines = Get-Content $file.FullName | ForEach-Object {
        $_.Trim('"')
    }
    Set-Content -Path $file.FullName -Value $cleanedLines
}

# Get all relevant CSV files
$allFiles = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File

# Group files by connector group (e.g., "Exempt-Unrestricted" from filename)
$connectorGroups = $allFiles | Group-Object {
    $base = $_.BaseName
    if ($base -match '^\d{4}-\d{2}-\d{2}-[^-]+-[^-]+-(?<group>.+)-IPRangeExport$') {
        $matches['group']
    } else {
        'Unknown'
    }
}

# Print all connector groups
Write-Host "Found connector groups :"
foreach ($group in $connectorGroups) {
    Write-Host "🔹 Connector: $($group.Name) — $($group.Count) file(s)"
}

# Run comparison for each connector group
foreach ($group in $connectorGroups) {
    $connector = $group.Name
    $files     = $group.Group.FullName
    $csvPath   = Join-Path $outputFolder "$connector-ComparisonReport.csv"

    Write-Host "Comparing connector : $connector ($($files.Count) files)..."

    try {
        Compare-IpFiles -Files $files -Logger $logger -CsvPath $csvPath
        Write-Host "Report saved to : $csvPath"
    } catch {
        Write-Warning "Failed to compare"
    }
}

$reportsFolder = Join-Path $PSScriptRoot 'reports'
$csvFiles = Get-ChildItem -Path $reportsFolder -Filter "*.csv" -File

foreach ($file in $csvFiles) {
    Write-Host "Cleaning file: $($file.Name)"
    $filteredLines = Get-Content $file.FullName | Where-Object { -not ($_ -like '"Exact*') }
    Set-Content -Path $file.FullName -Value $filteredLines
}
