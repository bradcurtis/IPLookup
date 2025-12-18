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

# Group files by date (YYYY-MM-DD) then by connector within each date.
$allFiles = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File
$dateGroups = $allFiles | Group-Object {
    $base = $_.BaseName
    if ($base -match '^(\d{4}-\d{2}-\d{2})') { $matches[1] } else { 'Unknown' }
}

Write-Host "Found date groups :"
foreach ($dg in $dateGroups) { Write-Host "🔹 Date: $($dg.Name) — $($dg.Count) file(s)" }

# For each date create a subfolder under reports, copy the exports there,
# then run connector-grouped comparisons and write reports into that date folder.
foreach ($dg in $dateGroups) {
    $date = $dg.Name
    $dateFolder = Join-Path $outputFolder $date
    if (-not (Test-Path $dateFolder)) { New-Item -ItemType Directory -Path $dateFolder | Out-Null }

    # Copy the source export files into the date folder for easy browsing
    foreach ($f in $dg.Group) {
        $dest = Join-Path $dateFolder $f.Name
        Copy-Item -Path $f.FullName -Destination $dest -Force
    }

    # Group the files for this date by connector descriptor
    $connectorGroups = $dg.Group | Group-Object {
        $base = $_.BaseName
        if ($base -match '^\d{4}-\d{2}-\d{2}-[^-]+-[^-]+-(?<group>.+)-IPRangeExport$') {
            $matches['group']
        } else {
            'Unknown'
        }
    }

    foreach ($group in $connectorGroups) {
        $connector = $group.Name
        $files     = $group.Group.FullName
        $csvPath   = Join-Path $dateFolder "$connector-ComparisonReport.csv"

        Write-Host "Comparing date=$date connector=$connector ($($files.Count) files)..."
        try {
            Compare-IpFiles -Files $files -Logger $logger -CsvPath $csvPath
            Write-Host "Report saved to : $csvPath"
        } catch {
            Write-Warning "Failed to compare $connector on $date : $_"
        }
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
