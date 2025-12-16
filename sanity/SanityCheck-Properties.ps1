Write-Host "=== Sanity Check: ProjectConfig ==="

# Load class definitions
$srcPath = Join-Path $PSScriptRoot "..\src"
$allClassesPath = Join-Path $srcPath "AllClasses.ps1"
$projectConfigPath = Join-Path $srcPath "ProjectConfig.ps1"

Write-Host "Loading AllClasses.ps1 from $allClassesPath"
. $allClassesPath

Write-Host "Loading ProjectConfig.ps1 from $projectConfigPath"
. $projectConfigPath

# Check if class is defined
if (-not ("ProjectConfig" -as [type])) {
    Write-Host "[FAIL] ProjectConfig class is not defined." -ForegroundColor Red
    return
} else {
    Write-Host "[OK] ProjectConfig class is defined." -ForegroundColor Green
}

# Try to instantiate ProjectConfig
try {
    Write-Host "Defining class ProjectConfig"
    $configPath = Join-Path $PSScriptRoot "test-config.properties"

    # Create a logger instance to inject
    $logPath = Join-Path $PSScriptRoot "..\logs\sanity.log"
    $logger = [Logger]::new("Info", $true, $logPath)

    # Instantiate ProjectConfig with logger
    $config = [ProjectConfig]::new($configPath, $logger)

    Write-Host "[OK] ProjectConfig instance created." -ForegroundColor Green
    Write-Host "Environment: $($config.Environment)"
    Write-Host "Logger Type: $($config.Logger.GetType().Name)"
}
catch {
    Write-Host "[FAIL] Failed to instantiate ProjectConfig:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
