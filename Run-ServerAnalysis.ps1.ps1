# Load dependencies
if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
}
. (Join-Path $PSScriptRoot 'src\Analyze-IpExpressionFile.ps1')

# Logger setup
$logPath = Join-Path $PSScriptRoot "logs\analyze-allservers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new("Warn", $true, $logPath)

# Define folders
$inputFolder  = Join-Path $PSScriptRoot 'exports'
$outputFolder = Join-Path $PSScriptRoot 'reports'

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Get all matching files
$matchingFiles = Get-ChildItem -Path $inputFolder -Filter "*-IPRangeExport.csv" -File

if ($matchingFiles.Count -eq 0) {
    Write-Warning "No IPRangeExport files found in $inputFolder"
    return
}

Write-Host "Found $($matchingFiles.Count) file(s) to analyze:"
$matchingFiles | ForEach-Object { Write-Host " - $($_.Name)" }

# Clean quotes and analyze each file
foreach ($file in $matchingFiles) {
    Write-Host " Processing: $($file.Name)"

    # Clean quotes
    $quote = [char]34
    $cleaned = Get-Content $file.FullName | ForEach-Object { $_.Trim($quote) }
    Set-Content -Path $file.FullName -Value $cleaned

    # Run analysis
    try {
        Analyze-IpExpressionFile -Path $file.FullName -Logger $logger -OutputFolder $outputFolder
    } catch {
        Write-Warning "Failed to analyze $($file.Name): $_"
    }
}

Write-Host "`n✅ Analysis complete. Log saved to: $logPath"
