# Load all types before discovery
. ([scriptblock]::Create(". '$PSScriptRoot\..\src\AllClasses.ps1'"))

Describe 'ProjectConfig' {
    BeforeAll {
        $tempFile = Join-Path $PSScriptRoot 'test-config.properties'

        @"
Environment=Test
InputFolder=inputs
OutputFolder=outputs
LogFolder=logs
LogLevel=Info
EnableUpload=false
SharePointSite=https://test.sharepoint.com/sites/demo
TargetLibrary=Shared Documents/Demo
"@ | Set-Content $tempFile

        # Create a logger to inject
        $logPath = Join-Path $PSScriptRoot 'test.log'
        $logger = [Logger]::new("Info", $true, $logPath)

        # Instantiate ProjectConfig with logger
        $config = [ProjectConfig]::new($tempFile, $logger)

        Set-Variable -Name config -Value $config -Scope Global
    }

    It 'maps properties into class members' {
        $config.Environment    | Should -Be 'Test'
        $config.InputFolder    | Should -Match 'inputs$'
        $config.OutputFolder   | Should -Match 'outputs$'
        $config.LogLevel       | Should -Be 'Info'
        $config.EnableUpload   | Should -BeFalse
        $config.SharePointSite | Should -Match 'test.sharepoint.com'
        $config.TargetLibrary  | Should -Match 'Shared Documents/Demo'
    }

    It 'initializes logger and ensures log folder exists' {
        $config.Logger.GetType().Name | Should -Be 'Logger'
        Test-Path $config.LogFolder   | Should -BeTrue
    }

    AfterAll {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Remove-Item $logPath -Force -ErrorAction SilentlyContinue
    }
}
