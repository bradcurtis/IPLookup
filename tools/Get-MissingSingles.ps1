param(
    [string]$TargetServer = 'fdswv30900',
    [string]$TargetDate   = '2025-12-17'
)

if (-not $PSScriptRoot -or $PSScriptRoot -eq '') {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$reportsRoot = Join-Path $PSScriptRoot '..\reports' | Resolve-Path -ErrorAction Stop

$missingSingles =
    Get-ChildItem $reportsRoot -Filter '*-ComparisonReport-CC.csv' -File -Recurse |
    ForEach-Object {
        $date = Split-Path $_.DirectoryName -Leaf
        if ($date -ne $TargetDate) { return }

        Import-Csv -LiteralPath $_.FullName | Where-Object {
            $_.ComparisonType -eq 'Missing' -and
            $_.File2          -like "*$TargetServer*" -and
            $_.Expression1    -notmatch '[-/]'
        } | Select-Object @{n='Date';e={$date}},
                          @{n='OtherServer';e={
                              $leaf = Split-Path $_.File1 -Leaf
                              if ($leaf -match '-Relay-(?<srv>[^-]+)') { $Matches['srv'] } else { $leaf }
                          }},
                          File1, Line1, Expression1,
                          File2, Line2, Expression2
    }

$missingSingles |
    Where-Object { $_ } |
    Sort-Object Expression1 -Unique |
    Export-Csv (Join-Path $reportsRoot "missing-on-$TargetServer-$TargetDate.csv") -NoTypeInformation