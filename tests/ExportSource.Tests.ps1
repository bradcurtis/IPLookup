# ExportSource.Tests.ps1
# Pester tests for ExportSource helper class

BeforeAll {
    if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }
    . (Join-Path $PSScriptRoot '..\src\ExportSource.ps1')
    
    $global:logger = [Logger]::new("Info", $false, "")
    $global:testExportFolder = Join-Path $env:TEMP "ExportSourceTest"
    $global:testFile1 = Join-Path $global:testExportFolder "2025-12-18-Relay-fdswv09480-2-IPRangeExport.csv"
    $global:testFile2 = Join-Path $global:testExportFolder "2025-12-18-Relay-fdswv09481-TLS-IPRangeExport.csv"
    
    # Create test directory and dummy export files
    if (-not (Test-Path $global:testExportFolder)) {
        New-Item -ItemType Directory -Path $global:testExportFolder | Out-Null
    }
    
    "192.168.1.0/24`n10.0.0.0/8" | Set-Content $global:testFile1
    "172.16.0.0/12`n10.1.1.1" | Set-Content $global:testFile2
}

AfterAll {
    if (Test-Path $global:testExportFolder) {
        Remove-Item -Path $global:testExportFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "ExportSource factory" {
    It "creates a LocalExportSource when type is Local" {
        $config = @{
            ExportSourceType = "Local"
            ExportPath = $global:testExportFolder
        }
        $source = New-ExportSource -Config $config
        
        $source.Type | Should -Be "Local"
        $source.Path | Should -Be $global:testExportFolder
    }
    
    It "creates a LocalExportSource by default when type is omitted" {
        $config = @{
            ExportPath = $global:testExportFolder
        }
        $source = New-ExportSource -Config $config
        
        $source.Type | Should -Be "Local"
    }
    
    It "creates a SharePointExportSource when type is SharePoint" {
        $config = @{
            ExportSourceType = "SharePoint"
            SharePointUrl = "https://example.sharepoint.com/sites/MyTeam"
            LibraryName = "IP Exports"
            SharePointProvider = "REST"
        }
        $source = New-ExportSource -Config $config
        
        $source.Type | Should -Be "SharePoint-REST"
        $source.SiteUrl | Should -Be "https://example.sharepoint.com/sites/MyTeam"
        $source.LibraryName | Should -Be "IP Exports"
    }
    
    It "throws when SharePoint config is missing required fields" {
        $config = @{
            ExportSourceType = "SharePoint"
            SharePointUrl = "https://example.sharepoint.com"
        }
        
        { New-ExportSource -Config $config } | Should -Throw
    }
}

Describe "LocalExportSource functionality" {
    It "returns export files matching filter" {
        $config = @{
            ExportSourceType = "Local"
            ExportPath = $global:testExportFolder
        }
        $source = New-ExportSource -Config $config
        
        $files = $source.GetExportFiles()
        $files.Count | Should -Be 2
    }
    
    It "returns empty array when no matching files exist" {
        $emptyFolder = Join-Path $env:TEMP "ExportSourceEmpty"
        New-Item -ItemType Directory -Path $emptyFolder -Force | Out-Null
        
        try {
            $config = @{
                ExportSourceType = "Local"
                ExportPath = $emptyFolder
            }
            $source = New-ExportSource -Config $config
            
            $files = $source.GetExportFiles()
            $files.Count | Should -Be 0
        } finally {
            Remove-Item -Path $emptyFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "returns empty array when path does not exist" {
        $config = @{
            ExportSourceType = "Local"
            ExportPath = "C:\\NonExistent\\Path\\Here"
        }
        $source = New-ExportSource -Config $config
        
        $files = $source.GetExportFiles()
        $files.Count | Should -Be 0
    }
    
    It "completes DownloadExports without error (no-op for local)" {
        $config = @{
            ExportSourceType = "Local"
            ExportPath = $global:testExportFolder
        }
        $source = New-ExportSource -Config $config
        
        { $source.DownloadExports($env:TEMP) } | Should -Not -Throw
    }
}

Describe "SharePointExportSource initialization" {
    It "initializes with correct properties" {
        $config = @{
            ExportSourceType = "SharePoint"
            SharePointUrl = "https://example.sharepoint.com/sites/IP"
            LibraryName = "Range Exports"
            SharePointProvider = "REST"
        }
        $source = New-ExportSource -Config $config
        
        $source.Type | Should -Be "SharePoint-REST"
        $source.SiteUrl | Should -Be "https://example.sharepoint.com/sites/IP"
        $source.LibraryName | Should -Be "Range Exports"
        $source.Connection | Should -BeNullOrEmpty  # Not connected until needed
    }

    It "accepts a LibrarySubFolder when provided" {
        $config = @{
            ExportSourceType = "SharePoint"
            SharePointUrl = "https://example.sharepoint.com/sites/IP"
            LibraryName = "Shared Documents"
            LibrarySubFolder = "Files Exported/Connector Export"
        }
        $source = New-ExportSource -Config $config
        $source.LibrarySubFolder | Should -Be "Files Exported/Connector Export"
    }
}

Describe "ExportSource with ProjectConfig" {
    It "loads ExportSourceType and related config from ProjectConfig" {
        # This test validates that ProjectConfig properly loads the new export source properties
        $configPath = Join-Path $PSScriptRoot '..\project.properties'
        
        if (Test-Path $configPath) {
            $config = [ProjectConfig]::new($configPath, $global:logger)
            
            $config.ExportSourceType | Should -Not -BeNullOrEmpty
            $config.ExportPath | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "project.properties not found"
        }
    }
}
