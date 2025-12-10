Import-Module (Join-Path $PSScriptRoot 'Tests.psm1') -Force

Describe 'IpExpression parsing' {
    It 'parses single IP' {
        $expr = [IpExpressionFactory]::Create('192.168.1.10')
        $expr.GetType().Name | Should -Be 'SingleIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.10')) | Should -BeTrue
    }

    It 'parses range' {
        $expr = [IpExpressionFactory]::Create('192.168.1.20-192.168.1.25')
        $expr.GetType().Name | Should -Be 'RangeIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.23')) | Should -BeTrue
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.1.19')) | Should -BeFalse
    }

    It 'parses CIDR' {
        $expr = [IpExpressionFactory]::Create('192.168.2.0/30')
        $expr.GetType().Name | Should -Be 'CidrIpExpression'
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.2.1')) | Should -BeTrue
        $expr.Contains([System.Net.IPAddress]::Parse('192.168.2.4')) | Should -BeFalse
    }
}