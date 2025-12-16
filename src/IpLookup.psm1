<#
Module: IpLookup
Description: Initializes the IPLookup PowerShell module by loading the
	      required native type and dot-sourcing the script files
	      that implement the repository, lookup logic, and helpers.
Usage: Import-Module <path-to-this-folder> and then call exported
	functions from the module (see individual script files).
#>

# Ensure the native helper type is available to the module. The C# file
# provides performant IP network operations used by the scripts.
Add-Type -Path (Join-Path $PSScriptRoot 'IpNetworkNative.cs')

# Dot-source script dependencies in the order they must be loaded so that
# functions and variables are available to consumers and to each other.
. (Join-Path $PSScriptRoot 'IpExpressions.ps1')
. (Join-Path $PSScriptRoot 'CsvRepository.ps1')
. (Join-Path $PSScriptRoot 'Logger.ps1')
. (Join-Path $PSScriptRoot 'Parameters.ps1')
. (Join-Path $PSScriptRoot 'LookupService.ps1')

# Export-ModuleMember is intentionally left bare in this project: specific
# function exports may be added here if you want to limit the public surface
# of the module. Leaving it empty exports nothing by default.
Export-ModuleMember