# Run-ConnectorComparisons.ps1
# Compare IP range exports across servers grouped by connector type.

# Load all classes and utilities (via consolidated loader)
if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
}

# Logger configuration for batch runs (file output)
$logPath = Join-Path $PSScriptRoot "logs\batch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new("Warn", $true, $logPath)

# Define input and output folders
$inputFolder  = Join-Path $PSScriptRoot 'exports'
$outputFolder = Join-Path $PSScriptRoot 'reports'

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Normalize input CSVs by trimming surrounding quotes from each line
$files = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File
foreach ($file in $files) {
    Write-Host "Cleaning quotes in : $($file.Name)"
    $cleanedLines = Get-Content $file.FullName | ForEach-Object {
        $_.Trim('"')
    }
    Set-Content -Path $file.FullName -Value $cleanedLines
}

# Collect files and group them by connector descriptor extracted from the
# filename so we run comparisons per logical connector group.
$allFiles = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File
$connectorGroups = $allFiles | Group-Object {
    $base = $_.BaseName
    if ($base -match '^\d{4}-\d{2}-\d{2}-[^-]+-[^-]+-(?<group>.+)-IPRangeExport$') {
        $matches['group']
    } else {
        'Unknown'
    }
}

Write-Host "Found connector groups :"
foreach ($group in $connectorGroups) {
    Write-Host "🔹 Connector: $($group.Name) — $($group.Count) file(s)"
}

# Run pairwise comparisons for each connector group and create reports
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

# Post-process generated reports to remove Exact marker lines (optional)
$reportsFolder = Join-Path $PSScriptRoot 'reports'
$csvFiles = Get-ChildItem -Path $reportsFolder -Filter "*.csv" -File

foreach ($file in $csvFiles) {
    Write-Host "Cleaning file: $($file.Name)"
    $filteredLines = Get-Content $file.FullName | Where-Object { -not ($_ -like '"Exact*') }
    Set-Content -Path $file.FullName -Value $filteredLines
}
