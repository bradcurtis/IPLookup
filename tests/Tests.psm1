# Tests.psm1
# Shared test module to preload all classes for PowerShell 5.1

# Ensure classes are loaded once for all test files
if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }

Export-ModuleMember