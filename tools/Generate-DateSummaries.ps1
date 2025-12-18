# Generate-DateSummaries.ps1
# Scan `reports\YYYY-MM-DD` subfolders, read `GroupedIssues.csv` in each,
# and produce a summary CSV `reports\summary-by-date.csv` with counts per date.

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportsRoot = Join-Path $scriptRoot '..\reports' | Resolve-Path -ErrorAction SilentlyContinue
if (-not $reportsRoot) { $reportsRoot = Join-Path (Get-Location) 'reports' }
$reportsRoot = (Resolve-Path $reportsRoot).ProviderPath

Write-Host "Scanning reports root: $reportsRoot"

$dateDirs = Get-ChildItem -Path $reportsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
if (-not $dateDirs -or $dateDirs.Count -eq 0) {
    Write-Warning "No date-formatted subfolders (YYYY-MM-DD) found under $reportsRoot. Skipping summary generation."
    # Write an empty summary file so callers have a predictable artifact
    $outPath = Join-Path $reportsRoot 'summary-by-date.csv'
    @() | Export-Csv -Path $outPath -NoTypeInformation -Force
    Write-Host "Wrote empty summary to: $outPath"
    return
}

$summaries = @()
foreach ($dir in $dateDirs) {
    $date = $dir.Name
    $groupedPath = Join-Path $dir.FullName 'GroupedIssues.csv'

    $total = 0; $open = 0; $fixed = 0; $connectors = @(); $servers = @()
    if (Test-Path $groupedPath) {
        $rows = Import-Csv -Path $groupedPath
        $total = $rows.Count
        $open = ($rows | Where-Object { ($_.Fixed -eq $null) -or ($_.Fixed -eq '') -or ($_.Fixed -eq 'False') -or ($_.Fixed -eq $false) }).Count
        $fixed = ($rows | Where-Object { ($_.Fixed -ne $null) -and ($_.Fixed -ne '') -and ($_.Fixed -ne 'False') -and ($_.Fixed -ne $false) }).Count
        $connectors = ($rows | Select-Object -ExpandProperty Connector -Unique) -join ', '
        if ($rows | Get-Member -Name ServerName -MemberType NoteProperty -ErrorAction SilentlyContinue) {
            $servers = ($rows | Select-Object -ExpandProperty ServerName -Unique) -join ', '
        } else {
            $servers = ''
        }
    } else {
        # No grouped issues file, try to produce summary from IPExpression CSVs
        $ipExprFiles = Get-ChildItem -Path $dir.FullName -Filter '*IPExpression*.csv' -File -ErrorAction SilentlyContinue
        if ($ipExprFiles) {
            $total = ($ipExprFiles | ForEach-Object { (Import-Csv $_.FullName).Count } | Measure-Object -Sum).Sum
            $connectors = ($ipExprFiles | Select-Object -ExpandProperty BaseName -Unique) -join ', '
        }
    }

    $summaries += [PSCustomObject]@{
        Date = $date
        TotalIssues = $total
        OpenIssues = $open
        FixedIssues = $fixed
        UniqueConnectors = ($connectors -split ', ' | Where-Object { $_ -ne '' }).Count
        Connectors = $connectors
        UniqueServers = ($servers -split ', ' | Where-Object { $_ -ne '' }).Count
        Servers = $servers
    }
}

# Compute deltas (sort ascending by date)
$summaries = $summaries | Sort-Object {[datetime]$_.Date}
$prevOpen = $null
foreach ($s in $summaries) {
    if ($prevOpen -ne $null) {
        $s | Add-Member -MemberType NoteProperty -Name DeltaOpen -Value ($s.OpenIssues - $prevOpen)
        if ($prevOpen -ne 0) {
            $pct = [math]::Round((($s.OpenIssues - $prevOpen) / $prevOpen) * 100, 2)
        } else { $pct = $null }
        $s | Add-Member -MemberType NoteProperty -Name PctChangeOpen -Value $pct
    } else {
        $s | Add-Member -MemberType NoteProperty -Name DeltaOpen -Value $null
        $s | Add-Member -MemberType NoteProperty -Name PctChangeOpen -Value $null
    }
    $prevOpen = $s.OpenIssues
}

$outPath = Join-Path $reportsRoot 'summary-by-date.csv'
$summaries | Export-Csv -Path $outPath -NoTypeInformation

Write-Host "Wrote summary to: $outPath"
Write-Host "Summary (most recent):"
$summaries | Select-Object -Last 10 | Format-Table -AutoSize
