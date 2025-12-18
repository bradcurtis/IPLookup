# Load dependencies and analysis helper
. (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
. (Join-Path $PSScriptRoot 'src\ExportSource.ps1')
. (Join-Path $PSScriptRoot 'src\Analyze-IpExpressionFile.ps1')

# Bootstrap logger (no file) for config loading
$bootstrapLogger = [Logger]::new("Info", $false, "")
$configPath = Join-Path $PSScriptRoot 'project.properties'
$projectConfig = [ProjectConfig]::new($configPath, $bootstrapLogger)

# Resolve folders from config (ExportPath/InputFolder/OutputFolder may be relative)
function Resolve-PathRelativeToRoot {
    param(
        [string]$Root,
        [string]$Path
    )
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Root $Path)
}

$inputFolderPath  = if ($projectConfig.ExportPath  -and $projectConfig.ExportPath.Trim()  -ne '') { $projectConfig.ExportPath }  else { 'exports' }
$outputFolderPath = if ($projectConfig.OutputFolder -and $projectConfig.OutputFolder.Trim() -ne '') { $projectConfig.OutputFolder } else { 'reports' }
$logFolderPath    = if ($projectConfig.LogFolder   -and $projectConfig.LogFolder.Trim()   -ne '') { $projectConfig.LogFolder }   else { 'logs' }

$inputFolder  = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $inputFolderPath
$outputFolder = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $outputFolderPath
$logFolder    = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $logFolderPath

if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder | Out-Null }
if (-not (Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder | Out-Null }
if (-not (Test-Path $inputFolder)) { New-Item -ItemType Directory -Path $inputFolder | Out-Null }

# Logger setup (file-based now that folders are known)
$logPath = Join-Path $logFolder "analyze-allservers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new($projectConfig.LogLevel, $true, $logPath)

# Prepare export source and download (SharePoint or Local)
$exportSourceConfig = @{
    ExportSourceType  = $projectConfig.ExportSourceType
    ExportPath        = $inputFolder
    SharePointUrl     = $projectConfig.SharePointUrl
    LibraryName       = $projectConfig.LibraryName
    LibrarySubFolder  = $projectConfig.LibrarySubFolder
    SharePointTenant  = $projectConfig.SharePointTenant
    SharePointProvider = $projectConfig.SharePointProvider
}
$exportSource = New-ExportSource -Config $exportSourceConfig
Write-Host "Using export source: $($exportSource.Type)"
$exportSource.DownloadExports($inputFolder)


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
