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

# Iterate files, normalize quotes then run the analyzer for each
foreach ($file in $matchingFiles) {
    Write-Host " Processing: $($file.Name)"

    # Trim surrounding quotes from each line to normalize CSV content
    $quote = [char]34
    $cleaned = Get-Content $file.FullName | ForEach-Object { $_.Trim($quote) }
    Set-Content -Path $file.FullName -Value $cleaned

    # Run analysis and handle any per-file errors gracefully
    try {
        Analyze-IpExpressionFile -Path $file.FullName -Logger $logger -OutputFolder $outputFolder
    } catch {
        Write-Warning "Failed to analyze $($file.Name): $_"
    }
}

Write-Host "`n✅ Analysis complete. Log saved to: $logPath"
