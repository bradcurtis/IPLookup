Import-Module (Join-Path $PSScriptRoot 'Tests.psm1') -Force

BeforeAll {
    
    if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }
}



Describe 'IpExpression parsing' {
    It 'parses single IP' {
        $expr = [IpExpressionFactory]::Create('192.168.1.10')
        $expr.GetType().Name | Should -Be 'SingleIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.10')) | Should -BeTrue
        $expr.Raw | Should -Be '192.168.1.10'
    }

    It 'parses range' {
        $expr = [IpExpressionFactory]::Create('192.168.1.20-192.168.1.25')
        $expr.GetType().Name | Should -Be 'RangeIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.23')) | Should -BeTrue
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.19')) | Should -BeFalse
        $expr.Raw | Should -Be '192.168.1.20-192.168.1.25'
    }

    It 'parses CIDR' {
        $expr = [IpExpressionFactory]::Create('192.168.2.0/30')
        $expr.GetType().Name | Should -Be 'CidrIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.2.1')) | Should -BeTrue
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.2.4')) | Should -BeFalse
        $expr.Raw | Should -Be '192.168.2.0/30'
    }
}

Describe 'LookupService existence reporting' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
        $logger  = [Logger]::new('Debug', $false, '')
        $paths   = @(
            (Join-Path $PSScriptRoot '..\data\ip-expressions.csv'),
            (Join-Path $PSScriptRoot '..\data\ip-expressions-2.csv')
        )
        $service = [LookupService]::new($paths, $logger)
        Set-Variable -Name service -Value $service -Scope Global
    }

    It 'returns metadata when IP exists' {
        $result = $service.Exists('10.0.0.15')
        $result.Found | Should -BeTrue
        $result.Match | Should -Be '10.0.0.10-10.0.0.20'
        $result.File  | Should -Match 'ip-expressions-2.csv'
    }

    It 'returns Found = false when IP not present' {
        $result = $service.Exists('8.8.8.8')
        $result.Found | Should -BeFalse
    }
}

Describe 'Range overlap detection' {
    It 'detects overlapping ranges' {
        $range1 = [IpExpressionFactory]::Create('192.168.1.20-192.168.1.25')
        $range2 = [IpExpressionFactory]::Create('192.168.1.23-192.168.1.30')

        $range1.Overlaps($range2) | Should -BeTrue
        $range2.Overlaps($range1) | Should -BeTrue
    }

    It 'detects non-overlapping ranges' {
        $range1 = [IpExpressionFactory]::Create('192.168.1.20-192.168.1.25')
        $range2 = [IpExpressionFactory]::Create('192.168.1.30-192.168.1.35')

        $range1.Overlaps($range2) | Should -BeFalse
        $range2.Overlaps($range1) | Should -BeFalse
    }

    It 'detects touching ranges as overlapping' {
        $range1 = [IpExpressionFactory]::Create('192.168.1.20-192.168.1.25')
        $range2 = [IpExpressionFactory]::Create('192.168.1.25-192.168.1.30')

        $range1.Overlaps($range2) | Should -BeTrue
        $range2.Overlaps($range1) | Should -BeTrue
    }
}

Describe 'CIDR range detection' {
    It 'detects IPs inside the CIDR block' {
        $cidr = [IpExpressionFactory]::Create('192.168.2.0/30')
        $cidr.GetType().Name | Should -Be 'CidrIpExpression'

        $cidr.Contains([System.Net.IPAddress]::Parse('192.168.2.1')) | Should -BeTrue
        $cidr.Contains([System.Net.IPAddress]::Parse('192.168.2.2')) | Should -BeTrue
    }

    It 'detects IPs outside the CIDR block' {
        $cidr = [IpExpressionFactory]::Create('192.168.2.0/30')

        $cidr.Contains([System.Net.IPAddress]::Parse('192.168.2.4')) | Should -BeFalse
        $cidr.Contains([System.Net.IPAddress]::Parse('192.168.3.1')) | Should -BeFalse
    }

    It 'handles edge addresses correctly' {
        $cidr = [IpExpressionFactory]::Create('10.0.0.0/29')

        # Network range is 10.0.0.0 – 10.0.0.7
        $cidr.Contains([System.Net.IPAddress]::Parse('10.0.0.0')) | Should -BeTrue   # network address
        $cidr.Contains([System.Net.IPAddress]::Parse('10.0.0.7')) | Should -BeTrue   # broadcast address
        $cidr.Contains([System.Net.IPAddress]::Parse('10.0.0.8')) | Should -BeFalse  # just outside
    }
}
