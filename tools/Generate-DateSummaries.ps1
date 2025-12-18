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

# Load all date directories and their issues
$dateData = @{}
foreach ($dir in $dateDirs) {
    $date = $dir.Name
    $groupedPath = Join-Path $dir.FullName 'GroupedIssues.csv'
    
    if (Test-Path $groupedPath) {
        $rows = Import-Csv -Path $groupedPath
        $dateData[$date] = $rows
    } else {
        $dateData[$date] = @()
    }
}

# Sort dates chronologically
$sortedDates = $dateData.Keys | Sort-Object {[datetime]$_}

# Track issues across dates and mark which were fixed
$previousIssues = @{}
foreach ($date in $sortedDates) {
    $currentIssues = $dateData[$date]
    
    # Build a set of current issue keys (Connector + IssueType + Expression)
    $currentKeys = @{}
    foreach ($issue in $currentIssues) {
        $key = "$($issue.Connector)|$($issue.IssueType)|$($issue.Expression)"
        $currentKeys[$key] = $true
    }
    
    # Check previous issues to see if they're fixed
    if ($previousIssues.Count -gt 0) {
        foreach ($issue in $currentIssues) {
            $key = "$($issue.Connector)|$($issue.IssueType)|$($issue.Expression)"
            
            # If this issue was present in previous date and Fixed is not already set, mark as still open
            if ($previousIssues.ContainsKey($key)) {
                if (-not $issue.Fixed -or $issue.Fixed -eq '' -or $issue.Fixed -eq 'False' -or $issue.Fixed -eq $false) {
                    # Issue persists from previous date
                    $issue.Fixed = 'False'
                }
            }
        }
        
        # Find issues from previous date that are no longer present (were fixed)
        foreach ($prevKey in $previousIssues.Keys) {
            if (-not $currentKeys.ContainsKey($prevKey)) {
                # Issue from previous date is now resolved - mark it in previous date's data
                $parts = $prevKey -split '\|', 3
                $prevIssue = $previousIssues[$prevKey]
                if ($prevIssue -and (-not $prevIssue.Fixed -or $prevIssue.Fixed -eq '' -or $prevIssue.Fixed -eq 'False' -or $prevIssue.Fixed -eq $false)) {
                    $prevIssue.Fixed = $date  # Mark with the date it was fixed
                }
            }
        }
    }
    
    # Update previous issues tracking
    $previousIssues.Clear()
    foreach ($issue in $currentIssues) {
        $key = "$($issue.Connector)|$($issue.IssueType)|$($issue.Expression)"
        $previousIssues[$key] = $issue
    }
}

# Write updated GroupedIssues back to disk
foreach ($date in $sortedDates) {
    $dateFolder = Join-Path $reportsRoot $date
    $groupedPath = Join-Path $dateFolder 'GroupedIssues.csv'
    if ($dateData[$date] -and $dateData[$date].Count -gt 0) {
        $dateData[$date] | Export-Csv -Path $groupedPath -NoTypeInformation -Force
    }
}

# Generate summaries (reload from disk to get updated Fixed values)
$summaries = @()
foreach ($date in $sortedDates) {
    $dateFolder = Join-Path $reportsRoot $date
    $groupedPath = Join-Path $dateFolder 'GroupedIssues.csv'
    
    if (Test-Path $groupedPath) {
        $rows = Import-Csv -Path $groupedPath
    } else {
        $rows = @()
    }
    
    $total = $rows.Count
    $openItems = @($rows | Where-Object { ($_.Fixed -eq $null) -or ($_.Fixed -eq '') -or ($_.Fixed -eq 'False') -or ($_.Fixed -eq $false) })
    $fixedItems = @($rows | Where-Object { ($_.Fixed -ne $null) -and ($_.Fixed -ne '') -and ($_.Fixed -ne 'False') -and ($_.Fixed -ne $false) })
    $open = $openItems.Count
    $fixed = $fixedItems.Count
    $connectors = ($rows | Select-Object -ExpandProperty Connector -Unique) -join ', '
    
    if ($rows | Get-Member -Name ServerName -MemberType NoteProperty -ErrorAction SilentlyContinue) {
        $servers = ($rows | Select-Object -ExpandProperty ServerName -Unique) -join ', '
    } else {
        $servers = ''
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
