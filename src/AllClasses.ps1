# AllClasses.ps1
# Consolidated loader for all class definitions (PowerShell 5.1-safe)

# Ensure we’re in the right namespace for IP types
using namespace System
using namespace System.Net

# Load the C# helper (IpNetwork implementation)
if (-not ("IpNetwork" -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')
}


# Dot-source each class file so definitions are parsed into the session
if (-not ("IpExpression" -as [type])) {
    . (Join-Path $PSScriptRoot 'IpExpressions.ps1')
}

if (-not ("CsvRepository" -as [type])) {
    . (Join-Path $PSScriptRoot 'CsvRepository.ps1')
}

if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'Logger.ps1')
}

# Load shared config and helpers
Write-Host "Loading ProjectConfig.ps1 from $PSScriptRoot"
if (-not ("ProjectConfig" -as [type])) {
    . (Join-Path $PSScriptRoot 'ProjectConfig.ps1')
}


if (-not ("Parameters" -as [type])) {
    . (Join-Path $PSScriptRoot 'Parameters.ps1')
}

if (-not ("LookupService" -as [type])) {
    . (Join-Path $PSScriptRoot 'LookupService.ps1')
}

if (-not ("CompareIpFiles" -as [type])) {
    . (Join-Path $PSScriptRoot 'CompareIpFiles.ps1')
}

if (-not ("IpExpressionFactory" -as [type])) {
    . (Join-Path $PSScriptRoot 'IpExpressionFactory.ps1')
}
