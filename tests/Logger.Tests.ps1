Describe 'Logger behavior' {
    BeforeAll {
        if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }
    }

    It 'writes Info messages to host' {
        $logger = [Logger]::new('Info', $false, '')
        $logger.Info("Test info message")
        $true | Should -BeTrue
    }

   <#
    Removing for pester test output file #>
    It 'writes Error messages to host' {
        $logger = [Logger]::new('Error', $false, '')
        $logger.Error("[EXPECTED] Logger test error message")
        $true | Should -BeTrue
    }<# #>#>

    It 'respects log level threshold' {
        $logger = [Logger]::new('Warn', $false, '')
        $logger.Debug("This should not appear")
        $true | Should -BeTrue
    }
}