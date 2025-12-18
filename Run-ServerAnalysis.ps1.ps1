# Load dependencies and analysis helper
if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
}
. (Join-Path $PSScriptRoot 'src\Analyze-IpExpressionFile.ps1')

# Logger setup
$logPath = Join-Path $PSScriptRoot "logs\analyze-allservers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new("Warn", $true, $logPath)

# Define input/output folders
$inputFolder  = Join-Path $PSScriptRoot 'exports'
$outputFolder = Join-Path $PSScriptRoot 'reports'

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Find input files to analyze
$matchingFiles = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File

if ($matchingFiles.Count -eq 0) {
    Write-Warning "No IPRangeExport files found in $inputFolder"
    return
}

Write-Host "Found $($matchingFiles.Count) file(s) to analyze:"
$matchingFiles | ForEach-Object { Write-Host " - $($_.Name)" }

# Group files by date (YYYY-MM-DD) and process each date in its own reports subfolder
$dateGroups = $matchingFiles | Group-Object {
    if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})') { $matches[1] } else { 'unknown' }
}

foreach ($dg in $dateGroups) {
    $date = $dg.Name
    $dateFolder = Join-Path $outputFolder $date
    if (-not (Test-Path $dateFolder)) { New-Item -ItemType Directory -Path $dateFolder | Out-Null }

    Write-Host "Processing date group: $date ($($dg.Count) file(s)) -> reports folder: $dateFolder"

    # Copy and normalize each file into the date folder, then analyze
    foreach ($f in $dg.Group) {
        $dest = Join-Path $dateFolder $f.Name

        try {
            Write-Host "  - Preparing: $($f.Name)"
            # Trim surrounding quotes from each line to normalize CSV content and write into date folder
            $quote = [char]34
            $cleaned = Get-Content $f.FullName | ForEach-Object { $_.Trim($quote) }
            Set-Content -Path $dest -Value $cleaned

            # Run analysis for the copied file, output into the date folder
            Analyze-IpExpressionFile -Path $dest -Logger $logger -OutputFolder $dateFolder
        } catch {
            Write-Warning ([string]::Format("Failed to analyze {0} for date {1}: {2}", $f.Name, $date, $_))
        }
    }
}

Write-Host "`n✅ Analysis complete. Log saved to: $logPath"
