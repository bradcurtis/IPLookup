# Sanity-ExportSource.ps1
# Validates ExportSource helper class functionality

param(
    [string]$TestMode = "Local"  # "Local" or "SharePoint"
)

# Load dependencies
. (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
. (Join-Path $PSScriptRoot '..\src\ExportSource.ps1')

# Instantiate Logger first, then ProjectConfig
$logger = [Logger]::new("Info", $false, "")
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $PSScriptRoot '..\project.properties'
$projectConfig = [ProjectConfig]::new($configPath, $logger)

Write-Host "[TEST] ExportSource Sanity Check"
Write-Host "Mode: $TestMode`n"

# Test 1: Create Local source
Write-Host "[1/5] Testing LocalExportSource..."
try {
    $localConfig = @{
        ExportSourceType = "Local"
        ExportPath = Join-Path $scriptRoot '..\exports'
    }
    Write-Host "  Config: ExportSourceType=$($localConfig.ExportSourceType), ExportPath=$($localConfig.ExportPath)"
    $localSource = New-ExportSource -Config $localConfig
    Write-Host "  [OK] LocalExportSource created successfully"
    Write-Host "    Type: $($localSource.Type), Path: $($localSource.Path)"
} catch {
    Write-Host "  [ERROR] Failed to create LocalExportSource: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Get local export files
Write-Host "`n[2/5] Fetching local export files..."
try {
    $files = $localSource.GetExportFiles()
    Write-Host "  [OK] Found $($files.Count) export file(s)"
    if ($files.Count -gt 0) {
        $files | Select-Object -First 3 | ForEach-Object { Write-Host "    - $($_.Name)" }
    }
} catch {
    Write-Host "  [ERROR] Failed to fetch files: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Local download (no-op)
Write-Host "`n[3/5] Testing LocalExportSource download (should be no-op)..."
try {
    $localSource.DownloadExports("$env:TEMP\test_export")
    Write-Host "  [OK] DownloadExports completed (no-op for local source)"
} catch {
    Write-Host "  [ERROR] DownloadExports failed: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Create SharePoint source (stub)
Write-Host "`n[4/5] Creating SharePointExportSource (stub)..."
try {
    $spConfig = @{
        ExportSourceType = "SharePoint"
        SharePointUrl = "https://fda.sharepoint.com/sites/ODT-EaaS-Team"
        LibraryName = "IP Range Exports"
    }
    $spSource = New-ExportSource -Config $spConfig
    Write-Host "  [OK] SharePointExportSource created successfully"
    Write-Host "    Type: $($spSource.Type), Site: $($spSource.SiteUrl), Library: $($spSource.LibraryName)"
} catch {
    Write-Host "  [ERROR] Failed to create SharePointExportSource: $_" -ForegroundColor Red
    exit 1
}

# Test 5: Validate config integration
Write-Host "`n[5/5] Testing ProjectConfig integration..."
try {
    if (Test-Path $configPath) {
        Write-Host "  [OK] ProjectConfig loaded"
        Write-Host "    ExportSourceType: $($projectConfig.ExportSourceType)"
        Write-Host "    ExportPath: $($projectConfig.ExportPath)"
        if ($projectConfig.SharePointUrl) {
            Write-Host "    SharePointUrl: $($projectConfig.SharePointUrl)"
            Write-Host "    LibraryName: $($projectConfig.LibraryName)"
        }
    } else {
        Write-Host "  [WARN] project.properties not found, skipping ProjectConfig check"
    }
} catch {
    Write-Host "  [ERROR] ProjectConfig integration failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[PASS] All sanity checks passed!"
