param(
    [Parameter(Mandatory)]
    [string] $CsvPath,
    [Parameter(Mandatory)]
    [string] $Query,
    [ValidateSet('Error','Warn','Info','Debug')]
    [string] $LogLevel = 'Info',
    [bool]   $LogToFile = $false,
    [string] $LogFilePath = ''
)

# Load class definitions directly (Option A)
Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')
. (Join-Path $PSScriptRoot 'IpExpressions.ps1')
. (Join-Path $PSScriptRoot 'CsvRepository.ps1')
. (Join-Path $PSScriptRoot 'Logger.ps1')
. (Join-Path $PSScriptRoot 'Parameters.ps1')
. (Join-Path $PSScriptRoot 'LookupService.ps1')

# Now the classes are available
$parameters = [Parameters]::new($CsvPath, $LogLevel, $LogToFile, $LogFilePath)
$logger     = [Logger]::new($parameters.LogLevel, $parameters.LogToFile, $parameters.LogFilePath)
$repo       = [CsvRepository]::new($parameters.CsvPath)
$repo.Load($logger)

$service = [LookupService]::new($repo, $logger)
$result  = $service.Exists($Query)

if ($result) {
    $logger.Info("Result: EXISTS")
    Write-Output $true
} else {
    $logger.Info("Result: NOT FOUND")
    Write-Output $false
}