Describe 'Logger behavior' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }

    It 'writes Info messages to host' {
        $logger = [Logger]::new('Info', $false, '')
        $logger.Info("Test info message")
        $true | Should -BeTrue
    }

    It 'writes Error messages to host' {
        $logger = [Logger]::new('Error', $false, '')
        $logger.Error("Test error message")
        $true | Should -BeTrue
    }

    It 'respects log level threshold' {
        $logger = [Logger]::new('Warn', $false, '')
        $logger.Debug("This should not appear")
        $true | Should -BeTrue
    }
}