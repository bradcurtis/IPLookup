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

<#
Simple script entry point for running a lookup against the provided
CSV of IP expressions.

Parameters:
- CsvPath: path to the CSV file or directory containing expression files
- Query: the IP address string to search for
- LogLevel / LogToFile / LogFilePath: logging controls
#>

# Load type and script dependencies so classes and helper functions are
# available to the script runtime. This mirrors how the module would
# normally be initialized when imported.
Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')
. (Join-Path $PSScriptRoot 'IpExpressions.ps1')
. (Join-Path $PSScriptRoot 'CsvRepository.ps1')
. (Join-Path $PSScriptRoot 'Logger.ps1')
. (Join-Path $PSScriptRoot 'Parameters.ps1')
. (Join-Path $PSScriptRoot 'LookupService.ps1')

# Create parameter and logger objects which encapsulate configuration
$parameters = [Parameters]::new($CsvPath, $LogLevel, $LogToFile, $LogFilePath)
$logger     = [Logger]::new($parameters.LogLevel, $parameters.LogToFile, $parameters.LogFilePath)

# Initialize repository and load expressions into memory
$repo       = [CsvRepository]::new($parameters.CsvPath)
$repo.Load($logger)

# Create the lookup service and perform the existence query. The
# service returns an object (or boolean depending on implementation),
# so we log the result and write a boolean to stdout for callers.
$service = [LookupService]::new($repo, $logger)
$result  = $service.Exists($Query)

if ($result) {
    $logger.Info("Result: EXISTS")
    Write-Output $true
} else {
    $logger.Info("Result: NOT FOUND")
    Write-Output $false
}