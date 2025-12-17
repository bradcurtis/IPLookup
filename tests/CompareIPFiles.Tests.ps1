# CompareIpFiles.Tests.ps1
# Pester harness for multi-file Compare-IpFiles utility

BeforeAll {
    # Load all classes and utilities
    if (-not ("Logger" -as [type])) {
        . (Join-Path $PSScriptRoot '..\src\AllClasses.ps1')
    }

    # Create a logger instance
    $global:logger = [Logger]::new("Info", $false, "")

    # Prepare sample data files in temp folder
    $global:file1 = Join-Path $env:TEMP "ips1.csv"
    $global:file2 = Join-Path $env:TEMP "ips2.csv"
    $global:file3 = Join-Path $env:TEMP "ips3.csv"
    $global:csvPath = Join-Path $env:TEMP "ComparisonReport.csv"

    @"
192.168.1.10
192.168.1.20-192.168.1.25
192.168.2.0/30
10.0.0.0/29
invalid-line-here
"@ | Set-Content $file1

    @"
192.168.1.10
192.168.1.23-192.168.1.30
192.168.2.0-192.168.2.3
10.0.0.0-10.0.0.7
8.8.8.8
"@ | Set-Content $file2

    @"
192.168.1.10
192.168.1.20-192.168.1.22
192.168.3.0/29
1.1.1.1
"@ | Set-Content $file3
}

Describe 'Compare-IpFiles utility (multi-file)' {

    BeforeEach {
        Compare-IpFiles -Files @($file1, $file2, $file3) -Logger $logger -CsvPath $csvPath
        $global:report = Import-Csv $csvPath
    }

    It 'produces a CSV report' {
        Test-Path $csvPath | Should -BeTrue
        $report.Count | Should -BeGreaterThan 0
    }

    It 'reports exact matches (192.168.1.10 present in all files)' {
        @( $report | Where-Object {
            $_.ComparisonType -eq "Exact" -and
            ($_.Expression1 -eq "192.168.1.10" -or $_.Expression2 -eq "192.168.1.10")
        } ).Count | Should -BeGreaterThan 0
    }

    It 'detects missing entries (8.8.8.8 only in file2)' {
        @( $report | Where-Object {
            $_.ComparisonType -eq "Missing" -and
            ($_.Expression1 -eq "8.8.8.8" -or $_.Expression2 -eq "8.8.8.8")
        } ).Count | Should -BeGreaterThan 0
    }

    It 'detects partial overlaps (20-25 vs 23-30 vs 20-22)' {
        @( $report | Where-Object {
            $_.ComparisonType -eq "Overlap" -and
            ($_.Expression1 -like "192.168.1.20*" -or $_.Expression2 -like "192.168.1.20*")
        } ).Count | Should -BeGreaterThan 0
    }

    It 'detects CIDR vs equivalent range (192.168.2.0/30 vs 192.168.2.0-192.168.2.3)' {
        @( $report | Where-Object {
            $_.ComparisonType -eq "Overlap" -and
            ($_.Expression1 -eq "192.168.2.0/30" -or $_.Expression2 -eq "192.168.2.0/30")
        } ).Count | Should -BeGreaterThan 0
    }

    It 'reports invalid lines gracefully (invalid-line-here)' {
        # Just ensure the run completes and CSV exists
        Test-Path $csvPath | Should -BeTrue
    }

    It 'detects unique entries (file3 has 1.1.1.1, file2 has 8.8.8.8)' {
        @( $report | Where-Object {
            $_.ComparisonType -eq "Missing" -and
            ($_.Expression1 -eq "1.1.1.1" -or $_.Expression2 -eq "1.1.1.1")
        } ).Count | Should -BeGreaterThan 0

        @( $report | Where-Object {
            $_.ComparisonType -eq "Missing" -and
            ($_.Expression1 -eq "8.8.8.8" -or $_.Expression2 -eq "8.8.8.8")
        } ).Count | Should -BeGreaterThan 0
    }
}