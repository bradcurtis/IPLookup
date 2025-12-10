Describe 'LookupService with multiple CSV files' {
    BeforeAll {
        # Load all class definitions first
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')

        $logger  = [Logger]::new('Debug', $false, '')
        $paths   = @(
            (Join-Path $PSScriptRoot '..\data\ip-expressions.csv'),
            (Join-Path $PSScriptRoot '..\data\ip-expressions-2.csv')
        )
        $service = [LookupService]::new($paths, $logger)
        Set-Variable -Name service -Value $service -Scope Global
    }

    It 'finds IP from first file CIDR' {
        $service.Exists('192.168.1.50') | Should -BeTrue
    }

    It 'finds IP from second file single IP' {
        $service.Exists('10.0.0.5') | Should -BeTrue
    }

    It 'finds IP inside second file range' {
        $service.Exists('10.0.0.15') | Should -BeTrue
    }

    It 'rejects IP outside both files' {
        $service.Exists('8.8.8.8') | Should -BeFalse
    }

    It 'finds IP inside second file CIDR' {
        $service.Exists('172.16.5.25') | Should -BeTrue
    }
}