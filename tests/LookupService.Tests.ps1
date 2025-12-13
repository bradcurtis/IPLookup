Describe 'LookupService existence checks' {
BeforeAll {
    if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }

    $logger = [Logger]::new('Debug', $false, '')
    $paths  = @((Join-Path $PSScriptRoot '..\data\ip-expressions.csv'))
    $service = [LookupService]::new($paths, $logger)

    Set-Variable -Name service -Value $service -Scope Global
}


    It 'finds IP inside CIDR' {
        $service.Exists('192.168.1.10') | Should -BeTrue
    }

    It 'rejects IP outside CIDR' {
        $service.Exists('192.168.2.5').Found | Should -BeFalse
    }

    It 'finds IP inside range' {
        $service.Exists('192.168.1.23') | Should -BeTrue
    }
}