# AllClasses.ps1
# Consolidated loader for all class definitions (PowerShell 5.1-safe)

# Load the C# helper
Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')

# Dot-source each class file so definitions are parsed into the session
. (Join-Path $PSScriptRoot 'IpExpressions.ps1')
. (Join-Path $PSScriptRoot 'CsvRepository.ps1')
. (Join-Path $PSScriptRoot 'Logger.ps1')
. (Join-Path $PSScriptRoot 'Parameters.ps1')
. (Join-Path $PSScriptRoot 'LookupService.ps1')