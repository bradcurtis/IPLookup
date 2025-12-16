Import-Module (Join-Path $PSScriptRoot 'Tests.psm1') -Force

BeforeAll {
    if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }
    . (Join-Path $PSScriptRoot '..\src\Analyze-IpExpressionFile.ps1')

    $TestOutput = Join-Path $PSScriptRoot 'data'
    if (-not (Test-Path $TestOutput)) {
        New-Item -ItemType Directory -Path $TestOutput | Out-Null
    }

    $Logger = [Logger]::new('Warn', $false, '')
}

Describe 'Analyze-IpExpressionFile scenarios' {

    It 'detects overlapping entries' {
        $path = Join-Path $TestOutput 'overlap.csv'
        @(
            '10.0.0.1',
            '10.0.0.0/24'
        ) | Set-Content $path

        Analyze-IpExpressionFile -Path $path -Logger $Logger -OutputFolder $TestOutput

        $file = Get-ChildItem "$TestOutput\*-overlap-IPExpression.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
        $file | Should -Not -BeNullOrEmpty -Because "Expected overlap report file"

        $report = Get-Content $file.FullName | Out-String
        $report | Should -Match 'Overlap'
    }

    It 'detects >11 consecutive single IPs as SuggestRange' {
        $path = Join-Path $TestOutput 'consecutive.csv'
        1..12 | ForEach-Object { "192.168.1.$_" } | Set-Content $path

        Analyze-IpExpressionFile -Path $path -Logger $Logger -OutputFolder $TestOutput

        $file = Get-ChildItem "$TestOutput\*-consecutive-IPExpression.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
        $file | Should -Not -BeNullOrEmpty -Because "Expected consecutive IP report file"

        $report = Get-Content $file.FullName | Out-String
        $report | Should -Match 'SuggestRange'
    }

    It 'detects small CIDRs as SuggestFlatten' {
        $path = Join-Path $TestOutput 'smallcidr.csv'
        @('10.0.0.0/30') | Set-Content $path

        Analyze-IpExpressionFile -Path $path -Logger $Logger -OutputFolder $TestOutput

        $file = Get-ChildItem "$TestOutput\*-smallcidr-IPExpression.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
        $file | Should -Not -BeNullOrEmpty -Because "Expected small CIDR report file"

        $report = Get-Content $file.FullName | Out-String
        $report | Should -Match 'SuggestFlatten'
    }

    It 'detects small dash-ranges as SmallRange' {
        $path = Join-Path $TestOutput 'smalldash.csv'
        @('10.0.0.1-10.0.0.5') | Set-Content $path

        Analyze-IpExpressionFile -Path $path -Logger $Logger -OutputFolder $TestOutput

        $file = Get-ChildItem "$TestOutput\*-smalldash-IPExpression.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
        $file | Should -Not -BeNullOrEmpty -Because "Expected small dash-range report file"

        $report = Get-Content $file.FullName | Out-String
        $report | Should -Match 'SmallRange'
    }

    It 'passes clean file with no issues' {
        $path = Join-Path $TestOutput 'clean.csv'
        @(
            '192.168.10.1',
            '192.168.20.1',
            '10.10.10.0/24'
        ) | Set-Content $path

        Analyze-IpExpressionFile -Path $path -Logger $Logger -OutputFolder $TestOutput

        $report = Get-ChildItem "$TestOutput\*-clean-IPExpression.csv" -ErrorAction SilentlyContinue
        $report | Should -BeNullOrEmpty -Because "Expected no report for clean input"
    }
}
