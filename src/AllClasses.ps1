# AllClasses.ps1
# Consolidated loader for all class and helper definitions used by the
# project. This file is a convenience entry point for interactive
# sessions and scripts that need to ensure all types are available.

# Import commonly used .NET namespaces for IP handling
using namespace System
using namespace System.Net

# Load the C# helper (IpNetwork implementation) if not already present
if (-not ("IpNetwork" -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')
}

# Dot-source each PowerShell file containing class definitions or
# helpers. Guard with type checks so the file can be safely sourced
# multiple times without re-defining types.
if (-not ("IpExpression" -as [type])) {
    . (Join-Path $PSScriptRoot 'IpExpressions.ps1')
}

if (-not ("CsvRepository" -as [type])) {
    . (Join-Path $PSScriptRoot 'CsvRepository.ps1')
}

if (-not ("Logger" -as [type])) {
    . (Join-Path $PSScriptRoot 'Logger.ps1')
}

# Load shared configuration and parameter helper classes
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
