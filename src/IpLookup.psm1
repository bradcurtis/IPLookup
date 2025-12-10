# PowerShell 5.1 module init

Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')

# Load in dependency order
. (Join-Path $PSScriptRoot 'IpExpressions.ps1')
. (Join-Path $PSScriptRoot 'CsvRepository.ps1')
. (Join-Path $PSScriptRoot 'Logger.ps1')
. (Join-Path $PSScriptRoot 'Parameters.ps1')
. (Join-Path $PSScriptRoot 'LookupService.ps1')

Export-ModuleMember